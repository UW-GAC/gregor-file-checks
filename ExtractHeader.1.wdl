version 1.0

workflow ExtractHeader {
    input {
        File input_bam
        String sample_id
        String output_filename = sample_id + "_header"
        Float input_size = size(input_bam, "GiB")
        Int additional_disk = 20
    }

    call SamtoolsView{
        input: input_bam = input_bam, output_filename = output_filename, disk_size = ceil(input_size * 3) + additional_disk
    }
}

task SamtoolsView {
    input {
        File input_bam
        String output_filename
        Int disk_size
        Int memory_in_GiB = 20
    }

    command <<<
    samtools view -H -o ~{output_filename} ~{input_bam}
    >>>

    runtime {
        docker: "us.gcr.io/broad-gotc-prod/samtools:1.0.0-1.11-1624651616"
        disks: "local-disk " + disk_size + " HDD"
        memory: "~{memory_in_GiB} GiB"
        preemptible: 3
    }

    output {
        File output_file = output_filename
    }

}