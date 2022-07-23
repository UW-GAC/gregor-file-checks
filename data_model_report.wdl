version 1.0

workflow data_model_report {
    input {
        Map[String, File] table_files
        String model_url
        String out_prefix
    }

    call results {
        input: table_files = table_files,
               model_url = model_url,
               out_prefix = out_prefix
    }

    output {
        File file_report = results.file_report
        Array[File]? tables = results.tables
        Boolean pass_checks = results.pass_checks
    }

     meta {
          author: "Stephanie Gogarten"
          email: "sdmorris@uw.edu"
    }
}

task results{
    input {
        Map[String, File] table_files
        String model_url
        String out_prefix
    }

    command {
        Rscript /usr/local/primed-file-checks/data_model_report.R \
            --table_files ${write_map(table_files)} \
            --model_file ${model_url} \
            --out_prefix ${out_prefix}
    }

    output {
        File file_report = "${out_prefix}.html"
        Array[File]? tables = glob("*_table.tsv")
        Boolean pass_checks = read_boolean("pass.txt")
    }

    runtime {
        docker: "uwgac/anvildatamodels:0.1.0"
    }
}
