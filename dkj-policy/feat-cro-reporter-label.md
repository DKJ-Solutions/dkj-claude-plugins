## feat/cro-reporter-label

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

Dave asked for a new GitHub label, `CRO`, known only to consumers of the `dkj-policy-bwj` plugin: it
marks a GitHub issue filed by, or on behalf of, the CRO team (today: Johnno), and it applies only in a
repo that is an actual Shopify store linked to an Asana project -- `smartwatchbanden` and
`xoxowildhearts`, never this plugin's own source repo `dkj-claude-plugins`, which has no store.

Every existing classification label on this tracker (`documentation`, the reach label, `needs-info`) is
set by judgement at the moment `report-issue` files the issue, never derived automatically from GitHub
metadata -- so `CRO` follows the same shape: documented as a fourth classification axis (who reported it,
not what it is), with no seam, since the scope is a fixed list of two repos rather than something a
function needs to answer.

### CREATE

- [x] Add the `CRO` row to the classification table in `WORKFLOW-portable.md`, and its own subsection
  explaining the axis and the store-repos-only scope.
- [x] Add the matching row to `report-issue`'s own step-1 table, pointing back at the portable page.
- [x] Add the label-creation step to `adopt-dkj-policy-bwj`'s step 4, explicit that it is skipped for
  `dkj-claude-plugins`.

### TEST

Documentation-only change to the `dkj-policy-bwj` plugin's portable pages -- no script or config
touched, so no test suite applies. Verified by reading the three edited files back for internal
consistency (the table row, the subsection anchor link, and the skip-here instruction all agree), and
the lint gate (`open-pr.ps1` / `check-plugin-integrity.ps1`) is the mechanical check for dead links and
frontmatter before the PR opens.

### DEPLOY: feat/cro-reporter-label

Documents a new GitHub classification label, `CRO`, for the `dkj-policy-bwj` workflow: it marks an
issue filed by, or on behalf of, the CRO team (currently Johnno), set by judgement at filing time like
`documentation` and the reach label. Scoped to repos that are an actual Shopify store linked to an
Asana project (`smartwatchbanden`, `xoxowildhearts`); `adopt-dkj-policy-bwj`'s label step explicitly
skips it for the plugin's own source repo, `dkj-claude-plugins`, which has no store. No mechanism
changes -- three portable pages only.

**Score:** 1 -- this repo's own developers notice a new paragraph in a plugin page they already read;
nothing here changes what this repo does or how it is checked.

#### What makes this deploy extra special

A consumer running `dkj-policy-bwj` (a BWJ store repo) gains a documented, ready-to-create label the
next time `adopt-dkj-policy-bwj` or `report-issue` is run there, and the CRO team's tickets become
filterable on GitHub (`is:open label:CRO`) the moment it exists.

**Score:** 2 -- small and welcome once it reaches a store repo, but nothing breaks and nothing is
required to change today; it waits for the next adoption run or the next CRO-filed finding there.

#### Pull Request

dkj-policy-bwj: add the CRO reporter label

