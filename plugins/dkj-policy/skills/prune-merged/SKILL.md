---
name: prune-merged
description: >-
  Tidy the local clone after merges via the shared, centralized prune-merged script from the plugin
  (single source of truth, issue #81) -- so a consumer does not have to duplicate this script
  locally. Fast-forwards the trunk, drops stale remote-tracking refs, and deletes only the local
  branches whose merge can be PROVEN: an ancestor of the trunk, or a branch whose PR is merged. A
  branch with neither proof -- unfinished work, a parked branch, a branch pushed from another machine
  -- is left alone and reported. Touches NO remote branch: -IncludeRemote additionally CLASSIFIES the
  heads on the remote with those same two proofs and hands the delete command over paste-ready, rather
  than running it. Use when merged branches have piled up in the clone, as the closing tidy-up of a
  working session, or when you need to know what a `git ls-remote --heads` line actually means.
disable-model-invocation: true
---

# prune-merged -- the shared branch-reaper for consumers

This is the **plugin mirror** of `prune-merged.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it. It exists because two consumers had each written their
own copy and the plugin had none — the same argument as
[issue #81](https://github.com/DKJ-Solutions/claude-code-specialists/issues/81), reported as
[#815](https://github.com/DKJ-Solutions/claude-code-specialists/issues/815).

## Branch cleanup has two halves, and only one of them is this script

| half | who does it | what you do |
|---|---|---|
| **remote** | GitHub, via the repo setting *"Automatically delete head branches"* (`deleteBranchOnMerge`) | switch it on once, per repo |
| **local** | this script | run it when branches have piled up |

**The remote half is a setting, not a flag, and that is deliberate.** The setting covers *every* merge
route — the script path, the web UI, another machine, another tool — while `--delete-branch` on
`gh pr merge` covers only the one path it is passed on. `ship-pr` reads the setting after a merge and
tells you, with the command, when it is off; it does not pass the flag. Turning it on:

```powershell
gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true
```

**Nothing in this workflow deletes a remote branch**, and that is a decision rather than a gap. With the
setting on, merged branches disappear by themselves, so a remote delete would only ever reach branches
that are **not** merged — exactly the ones whose loss is unrecoverable. All of the risk, almost none of
the benefit. Check your own repo's governance before reaching for `git push origin --delete`. What this
script will do is work out *which* heads that command would be safe on and hand you the line —
[`-IncludeRemote`](#-includeremote-reads-that-commands-output-for-you), below.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prune-merged.ps1"
```

**In the source repo, run its own copy instead -- `scripts/task/prune-merged.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

Look before you reap:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prune-merged.ps1" -DryRun
```

`-DryRun` reports what would go and deletes nothing. The fast-forward and the ref prune still run —
neither loses anything, and without them the branch list being reported on is the stale one.
`-Remote <name>` fetches and prunes a remote other than `origin`. `-IncludeRemote` adds the
report-only remote pass described in the next section.

The script:

1. **Refuses on a dirty working tree — where the step-off is reachable.** A run can still have to step
   off the branch you are standing on (4c), and doing that with uncommitted work either fails halfway
   or drags the work across. Commit, `park`, or stash first — **or rerun with `-DryRun`**, which
   deletes nothing and therefore never steps off, and still prints the whole classification.

   **Three states put 4c out of reach for the entire run, and there a dirty tree is reported rather
   than refused** ([#1575](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1575)):
   standing on the **trunk**, which the candidate list excludes and which is therefore never something
   this run can step off; a **detached** `HEAD`, for the same reason; and **`-DryRun`**, which
   `continue`s above 4c on every candidate. The guard used to fire on all of them, which mattered
   because this is the command a session is instructed to run *mid-assignment* — exactly when a
   checkout has uncommitted work in it. The line it prints instead names which of the three made the
   tree harmless, so an absent refusal is never read as an absent guard.
2. **Fast-forwards the trunk without checking it out** — `git fetch <remote> <trunk>:<trunk>`, which
   writes a local branch ref that `HEAD` is not on and moves no working tree at all
   ([#1147](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1147)). **Fast-forward only**
   — git refuses a non-ff update into `refs/heads/` unless the refspec carries a leading `+`, and this
   one does not, so the guarantee is git's rather than a flag's. A non-fast-forward is a warning, not
   a stop: the deletions are then judged against the older trunk, which errs towards keeping branches.
   A run that already **stands on** the trunk cannot fetch into its own checked-out ref and uses
   `git pull --ff-only` instead — same guarantee, and nothing moves there either.
   And if a **second worktree is standing on the trunk**, git will not write that ref either. That
   used to make the run impossible clone-wide; since #1147 it costs only the fast-forward, and the
   warning still names the directory and how to release it
   ([#1069](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1069)) rather than relaying
   git's own message — this script is what a session runs *instead of* hand-reading `git ls-remote`,
   so it was unavailable in exactly the situation that produces stray branches.
3. `git fetch --prune` — drops remote-tracking refs whose remote branch is gone.
4. Deletes each local branch whose merge can be **proven**, and only those — and where that branch is
   the one you are **standing on**, steps off it onto the trunk first, because `git branch -d` can
   never delete the branch `HEAD` is on.
5. Says where the run ended as its closing line
   ([#1071](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1071)) — which, on every run
   that did not reap the branch underneath itself, is exactly where it started.

**It does not borrow the checkout, and since #1147 it does not take one.** Step 2 used to switch to the
trunk and switch back; a borrow returned within the second is still a tree that moves under whatever
else is running in the same checkout, which is the collision measured in
[#1145](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1145) — a `ship-pr` gate reading the
working tree for a minute while this command ran beside it. The one move left is step 4c, and it can
only happen on a branch that has just been **proven merged**: a branch under a running gate is unmerged
by definition, so it never reaches that line. There is nothing to hand back once the branch is gone, so
the run then ends on the trunk and names the short sha it left.

**The exit contract is still deliberately not `ship-pr`'s.** That script ends on the trunk on purpose —
it closes a *finished* assignment, and ending there is what makes the session safe to clear. This one
closes nothing: it is a tidy-up run mid-assignment, and the branch you were standing on is still there
when it ends. Leaving you on the trunk cost the reporter of #1071 a commit that landed **directly on
`main`** — the tree is clean and `git status` says nothing unusual, so there is no signal at all between
the switch and the mistake. That is now structurally impossible rather than repaired after the fact:
nothing moves `HEAD` unless the branch it was on has been deleted.

## The proof, which is the whole safety property

- **An ancestor of the trunk** → `git branch -d`. That flag refuses an unmerged branch by itself, so
  the proof is checked twice.
- **Otherwise, a branch whose tip *is the head commit* of a merged PR** → `git branch -D`. This is the
  squash case: the branch's own tip is deliberately *not* in the trunk's history, so ancestry can never
  see it and `-d` would refuse a branch that is genuinely finished. The merged PR is what replaces
  ancestry — which is why the forced delete is safe here and nowhere else.
- **Neither** → the branch is **kept**, and the line says why. A parked branch (the `park` skill),
  unfinished work, or a branch pushed from another machine has neither proof, so none of them can be
  lost by this script.

### The proof is the PR's head commit, never its branch name (inbound [#1191](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1191))

A branch **name** proves nothing about which commits were merged under it, and this workflow recycles
names on purpose. `deleteBranchOnMerge` — the setting the remote half of this script leans on — frees the
name the moment a PR lands, so any repo that generates branch names from a template gets the same name
back. Until September 1, 2026 proof (b) was a name match, and the second branch under a reused name
inherited the first one's merge.

**Measured in a consumer whose pre-task sync names its branches `sync/live-<date>`.** A second sync the
same day recreated `sync/live-2026-09-01`, and the run printed:

```text
Deleted sync/live-2026-09-01 (git branch -D -- merged PR)
```

That name had two PRs: **#141**, merged, which is what put it in the merged set — and **#159**, still
**open**, whose commit the local branch was actually standing on. Nothing was lost that day, because this
script never touches a remote and `origin` still held the commit. What was broken regardless is the
property the script claims: the proof belonged to a different branch, and the output said `merged PR`
while it did it, so it actively reassured.

So the test is now the **name and the tip together**, and a name whose merged PR ended on a *different*
commit is kept with a reason that says exactly that — *"a merged PR used this name, but not this
commit — no proof for this tip (a recycled name, or a commit added after that PR merged)"*. "No merged
PR" would describe a lookup that came up empty, when this one came up full — the name matched, this
commit did not. The reason names that measurement rather than asserting a cause, because a recycled
name, an unreadable tip and a branch that took a commit after its own PR merged all resolve here
(issue #1296).

**It matters most in the `-IncludeRemote` pass**, which hands over a `git push origin --delete` line. The
local pass at worst discards commits `origin` still holds; a wrong line there reaches the copy of last
resort.

The merged-PR set is read **once** per run (`gh pr list --state merged --json headRefName,headRefOid`) and
matched locally, rather than one lookup per branch. A name may carry **several** head commits — a recycled
name merged twice has two, and each is a real proof for the branch that ended on it. If `gh` is absent,
unauthenticated, or answers something that will not parse, that is not an error: proof (b) simply cannot
be established, the run says so, and every squash-merged branch is kept.

## `git fetch --prune` proves nothing about the remote

It only drops tracking refs for branches **already gone** from the remote, so a clean local list is no
evidence whatsoever that the remote is clean. The one command that answers it is worth keeping in mind
whenever you reason about what has and has not landed:

```powershell
git ls-remote --heads origin
```

### `-IncludeRemote` reads that command's output for you

Its output is a list of shas and names, and **the two states you care about look identical in it**: a
merged leftover that is safe to delete, and live parked work that must not be touched. Telling them
apart by hand is four commands per head — ancestry, a PR lookup, a diff against the trunk, the head's
own commit message — and it has to be redone every time, because nothing in the list remembers the
answer.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prune-merged.ps1" -IncludeRemote
```

Every head that is not the trunk is put through **the same two proofs the local pass uses**, and the
report has two halves:

- **Neither proof** → `Kept origin/<branch> -- live work (unfinished, parked, or another open PR)`.
  This is the half worth having: parked work is labelled as such instead of being re-investigated, and
  somebody else's open branch is not mistaken for a leftover.
- **A proof** → the delete command, printed for you to paste:

  ```
  git push origin --delete <branch>   # ancestor of main
  ```

**It runs nothing on the remote**, with or without the switch — deleting a remote branch stays a manual
act, and this hands over the command rather than taking the decision. Because a head is only ever named
here on positive proof of a merge, the set it can point at is exactly the set that is safe to lose; a
head it cannot prove is one it tells you to leave alone. Check your own repo's governance before
pasting the line.

**Without the switch nothing on the remote is read at all**: the run ends by naming the raw `ls-remote`
command, as it always has, now with the switch beside it. The pass is opt-in because it costs a network
round trip plus one ancestry check per head, and most runs are a local tidy-up.

One thing the switch changed for every run: **a clone with nothing but the trunk left no longer ends
early.** That used to be the one state in which the closing line about the remote was never printed —
and it is precisely the state in which the remote question is worth asking, because a freshly tidied
clone is the strongest possible piece of evidence about nothing.

## Why this is a separate command and not part of `ship-pr`

So that a session cannot delete a branch as a **side effect** of shipping a PR. Merging and reaping are
two decisions, and the second one is the destructive one. It also keeps the reaping re-runnable and
inspectable (`-DryRun`) at a moment of your choosing, instead of once per merge whether you were looking
or not.

There is a measured reason not to reach for `--delete-branch` inside the merge either, beyond the route
coverage above: that flag deletes the **local** branch too, and on July 16, 2026 it was measured leaving
the checkout **on the merged branch** — with the fold then running there and having to be undone by hand.

## Requirements in the consumer

`git`, and `gh` for the squash-merge proof (optional — without it those branches are kept). It reads the
trunk name from `Get-TrunkBranchName` in `scripts/repo-config.ps1` when that file exists, defaulting to
`main`; nothing else is repo-owned, so there is nothing to scaffold. It resolves its repo root
dual-context via `${CLAUDE_PROJECT_DIR}`.

## Important

- **No remote branch is ever deleted by this script**, and no PR is opened or merged by it.
  `-IncludeRemote` prints a delete command; it never runs one, and the test suite asserts that
  structurally — no git call in the source carries a `--delete` argument, in quotes of either kind.
- This script is maintained in the source repo; do not modify it locally in the consumer. A change
  lands first in the source (`scripts/task/prune-merged.ps1`) and then travels via a release to the
  plugin mirror -- guarded by the shared-scripts drift lint.
