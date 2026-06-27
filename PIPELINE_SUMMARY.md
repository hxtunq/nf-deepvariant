# Tóm Tắt Pipeline

`nf-deepvariant` là workflow Nextflow DSL2 để gọi biến thể nhỏ WES/WGS từ dữ liệu paired-end FASTQ.

## Các Bước Chính

```text
Kiểm tra FASTQ
FastQC cho read thô
Trim bằng fastp
FastQC cho read sau trim
Căn chỉnh bằng BWA-MEM2
Sort/index BAM bằng samtools
QC BAM bằng samtools flagstat/stats/idxstats
Gọi biến thể bằng DeepVariant
QC VCF bằng bcftools
Tổng hợp phiên bản phần mềm
Báo cáo MultiQC
```

## File Chính

- `main.nf`: điều phối workflow
- `nextflow.config`: tham số mặc định và profile chạy
- `conf/base.config`: cấu hình tài nguyên mặc định
- `conf/modules.config`: cấu hình output cho từng module
- `modules/local/*.nf`: các process module
- `run_pipeline.sh`: launcher Bash
- `setup.sh`: kiểm tra môi trường cục bộ
- `validate_pipeline.sh`: kiểm tra nhanh cấu trúc repo
- `test_data/`: dữ liệu tổng hợp nhỏ để smoke test

## Cách Dùng Public

Clone repo, kiểm tra môi trường, chuẩn bị samplesheet, rồi chạy:

```bash
./run_pipeline.sh --input samplesheet.csv --fasta reference.fa --seq_type wgs --profile docker
```

Với WES, thêm:

```bash
--target_bed capture_targets.bed
```
