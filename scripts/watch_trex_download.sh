#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/datasets/t_rex/scripts/watch_download.sh" "$@"
