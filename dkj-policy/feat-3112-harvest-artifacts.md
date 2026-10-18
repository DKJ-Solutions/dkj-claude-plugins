## feat/3112-harvest-artifacts

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

[#3112](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3112): the Artifacts register behind
`/artifacts` is kept by hand, so a newly published Artifact is missing until somebody adds it. Of the two
options the issue weighs, the harvester (option 2) is built: a PostToolUse hook on Artifact publish would
rewrite a tracked file on whatever branch is checked out -- usually the trunk -- and leave it dirty for
the ship scripts. Measured first: this machine's transcripts are about 450 MB, too much to scan on every
page request, so the page keeps reading the committed register and the harvest fills it.

### CREATE

- [x] `scripts/lib/artifact-harvest-lib.ps1`: read publishes from one transcript (url from the result, session attributed by `cwd`), merge them into the register (adds only, widens dates), write the file in its own two-space shape
- [x] `scripts/maintenance/harvest-artifacts.ps1`: the dry run and `-Apply` around it
- [x] `.claude/skills/harvest-artifacts/SKILL.md`: the repo-local skill that documents it
- [x] `scripts/dashboard/artifacts.json` harvested: no Artifact was missing; the handout's creation date corrected from 2026-10-07 to 2026-10-05, the day of its Docs create; the about and method lines name the harvest
- [x] `scripts/lib/dev-pages-lib.ps1`: the page footer names the harvest instead of "added by hand"

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: url reading, cwd attribution, one fixture transcript (read, asset upload, another repo and a cut-off last line skipped), the merge keeping hand corrections, a second harvest changing nothing, and the written file's round trip (107 passed)
- [x] A real run on this machine: 1196 transcripts in 6.6 s, 17 publishes from this repo, all five Artifacts already recorded

### DEPLOY: feat/3112-harvest-artifacts

The Artifacts register behind the dev server's `/artifacts` page is no longer kept by hand
([#3112](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3112)). The new repo-local
`harvest-artifacts` skill reads this machine's session transcripts and adds every Artifact or Claude
Docs doc a session here published that the register lacks; it only adds, so a title or kind corrected
in the register by hand is kept. A dry run unless `-Apply`.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server and its register are this repo's own maintenance tools; nothing a plugin user installs changes.

**Score:** N/A

#### Pull Request

The Artifacts register is filled from the session transcripts
