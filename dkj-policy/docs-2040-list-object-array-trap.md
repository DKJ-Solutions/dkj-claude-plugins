## docs/2040-list-object-array-trap

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

#### The judgement the issue deferred

#2040 filed a verified, latent authoring hazard and named one open question for whoever wrote it up:
the trap **throws**, so it does not match the section title *"produce well-formed wrong output"* as
written — *"either the title widens or the row says so in its first line"*.

Chosen: **the row says so, and the title stands.** That is the section's own established convention —
its intro already carries one exception clause in exactly that shape (*"Ten are PowerShell's own; the
last is the same class one layer out"*) — and widening a title to cover one member of twelve weakens
the promise the other eleven keep. What makes it belong anyway is the honest reading: what is
well-formed and wrong here is the **exception's own report**, which blames the start of the enclosing
hashtable literal and names neither the operator nor the type. The section's closing sentence (*"when a
mistake cannot announce itself, the assert is the announcement"*) already covers that, so the shape was
there before the member arrived.

### CREATE

- [x] Verify the six pickup checks before repairing — symptom reproduced in isolation on this machine
      (PS `5.1.26100.9444`, `ArgumentException` on `@($l)`; `List[string]`, `[object[]]` and
      `.ToArray()` all fine); subject exists (the section at `05-15-manual.md:219`); the proposed
      repair names a real section; the repo is the right one.
- [x] Verify the *mechanism* the row states, not only the symptom — a returned list arrives already
      unrolled (`(Get-L).GetType()` is `System.Object[]`, so `@(Get-L)` is fine) while the same `@()`
      on a variable still holding the `List[object]` throws, and it fires one level up inside a
      `[pscustomobject]@{ … }` literal.
- [x] Write the twelfth row, placed beside the other array-literal trap (the comma-precedence one) so
      the `sed` trap stays last and the intro's *"the last is … one layer out"* clause stays true.
- [x] Update the three counts the section carries — heading, intro and closing sentence — and add the
      intro's exception clause for the member that throws.
- [~] Carry the issue's *"9 files under `scripts/`"* count into the row — dropped. Measured here it is
      already **10**, because #2037's own `always-on-budget-lib.ps1` landed between the filing and this
      branch. A count that moves in two days does not belong in a **portable** manual that ships to
      consumers whose trees it never described; the row states the mechanism instead, which does not age.

### TEST

- [x] `check-plugin-integrity.ps1` + all test suites green (run by `open-pr.ps1`).
- [~] Add a regression guard for the trap itself — dropped, one already exists and the row cites it:
      `scripts/tests/always-on-budget.tests.ps1` asserts the row sets come back as arrays built with
      `.ToArray()` rather than `@()`. A second guard would pin the same line twice.

### DEPLOY: docs/2040-list-object-array-trap

Sylvester's trap list gains a twelfth member: `@(...)` on a `List[object]` still held in a variable
throws `ArgumentException` — naming neither the operator nor the type, and blaming the start of the
enclosing hashtable literal rather than the line at fault. No live defect anywhere in the tree; every
existing caller survives by accident, because it wraps a list a *function returned* and a returned list
is unrolled to `object[]` before the operator sees it. The row names `.ToArray()` as the repair and
points at the worked example and the regression guard that already carry it.

**Score:** 2

#### What makes this deploy extra special

A consumer's developer reaches this manual through the plugin, and the trap is one ordinary edit away in
any repo that builds a `List[object]` — the house `@(...)` idiom is what walks them into it. Documented,
it is a lookup; undocumented, it is a bisection against an exception that points at the wrong line.

**Score:** 1

#### Pull Request

A twelfth PowerShell trap: the array-subexpression operator throws on a List[object]

