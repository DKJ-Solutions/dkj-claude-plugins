## feat/2695-dkj-solutions-house-style

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

Give every DKJ-Solutions app one shared house style (tokens, light/dark, base CSS) from a new dkj-policy-dkjs add-on, so it is not rebuilt per repo and never reaches BWJ-Development.

Dave chose the shape in-session (October 1, 2026). The style is for every DKJ-Solutions app, not only
Artifacts and not BWJ-Development. It lives in a new DKJ-Solutions codex, the counterpart of
`dkj-policy-bwj`, with the house style as its first chapter. A visible result, so the branch stops for
his look and does not merge.

### CREATE

- [x] Gwen: split the ETF dashboard's `<style>` block (`dkj-etf-tracker/etf_tracker/dashboard.py`)
  into general and domain-specific parts, keeping every value. The result is
  `plugins/dkj-policy/dkj-policy-dkjs/skills/house-style/house-style.css`.
- [x] Sylvester: marketplace entry, `plugin.json` at the lockstep version, and `false` in this repo's
  `enabledPlugins`.
- [x] Tessa: the extension `CLAUDE.md`, the plugin `README.md` and the `house-style` skill page.
- [x] Filed #2697: the extension-import tooling knows only bwj, so the dkjs import is added by hand.

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors, after fixing a README link that left the plugin root and
  an install line printed without the marketplace refresh.
- [x] `check-roster-sync.ps1`: 0 errors. The agent-less plugin is skipped with an info line.
- [x] Review in parallel. Sebastian: clean, with no data from the private source in the comments and no
  external requests. Edith: the skill's component list was incomplete, and it now names every reserved
  class. Victor: two deviations from the source were applied. The bare `header` selector is scoped to
  the page header (`body > header, main > header`), so it no longer styles a `<header>` inside a
  card. `.badge--neutral` takes `--ink` text, which fixes the source's near-black-on-dark contrast in
  dark mode. The missing `--c`/`--m` fallbacks were left as the source has them.
- [x] Gwen built a specimen page of every component, with a light/dark/auto toggle, for the owner's
  look. It sits in the session scratchpad and is not shipped.

### DEPLOY: feat/2695-dkj-solutions-house-style

Adds `dkj-policy-dkjs`, the DKJ-Solutions codex: an additive add-on to `dkj-policy` whose first chapter
is the house style. That chapter is one set of design tokens (light and dark), the light/dark mechanism
and a base stylesheet, lifted from the hand-tuned ETF dashboard with every value kept. Every
DKJ-Solutions app starts from it instead of rebuilding a style. A repo adds its own domain layer on top
and never redefines a house token. It is enabled in DKJ-Solutions repos only. BWJ-Development keeps its
own styling. Until #2697 lands, the extension's `CLAUDE.md` import is added by hand.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions maintainer enabling the new plugin gets a ready house style for any page, report or
Artifact. Nothing changes for a repo that does not enable it, BWJ's included.

**Score:** 2

#### Pull Request

A DKJ-Solutions codex plugin with the house style as its first chapter

