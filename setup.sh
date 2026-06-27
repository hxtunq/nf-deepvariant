#!/bin/bash

# ========================================
#  WES/WGS DeepVariant Pipeline - Setup Script
# ========================================
#  This script verifies that your system is ready to run the pipeline.
#  NO local tool installation required - everything runs in containers!
# ========================================

set -e

echo "========================================"
echo "  WES/WGS DeepVariant Pipeline Setup"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found: $(command -v $1)"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

check_version() {
    if command -v "$1" &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -1)
        echo "  Version: $VERSION"
    fi
}

ERRORS=0

# ========================================
# 1. Check Nextflow (REQUIRED)
# ========================================
echo ""
echo "1. Checking Nextflow..."
if check_command nextflow; then
    check_version nextflow
else
    echo -e "${YELLOW}→${NC} Install Nextflow:"
    echo "  curl -s https://get.nextflow.io | bash"
    echo "  sudo mv nextflow /usr/local/bin/"
    ((ERRORS++))
fi

# ========================================
# 2. Check Container Engine (REQUIRED - at least one)
# ========================================
echo ""
echo "2. Checking container engine..."
HAS_CONTAINER=false

if check_command docker; then
    check_version docker
    # Test if docker daemon is running
    if docker ps &> /dev/null; then
        echo -e "  ${GREEN}Docker daemon is running${NC}"
    else
        echo -e "  ${YELLOW}Docker installed but daemon not running${NC}"
        echo "  Start Docker and try again"
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
    echo -e "${RED}✗${NC} No container engine found!"
    echo -e "${YELLOW}→${NC} Install one of: Docker, Singularity, or Apptainer"
    echo "  Docker (recommended): https://docs.docker.com/get-docker/"
    echo "  Singularity: https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
    echo "  Apptainer: https://apptainer.org/docs/admin/latest/installation.html"
    ((ERRORS++))
fi

# ========================================
# 3. Check Java (REQUIRED for Nextflow)
# ========================================
echo ""
echo "3. Checking Java..."
if check_command java; then
    check_version java
else
    echo -e "${YELLOW}→${NC} Java 11+ required for Nextflow"
    echo "  sudo apt-get install openjdk-11-jdk  # Ubuntu/Debian"
    echo "  brew install openjdk@11               # macOS"
    ((ERRORS++))
fi

# ========================================
# 4. Check disk space
# ========================================
echo ""
echo "4. Checking disk space..."
AVAIL_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
echo "  Available: ${AVAIL_GB}GB"
if [ "$AVAIL_GB" -lt 50 ]; then
    echo -e "${YELLOW}⚠ Warning: Low disk space (<50GB). WGS may need 100GB+${NC}"
fi

# ========================================
# 5. Check memory
# ========================================
echo ""
echo "5. Checking system memory..."
TOTAL_MEM=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")
echo "  Total: ${TOTAL_MEM}GB"
if [ "$TOTAL_MEM" != "unknown" ] && [ "$TOTAL_MEM" -lt 16 ]; then
    echo -e "${YELLOW}⚠ Warning: <16GB RAM. DeepVariant recommends 32GB+${NC}"
fi

# ========================================
# Summary
# ========================================
echo ""
echo "========================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Setup check passed!${NC}"
    echo ""
    echo "You're ready to run the pipeline:"
    echo ""
    echo "  nextflow run main.nf \\
    --input samplesheet.csv \\
    --fasta /path/to/reference.fa \\
    --seq_type wes \\
    --target_bed /path/to/targets.bed \\
    -profile docker"
    echo ""
    echo "For WGS (no target BED needed):"
    echo ""
    echo "  nextflow run main.nf \\
    --input samplesheet.csv \\
    --fasta /path/to/reference.fa \\
    --seq_type wgs \\
    -profile docker"
else
    echo -e "${RED}✗ Setup check failed with $ERRORS error(s)${NC}"
    echo "Fix the issues above and try again."
fi
echo "========================================"
