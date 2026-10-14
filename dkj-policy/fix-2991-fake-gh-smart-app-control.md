## fix/2991-fake-gh-smart-app-control

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

#2991: `guard-stale-paste-block.tests.ps1` fails intermittently with 19 failures. Verify the reason
before repairing: the issue names a timeout or a fixture race as possible causes, and neither one is verified.

### CREATE

- [x] Reproduce: 2 of 5 standalone runs failed, each with exactly the 19 asserts that depend on the
  repo resolving, so a failing run fails every case and is not a race between cases.
- [x] Find the cause: `Invoke-AsanaGhBounded`'s `Process.Start` throws "blocked by an application
  control policy" (Smart App Control, `VerifiedAndReputablePolicyState = 1`). This affects about one fresh
  compile in four, and a refused build stays refused, measured over six builds of three starts each.
- [x] Repair the fixture: start the compiled fake once, and rebuild it when it is refused (up to six
  builds). The hook is unchanged, because failing open on a `gh` that will not start is its documented behaviour.

### TEST

- [x] 8 of 8 standalone runs green after the repair. Run 6 needed a rebuild, which shows the retry at work.

### DEPLOY: fix/2991-fake-gh-smart-app-control

`guard-stale-paste-block.tests.ps1` no longer fails at random on a Windows machine running Smart App
Control. The suite compiles a fake `gh.exe`, and Smart App Control refused about one build in four, so the
hook's fail-open path turned every case red with "could not resolve which repo". The suite now starts
the fake once and rebuilds it when it is refused
([#2991](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2991)).

**Score:** 2

#### What makes this deploy extra special

N/A. The suite is not shipped, and no consumer's behaviour changes.

**Score:** N/A

#### Pull Request

Recompile the fake gh.exe when Smart App Control blocks it

