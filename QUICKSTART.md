# Quick Start

```bash
git clone https://github.com/hxtunq/nf-deepvariant.git
cd nf-deepvariant
chmod +x setup.sh run_pipeline.sh
./setup.sh
```

Prepare `samplesheet.csv`:

```csv
sample_id,fastq_1,fastq_2
sample1,/data/sample1_R1.fastq.gz,/data/sample1_R2.fastq.gz
```

Run WGS:

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/GRCh38.fa \
  --seq_type wgs \
  --profile docker
```

Run WES:

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/GRCh38.fa \
  --seq_type wes \
  --target_bed /data/exome_targets.bed \
  --profile docker
```

Smoke test with bundled synthetic data:

```bash
nextflow run main.nf -profile test,docker
```
