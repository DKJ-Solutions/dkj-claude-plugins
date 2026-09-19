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
- [x] The always-on budget gate, which is the measurement this branch could not have predicted:
      **+22 B**. The longer filename sits on the always-on path twice -- once in `SPECIALISTS.md`'s
      import and once in Chris's lens blockquote -- at 11 characters each. The path is already over the
      100,000 B ceiling, so the ratchet refuses growth outright. Raised on the record rather than
      absorbed by trimming unrelated prose, which is the gate's own stated route and the one that
      leaves a reviewer a sentence to argue with: 109,380 B -> 109,402 B.
- [x] The baseline key was **moved, not regenerated**, and the recorded byte figure is untouched.
      Regenerating is impossible on a branch: that key is an absolute
      `~/.claude/plugins/marketplaces/...` path resolving against the marketplace clone, which tracks
      `main`, so on a branch the import does not resolve and the gate reports the term as *unmeasured*
      instead of re-measuring it. Left unmoved it read as a 30,245 B **shrink** -- the dead-import hole
      reported as a saving, which is the same silence this whole step is written around.

### DEPLOY: feat/2135-persona-filenames

The four persona files -- Chris, Bianca, Derek and Rendall -- move to `specialist-NN-NN-persona.md`,
completing the #2128 rename round. Every reader that judges or constructs that name moves with them:
lint check 3c's frontmatter-versus-filename assert, check 6b's persona-backed-manual construction,
`check-consumer-drift.ps1`, `check-roster-sync.ps1` and its mirror, and the `specialists-init`
bootstrap -- which both *writes* the orchestrator's `@`-import into a consumer and *probes* the
marketplace clone for it. A loose `*-persona.md` glob is left loose throughout, so a file still on the
old name lands inside a refusal rather than outside the scan.

Two sites named in the issue turned out not to be this step's, and both were verified against the tree
rather than taken from the report. `teardown.ps1`'s `@`-import recogniser matches on the **suffix**
`-persona.md`, which the prefixed name still carries, so it needs no change and the reason given for
changing it could not have held. `bootstrap.ps1:856` and `:872` are lens literals belonging to #2133.

**Score:** 4

#### What makes this deploy extra special

A consumer's `SPECIALISTS.md` carries the orchestrator's body as a hardcoded absolute `@`-import into
the marketplace clone -- a clone that tracks `main` and advances on `claude plugin marketplace update`,
with no release, no version bump and no `plugin update` behind it. So this merge opens a window in which
any consumer that refreshes its clone before that line is edited loses Chris's entire persona body,
30,267 B of it, **in complete silence**: the rest of `CLAUDE.md` loads, the raw `@`-line stays in
context as inert text, and nothing is reported on stdout, on stderr or under `--debug`. The six
registered consumers are updated as part of this act, with the exact lines in #2134.

**Score:** 5

#### Pull Request

The four persona files take the specialist- prefix, and every reader of their path moves with them
