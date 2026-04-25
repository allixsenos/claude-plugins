---
name: changelog
description: |
  Show the Claude Code changelog. Use when the user says /redline:changelog,
  "show changelog", "what's new in Claude Code", or "check Claude Code updates".
---

# Claude Code Changelog

## Steps

1. Detect the running session's Claude Code version, NOT the version on PATH.
   `claude --version` is unreliable here because Claude Code self-updates in the
   background — PATH almost always points at the latest release on disk, even
   when this session is still running an older binary. The whole point of this
   command is "what release notes apply to me right now," so we have to read
   the version from the actual session process.

   Walk up the parent process tree from this Bash subprocess until we hit a
   binary at `.../versions/X.Y.Z/claude` (Claude Code's self-update layout):

   ```bash
   pid=$PPID
   for d in 1 2 3 4 5; do
     if [ -r "/proc/$pid/exe" ]; then
       exe=$(readlink "/proc/$pid/exe" 2>/dev/null)
     else
       exe=$(lsof -a -p "$pid" -d txt 2>/dev/null | awk 'NR>1 {print $NF; exit}')
     fi
     installed=$(printf '%s' "$exe" | grep -oE 'versions/[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d/ -f2)
     [ -n "$installed" ] && break
     pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
     { [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ]; } && break
   done
   echo "session version: ${installed:-unknown}"
   ```

   If the walk returns nothing (e.g. custom install not at a versioned path),
   fall back to `claude --version` and note in the output that this is the
   PATH version, not necessarily what this session is running.

2. Get the latest published version: `npm view @anthropic-ai/claude-code version`

3. Fetch recent releases from GitHub:
   ```bash
   gh release list --repo anthropics/claude-code --limit 10
   ```

4. If the session version is behind the latest, highlight that **restarting
   the session** will pick up the newer binary (Claude Code self-updates on
   disk in the background, so you usually don't need to run `npm update` —
   just exit and relaunch). Only suggest `npm update -g @anthropic-ai/claude-code`
   if the on-disk version is also behind, which the user can check with
   `claude --version`.

5. Show the release notes for releases newer than the session version. For each release, use:
   ```bash
   gh release view <tag> --repo anthropics/claude-code
   ```

   Present the output in a clean, readable format — version as a header, body as-is.

6. If the session is already on the latest version, say so and show notes for the most recent 2-3 releases anyway.
