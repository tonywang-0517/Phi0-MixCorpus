#!/usr/bin/env bash
# Download zekaiwang/trex_dataset → datasets/t_rex/raw/trex_dataset
set -euo pipefail

DATASET_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "${DATASET_ROOT}/../.." && pwd)"
DEST="${DATASET_ROOT}/raw/trex_dataset"
LOG_DIR="${DATASET_ROOT}/logs"
LOG="${LOG_DIR}/download.log"
PROGRESS="${LOG_DIR}/download.progress.log"
EXPECTED_FILES=7903
REPO="zekaiwang/trex_dataset"

mkdir -p "$LOG_DIR" "$(dirname "$DEST")"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
  set +a
fi

: "${HF_TOKEN:?HF_TOKEN missing in ${PROJECT_ROOT}/.env}"

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

log "=== T-Rex download start ==="
log "DEST=$DEST"
log "REPO=$REPO"
log "进度: $PROGRESS | 监控: bash datasets/t_rex/scripts/watch_download.sh"

if ! HF_TOKEN="$HF_TOKEN" "$HF" auth whoami >/dev/null 2>&1; then
  log "ERROR: HF_TOKEN 无效，请更新 ${PROJECT_ROOT}/.env"
  exit 1
fi
log "HF token OK: $(HF_TOKEN="$HF_TOKEN" "$HF" auth whoami 2>&1 | head -1)"

watch_progress() {
  local dest="$1" expected="$2" prog="$3"
  local prev_bytes start_bytes start_ts interval=30
  prev_bytes="$(du -sb "$dest" 2>/dev/null | cut -f1)"
  start_bytes="$prev_bytes"
  start_ts="$(date +%s)"
  while pgrep -f "hf download ${REPO}" >/dev/null 2>&1; do
    sleep "$interval"
    local n sz pct curr_bytes delta inst_bps elapsed avg_bps inst_mb avg_mb
    n="$(find "$dest" -type f ! -path '*/.cache/*' 2>/dev/null | wc -l)"
    sz="$(du -sh "$dest" 2>/dev/null | cut -f1)"
    pct=$(( n * 100 / expected ))
    curr_bytes="$(du -sb "$dest" 2>/dev/null | cut -f1)"
    delta=$(( curr_bytes - prev_bytes ))
    inst_bps=$(( delta / interval ))
    elapsed=$(( $(date +%s) - start_ts ))
    avg_bps=$(( elapsed > 0 ? (curr_bytes - start_bytes) / elapsed : 0 ))
    inst_mb="$(awk "BEGIN{printf \"%.2f\", $inst_bps/1048576}")"
    avg_mb="$(awk "BEGIN{printf \"%.2f\", $avg_bps/1048576}")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] files=${n}/${expected} (${pct}%) size=${sz} speed=${inst_mb}MB/s avg=${avg_mb}MB/s" >> "$prog"
    prev_bytes="$curr_bytes"
  done
}

: > "$PROGRESS"
watch_progress "$DEST" "$EXPECTED_FILES" "$PROGRESS" &
WATCH_PID=$!

set +e
"$HF" download "$REPO" \
  --repo-type dataset \
  --local-dir "$DEST" \
  --token "$HF_TOKEN" \
  2>&1 | tee -a "$LOG"
DL_EXIT=$?
set -e

kill "$WATCH_PID" 2>/dev/null || true
wait "$WATCH_PID" 2>/dev/null || true

n="$(find "$DEST" -type f ! -path '*/.cache/*' 2>/dev/null | wc -l)"
log "download exit=$DL_EXIT  final files=${n}/${EXPECTED_FILES}  size=$(du -sh "$DEST" 2>/dev/null | cut -f1)"
[[ "$DL_EXIT" -eq 0 ]] || exit "$DL_EXIT"

log "=== T-Rex download finished ==="
bash "${PROJECT_ROOT}/scripts/setup_dataset_links.sh" --dataset t_rex 2>&1 | tee -a "$LOG"
