## feat/measure-session-start-skill

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

Turn the hand-built "session start prompt optimisation" (Dave, September 30, 2026) into a skill that
measures what a clean session loads, republishes the claude.ai artifact "Sessiestart-context", and ends
with advice. **The script measures and never advises; the model that runs the skill writes the advice**
(#861's verdict, and why the skill is `disable-model-invocation: true`: zero always-on tokens).

- `scripts/maintenance/measure-session-start.ps1` (+ plugin mirror, registered in the shared-scripts
  registry): **collect** writes the measured half as JSON (always-on documents via
  `Get-AlwaysOnDocuments`, the budget via `Resolve-AlwaysOnBudget`, plugin skill listings via `claude plugin
  details` minus the `disable-model-invocation` skills, recorded as excluded -- #2664, not fixed in
  `measure-skill`); **render** injects the data between two markers in the template, `<` escaped, and with
  `-Previous` reads the history back out of the published page, so the page is its own state.
- `scripts/lib/session-start-lib.ps1`: the pure half, so it can be tested without `claude`.
  `Get-PluginDetails` moved from `measure-skill.ps1` into `measure-skill-lib.ps1` (behaviour identical)
  so both scripts ask the CLI the same way.
- `plugins/dkj-policy/skills/measure-session-start/`: the skill page and the data-driven template (same
  look as the hand-built page, every string from the data, labels follow the session language).
- Footprint as `measure-closeouts` had it: plugin README skill row, scripts README rows, ADOPTION list,
  one line on `measure-skill`'s page.
- Not in this branch: tests (Tycho), the DEPLOY and tier sections (Rendall).

### CREATE

- [x] `measure-session-start.ps1` (collect + render) and `session-start-lib.ps1`, both mirrored and
  registered; `Get-PluginDetails` moved into `measure-skill-lib.ps1`
- [x] The skill page and the data-driven template under `plugins/dkj-policy/skills/measure-session-start/`
- [x] The footprint: plugin README, scripts README, ADOPTION list, one row on `measure-skill`'s page
- [ ] Review fixes from Victor, Sebastian and Edith: the history merge, the home path in `importedBy`, the
  untrusted previous page, and the wording
- [x] `ConvertTo-SafeScriptJson` was a no-op: the literal escape reached disk decoded, so the escape is now
  composed (#2671 files the class)

### TEST

- [x] `measure-session-start.tests.ps1` (Tycho): the frontmatter flag, the row split, the data block,
  the merge, injection safety, a render round trip, and mirror identity. It caught the no-op escape
- [x] `measure-skill` and `shared-scripts` suites still green after the move
- [x] First real run: collect on this repo, render against the hand-built page, published to the
  existing `Sessiestart-context` artifact (version 9)
- [ ] `open-pr` runs the lint gate and all suites before the push

### DEPLOY: feat/measure-session-start-skill

A new `dkj-policy` skill, `measure-session-start`, measures what a clean session loads before the first
question and republishes a page that shows it by influence. The page marks each layer as direct (files
in the repo), via a setting, or none (Claude Code itself), ranks the actions by tokens saved, and ends
with advice on where the biggest gain is and why. The script measures the always-on documents and the
plugin skill listings, minus the skills with `disable-model-invocation`. It never advises: the model
running the skill adds the estimated layers and writes the advice. The published page carries its own
data, so the next run shows the deltas without a state file anywhere. The skill itself carries
`disable-model-invocation: true` and costs no always-on tokens.

**Score:** 3

#### What makes this deploy extra special

A consumer gets one new skill, invoked by name only (`/measure-session-start`). It is not loaded into a
session, so nothing changes until somebody runs it.

**Score:** 2

#### Pull Request

measure-session-start: a skill that measures the session start and refreshes its artifact

