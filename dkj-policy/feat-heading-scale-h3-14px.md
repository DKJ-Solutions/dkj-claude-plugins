## feat/heading-scale-h3-14px

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

The owner's request (October 25, 2026): remove h4, h5 and h6 completely and make h3 14px. h2 stays at 24px for
now; changing it is a later, timed Stopwatch run on one variable.

### CREATE

- [x] `house-style.css`: `--text-h3` 14px, `--text-h4`/`--text-h5` and the `h4`/`h5` rules removed, every
      heading list cut to h1-h3, the dialog and menu sizes moved off the retired tokens, `.tile .v` to `--text-lg`
- [x] Brand book source: every `h4`/`h5` element an `h3`, retired token uses moved (titles to `--text-h3`, running
      text to `--text-base`, large figures to `--text-lg`), the prose scale and the showcase updated
- [x] Connector dashboard: the repo name is a bold line instead of an `h4`
- [x] `Get-HouseStyleRetiredTokens` retires `--text-h4` and `--text-h5`
- [x] House-style README (a new "heading cut" section) and the skill's checksum

### TEST

- [x] `npm run gate` in `brandbook/` (eslint, CSS checks, build) green
- [x] Suites `check-house-style`, `connector-dashboard`, `house-palette`, `dev-pages` green
- [x] `check-house-style.ps1` over this repo: OK

### DEPLOY: feat/heading-scale-h3-14px

The house style keeps three heading levels. `h3` is now 14px, the body size, and stands apart only by its weight
and colour. `h4` and `h5` are gone along with `--text-h4` and `--text-h5`, which the gate now reports as retired.
The brand book and the connector dashboard follow suit. Large figures that borrowed `--text-h3` for their size
move to `--text-lg`. The README's new section "The heading cut of October 25, 2026" tells an app how to move over.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes the next house-style copy has to turn its `h4` and `h5` into `h3` and move off
the two retired tokens. The gate names each use that is left behind.

**Score:** 4

#### Pull Request

House style headings: h3 at 14px, h4 and h5 retired

