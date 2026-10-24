## feat/3392-declared-scope-drops-walker

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Issue #3392, decided by the owner on October 24, 2026: a declared `# gate-selection: walks <roots>`
is authoritative for dropping a walker in CI's asset-only selection, Open or text-matched alike, on
condition of a scope guard that checks each declaration against every root its walks reach, `Copy-Item`
roots included.

### CREATE

- [x] `ci-suite-selection-lib.ps1`: a walker outside the selection's Always set (it declares its scope
  and reaches no undeclared walk) is kept only when it is in Scoped; undeclared walkers are judged as before.
- [x] `gate-lib.ps1` (and its mirror): `Get-SuiteReferenceSet -SuiteDirectory` records `WalkSamples` per
  live walk -- the root resolved through Join-Path, Split-Path, Resolve-Path, `[IO.Path]::Combine`,
  `"$var\x"`, a foreach or ForEach-Object over a constant list, and the variables those are assigned to,
  plus each typed filter, or any type for an open walk. `Get-UncoveredWalkSample` replaces the
  filter-only `Test-WalkScopeCovers`, and `WalkFilters` goes with it.
- [x] Victor's review: `+=` and Set-Variable writes make a variable unresolved, a foreach over live
  paths is a live walk through its loop variable, `Copy-Item -r` is a walk, a git `:!` or `-` argument is
  no filter, and samples are computed only when `-SuiteDirectory` is given (the selection never reads
  them, so its parse cost is unchanged). The shapes the walk reading still misses are #3397.
- [x] `affected-suites.tests.ps1` 3c holds every declared suite's samples against its scope;
  `ci-suite-selection-lib.tests.ps1` asserts that a declared walker is dropped, open or text-matched.

### TEST

- [x] `affected-suites` (182 pass) and `ci-suite-selection-lib` (44 pass), standalone. All 38 declared
  suites in the tree are covered, roots included; before the resolver followed constant lists and
  Split-Path, six read as unresolved, and none turned out to be a real hole.
- [x] The PR #3391 change (`brandbook/src/showcase/showcase.css`) now selects 2 of 168 suites instead of 7.

### DEPLOY: feat/3392-declared-scope-drops-walker

On CI, a pull request that changes only stylesheets, images or fonts no longer runs a suite whose
declared `# gate-selection: walks` scope leaves the change out, even when its text names the extension or
its walk can return any type ([#3392](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3392)).
The one-line CSS comment of PR #3391 now selects 2 of 168 suites instead of 7, so the three ~70-80s
suites that set shard 1's critical path no longer run for it. The trust rests on a stricter scope guard
in `affected-suites.tests.ps1`: every declaration is now held against the roots of the walks it can see,
`Copy-Item` sources included, and not only their literal filters. A walk added outside its suite's scope
fails there first.

**Score:** 2

#### What makes this deploy extra special

N/A -- the CI selection and its guard run in this repo only; a consumer's local gate selects as before.

**Score:** N/A

#### Pull Request

CI asset-only selection trusts a declared walk scope to drop a walker

