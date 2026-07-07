# Phi0 Action Schema

Phi0 混训统一动作表示规范。各数据集在 `manifests/mix.yaml` 中通过 `action_schema` 字段声明所用 schema。

当前主推：**Unified 512-d**（`unified_512` / `unified_smplh_sonic_rot6d`）。

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
| `projected_gravity_xyz` | `[460:463)` | 3 | 重力在 body/pelvis 系下方向 |
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
- **`reserved_49`**：保留位，写入时填零；训练时通过 `dim_mask` 屏蔽，不计入 loss。

### 1.5 适用数据集

`manifests/mix.yaml` 中 `action_schema: unified_512` 的条目，例如：

- `humanoid_everyday`
- `t_rex`
- `bone_seed`
- `phuma`
- `sonic_g1`（`supervision: g1_sonic_deploy`）

原始 Parquet 字段到 512-d 的映射见各数据集 `docs/README.md` 与转换脚本。

---

## 相关文档

- [`PARQUET_FORMAT.md`](./PARQUET_FORMAT.md) — Sonic G1 demo episode Parquet 原始字段
- [`../manifests/mix.yaml`](../manifests/mix.yaml) — 混训数据集注册表与 `action_schema` 声明
