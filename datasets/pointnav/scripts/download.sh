#!/usr/bin/env bash
# 可选 PointNav：Qwen-RobotNav ~984K 坐标目标轨迹无公开 HF 源
set -euo pipefail

DATASET_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "${DATASET_ROOT}/../.." && pwd)"
LOG="${DATASET_ROOT}/logs/download.log"
RAW="${DATASET_ROOT}/raw"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/hf_mirror.sh"

hf_mirror_load_env "$PROJECT_ROOT"
mkdir -p "${DATASET_ROOT}/logs" "$RAW"

hf_mirror_log "$LOG" "=== pointnav (optional) — no Qwen-equivalent HF dataset ==="
hf_mirror_log "$LOG" "MISSING: Qwen-RobotNav Point Goal ~984K（内部 sim 生成，未公开 HF）"
hf_mirror_log "$LOG" "Alternatives (non-HF): Habitat Gibson/MP3D PointNav zips → dl.fbaipublicfiles.com/habitat/data/datasets/pointnav/"
hf_mirror_log "$LOG" "HF partial (仅 ~200 episodes，非 Qwen 规模): vshwanilgv/wenavigatecontroller-episodes"

# 小规模 HM3D PointNav 专家轨迹（可选占位，便于后续 BC 实验）
PN_REPO="vshwanilgv/wenavigatecontroller-episodes"
PN_DEST="${RAW}/hm3d_minival_episodes/${PN_REPO}"
hf_mirror_download_repo_files dataset "$PN_REPO" "$PN_DEST" "$LOG" \
  README.md \
  meta.json \
  train.jsonl \
  val.jsonl || hf_mirror_log "$LOG" "WARN: ${PN_REPO} download failed (gated or network)"

hf_mirror_log "$LOG" "raw: $(find "$RAW" -type f 2>/dev/null | wc -l) files, $(du -sh "$RAW" 2>/dev/null | cut -f1 || echo 0)"
hf_mirror_log "$LOG" "=== pointnav script finished (see MISSING notes above) ==="

mkdir -p "${DATASET_ROOT}/train"
if [[ -d "${RAW}/hm3d_minival_episodes" ]]; then
  ln -sfn "../raw/hm3d_minival_episodes" "${DATASET_ROOT}/train/hm3d_minival_episodes"
fi

bash "${PROJECT_ROOT}/scripts/setup_dataset_links.sh" --dataset pointnav 2>&1 | tee -a "$LOG" || true
