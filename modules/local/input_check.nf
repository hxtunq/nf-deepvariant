/*
 * ========================================
 *  INPUT_CHECK - Đọc và kiểm tra samplesheet
 * ========================================
 */

process INPUT_CHECK {
    tag "$samplesheet"
    label 'process_single'
    
    conda "conda-forge::python=3.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"
    
    input:
    path samplesheet
    
    output:
    path "samplesheet_validated.csv", emit: samplesheet_validated
    path "versions.yml", emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    """
    # Kiểm tra định dạng samplesheet.
    python3 << 'EOF'
import csv
import sys

samplesheet = "${samplesheet}"

with open(samplesheet, 'r') as f:
    reader = csv.DictReader(f)
    headers = reader.fieldnames
    
    required_headers = ['sample_id', 'fastq_1']
    missing = [h for h in required_headers if h not in headers]
    
    if missing:
        print(f"ERROR: Missing required columns: {missing}")
        print(f"Found columns: {headers}")
        sys.exit(1)
    
    rows = list(reader)
    if not rows:
        print("ERROR: Samplesheet is empty")
        sys.exit(1)
    
    # Kiểm tra từng dòng.
    for i, row in enumerate(rows, 1):
        if not row.get('sample_id'):
            print(f"ERROR: Row {i}: missing sample_id")
            sys.exit(1)
        
        if not row.get('fastq_1'):
            print(f"ERROR: Row {i}: missing fastq_1")
            sys.exit(1)
        
        # Kiểm tra có phải paired-end không.
        has_r2 = bool(row.get('fastq_2'))
        if not has_r2:
            print(f"WARNING: Row {i} ({row['sample_id']}): single-end mode")
    
    print(f"Validated {len(rows)} samples")
    
    # Ghi samplesheet đã kiểm tra.
    with open('samplesheet_validated.csv', 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)
    
    print("Validated samplesheet written to samplesheet_validated.csv")
EOF
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """
}
