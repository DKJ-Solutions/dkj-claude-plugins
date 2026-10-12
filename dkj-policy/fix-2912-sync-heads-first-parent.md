## fix/2912-sync-heads-first-parent

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

Inbound #2912. The reporter inferred a reachability rule. The measured cause is narrower:
`Get-SyncMergeCommits` matches the subject, and a trunk-into-sync merge (`Merge branch 'main' into
sync/...`) names the sync branch too. Read as a head, its `FirstParent..Sha` is the trunk's work it
brought over, so the feature commits were counted as the sync's. Reproduced in a scratch repo: without
`--first-parent` both merges are heads and the feature path is sync-owned; with it only the real sync
merge is a head and the feature path stays ours.

### CREATE

- [x] `live-preflight` and `prepare-release` read the sync heads with `git log --first-parent`
- [x] `Get-SyncMergeCommits`' docstring makes the flag part of its input contract, with the measurement
- [x] Mirrors resynced (the lib in both plugins, `live-preflight` in the Shopify team)

### TEST

- [x] `live-push-rules.tests.ps1` pins the flag on both drivers, green on its own

### DEPLOY: fix/2912-sync-heads-first-parent

`live-preflight` and `prepare-release` no longer drop our own merged files from the live push list
after a trunk-into-sync merge. A merge of the trunk *into* a `sync/` branch names that branch in its
subject, so it was read as a sync and the trunk's commits it brought over were counted as the sync's.
Their paths were classified `sync-owned` and held back, and the live-push record would have written
them `live`. The sync heads are now read on the trunk's first-parent line only, where just the merge
that brought the sync in appears
([#2912](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2912)).

**Score:** 2

#### What makes this deploy extra special

A store team's push list stops silently losing merged work. Measured in xoxowildhearts, the halved
`theme.css` from #358 would have stayed off live while the changelog said it shipped.

**Score:** 4

#### Pull Request

Sync provenance reads sync heads on the trunk's first-parent line only

