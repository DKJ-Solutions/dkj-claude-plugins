## feat/2890-split-awaiting-decision

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

Resolves #2890. Dave's decision, recorded on the issue: two labels, "dev" means the owner alone, and
`awaiting-decision-client` stays separate from `awaiting-more-info`. Shaped after the #2741 rename
(b09bce37).

### CREATE

- [x] `Get-TriageLabels` and `adopt-triage-labels`' fallback: `awaiting-decision` becomes
  `awaiting-decision-dev` (a rename, with `awaiting-decision` and `needs-decision` as former names), and
  `awaiting-decision-client` is new.
- [x] The claim and sweep skip defaults, the issue dashboard and `pr-issues-lib`'s former-name map carry
  both labels.
- [x] `sweep-decisions` walks `-dev` plus its former names and skips `-client`; it removes whichever
  label the issue actually carries.
- [x] `CONTRIBUTING-portable.md` §1, the two lenses, the skill pages and the scripts README name both.
- [x] Plugin mirrors and `config-blueprint.json` regenerated through their build scripts.

### TEST

- [x] Suites: adopt-triage-labels, claim-issue, issue-dashboard, pr-issues, repo-config,
  config-blueprint, script-contract all pass; a new scenario renames `awaiting-decision` to `-dev` and
  creates `-client`.
- [x] `check-plugin-integrity`, `check-script-contract` and `build-shared-scripts -Check` clean.

### DEPLOY: feat/2890-split-awaiting-decision

The parking label `awaiting-decision` is split in two, so the label says whose decision an issue waits
on ([#2890](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2890)).
`awaiting-decision-dev` is the owner's choice: it is today's label under a new name, and
`sweep-decisions` keeps putting it to the owner. `awaiting-decision-client` is new and means a choice
from the client or requester outside the dev team. `sweep-issues`, `sweep-decisions` and the claim
defaults all skip it until that person answers. The old names `awaiting-decision` and `needs-decision`
stay matched everywhere, and `adopt-triage-labels` prints a `gh label edit` rename for a tracker
that still carries one.

**Score:** 2

#### What makes this deploy extra special

A consumer who runs `adopt-triage-labels` is offered one rename and one new label. An issue that waits
on a colleague's sign-off can now be parked where `sweep-decisions` no longer puts it to the owner.
Nothing breaks if they skip the rename, because the old name still parks the issue.

**Score:** 2

#### Pull Request

Split awaiting-decision into awaiting-decision-dev and awaiting-decision-client

