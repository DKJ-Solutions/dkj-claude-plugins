## feat/2818-asana-closed-message

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

[#2818](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2818), Dave's decision of October 5, 2026:
bring back only the closed message of the `asana-mirror` workflow #2804 retired that morning. Built as a new,
small template rather than a revert: the old 2,109-line script's close path is six pure helpers, and
everything else in it (card moves, sweeps, prio sync, reopen and label comments, backstop) stays retired.
The issue's item 3 proposal is taken as written: a close as completed with no block posts the header and
the closed line alone. It is `issues: closed` only, needs `ASANA_PAT` only, and reads the issue on GitHub
without writing to it. The template-self-containment suite comes back with it, as Sylvester's lens said
the next template should. One correction to the issue: `Select-SessionPasteBlockSections` did not survive
in `asana-task-lib.ps1`, so it is taken from the retired template.

### CREATE

- [x] `templates/asana-closed-message.yml` + `.ps1`: closed only, posts on a close as completed, nothing on not planned or duplicate, self-contained
- [x] The framing sentence, `build-golive-block`'s closing line and `asana-task-lib`'s header say the close carries the block again
- [x] WORKFLOW-portable step 4 and its other passages, the `golive-block`, `report-issue` and `adopt-bwj-development` skills, PREVIEW-portable and the README describe the closed message; adopt copies the template in the two stores and names `ASANA_PAT`
- [x] `bwj-development.tests.ps1`: the template's own section (copies equal the lib, decision, HTML, yml shape); `template-selfcontained.tests.ps1` restored, with its duration row
- [x] Code and security review before shipping: nothing blocking. Applied: the block is taken only from an OWNER/MEMBER/COLLABORATOR comment, XML-invalid control characters are dropped, no `&apos;`, a bare URL keeps its full stop outside the link, `\z` anchors, `persist-credentials: false`, the body via env, a corrected concurrency comment, and a structural one-call-site assert. Declined: the marker pointing at any task the token reaches (the retired workflow's trust model, stated in the template's header; checking the project needs a read this workflow does without), a nested-parenthesis URL in a Markdown link, and digits in a heading (both cosmetic and unmeasured in a real block)

### TEST

- [x] `bwj-development.tests.ps1`: 303 pass
- [x] `template-selfcontained.tests.ps1`: 8 pass; `workflow-timeouts`, `check-plugin-integrity-script-set`, `exception-message-guard`, `hook-stdin-guard`, `guard-asana-mirror` green
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: feat/2818-asana-closed-message

The closed message on the Asana task is back, and it is the only part of the retired `asana-mirror`
workflow that is. A new template, `asana-closed-message`, runs on `issues: closed` only. On a close as
completed it posts one comment on the linked task: the automation's header, the closed line, and the
go-live block the shipping session left on the issue. On a close as not planned or as a duplicate it
posts nothing. It needs `ASANA_PAT` alone, moves no card and completes no task. The go-live block's
framing sentence and the pages that said the block is pasted by hand say again that the close carries
it. `adopt-bwj-development` copies the template into the two store repos.

**Score:** 3

#### What makes this deploy extra special

When a store's issue closes as completed, the requester's Asana task hears about it again, with the
go-live block in it, and nobody pastes anything. To turn it on in a store, run `adopt-bwj-development`
after the update (it copies `.github/workflows/asana-closed-message.yml` and its script) and keep the
`ASANA_PAT` secret. A store that still has the old `asana-mirror` files should delete them, or the closed
message is posted twice.

**Score:** 4

#### Pull Request

The closed message on the Asana task is back, and it is the only automation

