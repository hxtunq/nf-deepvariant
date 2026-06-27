#!/bin/bash

# ========================================
#  Script kiểm tra môi trường cho pipeline WES/WGS DeepVariant
#  Không cần cài các công cụ tin sinh học cục bộ vì mọi thứ chạy trong container.
# ========================================

set -e

echo "========================================"
echo "  Kiem tra moi truong nf-deepvariant"
echo "========================================"
echo ""

# Ma mau terminal.
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Tim thay $1: $(command -v $1)"
        return 0
    else
        echo -e "${RED}✗${NC} Khong tim thay $1"
        return 1
    fi
}

check_version() {
    if command -v "$1" &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -1)
        echo "  Phien ban: $VERSION"
    fi
}

ERRORS=0

# ========================================
# 1. Kiem tra Nextflow
# ========================================
echo ""
echo "1. Kiem tra Nextflow..."
if check_command nextflow; then
    check_version nextflow
else
    echo -e "${YELLOW}→${NC} Cai Nextflow:"
    echo "  curl -s https://get.nextflow.io | bash"
    echo "  sudo mv nextflow /usr/local/bin/"
    ((ERRORS++))
fi

# ========================================
# 2. Kiem tra container engine (bat buoc co it nhat mot cai)
# ========================================
echo ""
echo "2. Kiem tra container engine..."
HAS_CONTAINER=false

if check_command docker; then
    check_version docker
    # Kiem tra Docker daemon co dang chay khong.
    if docker ps &> /dev/null; then
        echo -e "  ${GREEN}Docker daemon dang chay${NC}"
    else
        echo -e "  ${YELLOW}Docker da cai nhung daemon chua chay${NC}"
        echo "  Hay khoi dong Docker roi thu lai"
    fi
    HAS_CONTAINER=true
fi

if check_command singularity; then
    check_version singularity
    HAS_CONTAINER=true
fi

if check_command apptainer; then
    check_version apptainer
    HAS_CONTAINER=true
fi

if [ "$HAS_CONTAINER" = false ]; then
    echo -e "${RED}✗${NC} Khong tim thay container engine!"
    echo -e "${YELLOW}→${NC} Cai mot trong cac cong cu: Docker, Singularity, hoac Apptainer"
    echo "  Docker (recommended): https://docs.docker.com/get-docker/"
    echo "  Singularity: https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
    echo "  Apptainer: https://apptainer.org/docs/admin/latest/installation.html"
    ((ERRORS++))
fi

# ========================================
# 3. Kiem tra Java (bat buoc cho Nextflow)
# ========================================
echo ""
echo "3. Kiem tra Java..."
if check_command java; then
    check_version java
else
    echo -e "${YELLOW}→${NC} Nextflow can Java 11+"
    echo "  sudo apt-get install openjdk-11-jdk  # Ubuntu/Debian"
    echo "  brew install openjdk@11               # macOS"
    ((ERRORS++))
fi

# ========================================
# 4. Kiem tra dung luong dia
# ========================================
echo ""
echo "4. Kiem tra dung luong dia..."
AVAIL_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
echo "  Kha dung: ${AVAIL_GB}GB"
if [ "$AVAIL_GB" -lt 50 ]; then
    echo -e "${YELLOW} Canh bao: dung luong thap (<50GB). WGS co the can 100GB+${NC}"
fi

# ========================================
# 5. Kiem tra RAM
# ========================================
echo ""
echo "5. Kiem tra RAM..."
TOTAL_MEM=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")
echo "  Tong: ${TOTAL_MEM}GB"
if [ "$TOTAL_MEM" != "unknown" ] && [ "$TOTAL_MEM" -lt 16 ]; then
    echo -e "${YELLOW} Canh bao: <16GB RAM. DeepVariant khuyen nghi 32GB+${NC}"
fi

# ========================================
# Tong ket
# ========================================
echo ""
echo "========================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Kiem tra moi truong dat yeu cau!${NC}"
    echo ""
    echo "Co the chay pipeline:"
    echo ""
    echo "  nextflow run main.nf \\
    --input samplesheet.csv \\
    --fasta /path/to/reference.fa \\
    --seq_type wes \\
    --target_bed /path/to/targets.bed \\
    -profile docker"
    echo ""
    echo "Voi WGS khong can target BED:"
    echo ""
    echo "  nextflow run main.nf \\
    --input samplesheet.csv \\
    --fasta /path/to/reference.fa \\
    --seq_type wgs \\
    -profile docker"
else
    echo -e "${RED}✗ Kiem tra moi truong that bai voi $ERRORS loi${NC}"
    echo "Hay sua cac loi ben tren roi chay lai."
fi
echo "========================================"
