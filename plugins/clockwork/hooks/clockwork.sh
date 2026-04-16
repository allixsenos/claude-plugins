#!/bin/bash
# Clockwork — inject current time into Claude's context every 10 minutes.
# Prevents temporal disorientation in long sessions.
# Per-session stamp file so multiple sessions each get their own clock.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || SESSION_ID=""
SESSION_ID="${SESSION_ID:-no-session-id}"

STAMP_FILE="/tmp/claude-clockwork-${SESSION_ID}.stamp"
INTERVAL=600 # 10 minutes

NOW=$(date +%s)
LAST=0
[ -f "$STAMP_FILE" ] && LAST=$(cat "$STAMP_FILE")
DIFF=$((NOW - LAST))

if [ "$DIFF" -ge "$INTERVAL" ]; then
  echo "$NOW" > "$STAMP_FILE"
  TIME=$(date '+%A, %Y-%m-%d %H:%M %Z')
  # Tag identifies the source of this injection so the user (and Claude) can
  # tell where it came from weeks later, without burning extra context tokens.
  echo "Current time: ${TIME} (clockwork plugin)"
fi
exit 0
