#!/usr/bin/env bash
# InternData-N1 vln_pe: humanoid indoor VLN-PE (R2R + interiornav), ~95GB.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DATA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${DATA_ROOT}/logs/download_vln_pe.log"
LOCK="${DATA_ROOT}/logs/.hf_staging.lock"
STAGING="${DATA_ROOT}/raw/_hf_staging"
FINAL="${DATA_ROOT}/raw/vln_pe"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/interndata_hf.sh"

interndata_load_env "$PROJECT_ROOT"
interndata_check_hf "${HF:-hf}"

interndata_log "$LOG" "=== InternData-N1 vln_pe download start ==="
interndata_log "$LOG" "repo=${INTERNDATA_REPO}  final=${FINAL}"

mkdir -p "${DATA_ROOT}/logs" "${FINAL}"

if [[ -d "${FINAL}/traj_data" ]] && [[ -n "$(ls -A "${FINAL}/traj_data" 2>/dev/null)" ]]; then
  interndata_log "$LOG" "vln_pe traj_data already present, skip HF download"
else
  export INTERNDATA_LOCK_LOG="$LOG"
  interndata_with_lock "$LOCK" bash -c "
    set -euo pipefail
    source '${PROJECT_ROOT}/scripts/lib/interndata_hf.sh'
    interndata_download_hf_includes '${STAGING}' '${LOG}' \
      'vln_pe/raw_data/r2r/**' \
      'vln_pe/traj_data/r2r/**' \
      'vln_pe/traj_data/interiornav/**'
    interndata_install_staging_tree '${STAGING}' vln_pe '${DATA_ROOT}/raw' '${LOG}'
  "
fi

# interiornav scenes ship as tar.gz
if [[ -d "${FINAL}/traj_data/interiornav" ]]; then
  interndata_extract_traj_tars "${FINAL}/traj_data/interiornav" "$LOG"
fi
if [[ -d "${FINAL}/traj_data/r2r" ]]; then
  interndata_extract_traj_tars "${FINAL}/traj_data/r2r" "$LOG"
fi

interndata_log "$LOG" "vln_pe ready: $(find "${FINAL}" -type f ! -path '*/_hf_staging/*' | wc -l) files, $(du -sh "${FINAL}" | cut -f1)"
interndata_log "$LOG" "=== InternData-N1 vln_pe download finished ==="
