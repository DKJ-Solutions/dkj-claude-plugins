## feat/2643-issue-dashboard-worker

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

An optional dkj-policy feature: a Cloudflare Worker that renders a repo's open GitHub issues live, with each issue's status and a pick-up order derived from blocked-by dependencies.

#### Decisions (Dave, September 29, 2026 -- #2643)

Live via the GitHub API (token as a worker secret, short edge cache); one repo per dashboard; an
unguessable path, no Cloudflare Access; order by blockers only -- prio labels and age are not
ordering signals, ties fall back to issue number.

#### The contract Cody and Sylvester build against

- **Worker files**, shipped in `plugins/dkj-policy/worker/`: `issue-dashboard-worker.js` (the fetch
  handler) and `issue-dashboard-logic.js` (a pure ES module, no I/O: `deriveDashboard(issues, prs,
  branches)` -> ordered rows with status). The worker carries **no content, no token and no repo
  name** -- everything comes from `env`.
- **`env`**: `GITHUB_TOKEN` (secret -- fine-grained PAT, one repo, Issues/Pull requests/Contents read),
  `DASHBOARD_TOKEN` (secret -- 32 lowercase hex, the path lock), `GITHUB_REPO` (var, `owner/name`).
- **Route**: `GET|HEAD /issues/<32hex>` only, token compared in constant time; every miss the same
  404. `noindex`, `no-store` to the browser; the GitHub reads cached ~60 s at the edge (Cache API).
- **Data**: two-to-four GraphQL reads per refresh -- open issues paged (labels, assignees,
  `blockedBy`), open PRs (`isDraft`, `closingIssuesReferences`), branch refs under `feat/`, `fix/`,
  `docs/`. A truncated connection is reported on the page, never silently dropped.
- **Status**, first match wins: *In review* (open non-draft PR closes it) > *In progress* (draft PR,
  or a `<prefix>/<n>-` branch) > *Waiting* (a parking label: `needs-info`, `needs-decision`,
  `awaiting-recurrence`) > *Blocked* (an open `blockedBy`) > *Claimed* (assignee) > *Filed*.
- **Order**: topological over in-repo open `blockedBy` edges (Kahn), ties by issue number; an open
  blocker outside the repo sinks the issue below every issue without one; a cycle is flagged on the
  page and broken by issue number.
- **Script** `scripts/task/issue-dashboard.ps1` (mirrored, skill `issue-dashboard`): `-InitToken`
  writes the path token once into a gitignored `dkj-policy/dashboard/`; `-EmitWorker` copies both JS
  files there and writes `wrangler.toml` once (name from the optional seam
  `Get-IssueDashboardWorkerName`, `GITHUB_REPO` from `Get-RepoName`); it then **prints** the two
  `wrangler secret put` commands and `npx wrangler deploy`, run from that directory (never the repo
  root -- #2581). It deploys nothing and never reads a secret.

#### Visible result

The dashboard is judged by eye, so the chain stops before the merge and the checkout stays on this
branch until Dave has looked.

### CREATE

- [ ] Cody #13: `issue-dashboard-logic.js` + `issue-dashboard-worker.js` to the contract above
- [ ] Sylvester #15: `issue-dashboard.ps1`, its mirror + registry entry, the `issue-dashboard` skill, the gitignore line, the seam in the blueprint
- [ ] Tycho #18: a suite -- source-text invariants, and the ordering/status logic run under `node` against fixtures (skipped cleanly without `node`)
- [ ] Tessa #16: the README section naming the feature as optional and its Cloudflare prerequisite

### TEST

### DEPLOY: feat/2643-issue-dashboard-worker

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

A live issue dashboard on a Cloudflare Worker

