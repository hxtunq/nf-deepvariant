/*
 * ========================================
 *  FASTP - Trim adapter và lọc chất lượng
 * ========================================
 */

process FASTP {
    tag "$meta.id"
    label 'process_medium'
    
    conda "bioconda::fastp=0.23.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--h5f740d0_0' :
        'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0' }"
    
    input:
    tuple val(meta), path(reads)
    
    output:
    tuple val(meta), path("*.trimmed.fastq.gz"), emit: reads
    tuple val(meta), path("*.json")           , emit: json
    tuple val(meta), path("*.html")           , emit: html
    tuple val(meta), path("*.log")            , emit: log
    path "versions.yml"                       , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def single_end = reads instanceof Path || reads.size() == 1
    
    if (single_end) {
        """
        # Chạy fastp cho read single-end.
        fastp \\
            $args \\
            --in1 ${reads} \\
            --out1 ${prefix}.trimmed.fastq.gz \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            --thread $task.cpus \\
            2>&1 | tee ${prefix}.fastp.log
        
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/fastp //')
        END_VERSIONS
        """
    } else {
        """
        # Chạy fastp cho read paired-end.
        fastp \\
            $args \\
            --in1 ${reads[0]} \\
            --in2 ${reads[1]} \\
            --out1 ${prefix}_R1.trimmed.fastq.gz \\
            --out2 ${prefix}_R2.trimmed.fastq.gz \\
            --json ${prefix}.fastp.json \\
            --html ${prefix}.fastp.html \\
            --thread $task.cpus \\
            2>&1 | tee ${prefix}.fastp.log
        
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/fastp //')
        END_VERSIONS
        """
    }
}
