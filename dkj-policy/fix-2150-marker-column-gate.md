## fix/2150-marker-column-gate

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

#### What #2150 left open, and what this branch decided

The report proposed the check and was explicit about what it had NOT settled: the home
(`check-plugin-integrity.ps1`), the shape (a per-literal AST rule), and above all the subject set --
*"'a check script' needs a definition"*. It also flagged that the fixture layer would have to be
excluded the way `[exec-policy/script]` excludes it.

The subject set is the part that changed. A directory or a filename pattern is a guess; the exact
definition is **a script whose output a hook reads through the anchored selector**, and both halves of
that -- the markers, and the path -- are readable off the hook itself. So the set is derived rather
than listed, which also retires the fixture-exclusion question: a test fixture is not named by any
hook, so it was never in scope to exempt.

The shape changed too. A per-literal rule passes `("note: " + "[ERROR] x")`, because the marker does
open its own literal. The unit is the emitted line.

- [x] Verify the report against the tree before building it -- the anchor, the 26 call sites and
      whether every current emission really is a prefix
- [x] Measure the naive rule tree-wide, to see what the narrowings are actually buying

### CREATE

- [x] Check 45 `[marker-column]` in `scripts/lint/check-plugin-integrity.ps1`, with its subject set
      derived from the hooks
- [x] Register it in the `checks:list` span -- caught by the gate's own check-list guard, not by hand

### TEST

- [x] Scenarios in `scripts/tests/check-plugin-integrity-docs.tests.ps1`: the clean shape, the defect,
      the concatenation, the `-f` placeholder, the data field, and a check no hook reads
- [x] Full lint gate green, and the check born green at 69 emissions / 0 findings
- [x] All suites green

### DEPLOY: fix/2150-marker-column-gate

A new lint check, `[marker-column]`, holds a verdict marker to the **start** of the line a check
writes -- the convention the SessionStart hooks have silently depended on since #2142 anchored their
selector to `^\s*`. Before this, a future `Write-Host "note: [ERROR] ..."` in a check would have had
its finding dropped by the hook with no error, no red check and nothing in session context: the exact
failure the hooks exist to prevent, arriving through the front door.

The subject set is **derived from the hooks rather than listed** -- a subject is a script whose output
a hook reads through the anchored selector, so each hook contributes the markers its own
`Select-CheckMarkerLine` calls name and the check its own path literal names. A new hook brings its
check into scope on the day it is written, and no list goes stale. The markers are held per subject
rather than as one union, so a marker no hook selects from a given script is not reported and the
finding can name the hook that would do the dropping.

The unit is the **emitted line**, not the string literal: a `+` concatenation, a `-f` format string
and an argument array are all walked, with anything unknowable statically standing in as one
non-whitespace placeholder. That is what makes `("note: " + "[ERROR] x")` a finding, which the
per-literal shape the issue sketched would have passed.

Born green: 14 hook files, 8 of which select on markers, 15 check scripts, 69 marker emissions, 0
findings and 0 exemptions.

**Score:** 2

#### What makes this deploy extra special

Every repo running this workflow receives the hooks whose selector this convention protects, so the
guard travels with them. It changes nothing a consumer does and fires on nothing they have today --
it only stops a future check script from writing a line whose finding would never arrive.

**Score:** 1

#### Pull Request

A gate holds a check's verdict marker to the start of the line the hook selector anchors on

