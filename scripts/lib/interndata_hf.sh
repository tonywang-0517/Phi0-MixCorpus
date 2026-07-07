#!/usr/bin/env bash
# Shared helpers for InternData-N1 (trajectory VLN-CE / VLN-PE) downloads.
set -euo pipefail

INTERNDATA_REPO="InternRobotics/InternData-N1"

interndata_load_env() {
  local project_root="$1"
  if [[ -f "${project_root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${project_root}/.env"
    set +a
  fi
  : "${HF_TOKEN:?HF_TOKEN missing in ${project_root}/.env}"
  unset HF_ENDPOINT HUGGINGFACE_HUB_ENDPOINT HF_HUB_ENDPOINT
  export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
  export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-7200}"
  export HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-7200}"
}

interndata_check_hf() {
  local hf="${1:-hf}"
  command -v "$hf" >/dev/null 2>&1 || {
    echo "ERROR: hf CLI not found" >&2
    exit 1
  }
  if ! HF_TOKEN="$HF_TOKEN" "$hf" auth whoami >/dev/null 2>&1; then
    echo "ERROR: HF_TOKEN invalid (InternData-N1 is gated — accept license on HF first)" >&2
    exit 1
  fi
}

interndata_log() {
  local log="$1"
  shift
  mkdir -p "$(dirname "$log")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$log"
}

interndata_root() {
  local project_root="$1"
  echo "${project_root}/datasets/interndata_n1"
}

interndata_vln_ce_dir() {
  echo "$(interndata_root "$1")/raw/vln_ce"
}

interndata_vln_pe_dir() {
  echo "$(interndata_root "$1")/raw/vln_pe"
}

interndata_download_hf_includes() {
  # Args: staging_dir log_file include_glob1 include_glob2 ...
  # hf CLI treats positional paths as files; directories need --include globs.
  local staging="$1" log="$2"
  shift 2
  local hf="${HF:-hf}"
  local -a args=()

  interndata_log "$log" "HF download ${INTERNDATA_REPO} includes: $*"
  mkdir -p "$staging"
  for pat in "$@"; do
    args+=(--include "$pat")
  done
  "$hf" download "$INTERNDATA_REPO" \
    "${args[@]}" \
    --repo-type dataset \
    --local-dir "$staging" \
    --token "$HF_TOKEN" \
    2>&1 | tee -a "$log"
}

interndata_install_staging_tree() {
  # Copy vln_ce or vln_pe subtree from staging into final raw dir.
  local staging="$1" component="$2" final_root="$3" log="$4"
  local src="${staging}/${component}"
  local dst="${final_root}/${component}"

  if [[ ! -d "$src" ]]; then
    interndata_log "$log" "ERROR: missing staged ${component}/"
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$dst" ]]; then
    rsync -a "$src/" "$dst/"
  else
    cp -a "$src" "$dst"
  fi
  interndata_log "$log" "installed ${component}/ → ${dst}"
}

interndata_extract_traj_tars() {
  # Extract scene tarballs under traj_data/{split}/; keep .tar.gz for resume.
  local traj_split_dir="$1" log="$2"
  local tar scene extracted=0 skipped=0

  [[ -d "$traj_split_dir" ]] || return 0

  shopt -s nullglob
  for tar in "${traj_split_dir}"/*.tar.gz; do
    scene="$(basename "$tar" .tar.gz)"
    if [[ -d "${traj_split_dir}/${scene}" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    interndata_log "$log" "extract ${tar} → ${traj_split_dir}/${scene}/"
    tar -xzf "$tar" -C "$traj_split_dir"
    extracted=$((extracted + 1))
  done
  shopt -u nullglob
  interndata_log "$log" "tar extract done: new=${extracted} already=${skipped} in ${traj_split_dir}"
}

interndata_extract_rxr_zip() {
  local rxr_raw_dir="$1" log="$2"
  local zip="${rxr_raw_dir}/rxr.zip"
  local marker="${rxr_raw_dir}/.rxr_zip_extracted"

  [[ -f "$zip" ]] || return 0
  if [[ -f "$marker" ]]; then
    interndata_log "$log" "rxr.zip already extracted"
    return 0
  fi
  interndata_log "$log" "extract ${zip}"
  unzip -q -o "$zip" -d "$rxr_raw_dir"
  touch "$marker"
}

interndata_with_lock() {
  local lock_file="$1"
  shift
  mkdir -p "$(dirname "$lock_file")"
  exec 9>"$lock_file"
  if ! flock -n 9; then
    interndata_log "${INTERNDATA_LOCK_LOG:-/dev/stderr}" "waiting for lock: $lock_file"
    flock 9
  fi
  "$@"
}
