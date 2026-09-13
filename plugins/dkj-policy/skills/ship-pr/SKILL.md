---
name: ship-pr
description: >-
  Ship a finished branch in one command via the shared, centralized ship-pr script from the plugin
  (single source of truth, issue #411) -- open the PR, wait for CI, merge, fold the changelog entry,
  and verify the issues the PR declared it closes. Stops on the first failure and never forces:
  a failing gate means nothing is pushed, a red CI means nothing is merged. This is the sequence the
  registry classifies safety-critical, because it merges to the main branch and then commits directly
  to it under the fold exception. Use this when a branch is finished, committed, and the repo's
  governance rule allows the PR to be opened.
disable-model-invocation: true
---

# ship-pr — the shared PR chain for consumers

This is the **plugin mirror** of `ship-pr.ps1`: the same tested source as in the source repo,
shared here so consumers do not run the five-step chain by hand. Background in
[issue #411](https://github.com/DaveKJohn/claude-code-specialists/issues/411).

It also documents **`verify-resolved-issues.ps1`**, which is not a separate procedure but this
script's step 6 — see [Step 6 on its own](#step-6-on-its-own-repairing-bookkeeping-after-the-fact).

## When it may run is governance, not script logic

**The script executes; the repo's own rule decides whether it may.** Under the shared rule a finished
branch ships by default once the gates are green, and waits for the owner's explicit word only for
work with a **visible result** (a frontend, styling, rendered output, an artifact — no gate proves
that something *looks* right) or work that is **irreversible or outward-facing** (a release, a version
bump, a tag, repo settings, publishing beyond the PR flow).

That distinction matters more here than for `open-pr`, because this script does not stop at the PR: it
merges and then commits directly to the main branch. Running it is the whole movement, not the first
step of one.

## What the skill does

Run the shared script from the **root of the consuming repo**, on the branch you want to ship:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1"
```

**In the source repo, run its own copy instead — `scripts/release/ship-pr.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

**Nothing is passed, because there is nothing left to say.** Since
[#506](https://github.com/DaveKJohn/claude-code-specialists/issues/506) the PR title is composed from the
branch prefix and the entry's `Branch title` section, so it was already written when the branch was
created. `-Title` is still accepted and ignored, and is forwarded to `open-pr` only when you actually pass
one — see the [`open-pr` skill](../open-pr/SKILL.md) for why the parameter was kept rather than removed.
Running from the main branch is refused before anything happens — this ships a branch.

The six steps, stopping on the first failure:

1. **Open the PR** via `open-pr.ps1` — which runs the resolves gate, the scaffold gate, the impact gate,
   the step-list gate, the repo's own
   lint gate and all test suites, then pushes and opens. If any of those fails, nothing is pushed and
   this stops here. See the `open-pr` skill for what those gates check.

   **A branch whose PR is already open is resumed, not refused.** `open-pr.ps1` skips only the
   `gh pr create` in that case — the gates and the push still run — so this step succeeds and the chain
   carries on to step 2. Until August 4, 2026 it did not: the create was unconditional, a duplicate
   returned non-zero, and **steps 2-6 never ran**, so a branch whose PR was opened in an earlier session
   had to be merged and folded by hand. An existing PR keeps its own title — as every PR now does, the
   title being composed at creation and never rewritten afterwards — while
   `-Resolves` is still honoured — the closing keywords are appended to the existing body, because
   step 6 verifies exactly what the merged body declared. Measured on
   [PR #457](https://github.com/DaveKJohn/claude-code-specialists/pull/457).
2. **Find the PR number** for the current branch (`gh pr list --head <branch> --base main`).

   **`--base main` is load-bearing.** Without it the query asks "does this branch have an open PR
   *anywhere*", so if you run **stacked PRs** (`branch -> branch -> main`) the answer can be the stacked
   one — and step 4 would merge it into its intermediate base. GitHub allows one open PR per
   `(head, base)` pair, so with the base pinned there is at most one answer.

   This step also used to mis-parse gh's answer, repaired August 4, 2026: its "no open PR found" guard
   could never fire and a missing PR arrived as the empty string, so the script would have run
   `gh pr merge ''`. Worth knowing if you are on an older version of the plugin — the symptom is a
   `ship-pr` run that reports no PR number and then fails at the merge with an unhelpful gh error.

   **And then the checkout goes home, before the wait rather than after it (step 2b).** In the primary
   checkout, on a clean tree, with nobody else holding the trunk, `HEAD` moves to the main branch here —
   so a backgrounded ship leaves the session where a finished chain leaves it. Never a refusal; a tree
   that cannot go home stays where it is and says why. See
   [And stopping now leaves the checkout on the trunk](#and-stopping-now-leaves-the-checkout-on-the-trunk-1073).
3. **Wait for CI.** See [Why step 3 polls before it watches](#why-step-3-polls-before-it-watches).

   **Then, has `main` moved since the run that certified this PR (step 3b)?** A required check tests
   GitHub's merge ref as it stood when its run was created and is never refreshed if `main` moves
   afterward, so a green check can go stale before the merge. See
   [Has `main` moved since the certifying run?](#has-main-moved-since-the-certifying-run-1292).
4. **Merge** (`gh pr merge`), but first the **step-list gate again**: the phases above the DEPLOY heading in
   `dkj-policy/<branch>.md` must
   have nothing unresolved left in them, or the merge does not happen. Not belt-and-braces — the rule is
   about the *merge*, and step 1's copy of it lives in `open-pr.ps1`, which has a `-Force`. A PR opened
   through that valve, by hand on github.com, or days ago and resumed here would otherwise land with an
   unfinished plan. Checked here rather than trusted from step 1, against `refs/heads/<branch>` rather than the
   working copy, and there is no `-Force` for it: `- [~] dropped -- <why>` is the way past a step that should
   not be done.
   The three marks are in the `open-pr` skill and in [`DEVELOPMENT-portable.md`](../../DEVELOPMENT-portable.md).
   See [The merge method is repo policy](#the-merge-method-is-repo-policy), and
   [which copy of the document both gates read](#the-two-merge-gates-read-the-branchs-commit-and-why-they-used-to-read-the-tree).
5. **Check out the main branch, fast-forward, and fold** — handed to `fold-changelog-entry.ps1 -Push`,
   which folds the entry, commits it and pushes it. See
   [Why the fold is delegated](#why-the-fold-is-delegated-rather-than-inlined) and
   [losing that fold to `fold-on-merge` is a success](#losing-the-fold-race-is-a-stood-down-success-not-a-failed-ship-1792).
6. **Verify the issues the PR declared it closes are actually closed**, and close any that are not.

## The parameters

| Parameter | What it does |
|---|---|
| `-Title` | **Accepted and ignored** since [#506](https://github.com/DaveKJohn/claude-code-specialists/issues/506). The PR title comes from the entry's `Branch title` section; passing one here forwards it to `open-pr`, which warns and names the title the entry actually gives. |
| `-NoMerge` | Open the PR and stop — no CI wait, no merge, no fold. The same as calling `open-pr` directly, but convenient when scripting. |
| `-Resolves` | Passed through to `open-pr`: the issues this PR closes, **as a string** (`"331,332"`). Step 6 verifies them. |
| `-NoResolves` | Passed through to `open-pr`: declare that this PR closes no issue. Needed **once per branch**, not once per command: since [#1912](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1912) `open-pr` records the answer in the PR body, so this script's step 1 — which re-runs `open-pr` — reads it back instead of refusing. |
| `-SkipLint` | Passed through to `open-pr`: skip the lint gate. An escape valve. |
| `-SkipTests` | Passed through to `open-pr`: skip the test gate. An escape valve. |
| `-MaxParallel` | Passed through to `open-pr`: how many test suites its gate runs at once. `0` (the default) forwards nothing and leaves the gate's own resolution — `ProcessorCount - 2`, floor 2 — untouched. **Reach for this before `-SkipTests`** when the gate will not finish: it runs the suites smaller instead of not at all, so the run still measures. See the [`open-pr` skill](../open-pr/SKILL.md#when-the-test-gate-will-not-finish--maxparallel-not--skiptests). |
| `-SkipStaleCheck` | Skip step 3b's certificate-staleness check (issue #1292): merge even though `main` gained a commit after the run that certified this PR was created, or that check could not be completed at all. Use it only when the situation is known-harmless — e.g. the commits `main` gained are docs-only, or you have confirmed by hand that the certificate is sound. |
| `-Force` | Passed through to `open-pr`: ship an entry that still carries its scaffold wording. Deliberately separate from `-SkipLint`/`-SkipTests` — those skip a tool, this overrules a judgement about content. |
| `-RefreshBody` | Passed through to `open-pr`: on a branch whose PR is **already open**, rewrite that PR's description from the current changelog entry. Opt-in, so a body edited on github.com is never overwritten unasked. No effect when the PR is created in this run. |
| `-PollSeconds` | Poll interval in seconds for the CI wait. Default 15. |

**Reach for `-RefreshBody` on a branch you extended after opening its PR.** Without it the PR keeps
describing an earlier version of the work while the merged changelog entry carries the new one — and the
entry is what ends up in the release notes, so the two disagree in the place people go looking. Only the
description section is touched; see the [`open-pr` skill](../open-pr/SKILL.md#resuming-a-branch-whose-pr-is-already-open)
for exactly what is preserved.

**`-Resolves` takes a string on purpose, and this is the one parameter where the type is load-bearing.**
Across `powershell -File` a comma list is cast to a single number via the thousands separator, so an
`[int[]]` would silently turn `-Resolves 332,340` into issue `332340` — no error, just the wrong issue.
This script hands the raw string on to `open-pr`, which parses it there, precisely because the hop goes
through `powershell -File`.

```powershell
# ships and closes two issues
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1" -Resolves "331,332"

# open the PR only, e.g. to wait for a review
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1" -NoResolves -NoMerge
```

## The two merge gates read the branch's COMMIT, and why they used to read the tree

Both gates in step 4 read `dkj-policy/<branch>.md` as **`refs/heads/<branch>` has it** —
the commit, not the file on disk. Which is the document the merge is about to merge, so it is the document the
gates judge.

**They read the checkout until August 27, 2026, and the script's comment explained why:** *"Read from the
branch's own checkout, which is where HEAD still is at this point -- step 5 is what moves to main."* True of
an ordinary foreground run, and an **assumption rather than a check** — nothing compared the branch you were
standing on against the branch whose PR was merging.

**It broke twice, in two different shapes.** On **August 20, 2026** two sessions shared one checkout: one had
`ship-pr` waiting on CI, the other created a branch and moved `HEAD`. On **August 27, 2026** it needed no
second session at all (issue [#970](https://github.com/DaveKJohn/claude-code-specialists/issues/970)) — one
session backgrounded the ship, started the next piece of work while CI ran for 10m57s, and the gate read the
new branch's freshly scaffolded list. Both times it refused over
`- [ ] TODO: the first step of this branch`, a step belonging to nobody's work on that PR, while the PR's own
list was complete and committed.

**Neither instance damaged anything, and that is what made the second one the evidence.** The refusals were
safe and re-running from the right branch picked up where it left off. But the assumption fails the other way
too — a tree standing on a *finished* branch lets an unfinished one through — and **that direction is silent**:
a gate with no `-Force`, satisfied by a file the PR does not contain, reports the requirement as met while
nothing checked it. One benign instance was written down rather than repaired; two, the second of them needing
only the script's own ordinary usage, are a defect.

**The repair is the read, not a new refusal.** Refusing once `HEAD` has moved was the other shape on the table
and was declined: backgrounding a ship and starting the next thing is the ordinary shape of that window, so the
guard would break the ordinary case in order to protect it. The commit needs no network either, which matters
in a gate that must not refuse because a token expired. Two things follow that are worth knowing at the
keyboard:

- **A step ticked in the editor and never committed no longer gets past the merge gate.** It used to. Both
  messages have always said *"commit, and re-run"*.
- **`refs/heads/<branch>` is what step 1 pushed**, on every path through this script — a fresh PR and a resumed
  one alike — so there is nothing extra to do to keep the two in step.

**The wider rule this belongs to has since been closed at its last open point.** These scripts assumed one
working tree per session; the gates stopped depending on it here, and step 5 stopped depending on it in
[#972](https://github.com/DaveKJohn/claude-code-specialists/issues/972). Nothing in this workflow locks a
checkout — no script claims one, and none ever did. What changed is that no script silently moves one either.

## The wait runs in the background, and that is the default

**Do not hold a session open for the length of CI.** Start this script as a background command and carry
on; the merge cannot happen before the required check is green either way, so a foreground wait buys only
a second look at a result the local gate has already given. Measured in the source repo on
[PR #980](https://github.com/DaveKJohn/claude-code-specialists/pull/980) (August 27, 2026): `lint-en-tests`
took **11m48s**, while the same suites had run locally minutes earlier in **292s**. Over 65 blocking runs
the CI leg has a median of **8m 01s**, which at 73 merged PRs in a week is **9h 45m** of session time
spent watching a second opinion. Dave, [issue #985](https://github.com/DaveKJohn/claude-code-specialists/issues/985):
*"dit kan gewoon gerust in de achtergrond verder draaien"*.

**One habit comes with it, and it is no longer a condition.** So the session's next move is one of two
things:

- **open the next branch as a lane** — `worktree-lane.ps1 -Name <name>`, the
  [`worktree-lane` skill](../worktree-lane/SKILL.md); or
- **stop.** A close-out that says *"PR #N opened, shipping in the background"* is a finished assignment,
  not an open point — nothing about an in-flight ship needs answering before the session can be closed.

**But "stop" is not "quit", and the invitation now says so** ([#1428](https://github.com/DaveKJohn/claude-code-specialists/issues/1428)).
The run is **not detached** — that was considered and declined on purpose, because a detached watcher would
merge and fold onto the trunk with nobody reading the output — so it is a child process of the harness and
dies with it. Measured ancestry of a backgrounded run, September 5, 2026: `powershell.exe ← bash.exe ×3 ←
claude.exe ← Code.exe`. Two commits are still owed at that moment, and the **fold** is the one that bites: a
merge that never lands leaves the pull request open and visible, while a merge without its fold leaves the
branch's document stranded on the trunk — the state `check-unfolded-entry.ps1` was built for in
[#1270](https://github.com/DaveKJohn/claude-code-specialists/issues/1270), reached by a route that issue did
not consider. So the printed invitation says *"nothing here needs **you**"* and names what it holds; it said
*"nothing here needs the session"* for nine days, and a close-out inherited that as a conditional clearance
the owner could not read.

#### And what the owner MAY do is a second terminal — say that, not only what is unsafe

**Withholding a clearance and offering nothing in its place is the worse half of the same defect.** Dave,
September 5, 2026, on what he was actually after: *"Een PR-ship duurt soms 10 minuten. Ik wil niet zitten
wachten."* The point of backgrounding is to get on with the next issue, and a line that only says *"do not
quit"* leaves the reader holding a session he no longer wants and cannot safely release. **A second
terminal beside this one answers it and asks nothing of the process:** terminal 1 stays alive, so the merge
and the fold complete *and* the completion notification lands in a conversation that still exists — the
vanished-outcome problem solved rather than mitigated; terminal 2 carries the next issue, so nobody waits.

**One timing rule, and the ship prints its own go-ahead.** Step 1 is the only step that reads the **working
tree**, so this checkout is single-occupancy while its lint gate and suites walk it — measured on
[PR #1144](https://github.com/DaveKJohn/claude-code-specialists/pull/1144), one suite of 55 red inside the
gate and green standalone on the same commit seconds later
([#1145](https://github.com/DaveKJohn/claude-code-specialists/issues/1145)). Everything from step 2b down
reads refs and the PR instead, deliberately, which is what lets the tree go home before the CI wait. So:

> Wait for terminal 1 to print `ship-pr: waiting for the CI check(s) on PR #N`. That line means step 1 is
> over and the tree is free. Then open terminal 2 **in a lane** — `worktree-lane.ps1 -Name <name>` — a
> separate directory, so the two sessions stop sharing a `HEAD` at all.

A lane is detached at `origin/<trunk>` rather than standing on it, so it does not take the trunk away from
step 5's fold either ([#1069](https://github.com/DaveKJohn/claude-code-specialists/issues/1069)).

**And the two sessions share nothing but the tracker**, which is the orchestrator's standing rule and it
bites hardest here: terminal 2 cannot see terminal 1's branch or intent, and under one account the assignee
cannot name the machine. So claim the issue before working it — and **read** the claim as well as write it.

**What is still not measured, and no longer needs to be:** whether a `/clear` leaves the backgrounded run
alive. It follows from the ancestry — the process hangs off `claude.exe`, not off the conversation — and
nobody has cleared a context mid-ship to confirm it. The second terminal removes the reason to: it frees the
*person* rather than the *session*, so the unmeasured row stops being load-bearing. Until somebody measures
it, no document claims either answer.

### And stopping now leaves the checkout on the trunk ([#1073](https://github.com/DaveKJohn/claude-code-specialists/issues/1073))

**That second move used to be only half true**, and the missing half is the one the owner reads. The
orchestrator's own body carries two rules about this moment — *"parking is a state, not a promise to come
back within the turn"* and *"it ends on the trunk, which is what makes the session safe to clear"* — and
until step 2b existed a backgrounded ship could not satisfy both. `HEAD` did not move until step 5, after
the CI wait, so at the moment the close-out was written the tree was necessarily still on the branch.
Following the first rule meant breaking the second. Dave, after being handed exactly that session:
*"ik wil pas een sessie sluiten als ik terug op de main branch ben. Dat is voor mij het teken dat de sessie
veilig gesloten kan worden."*

**Step 2b hands the trunk back as soon as the PR exists**, before the wait rather than after it — so the
close-out can say both things at once. It is available because two earlier repairs already landed: since
[#970](https://github.com/DaveKJohn/claude-code-specialists/issues/970) both merge gates read
`refs/heads/<branch>` rather than the working copy, and since
[#972](https://github.com/DaveKJohn/claude-code-specialists/issues/972) step 5 reads `HEAD` before it moves
anything. Read together they say something neither one set out to: **nothing after step 2 reads the content
of the working tree.** Step 3 is `gh` over the network, step 4 is the ref plus `gh`, and step 5 folds
wherever `HEAD` already is — `main` being one of the two arms it has had all along.

**Three conditions, and it is never a refusal.** A tree that cannot go home stays where it is, says which
of the three it was, and the ship carries on:

| condition | why, and what skipping it costs |
|---|---|
| **the primary checkout only** | a lane taking the trunk here would hold the clone-wide lock of [#1069](https://github.com/DaveKJohn/claude-code-specialists/issues/1069) for the whole CI wait instead of for the length of a fold — worse than the defect that repair closed. A lane goes home at step 5b instead |
| **nobody else holds the trunk** | git allows one worktree per branch, so the checkout would simply fail. Asked rather than attempted, because failing here is free |
| **a clean tree** | #972's two outcomes met one step earlier: a colliding edit makes the checkout exit 1, and a non-colliding one **travels to the trunk**. The branch's own work is committed and pushed by step 1, so anything left here is something else |

**One thing it buys that was not the point.** A concurrent lane-ship that would have collided with the
primary's step 5 — the narrow window step 0 cannot cover — now meets step 0's own refusal instead, because
the primary takes the trunk before the wait rather than after it. A post-merge half-state becomes a
pre-push refusal, which is the trade step 0 was written for.

The decision itself is `Get-TrunkReturnDecision` in `worktree-lib.ps1`, a pure function of the porcelain
plus `git status --porcelain`, so it is asserted in `worktree-lib.tests.ps1` rather than only exercised by
a live ship.

**And the go-ahead line READS that decision rather than asserting an outcome**
([#1616](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1616)). For three days it carried
the trunk clause as a literal — `step 2b already put it back on the trunk` printed with no condition on it
— so on every run where one of the three conditions above declined, the one line a reader is told to act
on contradicted the line four rows above it. Measured on
[PR #1615](https://github.com/DKJ-Solutions/claude-code-specialists/pull/1615), September 8, 2026, where
what declined it was a single unrelated modified file the branch had deliberately left alone. It is
`Get-TrunkReturnGoAheadLine` now, in the same lib and asserted in the same suite: the yes arm is word for
word what it was, and the no arm names the branch this checkout is standing on and points at the lane
instead — a lane is detached at `origin/<trunk>`, so it is unaffected by where the primary happens to
stand. **Both arms keep the two clauses that are true either way** — step 1 is over, the tree is free —
because withdrawing those along with the trunk clause would cancel the invitation the line exists to make.

**And a ship that does not survive the wait can be resumed from the checkout it left behind**
([#1620](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1620)). The hand-back has a
price, and this is it: for the whole CI wait — the longest step in the run — `HEAD` says `main` while the
branch's merge and fold are still owed, so re-running `ship-pr` from that checkout met
`You are on main; ship-pr runs from a branch`, a refusal about the wrong problem. Measured on
[PR #1618](https://github.com/DKJ-Solutions/claude-code-specialists/pull/1618), September 8, 2026, where the
backgrounded process was killed by the host for low memory; `git checkout <branch>` and the same command
resumed correctly, `open-pr` skipping the create for the PR that already existed. **Nothing was ever at
risk** — both merge gates read `refs/heads/<branch>` ([#970](https://github.com/DKJ-Solutions/claude-code-specialists/issues/970)) — what was lost was the operator knowing what to do.

**The front door now diagnoses instead of restating the rule.** Standing on the trunk is still refused, and
the sentence is unchanged; under it, where an open PR's head branch is a branch **this checkout has**, the
refusal names the PR, the branch and the `git checkout` that resumes the ship. The pair is the whole signal
and the local half is what keeps it quiet: measured in the source repo the day it was written, 26 local
branches against 1 open PR whose head ref was not here — so the answer was *no candidate*, with 25 merged
leftovers producing no noise at all. `Get-InterruptedShipCandidates` decides and
`Get-InterruptedShipResumeNote` words it, both in `pr-issues-lib.ps1` and both asserted in
`pr-issues.tests.ps1` — the same decision/wording split, for the same reason, as the go-ahead line above.
It is **best-effort**: two reads, neither load-bearing, so a `gh` that cannot answer leaves the refusal
exactly as it has always been. And it prescribes no `-SkipLint`/`-SkipTests`: a resume re-runs the local
gate against a commit CI is already testing, and whether that should be skipped by default is a separate
question this remedy deliberately does not answer for you.

**Why #1588's repair does not cover this**, since both are the same message from the same root cause. That
one put the checkout at the head of the *stale-CI refusal's* printed remedy, which reaches a run that gets
as far as printing one. An interrupted process prints nothing — no refusal, no remedy, no next line — and a
kill usually takes the scrollback with it, which is why the state had to be recognised at the front door
rather than described in a message the operator never sees.

**Working in the primary anyway used to cost you your checkout, and no longer does.** Step 5 ran
`git checkout main` in the tree the script was started from, unconditionally, one line after the merge.
Measured on git 2.54.0.windows.1 for
[#972](https://github.com/DaveKJohn/claude-code-specialists/issues/972), that had exactly two outcomes:

| the tree when the merge lands | `git checkout main` |
|---|---|
| an uncommitted edit that collides with the trunk | **exit 1** — `"Your local changes ... would be overwritten by checkout"`. The run stops between the merge and the fold: PR merged, branch document still in the tree, every gate green until a release trips over it |
| an uncommitted edit that does not collide | **exit 0** — `HEAD` moves to the trunk **and the uncommitted work travels with it**, so the session carries on editing on `main` with its own work already sitting there |

Step 5 now reads `HEAD` first. Still on the shipping branch, or already on the trunk: it runs exactly what
it always ran. Anywhere else: it leaves your checkout alone and folds in a throwaway `git worktree` on the
trunk instead, then takes it down again. The lane is still the better move — it is where you build, and it
keeps one tree doing one thing — but forgetting it now costs a temporary directory rather than your work.

### And a lane no longer holds the trunk hostage ([#1069](https://github.com/DaveKJohn/claude-code-specialists/issues/1069))

git allows **one worktree per branch**, so a tree standing on the trunk locks it for the whole clone.
That is the other half of the same line: step 5 checks the trunk out *in the tree it runs in*, and in
the primary checkout that is deliberate — a finished chain ends on the trunk, which is what makes the
session safe to clear. In a lane it meant the lane held the trunk for **every later chain on the
machine**, nothing warned, and the bill was paid by an unrelated branch after *its* merge had landed.
Measured on PR #1068: merged, unfolded, changelog still pending.

Three answers, and the order is the point:

| when | what happens |
|---|---|
| **before step 1** (step 0) | another worktree holds the trunk → **refuse**, naming that directory and the two commands that release it. Nothing is gated, pushed or merged yet, so this is the one place where stopping is free |
| **at step 5**, in-place arm | the narrow window step 0 cannot cover — another session took the trunk while CI was being watched. It now prints the same hand-fold instruction the worktree arm always had, including the `-RepoRoot` call that folds from the tree that *does* hold it |
| **after the fold** (step 5b) | a tree that is **not** the primary checkout returns to its own branch, releasing the lock. Only after a *successful* fold: a failed one leaves you standing on the trunk, which is where a hand repair happens |

**Nothing takes the trunk away from anybody.** The holder may be a lane with work in it, and this script
does not know what — so both arms name the directory rather than acting on it. Handing a finished lane
back is still `worktree-lane.ps1 -HandBack`, and it is still the better move than relying on step 5b.

`prune-merged.ps1` was unavailable in exactly this state too, which mattered because it is the script a
session is told to run *instead of* hand-reading `git ls-remote`. It **runs** in this state now
([#1147](https://github.com/DaveKJohn/claude-code-specialists/issues/1147)): it advances the trunk with a
refspec fetch rather than a checkout, so a held trunk costs it the fast-forward and nothing else — and the
warning still names the worktree holding it instead of relaying git's message.

**What this deliberately is not.** Two larger shapes were named and declined when the default was written
down. A *green-and-unmerged reporter* at session start would re-add half of a status reporter the source
repo had removed on purpose five minutes before #985 was filed. A *detached watcher* that merges when the
check passes would put the merge and the fold — a commit that lands directly on the trunk under a named
exception — behind a process nobody is reading. Neither is ruled out forever; both need designing rather
than adopting, and #985 stays open as their home.

**Backgrounding tells you nothing while it runs, and that is normal.** The output is buffered, so an empty
log and an idle `gh` child are not evidence of a stall. Judge progress from `git log` and `gh pr view`, never
from the log file.


### And it will not merge what it cannot fold ([#1278](https://github.com/DaveKJohn/claude-code-specialists/issues/1278))

The section above asks whether step 5 can **check out** the trunk. This one asks whether it can **push**
to it, and it is the same half-state by a second route.

The fold is a **direct push** — one of the three named exceptions to *"never commit directly on the
trunk"*. A required status check cannot be satisfied by a direct push: the pushed commit carries no
checks, so the ref update is refused before any workflow could run. Which means an account can be fully
entitled to **merge** — the PR's own check ran and passed — and not entitled to **fold**. Measured on
PR #1271, September 3, 2026: `ship-pr` merged, checked out the trunk, folded, committed, and the push
came back

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Required status check "lint-en-tests" is expected.
```

leaving the trunk merged-but-unfolded. Not once — **every** run from that account, because the cause is
the ruleset rather than the run.

So step 0 now asks the question before step 1, for two `gh` reads:

| read | what it answers |
|---|---|
| `repos/<repo>/rules/branches/<trunk>` | which rules apply to the trunk. It does **not** filter by bypass — measured: it returns `required_status_checks` to an account whose `current_user_can_bypass` is `always` — which is exactly why a second read is needed |
| `repos/<repo>/rulesets/<id>` (or `orgs/<org>/rulesets/<id>`) | this account's `current_user_can_bypass` on the ruleset carrying it. The list endpoint returns that field as `null`, so it cannot be had in one call |

**Three rule types block a fold**, and each by its own definition rather than by guesswork:
`required_status_checks`, `pull_request` (the fold is not a pull request — so `pull_requests_only`
bypass is *not* bypass here), and `update`. `deletion`, `non_fast_forward`, `required_linear_history`
and `required_signatures` do not, and a trunk carrying only those ships exactly as before.

**An unreadable ruleset warns; it never refuses.** The opposite posture to the merge verdict at step 3,
and deliberately: there an unread required-check list could put red code on the trunk, while here the
thing at risk is a fold that can be redone by hand or from an account with bypass. Refusing on an unread
ruleset would take `ship-pr` away from every consumer whose token cannot read one — a far larger blast
radius than the defect. Same answer as step 0's own unreadable-worktree arm.

**It takes neither remedy**, and says both: give the account bypass on that ruleset (repo settings, so
it is the repo owner's call), or ship the branch from an account that already has it.
## Why step 3 polls before it watches

`gh pr checks` prints `no checks reported` **and exits 0** while no check has registered yet — which is
indistinguishable by exit code from "everything passed". A bare `--watch` right after the push can
therefore return immediately, and the merge below then runs straight into a `BLOCKED` wall from branch
protection.

So step 3 first polls the *text* until at least one check is registered (up to 180 seconds), and only
then watches it. A non-zero exit from the watch means **not merged** — the script stops rather than
retrying, because branch protection would block it anyway and forcing past a red CI is exactly what
this chain must not do.

**It deliberately does not name a check.** Step 3 watches whichever checks this repo's own ruleset
requires — read from the trunk's **branch rules** (`gh api repos/<repo>/rules/branches/<trunk>`, the
payload step 0b already fetched), never from a name written into the script. `gh pr checks --required`
is the fall-back for a checkout whose token cannot read those rules, and it is second rather than first
for a measured reason: it reports the required checks *that have registered*, so asked seconds after
the push it answers nothing, and cannot tell that from a trunk that requires nothing. The ruleset has
no such race.
Naming one here would be a claim about the consumer's CI that this script cannot keep, and it was the
half of the "this is too repo-specific to share" argument that did not survive being read.

**The non-required checks are still waited for and still reported — at step 8, after the fold**
([#1602](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1602), September 8, 2026). Until
then the merge sat behind them, and the trunk goes on moving while it waits: a commit landing between the
last required check and the last check of any kind voids the certificate step 3b then correctly refuses
on, at the price of a whole further CI cycle. Measured over 99 laps that is 5.1% of them — but 62.5% of
the tail-governed laps on the busiest day of the sample, so it is a busy-trunk cost rather than a
background one. Nothing about the merge DECISION changed: a red non-required check has never blocked this
merge, so waiting for one beforehand only decided when that was printed.

### A repo with no required check at all

**A private repository on the GitHub Free plan cannot have branch protection**, so it can have no
required check — and that is the shape most new repos start in. Nothing here needs configuring for it,
and two behaviours are worth knowing rather than deducing ([inbound
#1083](https://github.com/DaveKJohn/claude-code-specialists/issues/1083)):

- **the wait works unchanged**, because with no required check known step 3 watches every check the PR
  has rather than a named one. **That is still true after #1602**, and deliberately so: `--required` is
  added only where the ruleset names something, and "this repo requires nothing" is indistinguishable
  from "the required check has not registered yet" — so the fall-back is the behaviour every ship had
  before that change. A repo without a ruleset therefore also never reaches step 8, which would
  otherwise claim a non-required tail that never existed;
- **the merge verdict refuses on a red check rather than proceeding.** With nothing required,
  `gh pr checks --required` exits non-zero, and *"this repo requires nothing"* is indistinguishable from
  *"the required checks have not reported yet"* — so the verdict blocks. The repo without a ruleset is
  guarded conservatively rather than left open.

**The wait report is not where you learn whether a ruleset exists.** With nothing required it simply
omits the required/not-required label and prints the rest of the line. The fallback —
`waited 2s -- no readable check facts, so nothing to report about the wait` — means something else
entirely: gh answered nothing, or no check in the payload carried a readable completion time. It used to
read *"which check governed could not be read"*, which was reported from a fresh repo as sounding like a
fault; it is a statement about the payload, and never about the ruleset.

### When the required check never appears at all

After 180 seconds step 3 gives up and says so, without merging. That timeout usually means CI is slow —
but it also covers a real failure mode worth recognizing, because the remedy is counter-intuitive:
**the forge sometimes simply fails to fire a run** on the `pull_request opened` event. The tell is a
merge that stays blocked with **no check rollup on the PR at all** while minutes pass. It is a
platform-side hiccup rather than a repo error, and it has been observed with an unrelated PR
triggering normally moments before.

**Confirm there is no run before you retrigger.** A very late run and an absent run look identical on
the PR page, and retriggering a late one creates the second problem below. Ask the API for the head
SHA directly — a total of `0` rules out a run, and also rules out being fooled by an unrelated check
suite from another integration that shows up without being the check the branch is waiting on:

```powershell
gh api "repos/<owner>/<repo>/actions/runs?head_sha=<sha>" -q '.total_count'
```

**Then close and immediately reopen the PR.** The `reopened` event fires a fresh run. Pushing an empty
commit also retriggers CI, but close/reopen is preferred: it keeps the branch history free of noise
commits.

```powershell
gh pr close <branch>; gh pr reopen <branch>
```

**If you retriggered and the original then shows up anyway, expect two runs briefly.** The reopen-run
finishes first and goes green while the late original is still in progress — and during that window the
merge state can drop back to `BLOCKED`, with the merge refused for a base-branch policy. Wait for both
to go green, then merge normally. **Never reach for `--admin` here.** That bypasses the gate the check
exists for, and a forge suggesting it in its own error text does not make it the fix.

### When a not-required check fails, the merge proceeds and ship-pr relays the reason

A required check that goes red is a refusal, and its reason is one you meet first-hand at the local
gate before the push. A **not-required** (advisory) check is the other case: the ruleset does not block
on it, so `ship-pr` merges past it and prints `a check FAILED but the merge is not blocked`. That line
names the check but not *why* it failed, and the red mark is now behind you where nobody re-reads it —
so step 3 also fetches the failing check's annotations and prints the sentence the workflow **wrote
about itself**, right beside the warning.

**It relays a *titled* failure annotation only, and that is the whole contract on your workflow.** A
line your job emits as

```
echo "::error title=<name>::<one sentence on why it failed>"
```

is picked up and printed. GitHub's own Actions runner also writes failure annotations — `Process
completed with exit code 1`, `Action failed with error: ...` — but always with an **empty title**, so
"has a title" is what separates a sentence an author left for this reader from the runner's exit noise.
Nothing keys on a check *name*, so this works in your repo whose workflows the plugin has never seen.

**An advisory check that fails with no titled annotation is silent here on purpose.** A blank reason
line beside the red mark means the job left no sentence behind — not that the relay is broken. If your
advisory workflow has something useful to say about a failure, give it a titled `::error::` line and
`ship-pr` carries it to the operator's console; the first titled failure in the job wins, and warnings
are not read.

## Has `main` moved since the certifying run? ([#1292](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1292))

**The filed reason did not hold, and step 3b follows the corrected one.** #1292 reported "the required
check runs on the branch head" — it does not: `ci.yml`-style CI on `pull_request` tests GitHub's
**merge ref**, the branch already merged into the base tip, so the merge result genuinely is tested.
What verification found instead is a green check going **stale**: GitHub fixes the merge ref at the
moment the run is **created** and never refreshes it if the base moves afterward (`pull_request` does
not re-fire on that), and a ruleset without `strict_required_status_checks_policy: true` lets a stale
green check satisfy the gate regardless. Measured on the instance: a test block that PR #1268's branch
predated reached `main` 45 seconds before #1268's own CI run finished and 14m45s after that run
started, and #1268 merged on that same certificate 2h11m later.

**Why this is "has `main` moved since the run", not "is the branch behind `main`"** — the report's own
filed option. Behind-ness at merge is the ordinary case and is harmless whenever `main` advanced
*before* the certifying run started: the run then tested a merge ref that already held everything it
needed to. Measured on the source repo's last 45 merged PRs: 20 (44.4%) were behind-at-merge, but only
14 (31.1%) actually had `main` gain a first-parent commit *after* their certifying run began — the
narrower predicate step 3b uses. Median staleness among those 14 was 16.1 minutes, max 146.6 (PR #1268
itself). Of the 14, 2 carried a `scripts/**`/`scripts/tests/**` change in the window — the subset that
can actually turn a trunk red — but step 3b does not filter on that: predicting which file a future
test depends on is not this script's to do, and the predicate is already cheap enough (one fetch, one
first-parent log) that narrowing it further would trade a real safety margin for a rarer refusal on no
measured benefit.

**The anchor is the certifying run's own `created_at`, not a check's `startedAt` — re-anchored after a
red-team caught the first build's bias the wrong way round.** The original reasoning ("conservative,
because queueing only pushes `startedAt` *later* than the ref-fix moment") had the direction right and
the choice backwards: a *later* anchor makes `git log --since=<anchor>` **miss** commits that landed in
the gap, so a genuinely stale certificate reads as sound — the one failure this gate exists to prevent.
The gap is far larger than "sub-minute" in this repo for two reasons the original 45-PR sample could
not see: `windows-latest` provisioning routinely costs over a minute between a run's creation and a
job's `startedAt`, and "re-run failed jobs" against a flaky suite (ordinary practice here) re-runs the
*same* commit while `startedAt` jumps forward by however long the operator waited — seconds to hours.
Verified on a genuine re-run in this repo's own history: the run object's `created_at` stayed fixed
across the re-run while `run_started_at` moved over five hours later, and reading the per-attempt
sub-resource directly (`.../attempts/2`) would have reintroduced the identical bias by reporting its
own late `created_at`. Step 3b finds the run behind each required check from the `link` already in
`$checkFactsJson` (no new call for that), then asks `gh api repos/<repo>/actions/runs/<id>` for that
run's `created_at` — the one new network call per certifying run — before the `git fetch origin main`
that reads a current `main`.

**Two things this does not claim.** A `pull_request` run exists at all only for a *mergeable* PR —
GitHub creates none for one with a merge conflict, which is harmless here: an unmergeable PR cannot be
shipped by this script either way. And "GitHub fixes *the* merge ref" is this repo's own practical
experience with a single-job workflow, not a documented contract — different jobs of one triggering
event have been observed resolving different merge commits in the wild
([`actions/checkout#27`](https://github.com/actions/checkout/issues/27)) — so the reasoning holds on
"a run's `created_at` cannot postdate its own ref-fix moment" rather than on a guarantee GitHub does
not make.

**The fail-closed line is drawn in two places, deliberately, and it moved with the re-anchor.** With no
required check named at all, step 3b warns and does nothing — this predicate has nothing to protect on
a repo with no ruleset (the GitHub Free plan case above), and refusing there would permanently block
`ship-pr` on every such consumer; `Get-MergeBlockVerdict` already cannot tell "no ruleset" from
"unreadable" either, so this matches that existing posture. Once a required check *is* named, though,
every subsequent read — the run id, its `created_at`, the fetch, the log — now **fails closed**: the
first build warned and shipped on an unresolved read here, which is exactly the under-refusing bias the
re-anchor exists to close, so an unresolved read now refuses with `-SkipStaleCheck` as the valve.

**Repo-settings option 1 from the same issue** (`strict_required_status_checks_policy: true`) remains
available and closes the gap completely by forcing a re-run on every base move; it is the repo owner's
call, not this script's, and step 3b does not touch it.

## The merge method is repo policy

`gh pr merge` runs with `--merge` by default. A consumer that squashes or rebases declares that in
`Get-PrMergeMethod` in its own `scripts/repo-config.ps1`; the function is optional, so a repo that
never thought about it gets `merge`.

**The merge commit is named `merge: <branch> (#NN)`**, rather than GitHub's default
`Merge pull request #NN from Owner/branch`. That default is the one line in the graph with no type in
front of it, while everything around it has one — `feat:`, `fix:`, `docs:`, `fold:`, `release:` — so a
history scan has to read two shapes instead of one. It also pairs the merge with the fold commit that
follows it (`fold: <branch> changelog (#NN)`). Passed as `--subject`; a repo that squashes or
rebases has no merge commit for it to name, and `gh` ignores it there.

**The fold was typed `chore:` until August 10, 2026**, and the rename is worth knowing about if you
scan your own history: folding is a named act with its own script and its own exception to
"never commit directly", while `chore` said only "housekeeping". Nothing reads the subject, so every
`chore: fold ...` already in your log stays exactly as valid as it was — there is nothing to migrate.

The value is **validated before use** — anything other than `merge`, `squash` or `rebase` stops the
script with a named error. An unrecognized value would otherwise reach `gh` as an unknown flag at the
one moment this script is about to write to the main branch, which is the worst possible place to
discover a typo in a config file.

**There is no `--admin`, and that is not an omission.** Bypassing the CI gate is the thing this chain
exists to make unnecessary.

## Why the fold is delegated rather than inlined

Step 5 hands the fold, its commit **and** its push to `fold-changelog-entry.ps1 -Push`. That delegation
is the point, not a tidy-up.

This step used to run its own `git add -A` plus `git commit`. `git add -A` stages the **whole tree**, so
anything else modified or already staged rode along into a commit that lands **directly on the main
branch** under one of the two named exceptions to "never commit directly". The fold script instead
commits with an explicit pathspec — the changelog, the entries it actually folded, and any legacy step list
it removed beside them — and nothing else can enter however messy the tree is.

**An exception is only safe while it stays the size it was granted at.** The workshop's own governance
doc had stated since August 2, 2026 that the fold commit "names its paths, so nothing else in the tree
can ride along" — true of the fold script, false of this orchestrator, which is the more commonly used
route of the two. Repaired here rather than in the doc.

The fast-forward before it is an **explicit** `git fetch --prune` plus `git merge --ff-only origin/main`,
not a bare `git pull --ff-only`. The bare pull aborted with *"Cannot fast-forward to multiple branches"*
on a clean main immediately after a merge and prune — and it aborts in the one gap between the merge and
the fold, which is the state nothing reports: the PR is merged, the entry file is still in the root, and
every gate stays green until a release trips over it. Git raises that when handed more than one ref;
naming `origin/main` explicitly hands it exactly one.

### Losing the fold race is a stood-down success, not a failed ship ([#1792](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1792))

`fold-on-merge.yml` runs on **every** push to the trunk, so the merge in step 4 triggers the very job
step 5 is racing. Where a repo has no merge queue — which is most of them, and this workflow's ordinary
path since [#1720](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1720) — both fold, and
whichever gets its push in second is refused. Losing it is not a defect in either runner: the trunk ends
up folded exactly once, which is the whole point of having the second runner at all.

**What it used to cost when the loser was this session.** Step 5 read the fold's exit code as `-ne 0`, so
a race lost by seconds was reported as *"the fold is NOT committed or NOT pushed"* — over a ship that had
merged, folded and closed its issues correctly. Measured shipping PR #1789 on 2026-09-10: the two fold
commits had **identical trees**, `origin/main` was right, and the session was left standing on a local
trunk diverged 1/1 — a state whose obvious remedies (`reset --hard`, a rebase on a shared branch) a repo
running this workflow typically reserves to a person, so the operator was handed a state they were not
allowed to fix.

**The repair is the fold's `3`, read here as a stand-down.** `fold-changelog-entry.ps1` returns `3` only
when it committed, its push was refused, and **every** entry that commit carries is already upstream with
an identical body — see the [`fold-changelog` skill](../fold-changelog/SKILL.md). That is "the fold
happened, somebody else made it", so `ship-pr` carries straight on to step 5b, step 6 and its report, and
the closing line names who folded. Any other non-zero code is the hard failure it always was.

**And step 5c says what the race actually cost, which is local only.** The fold commit is still sitting on
this checkout's trunk, so the run prints two commands: a `backup/fold-<branch>` ref that preserves the
commit, then the one realignment the tree it finds can run — `reset --keep origin/main` where the trunk is
checked out here, `branch -f main origin/main` where nothing holds it (a detached tree included). No fetch
is printed: the fold's own diagnosis had to fetch `origin/<trunk>` to reach this verdict at all, so it is
already current. **Neither command is executed.** `--keep` is not `--hard`, but a script that moves a trunk
pointer on its own has taken a power nobody granted it, and the fold script it delegates to declines the
same thing in as many words. What #1792 measured missing was never the authority — it was the sentence
naming which two commands, which the operator of that incident had to derive by hand.

## Step 6 on its own: repairing bookkeeping after the fact

Step 6 is **`verify-resolved-issues.ps1`**, mirrored alongside this script because a consumer whose
`ship-pr` called a file that was not in the mirror would fail at the last step of a sequence that has
already merged.

**A plain `#332` in a PR body closes nothing** — GitHub only auto-closes on a closing keyword. `open-pr`
writes those keyword lines; this step checks the **outcome**, and closes what stayed open. A belt on top
of a brace: if it never fires, the keyword did its job. It **cannot fail the ship** — the merge has
already happened by then, so a problem here is a warning, not a failure.

**Under a merge queue this step does not run at all, and that is the one case worth arranging for.**
`ship-pr` reads the trunk's rules before it merges; where it finds a queue it enqueues and ends, and the
merge lands minutes later in a process the session never observes — so there is no "after the merge" for
step 6 to be. The closing itself is unaffected: GitHub honours the body's keywords on a queue merge
exactly as on any other. What is missing is the check that it did, and the repair above when a keyword
missed — precisely the class this script exists for. The enqueue arm prints the standalone command so
the step is manual rather than invisible, and a repo that would rather it were neither can run the same
script off the **merge** instead: a push to the trunk is the one event that always sees a queue merge,
which is the same property the fold relies on. The source repo does that in a CI workflow of its own; a
consumer arranging it needs to decide for itself whether that runner may *close* an issue or only report,
since closing means granting it issue-write.

It is also usable on its own, which is what it was needed for on August 1, 2026, when eight findings
repaired by three PRs had stayed open because those bodies carried plain mentions instead of keywords:

```powershell
# report what a merged PR declared, and close what is still open
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/verify-resolved-issues.ps1" -Pr 343

# report only, change nothing
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/verify-resolved-issues.ps1" -Pr 343 -ReportOnly
```

| Parameter | What it does |
|---|---|
| `-Pr` | **Required.** The (merged) PR number to verify. |
| `-ReportOnly` | Report the state of each declared issue without closing anything. |
| `-Repo` | `owner/name`. Defaults to `Get-RepoName` from the consumer's `scripts/repo-config.ps1`. |

Two design decisions worth knowing, because both look like bugs until you know them:

- **It reads the issue numbers back out of the merged PR body** rather than taking them as a parameter,
  so the verification is against what the PR actually declared. A second tally would be a second thing
  to drift from the first.
- **A closing keyword inside backticks is ignored**, because GitHub does not link a reference inside a
  code span either — so it closes nothing there. That is what makes it possible to write a document
  explaining this gate without the gate acting on the document.

## Requirements in the consumer

The script is repo-agnostic, but reads its repo data from the **root** of the consumer (dual-context via
`${CLAUDE_PROJECT_DIR}`):

- `scripts/repo-config.ps1` with `Get-RepoName` (the `gh --repo` target), and optionally
  `Get-PrMergeMethod`. `Get-RepoName` is hard-required: without it every `gh` call below would target
  the wrong repo or none at all, so the script stops with a pointer instead of a raw dot-source error.
- Everything `open-pr` and `fold-changelog` need in turn — `scripts/lib/branch-info.ps1`,
  `scripts/tests/*.tests.ps1`, `.github/pull_request_template.md`, and a `CHANGELOG.md` carrying the
  configured heading.
- `git` and a logged-in `gh` CLI.

The `specialists-init` bootstrap puts `repo-config.ps1` in place as a `VUL-IN` scaffold; fill it in
before you use this skill.

## Important

- **Re-running it on a branch that already shipped is safe, and says so.** Step 1 stops on a merged PR
  and step 2 recognises the same state for itself, so the run ends `PR #N for '<branch>' is already
  merged -- nothing to ship` on exit 0 rather than on an error naming `gh` authentication ([inbound
  #1077](https://github.com/DaveKJohn/claude-code-specialists/issues/1077)). The local branch survives a
  merge — `--delete-branch-on-merge` removes the remote one only — so this is exactly what a second
  session, an interrupted wait, or a `git checkout <branch>` out of habit sets up. And the *fold* refuses
  a second entry for a branch the changelog already carries, which is the other half of the same route
  ([#1082](https://github.com/DaveKJohn/claude-code-specialists/issues/1082)).
- **Do not redirect this script's stderr.** It runs `open-pr.ps1` as a child process on purpose, and
  under Windows PowerShell 5.1 a `2>&1` on the parent turns every stderr line the child writes into a
  `NativeCommandError` record — which collapses the output to a truncated path fragment and hides the
  one line you need. The child's stderr is normal output here; leave it alone and read it as it comes.
  Two runs were spent on this before the real message was seen.
- **Known test gap, stated rather than implied.** Like `open-pr`, this orchestrator drives live `git`
  and `gh` against a real remote and is not covered by an automated suite. The sub-steps it calls are
  each tested on their own — step 6 was extracted into its own script for exactly that reason, being the
  one step that mutates state *outside* the repo (it comments and closes). What remains untested here is
  only the orchestration order.
- **If it fails between the merge and the fold, do not re-run it blindly.** The PR is already merged at
  that point; the fold's own output says whether the entry file was removed. Re-running a fold that
  already deleted the entry is a different problem from the one you had.
- This script is maintained in the source repo; do not modify it locally in the consumer. A
  change lands first in the source (`scripts/release/ship-pr.ps1`) and then travels via a release to the
  plugin mirror — guarded by the shared-scripts drift lint.
