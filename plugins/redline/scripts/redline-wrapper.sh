#!/bin/bash
base="$HOME/.claude/plugins/cache/allixsenos/redline"
target=$(ls -1d "$base"/*/scripts/statusline.sh 2>/dev/null | sort -t/ -k9 -V | tail -1)
if [ -z "$target" ]; then
  printf '\033[1;31mredline: plugin not found in %s\033[0m \033[90m— reinstall redline@allixsenos\033[0m' "$base"
  exit 0
fi
exec bash "$target"
