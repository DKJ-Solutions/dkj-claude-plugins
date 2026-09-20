## docs/2179-folder-docs-into-lenses

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

Phase B of #2171: this repo's OWN `dkj-policy/README.md` (167 lines) and `dkj-policy/CONTRIBUTING.md`
(1,132 lines) move into the specialist lenses, then both are deleted and every link retargeted. Phase A
-- the plugin stops scaffolding those two pages into a consumer -- is PR #2178 and is independent of this
branch: it touches the plugin-side scaffolder and this one touches only this repo's own copies.

Dave's answer on #2171 (September 20, 2026, full reach, chosen from a menu): this repo's own copies go
too, because otherwise *"there is only one CONTRIBUTING"* is false in the very repo that ships the
sentence.

#### The migration is a MOVE, not a summary

Almost every paragraph in those two pages is a measured instance carrying an issue number and a date.
What travels is the measurement, the decision and the date -- substantially verbatim, adapted only where
a link or a framing sentence has to change. What does NOT travel is the half that merely restates
`plugins/dkj-policy/CONTRIBUTING-portable.md`: the portable page is the one CONTRIBUTING a consumer and
this repo both read, and duplicating it here is what #2171 retired.

#### Where each passage lands

- `CONTRIBUTING.md:199-931` -- the branch-document mechanics and the PR gates -> Sylvester's lens,
  which already owns the gate checks and the `LAW-THIRD-RANK-ORDER` block the opening overlaps with.
- `CONTRIBUTING.md:116-192` -- ticket work as a no-op here, the #1456 claim measurement, the #1315 split
  identity, the label table, and `:697-892` the queue, the merge step and the merge-queue retirement ->
  Derek's lens.
- `CONTRIBUTING.md:1-70`, `:938-1101`, `:1104-1133` -- this page's own history, CUT RELEASE, and the
  live-stage no-op -> Rendall's lens, which already points back at this page and therefore has to be
  deduplicated rather than appended to.
- `README.md:69-142` -- this repo consuming itself, the per-machine install record, #1812 and #1449 ->
  `.claude/specialists/README.md`, the merge target Dave named in #2171.
- `README.md:9-24`, `:39-67`, `:144-167` -- the seam-answer table, i.e. `scripts/repo-config.ps1` read as
  prose -> Sylvester's lens.

### CREATE

- [x] Sylvester's lens: receive the branch-document mechanics, the PR gates and the seam-answer table
- [x] Derek's lens: receive step 1's Claude half, the claim measurements and the merge/queue material
- [x] Rendall's lens: receive CUT RELEASE, the live-stage no-op and the fold, deduplicated against what it already said
- [x] `.claude/specialists/README.md`: receive the self-consumption and plugin-update material
- [x] Tessa's lens: receive the pages' own history -- **added to the plan**, because the issue's table had no
      home for `CONTRIBUTING.md:1-70` that fitted. A page's life and death is doc governance, which is Tessa's,
      not the release manager's; her lens also carries the forwarding address for all four destinations.
- [x] Delete `dkj-policy/README.md` and `dkj-policy/CONTRIBUTING.md`
- [x] Retarget every link that pointed at either page, and read the bare-prose mentions by eye

### TEST

- [x] `check-plugin-integrity.ps1` green -- it is the dead-link gate, so it is what proves the retarget.
      First run: **9 dead links**, none of them among the 14 the issue counted -- 7 in the archived release
      notes and 2 in the living `releases/` pages. Repointed and re-run: 0 errors.
- [x] The always-on budget: the path **shrank by 79 B** (110,154 -> 110,075). The lenses are not on that
      path, so ~1,300 lines moved at no session cost; `CLAUDE.md`'s pointers got shorter, and the review
      pass then spent most of that back on the rule it had to rescue.
- [x] Review pass on the diff before the PR -- Edith on the prose, Victor on the mechanics, in parallel.
      Between them: a rule that lived only on the page being deleted, the fold's `removes` weakened to
      `clears`, an inverted sentence, eight duplicated provenance preambles, two archive links repointed
      at a page that does not carry what their prose cites, and a second consumer of `ReservedNames` the
      new comment had not named. All applied. Victor also filed
      [#2180](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2180) for a pre-existing check-20
      defect four lines from a comment this branch edits, scoped out deliberately.
- [x] Bring the branch forward: phase A (PR #2178) merged while this one was in review, so the
      statements about the scaffolder are written in the simple past rather than hedged across two PRs.

### DEPLOY: docs/2179-folder-docs-into-lenses

`dkj-policy/` carries no prose pages any more. This repo's own `CONTRIBUTING.md` (1,132 lines) and
`README.md` (167) are gone, and the ~1,300 lines of measured answers they held now sit in the lens of
the specialist who owns each: the branch-document mechanics, the pull-request gates and the
seam-answer table with Sylvester; the issue layer, the claim measurements and the merge step with
Derek; the fold, the cut and the live-stage no-op with Rendall; keeping a checkout's plugins current in
the specialists handbook; and the pages' own history, plus the forwarding address to all four, with
Tessa. This is phase B of #2171 -- phase A is the plugin no longer scaffolding either page into a
consumer -- and it exists because *"there is only one CONTRIBUTING"* was false in the very repo that
ships the sentence.

Nothing was summarised away: the measurements keep their issue numbers and their dates, and what was
left behind is the half that only restated `CONTRIBUTING-portable.md`, which is the duplication #2171
retired. What the move costs is the one page that read as a route end to end; that route is still
readable, in the portable page that always described it.

The dead-link gate is what proves the retarget, and it found nine links the issue's count of fourteen
had missed: seven in the archived release notes, where the published-record rule permits a link target to
be repointed and forbids the prose around it to be rewritten, and two in the living `releases/` pages,
where the visible label was corrected along with the target. The always-on path **shrank by 79 B**, so
~1,300 lines moved at no session cost at all.

**Score:** 3

#### What makes this deploy extra special

A consumer following the worked example in `plugins/dkj-policy/README.md` was about to meet a 404: it
offered this repo's own `dkj-policy/CONTRIBUTING.md` as the model for writing down your own answers,
and that file stops existing here. It now points at the specialist lenses, and says in the same breath
why the page it used to name is gone -- so the example a consumer copies is the arrangement this
workflow actually recommends rather than the one it just retired.

**Score:** 2

#### Pull Request

The workflow folder's own README and CONTRIBUTING move into the specialist lenses
