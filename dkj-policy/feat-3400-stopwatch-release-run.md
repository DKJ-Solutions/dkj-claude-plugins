## feat/3400-stopwatch-release-run

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

Resolves [#3400](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3400): the owner wants to time
every release cut with the Stopwatch, to see whether it gets faster, and chose the stop rule in this session.

### CREATE

- [x] `Invoke-StopwatchHookEvent -Commits`: a Stop needs a commit made during the run, and a `release…` label
  needs a `release: vX.Y.Z release notes` commit made during the run
- [x] `ConvertFrom-StopwatchCommitLog` parses `git log --format='%ct %s'`; the Stop hook passes the commits in
  `StartHead..HEAD`, and `$null` when git refuses, which keeps the plain HEAD test
- [x] the lib's header and the function's docstring describe the new rule

### TEST

- [x] `stopwatch.tests.ps1`: 11 new asserts (the parser, a fast-forward of older commits, the same-second
  start, the release commit, the notes commit, older notes, the label test, the `$null` fallback); 159 passed
- [x] replayed against the v5.30.0 cut's real commits: the run keeps going after the fast-forward
  (`978d1c901..b162817d0`) and after the release commit (`..3ca292dd5`), and stops on the notes commit
  (`..0af12f457`)

### DEPLOY: feat/3400-stopwatch-release-run

A Stopwatch run now stops only on a commit made during it, so a fast-forward that brought in others' older
commits no longer ends it. A run whose label begins with `release` (`stopwatch: Release cut`) stops only on the
`release: vX.Y.Z release notes` commit that `cut-release` step 4 prescribes. A release cut had moved HEAD at the
fast-forward and again at the release commit, minutes before it was done
([#3400](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3400)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev-server page and its hooks; no plugin ships it.

**Score:** N/A

#### Pull Request

A Stopwatch release-cut run stops when the release is done

