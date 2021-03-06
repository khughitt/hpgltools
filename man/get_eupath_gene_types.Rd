% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_eupathdb.r
\name{get_eupath_gene_types}
\alias{get_eupath_gene_types}
\title{Returns a mapping of gene ID to gene type for a specified organism}
\usage{
get_eupath_gene_types(provider = "TriTrypDB", species = "Leishmania major",
  dir = ".")
}
\arguments{
\item{species}{Full name of organism, as used by EuPathDB APIs}

\item{dir}{Where to put the downloaded data?}

\item{data_provider}{Name of data provider to query (e.g. 'TriTrypDB')}
}
\value{
Dataframe with 'GID' and 'TYPE' columns.
}
\description{
Returns a mapping of gene ID to gene type for a specified organism
}
\author{
Keith Hughitt
}
