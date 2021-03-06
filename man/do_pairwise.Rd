% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/de_shared.r
\name{do_pairwise}
\alias{do_pairwise}
\title{Generalize pairwise comparisons}
\usage{
do_pairwise(type, ...)
}
\arguments{
\item{type}{Which type of pairwise comparison to perform}

\item{...}{The set of arguments intended for limma_pairwise(), edger_pairwise(), and friends.}
}
\value{
The result from limma/deseq/edger/basic
}
\description{
I want to multithread my pairwise comparisons, this is the first step in doing so.
}
\details{
Used to make parallel operations easier.
}
\seealso{
\code{\link{limma_pairwise}} \code{\link{edger_pairwise}} \code{\link{deseq_pairwise}}
 \code{\link{basic_pairwise}}
}
