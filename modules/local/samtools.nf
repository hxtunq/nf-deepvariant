/*
 * ========================================
 *  SAMTOOLS - Các tiện ích xử lý BAM
 * ========================================
 */

process SAMTOOLS_SORT {
    tag "$meta.id"
    label 'process_medium'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam)
    
    output:
    tuple val(meta), path("*.sorted.bam"), emit: bam
    path "versions.yml"                  , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools sort \\
        $args \\
        -@ $task.cpus \\
        -o ${prefix}.sorted.bam \\
        $bam
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process SAMTOOLS_INDEX {
    tag "$meta.id"
    label 'process_low'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam)
    
    output:
    tuple val(meta), path("*.bai") , emit: bai
    path "versions.yml"            , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    """
    samtools index \\
        $args \\
        -@ $task.cpus \\
        $bam
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process SAMTOOLS_FAIDX {
    tag "$fasta"
    label 'process_single'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    path fasta
    
    output:
    path "*.fai"        , emit: fai
    path "versions.yml" , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    """
    samtools faidx \\
        $fasta
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

// ============================================================
//  QC CHECKPOINT PROCESSES
// ============================================================

process SAMTOOLS_FLAGSTAT {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam)
    
    output:
    tuple val(meta), path("*.flagstat"), emit: flagstat
    path "versions.yml"               , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools flagstat \\
        $args \\
        -@ $task.cpus \\
        $bam \\
        > ${prefix}.flagstat
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process SAMTOOLS_STATS {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam)
    path fasta  // optional, can be empty
    
    output:
    tuple val(meta), path("*.stats"), emit: stats
    path "versions.yml"             , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ref = fasta ? "--ref-sites ${fasta}" : ''
    """
    samtools stats \\
        $args \\
        -@ $task.cpus \\
        $ref \\
        $bam \\
        > ${prefix}.stats
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process SAMTOOLS_IDXSTATS {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam)
    path(bai)
    
    output:
    tuple val(meta), path("*.idxstats"), emit: idxstats
    path "versions.yml"               , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools idxstats \\
        $args \\
        $bam \\
        > ${prefix}.idxstats
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}

process BAM_QC {
    tag "$meta.id"
    label 'process_low'
    
    conda "bioconda::samtools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(bam), path(bai)
    path fasta
    
    output:
    tuple val(meta), path("*.flagstat")  , emit: flagstat
    tuple val(meta), path("*.stats")     , emit: stats
    tuple val(meta), path("*.idxstats")  , emit: idxstats
    tuple val(meta), path("*.summary.txt"), emit: summary
    path "versions.yml"                  , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ref = fasta ? "-r ${fasta}" : ''
    """
    # 1. flagstat - thống kê căn chỉnh cơ bản.
    samtools flagstat -@ $task.cpus $bam > ${prefix}.flagstat
    
    # 2. stats - thống kê chi tiết.
    samtools stats -@ $task.cpus $ref $bam > ${prefix}.stats
    
    # 3. idxstats - số read theo từng nhiễm sắc thể/contig.
    samtools idxstats $bam > ${prefix}.idxstats
    
    # 4. Tạo file tóm tắt dễ đọc.
    echo "========================================" > ${prefix}.summary.txt
    echo "  Tom tat QC BAM: ${meta.id}" >> ${prefix}.summary.txt
    echo "========================================" >> ${prefix}.summary.txt
    echo "" >> ${prefix}.summary.txt
    
    echo "--- FLAGSTAT ---" >> ${prefix}.summary.txt
    cat ${prefix}.flagstat >> ${prefix}.summary.txt
    echo "" >> ${prefix}.summary.txt
    
    echo "--- KEY METRICS (from samtools stats) ---" >> ${prefix}.summary.txt
    grep -E "^(SN|RL)" ${prefix}.stats | head -30 >> ${prefix}.summary.txt
    echo "" >> ${prefix}.summary.txt
    
    echo "--- PER-CHROMOSOME READS (idxstats) ---" >> ${prefix}.summary.txt
    head -25 ${prefix}.idxstats >> ${prefix}.summary.txt
    echo "..." >> ${prefix}.summary.txt
    
    # 5. Trích xuất chỉ số chính để kiểm tra nhanh.
    TOTAL=\$(grep "in total" ${prefix}.flagstat | cut -f1 -d' ')
    MAPPED=\$(grep "mapped (" ${prefix}.flagstat | head -1 | cut -f1 -d' ')
    DUPLICATE=\$(grep "duplicates" ${prefix}.flagstat | head -1 | cut -f1 -d' ')
    
    if [ "\$TOTAL" -gt 0 ] 2>/dev/null; then
        MAP_PCT=\$(awk -v mapped="\$MAPPED" -v total="\$TOTAL" 'BEGIN { printf "%.2f", mapped * 100 / total }')
        DUP_PCT=\$(awk -v duplicate="\$DUPLICATE" -v total="\$TOTAL" 'BEGIN { printf "%.2f", duplicate * 100 / total }')
        echo "" >> ${prefix}.summary.txt
        echo "--- QUICK CHECK ---" >> ${prefix}.summary.txt
        echo "Total reads:     \$TOTAL" >> ${prefix}.summary.txt
        echo "Mapped reads:    \$MAPPED (\${MAP_PCT}%)" >> ${prefix}.summary.txt
        echo "Duplicates:      \$DUPLICATE (\${DUP_PCT}%)" >> ${prefix}.summary.txt
        
        # Gắn cảnh báo nếu chỉ số vượt ngưỡng.
        if awk -v value="\$MAP_PCT" 'BEGIN { exit !(value < 80) }'; then
            echo "WARNING: Low mapping rate (<80%)" >> ${prefix}.summary.txt
        fi
        if awk -v value="\$DUP_PCT" 'BEGIN { exit !(value > 30) }'; then
            echo "WARNING: High duplication rate (>30%)" >> ${prefix}.summary.txt
        fi
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}
