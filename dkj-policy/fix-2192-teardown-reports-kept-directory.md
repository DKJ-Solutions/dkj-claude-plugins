## fix/2192-teardown-reports-kept-directory

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

Repair: the leftover arm of $pruneEmptyDirs goes through Add-Kept with a third advice value, so the kept directory reaches the markers and the tally through the one door.

#### What the report claimed, and what the tree said

Verified before repairing, per the six-way check. The symptom stands at `teardown.ps1:322` -- a bare
`continue`, no marker, no count. The reason stands too: `.claude/specialists/always-on-baseline.json`
is on disk in this repo, so a `dkj-policy` consumer takes that arm on every teardown.

The report's one open question -- whether `bootstrap.ps1`'s `[tidy]` guard has the same silent arm --
is answered NO. That guard removes leftover orchestrator-note lines and reports the count it removed;
it prunes no directories, so there is no leftover arm there to be silent about.

### CREATE

- [x] `Add-Kept` takes a third `$Advice` value, `kept-directory`
- [x] the leftover arm of `$pruneEmptyDirs` reports through `Add-Kept` instead of `continue`-ing
- [x] the summary grows a third group, printing each label WITH its count
- [x] `SKILL.md` says a `[KEEP]` line can name a directory, and names the common case

### TEST

- [x] a regression case in `teardown.tests.ps1` on the fixture that made this the common case -- a
      baseline file inside the seam directory -- asserting the marker, the count, that the directory
      is not ALSO announced as going, that the nested lens directory still goes, and that preview and
      apply say the same thing
- [x] the kept figure is asserted against the markers (#356's invariant), which is what proves the
      new marker went through the one door rather than growing a tally beside it
- [x] `teardown.tests.ps1` 226 pass / 0 fail, `teardown-protocol.tests.ps1` 28 pass / 0 fail

### DEPLOY: fix/2192-teardown-reports-kept-directory

`specialists-teardown` now reports a directory it keeps instead of skipping it in silence. The pruner
removes a directory only when everything left in it was on its own removal list; the other arm was a
bare `continue`, so a directory that survived reached no `[remove]` line, no `[KEEP]` line and no
count. Keeping it is correct -- it holds a file this script did not place -- but the run then told a
reader the repo stood free of the plugin while the directory was still there. It goes through
`Add-Kept` like every other kept item, so the summary counts it, and carries the number of files that
kept it.

**Score:** 2

#### What makes this deploy extra special

A consumer running `dkj-policy` hit this on every teardown, not occasionally: since the always-on
baseline moved to `.claude/specialists/always-on-baseline.json`, the seam directory always holds a
file the teardown did not place. The uninstall report was wrong about the repo's final state in
exactly the repos that run both plugins.

**Score:** 2

#### Pull Request

specialists-teardown reports a directory it keeps instead of skipping it silently
