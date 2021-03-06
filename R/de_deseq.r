#' deseq_pairwise()  Because I can't be trusted to remember '2'.
#'
#' This calls deseq2_pairwise(...) because I am determined to forget typing deseq2.
#'
#' @param ... I like cats.
#' @return stuff deseq2_pairwise results.
#' @seealso \code{\link{deseq2_pairwise}}
#' @export
deseq_pairwise <- function(...) {
  message("Hey you, use deseq2 pairwise.")
  deseq2_pairwise(...)
}

#' Set up model matrices contrasts and do pairwise comparisons of all conditions using DESeq2.
#'
#' Invoking DESeq2 is confusing, this should help.
#'
#' Tested in test_24de_deseq.R
#' Like the other _pairwise() functions, this attempts to perform all pairwise contrasts in the
#' provided data set.  The details are of course slightly different when using DESeq2.  Thus, this
#' uses the function choose_binom_dataset() to try to ensure that the incoming data is appropriate
#' for DESeq2 (if one normalized the data, it will attempt to revert to raw counts, for example).
#' It continues on to extract the conditions and batches in the data, choose an appropriate
#' experimental model, and run the DESeq analyses as described in the manual.  It defaults to using
#' an experimental batch factor, but will accept a string like 'sva' instead, in which case it will
#' use sva to estimate the surrogates, and append them to the experimental design.  The deseq_method
#' parameter may be used to apply different DESeq2 code paths as outlined in the manual.  If you
#' want to play with non-standard data, the force argument will round the data and shoe-horn it into
#' DESeq2.
#'
#' @param input  Dataframe/vector or expt class containing data, normalization state, etc.
#' @param conditions  Factor of conditions in the experiment.
#' @param batches  Factor of batches in the experiment.
#' @param model_cond  Is condition in the experimental model?
#' @param model_batch  Is batch in the experimental model?
#' @param model_intercept  Use an intercept model?
#' @param alt_model  Provide an arbitrary model here.
#' @param extra_contrasts  Provide extra contrasts here.
#' @param annot_df  Include some annotation information in the results?
#' @param force  Force deseq to accept data which likely violates its assumptions.
#' @param deseq_method  The DESeq2 manual shows a few ways to invoke it, I make 2 of them available here.
#' @param ...  Triple dots!  Options are passed to arglist.
#' @return List including the following information:
#'  run = the return from calling DESeq()
#'  denominators = list of denominators in the contrasts
#'  numerators = list of the numerators in the contrasts
#'  conditions = the list of conditions in the experiment
#'  coefficients = list of coefficients making the contrasts
#'  all_tables = list of DE tables
#' @seealso \pkg{DESeq2} \pkg{Biobase} \pkg{stats}
#' @examples
#' \dontrun{
#'  pretend = deseq2_pairwise(data, conditions, batches)
#' }
#' @export
deseq2_pairwise <- function(input=NULL, conditions=NULL,
                            batches=NULL, model_cond=TRUE,
                            model_batch=TRUE, model_intercept=FALSE,
                            alt_model=NULL, extra_contrasts=NULL,
                            annot_df=NULL, force=FALSE, 
                            deseq_method="long", ...) {
  arglist <- list(...)

  message("Starting DESeq2 pairwise comparisons.")
  input_data <- choose_binom_dataset(input, force=force)
  ## Now that I understand pData a bit more, I should probably remove the conditions/batches slots
  ## from my expt classes.
  design <- pData(input)
  conditions <- input_data[["conditions"]]
  batches <- input_data[["batches"]]
  data <- input_data[["data"]]
  conditions_table <- table(conditions)
  batches_table <- table(batches)
  condition_levels <- levels(as.factor(conditions))
  ## batch_levels <- levels(as.factor(batches))
  ## Make a model matrix which will have one entry for
  ## each of the condition/batches
  summarized <- NULL
  ## Moving the size-factor estimation into this if(){} block in order to accomodate sva-ish
  ## batch estimation in the model
  deseq_sf <- NULL

  ## A caveat because this is a point of confusion
  ## choose_model() returns a few models, including intercept and non-intercept versions
  ## of the same things.  However, if model_batch is passed as something like 'sva', then
  ## it will gather surrogate estimates from sva and friends and return those estimates.
  model_choice <- choose_model(input, conditions, batches,
                               model_batch=model_batch,
                               model_cond=model_cond,
                               model_intercept=model_intercept,
                               alt_model=alt_model, ...)
  ## model_choice <- choose_model(input, conditions, batches,
  ##                              model_batch=model_batch,
  ##                              model_cond=model_cond,
  ##                              model_intercept=model_intercept,
  ##                              alt_model=alt_model)
  model_data <- model_choice[["chosen_model"]]
  model_including <- model_choice[["including"]]
  model_string <- model_choice[["chosen_string"]]
  column_data <- pData(input)
  if (class(model_choice[["model_batch"]]) == "matrix") {
    ## The SV matrix from sva/ruv/etc are put into the model batch slot of the return from choose_model.
    ## Use them here if appropriate
    model_batch <- model_choice[["model_batch"]]
    column_data <- cbind(column_data, model_batch)
  }
  ## choose_model should now take all of the following into account
  ## Therefore the following 8 or so lines should not be needed any longer.
  model_string <- NULL
  if (isTRUE(model_batch) & isTRUE(model_cond)) {
    message("DESeq2 step 1/5: Including batch and condition in the deseq model.")
    ## summarized = DESeqDataSetFromMatrix(countData=data, colData=pData(input$expressionset), design=~ 0 + condition + batch)
    ## conditions and batch in this context is information taken from pData()
    ##model_string <- "~ batch + condition"
    model_string <- model_choice[["chosen_string"]]
    column_data[["condition"]] <- as.factor(column_data[["condition"]])
    column_data[["batch"]] <- as.factor(column_data[["batch"]])
    summarized <- import_deseq(data, column_data, model_string, tximport=input[["tximport"]][["raw"]])
    dataset <- DESeq2::DESeqDataSet(se=summarized, design=as.formula(model_string))
  } else if (isTRUE(model_batch)) {
    message("DESeq2 step 1/5: Including only batch in the deseq model.")
    ##model_string <- "~ batch "
    model_string <- model_choice[["chosen_string"]]
    column_data[["batch"]] <- as.factor(column_data[["batch"]])
    summarized <- import_deseq(data, columns_data, model_string)
    dataset <- DESeq2::DESeqDataSet(se=summarized, design=as.formula(model_string))
  } else if (class(model_batch) == "matrix") {
    message("DESeq2 step 1/5: Including a matrix of batch estimates from sva/ruv/pca in the deseq model.")
    ##model_string <- "~ condition"
    ##cond_model_string <- "~ condition"
    sv_model_string <- model_choice[["chosen_string"]]
    column_data[["condition"]] <- as.factor(column_data[["condition"]])
    summarized <- import_deseq(data, column_data, sv_model_string)
    dataset <- DESeq2::DESeqDataSet(se=summarized, design=as.formula(sv_model_string))
    ## I think the following lines are no longer needed now that I properly add the SVs to the model.
    ##passed <- FALSE
    ##num_sv <- ncol(model_batch)
    ##new_dataset <- deseq_try_sv(dataset, summarized, model_batch)
    ##dataset <- new_dataset
    ##rm(new_dataset)
  } else {
    message("DESeq2 step 1/5: Including only condition in the deseq model.")
    model_string <- model_choice[["chosen_string"]]
    ##model_string <- "~ condition"
    column_data[["condition"]] <- as.factor(column_data[["condition"]])
    summarized <- import_deseq(data, column_data, model_string)
    dataset <- DESeq2::DESeqDataSet(se=summarized, design=as.formula(model_string))
  }

  deseq_run <- NULL
  chosen_beta <- model_intercept
  if (deseq_method == "short") {
    message("DESeq steps 2-4 in one shot.")
    deseq_run <- try(DESeq2::DESeq(dataset, fitType="parametric", betaPrior=chosen_beta), silent=TRUE)
    if (class(deseq_run) == "try-error") {
      message("A fitType of 'parametric' failed for this data, trying 'mean'.")
      deseq_run <- try(DESeq2::DESeq(dataset, fitType="mean"), silent=TRUE)
      if (class(deseq_run) == "try-error") {
        message("Both 'parametric' and 'mean' failed.  Trying 'local'.")
        deseq_run <- try(DESeq2::DESeq(dataset, fitType="local"), silent=TRUE)
        if (class(deseq_run) == "try-error") {
          warning("All fitting types failed.  This will end badly.")
        } else {
          message("Using a local fit seems to have worked.")
        }
      } else {
        message("Using a mean fitting seems to have worked.")
      }
    }
  } else {
    ## Eg. Using the long method of invoking DESeq.
    ## If making a model ~0 + condition -- then must set betaPrior=FALSE
    message("DESeq2 step 2/5: Estimate size factors.")
    deseq_sf <- DESeq2::estimateSizeFactors(dataset)
    message("DESeq2 step 3/5: Estimate dispersions.")
    deseq_disp <- try(DESeq2::estimateDispersions(deseq_sf, fitType="parametric"), silent=TRUE)
    if (class(deseq_disp) == "try-error") {
      message("Trying a mean fitting.")
      deseq_disp <- try(DESeq2::estimateDispersions(deseq_sf, fitType="mean"), silent=TRUE)
      if (class(deseq_disp) == "try-error") {
        warning("Both 'parametric' and 'mean' failed.  Trying 'local'.")
        deseq_disp <- try(DESeq2::estimateDispersions(deseq_sf, fitType="local"), silent=TRUE)
        if (class(deseq_disp) == "try-error") {
          warning("All fitting types failed.  This will end badly.")
        } else {
          message("Using a local fit seems to have worked.")
        }
      } else {
        message("Using a mean fitting seems to have worked.")
      }
    } else {
      message("Using a parametric fitting seems to have worked.")
    }
    ## deseq_run = nbinomWaldTest(deseq_disp, betaPrior=FALSE)
    message("DESeq2 step 4/5: nbinomWaldTest.")
    ## deseq_run <- DESeq2::DESeq(deseq_disp)
    deseq_run <- DESeq2::nbinomWaldTest(deseq_disp, betaPrior=chosen_beta, quiet=TRUE)
  }

  message("Plotting dispersions.")
  dispersions <- sm(try(DESeq2::plotDispEsts(deseq_run), silent=TRUE))
  dispersion_plot <- NULL
  if (class(dispersions)[[1]] != "try-error") {
    dispersion_plot <- grDevices::recordPlot()
  }

  ## possible options:  betaPrior=TRUE, betaPriorVar, modelMatrix=NULL
  ## modelMatrixType, maxit=100, useOptim=TRUE useT=FALSE df useQR=TRUE
  ## deseq_run = DESeq2::nbinomLRT(deseq_disp)
  ## Set contrast= for each pairwise comparison here!

  ## DESeq does not use contrasts in a way familiar to limma/edgeR
  ## Therefore we will create all sets of c/d using these for loops.
  denominators <- list()
  numerators <- list()
  result_list <- list()
  coefficient_list <- list()
  ## The following is an attempted simplification of the contrast formulae
  number_comparisons <- sum(1:(length(condition_levels) - 1))
  inner_count <- 0
  contrasts <- c()
  for (c in 1:(length(condition_levels) - 1)) {
    denominator <- condition_levels[c]
    nextc <- c + 1
    for (d in nextc:length(condition_levels)) {
      inner_count <- inner_count + 1
      numerator <- condition_levels[d]
      comparison <- paste0(numerator, "_vs_", denominator)
      contrasts <- append(comparison, contrasts)
      message(paste0("DESeq2 step 5/5: ", inner_count, "/",
                     number_comparisons, ": Creating table: ", comparison))
      result <- as.data.frame(DESeq2::results(deseq_run,
                                              contrast=c("condition", numerator, denominator),
                                              format="DataFrame"))
      result <- result[order(result[["log2FoldChange"]]), ]
      colnames(result) <- c("baseMean", "logFC", "lfcSE", "stat", "P.Value", "adj.P.Val")
      ## From here on everything is the same.
      result[is.na(result[["P.Value"]]), "P.Value"] <- 1 ## Some p-values come out as NA
      result[is.na(result[["adj.P.Val"]]), "adj.P.Val"] <- 1 ## Some p-values come out as NA
      result[["baseMean"]] <- signif(x=as.numeric(result[["baseMean"]]), digits=4)
      result[["logFC"]] <- signif(x=as.numeric(result[["logFC"]]), digits=4)
      result[["lfcSE"]] <- signif(x=as.numeric(result[["lfcSE"]]), digits=4)
      result[["stat"]] <- signif(x=as.numeric(result[["stat"]]), digits=4)
      result[["P.Value"]] <- signif(x=as.numeric(result[["P.Value"]]), digits=4)
      result[["adj.P.Val"]] <- signif(x=as.numeric(result[["adj.P.Val"]]), digits=4)
      result_name <- paste0(numerator, "_vs_", denominator)
      denominators[[result_name]] <- denominator
      numerators[[result_name]] <- numerator
      if (!is.null(annot_df)) {
        result <- merge(result, annot_df, by.x="row.names", by.y="row.names")
      }
      result_list[[result_name]] <- result
    } ## End for each d
    ## Fill in the last coefficient (since the for loop above goes from 1 to n-1
    denominator <- names(conditions_table[length(conditions)])
    ## denominator_name = paste0("condition", denominator)  ## maybe needed in 6 lines
  }  ## End for each c

  ## The logic here is a little tortuous.
  ## Here are some sample column names from an arbitrary coef() call:
  ## "Intercept" "SV1" "SV2" "SV3" "condition_mtc_wtu_vs_mtc_mtu"
  ## First of all, we don't care about the 'condition' prefix.
  ## In addition, if we want the coefficient for mtc_wtu, then we need to subtract
  ## the mtc_wtu_vs_mtc_mtu from the Intercept, which is annoying.
  ## The following lines will attempt to do these things and
  ## appropriately rename the columns.
  coefficient_df <- coef(deseq_run)
  ## Here I will just simplify the column names.
  colnames(coefficient_df) <- gsub(pattern="^condition", replacement="", x=colnames(coefficient_df))
  colnames(coefficient_df) <- gsub(pattern="^batch", replacement="", x=colnames(coefficient_df))
  colnames(coefficient_df) <- gsub(pattern="^_", replacement="", x=colnames(coefficient_df))
  remaining_list <- colnames(coefficient_df)

  ## Create a list of all the likely column names, depending on how deseq was called this might be
  ## numerator_vs_denominator or numerator denominator.
  ## So, I just make a list of them all.
  num_den <- unique(c(names(numerators), names(denominators)))
  ## AFAICT, the intercept is the second half of the contrasts listed.
  ## So grab that contrast name out
  if ("Intercept" %in% remaining_list) {
    ## When there is a bunch of x_vs_y, then the intercept will be set to the _y
    ## And all other columns will be subtracted from it to get their coefficients.
    vs_indexes <- grepl(pattern="_vs_", x=colnames(coefficient_df))
    if (sum(vs_indexes) > 0) {
      intercept_pairing <- strsplit(x=colnames(coefficient_df)[vs_indexes], split="_vs_")
      ## This gives a list like: [[1]][1]: 'numerator' [[1]][2]: 'denominator'
      ## So grab the second element of an arbitrary list element.
      intercept_name <- intercept_pairing[[1]][2]
      ## Now grab a list of every other column
      not_intercepts_idx <- ! grepl(pattern=intercept_name, x=unlist(intercept_pairing))
      not_intercepts <- unlist(intercept_pairing)[not_intercepts_idx]
      for (count in 1:ncol(coefficient_df)) {
        column_name <- colnames(coefficient_df)[count]
        if (count == 1) {
          colnames(coefficient_df)[1] <- intercept_name
          next
        } else if (! vs_indexes[count]) {
          ## Then this does not have _vs_ in it, so skip.
          next
        } else {
          numerator <- strsplit(x=column_name, split="_vs_")[[1]][1]
          coefficient_df[, count] <- abs(coefficient_df[, 1] - coefficient_df[, count])
          colnames(coefficient_df)[count] <- numerator
        }
      }
      ## End if the columns have _vs_ in them.
    } else {
      ## In this case, we just want the name of the condition which is not in the set
      ## of columns of the coefficient df.
      ## This is a bit more verbose that strictly it needs to be, but I hope it is clearer therefore.
      ## 1st, if a numerator/denominator is missing, then it is the intercept name.
      missing_name_idx <- ! num_den %in% colnames(coefficient_df)
      missing_name <- num_den[missing_name_idx]
      ## Those indexes found in the numerator+denominator list will be subtracted
      containing_names_idx <- columns %in% num_den
      containing_names <- columns[containing_names_idx]
      ## If the are not in the numerator+denominator list, then they must be the SVs (except the
      ## first column of course, that is the intercept.
      extra_names_idx <- ! columns %in% num_den
      extra_names <- columns[extra_names_idx]
      for (count in 1:ncol(coefficient_df)) {
        column_name <- colnames(coefficient_df)[count]
        if (count == 1) {
          colnames(coefficient_df)[1] <- missing_name
          next
        } else if (column_name %in% extra_names) {
          ## The SV columns or batch or whatever
          next
        } else {
          coefficient_df[, count] <- abs(coefficient_df[, 1] - coefficient_df[, count])
        }
      }
    } ## End both likely types of intercept columns.
  }

  ret_list <- list(
    "all_tables" = result_list,
    "batches" = batches,
    "batches_table" = batches_table,
    "coefficients" = coefficient_df,
    "conditions" = conditions,
    "conditions_table" = conditions_table,
    "contrasts_performed" = contrasts,
    "denominators" = denominators,
    "dispersion_plot" = dispersion_plot,
    "input_data" = input,
    "model" = model_data,
    "model_string" = model_string,
    "numerators" = numerators,
    "run" = deseq_run
    )
  return(ret_list)
}

deseq_try_sv <- function(data, summarized, svs, num_sv=NULL) {
  counts <- DESeq2::counts(data)
  passed <- FALSE
  if (is.null(num_sv)) {
    num_sv <- ncol(svs)
  }
  formula_string <- "as.formula(~ "
  for (count in 1:num_sv) {
    colname <- paste0("SV", count)
    summarized[[colname]] <- svs[, count]
    formula_string <- paste0(formula_string, " ", colname, " + ")
  }
  formula_string <- paste0(formula_string, "condition)")
  new_formula <- eval(parse(text=formula_string))
  new_summarized <- summarized
  DESeq2::design(new_summarized) <- new_formula
  data_model <- stats::model.matrix.default(DESeq2::design(summarized),
                                            data=as.data.frame(summarized@colData))
  model_columns <- ncol(data_model)
  model_rank <- qr(data_model)[["rank"]]
  if (model_rank < model_columns) {
    message(paste0("Including ", num_sv, " will fail because the resulting model is too low rank."))
    num_sv <- num_sv - 1
    message(paste0("Trying again with ", num_sv, " surrogates."))
    message("You should consider rerunning the pairwise comparison with the number of
surrogates explicitly stated with the option surrogates=number.")
    ret <- deseq_try_sv(data, summarized, svs, (num_sv - 1))
  } else {
    ## If we get here, then the number of surrogates should work with DESeq2.
    ## Perhaps I should re-calculate the variables with the specific number of variables.
    new_dataset <- DESeq2::DESeqDataSet(se=new_summarized, design=new_formula)
    return(new_dataset)
  }
  return(ret)
}

## Taken from the tximport manual with minor modification.
import_deseq <- function(data, column_data, model_string,
                         tximport=NULL) {
  summarized <- NULL

  ## The default.
  if (is.null(tximport)) {
    summarized <- DESeq2::DESeqDataSetFromMatrix(countData=data,
                                                 colData=column_data,
                                                 design=as.formula(model_string))
  } else if (tximport[1] == "htseq") {
    ## We are not likely to use this.
    summarized <- DESeq2::DESeqDataSetFromHTSeqCount(countData=data,
                                                     colData=column_data,
                                                     design=as.formula(model_string))
  } else {
    ## This may be insufficient, it may require the full tximport result, while this may just be
    ## that result$counts, so be aware!!

    ## First make sure that if we subsetted the data, that is maintained from
    ## the data to the tximportted data
    keepers <- rownames(data)
    tximport[["abundance"]] <- tximport[["abundance"]][keepers, ]
    tximport[["counts"]] <- tximport[["counts"]][keepers, ]
    tximport[["length"]] <- tximport[["length"]][keepers, ]
    summarized <- DESeq2::DESeqDataSetFromTximport(txi=tximport,
                                                   colData=column_data,
                                                   design=as.formula(model_string))
  }
  return(summarized)
}

#' Writes out the results of a deseq search using write_de_table()
#'
#' Looking to provide a single interface for writing tables from deseq and friends.
#'
#' Tested in test_24deseq.R
#'
#' @param data  Output from deseq_pairwise()
#' @param ...  Options for writing the xlsx file.
#' @seealso \pkg{DESeq2} \link{write_xls}
#' @examples
#' \dontrun{
#'  finished_comparison = deseq_pairwise(expressionset)
#'  data_list = write_deseq(finished_comparison)
#' }
#' @export
write_deseq <- function(data, ...) {
  result <- write_de_table(data, type="deseq", ...)
  return(result)
}

## EOF
