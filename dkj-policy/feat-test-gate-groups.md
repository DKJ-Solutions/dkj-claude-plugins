## feat/test-gate-groups

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

Maikel found the /test-gate page unclear and asked whether the gates could be grouped by which actions
need them and which are optional. No suite is optional -- CI and open-pr run all of them on every PR --
so the grouping is by the workflow step each suite guards, kept in a fixed file (his choice over
deriving groups from file names).

- [x] Group all 162 suites into thirteen groups in `scripts/tests/suite-groups.json`, in workflow order

### CREATE

- [x] `ConvertFrom-SuiteDurations` takes `-Groups`: per group its recorded and unmeasured suites and total, plus the ungrouped and unknown names
- [x] `Format-TestGatePageHtml`: a group overview, one section per group, a not-grouped section, and the old single table when the groups file cannot be read
- [x] Every section closes on an h3 "Points to note" below its card, outside the table: per group from its `tips` in `suite-groups.json`, verified against the tree; the overview, not-grouped and measured sections carry their own
- [x] Split advice: the six large groups (14 or more suites, or 10% or more of the sum) carry a hand-written `split` in `suite-groups.json`, shown in their notes; the overview's notes name them largest first with their measured size
- [x] Every table closes on a total row: its suites' seconds summed, labelled as run one after another, since CI runs them in parallel
- [x] `Get-TestGateModel` reads `suite-groups.json` beside `suite-durations.json`
- [x] `.dp-link` takes `--primary-11` instead of `--primary-9` and loses its underline except on hover and keyboard focus: Maikel found the links hard to read on the page

### TEST

- [x] `dev-pages.tests.ps1`: the group model, the page, the fallback, and a tree assert that every suite on disk is in exactly one group
- [x] `dev-pages` and `connector-dashboard` suites green locally
- [x] Victor and Edith reviewed the diff; their findings are applied (the merge-push wording in the note, two suites regrouped, a groups file with no groups warns, an ungrouped unmeasured suite is listed)

### DEPLOY: feat/test-gate-groups

The dev server's /test-gate page groups the test suites by the workflow step they guard -- starting a
branch, the PR, the fold, the release, the lint gate, CI, the hooks, adoption, machine upkeep, the dev
pages, the BWJ and Shopify plugins and the shared libs -- with each group's suite count, cost and share and a few points to note per section,
closes every table on a total -- the seconds summed as if run one after another, which the label says CI
does not do -- and says in its lead that no suite is optional: every one runs on every PR. The grouping lives in
`scripts/tests/suite-groups.json`, and `dev-pages.tests.ps1` fails when a suite on disk is in no group,
so a new suite is grouped in the PR that adds it. The links on the hub's pages (`.dp-link`) take
`--primary-11` instead of `--primary-9`, which read poorly as link text, and are underlined only on hover
and keyboard focus.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server page and the suite grouping are this repo's own; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

Test gate page groups the suites by the workflow step they guard

