#!/usr/bin/env bash
# git-pr-whip — PostToolUse hook that injects PR hygiene reminders after git commits.
#
# Fires after any `git commit` (including --amend). Emits `additionalContext` JSON
# on stdout so Claude Code feeds the reminder into the model's context (invisible
# to the user). Silent on any non-commit Bash call.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only Bash commands are in scope
[[ "$TOOL_NAME" == "Bash" ]] || exit 0
[[ -n "$COMMAND" ]] || exit 0

# --- Sanitize command to detect `git commit` without false positives ---
# Same approach as git-governor: strip heredocs, quoted strings, unwrap
# subshells, and normalize git global flags so patterns match reliably.

SCAN="$COMMAND"

# Collapse line continuations so "git commit \<nl>-m ..." matches
SCAN=$(printf '%s' "$SCAN" | perl -pe 's/\\\n\s*/ /g' 2>/dev/null || printf '%s' "$COMMAND")

# Strip heredoc bodies so a commit message that mentions "git commit" doesn't trigger
if printf '%s' "$SCAN" | grep -q '<<'; then
  STRIPPED=$(printf '%s' "$SCAN" | perl -0777 -pe "s/<<~?'?(\w+)'?\s*\n.*?\n\1\b//gs" 2>/dev/null) && SCAN="$STRIPPED"
fi

# Strip quoted strings (commit message bodies, etc.)
SCAN=$(printf '%s' "$SCAN" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g')

# Unwrap $(...) and `...` so "$(echo git) commit" still matches
SCAN=$(printf '%s' "$SCAN" | sed 's/\$(\([^)]*\))/\1/g' | sed 's/`\([^`]*\)`/\1/g')

# Normalize git global flags: "git -C /path commit" -> "git commit"
SCAN=$(printf '%s' "$SCAN" | perl -pe 's/\bgit\s+(?:(?:-[Cc]|--git-dir|--work-tree)(?:=\S+|\s+\S+)\s+)*/git /g')

# Detect any git commit invocation (plain, --amend, -m, --fixup, etc.)
if ! printf '%s' "$SCAN" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# --- Emit additionalContext for Claude ---

REMINDER="PR hygiene reminder (git-pr-whip plugin):
1. If this commit is meant to update an existing PR, before pushing run \`gh pr view --json state,url\` for that branch. If the PR state is MERGED or CLOSED, the branch is stale — pull the latest default branch, create a new branch from it, and open a fresh PR instead of pushing to the old one.
2. If this commit addresses PR review feedback from other users or agents, post one recap comment on the PR summarizing which suggestions you accepted vs. dismissed, with a one-line reason for each dismissal — so reviewers don't have to reconstruct it from the diff."

jq -n --arg ctx "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'

exit 0
