#!/bin/bash

# ========================================
#  Pipeline Test Script
#  Creates minimal test data and runs pipeline
# ========================================

set -e

echo "========================================"
echo "  WES/WGS Pipeline Test Runner"
echo "========================================"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check prerequisites
echo "[Step 1/6] Checking prerequisites..."

check_cmd() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 NOT FOUND"
        return 1
    fi
}

ERRORS=0
check_cmd nextflow || ((ERRORS++))

# Check container engine
HAS_CONTAINER=false
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker is running"
    CONTAINER_PROFILE="docker"
    HAS_CONTAINER=true
elif command -v singularity &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Singularity found"
    CONTAINER_PROFILE="singularity"
    HAS_CONTAINER=true
fi

if [ "$HAS_CONTAINER" = false ]; then
    echo -e "  ${RED}✗${NC} No container engine available"
    ((ERRORS++))
fi

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Missing prerequisites. Run ./setup.sh for guide.${NC}"
    exit 1
fi

# Step 2: Create test data directory
echo ""
echo "[Step 2/6] Creating test data..."
TEST_DIR="./test_run"
mkdir -p $TEST_DIR/reads $TEST_DIR/reference

# Step 3: Generate minimal test reference
echo ""
echo "[Step 3/6] Generating test reference (10kb synthetic)..."
python3 << 'PYTHON'
import random
random.seed(42)
bases = 'ACGT'
with open("./test_run/reference/test_ref.fa", "w") as f:
    f.write(">chr20\n")
    seq = ''.join(random.choice(bases) for _ in range(10000))
    for i in range(0, len(seq), 80):
        f.write(seq[i:i+80] + "\n")
print("  Created test_ref.fa (10kb synthetic)")
PYTHON

# Create fai index
python3 -c "
with open('./test_run/reference/test_ref.fa.fai', 'w') as f:
    f.write('chr20\t10000\t6\t80\t81\n')
"
echo "  Created test_ref.fa.fai"

# Step 4: Generate minimal test reads
echo ""
echo "[Step 4/6] Generating test reads (500 PE x 150bp)..."
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
print("  Created sample1_R1/R2.fastq.gz (500 reads)")
PYTHON

# Step 5: Create samplesheet
echo ""
echo "[Step 5/6] Creating samplesheet..."
cat > $TEST_DIR/samplesheet.csv << EOF
sample_id,fastq_1,fastq_2
sample1,$(pwd)/$TEST_DIR/reads/sample1_R1.fastq.gz,$(pwd)/$TEST_DIR/reads/sample1_R2.fastq.gz
EOF
echo "  Created samplesheet.csv"

# Step 6: Run pipeline
echo ""
echo "[Step 6/6] Running pipeline test..."
echo "  Container profile: $CONTAINER_PROFILE"
echo "  Reference: $TEST_DIR/reference/test_ref.fa"
echo "  Output: $TEST_DIR/results"
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
echo -e "${GREEN}  Test completed successfully!${NC}"
echo "========================================"
echo ""
echo "Results: $TEST_DIR/results/"
echo ""
echo "QC Reports:"
echo "  cat $TEST_DIR/results/fastq_qc/*.summary.txt"
echo "  cat $TEST_DIR/results/samtools_qc/*.summary.txt"
echo "  cat $TEST_DIR/results/vcf_qc/*.validation.txt"
