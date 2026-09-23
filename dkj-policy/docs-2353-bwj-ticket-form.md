## docs/2353-bwj-ticket-form

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

Inbound #2353: `smartwatchbanden`'s `dkj-policy-bwj/TICKET-FORM.md` is the only copy of BWJ's answers to
`dkj-policy`'s *What your repo answers* list. Verified on pickup: none of its markers (`Ball with`,
`question ready`, `Ga door naar Development`, `Remaining Question`, `About this ticket`) occur anywhere
under `plugins/`, and `xoxowildhearts` carries no copy. The form goes into `WORKFLOW-portable.md` as
step 8 rather than a new page, because `dkj-policy-bwj.tests.ps1` counts every `*-portable.md` as a
chapter and this is chapter one's subject, not a fifth chapter. The consumer's cleanup (deleting its
page, repointing its references) is the consumer's, after the release.

### CREATE

- [x] step 8 in `plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md`: the assignee rule, one issue
      per ticket, language, header, sections, gate sentences, Testing, measuring
- [x] `plugins/dkj-policy/dkj-policy-bwj/README.md`: chapter one paragraph and folder table name it
- [x] `plugins/dkj-policy/CONTRIBUTING-portable.md`: *What deliberately is not here* says the add-on
      now carries a shape
- [x] copy edit (Edith)

### TEST

- [x] lint and test gates, run by open-pr

### DEPLOY: docs/2353-bwj-ticket-form

`dkj-policy-bwj` now carries BWJ's ticket form, as step 8 of its ticket-handling page -- the form a
request arriving from Asana takes in both stores: the Asana assignee deciding whose ticket it is, the
seven-row header with `Reviewed` as the provenance boundary, the closed `State` and `Ball with`
vocabularies, the section route with its two dictated gate sentences, and what `### Testing` carries.
It lived only in `smartwatchbanden`'s tree until now, which left `xoxowildhearts` with no copy and
the assignee rule one deletion away from being lost (#2353).

**Score:** 3

#### What makes this deploy extra special

A BWJ store repo can now drop its own ticket-form page and point at the plugin, and both stores read
the same form from the version they loaded.

**Score:** 2

#### Pull Request

dkj-policy-bwj carries the BWJ ticket form

