# Phi-0 数据集格式规范（LeRobot v3.0）

Phi-0 混训语料的 **canonical 训练格式**。与 [LeRobot Dataset v3.0](https://github.com/huggingface/lerobot/blob/main/docs/source/lerobot-dataset-v3.mdx) 对齐，在标准 `meta/` + `data/` + `videos/` 布局上增加 Phi-0 专用列与帧级 mask。

> **设计原则**：dataloader 每帧只读固定形状张量，无需运行时拼装、无需查 episode 级元数据推断缺失模态。  
> **不包含**：`keypoints_256`（不作为 action，也不进入 observation）。

---

## 1. 术语

| 名称 | 含义 |
|------|------|
| `phi0_action_v1` | Phi-0 唯一 action 表示（512 维，见 [`ACTION_SCHEMA.md`](./ACTION_SCHEMA.md)） |
| `unified_512` | `mix.yaml` 历史别名，与 `phi0_action_v1` 同义 |
| `action.unified` | Parquet 扁平 action GT，`float32[512]` |
| `action.dim_mask` | Parquet 帧级监督掩码，`bool[512]` |
| canonical 列 | dataloader **必须**依赖的列 |

**为何叫 unified**：不同 embodiment 共用 **512 维动作容器**；VLN 轨迹落在 `[0:9)`（`root_trans_local` + `root_rot6d`），无需单独 nav schema。

---

## 2. LeRobot v3.0 合规清单

对照本仓库 T-Rex（`codebase_version: v3.0`）与官方文档，Phi-0 数据集 **必须** 满足：

| 项目 | LeRobot v3.0 要求 | Phi-0 约定 |
|------|-------------------|------------|
| 版本 | `codebase_version: "v3.0"` | 固定 |
| 数据路径 | `data/chunk-{chunk_index:03d}/file-{file_index:03d}.parquet` | 同左；多 episode 合文件 |
| 视频路径 | `videos/{video_key}/chunk-.../file-....mp4` | `video_key = observation.images.ego_view` |
| 任务表 | `meta/tasks.parquet`（`task_index`, `task`） | 同左；VLN 指令放此 |
| Episode 索引 | `meta/episodes/chunk-*/file-*.parquet` | **必须**；含 data/video 偏移与 per-episode stats |
| 全局统计 | `meta/stats.json` | **必须**；mask-aware 聚合（§8） |
| 分块参数 | `chunks_size`, `data_files_size_in_mb`, `video_files_size_in_mb` | 转换脚本写入 |
| 划分 | `splits`（如 `{"train": "0:N"}`） | 写入 `info.json` |
| 规模 | `total_episodes`, `total_frames`, `total_tasks` | 与 episodes 一致 |
| 视频 feature | `dtype: video`, `shape: [H,W,3]`, `info.video.*` | 见 §10 示例 |
| 录制收尾 | `dataset.finalize()` 关闭 Parquet writer | 转换脚本等价调用 |

**不兼容**：v2.1 每 episode 单文件（`episode_{i:06d}.parquet`）仅作转换源，产出必须 v3.0。

**Phi-0 扩展**（不破坏 LeRobot 加载）：`meta/info.json` 根级 `phi0` 块；`meta/stats.json` 根级 `phi0` 块记录 mask-aware 元信息。

---

## 3. 目录结构

```
<dataset_root>/
├── meta/
│   ├── info.json
│   ├── stats.json
│   ├── tasks.parquet
│   └── episodes/
│       └── chunk-{chunk_index:03d}/
│           └── file-{file_index:03d}.parquet
├── data/
│   └── chunk-{chunk_index:03d}/
│       └── file-{file_index:03d}.parquet
├── videos/
│   └── observation.images.ego_view/
│       └── chunk-{chunk_index:03d}/
│           └── file-{file_index:03d}.mp4
└── README.md
```

---

## 4. `meta/info.json`

### 4.1 LeRobot 标准字段（必填）

```json
{
  "codebase_version": "v3.0",
  "robot_type": "unitree_g1",
  "fps": 50,
  "total_episodes": 100,
  "total_frames": 50000,
  "total_tasks": 3,
  "chunks_size": 1000,
  "data_files_size_in_mb": 100,
  "video_files_size_in_mb": 200,
  "splits": { "train": "0:100" },
  "data_path": "data/chunk-{chunk_index:03d}/file-{file_index:03d}.parquet",
  "video_path": "videos/{video_key}/chunk-{chunk_index:03d}/file-{file_index:03d}.mp4",
  "features": { }
}
```

### 4.2 Phi-0 扩展块 `phi0`

```json
{
  "phi0": {
    "schema_version": "1.0",
    "action_representation": "phi0_action_v1",
    "action_dim": 512,
    "canonical_action_columns": ["action.unified", "action.dim_mask"],
    "canonical_observation_columns": [
      "observation.images.ego_view",
      "observation.qpos",
      "observation.projected_gravity",
      "observation.tactile",
      "observation.contacts",
      "observation.proprio_mask"
    ],
    "action_segment_slices": {
      "smplh": [0, 346],
      "g1_gripper": [346, 360],
      "g1_body": [360, 396],
      "sonic_token": [396, 460],
      "gravity": [460, 463],
      "reserved": [463, 512]
    },
    "embodiment": "g1_humanoid",
    "mix_dataset_id": "sonic_g1",
    "stats_policy": "mask_aware_v1"
  }
}
```

### 4.3 `meta/tasks.parquet`

| 列 | 类型 | 说明 |
|----|------|------|
| `task_index` | int64 | 与帧 `task_index` 对齐 |
| `task` | string | 自然语言指令或任务名 |

### 4.4 `meta/episodes/*.parquet`（必填）

每行一个 episode，至少包含 LeRobot v3 索引列：

| 列 | 说明 |
|----|------|
| `episode_index` | Episode ID |
| `tasks` | 本 episode 任务字符串列表 |
| `length` | 帧数 |
| `data/chunk_index`, `data/file_index` | 对应 `data/` 分片 |
| `dataset_from_index`, `dataset_to_index` | 全局帧偏移 `[from, to)` |
| `videos/observation.images.ego_view/chunk_index` | 视频分片 |
| `videos/observation.images.ego_view/file_index` | 视频分片 |
| `videos/observation.images.ego_view/from_timestamp` | episode 在 MP4 内起始时间 (s) |
| `videos/observation.images.ego_view/to_timestamp` | episode 在 MP4 内结束时间 (s) |
| `stats/<feature>/{mean,std,min,max,count,q01,q10,q50,q90,q99}` | per-episode 统计（§8） |

---

## 5. 帧级 Parquet 列规范

每一行 = **一帧**，observation 与 action 时间对齐。

### 5.1 索引与时间

| 列名 | dtype | shape | 说明 |
|------|-------|-------|------|
| `timestamp` | float32 | [1] | 相对 episode 起点 (s) |
| `frame_index` | int64 | [1] | episode 内序号 |
| `episode_index` | int64 | [1] | episode 编号 |
| `index` | int64 | [1] | 数据集全局行索引 |
| `task_index` | int64 | [1] | → `meta/tasks.parquet` |
| `next.done` | bool | [1] | episode 末帧 `true`（LeRobot v3 已支持 `bool`） |

### 5.2 Action（canonical）

| 列名 | dtype | shape | 说明 |
|------|-------|-------|------|
| **`action.unified`** | float32 | **[512]** | `phi0_action_v1` GT |
| **`action.dim_mask`** | bool | **[512]** | 帧级监督掩码（§7） |

- **不入库**：分解列、`keypoints_256`、原始 `teleop.*`
- **时间语义（帧 `t` 一行）**：
  - `observation.*[t]`：**当前时刻** \(t\) 的观测（含图像、proprio）
  - `action.unified[t]`：以 \(t\) 为条件的**控制/预测目标**；其中 `[460:463)` `projected_gravity_xyz` 为 **\(t{+}1\)** 的投影重力（下一帧预测），其余 action 段语义见 [`ACTION_SCHEMA.md`](./ACTION_SCHEMA.md)
  - episode 末帧：无 \(t{+}1\) 时，`action.dim_mask[460:463)` 置 `false`，对应维填 0

### 5.3 Observation

#### 视觉（单目）

| 列名 | dtype | shape | 说明 |
|------|-------|-------|------|
| **`observation.images.ego_view`** | video | **[H, W, 3]** | 像素在 `videos/`；Parquet 不内嵌图像 |

- **立体源选左眼**：双相机 / 立体采集统一取 **left**（如 xperience `stereo_left`）写入 `ego_view`。
- **分辨率**：各数据集在 `meta/info.json` → `features` 中声明**原生** `H×W`；**混训不强制统一分辨率**，训练时在 collate / transform 中按需 resize（见 §5.4）。
- **VLN / RGB-D**：v1 仅收录 **RGB** 至 `ego_view`；depth 不入库。
- `features` 中须含 `info.video`（codec、fps、pix_fmt 等），与 T-Rex / 官方 v3 一致。

#### 5.4 混训图像分辨率

| 规则 | 说明 |
|------|------|
| 存储 | 保持各数据集**原始分辨率**写入 MP4 |
| 混训 | **不**在 schema 层强制统一 `H×W` |
| 训练 | `Phi0MixedDataset` / collate 或 LeRobot `image_transforms` 中按模型输入 resize；不同子集可不同原生尺寸 |

#### 本体（proprio）

| 列名 | dtype | shape | 说明 |
|------|-------|-------|------|
| **`observation.qpos`** | float32 | **[43]** | G1 WBC：29 body + 14 gripper |
| **`observation.projected_gravity`** | float32 | **[3]** | **当前帧** \(t\) body / pelvis 系投影重力 |
| **`observation.tactile`** | float32 | **[10]** | 指尖触觉；无则 **0** |
| **`observation.contacts`** | float32 | **[21]** | 身体接触；无则 **0** |
| **`observation.proprio_mask`** | bool | **[4]** | `[qpos, gravity, tactile, contacts]` 段有效 |

**`observation.qpos` 布局**：

```
[0:29)   body 29 dof
[29:43)  Dex3 双手 14 维（index×2, middle×2, thumb×3 / 手）
```

#### 语言

VLN 等：`task_index` + `meta/tasks.parquet`，不占 per-frame 字符串列。

---

## 6. 非 G1 平台：Sonic 补全 observation

无 Unitree 实机 qpos 时，可用 **Sonic SMPL encoder** 与 **motion planner** 在转换阶段补全部分 proprio，再写入同一套列。

### 6.1 补全来源

| 目标列 | SMPL encoder | Motion planner | 实机 / sim |
|--------|--------------|----------------|------------|
| `observation.qpos` | 人体 → G1 retarget / IK 填部分 dof | 规划关节目标填入对应槽位 | Unitree debug 全量 |
| `observation.projected_gravity` | 由 root/body 朝向推算 | planner 身体朝向 | IMU / sim |
| `observation.tactile` | — | — | 触觉传感器；无则 0 |
| `observation.contacts` | SMPL 接触推理（若有） | — | 接触传感器 / 标注 |

### 6.2 写入规则

1. **能补则写值 + `proprio_mask=true`**：Sonic 推断视为有效训练输入（与实机测量同等进入 batch）。
2. **不能补则 0 + `proprio_mask=false`**：dataloader 侧可用 mask 做 attention / loss 加权。
3. **禁止**把补全逻辑放进 dataloader；均在 `convert_to_phi0.py` 完成。
4. 建议在 `phi0` 块记录 `proprio_fill_policy: sonic_smpl_encoder | motion_planner | hardware`（数据集级默认）；逐帧若有混合来源，可写入 episode 元数据备注，**不增加** parquet 列（保持 dataloader 简单）。

### 6.3 embodiment 与补全预期

| embodiment | qpos | gravity | tactile | contacts |
|------------|------|---------|---------|----------|
| G1 Sonic 实机 | hardware | hardware | 常无 → 0/false | 常无 → 0/false |
| 人体 mocap | sonic/retarget 部分 | sonic / IMU | 常无 | 标注则有 |
| VLN | planner / sim pose 子集 | sim | 无 | 无 |
| 灵巧手 t_rex | 不适用 G1 qpos → false | 可选 | hardware | 可选 |

---

## 7. `action.dim_mask` 语义（方案 B）

| 规则 | 说明 |
|------|------|
| `mask[i] == true` | 维 `i` 有 GT，参与 loss |
| `mask[i] == false` | 无 GT；`action.unified[i] == 0`，不参与 loss |
| `[463:512)` reserved | 值恒 0，mask 恒 false |

**权威来源**：Parquet 帧级 `action.dim_mask`（非 `mix.yaml`）。

### 7.1 embodiment 默认 mask 模板（转换用）

| embodiment | 典型 true 段 |
|------------|--------------|
| G1 Sonic | `g1_*`, `sonic_token`, `gravity`；有 SMPL 时 `smplh` 子集 |
| 人体 mocap | `smplh`；`gravity` 若有 |
| VLN | `[0:9)` root trans + rot6d |
| 灵巧手 | 手 / tactile 相关映射段 |

---

## 8. `stats.json` 计算规范（mask-aware）

LeRobot v3 的 `meta/stats.json` 用于 `dataset.meta.stats` 归一化。Phi-0 **必须** mask-aware，避免把 padding 零和无效维计入 mean/std。

### 8.1 统计字段（与 LeRobot 对齐）

每个 **参与归一化的 float feature** 输出：

```
min, max, mean, std, count, q01, q10, q50, q90, q99
```

- 标量 shape `[1]` 的列（如 `timestamp`）长度为 1 的数组
- 向量列（如 `action.unified`）长度为 `shape[0]` 的数组

### 8.2 纳入 / 排除

| Feature | 纳入全局 stats | 说明 |
|---------|----------------|------|
| `action.unified` | **是（mask-aware）** | 仅 `dim_mask[i]==true` 的样本参与维 `i` |
| `observation.qpos` | **是（segment-aware）** | 仅 `proprio_mask[0]==true` 的帧 |
| `observation.projected_gravity` | 是 | 仅 `proprio_mask[1]==true` |
| `observation.tactile` | 是 | 仅 `proprio_mask[2]==true` |
| `observation.contacts` | 是 | 仅 `proprio_mask[3]==true` |
| `observation.images.ego_view` | 是 | 像素统计（与 LeRobot 相同，可抽样加速） |
| `action.dim_mask` | **否** | 布尔掩码，非连续值 |
| `observation.proprio_mask` | **否** | 同上 |
| `frame_index`, `episode_index`, `index`, `task_index` | **否** | 索引列，不参与归一化 |
| `next.done` | **否** | 布尔标志 |

### 8.3 聚合流程（转换脚本 / `compute_phi0_stats.py`）

```
对每个 episode:
  1. 遍历帧，收集有效样本
  2. 写 meta/episodes 中 stats/<feature>/*
全局:
  3. 按 count 加权合并各 episode stats → meta/stats.json
  4. 写 meta/stats.json → phi0 块（有效样本计数）
```

**`action.unified` 逐维聚合**（维 `i`）：

```python
samples_i = [ frame["action.unified"][i]
              for frame in episode
              if frame["action.dim_mask"][i] ]
# 若 samples_i 为空：stats 中 mean/std 置 0，count 置 0，并在 phi0.invalid_dims 记录
```

**proprio 逐段聚合**：段 `s` 无效帧**整段跳过**（不把填充零计入）。

### 8.4 `meta/stats.json` 示例（节选）

```json
{
  "action.unified": {
    "min": [ "... 512 ..." ],
    "max": [ "... 512 ..." ],
    "mean": [ "... 512 ..." ],
    "std": [ "... 512 ..." ],
    "count": [ 12000, 12000, 0, 0, "... per-dim sample counts ..." ],
    "q01": [ "..." ],
    "q10": [ "..." ],
    "q50": [ "..." ],
    "q90": [ "..." ],
    "q99": [ "..." ]
  },
  "observation.qpos": { "mean": ["..."], "std": ["..."], "count": ["... 43 ..."] },
  "observation.projected_gravity": { },
  "phi0": {
    "stats_policy": "mask_aware_v1",
    "action_dim_valid_count": [ 12000, 12000, 0 ],
    "proprio_segment_frame_counts": [ 5000, 5000, 0, 0 ],
    "notes": "count[i]=0 的维勿用于归一化；训练侧应结合 dim_mask"
  }
}
```

### 8.5 训练侧使用

```python
# 归一化 action 维 i 前检查
if dataset.meta.stats["phi0"]["action_dim_valid_count"][i] > 0:
    x_i = (x_i - mean[i]) / (std[i] + eps)
# loss 仍由 action.dim_mask 控制，与 stats 独立
```

### 8.6 混训跨数据集 stats 二次聚合（已定）

混训时 **Phi0MixedDataset / collate 之前** 对各子集的 `meta/stats.json` 做二次聚合，得到 `mix_stats.json`（或内存缓存），供归一化使用。

**输入**：每个子数据集 `meta/stats.json`（已 mask-aware）+ `mix.yaml` 采样权重 `weight`。

**逐维加权合并**（以 `action.unified` 维 `i` 为例）：

```python
# 子集 k: count_k[i], mean_k[i], std_k[i]（来自该集 stats；count=0 的维跳过）
w_k = mix_weight_k * count_k[i]   # 或按有效帧数加权
mean_mix[i] = sum(w_k * mean_k[i]) / sum(w_k)
# 合并方差用 pooled 公式（需各集 std 与 count）
```

**`phi0.action_dim_valid_count`**：混训层合并各子集 count，得到全局「哪些维曾有 GT」；`count_mix[i]==0` 的维不做归一化。

**注意**：

- 二次聚合在 **训练代码 / mix manifest 层**，不写入各子数据集 Parquet。
- 各子集 **仍保留** 自己的 `stats.json`（可单独训练、调试）。
- proprio 段级 stats 同理，按 `proprio_segment_frame_counts` 加权。

---

## 9. Action chunking 与 schema 的关系

### 9.1 「collate 层滑窗」是什么意思

**Parquet 里**：每行一帧，只存 **当前时刻** 的 action：

```
frame t:   action.unified  shape (512,)
           action.dim_mask shape (512,)
```

**训练时**：扩散策略 / action head 常需要连续 **H 步** action（`action_horizon = H`）。这 **不写入数据集**，而在 `DataLoader` 的 **collate** 里用滑窗从相邻帧拼接：

```
collate 取 episode 内连续帧 [t, t+1, …, t+H-1]
  → action.unified  stack 成 (B, H, 512)
  → action.dim_mask   stack 成 (B, H, 512)
```

示意（`H=4`）：

```
Parquet:  ...  frame_{t-1}  frame_t  frame_{t+1}  frame_{t+2}  frame_{t+3}  ...
Collate 采样起点 t:
          actions = [a_t, a_{t+1}, a_{t+2}, a_{t+3}]   # shape (4, 512)
```

观测若需要历史帧（如 `obs_horizon`），同样在 collate 或 LeRobot `delta_timestamps` 取 **过去** 帧，与 action **未来** 窗对称处理。

### 9.2 是否影响 schema 设计？

**不影响 Parquet / `info.json` features 设计。** 理由：

| 层面 | 约定 |
|------|------|
| 存储 | 恒 **1 帧 : 1 行**，不增加 `action.unified` 第二维 |
| `action.dim_mask` | 每帧 512 bool，collate 时沿时间维 stack 为 `(B,H,512)` |
| episode 边界 | collate 负责：跨 `next.done` 的窗丢弃或 padding（训练代码策略，非 schema） |
| LeRobot | 与 v3 `delta_timestamps` 时间窗语义一致，无需自定义列 |

可选：在 `mix.yaml` 或训练 config 中声明 `action_horizon`、`obs_horizon`；**不必**写入 `meta/info.json`（除非做数据集级默认值文档）。

**结论**：schema 保持单帧 canonical；chunking 是 **Phi_0 训练 pipeline**  concern，不是数据格式 concern。

---

## 10. `features` 完整示例

```json
{
  "codebase_version": "v3.0",
  "robot_type": "unitree_g1",
  "fps": 50,
  "total_episodes": 100,
  "total_frames": 50000,
  "total_tasks": 3,
  "chunks_size": 1000,
  "data_files_size_in_mb": 100,
  "video_files_size_in_mb": 200,
  "splits": { "train": "0:100" },
  "data_path": "data/chunk-{chunk_index:03d}/file-{file_index:03d}.parquet",
  "video_path": "videos/{video_key}/chunk-{chunk_index:03d}/file-{file_index:03d}.mp4",
  "features": {
    "observation.images.ego_view": {
      "dtype": "video",
      "shape": [480, 640, 3],
      "names": ["height", "width", "channels"],
      "info": {
        "video.height": 480,
        "video.width": 640,
        "video.codec": "h264",
        "video.pix_fmt": "yuv420p",
        "video.fps": 50,
        "video.channels": 3,
        "video.is_depth_map": false,
        "has_audio": false
      }
    },
    "observation.qpos": { "dtype": "float32", "shape": [43] },
    "observation.projected_gravity": { "dtype": "float32", "shape": [3] },
    "observation.tactile": { "dtype": "float32", "shape": [10] },
    "observation.contacts": { "dtype": "float32", "shape": [21] },
    "observation.proprio_mask": { "dtype": "bool", "shape": [4] },
    "action.unified": { "dtype": "float32", "shape": [512] },
    "action.dim_mask": { "dtype": "bool", "shape": [512] },
    "timestamp": { "dtype": "float32", "shape": [1] },
    "frame_index": { "dtype": "int64", "shape": [1] },
    "episode_index": { "dtype": "int64", "shape": [1] },
    "index": { "dtype": "int64", "shape": [1] },
    "task_index": { "dtype": "int64", "shape": [1] },
    "next.done": { "dtype": "bool", "shape": [1] }
  },
  "phi0": {
    "schema_version": "1.0",
    "action_representation": "phi0_action_v1",
    "stats_policy": "mask_aware_v1",
    "mix_dataset_id": "sonic_g1"
  }
}
```

---

## 11. Dataloader 契约

```python
from lerobot.datasets import LeRobotDataset

ds = LeRobotDataset("<dataset_root>")
frame = ds[0]
assert frame["action.unified"].shape == (512,)
assert frame["action.dim_mask"].shape == (512,)
assert frame["action.dim_mask"][463:].sum() == 0
assert frame["observation.proprio_mask"].shape == (4,)
```

**必须遵守**：

1. 不现场拼装 `action.unified`
2. `dim_mask[i]==false` → `action.unified[i]==0`
3. `proprio_mask[j]==false` → 对应 proprio 段全 0
4. loss 用 `action.dim_mask`；归一化用 `meta/stats` + `phi0.action_dim_valid_count`
5. 混训子集均为 512 维 action

---

## 12. 转换流水线

```
raw / v2.1 / 厂商 Parquet
    → convert_to_phi0.py
    → LeRobot v3.0 目录 + finalize()
    → compute_phi0_stats.py（mask-aware）
    → datasets/<id>/train/<name>/
```

1. 写帧列 + episode 索引 + 视频 MP4 分片  
2. `finalize()` 关闭 writer  
3. 计算 per-episode + 全局 stats  
4. 校验：LeRobot `LeRobotDataset` 可加载、`stats.json` 含 `phi0` 块  

---

## 13. 与 `mix.yaml` 的关系

| 字段 | 角色 |
|------|------|
| `action_schema: unified_512` | = `phi0_action_v1` |
| `path` | 符合本规范的 `train/` 目录 |
| `supervision` | 转换默认 mask 模板名；**不**替代帧级 mask |
| `embodiment` | 与 `phi0.embodiment` 一致 |

---

## 14. 已定事项（v1.0）

| 话题 | 结论 |
|------|------|
| 混训全局归一化 | per-dataset stats + 混训层二次聚合（§8.6） |
| action chunking | 单帧 Parquet；`action_horizon` 在 collate 滑窗（§9） |
| 重力时序 | `observation.projected_gravity` = \(t\)；`action.unified[460:463)` = \(t{+}1\) 预测 |
| 单目 | 立体源取 **左眼** → `ego_view` |
| 分辨率 | 原生 `H×W` 入库；混训**不**强制统一，训练侧 resize |
| Sonic 补全 | 无质量阈值；`proprio_mask` 控制是否采用 |
| `mix.yaml` | 全部 `action_schema: unified_512`；`path` → `train/*_phi0` |

---

## 相关文档

- [`ACTION_SCHEMA.md`](./ACTION_SCHEMA.md) — 512 维语义
- [`PARQUET_FORMAT.md`](./PARQUET_FORMAT.md) — Sonic 原始 Parquet（转换源）
- [`../manifests/mix.yaml`](../manifests/mix.yaml) — 混训注册表
- [LeRobot Dataset v3.0](https://github.com/huggingface/lerobot/blob/main/docs/source/lerobot-dataset-v3.mdx) — 上游格式规范
