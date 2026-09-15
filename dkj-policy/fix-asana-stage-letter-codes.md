## fix/asana-stage-letter-codes

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

#### The gap (inbound #2016, filed from BWJ-Development/smartwatchbanden#657)

`Get-StageFromSectionName` recognises a section by a bare leading digit and casts it to `[int]`; every
ordering comparison downstream (`Sync-AsanaTaskStage`'s forward-only guard) compares that raw
magnitude. A consumer whose board groups several of its own stages under one leading digit from a
second, coarser board (smartwatchbanden aligning `GitHub - SWB` to `Workload Overview`) cannot be
expressed: `1A`/`1B`/`1C` either fail to parse at all, or collide once cast to `[int]`.

#### The fix

A stage code becomes a STRING that may carry one trailing letter, kept as a string everywhere. Every
comparison downstream is equality or containment (`-eq`, `-contains`), which PowerShell already
coerces across int/string -- the one genuine magnitude comparison (the forward-only guard) goes
through a new `Get-StageRank`, which reads a code's position in the map's own declared cycle order
instead of the code's numeric value. A Hashtable key (the one place PowerShell's coercion does not
reach) is normalised to `[string]` explicitly on both the write and the read.

### CREATE

- [x] Widen `Get-StageFromSectionName`'s regex to `^\s*([0-9]+[A-Za-z]*)\s*\.` and return the code as
      a string.
- [x] Drop the now-unnecessary `[int]` casts at every equality/containment site touching a stage
      value (`Get-StageMapNumbers`, `Get-WritableStages`, `Test-StageIsWritable`,
      `Test-StageIsTerminal`, `Get-StageForProjectStatus`, `Get-StageFloorForIssue`,
      `Resolve-TargetStage`, `Get-SubmitterHandoff`).
- [x] Add `Get-StageRank` and use it for `Sync-AsanaTaskStage`'s one magnitude comparison (the
      forward-only guard and its `(back)` log annotation).
- [x] Normalise the `Get-ProjectStageSections` dictionary and its `Sync-AsanaTaskStage` lookups to
      `[string]` keys explicitly.
- [x] Loosen `Test-AsanaStageMap`'s validation regex to accept an optional trailing letter
      (`^[1-9][0-9]*[A-Za-z]*$`), dropping the separate `-lt 1` check it replaces.

### TEST

- [x] `scripts/tests/dkj-policy-bwj.tests.ps1` -- the 251 pre-existing asserts over these functions
      (including the `$shifted`-map case) pass unchanged, proving zero behaviour change for a board
      that never adopts a letter.
- [x] Added 22 new asserts: `Get-StageFromSectionName` on lettered names, a `$lettered` map matching
      smartwatchbanden's actual rename (`1A`/`1B`/`1C`/`2`/`3A`/`3B`/`4`) through
      `Test-AsanaStageMap`/`Test-StageIsWritable`/`Test-StageIsTerminal`, and `Get-StageRank` proving
      the cycle order survives a shared leading digit (`1C` ranks before `2` though `"1C" > "2"` as
      text) plus agreeing with the default map's own plain-integer order.
- [x] `scripts/lint/check-plugin-integrity.ps1`: 0 errors.
- [~] the full `scripts/tests/*.tests.ps1` glob, run by hand as a second check before the PR: aborted
      mid-run when it collided with another session's uncommitted work on a shared checkout (branch
      `fix/2018-parked-fix-scan-title-overlap`, safely stashed and left untouched, not this branch's
      concern to resolve). Not re-run by hand a second time -- `open-pr.ps1` runs this exact glob
      itself as its own gate before a PR opens, so the step's intent (the full suite proves this
      sound before merge) is still met without a second manual pass that risks the same collision
      again.

### DEPLOY: fix/asana-stage-letter-codes

A stage code in `Get-AsanaStageMap` may now carry one trailing letter (`'1C'`, not just `'3'`), so a
consuming repo can group several of its own cycle stages under one leading digit shared with a second,
coarser board -- exactly the blocker smartwatchbanden hit renaming `GitHub - SWB` to align with
`Workload Overview`. Every board that has not adopted a letter is unaffected: the 251 pre-existing
asserts over these functions pass byte-for-byte unchanged, because ordering is now read from the map's
own declared cycle position (`Get-StageRank`) rather than the raw magnitude of the code, and that
reduces to the same answer a bare `1`..`7` already gave.

**Score:** 3 -- a repo that renames its board to share a leading digit goes from silently broken (a
section either drops off the pipeline entirely or is misread as a different stage) to correctly
tracked, the moment it touches that part. No repo that keeps plain per-stage numbers notices anything
changed.

#### What makes this deploy extra special

N/A -- an internal CI/Asana-mirroring mechanism; no subscriber of a service built on a consuming repo
is ever a reader of this.

**Score:** N/A

#### Pull Request

asana-mirror stage codes support a compound number+letter section prefix

