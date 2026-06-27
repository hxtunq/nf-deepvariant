#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Huong dan: ./run_pipeline.sh --input samplesheet.csv --fasta reference.fa [tuy_chon]

Bat buoc:
  --input FILE          Samplesheet CSV co cac cot: sample_id,fastq_1,fastq_2
  --fasta FILE          File FASTA he tham chieu

Tuy chon:
  --seq_type TYPE       wes hoac wgs (mac dinh: wes)
  --target_bed FILE     File BED vung bat giu, bat buoc khi --seq_type wes
  --outdir DIR          Thu muc ket qua (mac dinh: ./results)
  --profile PROFILE     Profile Nextflow: docker, singularity, apptainer, conda (mac dinh: docker)
  --dv_version VERSION  Phien ban container DeepVariant (mac dinh: 1.10.0)
  --dv_num_shards N     So shard cho DeepVariant
  --adapter_preset VAL  illumina hoac none (mac dinh: illumina)
  --skip_fastqc         Bo qua FastQC
  --skip_trim           Bo qua trim bang fastp
  --skip_deepvariant    Dung truoc buoc DeepVariant
  --skip_multiqc        Bo qua MultiQC
  -h, --help            Hien thi huong dan nay

Vi du:
  ./run_pipeline.sh --input samplesheet.csv --fasta /data/GRCh38.fa --seq_type wgs

  ./run_pipeline.sh \
    --input samplesheet.csv \
    --fasta /data/GRCh38.fa \
    --seq_type wes \
    --target_bed /data/exome_targets.bed \
    --profile docker
EOF
}

INPUT=""
FASTA=""
TARGET_BED=""
SEQ_TYPE="wes"
OUTDIR="./results"
PROFILE="docker"
DV_VERSION="1.10.0"
DV_NUM_SHARDS=""
ADAPTER_PRESET="illumina"
SKIP_FASTQC=false
SKIP_TRIM=false
SKIP_DEEPVARIANT=false
SKIP_MULTIQC=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input) INPUT="$2"; shift 2 ;;
        --fasta) FASTA="$2"; shift 2 ;;
        --target_bed) TARGET_BED="$2"; shift 2 ;;
        --seq_type) SEQ_TYPE="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --dv_version) DV_VERSION="$2"; shift 2 ;;
        --dv_num_shards) DV_NUM_SHARDS="$2"; shift 2 ;;
        --adapter_preset) ADAPTER_PRESET="$2"; shift 2 ;;
        --skip_fastqc) SKIP_FASTQC=true; shift ;;
        --skip_trim) SKIP_TRIM=true; shift ;;
        --skip_deepvariant) SKIP_DEEPVARIANT=true; shift ;;
        --skip_multiqc) SKIP_MULTIQC=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "LOI: tuy chon khong hop le: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo "LOI: can truyen --input" >&2
    usage
    exit 1
fi

if [[ -z "$FASTA" ]]; then
    echo "LOI: can truyen --fasta" >&2
    usage
    exit 1
fi

if [[ "$SEQ_TYPE" != "wes" && "$SEQ_TYPE" != "wgs" ]]; then
    echo "LOI: --seq_type phai la wes hoac wgs" >&2
    exit 1
fi

if [[ "$SEQ_TYPE" == "wes" && -z "$TARGET_BED" ]]; then
    echo "LOI: che do WES can --target_bed" >&2
    exit 1
fi

cmd=(
    nextflow run main.nf
    --input "$INPUT"
    --fasta "$FASTA"
    --seq_type "$SEQ_TYPE"
    --outdir "$OUTDIR"
    --dv_version "$DV_VERSION"
    --adapter_preset "$ADAPTER_PRESET"
    -profile "$PROFILE"
)

[[ -n "$TARGET_BED" ]] && cmd+=(--target_bed "$TARGET_BED")
[[ -n "$DV_NUM_SHARDS" ]] && cmd+=(--dv_num_shards "$DV_NUM_SHARDS")
[[ "$SKIP_FASTQC" == true ]] && cmd+=(--skip_fastqc)
[[ "$SKIP_TRIM" == true ]] && cmd+=(--skip_trim)
[[ "$SKIP_DEEPVARIANT" == true ]] && cmd+=(--skip_deepvariant)
[[ "$SKIP_MULTIQC" == true ]] && cmd+=(--skip_multiqc)

echo "========================================"
echo "  nf-deepvariant"
echo "========================================"
echo "  Kieu du lieu    : $SEQ_TYPE"
echo "  He tham chieu   : $FASTA"
echo "  Thu muc ket qua : $OUTDIR"
echo "  Profile         : $PROFILE"
echo "  DeepVariant     : $DV_VERSION"
echo "========================================"
printf 'Lenh chay:'
printf ' %q' "${cmd[@]}"
printf '\n\n'

exec "${cmd[@]}"
