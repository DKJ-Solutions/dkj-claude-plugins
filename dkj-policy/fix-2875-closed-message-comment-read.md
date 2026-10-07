## fix/2875-closed-message-comment-read

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

- [x] Read #2875 and the template's comment read; confirm the REST read finds the block on xoxowildhearts#383 locally

### CREATE

- [x] Read the comments through REST (`gh api .../issues/<n>/comments --paginate --jq`), filtering on `author_association`
- [x] Keep gh's exit code and stderr, log them on a failed read, and say "could not be read" instead of "none was on the issue"
- [x] Update the template header, the workflow comment and `WORKFLOW-portable.md`

### TEST

- [x] `bwj-development.tests.ps1`: the REST arguments, paginated lines into trusted bodies, the failed-read log phrase -- 328 asserts green
- [x] Smoke run of `Read-IssueComments` against xoxowildhearts#383 (2 bodies, block found) and a missing repo (exit 1, `gh: Not Found (HTTP 404)` reported)

### DEPLOY: fix/2875-closed-message-comment-read

The `asana-closed-message` template now reads an issue's comments through REST
(`gh api repos/<owner>/<repo>/issues/<n>/comments --paginate`), which the workflow's `issues: read`
covers, instead of `gh issue view --json comments`
([#2875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2875)). On the runner the old read
returned nothing for an issue that carried a trusted go-live block, so the Asana task got the bare
closed line. A failed read is no longer silent: the run log shows gh's exit code and error, and its
last line says the comments could not be read rather than that no block was on the issue. The bare
closed message still goes out in that case. The suite pins the REST call, the parsing of paginated
output and the two log lines.

**Score:** 3

#### What makes this deploy extra special

A requester whose store issue closes as completed gets the go-live block on the Asana task again,
where the old read dropped it on the runner. A store picks the fix up by copying the template again
(`adopt-bwj-development` step 1) after the update; until then it keeps the old read.

**Score:** 3

#### Pull Request

bwj-development: asana-closed-message reads comments through REST and logs a failed read
