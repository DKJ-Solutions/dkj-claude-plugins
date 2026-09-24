## feat/2304-split-new-branch-suite

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

Step 5 of #2304. Step 4's comment named the next move: re-read the durations over a few 5-shard runs,
then split `new-branch` if it is still the floor. A partial step, so it ships with `-NoResolves`.

### CREATE

- [x] Re-read `suite-durations.json` over three 5-shard PR runs (35902838420, 35900890044,
  35899919410). The trunk's merge and fold runs print no suite table, so PR runs are the source.
  Pool 6,593s, work bound ~330s over 20 lanes, `new-branch.tests.ps1` 392.5s: the one file above it.
- [x] Split it into three suites over a shared `new-branch-fixture.ps1`, cut at scenario boundaries
  and balanced on measured local time. No scenario reads another one's variables (checked before the cut).
- [x] Repoint the five comments that name a scenario now in another file, and the `(n2)` citation in
  `new-branch.ps1` (both copies, still byte-identical).
- [x] Record step 5 in `ci.yml`'s matrix comment.

### TEST

- [x] The three suites side by side: 79 + 154 + 69 = 302 asserts, the count the single file
  reported. Longest part 52.5s against 149s for the single file, on the same workstation.
- [x] Brought forward over 184 trunk commits (merge; `suite-durations.json` kept this branch's reading,
  less the two `round-*` rows #2414 retired). CI then went red on `fixture-lib-deps.tests.ps1`, which
  landed after the branch point: the "no repo root" scenario copies `new-branch.ps1` alone, and the
  fixture's lib copies that used to share its file now sit in `new-branch-fixture.ps1`. Declared with the
  gate's own `fixture-dep: script-not-loaded` opt-out and its reason; `fixture-lib-deps` 49/49 green.

### DEPLOY: feat/2304-split-new-branch-suite

`new-branch.tests.ps1` is three suites now (`new-branch`, `new-branch-document`, `new-branch-base`),
over a shared `new-branch-fixture.ps1`. Re-read over three 5-shard runs, it was the one file above the
gate's work bound (392.5s against ~330s over 20 lanes). With it split, the heaviest remaining file is
229.4s and the gate is bound by total work again. All 302 asserts are preserved and were verified by
running the three parts. `suite-durations.json` is re-recorded from those runs. Step 5 of #2304.

**Score:** 3

#### What makes this deploy extra special

This split was cheap. Every scenario already built its own fixture, so nothing had to be rebuilt per
part the way the integrity family's splits had to. Whether a sixth shard pays is for the next re-read,
once the three new names have real durations.

**Score:** N/A

#### Pull Request

Split new-branch.tests.ps1, the critical-path file on five shards

