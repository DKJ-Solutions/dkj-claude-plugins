## fix/2283-ship-pr-refusal-signal

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

#### The reported reason does not hold, and the repair changed with it

[#2283](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2283) reports that `ship-pr` exits 0
when `Wait-CheckRegistration` refuses, and proposes `exit 1` on that path. The symptom is real and was
measured on PR #2282. The **reason** is not: `$ErrorActionPreference = 'Stop'` sits at the top of the
script, so every `Write-Error` in it is a **terminating** error, the host exits 1 by itself, and the
`exit 1` written beneath each refusal is already dead code. Building the proposed repair would have added
a second dead line and closed the issue with a citation.

What actually destroys the signal is the **pipe**. Measured here, September 22, 2026, on this script's own
trunk refusal: run as `powershell -File scripts/release/ship-pr.ps1` it exits **1**; run as
`powershell -File scripts/release/ship-pr.ps1 2>&1 | tail -40` it exits **0**, because a pipeline reports
the status of its last element.

And the pipe is not somebody's slip. **Every** recorded invocation of `ship-pr` and `open-pr` in this
machine's session transcripts goes through one (`| tail -n`, `| Select-Object -Last n`), because the output
is long -- 82 piped invocations for `open-pr` alone. So the exit code is a channel this workflow's own
reading habit throws away every time, and telling sessions to stop piping is a rule enforced by memory,
which is the class this tree keeps replacing with a mechanism.

#### So the verdict moves in-band, and the scope is the five chain enders

`closeout-lib.ps1` already names the five scripts whose ending IS a close-out (`Get-ChainEndingScripts`,
#2060), and each of them prints the close-out receipt when it **finishes** (#1884). This branch gives each
the other half: one unmistakable `[REFUSED]` line when it **refuses**. Whatever the caller reads -- piped,
backgrounded, or whole -- the last line says which of the two happened.

`ship-pr` gets a two-state verdict, because one sentence there would have been a lie on one side: its
refusals live on **both** sides of the merge (step 4 refuses when `gh pr merge` returned 0 and the PR does
not read MERGED; step 5 can fail with the merge already landed, which is #1270's trapped entry and the
opposite of "nothing happened").

#### What is deliberately NOT covered

A trap fires on a **terminating error**, so it covers every `Write-Error` refusal -- all 39 in `ship-pr`,
all 27 in `open-pr`, all 29 in `cut-release`. It does not cover a refusal that prints with `Write-Host` and
calls `exit 1` itself; in this tree that is `Resolve-RepoRootOrFail` (`check-report-lib.ps1`), whose output
already opens with `REFUSED:` in red and ends with the remedy, so it is legible on its own and is left
alone.

### CREATE

- [x] `scripts/release/ship-pr.ps1` -- script-scope refusal trap above the dot-sources (so the source-repo
      guard's own refusal reaches it), with the two-state verdict and `$shipMergeLanded` set at the one
      line that reports the merge.
- [x] `scripts/release/open-pr.ps1`, `fold-changelog-entry.ps1`, `cut-release.ps1`,
      `scripts/task/park-branch.ps1` -- the same trap, with the generic consequence sentence.
- [x] `plugins/dkj-policy/skills/ship-pr/SKILL.md` and `open-pr/SKILL.md` -- the pipe hazard, the
      measurement, and what to read instead.
- [x] Plugin mirrors rebuilt (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/closeout-lib.tests.ps1` -- the refusal verdict asserted across the same five, the set
      pinned so a sixth script cannot claim an ending it does not have, and `ship-pr`'s merge-landed flag
      pinned to exactly one write site.
- [x] Verified live on the real script: `ship-pr` from the trunk prints the `[REFUSED]` block as the last
      three lines under `| tail -6`, and exits 1 unpiped.
- [x] Parse-checked all five edited scripts.

### DEPLOY: fix/2283-ship-pr-refusal-signal

`ship-pr`, `open-pr`, `fold-changelog-entry`, `cut-release` and `park-branch` now end a refusal with a
`[REFUSED]` line naming what did and did not happen -- printed on the error stream the host already used,
and followed by an explicit `exit 1`. `ship-pr`'s says which side of the merge it stopped on, because a
refusal after the merge leaves the fold owed, and that is the opposite of nothing having happened.

The defect it closes is that a backgrounded run reported `completed (exit code 0)` for a run that merged
nothing (measured on PR #2282): the refusal's only machine-readable signal is the process exit code, and
every recorded invocation of these scripts is read through a pipe, which reports its own `0` instead. The
scripts' exit codes were never wrong -- unpiped they are 1 -- so the repair had to move the verdict into
the output rather than into the exit path the report named.

**Score:** 4

#### What makes this deploy extra special

It is the half of a chain ending that was missing. A finishing run has printed a close-out receipt since
#1884; a refusing one printed a PowerShell error record and nothing that said *this run did not finish*.
The two endings are symmetrical now, and the asymmetry had been costing exactly what it was bound to cost:
a session reading the cheap signal and closing out on the wrong one of the two.

For a subscriber of this workflow the change is invisible until a run refuses -- and then it is the
difference between reading a stack trace and reading a verdict. Nothing about which runs refuse changed.

**Score:** 3

#### Pull Request

A refused chain-ending run says so in its LAST LINE, not only in an exit code a pipe throws away
