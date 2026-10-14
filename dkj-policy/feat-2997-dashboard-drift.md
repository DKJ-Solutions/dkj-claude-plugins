## feat/2997-dashboard-drift

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

Each `-- drift-check: <repo>` header names its repo, so the block reopens that repo's record. Its two
summary lines become a Drift record. Only its `[ERROR]` (the check's own verdict on agent-def drift,
which the parser used to drop with the rest of the section) joins the signals. The per-file
`[DRIFTED]`/`[IDENTICAL]` lines carry local paths and are already counted in the summary, so they
stay out. Persona drift stays informational. A visible result: parked for the owner's look.

#### Parked for the owner's eye

On the connector dashboard (http://localhost:4872/, served from this branch), each consumer card
present on this machine has a new `Drift:` line under its plugin list.

### CREATE

- [x] `scripts/lib/connector-dashboard-lib.ps1`: drift blocks parsed into a per-repo Drift record,
  `Format-DashboardDrift`, and the card line
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: the check runs without `-SkipDrift`, and the
  record reaches the model
- [x] `scripts/tests/connector-dashboard.tests.ps1`: group 1b1, and the group 1a assert that pinned the
  old "drift adds nothing" behaviour rewritten for the summary line

### TEST

- [x] `connector-dashboard.tests.ps1` standalone: 90 passed, 0 failed
- [x] The page served from this branch on this machine: three consumers present show `Drift: 0 dead
  copies, 0 drifted agent defs, 0 of 4 personas drifted`
- [x] `open-pr.ps1 -GatesOnly` before the park

### DEPLOY: feat/2997-dashboard-drift

The connector dashboard now shows each consumer's agent-def and persona drift. Before, the server ran
`check-connectors.ps1 -SkipDrift`, so this was seen only by running the check by hand. Each card on this
machine has a line counting dead copies, drifted agent defs and drifted personas. Agent-def drift marks
the repo `Needs action`, as the check itself counts it. Persona drift stays informational and never
changes a status on its own. A page build takes about 1.4 s longer
([#2997](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2997)).

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local maintenance view of this repo, and no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard shows agent-def and persona drift per repo

