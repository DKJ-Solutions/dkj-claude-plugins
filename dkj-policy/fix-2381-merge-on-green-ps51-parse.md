## fix/2381-merge-on-green-ps51-parse

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

Repair [#2381](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2381): under Windows
PowerShell 5.1, `pick-merge-on-green.ps1` read the armed list as one record and evaluated nothing.
Both halves the issue names are fixed: the parse, and the silent skip that hid it. The cause was
re-measured here on 5.1.26100 before anything was touched: `@('[{...}]' | ConvertFrom-Json)` has a
Count of 1 and its element is an `Object[]`, for one element as for many.

### CREATE

- [x] `ConvertFrom-MergeOnGreenListJson` in `merge-on-green-lib.ps1`: take the parse as a value, then enumerate it
- [x] `pick-merge-on-green.ps1` parses through it; a skipped record prints a line; "armed, but no verdict" is its own reason
- [x] plugin mirrors of both files synced byte-identical

### TEST

- [x] `merge-on-green-lib.tests.ps1` feeds real one- and three-element `gh pr list` payloads, plus empty and non-JSON: 68 pass, 0 fail under 5.1
- [x] the first draft returned `,@(...)`, and the new asserts caught it re-wrapping the array in the caller's `@()`. That is the same defect one layer down, so the comma was removed
- [x] live, read-only run of the picker against this repo: `#2345 ... ELIGIBLE` and `picked=true`, where six CI sweeps had reported `0 armed`

### DEPLOY: fix/2381-merge-on-green-ps51-parse

The merge-on-green sweep could never pick an armed pull request under Windows PowerShell 5.1, which
is what its runner uses. `ConvertFrom-Json` wrote the whole `gh pr list` array as one record with no
number, and the sweep skipped that record without saying so. Every run then reported "0 armed pull
request(s), none eligible yet" while PR #2345 sat armed and green. The list is now enumerated
through a tested lib function (`ConvertFrom-MergeOnGreenListJson`). A skipped record prints a line,
and "armed but nothing evaluated" is reported as the contradiction it is, not as a wait
([#2381](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2381)). The script travels in
`dkj-policy` and consumer runners fetch it at `ref: main`, so every adopted consumer's sweep starts
merging on its next run.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

merge-on-green: enumerate the armed list under PowerShell 5.1 and say why a record is skipped

