version 1.0

import "https://raw.githubusercontent.com/UW-GAC/anvil-util-workflows/main/validate_data_model.wdl" as validate
import "https://raw.githubusercontent.com/UW-GAC/anvil-util-workflows/main/check_md5.wdl" as md5
import "check_vcf_samples.wdl" as vcf
import "check_bam_sample.wdl" as bam

workflow validate_gregor_model {
    input {
        Map[String, File] table_files
        String model_url
        String workspace_name
        String workspace_namespace
        Boolean overwrite = false
        Boolean import_tables = false
        Boolean check_bucket_paths = true
        Boolean check_md5 = true
        Boolean check_vcf = true
        Boolean check_bam = false
        Boolean check_phenotype_terms = true
        Int? hash_id_nchar
        String? project_id
    }

    call validate.validate {
        input: table_files = table_files,
               model_url = model_url,
               hash_id_nchar = hash_id_nchar,
               workspace_name = workspace_name,
               workspace_namespace = workspace_namespace,
               overwrite = overwrite,
               import_tables = import_tables,
               check_bucket_paths = check_bucket_paths
    }

    # need this because validate.tables is optional but input to select_md5_files is required
    Array[File] val_tables = select_first([validate.tables, ""])

    if (defined(validate.tables)) {
        if (check_phenotype_terms) {
            call check_term_id {
                input: validated_table_files = val_tables
            }
        }

        if (check_md5) {
            call select_md5_files {
                input: validated_table_files = val_tables
            }

            if (select_md5_files.files_to_check[0] != "NULL") {
                scatter (pair in zip(select_md5_files.files_to_check, select_md5_files.md5sum_to_check)) {
                    call md5.md5check {
                        input: file = pair.left,
                            md5sum = pair.right,
                            project_id = project_id
                    }
                }

                call md5.summarize_md5_check {
                    input: file = select_md5_files.files_to_check,
                        md5_check = md5check.md5_check,
                        id = select_md5_files.ids_to_check
                }
            }
        }

        # can only check VCF files once tables are imported since check_vcf_samples reads tables
        if (check_vcf && import_tables) {
            call select_vcf_files {
                input: validated_table_files = val_tables
            }

            if (select_vcf_files.files_to_check[0] != "NULL") {
                scatter (pair in zip(zip(select_vcf_files.files_to_check, select_vcf_files.ids_to_check), 
                                    select_vcf_files.types_to_check)) {
                    call vcf.check_vcf_samples {
                        input: vcf_file = pair.left.left,
                            id_in_table = pair.left.right,
                            data_type = pair.right,
                            workspace_name = workspace_name,
                            workspace_namespace = workspace_namespace
                    }
                }

                call vcf.summarize_vcf_check {
                    input: file = select_vcf_files.files_to_check,
                        vcf_check = check_vcf_samples.vcf_sample_check
                }
            }
        }

        if (check_bam && import_tables) {
            call select_bam_files {
                input: validated_table_files = val_tables
            }

            if (select_bam_files.files_to_check[0] != "NULL") {
                scatter (pair in zip(zip(select_bam_files.files_to_check, select_bam_files.ids_to_check), 
                                    select_bam_files.types_to_check)) {
                    call bam.check_bam_sample {
                        input: bam_file = pair.left.left,
                            id_in_table = pair.left.right,
                            data_type = pair.right,
                            workspace_name = workspace_name,
                            workspace_namespace = workspace_namespace
                    }
                }

                call bam.summarize_bam_check {
                    input: file = select_bam_files.files_to_check,
                        bam_check = check_bam_sample.bam_sample_check
                }
            }
        }
    }

    output {
        File validation_report = validate.validation_report
        Array[File]? tables = validate.tables
        String? md5_check_summary = summarize_md5_check.summary
        File? md5_check_details = summarize_md5_check.details
        String? vcf_check_summary = summarize_vcf_check.summary
        File? vcf_check_details = summarize_vcf_check.details
        String? bam_check_summary = summarize_bam_check.summary
        File? bam_check_details = summarize_bam_check.details
        File? phenotype_terms_check = check_term_id.phenotype_terms_check
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
    }
}


task check_term_id {
    input {
        Array[File] validated_table_files
    }

    command <<<
        R << RSCRIPT
            library(tidyverse)

            match_term <- function(ontology, term) {
                patterns <- c(
                    "HPO" = "^HP:[0-9]{7}$",
                    "MONDO" = "^MONDO:[0-9]{7}$",
                    "OMIM" = "^OMIM:[0-9]{6}$",
                    "ORPHANET" = "^ORPHA:[0-9]+$",
                    "SNOMED" = "^SCTID:[0-9]+$",
                    "ICD10" = "^[A-Z][0-9]{2}([.][0-9]+)?$"
                )
                str_detect(term, patterns[ontology])
            }

            tables <- readLines('~{write_lines(validated_table_files)}')
            phenotype_file <- tables[str_detect(tables, 'phenotype')]
            if (length(phenotype_file) > 0) {
                phen <- read_tsv(phenotype_file) %>%
                    select(phenotype_id, participant_id, ontology, term_id)
                mismatches <- phen %>%
                    filter(!match_term(ontology, term_id)) %>%
                    select(phenotype_id, participant_id, ontology, term_id)
                write_tsv(mismatches, 'term_id_errors.tsv')
                if (nrow(mismatches) == 0) status <- 'PASS' else status <- 'FAIL'
                cat(status, file='status.txt')
                if (status == 'FAIL') stop('Phenotype term IDs do not match expected formats; see term_id_errors.tsv for details')
            } else {
                writeLines('No phenotype table found, skipping check', 'status.txt')
                writeLines('', 'term_id_errors.tsv')
            }
        RSCRIPT
    >>>

    output {
        String check_status = read_string("status.txt")
        File phenotype_terms_check = "term_id_errors.tsv"
    }

    runtime {
        docker: "rocker/tidyverse:4"
    }
}


task select_md5_files {
    input {
        Array[File] validated_table_files
    }

    command <<<
        Rscript -e "\
        tables <- readLines('~{write_lines(validated_table_files)}'); \
        names(tables) <- sub('^output_', '', sub('_table.tsv', '', basename(tables))); \
        md5_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_file', \
          'called_variants_dna_short_read'='called_variants_dna_file', \
          'aligned_rna_short_read'='aligned_rna_short_read_file', \
          'readcounts_rna_short_read'='readcounts_rna_file', \
          'aligned_nanopore'='aligned_nanopore_file', \
          'called_variants_nanopore'='called_variants_dna_file', \
          'aligned_pac_bio'='aligned_pac_bio_file', \
          'called_variants_pac_bio'='called_variants_dna_file', \
          'aligned_atac_short_read'='aligned_atac_short_read_file', \
          'called_peaks_atac_short_read'='called_peaks_file', \
          'molecule_file_optical_mapping'='bnx_file', \
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_file', \
          'called_variants_optical_mapping'='optical_mapping_vcf_file', \
          'mass_spectra_metabolomics'='mass_spectra_file', \
          'preprocessed_file_metabolomics'='preprocessed_file', \
          'processed_file_metabolomics'='processed_file', \
          'harmonized_file_metabolomics'='harmonized_file'); \
        id_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_id', \
          'called_variants_dna_short_read'='called_variants_dna_short_read_id', \
          'aligned_rna_short_read'='aligned_rna_short_read_id', \
          'readcounts_rna_short_read'='readcounts_rna_short_read_id', \
          'aligned_nanopore'='aligned_nanopore_id', \
          'called_variants_nanopore'='called_variants_nanopore_id', \
          'aligned_pac_bio'='aligned_pac_bio_id', \
          'called_variants_pac_bio'='called_variants_pac_bio_id', \
          'aligned_atac_short_read'='aligned_atac_short_read_id', \
          'called_peaks_atac_short_read'='called_peaks_atac_short_read_id', \
          'molecule_file_optical_mapping'='molecule_file_optical_mapping_id', \
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_id', \
          'called_variants_optical_mapping'='called_variants_optical_mapping_id', \
          'mass_spectra_metabolomics'='mass_spectra_metabolomics_id', \
          'preprocessed_file_metabolomics'='preprocessed_file_metabolomics_id', \
          'processed_file_metabolomics'='processed_file_metabolomics_id', \
          'harmonized_file_metabolomics'='harmonized_file_metabolomics_id'); \
        tables <- tables[names(tables) %in% names(md5_cols)]; \
        files <- list(); md5 <- list(); ids <- list(); \
        for (t in names(tables)) { \
          dat <- readr::read_tsv(tables[t]); \
          files[[t]] <- dat[[md5_cols[t]]]; \
          md5[[t]] <- dat[['md5sum']]; \
          ids[[t]] <- dat[[id_cols[t]]]; \
        }; \
        if (length(unlist(files)) > 0) { \
          writeLines(unlist(files), 'file.txt'); \
          writeLines(unlist(md5), 'md5sum.txt'); \
          writeLines(unlist(ids), 'id.txt'); \
        } else { \
          writeLines('NULL', 'file.txt'); \
          writeLines('NULL', 'md5sum.txt'); \
          writeLines('NULL', 'id.txt'); \
        } \
        "
    >>>

    output {
        Array[String] files_to_check = read_lines("file.txt")
        Array[String] md5sum_to_check = read_lines("md5sum.txt")
        Array[String] ids_to_check = read_lines("id.txt")
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}


task select_vcf_files {    
    input {
        Array[File] validated_table_files
    }

    command <<<
        Rscript -e "\
        tables <- readLines('~{write_lines(validated_table_files)}'); \
        names(tables) <- sub('^output_', '', sub('_table.tsv', '', basename(tables))); \
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


task select_bam_files {
    input {
        Array[File] validated_table_files
    }

    command <<<
        Rscript -e "\
        tables <- readLines('~{write_lines(validated_table_files)}'); \
        names(tables) <- sub('^output_', '', sub('_table.tsv', '', basename(tables))); \
        bam_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_file', \
          'aligned_rna_short_read'='aligned_rna_short_read_file', \
          'aligned_nanopore'='aligned_nanopore_file', \
          'aligned_pac_bio'='aligned_pac_bio_file', \
          'aligned_atac_short_read'='aligned_atac_short_read_file', \
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_file'); \
        id_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_id', \
          'aligned_rna_short_read'='aligned_rna_short_read_id', \
          'aligned_nanopore'='aligned_nanopore_id', \
          'aligned_pac_bio'='aligned_pac_bio_id', \
          'aligned_atac_short_read'='aligned_atac_short_read_id', \
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_id'); \
        tables <- tables[names(tables) %in% names(bam_cols)]; \
        files <- list(); ids <- list(); types <- list(); \
        for (t in names(tables)) { \
          dat <- readr::read_tsv(tables[t]); \
          files[[t]] <- dat[[bam_cols[t]]]; \
          ids[[t]] <- dat[[id_cols[t]]]; \
          types[[t]] <- rep(sub('^aligned_', '', t), nrow(dat)); \
        }; \
        if (length(files) > 0) { \
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
