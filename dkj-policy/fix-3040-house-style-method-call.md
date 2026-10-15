## fix/3040-house-style-method-call

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

Issue [#3040](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3040) and its two comments
(dkj-music-library, dkj-etf-tracker). Read in `Find-HouseStyleClassHit`: the text before any `{` is
taken as a selector, and the class pattern excluded only a word character or quote before the dot.
Reproduced on strings: a chained `.sort(`/`.map(` before `=> ({`, `[...H].sort((a, b) => {`, and an
object spread `...meta,`. The Python `.sub(lambda` shape did not reproduce from the description alone.

### CREATE

- [x] The class pattern (and the own-class pattern beside it) refuses a dot before the dot and a `(` right after the name; `]` and `)` before the dot stay allowed, because `[x].card` and `:not(.a).card` are selectors.
- [x] `check-house-style.tests.ps1`: one line held two asserts with no separator; split.

### TEST

- [x] Six new asserts in group 1d: the three script shapes give no hit, the two CSS shapes beside a `]`/`)` still do, and a method call elsewhere does not hide a real rule. 58 passed.

### DEPLOY: fix/3040-house-style-method-call

`check-house-style` no longer reads a method call or an object spread in a script as a house class
selector ([#3040](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3040)). A chained `.sort(`
or `.map(` before an arrow function, and `...meta,` inside an object literal, had been reported as
restyling `.sort`, `.map` or `.meta`.

**Score:** 2

#### What makes this deploy extra special

In a DKJ-Solutions repo, the house-style gate and its session-start line no longer flag TypeScript or
JavaScript such as `.sort((a, b) => {` or `{ ...meta, }` as a restyled house class. A repo that had to
answer those lines in `Get-HouseStyleAllowlist` can remove those entries.

**Score:** 2

#### Pull Request

check-house-style: a method call or object spread is no house class selector
