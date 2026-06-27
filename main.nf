#!/usr/bin/env nextflow

/*
 * ========================================
 *  WES/WGS Variant Calling Pipeline with DeepVariant
 * ========================================
 *
 *  Author: hxtunq
 *  Version: 1.0.0
 *  
 *  Description:
 *    Complete whole-exome/whole-genome sequencing pipeline from FASTQ to VCF.
 *    Uses DeepVariant for variant calling with support for:
 *      - WES (Whole Exome Sequencing) and WGS (Whole Genome Sequencing) modes
 *      - Optional QC, trimming, and alignment steps
 *      - Configurable DeepVariant model version
 *  
 *  Pipeline Steps:
 *    1. QC (FastQC) - Quality control of raw reads [optional]
 *    2. Trimming (fastp) - Adapter and quality trimming [optional]
 *    3. Alignment (BWA-MEM2) - Read alignment to reference [optional]
 *    4. Post-alignment processing (Samtools sort/index and BAM QC)
 *    5. Variant Calling (DeepVariant) - Deep learning variant detection
 *    6. Reporting (MultiQC) - Aggregated QC report
 */


/*
 * ========================================
 *  Import modules/subworkflows
 * ========================================
 */


include { INPUT_CHECK                       } from './modules/local/input_check'
include { SAMTOOLS_FAIDX                    } from './modules/local/samtools'
include { FASTQC as FASTQC_RAW             } from './modules/local/fastqc'
include { FASTQC as FASTQC_TRIMMED         } from './modules/local/fastqc'
include { FASTQ_VALIDATION                  } from './modules/local/fastq_qc'
include { FASTP                             } from './modules/local/fastp'
include { BWA_MEM2_INDEX                    } from './modules/local/bwa_mem2'
include { BWA_MEM2                          } from './modules/local/bwa_mem2'
include { SAMTOOLS_SORT                     } from './modules/local/samtools'
include { SAMTOOLS_INDEX                    } from './modules/local/samtools'
include { SAMTOOLS_FLAGSTAT                 } from './modules/local/samtools'
include { SAMTOOLS_STATS                    } from './modules/local/samtools'
include { SAMTOOLS_IDXSTATS                 } from './modules/local/samtools'
include { BAM_QC                            } from './modules/local/samtools'
include { DEEPVARIANT                       } from './modules/local/deepvariant'
include { BCFTOOLS_STATS                    } from './modules/local/bcftools'
include { VCF_VALIDATION                    } from './modules/local/bcftools'
include { MULTIQC                           } from './modules/local/multiqc'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from './modules/local/utils'

/*
 * ========================================
 *  Subworkflows
 * ========================================
 */

// Subworkflow: Prepare reference indexes if not provided
workflow PREPARE_REFERENCE {
    take:
    fasta
    fasta_fai
    
    main:
    ch_fasta_indexed = fasta
    ch_fai = fasta_fai
    
    // Generate FASTA index if not provided
    if (!fasta_fai) {
        SAMTOOLS_FAIDX(fasta)
        ch_fai = SAMTOOLS_FAIDX.out.fai
    }
    
    // Generate BWA-MEM2 index if not provided
    BWA_MEM2_INDEX(fasta)
    ch_bwa_index = BWA_MEM2_INDEX.out.index
    
    emit:
    fasta       = ch_fasta_indexed
    fai         = ch_fai
    bwa_index   = ch_bwa_index
}

// Subworkflow: QC and Trimming
workflow QC_AND_TRIM {
    take:
    reads       // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    
    main:
    ch_versions = Channel.empty()
    ch_fastqc_results = Channel.empty()
    ch_fastq_validation = Channel.empty()
    
    // FASTQ validation (always runs - lightweight check)
    FASTQ_VALIDATION(reads)
    ch_fastq_validation = FASTQ_VALIDATION.out.summary
    ch_versions = ch_versions.mix(FASTQ_VALIDATION.out.versions)
    
    // Raw read QC
    if (!params.skip_fastqc) {
        FASTQC_RAW(reads)
        ch_fastqc_results = FASTQC_RAW.out.results
        ch_versions = ch_versions.mix(FASTQC_RAW.out.versions)
    }
    
    // Trimming
    ch_trimmed_reads = reads
    ch_trim_json = Channel.empty()
    
    if (!params.skip_trim) {
        FASTP(reads)
        ch_trimmed_reads = FASTP.out.reads
        ch_trim_json = FASTP.out.json
        ch_versions = ch_versions.mix(FASTP.out.versions)
        
        // Post-trim QC
        if (!params.skip_fastqc) {
            FASTQC_TRIMMED(ch_trimmed_reads)
            ch_fastqc_results = ch_fastqc_results.mix(FASTQC_TRIMMED.out.results)
            ch_versions = ch_versions.mix(FASTQC_TRIMMED.out.versions)
        }
    }
    
    emit:
    reads          = ch_trimmed_reads    // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    fastqc_results = ch_fastqc_results
    fastq_validation = ch_fastq_validation
    trim_json      = ch_trim_json
    versions       = ch_versions
}

// Subworkflow: Alignment
workflow ALIGN {
    take:
    reads       // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    index       // channel: BWA_MEM2 index files
    fasta       // channel: reference FASTA
    fai         // channel: reference FASTA index
    
    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_bam_qc = Channel.empty()
    
    BWA_MEM2(reads, index, fasta, fai)
    ch_versions = ch_versions.mix(BWA_MEM2.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(BWA_MEM2.out.log)
    
    SAMTOOLS_SORT(BWA_MEM2.out.bam)
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)
    
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.bam)
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
    
    ch_bam_with_bai = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
    BAM_QC(ch_bam_with_bai, fasta)
    ch_bam_qc = BAM_QC.out.summary
    ch_versions = ch_versions.mix(BAM_QC.out.versions)
    
    emit:
    bam            = SAMTOOLS_SORT.out.bam   // channel: [ val(meta), bam ]
    bai            = SAMTOOLS_INDEX.out.bai   // channel: [ val(meta), bai ]
    bam_qc         = ch_bam_qc               // channel: [ val(meta), summary ]
    multiqc_files  = ch_multiqc_files
    versions       = ch_versions
}


// Subworkflow: DeepVariant calling
workflow CALL_VARIANTS {
    take:
    bam         // channel: [ val(meta), bam ]
    bai         // channel: [ val(meta), bai ]
    fasta       // channel: reference fasta
    fai         // channel: fasta index
    target_bed  // channel: target regions BED (optional for WES)
    
    main:
    ch_versions = Channel.empty()
    ch_vcf_validation = Channel.empty()
    
    // DeepVariant
    ch_bam_with_bai = bam.join(bai)
    DEEPVARIANT(ch_bam_with_bai, fasta, fai, target_bed)
    ch_vcf = DEEPVARIANT.out.vcf.join(DEEPVARIANT.out.vcf_tbi)
    ch_gvcf = DEEPVARIANT.out.gvcf
    ch_versions = ch_versions.mix(DEEPVARIANT.out.versions)
    
    // VCF QC Checkpoint - bcftools stats
    BCFTOOLS_STATS(
        ch_vcf,
        target_bed
    )
    ch_versions = ch_versions.mix(BCFTOOLS_STATS.out.versions)
    
    // VCF Validation Check
    VCF_VALIDATION(ch_vcf)
    ch_vcf_validation = VCF_VALIDATION.out.validation
    ch_versions = ch_versions.mix(VCF_VALIDATION.out.versions)
    
    emit:
    vcf            = ch_vcf               // channel: [ val(meta), vcf, tbi ]
    gvcf           = ch_gvcf              // channel: [ val(meta), gvcf, tbi ]
    vcf_stats      = BCFTOOLS_STATS.out.stats     // channel: [ val(meta), stats ]
    vcf_validation = ch_vcf_validation    // channel: [ val(meta), validation ]
    versions       = ch_versions
}

/*
 * ========================================
 *  Main workflow
 * ========================================
 */

workflow {

    // Validate parameters
    if (!params.input) {
        error "Input samplesheet not specified! Use --input <samplesheet.csv>"
    }
    if (!params.fasta) {
        error "Reference FASTA not specified! Use --fasta <reference.fa>"
    }
    if (!['wes', 'wgs'].contains(params.seq_type)) {
        error "Invalid sequencing type: ${params.seq_type}. Must be 'wes' or 'wgs'."
    }
    if (!['illumina', 'none'].contains(params.adapter_preset)) {
        error "Invalid adapter preset: ${params.adapter_preset}. Must be 'illumina' or 'none'."
    }
    if (params.seq_type == 'wes' && !params.target_bed) {
        error "WES mode requires --target_bed for exome capture regions."
    }
    
    // Resolve inputs
    ch_input = Channel.value(file(params.input, checkIfExists: true))
    ch_fasta = Channel.value(file(params.fasta, checkIfExists: true))
    
    // Resolve DeepVariant model type
    def dv_model = params.dv_model_type ?: (params.seq_type == 'wes' ? 'WES' : 'WGS')
    log.info """
    ============================================================
      WES/WGS DeepVariant Pipeline v${params.version}
    ============================================================
      Sequencing type  : ${params.seq_type.toUpperCase()}
      DeepVariant model: ${dv_model}
      DeepVariant ver  : ${params.dv_version}
      Skip QC          : ${params.skip_fastqc}
      Skip trimming    : ${params.skip_trim}
      Adapter preset   : ${params.adapter_preset}
      Skip DeepVariant : ${params.skip_deepvariant}
    ============================================================
    """

    
    // Initialize version channel
    ch_versions = Channel.empty()
    
    // Collect FastQC results for MultiQC
    ch_fastqc_for_multiqc = Channel.empty()
    ch_trim_json_for_multiqc = Channel.empty()
    ch_alignment_logs_for_multiqc = Channel.empty()
    
    /*
     * ========================================
     *  STEP 0: Parse input samplesheet
     * ========================================
     */
    INPUT_CHECK(ch_input)
    ch_reads = Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def meta = [ id: row.sample_id ]
            def reads = row.fastq_2 ?
                [ file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true) ] :
                [ file(row.fastq_1, checkIfExists: true) ]
            [ meta, reads ]
        }
    
    /*
     * ========================================
     *  STEP 1: Prepare reference indexes
     * ========================================
     */
    PREPARE_REFERENCE(
        ch_fasta,
        params.fasta_fai ? file(params.fasta_fai, checkIfExists: true) : []
    )
    
    ch_fasta_with_fai = PREPARE_REFERENCE.out.fasta
    ch_fai = PREPARE_REFERENCE.out.fai
    ch_bwa_index = PREPARE_REFERENCE.out.bwa_index
    
    /*
     * ========================================
     *  STEP 2: QC and Trimming
     * ========================================
     */
    QC_AND_TRIM(ch_reads)
    ch_trimmed_reads = QC_AND_TRIM.out.reads
    ch_fastqc_for_multiqc = QC_AND_TRIM.out.fastqc_results
    ch_trim_json_for_multiqc = QC_AND_TRIM.out.trim_json
    ch_versions = ch_versions.mix(QC_AND_TRIM.out.versions)
    
    /*
     * ========================================
     *  STEP 3: Alignment
     * ========================================
     */
    ALIGN(
        ch_trimmed_reads,
        ch_bwa_index.collect(),
        ch_fasta_with_fai.collect(),
        ch_fai.collect()
    )
    ch_aligned_bam = ALIGN.out.bam
    ch_aligned_bai = ALIGN.out.bai
    ch_alignment_logs_for_multiqc = ALIGN.out.multiqc_files
    ch_versions = ch_versions.mix(ALIGN.out.versions)
    
    /*
     * ========================================
     *  STEP 5: DeepVariant variant calling
     * ========================================
     */
    if (!params.skip_deepvariant) {
        ch_target_bed = Channel.value(params.target_bed ? 
            file(params.target_bed, checkIfExists: true) : 
            [])
        
        CALL_VARIANTS(
            ch_aligned_bam,
            ch_aligned_bai,
            ch_fasta_with_fai.collect(),
            ch_fai.collect(),
            ch_target_bed
        )
        ch_versions = ch_versions.mix(CALL_VARIANTS.out.versions)
    }
    
    /*
     * ========================================
     *  STEP 6: MultiQC reporting
     * ========================================
     */
    if (!params.skip_multiqc) {
        ch_multiqc_files = ch_fastqc_for_multiqc.map { x -> x[1] }
            .mix(ch_trim_json_for_multiqc.map { x -> x[1] })
            .mix(ch_alignment_logs_for_multiqc.map { x -> x[1] })
        
        MULTIQC(ch_multiqc_files.collect())
    }
    
    /*
     * ========================================
     *  STEP 7: Collect software versions
     * ========================================
     */
    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}
