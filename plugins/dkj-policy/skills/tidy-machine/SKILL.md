---
name: tidy-machine
description: >-
  Clear the clutter this workflow leaves behind on a machine, in one command and twelve lanes: finished
  branches, stale worktree lanes, branches whose pull request was CLOSED without merging, expired
  backup branches, old stashes, an unfolded changelog entry, the ~/.claude plugin administration,
  install records pointing at a checkout that is gone or naming a plugin the marketplace has retired,
  plugin/marketplace staleness, extracted plugin payload no install record points at any more, and
  fixture trees under the scratch root. It DELETES only what
  prune-merged can already prove -- an ancestor of the trunk, or a tip that is the head commit of a
  merged PR -- and everything else it classifies and hands over with the command, paste-ready. Use it when branches have piled up, as the closing tidy-up
  of a working session, when a lane worktree has outlived its branch, or when you want to know which
  of the trees under your temp directory belong to runs that have ended.
---

# tidy-machine -- the whole-machine tidy, in twelve lanes

`prune-merged` answers one question extremely well: **was this branch merged?** This command answers
the ones next to it, and calls `prune-merged` for that one rather than re-deciding it.

## Why it exists, measured

Run in the source repo on **September 10, 2026**, `prune-merged -DryRun -IncludeRemote` found 32 local
branches beside the trunk: **27 provably merged, 5 kept -- and not one of the five was live work.**

| branch | what it actually was |
|---|---|
| `backup/main-pre-sync-20260903` | a 7-day-old pre-sync backup, no PR has ever existed for it |
| `docs/changelog-dropped-ship-cost-v1` | PR #1299 **CLOSED**, unmerged |
| `fix/round-tally-error-wrap-v1` | PR #1243 **CLOSED**, unmerged |
| `fix/branch-doc-per-branch-path-v1` | PR #1260 **CLOSED**, unmerged -- **and holding a whole second checkout** |
| `feat/plugin-version-overview` | PR #1599 **MERGED**, local tip one commit past the merge |

`prune-merged` keeps all five **correctly**: none of them has a merge proof, and inventing one is the
defect inbound [#1191](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1191) measured.
What was missing was a name for what they *are*.

**A closed pull request is a decision a person took on the tracker: this work does not land.** That is
evidence of the same kind as a merged one -- a state outside the working tree -- and it is the only
thing that separates *abandoned* from *in progress* without guessing from a date or a branch name.

## What it may throw away, and what it only reports

**Dave, September 10, 2026, asked what this command may delete on its own: only what is provably
merged.** So:

| | |
|---|---|
| **deletes** | exactly one lane, and only by delegation -- `prune-merged.ps1`, on its own two existing proofs |
| **reports** | everything else, each item with what was measured and the command that would act on it |

**That is the `-IncludeRemote` doctrine turned inward.** `prune-merged` refuses to delete a *remote*
branch and hands over the line instead, because with `deleteBranchOnMerge` on, the only branches a
delete could still reach are the ones whose loss is unrecoverable. An abandoned branch is in exactly
that position from the other direction: **its pull request is closed, so the remote copy is gone and
this clone holds the last one.** A closed PR is strong evidence that nobody wants the work; it is not
evidence that nobody wants the commits.

## Running it

From the root of the consuming repo:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/tidy-machine.ps1" -DryRun
```

**In the source repo, run its own copy instead -- `scripts/maintenance/tidy-machine.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own,
so for them the line above is the correct one.

Look first, then let it act:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/tidy-machine.ps1"
```

| flag | what it does |
|---|---|
| `-DryRun` | change nothing anywhere, including in the one lane that would otherwise act -- it is passed through to `prune-merged` |
| `-CheckoutOnly` | lanes 1-6 only |
| `-MachineOnly` | lanes 7-12 only. Useful mid-flight, when you want the `~/.claude` and scratch answers without anything reading the branch list -- **and the one mode that runs with no checkout at all** (below) |
| `-MaxAgeDays <n>` | how old a `backup/*` branch or a stash must be to be reported. Default 14 |
| `-MinFixtureAgeHours <n>` | how old a scratch tree must be before its dead pid counts. Default 24 |
| `-Remote <name>` | the remote `prune-merged` fetches and prunes. Default `origin` |

## The twelve lanes

**Per checkout:**

| # | lane | authority |
|---|---|---|
| 1 | **stale lanes** -- a worktree whose branch is finished | reports, with the hand-back command |
| 2 | merged branches and stale tracking refs | → `prune-merged.ps1`; **deletes on proof** |
| 3 | **abandoned** -- a PR CLOSED without merging | reports, with `git branch -D` |
| 4 | **expired backups**, and branches no proof reaches | reports |
| 5 | stashes past the bound | reports -- **never dropped** |
| 6 | an unfolded changelog entry on the trunk | → `check-unfolded-entry.ps1` |

**Machine-wide, once:**

| # | lane | authority |
|---|---|---|
| 7 | the `~/.claude` plugin administration | → `check-claude-home.ps1` |
| 8 | **install records pointing at a checkout that is gone** | reports |
| 9 | plugin and marketplace staleness | → `plugin-versions.ps1` |
| 10 | **fixture trees under the scratch root** | attributes -- **never deletes** |
| 11 | **install records under a plugin name the marketplace has retired** | reports, with the uninstall |
| 12 | **extracted plugin payload no install record points at** | reports -- **no command, nothing removed** |

Six of the twelve are a call into a script that already exists and already has its own suite. Only six
carry new logic, and that logic is pure and lives in `tidy-lib.ps1`, which is what lets its suite drive
the classifier over states no machine here has ever been in.

### `-MachineOnly` runs with no checkout at all (#1926)

Every other invocation needs one and refuses without it, because lanes 1-6 read a branch list and a
branch list has no meaning outside a repository. Under `-MachineOnly` there is no such subject, so the
run works from a home directory, a scratch directory, anywhere:

```powershell
cd ~
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/tidy-machine.ps1" -MachineOnly -DryRun
```

**Five of the six lanes need no repo, and that was measured rather than assumed.** Lane 7 delegates to a
script that already resolves its root tolerantly; lanes 8, 11 and 12 hand `Get-InstallRecord` a root only
to read the one field of its answer that is not filtered by it; lane 10 walks the scratch root. **The
sixth is lane 9, and it is the exception**: its question is how far behind *this checkout's* plugins are,
so with no checkout it is skipped by name and says so, rather than being left to refuse inside
`plugin-versions.ps1` -- where the refusal is worded for somebody who ran that script directly and would
read, from here, as the whole run having failed.

**Lane 11's one other repo-dependent line degrades into a true sentence.** It normally marks the findings
that belong to a *different* checkout, since `claude plugin uninstall` is keyed on the directory it runs
in. Standing nowhere, every finding belongs to a different checkout -- which is what it says, with a line
naming the reason so *"another checkout"* does not send the reader hunting for which one is this one.

**This was never the behaviour before, despite a fallback that read exactly like it.** The script carried
`if (-not $repoRoot) { $repoRoot = (Get-Location).Path }` from its first commit; that guard could only
fire on an empty string, and the line above it threw on `$null` first. So it caught a state that could
not occur, and `-MachineOnly` has failed outside a checkout for its whole life. #1917 replaced the
resolution and removed the dead line, leaving the question visible; this is the answer to it.

### Lanes 8 and 11 are one defect from opposite ends

Both answer *"this record names something that no longer exists"*, and neither can see the other's half.
Lane 8 probes the record's **checkout**; lane 11 asks whether the **plugin name** is still in the
manifest of the marketplace that record names. A record can be dead by either, and the remedies are
opposites -- re-install at the new path, or drop a record nothing will ever use again -- which is why
they are two lanes and not one.

**Lane 11 exists because this workflow generates its own instances of it.** A rename is a deliberate act,
and each one turns every existing install record into dead weight on every machine that had the plugin.
Measured in the source repo after two renames in two days (#1697, #1698): five records under three
retired naming generations, reported by no lane, while `claude plugin list` read as seventeen plugins and
four of the six *enabled* plugins had no install record at all. The signal that would have named the real
problem was buried in noise nothing could clear
([#1773](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1773)).

Three things about what it prints:

- **The authority is each marketplace's own clone under `~/.claude`, per marketplace.** A record can
  legitimately name a plugin from a different marketplace this machine also uses, so the question is
  never *"is this name in a manifest"*. A clone this run could not read gets no answer at all and every
  record naming it stays silent -- an authority you could not read is not evidence of absence.
- **The `--scope` in the printed command is the record's own**, never a fixed `project`:
  `claude plugin uninstall ... --scope project` refuses to remove a record sitting at `local` (inbound
  #315), and a session start alone is enough to create one.
- **Most findings belong to another checkout on this machine**, and the run says so per line. An
  uninstall is keyed on the directory it runs in, so those commands have to be run *there*. The register
  is machine-wide; visiting another repository is not something this script does.

### Lane 1 runs first, and the order is load-bearing

git refuses to delete a branch that is checked out in **any** worktree, and that refusal is raised
*before* the merged/unmerged question is asked. Measured on git 2.54.0.windows.1
([#1760](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1760)):

```text
error: cannot delete branch 'X' used by worktree at '<path>'
```

So a lane holding a provably merged branch makes that branch **unreapable** until the lane goes.
Reported first, you can clear it in the same sitting; reported afterwards, you get git's sentence about
a worktree in the middle of a list of merge proofs. The run also says so explicitly when it finds that
pair, rather than leaving you to notice.

### Lane 3's proof is the name **and** the tip, exactly like lane 2's

A branch **name** proves nothing about which commits were merged -- or closed -- under it, and
`deleteBranchOnMerge` frees a name the moment a PR ends, whichever way it ended. So the closed-PR test
is the same pair test `prune-merged` uses, through the same shared functions rather than a second copy
of them: the ordinal-keyed lookup is precisely the detail a re-typed copy loses silently, and it has
already gone wrong twice ([#1190](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1190),
[#1191](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1191)).

A name whose closed PR ended on a *different* commit is reported as **recycled** and nothing is
proposed for it -- the lookup came up full and belonged to somebody else's work, which is a different
sentence from "no PR found".

### Lane 3's lookup filters on the server, and that was measured

`gh pr list --state closed` **includes merged** -- merged is a kind of closed, and gh has no state
meaning closed-and-not-merged. The first version of this script asked for `--state closed --limit 200`
and dropped merged rows locally. It found **zero** abandoned branches in a repo that has three: where
nearly every PR merges, the 200 most recent closed pull requests are 200 merged ones, so every
genuinely abandoned branch falls outside the window. A filter that is correct and reaches nothing.

`--search is:unmerged` asks GitHub the question instead, so the whole limit is spent on rows that can
actually be a proof. `mergedAt` is still requested and still dropped on, as a belt.

### Lane 4's age bound applies to `backup/` and to nothing else

An age is not evidence: a branch untouched for a month may be a month of not getting round to it. The
one place a date carries meaning is a branch whose **name** says it was made to be temporary, and
`backup/` is this workflow's only such prefix.

An expired backup is reported with **whether it is an ancestor of the trunk**, because the two are not
the same risk wearing one name. One that is holds nothing the trunk does not; one that is **not** holds
commits that exist in this clone and nowhere else -- which is exactly what a pre-sync backup is for
when a sync went non-fast-forward. Measured on `backup/main-pre-sync-20260903`: **not** an ancestor.

### Lane 10 attributes and never deletes, by a decision already taken

`scripts/README.md` settled this before the lane was written, on
[#1668](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1668): those trees are *"left
standing on purpose: `$PID` in the leaf is what makes one attributable to a run that is no longer
alive, and a person can clear it by hand"* -- and it names the alternative by name, *"a sweep by name
pattern in a shared temp directory, i.e. the same delete primitive `New-ScratchPath` exists to
remove"* ([#1659](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1659)).

**An earlier draft of this lane offered exactly that behind a `-ReapScratch` flag. It was removed
rather than defended**, and the suite now pins its absence -- a decision that lives only in prose is
one draft away from being made again.

What is left is worth having on its own, because #1668 also measured that the *first* reading of that
directory was wrong: 413 entries read as leaked fixtures, of which 546 in the same directory were
retained-on-purpose artefacts (`sync-pr-body-*`, written for you to paste into `gh pr create
--body-file`; the gate's capture directories from
[#1636](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1636)) and 162 belonged to an
unrelated tool. **Attribution is the scarce thing, not deletion.** The lane skips both retained labels
by name and reports only trees whose pid is no longer a running process.

### Lane 12 judges the other end of the pointer lanes 8 and 11 read

A record's `installPath` names an **extracted copy of the plugin** under
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version-or-sha>/`, and that copy — not the marketplace
clone — is what a session loads. Measured September 10, 2026 on Claude Code 2.1.267
([#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)): the running process
writes a lease at `<installPath>/.in_use/<pid>` and holds it for the life of the session, and the clone
holds none. Lanes 8 and 11 ask whether a pointer is still good; this one asks what is on the other end
of it, and it is the only lane whose subject the install register does not itself enumerate.

**It is worth a lane because nothing reaps those copies.** The harness marks a tree no record points at
with `.orphaned_at` and stamps `~/.claude/plugins/.last_inuse_sweep` — but on the machine measured, 30
of 41 trees carried that mark, 22.2 MB of 32.6 MB, the oldest six days old and every one still on disk.
An uninstall was measured to remove the **record** and leave the payload standing, so lane 11's handover
grows this pile rather than clearing it.

**Three things about what it prints:**

- **Grouped by plugin id, not one line per tree.** A machine that has taken a dozen releases holds a
  dozen trees per plugin, and a per-tree list buries the one number a reader acts on under its own
  length.
- **A tree nothing points at but a LIVE process is still reading is never counted as reclaimable.** That
  is a session which started before the record moved; it goes when the session does, and deleting it
  would pull the files out from under a running session.
- **No command is handed over, and that omission is the point — the same decision as lane 10.** There
  is no plugin-cache verb to hand over, so the only line to print would be a recursive `Remove-Item`
  under your home, which is the delete primitive `New-ScratchPath` exists to remove
  ([#1659](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1659)). Clear by hand what
  you recognise.

## What it never touches

- **No remote branch**, ever, with or without a flag. Same rule as `prune-merged`, same reason, and the
  suite asserts it structurally -- no `--delete` argument appears in the source, in quotes of either
  kind.
- **No stash is ever dropped.** A stash is unrecoverable and invisible to every other guard here.
- **No pull request** is opened, merged or closed, and no issue is touched.
- **Nothing under the scratch root is deleted** (lane 10, above).
- **No working tree is moved by this script.** The one exception is inherited rather than performed:
  `prune-merged`'s step 4c steps off a branch it has just proven merged, and only then.
- **No other checkout is visited.** The machine-wide lanes read `~/.claude`; they do not walk into other
  repositories. Dave's answer on September 10, 2026 was "this checkout plus the machine-wide lanes"
  rather than "every checkout the machine knows about" -- the blast radius of a bug in the second shape
  is repositories nobody had opened.

## Requirements in the consumer

`git`, and `gh` for both PR proofs (optional -- without it only ancestry proves anything, and nothing is
ever classified abandoned). It reads the trunk name from `Get-TrunkBranchName` in
`scripts/repo-config.ps1` when that file exists, defaulting to `main`; nothing else is repo-owned, so
there is nothing to scaffold. It resolves its repo root dual-context via `${CLAUDE_PROJECT_DIR}`.

Lanes 6, 7 and 9 delegate to scripts that may not be present in every consumer; each says so and is
skipped rather than failing the run.

## Important

- **Run `-DryRun` first on any machine you have not run this on.** Lane 2 deletes, and on a clone that
  has never been tidied it will delete a lot -- 27 branches, in the measurement above.
- This script is maintained in the source repo; do not modify it locally in the consumer. A change
  lands first in the source (`scripts/maintenance/tidy-machine.ps1`) and then travels via a release to
  the plugin mirror -- guarded by the shared-scripts drift lint.
