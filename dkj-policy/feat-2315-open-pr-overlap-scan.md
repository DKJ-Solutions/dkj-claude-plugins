## feat/2315-open-pr-overlap-scan

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

#### The finding, and what had to be settled before building anything

Issue [#2315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2315): nothing in this
workflow reports that another open pull request is editing the same file. The first thing that does is
`ship-pr`'s forward lap learning it from GitHub as `422 merge conflict between base and head` -- on
PR #2300, at forward lap 3, roughly forty minutes of CI waits in.

The issue left three questions open, and it named the house convention for the second: measure the
false-positive rate over recent PRs before building the check.

- [x] **Where it runs.** `open-pr`, as the issue proposed -- and that is also `ship-pr`'s step 1, so
      the scan runs once more at the start of every ship, which is the last cheap moment before the
      certification laps. Checked against the incident: #2308 opened 15:01Z and #2310 at 15:22Z, and
      #2300's ship run reached its 422 about forty minutes before merging at 16:17Z -- so that run
      began after both siblings were open and the note would have printed for it.
- [x] **What counts as an overlap.** Path equality, no exclusion list -- see the measurement below.
- [x] **The cost.** One `gh pr list --json files`: ~700ms here against ~580ms for the label gate's own
      query, rising ~25ms per open PR. Bounded, and it passes the shared network bound like every
      other network call in this workflow.

#### The measurement the issue asked for, and what it changed

Held against this repo's last 60 pull requests (#2195-#2316, September 22, 2026): 40 had at least one
concurrently open PR, and 11 of those -- about 18% of all 60 -- would have seen this note, over 13
overlapping pairs in all.

**Filtering `CHANGELOG.md` and the branch document out changed nothing: 13 against 13.** Neither path
appears in a single PR's changed-file set, because the fold writes the changelog on the trunk after the
merge, and [#1255](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1255) gave every branch
its own document. So the exclusion list the issue proposed -- and itself named as the obvious way for
this to go stale -- is not built: it would be a mechanism with nothing to exclude.

All 13 pairs were genuine same-file collisions on real source, the incident's own
`.github/workflows/ci.yml` among them. What the measurement did surface is mirrored paths: 5 of the 13
are one shared workflow script arriving as its root copy plus two plugin mirrors. They are not
collapsed -- three files really can conflict three times -- and what answers them is the per-PR path
cap in the note.

#### And one thing the issue proposed that was checked and NOT built

Its draft note closed with *"Merging the trunk in NOW costs one resolution instead of one per
certification lap."* That sentence is wrong at the moment the note prints: every PR it names is OPEN,
so its work is not on the trunk and there is nothing to merge in. It is replaced by the decision that
is actually available before either lands -- ship them in a deliberate order rather than racing them --
and an assert pins that the old wording cannot be helpfully re-added.

### CREATE

- [x] `scripts/lib/pr-overlap-lib.ps1` -- the payload parse, the path normalisation, the intersection
      and the wording, all pure: no git, no gh, no disk. It reuses two sibling libs rather than
      hand-rolling either, both after review caught the hand-rolled version: `Convert-GitQuotedPath`
      (`git-porcelain-lib.ps1`) for the decode, `Get-DisplayRef` / `Get-DisplayPath`
      (`ref-print-lib.ps1`) for the three fields the note prints.
- [x] `scripts/release/open-pr.ps1` -- the scan block beside the label gate, before the lint and test
      gates, composing the note and warning with it; re-printed at all three of the script's endings,
      exactly where the machine-local note (#1559) is, because everything before the gates is
      off-screen by the time anybody reads an ending.
- [x] Registered in `scripts/lib/shared-scripts-lib.ps1` as a `LibOnly` mirror in `dkj-policy`, the
      mirrors regenerated, and the row added to `plugins/dkj-policy/scripts/README.md`.

### TEST

- [x] `scripts/tests/pr-overlap-lib.tests.ps1` -- 86 asserts over seven sections: the parse (including
      both Windows PowerShell 5.1 traps and the three unreadable answers), the normalisation, the
      intersection, the wording, the sanitising of the three fields somebody else wrote, the `open-pr`
      wiring, and the mirror.
- [x] Smoke-tested against the live repo: the two real calls made, this branch measured against the
      open PRs, and the note rendered on a replayed positive case.
- [x] Lint gate green (`check-plugin-integrity.ps1`, 0 errors) -- it caught the missing mirror row.
- [x] Full suite gate via `open-pr`.

#### What the review chain caught, and what it changed

Three reviewers read the diff in parallel. Four findings, all repaired here rather than filed:

- **The path normalisation was broken for every non-ASCII path** (code review + security review,
  independently). The caller forces `-c core.quotePath=true`, so git emits `"cafe\314\201.md"`, and the
  hand-rolled quote-strip left the octal escapes for the slash-normalisation to turn into separators --
  `cafe/314/201.md` -- while gh's copy arrived decoded. The two could never match, so the scan went
  silent on exactly the paths its own comment claimed to handle. That is inbound #821's lesson one file
  over; `Convert-GitQuotedPath` now does the decode, before the slash-normalisation.
  **The suite had asserted the wrong shape**: its fixture wrapped a literal accented character in
  quotes, which git never emits under that flag, so the assert passed over broken code. It now uses the
  octal form, verified by hand against a throwaway repo.
- **The title, the head ref and the shared paths are written by strangers** (security review). This repo
  is public, anyone can open a pull request, and git permits the format characters in a ref while a
  GitHub title is unrestricted free text -- an RTL override, a zero-width joiner or a line separator can
  make this note read as something other than what it is, to a person and to an agent driving the ship.
  `open-pr.ps1` already declines to print even its own branch name raw (#1623). All three fields now go
  through `ref-print-lib.ps1`, paths via `Get-DisplayPath` rather than `Get-DisplayRef` because a path
  may legitimately hold a space (#1638).
- **A percentage attached to the wrong number, and a duration that did not hold** (copy edit). "About
  18%" sat beside the 13 pairs where it describes the 11 PRs, and "both PRs listed for over an hour" is
  false for #2310, which was open 55 minutes. The percentage moved; the duration is replaced by the
  timestamps, which are the checkable part.
- **A dead test alternative** (code review): a two-branch regex whose first branch could never match,
  reading as coverage. Trimmed to the one that does.

And one the repair itself introduced, caught by the suite on its first run after: the sanitised path was
assigned to `$shown`, shadowing the finding list of the same name, so the truncation line asked a string
for its `.Count` -- a terminating error under `Set-StrictMode`, which failed the whole note rather than
printing it wrongly.

### DEPLOY: feat/2315-open-pr-overlap-scan

`open-pr` now says which OTHER open pull requests change a file this branch also changes -- a note,
never a refusal, printed beside the label gate and repeated at each of the script's endings. Nothing
reported that before: the first thing that did was `ship-pr`'s forward lap meeting it as
`422 merge conflict between base and head`, on PR #2300 at forward lap 3, roughly forty minutes of CI
waits in -- while both colliding PRs (#2308 opened 15:01Z, #2310 at 15:22Z, against a merge at 16:17Z)
were listed in `gh pr list` throughout that run, readable by one command.

It is not `ship-pr`'s conflict guard ([#1584](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1584))
firing late. That one asks whether this PR is conflicting *now*, a fact about the trunk, and it was
correct and silent here because the conflict came into existence during the run. This asks whether
somebody else is editing what you are editing -- a fact about other open *branches*, knowable before
the trunk has moved at all.

**There is no exclusion list, and that is measured rather than omitted.**
[#2315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2315) predicted path equality would
be noisy on `CHANGELOG.md` and proposed one while naming it as the obvious way for this to go stale.
Over this repo's last 60 pull requests: 40 with a concurrent PR, 11 of them would see this note, 13
overlapping pairs -- and filtering the changelog and the branch document out changed nothing, 13
against 13. The fold writes the changelog on the trunk after the merge, and #1255 gave every branch its
own document, so neither path is ever in a PR's diff. All 13 pairs were real same-file collisions.

Because the note is advisory it costs nothing when it is wrong, which is why the reach question is
answered by measuring rather than by narrowing: one `gh pr list --json files` at ~700ms, bounded by the
shared network bound, on a path before the suites rather than after them.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow gets the note in their own `open-pr` with no configuration: the lib
ships as a `dkj-policy` mirror and the scan reads only what `git` and `gh` already answer. It is silent
on a repo with one branch in flight, which is most consumers most of the time, and it can refuse
nothing -- so the cost of adopting it is one extra `gh` call before the gates and the benefit lands on
exactly the days two people are working the same file.

**Score:** 2

#### Pull Request

open-pr reports which other open PRs change a file this branch also changes
