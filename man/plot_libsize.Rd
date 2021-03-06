% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_bar.r
\name{plot_libsize}
\alias{plot_libsize}
\title{Make a ggplot graph of library sizes.}
\usage{
plot_libsize(data, condition = NULL, colors = NULL, names = NULL,
  text = TRUE, title = NULL, yscale = NULL, ...)
}
\arguments{
\item{data}{Expt, dataframe, or expressionset of samples.}

\item{condition}{vector of sample condition names.}

\item{colors}{Color scheme if the data is not an expt.}

\item{names}{Alternate names for the x-axis.}

\item{text}{Add the numeric values inside the top of the bars of the plot?}

\item{title}{Title for the plot.}

\item{yscale}{Whether or not to log10 the y-axis.}

\item{...}{More parameters for your good time!}
}
\value{
a ggplot2 bar plot of every sample's size
}
\description{
It is often useful to have a quick view of which samples have more/fewer reads.  This does that
and maintains one's favorite color scheme and tries to make it pretty!
}
\examples{
\dontrun{
 libsize_plot <- plot_libsize(expt=expt)
 libsize_plot  ## ooo pretty bargraph
}
}
\seealso{
\pkg{ggplot2}
 \code{\link[ggplot2]{geom_bar}} \code{\link[ggplot2]{geom_text}}
 \code{\link{prettyNum}} \code{\link[ggplot2]{scale_y_log10}}
}
