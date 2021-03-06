% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/de_edger.r
\name{write_edger}
\alias{write_edger}
\title{Writes out the results of a edger search using write_de_table()}
\usage{
write_edger(data, ...)
}
\arguments{
\item{data}{Output from deseq_pairwise()}

\item{...}{Options for writing the xlsx file.}
}
\description{
Looking to provide a single interface for writing tables from edger and friends.
}
\details{
Tested in test_26edger.R
}
\examples{
\dontrun{
 finished_comparison <- edger_pairwise(expressionset)
 data_list <- write_edger(finished_comparison)
}
}
\seealso{
\pkg{limma}
 \code{\link[limma]{toptable}} \code{\link{write_xls}}
}
