## fix/2348-preview-context-settings

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

Inbound #2348. Verified on pickup: the symptom stands in source (`push-preview.ps1` created with
`theme push --unpublished`), and the reason was read in the installed CLI 4.8.0
(`dist/chunk-7T6M7FAC.js`, function `Do`): `config/settings_data.context.<x>.json` matches no upload
bucket. That holds for EVERY push, so a server-side `theme duplicate` of live is the only route -- the
consumer's repair (smartwatchbanden #752, uncommitted in its checkout, read only) is the model.

Departure from the report: `Get-ThemeFileCount` goes into `shopify-cli-lib.ps1`, not
`theme-lifecycle-rules.ps1`, because that lib's header promises no CLI and no network.

### CREATE

- [x] `Get-ThemeFileCount -Store -ThemeId` in `scripts/lib/shopify-cli-lib.ps1`; `backup-live-theme.ps1`
      calls it instead of its local copy.
- [x] `preview-theme.ps1`: `Get-ThemeDuplicateArgs` with a duplicate flag whitelist measured from
      `shopify theme duplicate --help` (CLI 4.8.0), `Test-ContextSettingsPath`,
      `Get-ContextSettingsMarkets`, `Get-PreviewSettingsNotice`.
- [x] `push-preview.ps1`: step 4 duplicates live (fallback to the old create where no live id is
      answered), records `branch.<name>.previewFill`, waits on `Get-ThemeFillVerdict` before the push,
      prints the settings notice.
- [x] Docs: push-preview skill page (steps, parameters, the why), Steven's manual line.
- [x] Mirrors rebuilt (`build-shared-scripts.ps1`).
- [x] Filed #2350: backup-live-theme breaks on an early `short` verdict that push-preview now waits through.

### TEST

- [x] `push-preview.tests.ps1` -- 95 asserts pass, new ones cover the duplicate call, its whitelist,
      the context path, the markets reader and the notice.
- [x] `theme-lifecycle-rules.tests.ps1` -- 102 pass.
- [x] `check-plugin-integrity.ps1` -- 0 errors.
- [~] The script itself against a store -- this repo has none; the path is exercised by the consumer's
      identical #752 repair, not here.

### DEPLOY: fix/2348-preview-context-settings

`push-preview` created a new preview with `theme push --unpublished`, and no `theme push` uploads
`config/settings_data.context.<market>.json` -- the CLI lists the file, never sends it, and reports
success (CLI 4.8.0; no upload bucket matches a context file under `config/`). On a Markets store every
preview therefore rendered every market with the global settings. A new preview is now a
`shopify theme duplicate` of live, waited on until the copy has filled (`Get-ThemeFillVerdict`, with
`-PollSeconds` / `-TimeoutMinutes`), and only then pushed over -- so the first push of a branch takes
minutes longer. Where no live id is answered it falls back to the old create. A preview this checkout
has no record of copying, and a branch that changes a context-settings file, get a printed notice,
since no push can put those bytes on a theme. `Get-ThemeFileCount` moved from `backup-live-theme.ps1`
into `shopify-cli-lib.ps1` so both callers share it (#2348).

**Score:** 3 -- a Markets store's previews stop differing from live for reasons the branch did not
cause, noticed the first time somebody compares one; the first push per branch now waits for the copy.

#### What makes this deploy extra special

N/A -- nothing to migrate. Existing previews keep working and are named by the notice; removing one and
pushing again gets a copy of live.

**Score:** N/A

#### Pull Request

push-preview creates previews by duplicating live, so per-market context settings arrive

