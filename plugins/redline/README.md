# redline

Configurable statusline for Claude Code with progress bars, git info, cost tracking, and PS1-style prompt.

## Install

```
/plugin marketplace add allixsenos/claude-plugins
/plugin install redline@allixsenos
/reload-plugins
/redline:setup
```

The setup skill creates a version-resilient wrapper and configures your statusLine setting automatically.

## Skills

- `/redline:setup` — one-time setup after install
- `/redline:config` — interactively change the layout
- `/redline:changelog` — show recent Claude Code release notes

## Features

- PS1-style `user@host:cwd` prompt
- Git branch + compact status flags (S=staged, M=modified, ?=untracked)
- Model name display
- Progress bars for context window, 5h session limit, and 7d weekly limit
  - Color thresholds: green < 60%, yellow >= 60%, red >= 80%
- Rate-limit bars include an in-bar `|` marker showing how far through the
  window you are — usage fill past the marker = burning faster than real time
- Short variants with dark grey brackets (e.g. `[5h 42%]`) flag burning pace
  with a bright red `↑` inside the brackets
- Rate limit reset countdown (e.g. `4h`, `5d`) rounded up to the coarsest
  nonzero unit
- Session cost and lines changed (+/-)
- Fully configurable layout via JSON
- Any number of output lines

## Configuration

Create `~/.claude/statusline-config.json` or use `/redline:config`:

```json
{
  "show_reset_at": 0,
  "burn_threshold": 10,
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
| `show_reset_at` | `0` | Show rate limit reset countdown when usage >= this %. `0` = always, `100` = never. |
| `burn_threshold` | `10` | Percentage-point gap above elapsed time that triggers the `↑` burn icon in `5h_short`/`7d_short`. Only fires once the window is at least 20% elapsed. |

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
| `5h_bar` | 5-hour rate limit: `5h NN% [bar\|with\|marker] countdown`. `\|` shows elapsed-time position |
| `5h_short` | 5-hour rate limit as `[5h NN%]` with `↑` inside when burning hot + countdown |
| `7d_bar` | 7-day rate limit: `7d NN% [bar\|with\|marker] countdown` |
| `7d_short` | 7-day rate limit as `[7d NN%]` with `↑` inside when burning hot + countdown |
| `cost` | Session cost in yellow (e.g. `$0.42`) |
| `lines` | Lines added (green) and removed (red) |
| `update` | Shows bold yellow `↑ claude code A.B.C → X.Y.Z` when the latest on npm is newer than the version running this session. Reads the running version from the statusline's parent process (the Claude Code binary that launched this session — path format `.../versions/X.Y.Z/claude`), not from `claude --version` on PATH. Claude self-updates in the background, so PATH always points at the latest on disk; a long-running session stays on its launch version until you restart it, and this component flags that specifically. Silent when current or when the session binary isn't at a versioned path (e.g. custom installs). npm checked at most once every 4 hours (cached in `/tmp/redline-claude-version`). |

Components can be placed on any line in any order. Omit a component to disable it entirely — no work is done for components not in the config.
