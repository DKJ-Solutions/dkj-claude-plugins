## feat/heading-colours-h2-h3

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

Dave, October 19, 2026: the h2 looked too much like the h1 (both `--primary-7`). The first pass gave h2 `-8` and h3
the grey `-6`. Dave then rejected the grey: a grey h3 does not work, and `-9` is reserved for body text. So the
scale grows from nine steps to twelve, in three groups of four: `-1` to `-4` the light steps of the colour, `-5` to `-8`
the greys (a faint tint, light to dark), `-9` to `-12` the dark steps. Dave chose the strict 4/4/4 numbering from a
menu: old -1 -2 -3 -4 -5 -6 -7 -8 -9 become -1 -2 -4 -5 -6 -7 -9 -10 -12, and -3, -8 and -11 are new. Headings: h1 `-9`,
h2 `-10`, h3-h6 `-11`. On a `-12` surface they are h1 `-4`, h2 `-3` and h3-h6 `-2`.

#### The anchors (Dave, October 19, 2026, second round)

`-1` and `-12` sit against the edge of white and black. `-4` and `-9` are the theme's colour where it reads best on
black or white: `-9` is the most saturated colour of the hue at 4.55:1 on `-1`, and `-4` the same against `-12`.
`-2`/`-3` and `-10`/`-11` run evenly between them, and the greys stay. The cost, measured: the cards are tinted much
more, so `-9` on a card drops below 4.5:1 in eight themes (Magenta 3.2:1), and on dark `-6` on a card drops to 2.9:1.

#### A visible result

This changes what every page looks like, so the branch stops for the owner's look before it merges.

#### Not reachable from here

The README names the Figma library *DKJ-Solutions Theme's - LIBRARY* as the mirror of the theme values. The three
new steps still have to be added there, by hand.

### CREATE

- [x] `house-style.css`: each of the 15 theme blocks rewritten from nine to twelve values. The three new steps are derived per theme in OKLCH (-3 halfway between -2 and -4; -8 at L 0.31 or 0.80 dark in -7's hue and chroma; -11 halfway between -10 and -12), and every other value is unchanged and renumbered
- [x] every `--primary-N` use renumbered in the stylesheet, the brandbook (`brandbook/src`) and the scripts that emit house CSS (dev-pages, connector-dashboard, general-pages, dev-preview placeholder, repo-config allowlist)
- [x] headings: `:where(h1)` -9, `:where(h2)` -10, `:where(h3-h6)` -11, and `.card__title`, `.dkj-card-title` and `.dkj-dialog-title` -11
- [x] the short-form step names in comments (`-7`, `-5` …) renumbered by hand, and the scale comment rewritten for the three groups
- [x] `README.md`: the current rules renumbered, the lightness tables given the three new rows, and a nine-to-twelve migration table added for consuming apps. The historical migration tables keep their old numbers
- [x] `dev-pages-lib.ps1` reads and draws twelve steps per theme
- [x] `house-style` skill: the new sha256 of `house-style.css`
- [x] the anchors: every theme's `-1` to `-4` and `-9` to `-12` recomputed. The rule and the measured contrasts are in the stylesheet comment and the README, which drops the old per-step tables
- [x] `house-theme.js`: each theme's picker dot is its new `-9`; the `house-style` skill pins both new checksums
- [x] filed #3193: the README's detailed lightness tables disagree with the shipped grey values (it predates this branch)

### TEST

- [x] `check-house-style.tests.ps1`: 88 passed (red until the checksum followed)
- [x] `dev-pages.tests.ps1`: 232 passed, its fixture and step count moved to twelve
- [x] `connector-dashboard.tests.ps1` 164 passed, `dev-preview-sessionstart.tests.ps1` 181 passed
- [x] `check-plugin-integrity.ps1`: 0 errors; the brandbook builds

### DEPLOY: feat/heading-colours-h2-h3

Inside this repo the brandbook, the repo hub and the dev pages render with the twelve-step scale. The hub's theme
table shows twelve columns.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release has to renumber its own `--primary-*` uses. The names stay valid,
so a missed one fails silently and just shows the wrong colour. The README's migration table gives the order. The
headings change by themselves: h2 moves off the h1's colour to `-10`, and h3-h6 take the new dark step `-11`.
The colours themselves change too: `-1` and `-12` are almost white and black, the theme's colour (`-9`) is the most
saturated version of its hue that still reads on the page, and the cards and lines carry clearly more colour.

**Score:** 5

#### Pull Request

The primary scale grows to twelve steps (4 light, 4 grey, 4 dark); h2 takes -10 and h3-h6 the new -11
