% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_eupathdb.r
\name{make_eupath_bsgenome}
\alias{make_eupath_bsgenome}
\title{Generate a BSgenome package from the eupathdb.}
\usage{
make_eupath_bsgenome(species = "Leishmania major strain Friedlin",
  dir = ".", overwrite = FALSE, metadata = NULL, ...)
}
\arguments{
\item{species}{Species to create.}

\item{dir}{Working directory.}

\item{overwrite}{Rewrite an existing package directory.}

\item{metadata}{Dataframe of the required metadata.}

\item{...}{Extra arguments for downloading metadata when not provided.}
}
\value{
Currently just TRUE or an error.
}
\description{
Since we go to the trouble to try and generate nice orgdb/txdb/organismdbi packages, it
seems to me that we ought to also be able to make a readable genome package.  I should
probably use some of the logic from this to make the organismdbi generator smarter.
}
