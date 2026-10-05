## fix/2798-preflight-live-role

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

Inbound [#2798](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2798), verified: `live-preflight.ps1`
step 5 was the one role reader comparing against `'main'` alone; `theme-lifecycle-rules.ps1` (twice) and
`theme-archive-rules.ps1` already accept both spellings. No shared helper: the two rules libs are tested
standalone and share no lib with the preflight, so a helper would add a dependency to pure libs. The drift
guard is a source pin across all three readers instead.

### CREATE

- [x] Step 5's `$byRole` accepts `live` and `main`, in both copies of `live-preflight.ps1`
- [x] Pin in `live-push-rules.tests.ps1`: the preflight accepts both, and no reader compares `'main'` without `'live'`

### TEST

- [x] `live-push-rules.tests.ps1`: 116 pass; with the preflight fix stashed, the two new asserts fail

### DEPLOY: fix/2798-preflight-live-role

`live-preflight`'s step 5 now reads the live theme's role as either `live` or `main`. Shopify CLI 4.8.x
reports `live`, so the `main`-only compare never matched, and the refusal for a configured live theme id
that disagrees with the store's own live theme could not fire. A source pin in `live-push-rules.tests.ps1`
holds the preflight and both theme rules libs to accepting both spellings.

**Score:** 2

#### What makes this deploy extra special

`live-preflight` once again refuses when `Get-ShopifyLiveThemeId` names a theme the store does not
report as live. Before, a stale id that still pointed at an existing unpublished theme passed step 5, and
the preflight printed a push aimed at a theme no customer sees.

**Score:** 1

#### Pull Request

live-preflight's role check accepts 'live' as well as 'main'

