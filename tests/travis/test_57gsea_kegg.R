start <- as.POSIXlt(Sys.time())
library(testthat)
library(hpgltools)
library(pasilla)
tt <- sm(library(pathview))
data(pasillaGenes)
context("57gsea_kegg.R: Do KEGGREST and pathview work?\n")

pasilla <- new.env()
load("pasilla.Rdata", envir=pasilla)
pasilla_expt <- pasilla[["expt"]]
limma <- new.env()
load("de_limma.rda", envir=limma)

test_orgn <- get_kegg_orgn("Drosophila melanogaster", short=FALSE)
actual <- as.character(test_orgn[["orgid"]])
expected <- c("dme", "wol")
test_that("Is it possible to look up a kegg species ID?", {
    expect_equal(expected, actual)
})

## Make a map of the weird flybase IDs FBgn to the also weird Cg ids.
dm_orgdb <- sm(choose_orgdb("drosophila_melanogaster"))
mapping <- sm(orgdb_idmap(dm_orgdb, mapto=c("ENSEMBL","ENTREZID","FLYBASE","FLYBASECG","GENENAME")))
expected <- c("FBgn0040373", "FBgn0040372", "FBgn0261446", "FBgn0000316", "FBgn0005427", "FBgn0040370")
actual <- head(mapping[["flybase"]])
test_that("Did orgdb give useful ID mappings? (FBgn IDs)", {
    expect_equal(expected, actual)
})

expected <- c("30970", "30971", "30972", "30973", "30975", "30976")
actual <- head(mapping[["entrezid"]])
test_that("Did orgdb give useful ID mappings? (entrez)", {
    expect_equal(expected, actual)
})

limma_result <- limma[["hpgl_limma"]]
all_genes <- limma_result[["all_tables"]][["untreated_vs_treated"]]
all_genes <- merge(x=all_genes, y=mapping, by.x="row.names", by.y="flybase", all.x=TRUE)
sig_up <- sm(get_sig_genes(all_genes, z=2)[["up_genes"]])
all_ids <- paste0("Dmel_", all_genes[["flybasecg"]])
sig_ids <- paste0("Dmel_", sig_up[["flybasecg"]])

## When using the web site, it goes to:
## However, KEGGgraph goes to http://www.genome.jp ...

## Note, I split the result of this into percent_nodes and percent_edges
## Looks like some KEGG functionality has died, www.genome.jp/kegg-bin/download no longer returns anything...
## So I hacked my own retrieveKGML which adds a referer to get around this problem.
pct_citrate <- sm(pct_kegg_diff(all_ids, sig_ids, organism="dme", pathway="00500"))
expected <- 18.18
actual <- pct_citrate[["percent_nodes"]]
test_that("Can we extract the percent differentially expressed genes in one pathway?", {
    expect_equal(expected, actual, tolerance=0.1)
})
##
pathways <- c("00010", "00020", "00030", "00040","nonexistent", "00051")
all_percentages <- sm(pct_all_kegg(all_ids, sig_ids, pathways=pathways, organism="dme"))
expected <- c(5.556, 4.651, 0, 12.000, NA, 3.448)
actual <- all_percentages[["percent_nodes"]]
test_that("Can we extract the percent differentially expressed genes from multiple pathways?", {
    expect_equal(expected, actual, tolerance=0.1)
})

## Try testing out pathview
mel_id <- get_kegg_orgn("melanogaster")
rownames(sig_up) <- make.names(sig_up[["flybasecg"]], unique=TRUE)

funkytown <- sm(simple_pathview(sig_up, fc_column="logFC", species="dme", pathway=pathways,
                                from_list=c("CG"), to_list=c("Dmel_CG")))

expected <- c(0, 3, 2, 3, 4)
actual <- head(funkytown[["total_mapped_nodes"]])
test_that("Did pathview work? (total mapped nodes)", {
    expect_equal(expected, actual, tolerance=0.1)
})

unlink("kegg_pathways", recursive=TRUE)
end <- as.POSIXlt(Sys.time())
elapsed <- round(x=as.numeric(end) - as.numeric(start))
message(paste0("\nFinished 57gsea_kegg.R in ", elapsed,  " seconds."))
tt <- try(clear_session())
