version 1.0

import "https://raw.githubusercontent.com/UW-GAC/anvil-util-workflows/main/validate_data_model.wdl" as validate
import "https://raw.githubusercontent.com/UW-GAC/anvil-util-workflows/main/check_md5.wdl" as md5
import "check_vcf_samples.wdl" as vcf

workflow validate_gregor_model {
    input {
        Map[String, File] table_files
        String model_url
        String workspace_name
        String workspace_namespace
        Boolean overwrite = false
        Boolean import_tables = false
        Boolean check_md5 = true
        Boolean check_vcf = true
        Int? hash_id_nchar
        Int? vcf_disk_gb
        String? project_id
    }

    call validate.validate {
        input: table_files = table_files,
               model_url = model_url,
               hash_id_nchar = hash_id_nchar,
               workspace_name = workspace_name,
               workspace_namespace = workspace_namespace,
               overwrite = overwrite,
               import_tables = import_tables
    }

    # need this because validate.tables is optional but input to select_md5_files is required
    Array[File] val_tables = select_first([validate.tables, ""])

    if (defined(validate.tables)) {
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
                        md5_check = md5check.md5_check
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
                            workspace_namespace = workspace_namespace,
                            disk_gb = vcf_disk_gb
                    }
                }

                call vcf.summarize_vcf_check {
                    input: file = select_vcf_files.files_to_check,
                        vcf_check = check_vcf_samples.vcf_sample_check
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
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
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
          'aligned_nanopore'='aligned_nanopore_file', \
          'called_variants_nanopore'='called_variants_dna_file'); \
        tables <- tables[names(tables) %in% names(md5_cols)]; \
        files <- list(); md5 <- list();
        for (t in names(tables)) { \
          dat <- readr::read_tsv(tables[t]); \
          files[[t]] <- dat[[md5_cols[t]]]; \
          md5[[t]] <- dat[['md5sum']]; \
        }; \
        if (length(files) > 0) { \
          writeLines(unlist(files), 'file.txt'); \
          writeLines(unlist(md5), 'md5sum.txt'); \
        } else { \
          writeLines('NULL', 'file.txt'); \
          writeLines('NULL', 'md5sum.txt'); \
        } \
        "
    >>>

    output {
        Array[String] files_to_check = read_lines("file.txt")
        Array[String] md5sum_to_check = read_lines("md5sum.txt")
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
            'called_variants_nanopore'='called_variants_dna_file'); \
        id_cols <- c('called_variants_dna_short_read'='called_variants_dna_short_read_id', \
            'called_variants_nanopore'='called_variants_nanopore_id'); \
        tables <- tables[names(tables) %in% names(vcf_cols)]; \
        files <- list(); ids <- list(); types <- list(); \
        for (t in names(tables)) { \
          dat <- readr::read_tsv(tables[t]); \
          files[[t]] <- dat[[vcf_cols[t]]]; \
          ids[[t]] <- dat[[id_cols[t]]]; \
          types[[t]] <- rep(sub('^called_variants_', '', t), nrow(dat)); \
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

