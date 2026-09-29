## fix/2633-push-preview-create-path-reads-rejections

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

#2633: `push-preview.ps1`'s create path (`theme push --unpublished --json`, reached only where no live
theme id is answered) judged a push on its exit code, and #2624 measured that the CLI exits 0 when it
rejects a file. The prerequisite the pickup note named, `Get-ThemePushProblems`, has been on `main`
since PR #2636.

The issue asked for a store measurement first. That cannot run from this checkout (it has no store), but
it does not block a fail-open repair. The call discarded stderr only because its output is parsed, and
`Get-ThemeIdFromPushOutput` is a regex that tolerates lines around the JSON. So keeping stderr and
reading the merged capture adds detection on the inferred channel and removes nothing. The unmeasured
half, a rejection carried in the stdout JSON instead, is #2638.

### CREATE

- [x] The create call keeps stderr (`-Quiet` only), and its output goes through `Get-ThemePushProblems`
  before any URL is printed; on a rejection it names the file and exits 1.
- [x] The theme id is remembered, and a stale `previewFill` cleared, BEFORE that refusal, because the
  theme exists either way and the next run should push into it by id.
- [x] The `dkj-subagents-shopify` mirror of `push-preview.ps1` carries the same bytes.
- [x] `push-preview.tests.ps1` pins the create path's order statically (call, read, `exit 1`, URLs), that
  the call keeps stderr, and that the id still reads out of a merged capture holding an error box.
- [x] Filed #2638 for the `--json` measurement in a store checkout.

### TEST

- [x] `scripts/tests/push-preview.tests.ps1`: 126 asserts, all passed.
- [~] A live run of the create path against a store: there is no store here, and that is #2638.

### DEPLOY: fix/2633-push-preview-create-path-reads-rejections

`push-preview` now fails on the create path too when the Shopify CLI rejected a file. Where no live
theme id is answered, the preview theme is created by `theme push --unpublished --json`, and that push
was judged on its exit code alone, which is 0 when a file is rejected (#2624). The call now keeps stderr,
reads its output the way the update path does, and exits 1 naming the rejected file before any URL is
printed. The theme id is still remembered, so the next run pushes into the same theme (#2633). Whether
`--json` ever carries the rejection on stdout instead is not yet measured (#2638).

**Score:** 2

#### What makes this deploy extra special

A store maintainer whose repo does not answer the live theme id no longer gets preview URLs for a
freshly created preview that silently lacks a file. Nothing to do after the update.

**Score:** 1

#### Pull Request

push-preview: the create path fails on a file the CLI rejected, as the update path already does

Plugins: dkj-subagents-shopify

