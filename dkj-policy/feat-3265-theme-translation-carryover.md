## feat/3265-theme-translation-carryover

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

Inbound #3265 asks for a pre-publish gate in "the theme-cutover / preview-promotion procedure". No such
procedure exists, the publish is always a person's act (the guard refuses it), and the translations are
readable only through the Admin GraphQL connector, which no script or hook can call. So the gate is a
skill step the session runs before the person publishes, and the guard's publish refusal points at it.

### CREATE

- [x] `carry-theme-translations` skill: list locales and markets, read both themes one locale and market
  per query (no aliases, #3266), diff, copy the digest-matching keys with `translationsRegister`, verify by
  reading again, report the verdict before the publish
- [x] README row; `theme-lifecycle`'s restore step runs it before publishing the backup
- [x] the guard's two publish refusals (`theme publish`, `themePublish` through `store execute`) name it

### TEST

- [x] `guard-live-theme.tests.ps1`: the publish refusal names the skill (204 passed, 0 failed)

### DEPLOY: feat/3265-theme-translation-carryover

A new `dkj-subagents-shopify` skill, `carry-theme-translations`, carries a store's per-theme content
translations over to a theme before a person publishes it as live, and verifies that none are missing.
Those translations (Translate & Adapt, the Translations API) are stored per theme in the store, not in
the theme files, so neither git nor a push nor a Git connection brings them along. A cutover in a
consumer lost about 1,225 section-setting translations across four languages, and every non-English
storefront went English
([#3265](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3265)). The step runs through the
Shopify connector and never publishes. The live-theme guard's publish refusal now names it, and
`theme-lifecycle`'s restore runs it before publishing a backup.

**Score:** 3

#### What makes this deploy extra special

A Shopify store repo that switches its live theme (a cutover to a Git-connected theme, or a restore) now
has a step that keeps its translated storefronts from falling back to the primary language at the
publish. A store that never switches themes sees one longer refusal line and nothing else.

**Score:** 3

#### Pull Request

A theme switch carries the per-theme content translations over, verified before the publish

