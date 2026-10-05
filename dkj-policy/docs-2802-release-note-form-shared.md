## docs/2802-release-note-form-shared

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

Inbound [#2802](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2802), four asks. Verified first:
`Build-ReleaseNote` merges `Get-ReleaseNoteWording` over its defaults key by key (title, `For whom`, the section
headings), so a repo can already rename the form. The rule therefore names that seam as the one route,
rather than forbidding any change. Item 2 (language) is answered as a per-repo content answer, translated
once through the same seam. Item 3 is proposed in `adopt-bwj-development`. Item 4, the optional check, is
split to #2812, because published notes keep their old form and the check needs a cutoff it cannot infer.

### CREATE

- [x] `cut-release` skill, step 2: the form is the plugin's, `Get-ReleaseNoteWording` is the one route, a lens restating it is drift, and the language is a per-repo content answer
- [x] `adopt-bwj-development`, step 2: propose `Get-ReleaseNoteTaskLink` in both store repos
- [x] Item 4 filed as #2812

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: docs/2802-release-note-form-shared

The `cut-release` skill now says whose the audience release note's form is. The title line, the `Date` /
`Type` / `For whom` labels and the section headings are what the cut drafts, and `Get-ReleaseNoteWording`
is the only route to change them. A lens or comment that restates or translates them is drift. The note's
language is a per-repo content answer, translated once through that seam. `adopt-bwj-development` now
proposes `Get-ReleaseNoteTaskLink` to both stores, so their drafts arrive as solved tasks.

**Score:** 2

#### What makes this deploy extra special

A store writes its release note in the plugin's form, not in one a local page invented. To use other
labels or another language, answer `Get-ReleaseNoteWording` once and drop the lens section or comment that
restated the form. The BWJ stores are offered the task form of the note at adoption, so the cut drafts
which Asana tasks were solved and nobody rewrites the entries by hand.

**Score:** 3

#### Pull Request

The audience release note's form is the plugin's, and only Get-ReleaseNoteWording changes it

