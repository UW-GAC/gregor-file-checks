version 1.0

import "check_vcf_samples.wdl" as vcf
import "validate_gregor_model.wdl" as validate

workflow validate_vcf {
    input {
        Array[File] table_files
        String workspace_name
        String workspace_namespace
    }

    call validate.select_vcf_files {
        input: validated_table_files = table_files
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

        call summarize_vcf_check_samples {
            input: file = select_vcf_files.files_to_check,
                vcf_check = check_vcf_samples.vcf_sample_check

        }
    }

    output {
        String? vcf_check_summary = summarize_vcf_check_samples.summary
        File? vcf_check_details = summarize_vcf_check_samples.details
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
    }
}


task summarize_vcf_check_samples {
    input {
        Array[String] file
        Array[String] vcf_check
        Array[String] first_vcf_sample
        Array[String] first_workspace_sample
    }

    command <<<
        Rscript -e "\
        files <- readLines('~{write_lines(file)}'); \
        checks <- readLines('~{write_lines(vcf_check)}'); \
        vcf_sample <- readLines('~{write_lines(first_vcf_sample)}'); \
        workspace_sample <- readLines('~{write_lines(first_workspace_sample)}'); \
        library(dplyr); \
        dat <- tibble(file_path=files, vcf_check=checks, first_vcf_sample=vcf_sample, first_workspace_sample=workspace_sample); \
        readr::write_tsv(dat, 'details.txt'); \
        ct <- mutate(count(dat, vcf_check), x=paste(n, vcf_check)); \
        writeLines(paste(ct[['x']], collapse=', '), 'summary.txt'); \
        "
    >>>
    
    output {
        String summary = read_string("summary.txt")
        File details = "details.txt"
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}
