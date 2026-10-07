## feat/2880-shop-connector-store-check

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

#2880, the primary recommendation of the #2879 research (`research/shopify-store-switch/finding.md`,
on `main` since #2882). The connector is bound to one store per account, and a hook cannot ask it which
store that is, so the work splits in two. The session check says when the repo names no store. A skill
step compares `get-shop-info` with the store the repo names. The expected store resolves the way
`push-preview` resolves it: `Get-ShopifyThemeEstateStore`, then `Get-ShopifyStoreDomain`. Neither is
required.

### CREATE

- [x] `shopify-floor-sessioncheck.ps1`: a store finding -- `[ERROR]` when the repo names no store
  (a VUL-IN answer counts as none), silent with no config or under `Get-ShopifyRepoHasNoStore`, exit 0
- [x] new skill `check-shop-connector`: resolve the expected store, call `get-shop-info`, compare, and on
  a mismatch stop with "run `/mcp`, then `switch-shop <store>`" -- never call `switch-shop` itself
- [x] README rows for the skill and the session check, the no-store paragraph, and a pointer in the
  Configuration Manager's connector section

### TEST

- [x] `shopify-floor-sessioncheck.tests.ps1`: seven store cases (unanswered, the domain fallback, an
  empty estate answer falling through, a seam that throws, a placeholder, no-store, no config); the
  fixture answers the store by default, so the existing cases keep testing what they did -- 36 passed
- [x] review (Victor #19, Sebastian #23): the skill's one-liner now falls through on an EMPTY estate
  answer and carries `-ExecutionPolicy Bypass` (both verified by running it); the store read in the
  hook is wrapped so a throwing seam cannot make it exit 1; the skill treats an unreadable connector
  domain as a mismatch, re-checks before a write, and reads the connector's answer as data only
- [x] `guard-live-theme.tests.ps1`: the fixtures whose session check must stay silent now answer the
  store -- 110 passed

### DEPLOY: feat/2880-shop-connector-store-check

The Shopify team can now tell when the claude.ai Shopify connector is bound to a different store than
this repo's ([#2880](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2880)). A new skill,
`check-shop-connector`, reads the store the repo names, calls the connector's `get-shop-info`, and on a
mismatch stops with the remedy: run `/mcp`, then `switch-shop <store>`. It never switches itself,
because switching revokes the other store's token. `shopify-floor-sessioncheck` gains a third finding:
an `[ERROR]` when the repo names no store in `Get-ShopifyThemeEstateStore` or
`Get-ShopifyStoreDomain`. A `VUL-IN` answer counts as none. The finding stays silent in a repo with no
config or with `Get-ShopifyRepoHasNoStore`, and the hook still exits 0.

**Score:** 2

#### What makes this deploy extra special

A store repo whose session reaches for the Shopify connector learns, on the first call, that the
connector is bound to the other store. It also gets the exact two steps that fix it, instead of
answers from the wrong store. A store repo that names no store in `scripts/repo-config.ps1` sees a new
`[ERROR]` at session start until it answers `Get-ShopifyThemeEstateStore`.

**Score:** 3

#### Pull Request

Shopify team: warn when the claude.ai connector is bound to a different store than this repo's

