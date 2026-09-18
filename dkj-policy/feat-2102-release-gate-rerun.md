## feat/2102-release-gate-rerun

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

Answer the issue's own question: can any of the 114 suites fail on a change confined to releases/**? Measure, then decide whether the lint half alone answers it.

#### What the measurement found

The whole of dkj-policy/releases/ was moved aside and all 114 suites were run against the result. Four
went red, and the answer inverts the question:

| suite | why |
|---|---|
| repo-config.tests.ps1 | one EXISTENCE assert over the path set Get-MojibakePaths returns. It reads the list, never a file in it -- and a cut only ADDS notes, so the assert can only become more true |
| bootstrap-drift.tests.ps1 | runs check-plugin-integrity.ps1 over the live repo as a smoke assert |
| fix-mojibake.tests.ps1 | the same |
| subagent-shared.tests.ps1 | the same |

So no suite reads the CONTENT of a release note. The suites' entire coverage of that tree IS the lint
gate, run three more times -- which makes lint-only there not an approximation of the test gate's
answer but that answer.

Cost, each figure credited to the run that produced it. THIS machine, 30 lanes: the suites alone 249s,
the lint gate alone 27s. The v5.5.0 cut, at 6 lanes: the whole second gate leg 325s, never split into
its two halves anywhere -- and one of the two runs that together are 652s of a 1,166s release, the 56%
the issue reports. The makespan
is set by check-plugin-integrity-docs.tests.ps1 at 247.5s, so the three embedded lint runs are not
themselves on the critical path -- this is a coverage finding, not a second cost one.

Dave chose the mechanical repair over documenting the measurement alone.

### CREATE

- [x] Get-ReleaseNoteTreeRoots + Get-NoteTreeOnlyVerdict in scripts/lib/gate-lib.ps1
- [x] -NoteTreeOnly on Invoke-WorkflowGates, consumed in the test-gate chain after the evidence record and the CI certificate
- [x] -NoteTreeOnly on open-pr.ps1, forwarded at the -GatesOnly site and named as ignored on the PR path
- [x] the shared-script mirrors rebuilt
- [x] cut-release step 4 and the open-pr skill page carry the switch and the measurement behind it

### TEST

- [x] gate-lib.tests.ps1 case 18: the happy path, plus the refusals -- clean tree, stray path, empty bound, prefix trap, rename out, ordinal case
- [x] lint gate green
- [x] all 114 suites green
- [x] end-to-end on a note-only working tree: the deduction fires and the suites do not run

### DEPLOY: feat/2102-release-gate-rerun

The release-notes commit no longer pays for the test gate it cannot use. open-pr.ps1 -GatesOnly
-NoteTreeOnly asks whether every path differing from HEAD sits inside the release-note tree the
third direct-on-main exception already bounds that commit to, and only where that is PROVEN does it
skip the suites -- the lint gate runs either way. On the v5.5.0 cut that second gate leg cost 325s
over one hand-written markdown file: one of the two runs that together are 652s of a 1,166s release, 56%
of it spent on the same 114 suites twice. What the switch leaves standing is the lint half, 27s here
against 249s for the suites; the cut never split its own 325s, so neither figure is credited to it.

The skip is a deduction rather than a favour because the suites have no coverage of that tree to lose.
Moving the whole release tree aside and running all 114 turned four red: one on an existence assert over
a path list, which a cut only satisfies more firmly, and three because they run the lint script over the
live repo as a smoke assert. The suites' entire coverage of a release note IS the lint gate.

It proves rather than filters, which is what makes it survivable: #2102 declined a docs-only path
predicate by name, on the grounds that a wrong matcher is silent. This answers no to an unreadable git,
a repo naming no note tree, a clean tree, one stray path, and a rename dragging a note out of the tree --
so being wrong costs a full gate run rather than a skipped one, and the fallback is byte-for-byte the
un-flagged run.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow gets the switch and the measurement behind it through the plugin, and
their own release-notes commit stops paying for a gate that cannot reach a different verdict there. It
is opt-in and scoped to -GatesOnly, so a consumer who never types it sees no change at all.

**Score:** 2

#### Pull Request

The release-notes gate re-run, measured
