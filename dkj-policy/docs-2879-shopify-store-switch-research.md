## docs/2879-shopify-store-switch-research

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

Inbound #2879 asks for research, not for a build. The owner switches the claude.ai Shopify connector
between the two BWJ store repos all the time, and every switch costs a manual `/mcp` re-auth. The
deliverable is a short written finding with one recommendation, landed as a dossier under
`research/<topic>/` (Rebecca's lens), plus a follow-up issue for the skill or check itself if the
recommendation holds up.

### CREATE

- [x] Rebecca #07 researches the four questions in the issue (source-cited, measured vs inferred)
- [x] Marlowe #29 red-teams the recommendation before it is written down -- holds with corrections; the connector mismatch check became the primary recommendation and the CLI route an optional read-only extra
- [x] Tessa #16 lands the finding as `research/shopify-store-switch/finding.md`
- [x] File the follow-up issues: #2880 (connector store-mismatch check), #2881 (guard gap Marlowe confirmed)

### TEST

- [x] Every link in the finding points at a source fetched during the research, or at an issue filed in this branch; the lint gate runs at open-pr

### DEPLOY: docs/2879-shopify-store-switch-research

A research dossier, [`research/shopify-store-switch/finding.md`](../research/shopify-store-switch/finding.md), answers [#2879](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2879): why the claude.ai Shopify connector has to be switched by hand between the two store repos, and what can make that easier. A second connector or a per-project Admin MCP is not available. Shopify CLI `store auth`/`store execute` gives a per-store channel for scripted reads, but the token lifetime has to be measured before any skill depends on it. The recommendation is a store-mismatch check that catches the wrong store at the first call ([#2880](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2880)). The research also confirmed that `guard-live-theme` does not see `shopify store execute --allow-mutations` ([#2881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2881)).

**Score:** 2

#### What makes this deploy extra special

N/A -- a research document in the source repo; no plugin ships anything new from it.

**Score:** N/A

#### Pull Request

Research: switching the claude.ai Shopify connector between store repos

