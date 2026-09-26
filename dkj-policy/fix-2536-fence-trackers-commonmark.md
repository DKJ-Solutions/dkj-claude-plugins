## fix/2536-fence-trackers-commonmark

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

#### Scope

Every plain fence toggle in the tree moves onto `Get-NextFenceState`, which moves out of
`measure-context-lib.ps1` into a dependency-free `fence-lib.ps1` so the PR-body libs and the roster check
can load it without the measuring lib. `Test-FenceDelimiterLine` goes. Three sites the issue's grep missed
come along: open-pr's template scan, entry-scaffold-lib's branch-document shape check, and one inline walk
in `entry-scaffold.tests.ps1`.

#### The indent decision

`Get-NextFenceState` opens a fence only at 0-3 spaces, counted from the document edge because it sees no
containers. The migrated readers accepted any indent, and the tree needs that: `cut-release/SKILL.md`
fences a `### DEPLOY:` example at five spaces inside a numbered item. So the function gets `-AnyIndent`,
the migrated readers pass it, and the always-on walk keeps #2534's rule. The two readers that already
used `\s{0,3}` (the branch-document shape check and its test) keep it.

### CREATE

- [x] `scripts/lib/fence-lib.ps1`: `Get-NextFenceState` with `-AnyIndent`; `measure-context-lib.ps1` dot-sources it
- [x] pr-body-lib (8 sites), pr-issues-lib, check-roster-sync, open-pr, entry-scaffold-lib (`Get-FencedLineFlags` + the shape check) and check-plugin-integrity (5 sites) moved onto it
- [x] `Test-FenceDelimiterLine` removed; `Get-FencedLineFlags`' premise about nested fences corrected
- [x] Mirrored into dkj-policy, dkj-policy-bwj and dkj-subagents-alpha (`shared-scripts-lib.ps1`, `build-shared-scripts.ps1`)
- [x] The eight fixtures that copy entry-scaffold-lib's siblings copy fence-lib too

### TEST

- [x] New `fence-lib.tests.ps1`: `-AnyIndent`, a nested block through `Get-FencedLineFlags` and `Get-GateBypassLines`, and a tree-wide guard against a plain toggle coming back (falsified against the old shapes)
- [x] `entry-scaffold.tests.ps1`: the one-owner assert now expects zero rule copies in the lib. A fixture whose closing fence read `` ```\n `` (a literal backslash-n) passed only because the toggle closed on it; fixed
- [x] measure-always-on, pr-body, pr-issues, release-lib, entry-scaffold, fence-lib green locally

### DEPLOY: fix/2536-fence-trackers-commonmark

The workflow's markdown readers now track fenced code blocks the CommonMark way. A block closes only on
a run of the same character at least as long as the one that opened it. Before this, a four-backtick
block quoting a three-backtick example closed at the inner fence, and the rest of the example was read
as real structure. That covered PR-body section and heading scans, the resolves reader, the changelog
entry format, open-pr's template scan, the roster check's import scan and the lint gate's anchor and
sample checks. Tilde fences are now recognised by the lint gate, which knew only backticks. All of them
share one definition, `Get-NextFenceState` in `fence-lib.ps1`. No real document is known to have been
misread; the repo's own test fixtures quote nested fences, so a PR body or entry quoting them was the
likeliest place for it to happen.

**Score:** 1

#### What makes this deploy extra special

N/A. Workflow tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

Move the remaining fence trackers to the CommonMark fence state

