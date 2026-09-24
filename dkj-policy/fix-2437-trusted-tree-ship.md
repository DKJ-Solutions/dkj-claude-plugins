## fix/2437-trusted-tree-ship

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

The sweep runs ship-pr from a main checkout rather than from the branch, with the token kept out of the branch tree, so a PR touching scripts/ or .github/ can still be finished by the sweep.

Sebastian #23's design review (posted on issue #2437) set four conditions before anything was built:
(a) repoint the two repo-owned seam dot-sources (`scripts/repo-config.ps1`, `scripts/lib/branch-info.ps1`)
at a trusted tree; (b) add a lint/test guard so no third such dot-source can reappear silently; (c) make
`-SkipLint -SkipTests` structurally guaranteed for trusted-tree mode, not merely present in the yml; (d)
keep `FOLD_PUSH_TOKEN` out of the PR-branch tree, with the smallest sound restructure (two checkouts, or
two jobs).

**The design chosen, and where it departs from Sebastian's own wording (named, not hidden):**

- `ship-pr.ps1` gets a new `-TrustedRoot <path>` parameter, forwarded to `open-pr.ps1` as `-SeamRoot`.
  Both scripts now dot-source the two repo-owned seams from a resolved `$seamRoot` (that path when given,
  `$repoRoot` otherwise -- every existing call site unchanged). Condition (a).
- `scripts/tests/trusted-tree-seam.tests.ps1` (new) discovers ship-pr.ps1's and open-pr.ps1's whole
  dot-source closure by WALKING the `$PSScriptRoot` graph rather than hand-listing it, and asserts zero
  files in that closure still dot-source via `$repoRoot`/`$RepoRoot` -- only via `$seamRoot`. A third such
  line added later, anywhere in the closure, fails this suite without anyone having to remember to extend
  an allowlist. Condition (b).
- Both scripts force `$SkipLint = $true; $SkipTests = $true` (with a loud warning) the moment
  `-TrustedRoot`/`-SeamRoot` is set, before either gate call site is reachable -- not merely documented as
  "always pass both together with this." Condition (c).
- `.github/workflows/merge-on-green.yml` now checks out `main` into `trusted-main` and, once a PR is
  picked, the PR's own head into `pr-branch` -- two separate `.git` directories, both
  `persist-credentials: false`, neither carrying `FOLD_PUSH_TOKEN` on disk. `ship-pr.ps1` runs from
  `trusted-main` with `-TrustedRoot`; `CLAUDE_PROJECT_DIR` points `$repoRoot` at `pr-branch`. The fold
  step, since `$repoRoot` (the branch tree) can push nothing, uses `-TrustedRoot` directly as the fold
  tree instead of `git worktree add`-ing a new one off a repo that could never push it
  (`Remove-ShipFoldWorktree -NotOwned` keeps this run from ever deleting a tree it did not create). The
  actual push authority is supplied as an EPHEMERAL, environment-only git credential (git's documented
  `GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n`/`GIT_CONFIG_COUNT` triplet, built from `FOLD_PUSH_TOKEN`),
  applied uniformly to both trees for the one step that needs it, rather than a STATIC, on-disk credential
  via `actions/checkout`'s own `token:`/`persist-credentials: true`. **This is the one deliberate
  departure from Sebastian's literal condition-(d) wording** ("token-bearing checkout only for the
  trusted main tree"): his design still leaves the raw token sitting in `trusted-main`'s `.git/config` on
  disk for the step's duration (his own residual-exposure #3 in the design review), and one credential
  applied the same way to both trees removes that residue everywhere rather than only in the tree his
  wording named. Named here and in the workflow's own comment rather than silently substituted, because
  it is a live judgement call this branch could not get his sign-off on before building, not something
  to present as if it were his own prescription.
- `Get-MergeOnGreenExecutedPathHit` (`scripts/lib/merge-on-green-lib.ps1`) shrinks from a four-prefix
  regex (`scripts/`, `.github/`, `.workflow-scripts/`, `plugins/**/scripts/`) to an exact two-file
  enumeration -- exactly the two seams `-TrustedRoot`/`-SeamRoot` cannot repoint, per Sebastian's own
  verdict ("the rule shrinks to the seam files, not to none"). Every other path that used to refuse a
  sweep is now eligible; `merge-on-green-lib.tests.ps1` and `stranded-sweep-gate.tests.ps1` assert the
  shrink positively, not only what still refuses.
- The consumer-scaffolded template (`adopt-ci-floor.ps1`'s fourth runner) is verified as carrying a
  DIFFERENT, narrower exposure (its own `ship-pr.ps1` already runs from a separate, pinned, token-free
  plugin checkout since #2329/#2333 -- only a consumer's own two seams are still read from the
  single, token-bearing workspace) and is deliberately left unchanged here; filed separately as
  [#2449](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2449) because it touches the
  scaffolder template rather than this repo's own workflow, and has to reconcile with #2333's SHA-pin
  machinery rather than starting clean.
- `check-stranded-sweep.ps1` (issue #2438) needed NO code change -- it only calls
  `Get-MergeOnGreenStrandedVerdict`, which reuses the shrunk predicate automatically. Its own test
  fixtures (`scripts/tests/stranded-sweep-gate.tests.ps1`) DID need updating: they used a generic
  `scripts/x.ps1` fixture path to exercise the "stranded" branch, which the shrink no longer flags, so
  both occurrences were repointed at `scripts/repo-config.ps1`.
- Docs updated: `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md`'s "fourth runner" section now names
  the consumer template's own residual exposure and points at #2449; this repo's own
  `.claude/specialists/lenses/specialist-05-15-lens.md` gained a block under the existing merge-on-green
  entry describing the design, the departure from Sebastian's wording, and what remains unproven without
  a live run.

**What this branch could NOT prove, and needs Tycho's / a live run's eyes:**

- The ephemeral `GIT_CONFIG_KEY_n` credential mechanism (git 2.31+, documented, but not exercised by any
  suite here, since it needs a real two-directory git push over HTTPS) is unverified beyond reading git's
  own documentation. This workflow cannot be proved on its own pull request (`workflow_run` always runs
  the DEFAULT branch's copy of the file), so its first live proof is this workflow's first sweep after
  this branch merges.
- Whether `git push` against an already-up-to-date branch genuinely requires write authentication on
  GitHub's HTTPS remote (assumed here, based on general knowledge of `git-receive-pack` requiring auth
  regardless of whether a ref moves) -- not measured against GitHub directly.
- Whether sending the SAME `Authorization` header via both `actions/checkout`'s persisted config AND the
  ephemeral env-var mechanism would ever collide -- moot under the design actually built (persist-credentials:
  false on both checkouts, so only the env-var mechanism ever supplies the header), but worth a note in
  case a future edit re-adds a persisted credential to `trusted-main` without noticing the interaction.

### CREATE

- [x] Add `-TrustedRoot` to `ship-pr.ps1` (seam redirection, forced skip, fold-tree short-circuit,
      `Remove-ShipFoldWorktree -NotOwned`) and forward it to `open-pr.ps1` as `-SeamRoot`.
- [x] Add `-SeamRoot` to `open-pr.ps1` (seam redirection, forced skip).
- [x] Shrink `Get-MergeOnGreenExecutedPathHit` to the two-file enumeration; update its callers' comments.
- [x] Add `scripts/tests/trusted-tree-seam.tests.ps1` (condition (b), the closure-walking guard).
- [x] Update `scripts/tests/merge-on-green-lib.tests.ps1` and `scripts/tests/stranded-sweep-gate.tests.ps1`
      for the shrink (positive + fixture updates).
- [x] Restructure `.github/workflows/merge-on-green.yml` into two checkouts + `-TrustedRoot` + the
      ephemeral push credential; keep every existing guard (branch via `env:`, SHA verification,
      cross-repo refusal via the picker, concurrency).
- [x] Rebuild the plugin mirrors (`scripts/sync/build-shared-scripts.ps1`) for `ship-pr.ps1`,
      `open-pr.ps1`, `merge-on-green-lib.ps1`.
- [x] Verify the consumer template (`adopt-ci-floor.ps1`) separately; file #2449 rather than editing it.
- [x] Update `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md` and this repo's own
      `specialist-05-15-lens.md`.

### TEST

- [x] `scripts/tests/trusted-tree-seam.tests.ps1` (new) -- run standalone, 19/19 pass.
- [x] `scripts/tests/merge-on-green-lib.tests.ps1` -- updated + run standalone, 146/146 pass.
- [x] `scripts/tests/stranded-sweep-gate.tests.ps1` -- fixtures updated + run standalone, 46/46 pass.
- [x] Full gate (`open-pr.ps1 -GatesOnly`): lint + all suites green.
- [ ] TODO (Tycho #18): coverage this branch's own suite could not reach --
      (1) a live-run assertion or a tighter static check that the "Ship it" step's `run:` body actually
      builds the ephemeral `GIT_CONFIG_KEY_n`/`VALUE_n`/`COUNT` triplet correctly (this branch only
      confirmed the YAML parses and the PowerShell reads sensibly, not that git honours the triplet on a
      real two-directory push); (2) a fixture-tree test of `ship-pr.ps1 -TrustedRoot` end to end --
      seam files loaded from the trusted root, fold landing there without a worktree, `-NotOwned`
      actually preventing removal -- the way `worktree-lane.tests.ps1` or similar already fixture-tests
      other ship-pr arms, since `trusted-tree-seam.tests.ps1` is a STATIC/textual guard, not a behavioural
      one; (3) whether `Get-MergeOnGreenExecutedPathHit`'s new exact-match (`-ccontains`) is itself worth
      a dedicated case for a path that differs from a seam file only by case or by a trailing/leading
      slash variant PowerShell's own path handling might normalise differently than expected.

### DEPLOY: fix/2437-trusted-tree-ship

This closes issue #2437 (following Sebastian #23's design review) and files #2449 for the consumer
template's own, narrower version of the same class of exposure. `ship-pr.ps1` gained `-TrustedRoot`
(forwarded to `open-pr.ps1` as `-SeamRoot`), `.github/workflows/merge-on-green.yml` now runs from two
separate, token-isolated checkouts, `Get-MergeOnGreenExecutedPathHit` shrank to an enumerated two-file
list, and a new closure-walking test (`trusted-tree-seam.tests.ps1`) guards against a third
`$repoRoot`-rooted dot-source reappearing silently in ship-pr's own closure.

Every specialist here maintains this repo's own CI/release tooling and reads this repo's own commits, so
tier 0 is scored against how much clearer/safer/costlier the mechanism became for the next person (or
session) touching `ship-pr.ps1`, `open-pr.ps1`, or this workflow.

This closes a measured, session-facing cost (#2436: ~80% of merged PRs here could never be finished by
the sweep) with a design that was reviewed BEFORE it was built rather than patched after a live incident,
and it leaves one explicit, load-bearing judgement call (the ephemeral-credential departure from
Sebastian's literal wording) named in three places (the yml, the lens, this document) rather than buried
in a diff. The cost is real complexity: two checkouts, a new parameter surface on two already-large
scripts, and one mechanism (the `GIT_CONFIG_KEY_n` credential) that is textbook-sound but has not run
live in this repo before.

**Score:** 4

#### What makes this deploy extra special

This repo's tier-2 audience is a subscriber of the workflow -- a consumer repo running `dkj-policy`
adopts `ship-pr.ps1`/`open-pr.ps1` on their next plugin update, and the new `-TrustedRoot`/`-SeamRoot`
parameters are additive (empty default, every existing call site unchanged), so nothing in a consumer's
own workflow breaks or behaves differently until THEY choose to wire up trusted-tree mode -- which only
`adopt-ci-floor.ps1`'s scaffolded runner would ever do, and it does not yet (see #2449). So today's
consumers see a safer `ship-pr.ps1`/`open-pr.ps1` with no action required, and the specific security
improvement this branch makes (closing #2338 for THIS repo's own sweep) does not reach a consumer's own
`merge-on-green.yml` until #2449 is built and adopted separately.

**Score:** 2

#### Pull Request

merge-on-green ships from a trusted trunk tree, so the executed-path exclusion shrinks to the seam files

