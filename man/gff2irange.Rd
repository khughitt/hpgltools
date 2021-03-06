% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_gff.r
\name{gff2irange}
\alias{gff2irange}
\title{Extract annotation information from a gff file into an irange object.}
\usage{
gff2irange(gff, type = NULL)
}
\arguments{
\item{gff}{Gff filename.}

\item{type}{Subset to extract.}
}
\value{
Iranges! (useful for getSeq().)
}
\description{
Try to make import.gff a little more robust; I acquire (hopefully) valid gff files from various
sources: yeastgenome.org, microbesonline, tritrypdb, ucsc, ncbi. To my eyes, they all look like
reasonably good gff3 files, but some of them must be loaded with import.gff2, import.gff3, etc.
That is super annoying. Also, I pretty much always just do as.data.frame() when I get something
valid from rtracklayer, so this does that for me, I have another function which returns the
iranges etc.  This function wraps import.gff/import.gff3/import.gff2 calls in try() because
sometimes those functions fail in unpredictable ways.
}
\details{
This is essentially load_gff_annotations(), but returns data suitable for getSet()
}
\examples{
\dontrun{
 library(BSgenome.Tcruzi.clbrener.all)
 tc_clb_all <- BSgenome.Tcruzi.clbrener.all
 cds_ranges <- gff2irange('reference/gff/tcruzi_clbrener.gff.xz', type='CDS')
 cds_sequences <- Biostrings::getSeq(tc_clb_all, cds_ranges)
}
}
\seealso{
\pkg{rtracklayer} \link{load_gff_annotations} \pkg{Biostrings}
 \code{\link[rtracklayer]{import.gff}}
}
