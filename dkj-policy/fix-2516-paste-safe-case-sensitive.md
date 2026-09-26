## fix/2516-paste-safe-case-sensitive

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

Switch `Test-RefPasteSafe` and `Test-PathPasteSafe` in `scripts/lib/ref-print-lib.ps1` from `-match` to
`-cmatch`, mirror the lib into both plugin copies, and pin the Kelvin sign in `ref-print-lib.tests.ps1`.
The same defect at four other allowlist sites is out of scope and filed as #2520.

### CREATE

- [x] Both guards match case-sensitively; a comment above the patterns says why (#2516)
- [x] `ref-print-lib.ps1` copied byte-identical into the `dkj-policy` and `dkj-subagents-shopify` mirrors
- [x] Kelvin-sign asserts on both axes, plus upper-case ASCII still admitted, in `ref-print-lib.tests.ps1`

### TEST

- [x] `ref-print-lib.tests.ps1`: 478 pass, 0 fail
- [x] Reproduced first: `'assets/' + [char]0x212A + '.css'` passed `-match` and fails `-cmatch`; git accepts a branch name carrying that character, so it is reachable through a ref

### DEPLOY: fix/2516-paste-safe-case-sensitive

The two shared "safe to paste" guards no longer let a look-alike letter through
([#2516](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2516)). `Test-RefPasteSafe` and
`Test-PathPasteSafe` matched their ASCII allowlists case-insensitively. Under case folding the Kelvin
sign (U+212A) matches `k`, so a branch name or path carrying it was judged safe to print into a command
line. Git accepts that character in a branch name. Both guards now match case-sensitively, like
`live-preflight`'s newer check already did. Every value that passed before still passes.

**Score:** 1

#### What makes this deploy extra special

N/A -- an internal guard in the workflow scripts; no subscriber of a service runs anything new.

**Score:** N/A

#### Pull Request

The paste-safe guards match case-sensitively, so the Kelvin sign is refused
