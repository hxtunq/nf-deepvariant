#!/bin/bash

# ========================================
#  Script kiểm tra nhanh repo pipeline
# ========================================

set -e

echo "========================================"
echo "  Kiem tra repo WES/WGS DeepVariant Pipeline"
echo "========================================"

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PIPELINE_DIR"

ERRORS=0

# Kiem tra cac file bat buoc.
echo ""
echo "Kiem tra cac file bat buoc..."
REQUIRED_FILES=(

    "main.nf"

    "nextflow.config"

    "conf/base.config"

    "conf/modules.config"

    "conf/test.config"

    "modules/local/input_check.nf"

    "modules/local/fastqc.nf"

    "modules/local/fastq_qc.nf"

    "modules/local/fastp.nf"

    "modules/local/bwa_mem2.nf"

    "modules/local/samtools.nf"

    "modules/local/deepvariant.nf"

    "modules/local/bcftools.nf"

    "modules/local/multiqc.nf"

    "modules/local/utils.nf"

    "nextflow_schema.json"

    "README.md"

    "setup.sh"

    "run_pipeline.sh"

    "assets/example_samplesheet.csv"

)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $file"
    else
        echo "  ✗ THIEU: $file"
        ((ERRORS++))
    fi
done

# Kiem tra launcher co quyen thuc thi khong.
echo ""
echo "Kiem tra quyen thuc thi launcher..."
if [[ -x "run_pipeline.sh" ]]; then
    echo "  ✓ run_pipeline.sh co quyen thuc thi"
else
    echo "  ✗ run_pipeline.sh chua co quyen thuc thi"
    ((ERRORS++))
fi

# Kiem tra cu phap Nextflow neu may co Nextflow.
echo ""
if command -v nextflow &> /dev/null; then
    echo "Kiem tra cu phap Nextflow..."
    # Chay voi --help; neu bao thieu samplesheet thi cu phap da duoc doc toi buoc validate tham so.
    # Loi nay la loi thieu tham so, khong phai loi cu phap.
    NEXTFLOW_OUTPUT=$(nextflow run main.nf --help 2>&1 || true)
    if echo "$NEXTFLOW_OUTPUT" | grep -q "Chưa truyền samplesheet"; then
        echo "  ✓ Cu phap Nextflow hop le (validate tham so hoat dong)"
    elif echo "$NEXTFLOW_OUTPUT" | grep -q "Launching\|N E X T F L O W"; then
        echo "  ✓ Cu phap Nextflow hop le"
    else
        echo "  ✗ Phat hien loi cu phap Nextflow"
        echo "$NEXTFLOW_OUTPUT" | grep -i "error" | head -3
        ((ERRORS++))
    fi
else
    echo "Khong tim thay Nextflow - bo qua kiem tra cu phap"
fi

# Kiem tra mot so loi thuong gap.
echo ""
echo "Kiem tra loi thuong gap..."

# Kiem tra duong dan placeholder.
if grep -q "/absolute/path" README.md 2>/dev/null; then
    echo "  ⚠ Canh bao: README co duong dan placeholder - nen sua truoc khi phat hanh"
fi

# Kiem tra main.nf co import module khong.
if grep -q "include {" main.nf; then
    echo "  ✓ main.nf co import module"
else
    echo "  ✗ Khong thay import module trong main.nf"
    ((ERRORS++))
fi

# Tong ket
echo ""
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
    echo "  Kiem tra DAT"
    echo "  Pipeline san sang su dung"
else
    echo "  Kiem tra THAT BAI"
    echo "  Tim thay $ERRORS loi"
fi
echo "========================================"

exit $ERRORS
