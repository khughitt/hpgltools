% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_biomart.r
\name{load_biomart_annotations}
\alias{load_biomart_annotations}
\title{Extract annotation information from biomart.}
\usage{
load_biomart_annotations(species = "hsapiens", overwrite = FALSE,
  do_save = TRUE, host = "dec2016.archive.ensembl.org",
  drop_haplotypes = TRUE, trymart = "ENSEMBL_MART_ENSEMBL",
  gene_requests = c("ensembl_gene_id", "version", "ensembl_transcript_id",
  "transcript_version", "hgnc_symbol", "description", "gene_biotype"),
  length_requests = c("ensembl_transcript_id", "cds_length",
  "chromosome_name", "strand", "start_position", "end_position"),
  include_lengths = TRUE)
}
\arguments{
\item{species}{Choose a species.}

\item{overwrite}{Overwite an existing save file?}

\item{do_save}{Create a savefile of annotations for future runs?}

\item{host}{Ensembl hostname to use.}

\item{trymart}{Biomart has become a circular dependency, this makes me sad, now to list the
marts, you need to have a mart loaded...}

\item{gene_requests}{Set of columns to query for description-ish annotations.}

\item{length_requests}{Set of columns to query for location-ish annotations.}

\item{include_lengths}{Also perform a search on structural elements in the genome?}
}
\value{
Df of some (by default) human annotations.
}
\description{
Biomart is an amazing resource of information, but using it is a bit annoying.  This function
hopes to alleviate some common headaches.
}
\details{
Tested in test_40ann_biomart.R
This goes to some lengths to find the relevant tables in biomart.  But biomart is incredibly
complex and one should carefully inspect the output if it fails to see if there are more
appropriate marts, datasets, and columns to download.
}
\examples{
\dontrun{
 tt = get_biomart_annotations()
}
}
\seealso{
\pkg{biomaRt}
 \code{\link[biomaRt]{listDatasets}} \code{\link[biomaRt]{getBM}}
}
