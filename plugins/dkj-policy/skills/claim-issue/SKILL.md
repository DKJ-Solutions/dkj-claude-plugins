---
name: claim-issue
description: >-
  Claim a GitHub issue on the tracker before any work on it begins -- assign it to the account THIS
  checkout commits as, and refuse when the issue is closed, missing, or already somebody else's. Use
  it the moment an issue number is named as the work -- "fix issue 1234", "pick up #87", "take this
  one", in whatever language the request arrives -- and again when resuming one, BEFORE reading the
  code or opening a branch. It writes one assignee and nothing else -- no branch, no commit, no
  comment -- so it is the step that runs first and not a replacement for new-branch: claim, then carry
  straight on into the work in the same turn.
---

# claim-issue -- the claim rule, performed

The rule has been written down for as long as this workflow has existed:
[`CONTRIBUTING-portable.md`](../../CONTRIBUTING-portable.md) states it
("**Claim an issue before working it**, and read the claim as well as write it"), and Chris's persona
body states it with the command -- `gh issue edit <n> --add-assignee @me`. **Both leave it to a
session to remember, to type, and to read the result of.** This skill is that step, so that
*"fix issue 1234"* cannot begin before the tracker says who is on it.

**Why the tracker and not a branch.** It is the only thing two sessions share. The same owner may be
running a second machine and a colleague may be working the same board; neither session sees the
other's branch or intent, so an unassigned issue is indistinguishable from an untouched one -- which
is how the same work gets built twice and discovered at the merge.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" 1234
```

**In the source repo, run its own copy instead -- `scripts/task/claim-issue.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own,
so for them the line above is the correct one.

The script:

1. Resolves **which account** this checkout claims under -- see the next section. It never sends
   `@me`.
2. Reads the issue (`gh issue view --json number,title,state,url,assignees,body`).
3. **Judges it** -- five verdicts, three of them refusals (below).
4. On a claim or a resume, **scans the branches** for a fix that is already pushed (below). A warning,
   never a refusal.
5. **Weighs whatever that scan surfaced** -- how far ahead of the trunk each branch is, and whether
   anything the issue names sits there and not on the trunk (below). A warning, never a refusal, and
   no git call at all where nothing was surfaced.
6. Writes the assignee, then **reads the claim back** and fails if it did not land.

## Two parameters

- **`-Issue <n>`** (positional, required) -- the issue. A bare number (`1234`), a hash-prefixed one
  (`#1234`), or the issue's own URL: all three are what a person has in their hand at that moment,
  and requiring one spelling would only teach the caller to strip characters the script strips
  itself.
- **`-DryRun`** -- read and judge, write nothing. Prints the verdict it would act on, so you can see
  **who holds an issue without taking it**.

## Which account -- and why never `@me`

`@me` resolves through the GitHub API, so it binds to whatever `gh` is authenticated as. The branch a
second session correlates the claim **with** carries the *git* identity. A machine can hold both --
a personal login on the tracker, a work account on the commits -- and then `@me` claims under one
name while every commit lands under the other. Nothing errors, no gate fails, and the claim answers
the wrong question.

Measured, September 3, 2026
([#1315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1315)): `gh` authenticated as
`DaveKJohn` on a checkout committing as `davekokbwj`, so claiming #1314 with the documented idiom put
the wrong account on it and it had to be corrected by hand.

So this script reads **both** and claims **by name**, which is exactly what
`check-git-identity.ps1`'s own report already instructs on such a checkout. On a split identity it
says so before it writes, and picks the **git** name -- the tracker is made to agree with the
commits, because the commits are the half nothing can rewrite afterwards. A `git config user.name`
holding a display name ("Ada Lovelace") is not an account at all and is no evidence of a split, so a
normal repo never sees this.

## The five verdicts

| Verdict | What happens |
|---|---|
| **open, unassigned** | Claimed, read back, and the work may start. |
| **already yours** | Nothing to write -- this is a resume. Read the branch and its document before carrying the work. |
| **closed** | **Refused.** |
| **held by somebody else** | **Refused.** |
| **no account** | **Refused** -- `gh` is absent or logged out, so there is nobody to claim as. A step whose whole job is to say who is working cannot proceed anonymously. |

**The closed refusal is the one this step was built for.** `gh issue edit <n> --add-assignee`
**succeeds silently on a closed issue**, so the documented one-liner gives a session every signal of
having taken ownership of work that is already done. That is the case recorded in `new-branch.ps1`'s
stale-base block: a branch cut, committed, pushed and PR'd against an issue another session had
closed by a merged PR **four minutes earlier**, found only when the PR sat without a check suite.
Nothing downstream catches it, because every gate reads the branch and the branch is fine.

If a closed issue is still broken, **reopen it first**. The reopening is the record that the earlier
repair did not hold, and this step is not the place to make that record silently.

**There is deliberately no flag past that fourth verdict.** An assignee that is not this checkout's own
account stops the work; the way through is asking whoever holds it, and a switch cannot have a
conversation. A **co-assignment stops it too**, including one this account is part of: two people on
one issue is the duplicate-work hazard itself, and being one of the two is no evidence about what the
other is building.

## The claim is read back, because the write is not the proof

`--add-assignee` reports success for a login GitHub silently drops -- most often an account with no
write access to the repo. An unverified claim is worse than none: the session believes the tracker
says something it does not. So the script re-reads the assignees and **fails** when its own account
is not among them, telling you to treat the issue as unclaimed.

**And the read-back reports THREE states, because two of them are opposite facts** (#1628,
September 8, 2026). It used to hold one boolean, which read `$false` both when the read had answered
and the account was absent *and* when the read had never happened -- and then printed the first:

| State | What it means | What happens |
|---|---|---|
| **claimed** | the read answered and the account is on the issue | `[OK]`, and the work starts |
| **refused** | the read answered and the account is **not** on the issue | `[ERROR]`, treat it as unclaimed, exit 1 |
| **could not verify** | the read did not answer (`gh` absent, a non-zero exit, or a timeout) | `[WARNING]` naming which of the three -- and it does **not** block |

**The third state does not block, and that is the point of separating it.** The write it is checking
returned 0 and the read *before* the write answered normally, so the far likelier state is a claim
that landed and a read that did not -- and everything that guards against duplicate work has already
succeeded by then. Refusing there costs the whole assignment, which is exactly what a claim is not
allowed to do ([#1485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1485): the
claim is the *opening* of the work). So it says which of the two it is in and hands over the one
command that settles it, the way `new-branch` already words its own unreachable-`gh` line.

Measured on the claim of [#1623](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1623)
in the source repo: the old message fired, named a cause it had not measured, and told the operator to
treat the issue as unclaimed -- while a plain `gh issue view` on the same checkout, seconds later,
showed the claim sitting there. Followed literally by a second session, that inverts the very hazard
this step exists to prevent.

## The fourth signal: a fix already pushed on a branch with no pull request

**The three signals above all read "untouched" in one shape.** The verdicts read the issue's *state*
and its *assignees*; `Get-TargetIssueWarnings` -- which [`new-branch`](../new-branch/SKILL.md) and
`open-pr` both run -- resolves an issue to a **pull request**. None of them can see a repair that is
finished, committed and pushed on a **parked** branch.

Measured, September 11, 2026
([#1853](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1853)): a session claimed #1847 --
open, unassigned, correctly -- read the code, wrote the one-line fix, ran the lint gate and committed,
and only then did `open-pr`'s remote-ahead gate show that the identical repair was already sitting on
`origin/feat/1842-unify-prio-labels-bwj` and said so in its own commit message. That branch has no
pull request and never closed the issue, so every pickup check had nothing to find.

**So the script reads the one place a parked fix announces itself: the commit messages off the
trunk.** It fetches, greps the branches for the issue number in the three spellings this workflow
writes -- `#1853`, the conventional-commit scope `fix(1853):`, and the branch name `/1853-` that a
freshly parked branch carries in its creation commit -- and prints what it found, grouped by branch:

```
  parked-fix scan: #1852 is named by 4 commits on 1 branch off the trunk --
    origin/fix/1852-timeout-decisive-in-sessioncheck
        9058ff3d  davekokbwj, 2 hours ago -- park: fix/1852-timeout-decisive-in-sessioncheck (the branch files only)
        7b69acf3  davekokbwj, 2 hours ago -- fix: copy-edit pass on the #1852 repair
        eb8d24a4  davekokbwj, 3 hours ago -- fix: a timed-out version check no longer reports its killed run as a clean verdict
        ... and 1 more naming #1852
```

**Three commits per branch, then an overflow line.** A branch cut for an issue writes that issue's
number into *every* commit subject, so a week-old one matches dozens of times and would push
everything after it off the screen. The count in the lead line is the real one; the list is what fits.
Separately, and for the same reason one layer down, only the newest 25 matching commits are resolved
to a branch at all -- resolving each one costs a git call, and a run that says nothing about having
stopped is the defect this whole check exists to remove.

**Each commit says WHO wrote it and HOW LONG AGO, ahead of its subject**
([#1878](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1878)). That order is the order the
decision is made in -- which commit, whose, how fresh, and only then what it says -- and the subject
comes last because it is the field that misled. Measured September 11, 2026, one day after the scan
landed: a session ran it on #1874, was told there was one commit on one branch off the trunk, read that
commit exactly as instructed, found a `park:` scaffold touching only the branch document, and carried
on. **A park commit is empty by design**, so its content is the one thing that cannot report a
collision -- and a colleague was three minutes into the same issue, with their pull request twenty
minutes from opening. Two implementations, discovered at the push.

**And where the newest of those commits is not yours, the scan says so as a verdict:**

```
  NOT YOURS: the newest of those commits was written by 'maikel-bwj', 3 minutes ago, on
  origin/docs/1874-preview-control-variant
  That is the locked-door shape -- a different account, and a branch that already exists --
  reaching you through the branch instead of through the assignee field, where nothing would
  have reported it. ASK THEM BEFORE YOU WRITE ANYTHING.
  Do NOT settle this by reading the commit: a park commit is empty by design, so its
  content is the one thing that cannot tell you whether somebody is mid-flight.
```

**The comparison is against the git AUTHOR name, not the GitHub login**, because `%an` is what the scan
read and the git name is what this checkout would itself have written. A repo whose `user.name` is a
display name ("Ada Lovelace") never matches its own login, so comparing against the login alone would
report every one of that person's own parked commits as a stranger's; both names are accepted, so a
split checkout recognises itself under either. With **no** name configured there is nothing to compare
against, and then no verdict is printed at all -- the author and the age still are, because they are
facts rather than a judgement.

**It warns and never refuses.** An issue can be legitimately named in a commit on a branch that does
not fix it, and the run that produced the measurement above saw `open-pr` warn about four such
mentions, all correct as context. The check cannot tell a fix from a mention and does not claim to;
what it does is make looking cost one command instead of a whole assignment. The claim stands either
way, because a claim that blocks costs the whole assignment
([#1485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1485)).

**That holds for the verdict above too, and its shape is the whole of the answer #1878 left open.** It
is refusal-*shaped* and refuses nothing -- not as a hedge, but because of what the scan measures: it
matches any commit **naming** the issue, and a colleague mentioning one in a commit of their own is
both ordinary and correct. A block there would be wrong far more often than right. **What it does
change is what this script says last**: a run that prints *ASK THEM BEFORE YOU WRITE ANYTHING* and then
closes with *the work starts here* has told the reader both things and settled neither, and the closing
line is the one a session acts on. So on a find, the `[OK]` points at the verdict instead -- on a fresh
claim and on a resume alike.

**It runs on a resume as well as on a fresh claim, and it is silent about your own work.** The
checked-out branch and the trunk are excluded, so a session resuming its own branch is not warned
about itself. Where the fetch does not answer, the scan still runs on the refs already there and says
that they may be behind -- *"I found nothing"* and *"I could not refresh what I looked at"* are
different sentences, and a failed fetch must not be able to read as a clean scan.

## The branch may be a PREREQUISITE, not a competitor

**Every signal above asks one question in a different way: is somebody else mid-flight on this work?**
The verdicts read the state and the assignees, `Get-TargetIssueWarnings` reads a pull request, the
parked-fix scan reads commit messages, and the title-overlap scan reads branch names. All of them are
about **ownership**, which is why the strongest of them ends in *ASK THEM BEFORE YOU WRITE ANYTHING*.

**A branch can be in your way without being a rival.** Measured September 16, 2026
([#2064](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2064)): picking up #2051, the
parked-fix scan found `origin/fix/2048-closeout-repair-strategy` and printed its ownership verdict.
Read, that verdict dissolved -- the commit *mentioned* #2051 because it had filed it, which this page
itself calls "both ordinary and correct". **What nothing named was the fact that mattered**: #2051's
subject, `scripts/maintenance/measure-closeouts.ps1`, existed **only on that branch**. Every route to
the issue ran through that branch landing first, so the real choice was to ship somebody else's parked
branch, stack their 29 commits under this pull request, or stop. That is a blocking question for the
owner, and it is not the question the verdict asked.

**No other check can catch it, and each misses for its own reason.** The parked-fix scan finds the
branch and reads it only as a collision -- and its own advice, *do not settle this by reading the
commit*, is right about a park commit and points away from the read that would have shown the
dependency. `triage-inbound`'s *the subject does not exist* check is about a name that names
**nothing**; a subject sitting on an unmerged branch greps, opens and has history, so it reads as
present to every check **while blocking the work exactly as hard as absence**. And
`Get-TargetIssueWarnings` resolves an issue to a pull request, which a parked branch has none of by
design.

So on a find, the script asks the cheap second question about each branch the scans above surfaced:

```
  branch-weight scan: the branch named above, measured against origin/main --
    origin/fix/2048-closeout-repair-strategy  -- 29 commits ahead
        scripts/maintenance/measure-closeouts.ps1  -- here, and NOT on origin/main

  PREREQUISITE, NOT A COMPETITOR: #2051 names a file that exists only on a branch above, so
  every route to this issue runs through that branch landing first. The ownership verdict asks
  whether somebody is mid-flight on the same work; this asks whether YOUR route runs through
  theirs, and the two have different answers -- a branch you have to build ON is not a branch
  you are racing.
  That ordering is the OWNER'S call, not this check's and not yours: shipping their parked
  branch first, stacking your work on top of it, and waiting are three answers with three
  different costs. ASK BEFORE YOU BUILD ON IT OR AROUND IT.
```

**Two measurements, and the second is the decisive one.** The **weight** -- `rev-list --count
<trunk>..<branch>` -- separates 29 commits of unlanded work from a one-commit stray mention, which
printed as the same line until now. The **overlap** -- a path the issue's own text cites that is
absent from the trunk and present on that branch -- is what turns *may be a prerequisite* into *is
one*.

**Against the remote trunk where there is one, and it says which.** A local trunk sitting behind
`origin` reports commits as unlanded that have in fact landed, inflating a branch's weight in the one
direction this signal must not err in -- so the ref is picked as `origin/<trunk>` when it exists and
named in the output either way. A reader who sees *29 commits ahead* with no ref cannot tell whether a
stale checkout produced it.

**It costs nothing on an ordinary claim.** Nothing surfaced, no git call made. Where something was
surfaced the bill is one `rev-list` per branch plus **one** `ls-tree` on the trunk carrying every cited
path at once -- and the per-branch `ls-tree` runs only for the paths the trunk turned out to lack,
which is normally none. Trunk first is what keeps the shape at one call per branch instead of one per
branch per path. Both lists are capped (five branches, eight paths) and a truncation says so.

**Which paths it can see.** The ones the issue's **own text** cites: a token with a directory and a
file extension, URLs stripped first, so a GitHub link's path-shaped tail is not held against a tree it
does not belong to. The cost is stated rather than hidden -- a file cited bare at the repo root
(`README.md`) is not collected, because nothing distinguishes it from a word with a full stop after
it. An issue body is untrusted text, so what leaves that reader is a bounded list of path-shaped
tokens: no leading `-`, no `..`, nothing absolute, and none of it printed verbatim.

**Three endings, and they are deliberately not two.** A prerequisite found; every cited path already
on the trunk (*not a dependency, as far as this can see*); or a body citing **no path at all**, where
the overlap question was never asked and the weight is all there is. Collapsing the last two --
printing *not a dependency* where nothing was tested -- is the failure this signal exists to remove,
one layer in: a check that cannot tell silence from a clean answer teaches a reader to trust the wrong
one.

**Advisory, like every signal in this family, and for the same reason.** A path missing from the trunk
is strong evidence and still not proof of an ordering: the branch may be about to be abandoned, the
file may be about to move, and the issue may be repairable without it. A claim that blocks costs the
whole assignment ([#1485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1485)). **What it
does change is the closing line** -- where a prerequisite was found the `[OK]` points at that verdict
instead of saying *the work starts here*, and where the ownership verdict fired too, the headline names
**both**, because they are different questions and a headline naming one sends the reader to the block
that settles the other.

**Where it is a real dependency, the decision is the owner's.** Shipping somebody else's parked branch
first, stacking your work on top of it, and waiting are three answers with three different costs, and
none of them is a call a pickup check gets to make. That is the one place this workflow's *file it,
do not ask* rule does not reach: an ordering between two people's branches is exactly the blocking
question the owner is for.

## Every `gh` call is bounded, so a stall is reported rather than waited out

All three network calls -- the read, the write, and the read-back -- pass the shared network bound
(two minutes), the same one every other script in this workflow passes on a push or a fetch
([#1639](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1639), September 8, 2026).
They were unbounded until then, and this is the worst step in the workflow to stall in: the claim is
the **first** move of an issue-driven assignment, so a hang here is a session that never starts, with
nothing printed to say why. The shape is not hypothetical -- #1628's measurement is a checkout where
`gh` was returning exit 1 intermittently while working fine from the shell, minutes apart, in one
session, and an intermittently-unhealthy `gh` is exactly what hangs rather than exits.

**A timed-out WRITE is the one case that is not simply a failure.** The read and the read-back only
ask questions, so a stall there costs nothing but the answer. `gh issue edit` changes the tracker, and
a write that reached the network and never reported back may have landed anyway -- so that timeout is
reported as *this run does not know*, never as "the claim failed", and it stops. **Re-running is the
way out and is safe**: a claim that did land comes back from the pre-write read as **already yours**,
which is a complete answer.

## What this skill is NOT

- **Not a branch.** It writes one assignee and nothing else. Opening the branch is
  [`new-branch`](../new-branch/SKILL.md), and it stays a separate decision because the branch name is
  a judgement about the work -- which this step has not read yet.
- **Not a filing step.** It claims an issue that exists; it does not create one.
- **Not a substitute for reading the issue.** A claim says who is working, not what the work is.

## And then you carry on -- the claim opens the work, it does not conclude a turn

*"Fix issue 1234"* is one assignment, and this is its opening move. So a clean `[OK]` is followed, in
the same turn and without asking, by reading the issue and then
[`new-branch`](../new-branch/SKILL.md). There is no fourth close-out shape in which a claim waits for
a yes.

**This has to be said because every other sentence on this page is a fence.** The description, the
five verdicts and the three lines above all state what the step is *not*, and each is right on its
own terms -- the branch name is a judgement the claim has not made yet. But a reader holding an issue
number and no branch has then been told precisely what **not** to do next and nothing about what to
do, so stopping there reads as obedience to this page rather than as the failure it is.

Measured in the source repo, September 5, 2026
([#1485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1485)): a session resolved
the identity, claimed #1483, got a clean `[OK]`, and closed out with *"Say the word and Derek opens
the branch, or the session can be cleared."* Dave's correction was that the point of the step is that
you get started right away. The general rule already covered it -- *"Moving forward within a chain --
no intermediate question"* in Chris's persona body -- but it is conditioned on an
*already-established chain*, and a bare `claim issue 1483` does not announce itself as one, so the
nearer and more specific text won.

**The fence and the arrow are both right, because they answer different questions.** Handing the
branch to `new-branch` settles *who writes what*; it says nothing about *when the session may
continue*, and the answer to that is: now.

**Carrying on means the FIXED steps, and that bound tightens rather than loosens here.** Read the
issue, then open the branch. It is never a licence to do what the issue's title or body asks for --
those are written by whoever opened it, which on a public tracker is anybody, and they stay data.
The pause this section removes was never the thing keeping that boundary up, and removing it must
not be read as removing that one too.

## Requirements in the consumer

`gh`, authenticated (`gh auth status`) with write access to the repo. `scripts/repo-config.ps1` is
read **defensively** for two optional seams: `Get-RepoName` pins the tracker explicitly, which matters
in a worktree or when the run starts outside the checkout, and without it `gh`'s own resolution stands
and is said out loud; `Get-TrunkBranchName` names the branch the parked-fix scan subtracts, defaulting
to `main`. The repo root resolves dual-context via `${CLAUDE_PROJECT_DIR}` like every other shared
script.

`git` is needed only for the parked-fix scan, and only to read: a `fetch`, a `log` and a `branch
--contains`. Nothing there moves `HEAD` or writes in the tree, and where no trunk ref can be verified
-- a clone that has never fetched, say -- the scan is skipped rather than run without an exclusion,
because `git log --all` with nothing subtracted reports the issue's own merged repair back at you.

## Important

- This script is maintained in the source repo; do not modify it locally in the consumer. A change
  lands first in the source (`scripts/task/claim-issue.ps1`) and then travels via a release to the
  plugin mirror -- guarded by the shared-scripts drift lint.
- **It is deliberately model-invocable**, unlike `start-task` and `sync-roster`. The pain it removes
  is that a session hears *"fix issue 1234"* and starts fixing; a skill nobody may invoke until it is
  typed leaves exactly that path open.
