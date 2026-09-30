## fix/2647-dashboard-toml-backtick

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

The first real deploy of the issue dashboard (#2643) failed: wrangler refused the generated
`wrangler.toml` (`illegal character in key`, line 11). The secrets comment sits in an expandable
here-string, and its Markdown backticks around `npx` made `` `n `` a newline escape.

### CREATE

- [x] Drop the backticks from the secrets comment in `issue-dashboard.ps1` and its plugin mirror (kept byte-identical)
- [x] Suite assert: every emitted `wrangler.toml` line is blank, a comment, a `[table]` or a `key = value`

### TEST

- [x] `issue-dashboard.tests.ps1` against the unfixed script: the new assert fails on the stray `px wrangler secret put` line (328 pass, 1 fail)
- [x] The same suite against the fix: 329 pass, 0 fail

### DEPLOY: fix/2647-dashboard-toml-backtick

`issue-dashboard.ps1 -EmitWorker` now writes a `wrangler.toml` that wrangler accepts. A PowerShell
escape had split one comment line and left a bare `px wrangler ...` line in the file. The suite now
checks every line of the emitted file, so this class of break is caught before the file reaches wrangler.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now actually be deployed. Until now, a first `npx wrangler deploy` of the
dashboard stopped with `Invalid TOML document: illegal character in key`. A `wrangler.toml` written
by the old version stays broken, because the script never rewrites it. In that file, put `#` back at
the start of the line that begins with `px wrangler secret put`, or delete the file and re-run
`-EmitWorker`.

**Score:** 3

#### Pull Request

