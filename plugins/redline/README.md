# redline

Configurable statusline for Claude Code with progress bars, git info, cost tracking, and PS1-style prompt.

## Install

```
/plugin marketplace add allixsenos/claude-plugins
/plugin install redline@allixsenos
/reload-plugins
/redline:init
```

The init skill creates a version-resilient wrapper and configures your statusLine setting automatically.

## Skills

- `/redline:init` — one-time setup after install
- `/redline:config` — interactively change the layout
- `/redline:changelog` — show recent Claude Code release notes

## Features

- PS1-style `user@host:cwd` prompt
- Git branch + compact status flags (S=staged, M=modified, ?=untracked)
- Model name display
- Progress bars for context window, 5h session limit, and 7d weekly limit
  - Percentage rendered inline inside the bar
  - Color thresholds: green < 60%, yellow >= 60%, red >= 80%
- Short text variants with dark grey brackets (e.g. `[5h 42%]`)
- Rate limit reset countdown (e.g. `2h31m`) — shown when usage exceeds threshold
- Session cost and lines changed (+/-)
- Fully configurable layout via JSON
- Any number of output lines

## Configuration

Create `~/.claude/statusline-config.json` or use `/redline:config`:

```json
{
  "show_reset_at": 70,
  "lines": [
    ["ps1", "git", "update"],
    ["model", "ctx_short", "5h_short", "7d_short", "cost", "lines"]
  ]
}
```

Override config path with the `CLAUDE_STATUSLINE_CONFIG` env var.

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `show_reset_at` | `70` | Show rate limit reset countdown when usage >= this %. `0` = always, `100` = never. |

### Available components

| Component | Description |
|-----------|-------------|
| `ps1` | Bold green user@host, colon, bold blue working directory |
| `user` | Bold green username |
| `host_short` | Bold green short hostname |
| `host_long` | Bold green FQDN hostname |
| `cwd` | Bold blue working directory |
| `git` | Yellow branch name + red status flags |
| `model` | Cyan model display name |
| `ctx_bar` | Context window usage as a 10-step progress bar |
| `ctx_short` | Context window usage as colored text in brackets |
| `5h_bar` | 5-hour session rate limit as a progress bar + reset countdown |
| `5h_short` | 5-hour rate limit as colored text in brackets + reset countdown |
| `7d_bar` | 7-day weekly rate limit as a progress bar + reset countdown |
| `7d_short` | 7-day rate limit as colored text in brackets + reset countdown |
| `cost` | Session cost in yellow (e.g. `$0.42`) |
| `lines` | Lines added (green) and removed (red) |
| `update` | Shows bold yellow `↑ X.Y.Z` when a newer Claude Code version is available. Checks npm at most once every 4 hours (cached in `/tmp/redline-claude-version`). Silent when up to date. |

Components can be placed on any line in any order. Omit a component to disable it entirely — no work is done for components not in the config.
