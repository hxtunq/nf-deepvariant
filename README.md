# nf-deepvariant

Pipeline Nextflow DSL2 gọi biến thể dòng mầm nhỏ từ dữ liệu WES/WGS paired-end FASTQ bằng DeepVariant.

## Quy Trình

```text
FASTQ -> kiểm tra FASTQ -> FastQC -> fastp -> BWA-MEM2 -> samtools sort/index/QC -> DeepVariant -> bcftools QC -> MultiQC
```

Các công cụ tin sinh học chạy trong container. Người dùng chỉ cần cài Nextflow và một container engine như Docker/Singularity/Apptainer.

## Yêu Cầu

- Linux, WSL2 hoặc terminal trên hệ thống HPC
- Java phiên bản 11 trở lên
- Nextflow phiên bản 23.04.0 trở lên
- Docker, Singularity hoặc Apptainer
- File FASTA hệ tham chiếu
- File BED vùng bắt giữ cho chế độ WES

## Cài Đặt

```bash
git clone https://github.com/hxtunq/nf-deepvariant.git
cd nf-deepvariant
chmod +x setup.sh run_pipeline.sh validate_pipeline.sh test_pipeline.sh
./setup.sh
```

Nếu chưa cài đặt Nextflow cục bộ:

```bash
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
```

## Samplesheet

Tạo file CSV chứa đường dẫn tuyệt đối hoặc đường dẫn tương đối trỏ file fastq đầu vào từ thư mục chạy pipeline:

```csv
sample_id,fastq_1,fastq_2
sample1,/data/sample1_R1.fastq.gz,/data/sample1_R2.fastq.gz
sample2,/data/sample2_R1.fastq.gz,/data/sample2_R2.fastq.gz
```

## Chạy WGS

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wgs \
  --outdir results_wgs \
  --profile docker
```

## Chạy WES

```bash
./run_pipeline.sh \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wes \
  --target_bed /data/capture_targets.bed \
  --outdir results_wes \
  --profile docker
```

Có thể chạy trực tiếp bằng Nextflow nếu không dùng launcher:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --fasta /data/reference/GRCh38.fa \
  --seq_type wgs \
  --outdir results_wgs \
  -profile docker
```

## Tùy Chọn Thường Dùng

| Tùy chọn | Ý nghĩa | Mặc định |
| --- | --- | --- |
| `--seq_type` | Kiểu dữ liệu: `wes` hoặc `wgs` | `wes` |
| `--target_bed` | File BED vùng bắt giữ, bắt buộc với WES | chưa đặt |
| `--dv_version` | Phiên bản Docker image DeepVariant | `1.10.0` |
| `--dv_num_shards` | Số shard cho DeepVariant | bằng số CPU của task |
| `--adapter_preset` | `illumina` hoặc `none` | `illumina` |
| `--skip_fastqc` | Bỏ qua FastQC | false |
| `--skip_trim` | Bỏ qua bước trim bằng fastp | false |
| `--skip_deepvariant` | Chỉ chạy QC/căn chỉnh, không gọi biến thể | false |
| `--skip_multiqc` | Bỏ qua MultiQC | false |

Mặc định, fastp dùng cặp adapter Illumina phổ biến cùng cơ chế tự phát hiện adapter. Dùng `--adapter_preset none` hoặc truyền thêm tham số qua `--fastp_extra_args` nếu bộ kit của bạn cần cấu hình khác.

## Chạy Thử

Repo có sẵn bộ dữ liệu nhân tạo rất nhỏ để kiểm tra xem pipeline có hoạt động được hay không:

```bash
nextflow run main.nf -profile test,docker
```

Bộ test này chỉ dùng để kiểm tra kỹ thuật, không có ý nghĩa sinh học.

## Kết Quả

```text
results/
├── fastq_qc/       Kiểm tra chất lượng file dữ liệu NGS đầu vào định dạng FASTQ
├── fastqc/         Báo cáo QC đoạn đọc thô và đoạn đọc sau trim
├── fastp/          Báo cáo trim adapter/chất lượng
├── bwa_mem2/       Log căn chỉnh
├── samtools/       BAM đã sort và file index
├── samtools_qc/    flagstat, stats, idxstats và file tóm tắt
├── deepvariant/    VCF/gVCF và file index
├── vcf_qc/         Thống kê và kiểm tra VCF bằng bcftools
├── multiqc/        Báo cáo MultiQC
└── pipeline_info/  Phiên bản phần mềm và metadata lúc chạy
```

## Ghi Chú

- Chế độ WES cần `--target_bed` để DeepVariant giới hạn gọi biến thể trong vùng bắt giữ.
- Phiên bản hiện tại nhận đầu vào từ FASTQ. Không hỗ trợ chạy trực tiếp từ BAM đã căn chỉnh.
- Mặc định pipeline dùng image CPU của DeepVariant: `google/deepvariant:1.10.0`.
