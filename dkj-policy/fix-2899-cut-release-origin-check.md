## fix/2899-cut-release-origin-check

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

#### Issue

#2899: `cut-release.ps1` never fetched or compared `HEAD` with `origin/main`, so a merge landing during
the gates stranded a local release commit and tag (v5.17.0 cut). A consumer comment adds the second
shape: a stale main before the cut, and a `-NoPush` push line whose two independent pushes published
the tag while main was rejected.

### CREATE

- [x] `Assert-TrunkMatchesOrigin` in `scripts/release/cut-release.ps1`: fetch `origin main`, refuse when
      main is behind or ahead of `origin/main` (naming the commits), run before the gates and again after
      them, before the first write. No `origin` remote skips with a line; a failed fetch refuses;
      `-SkipOriginCheck` is the escape valve.
- [x] The `-NoPush` push line is now one `git push --atomic origin main vX.Y.Z`.
- [x] Mirror `plugins/dkj-policy/scripts/release/cut-release.ps1` kept byte-identical.
- [x] `cut-release` skill page: the new flag, the atomic push line.

### TEST

- [x] `cut-release-drive.tests.ps1` case 12 against a local bare origin: in sync passes and prints the
      atomic line; behind and ahead each refuse, name the commit, write nothing and tag nothing;
      `-SkipOriginCheck` cuts the behind state. 85/85 asserts.
- [x] `cut-release-guardrail.tests.ps1` 128/128; lint gate 0 errors.

### DEPLOY: fix/2899-cut-release-origin-check

`cut-release.ps1` now fetches `origin/main` and refuses unless local `main` is exactly that, naming
the commits it is behind or ahead. It checks twice: before the gates, and again after them, before the
first write, because the gate minutes are when merges land. A refusal there leaves the tree untouched,
where before a merge during the gates left a local release commit and tag that only an owner-gated
`reset --hard` could unpick. `-SkipOriginCheck` is the escape valve, and a repo with no `origin` remote
skips the check on its own and says so.

**Score:** 3

#### What makes this deploy extra special

If you cut releases with `cut-release`, a release can no longer be built on a `main` that is behind
GitHub: the cut stops before it writes anything and tells you to `git merge --ff-only origin/main`. With
`-NoPush` the command it prints is now a single atomic push, so a rejected `main` can no longer publish
the tag on its own.

**Score:** 2

#### Pull Request

cut-release refuses a main that is not origin/main
