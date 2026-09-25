## fix/2476-asana-automated-comment-header

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

#### Inbound verification (#2476)

- Symptom stands: `New-MirrorComment` opened every update with the bare marker sentence, and nothing on the workflow page or in `report-issue` set a disclosure form for a session's own Asana comment.
- Proposed repair narrowed: `New-AsanaPasteBlockComment` writes to the GitHub issue, not to Asana, and a person pastes the block into the task. That is the person's own message, so it takes no header.
- De-dup risk checked: `Test-MirrorUpdatePosted` matches the marker as a substring (`Contains`), so a header line above it keeps old and new updates de-duplicating alike.

### CREATE

- [x] `asana-mirror.ps1`: `Get-MirrorCommentHeader`, prepended to all three `New-MirrorComment` shapes (closed, not planned, reopened); the marker is unchanged
- [x] WORKFLOW-portable step 2: the rule, both writers, the header's language, and that an MCP-posted comment cannot be edited afterwards
- [x] `report-issue` SKILL.md: the rule where the write would happen
- [~] Is the change visible in the frontend / storefront? No -- the Asana comment text changes; no storefront renders it

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: the header is line one of every update shape, and the marker follows it unchanged (all 390 asserts green)
- [x] Lint gate (`-SkipTests`, per this machine's memory limit) plus CI

### DEPLOY: fix/2476-asana-automated-comment-header

Every comment the `asana-mirror` CI posts on an Asana task now opens with an `[Automated message]`
line, and the workflow page now requires the same of a session writing a comment through the Asana
MCP. Both post under a person's account, so without that line a colleague read a machine update as
that person's own words. De-duplication is unchanged, so tasks that already carry an update do not get
a second one.

A store repo posts the header once its `.github/scripts/asana-mirror.ps1` copy is refreshed from the
release. Until then it keeps posting the old text, and the session rule applies as soon as the page
is installed.

**Score:** 3

#### What makes this deploy extra special

N/A -- the colleagues who read the Asana board are not subscribers of this plugin.

**Score:** N/A

#### Pull Request

Agent-written Asana comments open with an automated-message header
