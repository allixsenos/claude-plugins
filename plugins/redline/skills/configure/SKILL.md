---
name: configure
description: |
  Configure the redline statusline layout and settings. Use when the user says
  /redline:configure, "configure redline", "change statusline layout",
  "redline components", or wants to reorder, add, or remove statusline
  components, or change settings like show_reset_at.
---

# Redline Configuration

Interactive configuration for the redline statusline.

## Step 1: Show current config

Read `~/.claude/statusline-config.json` if it exists. If not, note the defaults:
- `show_reset_at`: 0
- `burn_threshold`: 10
- `lines`: `[["ps1","git","update"],["model","ctx_bar","5h_bar","7d_bar","cost","lines"]]`

## Step 2: Show the dashboard

Present the current layout with a monochrome ASCII preview of what each line looks like, and list available components with descriptions. Use this exact format:

```
Current layout:
  Line 1: ps1, git, update
  Line 2: model, ctx_bar, 5h_bar, 7d_bar, cost, lines

Preview:
  rmbug@veles:~/dev  main SM  ↑ claude code 2.1.117 → 2.1.118
  Claude Opus 4.6  ctx [####8%....] 5h 27% [###|.......] 4h  7d 12% [#|........] 6d  $0.42  +156 -23

Settings:
  show_reset_at: 0   (always show reset countdown)
  burn_threshold: 10 (flag burn when usage > elapsed + 10%)
```

Then list ALL available components grouped by category:

```
Prompt:
  ps1          user@host:cwd combined       rmbug@veles:~/dev
  user         username only                 rmbug
  host_short   short hostname                veles
  host_long    fully qualified hostname      veles.example.com
  cwd          working directory (~ for home) ~/dev

Git:
  git          branch + status flags         main SM

Model:
  model        model display name            Claude Opus 4.6

Meters (bar = visual bar, short = compact text):
  ctx_bar      context window bar            ctx [####8%......]
  ctx_short    context window text           [ctx 8%]
  5h_bar       5h rate limit bar             5h 27% [##|########] 4h
  5h_short     5h rate limit text            [5h 27%↑] 4h
  7d_bar       7d rate limit bar             7d 12% [#|.........] 6d
  7d_short     7d rate limit text            [7d 12%] 6d

Rate-limit bars include a `|` marker at the elapsed-time position — fill past
the marker means usage is pulling ahead of the clock. Short variants get a
bright red `↑` inside the brackets when burning hot (usage > elapsed + burn_threshold).

Stats:
  cost         session cost                  $0.42
  lines        lines changed                 +156 -23

Updates:
  update       session older than latest npm  ↑ 2.1.117 → 2.1.118
               (reads the session's running version from the statusline's
                parent process, not `claude` on PATH, so it flags stale
                sessions even after a background self-update)
```

Note: countdowns show the coarsest nonzero unit, rounded up (e.g. 4h30m → 5h,
3d15h → 4d). They always appear by default; set `show_reset_at` to a threshold
(0-100) to hide them at low usage.

## Step 3: Ask what to change

If the user already said what they want, apply it. Otherwise ask. Common operations:
- Reorder components
- Switch between bar and short variants
- Add/remove components
- Move components between lines
- Add/remove lines
- Change `show_reset_at` or `burn_threshold`

## Step 4: Write config

Write the updated config to `~/.claude/statusline-config.json`. Always include `show_reset_at` and `burn_threshold` if they differ from the defaults (0 and 10 respectively).

## Step 5: Confirm

Show the updated preview and tell the user it takes effect on the next assistant response.
