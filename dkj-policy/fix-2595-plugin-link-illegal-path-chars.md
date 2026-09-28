## fix/2595-plugin-link-illegal-path-chars

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

- [x] Verify the reason in #2595: under Windows PowerShell 5.1, `IsPathRooted`, `GetFullPath` and `Test-Path -LiteralPath`
  (under `Stop`) all throw on `<`. Check 4 has the same shape, so both scans are repaired.

### CREATE

- [x] `check-plugin-integrity.ps1`: both link scans test a target against `GetInvalidPathChars()` before any path API sees it,
  and report it as a finding. `[plugin-link]` gives the line.

### TEST

- [x] Scenario 41c in `check-plugin-integrity-plugin-links.tests.ps1` covers the measured multi-line code span and a plain
  prose placeholder. It fails on the old script (the run printed no Summary) and passes on the new one.

### DEPLOY: fix/2595-plugin-link-illegal-path-chars

A link target holding `<`, `>`, `"` or `|` no longer crashes `check-plugin-integrity.ps1`. Under Windows PowerShell 5.1 the
path calls in check 4 and `[plugin-link]` threw on those characters. That ended the whole lint with an error that named no
file. Both scans now report such a target as a finding, and `[plugin-link]` gives its line. The measured trigger was a
placeholder `(<url>)` inside a code span that opened on the line before (#2595).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A link target with illegal path characters is a finding, not a lint crash

