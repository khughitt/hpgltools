% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/expt.r
\name{exclude_genes_expt}
\alias{exclude_genes_expt}
\title{Exclude some genes given a pattern match}
\usage{
exclude_genes_expt(expt, column = "txtype", method = "remove", ids = NULL,
  patterns = c("snRNA", "tRNA", "rRNA"), ...)
}
\arguments{
\item{expt}{Expressionset containing expt object.}

\item{column}{fData column to use for subsetting.}

\item{method}{Either remove explicit rows, or keep them.}

\item{patterns}{Character list of patterns to remove/keep}

\item{...}{Extra arguments are passed to arglist, currently unused.}
}
\value{
A smaller expt
}
\description{
Because I am too lazy to remember that expressionsets use matrix subsets for [gene,sample]
}
\seealso{
\code{\link{create_expt}}
}
