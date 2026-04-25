---
name: setup
description: |
  Initial setup for the redline statusline plugin. Use when the user says
  /redline:setup, "set up redline", or "install redline statusline". Creates
  the wrapper script and statusLine setting. Run once after install.
---

# Redline Setup

Install the redline statusline by running these steps:

## 1. Copy the wrapper script to a stable location

```bash
wrapper_src=$(ls -1d "$HOME/.claude/plugins/cache/allixsenos/redline"/*/scripts/redline-wrapper.sh 2>/dev/null | sort -t/ -k9 -V | tail -1)
if [ -n "$wrapper_src" ]; then
  cp "$wrapper_src" "$HOME/.claude/redline-wrapper.sh"
  chmod +x "$HOME/.claude/redline-wrapper.sh"
  echo "Installed wrapper: $HOME/.claude/redline-wrapper.sh"
else
  echo "ERROR: wrapper script not found in plugin cache."
fi
```

## 2. Set the statusLine in settings.json

Read `~/.claude/settings.json`, set `statusLine` to:

```json
{
  "type": "command",
  "command": "bash ~/.claude/redline-wrapper.sh"
}
```

Use the Edit tool to update `~/.claude/settings.json`. If a `statusLine` key already exists, replace it. If not, add it.

## 3. Confirm

Tell the user setup is complete and the statusline will appear after the next assistant response. To customize the layout, run `/redline:configure`.
