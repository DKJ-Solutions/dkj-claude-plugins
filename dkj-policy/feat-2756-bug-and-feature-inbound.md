## feat/2756-bug-and-feature-inbound

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

#2756 (Dave): the single `inbound` label is replaced by two -- `bug-inbound` in the magenta `bug`
family (`FF00FF`) and `feature-inbound` in the cyan `enhancement` family (`a2eeef`). Dave's answers on
the thread: replace rather than add; the filer is always a Claude session, so the choice between the two
is the shared block's to state; the colours are the family anchors. Whether #2750 (dropping GitHub
issue types for labels) had to land first was left to the specialist: it does not, because #2750
consumes the bug/feature families and this branch is what gives inbound issues one. The label is the
route's name in the template, the constitution, the shared `inbound-behaviour` block and therefore every
generated subagent def, Chris's persona and manual, ADOPTION, the connectors README and Derek's lens.
The route itself keeps its name -- "inbound #NNN" citations are history and stay.

### CREATE

- [x] `inbound-behaviour.md`: the filer picks `bug-inbound` (something shipped is wrong) or
  `feature-inbound` (something is missing); `build-agent-defs.ps1` regenerated the 26 subagent defs
- [x] `.github/ISSUE_TEMPLATE/inbound-improvement.md` became `feature-inbound.md`, and `bug-inbound.md`
  is new beside it, asking what is wrong rather than what should change
- [x] The constitution, Chris's persona and manual, ADOPTION, connectors README, house-style, Derek's
  lens (with the decision and the prefix mapping), the language-layers rule, Sylvester's lens, the
  `claude.yml` comment and the `entry-scaffold-lib` comment (both copies)
- [x] "keeps the `inbound` route" loses its code style in `findings-become-issues.md` and the personas:
  it names the route, not a label
- [x] Tracker: `bug-inbound` and `feature-inbound` created
- [ ] Tracker: all 376 issues labelled `inbound` relabelled with one of the two, then `inbound` deleted
- [~] Test fixtures and the `open-pr` skill's quoted refusal keep `'inbound'`: they record a tracker
  payload as it was measured, not the canonical labels

### TEST

- [ ] The gates, through `ship-pr`

### DEPLOY: feat/2756-bug-and-feature-inbound

An inbound report is now filed as `bug-inbound` when something the plugins ship is wrong, or as
`feature-inbound` when something is missing, each with its own issue template. Every specialist's
shared instructions say which to pick. The single `inbound` label is gone from the source tracker, so a
session on an older release that files with `--label inbound` gets an error from `gh` until it
updates.

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the label split itself.

**Score:** N/A

#### Pull Request

The inbound label splits into bug-inbound and feature-inbound
