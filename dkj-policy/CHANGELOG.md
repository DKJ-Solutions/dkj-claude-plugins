# Changelog

## [Unreleased]

**3 / 6 minor entries** <!-- pending-tally -->

### DEPLOY: fix/session-line-says-hub · 20261022-190822Z

The session-start line opens with `Hub:` instead of `Repository:` (#3285 had renamed it from
`Repo hub:`). Since #3291 *Repository* is the name of a page on the hub, `/repository`, and the port
itself is called `hub` in the site header, so the line follows the port.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-policy` sees its session-start line open with `Hub:`; nothing has to be done for it.

**Score:** 2

#### Pull Request

The session-start line opens with Hub, not Repository

Plugins: dkj-policy

[PR #3295](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3295)

---

### DEPLOY: feat/site-header-everywhere · 20261022-183959Z

The site header now stands on every hub page in every DKJ-Solutions repo, not only on this repo's own pages: the
dkj-policy hub server draws it on the home page, About, Artifacts, Issues, Release notes and SessionStart, with the
repo's name and `hub` after it, the settings button in it and no eyebrow or intro under it. The brand book app
carries it too, as *DKJ brand book*, holding its preview settings, across the whole width with the contents panel under it.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions repo that takes the release sees its hub pages open with the site header, and its hub home
without the h1 and lead it had.

**Score:** 3

#### Pull Request

The site header on every page: the general pages in every repo, and the brand book app

Plugins: dkj-policy, dkj-solutions

[PR #3293](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3293)

---

### DEPLOY: feat/product-root-cards · 20261022-174227Z

The product's home page (`brandbook/root.html`, on the product port) now has the hub's form: its four pages,
the brand book, Connectors, Specialists and DKJ repos, are a card each, three to a row, with no headings above
them, and a footer note says where each comes from.

**Score:** 1

#### What makes this deploy extra special

N/A: the source repo's own dev server.

**Score:** N/A

#### Pull Request

The product's home page takes the hub's form: only cards, no headings

[PR #3292](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3292)

---

### DEPLOY: feat/product-connectors-specialists · 20261022-132050Z

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
style a breadcrumb bar changes colour only right under a site header. The house style also gains `.grid-3`, `.grid-2`'s group three to a row, and `.facts--row`, the facts as one row on the page. The header says `hub` after the name on the hub and`nproduct` on the product port, and both ports open in the same theme (lilac, one theme key).

The house style's largest heading is now 32px: `--text-h1` came down from 48px to `h2`'s size, the hero figure with it, so a page fits more on a 900px-high screen; `h1` stands apart by its capitals and colour. On the two home pages the `h1` repeated the name the header shows, so under a site header the home page has no intro at all: no `h1`, no lead, `<main>` opens on its first block. And the hub is one page now: its home holds everything About this repo held (every page as a card of its own, three to a row and with no heading above them, and the footer note); a new Repository page (`/repository`) holds the GitHub repo's facts as one row of label-over-value (`.facts--row`, new in the house style, since every card is a link and the facts are not), the Issues page and its pull requests and Actions on GitHub, and `/about` sends an old link on to `/`.

**Score:** 2

#### What makes this deploy extra special

N/A: the source repo's own dev servers; no consumer's hub or product changes.

**Score:** N/A

#### Pull Request

The Connectors, Specialists and DKJ repos pages move from the Repository to the product port

Plugins: dkj-policy, dkj-solutions

[PR #3291](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3291)

---

### DEPLOY: fix/hub-without-brandbook · 20261022-103726Z

This repo's Repository (the hub on port 4870) no longer shows the brand book: its home page drops the Brandbook
link, its section is now called DKJ-Solutions and holds the DKJ repos page alone, and `/brandbook` is a 404
there. The hub had served a build of the `brandbook/` app at `/brandbook/` since #3210, rebuilding it with npm
on a stale visit; since #3283 the same app runs as this repo's product on a port of its own, from the tree, so
one brand book was visible on two ports. The product port is now the one place, and it starts at the root:
in dev, `/` is a page of its own (`brandbook/root.html`) linking the brand book at `/brandbook/`, and the
dev-preview hook hands out that root. The brand book's Home crumb, which pointed at a `/` the Vite server did not
answer, now lands on it (#3286). The shared General card, in
dkj-policy's `general-pages-lib.ps1`, no longer says the general pages server is not running when it is
handed no server rows, since it links nothing of that server. Every other DKJ-Solutions repo still gets the
brand book from the dkj-solutions plugin, unchanged.

**Score:** 2

#### What makes this deploy extra special

N/A: the source repo's own hub; no consumer's hub or brand book changes.

**Score:** N/A

#### Pull Request

The brand book lives on the product port alone, which starts at a root page linking it

Plugins: dkj-policy, dkj-solutions

[PR #3287](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3287)

---

### DEPLOY: feat/rename-repo-hub-to-repository · 20261022-095044Z

The Repo hub is now called the Repository, everywhere: the session-start line, the docs, the house-style
reference pages, and the functions, file and state file behind it (`Format-PluginRepositoryHtml`,
`hub/lib/repository-page.ps1`, `%TEMP%\dkj-repository-<leaf>-<hash>.json`). A hub server started under
the previous version is restarted at the next session start, as it already is on any version change, so
the new state file name needs nothing done by hand.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-policy` sees its session-start line open with `Repository:` instead of
`Repo hub:`; nothing has to be done for it. A repo that builds its own hub and calls the general banner
function calls it by its new name, `Format-RepositoryBanner` (it was `Format-RepoHubBanner`); no
consumer checkout on this machine calls the old one.

**Score:** 2

#### Pull Request

Rename the Repo hub to Repository

Plugins: dkj-policy, dkj-solutions

[PR #3285](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3285)

---

