## feat/3463-hub-config-drift

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

Issue #3463, with the owner's decision recorded on it (October 25, 2026): name all three, `OwnHub` neutrally
as a fact, the other two as config defects. The source repo's own `OwnHub` is exempt.

### CREATE

- [x] `Get-DevPreviewDriftClauses` in `hub/lib/dev-preview-rules.ps1` (pure), and `NameStated` on the parsed config
- [x] The dev-preview hook appends the clauses to its product and OwnHub lines, in a DKJ-Solutions repo only
- [x] Asserts in `dev-preview-sessionstart.tests.ps1`, group 1d2

### TEST

- [x] Smoke run of the hook in this repo: the source repo's `OwnHub` is not named; the clauses read as intended

### DEPLOY: feat/3463-hub-config-drift

In a DKJ-Solutions repo, the dev-preview SessionStart line now names three things that keep a repo from
following a hub change ([#3463](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3463)). `OwnHub = $true`
is named as a plain fact (`this repo runs its own hub (OwnHub), so hub releases do not reach it`), because it
stays a supported opt-out. `OpenInVsCode` with no hub port (4890-4899) routed in `.vscode/settings.json`, and a
`Name` still stated in `Get-DevPreview`, are named together as `config drift`. The source repo, which runs the
hub from its own tree, is not named for its `OwnHub`.

**Score:** 3

#### What makes this deploy extra special

A maintainer of a DKJ-Solutions repo sees on the next session's first line why a hub change did not reach
that repo, or why the hub opens in the system browser, and what to delete or route.

**Score:** 2

#### Pull Request

Hub: name the config drift that keeps a DKJ repo from following a hub change

