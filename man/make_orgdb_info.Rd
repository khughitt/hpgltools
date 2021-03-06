% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_tritrypdb.r
\name{make_orgdb_info}
\alias{make_orgdb_info}
\title{Generate the (large) set of data frames required to make functional OrgDb/TxDb/OrganismDbi
objects.}
\usage{
make_orgdb_info(gff, txt = NULL, kegg = TRUE)
}
\arguments{
\item{gff}{File to read gff annotations from.}

\item{txt}{File to read txt annotations from.}

\item{kegg}{Boolean deciding whether to try for KEGG data.}
}
\value{
List containing gene information (likely from the txt file), chromosome information
  (gff file), gene types (gff file), gene ontology information, and potentially kegg information.
}
\description{
This function should probably be split into a few more pieces as it is pretty unwieldy at the
moment.
}
\examples{
\dontrun{
 orgdb_data <- make_orgdb_info(gff="lmajor.gff", txt="lmajor.txt")
}
}
\seealso{
\pkg{rtracklayer} \pkg{GenomicRanges}
}
