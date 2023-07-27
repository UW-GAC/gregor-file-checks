# gregor-file-checks

Workflows for checking files in AnVIL, according to the [GREGoR data model](https://github.com/UW-GAC/gregor_data_models)

The workflows are written in the Workflow Description Language ([WDL](https://docs.dockstore.org/en/stable/getting-started/getting-started-with-wdl.html)). This GitHub repository contains the WDL code and a JSON file containing inputs to the workflow, both for testing and to serve as an example.


## validate_gregor_model

Workflow to validate TSV files against the GREGoR data model using the [AnvilDataModels](https://github.com/UW-GAC/AnvilDataModels) package. An uploader will prepare files in tab separated values (TSV) format, with one file for each data table in the model, and upload them to an AnVIL workspace. This workflow will compare those files to the data model, and generate an HTML report describing any inconsistencies. 

If the data model specifies that any columns be auto-generated from other columns, the workflow generates TSV files with updated tables before running checks.

This workflow checks whether expected tables (both required and optional) are included. For each table, it checks column names, data types, and primary keys. Finally, it checks foreign keys (cross-references across tables). Results of all checks are displayed in an HTML file.

If any tables in the data model are not included in the "table_files" input but are already present in the workspace, the workflow will read them from the workspace for cross-checks with supplied tables.

If miminal checks are passed and `import_tables` is set to `true`, the workflow will then import the files as data tables in an AnVIL workspace. If checks are not passed, the workflow will fail and the user should review the file "data_model_validation.html" in the workflow output directory.

If validation is successful, the workflow will check the md5sums provided for each BAM/CRAM/VCF file against the value in google cloud storage. For each file, the workflow will return 'PASS' if the check was successful or 'UNVERIFIED' if the file was found but does not have an md5 value in its metadata. The workflow will fail if the md5sums do not match or if the file is not found. Review the log file for check details including the two md5 values compared.

If validation and import are successful and the called_variants_dna_short_read table is present, check_vcf_samples (see below) is run on all VCF files.

The user must specify the following inputs:

input | description
--- | ---
table_files | This input is of type Map[String, File], which consists of key:value pairs. Keys are table names, which should correspond to names in the data model, and values are Google bucket paths to TSV files for each table.
model_url | A URL providing the path to the data model in JSON format.
hash_id_nchar | Number of characters in auto-generated columns (default 16)
import_tables | A boolean indicating whether tables should be imported to a workspace after validation.
overwrite | A boolean indicating whether existing rows in the data tables should be overwritten.
workspace_name | A string with the workspace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace name is "Terra-Workflows-Quickstart"
workspace_namespace | A string with the workspace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace namespace is "fc-product-demo"
project_id | Google project id to bill for checking md5sums of files in requester_pays buckets.
vcf_disk_gb | Disk space required for each VCF file (default 10 GB). If the job fails due to lack of disk space, try setting this to a larger value.

The workflow returns the following outputs:

output | description
--- | ---
validation_report | An HTML file with validation results
tables | A file array with the tables after adding auto-generated columns. This output is not generated if no additional columns are specified in the data model.


## check_vcf_samples

This workflow checks that the samples in the header of a VCF file match the sample ids in the data model (dataset_id -> sample_set_id -> sample_id).

The user must specify the following inputs:

input | description
--- | ---
vcf_file | Google bucket path to a VCF file
called_variants_dna_short_read_id | The id associated with the vcf_file
workspace_name | A string with the workpsace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace name is "Terra-Workflows-Quickstart"
workspace_namespace | A string with the workpsace name. e.g, if the workspace URL is https://anvil.terra.bio/#workspaces/fc-product-demo/Terra-Workflows-Quickstart, the workspace namespace is "fc-product-demo"
disk_gb | Disk space required for the VCF file (default 10 GB). If the job fails due to lack of disk space, try setting this to a larger value.

The workflow returns the following outputs:

output | description
--- | ---
vcf_sample_check | "PASS" or "FAIL" indicating whether the VCF sample ids match the sample_set in the workspace data tables
