## fix/3273-release-freshness-mixed

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

Inbound #3273, verified on pickup: the hook still takes its own `plugin.json` as the version of every
dkj plugin ("one version speaks for all of them"). The proposed repair -- read every enabled dkj
plugin's install records and report `[MIXED]` -- fits `Get-EnabledPlugins` + `Get-InstallRecord`,
which already exist. Loading `check-report-lib.ps1` costs about 200ms in a cold PowerShell 5.1.

### CREATE

- [x] `release-freshness-sessioncheck.ps1`: `Get-LoadedVersionMix` reads the install records covering
  this checkout for every enabled id of the marketplace; more than one version (the running one included)
  is `[MIXED]`, listed per plugin with its scopes. It outranks `[CURRENT]` and `[BEHIND]`, and an unreadable
  administration leaves the lockstep verdict standing.
- [x] Tests: every scenario pins a fixture home and checkout, plus five mix scenarios (the measured shape,
  mixed with nothing behind, agreeing records, a record for a plugin not enabled, an unreadable file).

### TEST

- [x] Review: Victor and Sebastian. Their shared finding -- the plugin name was the one unchecked value reaching the model -- is repaired: only a slug name of exactly this marketplace counts (hostile-id test added).
- [x] `release-freshness-sessioncheck.tests.ps1`: 36 of 36 pass.
- [x] Live in this checkout (all records on 5.27.0): still `[CURRENT]`.

### DEPLOY: fix/3273-release-freshness-mixed

The session-start release check no longer says "this session runs dkj plugins vX" when the enabled dkj
plugins load different versions (#3273). When a user-scope install sits beside an older project-scope
one, or the plugins of one checkout were updated apart, it now reports `[MIXED]`. It names each plugin's
version and scope, and asks for `/dkj-policy:update-plugins` when one of them is behind GitHub's newest
release.

**Score:** 2

#### What makes this deploy extra special

Nothing to do on update: the new line appears by itself at the next session start.

**Score:** N/A

#### Pull Request

release-freshness-sessioncheck reports [MIXED] when the enabled dkj plugins load different versions

