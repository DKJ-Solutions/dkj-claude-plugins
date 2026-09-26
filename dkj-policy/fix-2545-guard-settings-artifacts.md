## fix/2545-guard-settings-artifacts

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

#2540 left bootstrap's two settings proposals unguarded, because the reporting after each write
assumes the file exists. Verified by reading: `.claude/settings.suggested.jsonc` and
`.claude/settings.proposed.json` are written unconditionally, the `.claude/` directory is created with a
plain `New-Item`, and the next steps name both files. The merged proposal can hold a copy of the
consumer's `settings.json`, so it is the one that matters most.

### CREATE

- [x] `.claude/` is created through `New-DirectoryInside`, so never through a junction
- [x] each proposal is written only when `Test-WriteRefused` passes; `$suggestWritten` / `$proposedWritten` record which were, and the `[create]` line, the git-ignore reading and the settings.json ignore notice run only for a file that was written
- [x] next steps: step 3 gets a branch for when neither proposal was written, and the hand-merge branch points at a `[refused]` line as well as a `[notice]`
- [x] after Victor's review: step 3 has four cases rather than two. Only the annotated proposal refused now reads "delete it" and says the annotated file was not written; neither written names the `[refused]` and `[notice]` lines instead of claiming a junction as the one cause

### TEST

- [x] `bootstrap-drift.tests.ps1`: `.claude/` itself a junction -- nothing lands outside, both proposals are reported refused and neither is announced as placed, and step 3 says there is nothing to copy from; and only the annotated leaf a reparse point -- the merged proposal is still written and step 3 names one proposal, not both (234 asserts green)
- [x] Victor (code review) and Sebastian (security review): Victor's step-3 finding repaired above; Sebastian found the read side of the merge unguarded, outside this diff, filed as #2549
- [x] `teardown.tests.ps1` and `test-suite-gate.tests.ps1` green; `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: fix/2545-guard-settings-artifacts

`specialists-init`'s bootstrap no longer writes its two settings proposals through a symlink or junction.
`.claude/settings.suggested.jsonc` and `.claude/settings.proposed.json` were written without a check, so
a junctioned `.claude/` put both outside the repo. The merged proposal can carry a copy of the repo's
own `settings.json`. Both now go through the same `[refused]` check as every other file the bootstrap
creates since #2540, and `.claude/` is no longer created through a junction either. A refused proposal
is not announced as placed, and the next steps no longer tell you to copy from a file that was never
written.

**Score:** 1

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

The bootstrap's settings proposals refuse a symlink or junction too

