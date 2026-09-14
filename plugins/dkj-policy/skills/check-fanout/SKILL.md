---
name: check-fanout
description: >-
  Find out whether a dispatched fan-out discarded any of THIS session's uncommitted work -- take a
  baseline of the working copy before dispatching subagents, compare after they return, and report
  shrinkage only: a path that was changed and no longer is, a worktree edit that has been reverted, or
  a stash entry that has gone. Use it whenever work is handed to subagents while the checkout holds
  uncommitted edits, which is exactly what a parallel review chain is. It reads and reports, refuses
  nothing, and cannot restore -- discarded uncommitted content is in no reflog, so knowing WHICH file
  to write again is the whole available remedy. Growth is expected and stays silent, so a subagent
  legitimately writing files never trips it.
---

# check-fanout -- the detection half of the working-copy boundary

A dispatched specialist is told the checkout is not its own to move. That rule is
[`working-copy-boundary`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/plugins/dkj-subagents/subagent-shared/working-copy-boundary.md),
carried by every
agent def that holds `Bash`, and **nothing about it was ever detectable.** This skill is the other
half: it does not stop anything, it tells you whether something already happened.

**Since [#1669](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1669) there is a third
thing, and it is not a substitute for this one.** `hooks/guard-working-copy.ps1` in this plugin
*refuses* those commands when the payload says the caller is a dispatched subagent, so the common case
never happens now. It still leaves this skill its whole job, for two reasons the guard's own header
states: the guard reads a **command**, so anything it does not parse -- a script file, an encoded
command, a text tool asked to execute -- passes it untouched, and there is no verb list that covers a
subagent writing over a file with `Out-File`. This skill reads the **result**, which is the only
question that stays answerable whatever the route in.

## The measurement this exists for

September 8, 2026, issue
[#1665](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1665). A dispatched code
reviewer needed to compare a branch against the trunk. Mid-review it ran `git stash`, hit a conflict
against stash entries belonging to other sessions, and resolved that with
`git checkout HEAD -- <file>` on three files. Those three files held **the orchestrating session's
uncommitted work** -- four edits made after the branch's last commit.

Everything about that loss was silent:

- no error, no notice, no refusal;
- a **clean `git status`** afterwards, which the review's own report cited as proof it had changed
  nothing (`the working tree is back to git status clean, matching this commit exactly`);
- and it was found **days later, by accident**, because a `grep` happened to show old text where new
  text had been verified minutes earlier.

The repair was an instruction. Issue
[#1670](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1670) then made the point this
skill answers: the next occurrence was **exactly as invisible as the first**, and it would be *less*
conspicuous whenever what gets discarded is a config value or a single flag rather than a paragraph of
prose somebody later happens to read.

## How to run it

Two calls, one on each side of the dispatch. Run them from the **root of the consuming repo**:

```powershell
# BEFORE dispatching any subagent
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/check-fanout.ps1" -Capture
# -> [OK] baseline taken, and it prints the -Compare line to run afterwards

# AFTER the fan-out has returned
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/check-fanout.ps1" -Compare "<that path>"
```

**In the source repo, run its own copy instead** -- `scripts/task/check-fanout.ps1`. The plugin cache
holds the last *released* mirror and so lags its own source by however many merges have landed since; a
consumer keeps no copy of their own, so for them the line above is the correct one.

## The two parameters

- **`-Capture`** -- take the baseline. It prints the path to hand back, because the file lives at an
  **unpredictable** temp path (`New-ScratchPath`, issue #1659) rather than at a name both runs could
  guess. That costs nothing: the caller is a session with the printed path in front of it.
- **`-Compare <path>`** -- read that baseline, take a second reading, and report.

Passing both, or neither, is **exit 2** rather than a guess -- a mode confusion must not read as a
clean bill of health. So is a `-Compare` path that does not exist: a window with no beginning says
nothing about what happened inside it.

## What it reports, and what it deliberately does not

**Shrinkage is the signal, not change.** A subagent legitimately writing files makes the changed-path
list **grow**, which is expected and never reported. What is reported is the list getting smaller:

| Finding | What it means |
|---|---|
| `[ALARM] <path>` vanished | the path was changed at the baseline and is now unchanged, and no commit since the baseline carries it. **The #1665 case.** |
| `[ALARM] <path>` worktree cleared | the path is still listed, but its worktree change is gone -- what `git checkout -- <path>` leaves behind on a file that also had a staged change. |
| `[ALARM]` stash entry gone | an entry present at the baseline is absent now, **by its own id**. |
| `[INFO]` not comparable | the two readings are on different branches, or the second HEAD is not a descendant of the first. Reported *instead of* a comparison. |
| `[INFO]` not measured | one of the git reads failed, so a figure is unknown rather than zero. |

**Exit 0 when the comparison was made and nothing shrank, 1 when something shrank, 3 when the
comparison could not be made at all.** That third code is the one worth knowing: *"nothing shrank"* and
*"this could not be established"* are different answers, and a caller branching on the exit code has no
other way to tell them apart. The most likely cause is the ordinary one — a `git status` losing a race
for `.git/index.lock` while dispatched agents run `git` in the same checkout — and in that case the
baseline is **kept**, not spent, because a retry is exactly the right next move.

### The five false positives it answers

Each of these would otherwise fire on ordinary work, and a detector that cries wolf is one somebody
switches off:

1. **The orchestrator committed.** It is explicitly told to keep working while the fan-out runs, so a
   path may leave the list because it was committed. The paths carried by the commits added since the
   baseline are excluded -- and where that list could not be read, the finding still stands but says
   the innocent explanation was not ruled out.
2. **History was rewritten.** If the second HEAD is not a descendant of the first, the commits between
   them are not a bridge and nothing is differenced across it.
3. **The branch changed.** A changed-path list is relative to `HEAD`, so two readings on different
   branches answer different questions.
4. **`git reset`.** Unstaging moves a change from the index to the worktree and destroys nothing, so
   the index half going clean is **not** reported. Only the worktree half is.
5. **`git mv`.** A rename takes the baseline's name out of the list while the edit sits intact under
   the new one, so the rename pairing is kept and the comparison **follows** the file — in both
   directions, since a baseline taken with a rename already staged can equally be unstaged inside the
   window. Following it is better than exempting it: the worktree-half rule then still reaches a real
   loss that happens on the far side of the rename, and the finding is reported under the name the file
   has *now* with the old one named beside it.

### Paste the printed line -- `-Compare` refuses anything else

This step both **reads** and **deletes** what it is given, so it accepts only a
`fanout-baseline-<pid>-<guid>.json` sitting directly in the temp directory — which is exactly what
`-Capture` prints. Anything else is **exit 2** and is left untouched. Two things that buys: a UNC path
handed to a file read opens an outbound SMB connection and authenticates before a byte is validated,
and a stale or mistyped path that happened to name somebody else's live baseline would otherwise be
deleted as spent.

Where the confinement stops is worth stating plainly rather than leaving implied: a process that can
already write your temp directory can rewrite a baseline in place, and this step would compare against
it and believe it. That is outside what a detector built for **accidents** can answer, and it is why
the guarantee is worded as detection rather than proof.

**And a baseline nobody compares is never reaped.** Only a `-Compare` that reaches a verdict removes
the file, so a crashed or abandoned session leaves one behind in the temp directory, naming the paths
that were mid-edit when it was taken. Deliberately not swept: the leaf carries the capturing process's
own id, and deciding whether another run's baseline is dead is the judgement the confinement above
exists to keep this step out of.

### And a stash entry is identified, not counted

#1670 proposed counting stash entries and said a count is enough. It is not, and the gap was cheap to
close: a subagent that **pops one entry while the orchestrator pushes another** leaves the count
unchanged, so a count would report nothing on exactly the #1665 command. `git stash list --format=%H`
gives every entry its own commit id, so a vanished entry is a vanished id whatever happened beside it.

## What this skill is NOT

- **Not a guard.** It stops no command. Whether a `PreToolUse` hook should refuse these commands
  inside a dispatched subagent is [#1669](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1669),
  and it is a separate decision with an outward-facing cost.
- **Not a recovery.** Content discarded by `git checkout HEAD -- <path>` was never committed and is in
  no reflog. There is nothing to restore it *from*, which is precisely why detection was the gap worth
  closing.
- **Not automatic.** #1670 left the home open between a hook, tooling and a documented step, and the
  invoked script shipped first for one reason: a `Pre`/`PostToolUse` pair around the dispatch rests on
  the matcher name of the dispatch tool, and that had not been measured. Nothing here rests on anything
  unmeasured. The hook variant stays open on #1670 and is cheap to add, because the judgement it would
  need is already the shared function `Compare-WorkingCopySnapshot` rather than anything in the script.

**That last one is the honest weakness, so it is stated rather than buried:** a baseline nobody took
is a comparison nobody can make, and this repo's own laziness rule says a step that must happen every
time belongs in a hook. Until that decision is made, taking the baseline is a discipline -- which is
why this skill is **model-invocable**, like `claim-issue` and unlike the release skills: the pain it
removes is that a session dispatches a fan-out and never thinks about the working copy at all, and a
skill nobody may invoke until it is typed leaves exactly that path open.

## Requirements in the consumer

`git`, and a checkout. Nothing else: no `gh`, no network, no `scripts/repo-config.ps1` seam, and no
knowledge of what a specialist is. It reads `git status`, `git stash list`, `git rev-parse`,
`git merge-base` and `git diff --name-only`, and it writes exactly one file -- the baseline, in the
temp directory, which `-Compare` deletes once it has been spent. A baseline that turned out **not** to
be comparable is kept instead, and the report says so, because the sensible next move is to get back
to that state and compare again.

## Important

This script is maintained in the source repo; do not modify it locally in the consumer. A change lands
first in the source (`scripts/task/check-fanout.ps1` and `scripts/lib/fanout-lib.ps1`) and then travels
via a release to the plugin mirror -- guarded by the shared-scripts drift lint. The whole judgement is
in the lib, tested by `scripts/tests/fanout-lib.tests.ps1`: change one, run the other.
