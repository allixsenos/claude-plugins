---
name: changelog
description: |
  Show the Claude Code changelog. Use when the user says /redline:changelog,
  "show changelog", "what's new in Claude Code", or "check Claude Code updates".
---

# Claude Code Changelog

## Steps

1. Run these two commands in parallel:
   - Get installed version: `claude --version`
   - Get latest version: `npm view @anthropic-ai/claude-code version`

2. Fetch recent releases from GitHub:
   ```bash
   gh release list --repo anthropics/claude-code --limit 10
   ```

3. If the installed version is behind the latest, highlight that an update is available and show how to update:
   ```bash
   npm update -g @anthropic-ai/claude-code
   ```

4. Show the release notes for releases newer than the currently installed version. For each release, use:
   ```bash
   gh release view <tag> --repo anthropics/claude-code
   ```

   Present the output in a clean, readable format — version as a header, body as-is.

5. If already on the latest version, say so and show notes for the most recent 2-3 releases anyway.
