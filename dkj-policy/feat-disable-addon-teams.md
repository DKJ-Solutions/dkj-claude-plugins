## feat/disable-addon-teams

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

Dave, September 30, 2026: switch off the three add-on teams here, because none has work in this repo.
This reverses the September 8 choice to enable every plugin for validation. The session-start measurement
of the same day put their cost at about 2.9k tokens per session. An Explore pass mapped what depends on
the enabled set before anything changed.

### CREATE

- [x] `.claude/settings.json`: ecomm, lifehub and shopify set to `false`. They are not deleted, because
  the user-scope settings enable shopify on this machine and the last layer to name a plugin wins
- [x] `connectors/dkj-claude-plugins.json`: the three blocks removed and a dated REDUCED note added, so
  `connectors.tests.ps1` case 6 (the self-manifest) stays green
- [x] The 11 empty `VUL-IN` lenses deleted and their roster rows removed from `SPECIALISTS.md`, so the
  roster check prints no `[ORPHANS]` line at every session start
- [x] Docs brought in line: `this-repo.md`, `SPECIALISTS.md`, Chris's, Sylvester's and Tessa's lenses,
  the `repo-config.ps1` seam comment, and `.claude/specialists/UPDATE`

### TEST

- [x] The four gates run locally (roster sync, plugin integrity, script contract, unfolded entry)
- [x] `open-pr` runs the lint gate and all suites before the push

### DEPLOY: feat/disable-addon-teams

The three add-on teams (`dkj-subagents-ecomm`, `dkj-subagents-lifehub`, `dkj-subagents-shopify`) are
switched off in this repo's own `.claude/settings.json`. They had no work here and cost every session
about 2.9k tokens. They are set to `false` rather than removed, so a user-scope setting cannot switch
them back on. Their entries in the self-connector record, their 11 empty lenses and their roster rows go
with them, so no gate and no session-start check reports them. What is given up is the early warning:
a broken add-on plugin no longer surfaces at this repo's own session start. Sylvester's lens says how
to switch one back on for a validation pass.

**Score:** 2

#### What makes this deploy extra special

N/A. Only this repo's own settings change. No consumer's installed plugins or shipped files change.

**Score:** N/A

#### Pull Request

Disable the three add-on teams in this repo's own settings

