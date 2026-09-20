## fix/2184-policy-drift-rank2-lenses

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

Issue [#2184](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2184): since #2179 moved
this repo's seam answers into `.claude/specialists/lenses/`, `check-policy-drift.ps1` reads none of
them. RANK 2 is built from documents under `dkj-policy/` and RANK 3 from the always-on closure, and a
lens is in neither -- so the largest restatement surface in the tree is examined by nothing, while the
report still prints as if it were complete.

#### The repair, and why candidate 1

The issue offers two candidates. **RANK 2 learns the new home** is the one taken: it matches what
#2179 actually did, keeps the three-rank model intact, and needs no fourth rank for a reader to learn.
A lens is exactly what RANK 2 says it is -- this repo's own answer to a seam -- and what separates it
from RANK 3 is that it is read on demand rather than always-on, which is the line RANK 3 already draws.

#### The lens location is ALREADY a seam, so no new one is written

`Get-LensDirCandidates` / `Get-SeamPaths` (check-report-lib, #221) own the four layouts a consumer's
lenses can sit in -- the seam directory, the pre-seam per-plugin tree, the pre-#179 family spelling and
the legacy `.claude/extensions/`. A new `repo-config.ps1` function would be a second answer to a
question that already has one, and would drag the script contract, the adopt blueprint and the
consumer scaffold along for nothing.

#### What a CONSUMER sees, which is the decision the issue asks for

Strictly additive. A consumer with no lenses gets exactly today's report, because the discovery returns
nothing. A consumer still carrying a populated `dkj-policy/` keeps those pages, listed first. The only
repo whose output changes is one that actually has lenses -- and there the change is the finding.

#### What is deliberately NOT touched: `Get-ConsumerProseDocuments`

That function is the #1380 corpus, and it is shared with the two GATED detectors behind
`consumer-prose-sessioncheck`. Widening it would change what a SessionStart hook reads in every
consumer, on a branch whose subject is an on-demand report. The blindness it has for the same reason
is a separate finding and is filed as one.

### CREATE

- [x] `scripts/task/check-policy-drift.ps1`: discover this repo's lens documents through the existing
      lens seam and fold them into RANK 2, minus any lens the always-on closure already lists at RANK 3
- [x] the rank title, the note under it and the hand-over wording follow the new membership
- [x] mirror the script into `plugins/dkj-policy/scripts/task/`
- [x] `plugins/dkj-policy/skills/check-policy-drift/SKILL.md`: what RANK 2 now holds, and why
- [x] the review round's repairs: the repo-relative form via `Get-PathRelativeToDirectory` instead of
      `Resolve-Path` + a substring (Victor), and the two wording findings (Edith)

### TEST

- [x] `scripts/tests/policy-drift-report.tests.ps1`: a lens lands in RANK 2, a lens that is
      `@`-imported stays in RANK 3 and is not listed twice, the pre-seam per-plugin tree is reached by
      its own route, and a tree with no lenses is unchanged
- [x] and the root-spelling regression the review found, pinned with an 8.3 short name -- measured
      against the old derivation first, so the test is known to fail without the repair
- [x] the parallel review round: Victor (code), Edith (copy), Sebastian (security)
- [x] the full gate: `check-plugin-integrity.ps1` + every suite

### DEPLOY: fix/2184-policy-drift-rank2-lenses

`check-policy-drift.ps1`'s RANK 2 reads the repo lenses. Since #2179 moved this repo's seam answers
out of `dkj-policy/` and into the lenses, RANK 2 was built from the workflow-folder prefix and RANK 3
from the always-on closure -- and a lens was in **neither**, so ~1,300 migrated lines were examined by
nothing. Measured here: 29 lens documents and 8,864 lines, against the two `(absent)` folder pages that
were the whole of RANK 2 before.

**The report still printed as though it were complete**, which is the part that cost. Two `(absent)`
lines read as *"this repo has no rank 2"* rather than as *"rank 2 moved and nobody told the tool"*, so
the blindness was invisible from the output -- the shape this repo keeps naming as the expensive one.
Each rank now closes with a tally of what is present and how many lines it holds, so a reader can see
the volume they are being handed and not only the names.

A lens joins rank 2 rather than getting a fourth rank because it does the same job the folder pages do:
it states *this* repo's answer to a seam. What keeps it out of rank 3 is that it is read on demand
rather than always-on -- and a lens the root document `@`-imports stays in rank 3, listed once, because
a document sitting in two ranks would be a *"which one wins"* question in the one report whose job is
to settle those.

**No new seam was written.** `Get-LensDirCandidates` / `Get-SeamPaths` (#221) already own the four
layouts a consumer's lenses may sit in -- the seam directory, the pre-seam per-plugin tree, the
pre-#179 family spelling and legacy `.claude/extensions/` -- and `Get-SpecialistFiles` owns both
filename spellings (#2130). A `repo-config.ps1` function beside them would have been a second answer to
a question that has one, and would have dragged the script contract, the adopt blueprint and the
consumer scaffold along for nothing.

**The review round caught the same blindness trying to come back through a second door**, which is
worth recording because it is the more interesting half. The first cut derived the repo-relative form
with `Resolve-Path` plus a substring, while every lens directory is composed off the root *as it
arrived* -- so on a checkout reached through an 8.3 short name the two spellings diverge and the rank
comes back empty, silently. Measured on a scratch tree before repairing it: `Resolve-Path` keeps the
short form it was handed (`...\Temp\PROBE-~2`) while `Get-ChildItem` returns the long `FullName`
(`...\Temp\probe-28e06bbc\...`), so the prefix test matched nothing. It now uses the pure
`Get-PathRelativeToDirectory`, which normalizes both sides without touching the filesystem, and the
suite pins it with a short name -- skipping out loud where the volume has 8.3 generation off, because a
silent skip there would read as coverage this suite does not have. The class was already documented in
`scripts/lib/worktree-lib.ps1`; what it had was no test.

`Get-ConsumerProseDocuments` is deliberately **not** widened to match. It is the same corpus the two
GATED prose detectors read behind `consumer-prose-sessioncheck`, so a change there moves what fires at
every session start in every adopted consumer -- a different decision from what an on-demand report
lays out. That blindness is real and is filed as
[#2188](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2188) rather than carried here.

**Score:** 2

#### What makes this deploy extra special

Every consumer of this workflow gets the same repair, and in the only way an additive one can be given:
a repo with no lenses gets exactly the report it had before, because the probe returns nothing and no
note is printed. Nothing is relocated and nothing is asked of the reader. The consumers this reaches
hardest are the ones running longest -- a repo bootstrapped before #221 keeps its lenses in
`.claude/plugins/<family>/<plugin>/` and is never moved, so a rank that had learned only the seam
directory would have stayed blind in exactly those trees. The suite pins that path by its own route.

**Score:** 2

#### Pull Request

check-policy-drift's RANK 2 learns the lens directory, so the migrated seam answers are read again

Plugins: dkj-policy

