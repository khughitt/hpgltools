start <- as.POSIXlt(Sys.time())
library(testthat)
library(hpgltools)
context("11norm_convert.R: Are normalizations consistent over time (Conversions)?\n")

load("pasilla_df.rda")
## Uses these genes for quick tests
test_genes <- c("FBgn0000014", "FBgn0000008", "FBgn0000017", "FBgn0000018", "FBgn0000024")
## create_expt generates a .Rdata file which may be reread, do so.
pasilla <- new.env()
load("pasilla.Rdata", envir=pasilla)
pasilla_expt <- pasilla[["expt"]]

## Make sure that my invocation of cpm() is the same as edgeR's.
pasilla_convert <- sm(normalize_expt(pasilla_expt, convert="cpm"))
expected <- edgeR::cpm(pasilla_expt[["expressionset"]])
actual <- exprs(pasilla_convert)
test_that("cpm conversions are equivalent?", {
    expect_equal(expected, actual)
})

## Check that the different ways of calling rpkm() are identical
pasilla_convert <- sm(convert_counts(pasilla_expt, convert="rpkm", column="cds_length"))
pasilla_norm <- sm(normalize_expt(pasilla_expt, convert="rpkm", column="cds_length"))
expected <- pasilla_convert[["count_table"]]
actual <- exprs(pasilla_norm)
test_that("calling convert_counts and normalize_expt are equivalent?", {
    expect_equal(expected, actual)
})

## Similarly check that edgeR's rpkm() comes out the same
## Make sure that we remove undefined numbers from fdata(length)
undef <- fData(pasilla_expt)[["cds_length"]] == "undefined"
lengths <- fData(pasilla_expt)[["cds_length"]]
lengths[undef] <- NA
fdata_lengths <- as.vector(as.numeric(lengths))
names(fdata_lengths) <- rownames(fData(pasilla_expt))
expected <- edgeR::rpkm(exprs(pasilla_expt), gene.length=fdata_lengths)
actual <- exprs(pasilla_norm)
test_that("rpkm conversions are equivalent?", {
    expect_equal(expected, actual)
})

## I have a modification of rpkm(), cp_seq_m(), which should give some expected results.
## This is intended to count the number of instances of a given sequence ('TA' by default)
## and normalize based on its relative frequency.  This is useful primarily for tnseq.
tt <- sm(require.auto("BSgenome.Dmelanogaster.UCSC.dm6"))
tt <- sm(library("BSgenome.Dmelanogaster.UCSC.dm6"))
pasilla_convert <- sm(normalize_expt(
  pasilla_expt, convert="cp_seq_m", start_column="start_position",
  chromosome_column="chromosome_name", end_column="end_position",
  genome=BSgenome.Dmelanogaster.UCSC.dm6))
expected <- c(0.03443909, 0.46719586, 22.38432168, 54.32421464, 0.03908639)
actual <- as.numeric(exprs(pasilla_convert)[test_genes, 1])
test_that("cp_seq_m works for TA?", {
    expect_equal(expected, actual)
})

## Repeat cp_seq_m() for ATG
pasilla_convert <- sm(normalize_expt(
  pasilla_expt, convert="cp_seq_m", start_column="start_position",
  chromosome_column="chromosome_name", end_column="end_position",
  genome=BSgenome.Dmelanogaster.UCSC.dm6, pattern="ATG"))
expected <- c(0.04536343, 0.51893853, 27.76677691, 46.94320722, 0.05237078)
actual <- as.numeric(exprs(pasilla_convert)[test_genes, c("untreated1")])
test_that("cp_seq_m works for ATG?", {
    expect_equal(expected, actual)
})

end <- as.POSIXlt(Sys.time())
elapsed <- round(x=as.numeric(end) - as.numeric(start))
message(paste0("\nFinished 11norm_convert.R in ", elapsed, " seconds."))
tt <- try(clear_session())
