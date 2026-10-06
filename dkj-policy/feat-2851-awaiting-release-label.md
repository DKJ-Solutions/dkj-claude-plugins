## feat/2851-awaiting-release-label

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

Inbound #2851, decided by Dave on October 6, 2026: option (a), a new `awaiting-release` parking label
that the cut lists. Modelled on #2828's `awaiting-owner-act` for every place a parking label is
registered. The listing goes in `cut-release.ps1`, the cut every consumer runs, rather than the
Shopify-only `live-preflight`.

### CREATE

- [x] The label in both canonical copies (`Get-TriageLabels`, `adopt-triage-labels`' fallback), the claim/sweep default skip lists, the dashboard's parking set and reason text, and the contract record
- [x] `Write-ParkedForRelease` in `cut-release.ps1`'s follow-up block: lists open `awaiting-release` issues, prints nothing when there are none, and prints the hand command on a failed read instead of throwing
- [x] Docs: `CONTRIBUTING-portable.md` (its own paragraph; the filing rule's count corrected from five to seven, because it had missed `awaiting-owner-act`), the claim, sweep and dashboard skills, the scripts README, and Chris's and Derek's lenses
- [x] Mirrors and blueprint regenerated; the label created on this repo's tracker

### TEST

- [x] `cut-release-guardrail.tests.ps1` drives the lifted function with the native call stubbed: two issues are listed in number order, an empty list prints nothing, and a failed read neither throws nor goes silent (128/128 green)
- [x] The count and record asserts in the label, contract, repo-config, claim and dashboard suites now include the eleventh label

### DEPLOY: feat/2851-awaiting-release-label

New parking label `awaiting-release`, purple like the rest of the awaiting-* family. It is for an issue
whose remaining work may only run inside the next release, in its cut or its live step
([#2851](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2851)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. `cut-release.ps1` now lists the open
issues that carry it among its follow-up steps, so parked work comes up at the release it is waiting for.

**Score:** 2

#### What makes this deploy extra special

A consumer who parks "do this at the next release" work no longer has to borrow `awaiting-owner-act`,
which told the owner to act now. At the cut, the parked issues are listed right after the tag, so nobody
has to remember them. `adopt-triage-labels` offers one more `gh label create` line.

**Score:** 2

#### Pull Request

A sixth parking label: awaiting-release, listed by the cut

