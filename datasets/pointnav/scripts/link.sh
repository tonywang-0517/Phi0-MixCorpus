#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/../../.." && pwd)/scripts/setup_dataset_links.sh" --dataset "pointnav"
