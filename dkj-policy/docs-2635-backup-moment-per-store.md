## docs/2635-backup-moment-per-store

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

Inbound #2635 (smartwatchbanden#783). Verified on pickup: `THEME-LIFECYCLE-portable.md` still marks
backup-at-the-cut as BWJ's answer, and `Get-CutOrderWarning`'s docstring does too. The warning's own
text does as well, and it fires on every `live-preflight` run because that backup is taken before
the push. #2228 moved the moment and never touched these. Push-then-cut stays as it is. What changes
is that the backup's moment becomes a per-store choice, stated once, with a rule against taking two.

### CREATE

- [x] `THEME-LIFECYCLE-portable.md`: the one-paragraph rule, the order table (rewritten as a
      moment table), the restore sentence and standing approval 3 are now neutral on the moment,
      and there is a "pick one moment per store" rule.
- [x] `theme-lifecycle-rules.ps1` (source + byte-identical shopify mirror): `Get-CutOrderWarning`
      docstring and message, plus the rotation docstring and the rotation plan's reason string, no
      longer say the cut is what rotates the backup. No logic changed.
- [x] `shared-scripts-lib.ps1`: the registry comment says the same thing, corrected to match.
- [x] `theme-lifecycle/SKILL.md`: the "cut/push order" section called an unpushed trunk "the other
      order", which contradicts the new docstring and that page's own moment table. Reworded.

### TEST

- [x] The existing `theme-lifecycle-rules` suite asserts still hold (the message still names
      `push-then-cut` and `THEME-LIFECYCLE`). The full gate runs in open-pr.

### DEPLOY: docs/2635-backup-moment-per-store

The BWJ theme-lifecycle page no longer calls a backup taken at the cut BWJ's answer. Push-then-cut is
unchanged. When the release's one backup is taken is now a per-store choice: before the push through
`live-preflight` (a rollback point), or at the cut (a baseline of what shipped). The page also says to
pick one, because following both pages gave a store two backups per release, and the cut's backup
rotated out the rollback point the preflight had just made. The backup run's order warning no longer
calls a pre-push backup a departure from policy (#2635).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

theme-lifecycle: the backup's moment is a per-store choice, and a store takes only one

