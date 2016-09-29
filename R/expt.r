#' Wrap bioconductor's expressionset to include some other extraneous
#' information.
#'
#' It is worth noting that this function has a lot of logic used to
#' find the count tables in the local filesystem.  This logic has been
#' superceded by simply adding a field to the .csv file called
#' 'file'.  create_expt() will then just read that filename, it may be
#' a full pathname or local to the cwd of the project.
#'
#' @param metadata Comma separated file (or excel) describing the samples with information like
#'     condition, batch, count_filename, etc.
#' @param gene_info Annotation information describing the rows of the data set, this often comes
#'     from a call to import.gff() or biomart or organismdbi.
#' @param count_dataframe If one does not wish to read the count tables from the filesystem, they
#'     may instead be fed as a data frame here.
#' @param sample_colors List of colors by condition, if not provided it will generate its own colors
#'     using colorBrewer.
#' @param title Provide a title for the expt?
#' @param notes Additional notes?
#' @param include_type I have usually assumed that all gff annotations should be used, but that is
#'     not always true, this allows one to limit to a specific annotation type.
#' @param include_gff Gff file to help in sorting which features to keep.
#' @param savefile Rdata filename prefix for saving the data of the resulting expt.
#' @param low_files Explicitly lowercase the filenames when searching the filesystem?
#' @param ... More parameters are fun!
#' @return  experiment an expressionset
#' @seealso \pkg{Biobase} \link[Biobase]{pData} \link[Biobase]{fData} \link[Biobase]{exprs}
#' \link{expt_read_counts} \link[hash]{as.list.hash}
#' @examples
#' \dontrun{
#' new_experiment = create_expt("some_csv_file.csv", color_hash)
#' ## Remember that this depends on an existing data structure of gene annotations.
#' }
#' @export
create_expt <- function(metadata, gene_info=NULL, count_dataframe=NULL, sample_colors=NULL, title=NULL, notes=NULL,
                        include_type="all", include_gff=NULL,
                        savefile="expt", low_files=FALSE, ...) {
    arglist <- list(...)  ## pass stuff like sep=, header=, etc here
    ## Palette for colors when auto-chosen
    chosen_palette <- "Dark2"
    ## I am learning about simplifying vs. preserving subsetting
    ## This is a case of simplifying and I believe one which is good because I just want the string out from my list
    ## Lets assume that palette is in fact an element in arglist, I really don't care that the name
    ## of the resturn is 'palette' -- I already knew that by asking for it.
    if (is.null(title)) {
        title <- paste0("This is an expt class.")
    }
    if (is.null(notes)) {
        notes <- paste0("Created on ", date(), ".\n")
    }
    if (!is.null(arglist[["palette"]])) {
        chosen_palette <- arglist[["palette"]]
    }
    file_suffix <- ".count.gz"
    if (!is.null(arglist[["file_suffix"]])) {
        file_suffix <- arglist[["file_suffix"]]
    }
    file_prefix <- ""
    if (!is.null(arglist[["file_prefix"]])) {
        file_prefix <- arglist[["file_prefix"]]
    }
    gff_type <- "all"
    if (!is.null(arglist[["include_type"]])) {
        gff_type <- arglist[["include_type"]]
    }
    file_column <- "file"
    if (!is.null(arglist[["file_column"]])) {
        file_column <- arglist[["file_column"]]  ## Make it possible to have multiple count tables / sample in one sheet.
    }

    ## Read in the metadata from the provided data frame, csv, or xlsx.
    sample_definitions <- data.frame()
    file <- NULL
    meta_dataframe <- NULL
    if (class(metadata) == "character") { ## This is a filename containing the metadata
        file <- metadata
    } else if (class(metadata) == "data.frame") {
        meta_dataframe <- metadata
    } else {
        stop("This requires either a file or meta data.frame.")
    }
    if (is.null(meta_dataframe) & is.null(file)) {
        stop("This requires either a csv file or dataframe of metadata describing the samples.")
    } else if (is.null(file)) {
        sample_definitions <- meta_dataframe
        colnames(sample_definitions) <- tolower(colnames(sample_definitions))
        colnames(sample_definitions) <- gsub("[[:punct:]]", "", colnames(sample_definitions))
    }  else {
        sample_definitions <- read_metadata(file, ...)
    }

    ## Double-check that there is a usable condition column
    ## This is also an instance of simplifying subsetting, identical to
    ## sample_definitions[["condition"]] I don't think I care one way or the other which I use in
    ## this case, just so long as I am consistent -- I think because I have trouble remembering the
    ## difference between the concept of 'row' and 'column' I should probably use the [, column] or
    ## [row, ] method to reinforce my weak neurons.
    if (is.null(sample_definitions[["condition"]])) {
        sample_definitions[["condition"]] <- tolower(paste(sample_definitions[["type"]], sample_definitions[["stage"]], sep="_"))
    }
    condition_names <- unique(sample_definitions[["condition"]])
    if (is.null(condition_names)) {
        warning("There is no 'condition' field in the definitions, this will make many analyses more difficult/impossible.")
    }
    sample_definitions[["condition"]] <- gsub(pattern="^(\\d+)$", replacement="c\\1", x=sample_definitions[["condition"]])
    sample_definitions[["batch"]] <- gsub(pattern="^(\\d+)$", replacement="b\\1", x=sample_definitions[["batch"]])

    ## Make sure we have a viable set of colors for plots
    chosen_colors <- as.character(sample_definitions[["condition"]])
    num_conditions <- length(condition_names)
    num_samples <- nrow(sample_definitions)
    if (!is.null(sample_colors) & length(sample_colors) == num_samples) {
        chosen_colors <- sample_colors
    } else if (!is.null(sample_colors) & length(sample_colors) == num_conditions) {
        mapping <- setNames(sample_colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    } else if (is.null(sample_colors)) {
        sample_colors <- suppressWarnings(grDevices::colorRampPalette(
            RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
        mapping <- setNames(sample_colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    } else {
        warning("The number of colors provided does not match either the number of conditions nor samples.")
        warning("Unsure of what to do, so choosing colors with RColorBrewer.")
        sample_colors <- suppressWarnings(grDevices::colorRampPalette(
            RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
        mapping <- setNames(sample_colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    }
    names(chosen_colors) <- sample_definitions[["sampleid"]]

    ## Create a matrix of counts with columns as samples and rows as genes
    ## This may come from either a data frame/matrix, a list of files from the metadata
    ## or it can attempt to figure out the location of the files from the sample names.
    filenames <- NULL
    found_counts <- NULL
    all_count_tables <- NULL
    if (!is.null(count_dataframe)) {
        all_count_tables <- count_dataframe
        testthat::expect_equal(colnames(all_count_tables), rownames(sample_definitions))
        ## If neither of these cases is true, start looking for the files in the processed_data/ directory
    } else if (is.null(sample_definitions[[file_column]])) {
        success <- 0
        ## Look for files organized by sample
        test_filenames <- paste0("processed_data/count_tables/",
                                 as.character(sample_definitions[['sampleid']]), "/",
                                 file_prefix,
                                 as.character(sample_definitions[["sampleid"]]),
                                 file_suffix)
        num_found <- sum(file.exists(test_filenames))
        if (num_found == num_samples) {
            success <- success + 1
            sample_definitions[["file"]] <- test_filenames
        } else {
            lower_test_filenames <- tolower(test_filenames)
            num_found <- sum(file.exists(lower_test_filenames))
            if (num_found == num_samples) {
                success <- success + 1
                sample_definitions[["file"]] <- lower_test_filenames
            }
        }
        if (success == 0) {
            ## Did not find samples by id, try them by type
            test_filenames <- paste0("processed_data/count_tables/",
                                     tolower(as.character(sample_definitions[["type"]])), "/",
                                     tolower(as.character(sample_definitions[["stage"]])), "/",
                                     sample_definitions[["sampleid"]], file_suffix)
            num_found <- sum(file.exists(test_filenames))
            if (num_found == num_samples) {
                success <- success + 1
                sample_definitions[["file"]] <- test_filenames
            } else {
                test_filenames <- tolower(test_filenames)
                num_found <- sum(file.exists(test_filenames))
                if (num_found == num_samples) {
                    success <- success + 1
                    sample_definitions[["file"]] <- test_filenames
                }
            }
        } ## tried by type
        if (success == 0) {
            stop("I could not find your count tables organised either by sample nor by type, uppercase nor lowercase.")
        }
    }

    ## At this point sample_definitions$file should be filled in no matter what
    if (is.null(all_count_tables)) {
        filenames <- as.character(sample_definitions[[file_column]])
        sample_ids <- as.character(sample_definitions[["sampleid"]])
        all_count_tables <- expt_read_counts(sample_ids, filenames, ...)
    }

    all_count_tables <- as.data.frame(all_count_tables)
    for (col in colnames(all_count_tables)) {
        ## Ensure there are no stupid entries like target_id est_counts
        all_count_tables[[col]] <- as.numeric(all_count_tables[[col]])
    }
    all_count_tables <- all_count_tables[complete.cases(all_count_tables), ]
    rownames(all_count_tables) <- gsub("^exon:", "", rownames(all_count_tables))
    rownames(all_count_tables) <- make.names(gsub(":\\d+", "", rownames(all_count_tables)), unique=TRUE)

    annotation <- NULL
    tooltip_data <- NULL
    if (is.null(gene_info)) {
        if (is.null(include_gff)) {
            gene_info <- as.data.frame(rownames(all_count_tables))
            rownames(gene_info) <- rownames(all_count_tables)
            colnames(gene_info) <- "name"
        } else {
            message("create_expt(): Reading annotation gff, this is slow.")
            annotation <- gff2df(gff=include_gff, type=gff_type)
            tooltip_data <- make_tooltips(annotations=annotation, type=gff_type, ...)
            gene_info <- annotation
        }
    } else if (class(gene_info) == "list" & !is.null(gene_info[["genes"]])) {
        gene_info <- as.data.frame(gene_info[["genes"]])
    }

    ## It turns out that loading the annotation information from orgdb/etc may not set the row names.
    ## Perhaps I should do that there, but I will add a check here, too.
    if (sum(rownames(gene_info) %in% rownames(all_count_tables)) == 0) {
        if (!is.null(gene_info[["geneid"]])) {
            rownames(gene_info) <- gene_info[["geneid"]]
        }
        if (sum(rownames(gene_info) %in% rownames(all_count_tables)) == 0) {
            warning("Even after changing the rownames in gene info, they do not match the count table.")
        }
    }

    ## Take a moment to remove columns which are blank
    columns_to_remove <- NULL
    for (col in 1:length(colnames(gene_info))) {
        sum_na <- sum(is.na(gene_info[[col]]))
        sum_null <- sum(is.null(gene_info[[col]]))
        sum_empty <- sum_na + sum_null
        if (sum_empty ==  nrow(gene_info)) {
            ## This column is empty.
            columns_to_remove <- append(columns_to_remove, col)
        }
    }
    if (length(columns_to_remove) > 0) {
        gene_info <- gene_info[-columns_to_remove]
    }
    ## There should no longer be blank columns in the annotation data.
    ## Maybe I will copy/move this to my annotation collection toys?
    tmp_countsdt <- data.table::as.data.table(all_count_tables)
    tmp_countsdt[["rownames"]] <- rownames(all_count_tables)
    tmp_countsdt[["temporary_id_number"]] <- 1:nrow(tmp_countsdt)
    gene_infodt <- data.table::as.data.table(gene_info)
    gene_infodt[["rownames"]] <- rownames(gene_info)

    message("Bringing together the count matrix and gene information.")
    counts_and_annotations <- merge(tmp_countsdt, gene_infodt, by="rownames", all.x=TRUE)
    counts_and_annotations <- counts_and_annotations[order(counts_and_annotations[["temporary_id_number"]]), ]
    counts_and_annotations <- as.data.frame(counts_and_annotations)
    final_annotations <- counts_and_annotations[, colnames(counts_and_annotations) %in% colnames(gene_infodt) ]
    rownames(final_annotations) <- counts_and_annotations[["rownames"]]
    final_annotations <- final_annotations[-1]
    ##colnames(final_annotations) <- colnames(gene_info)
    ##rownames(final_annotations) <- counts_and_annotations[["rownames"]]
    final_countsdt <- counts_and_annotations[, colnames(counts_and_annotations) %in% colnames(all_count_tables) ]
    final_counts <- as.data.frame(final_countsdt)
    rownames(final_counts) <- counts_and_annotations[["rownames"]]
    ##final_counts <- final_counts[-1]
    rm(counts_and_annotations)
    rm(tmp_countsdt)
    rm(gene_infodt)
    rm(final_countsdt)

    ## Perhaps I do not understand something about R's syntactic sugar
    ## Given a data frame with columns bob, jane, alice -- but not foo
    ## I can do df[["bob"]]) or df[, "bob"] to get the column bob
    ## however df[["foo"]] gives me null while df[, "foo"] gives an error.
    if (is.null(sample_definitions[["condition"]])) {
        sample_definitions[["condition"]] <- "unknown"
    }
    if (is.null(sample_definitions[["batch"]])) {
        sample_definitions[["batch"]] <- "unknown"
    }
    if (is.null(sample_definitions[["intercounts"]])) {
        sample_definitions[["intercounts"]] <- "unknown"
    }
    if (is.null(sample_definitions[["file"]])) {
        sample_definitions[["file"]] <- "null"
    }

    ## Adding this so that deseq does not complain about characters when calling DESeqDataSetFromMatrix()
    sample_definitions[["condition"]] <- as.factor(sample_definitions[["condition"]])
    sample_definitions[["batch"]] <- as.factor(sample_definitions[["batch"]])

    requireNamespace("Biobase")  ## AnnotatedDataFrame is from Biobase
    metadata <- methods::new("AnnotatedDataFrame",
                             sample_definitions)
    Biobase::sampleNames(metadata) <- colnames(final_counts)

    feature_data <- methods::new("AnnotatedDataFrame",
                                 final_annotations)
    Biobase::featureNames(feature_data) <- rownames(final_counts)

    experiment <- methods::new("ExpressionSet",
                               exprs=as.matrix(final_counts),
                               phenoData=metadata,
                               featureData=feature_data)
    Biobase::notes(experiment) <- toString(notes)

    ## These entries in new_expt are intended to maintain a record of
    ## the transformation status of the data, thus if we now call
    ## normalize_expt() it should change these.
    ## Therefore, if we call a function like DESeq() which requires
    ## non-log2 counts, we can check these values and convert accordingly
    expt <- expt_subset(experiment)
    expt[["title"]] <- title
    expt[["notes"]] <- toString(notes)
    expt[["design"]] <- sample_definitions
    expt[["annotation"]] <- annotation
    expt[["gff_file"]] <- include_gff
    expt[["tooltip"]] <- tooltip_data
    starting_state <- list(
        "lowfilter" = "raw",
        "normalization" = "raw",
        "conversion" = "raw",
        "batch" = "raw",
        "transform" = "raw")
    expt[["state"]] <- starting_state
    expt[["conditions"]] <- droplevels(as.factor(sample_definitions[, "condition"]))
    expt[["conditions"]] <- gsub(pattern="^(\\d+)$", replacement="c\\1", x=expt[["conditions"]])
    names(expt[["conditions"]]) <- rownames(sample_definitions)
    expt[["batches"]] <- droplevels(as.factor(sample_definitions[, "batch"]))
    expt[["batches"]] <- gsub(pattern="^(\\d+)$", replacement="b\\1", x=expt[["batches"]])
    names(expt[["batches"]]) <- rownames(sample_definitions)
    expt[["original_libsize"]] <- colSums(Biobase::exprs(experiment))
    names(expt[["original_libsize"]]) <- rownames(sample_definitions)
    expt[["libsize"]] <- expt[["original_libsize"]]
    names(expt[["libsize"]]) <- rownames(sample_definitions)
    expt[["colors"]] <- chosen_colors
    names(expt[["colors"]]) <- rownames(sample_definitions)
    if (!is.null(savefile)) {
        save_result <- try(save(list = c("expt"), file=paste(savefile, ".Rdata", sep="")))
    }
    if (class(save_result) == "try-error") {
        warning("Saving the expt object failed, perhaps you do not have permissions?")
    }
    return(expt)
}

#' Extract a subset of samples following some rule(s) from an
#' experiment class.
#'
#' Sometimes an experiment has too many parts to work with conveniently, this operation allows one
#' to break it into smaller pieces.
#'
#' @param expt Expt chosen to extract a subset of data.
#' @param subset Valid R expression which defines a subset of the design to keep.
#' @return metadata Expt class which contains the smaller set of data.
#' @seealso \pkg{Biobase} \link[Biobase]{pData}
#' \link[Biobase]{exprs} \link[Biobase]{fData}
#' @examples
#' \dontrun{
#'  smaller_expt = expt_subset(big_expt, "condition=='control'")
#'  all_expt = expt_subset(expressionset, "")  ## extracts everything
#' }
#' @export
expt_subset <- function(expt, subset=NULL) {
    if (class(expt)[[1]] == "ExpressionSet") {
        original_expressionset <- expt
        original_metadata <- Biobase::pData(original_expressionset)
    } else if (class(expt)[[1]] == "expt") {
        original_expressionset <- expt[["expressionset"]]
        original_metadata <- Biobase::pData(expt[["expressionset"]])
    } else {
        stop("expt is neither an expt nor ExpressionSet")
    }

    note_appended <- NULL
    if (is.null(subset)) {
        subset_design <- original_metadata
    } else {
        r_expression <- paste("subset(original_metadata,", subset, ")")
        subset_design <- eval(parse(text=r_expression))
        ## design = data.frame(sample=samples$sample, condition=samples$condition, batch=samples$batch)
        note_appended <- paste0("Subsetted with ", subset, " on ", date(), ".\n")
    }
    if (nrow(subset_design) == 0) {
        stop("When the subset was taken, the resulting design has 0 members, check your expression.")
    }
    subset_design <- as.data.frame(subset_design)
    ## This is to get around stupidity with respect to needing all factors to be in a DESeqDataSet
    original_ids <- rownames(original_metadata)
    subset_ids <- rownames(subset_design)
    subset_positions <- original_ids %in% subset_ids
    original_colors <- expt[["colors"]]
    subset_colors <- original_colors[subset_positions]
    original_conditions <- expt[["conditions"]]
    subset_conditions <- original_conditions[subset_positions, drop=TRUE]
    original_batches <- expt[["batches"]]
    subset_batches <- original_batches[subset_positions, drop=TRUE]
    original_libsize <- expt[["original_libsize"]]
    subset_libsize <- original_libsize[subset_positions, drop=TRUE]
    subset_expressionset <- original_expressionset[, subset_positions]
    first_expressionset <- original_expressionset[["original_expressionset"]]
    subset_first_expressionset <- first_expressionset[, subset_positions]

    notes <- expt[["notes"]]
    if (!is.null(note_appended)) {
        notes <- paste0(notes, note_appended)
    }

    for (col in 1:ncol(subset_design)) {
        if (class(subset_design[[col]]) == "factor") {
            subset_design[[col]] <- droplevels(subset_design[[col]])
        }
    }
    Biobase::pData(subset_expressionset) <- subset_design

    new_expt <- list(
        "title" = expt[["title"]],
        "notes" = toString(notes),
        "initial_metadata" = subset_design,
        "original_expressionset" = subset_first_expressionset,
        "expressionset" = subset_expressionset,
        "design" = subset_design,
        "conditions" = subset_conditions,
        "batches" = subset_batches,
        "samplenames" = subset_ids,
        "colors" = subset_colors,
        "state" = expt[["state"]],
        "original_libsize" = original_libsize,
        "libsize" = subset_libsize)
    class(new_expt) <- "expt"
    return(new_expt)
}
## Because I am an idiot.
subset_expt <- function(...) {
    expt_subset(...)
}

#' Given a table of meta data, read it in for use by create_expt().
#'
#' Reads an experimental design in a few different formats in preparation for creating an expt.
#'
#' @param file Csv/xls file to read.
#' @param ... Arguments for arglist, used by sep, header and similar read.csv/read.table parameters.
#' @return Df of metadata.
read_metadata <- function(file, ...) {
    arglist <- list(...)
    if (is.null(arglist[["sep"]])) {
        arglist[["sep"]] <- ","
    }
    if (is.null(arglist[["header"]])) {
        arglist[["header"]] <- TRUE
    }

    if (tools::file_ext(file) == "csv") {
        definitions <- read.csv(file=file, comment.char="#",
                                sep=arglist[["sep"]], header=arglist[["header"]])
    } else if (tools::file_ext(file) == "xlsx") {
        ## xls = loadWorkbook(file, create=FALSE)
        ## tmp_definitions = readWorksheet(xls, 1)
        definitions <- openxlsx::read.xlsx(xlsxFile=file, sheet=1)
    } else if (tools::file_ext(file) == "xls") {
        ## This is not correct, but it is a start
        definitions <- XLConnect::read.xls(xlsFile=file, sheet=1)
    } else {
        definitions <- read.table(file=file, sep=arglist[["sep"]], header=arglist[["header"]])
    }

    colnames(definitions) <- tolower(colnames(definitions))
    colnames(definitions) <- gsub("[[:punct:]]", "", colnames(definitions))
    rownames(definitions) <- make.names(definitions[["sampleid"]], unique=TRUE)
    ## "no visible binding for global variable 'sampleid'"  ## hmm sample.id is a column from the csv file.
    ## tmp_definitions <- subset(tmp_definitions, sampleid != "")
    empty_samples <- which(definitions[, "sampleid"] == "" | is.na(definitions[, "sampleid"]) | grepl(pattern="^#", x=definitions[, "sampleid"]))
    if (length(empty_samples) > 0) {
        definitions <- definitions[-empty_samples, ]
    }
    return(definitions)
}

#' Change the batches of an expt.
#'
#' When exploring differential analyses, it might be useful to play with the conditions/batches of
#' the experiment.  Use this to make that easier.
#'
#' @param expt  Expt to modify.
#' @param fact  Batches to replace using this factor.
#' @param ids  Specific samples to change.
#' @param ...  Extra options are like spinach.
#' @return  The original expt with some new metadata.
#' @examples
#' \dontrun{
#'  expt = set_expt_batch(big_expt, factor=c(some,stuff,here))
#' }
#' @export
set_expt_batch <- function(expt, fact, ids=NULL, ...) {
    arglist <- list(...)
    original_batches <- expt[["batches"]]
    original_length <- length(original_batches)
    if (length(fact) == 1) {
        ## Assume it is a column in the design
        if (fact %in% colnames(expt[["design"]])) {
            fact <- expt[["design"]][[fact]]
        } else {
            stop("The provided factor is not in the design matrix.")
        }
    }

    if (length(fact) != original_length) {
        stop("The new factor of batches is not the same length as the original.")
    }
    expt[["batches"]] <- fact
    Biobase::pData(expt[["expressionset"]])[["batch"]] <- fact
    expt[["design"]][["batch"]] <- fact
    return(expt)
}

#' Change the colors of an expt
#'
#' When exploring differential analyses, it might be useful to play with the conditions/batches of
#' the experiment.  Use this to make that easier.
#'
#' @param expt Expt to modify
#' @param colors colors to replace
#' @param chosen_palette  I usually use Dark2 as the RColorBrewer palette.
#' @return expt Send back the expt with some new metadata
#' @examples
#' \dontrun{
#'  expt = set_expt_batch(big_expt, factor=c(some,stuff,here))
#' }
#' @export
set_expt_colors <- function(expt, colors=TRUE, chosen_palette="Dark2") {
    num_conditions <- length(levels(as.factor(expt[["conditions"]])))
    num_samples <- nrow(expt[["design"]])
    sample_ids <- expt[["design"]][["sampleid"]]
    chosen_colors <- expt[["conditions"]]

    if (is.null(colors) | isTRUE(colors)) {
        sample_colors <- suppressWarnings(grDevices::colorRampPalette(
            RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
        mapping <- setNames(sample_colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    } else if (!is.null(colors) & length(colors) == num_samples) {
        chosen_colors <- colors
    } else if (!is.null(colors) & length(colors) == num_conditions) {
        mapping <- setNames(colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    } else if (is.null(colors)) {
        colors <- sm(grDevices::colorRampPalette(
                                    RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
        mapping <- setNames(colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    } else {
        warning("The number of colors provided does not match either the number of conditions nor samples.")
        warning("Unsure of what to do, so choosing colors with RColorBrewer.")
        sample_colors <- suppressWarnings(grDevices::colorRampPalette(
            RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
        mapping <- setNames(sample_colors, unique(chosen_colors))
        chosen_colors <- mapping[chosen_colors]
    }
    names(chosen_colors) <- sample_ids

    expt[["colors"]] <- chosen_colors
    return(expt)
}
##set_expt_colors <- function(expt, colors=NULL, ids=NULL, ...) {
##    arglist <- list(...)
##    chosen_palette <- "Dark2"
##    if (!is.null(arglist[["chosen_palette"]])) {
##        chosen_palette <- arglist[["chosen_palette"]]
##    }
##    conditions <- expt[["conditions"]]
##    if (is.null(conditions) & !is.null(arglist[["conditions"]])) {
##        conditions <- arglist[["conditions"]]
##    } else if (is.null(conditions) & !is.null(expt[["design"]])) {
##        conditions <- expt[["design"]][["condition"]]
##    } else if (is.null(conditions)) {
##        warning("Unable to discern the number of conditions in the expt.")
##        warning("Choosing 1 color for each sample.")
##        conditions <- rownames(Biobase::pData(expt$expressionset))
##    }
##    num_conditions <- length(levels(as.factor(conditions)))
##    chosen_colors <- as.character(conditions)
##    if (is.null(colors)) {
##        sample_colors <- suppressWarnings(grDevices::colorRampPalette(
##            RColorBrewer::brewer.pal(num_conditions, chosen_palette))(num_conditions))
##        mapping <- setNames(sample_colors, unique(chosen_colors))
##        chosen_colors <- mapping[chosen_colors]
##        expt[["colors"]] <- chosen_colors
##    } else if (class(colors) == "character" | class(colors) == "factor") {
##        current <- levels(as.factor(expt[["colors"]]))
##        if (length(current) == length(colors)) {
##            for (c in 1:length(current)) {
##                cur <- current[[c]]
##                new <- colors[[c]]
##                expt[["colors"]] <- gsub(pattern=cur, replacement=new, x=expt[["colors"]])
##            }
##        } else {
##                warning("The numbers of colors do not match, using ColorBrewer to generate colors.")
##                expt <- set_expt_colors(expt, colors=NULL)
##            }
##        }
##    return(expt)
##}

#' Change the condition of an expt
#'
#' When exploring differential analyses, it might be useful to play with the conditions/batches of
#' the experiment.  Use this to make that easier.
#'
#' @param expt Expt to modify
#' @param fact Conditions to replace
#' @param ids Specific sample IDs to change.
#' @return expt Send back the expt with some new metadata
#' @examples
#' \dontrun{
#'  expt = set_expt_condition(big_expt, factor=c(some,stuff,here))
#' }
#' @export
set_expt_condition <- function(expt, fact, ids=NULL, ...) {
    arglist <- list(...)
    original_conditions <- expt[["conditions"]]
    original_length <- length(original_conditions)
    new_expt <- expt  ## Explicitly copying expt to new_expt
    ## because when I run this as a function call() it seems to be not properly setting the conditions
    ## and I do not know why.
    if (!is.null(ids)) {
        ## Change specific id(s) to given condition(s).
        old_pdata <- Biobase::pData(expt[["expressionset"]])
        old_cond <- as.character(old_pdata[["condition"]])
        names(old_cond) <- rownames(old_pdata)
        new_cond <- old_cond
        new_cond[ids] <- fact
        new_pdata <- old_pdata
        new_pdata[["condition"]] <- as.factor(new_cond)
        Biobase::pData(expt[["expressionset"]]) <- new_pdata
        new_expt[["conditions"]][ids] <- fact
        new_expt[["design"]][["condition"]] <- new_cond
    } else if (length(fact) == 1) {
        ## Assume it is a column in the design
        if (fact %in% colnames(expt[["design"]])) {
            new_fact <- expt[["design"]][[fact]]
            new_expt[["conditions"]] <- new_fact
            Biobase::pData(new_expt[["expressionset"]])[["condition"]] <- new_fact
            new_expt[["design"]][["condition"]] <- new_fact
        } else {
            stop("The provided factor is not in the design matrix.")
        }
    } else if (length(fact) != original_length) {
            stop("The new factor of conditions is not the same length as the original.")
    } else {
        new_expt[["conditions"]] <- fact
        Biobase::pData(new_expt[["expressionset"]])[["condition"]] <- fact
        new_expt[["design"]][["condition"]] <- fact
    }

    tmp_expt <- set_expt_colors(new_expt)
    rm(new_expt)
    return(tmp_expt)
}

#' Change the factors (condition and batch) of an expt
#'
#' When exploring differential analyses, it might be useful to play with the conditions/batches of
#' the experiment.  Use this to make that easier.
#'
#' @param expt Expt to modify
#' @param condition New condition factor
#' @param batch New batch factor
#' @param ids Specific sample IDs to change.
#' @param ... Arguments passed along (likely colors)
#' @return expt Send back the expt with some new metadata
#' @examples
#' \dontrun{
#'  expt = set_expt_factors(big_expt, condition="column", batch="another_column")
#' }
#' @export
set_expt_factors <- function(expt, condition=NULL, batch=NULL, ids=NULL, ...) {
    arglist <- list(...)
    if (!is.null(condition)) {
        expt <- set_expt_condition(expt, fact=condition, ...)
    }
    if (!is.null(batch)) {
        expt <- set_expt_batch(expt, fact=batch, ...)
    }
    return(expt)
}

## EOF
