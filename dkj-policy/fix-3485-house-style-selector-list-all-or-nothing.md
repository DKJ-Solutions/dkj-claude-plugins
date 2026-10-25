## fix/3485-house-style-selector-list-all-or-nothing

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

#3485: `Find-HouseStyleClassHit` judged each member of a comma list on its own, so in the assert message
`a .facts--row, not a card` the middle member passed the #3120 prose rule (`a` is an element name). Whether it was
reported hung on paren balance elsewhere in the prelude. Read the list all or nothing instead: one member that is
prose or an unbalanced tail means the text before the `{` is no selector list.

### CREATE

- [x] `house-style-rules.ps1`: members are judged first, and the prelude is skipped when any of them fails
- [x] `check-house-style.tests.ps1`: the measured shape as a regression assert (red without the fix), and a
  list of real selectors that still counts

### TEST

- [x] The gates run in `ship-pr`

### DEPLOY: fix/3485-house-style-selector-list-all-or-nothing

`check-house-style` no longer reports a house class named in prose inside a script's string, such as an assert
message reading `a .card, not a list` ([#3485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3485)).
It judged each member of a comma list on its own, and `a` is an element name, so that member looked like a
selector. Whether it was reported depended on lines elsewhere in the file. A selector list now counts only when
every member of it is a selector.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo running the house-style gate stops getting a finding on an unchanged line after an edit
somewhere else in the same script.

**Score:** 1

#### Pull Request

check-house-style: a selector list is read all or nothing, so prose in a script string is no finding

