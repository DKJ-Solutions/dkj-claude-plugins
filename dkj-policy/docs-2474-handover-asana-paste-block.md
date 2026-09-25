## docs/2474-handover-asana-paste-block

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

PREVIEW-portable's handover shape gains a fourth block: the golive-block paste-ready text, embedded with a copy button, and the sensitivity section states which URLs may reach the requester.

#### Inbound verification (#2474)

- Symptom stands: "The shape of the handover" named three blocks and said nothing about the requester's message.
- Reasoning refined: the message is not an undefined format. It is the paste-ready block `build-golive-block.ps1` already prints, and its link rule is already enforced there (#2341). So the repair embeds that printout and does not add the consumer's Dutch headings as a second format (the issue's own item 3).
- Split off: the block's bare live URLs hit the preview-cookie trap when opened before the release. Filed as #2477 on the script, not patched by hand on the page.

### CREATE

- [x] PREVIEW-portable: the fourth block in the shape table, plus a subsection on why it is golive-block's printout
- [x] PREVIEW-portable: the link rule in the sensitivity section (storefront URLs only, never the handover link)
- [x] PREVIEW-portable: the mechanism note gains the copy button and its required select fallback
- [x] golive-block SKILL.md names the page that embeds its printout
- [~] Is the change visible in the frontend / storefront? No -- a policy page and a skill page; nothing renders differently

### TEST

- Lint gate (`-SkipTests`, per this machine's memory limit) plus CI.

### DEPLOY: docs/2474-handover-asana-paste-block

A preview handover page now carries a fourth block: the Asana paste-ready block from
`golive-block`, embedded as printed, with a copy button. The requester reads the Asana task and cannot
open the private page, so the page now holds the message they actually get, from the same run that
posts it on the issue. The page also says which URLs that block may carry: storefront URLs only, never
the handover link.

**Score:** 2 -- a handover session gets one step fewer to do by hand; the block's wording is unchanged.

#### What makes this deploy extra special

N/A -- the requester reads the same block as before; only where the session copies it from changes.

**Score:** N/A

#### Pull Request

The handover page carries the Asana paste-ready block as its fourth block

