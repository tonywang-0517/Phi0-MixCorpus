# InternData-N1 (VLN)

轨迹型视觉语言导航（VLN-CE + VLN-PE），**非离散指令 SFT**。

| 子集 | 路径 | 说明 |
|------|------|------|
| vln_ce (R2R+RxR) | `raw/vln_ce/` | Habitat VLN-CE 轨迹，~24GB |
| vln_pe | `raw/vln_pe/` | 人形室内导航，~95GB |

- **注册表**: `manifests/mix.yaml` → `r2r`, `rxr`, `vln_pe`
- **下载 vln_ce**: `bash datasets/interndata_n1/scripts/download_vln_ce.sh`
- **下载 vln_pe**: `bash datasets/interndata_n1/scripts/download_vln_pe.sh`
- **监控**: `bash datasets/interndata_n1/scripts/watch_download.sh`

HF: [InternRobotics/InternData-N1](https://huggingface.co/datasets/InternRobotics/InternData-N1)（gated，需 HF_TOKEN）
