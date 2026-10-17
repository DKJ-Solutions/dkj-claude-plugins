## feat/3088-brandbook-v0-2-0

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

Inbound #3088 (name the breadcrumb bar) and #3089 (repoint the pin), absorbed together: both ask for
the same repoint to the brand book's `v0.2.0`, which carries dkj-brandbook#189. Verified first: the merge
of #189 is an ancestor of `v0.2.0`, and both files there hash to the values #3089 measured. Unlike
`v0.1.0` the files changed, so both vendored copies move with the pin; the safety reads the skill names
(no network call, no `eval`, no cookie, only the theme in storage, no `@import` or remote `url()`) pass,
and the README renames or retires no token, so the retired-name list stands.

### CREATE

- [x] Repoint every brand-book link in the `house-style` skill to `v0.2.0`, its commit to `a07f9fa2` and both checksums
- [x] Step 1 of "How to use it" names the breadcrumb bar on every dev-server page (#3088)
- [x] Replace the vendored copies under `scripts/dashboard/house-style/` and the plugin's `assets/house-style/`
- [x] The retired-names docstring and the test's tag asserts follow the new pin
- [x] The two dev-server pages here that lack the bar are filed, not built: #3090 (a visible result)

### TEST

- [x] `check-house-style.tests.ps1`: 58 passed, 0 failed
- [x] `connector-dashboard.tests.ps1`: 119 passed, 0 failed
- [x] `dev-preview-sessionstart.tests.ps1`: 104 passed, 0 failed

### DEPLOY: feat/3088-brandbook-v0-2-0

The `house-style` skill now fetches from the brand book's `v0.2.0` release, and its first step says that
every page a repo's dev server serves opens with the breadcrumb bar, starting at **Repo dashboard**
([#3088](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3088),
[#3089](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3089)). An app that takes the new copy
gets greyer middle steps (`--primary-4`..`-6`) in every theme, a theme picker whose dots come from the
stylesheet instead of the script, and the `.breadcrumbs` / `.breadcrumbs-bar` classes. No token was
renamed or removed, so nothing in an app's own layer has to change. The placeholder Repo dashboard this
plugin serves takes the same copy.

**Score:** 2

#### What makes this deploy extra special

A session doing visual work in a DKJ-Solutions repo now meets the breadcrumb rule in the skill it
loads first, rather than only in the brand book's README, so new dev-server pages get the bar from the
start.

**Score:** 2

#### Pull Request

house-style skill: repoint at dkj-brandbook v0.2.0 and name the breadcrumb bar
