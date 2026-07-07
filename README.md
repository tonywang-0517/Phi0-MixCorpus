# Phi0-MixCorpus

Phi-0 混训语料构建。与 `Phi_0/` 训练代码解耦：本目录负责 **原始数据 → 中间格式 → 训练可读格式**，混训注册在 `manifests/mix.yaml`。

## 数据集

| ID | 名称 | action schema | embodiment | 状态 |
|----|------|---------------|------------|------|
| `egodex` | EgoDex | keypoints_256 | human_egocentric | 待接入 |
| `humanoid_everyday` | Humanoid Everyday | unified_512 | humanoid | 待接入 |
| `t_rex` | T-Rex | unified_512 | dexterous_hand | 待接入 |
| `bone_seed` | Bone-SEED | unified_512 | human_mocap | 待接入 |
| `phuma` | PHUMA | unified_512 | human_mocap | 待接入 |
| `sonic_g1` | Sonic 采集 | unified_512 | g1_humanoid | 待接入 |
| `r2r` | R2R | nav | mobile_agent | 待接入 |

## 目录约定

```
Phi0-MixCorpus/
├── manifests/mix.yaml     # 混训注册表（权重、schema、监督掩码、tag）
└── datasets/<id>/         # 每个数据集独立目录
    ├── raw/               # 原始数据（软链或下载脚本）
    ├── processed/         # 域内中间格式
    └── train/             # Phi-0 可读产物（LeRobot / unified parquet 等）
```

分类轴写在 manifest，不在目录树里硬分：

- **action_schema**：`keypoints_256` / `unified_512` / `nav`
- **embodiment**：人手、人形、灵巧手、mocap、G1、移动体
- **tags**：`manipulation` / `locomotion` / `navigation` / `tactile` / `wholebody` 等，仅作采样与文档标注

## 混训消费

Phi_0 侧通过 `Phi0MixedDataset`（或后续 weighted mixture）读取 `manifests/mix.yaml` 中 `status: ready` 的条目。各数据集监督掩码对应 `dim_mask_for_dataset(supervision)`。

## 相关代码（Phi_0）

| 组件 | 路径 |
|------|------|
| 混合 Dataset | `Phi_0/src/phi0/data/processor.py` |
| EgoDex loader | `Phi_0/src/phi0/data/egodex.py` |
| Sonic unified | `Phi_0/src/phi0/data/sonic_unified_io.py` |
| Unified 512-d | `Phi_0/docs/report/architecture/unified_action.md` |
