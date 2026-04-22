#!/usr/bin/env bash
# git-pr-whip — PreToolUse hook that blocks `git commit` and `git push` from
# being chained in a single Bash call.
#
# Rationale: the PostToolUse reminder on `git commit` injects guidance (is the
# PR still open? scope grown? review-feedback recap needed?) that can only
# influence Claude's next decision if there IS a next decision. When Claude
# writes `git commit && git push`, the push has already been committed to by
# the shell by the time the PostToolUse hook fires — the reminder arrives
# after the fact. Blocking the chain forces a second Bash call, at which
# point the reminder is in context.
#
# Detection: if the sanitized command contains BOTH `git commit` and
# `git push` (in any order, separated by anything), deny. Standalone commits
# or pushes pass through.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

[[ "$TOOL_NAME" == "Bash" ]] || exit 0
[[ -n "$COMMAND" ]] || exit 0

# --- Sanitize (same approach as git-governor and git-pr-whip.sh) ---

SCAN="$COMMAND"

# Collapse line continuations
SCAN=$(printf '%s' "$SCAN" | perl -pe 's/\\\n\s*/ /g' 2>/dev/null || printf '%s' "$COMMAND")

# Strip heredoc bodies so a commit message containing "git push" doesn't match
if printf '%s' "$SCAN" | grep -q '<<'; then
  STRIPPED=$(printf '%s' "$SCAN" | perl -0777 -pe "s/<<~?'?(\w+)'?\s*\n.*?\n\1\b//gs" 2>/dev/null) && SCAN="$STRIPPED"
fi

# Strip quoted strings (commit messages, echoed strings)
SCAN=$(printf '%s' "$SCAN" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g')

# Unwrap $(...) and `...`
SCAN=$(printf '%s' "$SCAN" | sed 's/\$(\([^)]*\))/\1/g' | sed 's/`\([^`]*\)`/\1/g')

# Normalize git global flags
SCAN=$(printf '%s' "$SCAN" | perl -pe 's/\bgit\s+(?:(?:-[Cc]|--git-dir|--work-tree)(?:=\S+|\s+\S+)\s+)*/git /g')

# --- Dispatch: block only when BOTH commit and push appear in one call ---

if printf '%s' "$SCAN" | grep -qE '\bgit\s+commit\b' \
   && printf '%s' "$SCAN" | grep -qE '\bgit\s+push\b'; then
  REASON="git-pr-whip: chaining \`git commit\` with \`git push\` in a single Bash call is blocked. The post-commit PR-hygiene reminder (is the PR still open? has the scope drifted? etc.) only lands in context AFTER the tool call finishes — if you've already chained the push, the reminder can't change the outcome. Run them as separate Bash calls: commit first, read the reminder, then decide whether to push."
  jq -n --arg reason "$REASON" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

exit 0
