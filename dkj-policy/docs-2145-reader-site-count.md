## docs/2145-reader-site-count

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

Correct the feat/2130 pending entry: thirteen -> fourteen sites, and stop the two completeness claims
('all of it', 'no reader is edited again') from reading as a licence to skip the sweep in steps
#2132-#2135.

#### What was verified before anything was written

- The symptom stands: all three claims are still in `dkj-policy/CHANGELOG.md` under `## [Unreleased]`,
  so this is a live document rather than archived history and the `releases/**` carve-out does not
  reach it yet.
- The "nine scripts" half is RIGHT and is deliberately left alone. `Get-PluginIds` sits in
  `check-connectors.ps1`, which step A did touch -- its lens walk is one of the thirteen -- so the
  fourteenth site adds no tenth script. Only the site count was wrong.
- A tree-wide sweep for the same claim outside `CHANGELOG.md` found no other site, so the correction
  is confined to the one file.

### CREATE

- [x] The `feat/2130` entry's opening paragraph: `thirteen ... across` reworded so it states what was
      converted rather than asserting completeness, and the two completeness clauses removed from it.
- [x] A second paragraph added under it naming the fourteenth site, pointing at the `feat/2131` entry
      for why the sweep could not have found it, and stating that a later step still sweeps.
- [x] The `feat/2131` entry's own closing clause updated from *"is filed as #2145"* to *"is corrected
      under #2145"*, which is what this branch makes true.
- [~] The four parked branches for #2132-#2135 are NOT edited. Their branch documents are not on the
      trunk, and the licence this issue is about lived in the changelog entry a session would read on
      `main` -- which is the file that is corrected.

### TEST

- [x] Lint gate + full suite via `open-pr`.

### DEPLOY: docs/2145-reader-site-count

The `feat/2130` entry claimed thirteen reader sites, that **all of it** now goes through the four-row
table, and that **no reader is edited again**. All three were wrong by one site: step B (#2131) found
`Get-PluginIds` in `check-connectors.ps1` the moment it moved files, because that reader carries a
directory walk and a `-replace`, not one of the two shapes step A was sweeping for. The count now says
what was converted instead of asserting a total, the two completeness clauses are gone, and a paragraph
under them records the miss and states that a later step still sweeps before it moves anything.

It is corrected now rather than after the cut for one reason: the entry is still under
`## [Unreleased]`, so it is a live document, and four steps of the series (#2132, #2133, #2134, #2135)
are parked against it. A session picking one up reads *"no reader is edited again"* as a licence to skip
the sweep -- which is exactly the reasoning that let the fourteenth site through once already. After the
next cut the sentence is archived history and the carve-out for `dkj-policy/releases/**` applies.

**Score:** 2

#### What makes this deploy extra special

N/A -- the correction sits in the entry's tier-0 body, so it reaches this repo's own changelog release
document and nothing a subscriber installs or reads. No script, no plugin payload and no behaviour
changes.

**Score:** N/A

#### Pull Request

The #2130 entry's reader-site count and its completeness claims are corrected
