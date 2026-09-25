## fix/2482-asana-mirror-reach-gate

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

Inbound #2482, verified on pickup. The **symptom** stands: `BWJ-Development/smartwatchbanden#770` has
only `documentation`, and the reporter's closing comment records the marker that was removed and the card
deleted by hand. The **reason** stands too: `report-issue` has no script, and the plugin ships no hook,
so step 2's reach-label gate is a sentence and nothing else.

Proposed repair 1 is built here, in the hook form. It does not lean on a session remembering to run a
helper, which was the failure being repaired.

#### Proposed repair 2, declined with its reason

The report proposed making the `-Resolves` refusal depend on the reach label, on the reasoning that *an
Asana marker on a non-reach issue is itself the defect*. That does not hold for every case. A ticket that
**arrived from Asana** carries a card legitimately whether or not it has the reach label
(`WORKFLOW-portable.md` section 8). It must still wait for the paste-ready block before it closes, and
keying the exemption on the label would let its merge close it first. The "real place" the report names
already exists as well: since #2120, `open-pr`'s resolves gate reads `Get-ResolvesExemptMatchers`, and
the consumer's `guard-resolves-asana` bridge is what that seam replaces. With repair 1 in place, a
tier-0 issue gets no marker in the first place, so nothing is left for the exemption to misfire on.

### CREATE

- [x] `scripts/lib/asana-mirror-gate.ps1`: which URLs count as a mirror, and the three verdicts
- [x] `hooks/guard-asana-mirror.ps1` + `hooks/hooks.json`: a PreToolUse hook on `mcp__*Asana*__create_task*`
- [x] report-issue step 2, `WORKFLOW-portable.md` section 2 and the bwj README name the hook
- [x] `Get-ReachLabel`'s contract row names the hook as a reader (both byte-identical copies)

### TEST

- [x] `scripts/tests/guard-asana-mirror.tests.ps1`: 35 asserts over the lib, the hook's network-free paths, and the registration
- [x] Live smoke run: `smartwatchbanden#770` refused (exit 2), `#764` (carries `minor`) admitted, an unreadable issue passed with a warning
- [x] `check-plugin-integrity.ps1` at 0 errors; `hook-stdin-guard`, `hook-fail-closed` and `dkj-policy-bwj` suites green

### DEPLOY: fix/2482-asana-mirror-reach-gate

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

