## feat/allow-tree-hub-server

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

The hub on :4892 runs from the installed plugin release, so a merged hub change (the Clock card, #3560)
is invisible there until the next cut. Serving the tree's own hub on a spare port shows it, but auto mode
refused the command as a security weakening. The owner asked for it never to be refused again.

### CREATE

- [x] `.claude/settings.json`: allow exactly `serve-general-pages.ps1` from the tree, in the Bash form
  that matches the existing `scripts/` rules and in two PowerShell forms
- [x] `plugins/dkj-policy/hub/README.md`: say how to preview the tree's hub in the source repo

### TEST

- [x] `.claude/settings.json` still parses as JSON
- [x] the lint and test gate via open-pr

### DEPLOY: feat/allow-tree-hub-server

A session in this repo can now serve the tree's own hub on a spare port without a permission refusal, so a
merged hub change can be looked at before the release that carries it to `:4892`. The allow rules name the
one server script and nothing wider.

**Score:** 2

#### What makes this deploy extra special

N/A -- a permission in this repo's own settings and a note in the source-repo section; no consumer takes
either.

**Score:** N/A

#### Pull Request

Allow a session to serve the tree's own hub without a permission refusal

