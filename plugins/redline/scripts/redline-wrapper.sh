#!/bin/bash
link="$HOME/.claude/redline-statusline.sh"
if ! bash "$link" 2>/dev/null; then
  target=$(ls -1t "$HOME/.claude/plugins/cache/allixsenos/redline"/*/scripts/statusline.sh 2>/dev/null | head -1)
  [ -n "$target" ] && ln -sf "$target" "$link" && exec bash "$link"
fi
