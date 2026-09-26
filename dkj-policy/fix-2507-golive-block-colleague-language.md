## fix/2507-golive-block-colleague-language

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Inbound #2507: the paste-ready block was the one colleague-facing text whose words a script fixed in
English, and it lacked the sections of the block BWJ actually sends. The reference is Maikel's comment
of September 18, 2026 on the task behind `smartwatchbanden#394`, which the owner pointed to when rejecting
the English printout on `smartwatchbanden#769`. Verified on pickup: the backstop's de-duplication matches
only the marker (or its own lead sentence), so nothing inside the rules is load-bearing for it.

Found on the way: Windows PowerShell 5.1 pipes a string into a native command as ASCII, so
`$block | gh issue comment --body-file -` would have posted every accent and dash as `?`. The post
goes through a UTF-8 file now. The CI backstop's own placeholder is out of scope, filed as #2513.

### CREATE

- [x] `golive-block-rules.ps1`: the words per language (`Get-GoLiveBlockText`), the Dutch date without
  host culture data, the five-section shape in `Format-GoLiveBlock`, and `ConvertFrom-GoLiveProse`
  for the session's prose.
- [x] `build-golive-block.ps1`: `-Language` (default `nl`), `-ProseFile`, `-OutFile`, and the post
  through a UTF-8 body file instead of a pipe.
- [x] Suite: the go-live asserts rewritten for the new shape, plus both languages, the prose parser,
  a UTF-8 round trip through the driver, no-BOM output, and a static guard against piping into `gh`.
- [x] Docs: `WORKFLOW-portable.md` (the shape, rule 1, the plan wording), the skill page (the prose
  file, `-OutFile`), `PREVIEW-portable.md` (embed from `-OutFile`).

### TEST

- [x] `dkj-policy-bwj.tests.ps1` green: 434 asserts; the full gate runs in `open-pr`.
- [x] Driver run by hand on a fixture: the UTF-8 output matches the reference block's shape.

### DEPLOY: fix/2507-golive-block-colleague-language

The paste-ready block `golive-block` writes for the Asana task now has the shape BWJ actually sends its
colleagues, in their language ([#2507](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2507)).
It opens with `— automatisch bericht vanuit GitHub #<n>` and is set under five headings: `WAT ER NU
ANDERS IS`, `TE BEKIJKEN OP`, `WANNEER HET LIVE KOMT`, `WAT ER BEWUST NIET IN ZIT` and `WAT WE VAN JE
VRAGEN`. It used to be fixed English with no sections. Dutch is the default, and `-Language en`
writes the same shape for a task written in English. The date, version, live URLs and ask are still
the script's. What changed, where exactly to look and what was left out are the session's to write, in
a `-ProseFile`. `-OutFile` writes a UTF-8 copy for the preview handover page. `-Post` now sends the
body through a UTF-8 file: piped from Windows PowerShell 5.1, every accent and dash would have arrived
as `?`.

**Score:** 3

#### What makes this deploy extra special

N/A -- the block is carried into Asana by the store's own team; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

golive-block writes BWJ's Dutch sectioned block, in the colleague's language

