#!/usr/bin/env bash
# Monitor InternData-N1 vln_ce / vln_pe download progress.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INTERVAL="${INTERVAL_SEC:-30}"

watch_one() {
  local name="$1" dir="$2"
  [[ -d "$dir" ]] || dir="$(dirname "$dir")"
  mkdir -p "$dir" 2>/dev/null || true
  local prev_bytes start_bytes start_ts
  prev_bytes="$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)"
  start_bytes="$prev_bytes"
  start_ts="$(date +%s)"

  while pgrep -f "InternRobotics/InternData-N1" >/dev/null 2>&1 \
     || pgrep -f "download_vln_ce.sh" >/dev/null 2>&1 \
     || pgrep -f "download_vln_pe.sh" >/dev/null 2>&1; do
    sleep "$INTERVAL"
    local n sz curr_bytes delta inst_bps elapsed avg_bps inst_mb avg_mb
    n="$(find "$dir" -type f ! -path '*/.cache/*' ! -path '*/_hf_staging/*' 2>/dev/null | wc -l)"
    sz="$(du -sh "$dir" 2>/dev/null | cut -f1 || echo '?')"
    curr_bytes="$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)"
    delta=$(( curr_bytes - prev_bytes ))
    inst_bps=$(( delta / INTERVAL ))
    elapsed=$(( $(date +%s) - start_ts ))
    avg_bps=$(( elapsed > 0 ? (curr_bytes - start_bytes) / elapsed : 0 ))
    inst_mb="$(awk "BEGIN{printf \"%.2f\", $inst_bps/1048576}")"
    avg_mb="$(awk "BEGIN{printf \"%.2f\", $avg_bps/1048576}")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${name}  files=${n}  size=${sz}  speed=${inst_mb}MB/s  avg=${avg_mb}MB/s"
    prev_bytes="$curr_bytes"
  done
}

echo "InternData-N1 下载监控 | 每 ${INTERVAL}s 刷新"
echo "vln_ce: ${DATA_ROOT}/raw/vln_ce"
echo "vln_pe: ${DATA_ROOT}/raw/vln_pe"
echo "---"

watch_one "vln_ce" "${DATA_ROOT}/raw/vln_ce"
watch_one "vln_pe" "${DATA_ROOT}/raw/vln_pe"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] no active InternData download processes"
