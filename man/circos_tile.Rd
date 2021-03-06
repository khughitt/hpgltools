% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_circos.r
\name{circos_tile}
\alias{circos_tile}
\title{Write tiles of arbitrary categorical point data in circos.}
\usage{
circos_tile(df, annot_df, cfgout = "circos/conf/default.conf",
  colname = "logFC", chr = "chr1", colors = NULL, outer = 0.9,
  width = 0.08, spacing = 0)
}
\arguments{
\item{df}{Dataframe with starts/ends and the floating point information.}

\item{annot_df}{Annotation data frame defining starts/stops.}

\item{cfgout}{Master configuration file to write.}

\item{colname}{Name of the column with the data of interest.}

\item{chr}{Name of the chromosome (This currently assumes a bacterial chromosome)}

\item{colors}{Colors of the data.}

\item{outer}{Floating point radius of the circle into which to place the categorical data.}

\item{width}{Width of each tile.}

\item{spacing}{Radial distance between outer, inner, and inner to whatever follows.}
}
\value{
Radius after adding the histogram and the spacing.
}
\description{
This function tries to make the writing circos tiles easier.  Like
circos_plus_minus() and circos_hist() it works in 3 stages,
It writes out a data file using cfgout as a basename and the data
from df in the circos histogram format into
circos/data/bob_tile.txt
It then writes out a configuration plot stanza in
circos/conf/bob_tile.conf
and finally adds an include to circos/bob.conf
}
