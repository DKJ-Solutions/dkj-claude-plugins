## feat/allow-git-stash

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

Retiring a superseded branch (`feat/2591-lens-retired-name-finding`, whose work had already shipped as
#2603) was refused by the auto-mode classifier as `[Git Destructive]`: the chained command opened with a
`git stash push`, the one git verb in it that the project allow-list did not name. Dave asked for auto
mode to be able to do that retire, so `git stash` joins the allow-list beside the other git verbs.

### CREATE

- [x] `Bash(git stash:*)` and `PowerShell(git stash:*)` added to `.claude/settings.json`, in the git block

### TEST

- [x] The settings file still parses as JSON
- [x] The retire itself ran in auto mode as separate steps once the rule was in place (stash of the three
  draft paths, checkout and pull of `main`, local and remote branch delete)

### DEPLOY: feat/allow-git-stash

A session in this repo can now stash uncommitted work without a permission prompt, so retiring or
switching away from a branch with a draft on it no longer stops for a question. A stash is reversible,
unlike the destructive verbs the safety rules name, which stay unlisted.

**Score:** 2

#### What makes this deploy extra special

N/A: `.claude/settings.json` is this repo's own harness config and reaches no consumer through a plugin
update.

**Score:** N/A

#### Pull Request

git stash is allowed without a permission prompt

