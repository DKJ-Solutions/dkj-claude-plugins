## fix/2735-session-start-no-out-dir

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

#2735: step 2 of `measure-session-start` said to download the previous page "into the scratch
directory". On Windows the harness can hand a session that path as an 8.3 short name, and the Artifact
tool refuses an `out_dir` with a `NAME~1` segment, so every run on that machine failed at step 2. I
checked the reason against the tree: line 65 of the skill page is the only place that sends the
scratch path to the Artifact tool. Steps 3 and 7 pass it to PowerShell, which resolves short names.

### CREATE

- [x] Step 2: download with no `out_dir`, copy the result to `<scratch>/previous.html`, and say why in
  one sentence

### TEST

- [~] No automated test: this is prose a session follows, and no suite reads it. The repair is the
  workaround the reporter already ran successfully (no `out_dir`, then `-Previous` on the named path)

### DEPLOY: fix/2735-session-start-no-out-dir

`/measure-session-start` no longer fails at step 2 on a Windows machine whose temp path has an 8.3
short name. Step 2 now downloads the previous page to the Artifact tool's own default folder and copies
it into the scratch directory, so the tool never sees an `out_dir` it refuses.

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the repair. Steps 3 and 7 keep `<scratch>` on purpose, because they pass it to
PowerShell rather than to the Artifact tool.

**Score:** N/A

#### Pull Request

measure-session-start step 2: download the previous page without out_dir
