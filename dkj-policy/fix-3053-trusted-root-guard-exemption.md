## fix/3053-trusted-root-guard-exemption

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

Exempt the trusted tree that `-TrustedRoot` names from the source-repo guard. Comparing by repository
identity would also wave through the plugin cache, which is a clone of the same GitHub repo.

### CREATE

- [x] `source-repo-guard-lib.ps1`: condition 1c exempts a script inside `DKJ_GUARD_TRUSTED_ROOT`
- [x] `ship-pr.ps1` (`-TrustedRoot`) and `open-pr.ps1` (`-SeamRoot`) set it before their own guard; children inherit it
- [x] the plugin mirrors copied byte-identical

### TEST

- [x] `source-repo-guard.tests.ps1`: the two-checkout layout refused undeclared, allowed declared, the released copy still refused, a missing declared tree exempts nothing, and both entry points declare before their guard (64 asserts green)

### DEPLOY: fix/3053-trusted-root-guard-exemption

`merge-on-green` can ship a PR in this repo again
([#3053](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3053)). The runner runs
`ship-pr.ps1` from a `trusted-main` checkout of the trunk while `CLAUDE_PROJECT_DIR` names `pr-branch`,
and the source-repo guard refused that as a released copy, because the two are separate clones and
`pr-branch` carries both the marketplace and its own copy. So PR #3051 sat green and armed through
every sweep. `-TrustedRoot` (and `open-pr`'s `-SeamRoot`) now declares that tree in
`DKJ_GUARD_TRUSTED_ROOT`, the guard exempts a script inside it, and the fold and
`verify-resolved-issues` children inherit the declaration. The plugin cache is still refused.

**Score:** 2

#### What makes this deploy extra special

A consumer has no marketplace, so the guard never refused it and nothing changes for it.

**Score:** N/A

#### Pull Request

merge-on-green can ship in the source repo: the own-copy guard exempts the declared trusted tree

