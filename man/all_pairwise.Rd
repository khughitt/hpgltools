% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/de_shared.r
\name{all_pairwise}
\alias{all_pairwise}
\title{Perform limma, DESeq2, EdgeR pairwise analyses.}
\usage{
all_pairwise(input = NULL, conditions = NULL, batches = NULL,
  model_cond = TRUE, modify_p = FALSE, model_batch = TRUE,
  model_intercept = FALSE, extra_contrasts = NULL, alt_model = NULL,
  libsize = NULL, test_pca = TRUE, annot_df = NULL, parallel = TRUE,
  ...)
}
\arguments{
\item{input}{Dataframe/vector or expt class containing count tables, normalization state, etc.}

\item{conditions}{Factor of conditions in the experiment.}

\item{batches}{Factor of batches in the experiment.}

\item{model_cond}{Include condition in the model?  This is likely always true.}

\item{modify_p}{Depending on how it is used, sva may require a modification of the p-values.}

\item{model_batch}{Include batch in the model?  This may be true/false/"sva" or other methods
supported by get_model_adjust().}

\item{model_intercept}{Use an intercept model instead of cell means?}

\item{extra_contrasts}{Optional extra contrasts beyone the pairwise comparisons.  This can be
pretty neat, lets say one has conditions A,B,C,D,E and wants to do (C/B)/A and (E/D)/A or
(E/D)/(C/B) then use this with a string like: "c_vs_b_ctrla = (C-B)-A, e_vs_d_ctrla =
(E-D)-A, de_vs_cb = (E-D)-(C-B)".}

\item{alt_model}{Alternate model to use rather than just condition/batch.}

\item{libsize}{Library size of the original data to help voom().}

\item{test_pca}{Perform some tests of the data before/after applying a given batch effect.}

\item{annot_df}{Annotations to add to the result tables.}

\item{parallel}{Use dopar to run limma, deseq, edger, and basic simultaneously.}

\item{...}{Picks up extra arguments into arglist, currently only passed to write_limma().}
}
\value{
A list of limma, deseq, edger results.
}
\description{
This takes an expt object, collects the set of all possible pairwise comparisons, sets up
experimental models appropriate for the differential expression analyses, and performs them.
}
\details{
Tested in test_29de_shared.R
This runs limma_pairwise(), deseq_pairwise(), edger_pairwise(), basic_pairwise() each in turn.
It collects the results and does some simple comparisons among them.
}
\examples{
 \dontrun{
  lotsodata <- all_pairwise(input=expt, model_batch="svaseq")
  summary(lotsodata)
  ## limma, edger, deseq, basic results; plots; and summaries.
 }
}
\seealso{
\pkg{limma} \pkg{DESeq2} \pkg{edgeR}
 \code{link{limma_pairwise}} \code{\link{deseq_pairwise}}
 \code{\link{edger_pairwise}} \code{\link{basic_pairwise}}
}
