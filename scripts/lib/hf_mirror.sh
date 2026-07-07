#!/usr/bin/env bash
# HuggingFace 镜像下载（curl -L；LFS 会 308 跳转到 huggingface.co，-L 可跟随）
set -euo pipefail

hf_mirror_load_env() {
  local project_root="$1"
  if [[ -f "${project_root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${project_root}/.env"
    set +a
  fi
  HF_MIRROR_BASE="${HF_ENDPOINT:-https://hf-mirror.com}"
  HF_MIRROR_BASE="${HF_MIRROR_BASE%/}"
  export HF_MIRROR_BASE
}

hf_mirror_log() {
  local log="$1"
  shift
  mkdir -p "$(dirname "$log")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$log"
}

hf_mirror_url() {
  # Args: repo_type(dataset|models) repo_id relpath
  local repo_type="$1" repo="$2" relpath="$3"
  local segment="$repo_type"
  if [[ "$repo_type" == "dataset" ]]; then
    segment="datasets"
  elif [[ "$repo_type" == "model" ]]; then
    segment="models"
  fi
  echo "${HF_MIRROR_BASE}/${segment}/${repo}/resolve/main/${relpath}"
}

hf_mirror_download_file() {
  # Args: repo_type repo relpath dest log
  local repo_type="$1" repo="$2" relpath="$3" dest="$4" log="$5"
  local url tmp

  url="$(hf_mirror_url "$repo_type" "$repo" "$relpath")"
  mkdir -p "$(dirname "$dest")"

  if [[ -s "$dest" ]]; then
    hf_mirror_log "$log" "skip (exists): ${repo}/${relpath}"
    return 0
  fi

  hf_mirror_log "$log" "GET ${url}"
  tmp="${dest}.part"
  rm -f "$tmp"

  local curl_args=(-fSL --retry 8 --retry-delay 15 --connect-timeout 30 --max-time 0 -C -)
  if [[ -n "${HF_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi

  if curl "${curl_args[@]}" -o "$tmp" "$url" 2>&1 | tee -a "$log"; then
    mv -f "$tmp" "$dest"
    hf_mirror_log "$log" "ok ${dest} ($(du -h "$dest" | cut -f1))"
  else
    rm -f "$tmp"
    hf_mirror_log "$log" "ERROR: failed ${repo}/${relpath}"
    return 1
  fi
}

hf_mirror_download_repo_files() {
  # Args: repo_type repo dest_root log relpath1 relpath2 ...
  local repo_type="$1" repo="$2" dest_root="$3" log="$4"
  shift 4
  local relpath dest failed=0
  for relpath in "$@"; do
    dest="${dest_root}/${relpath}"
    if ! hf_mirror_download_file "$repo_type" "$repo" "$relpath" "$dest" "$log"; then
      failed=$((failed + 1))
    fi
  done
  return $(( failed > 0 ? 1 : 0 ))
}
