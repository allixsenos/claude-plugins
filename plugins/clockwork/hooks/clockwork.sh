#!/bin/bash
# Clockwork — inject current time into Claude's context every 10 minutes.
# Prevents temporal disorientation in long sessions.

STAMP_FILE="/tmp/claude-clockwork.stamp"
INTERVAL=600 # 10 minutes

NOW=$(date +%s)
LAST=0
[ -f "$STAMP_FILE" ] && LAST=$(cat "$STAMP_FILE")
DIFF=$((NOW - LAST))

if [ "$DIFF" -ge "$INTERVAL" ]; then
  echo "$NOW" > "$STAMP_FILE"
  TIME=$(date '+%A, %Y-%m-%d %H:%M %Z')
  echo "{\"hookSpecificOutput\":{\"claudeOutput\":\"Current time: ${TIME}\"}}"
fi
