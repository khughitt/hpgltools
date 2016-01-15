## Time-stamp: <Thu Jan 14 15:22:45 2016 Ashton Trey Belew (abelew@gmail.com)>

#' make_SVD() is a function scabbed from Hector and Kwame's cbcbSEQ
#' It just does fast.svd of a matrix against its rowMeans().
#'
#' @param data A data frame to decompose
#'
#' @return a list containing the s,v,u from fast.svd
#' @seealso \code{\link{fast.svd}}
#'
#' @export
#' @examples
#' ## svd = makeSVD(data)
makeSVD <- function (x) {
    x <- as.matrix(x)
    s <- fast.svd(x - rowMeans(x))
    v <- s$v
    rownames(v) <- colnames(x)
    s <- list(v=v, u=s$u, d=s$d)
    return(s)
}

#' Beta.NA: Perform a quick solve to gather residuals etc
#' This was provided by Kwame for something which I don't remember a loong time ago.
Beta.NA <- function(y,X) {
    des <- X[!is.na(y),]
    y1 <- y[!is.na(y)]
    B <- solve(t(des)%*%des)%*%t(des)%*%y1
    return(B)
}

#' get_genelengths()  Grab gene lengths from a gff file.
#'
#' @param gff  a gff file with (hopefully) IDs and widths
#' @param type default='gene'  the annotation type to use.
#' @param key default='ID'  the identifier in the 10th column of the gff file to use.
#'
#' This function attempts to be robust to the differences in output from importing gff2/gff3 files.  But it certainly isn't perfect.
#'
#' @return  a data frame of gene IDs and widths.
#' @export
#' @seealso \code{\link{import.gff3}}, \code{\link{import.gff}}, \code{\link{import.gff2}}
#'
#' @examples
#' ## tt = hpgltools:::get_genelengths('reference/fun.gff.gz')
#' ## head(tt)
#' ##          ID width
#' ##1   YAL069W   312
#' ##2   YAL069W   315
#' ##3   YAL069W     3
#' ##4 YAL068W-A   252
#' ##5 YAL068W-A   255
#' ##6 YAL068W-A     3
get_genelengths <- function(gff, type="gene", key='ID') {
    ret <- gff2df(gff)
    ret <- ret[ret$type == type,]
    ret <- ret[,c(key,"width")]
    colnames(ret) <- c("ID","width")
    if (dim(genelengths)[1] == 0) {
        stop(paste0("No genelengths were found.  Perhaps you are using the wrong 'type' or 'key' arguments, type is: ", type, ", key is: ", key))
    }
    return(ret)
}


#' sum_exons()  Given a data frame of exon counts and annotation information, sum the exons.
#'
#' @param data  a count table by exon
#' @param gff default=NULL  a gff filename
#' @param annotdf default=NULL  a dataframe of annotations (probably from gff2df)
#' @param parent default='Parent'  a column from the annotations with the gene names
#' @param child default='row.names'  a column from the annotations with the exon names
#'
#' This function will merge a count table to an annotation table by the child column.
#' It will then sum all rows of exons by parent gene and sum the widths of the exons.
#' Finally it will return a list containing a df of gene lengths and summed counts.
#'
#' @return  a list of 2 data frames.
#' @export
sum_exons <- function(data, gff=NULL, annotdf=NULL, parent='Parent', child='row.names') {
    if (is.null(annotdf) & is.null(gff)) {
        stop("I need either a df with parents, children, and widths; or a gff filename.")
    } else if (is.null(annotdf)) {
        annotdf <- gff2df(gff)
    }

    tmp_data <- merge(data, annotdf, by=child)
    rownames(tmp_data) <- tmp_data$Row.names
    tmp_data <- tmp_data[-1]
    ## Start out by summing the gene widths
    column <- aggregate(tmp_data[,"width"], by=list(Parent=tmp_data[,parent]), FUN=sum)
    new_data <- data.frame(column$x)
    rownames(new_data) <- column$Parent
    colnames(new_data) <- c("width")

    for (c in 1:length(colnames(data))) {
        column_name <- colnames(data)[[c]]
        column <- aggregate(tmp_data[,column_name], by=list(Parent=tmp_data[,parent]), FUN=sum)
        rownames(column) <- column$Parent
        new_data <- cbind(new_data, column$x)
    } ## End for loop
    width_df <- data.frame(new_data$width)
    rownames(width_df) <- rownames(new_data)
    colnames(width_df) <- c("width")
    new_data <- new_data[-1]
    colnames(new_data) <- colnames(data)
    rownames(new_data) <- rownames(column)
    ret <- list(width=width_df, counts=new_data)
    return(ret)
}

#' make_report()  Make a knitr report with some defaults set
#'
#' @param type default='pdf'  html/pdf/fancy html reports?
#'
#' @return a dated report file
make_report <- function(name="report", type='pdf') {
    opts_knit$set(progress=FALSE, verbose=FALSE, error=FALSE, fig.width=7, fig.height=7)
    theme_set(theme_bw(base_size=10))
    options(java.parameters="-Xmx8g")
    set.seed(1)
    output_date <- format(Sys.time(), "%Y%m%d-%H%M")
    input_filename <- name
    ## In case I add .rmd on the end.
    input_filename <- gsub("\\.rmd", "", input_filename, perl=TRUE)
    input_filename <- paste0(input_filename, ".rmd")
    if (type == 'html') {
        output_filename <- paste0(name, "-", output_date, ".html")
        output_format <- 'html_document'
        render(output_filename, output_format)
    } else if (type == 'pdf') {
        output_filename <- paste0(name, "-", output_date, ".pdf")
        output_format <- 'pdf_document'
    } else {
        output_filename <- paste0(name, "-", output_date, ".html")
        output_format <- 'knitrBootstrap::bootstrap_document'
    }
    message(paste0("About to run: render(input=", input_filename, ", output_file=", output_filename, " and output_format=", output_format))
    result <- try(render(input=input_filename, output_file=output_filename, output_format=output_format), silent=TRUE)
    return(result)
}

#' hpgl_arescore()  Implement the arescan function in R
#'
#' This function was taken almost verbatim from AREScore() in SeqTools
#' Available at: https://github.com/lianos/seqtools.git
#' At least on my computer I could not make that implementation work
#' So I rewrapped its apply() calls and am now hoping to extend its logic
#' a little to make it more sensitive and get rid of some of the spurious
#' parameters or at least make them more transparent.
#'
#' @param stringset  A DNA/RNA StringSet containing the UTR sequences of interest
#' @param basal default=1  I dunno.
#' @param overlapping default=1.5
#' @param d1.3 default=0.75  These parameter names are so stupid, lets be realistic
#' @param d4.6 default=0.4
#' @param d7.9 default=0.2
#' @param within.AU default=0.3
#' @param aub.min.length default=10
#' @param aub.p.to.start default=0.8
#' @param aub.p.to.end default=0.55
#'
#' @return a DataFrame of scores
hpgl_arescore <- function (x, basal=1, overlapping=1.5, d1.3=0.75, d4.6=0.4,
                           d7.9=0.2, within.AU=0.3, aub.min.length=10, aub.p.to.start=0.8,
                           aub.p.to.end=0.55) {
    ## The seqtools package I am using is called in R 'SeqTools' (note the capital S T)
    ## However, the repository I want for it is 'seqtools'
    ## Ergo my stupid require.auto() will be confused by definition because it assumes equivalent names
    if (isTRUE('SeqTools' %in% .packages(all.available=TRUE))) {
        library('SeqTools')
    } else {
        require.auto("lianos/seqtools/R/pkg")
        library('SeqTools')
    }
    xtype <- match.arg(substr(class(x), 1, 3), c("DNA", "RNA"))
    if (xtype == "DNA") {
        pentamer <- "ATTTA"
        overmer <- "ATTTATTTA"
    } else {
        pentamer <- "AUUUA"
        overmer <- "AUUUAUUUA"
    }
    x <- as(x, "DNAStringSet")
    pmatches <- vmatchPattern(pentamer, x)
    omatches <- vmatchPattern(overmer, x)
    basal.score <- elementLengths(pmatches) * basal
    over.score <- elementLengths(omatches) * overlapping
    no.cluster <- data.frame(d1.3 = 0, d4.6 = 0, d7.9 = 0)
    clust <- lapply(pmatches, function(m) {
        if (length(m) < 2) {
            return(no.cluster)
        }
        wg <- width(gaps(m))
        data.frame(d1.3=sum(wg <= 3), d4.6=sum(wg >= 4 & wg <= 6), d7.9=sum(wg >= 7 & wg <= 9))
    })
    clust <- do.call(rbind, clust)
    dscores <- clust$d1.3 * d1.3 + clust$d4.6 * d4.6 + clust$d7.9 *  d7.9
    require.auto("Biostrings")
    au.blocks <- hpgltools:::my_identifyAUBlocks(x, aub.min.length, aub.p.to.start, aub.p.to.end)
    aub.score <- sum(countOverlaps(pmatches, au.blocks) * within.AU)
    score <- basal.score + over.score + dscores + aub.score
    ans <- DataFrame(score=score, n.pentamer=elementLengths(pmatches), n.overmer=elementLengths(omatches),
                     au.blocks=au.blocks, n.au.blocks=elementLengths(au.blocks))
    cbind(ans, DataFrame(clust))
}

#' my_identifyAUBlocks()  copy/paste the function from SeqTools
#' and find where it falls on its ass.
#'
#' Yeah, I do not remember what I changed in this function.
#'
#' @param x  A sequence object
#' @param min.length default=20  I dunno.
#' @param p.to.start default=0.8  the p to start of course
#' @param p.to.end default=0.8  and the p to end
#'
#' @return a list of IRanges which contain a bunch of As and Us.
my_identifyAUBlocks <- function (x, min.length=20, p.to.start=0.8, p.to.end=0.55) {
    xtype = match.arg(substr(class(x), 1, 3), c("DNA", "RNA"))
    stopifnot(isSingleNumber(min.length) && min.length >= 5 &&  min.length <= 50)
    stopifnot(isSingleNumber(p.to.start) && p.to.start >= 0.5 && p.to.start <= 0.95)
    stopifnot(isSingleNumber(p.to.end) && p.to.end >= 0.2 && p.to.end <= 0.7)
    stopifnot(p.to.start > p.to.end)
    if (xtype == "DNA") {
        AU <- "AT"
    } else {
        AU <- "AU"
    }
    y <- as(x, sprintf("%sStringSet", xtype))

    widths <- width(x)
    fun <- function(i) {
        one_seq <- x[[i]]
        au <- Biostrings::letterFrequencyInSlidingView(one_seq, min.length, AU, as.prob=TRUE)
        if (is.null(au) | nrow(au) == 0) {
                return(IRanges())
            }
        au <- as.numeric(au)
        can.start <- au >= p.to.start
        can.end <- au <= p.to.end
        posts <- .Call("find_au_start_end", au, p.to.start, p.to.end, PACKAGE = "SeqTools")
        blocks <- IRanges(posts$start, posts$end + min.length -  1L)
        end(blocks) <- ifelse(end(blocks) > widths[i], widths[i], end(blocks))
        IRanges::reduce(blocks)
    }
    au.blocks = lapply(1:length(x), fun)
    IRangesList(au.blocks)
}

#' gff2df()  Try to make import.gff a little more robust
#'
#' @param gff  a gff filename
#'
#' This function wraps import.gff/import.gff3/import.gff2 calls in try()
#' Because sometimes those functions fail in unpredictable ways.
#'
#' @export
#' @return  a df!
gff2df <- function(gff, type=NULL) {
    ret <- NULL
    annotations <- try(rtracklayer::import.gff3(gff), silent=TRUE)
    if (class(annotations) == 'try-error') {
        annotations <- try(rtracklayer::import.gff2(gff), silent=TRUE)
        if (class(annotations) == 'try-error') {
            stop("Could not extract the widths from the gff file.")
        } else {
            ret <- annotations
        }
    } else {
        ret <- annotations
    }
    ## The call to as.data.frame must be specified with the GenomicRanges namespace, otherwise one gets an error about
    ## no method to coerce an S4 class to a vector.
    ret <- GenomicRanges::as.data.frame(ret)
    if (!is.null(type)) {
        index <- ret[, "type"] == type
        ret <- ret[index, ]
    }
    return(ret)
}

#' gff2irange()  Try to make import.gff a little more robust
#'
#' @param gff  a gff filename
#'
#' This function wraps import.gff/import.gff3/import.gff2 calls in try()
#' Because sometimes those functions fail in unpredictable ways.
#'
#' @export
#' @return  an iranges! (useful for getSeq())
gff2irange <- function(gff) {
    ret <- NULL
    annotations <- try(import.gff3(gff), silent=TRUE)
    if (class(annotations) == 'try-error') {
        annotations <- try(import.gff2(gff), silent=TRUE)
        if (class(annotations) == 'try-error') {
            stop("Could not extract the widths from the gff file.")
        } else {
            ret <- annotations
        }
    } else {
        ret <- annotations
    }
    ## The call to as.data.frame must be specified with the GenomicRanges namespace, otherwise one gets an error about
    ## no method to coerce an S4 class to a vector.
     return(ret)
}

#' hpgl_cor()  Wrap cor() to include robust correlations.
#'
#' @param df  a data frame to test.
#' @param method default='pearson'  correlation method to use. Includes pearson, spearman, kendal, robust.
#' @param ...  other options to pass to stats::cor()
#'
#' @return  correlation some fun correlation statistics
#' @seealso \code{\link{cor}}, \code{\link{cov}}, \code{\link{covRob}}
#'
#' @export
#' @examples
#' ## hpgl_cor(df=df)
#' ## hpgl_cor(df=df, method="robust")
hpgl_cor <- function(df, method="pearson", ...) {
    if (method == "robust") {
        robust_cov <- robust::covRob(df, corr=TRUE)
        correlation <- robust_cov$cov
    } else {
        correlation <- stats::cor(df, method=method, ...)
    }
    return(correlation)
}

#' make_tooltips()  Create a simple df from gff which contains tooltip usable information for gVis graphs.
#'
#' @param gff or annotations: Either a gff file or annotation data frame (which likely came from a gff file.)
#'
#' @return a df of tooltip information
make_tooltips <- function(annotations=NULL, gff=NULL, desc_col='description') {
    if (is.null(annotations) & is.null(gff)) {
        stop("I need either a data frame or gff file.")
    } else {
        if (!is.null(annotations)) {
            tooltip_data <- annotations[,c("ID", desc_col)]
        } else {
            ret <- NULL
            annotations <- try(import.gff3(gff), silent=TRUE)
            if (class(annotations) == 'try-error') {
                annotations <- try(import.gff2(gff), silent=TRUE)
                if (class(annotations) == 'try-error') {
                    stop("Could not extract the widths from the gff file.")
                } else {
                    ret <- annotations
                }
            } else {
                ret <- annotations
            }
            ## The call to as.data.frame must be specified with the GenomicRanges namespace, otherwise one gets an error about
            ## no method to coerce an S4 class to a vector.
            tooltip_data <- GenomicRanges::as.data.frame(ret)
        }
    }
    tooltip_data$tooltip <- ""
    if (is.null(tooltip_data[[desc_col]])) {
        stop("I need a name!")
    } else {
        tooltip_data$tooltip <- paste0(tooltip_data$ID, ': ', tooltip_data[[desc_col]])
    }
    tooltip_data$tooltip <- gsub("\\+", " ", tooltip_data$tooltip)
    tooltip_data$tooltip <- gsub(": $", "", tooltip_data$tooltip)
    tooltip_data$tooltip <- gsub("^: ", "", tooltip_data$tooltip)
    rownames(tooltip_data) <- make.names(tooltip_data$ID, unique=TRUE)
    tooltip_data <- tooltip_data[-1]
    colnames(tooltip_data) <- c("short", "1.tooltip")
    tooltip_data <- tooltip_data[-1]
    return(tooltip_data)
}

#' pattern_count_genome()  Find how many times a given pattern occurs in every gene of a genome.
#'
#' @param fasta  a fasta genome
#' @param gff default=NULL  an optional gff of annotations (if not provided it will just ask the whole genome.
#' @param pattern default='TA'  what pattern to search for?  This was used for tnseq and TA is the mariner insertion point.
#' @param key default='locus_tag'  what type of entry of the gff file to key from?
#'
#' @return num_pattern a data frame of names and numbers.
#' @export
#' @seealso \code{\link{PDict}} \code{\link{FaFile}}
#' @examples
#' ## num_pattern = pattern_count_genome('mgas_5005.fasta', 'mgas_5005.gff')
pattern_count_genome <- function(fasta, gff=NULL, pattern='TA', type='gene', key='locus_tag') {
    rawseq <- FaFile(fasta)
    if (is.null(gff)) {
        entry_sequences <- rawseq
    } else {
        entries <- import.gff3(gff, asRangedData=FALSE)
        type_entries <- subset(entries, type==type)
        names(type_entries) <- rownames(type_entries)
        entry_sequences <- getSeq(rawseq, type_entries)
        names(entry_sequences) <- entry_sequences[[,key]]
    }
    dict <- PDict(pattern, max.mismatch=0)
    result <- vcountPDict(dict, entry_sequences)
    num_pattern <- data.frame(name=names(entry_sequences), num=as.data.frame(t(result)))
    return(num_pattern)
}

#' sillydist()  A stupid distance function of a point against two axes.
#'
#' @param firstterm  the x-values of the points.
#' @param secondterm  the y-values of the points.
#' @param firstaxis  the x-value of the vertical axis.
#' @param secondaxis  the y-value of the second axis.
#'
#' @return dataframe of the distances
#' @export
sillydist <- function(firstterm, secondterm, firstaxis, secondaxis) {
    dataframe <- data.frame(firstterm, secondterm)
    dataframe$x <- (abs(dataframe[,1]) - abs(firstaxis)) / abs(firstaxis)
    dataframe$y <- abs((dataframe[,2] - secondaxis) / secondaxis)
    dataframe$x <- abs(dataframe[,1] / max(dataframe$x))
    dataframe$y <- abs(dataframe[,2] / max(dataframe$y))
    dataframe$dist <- abs(dataframe$x * dataframe$y)
    dataframe$dist <- dataframe$dist / max(dataframe$dist)
    return(dataframe)
}

#' write_xls()  Write a dataframe to an excel spreadsheet sheet.
#'
#' @param type default='xlsx'  whether to use the xlsx or XLConnect package.
#' @param tripledots  the set of arguments given to either xlsx or XLConnect
#'
#' @return an excel workbook
#'
#' @seealso \code{\link{XLConnect}}, \code{\link{xlsx}},
#'
#' @export
#' @examples
#' ## write_xls(dataframe, "hpgl_data")
write_xls <- function(data, sheet="first", file="excel/workbook", overwrite_file=TRUE, overwrite_sheet=TRUE, dated=TRUE, suffix=".xlsx", type="openxlsx", ...) {
    excel_dir <- dirname(file)
    if (!file.exists(excel_dir)) {
        dir.create(excel_dir, recursive=TRUE)
    }

    file <- gsub(pattern="\\.xlsx", replacement="", file, perl=TRUE)
    file <- gsub(pattern="\\.xls", replacement="", file, perl=TRUE)
    filename <- NULL
    if (isTRUE(dated)) {
        timestamp <- format(Sys.time(), "%Y%m%d%H")
        filename <- paste0(file, "-", timestamp, suffix)
    } else {
        filename <- paste0(file, suffix)
    }

    if (file.exists(filename)) {
        if (isTRUE(overwrite_file)) {
            backup_file(filename)
        }
    }

    ret <- NULL
    if (type == 'xlsx') {
        ret <- write_xls_xlsx(data, sheet=sheet, file=filename, overwrite_file=overwrite_file, overwrite_sheet=overwrite_sheet, dated=dated, ...)
    } else if (type == 'openxlsx') {
        ret <- write_xls_openxlsx(data, sheet=sheet, file=filename, overwrite_file=overwrite_file, overwrite_sheet=overwrite_sheet, dated=dated, ...)
    } else {
        ret <- write_xls_xlconnect(data, sheet=sheet, file=filename, overwrite_file=overwrite_file, overwrite_sheet=overwrite_sheet, dated=dated, ...)
    }
    return(ret)
}

#' write_xls_xlconnect()  Write a dataframe to an excel spreadsheet sheet.
#'
#' @param data  a dataframe of information.
#' @param sheet default='first'  the name of an excel sheet in a workbook.
#' @param file default='excel/workbook.xls'  an excel workbook to which to write.
#' @param rowname default='rownames'  what will the rownames be?
#' @param overwritefile default=FALSE  overwrite the xls file with this new data, or use the original?
#' @param overwritesheet default=TRUE  overwrite the xls sheet with this new data?  (if true it will make a backup sheet .bak).
#'
#' @return NULL, on the say it creates a workbook if necessary,
#' creates a sheet, and writes the data to it.
#'
#' @seealso \code{\link{loadWorkbook}}, \code{\link{createSheet}},
#' \code{\link{writeWorksheet}}, \code{\link{saveWorkbook}}
#'
#' @examples
#' ## write_xls_xlconnect(dataframe, "hpgl_data")
#' ## Sometimes it is a good idea to go in and delete the workbook and
#' ## re-create it if this is used heavily, because it will get crufty.
write_xls_xlconnect <- function(data, sheet="first", file="excel/workbook.xls", overwrite_file=TRUE, overwrite_sheet=TRUE, dated=TRUE, suffix=".xls", ...) {
    xls <- XLConnect::loadWorkbook(file, create=TRUE)
    if (isTRUE(overwritesheet)) {
        newname <- paste0(sheet, '.bak')
        if (existsSheet(xls, newname)) {
            XLConnect::removeSheet(xls, sheet=newname)
        }
        if (existsSheet(xls, sheet)) {
            XLConnect::renameSheet(xls, sheet=sheet, newName=newname)
        }
    }

    XLConnect::createSheet(xls, name=sheet)
    if (is.na(rowname)) {
        XLConnect::writeWorksheet(xls, data, sheet=sheet)
    } else {
        XLConnect::writeWorksheet(xls, data, sheet=sheet, rowname=rowname)
    }
    ret <- XLConnect::saveWorkbook(xls)
    return(ret)
}

#' write_xls_xlsx()  Write a dataframe to an excel spreadsheet sheet using xlsx.
#'
#' @param data  a dataframe of information.
#' @param sheet default='first'  the name of an excel sheet in a workbook.
#' @param file default='excel/workbook.xls'  an excel workbook to which to write.
#' @param header default='Data Table'  a header to prepend to the printed worksheet.
#' @param rownames default=TRUE  add the rownames to the left side of the table?
#' @param colnames default=TRUE  add the column names to the top of the table?
#' @param overwritefile default=FALSE  overwrite the xls file with this new data, or use the original?
#' @param dated default=TRUE  append a dated suffix to the filename.
#' @param suffix default='.xlsx'
#'
#' @return NULL, on the say it creates a workbook if necessary,
#' creates a sheet, and writes the data to it.
#'
#' @seealso \code{\link{xlsx.addTable}}
#'
#' @examples
#' ## write_xls_xlsx(dataframe)
write_xls_xlsx <- function(data, sheet="first", file="excel/workbook.xls", overwrite_file=TRUE, overwrite_sheet=TRUE, dated=TRUE, suffix=".xlsx", ...) {
    ## require.auto("kassambara/r2excel")
    wb <- xlsx::createWorkbook(type="xlsx")
    sheet <- xlsx::createSheet(wb, sheetName=sheet)
    r2excel::xlsx.addHeader(wb, sheet, value=header, color="darkblue")
    r2excel::xlsx.addLineBreak(sheet, 1)
    r2excel::xlsx.addTable(wb, sheet, data, col.names=colnames, row.names=rownames, fontColor="black",
                           fontSize=12, rowFill=c("white","lightgrey"))
    res <- saveWorkbook(wb, file)
    return(res)
}

write_xls_openxlsx <- function(data, sheet="first", file="excel/workbook.xlsx", overwrite_file=TRUE, overwrite_sheet=TRUE, dated=TRUE, suffix=".xlsx", ...) {
    arglist = list(...)

    wb <- openxlsx::createWorkbook(creator="atb")
    openxlsx::addWorksheet(wb, sheetName=sheet)
    hs1 <- openxlsx::createStyle(fontColour="#000000", halign="LEFT", textDecoration="bold", border="Bottom", fontSize="30")
    new_row <- 1
    if (!is.null(arglist$title)) {
        openxlsx::writeData(wb, sheet, x=arglist$title, startRow=new_row)
        openxlsx::addStyle(wb, sheet, hs1, new_row, 1)
        new_row <- new_row + 1
    }

    ## I might have run into a bug in openxlsx, in WorkbookClass.R there is a call to is.nan() for a data.frame
    ## and it appears to me to be called oddly and causing problems
    openxlsx::writeDataTable(wb, sheet, x=data, tableStyle="TableStyleMedium9", startRow=new_row, rowNames=TRUE)
    new_row <- new_row + nrow(data) + 2

    openxlsx::setColWidths(wb, sheet=sheet, widths="auto", cols=1:ncol(data))
    openxlsx::saveWorkbook(wb, file, overwrite=overwrite_sheet)

    return(new_row)
}

my_writeDataTable <- function(wb, sheet, x, startCol=1, startRow=1, xy=NULL,
                              colNames=TRUE, rowNames=FALSE, tableStyle="TableStyleLight9",
                              tableName=NULL, headerStyle=NULL, withFilter=TRUE,
                              keepNA=FALSE) {
    if (!is.null(xy)) {
        if (length(xy) != 2) {
            stop("xy parameter must have length 2")
        }
        startCol <- xy[[1]]
        startRow <- xy[[2]]
    }
    if (!"Workbook" %in% class(wb))
        stop("First argument must be a Workbook.")
    if (!"data.frame" %in% class(x))
        stop("x must be a data.frame.")
    if (!is.logical(colNames))
        stop("colNames must be a logical.")
    if (!is.logical(rowNames))
        stop("rowNames must be a logical.")
    if (!is.null(headerStyle) & !"Style" %in% class(headerStyle))
        stop("headerStyle must be a style object or NULL.")
    if (!is.logical(withFilter))
        stop("withFilter must be a logical.")
    if (is.null(tableName)) {
        tableName <- paste0("Table", as.character(length(wb$tables) + 3L))
    } else if (tableName %in% attr(wb$tables, "tableName")) {
        stop(sprintf("Table with name '%s' already exists!", tableName))
    } else if (grepl("[^A-Z0-9_]", tableName[[1]], ignore.case = TRUE)) {
        stop("Invalid characters in tableName.")
    } else if (grepl("^[A-Z]{1,3}[0-9]+$", tableName)) {
        stop("tableName cannot look like a cell reference.")
    } else {
        tableName <- tableName
    }
    exSciPen <- getOption("scipen")
    options(scipen=10000)
    on.exit(options(scipen=exSciPen), add=TRUE)
    if (!is.numeric(startCol)) {
        startCol <- convertFromExcelRef(startCol)
    }
    startRow <- as.integer(startRow)
    if (rowNames) {
        x <- cbind(data.frame(`row names` = rownames(x)), x)
    }
    validNames <- c("none", paste0("TableStyleLight", 1:21),
                    paste0("TableStyleMedium", 1:28), paste0("TableStyleDark", 1:11))
    if (!tolower(tableStyle) %in% tolower(validNames)) {
        stop("Invalid table style.")
    } else {
        tableStyle <- validNames[grepl(paste0("^", tableStyle, "$"),
                                       validNames, ignore.case = TRUE)]
    }
    tableStyle <- na.omit(tableStyle)
    if (length(tableStyle) == 0) {
        stop("Unknown table style.")
    }
    if ("Style" %in% class(headerStyle)) {
        addStyle(wb = wb, sheet = sheet, style = headerStyle, rows = startRow,
                 cols = 0:(ncol(x) - 1L) + startCol, gridExpand = TRUE)
    }
    showColNames <- colNames
    if (colNames) {
        colNames <- colnames(x)
        if (any(duplicated(tolower(colNames)))) {
            stop("Column names of x must be case-insensitive unique.")
        }
        char0 <- nchar(colNames) == 0
        if (any(char0)) {
            colNames[char0] <- colnames(x)[char0] <- paste0("Column", which(char0))
        }
    } else {
        colNames <- paste0("Column", 1:ncol(x))
        names(x) <- colNames
    }
    if (nrow(x) == 0) {
        x <- rbind(x, matrix("", nrow = 1, ncol = ncol(x)))
        names(x) <- colNames
    }
    ref1 <- paste0(.Call("openxlsx_convert2ExcelRef", startCol,
                         LETTERS, PACKAGE = "openxlsx"), startRow)
    ref2 <- paste0(.Call("openxlsx_convert2ExcelRef", startCol + ncol(x) - 1,
                         LETTERS, PACKAGE = "openxlsx"), startRow + nrow(x))
    ref <- paste(ref1, ref2, sep = ":")
    if (length(wb$tables) > 0) {
        tableSheets <- attr(wb$tables, "sheet")
        if (sheet %in% tableSheets) {
            exTable <- wb$tables[tableSheets %in% sheet]
            newRows <- c(startRow, startRow + nrow(x) - 1L + 1)
            newCols <- c(startCol, startCol + ncol(x) - 1L)
            rows <- lapply(names(exTable), function(rectCoords) as.numeric(unlist(regmatches(rectCoords, gregexpr("[0-9]+", rectCoords)))))
            cols <- lapply(names(exTable), function(rectCoords) convertFromExcelRef(unlist(regmatches(rectCoords, gregexpr("[A-Z]+", rectCoords)))))
            for (i in 1:length(exTable)) {
                exCols <- cols[[i]]
                exRows <- rows[[i]]
                if (exCols[1] < newCols[2] & exCols[2] > newCols[1] &
                    exRows[1] < newRows[2] & exRows[2] > newRows[1]) {
                    stop("Cannot overwrite existing table.")
                }
            }
        }
    }
    colClasses <- lapply(x, function(x) tolower(class(x)))
    openxlsx:::classStyles(wb, sheet = sheet, startRow = startRow, startCol = startCol, colNames = TRUE, nRow = nrow(x), colClasses = colClasses)
    wb$writeData(df=x, colNames=TRUE, sheet=sheet, startRow=startRow,
                 startCol=startCol, colClasses=colClasses,
                 hlinkNames=NULL, keepNA = keepNA)
    colNames <- replaceIllegalCharacters(colNames)
    wb$buildTable(sheet, colNames, ref, showColNames, tableStyle, tableName, withFilter[1])
}


#' backup_file()  Make a backup of an existing file with n revisions, like VMS!
#'
#' @param file  the file to backup.
#' @param backups default=10  how many revisions?
backup_file <- function(backup_file, backups=10) {
    if (file.exists(backup_file)) {
        for (i in backups:01) {
            j <- i + 1
            i <- sprintf("%02d", i)
            j <- sprintf("%02d", j)
            test <- paste0(backup_file, ".", i)
            new <- paste0(backup_file, ".", j)
            if (file.exists(test)) {
                file.rename(test, new)
            }
        }
        newfile <- paste0(backup_file, ".", i)
        message(paste0("Renaming ", backup_file, " to ", newfile, "."))
        file.rename(backup_file, newfile)
    } else {
        message("The file does not yet exist.")
    }
}

#' saveme()  Load a backup rdata file
#'
#' @param dir default='savefiles'  the directory containing the RData.rda.xz file.
#'
#' I often use R over a sshfs connection, sometimes with significant latency, and
#' I want to be able to save/load my R sessions relatively quickly.
#' Thus this function uses my backup directory to load its R environment.
loadme <- function(dir="savefiles") {
    savefile <- paste0(getwd(), "/", dir, "/RData.rda.xz")
    message(paste0("Loading the savefile: ", savefile))
    load_string <- paste0("load('", savefile, "', envir=globalenv())")
    message(paste0("Command run: ", load_string))
    eval(parse(text=load_string))
}

#' saveme()  Make a backup rdata file for future reference
#'
#' @param dir  the directory to save the Rdata file.
#' @param backups default=10  how many revisions?
#'
#' I often use R over a sshfs connection, sometimes with significant latency, and
#' I want to be able to save/load my R sessions relatively quickly.
#' Thus this function uses pxz to compress the R session maximally and relatively fast.
saveme <- function(directory="savefiles", backups=4) {
    environment()
    if (!file.exists(directory)) {
        dir.create(directory)
    }
    savefile <- paste0(getwd(), "/", directory, "/RData.rda.xz")
    message(paste0("The savefile is: ", savefile))
    backup_file(savefile, backups=backups)
    ## The following save strings work:
    ## save_string <- paste0("save(list=ls(all.names=TRUE, envir=globalenv()), envir=globalenv(), file='", savefile, "')")
    ## save_string <- paste0("con <- base::pipe(paste0('pigz -p8 > ", savefile, "'), 'wb');\n save(list=ls(all.names=TRUE, envir=globalenv(), envir=globalenv(), file=con);\n close(con)")
    save_string <- paste0("con <- base::pipe(paste0('pxz -T4 > ", savefile, "'), 'wb');\n save(list=ls(all.names=TRUE, envir=globalenv()), envir=globalenv(), file=con, compress=FALSE);\n close(con)")
    message(paste0("The save string is: ", save_string))
    eval(parse(text=save_string))
}

## EOF
