#' Combine portions of deseq/limma/edger table output.
#'
#' This hopefully makes it easy to compare the outputs from
#' limma/DESeq2/EdgeR on a table-by-table basis.
#'
#' @param all_pairwise_result  Output from all_pairwise().
#' @param extra_annot  Add some annotation information?
#' @param excel  Filename for the excel workbook, or null if not printed.
#' @param sig_excel  Filename for writing significant tables.
#' @param abundant_excel  Filename for writing abundance tables.
#' @param excel_title  Title for the excel sheet(s).  If it has the
#'  string 'YYY', that will be replaced by the contrast name.
#' @param keepers  List of reformatted table names to explicitly keep
#'  certain contrasts in specific orders and orientations.
#' @param excludes  List of columns and patterns to use for excluding genes.
#' @param adjp  Perhaps you do not want the adjusted p-values for plotting?
#' @param include_limma  Include limma analyses in the table?
#' @param include_deseq  Include deseq analyses in the table?
#' @param include_edger  Include edger analyses in the table?
#' @param include_basic  Include my stupid basic logFC tables?
#' @param rownames  Add rownames to the xlsx printed table?
#' @param add_plots  Add plots to the end of the sheets with expression values?
#' @param loess  Add time intensive loess estimation to plots?
#' @param plot_dim  Number of inches squared for the plot if added.
#' @param compare_plots  In an attempt to save memory when printing to excel, make it possible to
#' @param padj_type  Add a consistent p adjustment of this type.
#' @param ...   Arguments passed to significance and abundance tables.
#' @return Table combining limma/edger/deseq outputs.
#' @seealso \code{\link{all_pairwise}}
#' @examples
#' \dontrun{
#'  pretty = combine_de_tables(big_result, table='t12_vs_t0')
#'  pretty = combine_de_tables(big_result, table='t12_vs_t0', keepers=list("avsb" = c("a","b")))
#'  pretty = combine_de_tables(big_result, table='t12_vs_t0', keepers=list("avsb" = c("a","b")),
#'                             excludes=list("description" = c("sno","rRNA")))
#' }
#' @export
combine_de_tables <- function(all_pairwise_result, extra_annot=NULL,
                              excel=NULL, sig_excel=NULL, abundant_excel=NULL,
                              excel_title="Table SXXX: Combined Differential Expression of YYY",
                              keepers="all", excludes=NULL, adjp=TRUE, include_limma=TRUE,
                              include_deseq=TRUE, include_edger=TRUE, include_basic=TRUE,
                              rownames=TRUE, add_plots=TRUE, loess=FALSE,
                              plot_dim=6, compare_plots=TRUE, padj_type="fdr", ...) {
  arglist <- list(...)
  retlist <- NULL

  ## First pull out the data for each tool
  limma <- all_pairwise_result[["limma"]]
  deseq <- all_pairwise_result[["deseq"]]
  edger <- all_pairwise_result[["edger"]]
  basic <- all_pairwise_result[["basic"]]

  ## Prettily print the linear equation relating the genes for each contrast
  make_equate <- function(lm_model) {
    coefficients <- summary(lm_model)[["coefficients"]]
    int <- signif(x=coefficients["(Intercept)", 1], digits=3)
    m <- signif(x=coefficients["first", 1], digits=3)
    ret <- NULL
    if (as.numeric(int) >= 0) {
      ret <- paste0("y = ", m, "x + ", int)
    } else {
      int <- int * -1
      ret <- paste0("y = ", m, "x - ", int)
    }
    return(ret)
  }

  ## If any of the tools failed, then we cannot plot stuff with confidence.
  if (!isTRUE(include_limma) | !isTRUE(include_deseq) |
      !isTRUE(include_edger) | !isTRUE(include_basic)) {
    add_plots <- FALSE
    compare_plots <- FALSE
    message("One or more methods was excluded.  Not adding the plots.")
  }
  if (class(limma) == "try-error") {
    add_plots <- FALSE
    compare_plots <- FALSE
    message("Not adding plots, limma had an error.")
  }
  if (class(deseq) == "try-error") {
    add_plots <- FALSE
    compare_plots <- FALSE
    message("Not adding plots, deseq had an error.")
  }
  if (class(edger) == "try-error") {
    add_plots <- FALSE
    compare_plots <- FALSE
    message("Not adding plots, edger had an error.")
  }
  if (class(basic) == "try-error") {
    add_plots <- FALSE
    compare_plots <- FALSE
    message("Not adding plots, basic had an error.")
  }

  ## Take a moment to ensure that we can create the excel file without error.
  excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
  wb <- NULL
  do_excel <- TRUE
  if (is.null(excel)) {
    do_excel <- FALSE
  } else if (excel == FALSE) {
    do_excel <- FALSE
  }
  if (isTRUE(do_excel)) {
    excel_dir <- dirname(excel)
    if (!file.exists(excel_dir)) {
      dir.create(excel_dir, recursive=TRUE)
    }
    if (file.exists(excel)) {
      message(paste0("Deleting the file ", excel, " before writing the tables."))
      file.remove(excel)
    }
    wb <- openxlsx::createWorkbook(creator="hpgltools")
  }

  ## I want to print a string reminding the user what kind of model was used in the analysis.
  ## Do that here.  Noting that if 'batch' is actually from a surrogate variable, then we will
  ## not have TRUE/FALSE but instead a matrix.
  reminder_model_cond <- all_pairwise_result[["model_cond"]]
  reminder_model_batch <- all_pairwise_result[["model_batch"]]
  reminder_extra <- all_pairwise_result[["extra_contrasts"]]
  reminder_string <- NULL
  if (class(reminder_model_batch) == "matrix") {
    reminder_string <- "The contrasts were performed using surrogates from sva/ruv/etc."
  } else if (isTRUE(reminder_model_batch) & isTRUE(reminder_model_cond)) {
    reminder_string <- "The contrasts were performed with experimental condition and batch in the model."
  } else if (isTRUE(reminder_model_cond)) {
    reminder_string <- "The contrasts were performed with only experimental condition in the model."
  } else {
    reminder_string <- "The contrasts were performed in a strange way, beware!"
  }

  ## The next large set of data.frame() calls create the first sheet, containing a legend.
  message("Writing a legend of columns.")
  legend <- data.frame(rbind(
    c("", reminder_string),
    c("The first ~3-10 columns of each sheet:",
      "are annotations provided by our chosen annotation source for this experiment."),
    c("Next 6 columns", "The logFC and p-values reported by limma, edger, and deseq2.")
  ),
  stringsAsFactors=FALSE)
  deseq_legend <- data.frame(rbind(
    c("The next 7 columns", "Statistics generated by DESeq2."),
    c("deseq_logfc_rep", "The log2 fold change reported by DESeq2, again."),
    c("deseq_adjp_rep", "The adjusted-p value reported by DESeq2, again."),
    c("deseq_basemean", "Analagous to limma's ave column, the base mean of all samples according to DESeq2."),
    c("deseq_lfcse", "The standard error observed given the log2 fold change."),
    c("deseq_stat", "T-statistic reported by DESeq2 given the log2FC and observed variances."),
    c("deseq_p", "Resulting p-value."),
    c(paste0("deseq_adjp_", padj_type), paste0("p-value adjusted with ", padj_type)),
    c("deseq_q", "False-positive corrected p-value.")
  ),
  stringsAsFactors=FALSE)
  edger_legend <- data.frame(rbind(
    c("The next 6 columns", "Statistics generated by edgeR."),
    c("edger_logfc_rep", "The log2 fold change reported by edgeR, again."),
    c("edger_adjp_rep", "The adjusted-p value reported by edgeR, again."),
    c("edger_logcpm",
      "Similar to limma's ave and DESeq2's basemean, except only including the samples in the comparison."),
    c("edger_lr", "Undocumented, I am reasonably certain it is the T-statistic calculated by edgeR."),
    c("edger_p", "The observed p-value from edgeR."),
    c(paste0("edger_adjp_", padj_type), paste0("p-value adjusted with ", padj_type)),
    c("edger_q", "The observed corrected p-value from edgeR.")
  ),
  stringsAsFactors=FALSE)
  limma_legend <- data.frame(rbind(
    c("The next 7 columns", "Statistics generated by limma."),
    c("limma_logfc_rep", "The log2 fold change reported by limma, again."),
    c("limma_adjp_rep", "The adjusted-p value reported by limma, again."),
    c("limma_ave", "Average log2 expression observed by limma across all samples."),
    c("limma_t", "T-statistic reported by limma given the log2FC and variances."),
    c("limma_p", "Derived from limma_t, the p-value asking 'is this logfc significant?'"),
    c(paste0("limma_adjp_", padj_type), paste0("p-value adjusted with ", padj_type)),
    c("limma_b", "Use a Bayesian estimate to calculate log-odds significance instead of a student's test."),
    c("limma_q", "A q-value FDR adjustment of the p-value above.")
  ),
  stringsAsFactors=FALSE)
  basic_legend <- data.frame(rbind(
    c("The next 8 columns", "Statistics generated by the basic analysis written by trey."),
    c("basic_nummed", "log2 median values of the numerator for this comparison (like edgeR's basemean)."),
    c("basic_denmed", "log2 median values of the denominator for this comparison."),
    c("basic_numvar", "Variance observed in the numerator values."),
    c("basic_denvar", "Variance observed in the denominator values."),
    c("basic_logfc", "The log2 fold change observed by the basic analysis."),
    c("basic_t", "T-statistic from basic."),
    c("basic_p", "Resulting p-value."),
    c(paste0("basic_adjp_", padj_type), paste0("p-value adjusted with ", padj_type)),
    c("basic_adjp", "BH correction of the p-value.")
  ),
  stringsAsFactors=FALSE)
  summary_legend <- data.frame(rbind(
    c("The next 5 columns", "Summaries of the limma/deseq/edger results."),
    c("lfc_meta", "The mean fold-change value of limma/deseq/edger."),
    c("lfc_var", "The variance between limma/deseq/edger."),
    c("lfc_varbymed", "The ratio of the variance/median (closer to 0 means better agreement.)"),
    c("p_meta", "A meta-p-value of the mean p-values."),
    c("p_var", "Variance among the 3 p-values."),
    c("The last columns: top plot left",
      "Venn diagram of the genes with logFC > 0 and p-value <= 0.05 for limma/DESeq/Edger."),
    c("The last columns: top plot right",
      "Venn diagram of the genes with logFC < 0 and p-value <= 0.05 for limma/DESeq/Edger."),
    c("The last columns: second plot",
      "Scatter plot of the voom-adjusted/normalized counts for each coefficient."),
    c("The last columns: third plot",
      "Scatter plot of the adjusted/normalized counts for each coefficient from edgeR."),
    c("The last columns: fourth plot",
      "Scatter plot of the adjusted/normalized counts for each coefficient from DESeq."),
    c("", "If this data was adjusted with sva, then check for a sheet 'original_pvalues' at the end.")
  ),
  stringsAsFactors=FALSE)
  ## Here we including only those columns which are relevant to the analysis performed.
  if (isTRUE(include_limma)) {
    legend <- rbind(legend,
                    c("limma_logfc", "The log2 fold change reported by limma."),
                    c("limma_adjp", "The adjusted-p value reported by limma."))
  }
  if (isTRUE(include_deseq)) {
    legend <- rbind(legend,
                    c("deseq_logfc", "The log2 fold change reported by DESeq2."),
                    c("deseq_adjp", "The adjusted-p value reported by DESeq2."))
  }
  if (isTRUE(include_edger)) {
    legend <- rbind(legend,
                    c("edger_logfc", "The log2 fold change reported by edgeR."),
                    c("edger_adjp", "The adjusted-p value reported by edgeR."))
  }
  if (isTRUE(include_limma)) {
    legend <- rbind(legend, limma_legend)
  }
  if (isTRUE(include_deseq)) {
    legend <- rbind(legend, deseq_legend)
  }
  if (isTRUE(include_edger)) {
    legend <- rbind(legend, edger_legend)
  }
  if (isTRUE(include_basic)) {
    legend <- rbind(legend, basic_legend)
  }
  if (isTRUE(include_limma) & isTRUE(include_deseq) &
      isTRUE(include_edger) & isTRUE(include_basic)) {
    legend <- rbind(legend, summary_legend)
  }
  colnames(legend) <- c("column name", "column definition")
  xls_result <- write_xls(
    wb, data=legend, sheet="legend", rownames=FALSE,
    title="Columns used in the following tables.")

  ## Some folks have asked for some PCA showing the before/after surrogates.
  ## Put that on the first sheet, then.
  ## This if (isTRUE()) is a little odd, perhaps it should be removed or moved up.
  if (isTRUE(do_excel)) {
    message("Printing a pca plot before/after surrogates/batch estimation.")
    ## Add PCA before/after
    chosen_estimate <- all_pairwise_result[["batch_type"]]
    xl_result <- openxlsx::writeData(
                             wb, sheet="legend", x="PCA plot before surrogate estimation.",
                             startRow=1, startCol=10)
    try_result <- xlsx_plot_png(
      all_pairwise_result[["pre_batch"]], wb=wb, sheet="legend", start_row=2,
      width=plot_dim, height=plot_dim, start_col=10, plotname="pre_pca", savedir=excel_basename)
    xl_result <- openxlsx::writeData(
                             wb, sheet="legend", startRow=36, startCol=10,
                             x=paste0("PCA plot after surrogate estimation with: ", chosen_estimate))
    try_result <- xlsx_plot_png(
      all_pairwise_result[["post_batch"]], wb=wb, sheet="legend", start_row=37,
      width=plot_dim, height=plot_dim, start_col=10, plotname="pre_pca", savedir=excel_basename)
  }

  ## A common request is to have the annotation data added to the table.  Do that here.
  annot_df <- fData(all_pairwise_result[["input"]])
  if (!is.null(extra_annot)) {
    annot_df <- merge(annot_df, extra_annot, by="row.names", all.x=TRUE)
    rownames(annot_df) <- annot_df[["Row.names"]]
    annot_df <- annot_df[, -1, drop=FALSE]
  }

  ## Now set up to do the more difficult work, starting by blanking out some lists to hold the data.
  ## The following will either:
  ## a) Take only those elements from all_pairwise() in the keepers list
  ## b) Take all elements arbitrarily
  ## c) Take a single element.
  combo <- list()
  limma_plots <- list()
  limma_ma_plots <- list()
  limma_vol_plots <- list()
  edger_plots <- list()
  edger_ma_plots <- list()
  edger_vol_plots <- list()
  deseq_plots <- list()
  deseq_ma_plots <- list()
  deseq_vol_plots <- list()
  sheet_count <- 0
  de_summaries <- data.frame()
  name_list <- c()
  contrast_list <- c()
  ret_keepers <- list()
  ## Here, we will look for only those elements in the keepers list.
  ## In addition, if someone wanted a_vs_b, but we did b_vs_a, then this will flip the logFCs.
  if (class(keepers) == "list") {
    ## First check that your set of kepers is in the data
    all_coefficients <- unlist(strsplit(x=limma[["contrasts_performed"]], split="_vs_"))
    all_keepers <- as.character(unlist(keepers))
    found_keepers <- sum(all_keepers %in% all_coefficients)
    ret_keepers <- keepers
    ## Just make sure we have something to work with.
    if (found_keepers == 0) {
      message("The keepers has no elements in the coefficients.")
      message(paste0("Here are the keepers: ", toString(all_keepers)))
      message(paste0("Here are the coefficients: ", toString(all_coefficients)))
      stop("Fix this and try again.")
    }
    ## Then keep specific tables in specific orientations.
    a <- 0
    keeper_len <- length(names(keepers))
    contrast_list <- names(keepers)
    table_names <- list()
    for (name in names(keepers)) {
      a <- a + 1
      message(paste0("Working on ", a, "/", keeper_len, ": ",  name))
      ## Each element in the list gets one worksheet.
      sheet_count <- sheet_count + 1
      ## The numerators and denominators will be used to check that we are a_vs_b or b_vs_a
      numerator <- keepers[[name]][1]
      denominator <- keepers[[name]][2]
      same_string <- numerator
      inverse_string <- numerator
      if (!is.na(denominator)) {
        same_string <- paste0(numerator, "_vs_", denominator)
        inverse_string <- paste0(denominator, "_vs_", numerator)
      }
      ## Blank out some elements for plots and such.
      dat <- NULL
      plt <- NULL
      summary <- NULL
      limma_plt <- limma_ma_plt <- limma_vol_plt <- NULL
      edger_plt <- edger_ma_plt <- edger_vol_plt <- NULL
      deseq_plt <- deseq_ma_plt <- deseq_vol_plt <- NULL

      ## Make sure there were no errors and die if things went catastrophically wrong.
      contrasts_performed <- NULL
      if (class(limma) != "try-error") {
        contrasts_performed <- limma[["contrasts_performed"]]
      } else if (class(edger) != "try-error") {
        contrasts_performed <- edger[["contrasts_performed"]]
      } else if (class(deseq) != "try-error") {
        contrasts_performed <- deseq[["contrasts_performed"]]
      } else if (class(basic) != "try-error") {
        contrasts_performed <- basic[["contrasts_performed"]]
      } else {
        stop("None of the DE tools appear to have worked.")
      }

      ## Do the actual table search, checking for the same_string (a_vs_b) and inverse (b_vs_a)
      ## Set a flag do_inverse appropriately, this will be used later to flip some numbers.
      found <- 0
      found_table <- NULL
      do_inverse <- FALSE
      for (tab in limma[["contrasts_performed"]]) {
        if (tab == same_string) {
          do_inverse <- FALSE
          found <- found + 1
          found_table <- same_string
          message(paste0("Found table with ", same_string))
        } else if (tab == inverse_string) {
          do_inverse <- TRUE
          found <- found + 1
          found_table <- inverse_string
          message(paste0("Found inverse table with ", inverse_string))
        }
        name_list[a] <- same_string
      }
      if (found == 0) {
        message(paste0("Found neither ", same_string, " nor ", inverse_string, "."))
        break
      }

      ## If an analysis returned an error, null it out.
      if (class(limma) == "try-error") {
        limma <- NULL
      }
      if (class(deseq) == "try-error") {
        deseq <- NULL
      }
      if (class(edger) == "try-error") {
        edger <- NULL
      }
      if (class(basic) == "try-error") {
        basic <- NULL
      }
      ## Now make a single table from the limma etc results.
      if (found > 0) {
        combined <- combine_de_table(
          limma, edger, deseq, basic, found_table, inverse=do_inverse, adjp=adjp, annot_df=annot_df,
          include_deseq=include_deseq, include_edger=include_edger, include_limma=include_limma,
          include_basic=include_basic, excludes=excludes, padj_type=padj_type)
        dat <- combined[["data"]]
        summary <- combined[["summary"]]
        ## And get a bunch of variables ready to receive the coefficient, ma, and volcano plots.
        limma_plt <- edger_plt <- deseq_plt <- NULL
        limma_ma_plt <-  edger_ma_plt <- deseq_ma_plt <- NULL
        limma_vol_plt <-  edger_vol_plt <- deseq_vol_plt <- NULL

        ## The following logic will be repeated for limma, edger, deseq
        ## Check that the tool's data survived, and if so plot the coefficients, ma, and vol
        ## I think I will put extract_coefficient_scatter into extract_de_plots
        ## partially to simplify this and partially because having them separate is dumb.
        if (isTRUE(include_limma)) {
          limma_try <- try(sm(extract_coefficient_scatter(
            limma, type="limma", loess=loess, x=denominator, y=numerator)))
          if (class(limma_try) == "list") {
            limma_plt <- limma_try
          }
          ma_vol <- try(sm(extract_de_plots(
            combined, type="limma", invert=do_inverse, table=found_table)))
          if (class(ma_vol) != "try-error") {
            limma_ma_plt <- ma_vol[["ma"]]
            limma_vol_plt <- ma_vol[["volcano"]]
          }
        }
        if (isTRUE(include_edger)) {
          edger_try <- try(sm(extract_coefficient_scatter(
            edger, type="edger", loess=loess, x=denominator, y=numerator)))
          if (class(edger_try) == "list") {
            edger_plt <- edger_try
          }
          ma_vol <- try(sm(extract_de_plots(
            combined, type="edger", invert=do_inverse, table=found_table)))
          if (class(ma_vol) != "try-error") {
            edger_ma_plt <- ma_vol[["ma"]]
            edger_vol_plt <- ma_vol[["volcano"]]
          }
        }
        if (isTRUE(include_deseq)) {
          deseq_try <- try(sm(extract_coefficient_scatter(
            deseq, type="deseq", loess=loess, x=denominator, y=numerator)))
          if (class(deseq_try) == "list") {
            deseq_plt <- deseq_try
          }
          ma_vol <- try(sm(extract_de_plots(
            combined, type="deseq", invert=do_inverse, table=found_table)))
          if (class(ma_vol) != "try-error") {
            deseq_ma_plt <- ma_vol[["ma"]]
            deseq_vol_plt <- ma_vol[["volcano"]]
          }
        }

      } else {  ## End checking that we found the numerator/denominator
        warning(paste0("Did not find either ", same_string, " nor ", inverse_string, "."))
        message(paste0("Did not find either ", same_string, " nor ", inverse_string, "."))
        break
      }

      ## Now that we have made the plots and tables, drop them into the appropriate element
      ## in the top-level lists.
      combo[[name]] <- dat
      limma_plots[[name]] <- limma_plt
      limma_ma_plots[[name]] <- limma_ma_plt
      limma_vol_plots[[name]] <- limma_vol_plt
      edger_plots[[name]] <- edger_plt
      edger_ma_plots[[name]] <- edger_ma_plt
      edger_vol_plots[[name]] <- edger_vol_plt
      deseq_plots[[name]] <- deseq_plt
      deseq_ma_plots[[name]] <- deseq_ma_plt
      deseq_vol_plots[[name]] <- deseq_vol_plt
      de_summaries <- rbind(de_summaries, summary)
      table_names[[a]] <- summary[["table"]]
      names(combo) <- name_list
    }

    ## If you want all the tables in a dump
    ## The logic here is the same as above without worrying about a_vs_b, but instead just
    ## iterating through every returned table, combining them, and printing them to the excel.
  } else if (class(keepers) == "character" & keepers == "all") {
    a <- 0
    names_length <- length(names(edger[["contrast_list"]]))
    table_names <- names(edger[["contrast_list"]])
    contrast_list <- table_names
    ret_keepers <- list()
    for (tab in names(edger[["contrast_list"]])) {
      ret_keepers[[tab]] <- tab
      a <- a + 1
      name_list[a] <- tab
      message(paste0("Working on table ", a, "/", names_length, ": ", tab))
      sheet_count <- sheet_count + 1
      combined <- combine_de_table(
        limma, edger, deseq, basic, tab, annot_df=annot_df, include_basic=include_basic,
        include_deseq=include_deseq, include_edger=include_edger, include_limma=include_limma,
        excludes=excludes, padj_type=padj_type)
      de_summaries <- rbind(de_summaries, combined[["summary"]])
      combo[[tab]] <- combined[["data"]]
      splitted <- strsplit(x=tab, split="_vs_")
      xname <- splitted[[1]][1]
      yname <- splitted[[1]][2]
      limma_plots[[tab]] <-  limma_ma_plots[[tab]] <- edger_plots[[tab]] <- NULL
      edger_ma_plots[[tab]] <- deseq_plots[[tab]] <- deseq_ma_plots[[tab]] <- NULL
      if (isTRUE(include_limma)) {
        limma_try <- sm(try(extract_coefficient_scatter(
          limma, type="limma", loess=loess, x=xname, y=yname)))
        limma_ma_vol <- sm(try(extract_de_plots(combined, type="limma", table=tab)))
        if (class(limma_ma_vol) == "list") {
          limma_plots[[tab]] <- limma_try
        }
        if (class(limma_ma_vol) == "list") {
          limma_ma_plots[[tab]] <- limma_ma_vol[["ma"]]
          limma_vol_plots[[tab]] <- limma_ma_vol[["volcano"]]
        }
      }
      if (isTRUE(include_edger)) {
        edger_try <- sm(try(extract_coefficient_scatter(
          edger, type="edger", loess=loess, x=xname, y=yname)))
        edger_ma_vol <- sm(try(extract_de_plots(combined, type="edger", table=tab)))
        if (class(edger_try) == "list") {
          edger_plots[[tab]] <- edger_try
        }
        if (class(edger_ma_vol) == "list") {
          edger_ma_plots[[tab]] <- edger_ma_vol[["ma"]]
          edger_vol_plots[[tab]] <- edger_ma_vol[["volcano"]]
        }
      }
      if (isTRUE(include_deseq)) {
        deseq_try <- sm(try(extract_coefficient_scatter(
          deseq, type="deseq", loess=loess, x=xname, y=yname)))
        deseq_ma_vol <- sm(try(extract_de_plots(combined, type="deseq", table=tab)))
        if (class(deseq_try) == "list") {
          deseq_plots[[tab]] <- deseq_try
        }
        if (class(deseq_ma_vol) == "list") {
          deseq_ma_plots[[tab]] <- deseq_ma_vol[["ma"]]
          deseq_vol_plots[[tab]] <- deseq_ma_vol[["volcano"]]
        }
      }
    } ## End for list
  }

  ## Finally, the simplest case, just print a single table.  Otherwise the logic should
  ## be identical to the first case above.
  else if (class(keepers) == "character") {
    table <- keepers
    contrast_list <- table
    name_list[1] <- table
    sheet_count <- sheet_count + 1
    ret_keepers[[table]] <- table
    if (table %in% names(edger[["contrast_list"]])) {
      message(paste0("I found ", table, " in the available contrasts."))
    } else {
      message(paste0("I did not find ", table, " in the available contrasts."))
      message(paste0("The available tables are: ", names(edger[["contrast_list"]])))
      table <- names(edger[["contrast_list"]])[[1]]
      message(paste0("Choosing the first table: ", table))
    }
    combined <- combine_de_table(
      limma, edger, deseq, basic, table, annot_df=annot_df, include_basic=include_basic,
      include_deseq=include_deseq, include_edger=include_edger, include_limma=include_limma,
      excludes=excludes, padj_type=padj_type)
    combo[[table]] <- combined[["data"]]
    splitted <- strsplit(x=tab, split="_vs_")
    de_summaries <- rbind(de_summaries, combined[["summary"]])
    table_names[[a]] <- combined[["summary"]][["table"]]
    xname <- splitted[[1]][1]
    yname <- splitted[[1]][2]
    limma_plots[[name]] <- edger_plots[[name]] <- deseq_plots[[name]] <- NULL
    limma_ma_plots[[name]] <- edger_ma_plots[[name]] <- deseq_ma_plots[[name]] <- NULL
    if (isTRUE(include_limma)) {
      limma_try <- sm(try(extract_coefficient_scatter(
        limma, type="limma",
        loess=loess, x=xname, y=yname)))
      limma_ma_vol <- sm(try(extract_de_plots(combined, type="limma", table=table)))
      if (class(limma_try) == "list") {
        limma_plots[[name]] <- limma_try
      }
      if (class(limma_ma_vol) == "list") {
        limma_ma_plots[[name]] <- limma_ma_vol[["ma"]]
        limma_vol_plots[[name]] <- limma_ma_vol[["volcano"]]
      }
    }
    if (isTRUE(include_edger)) {
      edger_try <- sm(try(extract_coefficient_scatter(
        edger, type="edger",
        loess=loess, x=xname, y=yname)))
      edger_ma_vol <- sm(try(extract_de_plots(combined, type="edger", table=table)))
      if (class(edger_try) == "list") {
        edger_plots[[name]] <- edger_try
      }
      if (class(edger_ma_vol) == "list") {
        edger_ma_plots[[tab]] <- edger_ma_vol[["ma"]]
        edger_vol_plots[[tab]] <- edger_ma_vol[["volcano"]]
      }
    }
    if (isTRUE(include_deseq)) {
      deseq_try <- sm(try(extract_coefficient_scatter(
        deseq, type="deseq",
        loess=loess, x=xname, y=yname)))
      deseq_ma_vol <- sm(try(extract_de_plots(combined, type="deseq", table=table)))
      if (class(deseq_try) == "list") {
        deseq_plots[[name]] <- deseq_try
      }
      if (class(deseq_ma_vol) == "list") {
        deseq_ma_plots[[tab]] <- deseq_ma_vol[["ma"]]
        deseq_vol_plots[[tab]] <- deseq_ma_vol[["volcano"]]
      }
    }
  } else {
    stop("I don't know what to do with your specification of tables to keep.")
  } ## End different types of things to keep.

  ## At this point, we have done everything we can to combine the requested tables.
  ## So lets dump the tables to the excel file and compare how the various tools performed
  ## with some venn diagrams, and finally dump the plots from above into the sheet.
  venns <- list()
  venns_sig <- list()
  comp <- list()
  if (isTRUE(do_excel)) {
    ## Starting a new counter of sheets.
    count <- 0
    for (tab in names(combo)) {
      sheetname <- tab
      count <- count + 1
      ## I was getting some weird errors which magically disappeared when I did the following
      ## two lines.  This is obviously not how things are supposed to work.
      ddd <- combo[[count]]
      oddness = summary(ddd)
      final_excel_title <- gsub(pattern="YYY", replacement=tab, x=excel_title)
      ## Dump each table to the appropriate excel sheet
      xls_result <- write_xls(data=ddd, wb=wb, sheet=sheetname,
                              title=final_excel_title, rownames=rownames)

      ## The function write_xls has some logic in it to get around excel name limitations
      ## (30 characters), therefore set the sheetname to what was returned in case it had to
      ## change the sheet's name.
      sheetname <- xls_result[["sheet"]]
      if (isTRUE(add_plots)) {
        ## Text on row 1, plots from 2-17 (15 rows)
        plot_column <- xls_result[["end_col"]] + 2
        message(paste0("Adding venn plots for ", names(combo)[[count]], "."))
        ## Make some venn diagrams comparing deseq/limma/edger!
        venn_list <- try(de_venn(ddd, lfc=0, adjp=adjp))
        venn_sig_list <- try(de_venn(ddd, lfc=1, adjp=adjp))

        ## If they worked, add them to the excel sheets after the data,
        ## but make them smaller than other graphs.
        if (class(venn_list) != "try-error") {
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x="Venn of p-value up genes, lfc > 0.",
                                   startRow=1, startCol=plot_column)
          up_plot <- venn_list[["up_venn"]]
          try_result <- xlsx_plot_png(
            up_plot, wb=wb, sheet=sheetname, width=(plot_dim / 2), height=(plot_dim / 2),
            start_col=plot_column, plotname="upvenn", savedir=excel_basename,
            start_row=2, doWeights=FALSE)
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x="Venn of p-value down genes, lfc < 0.",
                                   startRow=1,
                                   startCol=plot_column + 4)
          down_plot <- venn_list[["down_venn"]]
          try_result <- xlsx_plot_png(
            down_plot, wb=wb, sheet=sheetname, width=plot_dim / 2, height=plot_dim / 2,
            start_col=plot_column + 4, plotname="downvenn", savedir=excel_basename,
            start_row=2, doWeights=FALSE)
          venns[[tab]] <- venn_list

          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x="Venn of p-value up genes, lfc > 1.",
                                   startRow=1, startCol=plot_column + 8)
          sig_up_plot <- venn_sig_list[["up_venn"]]
          try_result <- xlsx_plot_png(
            sig_up_plot, wb=wb, sheet=sheetname, width=(plot_dim / 2), height=(plot_dim / 2),
            start_col=plot_column + 8, plotname="upvenn", savedir=excel_basename,
            start_row=2, doWeights=FALSE)
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x="Venn of p-value down genes, lfc < -1.",
                                   startRow=1,
                                   startCol=plot_column + 12)
          down_plot <- venn_sig_list[["down_venn"]]
          try_result <- xlsx_plot_png(
            down_plot, wb=wb, sheet=sheetname, width=plot_dim / 2, height=plot_dim / 2,
            start_col=plot_column + 12, plotname="downvenn", savedir=excel_basename,
            start_row=2, doWeights=FALSE)
          venns[[tab]] <- venn_list
        }

        ## Now add the coefficients, ma, and volcanoes below the venns.
        ## Text on row 18, plots from 19-49 (30 rows)
        plt <- limma_plots[count][[1]]
        ma_plt <- limma_ma_plots[count][[1]]
        vol_plt <- limma_vol_plots[count][[1]]
        if (class(plt) != "try-error" & !is.null(plt)) {
          printme <- paste0("Limma expression coefficients for ", names(combo)[[count]], "; R^2: ",
                            signif(x=plt[["lm_rsq"]], digits=3), "; equation: ",
                            make_equate(plt[["lm_model"]]))
          message(printme)
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x=printme, startRow=18, startCol=plot_column)
          try_result <- xlsx_plot_png(
            plt[["scatter"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column, plotname="lmscatter", savedir=excel_basename, start_row=19)
          try_ma_result <- xlsx_plot_png(
            ma_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 10, plotname="lmma", savedir=excel_basename, start_row=19)
          try_vol_result <- xlsx_plot_png(
            vol_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 20, pltname="lmvol", savedir=excel_basename, start_row=19)
        }
        ## Text on row 50, plots from 51-81
        plt <- edger_plots[count][[1]] ##FIXME this is suspicious
        ma_plt <- edger_ma_plots[count][[1]]
        vol_plt <- edger_vol_plots[count][[1]]
        if (class(plt) != "try-error" & !is.null(plt)) {
          printme <- paste0("Edger expression coefficients for ", names(combo)[[count]], "; R^2: ",
                            signif(plt[["lm_rsq"]], digits=3), "; equation: ",
                            make_equate(plt[["lm_model"]]))
          message(printme)
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x=printme, startRow=50, startCol=plot_column)
          try_result <- xlsx_plot_png(
            plt[["scatter"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column, plotname="edscatter", savedir=excel_basename, start_row=51)
          try_ma_result <- xlsx_plot_png(
            ma_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 10, plotname="edma", savedir=excel_basename, start_row=51)
          try_vol_result <- xlsx_plot_png(
            vol_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 20, plotname="edvol", savedir=excel_basename, start_row=51)
        }
        ## Text on 81, plots 82-112
        plt <- deseq_plots[count][[1]]
        ma_plt <- deseq_ma_plots[count][[1]]
        vol_plt <- deseq_vol_plots[count][[1]]
        if (class(plt) != "try-error" & !is.null(plt)) {
          printme <- paste0("DESeq2 expression coefficients for ", names(combo)[[count]], "; R^2: ",
                            signif(plt[["lm_rsq"]], digits=3), "; equation: ",
                            make_equate(plt[["lm_model"]]))
          message(printme)
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, x=printme, startRow=81, startCol=plot_column)
          try_result <- xlsx_plot_png(
            plt[["scatter"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column, plotname="descatter", savedir=excel_basename, start_row=82)
          try_ma_result <- xlsx_plot_png(
            ma_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 10, plotname="dema", savedir=excel_basename, start_row=82)
          try_vol_result <- xlsx_plot_png(
            vol_plt[["plot"]], wb=wb, sheet=sheetname, width=plot_dim, height=plot_dim,
            start_col=plot_column + 20, plotname="devol", savedir=excel_basename, start_row=82)
        }
      }
    }  ## End for loop iterating over every kept table.
    count <- count + 1

    ## Now add some summary data and some plots comparing the tools.
    message("Writing summary information.")
    if (isTRUE(compare_plots)) {
      sheetname <- "pairwise_summary"
      ## Add a graph on the final sheet of how similar the result types were
      comp[["summary"]] <- all_pairwise_result[["comparison"]][["comp"]]
      comp[["plot"]] <- all_pairwise_result[["comparison"]][["heat"]]
      de_summaries <- as.data.frame(de_summaries)
      rownames(de_summaries) <- table_names
      xls_result <- write_xls(
        wb, data=de_summaries, sheet=sheetname, title="Summary of contrasts.")
      new_row <- xls_result[["end_row"]] + 2
      xls_result <- write_xls(
        wb, data=comp[["summary"]], sheet=sheetname, start_row=new_row,
        title="Pairwise correlation coefficients among differential expression tools.")

      new_row <- xls_result[["end_row"]] + 2
      message(paste0("Attempting to add the comparison plot to pairwise_summary at row: ",
                     new_row + 1, " and column: ", 1))
      if (class(comp[["plot"]]) == "recordedplot") {
        try_result <- xlsx_plot_png(
          comp[["plot"]], wb=wb, sheet=sheetname, plotname="pairwise_summary",
          savedir=excel_basename, start_row=new_row + 1, start_col=1)
      }
      logfc_comparisons <- try(compare_logfc_plots(combo), silent=TRUE)
      if (class(logfc_comparisons) != "try-error") {
        logfc_names <- names(logfc_comparisons)
        new_row <- new_row + 2
        for (c in 1:length(logfc_comparisons)) {
          new_row <- new_row + 32
          le <- logfc_comparisons[[c]][["le"]]
          ld <- logfc_comparisons[[c]][["ld"]]
          de <- logfc_comparisons[[c]][["de"]]
          tmpcol <- 1
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, startRow=new_row - 2, startCol=tmpcol,
                                   x=paste0("Comparing DE tools for the comparison of: ",
                                            logfc_names[c]))
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, startRow=new_row - 1, startCol=tmpcol,
                                   x="Log2FC(Limma vs. EdgeR)")
          try_result <- xlsx_plot_png(
            le, wb=wb, sheet="pairwise_summary", plotname="compare_le", savedir=excel_basename,
            start_row=new_row, start_col=tmpcol)
          tmpcol <- 8
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, startRow=new_row - 1, startCol=tmpcol,
                                   x="Log2FC(Limma vs. DESeq2)")
          try_result <- xlsx_plot_png(
            ld, wb=wb, sheet=sheetname, plotname="compare_ld", savedir=excel_basename,
            start_row=new_row, start_col=tmpcol)
          tmpcol <- 15
          xl_result <- openxlsx::writeData(
                                   wb, sheetname, startRow=new_row - 1, startCol=tmpcol,
                                   x="Log2FC(DESeq2 vs. EdgeR)")
          try_result <- xlsx_plot_png(
            de, wb=wb, sheet=sheetname, plotname="compare_ld", savedir=excel_basename,
            start_row=new_row, start_col=tmpcol)
        }
      } ## End checking if we could compare the logFC/P-values
    } ## End if compare_plots is TRUE

    if (!is.null(all_pairwise_result[["original_pvalues"]])) {
      message("Appending a data frame of the original pvalues before sva messed with them.")
      xls_result <- write_xls(
        wb, data=all_pairwise_result[["original_pvalues"]], sheet="original_pvalues",
        title="Original pvalues for all contrasts before sva adjustment.",
        start_row=1, rownames=rownames)
    }


    message("Performing save of the workbook.")
    save_result <- try(openxlsx::saveWorkbook(wb, excel, overwrite=TRUE))
    if (class(save_result) == "try-error") {
      message("Saving xlsx failed.")
    }
  } ## End if !is.null(excel)

  ## We have finished!  Dump the important stuff into a return list.
  ret <- NULL
  if (is.null(retlist)) {
    ret <- list(
      "data" = combo,
      "limma_plots" = limma_plots,
      "edger_plots" = edger_plots,
      "deseq_plots" = deseq_plots,
      "comp_plot" = comp,
      "venns" = venns,
      "keepers" = ret_keepers,
      "contrast_list" = contrast_list,
      "de_summary" = de_summaries)
  } else {
    ret <- retlist
  }

  ## If someone asked for the siginficant/abundant genes to be printed, just do that here.
  if (!is.null(sig_excel)) {
    message("Invoking extract_significant_genes().")
    significant <- try(extract_significant_genes(ret, excel=sig_excel, ...))
    ret[["significant"]] <- significant
  }
  if (!is.null(abundant_excel)) {
    message("Invoking extract_abundant_genes().")
    abundant <- try(extract_abundant_genes(all_pairwise_result, excel=abundant_excel, ...))
    ret[["abundant"]] <- abundant
  }
  if (!is.null(arglist[["rda"]])) {
    saved <- save(list="ret", file=arglist[["rda"]])
  }
  return(ret)
}

#' Given a limma, edger, and deseq table, combine them into one.
#'
#' This combines the outputs from the various differential expression
#' tools and formalizes some column names to make them a little more
#' consistent.
#'
#' @param li  Limma output table.
#' @param ed  Edger output table.
#' @param de  Deseq2 output table.
#' @param ba  Basic output table.
#' @param table_name  Name of the table to merge.
#' @param annot_df  Add some annotation information?
#' @param inverse  Invert the fold changes?
#' @param adjp  Use adjusted p-values?
#' @param padj_type  Add this consistent p-adjustment.
#' @param include_deseq  Include tables from deseq?
#' @param include_edger  Include tables from edger?
#' @param include_limma  Include tables from limma?
#' @param include_basic  Include the basic table?
#' @param lfc_cutoff  Preferred logfoldchange cutoff.
#' @param p_cutoff  Preferred pvalue cutoff.
#' @param excludes  Set of genes to exclude from the output.
#' @return List containing a) Dataframe containing the merged
#'  limma/edger/deseq/basic tables, and b) A summary of how many
#'  genes were observed as up/down by output table.
#' @seealso \pkg{data.table} \pkg{openxlsx}
combine_de_table <- function(li, ed, de, ba, table_name,
                             annot_df=NULL, inverse=FALSE, adjp=TRUE, padj_type="fdr",
                             include_deseq=TRUE, include_edger=TRUE, include_limma=TRUE,
                             include_basic=TRUE, lfc_cutoff=1, p_cutoff=0.05, excludes=NULL) {
  if (!padj_type %in% p.adjust.methods) {
    warning(paste0("The p adjustment ", padj_type, " is not in the set of p.adjust.methods.
Defaulting to fdr."))
    padj_type <- "fdr"
  }

  ## Check that the limma result is valid.
  if (is.null(li) | class(li) == "try-error") {
    li <- data.frame("limma_logfc" = 0, "limma_ave" = 0, "limma_t" = 0,
                     "limma_p" = 0, "limma_adjp" = 0, "limma_b" = 0)
  } else {
    li <- li[["all_tables"]][[table_name]]
  }

  ## Check that the deseq result is valid.
  if (is.null(de) | class(de) == "try-error") {
    de <- data.frame("deseq_basemean" = 0, "deseq_logfc" = 0, "deseq_lfcse" = 0,
                     "deseq_stat" = 0, "deseq_p" = 0, "deseq_adjp" = 0)
  } else {
    de <- de[["all_tables"]][[table_name]]
  }

  ## Check that the edger result is valid.
  if (is.null(ed) | class(ed) == "try-error") {
    ed <- data.frame("edger_logfc" = 0, "edger_logcpm" = 0, "edger_lr" = 0,
                     "edger_p" = 0, "edger_adjp" = 0)
  } else {
    ed <- ed[["all_tables"]][[table_name]]
  }

  ## And finally, check that my stupid basic result is valid.
  if (is.null(ba) | class(ba) == "try-error") {
    ba <- data.frame("numerator_median" = 0, "denominator_median" = 0, "numerator_var" = 0,
                     "denominator_var" = 0, "logFC" = 0, "t" = 0, "p" = 0, "adjp" = 0)
  } else {
    ba <- ba[["all_tables"]][[table_name]]
  }

  colnames(li) <- c("limma_logfc", "limma_ave", "limma_t", "limma_p",
                    "limma_adjp", "limma_b")
  li_stats <- li[, c("limma_ave", "limma_t", "limma_b", "limma_p")]
  li_lfc_adjp <- li[, c("limma_logfc", "limma_adjp")]

  colnames(de) <- c("deseq_basemean", "deseq_logfc", "deseq_lfcse",
                    "deseq_stat", "deseq_p", "deseq_adjp")
  de_stats <- de[, c("deseq_basemean", "deseq_lfcse", "deseq_stat", "deseq_p")]
  de_lfc_adjp <- de[, c("deseq_logfc", "deseq_adjp")]

  colnames(ed) <- c("edger_logfc", "edger_logcpm", "edger_lr", "edger_p", "edger_adjp")
  ed_stats <- ed[, c("edger_logcpm", "edger_lr", "edger_p")]
  ed_lfc_adjp <- ed[, c("edger_logfc", "edger_adjp")]

  ba_stats <- ba[, c("numerator_median", "denominator_median", "numerator_var",
                     "denominator_var", "logFC", "t", "p", "adjp")]
  colnames(ba_stats) <- c("basic_nummed", "basic_denmed", "basic_numvar", "basic_denvar",
                          "basic_logfc", "basic_t", "basic_p", "basic_adjp")

  li_lfcdt <- data.table::as.data.table(li_lfc_adjp)
  li_lfcdt[["rownames"]] <- rownames(li_lfc_adjp)
  de_lfcdt <- data.table::as.data.table(de_lfc_adjp)
  de_lfcdt[["rownames"]] <- rownames(de_lfc_adjp)
  ed_lfcdt <- data.table::as.data.table(ed_lfc_adjp)
  ed_lfcdt[["rownames"]] <- rownames(ed_lfc_adjp)

  li_statsdt <- data.table::as.data.table(li_stats)
  li_statsdt[["rownames"]] <- rownames(li_stats)
  de_statsdt <- data.table::as.data.table(de_stats)
  de_statsdt[["rownames"]] <- rownames(de_stats)
  ed_statsdt <- data.table::as.data.table(ed_stats)
  ed_statsdt[["rownames"]] <- rownames(ed_stats)
  ba_statsdt <- data.table::as.data.table(ba_stats)
  ba_statsdt[["rownames"]] <- rownames(ba_stats)

  comb <- combine_de_data_table(
    li_lfcdt, li_statsdt, include_limma, de_lfcdt, de_statsdt, include_deseq,
    ed_lfcdt, ed_statsdt, include_edger, ba_statsdt, include_basic)
  comb <- as.data.frame(comb)
  rownames(comb) <- comb[["rownames"]]
  keepers <- colnames(comb) != "rownames"
  comb <- comb[, keepers, drop=FALSE]
  comb[is.na(comb)] <- 0
  if (isTRUE(inverse)) {
    if (isTRUE(include_basic)) {
      comb[["basic_logfc"]] <- comb[["basic_logfc"]] * -1.0
    }
    if (isTRUE(include_limma)) {
      comb[["limma_logfc"]] <- comb[["limma_logfc"]] * -1.0
    }
    if (isTRUE(include_deseq)) {
      comb[["deseq_logfc"]] <- comb[["deseq_logfc"]] * -1.0
      comb[["deseq_stat"]] <- comb[["deseq_stat"]] * -1.0
    }
    if (isTRUE(include_edger)) {
      comb[["edger_logfc"]] <- comb[["edger_logfc"]] * -1.0
    }
  }

  ## Add one final p-adjustment to ensure a consistent and user defined value.
  if (!is.null(comb[["limma_p"]])) {
    colname <- paste0("limma_adjp_", padj_type)
    comb[[colname]] <- p.adjust(comb[["limma_p"]], method=padj_type)
    comb[[colname]] <- format(x=comb[[colname]], digits=4, scientific=TRUE)
  }
  if (!is.null(comb[["deseq_p"]])) {
    colname <- paste0("deseq_adjp_", padj_type)
    comb[[colname]] <- p.adjust(comb[["deseq_p"]], method=padj_type)
    comb[[colname]] <- format(x=comb[[colname]], digits=4, scientific=TRUE)
  }
  if (!is.null(comb[["edger_p"]])) {
    colname <- paste0("edger_adjp_", padj_type)
    comb[[colname]] <- p.adjust(comb[["edger_p"]], method=padj_type)
    comb[[colname]] <- format(x=comb[[colname]], digits=4, scientific=TRUE)
  }
  if (!is.null(comb[["basic_p"]])) {
    colname <- paste0("basic_adjp_", padj_type)
    comb[[colname]] <- p.adjust(comb[["basic_p"]], method=padj_type)
    comb[[colname]] <- format(x=comb[[colname]], digits=4, scientific=TRUE)
  }


  ## I made an odd choice in a moment to normalize.quantiles the combined fold changes
  ## This should be reevaluated
  temp_fc <- data.frame()
  if (isTRUE(include_limma) & isTRUE(include_deseq) & isTRUE(include_edger)) {
    temp_fc <- cbind(as.numeric(comb[["limma_logfc"]]),
                     as.numeric(comb[["edger_logfc"]]),
                     as.numeric(comb[["deseq_logfc"]]))
    temp_fc <- preprocessCore::normalize.quantiles(as.matrix(temp_fc))
    comb[["lfc_meta"]] <- rowMeans(temp_fc, na.rm=TRUE)
    comb[["lfc_var"]] <- genefilter::rowVars(temp_fc, na.rm=TRUE)
    comb[["lfc_varbymed"]] <- comb[["lfc_var"]] / comb[["lfc_meta"]]
    temp_p <- cbind(as.numeric(comb[["limma_p"]]),
                    as.numeric(comb[["edger_p"]]),
                    as.numeric(comb[["deseq_p"]]))
    comb[["p_meta"]] <- rowMeans(temp_p, na.rm=TRUE)
    comb[["p_var"]] <- genefilter::rowVars(temp_p, na.rm=TRUE)
    comb[["lfc_meta"]] <- signif(x=comb[["lfc_meta"]], digits=4)
    comb[["lfc_var"]] <- format(x=comb[["lfc_var"]], digits=4, scientific=TRUE)
    comb[["lfc_varbymed"]] <- format(x=comb[["lfc_varbymed"]], digits=4, scientific=TRUE)
    comb[["p_var"]] <- format(x=comb[["p_var"]], digits=4, scientific=TRUE)
    comb[["p_meta"]] <- format(x=comb[["p_meta"]], digits=4, scientific=TRUE)
  }
  if (!is.null(annot_df)) {
    ## colnames(annot_df) <- gsub("[[:digit:]]", "", colnames(annot_df))
    colnames(annot_df) <- gsub("[[:punct:]]", "", colnames(annot_df))
    comb <- merge(annot_df, comb, by="row.names", all.y=TRUE)
    rownames(comb) <- comb[["Row.names"]]
    comb <- comb[, -1, drop=FALSE]
    colnames(comb) <- make.names(tolower(colnames(comb)), unique=TRUE)
  }

  ## Exclude rows based on a list of unwanted columns/strings
  if (!is.null(excludes)) {
    for (colnum in 1:length(excludes)) {
      col <- names(excludes)[colnum]
      for (exclude_num in 1:length(excludes[[col]])) {
        exclude <- excludes[[col]][exclude_num]
        remove_column <- comb[[col]]
        remove_idx <- grep(pattern=exclude, x=remove_column, perl=TRUE, invert=TRUE)
        removed_num <- sum(as.numeric(remove_idx))
        message(paste0("Removed ", removed_num, " genes using ",
                       exclude, " as a string against column ", remove_column, "."))
        comb <- comb[remove_idx, ]
      }  ## End iterating through every string to exclude
    }  ## End iterating through every element of the exclude list
  }

  up_fc <- lfc_cutoff
  down_fc <- -1.0 * lfc_cutoff
  summary_table_name <- table_name
  if (isTRUE(inverse)) {
    summary_table_name <- paste0(summary_table_name, "-inverted")
  }
  limma_p_column <- "limma_adjp"
  deseq_p_column <- "deseq_adjp"
  edger_p_column <- "edger_adjp"
  if (!isTRUE(adjp)) {
    limma_p_column <- "limma_p"
    deseq_p_column <- "deseq_p"
    edger_p_column <- "edger_p"
  }
  summary_lst <- list(
    "table" = summary_table_name,
    "total" = nrow(comb),
    "limma_up" = sum(comb[["limma_logfc"]] >= up_fc),
    "limma_sigup" = sum(
      comb[["limma_logfc"]] >= up_fc & as.numeric(comb[[limma_p_column]]) <= p_cutoff),
    "deseq_up" = sum(comb[["deseq_logfc"]] >= up_fc),
    "deseq_sigup" = sum(
      comb[["deseq_logfc"]] >= up_fc & as.numeric(comb[[deseq_p_column]]) <= p_cutoff),
    "edger_up" = sum(comb[["edger_logfc"]] >= up_fc),
    "edger_sigup" = sum(
      comb[["edger_logfc"]] >= up_fc & as.numeric(comb[[edger_p_column]]) <= p_cutoff),
    "basic_up" = sum(comb[["basic_logfc"]] >= up_fc),
    "basic_sigup" = sum(
      comb[["basic_logfc"]] >= up_fc & as.numeric(comb[["basic_p"]]) <= p_cutoff),
    "limma_down" = sum(comb[["limma_logfc"]] <= down_fc),
    "limma_sigdown" = sum(
      comb[["limma_logfc"]] <= down_fc & as.numeric(comb[[limma_p_column]]) <= p_cutoff),
    "deseq_down" = sum(comb[["deseq_logfc"]] <= down_fc),
    "deseq_sigdown" = sum(
      comb[["deseq_logfc"]] <= down_fc & as.numeric(comb[[deseq_p_column]]) <= p_cutoff),
    "edger_down" = sum(comb[["edger_logfc"]] <= down_fc),
    "edger_sigdown" = sum(
      comb[["edger_logfc"]] <= down_fc & as.numeric(comb[[edger_p_column]]) <= p_cutoff),
    "basic_down" = sum(comb[["basic_logfc"]] <= down_fc),
    "basic_sigdown" = sum(
      comb[["basic_logfc"]] <= down_fc & as.numeric(comb[["basic_p"]]) <= p_cutoff),
    "meta_up" = sum(comb[["fc_meta"]] >= up_fc),
    "meta_sigup" = sum(
      comb[["lfc_meta"]] >= up_fc & as.numeric(comb[["p_meta"]]) <= p_cutoff),
    "meta_down" = sum(comb[["lfc_meta"]] <= down_fc),
    "meta_sigdown" = sum(
      comb[["lfc_meta"]] <= down_fc & as.numeric(comb[["p_meta"]]) <= p_cutoff)
  )

  ret <- list(
    "data" = comb,
    "summary" = summary_lst)
  return(ret)
}

combine_de_data_table <- function(lilfcdt, listatsdt, include_limma,
                                  delfcdt, destatsdt, include_deseq,
                                  edlfcdt, edstatsdt, include_edger,
                                  badt, include_basic) {
  comb <- data.table::data.table()
  if (!isTRUE(include_basic) & !isTRUE(include_deseq) &
      !isTRUE(include_edger) & !isTRUE(include_limma)) {
    stop("Nothing is included!")
  } else if (isTRUE(include_basic) & !isTRUE(include_deseq) &
             !isTRUE(include_edger) & !isTRUE(include_limma)) {
    ## The case where someone only wants the basic analysis: Why!?
    comb <- badt
  } else if (!isTRUE(include_basic) & isTRUE(include_deseq) &
             !isTRUE(include_edger) & !isTRUE(include_limma)) {
    ## Perhaps one only wants deseq
    comb <- merge(delfcdt, destatsdt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_basic) & !isTRUE(include_deseq) &
             isTRUE(include_edger) & !isTRUE(include_limma)) {
    ## Or perhaps only edger
    comb <- merge(edlfcdt, edstatsdt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_basic) & !isTRUE(include_deseq) &
             !isTRUE(include_edger) & isTRUE(include_limma)) {
    ## The most likely for Najib, only limma.
    comb <- merge(lilfcdt, listatsdt, by="rownames", all.x=TRUE)
  } else if (isTRUE(include_basic) & isTRUE(include_deseq) &
             !isTRUE(include_edger) & isTRUE(include_limma)) {
    ## Include basic and deseq
    comb <- merge(delfcdt, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else if (isTRUE(include_basic) & !isTRUE(include_deseq) &
             isTRUE(include_edger) & !isTRUE(include_limma)) {
    ## basic and edgeR
    comb <- merge(edlfcdt, edstatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else if (isTRUE(include_basic) & !isTRUE(include_deseq) &
             !isTRUE(include_edger) & isTRUE(include_limma)) {
    ## basic and limma
    comb <- merge(lilfcdt, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_basic) & isTRUE(include_deseq) &
             isTRUE(include_edger) & !isTRUE(include_limma)) {
    ## deseq and edger
    comb <- merge(delfcdt, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_basic) & isTRUE(include_deseq) &
             !isTRUE(include_edger) & isTRUE(include_limma)) {
    ## deseq and limma
    comb <- merge(lilfcdt, delfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_basic) & !isTRUE(include_deseq) &
             isTRUE(include_edger) & isTRUE(include_limma)) {
    ## edger and limma
    comb <- merge(lilfcdt, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
    ## Now we get into the sets of threes
  } else if (!isTRUE(include_basic)) {
    comb <- merge(lilfcdt, delfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_deseq)) {
    comb <- merge(lilfcdt, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_edger)) {
    comb <- merge(lilfcdt, delfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else if (!isTRUE(include_limma)) {
    comb <- merge(delfcdt, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  } else {
    ## Include everyone
    comb <- merge(lilfcdt, delfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edlfcdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, listatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, destatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, edstatsdt, by="rownames", all.x=TRUE)
    comb <- merge(comb, badt, by="rownames", all.x=TRUE)
  }
  return(comb)
}

#' Extract the sets of genes which are significantly more abundant than the rest.
#'
#' Given the output of something_pairwise(), pull out the genes for each contrast
#' which are the most/least abundant.  This is in contrast to extract_significant_genes().
#' That function seeks out the most changed, statistically significant genes.
#'
#' @param pairwise  Output from _pairwise()().
#' @param according_to  What tool(s) define 'most?'  One may use deseq, edger, limma, basic, all.
#' @param n  How many genes to pull?
#' @param z  Instead take the distribution of abundances and pull those past the given z score.
#' @param unique  One might want the subset of unique genes in the top-n which are unique in the set
#'  of available conditions.  This will attempt to provide that.
#' @param least  Instead of the most abundant, do the least.
#' @param excel  Excel file to write.
#' @param ...  Arguments passed into arglist.
#' @return  The set of most/least abundant genes by contrast/tool.
#' @seealso \pkg{openxlsx}
#' @export
extract_abundant_genes <- function(pairwise, according_to="all", n=100, z=NULL, unique=FALSE,
                                   least=FALSE, excel="excel/abundant_genes.xlsx", ...) {
  arglist <- list(...)
  excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
  abundant_lists <- list()
  final_list <- list()

  data <- NULL
  if (according_to[[1]] == "all") {
    according_to <- c("limma", "deseq", "edger", "basic")
  }

  for (type in according_to) {
    datum <- pairwise[[type]]
    abundant_lists[[type]] <- get_abundant_genes(datum, type=type, n=n, z=z,
                                                 unique=unique, least=least)
  }

  wb <- NULL
  excel_basename <- NULL
  if (class(excel) == "character") {
    message("Writing a legend of columns.")
    excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
    wb <- openxlsx::createWorkbook(creator="hpgltools")
    legend <- data.frame(rbind(
      c("The first ~3-10 columns of each sheet:",
        "are annotations provided by our chosen annotation source for this experiment."),
      c("Next column", "The most/least abundant genes.")),
      stringsAsFactors=FALSE)
    colnames(legend) <- c("column name", "column definition")
    xls_result <- write_xls(wb, data=legend, sheet="legend", rownames=FALSE,
                            title="Columns used in the following tables.")
  }

  ## Now make the excel sheet for each method/coefficient
  for (according in names(abundant_lists)) {
    for (coef in names(abundant_lists[[according]])) {
      sheetname <- paste0(according, "_", coef)
      annotations <- fData(pairwise[["input"]])
      abundances <- abundant_lists[[according]][[coef]]
      kept_annotations <- names(abundant_lists[[according]][[coef]])
      kept_idx <- rownames(annotations) %in% kept_annotations
      kept_annotations <- annotations[kept_idx, ]
      kept_annotations <- cbind(kept_annotations, abundances)
      final_list[[according]][[coef]] <- kept_annotations
      title <- paste0("Table SXXX: Abundant genes in ", coef, " according to ", according, ".")
      xls_result <- write_xls(data=kept_annotations, wb=wb, sheet=sheetname, title=title)
    }
  }

  excel_ret <- try(openxlsx::saveWorkbook(wb, excel, overwrite=TRUE))
  ret <- list(
    "with_annotations" = final_list,
    "abundances" = abundant_lists)
  return(ret)
}

#' Alias for extract_significant_genes because I am dumb.
#'
#' @param ... The parameters for extract_significant_genes()
#' @return  It should return a reminder for me to remember my function names or change them to
#'     something not stupid.
#' @export
extract_siggenes <- function(...) {
  extract_significant_genes(...)
}
#' Extract the sets of genes which are significantly up/down regulated
#' from the combined tables.
#'
#' Given the output from combine_de_tables(), extract the genes in
#' which we have the greatest likely interest, either because they
#' have the largest fold changes, lowest p-values, fall outside a
#' z-score, or are at the top/bottom of the ranked list.
#'
#' @param combined  Output from combine_de_tables().
#' @param according_to  What tool(s) decide 'significant?'  One may use
#'  the deseq, edger, limma, basic, meta, or all.
#' @param lfc  Log fold change to define 'significant'.
#' @param p  (Adjusted)p-value to define 'significant'.
#' @param sig_bar  Add bar plots describing various cutoffs of 'significant'?
#' @param z  Z-score to define 'significant'.
#' @param n  Take the top/bottom-n genes.
#' @param ma  Add ma plots to the sheets of 'up' genes?
#' @param p_type  use an adjusted p-value?
#' @param invert_barplots  Invert the significance barplots as per Najib's request?
#' @param excel  Write the results to this excel file, or NULL.
#' @param siglfc_cutoffs  Set of cutoffs used to define levels of 'significant.'
#' @param ...  Arguments passed into arglist.
#' @return The set of up-genes, down-genes, and numbers therein.
#' @seealso \code{\link{combine_de_tables}}
#' @export
extract_significant_genes <- function(combined, according_to="all", lfc=1.0, p=0.05, sig_bar=TRUE,
                                      z=NULL, n=NULL, ma=TRUE, p_type="adj", invert_barplots=FALSE,
                                      excel="excel/significant_genes.xlsx",
                                      siglfc_cutoffs=c(0, 1, 2), ...) {
  arglist <- list(...)
  excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
  num_tables <- 0
  table_names <- NULL
  all_tables <- NULL
  table_mappings <- NULL
  if (class(combined) == "data.frame") {
    ## Then this is just a data frame.
    all_tables[["all"]] <- combined
    table_names <- "all"
    num_tables <- 1
    table_mappings <- table_names
  } else if (is.null(combined[["data"]])) {
    ## Then this is the result of combine_de_tables()
    num_tables <- length(names(combined[["data"]]))
    table_names <- names(combined[["data"]])
    all_tables <- combined[["data"]]
    table_mappings <- table_names
  } else if (!is.null(combined[["contrast_list"]])) {
    ## Then this is the result of all_pairwise()
    num_tables <- length(combined[["contrast_list"]])
    ## Extract the names of the tables which filled combined
    table_names <- names(combined[["data"]])
    ## Pull the table list
    all_tables <- combined[["data"]]
    ## Get the mappings of contrast_name -> table_name
    table_mappings <- combined[["keepers"]]
  } else {
    ## Then this is just a data frame.
    all_tables[["all"]] <- combined
    table_names <- "all"
    num_tables <- 1
    table_mappings <- table_names
  }

  trimmed_up <- list()
  trimmed_down <- list()
  up_titles <- list()
  down_titles <- list()
  sig_list <- list()
  title_append <- ""
  if (!is.null(lfc)) {
    title_append <- paste0(title_append, " |log2fc|>=", lfc)
  }
  if (!is.null(p)) {
    title_append <- paste0(title_append, " p<=", p)
  }
  if (!is.null(z)) {
    title_append <- paste0(title_append, " |z|>=", z)
  }
  if (!is.null(n)) {
    title_append <- paste0(title_append, " top|bottom n=", n)
  }

  table_count <- 0
  if (according_to[[1]] == "all") {
    according_to <- c("limma", "edger", "deseq", "basic")
  }

  wb <- NULL
  excel_basename <- NULL
  if (class(excel) == "character") {
    message("Writing a legend of columns.")
    excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
    wb <- openxlsx::createWorkbook(creator="hpgltools")
    legend <- data.frame(rbind(
      c("The first ~3-10 columns of each sheet:",
        "are annotations provided by our chosen annotation source for this experiment."),
      c("Next 6 columns", "The logFC and p-values reported by limma, edger, and deseq2."),
      c("limma_logfc", "The log2 fold change reported by limma."),
      c("deseq_logfc", "The log2 fold change reported by DESeq2."),
      c("edger_logfc", "The log2 fold change reported by edgeR."),
      c("limma_adjp", "The adjusted-p value reported by limma."),
      c("deseq_adjp", "The adjusted-p value reported by DESeq2."),
      c("edger_adjp", "The adjusted-p value reported by edgeR."),
      c("The next 5 columns", "Statistics generated by limma."),
      c("limma_ave", "Average log2 expression observed by limma across all samples."),
      c("limma_t", "T-statistic reported by limma given the log2FC and variances."),
      c("limma_p", "Derived from limma_t, the p-value asking 'is this logfc significant?'"),
      c("limma_b", "Use a Bayesian estimate to calculate log-odds significance instead of a student's test."),
      c("limma_q", "A q-value FDR adjustment of the p-value above."),
      c("The next 5 columns", "Statistics generated by DESeq2."),
      c("deseq_basemean", "Analagous to limma's ave column, the base mean of all samples according to DESeq2."),
      c("deseq_lfcse", "The standard error observed given the log2 fold change."),
      c("deseq_stat", "T-statistic reported by DESeq2 given the log2FC and observed variances."),
      c("deseq_p", "Resulting p-value."),
      c("deseq_q", "False-positive corrected p-value."),
      c("The next 4 columns", "Statistics generated by edgeR."),
      c("edger_logcpm",
        "Similar to limma's ave and DESeq2's basemean, only including the samples in the comparison."),
      c("edger_lr", "Undocumented, I am reasonably certain it is the T-statistic calculated by edgeR."),
      c("edger_p", "The observed p-value from edgeR."),
      c("edger_q", "The observed corrected p-value from edgeR."),
      c("The next 8 columns", "Statistics generated by the basic analysis written by trey."),
      c("basic_nummed", "log2 median values of the numerator for this comparison (like edgeR's basemean)."),
      c("basic_denmed", "log2 median values of the denominator for this comparison."),
      c("basic_numvar", "Variance observed in the numerator values."),
      c("basic_denvar", "Variance observed in the denominator values."),
      c("basic_logfc", "The log2 fold change observed by the basic analysis."),
      c("basic_t", "T-statistic from basic."),
      c("basic_p", "Resulting p-value."),
      c("basic_adjp", "BH correction of the p-value."),
      c("The next 5 columns", "Summaries of the limma/deseq/edger results."),
      c("lfc_meta", "The mean fold-change value of limma/deseq/edger."),
      c("lfc_var", "The variance between limma/deseq/edger."),
      c("lfc_varbymed", "The ratio of the variance/median (closer to 0 means better agreement.)"),
      c("p_meta", "A meta-p-value of the mean p-values."),
      c("p_var", "Variance among the 3 p-values."),
      c("The last columns: top plot left",
        "Venn diagram of the genes with logFC > 0 and p-value <= 0.05 for limma/DESeq/Edger."),
      c("The last columns: top plot right",
        "Venn diagram of the genes with logFC < 0 and p-value <= 0.05 for limma/DESeq/Edger."),
      c("The last columns: second plot",
        "Scatter plot of the voom-adjusted/normalized counts for each coefficient."),
      c("The last columns: third plot",
        "Scatter plot of the adjusted/normalized counts for each coefficient from edgeR."),
      c("The last columns: fourth plot",
        "Scatter plot of the adjusted/normalized counts for each coefficient from DESeq."),
      c("", "If this data was adjusted with sva, then check for a sheet 'original_pvalues' at the end.")
    ),
    stringsAsFactors=FALSE)

    colnames(legend) <- c("column name", "column definition")
    xls_result <- write_xls(wb, data=legend, sheet="legend", rownames=FALSE,
                            title="Columns used in the following tables.")
  }

  ret <- list()
  summary_count <- 0
  sheet_count <- 0
  for (according in according_to) {
    summary_count <- summary_count + 1
    ret[[according]] <- list()
    ma_plots <- list()
    change_counts_up <- list()
    change_counts_down <- list()
    for (table_name in table_names) {
      ## Extract the MA data if requested.
      if (isTRUE(ma)) {
        single_ma <- NULL
        if (according == "limma") {
          single_ma <- extract_de_plots(
            combined, type="limma", table=table_name, lfc=lfc,  pval_cutoff=p)
          single_ma <- single_ma[["ma"]][["plot"]]
        } else if (according == "deseq") {
          single_ma <- extract_de_plots(
            combined, type="deseq", table=table_name, lfc=lfc, pval_cutoff=p)
          single_ma <- single_ma[["ma"]][["plot"]]
        } else if (according == "edger") {
          single_ma <- extract_de_plots(
            combined, type="edger", table=table_name, lfc=lfc, pval_cutoff=p)
          single_ma <- single_ma[["ma"]][["plot"]]
        } else if (according == "basic") {
          single_ma <- extract_de_plots(
            combined, type="basic", table=table_name, lfc=lfc, pval_cutoff=p)
          single_ma <- single_ma[["ma"]][["plot"]]
        } else {
          message("Do not know this according type.")
        }
        ma_plots[[table_name]] <- single_ma
      }

      message(paste0("Writing excel data sheet ", table_count, "/", num_tables, ": ", table_name))
      table_count <- table_count + 1
      table <- all_tables[[table_name]]
      fc_column <- paste0(according, "_logfc")
      p_column <- paste0(according, "_adjp")
      if (p_type != "adj") {
        p_column <- paste0(according, "_p")
      }

      trimming <- get_sig_genes(
        table, lfc=lfc, p=p, z=z, n=n, column=fc_column, p_column=p_column)
      trimmed_up[[table_name]] <- trimming[["up_genes"]]
      change_counts_up[[table_name]] <- nrow(trimmed_up[[table_name]])
      trimmed_down[[table_name]] <- trimming[["down_genes"]]
      change_counts_down[[table_name]] <- nrow(trimmed_down[[table_name]])
      up_title <- paste0("Table SXXX: Genes deemed significantly up in ",
                         table_name, " with", title_append, " according to ", according)
      up_titles[[table_name]] <- up_title
      down_title <- paste0("Table SXXX: Genes deemed significantly down in ",
                           table_name, " with", title_append, " according to ", according)
      down_titles[[table_name]] <- down_title
    } ## End extracting significant genes for loop

    change_counts <- as.data.frame(cbind(change_counts_up, change_counts_down))
    ## Found on http://stackoverflow.com/questions/2851015/convert-data-frame-columns-from-factors-to-characters
    ## A quick and somewhat dirty way to coerce columns to a given type from lists etc.
    ## I am not sure I am a fan, but it certainly is concise.
    change_counts[] <- lapply(change_counts, as.numeric)
    summary_title <- paste0("Counting the number of changed genes by contrast according to ",
                            according, " with ", title_append)
    ## xls_result <- write_xls(data=change_counts, sheet="number_changed", file=sig_table,
    ##                         title=summary_title,
    ##                         overwrite_file=TRUE, newsheet=TRUE)

    ret[[according]] <- list(
      "ups" = trimmed_up,
      "downs" = trimmed_down,
      "counts" = change_counts,
      "up_titles" = up_titles,
      "down_titles" = down_titles,
      "counts_title" = summary_title,
      "ma_plots" = ma_plots)
    do_excel=TRUE
    if (is.null(excel)) {
      do_excel <- FALSE
      message("Not printing excel sheets for the significant genes.")
    } else if (excel == FALSE) {
      do_excel <- FALSE
      message("Still not printing excel sheets for the significant genes.")
    } else {
      message(paste0("Printing significant genes to the file: ", excel))
      xlsx_ret <- print_ups_downs(ret[[according]], wb=wb, excel=excel, according=according,
                                  summary_count=summary_count, ma=ma)
      ## This is in case writing the sheet resulted in it being shortened.
      ## wb <- xlsx_ret[["workbook"]]
    } ## End of an if whether to print the data to excel
  } ## End list of according_to's

  sig_bar_plots <- NULL
  if (isTRUE(do_excel) & isTRUE(sig_bar)) {
    ## This needs to be changed to get_sig_genes()
    sig_bar_plots <- significant_barplots(
      combined, lfc_cutoffs=siglfc_cutoffs, invert=invert_barplots, p=p, z=z, p_type=p_type,
      according_to=according_to)
    plot_row <- 1
    plot_col <- 1
    message(paste0("Adding significance bar plots."))

    num_tables <- length(according_to)
    plot_row <- plot_row + ((nrow(change_counts) + 1) * num_tables) + 4
    ## The +4 is for the number of tools.
    ## I know it is silly to set the row in this very explicit fashion, but I want to make clear
    ## the fact that the table has a title, a set of headings, a length corresponding to the
    ## number of contrasts,  and then the new stuff should be added.

    ## Now add in a table summarizing the numbers in the plot.
    ## The information required to make this table is in sig_bar_plots[["ups"]][["limma"]]
    ## and sig_bar_plots[["downs"]][["limma"]]
    summarize_ups_downs <- function(ups, downs) {
      ## The ups and downs tables have 1 row for each contrast, 3 columns of numbers named
      ## 'a_up_inner', 'b_up_middle', 'c_up_outer'.
      ups <- ups[, -1]
      downs <- downs[, -1]
      ups[[1]] <- as.numeric(ups[[1]])
      ups[[2]] <- as.numeric(ups[[2]])
      ups[[3]] <- as.numeric(ups[[3]])
      ups[["up_sum"]] <- rowSums(ups)
      downs[[1]] <- as.numeric(downs[[1]])
      downs[[2]] <- as.numeric(downs[[2]])
      downs[[3]] <- as.numeric(downs[[3]])
      downs[["down_sum"]] <- rowSums(downs)
      summary_table <- as.data.frame(cbind(ups, downs))
      summary_table <- summary_table[, c(1, 2, 3, 5, 6, 7, 4, 8)]
      colnames(summary_table) <- c("up_from_0_to_2", "up_from_2_to_4", "up_gt_4",
                                   "down_from_0_to_2", "down_from_2_to_4", "down_gt_4",
                                   "sum_up", "sum_down")
      summary_table[["up_gt_2"]] <- summary_table[["up_from_2_to_4"]] + summary_table[["up_gt_4"]]
      summary_table[["down_gt_2"]] <- summary_table[["down_from_2_to_4"]] + summary_table[["down_gt_4"]]
      summary_table_idx <- rev(rownames(summary_table))
      summary_table <- summary_table[summary_table_idx, ]
      return(summary_table)
    }

    ## I messed up something here.  The plots and tables
    ## at this point should start 5(blank spaces and titles) + 4(table headings) + 4 * the number of contrasts.
    if ("limma" %in% according_to) {
      xl_result <- openxlsx::writeData(
                               wb, "number_changed", x="Significant limma genes.",
                               startRow=plot_row, startCol=plot_col)
      plot_row <- plot_row + 1
      try_result <- xlsx_plot_png(
        sig_bar_plots[["limma"]], wb=wb, sheet="number_changed", plotname="sigbar_limma",
        savedir=excel_basename, width=9, height=6, start_row=plot_row, start_col=plot_col)
      summary_row <- plot_row
      summary_col <- plot_col + 11
      limma_summary <- summarize_ups_downs(sig_bar_plots[["ups"]][["limma"]], sig_bar_plots[["downs"]][["limma"]])
      limma_xls_summary <- write_xls(
        data=limma_summary, wb=wb, sheet="number_changed", rownames=TRUE,
        start_row=summary_row, start_col=summary_col)
      plot_row <- plot_row + 30
    }

    if ("deseq" %in% according_to) {
      xl_result <- openxlsx::writeData(
                               wb, "number_changed", startRow=plot_row, startCol=plot_col,
                               x="Significant deseq genes.")
      plot_row <- plot_row + 1
      try_result <- xlsx_plot_png(
        sig_bar_plots[["deseq"]], wb=wb, sheet="number_changed", plotname="sigbar_deseq",
        savedir=excel_basename, width=9, height=6, start_row=plot_row, start_col=plot_col)
      summary_row <- plot_row
      summary_col <- plot_col + 11
      deseq_summary <- summarize_ups_downs(
        sig_bar_plots[["ups"]][["deseq"]], sig_bar_plots[["downs"]][["deseq"]])
      deseq_xls_summary <- write_xls(
        data=deseq_summary, wb=wb, sheet="number_changed", rownames=TRUE,
        start_row=summary_row, start_col=summary_col)
      plot_row <- plot_row + 30
    }

    if ("edger" %in% according_to) {
      xl_result <- openxlsx::writeData(
                               wb, "number_changed", startRow=plot_row, startCol=plot_col,
                               x="Significant edger genes.")
      plot_row <- plot_row + 1
      try_result <- xlsx_plot_png(
        sig_bar_plots[["edger"]], wb=wb, sheet="number_changed", plotname="sibar_edger",
        savedir=excel_basename, width=9, height=6, start_row=plot_row, start_col=plot_col)
      summary_row <- plot_row
      summary_col <- plot_col + 11
      edger_summary <- summarize_ups_downs(
        sig_bar_plots[["ups"]][["edger"]], sig_bar_plots[["downs"]][["edger"]])
      edger_xls_summary <- write_xls(
        data=edger_summary, wb=wb, sheet="number_changed", rownames=TRUE,
        start_row=summary_row, start_col=summary_col)
    }

  } ## End if we want significance bar plots
  ret[["sig_bar_plots"]] <- sig_bar_plots

  if (isTRUE(do_excel)) {
    excel_ret <- try(openxlsx::saveWorkbook(wb, excel, overwrite=TRUE))
  }

  return(ret)
}

#' Reprint the output from extract_significant_genes().
#'
#' I found myself needing to reprint these excel sheets because I
#' added some new information. This shortcuts that process for me.
#'
#' @param upsdowns  Output from extract_significant_genes().
#' @param wb  Workbook object to use for writing, or start a new one.
#' @param excel  Filename for writing the data.
#' @param according  Use limma, deseq, or edger for defining 'significant'.
#' @param summary_count  For spacing sequential tables one after another.
#' @param ma  Include ma plots?
#' @return Return from write_xls.
#' @seealso \code{\link{combine_de_tables}}
#' @export
print_ups_downs <- function(upsdowns, wb=NULL, excel="excel/significant_genes.xlsx",
                            according="limma", summary_count=1, ma=FALSE) {
  xls_result <- NULL
  if (is.null(wb)) {
    wb <- openxlsx::createWorkbook(creator="hpgltools")
  }
  excel_basename <- gsub(pattern="\\.xlsx", replacement="", x=excel)
  ups <- upsdowns[["ups"]]
  downs <- upsdowns[["downs"]]
  up_titles <- upsdowns[["up_titles"]]
  down_titles <- upsdowns[["down_titles"]]
  summary <- as.data.frame(upsdowns[["counts"]])
  summary_title <- upsdowns[["counts_title"]]
  ma_plots <- upsdowns[["ma_plots"]]
  table_count <- 0
  summary_count <- summary_count - 1
  num_tables <- length(names(ups))
  summary_start <- ((num_tables + 2) * summary_count) + 1
  xls_summary_result <- write_xls(wb=wb, data=summary, start_col=1, start_row=summary_start,
                                  sheet="number_changed", title=summary_title)
  for (base_name in names(ups)) {
    table_count <- table_count + 1
    up_name <- paste0("up_", table_count, according, "_", base_name)
    down_name <- paste0("down_", table_count, according, "_", base_name)
    up_table <- ups[[table_count]]
    down_table <- downs[[table_count]]
    up_title <- up_titles[[table_count]]
    down_title <- down_titles[[table_count]]
    message(paste0(table_count, "/", num_tables, ": Writing excel data sheet ", up_name))
    xls_result <- write_xls(data=up_table, wb=wb, sheet=up_name, title=up_title)
    ## This is in case the sheet name is past the 30 character limit.
    sheet_name <- xls_result[["sheet"]]
    if (isTRUE(ma)) {
      ma_row <- 1
      ma_col <- xls_result[["end_col"]] + 1
      if (!is.null(ma_plots[[base_name]])) {
        try_result <- xlsx_plot_png(ma_plots[[base_name]], wb=wb, sheet=sheet_name,
                                    plotname="ma", savedir=excel_basename,
                                    start_row=ma_row, start_col=ma_col)
      }
    }
    message(paste0(table_count, "/", num_tables, ": Writing excel data sheet ", down_name))
    xls_result <- write_xls(data=down_table, wb=wb, sheet=down_name, title=down_title)
  } ## End for each name in ups
  return(xls_result)
}

#' Find the sets of intersecting significant genes
#'
#' Use extract_significant_genes() to find the points of agreement between limma/deseq/edger.
#'
#' @param combined  A result from combine_de_tables().
#' @param lfc  Define significant via fold-change.
#' @param p  Or p-value.
#' @param z  Or z-score.
#' @param p_type  Use normal or adjusted p-values.
#' @param excel  An optional excel workbook to which to write.
#' @export
intersect_significant <- function(combined, lfc=1.0, p=0.05,
                                  z=NULL, p_type="adj",
                                  excel="excel/intersect_significant.xlsx") {
  sig_genes <- sm(extract_significant_genes(combined, lfc=lfc, p=p,
                                            z=z, p_type=p_type, excel=NULL))

  up_result_list <- list()
  down_result_list <- list()
  for (table in names(sig_genes[["limma"]][["ups"]])) {
    tabname <- paste0("up_", table)
    up_result_list[[tabname]] <- make_intersect(sig_genes[["limma"]][["ups"]][[table]],
                                                sig_genes[["deseq"]][["ups"]][[table]],
                                                sig_genes[["edger"]][["ups"]][[table]])
    tabname <- paste0("down_", table)
    down_result_list[[tabname]] <- make_intersect(sig_genes[["limma"]][["downs"]][[table]],
                                                  sig_genes[["deseq"]][["downs"]][[table]],
                                                  sig_genes[["edger"]][["downs"]][[table]])
  }

  xls_result <- NULL
  if (!is.null(excel)) {
    wb <- openxlsx::createWorkbook(creator="hpgltools")
    testdir <- dirname(excel)
    if (!file.exists(testdir)) {
      dir.create(testdir, recursive=TRUE)
    }
    for (tab in names(up_result_list)) {  ## Get the tables back
      tabname <- paste0("up_", tab)
      row_num <- 1
      xl_result <- write_xls(
        data=up_result_list[[tab]][["l"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by limma."))
      row_num <- row_num + nrow(up_result_list[[tab]][["l"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["d"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by DESeq2."))
      row_num <- row_num + nrow(up_result_list[[tab]][["d"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["e"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by EdgeR."))
      row_num <- row_num + nrow(up_result_list[[tab]][["e"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["ld"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma and DESeq2."))
      row_num <- row_num + nrow(up_result_list[[tab]][["le"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["le"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma and EdgeR."))
      row_num <- row_num + nrow(up_result_list[[tab]][["le"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["de"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by DESeq2 and EdgeR."))
      row_num <- row_num + nrow(up_result_list[[tab]][["led"]]) + 2
      xl_result <- write_xls(
        data=up_result_list[[tab]][["led"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma, DESeq2, and EdgeR."))

      tabname <- paste0("down_", tab)
      row_num <- 1
      xl_result <- write_xls(
        data=down_result_list[[tab]][["l"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by limma."))
      row_num <- row_num + nrow(down_result_list[[tab]][["l"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["d"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by DESeq2."))
      row_num <- row_num + nrow(down_result_list[[tab]][["d"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["e"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc, ", p-value: ", p, " by EdgeR."))
      row_num <- row_num + nrow(down_result_list[[tab]][["e"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["ld"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma and DESeq2."))
      row_num <- row_num + nrow(down_result_list[[tab]][["le"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["le"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma and EdgeR."))
      row_num <- row_num + nrow(down_result_list[[tab]][["le"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["de"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by DESeq2 and EdgeR."))
      row_num <- row_num + nrow(down_result_list[[tab]][["led"]]) + 2
      xl_result <- write_xls(
        data=down_result_list[[tab]][["led"]], wb=wb, sheet=tabname, start_row=row_num,
        title=paste0("Genes deemed significant via logFC: ", lfc,
                     ", p-value: ", p, " by limma, DESeq2, and EdgeR."))
    }
    excel_ret <- try(openxlsx::saveWorkbook(wb, excel, overwrite=TRUE))
  } ## End if isTRUE(excel)
  return_list <- append(up_result_list, down_result_list)
  return(return_list)
}

make_intersect <- function(limma, deseq, edger) {
  l_alone_idx <- (! (rownames(limma) %in% rownames(deseq))) &
    (! (rownames(limma) %in% rownames(edger)))
  l_alone <- limma[l_alone_idx, ]
  d_alone_idx <- (! (rownames(deseq) %in% rownames(limma))) &
    (! (rownames(deseq) %in% rownames(edger)))
  d_alone <- deseq[d_alone_idx, ]
  e_alone_idx <- (! (rownames(edger) %in% rownames(limma))) &
    (! (rownames(edger) %in% rownames(edger)))
  e_alone <- edger[e_alone_idx, ]

  ld_idx <- (rownames(limma) %in% rownames(deseq)) & (! (rownames(limma) %in% rownames(edger)))
  ld <- limma[ld_idx, ]
  le_idx <- (rownames(limma) %in% rownames(edger)) & (! (rownames(limma) %in% rownames(deseq)))
  le <- limma[le_idx, ]
  de_idx <- (rownames(deseq) %in% rownames(edger)) & (! (rownames(deseq) %in% rownames(edger)))
  de <- deseq[de_idx, ]
  led_idx <- (rownames(limma) %in% rownames(deseq)) &
    (rownames(limma) %in% rownames(edger))
  led <- limma[led_idx, ]
  retlist <- list(
    "d" = d_alone,
    "e" = e_alone,
    "l" = l_alone,
    "ld" = ld,
    "le" = le,
    "de" = de,
    "led" = led)
  return(retlist)
}

#' Writes out the results of a single pairwise comparison.
#'
#' However, this will do a couple of things to make one's life easier:
#' 1.  Make a list of the output, one element for each comparison of the contrast matrix.
#' 2.  Write out the results() output for them in separate sheets in excel.
#' 3.  Since I have been using qvalues a lot for other stuff, add a column for them.
#'
#' Tested in test_24deseq.R
#' Rewritten in 2016-12 looking to simplify combine_de_tables().  That function is far too big,
#' This should become a template for that.
#'
#' @param data Output from results().
#' @param type  Which DE tool to write.
#' @param ...  Parameters passed downstream, dumped into arglist and passed, notably the number
#'  of genes (n), the coefficient column (coef)
#' @return List of data frames comprising the toptable output for each coefficient, I also added a
#'  qvalue entry to these toptable() outputs.
#' @seealso \code{\link{write_xls}}
#' @examples
#' \dontrun{
#'  finished_comparison = eBayes(deseq_output)
#'  data_list = write_deseq(finished_comparison, workbook="excel/deseq_output.xls")
#' }
#' @export
write_de_table <- function(data, type="limma", ...) {
  arglist <- list(...)
  excel <- arglist[["excel"]]
  if (is.null(excel)) {
    excel <- "table.xlsx"
  }
  n <- arglist[["n"]]
  if (is.null(n)) {
    n <- 0
  }
  coef <- arglist[["coef"]]
  if (is.null(coef)) {
    coef <- data[["contrasts_performed"]]
  } else {
    coef <- as.character(coef)
  }

  ## Figure out the number of genes if not provided
  if (n == 0) {
    n <- nrow(data[["coefficients"]])
  }

  wb <- NULL
  if (!is.null(excel) & excel != FALSE) {
    excel_dir <- dirname(excel)
    if (!file.exists(excel_dir)) {
      dir.create(excel_dir, recursive=TRUE)
    }
    if (file.exists(excel)) {
      message(paste0("Deleting the file ", excel, " before writing the tables."))
      file.remove(excel)
    }
    wb <- openxlsx::createWorkbook(creator="hpgltools")
  }

  return_data <- list()
  end <- length(coef)
  for (c in 1:end) {
    comparison <- coef[c]
    message(paste0("Writing ", c, "/", end, ": table: ", comparison, "."))
    table <- data[["all_tables"]][[c]]

    written <- try(write_xls(
      data=table, wb=wb, sheet=comparison, title=paste0(type, " results for: ", comparison, ".")))
  }

  save_result <- try(openxlsx::saveWorkbook(wb, excel, overwrite=TRUE))
  return(save_result)
}

## EOF
