version 1.0

import "https://raw.githubusercontent.com/UW-GAC/anvil-util-workflows/main/validate_data_model.wdl" as validate

workflow validate_gregor_model {
    input {
        Map[String, File] table_files
        String model_url
        String workspace_name
        String workspace_namespace
        Boolean overwrite = false
        Boolean import_tables = false
        Int? hash_id_nchar
    }

    # call validate.results {
    #     input: table_files = table_files,
    #            model_url = model_url,
    #            hash_id_nchar = hash_id_nchar,
    #            workspace_name = workspace_name,
    #            workspace_namespace = workspace_namespace,
    #            overwrite = overwrite,
    #            import_tables = import_tables
    # }

    call select_md5_files {
        input: workspace_name = workspace_name,
               workspace_namespace = workspace_namespace
    }

    # output {
    #     File validation_report = results.validation_report
    #     Array[File]? tables = results.tables
    # }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
    }
}


task select_md5_files {
    input {
        String workspace_name
        String workspace_namespace
    }

    command <<<
        Rscript -e "\
        workspace_name <- '~{workspace_name}'; \
        workspace_namespace <- '~{workspace_namespace}'; \
        tables <- AnVIL::avtables(name=workspace_name, namespace=workspace_namespace); \
        md5_cols <- c('aligned_dna_short_read'='aligned_dna_short_read_file', \
          'called_variants_dna_short_read'='called_variants_dna_file', \
          'aligned_rna_short_read'='aligned_rna_short_read_file'); \
        md5_cols <- md5_cols[intersect(names(md5_cols), tables[['table']])]; \
        files <- list(); md5 <- list();
        for (t in names(md5_cols)) { \
          dat <- AnVIL::avtable(t, name=workspace_name, namespace=workspace_namespace) \
          files[[t]] <- dat[[md5_cols[t]]] \
          md5[[t]] <- dat[['md5sum']] \
        }; \
        writeLines(unlist(files), 'file.txt'); \
        writeLines(unlist(md5), 'md5sum.txt'); \
        "
    >>>

    output {
        Array[String] files_to_check = read_lines("file.txt")
        Array[String] md5sum_to_check = read_lines("md5sum.txt")
    }

    runtime {
        docker: "us.gcr.io/broad-dsp-gcr-public/anvil-rstudio-bioconductor:3.16.0"
    }
}


#task select_vcf_files {    
#}

