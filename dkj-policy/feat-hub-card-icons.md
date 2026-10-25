## feat/hub-card-icons

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

Owner's ask (October 25, 2026): give every card on the home page an icon. A visible result, so the branch
stops for the owner's look instead of merging.

### CREATE

- [x] `general-pages-lib.ps1`: a set of line icons (`$script:HubIcons`), `Get-HubIconSvg`, and an optional `-Icon` on `Format-HubCardLinkHtml`, drawn before the label in the house `.menu-item__icon` slot
- [x] An icon key on every page a hub card links: the general pages, this repo's hub pages, the Brandbook, and the plugin hub's Product, Repository, Issues, Pull requests and Actions cards
- [x] The product port's root page (`brandbook/root.html`): an icon on its Brandbook, Connectors, Specialists and DKJ repos cards -- the home page the owner looked at first

### TEST

- [x] `dev-pages.tests.ps1`: every linked page names a known icon, every home card draws one, and a card naming none draws none; the row-shape assert now reads icon, label, description, chevron -- 319 passed
- [x] `dev-preview-sessionstart.tests.ps1` -- 359 passed
- [x] The live hub on 4871 restarted: the home page draws 7 icons, one per card

### DEPLOY: feat/hub-card-icons

Every card on a hub's home page now carries an icon before its label -- Test gate, Stopwatch, Logbook, Repository and the general pages here, and the Product, Repository, general and Brandbook cards on the plugin's hub in every other repo -- as do the cards on the Repository page. The product port's root page gives its Brandbook, Connectors, Specialists and DKJ repos cards one too. The icons are line drawings stroked in the text colour, like the chevron, set in the house style's existing `.menu-item__icon` slot, so the house stylesheet is unchanged.

**Score:** 2

#### What makes this deploy extra special

A consumer's hub home page gains an icon on every card once the plugin is updated; nothing else changes.

**Score:** 2

#### Pull Request

An icon on every card of the hub home page

