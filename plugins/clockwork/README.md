# clockwork

Keeps Claude oriented in time during long sessions.

Claude has no internal clock. In conversations that span hours, it loses track of time completely -- guessing 3 AM when it's actually noon, or not knowing what day it is after a context compaction.

Clockwork fixes this by injecting the current day, date, and time into the conversation context. It fires on every message you send, but only injects the time if 10+ minutes have passed since the last injection -- so it stays out of the way during rapid back-and-forth.

## Install

```
/plugin install clockwork@allixsenos
/reload-plugins
```

That's it. No configuration needed.

## How it works

A `UserPromptSubmit` hook runs a shell script that:
1. Checks a timestamp file (`/tmp/claude-clockwork.stamp`)
2. If 10+ minutes have elapsed, injects `Current time: Tuesday, 2026-04-14 11:40 CEST` into the context
3. If less than 10 minutes, does nothing

The injection uses `claudeOutput` so it appears as context to Claude, not as a visible message to you.

## Why 10 minutes?

Short enough that Claude stays oriented across topic changes and context compactions. Long enough that it doesn't waste tokens on every single message.
