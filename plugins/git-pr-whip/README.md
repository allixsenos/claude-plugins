# git-pr-whip

Keeps Claude honest about PR hygiene after it commits.

Claude is great at forgetting two specific things after a `git commit`:

1. **The PR it's updating might already be closed.** If you squash-merged the PR while Claude was doing other work, Claude will happily keep pushing to that stale branch and watch the push get rejected — or worse, re-open a dead PR. The branch should be rebuilt from the current default branch.
2. **Review feedback it addressed in the commit never gets acknowledged on the PR itself.** Reviewers left suggestions; Claude accepted some, dismissed others, silently. The PR conversation has no record of what changed and why.

This plugin nudges it, quietly.

## What it prevents

Two failure modes, both reconstructed from real sessions (names changed, pacing tightened).

### 1. Pushing into a PR that was already merged

```
> apply the reviewer's fix on #204, then push

● I'll address the feedback and push.
● Edit(src/auth.ts)          — 3 edits
● Bash(git commit -m "fix: handle null session in resolver")
  ✓ [fix-auth-resolver abc1234] fix: handle null session in resolver
● Bash(git push)
  ✗ ! [rejected] fix-auth-resolver -> fix-auth-resolver (non-fast-forward)
    hint: Updates were rejected because the remote contains work that you do
    hint: not have locally.

● The remote has new work. Let me rebase.
● Bash(git pull --rebase origin fix-auth-resolver)
  ✗ fatal: couldn't find remote ref fix-auth-resolver
● Bash(gh pr view 204 --json state,mergedAt)
  {"state":"MERGED","mergedAt":"2026-04-22T14:02:11Z"}

● The PR was squash-merged 40 minutes ago. The branch is stale. Sorry —
  I'll restart from master.
```

Four wasted tool calls, a confused rebase attempt, and the commit is now orphaned on a dead branch. With git-pr-whip, the `gh pr view` check happens *before* the push, right after the commit.

### 2. Silent dismissal of review suggestions

A reviewer left five line comments. Claude accepts three, dismisses two (one because the suggested refactor would duplicate private state across both halves, one because the suggested regex rejects a valid production input). The follow-up commit lands. The PR auto-merges on approval. The reviewer, days later:

> Why did you ignore the null-check suggestion on `session.ts:88`? Also what happened to the regex tightening?

Claude has no memory of the session. The diff shows only what changed, not what was *considered and rejected*. Now someone has to re-read the review, re-read the diff, and reconstruct the reasoning — or re-open the discussion from scratch.

With git-pr-whip, the post-commit nudge triggers a single recap comment on the PR:

> **Review recap (fix-auth-resolver @ abc1234):**
> - ✓ #1 missing null check on `session.user` → added in `session.ts:88`
> - ✓ #2 typo in error message → fixed
> - ✓ #3 extract `validateToken` helper → done
> - ✗ #4 split `AuthResolver` into two classes → dismissed; the two halves share six private fields, splitting duplicates them with no win
> - ✗ #5 tighten the email regex to `^[a-z0-9]` → dismissed; that rejects addresses with `+` aliases which we accept in prod (see #137)

## First real catch (five minutes after install)

The two transcripts above are fake. This one is not. I wrote the faux reproduction section, committed it, and pushed — and the plugin caught me on its own README commit, because the user had squash-merged the plugin's own PR ([#19](https://github.com/allixsenos/claude-plugins/pull/19)) while I was still editing. The commit landed on a now-dead branch. Verbatim session:

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

Without the nudge after `git commit`, the orphaned commit would have silently stayed on the dead branch until someone noticed it wasn't on `master`. With it, the recovery took three extra commands and zero lost work.

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
