## feat/3009-live-preflight-connected-mode

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

#### Scope

Part 2 of [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998): `live-preflight` gets a Git-connected mode, selected by a new optional Shopify seam `Get-ShopifyLiveDeployBranch`. It uses #3008's `Get-LivePromotionStep`, `Format-LivePromotionCommand` and the record's promoted-sha line. With the seam unanswered, the CLI push behaves exactly as before.

#### Design choices

- The rule-suite read counts **every** failed suite on the deploy branch in the last week, not only the Shopify bot's, because the bot's actor name has not been measured. `-AcceptRejectedWriteBacks` downgrades it to a note once a person has reconciled. An unreadable log (no admin access) is a skip, never a pass.
- Step 3 still derives the range's rows, because the record has to list every theme file of the range for the cut. What the promotion carries is measured separately at step 6, against the deploy branch.

### CREATE

- [x] `Get-LiveWriteBackStep` in `scripts/lib/live-push-rules.ps1`, pure, with its asserts in `live-push-rules.tests.ps1`.
- [x] `live-preflight.ps1`: the seam, and connected-mode steps 3, 6 and 8 and the record. CLI mode is untouched.
- [x] Skill page: parameter row, the connected-mode section, seam row. Shopify README: seam row. Also fixed four literal `\n` sequences in the skill page's drift paragraph.
- [x] Mirrors regenerated (`build-shared-scripts`).

### TEST

- [x] `live-push-rules.tests.ps1` 166/0, standalone.
- [x] Smoke-run against a scratch repo with a local bare origin and a stubbed `shopify` that fails at once: connected mode measured 3 promotion paths and composed the promotion PR. A bot commit on `live` refused it with the back-flow message. With the seam removed, CLI mode printed its old steps unchanged. The rule-suite read was a skip there, since a local remote has no API.

### DEPLOY: feat/3009-live-preflight-connected-mode

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

live-preflight: verify a promotion when the live theme deploys from a branch

