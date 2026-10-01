## fix/2693-null-plugin-roots-under-pwsh

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

Get-TouchedPlugins/Get-PluginNameForPath survive a null PluginRoots under pwsh 7, so fold-on-merge folds in a consumer without marketplace.json

#### The reason, verified rather than inherited

The report inferred the cause and said so. Measured on this branch with the same call under both
editions: `Get-TouchedPlugins -PluginRoots (Get-RepoPluginRoots ...)` in a repo with no
`marketplace.json` returns nothing under Windows PowerShell 5.1 and throws the reported error under
pwsh 7.4.6. An `[object[]]` parameter bound to `$null` re-wraps as an empty array in 5.1 and as one
`$null` element in pwsh 7. That explains why the consumer's local fold (5.1) succeeded where the
runner (pwsh) failed. Why the merges of the consumer's PRs #17 and #18 folded under the same runner
was not measured.

### CREATE

- [x] `Get-PluginRootSet` in `scripts/lib/plugin-tree-lib.ps1`: every `$PluginRoots` loop in the lib
      (`Get-PluginRootByName`, `Get-PluginNameForPath`, `Get-PluginSubdirs`) drops `$null` before it
      iterates. The plugin mirror is copied byte for byte.

### TEST

- [x] `fold-changelog.tests.ps1` gained six asserts on the call the fold makes. They fail 5 of 6 on the
      old lib under pwsh 7.4.6 (1 of 6 under 5.1) and pass 6 of 6 on the new lib under both. They sit in
      that suite because it is the one CI also runs under pwsh on Linux.

### DEPLOY: fix/2693-null-plugin-roots-under-pwsh

Inside this repo: the plugin-tree lib no longer trusts `@($PluginRoots)` to drop a `$null`. That holds
in Windows PowerShell 5.1 and not in pwsh 7, and every CI-floor runner executes under pwsh while the
suites that reached this path ran under 5.1. A new `Get-PluginRootSet` filters it in the three loops,
and `fold-changelog.tests.ps1` now asserts that call itself, so the Linux pwsh job covers it.

**Score:** 2

#### What makes this deploy extra special

For the maintainer of a consuming repo that declares no plugins: `fold-on-merge` no longer fails on a
merge with `You cannot call a method on a null-valued expression` in `Get-PluginNameForPath`, so the
changelog entry folds on the runner instead of waiting for somebody to fold it locally
([#2693](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2693)).

**Score:** 3

#### Pull Request

The fold no longer crashes under pwsh in a repo with no marketplace

