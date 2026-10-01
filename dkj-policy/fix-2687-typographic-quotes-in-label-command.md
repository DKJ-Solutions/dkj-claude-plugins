## fix/2687-typographic-quotes-in-label-command

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

#2687: `Format-SingleQuotedArg` doubled only U+0027, while PowerShell's tokenizer also reads U+2018,
U+2019, U+201A and U+201B as single-quote delimiters. Reason verified before the repair: a
`PSParser::Tokenize` of `'a` + U+2019 U+2019 + ` b'` yields one string token holding one U+2019, so
doubling is the right escape for all five.

### CREATE

- [x] `scripts/task/adopt-triage-labels.ps1`: the escape covers all five single quotes, composed from
  code points (the script layer is ASCII); plugin mirror synced.
- [x] `adopt-triage-labels.tests.ps1` test 6c: per typographic quote, the composed line tokenizes into
  exactly two string arguments, the description reads back raw, and `evil` is no token of its own.
  Asserted in-process on the function, since the child's printed output is decoded with the console
  code page and cp850 has no U+2019.

### TEST

- [x] The suite passes (89 asserts); against the old function 6c fails on all four code points.

### DEPLOY: fix/2687-typographic-quotes-in-label-command

`adopt-triage-labels` now escapes the four typographic single quotes (U+2018, U+2019, U+201A, U+201B)
as well as the ASCII one in the `gh label create` line it prints. PowerShell reads all five as
quote delimiters, so a consumer's own `Get-TriageLabels` description carrying a curly apostrophe
closed the printed argument early and spilled the rest into separate tokens on paste (#2687).

**Score:** 1

#### What makes this deploy extra special

N/A. Only a consumer that answers `Get-TriageLabels` with a curly apostrophe of its own is reached,
and the script only prints the line; nothing a subscriber runs changes otherwise.

**Score:** N/A

#### Pull Request

adopt-triage-labels: escape PowerShell's typographic single quotes in the printed command

