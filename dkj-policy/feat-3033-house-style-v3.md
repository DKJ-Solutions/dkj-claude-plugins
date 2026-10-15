## feat/3033-house-style-v3

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

Repoint the `house-style` skill to the brand book's `house-style-v3` tag, as #3033 asks. That means the
links, the commit and both checksums, each measured here from the bytes the tag serves. The same branch
moves the connector dashboard's vendored copy to v3 (#2989) and its own layer off the tokens v3 retired.
This is phase 0 of the cross-repo plan to bring every DKJ-Solutions repo onto one design system; the gate
that keeps them there is #3035.

### CREATE

- [x] Every `house-style-v2` link on `SKILL.md` now reads `house-style-v3`.
- [x] Commit `ac7a86b9e3cc646fbc389675480e0a4f01ec25aa`, read from the annotated tag.
- [x] Both sha256 values were measured from the bytes served at the tag and match `git show house-style-v3:<path>`:
  css `58cf0bbc…`, js `80e771ba…`.
- [x] `scripts/dashboard/house-style/` now holds the v3 files, byte-identical to the tag.
- [x] The dashboard's own layer in `connector-dashboard-lib.ps1` moved off four tokens v3 no longer defines:
  `--primary` → `--primary-7` (the highlight), `--primary-soft` and `--grid` → `--primary-3`,
  `--ink-2` → `--primary-6` (notes), following the role table in the brand book's README at the tag.

### TEST

- [x] Pre-inline rules checked on the v3 files: `house-theme.js` makes no network call, uses no `eval` or
  `new Function`, does not touch `document.cookie`, and keeps `localStorage` to the theme key;
  `house-style.css` carries no `@import` and no `url(`.
- [x] `connector-dashboard.tests.ps1`: 90 passed, 0 failed, the vendored-copy checksum assert included.
- [x] The owner looked at the dashboard and approved it (October 15, 2026).

### DEPLOY: feat/3033-house-style-v3

The `house-style` skill now points at the brand book's `house-style-v3` tag
([#3033](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3033)), with its commit and both
checksums measured here. The connector dashboard serves the v3 copy, and its own layer uses only tokens
v3 defines.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that takes its next copy of the house style gets v3, and v3 renames the colour tokens:
`--good`/`--bad`/`--up`/`--down`/`--warn`/`--ink`/`--muted`/`--gain` and the bare `--primary` are gone,
and their roles now sit on `--positive-N`/`--negative-N`/`--warning-N` and a nine-step `--primary-1`…`-9`.
An app's own layer must be renamed when it takes the copy. The mapping tables are in
`house-style/README.md` at the tag.

**Score:** 4

#### Pull Request

house-style skill repointed to house-style-v3, the renamed colour tokens

