# git-pr-whip

Keeps Claude honest about PR hygiene after it commits.

Claude is great at forgetting three specific things around commit and push time:

1. **The PR it's updating might already be closed.** If you squash-merged the PR while Claude was doing other work, Claude will happily keep pushing to that stale branch and watch the push get rejected — or worse, re-open a dead PR. The branch should be rebuilt from the current default branch. (Checked after `git commit`.)
2. **The PR's scope has grown past its title and description.** Claude adds a "while I'm here" fix, then another, and the PR still says what the first commit was about. Reviewers lose trust when they open a PR titled *"fix null session"* and find a logger refactor. (Checked after `git push`.)
3. **Review feedback Claude addressed never gets acknowledged on the PR itself.** Reviewers left suggestions; Claude accepted some, dismissed others, silently. The PR conversation has no record of what changed and why. (Checked after `git push`.)

It also forgets a fourth thing — that the above reminders can't help when commit and push are chained in one Bash call. So this plugin also **blocks** `git commit && git push` (and friends) before the tool runs, forcing the work into two turns so the reminder has a chance to land. More on that below.

This plugin nudges it, quietly — and occasionally refuses to let Claude skip the nudge.

## What it prevents

Four failure modes, reconstructed from real sessions (names changed, pacing tightened). The first three are nudged; the fourth is outright denied.

### 1. Pushing into a PR that was already merged — nudged after `git commit`

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

### 2. Scope creep without updating the PR — nudged after `git push`

```
> the auth-resolver PR is ready to push, but the logger module also has a race
  condition that's been bugging me. fix that too while you're in there.

● Edit(src/auth-resolver.ts)
● Edit(src/logger.ts)           — unrelated subsystem
● Bash(git commit -am "fix: logger init race on hot reload")
● Bash(git push)
  ✓ To github.com:acme/app.git
     abc1234..def5678  fix-auth-resolver -> fix-auth-resolver

PR #204 title:  "fix: null session in auth resolver"
PR #204 body:   "Fixes the null session bug reported in #198."
PR #204 diff:   src/auth-resolver.ts (+12 -3)
                src/logger.ts       (+18 -6)   ← not mentioned in title or body
```

Next morning, reviewer:

> Why is there a logger change in a PR titled *"null session in auth resolver"*? I was going to skim-approve based on the title. Splitting into two PRs.

With git-pr-whip, the push nudge prompts Claude to run `gh pr edit 204 --title "..." --body "..."` right after the push, so the PR metadata matches what it actually contains before anyone looks at it.

### 3. Silent dismissal of review suggestions — nudged after `git push`

A reviewer left five line comments. Claude accepts three, dismisses two (one because the suggested refactor would duplicate private state across both halves, one because the suggested regex rejects a valid production input). The follow-up commit lands. The PR auto-merges on approval. The reviewer, days later:

> Why did you ignore the null-check suggestion on `session.ts:88`? Also what happened to the regex tightening?

Claude has no memory of the session. The diff shows only what changed, not what was *considered and rejected*. Now someone has to re-read the review, re-read the diff, and reconstruct the reasoning — or re-open the discussion from scratch.

With git-pr-whip, the post-push nudge triggers a single recap comment on the PR:

> **Review recap (fix-auth-resolver @ abc1234):**
> - ✓ #1 missing null check on `session.user` → added in `session.ts:88`
> - ✓ #2 typo in error message → fixed
> - ✓ #3 extract `validateToken` helper → done
> - ✗ #4 split `AuthResolver` into two classes → dismissed; the two halves share six private fields, splitting duplicates them with no win
> - ✗ #5 tighten the email regex to `^[a-z0-9]` → dismissed; that rejects addresses with `+` aliases which we accept in prod (see #137)

### 4. Chaining commit and push so the reminder can't land — blocked before the tool runs

The reminders above fire *after* the tool call. That's fine when commit and push are two separate calls, but Claude often tries:

```
> commit the fix and push it

● Bash(git commit -m "fix: null session" && git push)
```

With both commands in one shell invocation, the commit's post-commit reminder (*"is the PR still open? pull master first?"*) gets generated — but the push already ran. The reminder lands as context for Claude's *next* turn, which is now after the push, when it can't influence anything.

git-pr-whip denies this pattern at `PreToolUse`:

```
● Bash(git commit -m "fix: null session" && git push)
  ✗ denied by git-pr-whip: chaining `git commit` with `git push` in a single
    Bash call is blocked. The post-commit PR-hygiene reminder only lands in
    context AFTER the tool call finishes — if you've already chained the
    push, the reminder can't change the outcome. Run them as separate Bash
    calls: commit first, read the reminder, then decide whether to push.

● Right — splitting them.
● Bash(git commit -m "fix: null session")
  ✓ [fix-auth abc1234] fix: null session
  [reminder arrives: run `gh pr view --json state,url` before pushing]

● Bash(gh pr view --json state)
  {"state":"OPEN"}

● Bash(git push)
  ✓ …
```

Detection covers `&&`, `;`, `||`, `|`, subshells like `(git commit ... && git push)`, line continuations, and `git -C /path commit`. Standalone commits and pushes pass through untouched, and `git stash push` is correctly *not* matched (the regex requires `commit`/`push` to be the first word after `git`).

## First real catch (five minutes after install)

The three transcripts above are fake. This one is not. I wrote the faux reproduction section, committed it, and pushed — and the plugin caught me on its own README commit, because the user had squash-merged the plugin's own PR ([#19](https://github.com/allixsenos/claude-plugins/pull/19)) while I was still editing. The commit landed on a now-dead branch. Verbatim session:

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

Two hooks on the `Bash` tool:

- **`PreToolUse`** (`block-chain.sh`) — denies any command that contains *both* `git commit` and `git push`. No reminder would reach Claude in time to affect the push otherwise.
- **`PostToolUse`** (`git-pr-whip.sh`) — when the command is `git commit` (any variant: `-m`, `--amend`, `--fixup`) or `git push`, injects an `additionalContext` reminder that Claude sees but you don't.

**After `git commit`:**

> **PR hygiene reminder (git-pr-whip plugin):**
> If this commit is meant to update an existing PR, before pushing run `gh pr view --json state,url` for that branch. If the PR state is MERGED or CLOSED, the branch is stale — pull the latest default branch, create a new branch from it, and open a fresh PR instead of pushing to the old one.

**After `git push`:**

> **PR hygiene reminder (git-pr-whip plugin):**
>
> 1. If this push updates an existing PR, check whether the commits now on the branch have expanded the PR's scope past what its title and body describe (e.g. additional fixes, new features, or refactors added after the PR opened). If so, run `gh pr edit <num> --title ... --body ...` so reviewers see the full scope, not just what the PR originally claimed.
> 2. If this push includes commits that address PR review feedback from other users or agents, post one recap comment on the PR summarizing which suggestions you accepted vs. dismissed, with a one-line reason for each dismissal — so reviewers don't have to reconstruct it from the diff.

Other Bash calls are silent. `git stash push` is correctly ignored (the regex requires `commit`/`push` to be the first word after `git`). The hook also strips quoted strings and heredoc bodies before scanning, so a shell script or commit message that happens to mention `git commit` or `git push` doesn't trigger it.

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
