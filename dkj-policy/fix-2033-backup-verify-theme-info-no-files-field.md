## fix/2033-backup-verify-theme-info-no-files-field

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

Inbound #2033: on `@shopify/cli` 4.8.0 (the consumer's current release, measured September 15, 2026)
`shopify theme info --json` no longer carries a `files` array at any level -- its schema is fixed to
`id`/`name`/`role`/`shop`/`preview_url`/`editor_url`. `backup-live-theme.ps1`'s `Get-ThemeFileCount`
read that field exclusively, so it returned -1 for every theme and step 2 (verify) could never pass:
the live theme's own count read as unknown and the run refused before it ever polled the backup.

Verified against the tree rather than taken on the report's word: `Get-ThemeFileCount` at
`scripts/task/backup-live-theme.ps1` (mirrored into `plugins/dkj-subagents/dkj-subagents-shopify/`)
matches the issue's quoted code exactly. Checked whether any other CLI JSON surface still carries a
count -- it does not: `theme info --json`'s schema (confirmed via the CLI's own JSON-schema PR,
Shopify/cli#8525) has never had a content field, and `theme list --json` answers only
`id`/`name`/`role`/`processing` (already documented in this repo's own `05-22-manual.md`), with
`processing`'s semantics undocumented and not something to guess at for a safety-critical verify
step. So the count is now taken off a real `theme pull` into a scratch directory, counted off what
lands on disk -- the same verification the #2033 consumer did by hand, and the exact call shape
`sync-main.ps1` already uses to mirror the live theme (`Invoke-ShopifyCli -Arguments @('theme',
'pull', ...)`, not `-Quiet`, since a pull can run for minutes and stop to ask for authentication).

`Get-ThemeFillVerdict` (the polling/settling logic in `theme-lifecycle-rules.ps1`) is untouched --
only the source of the count changed, so its existing 84 asserts keep covering the correctness point
that matters (two stable samples AND a match against the source, not stability alone).

### CREATE

- [x] `Get-ThemeFileCount` in `scripts/task/backup-live-theme.ps1` (the canonical source):
      replaced the `theme info --json` field read with a `theme pull` into a scratch directory,
      counted off disk, cleaned up in a `finally`.
- [x] Updated the script's `.DESCRIPTION`, the `-PollSeconds`/`-TimeoutMinutes` parameter docs, and
      the in-loop `Write-Host` lines to say a sample is now a real pull and to flag that a large
      theme may need more headroom than the old, cheaper JSON read did.
- [x] Ran `scripts/sync/build-shared-scripts.ps1` to regenerate the
      `plugins/dkj-subagents/dkj-subagents-shopify/` mirror rather than hand-editing both copies.

### TEST

- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors (shared-script mirror check included).
- [x] `scripts/tests/theme-lifecycle-rules.tests.ps1` -- 84 pass, 0 fail (`Get-ThemeFillVerdict`'s
      contract is unaffected by the count source).
- [x] `scripts/tests/shared-scripts.tests.ps1` -- 844 asserts, all pass (root/mirror pair still
      registered and now byte-identical again).
- [~] `backup-live-theme.ps1` itself is not suite-driven, by design -- its own `.NOTES` state why:
      every path in it either calls the Shopify CLI against a real store or reads a consumer's
      `repo-config.ps1`, and a suite must not be able to reach a store. Live verification happens in
      a consumer, as it already did for this exact mechanism (the #2033 issue's own "Consumer state"
      section: `BWJ-Development/smartwatchbanden` pulled both themes and compared by hand).

### DEPLOY: fix/2033-backup-verify-theme-info-no-files-field

`backup-live-theme.ps1`'s verify step no longer depends on `theme info --json` carrying a `files`
field, which current Shopify CLI releases (4.8.0+) do not provide. It now confirms a backup theme's
fill by pulling it and counting files on disk -- heavier than a JSON read, and strictly stronger,
since it verifies identity rather than trusting a number the CLI reports about itself.

**Score:** 2 -- routine maintenance to one script's internal mechanism; the polling/settling contract
(`Get-ThemeFillVerdict`) that repo maintainers actually reason about did not change.

#### What makes this deploy extra special

Before this fix, `backup-live-theme.ps1`'s verify step could never pass on current Shopify CLI
releases (4.8.0+) -- every run refused at "Could not read the LIVE theme's file count", making the
release-cut backup step a standing blocker for any consumer on an up-to-date CLI. That is now fixed.

**Score:** 5 -- a long-standing blocker (the verify step could never pass) is now gone for every
consumer running a current Shopify CLI.

#### Pull Request

backup-live-theme's verify step no longer relies on 'theme info --json' carrying a files array

