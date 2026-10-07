## fix/2881-guard-store-execute

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

#2881: `guard-live-theme.ps1` matched only `shopify theme publish|delete|push`, so an Admin GraphQL
theme mutation through `shopify store execute --allow-mutations` passed it. Verified by reading the
guard on main. The flags come from the Shopify CLI docs (`--query`/`-q`, `--query-file`,
`--variables`/`-v`, `--variable-file`, `--allow-mutations`). The fix maps the mutations onto the existing
marker model, so no new seam is needed.

### CREATE

- [x] guard rule 4: on `shopify store execute` with `--allow-mutations` anywhere in the command, read
  the whole command plus every `--query-file`/`--variable-file` (an unreadable one is refused).
  `themePublish` is refused always, `themeDelete` follows rule 2, and the other theme writes follow
  rule 3, where "aimed at live" is the live id in what was read, or any theme write while no live id
  is configured
- [x] the guard's header, the plugin README's rule table (row 4, the assert count), and
  `adopt-shopify-floor`'s opening sentence
- [x] filed #2889: the README's "no escape hatch" paragraph predates this branch and contradicts the
  delete marker

### TEST

- [x] `guard-live-theme.tests.ps1` group 9 -- 19 asserts: each rule in its API form, an inline,
  multi-line and file-borne query, the live id in a variable file, an unreadable file, a flag on a
  continuation line, and the reads, the non-theme mutations and a text-tool mention that must pass --
  129 passed

### DEPLOY: fix/2881-guard-store-execute

`guard-live-theme` now holds Admin GraphQL theme writes made through
`shopify store execute --allow-mutations`
([#2881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2881)). Until now it matched only
`shopify theme`, so `themePublish` or `themeFilesUpsert` through the API passed it. The new rule 4
reads the command and any `--query-file` or `--variable-file` it names, and applies the existing rules.
`themePublish` is always refused. `themeDelete` follows the delete rule. Any other theme write aimed at
the live id is refused unless the live-push marker is on the command. A repo that has not named its
live id gets every theme write refused, because nothing can tell it from a write to live. A file the
guard cannot read is refused. Reads, and mutations that touch no theme, pass as before.

**Score:** 3

#### What makes this deploy extra special

A Shopify store repo's live theme is now guarded against the Admin API route as well as the theme
CLI. A session can no longer publish a theme, or overwrite live theme files, by putting the same
change in a GraphQL mutation. A store repo with no live id configured sees its Admin API theme writes
refused until it answers `Get-ShopifyLiveThemeId`.

**Score:** 3

#### Pull Request

guard-live-theme refuses Admin GraphQL theme writes through 'shopify store execute'

