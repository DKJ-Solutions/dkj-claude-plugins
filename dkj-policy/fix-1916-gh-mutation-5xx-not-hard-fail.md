## fix/1916-gh-mutation-5xx-not-hard-fail

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

Inbound #1916 (BWJ-Development/smartwatchbanden, dkj-policy 5.1.0): `open-pr.ps1`'s `gh pr create` and
`ship-pr.ps1`'s `gh pr merge` both turn every non-zero exit into a hard failure, even when the
underlying request was a 5xx/transport error that reached GitHub and landed anyway. `claim-issue`
already carries the doctrine for this exact shape (a timed-out WRITE is not simply a failure -- read
the state back before believing it) and neither mutation applies it to itself.

Repair: a new pure classifier `Test-GhMutationTransient` (pr-issues-lib.ps1, shared by both scripts)
tells a 5xx/transport failure apart from a real 4xx refusal. On a transient failure, both scripts read
the state back before reporting anything:
- `open-pr.ps1`'s create re-checks for an open PR on the branch; if found, it reports success instead
  of a failure that already happened.
- `ship-pr.ps1`'s merge reuses the SAME read-back loop issue #1325 already runs after an exit-0 merge
  (three attempts, propagation-only). Where that reads MERGED, the run carries on to the fold exactly
  as an ordinary merge. Where it cannot confirm MERGED, the run says "this run does not know" and
  exits 1 instead of silently proceeding OR silently failing -- the #1325 exemption for an unreadable
  state (harmless there because gh's own exit 0 is evidence) does not apply here, since gh's own call
  already failed and there is no such evidence.

A 4xx stays a hard failure in both scripts, unchanged.

### CREATE

- [x] `Test-GhMutationTransient` added to `scripts/lib/pr-issues-lib.ps1` (pure, ASCII, ported doctrine
      from `claim-issue`'s timed-out-write handling)
- [x] `open-pr.ps1`: on a failed `gh pr create`, classify before reporting -- transient -> re-check for
      the PR, hard failure otherwise unchanged
- [x] `ship-pr.ps1`: on a failed `gh pr merge`, classify before reporting -- transient -> fall through
      into the existing #1325 read-back loop with a recovery flag; both the queue and no-queue branches
      read that flag so an inconclusive read-back after a transient failure reports "does not know"
      rather than silently folding or silently refusing with the wrong reason
- [x] Mirrors regenerated (`scripts/sync/build-shared-scripts.ps1`) -- `plugins/dkj-policy/scripts/{lib/pr-issues-lib.ps1,release/open-pr.ps1,release/ship-pr.ps1}`

### TEST

- [x] Parser check on all three edited files (`[System.Management.Automation.Language.Parser]::ParseFile`)
      -- caught and fixed a `$pr:`-in-string scope-qualifier pitfall this same repo already documents
      elsewhere in open-pr.ps1
- [x] ASCII check on all three edited files (script-layer rule, `.claude/rules/language-layers.md`)
- [x] Unit tests added to `scripts/tests/pr-issues.tests.ps1` for `Test-GhMutationTransient`: the three
      answers measured in #1916 verbatim, every recognised 5xx/transport wording, several 4xx/refusal
      shapes that must stay hard failures, the "bare 5xx-shaped number is not enough" guard, and the
      null/empty boundary cases -- plus call-site asserts that both scripts actually invoke it in the
      right place
- [x] `scripts/tests/pr-issues.tests.ps1` run standalone: all 929 asserts pass
- [x] `scripts/tests/shared-scripts.tests.ps1` run standalone (mirror-drift proof): all 782 asserts pass
- [x] `scripts/lint/check-plugin-integrity.ps1` run standalone: 0 errors
- [x] Full suite (`scripts/tests/*.tests.ps1`, all 107 files) run standalone before the PR gate runs it
      again

### DEPLOY: fix/1916-gh-mutation-5xx-not-hard-fail

Fixes a correctness gap in the shared `open-pr`/`ship-pr` scripts every consumer of `dkj-policy` runs:
a 5xx or transport failure on the PR-create or PR-merge call was reported as a hard failure even where
it had actually landed, which for the merge case meant the fold never ran and the branch's changelog
entry was left stranded on the trunk beside an already-merged PR. Operators reading a false "failed"
either re-ran into a duplicate-shaped situation or gave up on work that had already shipped.

**Score:** 3 -- a clear improvement, noticed the moment an operator hits exactly this GitHub API hiccup;
before this fix the reported failure was actively misleading about work that had already succeeded.

#### What makes this deploy extra special

Nothing operationally special -- both scripts keep every existing behavior for the ordinary path and
for a real 4xx refusal. The only reader-visible change is that a 5xx/transport failure is no longer
silently treated as a plain failure: it triggers one extra read before either continuing (state
confirms it landed) or reporting the true "this run does not know" instead of a confident wrong answer.

**Score:** 1 -- prevents a failure that has already happened at least once in the field (inbound #1916)
rather than one that has not happened yet.

#### Pull Request

gh mutation 5xx niet direct als harde mislukking behandelen

Resolves #1916.

