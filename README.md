# allixsenos Claude Code plugins & skills

A collection of plugins and standalone skills for Claude Code.

## Setup

**Plugins** (hooks + skills — need the plugin system):
```
/plugin marketplace add allixsenos/claude-plugins
```

**Standalone skills** (no hooks, works everywhere):
```
npx skills add allixsenos/claude-plugins
```

Use `--list` to see available skills, `--skill <name>` to install a specific one.

## Plugins

Plugins include hooks that run automatically — they need `/plugin install`.

| Plugin | Description | Install |
|--------|-------------|---------|
| [git-governor](plugins/git-governor/) | Git governance via PreToolUse hooks — block or prompt on amends, force pushes, protected branches | `/plugin install git-governor@allixsenos` |
| [redline](plugins/redline/) | Configurable statusline with progress bars, git info, cost tracking | `/plugin install redline@allixsenos` |
| [clockwork](plugins/clockwork/) | Periodic time injection so Claude knows what day and time it is | `/plugin install clockwork@allixsenos` |

## Skills

Standalone skills — pure knowledge, no hooks. Install via `npx skills add` or copy the SKILL.md into your project's `.claude/skills/`.

| Skill | Description | Install |
|-------|-------------|---------|
| [nano-banana](skills/nano-banana/) | Image generation and editing via Gemini API (Nano Banana models) | `npx skills add allixsenos/claude-plugins --skill nano-banana` |
| [openrouter-imagegen](skills/openrouter-imagegen/) | Image generation via OpenRouter's unified API with runtime model discovery | `npx skills add allixsenos/claude-plugins --skill openrouter-imagegen` |
| [linkedin-data-portability](skills/linkedin-data-portability/) | Export LinkedIn member data (connections, profile, messages, etc.) via the DMA Data Portability API | `npx skills add allixsenos/claude-plugins --skill linkedin-data-portability` |
