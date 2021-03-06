library(dplyr)
library(data.table)

options(stringsAsFactors = FALSE,
        error = function(){dump.frames("compare_eq_classes_debug", to.file = TRUE); q()})

# load helper methods
args <- commandArgs(trailingOnly=FALSE)
file.arg <- grep("--file=", args, value=TRUE)
incl.path <- gsub("--file=(.*)compare_eq_classes.R", "\\1de_methods.R", file.arg)
source(incl.path, chdir=TRUE)

args <- commandArgs(trailingOnly=TRUE)

if(length(args) < 4) {
    print("Invalid arguments.\n\n")
    args <- c("--help")
}

if("--help" %in% args) {
    cat("
        Load in Salmon equivalence classes from two samples,
        match them and perform differential expression analysis
        between equivalence class counts between case and control
        samples.

        Usage:
        Rscript compare_eq_classes.R <case_name> <ec_matrix> <tx_ref_fasta> <output> --FDR=<value> --minCPM=<value> --minLogFC=<value>)\n\n

        All flags are optonal. The defaults are:
        FDR = 0.05
        minCPM = 0.1
        minLogFC = 5\n\n
    ")

    q(save="no")
}

MIN_CONTROLS <- 1
GENE_REGEX <- "gene_symbol:([a-zA-Z0-9.-]+)"

FDR <- 0.05
minCPM <- 0.1
minLogFC <- 5

#############################################################
# Parse arguments
#############################################################

args <- commandArgs(trailingOnly=TRUE)
case_name <- args[1]
ec_matrix_file <- args[2]
tx_ref_fasta <- args[3]
outfile <- args[4]
test_mode <- length(grep("--test", args)) > 0

# optional flags
set_arg <- function(argname) {
    flag <- paste0("--", argname, "=")
    arg <- grep(flag, args, value=T)
    if(!length(arg) == 0) {
        value <- as.numeric(strsplit(arg, "=")[[1]][2])
        if(is.na(value)) {
            stop(paste("Invalid", argname, "value."))
        }
        assign(argname, value, envir = .GlobalEnv)
    }
}
set_arg("FDR")
set_arg("minCPM")
set_arg("minLogFC")

#############################################################
# load data
#############################################################

print("Reading input data...")
ec_matrix <- fread(ec_matrix_file, sep="\t")
n_controls <- ncol(ec_matrix) - 4
if(n_controls < MIN_CONTROLS) {
    stop(paste("Insufficient controls. Please run MINTIE with at least", MIN_CONTROLS, "controls."))
}

# get reference transcript IDs
txs <- fread(tx_ref_fasta, header=FALSE, sep="\n")
txs <- txs[grep("^>", txs$V1),]
txs <- sapply(txs$V1, function(x){strsplit(x, " ")[[1]][1]})
txs <- as.character(sapply(txs, gsub, pattern=">", replacement=""))

#############################################################
# Prepare data for DE analysis
#############################################################

print("Extracting ECs associated with only novel contigs...")
tx_ec <- data.table(distinct(ec_matrix[,c("ec_names", "transcript")]))
tx_ec$assembled <- !tx_ec$transcript%in%txs
novel_contig_ecs <- tx_ec[, all(assembled), by="ec_names"]
novel_contig_ecs <- unique(novel_contig_ecs$ec_names[novel_contig_ecs$V1])
if(length(novel_contig_ecs) == 0) {
    stop("No novel ECs were found. Pipeline cannot continue.")
}

# write EC > TX lookup for reference
novel_contig_outfile <- paste0(dirname(outfile), "/ec_tx_table.txt")
tx_ec$novel_ec <- tx_ec$ec_names %in% novel_contig_ecs
tx_ec$assembled <- NULL
write.table(tx_ec, novel_contig_outfile, sep="\t", quote=FALSE, row.names=FALSE)

# make collapsed EC > contig lookup table
tx_ec <- tx_ec[tx_ec$novel_ec,]
tx_ec <- tx_ec[, paste(transcript, collapse=":"), by="ec_names"]
colnames(tx_ec)[2] <- "contigs"

#############################################################
# Perform DE
#############################################################

print("Performing differential expression analysis...")
de_results <- run_edgeR(case_name, ec_matrix, tx_ec, dirname(outfile),
                        cpm_cutoff=minCPM, qval=FDR, min_logfc=minLogFC)
if(nrow(de_results) == 0) {
    stop("Invalid output result obtained from differential expression. Please check all input data.")
}

#############################################################
# Compile and write results
#############################################################

print("Compiling and writing results...")

# separate out contigs
contigs <- sapply(de_results$contigs, strsplit, split=":")
de_results <- de_results[rep(1:nrow(de_results), as.numeric(sapply(contigs, length))),]
de_results$contig <- as.character(unlist(contigs))

write.table(de_results, outfile, row.names=F, quote=F, sep="\t")
