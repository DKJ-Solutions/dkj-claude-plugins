## feat/house-style-to-dkj-brandbook

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

Scope chosen by the owner (Maikel, October 31, 2026): rename the name, not the files.

### CREATE

- [x] `git mv` the skill folder (`skills/house-style` -> `skills/dkj-brandbook`, frontmatter `name`) and the asset folder (`assets/house-style` -> `assets/dkj-brandbook`)
- [x] Repoint every path reader: `Get-HouseStyleCanonicalDir`, `Get-HouseStyleDir`, the hooks, the gate, the hub, the consumer dashboard, `Get-ReleaseVersionPins` (repo-config + blueprint), the CI path filters
- [x] Keep older tags readable: `Get-HouseStylePin` accepts `assets/house-style/` too, `Get-HouseStyleTagPin` tries both skill folders (`Get-HouseStyleSkillDirNames`), and the reusable workflow fetches both and takes whichever exists
- [x] Docs: the skill is `dkj-brandbook` everywhere, and the concept reads "the brand book"; the archived `dkj-brandbook` repo is named as such where history cites it
- [~] Hub page labels/routes and script console wording -- dropped from this branch, filed as #3704 (visible result) and #3705

### TEST

- [x] Suites: check-house-style (new asserts for the pre-rename spelling and the dual fetch), cut-release-drive, consumer-dashboard, dev-pages, dev-preview-sessionstart, house-palette, shared-scripts
- [x] Gates: plugin integrity, roster sync, script contract

### DEPLOY: feat/house-style-to-dkj-brandbook

The house style is renamed to **dkj-brandbook**: the skill is now `dkj-solutions:dkj-brandbook`, its canonical files sit in `plugins/dkj-policy/assets/dkj-brandbook/`, and the docs call it the brand book. The files keep their names (`house-style.css`, `house-theme.js`, the house tokens and classes, `check-house-style` and its session check), so no vendored copy has to change. The pin readers and the reusable `check-house-style` workflow read a skill page at a tag cut before the rename as well, so a consumer pinned at v6.1.0 or earlier keeps passing. Between this merge and the next cut, the skill page on `main` names v6.1.0 under the new folder path, which that tag does not serve. The cut repoints the tag, as it does after every brand book change.

**Score:** 3

#### What makes this deploy extra special

A session in a DKJ-Solutions repo loads the brand book under its new skill name, `dkj-brandbook`. Anything that calls the skill by its old name, `house-style`, now has to use the new one. The copies a repo vendors, and its CI call to the reusable workflow, stay as they are.

**Score:** 3

#### Pull Request

The house style is renamed to dkj-brandbook
