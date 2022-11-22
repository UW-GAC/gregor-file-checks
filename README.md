# gregor-file-checks

Workflows for checking files in AnVIL, according to the [GREGoR data model](https://github.com/UW-GAC/gregor_data_models)

The workflows are written in the Workflow Description Language ([WDL](https://docs.dockstore.org/en/stable/getting-started/getting-started-with-wdl.html)). This GitHub repository contains the WDL code and a JSON file containing inputs to the workflow, both for testing and to serve as an example.


## check_vcf_samples

This workflow checks that the samples in the header of a VCF file match the sample ids in the data model (dataset_id -> sample_set_id -> sample_id).

The user must specify the following inputs:

input | description
--- | ---
vcf_file | Google bucket path to a VCF file
called_variants_dna_short_read_id | The id associated with the vcf_file
workspace_name | A string with the workpsace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace name is "Terra-Workflows-Quickstart"
workspace_namespace | A string with the workpsace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace namespace is "fc-product-demo"

The workflow returns the following outputs:

output | description
--- | ---
vcf_sample_check | "PASS" or "FAIL" indicating whether the VCF sample ids match the sample_set in the workspace data tables
