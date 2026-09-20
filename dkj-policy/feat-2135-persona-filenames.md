## feat/2135-persona-filenames

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

Step F of the #2128 rename round, and the last one. Depends on #2130 (dual-name readers) and #2134
(the consumer migration section) having landed -- **the PR is deliberately held until steps A-E are
done** (Dave, September 19, 2026). The work is built now so it is ready the moment the window opens.

#### What this branch moves, and what it deliberately leaves

`plugins/dkj-subagents/dkj-subagents-alpha/personas/NN-NN-persona.md` -> `specialist-NN-NN-persona.md`,
four files: `01-01` (Chris), `03-02` (Bianca), `05-05` (Derek), `05-06` (Rendall).

It follows **step C's discipline** (`706512b3`, Dave's own hand, the most recent precedent in this
round): rename the files, move every live pointer to them, move the readers that **judge or construct**
that name, and leave a loose `*-persona.md` glob loose -- a loose glob matches both spellings, which is
what keeps a file left on the old name inside a refusal rather than outside the scan. Step B
(`c4257223`) left its readers to #2130 and is red by design; this branch is green instead, because the
four sites it touches are ones #2130's dual-name layer can widen later without conflict.

**`INSTALL.md` is untouched on purpose** -- it is #2134's file for this round, and that branch already
carries both spellings of the import line. One line there still goes stale when this merges, filed as a
comment on #2134.

### CREATE

- [x] `git mv` the four persona files to `specialist-NN-NN-persona.md`.
- [x] The readers that **judge** the name -- the anchored `^(\d{2})-(\d{2})-persona$` in
      `check-plugin-integrity.ps1` (check 3c), `check-consumer-drift.ps1`, `check-roster-sync.ps1` and
      its byte-identical `dkj-subagents-alpha` mirror, and `bootstrap.ps1:229`.
- [x] The reader that **constructs** it -- check 6b's `personas\$g-$id-persona.md` and the orphan-manual
      message that names it.
- [x] What `bootstrap.ps1` **writes and probes** -- the `$bodyImport` line it writes into a consumer's
      `SPECIALISTS.md` (`:811`) and the clone probe that must find the import target (`:149`), plus the
      two comments stating the convention (`:20`, `:43`, `:145`).
- [x] The live pointers: the `@`-import in `.claude/specialists/SPECIALISTS.md`, the blockquote in the
      `01-01`, `05-05` and `05-06` lenses, the specialists handbook, `triage-inbound/SKILL.md`, the
      `orchestrator` skill page, the root `README.md` convention statements, and the
      `always-on-budget-lib.ps1` comment in both mirror copies.
- [x] The persona key in `dkj-policy/always-on-baseline.json`.
- [~] `teardown.ps1:132` -- **no change needed**, and the issue's stated reason does not hold. See TEST.
- [~] `bootstrap.ps1:856` and `:872` -- **not this step's.** Both are `01-01-extension.md` literals, so
      they belong to #2133 (step D). Filed as a comment there, since #2133's own scope list omits them.
- [~] `find-specialist-mentions.ps1:118` -- left to #2130. Its `^(\d{2}-\d{2})-` anchor is broken
      identically by steps B, C, D and F, which is what makes it a shared reader rather than this
      branch's to claim.

- [x] **Rebased onto the table, after #2130/#2131/#2132/#2133 landed.** This branch was cut from
      `a77465f8`, before step A, so it edited each reader by hand. On `main` every one of those sites
      now reads through `Get-SpecialistFiles` / `Get-SpecialistFileId` /
      `Get-SpecialistFileNamePattern`, which resolve from `Get-SpecialistFileShapes`. So the merge took
      **main's** version of all six reader sites -- `check-plugin-integrity.ps1`,
      `check-consumer-drift.ps1`, `check-roster-sync.ps1` and its mirror, `bootstrap.ps1`,
      `check-plugin-integrity-docs.tests.ps1` -- and the hand-written anchors were discarded.
- [x] **Flipped the Persona row instead**, in all four copies of `check-report-lib.ps1`: `Current`
      takes `Prefix = 'specialist-'`, `AlsoRead` keeps the bare spelling a consumer's cache still
      carries. That is the contract the table's own docstring states -- *"Step B..F each move one
      kind's files and swap that kind's row here; no reader is touched again"* -- and it is what step C
      did. **No reader moves with this branch**, which is the opposite of what the CREATE steps above
      say and the whole point of the architecture that landed in between.
- [x] **This repo takes its own overlap advice.** `SPECIALISTS.md` now carries BOTH import lines, new
      one first, per `INSTALL.md`'s "Do it with BOTH lines" -- which #2134 published two PRs ago. This
      repo is one of the six consumers, and the single-line edit this branch originally made opens
      exactly the silent window that section exists to close. Measured here rather than argued: with
      one line the budget gate reported the dead import and a 30,245 B "shrink", which is Chris's body
      dropping out of every session in this checkout.
- [x] Filed [#2167](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2167): step D renamed
      the lenses and never flipped the **Lens** row, so `Get-SpecialistFileName -Kind Lens` still
      returns `<id>-extension.md` and `specialists-init` scaffolds a fresh consumer's lenses under the
- [x] Corrected the branch title, which `new-branch -Title` wrote at creation and which travels
      verbatim into `CHANGELOG.md`. It read *"every reader of their path moves with them"* -- true of
      the pre-#2130 implementation, and the exact opposite of what now lands. The write-once rule
      exists so the PR, the changelog and the release notes cannot disagree about what a change is
      called; it is not a reason to ship a sentence the diff contradicts.
      retired name. Not repaired here -- different kind, different subject.
### TEST

- [x] `check-plugin-integrity.ps1`: **0 errors**, and `[persona] checked 4` -- the renamed files are
      found and validated rather than skipped, which is the failure a loose glob would have hidden.
- [x] The full test gate: **all 118 suites passed in 1,089s**, `Invoke-TestSuiteGate` at 5 lanes --
      lanes set by free memory rather than cores on this machine (#2121), which is why it took that
      long. Zero failures, zero crashes, zero timeouts.
- [x] `teardown.ps1:132` verified against the tree rather than against the report. The recogniser is
      `($line -match '^\s*@') -and ($line -match '(-persona\.md|-extension\.md)\s*$')` -- **suffix**
      anchored, so `specialist-01-01-persona.md` still ends in `-persona.md` and still matches. The
      issue's reason ("teardown stops removing what bootstrap wrote") is the one thing that cannot
      happen here. The lens half of the same line is the one that does break, under #2133, because
      `specialist-01-01-lens.md` does not end in `-extension.md`.
- [x] The always-on budget gate, re-measured on the merged state and **not** the +22 B this branch
      first recorded: **+415 B**, 109,739 B -> 110,154 B. The longer filename is only part of it; the
      rest is the deliberate overlap -- the second import line and its comment, about 280 B, which
      comes back off the path when that line is deleted after the clone is refreshed. Raised on the
      record with that impermanence named, so whoever removes the line knows the figure is expected to
      fall rather than reading it as the new floor.
- [x] The baseline key is **regenerated through the gate, on the merged state** -- the earlier
      hand-move is moot. With both import lines present the old path resolves, so the persona body is
      measured rather than reported as a hole, which is what made regenerating impossible before. The
      dead-import `[WARN]` now names the NEW path and is correct: it is inert until the clone catches
      up, which is precisely the state the two-line recipe makes safe.
- [x] Lint gate 0 errors with `[persona] checked 4`, and all 118 suites green in 807s, on the reworked
      tree -- so the row flip carries the rename with no reader edited.
### DEPLOY: feat/2135-persona-filenames

The four persona files -- Chris, Bianca, Derek and Rendall -- become `specialist-NN-NN-persona.md`,
closing the #2128 rename round. **No reader moves with them.** What makes this the written name is a
single row: `Get-SpecialistFileShapes`'s Persona entry, where `Current` takes the `specialist-` prefix
and `AlsoRead` keeps the bare spelling a consumer's cache may still be carrying. Every site that judges
or constructs the name -- lint check 3c, check 6b's persona-backed-manual construction,
`check-consumer-drift.ps1`, `check-roster-sync.ps1` and its mirror, and the `specialists-init`
bootstrap that both writes the orchestrator's `@`-import and probes the clone for it -- already reads
through that table, so a file left on the old name is still enumerated and still refused, because the
filter list derives from the same row.

That is not how this branch was originally written. It was cut before step A (#2130) and edited each
reader by hand; the merge that brought A through D in discarded those anchors in favour of main's
shape-driven ones. The round therefore ends the way step C ended, which is the property the table was
built for.

Two sites the issue named turned out not to be this step's, both verified against the tree rather than
taken from the report. `teardown.ps1`'s `@`-import recogniser matches on the **suffix** `-persona.md`,
which the prefixed name still carries, so the stated reason for changing it could not have held.
`bootstrap.ps1:856` and `:872` are lens literals belonging to #2133.

**Score:** 4

#### What makes this deploy extra special

A consumer's `SPECIALISTS.md` carries the orchestrator's body as a hardcoded absolute `@`-import into
the marketplace clone -- a clone that tracks `main` and advances on `claude plugin marketplace update`,
with no release, no version bump and no `plugin update` behind it. So this merge opens a window in which
any consumer that refreshes its clone before that line is edited loses Chris's entire persona body,
30,267 B of it, **in complete silence**: the rest of `CLAUDE.md` loads, the raw `@`-line stays in
context as inert text, and nothing is reported on stdout, on stderr or under `--debug`.

**This repo closed that window on itself rather than only documenting it for others.** Its
`SPECIALISTS.md` now carries both import lines, new one first -- the recipe #2134 published in
`INSTALL.md`, applied to the first of the six registered consumers. It was not a precaution: with the
single-line edit the budget gate reported the dead import and a 30,245 B shrink on this very checkout,
which is the measurement rather than the theory. The remaining five consumers take the same recipe,
and the old line comes out on both sides once the clone is refreshed.

**Score:** 5

#### Pull Request

The four persona files take the specialist- prefix, and the Persona row is what carries it
