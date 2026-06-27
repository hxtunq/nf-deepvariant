#!/usr/bin/env nextflow

/*
 * ========================================
 *  Pipeline gọi biến thể WES/WGS bằng DeepVariant
 * ========================================
 *
 *  Author: hxtunq
 *  Version: 1.0.0
 *  
 *  Mô tả:
 *    Pipeline từ FASTQ đến VCF cho dữ liệu WES/WGS.
 *    DeepVariant được dùng để gọi biến thể, hỗ trợ:
 *      - Chế độ WES và WGS
 *      - QC, trim và căn chỉnh ở mức pipeline
 *      - Cấu hình được phiên bản DeepVariant
 *  
 *  Các bước:
 *    1. QC đoạn đọc thô bằng FastQC
 *    2. Cắt adapter/chất lượng bằng fastp
 *    3. Căn chỉnh đoạn đọc vào hệ gen tham chiếu bằng BWA-MEM2
 *    4. Sắp xếp, tạo chỉ mục và QC BAM bằng samtools
 *    5. Gọi biến thể bằng DeepVariant
 *    6. Tổng hợp báo cáo bằng MultiQC
 */


/*
 * ========================================
 *  Nạp module/subworkflow
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
 *  Các subworkflow
 * ========================================
 */

// Chuẩn bị chỉ mục cho hệ gen tham chiếu nếu người dùng chưa cung cấp.
workflow PREPARE_REFERENCE {
    take:
    fasta
    fasta_fai
    
    main:
    ch_fasta_indexed = fasta
    ch_fai = fasta_fai
    
    // Tạo chỉ mục FASTA nếu chưa có.
    if (!fasta_fai) {
        SAMTOOLS_FAIDX(fasta)
        ch_fai = SAMTOOLS_FAIDX.out.fai
    }
    
    // Tạo chỉ mục BWA-MEM2 cho hệ tham chiếu.
    BWA_MEM2_INDEX(fasta)
    ch_bwa_index = BWA_MEM2_INDEX.out.index
    
    emit:
    fasta       = ch_fasta_indexed
    fai         = ch_fai
    bwa_index   = ch_bwa_index
}

// Subworkflow QC và trim read.
workflow QC_AND_TRIM {
    take:
    reads       // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    
    main:
    ch_versions = Channel.empty()
    ch_fastqc_results = Channel.empty()
    ch_fastq_validation = Channel.empty()
    
    // Kiểm tra FASTQ
    FASTQ_VALIDATION(reads)
    ch_fastq_validation = FASTQ_VALIDATION.out.summary
    ch_versions = ch_versions.mix(FASTQ_VALIDATION.out.versions)
    
    // QC đoạn đọc thô.
    if (!params.skip_fastqc) {
        FASTQC_RAW(reads)
        ch_fastqc_results = FASTQC_RAW.out.results
        ch_versions = ch_versions.mix(FASTQC_RAW.out.versions)
    }
    
    // Cắt adapter/đoạn đọc chất lượng thấp.
    ch_trimmed_reads = reads
    ch_trim_json = Channel.empty()
    
    if (!params.skip_trim) {
        FASTP(reads)
        ch_trimmed_reads = FASTP.out.reads
        ch_trim_json = FASTP.out.json
        ch_versions = ch_versions.mix(FASTP.out.versions)
        
        // QC sau cắt.
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

// Subworkflow căn chỉnh và QC BAM.
workflow ALIGN {
    take:
    reads       // channel: [ val(meta), [ fastq_1, fastq_2 ] ]
    index       // channel chứa file index BWA-MEM2
    fasta       // channel chứa FASTA tham chiếu
    fai         // channel chứa FASTA index
    
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
        ch_multiqc_files = ch_multiqc_files
            .mix(BAM_QC.out.flagstat)
            .mix(BAM_QC.out.stats)
            .mix(BAM_QC.out.idxstats)
    
    emit:
    bam            = SAMTOOLS_SORT.out.bam   // channel: [ val(meta), bam ]
    bai            = SAMTOOLS_INDEX.out.bai   // channel: [ val(meta), bai ]
    bam_qc         = ch_bam_qc               // channel: [ val(meta), summary ]
    multiqc_files  = ch_multiqc_files
    versions       = ch_versions
}


// Subworkflow gọi biến thể bằng DeepVariant.
workflow CALL_VARIANTS {
    take:
    bam         // channel: [ val(meta), bam ]
    bai         // channel: [ val(meta), bai ]
    fasta       // channel chứa FASTA tham chiếu
    fai         // channel chứa chỉ mục FASTA
    target_bed  // channel chứa BED vùng đích; dùng cho WES
    
    main:
    ch_versions = Channel.empty()
    ch_vcf_validation = Channel.empty()
    
    // Chạy DeepVariant.
    ch_bam_with_bai = bam.join(bai)
    DEEPVARIANT(ch_bam_with_bai, fasta, fai, target_bed)
    ch_vcf = DEEPVARIANT.out.vcf.join(DEEPVARIANT.out.vcf_tbi)
    ch_gvcf = DEEPVARIANT.out.gvcf
    ch_versions = ch_versions.mix(DEEPVARIANT.out.versions)
    
    // QC VCF bằng bcftools stats.
    BCFTOOLS_STATS(
        ch_vcf,
        target_bed
    )
    ch_versions = ch_versions.mix(BCFTOOLS_STATS.out.versions)
    
    // Kiểm tra tính hợp lệ của VCF.
    VCF_VALIDATION(ch_vcf)
    ch_vcf_validation = VCF_VALIDATION.out.validation
    ch_versions = ch_versions.mix(VCF_VALIDATION.out.versions)
    
    emit:
        vcf            = ch_vcf               // channel: [ val(meta), vcf, tbi ]
        gvcf           = ch_gvcf              // channel: [ val(meta), gvcf, tbi ]
        vcf_stats      = BCFTOOLS_STATS.out.stats     // channel: [ val(meta), stats ]
        vcf_validation = ch_vcf_validation    // channel: [ val(meta), validation ]
        multiqc_files  = BCFTOOLS_STATS.out.stats
        versions       = ch_versions
}

/*
 * ========================================
 *  Workflow chính
 * ========================================
 */

workflow {

    // Kiểm tra tham số đầu vào.
    if (!params.input) {
        error "Chưa truyền samplesheet. Dùng --input <samplesheet.csv>"
    }
    if (!params.fasta) {
        error "Chưa truyền FASTA tham chiếu. Dùng --fasta <reference.fa>"
    }
    if (!['wes', 'wgs'].contains(params.seq_type)) {
        error "Kiểu dữ liệu không hợp lệ: ${params.seq_type}. Chỉ nhận 'wes' hoặc 'wgs'."
    }
    if (!['illumina', 'none'].contains(params.adapter_preset)) {
        error "Adapter preset không hợp lệ: ${params.adapter_preset}. Chỉ nhận 'illumina' hoặc 'none'."
    }
    if (params.seq_type == 'wes' && !params.target_bed) {
        error "Chế độ WES cần --target_bed cho vùng bắt giữ exome."
    }
    
    // Chuẩn hóa input.
    def samplesheet_file = file(params.input, checkIfExists: true)
    def samplesheet_dir = samplesheet_file.parent
    def resolve_samplesheet_path = { value ->
        def raw_path = value as String
        def is_absolute = java.nio.file.Paths.get(raw_path).isAbsolute()
        file(is_absolute ? raw_path : "${samplesheet_dir}/${raw_path}", checkIfExists: true)
    }
    ch_input = Channel.value(samplesheet_file)
    ch_fasta = Channel.value(file(params.fasta, checkIfExists: true))
    
    // Xác định model DeepVariant theo kiểu dữ liệu.
    def dv_model = params.dv_model_type ?: (params.seq_type == 'wes' ? 'WES' : 'WGS')
    log.info """
    ============================================================
      Pipeline WES/WGS DeepVariant v${params.version}
    ============================================================
      Kiểu dữ liệu       : ${params.seq_type.toUpperCase()}
      Model DeepVariant  : ${dv_model}
      Phiên bản DV       : ${params.dv_version}
      Bỏ qua QC          : ${params.skip_fastqc}
      Bỏ qua trim        : ${params.skip_trim}
      Adapter preset     : ${params.adapter_preset}
      Bỏ qua DeepVariant : ${params.skip_deepvariant}
    ============================================================
    """

    
    // Khởi tạo channel gom phiên bản phần mềm.
    ch_versions = Channel.empty()
    
    // Gom output QC cho MultiQC.
    ch_fastqc_for_multiqc = Channel.empty()
    ch_trim_json_for_multiqc = Channel.empty()
    ch_alignment_logs_for_multiqc = Channel.empty()
    ch_variant_qc_for_multiqc = Channel.empty()
    
    /*
     * ========================================
     *  BƯỚC 0: Đọc samplesheet đầu vào
     * ========================================
     */
    INPUT_CHECK(ch_input)
    ch_reads = Channel
        .fromPath(samplesheet_file, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def meta = [ id: row.sample_id ]
            def reads = row.fastq_2 ?
                [ resolve_samplesheet_path(row.fastq_1), resolve_samplesheet_path(row.fastq_2) ] :
                [ resolve_samplesheet_path(row.fastq_1) ]
            [ meta, reads ]
        }
    
    /*
     * ========================================
     *  BƯỚC 1: Chuẩn bị chỉ mục cho hệ gen tham chiếu
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
     *  BƯỚC 2: QC và cắt tỉa đoạn đọc
     * ========================================
     */
    QC_AND_TRIM(ch_reads)
    ch_trimmed_reads = QC_AND_TRIM.out.reads
    ch_fastqc_for_multiqc = QC_AND_TRIM.out.fastqc_results
    ch_trim_json_for_multiqc = QC_AND_TRIM.out.trim_json
    ch_versions = ch_versions.mix(QC_AND_TRIM.out.versions)
    
    /*
     * ========================================
     *  BƯỚC 3: Căn chỉnh đoạn đọc
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
     *  BƯỚC 4: Gọi biến thể bằng DeepVariant
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
        ch_variant_qc_for_multiqc = CALL_VARIANTS.out.multiqc_files
    }
    
    /*
     * ========================================
     *  BƯỚC 5: Tổng hợp phiên bản phần mềm
     * ========================================
     */
    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
    
    /*
     * ========================================
     *  BƯỚC 6: Báo cáo MultiQC
     * ========================================
     */
    if (!params.skip_multiqc) {
        ch_multiqc_files = ch_fastqc_for_multiqc.map { x -> x[1] }
            .mix(ch_trim_json_for_multiqc.map { x -> x[1] })
            .mix(ch_alignment_logs_for_multiqc.map { x -> x[1] })
            .mix(ch_variant_qc_for_multiqc.map { x -> x[1] })
            .mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml)
        
        MULTIQC(ch_multiqc_files.collect())
    }
}
