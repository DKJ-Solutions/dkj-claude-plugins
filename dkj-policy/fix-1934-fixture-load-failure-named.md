## fix/1934-fixture-load-failure-named

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

The suites already capture the load failure and discard it. Judge the child's exit code at the
invocation and print what was captured, naming the absent lib.

#### Why neither filed candidate was built

#1934 declined to choose a repair and asked whoever picked it up to measure first. The measurement
retired both candidates, because both rest on a premise that does not hold.

Reproduced September 13, 2026 on a scratch fixture holding `fold-changelog-entry.ps1` **without**
`check-report-lib.ps1`, invoked exactly as `Invoke-Fold` invokes it. The child's own output:

```
'...\..\lib\check-report-lib.ps1' is not recognized as the name of a cmdlet, function,
script file, or operable program.
At ...\fold-changelog-entry.ps1:204 char:3
+ . (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
```

The absent lib, the dot-source and the exact line are all there, and the child exits 1. **Five of the
six suites already capture both** -- `fold-changelog`, `prune-merged`, `park-branch` and
`worktree-lane` with `2>&1` into a variable, `new-branch` through `Start-Process` redirect files.
They simply never look. So the fixture builder does not need to probe its own copy list (candidate 1,
which would be the hand-listed copy list #1693 and #1924 both exist because nobody maintains), and
nothing needs re-running with output captured (candidate 2) -- it is already captured. What was
missing was a reader.

**The sixth is the exception, and it is the one with the scar.** `entry-scaffold.tests.ps1` invokes
its child as `2>$null | Out-Null` at two sites and reads only the exit code -- so there the diagnosis
really is destroyed rather than ignored. Its own comment already records this class from the other
side: inbound #1046, where that fixture was missing `native-capture-lib.ps1` and the run passed over a
script that had died, for two weeks. Capturing is one line there, and still not a re-run.

### CREATE

- [x] `scripts/lib/fixture-script-lib.ps1` -- the runtime sibling of `fixture-git-lib.ps1`, whose
      shape it follows deliberately (a counter in the calling suite's scope, a verdict that prints
      and does not throw, a summary that turns the count into an exit code).
- [x] **The signature is the error ID, never the English prose.** `is not recognized as the name of a
      cmdlet` is localized -- the symptom #1934 quotes is Dutch, off this same class -- so keying on
      it would hand a reader on a localized Windows exactly the silence this exists to remove.
      `FullyQualifiedErrorId` values are not localized, so `CommandNotFoundException` is what matches.
- [x] **Silent on a deliberate refusal**, which is what makes it safe to wire into a shared invocation
      helper. Dozens of cases here assert a non-zero exit on purpose; a refusal carries no
      `CommandNotFoundException`. A load failure is never an expected refusal -- it means the FIXTURE
      is broken, not that the script declined.
- [x] Wired into all six suites: the four `2>&1` helpers, `new-branch`'s `Invoke-CapturedChild`, and
      both `entry-scaffold` sites, which now capture instead of discarding.
- [x] `-Code` is deliberately untyped, where `Assert-FixtureGitOk`'s is `[int]`. One caller passes
      `$proc.ExitCode` from `Start-Process -PassThru`, which comes back absent often enough to have
      its own measurement (#1920: 27 of 960 captures at 16 lanes). Typed, that `$null` arrives as `0`
      and the function returns early -- silent exactly where the run is already strange.

### TEST

- [x] `scripts/tests/fixture-script-lib.tests.ps1` -- **30 pass, 0 fail.** The load-failure case runs
      a REAL child that dot-sources a lib that is not there, rather than feeding the matcher a canned
      string: the signature is produced by PowerShell, not by this repo, so a hand-written fixture
      would only prove the regex matches itself. Both silence cases are asserted with a real child
      too, and the localized-message case proves the ID and not the sentence is what is read.
- [x] **The end-to-end proof.** `check-report-lib.ps1` was removed from `fold-changelog`'s copy list
      -- #1917's breakage exactly -- and the suite re-run. It produced **155 red asserts**, the same
      figure #1924 reported for that suite, so the reproduction is faithful. Above them now sit 53
      `[FIXTURE SCRIPT DIED ON LOAD]` headlines naming `check-report-lib.ps1`, and a closing block
      saying the asserts are not a verdict on the script under test. The copy list was restored and
      the suite is green again (264 pass).
- [x] Two artefacts were caught by that proof and repaired before shipping, both of them the
      **same defect as #1936**: a headline that names something which does not exist. The child's host
      WRAPS its error text at its own console width, so `...\task\pretend-acting.ps1` broke after
      `preten` and `d-acting.ps1` was read as a file; and a `CategoryInfo` line truncates its target
      mid-path, so `...-helper-lib.ps1` was read as another. `Out-String -Width` cannot undo a wrap
      baked in upstream, so a leaf is now only accepted behind a `\`, `/` or quote, and a leading dot
      is rejected. Asserted in the suite, not just described.
- [x] All six modified suites re-run: green. Lint gate: 0 errors.

#### What the review chain changed

Victor, Edith and Tycho ran in parallel on the diff.

- **Victor** found no bug, and named one boundary worth acting on: `CommandNotFoundException` says
  PowerShell could not resolve *some* command, which a mistyped cmdlet **inside** an acting script
  also raises -- long after load, and a bug in that script rather than a gap in the copy list. The
  verdict now takes one of **two** headlines: with a `.ps1` behind it, the load-failure line and the
  copy-list pointer; with none, an `UNRESOLVED COMMAND` line that claims neither. Claiming
  *"never ran"* there would have been false, and pointing at the copy list would have sent the reader
  to repair the one thing that is not broken -- #1936's defect, one layer over.
- **Tycho** found two cheap coverage gaps and both are closed. `Write-FixtureScriptSummary`'s `$false`
  path -- the one every wired suite takes on a green run -- was unproven, so a guard that always
  printed would have passed the whole suite; it is now asserted in a **fresh child process**, since
  the counter lives in the calling suite's own scope and is non-zero by then. And the wrap guard was
  proven only incidentally, by a real host that happened to wrap; it now has a **canned** wrapped
  string beside the canned localized one, so a wider console cannot turn that proof green by absence.
- **Edith** reproduced every number in this document independently -- 155 red asserts, 53 headlines,
  264 pass restored, 0 lint errors -- and found one capitalisation typo, repaired.

Tycho's third point is filed as **#1948** rather than built: nothing asserts the wiring itself is
present, so a future edit that drops an `Assert-FixtureScriptLoaded` call would silently restore this
class. That is a tree-wide AST check of the kind #1693/#1865/#1924 each ended up building, which is
new machinery beyond this branch's subject.

### DEPLOY: fix/1934-fixture-load-failure-named

A fixture whose acting script dies during **load** now says so, names the lib it could not load, and
prints what the child actually said. Before this, what the suite reported was the absence of the
document the script never got far enough to write -- `Kan een gedeelte van het pad ... niet vinden`
-- naming the absent lib, the dot-source and load failure not at all. Measured on the #1917 branch,
six suites failed exactly that way; re-measured here, `fold-changelog` alone turns 155 unexplained red
asserts into 53 headlines that each name `check-report-lib.ps1`.

Neither repair #1934 proposed was built, and the measurement is why: the diagnosis was already in the
child's output and already captured by five of the six suites. They never read it. So this adds a
reader -- `fixture-script-lib.ps1`, the runtime sibling of `fixture-git-lib.ps1` -- rather than a
probe over the hand-listed copy list that #1693 and #1924 both exist because nobody maintains. The
sixth suite, which really did discard its output, now captures it.

**Score:** 3

#### What makes this deploy extra special

Nothing here ships to a consumer: `scripts/tests/` is not mirrored into any plugin, so this lib has no
mirror and no release to travel on. It is maintenance-repo tooling, and the reader it serves is
whoever next meets a red suite in this tree.

**Score:** N/A

#### Pull Request

A fixture script that dies on lib load now says so, instead of reporting a missing document
