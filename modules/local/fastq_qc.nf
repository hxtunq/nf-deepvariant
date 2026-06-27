/*
 * ========================================
 *  FASTQ_QC - Kiểm tra FASTQ nhẹ
 *  Dùng seqkit hoặc awk cho các kiểm tra cơ bản
 * ========================================
 */

process FASTQ_VALIDATION {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::seqkit=2.8.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/seqkit:2.8.0--h9ee0642_0' }"
    
    input:
    tuple val(meta), path(reads)
    
    output:
    tuple val(meta), path("*.fqchk.txt"), emit: report
    tuple val(meta), path("*.summary.txt"), emit: summary
    path "versions.yml"                 , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Kiểm tra FASTQ và tạo file tóm tắt.
    echo "========================================" > ${prefix}.summary.txt
    echo "  FASTQ Validation: ${meta.id}" >> ${prefix}.summary.txt
    echo "========================================" >> ${prefix}.summary.txt
    echo "" >> ${prefix}.summary.txt
    
    PASS=true
    
    for fq in ${reads}; do
        echo "--- \$fq ---" >> ${prefix}.summary.txt
        
        # Thống kê cơ bản bằng seqkit.
        seqkit stats -a \$fq > ${prefix}.\$(basename \$fq .fastq.gz).fqchk.txt 2>/dev/null || true
        
        # Trích xuất thông tin chính.
        READS=\$(seqkit stats -T \$fq 2>/dev/null | tail -1 | cut -f4)
        AVG_LEN=\$(seqkit stats -T \$fq 2>/dev/null | tail -1 | cut -f7)
        GC=\$(seqkit stats -T \$fq 2>/dev/null | tail -1 | cut -f9)
        
        echo "  Reads:       \$READS" >> ${prefix}.summary.txt
        echo "  Avg length:  \$AVG_LEN" >> ${prefix}.summary.txt
        echo "  GC%:         \$GC" >> ${prefix}.summary.txt
        
        # Kiểm tra FASTQ gzip có đọc được không.
        if ! gzip -t \$fq 2>/dev/null; then
            echo "  STATUS: FAIL - corrupted gzip" >> ${prefix}.summary.txt
            PASS=false
        else
            echo "  STATUS: PASS - valid gzip" >> ${prefix}.summary.txt
        fi
        
        # Kiểm tra file rỗng.
        if [ ! -s "\$fq" ]; then
            echo "  STATUS: FAIL - empty file" >> ${prefix}.summary.txt
            PASS=false
        fi
        
        echo "" >> ${prefix}.summary.txt
    done
    
    # Kiểm tra tính nhất quán paired-end nếu có 2 file.
    NFILES=\$(echo ${reads} | wc -w)
    if [ "\$NFILES" -eq 2 ]; then
        R1_READS=\$(seqkit stats -T ${reads[0]} 2>/dev/null | tail -1 | cut -f4)
        R2_READS=\$(seqkit stats -T ${reads[1]} 2>/dev/null | tail -1 | cut -f4)
        
        if [ "\$R1_READS" != "\$R2_READS" ]; then
            echo "WARNING: R1 (\$R1_READS) and R2 (\$R2_READS) read counts differ!" >> ${prefix}.summary.txt
            PASS=false
        else
            echo "PASS: R1 and R2 read counts match (\$R1_READS)" >> ${prefix}.summary.txt
        fi
    fi
    
    echo "" >> ${prefix}.summary.txt
    if [ "\$PASS" = true ]; then
        echo "OVERALL: PASS" >> ${prefix}.summary.txt
    else
        echo "OVERALL: FAIL - check errors above" >> ${prefix}.summary.txt
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version 2>&1 | head -1 | sed 's/seqkit //')
    END_VERSIONS
    """
}
