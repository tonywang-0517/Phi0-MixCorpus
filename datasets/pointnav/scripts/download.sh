#!/usr/bin/env bash
# PointNav: vshwanilgv/wenavigatecontroller-episodes（HM3D minival ~200 episodes）
set -euo pipefail

DATASET_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "${DATASET_ROOT}/../.." && pwd)"
LOG="${DATASET_ROOT}/logs/download.log"
PN_REPO="vshwanilgv/wenavigatecontroller-episodes"
PN_DEST="${DATASET_ROOT}/raw/hm3d_minival_episodes/${PN_REPO}"
EXPECTED_FILES=23

mkdir -p "${DATASET_ROOT}/logs" "$PN_DEST"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
fi

: "${HF_TOKEN:?HF_TOKEN missing in ${PROJECT_ROOT}/.env}"

# ponytail: hf CLI 断点续传需直连 huggingface.co；mirror 仅 metadata 可用
unset HF_ENDPOINT HUGGINGFACE_HUB_ENDPOINT HF_HUB_ENDPOINT
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-3600}"
export HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-3600}"

HF="${HF:-hf}"
if ! command -v "$HF" >/dev/null 2>&1; then
  echo "ERROR: 未找到 hf CLI" >&2
  exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "=== pointnav download start (hf CLI, resume) ==="
log "REPO=$PN_REPO  DEST=$PN_DEST"

set +e
"$HF" download "$PN_REPO" \
  --repo-type dataset \
  --local-dir "$PN_DEST" \
  --token "$HF_TOKEN" \
  2>&1 | tee -a "$LOG"
DL_EXIT=$?
set -e

n="$(find "$PN_DEST" -type f ! -path '*/.cache/*' 2>/dev/null | wc -l)"
log "exit=$DL_EXIT  files=${n}/${EXPECTED_FILES}  size=$(du -sh "$PN_DEST" 2>/dev/null | cut -f1)"
[[ "$DL_EXIT" -eq 0 ]] || exit "$DL_EXIT"

log "=== pointnav download finished ==="

mkdir -p "${DATASET_ROOT}/train"
ln -sfn "../raw/hm3d_minival_episodes" "${DATASET_ROOT}/train/hm3d_minival_episodes"
bash "${PROJECT_ROOT}/scripts/setup_dataset_links.sh" --dataset pointnav 2>&1 | tee -a "$LOG" || true
