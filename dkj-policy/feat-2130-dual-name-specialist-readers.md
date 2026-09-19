## feat/2130-dual-name-specialist-readers

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

Build the dual-name layer every later rename step depends on: a resolver plus a retired-pattern list,
wired into every reader site. Nothing is renamed.

#### The shape chosen, and why it is one table rather than a resolver per kind

`Resolve-BranchFilePath` is the precedent the issue names, and it is the wrong one to copy wholesale:
it resolves ONE document by reading each candidate and asking which branch it declares, because a
filename there is not allowed to be the authority. A specialist file's name IS the authority -- the
lint holds it against the frontmatter -- so what is needed is not a declare-test but a single place
that knows every spelling. The nearer precedent is `Get-SubagentDirName`, one layer down, whose
docstring already states the doctrine for the directory leaf: **both are read and one is written**.

So the layer is a four-row table plus six derived readers, all in `check-report-lib.ps1` -- which is
already mirrored into the three plugins that carry a reader, so no new registry row and no new
dot-source chain. Steps B..F each swap one row and move that kind's files; **no reader is edited
again by the series**, because no reader names a shape.

### CREATE

- [x] `Get-SpecialistFileShapes` and its five derived helpers in `scripts/lib/check-report-lib.ps1`:
      `Get-SpecialistFileName` (the one written name), `Get-SpecialistFileNameCandidates` (every read
      name), `Get-SpecialistFileFilters`, `Get-SpecialistFiles`, `Get-SpecialistFileNamePattern`
      (duplicate named groups across the alternation, so a caller reads one `g`/`i` pair whichever
      spelling matched), `Get-SpecialistFileId` and `Get-SpecialistFileRefPattern`.
- [x] The `Get-RosterIdTokenPattern` lookbehind, split from `(?<![\d-])` into `(?<!\d)(?<!\d-)`.
- [x] `check-plugin-integrity.ps1` -- checks 3, 3b, 3c, 4, 6a, 6b, 30, 38.
- [x] `check-roster-sync.ps1` -- `Get-AgentIds`, `Get-PersonaIds`, `Get-LensPath`, `Get-AgentName`,
      `Get-LensIds`, the bootstrap-detection scan and the missing-lens finding.
- [x] `check-report-lib.ps1`'s own `Get-LensWriteDir`.
- [x] `check-connectors.ps1`, `check-consumer-drift.ps1` (both loops), `find-specialist-mentions.ps1`,
      `build-agent-defs.ps1`.
- [x] `bootstrap.ps1`, `teardown.ps1`, `sync-roster.ps1` -- each on a guarded load with a degraded arm
      that is exactly today's behaviour, because these three run in a consumer against whatever payload
      that machine last installed.
- [x] The mirror families regenerated: `check-report-lib.ps1` (root + three plugins) and
      `check-roster-sync.ps1` (root + `-alpha`).

#### Three defects found in the reader sites while wiring them, all repaired here

None of these is the rename. Each is a reader that was already wrong, or about to become wrong, and
each sits in a file this issue names -- so they are repaired in place rather than filed.

1. **`build-agent-defs.ps1` walked zero of the 26 agent defs.** Its filter was `'\\agents\\'`, which
   matches no path in this tree: the defs moved to `subagents/` at #1698, and that pattern needs a
   separator immediately before `agents` where the path has a `b`. Measured: 26 files, 0 matched.
   Nothing had drifted, because the lint's check 7 builds its own set correctly and compares all 30 --
   which is precisely why it was invisible for as long as the rename is old. Repaired and pinned by an
   assert, in both directions.
2. **`check-roster-sync.ps1`'s bootstrap-detection scan carried a drifted copy** of the roster-id
   pattern -- trailing `(?![\d-])` where the shared source has `(?!\d)` -- under a comment claiming the
   two were the same rule. The tighter form excludes an id followed by a hyphen, which is every lens
   reference ever written, so a roster whose ids sit only inside lens filenames read as **no roster
   row** and the `[BOOTSTRAP]` line would swallow every real finding. #182's own shape, one file over.
3. **The `(?<![\d-])` lookbehind was a silent break waiting for step D.** In
   `.claude/specialists/SPECIALISTS.md` the four main-loop personas carry their id **only** inside the
   lens filename; once that is `specialist-01-01-lens.md` the id is preceded by an ordinary word's
   hyphen and Chris, Bianca, Derek and Rendall stop counting as rostered -- in a file no
   `^(\d{2})-(\d{2})-...$` sweep reaches. The two copies of that pattern in `teardown.ps1` now both ask
   the shared function; one of them was a bare literal that would not have picked the repair up.

### TEST

- [x] Lint gate: `0 error(s)`, including the mirror check over all four `check-report-lib` copies.
- [x] Full suite gate: **118 of 118 passed**.
- [x] `check-report-lib.tests.ps1` -- a new section 9 for the layer and a section 10 for the token
      pattern. 377 asserts pass. Written against the PROPERTY, not today's answers: the written name is
      the first read candidate, every candidate round-trips to its id, some filter reaches every
      candidate, a half-renamed name (`specialist-02-09-agent.md`) is accepted by neither shape, and
      both alternation branches fill the same named groups. The only literals are the two hazards --
      the ISO date that must stay out and the renamed lens filename that must get in.
- [x] `subagent-shared.tests.ps1` -- the assert pinning `'*-persona.md'` was the one spelling the layer
      exists to stop anybody writing, so it now pins the widening it was actually for. Added: the layer
      selects **exactly** the files the pre-#2130 globs did over this tree, which is this branch's whole
      claim stated as an assert; and the generator's directory filter, in both directions.
- [x] Byte-unchanged apart from the readers, as the issue requires: `git status` shows 16 files, all of
      them a reader, a mirror of one, or a suite. No manual, persona, subagent def or lens was touched.
- [x] Ran live, not just asserted: `check-roster-sync` (`0 error(s)`), `check-connectors`
      (`0 error(s)`), `check-consumer-drift` (26 defs + 4 personas enumerated; its one informational
      persona drift is byte-identical before and after this branch, verified against a stash),
      `find-specialist-mentions` (1672 mentions across 30 specialists), `build-agent-defs -Check`
      (now 30 files, all in sync).

### DEPLOY: feat/2130-dual-name-specialist-readers

The specialist filename readers now accept both conventions, so the #2128 rename can proceed one kind
at a time without a flag day. Four filename shapes -- manual, persona, subagent def, lens -- were
recognised by a scatter of independently anchored globs and `^(\d{2})-(\d{2})-...$` regexes across
thirteen reader sites in nine scripts, four of them held byte-identical to plugin mirrors. All of it now
goes through one four-row table in `check-report-lib.ps1`, on `Get-SubagentDirName`'s standing doctrine:
both are read, one is written. Each later step of the series swaps one row and moves that kind's files;
no reader is edited again. **Nothing is renamed by this change** and the tree is byte-unchanged apart
from the readers.

Wiring them surfaced three defects that were already there. `build-agent-defs.ps1` had been walking
**zero of the 26 agent defs** since the `agents/` -> `subagents/` rename, invisibly, because the lint
check that would have reported the resulting drift builds its own set correctly. The roster check's
bootstrap-detection scan carried a hand-copied id pattern that had drifted tighter than its source, so a
roster whose ids sit only inside lens filenames read as no roster at all. And the shared lookbehind
would have quietly unrostered the four main-loop personas at step D, in a file no anchored-filename
sweep reaches.

**Score:** 3

#### What makes this deploy extra special

The three repaired readers travel to a consumer in the plugin payload -- `bootstrap.ps1`,
`teardown.ps1`, `sync-roster.ps1` and `check-roster-sync.ps1` -- so a consumer gets them at the next
release. Today they change one behaviour and prevent three. Changed: a consumer whose roster ids appear
only inside lens filenames is no longer told it was never bootstrapped, which is the `[BOOTSTRAP]` line
that suppresses every other finding under it. Prevented, once a kind is renamed: a bootstrap writing a
second empty lens over one the owner had filled in, a teardown leaving the other spelling behind, and a
roster check reporting a plugin as shipping no subagents at all. Nothing a consumer has to do, and no
migration -- which is the point of doing this before anything moves.

**Score:** 1

#### Pull Request

The specialist filename readers learn both conventions

