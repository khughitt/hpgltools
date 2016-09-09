#' Given a genbank accession, make a txDb object along with sequences, etc.
#'
#' Let us admit it, sometimes biomart is a pain.  It also does not have easily accessible data for
#' microbes.  Genbank does!
#'
#' @param accession Accession to download and import
#' @return List containing a txDb, sequences, and some other stuff which I haven't yet finalized.
#' @export
gbk2txdb <- function(accession="AE009949") {
    gbk <- NULL
    if (file.exists(paste0(accession, ".gb"))) {
        gbk <- genbankr::import(accession)
        ## The file exists, read it
    } else {
        tt <- sm(require.auto("rentrez"))
        gba <- genbankr::GBAccession(accession)
        gbk <- genbankr::readGenBank(gba, partial=FALSE)
    }
    gbr <- genbankr::makeTxDbFromGenBank(gbk)
    seq <- genbankr::getSeq(gbk)
    others <- genbankr::otherFeatures(gbk)
    genes <- genbankr::genes(gbk)
    exons <- genbankr::exons(gbk)
    intergenic <- genbankr::intergenic(gbk)
    cds <- genbankr::cds(gbk)
    ret <- list(
        "others" = others,
        "exons" = exons,
        "cds" = cds,
        "intergenic" = intergenic,
        "genes" = genes,
        "txdb" = gbr,
        "seq" = seq)
    return(ret)
}

#' Extract some useful information from a gbk imported as a txDb.
#'
#' Maybe this should get pulled into the previous function?
#'
#' @param gbr TxDb object to poke at.
#' @return Granges data
#' @export
gbk_annotations <- function(gbr) {
    chromosomes <- GenomeInfoDb::seqlevels(gbr)
    genes <- AnnotationDbi::keys(gbr)
    keytypes <- AnnotationDbi::keytypes(gbr)
    columns <- AnnotationDbi::columns(gbr)
    lengths <- AnnotationDbi::select(gbr, columns=c("CDSNAME", "CDSCHROM","CDSEND","CDSSTART","CDSSTRAND","CDSID", "TXNAME"), keys=genes, keytype="GENEID")
    lengths[["length"]] <- abs(lengths[["CDSSTART"]] - lengths[["CDSEND"]])
    granges <- GenomicFeatures::transcripts(gbr)
    return(granges)
}


#' A genbank accession downloader scurrilously stolen from ape
#'
#' This takes and downloads genbank accessions
#'
#' @param accession An accession!
#' @param write  Write the files?  Otherwise return a list of the strings
#' @return A list containing the number of files downloaded and the character strings actually acquired
#' @export
download_gbk <- function(accessions, write=TRUE) {
    N <- length(accession)
    nrequest <- N%/%400 + as.logical(N%%400)
    downloaded <- character(0)
    num_downloaded <- 0
    strings <- list()
    for (i in 1:nrequest) {
        a <- (i - 1) * 400 + 1
        b <- 400 * i
        if (i == nrequest) {
            b <- N
        }

        URL <- paste0("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=",
                      paste(accessions[a:b], collapse = ","), "&rettype=gb&retmode=text&report=gbwithparts")
        scanned <- try(scan(file=URL, what="", sep="\n", quiet=TRUE))
        if (class(scanned) != "try-error") {
            downloaded <- c(downloaded, scanned)
            num_downloaded <- num_downloaded + 1
        }
        strings[i] <- downloaded
        if (isTRUE(write)) {
            file_connection <- file(paste0(accessions[a], ".gb"))
            writeLines(downloaded, file_connection)
            close(file_connection)
        }
    } ## End of for loop
    retlist <- list(
        "num_success" = num_downloaded,
        "strings" = strings)
    return(retlist)
}
