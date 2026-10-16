## fix/3056-one-retired-extension-repair

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

Issue #3056: the repair for a retired extension id was composed independently in three scripts. One
helper beside `Get-RetiredPolicyExtensionNames` composes it, and all three call it.

### CREATE

- [x] `Get-RetiredExtensionRepair` in `scripts/lib/claude-md-import-lib.ps1`, returning `$null` for a
  name that is not retired
- [x] `check-consumer-prose.ps1`, `plugin-versions.ps1` and `update-plugins.ps1` call it; consumer-prose
  now prints the settings' own marketplace once `Test-PluginMarketplaceSlug` accepts it, `<marketplace>`
  otherwise
- [x] the plugin mirrors under `plugins/dkj-policy/` (both copies of the lib) synced byte-identical

### TEST

- [x] each script's retired-id case asserts the lib's sentence itself: `consumer-prose-gate` (143 pass),
  `plugin-versions` case 38 (265 pass), `update-plugins` case 24 (137 pass)

### DEPLOY: fix/3056-one-retired-extension-repair

The repair for an enabled plugin id under a retired extension name (`dkj-policy-bwj`,
`dkj-policy-dkjs`) is now composed by one helper, `Get-RetiredExtensionRepair` in
`scripts/lib/claude-md-import-lib.ps1`
([#3056](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3056)).
`consumer-prose-sessioncheck`, `plugin-versions` and `update-plugins` had each written that sentence out
for themselves, so a change to the command in one would drift from the other two. The tests for all three
now assert the helper's sentence itself. The session check's warning also gains the settings step and the
repo's own marketplace name in place of a `<marketplace>` placeholder.

**Score:** 2

#### What makes this deploy extra special

A consumer still enabling a retired extension name sees the same repair as before, now worded alike in
all three places. Nothing changes in how they work.

**Score:** N/A

#### Pull Request

One helper composes the retired-extension repair

