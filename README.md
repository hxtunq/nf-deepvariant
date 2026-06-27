# nf-deepvariant

Nextflow DSL2 pipeline for WES/WGS small-variant calling from paired FASTQ files with DeepVariant.

## Workflow

```text
FASTQ -> FASTQ validation -> FastQC -> fastp -> BWA-MEM2 -> samtools sort/index/QC -> DeepVariant -> bcftools QC -> MultiQC
```

All bioinformatics tools run in containers. Users only need Nextflow plus a container engine such as Docker, Singularity, or Apptainer.

## Requirements

- Linux, WSL2, or HPC shell
- Java 11 or newer
- Nextflow 23.04.0 or newer
- Docker, Singularity, or Apptainer
- Reference FASTA
- Target BED file for WES mode

For WSL2, install Docker Desktop on Windows, enable WSL integration, then run this pipeline inside the WSL terminal.

## Install

```bash
git clone https://github.com/hxtunq/nf-deepvariant.git
cd nf-deepvariant
chmod +x setup.sh run_pipeline.sh validate_pipeline.sh test_pipeline.sh
./setup.sh
```

If Nextflow is not installed:

```bash
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
```

## Samplesheet

Create a CSV file with absolute or working-directory-relative paths:

```csv
sample_id,fastq_1,fastq_2
sample1,/data/sample1_R1.fastq.gz,/data/sample1_R2.fastq.gz
sample2,/data/sample2_R1.fastq.gz,/data/sample2_R2.fastq.gz
```

## Run WGS

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wgs \
  --outdir results_wgs \
  --profile docker
```

## Run WES

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wes \
  --target_bed /data/capture_targets.bed \
  --outdir results_wes \
  --profile docker
```

You can also run Nextflow directly:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wgs \
  --outdir results_wgs \
  -profile docker
```

## Common Options

| Option | Meaning | Default |
| --- | --- | --- |
| `--seq_type` | `wes` or `wgs` | `wes` |
| `--target_bed` | Capture target BED, required for WES | unset |
| `--dv_version` | DeepVariant Docker image version | `1.8.0` |
| `--dv_num_shards` | Number of DeepVariant shards | task CPU count |
| `--adapter_preset` | `illumina` or `none` | `illumina` |
| `--skip_fastqc` | Skip FastQC | false |
| `--skip_trim` | Skip fastp trimming | false |
| `--skip_deepvariant` | Run QC/alignment only | false |
| `--skip_multiqc` | Skip MultiQC | false |

By default, fastp uses common Illumina paired-end adapter sequences plus auto-detection. Use `--adapter_preset none` or pass custom adapter parameters through `--fastp_extra_args` when needed.

## Test Run

The repository includes a tiny synthetic dataset for checking that the workflow starts correctly:

```bash
nextflow run main.nf -profile test,docker
```

This test is only for pipeline smoke testing. It is not a biological benchmark.

## Outputs

```text
results/
├── fastq_qc/       FASTQ integrity summaries
├── fastqc/         Raw and trimmed read QC reports
├── fastp/          Trimming reports
├── bwa_mem2/       Alignment logs
├── samtools/       Sorted BAM and index files
├── samtools_qc/    flagstat, stats, idxstats, and summary files
├── deepvariant/    VCF/gVCF outputs and indexes
├── vcf_qc/         bcftools statistics and validation summaries
├── multiqc/        MultiQC report
└── pipeline_info/  Software versions and execution metadata
```

## Notes

- WES mode requires `--target_bed` so DeepVariant can restrict calling to capture regions.
- The current input mode starts from FASTQ. Pre-aligned BAM input is not implemented.
- DeepVariant can require substantial CPU, memory, and disk space on real WES/WGS data. Start with `--dv_num_shards` close to the CPU count available to Docker/WSL.
