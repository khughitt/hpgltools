% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/normalize_batch.r
\name{counts_from_surrogates}
\alias{counts_from_surrogates}
\title{A single place to extract count tables from a set of surrogate variables.}
\usage{
counts_from_surrogates(data, adjust, design = NULL)
}
\arguments{
\item{data}{Original count table, may be an expt/expressionset or df/matrix.}

\item{adjust}{Surrogates with which to adjust the data.}

\item{design}{Experimental design if it is not included in the expressionset.}
}
\value{
A data frame of adjusted counts.
}
\description{
Given an initial set of counts and a series of surrogates, what would the resulting count table
look like? Hopefully this function answers that question.
}
\seealso{
\pkg{Biobase}
}
