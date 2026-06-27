#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./run_pipeline.sh --input samplesheet.csv --fasta reference.fa [options]

Required:
  --input FILE          Samplesheet CSV with columns: sample_id,fastq_1,fastq_2
  --fasta FILE          Reference genome FASTA

Options:
  --seq_type TYPE       wes or wgs (default: wes)
  --target_bed FILE     Target BED file, required when --seq_type wes
  --outdir DIR          Output directory (default: ./results)
  --profile PROFILE     Nextflow profile: docker, singularity, apptainer, conda (default: docker)
  --dv_version VERSION  DeepVariant container version (default: 1.10.0)
  --dv_num_shards N     Number of DeepVariant shards
  --adapter_preset VAL  illumina or none (default: illumina)
  --skip_fastqc         Skip FastQC
  --skip_trim           Skip fastp trimming
  --skip_deepvariant    Stop before DeepVariant
  --skip_multiqc        Skip MultiQC
  -h, --help            Show this help

Examples:
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
        *) echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo "ERROR: --input is required" >&2
    usage
    exit 1
fi

if [[ -z "$FASTA" ]]; then
    echo "ERROR: --fasta is required" >&2
    usage
    exit 1
fi

if [[ "$SEQ_TYPE" != "wes" && "$SEQ_TYPE" != "wgs" ]]; then
    echo "ERROR: --seq_type must be wes or wgs" >&2
    exit 1
fi

if [[ "$SEQ_TYPE" == "wes" && -z "$TARGET_BED" ]]; then
    echo "ERROR: WES mode requires --target_bed" >&2
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
echo "  Sequencing type : $SEQ_TYPE"
echo "  Reference       : $FASTA"
echo "  Output          : $OUTDIR"
echo "  Profile         : $PROFILE"
echo "  DeepVariant     : $DV_VERSION"
echo "========================================"
printf 'Running:'
printf ' %q' "${cmd[@]}"
printf '\n\n'

exec "${cmd[@]}"
