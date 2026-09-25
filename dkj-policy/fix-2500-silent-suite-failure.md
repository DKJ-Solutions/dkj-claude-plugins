## fix/2500-silent-suite-failure

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

#2500 asked two things. **Why was no output kept?** The retention block drops a 0-byte capture file by
design, so "no output kept" meant the suite wrote nothing to either stream -- and nothing on the
verdict said so. A suite that writes nothing never reached its own first line
(`session-cache-lib.tests.ps1` opens with a `Write-Host`; a throw or a parse error before that would
print to stderr). So it has measured nothing, the same state #1723's lone re-run exists for.

**Does the suite have a contention-sensitive fixture of its own?** Measured: no sign of one.
`reproduce-suite-contention.ps1 -Suite session-cache-lib.tests.ps1 -Repeat 10 -MaxParallel 22`
passed 10 of 10 under 22 lanes of real sibling suites, in 3.4-4.2s each. #2481's failing run ended at
1.6s, faster than any full pass, which fits a process that died before the suite's body rather than a
fixture inside it. The exit code of that run was not recorded, so the process-start cause stays
inferred.

### CREATE

- [x] `native-capture-lib.ps1`: `Test-GateSuiteSilent` (settle-aware, like the retention read), and a
      SILENT verdict in the reap loop routed into the crash path's lone re-run; excluded from the pace
      sample and marked on the timing row as a crash is
- [x] Re-run wording names a silent exit as one (banner, pass line, `SILENT AGAIN`); the banner stays
      byte-identical when nothing was silent
- [x] Green verdict names a silent exit cleared by its re-run; red verdict says which suites wrote
      nothing, so an absent kept-output line is explained
- [x] Mirrors regenerated (`build-shared-scripts.ps1`)

### TEST

- [x] `test-suite-gate.tests.ps1` 8g: silent once, then green on the re-run; silent every time, red
      with `SILENT AGAIN` and the no-output line; `Test-GateSuiteSilent` in-process (empty, missing,
      one byte). Suite: 342 pass, 0 fail
- [x] Focus reproduction of `session-cache-lib.tests.ps1`, 10 repeats under 22 lanes: all green

### DEPLOY: fix/2500-silent-suite-failure

The test gate no longer reports a suite that exited non-zero **without writing a single byte** as a
plain `FAILED`, with no output shown and none kept. Such a suite never reached its own first line, so
the gate now marks it `SILENT`, re-runs it alone once (as it already does for a crash), and names it
on the verdict: as cleared on a green run, or as having written nothing to keep on a red one. A suite
silent on its re-run too is red. A suite that printed anything at all is judged exactly as before and
never re-run ([#2500](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2500)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the test gate runs inside the repos that adopt this workflow; no subscriber of a service sees it.

**Score:** N/A

#### Pull Request

