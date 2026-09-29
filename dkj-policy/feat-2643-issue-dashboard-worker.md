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
  blocker outside the repo sinks the issue, and every issue that waits on a sunk issue, below every
  issue without one (transitive -- Cody's accepted refinement, so topological order holds); a cycle is flagged on the
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

- [x] Cody #13: `issue-dashboard-logic.js` + `issue-dashboard-worker.js` to the contract above
- [x] Sylvester #15: `issue-dashboard.ps1`, its mirror + registry entry, the `issue-dashboard` skill, the gitignore line, the seam in the blueprint
- [x] Tycho #18: a suite -- source-text invariants, and the ordering/status logic run under `node` against fixtures (skipped cleanly without `node`)
- [x] Tessa #16: the README section naming the feature as optional and its Cloudflare prerequisite
- [x] Review round -- Victor #19 (no correctness bugs; paging, page cap and toml drift were untested), Sebastian #23 (no blockers; no-referrer, CSP, nosniff, noreferrer links, the token URL no longer printed, the token file must be gitignored, Workers Logs off), Edith #17 (the transitive-sinking drift, route and pointer wording) -- all applied; the stray-token duplicate is #2644
- [x] Caching made honest: that `caches.default` works on `*.workers.dev` is not confirmed by Cloudflare's docs, so a 60 s per-isolate memo sits in front of it

### TEST

- [x] The suite and the lint gates below, green
- [x] A live local render against this repo's tracker, headers and the 404 checked

#### Test results

- `scripts/tests/issue-dashboard.tests.ps1`: **328 pass, 0 fail** under node v22.15.1 -- route and header invariants on every response, escaping, the ordering/status rules against fixtures (chains, ties, closed and cross-repo blockers, transitive sinking, cycles, labels and age inert), paging over two pages, the 10-request cap, the memo, and the script in temp repos (token once, gitignore refusal, toml once with observability off, drift warnings, the token never in the output).
- `check-plugin-integrity`: 0 errors. `check-script-contract`: 0 errors (`Get-IssueDashboardWorkerName` reported unanswered, which is informational -- the seam is optional).
- **Live, against this repo's own tracker:** the worker was run locally under Node with a stubbed Cache API and a real `gh` token, and rendered this repo's 4 open issues in pick-up order with derived statuses; an unknown path token got the uniform 404; the new headers were read off the response. What stays unexercised is a real `wrangler deploy` and the edge cache on a deployed worker, since both run against somebody's Cloudflare account.

### DEPLOY: feat/2643-issue-dashboard-worker

`dkj-policy` gains an optional, self-contained feature and nothing else changes: a new skill, a new script with its mirror, two worker files, one optional seam and one gitignore line. The worker holds no content and no secret, and the ordering and status rules sit in a pure module the suite runs under `node`, so a later change to them is testable without a Cloudflare account.

**Score:** 3

#### What makes this deploy extra special

A repo running `dkj-policy` can now put its open issues on a live dashboard that says what is in flight, what is waiting, what is blocked and what to pick up next. The order comes from GitHub's own blocked-by dependencies rather than from labels. The feature is optional because it needs a Cloudflare account and `node`; a repo without one adopts nothing and loses nothing. Setup is in [the `issue-dashboard` skill](../plugins/dkj-policy/skills/issue-dashboard/SKILL.md).

**Score:** 3

#### Pull Request

A live issue dashboard on a Cloudflare Worker
