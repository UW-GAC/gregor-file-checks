version 1.0

workflow check_vcf_samples {
    input {
        File vcf_file
        String data_type
        String id_in_table
        String workspace_name
        String workspace_namespace
    }

    Int disk_gb = ceil(size(vcf_file, "GB")*1.5) + 5

    call vcf_samples {
        input: vcf_file = vcf_file,
               disk_gb = disk_gb
    }

    call compare_sample_sets {
        input: sample_file = vcf_samples.sample_file,
               data_type = data_type,
               id_in_table = id_in_table,
               workspace_name = workspace_name,
               workspace_namespace = workspace_namespace
    }

    output {
        String vcf_sample_check = compare_sample_sets.check_status
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
     }
}

task vcf_samples {
    input {
        File vcf_file
        Int disk_gb = 10
    }

    command {
        bcftools query --list-samples ${vcf_file} > vcf_samples.txt
    }

    output {
        File sample_file = "vcf_samples.txt"
    }

    runtime {
        docker: "xbrianh/xsamtools:v0.5.2"
        disks: "local-disk ${disk_gb} SSD"
    }
}

task compare_sample_sets {
    input {
        File sample_file
        String data_type
        String id_in_table
        String workspace_name
        String workspace_namespace
    }

    command <<<
        Rscript -e "\
        workspace_name <- '~{workspace_name}'; \
        workspace_namespace <- '~{workspace_namespace}'; \
        variants_table_name <- paste0('called_variants_', '~{data_type}'); \
        variants_id_name <- paste0(variants_table_name, '_id'); \
        aligned_table_name <- paste0('aligned_', '~{data_type}'); \
        aligned_id_name <- paste0(aligned_table_name, '_id'); \
        aligned_set_table_name <- paste0(aligned_table_name, '_set'); \
        aligned_set_id_name <- paste0(aligned_set_table_name, '_id'); \
        experiment_table_name <- paste0('experiment_', '~{data_type}'); \
        experiment_id_name <- paste0(experiment_table_name, '_id'); \
        id <- '~{id_in_table}'; \
        variants_table <- AnVIL::avtable(variants_table_name, name=workspace_name, namespace=workspace_namespace); \
        aligned_set_id <- variants_table[[aligned_set_id_name]][variants_table[[variants_id_name]] == id]; \
        aligned_set <- AnVIL::avtable(aligned_set_table_name, name=workspace_name, namespace=workspace_namespace); \
        aligned_reads <- aligned_set[[paste0(aligned_table_name, 's.items')]][aligned_set[[aligned_set_id_name]] == aligned_set_id][[1]][['entityName']]; \
        aligned_table <- AnVIL::avtable(aligned_table_name, name=workspace_name, namespace=workspace_namespace); \
        experiments <- aligned_table[[experiment_id_name]][aligned_table[[aligned_id_name]] %in% aligned_reads]; \
        experiment_table <- AnVIL::avtable(experiment_table_name, name=workspace_name, namespace=workspace_namespace); \
        if ('experiment_sample_id' %in% names(experiment_table)) samples <- experiment_table[['experiment_sample_id']][experiment_table[[experiment_id_name]] %in% experiments] else samples <- experiments; \
        writeLines(as.character(samples), 'workspace_samples.txt'); \
        vcf_samples <- readLines('~{sample_file}'); \
        if (setequal(samples, vcf_samples)) status <- 'PASS' else status <- 'FAIL'; \
        cat(status, file='status.txt'); \
        if (status == 'FAIL') stop('Samples do not match; compare vcf_samples.txt and workspace_samples.txt')
        "
    >>>

    output {
        String check_status = read_string("status.txt")
        File workspace_samples = "workspace_samples.txt"
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.17.0"
    }
}


task summarize_vcf_check {
    input {
        Array[String] file
        Array[String] vcf_check
    }

    command <<<
        Rscript -e "\
        files <- readLines('~{write_lines(file)}'); \
        checks <- readLines('~{write_lines(vcf_check)}'); \
        library(dplyr); \
        dat <- tibble(file_path=files, vcf_check=checks); \
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
