library(argparser)
library(AnvilDataModels)

argp <- arg_parser("report")
argp <- add_argument(argp, "--table_files", help="2-column tsv file with (table name, table tsv file)")
argp <- add_argument(argp, "--model_file", help="tsv file with data model")
argp <- add_argument(argp, "--out_prefix", help="output prefix")
argv <- parse_args(argp)

# argv <- list(table_files="testdata/table_files.tsv",
#              model_file="testdata/data_model.tsv",
#              out_prefix="test")

# read data model
model <- tsv_to_dm(argv$model_file)

# read tables
table_files <- readr::read_tsv(argv$table_files, col_names=c("names", "files"), col_types = readr::cols())

# check if we need to add any columns to files
if (length(attr(model, "auto_id")) > 0) {
    tables <- read_data_tables(table_files$files, table_names=table_files$names)
    
    # add auto columns
    tables2 <- lapply(names(tables), function(t) {
        add_auto_columns(tables[[t]], table_name=t, model=model)
    })
    names(tables2) <- names(tables)
    
    # write new tables
    new_files <- paste(argv$out_prefix, names(tables), "table.tsv", sep="_")
    names(new_files) <- names(tables)
    for (t in names(tables2)) {
        readr::write_tsv(tables2[[t]], new_files[t])
    }
    
    params <- list(tables=new_files, model=argv$model_file)
} else {
    params <- list(tables=setNames(table_files$files, table_filess$names), model=argv$model_file)
}

pass <- custom_render_markdown("data_model_report", argv$out_prefix, parameters=params)
writeLines(tolower(as.character(pass)), "pass.txt")
