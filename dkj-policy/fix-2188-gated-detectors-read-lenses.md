## fix/2188-gated-detectors-read-lenses

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

Measured before building, because #2188's three questions are all measurements and the third one
turned out to be decisive.

- **Does a lens belong in the shared corpus at all?** Yes, and the argument is that the corpus already
  held one HALF of rank 2. #2179 put this repo's seam answers in the lenses and #2184 taught
  `check-policy-drift.ps1` to read them as RANK 2 -- the same rank as the `dkj-policy/` pages the corpus
  already carries. A retired convention restated in `dkj-policy/README.md` was reported at session start;
  the identical sentence in a lens was not.
- **The supremacy grep's false-positive cost over a lens.** #2188 predicted this would be the blocker
  ("a lens is where this family writes *about* the rank order"). Measured over 29 non-imported lenses,
  9,100 lines: **0 findings**. The prediction is disconfirmed rather than merely unobserved.
- **The per-session cost.** The one that nearly sank it -- see CREATE.

### CREATE

- [x] Widen `Get-ConsumerProseDocuments` to kind 3, the repo lenses, behind a new optional `-RepoRoot`.
      The walk reuses `Get-SeamPaths` / `Get-LensDirCandidates` / `Get-SpecialistFiles`, all already on
      `main`, so no layout rule is written here. Omitting `-RepoRoot` is exactly today's two-kind corpus,
      which is both the degradation for an older caller and the per-detector seam #2197 may need.
- [x] Measure the naive widening first: **+5.7 s at every session start**, in every adopted consumer.
      That is twelve times the ~457 ms saving #1421's whole hook merge was built for, so it was
      disqualifying and the branch went profiling instead of shipping.
- [x] `Test-ProseCarriesAnyLiteral` -- a whole-text literal prefilter in both detectors. Rejects 29 of
      34 documents for ~3-6 ms total. Provably lossless: both detectors match literals that must already
      appear contiguously in the raw text, and the paragraph join can only INSERT a space while its two
      strips are anchored at line start, so no match can exist in a unit and not in the text.
- [x] Profile what survived it, which is where the two real defects were. Both predate this branch by
      months and were invisible at 78 KB:
      - `Get-ProseParagraphUnits` built one `[pscustomobject]` per LINE for its offset map -- 677 ms of
        a 1,100 ms walk on a 312 KB document, against 8 ms for all the regex work. Now two parallel int
        arrays; `Resolve-ProseUnitLine` reads the same two numbers and returns the same line.
      - `Get-RetiredDocNameMention` allocated a `List[object]` per LINE to track claimed spans -- 573 ms
        against 41 ms for the eight `IndexOf` passes it supports, on lines that almost never claim
        anything. Now allocated on the first claim.
- [x] Regenerate the `dkj-policy` mirror (`build-shared-scripts.ps1`).
- [x] File the half this machine cannot measure: #2197, the retired-name detector's false-positive rate
      over a CONSUMER's lenses.

### TEST

- [x] 12 new asserts in `consumer-prose-gate.tests.ps1`, 91 passing in all. They pin the corpus widening,
      the `-RepoRoot` seam in both directions, the once-only rule for an `@`-imported lens, both detectors
      firing on a defect in a lens, and `Test-ProseCarriesAnyLiteral` on its own.
- [x] The prefilter's losslessness is pinned by the case that would break it -- a declaration hard-wrapped
      across two lines of a lens. A well-meaning narrowing to a per-LINE test passes every other case in
      the file and empties the gate on exactly the shape #1415 built the paragraph walk for.
- [x] The suite now dot-sources `check-report-lib.ps1`; without it the lens half degrades silently to off
      and every new case would have passed for the wrong reason.
- [x] Lint gate: 0 errors. Full suite sweep: green.

### DEPLOY: fix/2188-gated-detectors-read-lenses

The two prose detectors behind `consumer-prose-sessioncheck` now read a repo's specialist lenses, not
just its always-on closure and workflow folder -- so a consumer restating a retired branch-document name,
or declaring its own `CLAUDE.md` the winner over the workflow's page, is reported wherever that sentence
actually sits. The corpus held one half of rank 2 and not the other; #2184 had just taught the on-demand
drift report to read the lens surface, and this is the always-on hook catching up.

It ships with the three repairs that make it affordable, because the widening alone measured **+5.7 s at
every session start** -- twelve times the saving the hook merge was built for. A literal prefilter rejects
the documents that cannot match, and two per-line allocation defects that predate this work were removed
from the hot path. Measured best-of-3, old code against new:

| tree | before | after |
|---|---|---|
| a repo with no lenses (3 documents) | 261 ms | **104 ms** |
| this repo (5 -> 34 documents, 767 KB) | 482 ms | **838 ms** |

So a consumer with no lenses gets a check 2.5x faster than before, and the worst-case tree in the family
pays +356 ms for 6.8x the corpus.

**Score:** 4

#### What makes this deploy extra special

N/A -- nobody outside this repo's own maintainers reads this. The detectors ship in `dkj-policy` and run
at session start in every adopted consumer, so the reach is real, but what changes for them is a gate
that sees more and runs faster: no action, no migration, nothing to read.

**Score:** N/A

#### Pull Request

The gated prose detectors read the repo lenses, behind a literal prefilter
