## fix/2481-fixture-git-transport-retry

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

#2481 asked whether to retry the failure or lower the lane count. The answer here is a retry: the
failure is one local push in 144 suites, and a lower lane count would slow every run on every machine
to avoid it.

The second suite #2481 named, `session-cache-lib.tests.ps1`, has no captured cause and nothing
pointing at git transport, so it is split out as #2500 rather than claimed as fixed here.

### CREATE

- [x] `fixture-git-lib.ps1`: `Test-FixtureGitTransientFailure` (a push or fetch whose output shows the
      transport breaking), `Invoke-FixtureGitNative` (one retry, printed and counted), retries named in
      `Write-FixtureGitSummary`
- [x] The seven suite-local git helpers with the plain `$out = & git ...; Assert-FixtureGitOk` body call
      it instead (`prune-merged`, `backing-gate`, `machine-local-gate`, `fetch-attempt`, `gate-lib`,
      `remote-ahead-lib`, `sync-main`)
- [~] `connector-sessioncheck` and `plugin-versions`: dropped -- their helpers return git's output as a
      value, so they are a different shape and are not the suite #2481 measured

### TEST

- [x] `fixture-git-lib.tests.ps1` groups 7 and 8: which failures earn a retry, and the retry itself run
      against a shadowing `git` function -- once, counted apart from failures, never for a commit

### DEPLOY: fix/2481-fixture-git-transport-retry

The test gate retries a fixture `git push` or `git fetch` once when its transport breaks mid-transfer
(`unexpected sideband packet`, a remote that hung up, early EOF), instead of failing a suite whose
asserts all passed. The retry is printed as `[FIXTURE GIT RETRY]` and counted in the suite's fixture
summary, separately from failures. A commit, a clone, or a push that git refused is never retried, and a
second break is judged as a failure exactly as before
([#2481](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2481)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the test fixtures live in this repo only and ship to no consumer.

**Score:** N/A

#### Pull Request

A fixture git push that breaks in transport under the parallel gate is retried once, instead of failing the suite

