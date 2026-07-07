#!/usr/bin/env bash
# Shared helpers for VLN-CE downloads (NaVILA-Dataset on HuggingFace).
set -euo pipefail

vln_load_env() {
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
  export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-3600}"
  export HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-3600}"
}

vln_check_hf() {
  local hf="${1:-hf}"
  command -v "$hf" >/dev/null 2>&1 || {
    echo "ERROR: hf CLI not found" >&2
    exit 1
  }
  if ! HF_TOKEN="$HF_TOKEN" "$hf" auth whoami >/dev/null 2>&1; then
    echo "ERROR: HF_TOKEN invalid" >&2
    exit 1
  fi
}

vln_log() {
  local log="$1"
  shift
  mkdir -p "$(dirname "$log")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$log"
}

vln_download_navila_split() {
  # Args: hf_prefix (R2R|RxR), dataset_root, log_file
  local hf_prefix="$1" dataset_root="$2" log="$3"
  local hf="${HF:-hf}"
  local repo="a8cheng/NaVILA-Dataset"
  local staging="${dataset_root}/raw/_hf_staging"
  local raw="${dataset_root}/raw"

  mkdir -p "$staging" "$raw/train" "$(dirname "$log")"

  vln_log "$log" "HF download ${repo} ${hf_prefix}/"
  "$hf" download "$repo" \
    "${hf_prefix}/annotations.json" \
    "${hf_prefix}/train.tar.gz" \
    --repo-type dataset \
    --local-dir "$staging" \
    --token "$HF_TOKEN" \
    2>&1 | tee -a "$log"

  vln_log "$log" "install annotations + extract train.tar.gz"
  cp -f "${staging}/${hf_prefix}/annotations.json" "${raw}/annotations.json"
  tar -xzf "${staging}/${hf_prefix}/train.tar.gz" -C "$raw"
  # NaVILA packs as train/ at archive root
  if [[ ! -d "${raw}/train" ]] && [[ -d "${raw}/${hf_prefix}/train" ]]; then
    mv "${raw}/${hf_prefix}/train" "${raw}/train"
  fi

  vln_log "$log" "raw ready: $(find "$raw" -type f ! -path '*/_hf_staging/*' | wc -l) files, $(du -sh "$raw" | cut -f1)"
}

vln_process_qwenvl_annotations() {
  # Args: hf_prefix (R2R|RxR), dataset_root, log, [starvla_root]
  local hf_prefix="$1" dataset_root="$2" log="$3"
  local starvla_root="${4:-/mnt/data2/wpy/workspace/starVLA}"
  local py_script="${starvla_root}/examples/simBenchmarks/VLN-CE/train_files/annotation_processing.py"
  local processed="${dataset_root}/processed"
  local raw="${dataset_root}/raw"

  mkdir -p "$processed"
  if [[ ! -f "$py_script" ]]; then
    vln_log "$log" "WARN: StarVLA annotation_processing.py not found, skip"
    return 0
  fi

  cp -f "${raw}/annotations.json" "${processed}/annotations_source.json"
  vln_log "$log" "process QwenVL annotations (${hf_prefix})"
  python3 "$py_script" \
    --data_path "${processed}/annotations_source.json" \
    --dataset "$hf_prefix" \
    2>&1 | tee -a "$log"
  if [[ -f "${processed}/annotations.json" ]]; then
    mv -f "${processed}/annotations.json" "${processed}/annotations_qwenvl.json"
  fi
  vln_log "$log" "processed: ${processed}/annotations_qwenvl.json"
}

vln_link_train_entry() {
  local dataset_root="$1"
  mkdir -p "${dataset_root}/train"
  ln -sfn "../raw/train" "${dataset_root}/train/images"
  if [[ -f "${dataset_root}/processed/annotations_qwenvl.json" ]]; then
    ln -sfn "../processed/annotations_qwenvl.json" "${dataset_root}/train/annotations_qwenvl.json"
  else
    ln -sfn "../raw/annotations.json" "${dataset_root}/train/annotations.json"
  fi
}
