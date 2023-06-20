
participant <- tibble(
    participant_id = paste0("UW_DCC_participant_", 123:126),
    gregor_center = "UW_DCC",
    consent_code = c(rep("GRU", 2), rep("HMB", 2)),
    recontactable = c("Yes", "Yes", "No", "No"),
    prior_testing = c("Normal karyotype | FBN2 screened clinically", "", "Abnormal karyotype", ""),
    pmid_id = c("25683120", "", "25683120|25683125", ""),
    family_id = paste0("UW_DCC_FAM", c(rep("001", 3), "002")),
    paternal_id = c("UW_DCC_participant_124", rep(0, 3)),
    maternal_id = c("UW_DCC_participant_125", rep(0, 3)),
    proband_relationship = c("Self", "Mother", "Father", "Other"),
    proband_relationship_detail = c(rep("", 3), "Third cousins, through mother's side"),
    sex = c("Male", "Female", "Male", "Female"),
    sex_detail = c("XXY expected", "", "", "XY expected"),
    reported_race = c(rep("American Indian or Alaska Native", 2), "White", "Black or African American"),
    reported_ethnicity = c(rep("Not Hispanic or Latino", 3), NA),
    ancestry_detail = c("", "", "Polish", ""),
    age_at_last_observation = c(6.5, 35, 37, 28),
    affected_status = c("Affected", "Unknown", rep("Possibly affected", 2)),
    phenotype_description = c("Distal arthrogryposis with stellate teeth", "mother of participant_123", "father of participant_123", "Missing one variant in gene XXX"),
    age_at_enrollment = c(4, 33, 35, 28)
)

family <- tibble(
    family_id = paste0("UW_DCC_FAM", c("001", "002")),
    consanguinity = "None suspected"
)

phenotype <- tibble(
    participant_id = paste0("UW_DCC_participant_", c(123, 125, 125)),
    term_id	= c("HP:0001627", "HP:0001637", "HP:0001647"),
    presence = c("Present", "Absent", "Present"),
    ontology = "HPO",
    additional_details = c("", "cardiac abnormality differs from participant_123", ""),
    onset_age_range	= c("", "", "HP:0003577"),
    additional_modifiers = c("HP:0025226", "", "")
)

analyte <- tibble(
    analyte_id = c("UW_DCC_analyte_1", "UW_DCC_analyte_2"),
    participant_id = c("UW_DCC_participant_123", "UW_DCC_participant_125"),
    analyte_type = "DNA",
    primary_biosample = "UBERON:0000479"
)

experiment_dna_short_read <- tibble(
    experiment_dna_short_read_id = c("UW_DCC_experiment_1", "UW_DCC_experiment_2"),
    analyte_id = c("UW_DCC_analyte_1", "UW_DCC_analyte_2"),
    experiment_sample_id = c("H7YG5DSX2-3-IDUDI0014-1", "H7YG5DSX2-5-IDUDI0126-1"),
    seq_library_prep_kit_method = "Kappa Hyper PCR plus",
    read_length = 100,
    experiment_type = "exome",
    targeted_region_bed_file = "gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/regions_1.bed",
    date_data_generation = "2022-06-29",
    target_insert_size = 600,
    sequencing_platform = "Illumina NovaSeq6000"
)

aligned_dna_short_read = tibble(
    aligned_dna_short_read_id = c("UW_DCC_H7YG5DSX2-3-IDUDI0014-1", "UW_DCC_H7YG5DSX2-5-IDUDI0126-1"),
    experiment_dna_short_read_id = c("UW_DCC_experiment_1", "UW_DCC_experiment_2"),
    aligned_dna_short_read_file = paste0("gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/experiment_", 1:2, ".bam"),
    aligned_dna_short_read_index_file = paste0("gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/experiment_", 1:2, ".bai"),
    md5sum = c("d3b07384d113edec49eaa6238ad5ff00", "a7457a3403aa8e4616ce64bfae86655c"),
    reference_assembly = "GRCh38",
    alignment_software = "BWA-MEM-2.3",
    mean_coverage = 100,
    analysis_details = "10.5281/zenodo.4469317"
)

aligned_dna_short_read_set <- tibble(
    aligned_dna_short_read_set_id = "UW_DCC_H7YG5DSX2-3-IDUDI0014-1",
    aligned_dna_short_read_id = c("UW_DCC_H7YG5DSX2-3-IDUDI0014-1", "UW_DCC_H7YG5DSX2-5-IDUDI0126-1")
)

called_variants_dna_short_read <- tibble(
    aligned_dna_short_read_set_id = "UW_DCC_H7YG5DSX2-3-IDUDI0014-1",
    called_variants_dna_file = "gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/variants_file.vcf",
    md5sum = "efdf612a01049cc6e99470ad92b0326e",
    caller_software = "gatk4.1.2",
    variant_types = "SNV|INDEL",
    analysis_details = "10.5281/zenodo.4469317"
)

experiment_rna_short_read <- tibble(
    experiment_rna_short_read_id = c("UW_DCC_experiment_1", "UW_DCC_experiment_2"),
    analyte_id = c("UW_DCC_analyte_1", "UW_DCC_analyte_2"),
    experiment_sample_id = c("H7YG5DSX2-3-IDUDI0014-1", "H7YG5DSX2-5-IDUDI0126-1"),
    seq_library_prep_kit_method = "Kappa Hyper PCR plus",
    read_length = 100,
    experiment_type = "paired-end | targeted",
    single_or_paired_ends = "paired-end",
    date_data_generation = "2022-06-29",
    sequencing_platform = "Illumina NovaSeq6000",
    within_site_batch_name = "Batch 4",
    RIN = 9.8
)

aligned_rna_short_read = tibble(
    aligned_rna_short_read_id = c("UW_DCC_H7YG5DSX2-3-IDUDI0014-1", "UW_DCC_H7YG5DSX2-5-IDUDI0126-1"),
    experiment_rna_short_read_id = c("UW_DCC_experiment_1", "UW_DCC_experiment_2"),
    aligned_rna_short_read_file = paste0("gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/rna_experiment_", 1:2, ".bam"),
    aligned_rna_short_read_index_file = paste0("gs://fc-eb352699-d849-483f-aefe-9d35ce2b21ac/rna_experiment_", 1:2, ".bai"),
    md5sum = c("a3b07384d113edec49eaa6238ad5ff00", "b7457a3403aa8e4616ce64bfae86655c"),
    reference_assembly = "GRCh38",
    alignment_software = "BWA-MEM-2.3",
    mean_coverage = 100,
    gene_annotation = "GENCODEv35",
    gene_annotation_details = "gencode_comprehensive_chr"
)

table_names <- c("participant", "family", "phenotype", "analyte", "experiment_dna_short_read",
    "aligned_dna_short_read", "aligned_dna_short_read_set", "called_variants_dna_short_read",
    "experiment_rna_short_read", "aligned_rna_short_read")
for (t in table_names) {
    outfile <- paste0(t, ".tsv")
    readr::write_tsv(get(t), outfile)
}
