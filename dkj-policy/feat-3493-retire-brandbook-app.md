## feat/3493-retire-brandbook-app

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

The rest of #3493 after #3521 (which promoted the components and gave house-style.css its own CSS gate): points 3
and 4, and the app itself. Point 3, the check by eye, becomes a House style page on this repo's hub; point 4, the
product port's root page, goes with the product port, so its three pages (Connectors, Specialists, DKJ repos)
are linked from the hub again. Then `brandbook/`, its workflow and every reference to it are removed.

A house-style page is a visible result, so this branch stops for the owner's look instead of merging.

### CREATE

- [x] Gwen: `scripts/dashboard/house-style-specimens.html`, a body fragment with every token, the twelve themes and
  every component with its variants and states, on house classes plus a layout-only `.spec-*` layer
- [x] Sylvester: `/house-style` on the hub (`Format-HouseStylePageHtml`, read from the tree per request); the hub
  links House style, Connectors, Specialists and DKJ repos; the Product card and the `product` header tag go;
  four hub icons in the plugin's `$script:HubIcons`
- [x] Sylvester: `Get-DevPreview` states no `Product`; the app's eleven `Get-HouseStyleAllowlist` entries go
- [x] `brandbook/` and `.github/workflows/brandbook.yml` deleted; this checkout's running Vite server stopped
- [x] Tessa: the house-style README, the dkj-solutions and hub READMEs, Cody's lens (back to the empty scaffold)
  and Gwen's lens; three stale plugin script comments
- [x] Fixture paths in two suites no longer name `brandbook/`

### TEST

- [x] `dev-pages` (350), `connector-dashboard` (226), `ci-suite-selection-lib` (49), `affected-suites` (194) green
- [x] `check-house-style` green over the tree, the specimens page included
- [ ] The owner's look at `/house-style` on the hub, at full width and at 360px

### DEPLOY: feat/3493-retire-brandbook-app

This repo's `brandbook/` app is retired ([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)),
so the house style is the one place DKJ styling lives. A house-style change is judged on the hub's new House
style page, which shows every token, theme and component from the tree as it is edited; the hub links
Connectors, Specialists and DKJ repos again, and the session start no longer starts a product server.

**Score:** 3

#### What makes this deploy extra special

N/A: the app and its product port were this repo's own dev preview; no consumer ever received them since #3477.

**Score:** N/A

#### Pull Request

Retire the brandbook app: a house-style specimen page on the hub, the product pages back on it
