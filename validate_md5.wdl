version 1.0

workflow validate_md5 {
    input {
        File data_table
        String table_name
    }

    call identify_columns {
        input:
            table_name = table_name
    }

    call check_md5 {
        input:
            data_table = data_table,
            file_column = identify_columns.file_column,
            md5_column = identify_columns.md5_column,
            id_column = identify_columns.id_column
    }

    output {
        File md5_check = check_md5.md5_check
        String md5_check_status = check_md5.md5_check_status
    }
}


task identify_columns {
    input {
        String table_name
    }

    command <<<
        R << RSCRIPT
        file_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_file',
          'called_variants_dna_short_read'='called_variants_dna_file',
          'aligned_rna_short_read'='aligned_rna_short_read_file',
          'readcounts_rna_short_read'='readcounts_rna_file',
          'aligned_nanopore'='aligned_nanopore_file',
          'called_variants_nanopore'='called_variants_dna_file',
          'aligned_pac_bio'='aligned_pac_bio_file',
          'called_variants_pac_bio'='called_variants_dna_file',
          'aligned_atac_short_read'='aligned_atac_short_read_file',
          'called_peaks_atac_short_read'='called_peaks_file',
          'molecule_file_optical_mapping'='bnx_file',
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_file',
          'called_variants_optical_mapping'='optical_mapping_vcf_file',
          'mass_spectra_metabolomics'='mass_spectra_file',
          'preprocessed_file_metabolomics'='preprocessed_file',
          'processed_file_metabolomics'='processed_file',
          'harmonized_file_metabolomics'='harmonized_file');
        id_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_id',
          'called_variants_dna_short_read'='called_variants_dna_short_read_id',
          'aligned_rna_short_read'='aligned_rna_short_read_id',
          'readcounts_rna_short_read'='readcounts_rna_short_read_id',
          'aligned_nanopore'='aligned_nanopore_id',
          'called_variants_nanopore'='called_variants_nanopore_id',
          'aligned_pac_bio'='aligned_pac_bio_id',
          'called_variants_pac_bio'='called_variants_pac_bio_id',
          'aligned_atac_short_read'='aligned_atac_short_read_id',
          'called_peaks_atac_short_read'='called_peaks_atac_short_read_id',
          'molecule_file_optical_mapping'='molecule_file_optical_mapping_id',
          'aligned_molecules_optical_mapping'='aligned_molecules_optical_mapping_id',
          'called_variants_optical_mapping'='called_variants_optical_mapping_id',
          'mass_spectra_metabolomics'='mass_spectra_metabolomics_id',
          'preprocessed_file_metabolomics'='preprocessed_file_metabolomics_id',
          'processed_file_metabolomics'='processed_file_metabolomics_id',
          'harmonized_file_metabolomics'='harmonized_file_metabolomics_id');
        md5_col <- "md5sum"
        writeLines(file_cols["~{table_name}"], "file_column.txt")
        writeLines(id_cols["~{table_name}"], "id_column.txt")
        writeLines(md5_col, "md5_column.txt")
        RSCRIPT
    >>>

    output {
        String file_column = read_string("file_column.txt")
        String id_column = read_string("id_column.txt")
        String md5_column = read_string("md5_column.txt")
    }

    runtime {
        docker: "rocker/tidyverse:4"
    }
}


task check_md5 {
    input {
        File data_table
        String file_column
        String md5_column
        String id_column
    }

    command <<<
        R << RSCRIPT
        library(tidyverse)
        md5 <- function(f) {
            AnVIL::gsutil_stat(f) %>%
                select(`Hash (md5)`) %>%
                unlist() %>%
                writeLines("md5_b64.txt")
            system("python3 -c \"import base64; import binascii; print(binascii.hexlify(base64.urlsafe_b64decode(open('md5_b64.txt').read())))\" | cut -d \"'\" -f 2 > md5_hex.txt")
            hex <- readLines("md5_hex.txt")
            file.remove(c("md5_hex.txt", "md5_b64.txt"))
            return(hex)
        }
        tbl <- read_tsv("~{data_table}") %>%
            select(~{id_column}, ~{file_column}, ~{md5_column}) %>%
            rowwise() %>%
            mutate(md5_metadata = md5(~{file_column}))
        tbl <- tbl %>%
            mutate(status = ifelse(is.na(md5_metadata), "UNVERIFIED",
                                 ifelse(md5_metadata == ~{md5_column}, "PASS", "FAIL")))
        write_tsv(tbl, "md5_check.txt")
        status <- if (all(tbl$status == "PASS")) "PASS" else "FAIL"
        writeLines(status, "status.txt")
        RSCRIPT
    >>>

    output {
        File md5_check = "md5_check.txt"
        String md5_check_status = read_string("status.txt")
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}