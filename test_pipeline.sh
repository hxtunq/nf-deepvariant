#!/bin/bash

# ========================================
#  Script test pipeline
#  Tao du lieu test toi thieu va chay pipeline
# ========================================

set -e

echo "========================================"
echo "  Chay test WES/WGS Pipeline"
echo "========================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Buoc 1: kiem tra dieu kien chay.
echo "[Buoc 1/6] Kiem tra dieu kien chay..."

check_cmd() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Tim thay $1"
        return 0
    else
        echo -e "  ${RED}✗${NC} Khong tim thay $1"
        return 1
    fi
}

ERRORS=0
check_cmd nextflow || ((ERRORS++))

# Kiem tra container engine.
HAS_CONTAINER=false
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker dang chay"
    CONTAINER_PROFILE="docker"
    HAS_CONTAINER=true
elif command -v singularity &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Tim thay Singularity"
    CONTAINER_PROFILE="singularity"
    HAS_CONTAINER=true
fi

if [ "$HAS_CONTAINER" = false ]; then
    echo -e "  ${RED}✗${NC} Khong co container engine kha dung"
    ((ERRORS++))
fi

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Thieu dieu kien chay. Chay ./setup.sh de xem huong dan.${NC}"
    exit 1
fi

# Buoc 2: tao thu muc du lieu test.
echo ""
echo "[Buoc 2/6] Tao du lieu test..."
TEST_DIR="./test_run"
mkdir -p $TEST_DIR/reads $TEST_DIR/reference

# Buoc 3: tao he tham chieu test toi thieu.
echo ""
echo "[Buoc 3/6] Tao he tham chieu test tong hop 10kb..."
python3 << 'PYTHON'
import random
random.seed(42)
bases = 'ACGT'
with open("./test_run/reference/test_ref.fa", "w") as f:
    f.write(">chr20\n")
    seq = ''.join(random.choice(bases) for _ in range(10000))
    for i in range(0, len(seq), 80):
        f.write(seq[i:i+80] + "\n")
print("  Da tao test_ref.fa (du lieu tong hop 10kb)")
PYTHON

# Tao index FAI.
python3 -c "
with open('./test_run/reference/test_ref.fa.fai', 'w') as f:
    f.write('chr20\t10000\t6\t80\t81\n')
"
echo "  Da tao test_ref.fa.fai"

# Buoc 4: tao read test toi thieu.
echo ""
echo "[Buoc 4/6] Tao read test (500 PE x 150bp)..."
python3 << 'PYTHON'
import gzip, random
random.seed(42)
bases = 'ACGT'
def rand_seq(n): return ''.join(random.choice(bases) for _ in range(n))
def rand_qual(n): return ''.join(chr(random.randint(35, 74)) for _ in range(n))

with gzip.open('./test_run/reads/sample1_R1.fastq.gz', 'wt') as r1, \
     gzip.open('./test_run/reads/sample1_R2.fastq.gz', 'wt') as r2:
    for i in range(500):
        seq = rand_seq(150)
        r1.write(f'@READ_{i}/1\n{seq}\n+\n{rand_qual(150)}\n')
        r2.write(f'@READ_{i}/2\n{seq}\n+\n{rand_qual(150)}\n')
print("  Da tao sample1_R1/R2.fastq.gz (500 reads)")
PYTHON

# Buoc 5: tao samplesheet.
echo ""
echo "[Buoc 5/6] Tao samplesheet..."
cat > $TEST_DIR/samplesheet.csv << EOF
sample_id,fastq_1,fastq_2
sample1,$(pwd)/$TEST_DIR/reads/sample1_R1.fastq.gz,$(pwd)/$TEST_DIR/reads/sample1_R2.fastq.gz
EOF
echo "  Da tao samplesheet.csv"

# Buoc 6: chay pipeline.
echo ""
echo "[Buoc 6/6] Chay test pipeline..."
echo "  Profile container: $CONTAINER_PROFILE"
echo "  He tham chieu: $TEST_DIR/reference/test_ref.fa"
echo "  Ket qua: $TEST_DIR/results"
echo ""

nextflow run main.nf \
    --input $TEST_DIR/samplesheet.csv \
    --fasta $TEST_DIR/reference/test_ref.fa \
    --seq_type wgs \
    --dv_extra_args=--call_variants_extra_args=allow_empty_examples=true \
    --outdir $TEST_DIR/results \
    -profile $CONTAINER_PROFILE

echo ""
echo "========================================"
echo -e "${GREEN}  Test hoan tat thanh cong!${NC}"
echo "========================================"
echo ""
echo "Ket qua: $TEST_DIR/results/"
echo ""
echo "Bao cao QC:"
echo "  cat $TEST_DIR/results/fastq_qc/*.summary.txt"
echo "  cat $TEST_DIR/results/samtools_qc/*.summary.txt"
echo "  cat $TEST_DIR/results/vcf_qc/*.validation.txt"
