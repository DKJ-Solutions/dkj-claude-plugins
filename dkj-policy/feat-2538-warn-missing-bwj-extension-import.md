## feat/2538-warn-missing-bwj-extension-import

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

#2538 left open whether `consumer-prose-sessioncheck` should warn when a `dkj-policy-bwj` repo lacks the
extension import. Dave's "fix issue 2538" (September 27, 2026) answers yes, in the shape the issue
proposed: only where the plugin is enabled, through `Test-BwjExtensionImported`, naming
`adopt-extension-import.ps1`. Verified by reading: `check-consumer-prose.ps1` had no extension branch, and
`Get-EnabledPlugins` (check-report-lib) already separates the repo's own enables as `RepoEnabledIds`.

### CREATE

- [x] `check-consumer-prose.ps1`: a fourth `[WARNING]` where `RepoEnabledIds` holds `dkj-policy-bwj@*` and the closure does not import the extension; it names the adopter and prints `Get-BwjExtensionImportLine`; never the exit code, wrapped against a malformed settings layer; mirror synced
- [x] `adopt-dkj-policy-bwj` SKILL.md step 6: one sentence saying the session check warns until the line is there

### TEST

- [x] `consumer-prose-gate.tests.ps1`: enabled + missing warns (script and hook), enabled + imported is quiet, an enable in `settings.local.json` warns, a disabled plugin is quiet, an unparseable settings.json is quiet and does not take the check down (135 asserts green)

### DEPLOY: feat/2538-warn-missing-bwj-extension-import

`consumer-prose-sessioncheck` now warns at session start when a repo enables `dkj-policy-bwj` in its own
settings but its `CLAUDE.md` does not import that plugin's extension. Until now the four BWJ chapters
could be missing from context with no signal at all. The warning names step 6 of
`adopt-dkj-policy-bwj`, which writes the line (`adopt-extension-import.ps1 -Apply`), and prints the line to
add by hand. An enable arriving only from the machine-wide user settings is not judged, and the warning
never changes the exit code.

**Score:** 2

#### What makes this deploy extra special

N/A. A session-start check does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

consumer-prose-sessioncheck warns when a dkj-policy-bwj repo lacks the extension import

