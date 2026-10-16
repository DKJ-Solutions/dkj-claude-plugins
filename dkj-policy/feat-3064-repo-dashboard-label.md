## feat/3064-repo-dashboard-label

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

Inbound [#3064](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3064): the owner's term for
the dev-preview page is `Repo dashboard`, in every repo. Verified against the tree before building:
`ConvertTo-DevPreviewConfig` read the repo's `Name` (default `dev-preview`) and the placeholder set its own
`Placeholder preview`, so the issue stood as filed. A stated `Name` is ignored rather than refused, so a
consumer config that still carries one keeps working.

### CREATE

- [x] `dev-preview-rules.ps1`: the label is fixed at `Repo dashboard`, a repo's `Name` is no longer read,
  and the placeholder states none; the contract comment says why
- [x] `dev-preview-placeholder.ps1`: the page title carries the term, and the example drops `Name`
- [x] `dkj-solutions/README.md` and this repo's own `Get-DevPreview` follow the term

### TEST

- [x] `dev-preview-sessionstart.tests.ps1` repointed to the fixed label, plus a stated `Name` is ignored
  and the placeholder page's title and example: 102 passed, 0 failed

### DEPLOY: feat/3064-repo-dashboard-label

The dev-preview hook's session-start line now opens with `Repo dashboard:` in every DKJ-Solutions repo
([#3064](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3064), the owner's term, October 16,
2026). It used to open with whatever word each repo chose through `Get-DevPreview`'s `Name` (Showcase,
connector dashboard, dev-preview), so the same page had three names. The plugin now fixes the label, the
placeholder's included. A `Name` a repo still states is ignored rather than refused, so delete it at your
next edit. The hook's lines about its own setup (skipped, config unreadable, a config it cannot run) keep
the `dev-preview:` prefix, because that word names the mechanism.

**Score:** 2

#### What makes this deploy extra special

In every DKJ-Solutions repo, the link to the repo's local page at session start now reads
`Repo dashboard: http://localhost:...`, whatever the repo once called it.

**Score:** 2

#### Pull Request

dev-preview: one fixed label, Repo dashboard

