## fix/2848-anchor-statusline-path

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

#2848 (inbound, smartwatchbanden): `adopt-statusline` writes `-File ".claude/statusline/dkj-progress.ps1"`,
relative to the status line's cwd, while every hook command anchors on `${CLAUDE_PROJECT_DIR}`. The
issue's first check -- is the variable available to a `statusLine` command at all -- was measured
before changing anything: two probe `statusLine`s in `.claude/settings.local.json` (removed afterwards).
Double-quoted, `"${CLAUDE_PROJECT_DIR}/x"` arrived expanded; single-quoted it arrived literally. So
Claude Code exports the variable and Git Bash expands it, exactly as for the hooks. The PowerShell
fallback without Git Bash is filed as #2850; the invalid JSON in the printed block as #2849.

### CREATE

- [x] `adopt-statusline.ps1` (source and plugin mirror, byte-identical) emits the anchored path
- [x] Part 5 of the `adopt-dkj-policy` page says what the key names, and why
- [x] `adopt-statusline.tests.ps1`: the anchored form asserted, the byte-exact expected insert updated

### TEST

- [x] `adopt-statusline.tests.ps1`: 74 asserts green

### DEPLOY: fix/2848-anchor-statusline-path

`adopt-statusline` now writes the status line's shim path as
`${CLAUDE_PROJECT_DIR}/.claude/statusline/dkj-progress.ps1`, anchored like the hook commands in the same settings file.
The relative path it wrote before resolved against the status line's working directory, so from below
the repo root it missed the shim, or ran a different file at the same relative path.

**Score:** 2

#### What makes this deploy extra special

A repo that already ran Part 5 keeps its relative line; `adopt-statusline` never replaces an existing
`statusLine`. To anchor it, change the `command` in `.claude/settings.json` by hand to
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/.claude/statusline/dkj-progress.ps1"`.

**Score:** 2

#### Pull Request

adopt-statusline anchors the statusLine shim path on CLAUDE_PROJECT_DIR

