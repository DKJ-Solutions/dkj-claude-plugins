## docs/1980-artifact-source-url-record

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

Close inbound [#1980](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1980) (submitted from
`BWJ-Development/smartwatchbanden`): nothing in `dkj-policy` says where the published URL of a durable,
committed Artifact source lives, and nothing in the cycle produces one -- so a later session that edits
and republishes such a source silently creates a *second* artifact instead of updating the first, and a
page carrying its own state (a backlog/snapshot feeding a scheduled workflow) starts that second one
empty, on its committed fallback data, looking exactly like a working page. Doc-content only: the policy
lands on the right portable page, the mechanism side (a printed closing note, in the shape
`push-preview.ps1` already uses) is named as future, optional work and is not built here.

- [x] Verified the report still stands: `grep -rn "claude.ai/code/artifact"` across the whole repo
  returns nothing, and no rule or mechanism in `plugins/dkj-policy/**` (or elsewhere) already records a
  published Artifact URL. `plugins/dkj-policy/dkj-policy-bwj/PREVIEW-portable.md` exists but covers a
  different, short-lived handover link, not a durable committed source's own URL.

### CREATE

- [x] Added the policy as a new `####` subsection under step 3 ("Work, and keep the plan current") of
  `plugins/dkj-policy/CONTRIBUTING-portable.md` -- the three-part rule (URL beside the source; a
  republishing session reads it first; the record lands in the same commit as the first publication),
  scoped to a durable, committed source and explicitly not the short-lived preview-handover shape
  `dkj-policy-bwj/PREVIEW-portable.md` already draws, with the mechanism side named as a later,
  optional step rather than built now.

### TEST

- [~] No suite: this is doc content only, no script or gate changed -- the lint gate and its link
  checker do not run from this session, so the check below is by hand.
- [x] Manual pass over the new subsection's own three internal references: the issue link
  (`https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1980`), the relative link to
  `dkj-policy-bwj/PREVIEW-portable.md` (confirmed it resolves: that file exists at exactly
  `plugins/dkj-policy/dkj-policy-bwj/PREVIEW-portable.md`, one level under this document), and a
  heading-nesting check (`grep -n '^#{2,4} '` over the whole file) confirming the new `####`
  subsection sits under `### 3.` and before `### 4.` with no stray `###` introduced (which would read
  as a separate changelog entry once folded) and no `####` colliding with a named DEPLOY heading.

### DEPLOY: docs/1980-artifact-source-url-record

`dkj-policy`'s contribution cycle now states where a durable, published Artifact's own URL belongs when
its source is committed: beside the source, read and passed to the publish call before any
republication, and written into the same commit as the first publication rather than as later
housekeeping. Closes inbound
[#1980](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1980): without this, a session that
edits and republishes a committed Artifact source creates a second, unmaintained artifact while the
original link goes on serving stale content, and a page with its own state (a backlog/snapshot document
feeding a scheduled workflow) starts the second copy empty on its committed fallback data -- rendering
correctly and looking exactly like a current page, with nothing erroring and no gate able to catch it.
Scope is deliberately narrow: a durable surface whose source is committed, not the short-lived preview
handover `dkj-policy-bwj`'s own `PREVIEW-portable.md` chapter already covers for its own kind of link.
No mechanism is built here; the closing note a publishing session could print (the shape
`push-preview.ps1` already uses) is named as later, optional work.

**Score:** 3 -- a preventive rule closing a gap that has already caused a real, measured failure (a
second artifact silently orphaning the first, with a page's own persisted state left behind on the
stranded copy) rather than one hypothesised in the abstract; every consumer running this workflow that
publishes a durable Artifact is exposed to it, but nothing forces a reader to act today -- the rule
changes what a *future* session does the next time it republishes such a source.

#### What makes this deploy extra special

Every consumer of this workflow (this repo's audience, tier 2) that commits the source of a durable,
published Artifact was exposed to the failure this closes: silently duplicating a published page on
republish, with no error and no gate to catch it, and losing whatever state the original page had
accumulated. The rule tells a session what to do the next time it republishes such a source, so it
belongs in the record any subscriber of this service reads.

**Score:** 3 -- same reasoning as tier 0: a real, previously-unrecorded failure mode closed by a rule a
session needs to already know before its next republish, not a change anyone has to react to today.

#### Pull Request

record the published URL of a committed Artifact source

