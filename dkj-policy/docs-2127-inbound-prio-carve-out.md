## docs/2127-inbound-prio-carve-out

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

#### The decision behind this branch

#2127 offered two mutually exclusive answers and called the choice a decision rather than a repair.
Two measurements taken while verifying the inbound item settled it, and Dave chose the carve-out
(September 19, 2026):

1. **The template reaches 2 of 12.** Of the twelve most recent `inbound` issues, only #2117 and #2048
   were filed through `.github/ISSUE_TEMPLATE/inbound-improvement.md` at all (its
   `## Which repo does this come from?` heading is the tell); the other ten are free-form
   `gh issue create --label inbound` calls that no front matter can reach. #2048 already carried
   `prio-3`, so a default rung would have repaired **one** of the eleven missing ones.
2. **The portable layer already decided it.** `plugins/dkj-policy/CONTRIBUTING-portable.md` states
   that priority is an offered convention -- *"nothing here reads it either"* -- and that **exactly
   one** label is prescribed to a consumer, the reach label. The carve-out makes that explicit where
   this repo's own rule is stated; it does not invent a new exception.

### CREATE

- [x] Chris's lens: the always-on statement binds the **filer** (*"every issue YOU file here"*) and
      its pointer list names the inbound carve-out. Rewritten **byte-neutral at 585 B**, since the
      always-on path is 9,380 B over budget and the ratchet refuses growth; the retired repo name in
      the #1685 citation was corrected in the same edit, which is where the budget came from.
- [x] Derek's lens: the carve-out itself, with both measurements and the declined template default,
      inserted directly under the re-rank commands so the *"arrived without a rung"* line is adjacent.
- [x] `triage-inbound` skill: ranking the item is part of the pickup, beside the six checks -- the
      half the carve-out creates, since the filer can no longer be asked to do it.
- [~] `.github/ISSUE_TEMPLATE/inbound-improvement.md` left at `labels: inbound`. Dropped
      deliberately: that is the decision, and Derek's lens names the file so a later reader does not
      read it as the unrepaired half. No internal reasoning is added to a form consumers read.

### TEST

- [x] `check-always-on-budget.ps1` green -- the path still measures 109,380 B, unchanged.
- [x] `check-plugin-integrity.ps1` green -- 0 error(s), dead links and `@`-imports included, which
      is the class a docs branch actually risks: two of the three edited files are link-carrying
      lenses and the third is a skill page.
- [~] A separate suite sweep dropped. `open-pr.ps1` runs that same gate and every suite before it
      pushes, so a copy started ahead of it proves nothing that gate would not catch and charges the
      same measurement twice.

### DEPLOY: docs/2127-inbound-prio-carve-out

The priority-label rule now says whose rule it is. *"Every issue filed here carries a priority
label"* read as a property of the tracker, which bound a consumer's session filing inbound to a
label set it has no reason to know -- and the portable layer had already decided the opposite,
prescribing only the reach label to a consumer. The rule now binds the **filer**, an `inbound` issue
is outside it by design, and the rung is set here at triage. The `triage-inbound` skill carries that
step beside its six verification checks; Derek's lens carries the measurement, including why a
default rung in the issue template was declined rather than left undone. The always-on statement was
rewritten byte-neutral, so the correction costs no session a single byte.

**Score:** 2

#### What makes this deploy extra special

N/A -- this is a governance clarification in this repo's own lenses and one of its skills. Nothing a
consumer installs changes: the portable layer already said what this now says, which is the whole
argument for the carve-out.

**Score:** N/A

#### Pull Request

The priority-label rule states its scope: it binds sessions working in this repo, not a consumer filing inbound
