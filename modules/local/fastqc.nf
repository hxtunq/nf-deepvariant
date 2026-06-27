/*
 * ========================================
 *  FASTQC - Quality control of raw/trimmed reads
 * ========================================
 */

process FASTQC {
    tag "$meta.id"
    label 'process_medium'
    
    conda "bioconda::fastqc=0.12.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0' }"
    
    input:
    tuple val(meta), path(reads)
    
    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip") , emit: zip
    tuple val(meta), path("*.results"), emit: results
    path "versions.yml"            , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Run FastQC
    fastqc \\
        $args \\
        --threads $task.cpus \\
        --outdir . \\
        $reads
    
    # Rename output files for consistency
    for file in *.html *.zip; do
        if [[ -f "\$file" ]]; then
            mv "\$file" "${prefix}.\${file#*fastqc_}"
        fi
    done
    
    # Create results summary file
    echo "FastQC results for ${meta.id}" > ${prefix}.results
    echo "  Input: ${reads}" >> ${prefix}.results
    echo "  Status: Completed" >> ${prefix}.results
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$(fastqc --version | sed 's/FastQC v//')
    END_VERSIONS
    """
}
