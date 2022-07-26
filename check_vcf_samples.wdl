version 1.0

workflow check_vcf_samples {
    input {
        File vcf_file
        String called_variants_dna_short_read_id
        String workspace_name
        String workspace_namespace
    }

    call vcf_samples {
        input: vcf_file = vcf_file
    }

    call compare_sample_sets {
        input: sample_file = vcf_samples.sample_file,
               called_variants_dna_short_read_id = called_variants_dna_short_read_id,
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
    }

    command {
        bcftools query --list-samples ${vcf_file} > samples.txt
    }

    output {
        File sample_file = "samples.txt"
    }

    runtime {
        docker: "xbrianh/xsamtools:v0.5.2"
    }
}

task compare_sample_sets {
    input {
        File sample_file
        String called_variants_dna_short_read_id
        String workspace_name
        String workspace_namespace
    }

    command {
        Rscript -e "\
        workspace_name <- '${workspace_name}'; \
        workspace_namespace <- '${workspace_namespace}'; \
        id <- '${called_variants_dna_short_read_id}'; \
        variants_table <- AnVIL::avtable('called_variants_dna_short_read', name=workspace_name, namespace=workspace_namespace); \
        aligned_set_id <- variants_table[['aligned_dna_short_read_set_id']][variants_table[['called_variants_dna_short_read_id']] == id]; \
        aligned_set <- AnVIL::avtable('aligned_dna_short_read_set', name=workspace_name, namespace=workspace_namespace); \
        aligned_reads <- aligned_set[['aligned_dna_short_reads.items']][aligned_set[['aligned_dna_short_read_set_id']] == aligned_set_id][[1]][['entityName']]; \
        aligned_table <- AnVIL::avtable('aligned_dna_short_read', name=workspace_name, namespace=workspace_namespace); \
        experiments <- aligned_table[['experiment_dna_short_read_id']][aligned_table[['aligned_dna_short_read_id']] %in% aligned_reads]; \
        experiment_table <- AnVIL::avtable('experiment_dna_short_read', name=workspace_name, namespace=workspace_namespace); \
        if ('experiment_sample_id' %in% names(experiment_table)) samples <- experiment_table[['experiment_sample_id']][experiment_table[['experiment_dna_short_read_id']] %in% experiments] else samples <- experiments; \
        vcf_samples <- readLines('${sample_file}'); \
        if (setequal(samples, vcf_samples)) status <- 'PASS' else status <- 'FAIL'; \
        cat(status, file='status.txt') \
        "
    }

    output {
        String check_status = read_string("status.txt")
    }

    runtime {
        docker: "us.gcr.io/anvil-gcr-public/anvil-rstudio-bioconductor-devel:3.15.0"
    }
}
