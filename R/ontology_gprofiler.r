## Time-stamp: <Fri May 13 21:17:30 2016 Ashton Trey Belew (abelew@gmail.com)>

#' Run searches against the web service g:Profiler.
#'
#' Thank you Ginger for showing me your thesis, gProfiler is pretty cool!
#'
#' @param gene_list guess!
#' @param species an organism supported by gprofiler
#' @param first_col where to search for the order of 'significant' first
#' @param second_col if that fails, try some where else.
#' @return a list of results for go, kegg, reactome, and a few more.
#' @export
simple_gprofiler <- function(gene_list, species="hsapiens", first_col="logFC", second_col="limma_logfc") {
    ## Assume for the moment a limma-ish data frame
    if (!is.null(gene_list[[first_col]])) {
        gene_list <- gene_list[order(-gene_list[[first_col]]), ]
    } else if (!is.null(gene_list[[second_col]])) {
        gene_list <- gene_list[order(-gene_list[[second_col]]), ]
    }

    gene_ids <- NULL
    if (!is.null(gene_list[["ID"]])) {
        gene_ids <- as.vector(gene_list[["ID"]])
    } else if (!is.null(rownames(gene_list))) {
        gene_ids <- rownames(gene_list)
    } else {
        stop("Unable to get the set of gene ids.")
    }
    ## Setting 'ordered_query' to TRUE, so rank these by p-value or FC or something
    message("Performing g:Profiler GO search.")
    go_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                          ordered_query=TRUE, src_filter="GO"))
    message("Performing g:Profiler KEGG search.")
    kegg_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                             ordered_query=TRUE, src_filter="KEGG"))
    message("Performing g:Profiler reactome.db search.")
    reactome_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                                ordered_query=TRUE, src_filter="REAC"))
    message("Performing g:Profiler mi search.")
    mi_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                          ordered_query=TRUE, src_filter="MI"))
    message("Performing g:Profiler tf search.")
    tf_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                          ordered_query=TRUE, src_filter="TF"))
    message("Performing g:Profiler corum search.")
    corum_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                             ordered_query=TRUE, src_filter="CORUM"))
    message("Performing g:Profiler hp search.")
    hp_result <- try(gProfileR::gprofiler(query=gene_ids, organism=species, significant=TRUE,
                                          ordered_query=TRUE, src_filter="HP"))
    retlist <- list(
        "go" = go_result,
        "kegg" = kegg_result,
        "reactome" = reactome_result,
        "mi" = mi_result,
        "tf" = tf_result,
        "corum" = corum_result,
        "hp" = hp_result)
    retlist[["plots"]] <- plot_gprofiler_pval(retlist)
    return(retlist)
}

#' Make a pvalue plot from gprofiler data.
#'
#' The p-value plots from clusterProfiler are pretty, this sets the gprofiler data into a format
#' suitable for plotting in that fashion and returns the resulting plots of significant ontologies.
#'
#' @param topgo Some data from topgo!
#' @param wrapped_width  Maximum width of the text names.
#' @param cutoff P-value cutoff for the plots.
#' @param n Maximum number of ontologies to include.
#' @param type Type of score to use.
#' @return List of MF/BP/CC pvalue plots.
#' @seealso \pkg{topgo} \code{clusterProfiler}
#' @export
plot_gprofiler_pval <- function(gp_result, wrapped_width=20, cutoff=0.1, n=12, group_minsize=5) {
    go_result <- gp_result[["go"]]
    kegg_result <- gp_result[["kegg"]]
    react_result <- gp_result[["react"]]
    mi_result <- gp_result[["mi"]]
    tf_result <- gp_result[["tf"]]
    corum_result <- gp_result[["corum"]]

    mf_over <- go_result[go_result[["domain"]] == "MF", ]
    bp_over <- go_result[go_result[["domain"]] == "BP", ]
    cc_over <- go_result[go_result[["domain"]] == "CC", ]

    plotting_mf_over <- mf_over
    mf_pval_plot_over <- NULL
    if (is.null(mf_over)) {
        plotting_mf_over <- NULL
    } else {
        plotting_mf_over$score <- plotting_mf_over$recall
        ## plotting_mf_over <- subset(plotting_mf_over, Term != "NULL")
        plotting_mf_over <- plotting_mf_over[plotting_mf_over$term.name != "NULL", ]
        ## plotting_mf_over <- subset(plotting_mf_over, Pvalue <= cutoff)
        plotting_mf_over <- plotting_mf_over[plotting_mf_over$p.value <= cutoff, ]
        ## plotting_mf_over <- subset(plotting_mf_over, Size >= group_minsize)
        plotting_mf_over <- plotting_mf_over[plotting_mf_over$query.size >= group_minsize, ]
        plotting_mf_over <- plotting_mf_over[order(plotting_mf_over$p.value), ]
        plotting_mf_over <- head(plotting_mf_over, n=n)
        plotting_mf_over <- plotting_mf_over[, c("term.name", "p.value", "recall")]
        colnames(plotting_mf_over) <- c("term", "pvalue", "score")
        plotting_mf_over$term <- as.character(lapply(strwrap(plotting_mf_over$term, wrapped_width, simplify=FALSE), paste, collapse="\n"))
    }
    if (nrow(plotting_mf_over) > 0) {
        mf_pval_plot_over <- plot_ontpval(plotting_mf_over, ontology="MF")
    }

    plotting_bp_over <- bp_over
    bp_pval_plot_over <- NULL
    if (is.null(bp_over)) {
        plotting_bp_over <- NULL
    } else {
        plotting_bp_over$score <- plotting_bp_over$recall
        ## plotting_bp_over <- subset(plotting_bp_over, Term != "NULL")
        plotting_bp_over <- plotting_bp_over[plotting_bp_over$term.name != "NULL", ]
        ## plotting_bp_over <- subset(plotting_bp_over, Pvalue <= cutoff)
        plotting_bp_over <- plotting_bp_over[plotting_bp_over$p.value <= cutoff, ]
        ## plotting_bp_over <- subset(plotting_bp_over, Size >= group_minsize)
        plotting_bp_over <- plotting_bp_over[plotting_bp_over$query.size >= group_minsize, ]
        plotting_bp_over <- plotting_bp_over[order(plotting_bp_over$p.value), ]
        plotting_bp_over <- head(plotting_bp_over, n=n)
        plotting_bp_over <- plotting_bp_over[, c("term.name", "p.value", "recall")]
        colnames(plotting_bp_over) <- c("term", "pvalue", "score")
        plotting_bp_over$term <- as.character(lapply(strwrap(plotting_bp_over$term, wrapped_width, simplify=FALSE), paste, collapse="\n"))
    }
    if (nrow(plotting_bp_over) > 0) {
        bp_pval_plot_over <- plot_ontpval(plotting_bp_over, ontology="BP")
    }

    plotting_cc_over <- cc_over
    cc_pval_plot_over <- NULL
    if (is.null(cc_over)) {
        plotting_cc_over <- NULL
    } else {
        plotting_cc_over$score <- plotting_cc_over$recall
        ## plotting_cc_over <- subset(plotting_cc_over, Term != "NULL")
        plotting_cc_over <- plotting_cc_over[plotting_cc_over$term.name != "NULL", ]
        ## plotting_cc_over <- subset(plotting_cc_over, Pvalue <= cutoff)
        plotting_cc_over <- plotting_cc_over[plotting_cc_over$p.value <= cutoff, ]
        ## plotting_cc_over <- subset(plotting_cc_over, Size >= group_minsize)
        plotting_cc_over <- plotting_cc_over[plotting_cc_over$query.size >= group_minsize, ]
        plotting_cc_over <- plotting_cc_over[order(plotting_cc_over$p.value), ]
        plotting_cc_over <- head(plotting_cc_over, n=n)
        plotting_cc_over <- plotting_cc_over[, c("term.name", "p.value", "recall")]
        colnames(plotting_cc_over) <- c("term", "pvalue", "score")
        plotting_cc_over$term <- as.character(lapply(strwrap(plotting_cc_over$term, wrapped_width, simplify=FALSE), paste, collapse="\n"))
    }
    if (nrow(plotting_cc_over) > 0) {
        cc_pval_plot_over <- plot_ontpval(plotting_cc_over, ontology="CC")
    }


    pval_plots <- list(
        "mfp_plot_over" = mf_pval_plot_over,
        "bpp_plot_over" = bp_pval_plot_over,
        "ccp_plot_over" = cc_pval_plot_over,
        "mf_subset_over" = plotting_mf_over,
        "bp_subset_over" = plotting_bp_over,
        "cc_subset_over" = plotting_cc_over)
    return(pval_plots)
}

## EOF
