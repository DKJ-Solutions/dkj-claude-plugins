## feat/2361-pr-bypass-note

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

#2361: the workflow says a deliberate `-SkipLint`/`-SkipTests` belongs in the PR body, and the receipt
printed that sentence, but neither `open-pr` nor `ship-pr` could write it -- `-Body` replaces the template
and `-RefreshBody` rewrites from the document -- so it took a hand edit of the body the DEPLOY lock reads,
and on PR #2357 that edit flattened the body and the lock refused the merge after a full CI wait. Verified
against the tree: `Get-GateBypassNote` already names the skipped switches for the receipt, and
`Test-DeployLock` tests containment, so an appended sibling section cannot trip it. Build the section into
open-pr, modelled on the closing block.

#### Resumed September 24, 2026: the issue's two later comments

Two further measurements landed on #2361 after this branch was parked (BWJ-Development/xoxowildhearts
PR #275, and PR #2363 here). Both were a caller-supplied `-Body` that skipped the placeholder fill, so it
published without the DEPLOY section and was refused at the lock after CI. That is the same root as the
issue title, so it is repaired here: the placeholder is filled in a `-Body` too, and a `-Body` still
lacking the section is refused before the gates. The PS 5.1 argument split in the first comment is a
different subject, and is filed as #2405.

### CREATE

- [x] `pr-body-lib.ps1`: `New-GateBypassLine`, `Get-GateBypassLines`, `Add-GateBypassLines` (idempotent per
  line, level read off the body, fence-aware) plus `Get-GateBypassHeadingText`
- [x] `open-pr.ps1`: `-BypassNote`; the line is added on the create path and on the existing-PR path, where
  the lines the body already carried are read before a refresh and put back after it
- [x] `ship-pr.ps1`: `-BypassNote` forwarded; `closeout-lib.ps1`'s receipt line says the record was written
- [x] Plugin mirrors synced; `open-pr` and `ship-pr` skill pages name the parameter
- [x] `pr-body-lib.ps1`: `Complete-SuppliedPrBody` fills the entry's description at the placeholder of a
  caller-supplied `-Body`; `open-pr.ps1` runs it before the gates and refuses a `-Body` that
  `Test-DeployLock` says does not carry the DEPLOY section (placeholder resolution moved up to serve it)

### TEST

- [x] `pr-body.tests.ps1`: 21 new asserts (line shape, forged-newline, idempotence, append-not-replace,
  level, placement above the next section, fence, restore after refresh, DEPLOY lock still holding) --
  229 pass
- [x] Code review (Victor): one real bug -- the reader ran to the next heading, so a body-final section
  swept in the headingless no-resolves marker a `-SkipTests -NoResolves` run leaves below it, and the next
  refresh would have welded it in. Repaired (only list items are section lines) and pinned; also kept a
  CRLF body CRLF on insert, and a blank line above a heading that follows the section
- [x] Gates via `open-pr -GatesOnly`
- [x] `pr-body.tests.ps1`: 7 asserts for `Complete-SuppliedPrBody` (fill, caller lines kept, lock holds
  once filled, empty description, untouched without placeholder, note-only body is lock-refused, CRLF) --
  236 pass
- [ ] Code review (Victor) of the supplied-`-Body` check

### DEPLOY: feat/2361-pr-bypass-note

A run of `open-pr` or `ship-pr` that skips a gate now records it in the PR body itself: a **Gate bypass**
section naming the switches, with the reason given by the new `-BypassNote`, or a line saying none was
given. The section is kept across `-RefreshBody`, and a later bypass is added beneath an earlier one. Until
now the workflow asked for that record and the tooling offered no way to write it, so it took a hand edit
of the body the DEPLOY lock reads; on PR #2357 that edit flattened the body and the merge was refused
after a full CI wait.

A body passed with `-Body` now gets the entry's description filled in at the template's placeholder, as
the default body does. A `-Body` that still lacks the DEPLOY section is refused before the gates, instead
of opening a PR the DEPLOY lock would refuse to merge after CI.

**Score:** 3

#### What makes this deploy extra special

A consumer whose session has to ship past a gate gets the record the workflow asks for without touching
the PR body by hand, which is the step that broke a merge here. Visible to whoever runs `open-pr`/`ship-pr`
with a skip switch after the next plugin update, and to anyone reviewing such a PR.

**Score:** 2

#### Pull Request

open-pr/ship-pr: record a gate bypass in its own PR-body section that survives -RefreshBody

