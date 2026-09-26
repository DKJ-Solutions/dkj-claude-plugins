## fix/2542-deep-fence-closes-on-dedent

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

#### Scope

Issue #2542: under `-AnyIndent`, a line indented four or more spaces that starts with three backticks
(pasted terminal output under a paragraph) opened a fence that never closed. On GitHub it is an indented
code block that ends when the indentation drops. `Get-GateBypassLines` then read nothing below it, and
`Add-GateBypassLines` returned the body unchanged, so a new bypass line was dropped silently.

#### The decision

The issue offered two directions: bound the lifted indent by the list container, or drop `-AnyIndent` in
the PR-body readers. The first is taken, because it fixes the one shared primitive for every reader and
not just the PR-body ones. The tracker sees no containers, but it does not need to. A fence opened at
N > 3 spaces can only sit in a container whose content starts at N-3 or deeper, so a non-blank line
indented less than that ends the block. The state carries N (the indent in spaces plus the run), and a
new `Resolve-FenceState` gives callers the state *at* a line, so the line that ends the block is not
skipped as part of it. A valid closer below the bound still closes. Reading it as a new, unclosed opener
(strict CommonMark) is the same swallow-the-rest failure.

`Add-GateBypassLines` now decides between insert and append from one fence-aware scan. A body that only
quotes the heading in a fence gets a new section instead of a silent no-op.

### CREATE

- [x] `fence-lib.ps1`: deep opener carries its depth; `Resolve-FenceState` and `Get-FenceIndentWidth` added
- [x] All 17 `-AnyIndent` call sites read their state-before through `Resolve-FenceState` (pr-body-lib 8, check-plugin-integrity 5, pr-issues-lib, entry-scaffold-lib, open-pr, check-roster-sync)
- [x] check-plugin-integrity's two transition loops (record-query, consumer-doc samples) annotated: a block ended by indent goes unjudged
- [x] `Add-GateBypassLines`: the append branch reads the same fence-aware scan as the insert branch
- [x] Mirrors regenerated (`build-shared-scripts.ps1`)

### TEST

- [x] `fence-lib.tests.ps1`: the deep-block bound, the column-0 closer, tabs, the measured gate-bypass case through both readers, the quoted-heading append, and a tree-wide guard against a bare `$was = $fence` beside `-AnyIndent` (falsified against the old shape)
- [x] fence-lib, pr-body and measure-always-on green locally

### DEPLOY: fix/2542-deep-fence-closes-on-dedent

A PR body's gate-bypass section is no longer lost below a line of pasted output. Terminal output indented
four spaces and starting with three backticks is an indented code block on GitHub, but the workflow's
markdown readers treated it as a fence that never closed. Everything below it counted as quoted. So
`Get-GateBypassLines` read no bypass section, and `Add-GateBypassLines` dropped a new bypass line without
an error. A fence opened deeper than three spaces now ends at the first line indented less than any list
container could allow. That applies to every reader sharing `Get-NextFenceState`: the PR-body scans, the
resolves reader, the entry format, open-pr's template scan, the roster check and the lint gate. Separately,
a body that only quotes the gate-bypass heading in a code block now gets a real section appended instead
of an unchanged body.

**Score:** 1

#### What makes this deploy extra special

N/A. Workflow tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

A deep fence ends when its container does, so a gate-bypass line is not dropped
