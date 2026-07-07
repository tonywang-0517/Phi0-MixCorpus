# Phi0 Action Schema

Phi0 混训统一动作表示规范（**`phi0_action_v1`**）。各数据集在 `manifests/mix.yaml` 中通过 `action_schema: unified_512` 声明（与 `phi0_action_v1` 同义）。

Parquet 中仅存扁平列 **`action.unified[512]`** + **`action.dim_mask[512]`**；见 [`PHI0_DATASET_SCHEMA.md`](./PHI0_DATASET_SCHEMA.md)。

内部表示名：`unified_smplh_sonic_rot6d`。

---

## 1. Unified 512-d（主推）

| 属性 | 值 |
|------|-----|
| 总维度 | `D_UNIFIED = 512` |
| 表示名 | `unified_smplh_sonic_rot6d` |
| 旋转约定 | 6D rotation（Zhou et al.，旋转矩阵前两列） |

### 1.1 分段总览

```
[0:346)   SMPL-H 语义
[346:360) G1 Dex3 夹爪 14 维
[360:396) G1 body qpos 36 维
[396:460) SONIC motion_token 64 维
[460:463) projected_gravity 3 维
[463:512) reserved padding 49 维
```

### 1.2 字段明细

| 字段 | 索引 | 维数 | 说明 |
|------|------|------|------|
| `root_trans_local` | `[0:3)` | 3 | 骨盆平移 delta（相对 proprio `State_t`） |
| `root_rot6d` | `[3:9)` | 6 | 骨盆全局朝向（6D rot） |
| `joint_rot6d_local_51` | `[9:315)` | 306 | 关节 1–51 的 parent-local 6D rot |
| `contacts_body21` | `[315:336)` | 21 | 身体接触 |
| `tactile_fingertips_10` | `[336:346)` | 10 | 指尖触觉 |
| `g1_gripper_joints_14` | `[346:360)` | 14 | Dex3 双手，WBC 顺序：index×2, middle×2, thumb×3 / 手 |
| `g1_body_qpos_root_xyz` | `[360:363)` | 3 | root xyz |
| `g1_body_qpos_root_quat` | `[363:367)` | 4 | root quat **wxyz** |
| `g1_body_qpos_dof29` | `[367:396)` | 29 | body 29 dof |
| `sonic_motion_token_64` | `[396:460)` | 64 | gear_sonic deploy encoder 输出 |
| `projected_gravity_xyz` | `[460:463)` | 3 | **下一帧** \(t{+}1\) 重力在 body/pelvis 系下方向（预测目标） |
| `reserved_49` | `[463:512)` | 49 | padding，恒零，**不参与 loss** |

### 1.3 分段结构图

```
unified_smplh_sonic_rot6d  (512-d)
├─ [0:346)   SMPL-H
│   ├─ [0:3)     root_trans_local
│   ├─ [3:9)     root_rot6d
│   ├─ [9:315)   joint_rot6d_local_51   (51 joints × 6)
│   ├─ [315:336) contacts_body21
│   └─ [336:346) tactile_fingertips_10
├─ [346:360) G1 Dex3 gripper
│   └─ [346:360) g1_gripper_joints_14
├─ [360:396) G1 body qpos
│   ├─ [360:363) g1_body_qpos_root_xyz
│   ├─ [363:367) g1_body_qpos_root_quat
│   └─ [367:396) g1_body_qpos_dof29
├─ [396:460) sonic_motion_token_64
├─ [460:463) projected_gravity_xyz
└─ [463:512) reserved_49  (zero padding, masked in loss)
```

### 1.4 约定说明

- **6D rotation**：每个关节/根部朝向占 6 维，为旋转矩阵 \(R \in SO(3)\) 的前两列展平；与 Zhou et al. 连续旋转表示一致。
- **`root_trans_local`**：骨盆平移为相对当前 proprioceptive 状态 `State_t` 的 delta，非世界坐标绝对值。
- **`g1_gripper_joints_14`**：左右 Dex3 夹爪，按 WBC 顺序排列——每只手 index×2, middle×2, thumb×3。
- **`g1_body_qpos_root_quat`**：四元数顺序为 **w, x, y, z**。
- **`sonic_motion_token_64`**：来自 gear_sonic deploy encoder，与 `action.motion_token`（见 `PARQUET_FORMAT.md`）语义对应。
- **`projected_gravity_xyz`（action 段）**：帧 `t` 行上存的是 **\(t{+}1\) 时刻** 的投影重力（预测/监督目标）。当前时刻重力见 `observation.projected_gravity`（[`PHI0_DATASET_SCHEMA.md`](./PHI0_DATASET_SCHEMA.md) §5.3）。
- **`reserved_49`**：保留位，写入时填零；训练时通过 `dim_mask` 屏蔽，不计入 loss。

### 1.5 适用数据集

`manifests/mix.yaml` 中 `action_schema: unified_512` 的条目，例如：

- `humanoid_everyday`
- `xperience`
- `egodex`
- `t_rex`
- `bone_seed`
- `phuma`
- `sonic_g1`（`supervision: g1_sonic_deploy`）

原始 Parquet 字段到 512-d 的映射见各数据集 `docs/README.md` 与转换脚本。

---

## 相关文档

- [`PHI0_DATASET_SCHEMA.md`](./PHI0_DATASET_SCHEMA.md) — Phi-0 LeRobot v3.0 数据集格式（canonical 列、mask、dataloader 契约）
- [`PARQUET_FORMAT.md`](./PARQUET_FORMAT.md) — Sonic G1 原始采集 Parquet（转换源，非训练格式）
- [`../manifests/mix.yaml`](../manifests/mix.yaml) — 混训数据集注册表与 `action_schema` 声明
