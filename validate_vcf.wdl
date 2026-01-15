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
