% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/model_pca.r
\name{pcRes}
\alias{pcRes}
\title{Compute variance of each principal component and how they correlate with batch and cond}
\usage{
pcRes(v, d, condition = NULL, batch = NULL)
}
\arguments{
\item{v}{from makeSVD}

\item{d}{from makeSVD}

\item{condition}{factor describing experiment}

\item{batch}{factor describing batch}
}
\value{
A dataframe containig variance, cum. variance, cond.R-sqrd, batch.R-sqrd
}
\description{
This was copy/pasted from cbcbSEQ
https://github.com/kokrah/cbcbSEQ/blob/master/R/explore.R
}
\seealso{
\code{\link{plot_pca}}
}
