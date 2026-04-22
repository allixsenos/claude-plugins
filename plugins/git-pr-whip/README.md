# git-pr-whip

Keeps Claude honest about PR hygiene after it commits.

Claude is great at forgetting two specific things after a `git commit`:

1. **The PR it's updating might already be closed.** If you squash-merged the PR while Claude was doing other work, Claude will happily keep pushing to that stale branch and watch the push get rejected — or worse, re-open a dead PR. The branch should be rebuilt from the current default branch.
2. **Review feedback it addressed in the commit never gets acknowledged on the PR itself.** Reviewers left suggestions; Claude accepted some, dismissed others, silently. The PR conversation has no record of what changed and why.

This plugin nudges it, quietly.

## What it does

A `PostToolUse` hook fires after every Bash command. When the command is a `git commit` (any variant: `-m`, `--amend`, `--fixup`, etc.), it injects an `additionalContext` reminder that Claude sees but you don't:

> **PR hygiene reminder (git-pr-whip plugin):**
>
> 1. If this commit is meant to update an existing PR, before pushing run `gh pr view --json state,url` for that branch. If the PR state is MERGED or CLOSED, the branch is stale — pull the latest default branch, create a new branch from it, and open a fresh PR instead of pushing to the old one.
> 2. If this commit addresses PR review feedback from other users or agents, post one recap comment on the PR summarizing which suggestions you accepted vs. dismissed, with a one-line reason for each dismissal — so reviewers don't have to reconstruct it from the diff.

Non-commit Bash calls are silent. The hook also ignores `git commit` inside quoted strings or heredoc bodies, so writing a shell script that happens to mention the string doesn't trigger it.

## Install

```
/plugin marketplace add allixsenos/claude-plugins
/plugin install git-pr-whip@allixsenos
/reload-plugins
```

No configuration.

## Why a hook and not memory or CLAUDE.md

Because Claude forgets. Memory and CLAUDE.md get compacted, glossed over, or outweighed by whatever is currently on-screen. A PostToolUse injection happens at the exact moment the reminder is actionable — immediately after `git commit`, before the next `git push` or PR edit — which makes it much harder to skip.

## Pairs well with

- **git-governor** — catches the dangerous stuff (amends on pushed commits, force pushes, commits to `main`). `git-pr-whip` covers the workflow-hygiene stuff governor doesn't block.
