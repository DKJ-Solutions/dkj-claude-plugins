## fix/3055-retired-plugin-id-in-update-tools

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

- Issue [#3055](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3055): a retired plugin id
  (`dkj-policy-bwj`) made `update-plugins` count a failed update and `plugin-versions` prescribe a
  refresh step 1 had just run. Reason verified: `Get-RetiredPolicyExtensionNames` exists in
  `claude-md-import-lib.ps1`, and neither script read it.

### CREATE

- [x] `plugin-versions.ps1`: a retired id whose successor the clone lists gets its own `retired` verdict,
  naming the successor and the install, with its own summary bucket and an `[INFO]` line in `-Brief`
- [x] `update-plugins.ps1`: a retired id is named with its successor and skipped, never handed to the CLI,
  never counted as failed; only retired ids left exits 0
- [x] Plugin mirrors synced with `build-shared-scripts.ps1`

### TEST

- [x] `plugin-versions.tests.ps1` scenario 38 and `update-plugins.tests.ps1` scenario 24 added; both
  suites green (264 and 136 pass)

### DEPLOY: fix/3055-retired-plugin-id-in-update-tools

`update-plugins` and `plugin-versions` now recognise a retired plugin id
([#3055](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3055)). A checkout still enabling
`dkj-policy-bwj` or `dkj-policy-dkjs` (renamed in #2788) made `update-plugins` call
`claude plugin update` on a name the marketplace no longer declares and count it as `FAILED`, which
turned the whole checkout red in an `-AllCheckouts` sweep. Its receipt then advised a marketplace
refresh that step 1 of the same run had just done. Now the update skips that id and names its
successor, and the receipt reports it as `retired` with the real repair: enable the successor and
install it.

**Score:** 2

#### What makes this deploy extra special

An `update-plugins` run in a repo that has not migrated off a retired extension name no longer reports
failure. It names the one change that fixes it, instead of advising a refresh that cannot help.

**Score:** 1

#### Pull Request

update-plugins and plugin-versions recognise a retired plugin id
