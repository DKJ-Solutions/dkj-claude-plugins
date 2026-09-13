## feat/1954-widen-fixture-load-guard

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

#### What #1954 asked, and the question it left open

#1954 measured 82 captured child-script invocations under `scripts/tests/`, 11 of them in a scope that
judges, and filed the remaining **71 findings in ~65 suites** as a proposal to widen the #1934 fixture
load guard. It deliberately did not decide whether widening was worth it, and named the cheaper
alternative to measure first: whether the per-suite `Invoke-*` helpers could carry the call once, so
that *"the true edit count is well below 65."*

#### The subject is not 65 suites, it is SIX

The probe #1954 ran counts every child invocation whose output is captured. The hazard needs one thing
more: the child has to be a **copy**. `fixture-script-lib.ps1` exists because a fixture that does not
carry a lib the copied script dot-sources **unguarded** kills the child during load -- and a child run
from the repo in place resolves its libs against the real tree, which is complete by construction. It
has no copy list, so it has nothing that can go stale.

Re-measured against that rule:

| | |
|---|---|
| suites that copy a `.ps1` into a fixture and run it | **17** |
| already wired by #1934 | 6 |
| deliberately out of scope (below) | 5 |
| **genuinely unwired and exposed** | **6** |

The first pass of this probe found 15, not 17: it matched `Copy-Item` calls whose text names a `.ps1`,
and a copy written entirely through variables -- `Copy-Item -LiteralPath $Guard -Destination $orphan` --
names none. Reading the variable's own assignment found `guard-live-theme` and `guard-working-copy`,
both of which then turned out to be exclusions. The hole was worth closing anyway: the same shape could
just as easily have hidden a genuine candidate.

#### The five exclusions, each for a different reason

- **`cut-release-drive`, `shared-scripts`** -- they copy `.ps1` files into a fixture, but the acting
  script under test runs from the **repo**. The copies are consumer-side seams the script reads through
  its `-RepoRoot`, not siblings it resolves through `$PSScriptRoot`. Same shape as `bootstrap-drift`,
  which the first probe never flagged at all.
- **`guard-working-copy`, `guard-live-theme`** -- they copy the guard into a directory with **no libs on
  purpose**, because degrading on a missing lib is the behaviour under test. Their loads are guarded, so
  there is no load failure to find, and a headline saying *"add it to this suite's copy list"* would
  point at the one thing that is working as designed.
- **`source-repo-guard`** -- already declared out of scope by the tree's own mechanism:
  `# fixture-dep: script-not-loaded scripts/lint/check-branch-entry.ps1`. That opt-out was specified
  under #1693 before it was needed and #1924 produced its first instance. Wiring over a standing,
  argued declaration would be the wrong direction.

#### And the cheap alternative #1954 hoped for does not exist

There is no helper shared **across** suites to carry the call once: each of the six funnels its own
child invocation through its own `Invoke-*`. The one real saving is `check-plugin-integrity-fixture.ps1`,
where both the invocation and the close-out are already shared -- so one wiring there covers **four**
suites. Six suites, five wirings.

### CREATE

- [x] `find-specialist-mentions` -- the reference wiring
- [x] `check-plugin-integrity-fixture` -- one wiring, four suites
- [x] `consumer-check-lib`
- [x] `park-cycle`
- [x] `internal-note`
- [x] `connector-sessioncheck` -- three call sites, two of which captured stdout only

#### The wiring is FOUR parts, not three, and the fourth is load-bearing

#1934 describes three parts: the dot-source, the `Assert-FixtureScriptLoaded` call, and
`Write-FixtureScriptSummary` whose verdict is read. Wiring those three into a suite running under
`$ErrorActionPreference = 'Stop'` produces a guard that **never fires**. Under `& powershell ... 2>&1`
the parent re-renders the child's stderr as its own `NativeCommandError`, which at `Stop` is
*terminating* -- so a child that died on load kills the suite at the invocation, and the verdict on the
next line is never reached.

Measured by dropping `check-report-lib.ps1` from `find-specialist-mentions`'s copy list:

| | |
|---|---|
| three parts, EAP left at `Stop` | the run ends at the first case with a truncated `NativeCommandError`, no headline |
| EAP lowered for the call | three headlines naming `check-report-lib.ps1` and the copy list |

The six suites #1934 wired already made this arrangement; it simply was not stated as part of the
wiring. And a second sub-part sits beside it: the verdict reads the child's **output**, so a call site
capturing stdout only has nothing to judge. Two of `connector-sessioncheck`'s three did exactly that.

### TEST

- [x] every wired suite green and unchanged: `find-specialist-mentions` 31, integrity-docs 144,
      `park-cycle` 112, `internal-note` 111, `consumer-check-lib` 9, `connector-sessioncheck` 51
- [x] the guard PROVEN to fire, not merely present -- `find-specialist-mentions`'s copy list broken on
      purpose, before and after the EAP repair, with the two outcomes in the table above
- [x] check 41 `[fixture-script]` counts the newly wired files and stays at 0 findings, so every one of
      them carries all three parts and reads its verdict

### DEPLOY: feat/1954-widen-fixture-load-guard

A fixture whose acting script dies during **load** writes nothing, and what the suite then reports is
the absence of the document the child never got far enough to write -- naming the absent lib, the
dot-source and load failure not at all. Worse, a case that only checks something is ABSENT *passes*.
#1934 built the reader for that and wired it into the six suites #1924 had measured failing; #1954 asked
how far it should reach.

Filed as 71 findings in ~65 suites, the answer is **six**. The probe behind that number counts every
captured child invocation, and the hazard needs a **copied** child: a script run from the repo in place
resolves its libs against the real tree and has no copy list to go stale. Of the 17 suites that do copy
one, six were already wired and five are out of scope for three separate reasons -- the acting script
runs from the repo, the missing lib is the behaviour under test, or the tree's own
`fixture-dep: script-not-loaded` opt-out already covers it.

The six are wired in five edits, because `check-plugin-integrity-fixture.ps1` shares both its invocation
and its close-out across four suites.

And the wiring turned out to be four parts rather than three. Under `$ErrorActionPreference = 'Stop'`
the child's stderr comes back as a terminating `NativeCommandError`, so the suite dies at the invocation
and the verdict never runs: the three documented parts alone produce a guard that is present and inert.
Measured by breaking a copy list on purpose -- a truncated `NativeCommandError` and no headline before,
three headlines naming the missing lib after.

**Score:** 3

#### What makes this deploy extra special

Nothing here ships to a consumer: `scripts/tests/` is mirrored into no plugin. The reader served is
whoever next edits one of these fixtures, and what they get is a headline naming the file to add
instead of a wall of asserts about a document that was never written.

**Score:** N/A

#### Pull Request

The fixture load guard reaches every suite that copies an acting script
