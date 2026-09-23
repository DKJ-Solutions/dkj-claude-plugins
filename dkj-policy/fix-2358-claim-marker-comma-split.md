## fix/2358-claim-marker-comma-split

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

Reason verified against the tree before the repair: nothing split `-Marker`, so `-File` delivered a
comma list as one name to both `Format-ClaimComment` and `Get-ClaimMarkerPattern`.

### CREATE

- [x] `Split-ClaimMarkerNames` in `claim-issue-lib.ps1`; the pattern and the writer use it, and the
      script normalises `$Marker` once after loading the lib
- [x] The pattern also reads a compound marker already written (`claim-tag,xoxo-lane`) when any part is
      a listed name -- the transition, so no consumer has to list the compound spelling
- [x] Plugin mirrors copied; `-Marker` documented in the script help and the skill page

### TEST

- [x] `claim-issue.tests.ps1`: split, first-name write, read of ordinary/predecessor/compound markers,
      no suffix match, and a real `powershell -File` binding probe -- 436 passed, 0 failed

### DEPLOY: fix/2358-claim-marker-comma-split

`claim-issue.ps1 -Marker` now splits a comma list into names. Under the documented
`powershell -File` route a list such as `-Marker claim-tag,xoxo-lane` arrived as one literal string,
was written as a compound marker name and read as one, so a machine passing a predecessor list could not
see ordinary `claim-tag` claims and its own claims were invisible to every other machine. Only the first
name is written now, every name is read, and a compound marker already written before this repair is
still recognised whenever one of its parts is a listed name
([#2358](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2358)).

**Score:** 3

#### What makes this deploy extra special

A consumer sweeping one backlog from several machines with `-Tag` stops seeing claimed issues listed
as free after a plugin update, and the compound markers already on its issues keep holding.

**Score:** 4

#### Pull Request

claim-issue -Marker splits a comma list, so -File callers read every predecessor name

