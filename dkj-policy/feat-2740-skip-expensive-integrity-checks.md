## feat/2740-skip-expensive-integrity-checks

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Owner's decision on #2740 (option B, October 3, 2026): widen `$script:SkippableChecks` by the five
expensive checks (exec-policy/script, shopify-cli, mirror-depth, shared-script, shopify-force), have the
integrity fixture skip all eight by default, and let the scenarios about those five opt back in. No
`-OnlyCheck`.

### CREATE

- [x] `check-plugin-integrity.ps1`: the five blocks wrapped in `Test-CheckEnabled` with a `[SKIP]` line each; the list goes from 3 to 8; the docstring and the comments that said "three" or "NOT SKIPPABLE" updated
- [x] `check-plugin-integrity-fixture.ps1`: `$SkippedForSpeed` holds eight; `Invoke-Integrity -Run <name>` takes one name off the skip list and throws on a name that is not on it
- [x] 23 call sites opt back in with `-Run`: every scenario that asserts on one of the five, plus scenario 82, which asserts that no check reports anything
- [x] Sylvester's lens: the passage that held the list at exactly three now says it is eight, and why `section-number` stays off it

### TEST

- [x] Over a `New-IntegrityFixture` tree, n=5 medians: a child run with three skipped took 2.21s, and with eight skipped 1.43s (35% less). That is less than the ~47% the per-check stopwatch predicted, because three of the five read the shared parse cache, so the parse moves to `barred-skill` rather than going away
- [x] With the new default and no opt-ins, 20 presence asserts in four suites failed, which proves the skip took effect. With the opt-ins, all 15 integrity suites pass

### DEPLOY: feat/2740-skip-expensive-integrity-checks

The 15 `check-plugin-integrity-*` suites, which start the gate about 280 times between them, now skip
five more checks by default in each run: `exec-policy/script`, `shopify-cli`, `mirror-depth`, `shared-script` and
`shopify-force`. That takes each child run from 2.21s to 1.43s locally, so 35% less. On the three CI runs
measured in the issue, those suites were 35% of the test pool's work. A scenario about one of those five names it with
`Invoke-Integrity -Run '<name>'`, and an unknown name throws. The real gate (`open-pr`, CI) still runs
every check. `-SkipCheck` now accepts eight names instead of three
([#2740](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2740)).

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

check-plugin-integrity suites: skip the five most expensive checks by default

