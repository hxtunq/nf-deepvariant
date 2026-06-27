#!/bin/bash

# ========================================
#  Pipeline Validation Script
# ========================================

set -e

echo "========================================"
echo "  Validating WES/WGS DeepVariant Pipeline"
echo "========================================"

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PIPELINE_DIR"

ERRORS=0

# Check required files
echo ""
echo "Checking required files..."
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
        echo "  ✗ MISSING: $file"
        ((ERRORS++))
    fi
done

# Check if launcher is executable
echo ""
echo "Checking launcher permissions..."
if [[ -x "run_pipeline.sh" ]]; then
    echo "  ✓ run_pipeline.sh is executable"
else
    echo "  ✗ run_pipeline.sh is not executable"
    ((ERRORS++))
fi

# Validate Nextflow syntax (if Nextflow is available)
echo ""
if command -v nextflow &> /dev/null; then
    echo "Validating Nextflow syntax..."
    # Run with --help flag - if it shows "Input samplesheet not specified", syntax is valid
    # (the error is about missing parameters, not syntax)
    NEXTFLOW_OUTPUT=$(nextflow run main.nf --help 2>&1 || true)
    if echo "$NEXTFLOW_OUTPUT" | grep -q "Input samplesheet not specified"; then
        echo "  ✓ Nextflow syntax valid (parameter validation working)"
    elif echo "$NEXTFLOW_OUTPUT" | grep -q "Launching\|N E X T F L O W"; then
        echo "  ✓ Nextflow syntax valid"
    else
        echo "  ✗ Nextflow syntax errors detected"
        echo "$NEXTFLOW_OUTPUT" | grep -i "error" | head -3
        ((ERRORS++))
    fi
else
    echo "Nextflow not found - skipping syntax validation"
fi

# Check for common issues
echo ""
echo "Checking for common issues..."

# Check for hardcoded paths
if grep -q "/absolute/path" README.md 2>/dev/null; then
    echo "  ⚠ Warning: README contains placeholder paths - update before distribution"
fi

# Check for missing imports in main.nf
if grep -q "include {" main.nf; then
    echo "  ✓ Module imports present in main.nf"
else
    echo "  ✗ No module imports found in main.nf"
    ((ERRORS++))
fi

# Summary
echo ""
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
    echo "  Validation PASSED"
    echo "  Pipeline is ready to use"
else
    echo "  Validation FAILED"
    echo "  $ERRORS error(s) found"
fi
echo "========================================"

exit $ERRORS
