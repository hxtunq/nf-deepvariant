/*
 * ========================================
 *  BCFTOOLS - Các tiện ích xử lý VCF/BCF
 * ========================================
 */

process BCFTOOLS_STATS {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::bcftools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bcftools:1.21--4335bec1d7b44d11' :
        'community.wave.seqera.io/library/bcftools:1.21--4335bec1d7b44d11' }"
    
    input:
    tuple val(meta), path(vcf), path(tbi)
    path target_bed  // optional: BED file for region restriction
    
    output:
    tuple val(meta), path("*.bcftools_stats.txt"), emit: stats
    tuple val(meta), path("*.summary.txt")       , emit: summary
    path "versions.yml"                          , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def regions = target_bed ? "--regions-file ${target_bed}" : ''
    """
    # Chạy bcftools stats.
    bcftools stats \\
        $args \\
        $regions \\
        $vcf \\
        > ${prefix}.bcftools_stats.txt
    
    # Tạo file tóm tắt dễ đọc.
    echo "========================================" > ${prefix}.summary.txt
    echo "  Tom tat QC VCF: ${meta.id}" >> ${prefix}.summary.txt
    echo "========================================" >> ${prefix}.summary.txt
    echo "" >> ${prefix}.summary.txt
    
    echo "--- VARIANT COUNTS ---" >> ${prefix}.summary.txt
    grep "^SN" ${prefix}.bcftools_stats.txt | cut -f3- >> ${prefix}.summary.txt || true
    echo "" >> ${prefix}.summary.txt
    
    echo "--- Ts/Tv RATIO ---" >> ${prefix}.summary.txt
    grep "^TSTV" ${prefix}.bcftools_stats.txt | head -1 >> ${prefix}.summary.txt || true
    echo "" >> ${prefix}.summary.txt
    
    echo "--- QUALITY DISTRIBUTION ---" >> ${prefix}.summary.txt
    grep "^QUAL" ${prefix}.bcftools_stats.txt | head -5 >> ${prefix}.summary.txt || true
    echo "" >> ${prefix}.summary.txt
    
    echo "--- SNP/INDEL TYPES ---" >> ${prefix}.summary.txt
    grep "^ST" ${prefix}.bcftools_stats.txt | head -5 >> ${prefix}.summary.txt || true
    
    # Trích xuất các chỉ số chính.
    SNPS=\$(grep "number of SNPs:" ${prefix}.bcftools_stats.txt | cut -f4 || true)
    INDELS=\$(grep "number of indels:" ${prefix}.bcftools_stats.txt | cut -f4 || true)
    TSTV=\$(grep "^TSTV" ${prefix}.bcftools_stats.txt | head -1 | cut -f5 || true)
    
    echo "" >> ${prefix}.summary.txt
    echo "--- QUICK CHECK ---" >> ${prefix}.summary.txt
    echo "SNPs:            \$SNPS" >> ${prefix}.summary.txt
    echo "Indels:          \$INDELS" >> ${prefix}.summary.txt
    echo "Ts/Tv ratio:     \$TSTV" >> ${prefix}.summary.txt
    
    # Kiểm tra nhanh tính hợp lý.
    if [ "\$SNPS" -gt 0 ] 2>/dev/null; then
        if awk -v value="\$TSTV" 'BEGIN { exit !(value != "" && value < 1.5) }'; then
            echo "WARNING: Low Ts/Tv ratio (<1.5) - possible quality issue" >> ${prefix}.summary.txt
        fi
        if awk -v value="\$TSTV" 'BEGIN { exit !(value != "" && value > 3.5) }'; then
            echo "WARNING: Very high Ts/Tv ratio (>3.5) - over-filtering?" >> ${prefix}.summary.txt
        fi
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -1 | sed 's/bcftools //')
    END_VERSIONS
    """
}

process VCF_VALIDATION {
    tag "$meta.id"
    label 'process_single'
    
    conda "bioconda::htslib=1.21 bioconda::bcftools=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bcftools:1.21--4335bec1d7b44d11' :
        'community.wave.seqera.io/library/bcftools:1.21--4335bec1d7b44d11' }"
    
    input:
    tuple val(meta), path(vcf), path(tbi)
    
    output:
    tuple val(meta), path("*.validation.txt"), emit: validation
    path "versions.yml"                     , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Kiểm tra tính toàn vẹn của file VCF.
    echo "========================================" > ${prefix}.validation.txt
    echo "  Kiem tra VCF: ${meta.id}" >> ${prefix}.validation.txt
    echo "========================================" >> ${prefix}.validation.txt
    echo "" >> ${prefix}.validation.txt
    
    PASS=true
    
    # 1. Kiểm tra file tồn tại và không rỗng.
    if [ ! -s "$vcf" ]; then
        echo "FAIL: File VCF rong hoac bi thieu" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: File VCF ton tai va khong rong" >> ${prefix}.validation.txt
    fi
    
    # 2. Kiểm tra tabix index có tồn tại không.
    if [ ! -f "${vcf}.tbi" ] && [ ! -f "$tbi" ]; then
        echo "FAIL: Thieu tabix index (.tbi)" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: Co tabix index" >> ${prefix}.validation.txt
    fi
    
    # 3. Kiểm tra header VCF.
    HEADER_LINES=\$(bcftools view -h $vcf 2>/dev/null | wc -l)
    if [ "\$HEADER_LINES" -eq 0 ]; then
        echo "FAIL: Khong tim thay header VCF" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: Tim thay header VCF (\$HEADER_LINES dong)" >> ${prefix}.validation.txt
    fi
    
    # 4. Kiểm tra VCF có dòng dữ liệu không.
    DATA_LINES=\$(bcftools view -H $vcf 2>/dev/null | wc -l)
    if [ "\$DATA_LINES" -eq 0 ]; then
        echo "WARNING: Khong co record bien the trong VCF" >> ${prefix}.validation.txt
    else
        echo "PASS: VCF co \$DATA_LINES record bien the" >> ${prefix}.validation.txt
    fi
    
    # 5. Kiểm tra các cột VCF bắt buộc.
    bcftools view -h $vcf 2>/dev/null | tail -1 | grep -q "^#CHROM" && \\
        echo "PASS: VCF co header #CHROM bat buoc" >> ${prefix}.validation.txt || \\
        echo "FAIL: Thieu dong header #CHROM" >> ${prefix}.validation.txt
    
    # 6. Thử query VCF để kiểm tra định dạng.
    if bcftools view $vcf 2>/dev/null | head -1 | grep -q "^"; then
        echo "PASS: bcftools doc duoc VCF" >> ${prefix}.validation.txt
    else
        echo "WARNING: VCF co the co loi dinh dang" >> ${prefix}.validation.txt
    fi
    
    echo "" >> ${prefix}.validation.txt
    if [ "\$PASS" = true ]; then
        echo "OVERALL: PASS" >> ${prefix}.validation.txt
    else
        echo "OVERALL: FAIL - xem loi ben tren" >> ${prefix}.validation.txt
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -1 | sed 's/bcftools //')
    END_VERSIONS
    """
}
