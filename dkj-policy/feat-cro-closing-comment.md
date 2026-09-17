## feat/cro-closing-comment

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

Dave asked for a follow-up to the `CRO` label just added: when a GitHub issue carrying that label is
closed, `asana-mirror` should automatically post a comment on the **GitHub issue itself** with text
ready to copy and paste into the Asana task, so Dave can tell the requester (today: Johnno) where to
see the result.

Clarified with Dave: the "where to view the result" link cannot be derived reliably from anything this
script reads (the issue, its pull requests, its labels) -- it depends on what the ticket was about, and
a wrong guess would read as authoritative to a colleague who never checked it. So the comment carries a
placeholder for the link, which Dave fills in by hand before pasting the paragraph into Asana. This
mirrors how every other label on this tracker is judged rather than derived.

Scope: the `closed` event only, no reconciliation-sweep backstop -- the same accepted gap this workflow
already carries for a dropped `reopened` event, so a missed close is a comment that never posts rather
than new machinery to detect it after the fact.

### CREATE

- [x] Add `Test-IssueIsCro` and `New-CroClosingComment` (pure helpers) plus `Add-GithubIssueComment`
  (the network call) to `templates/asana-mirror.ps1`.
- [x] Call the new step from `Invoke-EventMode`, gated on `$Event -eq 'closed'` and the issue's own
  `Labels` (already read by the existing `Get-IssueLinkState` call -- no extra API round trip).
- [x] Document the behaviour in `WORKFLOW-portable.md`, as a subsection of step 4, with a cross-link
  from the `CRO` label's own subsection.
- [x] Add the two new pure helpers to the docstring's list of what the test suite exercises, and write
  the tests themselves in `scripts/tests/dkj-policy-bwj.tests.ps1`.

### TEST

`scripts/tests/dkj-policy-bwj.tests.ps1` -- added assertions for `Test-IssueIsCro` (true/false on
various label sets) and `New-CroClosingComment` (names the label, carries the `[ADD LINK]` placeholder,
names the issue, invents no URL of its own). Full suite run: `318` asserts, all passing. The lint gate
(`check-plugin-integrity.ps1`) also ran clean, including the dead-link scan against the new cross-linked
anchors in `WORKFLOW-portable.md`.

`Add-GithubIssueComment` itself (the network call) is not unit-tested -- it has no pure logic beyond a
`gh` invocation, consistent with how this file's other network functions (`Add-AsanaComment`,
`Set-IssuePrioLabel`) are treated: the docstring says explicitly only the pure helpers are exercised
here. It will run for real the first time a `CRO`-labelled issue closes in a store repo that has
adopted this template refresh.

### DEPLOY: feat/cro-closing-comment

When a GitHub issue carrying the `CRO` label is closed, `asana-mirror` now posts a second comment --
on the GitHub issue itself, not on Asana -- carrying a paragraph ready to paste into the Asana task,
with a placeholder for the "where to view the result" link. This is additive to the existing close
update (which still goes to Asana unchanged) and fires only for `CRO`-labelled issues. No reconciliation
backstop: a missed `closed` event is not repaired later, matching the existing gap for a dropped
`reopened`.

**Score:** 1 -- this repo's own developers notice a new function in a plugin template they already
read; the mechanism itself only runs in a consumer that has adopted this refresh, and only on a `CRO`
issue closing there.

#### What makes this deploy extra special

A colleague closing a CRO-team ticket in a store repo (`smartwatchbanden`, `xoxowildhearts`) gets a
ready-made Asana message the moment they close the issue, instead of composing one from scratch --
saving them the round trip of figuring out what to tell the requester.

**Score:** 2 -- small and welcome the moment it fires, but nothing is required to change today: it
waits for the next `asana-mirror.ps1` refresh in a store repo and the next `CRO` issue closed there.

#### Pull Request

dkj-policy-bwj: post a paste-ready Asana comment when a CRO issue closes

