## fix/3212-sync-main-short-mirror-path

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

Inbound #3212, verified in the tree: `sync-main.ps1` cut `$mirror.Length` characters off each file's
`FullName`, and `FullName` is the walk's own spelling (long form, `..` resolved), not the argument's.
Reproduced here with a `..` segment: `sections/sub/a.liquid` came out as `ions/sub/a.liquid`.

### CREATE

- [x] `sync-main.ps1` (and its shopify-plugin mirror): the relative path comes from
  `Get-ChildItem -Name`, relative to the directory walked, so no spelling of the root reaches the key.

### TEST

- [x] `sync-main.tests.ps1`: the quiet run again with the mirror spelled `<mirror>\sections\..`, which
  must still read as no drift. 175/175 green locally.

### DEPLOY: fix/3212-sync-main-short-mirror-path

`sync-main` now reads every live file at its own path whichever way `-MirrorPath` is spelled. A mirror given
in 8.3 short form (as `%TEMP%` hands out on some machines) or with a `..` segment made every live file read
as content this repo had never held, under a mangled path such as `t/old/assets/...`, and every trunk file
as missing on live. Measured in a dry run (1,809 differing paths where the long form gave 37); a real run
with the same argument would have committed the whole mirror under those paths as third-party drift. The
default mirror, which the script creates itself, was not affected.

**Score:** 2

#### What makes this deploy extra special

A Shopify consumer that passes `-MirrorPath` gets a correct comparison where it got a wrong one; one who
never passes it notices nothing.

**Score:** 2

#### Pull Request

sync-main: a short-form -MirrorPath mis-cuts every relative path

