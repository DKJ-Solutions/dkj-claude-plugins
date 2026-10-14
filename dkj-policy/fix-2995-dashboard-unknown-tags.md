## fix/2995-dashboard-unknown-tags

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

Verified the reported reason before repairing it: `ConvertFrom-ConnectorCheckOutput` matched only
`[ERROR|INFO|OK|SKIP]`, while `check-connectors.ps1` prints four more tags inside a connector block --
the three the issue names plus `[UNREGISTERED]`. The page's counts and signal list also read only
`ERROR`/`INFO`/`SKIP`, so widening the regex alone would still have hidden them. Hence: accept any
tag, and read every tag other than ERROR, OK and SKIP as INFO, which carries status, counts and list
with no rendering change.

### CREATE

- [x] `scripts/lib/connector-dashboard-lib.ps1`: the parser takes any bracketed tag and reads an
  unknown one as INFO; the header docstring says why
- [x] `scripts/tests/connector-dashboard.tests.ps1`: a connector block carrying all four markers

### TEST

- [x] `connector-dashboard.tests.ps1` standalone: 69 passed, 0 failed

### DEPLOY: fix/2995-dashboard-unknown-tags

The connector dashboard no longer shows a repo as `In sync` while `check-connectors.ps1` reports a
marker for it. The parser kept only the `[ERROR]`, `[INFO]`, `[OK]` and `[SKIP]` tags, so
`[INVENTORY]`, `[UNLISTED]`, `[UNREGISTERED]` and `[NOT-INSTALLED-HERE]` were dropped. It now keeps
every bracketed tag and reads a tag other than those three as a note. The repo then shows as
`Has notes` and the marker appears in its card
([#2995](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2995)). No marker fires today,
so this prevents a failure that has not happened yet: a repo reading as in sync while its register
entry is behind.

**Score:** 1

#### What makes this deploy extra special

N/A: the dashboard is a local maintenance view of this repo, and no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard keeps every signal tag the check prints
