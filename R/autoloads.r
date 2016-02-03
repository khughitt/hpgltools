## Time-stamp: <Tue Feb  2 18:55:43 2016 Ashton Trey Belew (abelew@gmail.com)>

#' \code{require.auto()}  Automatic loading and/or installing of packages.
#'
#' Load a library, install it first if necessary.
#'
#' This was taken from:
#' http://sbamin.com/2012/11/05/tips-for-working-in-r-automatically-install-missing-package/
#'
#' @param lib  string name of a library
#' @param github_path default=NULL  an optional github username/path.
#' @param verbose default=FALSE  print some information while loading.
#' @param update default=FALSE  update packages?
#'
#' @return NULL currently
#' @seealso \code{\link[BiocInstaller]{biocLite}} and \code{\link{install.packages}}
#' @export
#' @examples
#' \donotrun{
#' require.auto("ggplot2")
#'}
require.auto <- function(lib, github_path=NULL, verbose=FALSE, update=FALSE) {
    local({r <- getOption("repos")
           r["CRAN"] <- "http://cran.r-project.org"
           options(repos=r)
       })
    if (isTRUE(update)) {
        update.packages(ask=FALSE)
    }
    if (isTRUE(lib %in% .packages(all.available=TRUE))) {
        if (verbose) {
            message(sprintf("Loading %s", lib))
        }
        eval(parse(text=paste("suppressPackageStartupMessages(require(", lib, "))", sep="")))
    } else {
        if (is.null(github_path)) {
            source("http://bioconductor.org/biocLite.R")
            ##biocLite(character(), ask=FALSE) # update dependencies, if any.
            eval(parse(text=paste("biocLite('", lib, "')", sep="")))
            if (verbose) {
                message(sprintf("Loading %s", lib))
            }
            eval(parse(text=paste("suppressPackageStartupMessages(require(", lib, "))", sep="")))
            ## eval(parse(text=paste("install.packages('", lib, "')", sep="")))
        } else {
            devtools::install_github(github_path)
        }
    }
}

autoloads_ontology <- function() {
    require.auto("clusterProfiler")
    require.auto("GO.db")
    require.auto("DOSE")
    require.auto("goseq")
    require.auto("GOstats")
    require.auto("GSEABase")
    require.auto("KEGGREST")
    require.auto("pathview")
    require.auto("RamiGO")
    require.auto("topGO")
}

autoloads_genome <- function() {
    require.auto("biomaRt")
    require.auto("BSgenome")
    require.auto("genomeIntervals")
    require.auto("rtracklayer")
}

autoloads_elsayedlab <- function() {
    require.auto("OrganismDbi")
    require.auto("TxDb.TcruziCLBrener.tritryp24.genes", "elsayed-lab/TxDb.TcruziCLBrener.tritryp24.genes")
    require.auto("TxDb.TcruziCLBrenerEsmer.tritryp24.genes", "elsayed-lab/TxDb.TcruziCLBrenerEsmer.tritryp24.genes")
    require.auto("TxDb.TcruziCLBrenerNonEsmer.tritryp9.genes", "elsayed-lab/TxDb.TcruziCLBrenerNonEsmer.tritryp9.genes")
    require.auto("TxDb.LmajorFriedlin.tritryp9.genes", "elsayed-lab/TxDb.LmajorFriedlin.tritryp9.genes")

    require.auto("BSgenome.Lmajor.friedlin", "elsayed-lab/BSgenome.Lmajor.friedlin")
    require.auto("BSgenome.Tcruzi.clbrener", "elsayed-lab/BSgenome.Tcruzi.clbrener")
    require.auto("BSgenome.Tcruzi.esmeraldo", "elsayed-lab/BSgenome.Tcruzi.esmeraldo")
    require.auto("BSgenome.Tcruzi.nonesmeraldo", "elsayed-lab/BSgenome.Tcruzi.nonesmeraldo")
    require.auto("org.TcCLB.nonesmer.tritryp.db", "elsayed-lab/org.TcCLB.nonesmer.tritryp.db")
    require.auto("org.TcCLB.esmer.tritryp.db", "elsayed-lab/org.TcCLB.esmer.tritryp.db")
    require.auto("org.TcCLB.tritryp.db", "elsayed-lab/org.TcCLB.tritryp.db")
    require.auto("org.LmjF.tritryp.db", "elsayed-lab/org.LmjF.tritryp.db")
    require.auto("Trypanosoma.cruzi.CLBrener", "elsayed-lab/Trypanosoma.cruzi.CLBrener")
    require.auto("Trypanosoma.cruzi.CLBrener.Esmeraldo", "elsayed-lab/Trypanosoma.cruzi.CLBrener.Esmeraldo")
    require.auto("Leishmania.major.Friedlin", "elsayed-lab/Leishmania.major.Friedlin")
}

autoloads_deseq <- function() {
    require.auto("preprocessCore")
    require.auto("DESeq2")
    require.auto("DESeq")
    require.auto("edgeR")
    require.auto("limma")
    require.auto("sva")
    require.auto("pasilla")  ## for cbcbSEQ
    require.auto("preprocessCore") ## for cbcbSEQ
    require.auto("cbcbSEQ", "kokrah/cbcbSEQ")  ## cbcbSeq has to be loaded last because its DESCRIPTION file is missing a couple of dependencies
##    require.auto("qlasso", "kokrah/qsmooth")
}

autoloads_graphs <- function() {
    require.auto("Cairo")
    require.auto("directlabels")
    require.auto("ggplot2")
    require.auto("googleVis")
    require.auto("gplots")
    require.auto("grid")
    require.auto("gridExtra")
    require.auto("RColorBrewer")
    require.auto("Rgraphviz")
}

autoloads_helpers <- function() {
    require.auto("MASS")
    require.auto("mgcv")
    require.auto("Matrix")
    require.auto("matrixStats")
    require.auto("devtools")
    require.auto("BiocParallel")
    require.auto("data.table")
    require.auto("gtools")
    require.auto("hash")
    require.auto("knitcitations")
    require.auto("knitr")
    require.auto("knitrBootstrap", "jimhester/knitrBootstrap")
    require.auto("methods")
    require.auto("plyr")
    require.auto("RCurl")
    require.auto("reshape")
    require.auto("rjson")
    require.auto("rmarkdown")
    require.auto("roxygen2")
    require.auto("testthat")
    require.auto("tools")
    require.auto("openxlsx")
    require.auto("xtable")
}

autoloads_stats <- function() {
    require.auto("multtest")
    require.auto("qvalue")
    require.auto("robust")
}

autoloads_misc <- function() {
    require.auto("motifRG")
    require.auto("Rsamtools")
    require.auto("scales")
    require.auto("seqinr")
    require.auto("lianos/seqtools/R/pkg")
}

#' Automatic loading of stuff I use, I am deprecating this now.
#'
#' @return NULL currently
#' @seealso \code{\link[BiocInstaller]{biocLite}} and \code{\link{install.packages}}
#' @export
autoloads_all <- function(update=FALSE) {
    autoloads_helpers()
    autoloads_misc()
    autoloads_genome()
    autoloads_graphs()
    autoloads_stats()
    autoloads_deseq()
    autoloads_ontology()
    ##cite_options(tooltip=TRUE)
    ##cleanbib()
    options(gvis.plot.tag="chart")
    mainfont = "Helvetica"
    ##Cairo()
    ##CairoFonts(regular = paste(mainfont, "style=Regular", sep = ":"),
    ##           bold = paste(mainfont, "style=Bold", sep = ":"),
    ##           italic = paste("SimSun", "style=Regular", sep = ":"),
    ##           bolditalic = paste(mainfont, "style=Bold Italic,BoldItalic", sep = ":"))
    ##pdf = CairoPDF
    ##png = CairoPNG
    ##x11 = CairoX11
    ##svg = CairoSVG
    if (isTRUE(update)) {
        update.packages()
    }
}

## EOF
