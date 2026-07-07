# demo Parquet 格式说明

本目录包含 **LeRobot / Hugging Face Datasets** 风格的 episode 级 Parquet 文件，用于 G1 人形遥操作（Sonic）采集数据的帧序列存储。

## 文件概览

| 文件 | 大小 | 行数（帧） | 时长 | 采样率 |
|------|------|-----------|------|--------|
| `episode_000000.parquet` | 1.66 MB | 1242 | ~24.82 s | 50 Hz |

- **Parquet 版本**: 2.6
- **写入工具**: `parquet-cpp-arrow version 24.0.0`
- **行组数**: 2
- **列数**: 34
- **压缩**: SNAPPY
- **元数据**: 含 `huggingface` 键，记录 Hugging Face `features` schema

## 数据模型

每一行对应 **一帧** 控制/观测数据。同一 episode 内所有帧的 `episode_index` 相同；`frame_index` 与 `index` 从 0 递增。

```
episode_000000.parquet
└── 1242 rows (frames)
    ├── observation.*   # 机器人本体观测
    ├── action.*        # 动作 / 控制目标
    ├── teleop.*        # 遥操作 / SMPL / VR 侧信号
    └── timestamp, frame_index, episode_index, index, task_index
```

## 字段 Schema

列名采用 `域.字段` 点分命名。向量列在 Parquet 中为 **定长列表**（`fixed_size_list`）。

### observation — 机器人观测

| 列名 | 类型 | 维度 | 说明 |
|------|------|------|------|
| `observation.state` | `float64[]` | 43 | 全身关节/状态向量 |
| `observation.eef_state` | `float64[]` | 14 | 末端执行器状态（左右手等） |
| `observation.root_orientation` | `float64[]` | 4 | 根部朝向四元数 (w,x,y,z) |
| `observation.projected_gravity` | `float64[]` | 3 | 投影重力向量 |
| `observation.cpp_rotation_offset` | `float64[]` | 4 | CPP 旋转偏移四元数 |
| `observation.init_base_quat` | `float64[]` | 4 | episode 初始基座四元数（episode 内恒定） |
| `observation.motor_temperature` | `float64[]` | 58 | 各电机温度 (°C)，实测约 38–75 |
| `observation.motor_error` | `float64[]` | 29 | 电机错误码 |
| `observation.motor_torque` | `float64[]` | 29 | 电机力矩 |

### action — 动作

| 列名 | 类型 | 维度 | 说明 |
|------|------|------|------|
| `action.wbc` | `float64[]` | 43 | Whole-Body Control 目标，与 `observation.state` 同维 |
| `action.motion_token` | `float64[]` | 64 | 动作 motion token 嵌入/编码 |

### teleop — 遥操作与人体先验

| 列名 | 类型 | 维度 | 说明 |
|------|------|------|------|
| `teleop.delta_heading` | `float64` | 1 | 航向增量 |
| `teleop.smpl_joints` | `float32[]` | 72 | SMPL 关节位置 (24×3) |
| `teleop.smpl_pose` | `float32[]` | 63 | SMPL 姿态参数 (21×3 轴角) |
| `teleop.body_quat_w` | `float32[]` | 4 | 人体根部四元数 (world) |
| `teleop.target_body_orientation` | `float32[]` | 6 | 目标身体朝向（含 heading 相关分量） |
| `teleop.left_hand_joints` | `float32[]` | 7 | 左手关节角 |
| `teleop.right_hand_joints` | `float32[]` | 7 | 右手关节角 |
| `teleop.smpl_frame_index` | `int64` | 1 | 对应 SMPL 源序列帧索引 (0–2021) |
| `teleop.left_wrist_joints` | `float32[]` | 3 | 左腕关节 |
| `teleop.right_wrist_joints` | `float32[]` | 3 | 右腕关节 |
| `teleop.stream_mode` | `int32` | 1 | 流模式（本文件恒为 1） |
| `teleop.planner_mode` | `int32` | 1 | 规划器模式（本文件恒为 0） |
| `teleop.planner_movement` | `float32[]` | 3 | 规划移动向量 (x,y,z) |
| `teleop.planner_facing` | `float32[]` | 3 | 规划朝向 |
| `teleop.planner_speed` | `float32` | 1 | 规划速度（-1 表示未启用） |
| `teleop.planner_height` | `float32` | 1 | 规划高度（-1 表示未启用） |
| `teleop.vr_3pt_position` | `float32[]` | 9 | VR 三点位置 (3×3) |
| `teleop.vr_3pt_orientation` | `float32[]` | 18 | VR 三点朝向 (3×6) |

### 索引与时间

| 列名 | 类型 | 取值范围（本文件） | 说明 |
|------|------|-------------------|------|
| `timestamp` | `float32` | 0.0 – 24.82 | 相对 episode 起始时间 (s)，步长约 0.02 s |
| `frame_index` | `int64` | 0 – 1241 | episode 内帧序号 |
| `episode_index` | `int64` | 0 | episode 编号 |
| `index` | `int64` | 0 – 1241 | 全局/数据集内行索引（本 episode 内与 frame_index 一致） |
| `task_index` | `int64` | 0 | 任务编号 |

## 首帧样例（Row 0）

```json
{
  "observation.state": [0.0153, 0.0685, 0.1235, "... (43)"],
  "observation.eef_state": [0.1448, 0.2244, 0.0115, "... (14)"],
  "action.wbc": [0.0862, -0.0233, 0.1566, "... (43)"],
  "observation.root_orientation": [0.9997, -0.0005, -0.0060, -0.0247],
  "observation.projected_gravity": [-0.0120, 0.0007, -0.9999],
  "observation.cpp_rotation_offset": [1.0, 0.0, 0.0, 0.0],
  "observation.init_base_quat": [0.9972, -0.0169, 0.0204, -0.0706],
  "teleop.delta_heading": 0.0,
  "action.motion_token": [0.0, 0.0, -0.125, "... (64)"],
  "teleop.smpl_joints": [0.3506, 0.0267, -0.0061, "... (72)"],
  "teleop.smpl_pose": [0.0256, 0.0143, 0.0764, "... (63)"],
  "teleop.body_quat_w": [0.6828, -0.0165, -0.0198, -0.7302],
  "teleop.target_body_orientation": [0.9987, 0.0, 0.0511, -0.0003, 0.9999, 0.0064],
  "teleop.left_hand_joints": [0, 0, 0, 0, 0, 0, 0],
  "teleop.right_hand_joints": [0, -0.0090, -0.0090, 0.0129, 0.0194, 0.0129, 0.0194],
  "teleop.smpl_frame_index": 1355,
  "teleop.left_wrist_joints": [-0.4745, -0.2260, 0.2770],
  "teleop.right_wrist_joints": [0.5748, -0.0662, 0.2960],
  "teleop.stream_mode": 1,
  "teleop.planner_mode": 0,
  "teleop.planner_movement": [0.0, 0.0, 0.0],
  "teleop.planner_facing": [1.0, 0.0, 0.0],
  "teleop.planner_speed": -1.0,
  "teleop.planner_height": -1.0,
  "teleop.vr_3pt_position": [0, 0, 0, 0, 0, 0, 0, 0, 0],
  "teleop.vr_3pt_orientation": [0, 0, 0, "... (18)"],
  "observation.motor_temperature": [39, 40, 39, "... (58)"],
  "observation.motor_error": [0, 0, 0, "... (29)"],
  "observation.motor_torque": [6.59, -9.58, 1.45, "... (29)"],
  "timestamp": 0.0,
  "frame_index": 0,
  "episode_index": 0,
  "index": 0,
  "task_index": 0
}
```

## 读取示例

```python
import pyarrow.parquet as pq

table = pq.read_table("episode_000000.parquet")
print(table.schema)
print(table.num_rows)          # 1242
print(table.column_names)      # 34 columns

# 取第 0 帧
row = {col: table.column(col)[0].as_py() for col in table.column_names}
```

或使用 Hugging Face `datasets`（会自动识别 `huggingface` 元数据中的 features）：

```python
from datasets import Dataset

ds = Dataset.from_parquet("episode_000000.parquet")
print(ds.features)
print(ds[0])
```

## 备注

- 本 demo 仅含 **单个 episode**（`episode_index = 0`），完整数据集通常按 `episode_XXXXXX.parquet` 分文件存储。
- `observation.init_base_quat` 在 episode 内保持不变，可作为 episode 级初始姿态参考。
- `teleop.planner_speed` / `teleop.planner_height` 为 `-1.0` 时表示规划器未激活。
- 关联数据集：`sonic_g1`（G1 人形遥操作），详见 `datasets/sonic_g1/docs/README.md`。
