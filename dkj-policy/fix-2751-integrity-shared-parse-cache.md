## fix/2751-integrity-shared-parse-cache

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

Issue [#2751](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2751). Before building, I measured
whether the parse is the cost, as the issue asked: over 451 `.ps1` files a parse is 1.5-2.1s and a
`FindAll` walk 4.4-6.4s. So the walk is the cost, and 42b was walking for CommandAsts a second time,
which the issue did not name. `mirror-depth` and `shared-script` compare bytes and never parse, so they
are out of scope.

### CREATE

- [x] `Get-PsScriptParse`: one parse per path, keeping the AST, tokens and errors, and one walk that collects CommandAsts and AssignmentStatementAsts together
- [x] `Get-PsScriptCommandAsts`, check 5 (`parse`), 42b (`exec-policy/script`) and `shopify-force` read from it
- [x] Scenario 75 asserts that 42b and shopify-force survive an unparseable file; 75b holds the gate to one parse site

### TEST

- [x] The full gate on the real tree produces the same output as `main`, apart from the lines this branch's own document adds
- [x] The removed work timed directly, three rounds: old passes 13.8-17.1s, new pass 4.4-5.4s
- [x] `check-plugin-integrity-scripts` (61), `-invocations` (39) and `-script-set` (28) are green

### DEPLOY: fix/2751-integrity-shared-parse-cache

`check-plugin-integrity.ps1` now parses each `.ps1` once and walks it once per run, and every check that
reads a script shares that pass. Before this, a run paid four parses and three full walks per file:
check 5 parsed again for the errors, `exec-policy/script` for the tokens plus a second CommandAst walk,
and `shopify-force` for the assignments. Over this repo's 451 scripts that work came to 13.8-17.1s,
and it now takes 4.4-5.4s. A new assert keeps the gate down to a single parse site, because the sharing
#1358 introduced eroded with nothing to hold it
([#2751](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2751)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

check-plugin-integrity: one parse per .ps1, shared across the checks

