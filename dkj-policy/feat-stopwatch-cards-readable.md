## feat/stopwatch-cards-readable

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

### CREATE

- [x] Overview cards in three lines (start, prompt label with its version, time with its change in percent), four to a row (`Format-StopwatchPageHtml`, new `Format-StopwatchChangePercent`)

### TEST

- [x] stopwatch and logbook suites updated and green

### DEPLOY: feat/stopwatch-cards-readable

The `/stopwatch` overview opens on an `h1` (Stopwatch, set in capitals by the house style) with its how-to as the lead, and groups its cards under one `h2` per prompt label (compared case-insensitively, the label with the newest run first, its sub line counting the runs); the Logbook, which draws its overview with the same function, keeps its bare page and its one Measurements heading (`-Flat`). The cards on both read in three lines, with no header above them: the run's start; its prompt label as the link to the run's page, with the run's version behind it (`v3`) once the label has run more than once; and its total time in large type with its change against the previous run of the same label beside it, as a signed percent only (`+31%` in green when faster, `-25%` in red when slower: the sign is the result's). A card sets its text in the house sizes (`--text-lg`, `-base`, `-sm`, `-xs`), the text colour or `--muted`, and the weights 400 to 700 only, with no heading: the start is the card's header (lg, bold), the prompt label with its version the least visible line (sm, regular, muted), and the time under it (base, regular) with its change beside it (xs, regular). The cards stand four to a row, stepping down to two and one on narrower screens. The four-column grid is a page-own class (`.sw-grid-4`) on top of the house `.grid-3`, so no house token or class changes.

**Score:** 2

#### What makes this deploy extra special

The stopwatch page is a dev-server page of this repo; no consumer sees it.

**Score:** N/A

#### Pull Request

Stopwatch overview cards read in three lines, four to a row

