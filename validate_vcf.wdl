version 1.0

import "check_vcf_samples.wdl" as vcf

workflow validate_vcf {
    input {
        Map[String, File] table_files
        String workspace_name
        String workspace_namespace
    }

    call select_vcf_files {
        input: table_files = table_files
    }

    if (select_vcf_files.files_to_check[0] != "NULL") {
        scatter (pair in zip(zip(select_vcf_files.files_to_check, select_vcf_files.ids_to_check), 
                            select_vcf_files.types_to_check)) {
            call vcf.check_vcf_samples {
                input: vcf_file = pair.left.left,
                    id_in_table = pair.left.right,
                    data_type = pair.right,
                    workspace_name = workspace_name,
                    workspace_namespace = workspace_namespace,
                    stop_on_fail = false
            }
        }

        call vcf.summarize_vcf_check {
            input: file = select_vcf_files.files_to_check,
                vcf_check = check_vcf_samples.vcf_sample_check
        }
    }

    output {
        String? vcf_check_summary = summarize_vcf_check.summary
        File? vcf_check_details = summarize_vcf_check.details
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
    }
}


task select_vcf_files {    
    input {
        Map[String, File] table_files
    }

    command <<<
        Rscript -e "\
        library(tidyverse); \
        table_files <- read_tsv('~{write_map(table_files)}', col_names=c("names", "files"), col_types="cc"); \
        print(head(table_files)); \
        tables <- table_files[['files']]; \
        names(tables) <- table_files[['names']]; \
        print(head(tables)); \
        vcf_cols <- c('called_variants_dna_short_read'='called_variants_dna_file', \
            'called_variants_nanopore'='called_variants_dna_file',
            'called_variants_pac_bio'='called_variants_dna_file', \
            'called_variants_optical_mapping'='optical_mapping_vcf_file'); \
        id_cols <- c('called_variants_dna_short_read'='called_variants_dna_short_read_id', \
            'called_variants_nanopore'='called_variants_nanopore_id', \
            'called_variants_pac_bio'='called_variants_pac_bio_id', \
            'called_variants_optical_mapping'='called_variants_optical_mapping_id'); \
        tables <- tables[names(tables) %in% names(vcf_cols)]; \
        files <- list(); ids <- list(); types <- list(); \
        for (t in names(tables)) { \
          dat <- readr::read_tsv(tables[t]); \
          files[[t]] <- dat[[vcf_cols[t]]]; \
          ids[[t]] <- dat[[id_cols[t]]]; \
          types[[t]] <- rep(sub('^called_variants_', '', t), nrow(dat)); \
        }; \
        if (length(unlist(files)) > 0) { \
          writeLines(unlist(files), 'file.txt'); \
          writeLines(unlist(ids), 'id.txt'); \
          writeLines(unlist(types), 'type.txt'); \
        } else { \
          writeLines('NULL', 'file.txt'); \
          writeLines('NULL', 'id.txt'); \
          writeLines('NULL', 'type.txt'); \
        } \
        "
    >>>

    output {
        Array[String] files_to_check = read_lines("file.txt")
        Array[String] ids_to_check = read_lines("id.txt")
        Array[String] types_to_check = read_lines("type.txt")
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}
