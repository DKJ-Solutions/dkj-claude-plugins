## fix/2621-fold-refuses-linked-reads

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

#2621, verified in the tree: `fold-changelog-entry.ps1` reads the branch document and the changelog off
the filesystem (`ReadAllText`/`ReadAllLines`/`Get-Content`, seven sites). fold-on-merge runs on
`ubuntu-latest` since #2488, where a committed mode-120000 entry checks out as a real symlink, so those
reads would follow it inside a process holding a push token. Repair: the issue's first option, taken at
the one script that reads. Every read target is judged with `Get-WriteTargetReparsePoint`, which reads
the parent directory's listing and walks every directory up to the root. A link anywhere on the path
stops the run before anything is read. merge-on-green reads no branch file, so it needs no change.

### CREATE

- [x] `fold-changelog-entry.ps1` (and its dkj-policy mirror): `Assert-FoldReadTarget` before each read of a branch document, entry file or changelog, before `repo-config.ps1` is dot-sourced and the manifest is read, and over every per-branch document BEFORE `Resolve-BranchFilePath` reads them (Sebastian's review); a link refuses with exit 1 and the trunk untouched
- [x] the fold fixture carries `write-target-lib.ps1`

### TEST

- [x] `fold-changelog.tests.ps1`: a branch-document folder that is a junction (a directory symlink off Windows) refuses the fold, names the link, and leaves the changelog and the linked document alone; a per-branch document that is itself a file symlink refuses too (needs a privilege Windows hosts may lack, so it is measured on the Linux leg, which runs this suite) -- 274 pass standalone

### DEPLOY: fix/2621-fold-refuses-linked-reads

The changelog fold now refuses to read a branch document, entry file or changelog that it would reach
through a symlink or junction, and stops before reading anything. On a Linux runner a committed symlink
checks out as a real one, and the fold pushes what it read onto the trunk, so a branch document linked
to a file elsewhere on the runner would have been folded into the public changelog (#2621).

**Score:** 1

#### What makes this deploy extra special

A repo whose CI fold runs on Linux is protected against a pull request that commits its branch document
as a symlink. A fold that meets one fails, and the trunk is left exactly as the merge left it. The failure
it prevents has not happened: a linked read pushing runner files into the trunk's changelog.

**Score:** 1

#### Pull Request

fold-changelog-entry refuses a branch document or changelog reached through a symlink
