## feat/2422-reusable-ci-gates

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

A consumer's Part 1 gates become a few-line caller of a reusable workflow in this repo, so runner, steps and commentary live in one place

Inbound #2422, verified at pickup. The symptom holds: no `workflow_call` anywhere in the tree, and Part 1
writes two full runners of about 50 lines each (`adopt-workflow-folder.ps1`). The mechanism exists, and a
public repo's reusable workflow may be called from a private one. The report inferred that the contract
check (`script-contract-lib.ps1:982`) would need to accept the caller shape, and that inference **does not
hold**. That inventory is presence-by-path, and the file names are unchanged. The reader that does break is
`consumer-runner-lib.ps1`. A caller has no checkout step, so without a repair `check-connectors` would
read every fresh adoption as reaching into this tree nowhere.

Kept out of scope, with the reason: the consumer's gate still passes no `-Pr` and so holds no DEPLOY lock,
because adding one means widening every caller's token. Filed as #2429.

### CREATE

- [x] `.github/workflows/reusable-branch-entry.yml` and `reusable-always-on-budget.yml` (`on: workflow_call`, input `scripts-ref` defaulting to `main`), each carrying the runner, the 10-minute cap and the reasoning that used to be copied into every consumer
- [x] `adopt-workflow-folder.ps1` (and its plugin mirror) writes a caller instead: trigger, `permissions`, one `uses:` line. No `timeout-minutes`, because GitHub refuses it on a calling job
- [x] `consumer-runner-lib.ps1`: `Get-SharedScriptReference` reads a `uses:` of a workflow in this repo as a reference into this tree (`Kind = 'call'`), so check 6 and 6c keep seeing a caller-only consumer
- [x] `check-connectors.ps1` words a missing reusable workflow as a call, not as a checkout the consumer does not have
- [x] `adopt-dkj-policy/SKILL.md`: what lands is a caller, the `<job> / <job>` check name, how to pin, and what an already-adopted repo does (delete the file, re-run Part 1)

### TEST

- [x] `adopt-workflow-folder.tests.ps1` follows both hops: the caller calls a reusable workflow that exists here, and that workflow runs a published-mirror script that exists here. It also asserts that the caller carries no key a calling job may not have
- [x] `workflow-timeouts.tests.ps1`: a scaffolder composing only calls is accepted, and each called file must be one of this repo's own, whose cap the first section already holds
- [x] `connectors.tests.ps1` 12j2/12j3: a caller-only consumer reads as adopted, and a caller of a missing reusable workflow is an `[ERROR]` worded as a call

### DEPLOY: feat/2422-reusable-ci-gates

Part 1 of `adopt-dkj-policy` no longer copies the two PR gates into a consumer
([#2422](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2422)). `branch-entry.yml` and
`always-on-budget.yml` are now a few-line caller of a reusable workflow in this repo
(`reusable-branch-entry.yml`, `reusable-always-on-budget.yml`). A change to the runner, its steps or its
timeout therefore reaches every consumer on its next pull request, with no re-adopt, and the reasoning
sits in one place. `check-connectors` recognises the `uses:` line as a reference into this tree, so a
caller-only consumer still reads as adopted. A repo adopted earlier keeps its full copy until it deletes
the file and re-runs Part 1.

**Score:** 2

#### What makes this deploy extra special

A repo adopting the workflow gets two short callers instead of two 50-line runners, and later changes to
those gates arrive without anyone re-running the adoption. An already-adopted repo sees no change unless
it opts in.

**Score:** 2

#### Pull Request

Ship the two PR gates as reusable workflows

