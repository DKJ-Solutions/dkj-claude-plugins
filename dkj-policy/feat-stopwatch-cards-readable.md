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

- [x] Overview cards in three lines (start, prompt label with its version, time with its change in percent), five to a row, grouped under an `h2` per prompt label, on a bare page with no `h1` (`Format-StopwatchPageHtml`, new `Format-StopwatchChangePercent`)
- [x] Hub banner the first block of every hub page, above the h1 (general page shell, home page, Connectors page)
- [x] House style: `--text-h2` 24px and `h2` in the sans in `--primary`, `.lead` at `--text-base`, breadcrumbs at `--text-base` with the current page in `--primary` under a site header, the site header's mark on `--text-h1`; README, brand book specimen and the skill's checksum follow (carried over from `feat/house-h2-24-primary`, so the owner reviews one branch)

### TEST

- [x] stopwatch, logbook, dev-pages, connector-dashboard, dev-preview-sessionstart, check-house-style and house-palette suites green; check-plugin-integrity clean

### DEPLOY: feat/stopwatch-cards-readable

The `/stopwatch` overview is a bare page, with no `h1` or lead (the breadcrumb names it), and groups its cards under one `h2` per prompt label (compared case-insensitively, the label with the newest run first, its sub line counting the runs); the Logbook, which draws its overview with the same function, keeps its bare page and its one Measurements heading (`-Flat`). The cards on both read in three lines, with no header above them: the run's start; its prompt label as the link to the run's page, with the run's version behind it (`v3`) once the label has run more than once; and its total time with its change against the previous run of the same label beside it, as a signed percent only (`+31%` in green when faster, `-25%` in red when slower: the sign is the result's). A card sets its text in the house sizes (`--text-lg`, `-base`, `-sm`, `-xs`), the text colour or `--muted`, and the weights 300 to 800 only, with no heading: the start is the heaviest line (base, 800), the prompt label with its version the least visible (sm, regular, muted), and the time light (base, 300) with its change beside it (xs, regular). The cards stand five to a row, then two and one on a narrow screen, in grids of the page's own (`.sw-grid`) with no top margin; the groups stand in one wrapper (`.sw-groups`) whose 40px gap spaces them apart.

The hub's airsquats banner is now always the first block of a hub page, above the `h1` where there is one (the general page shell, the home page and the Connectors page; the release notes already had it there).

The house style's `h2` is now 24px (`--text-h2`, was 32px) set in the sans (it was the serif `h1` keeps) and in the theme colour (`--primary`, was `--fg-2`), while the `h1` stands apart by its 32px serif capitals. The `.lead` under an `h1` is now body size (`--text-base`, was `--text-lg`). The site header's initials mark used `--text-h2` and now takes `--text-h1`, so it keeps its size. The breadcrumb trail is set at `--text-base` (was `--text-sm`), and under a site header its current page is in the theme colour (`--primary`, was `--fg-1`). The house style README, the brand book's type specimen and the checksum in the `house-style` skill follow the new file.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes the next house-style copy gets smaller sans `h2`s in its theme colour, a body-size lead under its `h1` and a larger breadcrumb trail with its current page in the theme colour, and every repo's hub shows its banner above the page title, without changing anything of its own.

**Score:** 3

#### Pull Request

Stopwatch cards grouped per prompt, the hub banner on top, and a smaller house h2
