% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotation_genbank.r
\name{gbk2txdb}
\alias{gbk2txdb}
\title{Given a genbank accession, make a txDb object along with sequences, etc.}
\usage{
gbk2txdb(accession = "AE009949", savetxdb = FALSE)
}
\arguments{
\item{accession}{Accession to download and import}

\item{savetxdb}{Save a txdb package from this? FIXME THIS DOES NOT WORK.}
}
\value{
List containing a txDb, sequences, and some other stuff which I haven't yet finalized.
}
\description{
Let us admit it, sometimes biomart is a pain.  It also does not have easily accessible data for
microbes.  Genbank does!
}
\details{
Tested in test_40ann_biomartgenbank.R and test_70expt_spyogenes.R
This just sets some defaults for the genbankr service in order to facilitate downloading
genomes and such from genbank and dumping them into a local txdb instance.
}
\examples{
\dontrun{
 txdb_result <- gbk2txdb(accession="AE009948", savetxdb=TRUE)
}
}
\seealso{
\pkg{genbankr} \pkg{rentrez}
 \code{\link[genbankr]{import}}
}
