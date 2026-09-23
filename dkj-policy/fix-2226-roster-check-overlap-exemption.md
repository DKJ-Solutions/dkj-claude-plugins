## fix/2226-roster-check-overlap-exemption

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

#### The decision this branch implements

Issue #2226 reported a contradiction between two things this repo ships and left the repair open
("Not decided here"). Dave chose **option 1** on September 21, 2026: the check learns the overlap,
rather than `INSTALL.md` retiring the recipe.

What the contradiction is. `INSTALL.md`'s #2128 migration section *recommends* carrying **both**
`@`-import lines in `.claude/specialists/SPECIALISTS.md` — the new spelling above the old — because
that is the one order in which the orchestrator's body is never absent. During that overlap exactly
one of the two lines is dead **by design**. And `check-roster-sync.ps1` errors on every unresolvable
roster import, without exception, which `roster-sessioncheck` then forwards into context at every
session start, resume, clear and compact. A consumer following the recommended recipe therefore had
no way to be green until they finished the migration.

#### Verified against the tree before any of this was written

- `INSTALL.md:371` — the dual-line recipe, recommended; the single edit is the *"if you would rather"*
  alternative.
- `scripts/sync/check-roster-sync.ps1:598` — one unconditional `Write-Failure`, no import class exempt.
- `scripts/tests/roster-sync.tests.ps1:1712` — case 18b pins it: `exit-code 1 -- loud, not soft`.
- **One claim in the report is overstated and is not repaired as written.** #2226 calls it a *blocking*
  `[ERROR]`. It blocks nothing: `roster-sessioncheck.ps1` ends on `exit 0` by design ("a session start
  must never strand here"), and the check appears in no CI workflow and in no gate. *Blocking* is the
  check's own vocabulary for a finding it surfaces, not a statement about the session. What is real is
  permanent noise on every session start for the whole migration.

#### Why [INFO] and not a new severity

`check-report-lib.ps1` has four levels — `[OK]`, `[SKIP]`, `[INFO]`, `[ERROR]`. `Write-Info` does not
increment `$script:errors`, so the check keeps exit 0; and `roster-sessioncheck.ps1`'s docstring states
that `[INFO]` stays **silent at session start** while a deliberate run of the script shows everything.
So the overlap goes quiet where it was noise and stays visible where somebody is looking. Nothing new
had to be built.

#### The collision, named rather than worked around

`fix/2224-stale-clone-import-remediation` rewrote the same `Write-Failure` block — it splits that
finding's cause list by import class. This branch was cut from `origin/main` without building on it.
#2224 landed first (#2245, September 21, 2026), and the conflict was resolved on September 23, 2026 by
merging `main` into this branch: the overlap check runs first, and its `else` branch carries #2224's
class-split cause list unchanged, in both script copies. `roster-sync.tests.ps1` holds both repairs:
414 pass, 0 fail.

#### Handover — this branch was parked mid-chain on September 21, 2026

Parked because the session had to end, not because anything is blocked. Everything below is on `origin`.

**What is finished and verified.** The implementation and its tests. `roster-sync.tests.ps1` runs 408
assertions, 0 failures, including 20 new ones as cases 18f-18i: the overlap pair with the new spelling
live, the same pair reversed (the recipe has to be safe in both directions), both lines dead (still two
`[ERROR]`s, exit 1, not softened), and an unrelated live sibling (still `[ERROR]` — the exemption must
not fire on a coincidence). `check-plugin-integrity.ps1` is clean. Root and mirror are byte-identical.

**What is NOT done, and must be redone rather than assumed.** The review round — code, copy edit and
security, in parallel on the diff — was in flight when the session ended and was cut off. Their partial
output is **not** a verdict and is deliberately not recorded here as one. One thing worth knowing is
that the code reviewer said it had read the whole diff, found no blocking bug, and had one
informational finding it had not yet named; that finding is lost and is a reason to run the review
again rather than to skip it. Re-run all three.

**The local test gate is red on two suites that are not ours.** A full `open-pr.ps1 -GatesOnly` run
failed on `connectors.tests.ps1` and `connector-sessioncheck.tests.ps1`, both killed by the 1,800s
per-suite bound. Both pass standalone on this tree minutes later — 384/384 in 158.2s and 51/51 in
90.5s. So `open-pr` will refuse to push until either the gate is re-run green or `-SkipTests` is
passed. **That is an open decision for whoever resumes, and Dave has not chosen:** re-running cost
~1.75h here and can flake again; `-SkipTests` keeps the lint gate, and CI's required `lint-en-tests`
still blocks the merge until it is green — but it is a deliberate gate bypass, so it belongs in the
pull request body and in the close-out.

**Filed along the way:**
[#2231](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2231) — `connector-sessioncheck.tests.ps1`
wedged for 22 minutes at 0s CPU with no children, past its own 300s bound, against a recorded normal
cost of 26.6s. Measured, with the machine-suspend explanation (#2095) ruled out for that suite: a
2,490s suspend does not fit inside a 1,512s process lifetime. The cause of the wedge itself is stated
as not established.

#### Resumed on September 23, 2026

Picked up under the existing claim (`maikel-bwj`, which is also this checkout's git and gh identity).
The two open points above are closed: the #2224 collision is resolved (see *The collision*), and the
gate question was decided by Dave in
[#2267](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2267) on September 22, 2026 — on the
machine this runs on, `open-pr` runs with `-SkipTests`, keeping the lint gate, while the required CI
check `lint-en-tests` runs every suite before the merge. The bypass is stated in the pull request body.
The review round was re-run from scratch.

### CREATE

- [x] `scripts/sync/check-roster-sync.ps1`: `Get-ImportOverlapKey` (normalises the `specialist-` prefix
      off an import's **filename** only — the #2128 rename left directories untouched) plus the `[INFO]`
      branch in the import loop, ahead of the existing `Write-Failure`, which stays byte-for-byte as it is.
- [x] Hold the exemption to its bounds: same directory required; **both** lines dead still errors, because
      that is the genuine no-body state the check exists for; a live sibling that is a *different* document
      still errors.
- [x] Regenerate the plugin mirror with `scripts/sync/build-shared-scripts.ps1` and confirm root and mirror
      are byte-identical (check 8 of the lint gate).

### TEST

- [x] `scripts/tests/roster-sync.tests.ps1`: cases 18f-18i. 408 pass, 0 fail; case 18b left exactly as it was.
- [ ] Code review, copy edit and security review on the diff — started, cut off by the session ending,
      no verdict received. Re-run from scratch.
- [ ] `check-plugin-integrity.ps1` plus every suite green. Lint is clean; the suite half is the red-on-two
      state described under PLAN, and the way past it is the open decision recorded there.

### DEPLOY: fix/2226-roster-check-overlap-exemption

`check-roster-sync` no longer reports a dead `@`-import as an error when a sibling import in the same
directory resolves to the same document under the other spelling — the `specialist-` migration overlap
that `INSTALL.md` recommends. It reports `[INFO]` there instead, which the session-start hook already
keeps silent and a deliberate run of the check still shows. Everything else is untouched: an unpaired
dead import, two dead lines, or a live sibling that is a different document all still error, because
those are the state this check was built for — the orchestrator running without his body while nothing
says so.

The two documents disagreed and each was internally consistent: the recipe is correct, and so was the
check's refusal to exempt anything. What was missing is that during a prescribed overlap nothing is
absent — a sibling is carrying it.

**Score:** 2

#### What makes this deploy extra special

A consumer following `INSTALL.md`'s recommended migration recipe could not be green: the dead half of
the overlap raised a blocking-shaped `[ERROR]` at every session start, resume, clear and compact, for as
long as the migration lasted, with no way to silence it short of abandoning the recipe. That is gone
without them doing anything — the noise stops on the plugin update that carries this, and the recipe
they were told to follow is the one the check now agrees with.

**Score:** 3

#### Pull Request

A dead roster import that a live sibling already covers no longer errors
