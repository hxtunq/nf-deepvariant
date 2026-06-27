/*
 * ========================================
 *  BCFTOOLS - VCF/BCF processing utilities
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
    # Run bcftools stats
    bcftools stats \\
        $args \\
        $regions \\
        $vcf \\
        > ${prefix}.bcftools_stats.txt
    
    # Generate human-readable summary
    echo "========================================" > ${prefix}.summary.txt
    echo "  VCF QC Summary: ${meta.id}" >> ${prefix}.summary.txt
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
    
    # Extract key metrics
    SNPS=\$(grep "number of SNPs:" ${prefix}.bcftools_stats.txt | cut -f4 || true)
    INDELS=\$(grep "number of indels:" ${prefix}.bcftools_stats.txt | cut -f4 || true)
    TSTV=\$(grep "^TSTV" ${prefix}.bcftools_stats.txt | head -1 | cut -f5 || true)
    
    echo "" >> ${prefix}.summary.txt
    echo "--- QUICK CHECK ---" >> ${prefix}.summary.txt
    echo "SNPs:            \$SNPS" >> ${prefix}.summary.txt
    echo "Indels:          \$INDELS" >> ${prefix}.summary.txt
    echo "Ts/Tv ratio:     \$TSTV" >> ${prefix}.summary.txt
    
    # Sanity checks
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
    # Validate VCF file integrity
    echo "========================================" > ${prefix}.validation.txt
    echo "  VCF Validation: ${meta.id}" >> ${prefix}.validation.txt
    echo "========================================" >> ${prefix}.validation.txt
    echo "" >> ${prefix}.validation.txt
    
    PASS=true
    
    # 1. Check if file exists and is non-empty
    if [ ! -s "$vcf" ]; then
        echo "FAIL: VCF file is empty or missing" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: VCF file exists and is non-empty" >> ${prefix}.validation.txt
    fi
    
    # 2. Check if tabix index exists
    if [ ! -f "${vcf}.tbi" ] && [ ! -f "$tbi" ]; then
        echo "FAIL: Tabix index (.tbi) is missing" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: Tabix index exists" >> ${prefix}.validation.txt
    fi
    
    # 3. Check VCF header
    HEADER_LINES=\$(bcftools view -h $vcf 2>/dev/null | wc -l)
    if [ "\$HEADER_LINES" -eq 0 ]; then
        echo "FAIL: No VCF header found" >> ${prefix}.validation.txt
        PASS=false
    else
        echo "PASS: VCF header found (\$HEADER_LINES lines)" >> ${prefix}.validation.txt
    fi
    
    # 4. Check if VCF has data lines
    DATA_LINES=\$(bcftools view -H $vcf 2>/dev/null | wc -l)
    if [ "\$DATA_LINES" -eq 0 ]; then
        echo "WARNING: No variant records in VCF" >> ${prefix}.validation.txt
    else
        echo "PASS: VCF has \$DATA_LINES variant records" >> ${prefix}.validation.txt
    fi
    
    # 5. Check required VCF columns
    bcftools view -h $vcf 2>/dev/null | tail -1 | grep -q "^#CHROM" && \\
        echo "PASS: VCF has required #CHROM header" >> ${prefix}.validation.txt || \\
        echo "FAIL: Missing #CHROM header line" >> ${prefix}.validation.txt
    
    # 6. Try to query VCF (tests if it's well-formed)
    if bcftools view $vcf 2>/dev/null | head -1 | grep -q "^"; then
        echo "PASS: VCF is parseable by bcftools" >> ${prefix}.validation.txt
    else
        echo "WARNING: VCF may have formatting issues" >> ${prefix}.validation.txt
    fi
    
    echo "" >> ${prefix}.validation.txt
    if [ "\$PASS" = true ]; then
        echo "OVERALL: PASS" >> ${prefix}.validation.txt
    else
        echo "OVERALL: FAIL - check errors above" >> ${prefix}.validation.txt
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -1 | sed 's/bcftools //')
    END_VERSIONS
    """
}
