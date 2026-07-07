#!/usr/bin/env bash
# 将服务器上已下载的数据挂载到 Phi0-MixCorpus/datasets/<id>/ 下。
# 大体量用软链；小切片复制到 slices/ 便于离线分析。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${ROOT}/datasets"

WPY="/mnt/data2/wpy/workspace"
EFS="/mnt/efs_1"

link() {
  local dest="$1" src="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" ]]; then
    rm -rf "$dest"
  fi
  ln -sfn "$src" "$dest"
  echo "  link  $dest -> $src"
}

copy_tree() {
  local dest="$1" src="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" ]]; then
    rm -rf "$dest"
  fi
  cp -a "$src" "$dest"
  echo "  copy  $dest <- $src"
}

copy_files() {
  local dest_dir="$1"
  shift
  mkdir -p "$dest_dir"
  for src in "$@"; do
    cp -a "$src" "${dest_dir}/$(basename "$src")"
    echo "  copy  ${dest_dir}/$(basename "$src") <- $src"
  done
}

ensure_dirs() {
  local id="$1"
  mkdir -p "${DATA}/${id}"/{raw,processed,slices,train,scripts,logs}
}

log_link() {
  local id="$1"
  shift
  mkdir -p "${DATA}/${id}/logs"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${DATA}/${id}/logs/link.log"
}

ONLY_IDS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset) ONLY_IDS+=("$2"); shift 2 ;;
    *) shift ;;
  esac
done

should_run() {
  [[ ${#ONLY_IDS[@]} -eq 0 ]] && return 0
  local id="$1" x
  for x in "${ONLY_IDS[@]}"; do
    [[ "$x" == "$id" ]] && return 0
  done
  return 1
}

if should_run egodex; then
echo "=== egodex ==="
log_link egodex "=== link start ==="
ensure_dirs egodex
link "${DATA}/egodex/raw/egodex_dex_ziyi"        "${EFS}/ziyi/egodex_dex"
link "${DATA}/egodex/raw/egodex_dex_wam"         "${EFS}/wam/egodex_dex"
link "${DATA}/egodex/raw/egoverse_full"          "${EFS}/ego_dataset/egoverse_full"
link "${DATA}/egodex/raw/demo_hf"                "${WPY}/Isaac-GR00T/demo_data/egodex"
link "${DATA}/egodex/processed/demo_smplh"       "${WPY}/Isaac-GR00T/demo_data/egodex/test/add_remove_lid"
copy_tree "${DATA}/egodex/slices/demo_add_remove_lid" \
  "${WPY}/Isaac-GR00T/demo_data/egodex/test/add_remove_lid"
link "${DATA}/egodex/train/demo_add_remove_lid"  "${DATA}/egodex/slices/demo_add_remove_lid"
log_link egodex "=== link done ==="
fi

if should_run humanoid_everyday; then
echo "=== humanoid_everyday ==="
log_link humanoid_everyday "=== link start ==="
ensure_dirs humanoid_everyday
HE="${WPY}/GR00T-WholeBodyControl/experiments/sonic_vla_overfit/data"
link "${DATA}/humanoid_everyday/raw/hf_slices"           "${HE}/humanoid_everyday_raw"
link "${DATA}/humanoid_everyday/processed/meta"          "${HE}/humanoid_everyday_meta"
link "${DATA}/humanoid_everyday/processed/he_g1_hand"    "${HE}/he_g1_hand_slices"
link "${DATA}/humanoid_everyday/processed/he_kettle_one" "${HE}/he_kettle_one_ep"
link "${DATA}/humanoid_everyday/processed/walk_one_ep"   "${HE}/walk_one_ep"
copy_tree "${DATA}/humanoid_everyday/slices/he_kettle_one_ep" "${HE}/he_kettle_one_ep"
copy_tree "${DATA}/humanoid_everyday/slices/walk_one_ep"      "${HE}/walk_one_ep"
link "${DATA}/humanoid_everyday/train/he_kettle_one_ep" "${DATA}/humanoid_everyday/slices/he_kettle_one_ep"
log_link humanoid_everyday "=== link done ==="
fi

if should_run bone_seed; then
echo "=== bone_seed ==="
log_link bone_seed "=== link start ==="
ensure_dirs bone_seed
PM="${WPY}/ProtoMotions-main/data"
link "${DATA}/bone_seed/raw/bones_studio_seed"     "${PM}/external/bones_seed"
link "${DATA}/bone_seed/processed/protomotions_g1" "${PM}/processed/bones_seed"
link "${DATA}/bone_seed/slices/sonic_vla_sample"   "${WPY}/GR00T-WholeBodyControl/experiments/sonic_vla_overfit/data/SONIC-VLA-BonesSeed"
copy_tree "${DATA}/bone_seed/slices/sonic_vla_sample_copy" \
  "${WPY}/GR00T-WholeBodyControl/experiments/sonic_vla_overfit/data/SONIC-VLA-BonesSeed"
link "${DATA}/bone_seed/train/protomotions_g1" "${DATA}/bone_seed/processed/protomotions_g1"
log_link bone_seed "=== link done ==="
fi

if should_run phuma; then
echo "=== phuma ==="
log_link phuma "=== link start ==="
ensure_dirs phuma
PM="${WPY}/ProtoMotions-main/data"
link "${DATA}/phuma/raw/hf_phuma"              "${PM}/external/phuma"
link "${DATA}/phuma/raw/phuma_upstream"        "${PM}/external/phuma-upstream"
link "${DATA}/phuma/processed/protomotions_g1" "${PM}/processed/phuma"
link "${DATA}/phuma/train/protomotions_g1"     "${DATA}/phuma/processed/protomotions_g1"
log_link phuma "=== link done ==="
fi

if should_run xperience; then
echo "=== xperience ==="
log_link xperience "=== link start ==="
ensure_dirs xperience
XP_DEMO="${WPY}/Isaac-GR00T/demo_data/xperience-10m-sample"
XP_DATA="${WPY}/Isaac-GR00T/data"
link "${DATA}/xperience/raw/xperience_10m_sample"              "${XP_DEMO}"
link "${DATA}/xperience/processed/pick_tissue_xperience_unified"       "${XP_DATA}/pick_tissue_xperience_unified"
link "${DATA}/xperience/processed/pick_tissue_valid_xperience_unified"   "${XP_DATA}/pick_tissue_valid_xperience_unified"
link "${DATA}/xperience/processed/pick_yellow_box_xperience_unified"     "${XP_DATA}/pick_yellow_box_xperience_unified"
copy_files "${DATA}/xperience/slices/xperience_10m_sample" \
  "${XP_DEMO}/annotation.hdf5" \
  "${XP_DEMO}/stereo_left.mp4" \
  "${XP_DEMO}/stereo_right.mp4" \
  "${XP_DEMO}/README.md"
copy_tree "${DATA}/xperience/slices/pick_yellow_box_xperience_unified" \
  "${XP_DATA}/pick_yellow_box_xperience_unified"
link "${DATA}/xperience/train/xperience_10m_sample" \
  "${DATA}/xperience/slices/xperience_10m_sample"
link "${DATA}/xperience/train/pick_tissue_xperience_unified" \
  "${DATA}/xperience/processed/pick_tissue_xperience_unified"
log_link xperience "=== link done ==="
fi

if should_run sonic_g1; then
echo "=== sonic_g1 ==="
log_link sonic_g1 "=== link start ==="
ensure_dirs sonic_g1
IG="${WPY}/Isaac-GR00T/data"
link "${DATA}/sonic_g1/raw/collections"                    "${IG}"
link "${DATA}/sonic_g1/processed/g1_manip_sonic_unified"   "${IG}/g1_manip_sonic_unified"
link "${DATA}/sonic_g1/processed/g1_manip_valid"         "${IG}/g1_manip_valid"
link "${DATA}/sonic_g1/processed/pick_tissue_sonic_unified" "${IG}/pick_tissue_sonic_unified"
link "${DATA}/sonic_g1/processed/pick_yellow_box_sonic_unified" "${IG}/pick_yellow_box_sonic_unified"
link "${DATA}/sonic_g1/processed/pick_tissue_valid"        "${IG}/pick_tissue_valid"
link "${DATA}/sonic_g1/slices/pick_yellow_box_sonic_unified" "${IG}/pick_yellow_box_sonic_unified"
link "${DATA}/sonic_g1/train/g1_manip_sonic_unified"       "${DATA}/sonic_g1/processed/g1_manip_sonic_unified"
log_link sonic_g1 "=== link done ==="
fi

if should_run t_rex; then
echo "=== t_rex ==="
log_link t_rex "=== link start ==="
ensure_dirs t_rex
TREX_RAW="${DATA}/t_rex/raw/trex_dataset"
if [[ -d "${TREX_RAW}/meta" ]]; then
  link "${DATA}/t_rex/train/trex_dataset" "${TREX_RAW}"
  if [[ -f "${TREX_RAW}/episodes_preview.parquet" ]]; then
    copy_files "${DATA}/t_rex/slices" "${TREX_RAW}/episodes_preview.parquet"
  fi
else
  touch "${DATA}/t_rex/raw/.gitkeep" "${DATA}/t_rex/processed/.gitkeep" \
        "${DATA}/t_rex/slices/.gitkeep" "${DATA}/t_rex/train/.gitkeep"
fi
log_link t_rex "=== link done ==="
fi

if should_run interndata_n1; then
echo "=== interndata_n1 (VLN-CE + VLN-PE) ==="
log_link interndata_n1 "=== link start ==="
ensure_dirs interndata_n1
mkdir -p "${DATA}/interndata_n1/raw/vln_ce"/{raw_data,traj_data} \
         "${DATA}/interndata_n1/raw/vln_pe"/{raw_data,traj_data}
touch "${DATA}/interndata_n1/raw/.gitkeep" \
      "${DATA}/interndata_n1/processed/.gitkeep" \
      "${DATA}/interndata_n1/slices/.gitkeep" \
      "${DATA}/interndata_n1/train/.gitkeep"
log_link interndata_n1 "data root: ${DATA}/interndata_n1/raw"
log_link interndata_n1 "=== link done ==="
fi

if should_run pointnav; then
echo "=== pointnav (optional HF) ==="
log_link pointnav "=== link start ==="
ensure_dirs pointnav
if [[ -d "${DATA}/pointnav/raw/hm3d_minival_episodes" ]]; then
  mkdir -p "${DATA}/pointnav/train"
  ln -sfn "../raw/hm3d_minival_episodes" "${DATA}/pointnav/train/hm3d_minival_episodes"
else
  touch "${DATA}/pointnav/raw/.gitkeep" "${DATA}/pointnav/processed/.gitkeep" \
        "${DATA}/pointnav/slices/.gitkeep" "${DATA}/pointnav/train/.gitkeep"
fi
log_link pointnav "=== link done ==="
fi

echo ""
echo "Done. Dataset root: ${DATA}"
