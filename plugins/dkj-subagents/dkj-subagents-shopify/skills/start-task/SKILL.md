---
name: start-task
description: Start a new task in a Shopify store repo — the git branch. Invoke manually as "/dkj-subagents-shopify:start-task <prefix>/<short-name>", e.g. /dkj-subagents-shopify:start-task feat/size-chart-popup. It drives THIS repo's own start-task script; the team deliberately ships none. The preview theme is NOT created here: push-preview creates it on the first push, so a branch that never needed one leaves none behind.
disable-model-invocation: true
---

# start-task — the branch that opens a Shopify task

**The preview theme is no longer part of this step.** It used to be: a branch and an unpublished theme of
the same name were created together. Since inbound
[#805](https://github.com/DaveKJohn/claude-code-specialists/issues/805) the theme comes into existence on
the **first push** instead — [`push-preview`](../push-preview/SKILL.md) creates it — so a docs or tooling
branch that could never touch a theme file no longer leaves an unused theme behind on a store with a hard
ceiling that is finite. Measured on the day the rule was made: of 12 real branch previews on one store, **6
belonged to branches that never needed one**.

> A preview theme is a consequence of *"I want to show this"*, not of *"I am starting work"*.

So this page opens the branch, and nothing else. When a change is ready to be looked at, ask for
`push-preview`.

## What this needs from your repo, and why it is not shipped

**`dkj-subagents-shopify` ships no `start-task` script**, and that is a decision rather than an omission — though a
narrower one than it used to be. What made the step unshareable was the preview theme, and that half has
now moved out into `push-preview`, which the team *does* ship. What is left is a branch, and a branch is
whatever your repo's own convention says it is: `dkj-policy` consumers have `new-branch`, others
have their own script, conventionally at `scripts/task/start-task.ps1`.

**If your repo has no such script, this skill has nothing to run — say so rather than improvising one.**
The branch is then made by hand, per that repo's branch convention as its own `CLAUDE.md` states it. Do
**not** create a preview theme at this point: that is `push-preview`'s job, and doing it here by hand is
exactly the estate this split cleaned up.

## Argument

The branch name, in the form **your repo** uses. This page carries no list of prefixes on purpose: a
taxonomy hardcoded here would contradict whichever one the repo actually has, and it is the repo that
refuses a bad name. Read it from `CLAUDE.md`, and — in a repo that also runs `dkj-policy` — from
the seam at `scripts/lib/branch-info.ps1` (`Get-BranchTypes`, `Test-BranchName`), which is where that repo
states it once for every script that asks. Classify by *what actually changes*.

## Steps

1. **No argument supplied?** → first ask which branch name is wanted. Do not guess.
2. **Gatekeepers:** verify you are on the trunk with a clean working tree. Take the branch convention from
   the repo, not from memory. **A sync is a gatekeeper here only if this branch will edit theme files** —
   [`sync-main`](../sync-main/SKILL.md#when-to-run-it) states when it applies, and a documentation, tooling
   or config branch has no stale base to avoid. Do not run one *"to be safe"*: it can refuse on a standing
   predecessor branch and block a branch it could never have conflicted with.
3. **Run the repo's script**, if it has one — plain, without a stderr redirect (the Shopify CLI writes its
   progress to stderr):
   ```powershell
   scripts/task/start-task.ps1 -Name "$ARGUMENTS"
   ```
   No such file? Stop, say that this repo has no start-task script, and offer the by-hand route above.
4. **A refusal is an answer.** Where the script validates the name, resolve the error it names; do not try
   another spelling to get past it.
5. **On success** say the branch is open — and **do not create a preview theme.** A repo whose own
   `start-task` script still creates one prints its URLs; pass those on, and note that
   [`push-preview`](../push-preview/SKILL.md) makes that half of the script redundant.

## Boundaries

- **The theme estate is not touched here.** Nothing is created, published or deleted; the preview theme
  arrives with the first `push-preview`, unpublished by definition.
- Do not touch the trunk or live beyond what the script does.
