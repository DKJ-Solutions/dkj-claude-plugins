## feat/product-connectors-specialists

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

The owner: add the Connectors page, and the Specialists page too, to the product of dkj-claude-plugins. Chosen
from a menu: move them, like the brand book, so the product port shows them and the hub no longer links them.
The pages stay built by the hub (they run check-connectors.ps1 and read this tree), and the product's dev server
relays them. The state file the hook writes could not name the hub on this machine (none was present), so the
product finds the hub by asking its ports for `/whoami`.

### CREATE

- [x] Hub: `/whoami` answers `Get-DevPreviewRootHash` of its root, before the restart check
- [x] Hub: `Get-RepositoryPages` lists Test gate alone; Connectors and Specialists are still served, for the relay
- [x] `brandbook/vite.config.ts`: find this checkout's hub on 4870-4879 by `/whoami`, relay `/connectors`, `/specialists` and `/refresh?page=connectors`
- [x] `brandbook/root.html`: a Plugins section linking both pages
- [x] Docstrings and `brandbook/README.md`
- [x] Then DKJ repos too (the owner, same day): relayed with its refresh, a DKJ-Solutions section on the product root, and the hub's home keeps About this repo alone (`Get-RepositoryDkjPages` goes)

- [x] Then a site header on both ports (the owner, same day; chosen from a menu: header on top, the bar under it on paper with a subtle line, a text wordmark): `.site-header` in `house-style.css` and its README section, `Format-SiteHeaderHtml` and an opt-in `-Brand` in dkj-policy's page shell, every page of the hub and the product root, the eyebrow gone under it, the checksum in the house-style skill
- [x] Then 'repository' after the name on the hub, as 'product' on the product port (the relayed pages say 'product'), and one theme for both ports: the product root takes the hub's lilac and theme key
- [x] Then compact (the owner, same day): no heading above 32px, so `--text-h1` 48 -> 32 in `house-style.css` (the hero figure with it), its README and checksum; the home pages' h1 repeated the header, so it is `.sr-only` there under a site header
- [x] Then the home pages' whole intro goes (the owner, same day): under a site header `Format-RepoHomeHeadHtml` writes no h1 and no lead, and the product root drops its own
- [x] Then About this repo onto the home page (the owner, same day): `Format-RepoAboutBodyHtml` (the Pages block and the facts) and the footer note on `/`, `Format-RepoAboutHtml` gone, `/about` a 303 to `/`
- [x] Then Facts as one card (the owner, same day; chosen from a menu): its title an `h3` in the card's head, no `grid-2`/`grid__head` around it, so the h2-in-a-card rule (#3175) and its gate hold
- [x] Then each general page its own card (the owner, same day): under the Pages `h2`, This repo across the row, then Artifacts, Issues, Release notes and SessionStart as a card each, two to a row; one card says so when the general pages server is not running

### TEST

- [x] `dev-pages.tests.ps1` (283 passed), `connector-dashboard.tests.ps1` (197 passed, `/whoami` asserted), `npm run gate` green
- [x] After the header: `dev-pages` (286), `connector-dashboard` (197), `dev-preview-sessionstart` (309), `check-house-style` (88) all green, `npm run gate` green, the gate itself OK; every page on both ports carries the header and no eyebrow or floating button, looked at in the browser
- [x] Live: the hub's `/whoami` equals the hash the dev server computes (`b8e66305`); on 5173 `/connectors` and `/specialists` answer 200 with Home on `/`, and the refresh comes back as a 303 to `/connectors` on 5173

### DEPLOY: feat/product-connectors-specialists

This repo's product port now carries the Connectors, Specialists and DKJ repos pages beside the brand book: its
root page links all four, and the Repository (the hub) lists none of the three, so its home page holds About this
repo alone. The pages are still built by the hub,
which runs `check-connectors.ps1` and reads this tree; the product's Vite dev server (`productRoot` in
`brandbook/vite.config.ts`) finds this checkout's hub by asking ports 4870-4879 for a new `/whoami` (the root's
`Get-DevPreviewRootHash`, as the general server already answers) and relays each request, so the pages, their
Home crumb and their refresh link all stay on the product's origin. The hub keeps answering the three paths, for
that relay. The dev server computes the same hash in TypeScript, so the two must agree: the live check above
compared them, and a change to the hash in `dev-preview-rules.ps1` has to land in `vite.config.ts` too.

Both ports also open with a **site header** now, a new house-style pattern (`.site-header`): at most 72px
high on the theme's primary, the DKJ wordmark and the repo's name on the left as the way home, the settings
button on the far right. The breadcrumb bar stands right under it, on the paper with a subtle line, and the
eyebrow above each `h1` is gone, since the header names the site. The page shell in dkj-policy draws the
header only for a caller that passes `-Brand`, so every other repo's pages are unchanged, and in the house
style a breadcrumb bar changes colour only right under a site header. The header says `repository` after the name on the hub and`nproduct` on the product port, and both ports open in the same theme (lilac, one theme key).

The house style's largest heading is now 32px: `--text-h1` came down from 48px to `h2`'s size, the hero figure with it, so a page fits more on a 900px-high screen; `h1` stands apart by its capitals and colour. On the two home pages the `h1` repeated the name the header shows, so under a site header the home page has no intro at all: no `h1`, no lead, `<main>` opens on its first block. And the hub is one page now: its home holds everything About this repo held (the Pages block with This repo and each general page as a card of its own, the facts as one card titled by its own `h3`, the footer note), and `/about` sends an old link on to `/`.

**Score:** 2

#### What makes this deploy extra special

N/A: the source repo's own dev servers; no consumer's hub or product changes.

**Score:** N/A

#### Pull Request

The Connectors, Specialists and DKJ repos pages move from the Repository to the product port

