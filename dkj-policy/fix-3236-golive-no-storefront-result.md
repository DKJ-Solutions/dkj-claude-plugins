## fix/3236-golive-no-storefront-result

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

Inbound #3236 (smartwatchbanden, October 21, 2026), verified against the tree: `-Link` took any URL, the
missing-link warning pushed a session toward passing *something*, and the result form's ask always said
*"wat je ziet is wat een klant ziet"*. The proposal is taken as filed: a `-NoStorefrontResult` variant of
the go-live form, and a refusal of a `github.com` `-Link`. A variant, not a fourth form: the change does
go live and has a date, so the closed message carries the block as a result block with no new marker.

### CREATE

- [x] `golive-block-rules.ps1`: `Test-RepoArtifactLink`; `Format-GoLiveBlock -NoStorefront` (fixed
  where-to-look sentence above the `[where]` prose, no after-release marker or line);
  `Get-GoLiveBlockAsk -NoStorefront`; the two sentences in Dutch and English.
- [x] `build-golive-block.ps1`: `-NoStorefrontResult` (refuses `-Link`, `-Path` and the other forms;
  warns without `[where]`), the `github.com` refusal in every form with no valve, and the missing-link
  warning naming the new switch.
- [x] The `golive-block` skill page and `WORKFLOW-portable.md` describe the form.

### TEST

- [x] `bwj-development.tests.ps1`: the block's shape in both languages, the marker and closed line, the
  link test, and the driver end to end (the form, its refusals, the `github.com` refusal past
  `-AllowPrivateLink`) -- 805 asserts green.

### DEPLOY: fix/3236-golive-no-storefront-result

A change that shows nothing on the storefront -- infrastructure, a deploy route, an admin-only setting --
now has its own go-live block: `build-golive-block.ps1 -NoStorefrontResult` (#3236). Its *where to look*
says that nothing changes for customers, with your `[where]` prose (where it does show) under it, and its
ask points at that prose instead of a link. It carries no after-release line, since nothing becomes
visible with the release. **A `github.com` `-Link` is now refused in every form**: a pull request, a
release or a commit had reached requesters as *"the result"*, above *"what you see is what a customer
sees"*. The skill page and `WORKFLOW-portable.md` describe the form.

**Score:** 3

#### What makes this deploy extra special

A session in a store repo that passes a pull request, release or commit URL as `-Link` is now refused,
with the remedy named; nothing else changes for an existing call.

**Score:** 2

#### Pull Request

golive-block: a form for a change with no storefront result, and no github.com link as the result

