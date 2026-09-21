## fix/2237-workflow-facts-crlf

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

Normalise line endings once on read in Get-WorkflowFacts; add a CRLF fixture to the suite.

#### The six pickup checks on inbound #2237

All six pass, and two were verified by measurement rather than read:

- **Symptom** -- stands. `scripts/task/adopt-ci-floor.ps1`'s job-`name:` capture is anchored on `$`.
- **Reason** -- verified, not taken on the report's word. Both regexes were run against the same text in
  CRLF and LF: keys `[theme-check]` both times, names `[]` on CRLF and `[Shopify theme check]` on LF.
- **Repair** -- names a mechanism that exists, and an established one: `subagent-shared-lib.ps1:128`
  already normalises on read with the identical `-replace`.
- **Subject** -- exists, in the source copy and its plugin mirror.
- **Size** -- as reported. Of the six regexes in the function only the `name:` one breaks; the job-KEY
  one survives by accident (`\s*$` absorbs the `\r`), and the four `on:`/`jobs:` matchers carry an
  explicit `\r?\n`.
- **Repo** -- the symptom is in this tree, not the reporter's.

**The report's "why the source never hit it" is right and understates itself.** This repo's own
`.gitattributes` pins `* text=auto eol=lf`, so even on `core.autocrlf=true` the workflows are LF here --
a second, independent reason on top of the one the report names (ci.yml's job declares no `name:`). Both
would have to fail before this tree could see it, which is why it took a consumer to find.

### CREATE

- [x] `Get-WorkflowFacts` normalises to LF once on read, before any of its regexes see the text
- [x] The docstring's "both are collected" promise says what that sentence depends on
- [x] The plugin mirror rebuilt via `scripts/sync/build-shared-scripts.ps1`

### TEST

- [x] Section 10 added to `scripts/tests/adopt-ci-floor.tests.ps1`: a fixture written with literal CRLF,
      whose job declares a `name:` -- the two things every existing fixture lacks
- [x] **Proven to fail without the repair.** Backed the one line out and re-ran: the five CRLF asserts
      go red and the two LF control asserts stay green, so they are pinned to the line endings and not
      to anything else about the fixture. That run also confirms the auto-fill half of the report
      end to end, which is the part that reaches past a wrong note into a merge outage.
- [x] `adopt-ci-floor.tests.ps1` green with the repair in: 172 passed, 0 failed
- [x] Full lint + test gate green

### DEPLOY: fix/2237-workflow-facts-crlf

`adopt-ci-floor` reads a job's `name:` on a CRLF checkout, so a Windows consumer is no longer handed a
ruleset requiring a check GitHub never reports.

`Get-WorkflowFacts` collected job keys and job names with two regexes, both anchored on `$`. .NET's
multiline `$` matches only immediately before a `\n`, so against a CRLF file the name capture's
`[^\r\n]*` stopped at the `\r` and the anchor failed -- collecting no names at all -- while the key
capture survived the same file by accident, its `\s*$` absorbing the `\r` first. The text is normalised
to LF once on read now, which closes the class rather than the two instances visible today.

**The damage reached past the wrong note it was reported as.** `$prJobIds` then held one id where LF
holds two, and one is exactly the count the paste-ready ruleset call auto-fills on -- so a consumer with
a single named job in a single `pull_request` workflow was handed a ruleset requiring the job KEY, while
GitHub reports that check under its NAME. A required check that never reports leaves every pull request
pending forever. On LF the same tree declines to auto-fill and prints the candidate list, so the bug
moved the script onto the branch it would otherwise have refused.

Reported from `BWJ-Development/xoxowildhearts` as inbound #2237.

**Score:** 4

#### What makes this deploy extra special

A subscriber of this workflow on Windows -- which is the reporting consumer's own configuration -- could
follow a printed instruction into a merge outage on their trunk. It reaches only a consumer who adopts
the CI floor without a required check already in place, but for that consumer the failure is total and
the cause is three layers from the symptom.

**Score:** 4

#### Pull Request

Get-WorkflowFacts reads a job name on CRLF too

