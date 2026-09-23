## fix/2362-roster-sync-clean-hook-under-load

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

#2362: `roster-sync.tests.ps1`'s "hook: exit 0 when clean" got exit 1 with no "in sync" line under the
parallel gate, then passed alone. The reason was verified before repairing anything: `roster-sessioncheck.ps1`
ends every path, its catch included, on `exit 0`, and every `Invoke-Hook` case expects 0 (the exit-1
asserts in the suite go through `Invoke-Ps`, not the hook). So exit 1 is a child that never reached its
script's end, not a verdict. The runner captured stdout only, which is why the report had no cause to
give. Repair it the way #2364 repaired `Invoke-Integrity`.

### CREATE

- [x] `Invoke-Hook` captures stderr, prints `[FIXTURE HOOK DID NOT FINISH]` with the child's last lines on
  an off-contract exit, and runs the child once more; a second failure is returned unchanged

### TEST

- [x] `roster-sync.tests.ps1` alone: 414 pass, 0 fail (unchanged count)
- [x] The retry path probed on its own with a fake hook exiting 1 (stderr shown, two attempts, code 1
  returned) and one exiting 0 (single run, output intact)
- [x] Gates via `open-pr -GatesOnly`

### DEPLOY: fix/2362-roster-sync-clean-hook-under-load

`roster-sync.tests.ps1` read a hook child that never finished as a hook that answered wrongly: the hook
exits 0 on every path, so its "exit 0 when clean" case failing with exit 1 under the parallel gate was a
run that did not complete, and the runner, which captured stdout only, kept nothing that said why. It
now captures stderr, prints that evidence on an off-contract exit, and runs the child once more. A hook
that really stops exiting 0 still fails every assert that reads it.

**Score:** 2

#### What makes this deploy extra special

N/A -- a test suite only; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

roster-sync: the clean-hook case tells a fixture failure from a verdict under the parallel gate

