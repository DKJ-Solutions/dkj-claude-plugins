## feat/2649-dashboard-org-mode

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

Dave wants two dashboards, one per GitHub organization (DKJ-Solutions and BWJ-Development), each
covering every repository in it. #2643 scoped the worker to one repo. This branch adds an org mode
beside repo mode and leaves repo mode's behaviour unchanged.

Decisions taken here:
- `GITHUB_ORG` is the alternative to `GITHUB_REPO`, exactly one of the two. It is read through
  `repositoryOwner`, so a user login works too.
- Only non-archived repositories with issues enabled are read.
- Issues are keyed on repo and number. Ties go by number, then by repo name.
- The org budget is 40 requests per refresh, under the free plan's 50 subrequests.
- Each org gets its own directory, `dkj-policy/dashboard/org-<login>/`, and a sibling dashboard's
  token is not treated as a stray.

#### Open for review

- [x] Victor and Sebastian review the diff

### CREATE

- [x] `issue-dashboard-logic.js`: repo-and-number keys, a generic comparator and labels in `orderByBlockers`, `repo` on every row, and `blocking` as `{number, repo}`
- [x] `issue-dashboard-worker.js`: `GITHUB_ORG`, `listOwnerRepos`, aliased batched `loadRepos`, cache and memo keyed on the target, org-aware links and heading, config validation
- [x] `issue-dashboard.ps1` and its mirror: `-Org`, a directory per org, a sibling-aware stray filter, `GITHUB_ORG` in `wrangler.toml` plus a both-vars warning, the org PAT guidance, a `wrangler whoami` note, and a trailing newline on the emitted toml
- [x] Skill page and plugin README describe org mode, the PAT per organization and the Cloudflare account check

### TEST

- [x] `issue-dashboard.tests.ps1`: 380 pass, 0 fail. New cases cover the org logic (cross-repo edge, ties, outside and unfetched sinks, branch and PR per repo, cycle labels), the org handler against a stubbed GitHub (listing, archived and issue-less repos skipped, one aliased batch, order, links, heading, cache key), config refusals, and `-Org` beside a repo dashboard

### DEPLOY: feat/2649-dashboard-org-mode

The dashboard worker and `issue-dashboard.ps1` gain an org mode. The logic now keys issues on repo and
number, and its rows carry `repo`. `blocking` is now a list of `{number, repo}`, and nothing outside
the worker reads it. Repo mode's pages, order and output are unchanged, and the suite pins that.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now cover a whole GitHub organization instead of one repository. Run
`issue-dashboard.ps1 -Org <login> -InitToken -EmitWorker` once per organization. Each organization gets
its own worker, token and directory, so several dashboards can be deployed from one checkout. A blocker
in another repository of the same organization now orders normally instead of sinking to the bottom.
Each organization needs a fine-grained PAT of its own, with that organization as resource owner. Setup
is in [the `issue-dashboard` skill](../plugins/dkj-policy/skills/issue-dashboard/SKILL.md).

**Score:** 3

#### Pull Request

The issue dashboard gains an org mode: one worker for every repo of a GitHub org

