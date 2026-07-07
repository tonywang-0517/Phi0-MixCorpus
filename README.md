# Phi0-MixCorpus

Phi-0 混训语料构建。与 `Phi_0/` 训练代码解耦：本目录负责 **原始数据 → 中间格式 → 训练可读格式**，混训注册在 `manifests/mix.yaml`。

## 数据集

| ID | 名称 | action schema | embodiment | 状态 |
|----|------|---------------|------------|------|
| `xperience` | Xperience | unified_512 | human_egocentric | 待转换 |
| `egodex` | EgoDex | unified_512 | human_egocentric | 待转换 |
| `humanoid_everyday` | Humanoid Everyday | unified_512 | humanoid | 待转换 |
| `t_rex` | T-Rex | unified_512 | dexterous_hand | 待转换 |
| `bone_seed` | Bone-SEED | unified_512 | human_mocap | 待转换 |
| `phuma` | PHUMA | unified_512 | human_mocap | 待转换 |
| `sonic_g1` | Sonic 采集 | unified_512 | g1_humanoid | 待转换 |
| `r2r` / `rxr` / `vln_pe` | VLN (InternData-N1) | unified_512 | mobile / humanoid | 待转换 |

格式规范见 [`demo/PHI0_DATASET_SCHEMA.md`](demo/PHI0_DATASET_SCHEMA.md)；训练目录为 `datasets/<id>/train/*_phi0/`。

## 目录约定

```
Phi0-MixCorpus/
├── manifests/mix.yaml     # 混训注册表（权重、schema、tag）
├── demo/                  # ACTION / DATASET schema 文档
└── datasets/<id>/
    ├── raw/               # 原始数据（软链或下载脚本）
    ├── processed/         # 域内中间格式
    └── train/*_phi0/      # Phi-0 canonical（LeRobot v3.0）
```

分类轴写在 manifest，不在目录树里硬分：

- **action_schema**：统一 `unified_512`（= `phi0_action_v1`）
- **embodiment**：人手、人形、灵巧手、mocap、G1、移动体
- **tags**：`manipulation` / `locomotion` / `navigation` / `tactile` / `wholebody` 等

## 混训消费

Phi_0 侧通过 `Phi0MixedDataset` 读取 `manifests/mix.yaml` 中 `status: ready` 的条目。监督掩码以 Parquet **`action.dim_mask`** 为准；`supervision` 字段仅作转换模板名。

## 相关代码（Phi_0）

| 组件 | 路径 |
|------|------|
| 混合 Dataset | `Phi_0/src/phi0/data/processor.py` |
| EgoDex loader | `Phi_0/src/phi0/data/egodex.py` |
| Sonic unified | `Phi_0/src/phi0/data/sonic_unified_io.py` |
| Unified 512-d | `Phi_0/docs/report/architecture/unified_action.md` |
