## Time-stamp: <Tue May 17 00:34:42 2016 Ashton Trey Belew (abelew@gmail.com)>

#' Make sure that clusterProfiler is ready to run.
#'
#' Many of our ontology searches are using non-supported organisms.  These need to have a
#' geneTable.rda file in place which maps the gene IDs to GO IDs.  This function checks for that
#' file and attempts to set it up if it is not found.
#'
#' @param gff Ggff file containing annotation data (gene lengths).
#' @param goids_df Data frame of gene IDs and GO ontologies 1:1, other columns are ignored.
#' @return GO2EG data structure created, probably don't save this, it is entirely too big.
#' @examples
#' \dontrun{
#'  go2eg <- check_clusterprofiler(gff, gomap)
#'  rm(go2eg)
#' }
#' @export
check_clusterprofiler <- function(gff='test.gff', goids_df=NULL) {
    genetable_test <- try(load("geneTable.rda"), silent=TRUE)
    if (class(genetable_test) == 'try-error') {
        if (!is.null(gff)) {
            message("simple_clus(): Generating the geneTable.rda")
            hpgl_Gff2GeneTable(gff)
            ##clusterProfiler:::Gff2GeneTable(gff)
        } else {
            stop("simple_clus(): requires geneTable.rda, thus a gff file.")
        }
    } else {
        message("Successfully found geneTable.rda.")
        rm(genetable_test)
    }
    gomapping_test <- suppressWarnings(try(load("GO2EG.rda"), silent=TRUE))
    if (class(gomapping_test) == 'try-error') {
        message("simple_clus(): Generating GO mapping data.")
        gomap <- goids_df[,c(1,2)]
        colnames(gomap) <- c("entrezgene", "go_accession")
        ## It turns out that the author of clusterprofiler reversed these fields...
        ## Column 1 must be GO ID, column 2 must be gene accession.
        gomap <- gomap[,c("go_accession","entrezgene")]

        log <- capture.output(type="output", { clusterProfiler::buildGOmap(gomap) })
    } else {
        message("Using GO mapping data located in GO2EG.rda")
    }
    gomapping_test <- try(load("GO2EG.rda"), silent=TRUE)
    go2eg <- get0("GO2EG")
    return(go2eg)
}

#' Perform a simplified clusterProfiler analysis.
#'
#' I like clusterProfiler quite a lot, but making it work for non-standard species is a bit of a
#' chore.  This attempts to alleivate some of those headaches and cover some corner cases where it
#' fails.
#'
#' @param de_genes Data frame of differentially expressed genes, it must contain an ID column.
#' @param goids_file File containing mappings of genes to goids in the format expected by buildGOmap().
#' @param golevel Relative level in the tree for printing p-value plots, higher is more specific.
#' @param pcutoff (Adj)p-value cutoff to define 'significant'.
#' @param fold_changes Df of fold changes for the DE genes.
#' @param include_cnetplots Cnetplots often have too many glyphs to read, so by default they are not
#'     included, however on occasion they are fairly interesting to look at.
#' @param showcategory How many categories to show in p-value plots?  Too many and they become
#'     illegible.
#' @param universe Gene universe to use.
#' @param species Name of the species to use if supported, jibberish otherwise.
#' @param gff Gff file to generate the universe of genes.
#' @param wrapped_width Width of ontology names in the pvalue plots, too long and the bars
#'     disappear, too short and the words run into the lines above.
#' @param method Method for calculating p-values.
#' @param padjust Method for adjusting the p-values.
#' @param ... More options, passed to arglist.
#' @return List including the following:
#'   mf_interesting: A table of the interesting molecular function groups
#'   bp_interesting: A table of the interesting biological process groups
#'   cc_interesting: A table of the interesting cellular component groups
#'   mf_pvals: A histogram of the molecular function p-values
#'   bp_pvals: Ditto, biological process
#'   cc_pvals: And cellular component...
#'   mf_enriched: A table of the enriched molecular function groups by adjusted p-value.
#'   bp_enriched: yep, you guessed it
#'   cc_enriched: cellular component, too
#'   mf_all/bp_all/cc_all: A table of all go categories observed (mf/bp/cc respectively)
#'   mfp_plot/bpp_plot/ccp_plot: ggplot2 p-value bar plots describing the over represented groups
#'   mf_cnetplot/bp_cnetplot/cc_cnetplot: clusterProfiler cnetplots
#'   mf_group_barplot/bp_group_barplot/cc_group_barplot: The group barplots from clusterProfiler
#' @examples
#' \dontrun{
#'  up_cluster = simple_clusterprofiler(mga2_ll_thy_top, goids=goids, gff="reference/genome/gas.gff")
#' ## > Some chattery while it runs
#' ## tail(head(up_cluster$bp_interesting, n=10), n=1)
#' ## > ID ont GeneRatio BgRatio     pvalue   p.adjust    qvalue
#' ## > 10 GO:0009311  BP     5/195 10/1262 0.01089364 0.01089364 0.1272835
#' ## >   geneID Count
#' ## >   10 M5005_Spy1632/M5005_Spy1637/M5005_Spy1635/M5005_Spy1636/M5005_Spy1638     5
#' ## >   Description
#' ## >   10 oligosaccharide metabolic process
#' }
#' @export
simple_clusterprofiler <- function(de_genes, goids_df=NULL, golevel=4, pcutoff=0.1,
                                   fold_changes=NULL, include_cnetplots=FALSE,
                                   showcategory=12, universe=NULL, species="undef", gff=NULL,
                                   wrapped_width=20, method="Wallenius", padjust="BH", ...) {

    if (is.null(species)) {
        species <- "unknown"
    }
    if (!is.null(gff)) {
        go2eg <- check_clusterprofiler(gff=gff, goids_df=goids_df)
        if (length(go2eg) == 0) {
            stop("The GO2EG data structure is empty.")
        }
    }
    gene_list <- NULL
    if (is.null(de_genes[["ID"]])) {
        gene_list <- as.character(rownames(de_genes))
    } else {
        gene_list <- as.character(de_genes[["ID"]])
        gene_list <- gene_list[!is.na(gene_list)]
    }
    ##message("Testing gseGO")
    ##ego2 = try(clusterProfiler::gseGO(geneList=gene_list, organism=organism, ont="GO", nPerm=100, minGSSize=2, pvalueCutoff=1, verbose=TRUE))
    ##message(paste0("Has ego desided to work? ", ego2)
    message("simple_clus(): Starting MF(molecular function) analysis")
    mf_group <- clusterProfiler::groupGO(gene_list, organism=species, ont="MF", level=golevel, readable=TRUE)
    mf_all <- hpgl_enrichGO(gene_list, organism=species, ont="MF",
                            pvalueCutoff=1.0, qvalueCutoff=1.0, pAdjustMethod="none")
    all_mf_phist <- try(plot_histogram(mf_all@result$pvalue, bins=20))
    if (class(all_mf_phist)[1] != 'try-error') {
        y_limit <- (sort(unique(table(all_mf_phist$data)), decreasing=TRUE)[2]) * 2
        all_mf_phist <- all_mf_phist +
            ggplot2::scale_y_continuous(limits=c(0, y_limit))
    }
    enriched_mf <- hpgl_enrichGO(gene_list, organism=species, ont="MF",
                                 pvalueCutoff=pcutoff, qvalueCutoff=1.0,
                                 pAdjustMethod=padjust)

    message("simple_clus(): Starting BP(biological process) analysis")
    bp_group <- clusterProfiler::groupGO(gene_list, organism=species, ont="BP",
                                         level=golevel, readable=TRUE)
    bp_all <- hpgl_enrichGO(gene_list, organism=species, ont="BP", pvalueCutoff=1.0,
                            qvalueCutoff=1.0, pAdjustMethod="none")
    all_bp_phist <- try(plot_histogram(bp_all@result$pvalue, bins=20))
    if (class(all_bp_phist)[1] != 'try-error') {
        y_limit <- (sort(unique(table(all_bp_phist$data)), decreasing=TRUE)[2]) * 2
        all_bp_phist <- all_bp_phist +
            ggplot2::scale_y_continuous(limits=c(0, y_limit))
    }
    enriched_bp <- hpgl_enrichGO(gene_list, organism=species, ont="BP",
                                 pvalueCutoff=pcutoff, qvalueCutoff=1.0,
                                 pAdjustMethod=padjust)

    message("simple_clus(): Starting CC(cellular component) analysis")
    cc_group <- clusterProfiler::groupGO(gene_list, organism=species, ont="CC",
                                         level=golevel, readable=TRUE)
    cc_all <- hpgl_enrichGO(gene_list, organism=species, ont="CC", pvalueCutoff=1.0,
                            qvalueCutoff=1.0, pAdjustMethod="none")
    enriched_cc <- hpgl_enrichGO(gene_list, organism=species, ont="CC", pvalueCutoff=pcutoff,
                                 qvalueCutoff=1.0, pAdjustMethod=padjust)
    all_cc_phist <- try(plot_histogram(cc_all@result$pvalue, bins=20))

    ## Try and catch if there are no significant hits.
    if (class(all_cc_phist)[1] != 'try-error') {
        y_limit <- (sort(unique(table(all_cc_phist$data)), decreasing=TRUE)[2]) * 2
        all_cc_phist <- all_cc_phist +
            ggplot2::scale_y_continuous(limits=c(0, y_limit))
    }

    mf_group_barplot <- try(barplot(mf_group, drop=TRUE, showCategory=showcategory), silent=TRUE)
    if (class(mf_group_barplot)[1] != 'try-error') {
        mf_group_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(mf_group_barplot$data$Description,
                                         wrapped_width, simplify=FALSE),paste,collapse="\n"))
    }

    bp_group_barplot <- try(barplot(bp_group, drop=TRUE, showCategory=showcategory), silent=TRUE)
    if (class(bp_group_barplot)[1] != 'try-error') {
        bp_group_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(bp_group_barplot$data$Description,
                                         wrapped_width, simplify=FALSE),paste,collapse="\n"))
    }

    cc_group_barplot <- try(barplot(cc_group, drop=TRUE, showCategory=showcategory), silent=TRUE)
    if (class(cc_group_barplot)[1] != 'try-error') {
        cc_group_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(cc_group_barplot$data$Description,
                                         wrapped_width, simplify=FALSE),paste,collapse="\n"))
    }

    all_mf_barplot <- try(barplot(mf_all, categorySize="pvalue", showCategory=showcategory), silent=TRUE)
    enriched_mf_barplot <- try(barplot(enriched_mf, categorySize="pvalue",
                                       showCategory=showcategory), silent=TRUE)
    if (class(enriched_mf_barplot)[1] == 'try-error') {
        message("simple_clus(): No enriched MF groups were observed.")
    } else {
        enriched_mf_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(enriched_mf_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }
    if (class(all_mf_barplot)[1] != 'try-error') {
        all_mf_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(all_mf_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }

    all_bp_barplot <- try(barplot(bp_all, categorySize="pvalue",
                                  showCategory=showcategory), silent=TRUE)
    enriched_bp_barplot <- try(barplot(enriched_bp, categorySize="pvalue",
                                       showCategory=showcategory), silent=TRUE)
    if (class(enriched_bp_barplot)[1] == 'try-error') {
        message("simple_clus(): No enriched BP groups observed.")
    } else {
        enriched_bp_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(enriched_bp_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }
    if (class(all_bp_barplot)[1] != 'try-error') {
        all_bp_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(all_bp_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }

    all_cc_barplot <- try(barplot(cc_all, categorySize="pvalue",
                                  showCategory=showcategory), silent=TRUE)
    enriched_cc_barplot <- try(barplot(enriched_cc, categorySize="pvalue",
                                       showCategory=showcategory), silent=TRUE)
    if (class(enriched_cc_barplot)[1] == 'try-error') {
        message("simple_clus(): No enriched CC groups observed.")
    } else {
        enriched_cc_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(enriched_cc_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }
    if (class(all_cc_barplot)[1] != 'try-error') {
        all_cc_barplot$data$Description <- as.character(
            BiocGenerics::lapply(strwrap(all_cc_barplot$data$Description,
                                         wrapped_width, simplify=FALSE), paste,collapse="\n"))
    }

    cnetplot_mf <- cnetplot_bp <- cnetplot_cc <- NULL
    cnetplot_mfall <- cnetplot_bpall <- cnetplot_ccall <- NULL
    if (include_cnetplots == TRUE) {
        message("simple_clus(): Attempting to include the cnetplots.")
        message("simple_clus(): If they fail, set include_cnetplots to FALSE")
        cnetplot_mf <- try(clusterProfiler::cnetplot(enriched_mf, categorySize="pvalue",
                                                     foldChange=fold_changes))
        if (class(cnetplot_mf)[1] != 'try-error') {
            cnetplot_mf <- grDevices::recordPlot()
        } else {
            message("simple_clus(): cnetplot failed for MF, no worries.")
        }
        cnetplot_bp <- try(clusterProfiler::cnetplot(enriched_bp, categorySize="pvalue",
                                                     foldChange=fold_changes))
        if (class(cnetplot_bp)[1] != 'try-error') {
            cnetplot_bp <- grDevices::recordPlot()
        } else {
            message("simple_clus(): cnetplot failed for BP, no worries.")
        }
        cnetplot_cc <- try(clusterProfiler::cnetplot(enriched_cc, categorySize="pvalue",
                                                     foldChange=fold_changes))
        if (class(cnetplot_cc)[1] != 'try-error') {
            cnetplot_cc <- grDevices::recordPlot()
        } else {
            message("simple_clus(): cnetplot failed for CC, no worries.")
        }
        cnetplot_mfall <- try(clusterProfiler::cnetplot(mf_all, categorySize="pvalue",
                                                        foldChange=fold_changes))
        if (class(cnetplot_mfall)[1] != 'try-error') {
            cnetplot_mfall <- grDevices::recordPlot()
        }
        cnetplot_bpall <- try(clusterProfiler::cnetplot(bp_all, categorySize="pvalue",
                                                        foldChange=fold_changes))
        if (class(cnetplot_bpall)[1] != 'try-error') {
            cnetplot_bpall <- grDevices::recordPlot()
        }
        cnetplot_ccall <- try(clusterProfiler::cnetplot(cc_all, categorySize="pvalue",
                                                        foldChange=fold_changes))
        if (class(cnetplot_ccall)[1] != 'try-error') {
            cnetplot_ccall <- grDevices::recordPlot()
        }
    }

    if (!is.null(mf_all)) {
        mf_interesting <- mf_all@result
        rownames(mf_interesting) = NULL
        mf_interesting$ont <- "MF"
        mf_interesting <- mf_interesting[,c("ID","ont","GeneRatio","BgRatio","pvalue",
                                            "p.adjust","qvalue","geneID","Count","Description")]
        ## mf_interesting = subset(mf_interesting, pvalue <= 0.1)
        mf_interesting <- mf_interesting[ which(mf_interesting$pvalue <= 0.1), ]
    } else {
        mf_interesting <- NULL
    }
    if (!is.null(bp_all)) {
        bp_interesting <- bp_all@result
        rownames(bp_interesting) <- NULL
        bp_interesting$ont <- "BP"
        bp_interesting <- bp_interesting[,c("ID","ont","GeneRatio","BgRatio","pvalue",
                                            "p.adjust","qvalue","geneID","Count","Description")]
        ## bp_interesting = subset(bp_interesting, pvalue <= 0.1)
        bp_interesting <- bp_interesting[ which(bp_interesting$pvalue <= 0.1), ]
    } else {
        bp_interesting <- NULL
    }
    if (!is.null(cc_all)) {
        cc_interesting <- cc_all@result
        rownames(cc_interesting) <- NULL
        cc_interesting$ont <- "CC"
        cc_interesting <- cc_interesting[,c("ID","ont","GeneRatio","BgRatio","pvalue",
                                            "p.adjust","qvalue","geneID","Count","Description")]
        ## cc_interesting = subset(cc_interesting, pvalue <= 0.1)
        cc_interesting <- cc_interesting[ which(cc_interesting$pvalue <= 0.1), ]
    } else {
        cc_interesting <- NULL
    }

    pval_plots <- list(
        "bpp_plot_over" = enriched_bp_barplot,
        "mfp_plot_over" = enriched_mf_barplot,
        "ccp_plot_over" = enriched_cc_barplot)
    all_barplots <- list(
        "bpp_plot_over" = all_bp_barplot,
        "mfp_plot_over" = all_mf_barplot,
        "ccp_plot_over" = all_cc_barplot)
    cnetplots <- list(
        "mfall_cnetplot" = cnetplot_mfall,
        "bpall_cnetplot" = cnetplot_bpall,
        "ccall_cnetplot" = cnetplot_ccall)
    group_barplots <- list(
        "mf_group_barplot" = mf_group_barplot,
        "bp_group_barplot" = bp_group_barplot,
        "cc_group_barplot" = cc_group_barplot)

    return_information <- list(
        "de_genes" = de_genes,
        "mf_interesting" = mf_interesting,
        "bp_interesting" = bp_interesting,
        "cc_interesting" = cc_interesting,
        "mf_pvals" = all_mf_phist,
        "bp_pvals" = all_bp_phist,
        "cc_pvals" = all_cc_phist,
        "mf_enriched" = enriched_mf,
        "bp_enriched" = enriched_bp,
        "cc_enriched" = enriched_cc,
        "mf_all" = mf_all,
        "bp_all" = bp_all,
        "cc_all" = cc_all,
        "mf_cnetplot" = cnetplot_mf,
        "bp_cnetplot" = cnetplot_bp,
        "cc_cnetplot" = cnetplot_cc,
        "mf_group" = mf_group,
        "bp_group" = bp_group,
        "cc_group" = cc_group,
        "pvalue_allplots" = all_barplots,
        "pvalue_plots" = pval_plots,
        "cnetplots" = cnetplots,
        "group_plots" = group_barplots)
    return(return_information)
}

#' Take clusterprofile group data and print it on a tree as per topGO.
#'
#' TopGO's ontology trees can be very illustrative.  This function shoe-horns clusterProfiler data
#' into the format expected by topGO and uses it to make those trees.
#'
#' @param de_genes List of genes deemed 'interesting'.
#' @param cpdata Data from simple_clusterprofiler().
#' @param goid_map Mapping file of IDs to GO ontologies.
#' @param goids_df Dataframe of mappings used to build goid_map.
#' @param score_limit Scoring limit above which to ignore genes.
#' @param overwrite Overwrite an existing goid mapping file?
#' @param selector Name of a function for applying scores to the trees.
#' @param pval_column Name of the column in the GO table from which to extract scores.
#' @return plots! Trees! oh my!
#' @seealso \pkg{Ramigo} \code{\link[topGO]{showSigOfNodes}}
#' @examples
#' \dontrun{
#' cluster_data <- simple_clusterprofiler(genes, stuff)
#' ctrees <- cluster_trees(genes, cluster_data)
#' }
#' @export
cluster_trees <- function(de_genes, cpdata, goid_map="reference/go/id2go.map", goids_df=NULL,
                          score_limit=0.2, overwrite=FALSE, selector="topDiffGenes", pval_column="adj.P.Val") {
    de_genes <- cpdata$de_genes
    make_id2gomap(goid_map=goid_map, goids_df=goids_df, overwrite=overwrite)
    geneID2GO <- topGO::readMappings(file=goid_map)
    annotated_genes <- names(geneID2GO)
    if (is.null(de_genes$ID)) {
        de_genes$ID <- make.names(rownames(de_genes), unique=TRUE)
    }
    interesting_genes <- factor(annotated_genes %in% de_genes$ID)
    names(interesting_genes) <- annotated_genes

    message(paste0("Checking the de_table for a p-value column:", pval_column))
    if (is.null(de_genes[[pval_column]])) {
        mf_GOdata <- new("topGOdata", ontology="MF", allGenes=interesting_genes,
                         annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
        bp_GOdata <- new("topGOdata", ontology="BP", allGenes=interesting_genes,
                         annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
        cc_GOdata <- new("topGOdata", ontology="CC", allGenes=interesting_genes,
                         annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
    } else {
        pvals <- as.vector(as.numeric(de_genes[[pval_column]]))
        names(pvals) <- rownames(de_genes)
        mf_GOdata <- new("topGOdata", description="MF", ontology="MF", allGenes=pvals,
                         geneSel=get(selector), annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
        bp_GOdata <- new("topGOdata", description="BP", ontology="BP", allGenes=pvals,
                         geneSel=get(selector), annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
        cc_GOdata <- new("topGOdata", description="CC", ontology="CC", allGenes=pvals,
                        geneSel=get(selector), annot=topGO::annFUN.gene2GO, gene2GO=geneID2GO)
    }

    mf_all <- cpdata$mf_all
    ## mf_enriched = cpdata$mf_enriched
    bp_all <- cpdata$bp_all
    ## bp_enriched = cpdata$bp_enriched
    cc_all <- cpdata$cc_all
    ## cc_enriched = cpdata$cc_enriched
    mf_all_ids <- mf_all@result$ID
    bp_all_ids <- bp_all@result$ID
    cc_all_ids <- cc_all@result$ID
    mf_all_scores <- mf_all@result$p.adjust
    bp_all_scores <- bp_all@result$p.adjust
    cc_all_scores <- cc_all@result$p.adjust
    names(mf_all_scores) <- mf_all_ids
    names(bp_all_scores) <- bp_all_ids
    names(cc_all_scores) <- cc_all_ids
    mf_included <- length(which(mf_all_scores <= score_limit))
    ## mf_tree_data = try(suppressWarnings(topGO::showSigOfNodes(mf_GOdata, mf_all_scores, useInfo="all", sigForAll=TRUE, firstSigNodes=mf_included, useFullNames=TRUE, plotFunction=hpgl_GOplot)))
    mf_tree_data <- try(suppressWarnings(
        topGO::showSigOfNodes(mf_GOdata, mf_all_scores, useInfo="all",
                              sigForAll=TRUE, firstSigNodes=floor(mf_included * 1.5),
                              useFullNames=TRUE, plotFunction=hpgl_GOplot)))
    if (class(mf_tree_data)[1] == 'try-error') {
        mf_tree <- NULL
    } else {
        mf_tree <- grDevices::recordPlot()
    }
    bp_included <- length(which(bp_all_scores <= score_limit))
    bp_tree_data <- try(suppressWarnings(
        topGO::showSigOfNodes(bp_GOdata, bp_all_scores, useInfo="all",
                              sigForAll=TRUE, firstSigNodes=bp_included,
                              useFullNames=TRUE, plotFunction=hpgl_GOplot)))
    if (class(bp_tree_data)[1] == 'try-error') {
        bp_tree <- NULL
    } else {
        bp_tree <- grDevices::recordPlot()
    }
    cc_included <- length(which(cc_all_scores <= score_limit))
    cc_tree_data <- try(suppressWarnings(
        topGO::showSigOfNodes(cc_GOdata, cc_all_scores, useInfo="all",
                              sigForAll=TRUE, firstSigNodes=cc_included,
                              useFullNames=TRUE, plotFunction=hpgl_GOplot)))
    if (class(cc_tree_data)[1] == 'try-error') {
        cc_tree <- NULL
    } else {
        cc_tree <- grDevices::recordPlot()
    }
    trees <- list(
        "MF_over" = mf_tree,
        "BP_over" = bp_tree,
        "CC_over" = cc_tree,
        "MF_overdata" = mf_tree_data,
        "BP_overdata" = bp_tree_data,
        "CC_overdata" = cc_tree_data)
    return(trees)
}

#' A minor hack in the clusterProfiler function 'enrichGO'.
#'
#' I do not remember any longer why, but enrichGO errors out in ways which do not always make sense,
#' this was written to alleviate that problem.  I believe I sent a diff to the clusterProfiler
#' author but did not hear back and so added this function.
#'
#' @param gene Some differentially expressed genes.
#' @param organism if used will cause this to pull the ensG annotations.
#' @param ont Molecular function, Biological process, or Cellular component?
#' @param pvalueCutoff P-value cutoff.
#' @param pAdjustMethod P-value adjustment.
#' @param universe Gene universe to use.
#' @param qvalueCutoff Maximum qvalue before adding.
#' @param minGSSize Smallest ontology group size allowed.
#' @param readable Set the readable tag on the returned object?
#' @return Some clusterProfiler data.
#' @seealso \pkg{clusterProfiler}
#' @export
hpgl_enrichGO <- function(gene, organism="human", ont="MF",
                          pvalueCutoff=0.05, pAdjustMethod="BH", universe,
                          qvalueCutoff=0.2, minGSSize=2, readable=FALSE) {
    information <- hpgl_enrich.internal(gene, organism=organism, pvalueCutoff=pvalueCutoff,
##        pAdjustMethod=pAdjustMethod, ont=ont, universe=universe,
                                        pAdjustMethod=pAdjustMethod, ont=ont,
                                        qvalueCutoff=qvalueCutoff, minGSSize=minGSSize)
##    print(summary(information))
    return(information)
}

#' A minor hack in the clusterProfiler function 'enrich.internal'.
#'
#' I do not remember any longer why, but enrichGO errors out in ways which do not always make sense,
#' this was written to alleviate that problem.  I believe I sent a diff to the clusterProfiler
#' author but did not hear back and so added this function.
#'
#' @param gene Differentially expressed genes.
#' @param organism Pull ensembl annotations if this is a supported species.
#' @param pvalueCutoff P-value cutoff.
#' @param pAdjustMethod P-adjust method.
#' @param ont Molecular function, Biological process, or Cellular component?
#' @param minGSSize Minimum gs size?
#' @param qvalueCutoff Maximum allowed q-value.
#' @param readable Set the readable flag for the DOSE object?
#' @param universe Universe of genes to score significance against.
#' @return Some clusterProfiler data.
#' @seealso \pkg{clusterProfiler}
#' @export
hpgl_enrich.internal <- function(gene, organism, pvalueCutoff=1, pAdjustMethod="fdr",
                                 ont, minGSSize=2, qvalueCutoff=0.2, readable=FALSE, universe=NULL) {
    ##require.auto("plyr")  ## dlply and the . function are too obnoxious without pulling them in.
    gene <- as.character(gene)
    class(gene) <- ont
    qExtID2TermID <- DOSE::EXTID2TERMID(gene, organism)
    qTermID <- unlist(qExtID2TermID)
    if (is.null(qTermID)) {
        return(NA)
    }
    ## Term ID -- query external ID association list.
    qExtID2TermID.df <- data.frame(extID=rep(names(qExtID2TermID),
                                   times=lapply(qExtID2TermID, length)),
                                   termID=qTermID)
    qExtID2TermID.df <- unique(qExtID2TermID.df)
    termID <- NULL ## to satisfy code tools
    qTermID2ExtID <- plyr::dlply(qExtID2TermID.df, plyr::.(termID),
                                 .fun=function(i) as.character(i$extID))
    class(organism) <- ont
    extID <- DOSE::ALLEXTID(organism)
    if(!missing(universe)) {
        extID <- intersect(extID, universe)
    }
    qTermID2ExtID <- sapply(qTermID2ExtID, intersect, extID)
### The L.major ontologies are smaller, and so if the default (5)
### minGSSize is left in place, this comes up as null and therefore
### ends with the entire thing returning null.  I changed it to 2 for
### the moment.
    idx <- sapply(qTermID2ExtID, length) > minGSSize
    if (sum(idx) == 0) {
        return (NULL)
    }
    qTermID2ExtID <- qTermID2ExtID[idx]
    ## Term ID annotate query external ID
    qTermID <- unique(names(qTermID2ExtID))
    ## prepare parameter for hypergeometric test
    k <- sapply(qTermID2ExtID, length)
    k <- k[qTermID]
    class(qTermID) <- ont
    termID2ExtID <- DOSE::TERMID2EXTID(qTermID, organism)
    termID2ExtID <- sapply(termID2ExtID, intersect, extID)
    if (length(qTermID)== 1) {
        M <- nrow(termID2ExtID)
    } else {
        M <- sapply(termID2ExtID, length)
        M <- M[qTermID]
    }
    N <- rep(length(extID), length(M))
    ## n <- rep(length(gene), length(M)) ## those genes that have no annotation should drop.
    n <- rep(length(qExtID2TermID), length(M))
    args.df <- data.frame(numWdrawn=k-1, ## White balls drawn
                          numW=M,        ## White balls
                          numB=N-M,      ## Black balls
                          numDrawn=n)    ## balls drawn
    ## calcute pvalues based on hypergeometric model
    pvalues <- apply(args.df, 1, function(n)
                     phyper(n[1], n[2], n[3], n[4], lower.tail=FALSE))
    ## gene ratio and background ratio
    GeneRatio <- apply(data.frame(a=k, b=n), 1, function(x)
                       paste(x[1], "/", x[2], sep="", collapse=""))
    BgRatio <- apply(data.frame(a=M, b=N), 1, function(x)
                     paste(x[1], "/", x[2], sep="", collapse=""))
    Over <- data.frame(ID=as.character(qTermID),
                       GeneRatio=GeneRatio,
                       BgRatio=BgRatio,
                       pvalue=pvalues)
    original_over = Over
    p.adj <- p.adjust(Over$pvalue, method=pAdjustMethod)
    message(paste0("The minimum observed pvalue for ", ont, " is: ", min(pvalues)))
    qobj = try(qvalue::qvalue(p=Over$pvalue, lambda=0.05, pi0.method="bootstrap"), silent=TRUE)
    if (class(qobj) == "qvalue") {
        qvalues <- qobj$qvalues
    } else {
        qvalues <- NA
    }
    geneID <- sapply(qTermID2ExtID, function(i) paste(i, collapse="/"))
    geneID <- geneID[qTermID]
    Over <- data.frame(Over,
                       p.adjust = p.adj,
                       qvalue=qvalues,
                       geneID=geneID,
                       Count=k)
    class(qTermID) <- ont
    Description <- DOSE::TERM2NAME(qTermID, organism)

    if (length(qTermID) != length(Description)) {
        idx <- qTermID %in% names(Description)
        Over <- Over[idx,]
    }
    Over$Description <- Description
    nc <- ncol(Over)
    Over <- Over[, c(1,nc, 2:(nc-1))]
    Over <- Over[order(pvalues), ]
    Over <- Over[ Over$pvalue <= pvalueCutoff, ]
    Over <- Over[ Over$p.adjust <= pvalueCutoff, ]
    if (! any(is.na(Over$qvalue))) {
        Over <- Over[ Over$qvalue <= qvalueCutoff, ]
    }
    Over$ID <- as.character(Over$ID)
    Over$Description <- as.character(Over$Description)
    category <- as.character(Over$ID)
    ### On my computer this fails.
    ##    rownames(Over) <- category
    x <- new("enrichResult",
             result = Over,
             pvalueCutoff=pvalueCutoff,
             pAdjustMethod=pAdjustMethod,
             organism=as.character(organism),
             ontology=as.character(ont),
             gene=as.character(gene),
             geneInCategory=qTermID2ExtID[category]
             )
    if(readable) {
        x <- DOSE::setReadable(x)
    }
    return (x)
}

##readGff <- function(gffFile, nrows = -1) {
##    cat("Reading ", gffFile, ": ", sep="")
##    gff <- read.table(gffFile, sep="\t", as.is=TRUE, quote="\"", fill=TRUE,
##                      header=FALSE, comment.char="#", nrows=nrows,
##                      colClasses=c("character", "character", "character", "integer",
##                          "integer", "character", "character", "character", "character"))
##    colnames(gff) = c("seqname", "source", "feature", "start", "end",
##                "score", "strand", "frame", "attributes")
##    cat("found", nrow(gff), "rows with classes:",
##        paste(sapply(gff, class), collapse=", "), "\n")
##    stopifnot(!any(is.na(gff$start)), !any(is.na(gff$end)))
##    return(gff)
##}
##

#' A near copy-paste of clusterProfiler's readGff().
#'
#' There is a redundant merge in the original code which caused my invocations to use up all the
#' memory on my machine.
#'
#' @param gffFile Gff file of annotations.
#' @param compress Compress the results?
#' @param split Splitter when reading gff files to extract annotation information.
#' @return geneTable.rda file of gene attributes.
#' @export
hpgl_Gff2GeneTable <- function(gffFile, compress=TRUE, split="=") {
    if (is.data.frame(gffFile)) {
        GeneID <- data.frame(GeneID = gffFile[["ID"]])
        geneInfo <- gffFile
        geneInfo$start <- 1
        geneInfo$GeneID <- gffFile[["ID"]]
        geneInfo$GeneName <- gffFile[["ID"]]
        geneInfo$Locus <- gffFile[["ID"]]
        geneInfo$end <- geneInfo[["width"]]
        geneInfo$strand <- "+"
    } else {
        gff <- clusterProfiler:::readGff(gffFile)
        GeneID <- data.frame(
            "GeneID" = hpgl_getGffAttribution(gff[["attributes"]], field="ID", split=split))
        geneInfo <- gff[gff[["feature"]] == "gene",]
        geneInfo <- geneInfo[, c("seqname", "start", "end", "strand", "attributes")]
        geneInfo[["GeneID"]] <- hpgl_getGffAttribution(geneInfo[["attributes"]], field="ID", split=split)
        geneInfo[["GeneName"]] <- hpgl_getGffAttribution(geneInfo[["attributes"]], field="gene", split=split)
        first_locus <- hpgl_getGffAttribution(geneInfo[["attributes"]], field="locus_tag", split=split)
        first_sum <- sum(is.na(first_locus))
        second_locus <- NULL
        second_sum <- first_sum
        if (first_sum > (length(geneInfo[["attributes"]]) / 2)) {
            ## Using this to approximate whether locus_tag has a useful meaning.
            ## If more than 1/2 of the attributes have no locus tag, try using gene_id instead -- which is what yeast uses (btw).
            message("Trying to use gene_id insteady of locus_tag, because locus_tag is poorly defined.")
            second_locus <- hpgl_getGffAttribution(geneInfo[["attributes"]], field="gene_id", split=split)
            second_sum <- sum(is.na(second_locus))
        }
        if (first_sum > second_sum) {
            geneInfo[["Locus"]] <- second_locus
        } else {
            geneInfo[["Locus"]] <- first_locus
        }
        geneInfo$GeneName[is.na(geneInfo$GeneName)] = "-"  ## wtf is going on here?
        geneInfo <- geneInfo[, -5] ## drop "attributes" column.
    }
    ##GI2GeneID <- data.frame(GI=getGffAttribution(gff$attributes, field="GI"),
    ##GeneID=getGffAttribution(gff$attributes, field="GeneID"),
    ##Product=getGffAttribution(gff$attributes, field="product"))
    ##GI2GeneID <- GI2GeneID[!is.na(GI2GeneID$GI),]
    ##GI2GeneID <- GI2GeneID[!is.na(GI2GeneID$Gene),]
    ##geneTable <- merge(GI2GeneID, geneInfo, by.x="GeneID", by.y="GeneID")
    geneTable <- merge(GeneID, geneInfo, by.x="GeneID", by.y="GeneID")
    geneTable <- unique(geneTable)
    if (compress) {
        save(geneTable, file="geneTable.rda", compress="xz")
    } else {
        save(geneTable, file="geneTable.rda")
    }
    message("Gene Table file save in the working directory.")
}

hpgl_getGffAttribution <- function(x, field, attrsep=";", split='=') {
    s <- strsplit(x, split=attrsep, fixed=TRUE)
    sapply(s, function(atts) {
        atts <- gsub("^ ", "", x=atts, perl=TRUE)
        a <- strsplit(atts, split=split, fixed = TRUE)
        m <- match(field, sapply(a, "[", 1))
        if (!is.na(m)) {
            rv <- a[[m]][2]
        } else {
            b <- sapply(a, function(atts) {
                strsplit(atts[2], split=",", fixed = TRUE)
            })
            rv <- as.character(NA)
            sapply(b, function(atts) {
                secA <- strsplit(atts, split = ":", fixed = TRUE)
                m <- match(field, sapply(secA, "[", 1))
                if (!is.na(m)) {
                  rv <<- secA[[m]][2]
                }
            })
        }
        return(rv)
    })
}

## EOF