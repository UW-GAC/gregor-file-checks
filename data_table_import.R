library(argparser)
library(AnvilDataModels)

argp <- arg_parser("report")
argp <- add_argument(argp, "--table_files", help="2-column tsv file with (table name, table tsv file)")
argp <- add_argument(argp, "--model_file", help="tsv file with data model")
argp <- add_argument(argp, "--overwrite", flag=TRUE, help="overwrite existing rows in tables")
argp <- add_argument(argp, "--workspace_name", help="name of AnVIL workspace to import data to")
argp <- add_argument(argp, "--workspace_namespace", help="namespace of AnVIL workspace to import data to")
argv <- parse_args(argp)

# argv <- list(table_files="testdata/table_files.tsv",
#              model_file="testdata/data_model.tsv",
#              overwrite=FALSE)

# identify table files
table_files <- readr::read_tsv(argv$table_files, col_names=c("names", "files"), col_types = readr::cols())

# read data model
model <- tsv_to_dm(argv$model_file)

# verify that tables match data model
params <- list(tables=setNames(table_files$files, table_files$names), model=argv$model_file)
pass <- custom_render_markdown("data_model_report", "pre_import_check", parameters=params)
if (!pass) stop("table_files not compatible with data model; see pre_import_check.html")

# read tables
tables <- read_data_tables(table_files$files, table_names=table_files$names)

# identify set tables
set_flag <- grepl("_set$", table_files$names)
sets <- table_files$names[set_flag]
not_sets <- table_files$names[!set_flag]

# must write sets after other tables
for (t in not_sets) {
    anvil_import_table(tables[[t]], table_name=t, model=model, overwrite=argv$overwrite,
                       namespace=argv$workspace_namespace, name=argv$workspace_name)
}

for (t in sets) {
    anvil_import_set(tables[[t]], table_name=t, overwrite=argv$overwrite,
                     namespace=argv$workspace_namespace, name=argv$workspace_name)
}
