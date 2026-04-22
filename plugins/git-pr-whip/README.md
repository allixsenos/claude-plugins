# git-pr-whip

Nudges Claude about PR hygiene at commit and push time, and blocks the one workflow where the nudge would arrive too late.

## What it catches

Three nudges and one block. Nudges are injected as `additionalContext` — Claude sees them, you don't.

- **After `git commit`** — *"Before you push, run `gh pr view` and check that the PR is still open."* Catches the case where the PR was squash-merged while Claude was working and the branch is now stale.
- **After `git push`** — *"Did these commits expand the PR's scope? Update the title and description with `gh pr edit`."* Catches *"while I'm here"* drift that leaves reviewers opening a PR titled *"fix null session"* and finding a logger refactor.
- **After `git push`** — *"If you addressed review feedback, post a recap comment with what you accepted vs. dismissed."* Gives reviewers a record instead of forcing them to reconstruct it from the diff.
- **Before `git commit && git push`** — denied. The commit-time reminder only lands *between* tool calls; if the push is chained behind the commit, the reminder arrives too late to change anything. Claude has to split the chain into two calls.

Detection ignores `git commit` / `git push` inside quoted strings and heredoc bodies, and correctly leaves `git stash push` alone.

## Install

```
/plugin marketplace add allixsenos/claude-plugins
/plugin install git-pr-whip@allixsenos
/reload-plugins
```

No configuration.

## Why a hook and not CLAUDE.md

Because Claude forgets. Memory and CLAUDE.md get compacted, glossed over, or outweighed by whatever is on-screen. A hook fires at the exact moment the reminder is actionable — right after the commit, right before the next push — which makes it much harder to skip past.

## It caught its own author five minutes in

While I was writing this plugin's original README, the user squash-merged the plugin's own landing PR ([#19](https://github.com/allixsenos/claude-plugins/pull/19)). My next commit pushed to a branch that was now dead. The very reminder I had just written caught it — verbatim session:

```
❯ add a faux reproduction of the scenario that the plugin prevents to the plugin's README

  Committed eed6a5, pushed to git-pr-whip, ran 1 bash command

Plugin fired on its own commit — nice end-to-end proof. Let me honor reminder #1
retroactively and confirm PR #19 is still open (not closed/merged while I was
committing).

  Ran 1 bash command

Oh — PR #19 is already MERGED. You merged it while I was working on the README
update, so I just pushed a new commit to a dead branch. This is literally the
scenario reminder #1 exists to prevent. Let me verify the damage and apply the fix.

  Ran 1 bash command

Confirmed: PR #19 was squash-merged as 7924c49 on master. My eed6a58 is orphaned
on the dead branch. Applying the fix the plugin prescribes.

  Cherry-picked 3b0095, created PR #20, ran 1 bash command

Follow-up PR opened: #20.

What just happened:
1. You squash-merged PR #19 → master now has commit 7924c49.
2. My README update committed and pushed to the old git-pr-whip branch — which
   was now dead. eed6a58 was orphaned (not in the PR, not on master).
3. The plugin's own PostToolUse reminder fired on that commit, telling me to run
   gh pr view — which showed state: MERGED.
4. I pulled master, cut a fresh branch git-pr-whip-readme-repro off 7924c49,
   cherry-picked eed6a58 onto it, pushed, opened #20.

The plugin caught its own author on its first real commit. Hard to ask for a
better smoke test.

✻ Churned for 2m 18s
```

Without the nudge, the orphaned commit would have silently stayed on the dead branch until someone noticed it wasn't on `master`. With it, recovery was three extra commands and zero lost work.

## Pairs well with

- **git-governor** — handles the dangerous stuff (amends on pushed commits, force pushes, commits to `main`). git-pr-whip handles the workflow-hygiene stuff governor doesn't block.
