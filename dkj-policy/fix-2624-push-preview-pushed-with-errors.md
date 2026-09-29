## fix/2624-push-preview-pushed-with-errors

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

Inbound #2624, verified in the tree. `shopify theme push` (CLI 4.8.2) exits 0 when it rejects a file:
it draws an `error` box naming the file and closes with "The theme '...' was pushed with errors"
(measured in BWJ-Development/smartwatchbanden#790, 2026-09-29). `push-preview.ps1` judged the push on
`ExitCode` alone, so it printed its green line and the preview URLs for a preview missing the rejected
file, and `shopify-cli-lib.ps1` stated ExitCode was the only thing a caller may judge. The streamed call
already hands back `Output`; nothing read it. The repair ports the consumer's measured parser. No other
plugin script runs `theme push` (`live-preflight` only prints the command). Closes #2624.

### CREATE

- [x] `preview-theme.ps1`: `Get-ThemePushProblems` reads the push output -- failed on the "pushed with errors" line or an `error` box, with the box's lines (file and error) returned; ANSI and box-drawing characters stripped, a `warning` box alone is not a failure
- [x] `push-preview.ps1`: on a failed read, prints the rejected lines and exits 1 before the preview URLs
- [x] `shopify-cli-lib.ps1`: the ExitCode-only sentence corrected, naming `theme push`; the `push-preview` SKILL.md step 6 says when URLs are withheld
- [x] Plugin mirrors of all three scripts byte-identical

### TEST

- [x] Tycho: the #2624 section in `push-preview.tests.ps1` -- the measured output (a synthetic theme name), each signal alone, ANSI colour, the not-failures, and the read sitting between the push and the URLs (121/121)
- [x] Victor, Edith, Sebastian on the diff: no blockers; the stale test heading in `shopify-cli.tests.ps1`, the SKILL.md sentence, the consumer theme name in the fixture and a fails-open note applied
- [x] The create path (`theme push --unpublished --json`, stderr discarded) has the same exit-code-only judgement, but its failure output is unmeasured -- filed as #2633 rather than repaired blind

### DEPLOY: fix/2624-push-preview-pushed-with-errors

`push-preview` no longer reports a preview push as successful when the Shopify CLI rejected a file.
`shopify theme push` (CLI 4.8.2) exits 0 when it rejects a file, with an `error` box and "pushed with
errors", and the script judged only that exit code: it printed its green line and the preview URLs for
a preview missing the rejected file. It now reads the push output, prints the rejected file and its
error, and exits 1 before any URL is printed (#2624). The create path, used only where no live theme id
is answered, is still judged on its exit code (#2633).

**Score:** 3

#### What makes this deploy extra special

A store maintainer who hands over a preview is no longer given URLs for one that silently lacks a
file. Nothing to do after the update; a push that used to "succeed" with a Liquid error now stops and
names the file.

**Score:** 2

#### Pull Request

push-preview: a push the CLI rejected a file in (exit 0, 'pushed with errors') now fails before the URLs

