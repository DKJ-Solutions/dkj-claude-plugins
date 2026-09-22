## fix/2250-gh-not-started-wording

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#### What #2234 left behind

#2234 made `Invoke-NativeCapture` return a verdict instead of throwing when the executable cannot be
started. The capture it returns sets `ExitCodeUnknown = $true` **deliberately** -- that is exactly what
lets the ~63 sites audited under #2081 keep working untouched. The cost is that *could not be started*
is a **subset** of *not measured*, so any site whose unmeasured arm hand-writes its own sentence absorbs
the not-started case and says two false things about it:

- *"gh ran"* -- precisely what did not happen; and
- *"it normally settles on a re-run"* -- false **advice** rather than merely imprecise. A command that
  is not installed does not settle, so a reader who follows it re-runs forever while the real remedy
  (install the CLI) is never named.

#### The shape of the repair, and why order is the whole of it

A `Test-NativeCommandStarted` arm placed **ahead** of the `Test-NativeExitMeasured` one, exactly as
`new-branch.ps1` and `open-pr.ps1` were repaired on #2234's own branch. Reversed, the broader test
answers first and the new arm is unreachable -- and nothing about that failure is visible: the site
still compiles, still refuses, still prints a sentence. That is what the suite pins.

#### The reachability map, which changed two of the six sentences

#2250 prescribes one shape for all six. Reading each site against the tree first -- this repo's own rule
that a report's **reason** is verified before its symptom is repaired -- showed that shape is wrong at
two of them, and the sweep would have printed a cause the same run has already measured to be false:

| Site | Reachable not-started state |
|---|---|
| `check-branch-entry.ps1` DEPLOY-lock read | absent gh, in full -- no guard above the call |
| `check-repo-settings.ps1` repo-settings read | **launch failure only** -- a `Get-Command gh` guard twelve lines up has already proved gh is on PATH |
| `ship-pr.ps1` DEPLOY-lock read | absent gh, in full -- no guard |
| `check-connectors.ps1` consumer repo read | **launch failure only** -- reached only under `$RemoteRunnerRead`, which needs `Get-Command gh` *and* `gh auth status` exit 0 |
| `check-consumer-siblings.ps1` default-branch read | absent gh, in full -- see below |
| `check-consumer-siblings.ps1` tree read | absent gh, in full -- see below |

The two siblings look guarded by `Test-GhCanAnswer`, which opens with `Get-Command gh`. They are not:
that guard is consulted only on the **default** route, and `-Source github` sets `$useGitHub` straight
to `$true` without ever asking it. So the caller who forces the remote route on a machine without gh
lands there exactly as the report describes.

#### The half the report did not name

At `ship-pr.ps1` the false advice also sits **outside** the parenthetical the report lists: the
enclosing `Write-Warning` closed with *"so a re-run normally settles it"*. Repairing only `$lockUnread`
would have satisfied the report and gone on printing false advice in the same printed sentence, which a
reader does not experience as two strings.

#### The seventh site, and why it stays

`claim-issue.ps1`'s parked-fix branch scan is the same shape and is deliberately left alone -- for a
reason stronger than the #2081 exemption the report cites for it: it reads **`git`**, not `gh`, and the
report's own scope paragraph excludes git-reading siblings, because git is a hard prerequisite of every
script here.

### CREATE

- [x] `scripts/lint/check-branch-entry.ps1` -- not-started arm ahead of the unmeasured one
- [x] `scripts/lint/check-repo-settings.ps1` -- launch-failure wording, since its PATH guard rules out an absent gh
- [x] `scripts/release/ship-pr.ps1` -- the arm, plus `$lockNotStarted` / `$lockRetry` so the enclosing warning branches too
- [x] `scripts/sync/check-connectors.ps1` -- launch-failure wording, behind its PATH and auth gate
- [x] `scripts/sync/check-consumer-siblings.ps1` -- both reads, kept in step with each other
- [x] Plugin mirrors resynced via `scripts/sync/build-shared-scripts.ps1` (3 updated)

### TEST

- [x] New suite `scripts/tests/native-not-started-wording.tests.ps1` -- 36 asserts, green
- [x] Proved it can fail: the two arms at `check-consumer-siblings.ps1` were swapped, the suite
      reported exactly one `[FAIL]` on the ordering assert, and the file was restored from a backup
- [x] Full lint + test gate via `open-pr.ps1`

### DEPLOY: fix/2250-gh-not-started-wording

Six `gh` reads composed their own sentence about an unmeasured exit code, so a `gh` that is **not
installed** -- a state #2234 deliberately reports with `ExitCodeUnknown` set, to keep the ~63 audited
sites working untouched -- was described as one that ran, and the reader was sent to a re-run that
cannot settle a missing dependency. Each now asks `Test-NativeCommandStarted` first, and names the
install as the remedy.

Two of the six say something different on purpose. `check-repo-settings.ps1` and
`check-connectors.ps1` sit behind a `Get-Command gh` guard that has already proved gh is on PATH, so
*"gh is not installed"* would be a cause the same run has measured to be false -- the class of
unmeasured diagnosis this whole family exists to stop printing. What is reachable at those two is a gh
that was found and still could not be launched, and their sentences say that instead.

At `ship-pr.ps1` the repair also reaches one layer out of what the report named: the enclosing
`Write-Warning` closed with *"so a re-run normally settles it"*, which is the same false advice in the
same printed sentence.

**Score:** 2

#### What makes this deploy extra special

Every one of these sentences is what a consumer reads in the window this workflow keeps measuring
against itself: adopting it before installing the GitHub CLI. The gate runners are the sharpest of
them -- `check-branch-entry.ps1` runs in a consumer's CI, and `ship-pr.ps1` prints its line while
merging -- and both told that reader to try again, forever, instead of naming the one thing that would
fix it. `check-consumer-siblings.ps1` reaches the same reader through `-Source github`, which bypasses
its own availability gate.

**Score:** 2

#### Pull Request

Six gh sites no longer say a missing gh ran, nor advise a re-run that cannot settle it
