---
name: sweep-issues
description: >-
  Work an open-issue backlog with SEVERAL machines at once, without two of them building the same
  thing. Each session claims by TAG -- machine:checkout/account, written as a marker comment -- so a claim names
  the checkout even where two of them share one machine and one GitHub account, and a two-session race is settled on
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

**One sweep per checkout, one issue at a time.** Claim, build, gates, hand over, next. The parallelism is
the CHECKOUTS, not the issues: a second issue in the same checkout means two branches in one working copy,
and nothing on the tracker can tell those apart. A second checkout -- another clone, or a
[worktree-lane](../worktree-lane/SKILL.md) -- is a second tag, on the same machine or another. And a
visible park (step 5) ends the sweep in its checkout, because the owner judges that working copy.

## Why the assignee cannot be the claim

`claim-issue` without `-Tag` writes an assignee, which is the right claim for one session picking up
one issue. A sweep breaks it on both halves:

- **The write cannot name the machine.** Two checkouts authenticated as the same account write the
  same assignee, and neither can afterwards tell its own claim from the other's.
- **The read refuses work that is free.** An assignee a colleague put on their own ticket months ago is
  not somebody mid-flight. Measured on the BWJ board, September 17, 2026: three of fourteen open issues
  carried such a name, on work that was the ordinary business of that round.

So a sweep claims with a **tag**: `machine:checkout/account`, written as a marker comment. Both halves carry
weight -- two accounts can share a machine name and two machines can share an account
([#701](https://github.com/BWJ-Development/smartwatchbanden/issues/701)) -- and the assignee is still
written beside it as the tracker's own visible signal.

**The checkout is a short hash of the checkout's root path**, never the path itself, which would put a
user name on the tracker. Without it two sweeps on one machine under one account wrote one tag, and each
read the other's claim as `mine` -- measured October 5, 2026, when two sessions built the same issue and
one shipped it while the other ran its gates
([#2836](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2836)). A claim written before the
checkout half existed reads as `held`, with a note that it is this machine's and account's: read its
branch, and `-TakeOver` resumes it when the work is yours.

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
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" -Candidates -SkipLabel awaiting-more-info,awaiting-decision,awaiting-pull,awaiting-event,awaiting-owner-act,awaiting-first-recurrence,awaiting-more-recurrences,needs-info,needs-decision,awaiting-recurrence,record,dossier
```

It prints every open issue as `free`, `mine`, `held`, `branch` or `skipped` with the reason, and names
the lowest free number. `-SkipLabel` is the labels that park an issue with somebody else; `-SkipIssue`
holds numbers out by hand. The last five are former names -- `needs-info` became `awaiting-more-info`, `needs-decision` became `awaiting-decision`,
`awaiting-recurrence` became `awaiting-first-recurrence`, and `dossier` then `record` became
`awaiting-more-recurrences` (#2683, #2723, October 2, 2026; #2741, October 3, 2026) -- listed because a tracker keeps an old name until
somebody renames it there.

**`branch` means somebody pushed work for it without a claim marker** -- a `<prefix>/<n>-<name>` branch
is on origin, and the reason names its author and how long ago it last moved. It is not free: a marker is
only written by a session that ran `-Tag`, so the tracker alone once read 11 of 11 open issues as free
while 9 had a live branch
([#2392](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2392)). Read that branch, or ask its
author, before you claim one. **And `free` still means only what this step can see** -- no marker and no
branch named with the number; a branch named for the subject is caught at the claim, by its
title-overlap scan.

**Choosing and claiming are two steps on purpose.** Between them you still have to ask whether the
issue is this repo's work at all. A tracker carrying an issue means the work is TRACKED here, not that
it is OURS: where the issue mirrors a ticket from somewhere else, read who that ticket is assigned to
and what its comments say before you take it. Measured, September 17, 2026
([#722](https://github.com/BWJ-Development/smartwatchbanden/issues/722)): four tickets were mirrored
onto a board, three belonged to a colleague's own running experiment, and they were built, merged and
reported as delivered before anybody asked. **If you cannot read the source ticket, that is not a green
light** -- report the number as unjudged and move on.

**A `free` issue that turns out to be WAITING is parked on the tracker, not held out**
([#2843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2843)). The wait might be a live
push, a release, a deletion or a credential (`awaiting-owner-act`), another issue's pull request
(`awaiting-pull`), an external event or date (`awaiting-event`), or the owner's choice
(`awaiting-decision`). Set the matching label and say in one comment what it waits on:

```powershell
gh issue edit <n> --add-label <awaiting-label>
gh issue comment <n> --body "Parked by a sweep: waiting on <what>."
```

`-SkipIssue` lasts one run and writes nothing, so a wait held out that way is judged again by every
sweep after it. Measured October 6, 2026
([xoxowildhearts](https://github.com/BWJ-Development/xoxowildhearts)): five of six `free` issues
were held out for the same reasons the previous day's sweep had held them out for. With the label, the
next sweep's step 1 reads them as `skipped`. **`-SkipIssue` stays for a hold-out that is not a wait**,
such as a source ticket you could not read. Where the tracker does not carry the label yet,
`adopt-triage-labels` prints the line that creates it.

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

**Leaving a machine on purpose, you can tidy first** -- `claim-issue.ps1 -Tag -ReleaseAll` lists every
open issue this tag holds, and `-Apply` releases them, so the next machine's `-Candidates` does not read
your old tag as `held` ([#2395](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2395)). It
touches this tag's own markers only, never another's, and it is optional: `-TakeOver` above is what
covers the switch you did not plan.

### 3. Build it

Read the issue and its comments in full. Then the ordinary workflow, unchanged:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" -Name <prefix>/<n>-<short-name> -Title "<title>"
```

The prefix table is this repo's own (`scripts/lib/branch-info.ps1`) -- read it rather than guessing.
Fill the `### DEPLOY:` section of `dkj-policy/<branch>.md`: that section IS the changelog entry. The
change and its entry go in **one** commit.

### 4. The gates, before the hand-over and not after

**Which command runs them depends on where step 5 sends the branch.**

- **It ships** (the gates prove it): run nothing yourself. `ship-pr` runs the full gate before it pushes,
  and a pre-run is almost never credited -- `open-pr` skips a gate only on a recorded pass of the
  *identical* tree (HEAD plus every uncommitted file) in the *same* worktree. A pre-run before the commit,
  or one in a lane followed by a ship from the primary checkout, is a different tree or a different
  worktree, so the same gate simply runs twice. Measured
  ([#2372](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2372)): 1,400s of `-GatesOnly`,
  then the same 1,400s again inside `ship-pr` on the same commit.
- **It stops** (a visible result, no pull request): here the gates have no other chance to run, so run
  them yourself before you park it:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -GatesOnly
  ```

Either way the outcome is a number, not a feeling.

### 5. Where the sweep STOPS

**Does the change produce something that has to be judged by eye?** A frontend, styling, rendered
output, an artifact, anything a visitor of a storefront can see or do. If yes -- or if you have to
ARGUE that it renders, which is itself the doubt -- then:

- push whatever preview the repo has (in a Shopify consumer, `push-preview`), hand it over in the form
  that repo's own pages prescribe, and **open no pull request**;
- park the branch on `origin`, and **the sweep ends here, on that branch** -- straight to the
  close-out below, with no step 7.

A pull request is the question *may this go to the trunk*, and that question is not open while nobody
has looked. The branch survives on `origin` with its own document, and step 6 picks it up whenever the
answer comes.

**The checkout stays where it is because the owner judges the working copy.** The constitution says so
in as many words -- *"the checkout stays on that branch until the owner has looked"* -- and a preview
served from this checkout is served from that branch. Step 7's `git checkout main` would take away the
very thing waiting to be judged, and a second issue built in the same checkout would replace it. So a
visible park ends the sweep in this checkout, even with `free` issues left: those are named in the
close-out, and the next sweep -- here once the owner has looked, or in another checkout now -- takes
them. Decided by Dave, October 6, 2026
([#2833](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2833)), over two alternatives
that kept the sweep going in a worktree lane: one first needs `ship-pr` verified to work from a lane,
the other needs the owner to be told a lane's path before they can judge.

**If the gates prove it** -- scripts, tests, docs, config -- the movement runs through without an
intermediate question: open, merge, fold.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1" -Resolves <n>
```

**`-Resolves <n>` is not optional here.** A sweep branch is named after its issue and its entry cites it,
so `open-pr`'s resolves gate always finds a mention and refuses a bare `ship-pr` before anything is pushed
([#2376](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2376)). Where the branch is only one
step of a larger issue -- the issue stays open for the next step -- pass `-NoResolves` instead, and say in
a comment on the issue what the step did and what is left.

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

Then ship it -- the same `ship-pr.ps1 -Resolves <n>` as step 5 -- and close the issue the way this repo
closes issues. **Where the issue mirrors a ticket
somewhere else, the message to the person who asked comes BEFORE the close** -- the plugin that owns
that mirror carries the form; without such a plugin the ordinary `Closes #<n>` applies.

### 7. Clean up, and go again

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prune-merged.ps1"
git checkout main
```

Back to step 1, in the same turn.

### When the sweep ends, and the one close-out it owes

**The loop stops when step 1 has nothing left for this session**: every issue `-Candidates` prints as
`free` has been shipped, given back, parked on the tracker with its `awaiting-*` label because it
waits, or judged and held out (with `-SkipIssue` and a reason) for something that is not a wait.
**Or when step 5 parks a visible result**, which ends it at once, on that branch. Nothing else ends it,
and one shipped issue in particular does not.

**The close-out `ship-pr` prints is one issue's receipt, not the sweep's**
([#2562](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2562)). Its last lines read
*"Close-out: a receipt ... Session can be cleared"*, and in a sweep that is only the end of step 5. Read
it as the cue for step 7, not as the end of the assignment. Measured September 28, 2026: a sweep shipped
one issue, took that template as its own close-out, and left four `free` issues untouched.

**What it skipped as `awaiting-decision` is the owner's half**, and `sweep-decisions` walks it with
them in one pass; a decided issue comes back here as `free`.

**The sweep closes out once, after the loop**, in the ordinary receipt shape: the PR number of each issue
it shipped, the branch it parked for the owner's eye (checked out, where it stays), the number and
label of each it parked as waiting, the number of each it held out, with a clause for why, and -- where
a visible park ended it early -- the numbers still `free`.

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
