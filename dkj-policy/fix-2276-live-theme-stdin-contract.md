## fix/2276-live-theme-stdin-contract

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

Write the piped-stdin assumption into guard-live-theme.ps1's header beside the fail-towards-CHECKING rule, and assert the wrapper half in hook-stdin-guard.tests.ps1.

#### What #2276 actually asks for

Two deficiencies, named in the issue itself: the piped-stdin assumption is "recorded nowhere durable"
and "asserted by no test". The first is a header edit. The second is reachable for the half this repo
owns -- the `hooks.json` wrapper that does the piping -- and unreachable for the runtime behaviour, which
`hook-stdin-guard.tests.ps1` already names as a gap.

### CREATE

- [x] Sylvester: write the stdin contract into `guard-live-theme.ps1`'s header -- what makes the
      no-handle branch unreachable in production, and what it would cost if the wrapper stopped piping
- [x] Sylvester: point the code-site comment above the `IsInputRedirected` read at that header block
- [x] Tycho: group 3 in `hook-stdin-guard.tests.ps1` -- a wrapper that drains the payload with `$(cat)`
      must pipe it back into the interpreter, counted out of the tree rather than hand-listed

### TEST

- [x] `hook-stdin-guard.tests.ps1` green, and its new group red when the pipe is removed from a fixture
- [x] the lint gate + all suites via `open-pr.ps1`

### DEPLOY: fix/2276-live-theme-stdin-contract

`guard-live-theme.ps1`'s header now states the assumption its no-handle branch rests on: the
`hooks.json` wrapper drains the payload with `$(cat)` and pipes it back into PowerShell, so
`IsInputRedirected` is true on every call the harness makes and the `exit 0` path is unreachable from
any command a session can cause. It also states what breaks if that ever stops -- this guard would
degrade towards ALLOWING, the one direction its own fail-towards-CHECKING rule forbids, on a subject
that cannot be un-published. `hook-stdin-guard.tests.ps1` gains a third group holding the half that is
reachable: every hooks.json command that drains the payload must hand it back, counted out of the tree
rather than hand-listed, with a counter-case. Removing the pipe from either shipped wrapper now turns
the gate red.

The failure it prevents, since it has not happened: a future edit to either PreToolUse wrapper that
drops the `printf | powershell` re-pipe. Nothing would fail -- both guards would go on exiting 0 on an
empty payload, which is their documented behaviour -- and the live-theme guard would be silently
waving through publishes, deletes and live pushes in production instead of only in the hand-run case
the branch was built for.

**Score:** 1

#### What makes this deploy extra special

A Shopify consumer auditing the live-theme guard now meets that assumption in the file itself rather
than reconstructing it from the wrapper. Nothing the guard does changes.

**Score:** 1

#### Pull Request

guard-live-theme records the stdin contract its no-handle branch depends on

