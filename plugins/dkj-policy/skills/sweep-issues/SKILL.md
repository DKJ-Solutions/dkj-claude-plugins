---
name: sweep-issues
description: >-
  Work an open-issue backlog with SEVERAL machines at once, without two of them building the same
  thing. Each session claims by TAG -- machine/account, written as a marker comment -- so a claim names
  the machine even where two checkouts share one GitHub account, and a two-session race is settled on
  the tracker's own timestamps: earliest marker wins, and only the losers let go. Use it when issues
  have piled up and you want them worked through rather than picked at one by one. It claims, builds,
  runs the gates and STOPS where a result has to be judged by eye -- it never opens a pull request on
  work nobody has looked at, and it never pushes anything live.
disable-model-invocation: true
---

# sweep-issues -- six machines, one backlog, no duplicated work

**It generalises a prompt block** that had to be pasted into a fresh session on every machine, whose
claim was prose a session had to type correctly, and whose race resolution did not close
([#2243](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2243)). Nothing on this page is
specific to the repo it came from.

**Run the shared script from the root of the consuming repo**, as the lines below spell it. *In the
source repo, run its own copy instead* -- `scripts/task/claim-issue.ps1`: `${CLAUDE_PLUGIN_ROOT}`
resolves into the plugin cache, which holds the last released mirror.

**Run it in one checkout at a time.** One machine, one issue, start to finish -- claim, build, gates,
hand over, next. The parallelism is the MACHINES, not the issues: a second issue in the same checkout
means two branches in one working copy, and nothing on the tracker can tell those apart.

## Why the assignee cannot be the claim

`claim-issue` without `-Tag` writes an assignee, which is the right claim for one session picking up
one issue. A sweep breaks it on both halves:

- **The write cannot name the machine.** Two checkouts authenticated as the same account write the
  same assignee, and neither can afterwards tell its own claim from the other's.
- **The read refuses work that is free.** An assignee a colleague put on their own ticket months ago is
  not somebody mid-flight. Measured on the BWJ board, September 17, 2026: three of fourteen open issues
  carried such a name, on work that was the ordinary business of that round.

So a sweep claims with a **tag**: `machine/account`, written as a marker comment. Both halves carry
weight -- two accounts can share a machine name and two machines can share an account
([#701](https://github.com/BWJ-Development/smartwatchbanden/issues/701)) -- and the assignee is still
written beside it as the tracker's own visible signal.

**The word "lane" is not used for it.** It already means a git worktree here
([`worktree-lane`](../worktree-lane/SKILL.md)), and the two are unrelated.

## The loop

### 0. Once, before anything

```powershell
git status                  # must be clean
git checkout main ; git fetch origin --prune ; git pull --ff-only
```

Then read the repo's own `CLAUDE.md`. **It outranks everything on this page**, and where the two
disagree you follow it and say so.

### 1. Choose -- and it writes nothing

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" -Candidates -SkipLabel needs-info
```

It prints every open issue as `free`, `mine`, `held` or `skipped` with the reason, and names the lowest
free number. `-SkipLabel` is the labels that park an issue with somebody else; `-SkipIssue` holds
numbers out by hand.

**Choosing and claiming are two steps on purpose.** Between them you still have to ask whether the
issue is this repo's work at all. A tracker carrying an issue means the work is TRACKED here, not that
it is OURS: where the issue mirrors a ticket from somewhere else, read who that ticket is assigned to
and what its comments say before you take it. Measured, September 17, 2026
([#722](https://github.com/BWJ-Development/smartwatchbanden/issues/722)): four tickets were mirrored
onto a board, three belonged to a colleague's own running experiment, and they were built, merged and
reported as delivered before anybody asked. **If you cannot read the source ticket, that is not a green
light** -- report the number as unjudged and move on.

### 2. Claim it

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" <n> -Tag
```

The marker goes on first, the assignee beside it, and then the claim is **read back**: if a second
machine got there first, this session releases its own marker and stops with exit 1. Take the next free
number -- a lost race costs a claim, never work.

**A refusal is final here -- with one deliberate exception.** `held` means another machine is mid-flight
and its branch is somewhere this session cannot see. The exception is your OWN issue on another of your
machines, whose branch IS on origin -- the state a machine you cannot reach leaves behind
([#2387](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2387)):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" <n> -Tag -TakeOver
```

It refuses a colleague's claim, an issue with no branch on origin, and one with several; otherwise it
replaces the old marker with this tag's, comments the handover, and prints the checkout. The old machine's
`-Verify` then reads `[NO]`, so step 6 stops it there.

**The same command resumes a branch that carries NO marker** -- a session that never ran `-Tag` leaves
only its branch on origin, and the claim's parked-fix scan then prints `NOT YOURS` over your own work
([#2394](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2394)). `-TakeOver` checks who wrote
the branch instead: every commit off the trunk must carry one of your names. **If you work under more
than one account**, declare the others in `DKJ_OWN_ACCOUNTS` (the `env` block of your own
`~/.claude/settings.json`) -- a branch on origin written by one of your declared accounts is then
resumable through `-TakeOver`, and an undeclared author still stops you.

### 3. Build it

Read the issue and its comments in full. Then the ordinary workflow, unchanged:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" -Name <prefix>/<n>-<short-name> -Title "<title>"
```

The prefix table is this repo's own (`scripts/lib/branch-info.ps1`) -- read it rather than guessing.
Fill the `### DEPLOY:` section of `dkj-policy/<branch>.md`: that section IS the changelog entry. The
change and its entry go in **one** commit.

### 4. The gates, before the hand-over and not after

`open-pr` runs them, and running them yourself first costs nothing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -GatesOnly
```

The outcome is a number, not a feeling.

### 5. Where the sweep STOPS

**Does the change produce something that has to be judged by eye?** A frontend, styling, rendered
output, an artifact, anything a visitor of a storefront can see or do. If yes -- or if you have to
ARGUE that it renders, which is itself the doubt -- then:

- push whatever preview the repo has (in a Shopify consumer, `push-preview`), hand it over in the form
  that repo's own pages prescribe, and **open no pull request**;
- park the branch on `origin`, report what you built in two lines, and **go back to step 1**.

A pull request is the question *may this go to the trunk*, and that question is not open while nobody
has looked. You do not wait for the answer: the branch survives on `origin` with its own document, and
step 6 picks it up whenever the answer comes.

**If the gates prove it** -- scripts, tests, docs, config -- the movement runs through without an
intermediate question: open, merge, fold.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1"
```

### 6. Coming back to an approved branch

An approval names a branch or an issue number. **Verify that this tag is the one that built it, before
you check anything out:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" <n> -Tag -Verify
```

Exit 0 means yours; anything else means another session's, and on this machine a checked-out branch is
indistinguishable from your own. **This is the sharpest place a vague claim costs** -- step 1 skips
everything that carries a marker and is therefore safe whoever wrote it, while this step deliberately
resumes on the tag's own work.

Then ship it, and close the issue the way this repo closes issues. **Where the issue mirrors a ticket
somewhere else, the message to the person who asked comes BEFORE the close** -- the plugin that owns
that mirror carries the form; without such a plugin the ordinary `Closes #<n>` applies.

### 7. Clean up, and go again

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prune-merged.ps1"
git checkout main
```

Back to step 1.

## Giving an issue back

A session that cannot finish an issue -- blocked, out of scope, waiting on somebody -- releases it
rather than leaving a marker standing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" <n> -Tag -Release
```

It deletes only markers carrying THIS tag, and the assignee with them. Where the issue is going back to
whoever asked for it, set the repo's own parked label in the same movement and say what you need --
a card parked with a question nobody can read is a waiting room nobody knows the subject of.

## What it never does

- **Open a pull request on work nobody has looked at**, where the result has to be judged by eye.
  Waiting means NOT OPENED, not "opened and unmerged".
- **Push anything live, publish anything, or cut a release.** Those come from a person, always.
- **Take an issue whose marker carries another tag** (outside `-TakeOver` above), or one whose source
  ticket it could not read.
- **Delete another session's marker** -- except through `-TakeOver`, on your own issue (this account or
  a declared one) with its branch on origin. `-Release` touches this tag's own and nothing else.
- **Close an issue that carries the repo's parked label.** That one is with the requester.

## Requirements

`gh`, authenticated, and `git`. The tag's machine half comes from `$env:COMPUTERNAME` or `hostname`;
its account half from `gh auth status`. **An incomplete tag refuses before the tracker is even read** --
half a tag reads like a claim and settles nothing.

`-Marker` names the marker a claim is written under (`claim-tag`) and any predecessors a repo still has
comments under, so a claim in flight under an older name still holds.

## Important

The scripts behind this skill are maintained in the source repo; do not modify them locally in a
consumer. A change lands first in the source and travels here via a release.
