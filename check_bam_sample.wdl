version 1.0

import "ExtractHeader.1.wdl" as tasks

workflow check_bam_sample {
    input {
        File bam_file
        String data_type
        String id_in_table
        String workspace_name
        String workspace_namespace
    }

    Int disk_gb = ceil(size(bam_file, "GiB")*3) + 20

    call tasks.SamtoolsView {
        input: input_bam = bam_file,
               output_filename = "header.txt",
               disk_size = disk_gb
    }

    call compare_samples {
        input: header_file = SamtoolsView.output_file,
               data_type = data_type,
               id_in_table = id_in_table,
               workspace_name = workspace_name,
               workspace_namespace = workspace_namespace
    }

    output {
        String bam_sample_check = compare_samples.check_status
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
     }
}


task compare_samples {
    input {
        File header_file
        String data_type
        String id_in_table
        String workspace_name
        String workspace_namespace
    }

    command <<<
        Rscript -e "\
        workspace_name <- '~{workspace_name}'; \
        workspace_namespace <- '~{workspace_namespace}'; \
        aligned_table_name <- paste0('aligned_', '~{data_type}'); \
        aligned_id_name <- paste0(aligned_table_name, '_id'); \
        aligned_set_table_name <- paste0(aligned_table_name, '_set'); \
        aligned_set_id_name <- paste0(aligned_set_table_name, '_id'); \
        experiment_table_name <- paste0('experiment_', '~{data_type}'); \
        experiment_id_name <- paste0(experiment_table_name, '_id'); \
        id <- '~{id_in_table}'; \
        aligned_table <- AnVIL::avtable(aligned_table_name, name=workspace_name, namespace=workspace_namespace); \
        experiments <- aligned_table[[experiment_id_name]][aligned_table[[aligned_id_name]] %in% id]; \
        experiment_table <- AnVIL::avtable(experiment_table_name, name=workspace_name, namespace=workspace_namespace); \
        if ('experiment_sample_id' %in% names(experiment_table)) samples <- experiment_table[['experiment_sample_id']][experiment_table[[experiment_id_name]] %in% experiments] else samples <- experiments; \
        writeLines(as.character(samples), 'workspace_sample.txt'); \
        bam_header <- readLines('~{header_file}'); \
        hdr_line <- bam_header[grep('^@RG', bam_header)[1]]; \
        hdr_vals <- strsplit(hdr_line, '\t')[[1]]; \
        bam_sample <- sub('^SM:', '', hdr_vals[grep('^SM:', hdr_vals)]); \
        writeLines(as.character(bam_sample), 'bam_sample.txt'); \
        if (setequal(samples, bam_sample)) status <- 'PASS' else status <- 'FAIL'; \
        cat(status, file='status.txt'); \
        if (status == 'FAIL') stop('Samples do not match; compare bam_sample.txt and workspace_sample.txt')
        "
    >>>

    output {
        String check_status = read_string("status.txt")
        File workspace_sample = "workspace_samples.txt"
        File bam_sample = "bam_sample.txt"
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}


task summarize_bam_check {
    input {
        Array[String] file
        Array[String] bam_check
    }

    command <<<
        Rscript -e "\
        files <- readLines('~{write_lines(file)}'); \
        checks <- readLines('~{write_lines(bam_check)}'); \
        library(dplyr); \
        dat <- tibble(file_path=files, bam_check=checks); \
        readr::write_tsv(dat, 'details.txt'); \
        ct <- mutate(count(dat, bam_check), x=paste(n, bam_check)); \
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
