#!/bin/bash
base="$HOME/.claude/plugins/cache/allixsenos/redline"
target=$(ls -1d "$base"/*/scripts/statusline.sh 2>/dev/null | sort -t/ -k9 -V | tail -1)
[ -n "$target" ] && exec bash "$target"
