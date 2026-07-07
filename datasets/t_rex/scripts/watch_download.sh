#!/usr/bin/env bash
# 监控 datasets/t_rex 下载进度与网速
set -euo pipefail

DATASET_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${DATASET_ROOT}/raw/trex_dataset"
PROGRESS="${DATASET_ROOT}/logs/download.progress.log"
REPO="zekaiwang/trex_dataset"
EXPECTED="${EXPECTED_FILES:-7903}"
INTERVAL="${INTERVAL_SEC:-15}"

count_files() {
  find "$DEST" -type f ! -path '*/.cache/*' 2>/dev/null | wc -l
}

dir_bytes() {
  du -sb "$DEST" 2>/dev/null | cut -f1
}

is_downloading() {
  pgrep -f "hf download ${REPO}" >/dev/null 2>&1
}

fmt_speed() {
  awk -v bps="$1" 'BEGIN {
    if (bps < 1024) printf "%.0f B/s", bps;
    else if (bps < 1048576) printf "%.1f KB/s", bps/1024;
    else if (bps < 1073741824) printf "%.2f MB/s", bps/1048576;
    else printf "%.2f GB/s", bps/1073741824;
  }'
}

echo "T-Rex | ${DEST}"
echo "日志: ${PROGRESS} | 每 ${INTERVAL}s"
echo "---"

prev_bytes="$(dir_bytes)"
start_bytes="$prev_bytes"
start_ts="$(date +%s)"
first=1

while true; do
  sleep "$INTERVAL"
  now_ts="$(date +%s)"
  curr_bytes="$(dir_bytes)"
  n="$(count_files)"
  sz="$(du -sh "$DEST" 2>/dev/null | cut -f1)"
  pct=$(( n * 100 / EXPECTED ))
  delta=$(( curr_bytes - prev_bytes ))
  inst_bps=$(( delta / INTERVAL ))
  elapsed=$(( now_ts - start_ts ))
  avg_bps=$(( elapsed > 0 ? (curr_bytes - start_bytes) / elapsed : 0 ))
  inst_human="$(fmt_speed "$inst_bps")"
  avg_human="$(fmt_speed "$avg_bps")"
  status="running"
  is_downloading || status="idle/done"
  if (( first )); then
    line="[$(date '+%Y-%m-%d %H:%M:%S')] ${status}  files=${n}/${EXPECTED} (${pct}%)  size=${sz}  speed=—  avg=—"
    first=0
  else
    line="[$(date '+%Y-%m-%d %H:%M:%S')] ${status}  files=${n}/${EXPECTED} (${pct}%)  size=${sz}  speed=${inst_human}  avg=${avg_human}"
  fi
  echo "$line"
  echo "$line" >> "$PROGRESS"
  prev_bytes="$curr_bytes"
  is_downloading || break
done

echo "---"
echo "最新: $(tail -1 "$PROGRESS" 2>/dev/null || echo '无')"
