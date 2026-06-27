/*
 * ========================================
 *  DEEPVARIANT - Deep learning variant calling
 * ========================================
 */

process DEEPVARIANT {
    tag "$meta.id"
    label 'process_high'
    
    container "google/deepvariant:${params.dv_version ?: '1.8.0'}"
    
    input:
    tuple val(meta), path(bam), path(bai)
    path fasta
    path fai
    path target_bed  // Optional: BED file for WES target regions
    
    output:
    tuple val(meta), path("*.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: vcf_tbi
    tuple val(meta), path("*.gvcf.gz")  , emit: gvcf, optional: true
    tuple val(meta), path("*.gvcf.gz.tbi"), emit: gvcf_tbi, optional: true
    tuple val(meta), path("*.visual_report.html"), emit: report, optional: true
    path "versions.yml"                  , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Determine model type
    def model_type = params.dv_model_type ?: (params.seq_type == 'wes' ? 'WES' : 'WGS')
    
    // Number of shards for parallelization
    def num_shards = params.dv_num_shards ?: task.cpus
    
    // Build regions argument for WES
    def regions_arg = ''
    if (params.seq_type == 'wes' && target_bed) {
        regions_arg = "--regions ${target_bed}"
    }
    
    // gVCF output
    def gvcf_arg = params.dv_gvcf ? "--output_gvcf ${prefix}.gvcf.gz" : ''
    
    // Extra arguments
    def extra_args = params.dv_extra_args ?: ''
    """
    # Run DeepVariant
    /opt/deepvariant/bin/run_deepvariant \\
        --model_type ${model_type} \\
        --ref $fasta \\
        --reads $bam \\
        --output_vcf ${prefix}.vcf.gz \\
        ${gvcf_arg} \\
        --num_shards ${num_shards} \\
        ${regions_arg} \\
        ${extra_args} \\
        ${args}
    
    # Generate visual report if available
    if [ -f ${prefix}.visual_report.html ]; then
        echo "Visual report generated: ${prefix}.visual_report.html"
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        deepvariant: ${params.dv_version ?: '1.8.0'}
    END_VERSIONS
    """
}
