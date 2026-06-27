/*
 * ========================================
 *  BWA - Căn chỉnh read
 * ========================================
 */

process BWA_MEM2_INDEX {
    tag "$fasta"
    label 'process_high'
    
    conda "bioconda::bwa=0.7.18 bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bwa_htslib_samtools:56c9f8d5201889a4' :
        'community.wave.seqera.io/library/bwa_htslib_samtools:56c9f8d5201889a4' }"
    
    input:
    path fasta
    
    output:
    path "bwa_mem2_index" , emit: index
    path "versions.yml"   , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    """
    # Tạo thư mục index.
    mkdir -p bwa_mem2_index
    
    # Sao chép FASTA đã stage vào thư mục index.
    cp ${fasta} bwa_mem2_index/genome.fa
    
    # Tạo BWA index.
    bwa index \\
        -p bwa_mem2_index/genome \\
        bwa_mem2_index/genome.fa
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(bwa 2>&1 | grep '^Version' | sed 's/Version: //')
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process BWA_MEM2 {
    tag "$meta.id"
    label 'process_high'
    
    conda "bioconda::bwa=0.7.18 bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bwa_htslib_samtools:56c9f8d5201889a4' :
        'community.wave.seqera.io/library/bwa_htslib_samtools:56c9f8d5201889a4' }"
    
    input:
    tuple val(meta), path(reads)
    path index
    path fasta
    path fai
    
    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.log"), emit: log
    path "versions.yml"           , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def single_end = reads instanceof Path || reads.size() == 1
    
    """
    # Tạo header read group.
    RG="@RG\\tID:${meta.id}\\tSM:${meta.id}\\tPL:ILLUMINA\\tLB:lib1\\tPU:unit1"
    
    # Căn chỉnh bằng BWA và sort BAM.
    bwa mem \\
        $args \\
        -R "\$RG" \\
        -t $task.cpus \\
        ${index}/genome \\
        $reads \\
        2> ${prefix}.bwa.log \\
        | samtools sort -@ ${task.cpus} -m 4G -o ${prefix}.bam -
    
    # Kiểm tra thống kê căn chỉnh.
    samtools flagstat ${prefix}.bam > ${prefix}.flagstat
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(bwa 2>&1 | grep '^Version' | sed 's/Version: //')
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}
