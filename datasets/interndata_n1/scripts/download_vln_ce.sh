#!/usr/bin/env bash
# InternData-N1 vln_ce: trajectory VLN-CE (R2R + RxR), ~24GB compressed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DATA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${DATA_ROOT}/logs/download_vln_ce.log"
LOCK="${DATA_ROOT}/logs/.hf_staging.lock"
STAGING="${DATA_ROOT}/raw/_hf_staging"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/interndata_hf.sh"

FINAL="$(interndata_vln_ce_dir "$PROJECT_ROOT")"

interndata_load_env "$PROJECT_ROOT"
interndata_check_hf "${HF:-hf}"

interndata_log "$LOG" "=== InternData-N1 vln_ce download start ==="
interndata_log "$LOG" "repo=${INTERNDATA_REPO}  final=${FINAL}"

mkdir -p "${DATA_ROOT}/logs" "${FINAL}/raw_data" "${FINAL}/traj_data"

if [[ -d "${FINAL}/traj_data/r2r" ]] && [[ -n "$(ls -A "${FINAL}/traj_data/r2r" 2>/dev/null)" ]] \
   && [[ -d "${FINAL}/traj_data/rxr" ]] && [[ -n "$(ls -A "${FINAL}/traj_data/rxr" 2>/dev/null)" ]] \
   && [[ -f "${FINAL}/raw_data/r2r/train/train.json.gz" ]]; then
  interndata_log "$LOG" "vln_ce already present, skip HF download"
else
  export INTERNDATA_LOCK_LOG="$LOG"
  interndata_with_lock "$LOCK" bash -c "
    set -euo pipefail
    source '${PROJECT_ROOT}/scripts/lib/interndata_hf.sh'
    interndata_download_hf_includes '${STAGING}' '${LOG}' \
      'vln_ce/raw_data/r2r/**' \
      'vln_ce/raw_data/rxr/**' \
      'vln_ce/traj_data/r2r/**' \
      'vln_ce/traj_data/rxr/**'
    interndata_install_staging_tree '${STAGING}' vln_ce '${DATA_ROOT}/raw' '${LOG}'
  "
fi

interndata_extract_traj_tars "${FINAL}/traj_data/r2r" "$LOG"
interndata_extract_traj_tars "${FINAL}/traj_data/rxr" "$LOG"
interndata_extract_rxr_zip "${FINAL}/raw_data/rxr" "$LOG"

interndata_log "$LOG" "vln_ce ready: $(find "${FINAL}" -type f ! -path '*/_hf_staging/*' | wc -l) files, $(du -sh "${FINAL}" | cut -f1)"
interndata_log "$LOG" "=== InternData-N1 vln_ce download finished ==="
