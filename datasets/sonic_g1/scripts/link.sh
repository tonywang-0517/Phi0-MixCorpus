#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "${PROJECT_ROOT}/scripts/setup_dataset_links.sh" --dataset "sonic_g1"
