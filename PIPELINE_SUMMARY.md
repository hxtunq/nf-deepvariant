# Pipeline Summary

`nf-deepvariant` is a Nextflow DSL2 workflow for WES/WGS small-variant calling from paired FASTQ files.

## Main Steps

```text
FASTQ validation
Raw FastQC
fastp trimming
Trimmed FastQC
BWA-MEM2 alignment
samtools sort/index
BAM QC with samtools flagstat/stats/idxstats
DeepVariant variant calling
VCF QC with bcftools
MultiQC report
Software version collection
```

## Main Files

- `main.nf`: workflow orchestration
- `nextflow.config`: default parameters and profiles
- `conf/base.config`: resource defaults
- `conf/modules.config`: module output configuration
- `modules/local/*.nf`: process modules
- `run_pipeline.sh`: Bash launcher
- `setup.sh`: local prerequisite checker
- `validate_pipeline.sh`: repository sanity checks
- `test_data/`: tiny synthetic smoke-test dataset

## Public Use

Clone the repo, check the environment, prepare a samplesheet, then run:

```bash
./run_pipeline.sh --input samplesheet.csv --fasta reference.fa --seq_type wgs --profile docker
```

For WES, add:

```bash
--target_bed capture_targets.bed
```
