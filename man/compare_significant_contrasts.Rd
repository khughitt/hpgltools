% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/de_shared.r
\name{compare_significant_contrasts}
\alias{compare_significant_contrasts}
\title{Implement a cleaner version of 'subset_significants' from analyses with Maria Adelaida.}
\usage{
compare_significant_contrasts(sig_tables, compare_by = "deseq",
  contrasts = c(1, 2, 3))
}
\arguments{
\item{sig_tables}{A set of significance tables to poke at.}

\item{compare_by}{Use which program for the comparisons?}

\item{contrasts}{A list of contrasts to compare.}
}
\description{
This should provide nice venn diagrams and some statistics to compare 2 or 3
contrasts in a differential expression analysis.
}
