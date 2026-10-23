# Changelog

## [Unreleased]

**9 / 14 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3309-ci-path-aware-suites · 20261023-003225Z

A pull request here that changes only stylesheets, images or fonts no longer waits on every test
suite in CI. The required check runs just the suites that read those files (3 to 6 of 165 for a CSS
change, where it used to run all of them over five shards), and the Linux leg skips. Every other pull
request runs the whole pool as before.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Path-aware suite selection on the required CI check

Plugins: dkj-policy

[PR #3311](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3311)

---

### DEPLOY: feat/3289-one-page-hub · 20261022-214353Z

The hub ([#3289](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3289)) is one page in every repo
now, not a home page that links an About this repo page. The plugin's hub home page holds the Products section
(or the setup cards), the General pages, the facts, the Brand book in a DKJ-Solutions repo, and a footer note.
`/about` answers 303 to `/`, so an old link still lands. The house-style README's "The hub" lays the one page
down as one table, and its stylesheet-only reference is the single
[`patterns/repo-dashboard.html`](../plugins/dkj-policy/dkj-solutions/assets/house-style/patterns/repo-dashboard.html),
under a site header. `repo-about.html` is gone.

**Score:** 3

#### What makes this deploy extra special

The hub that every repo's session start links is one page: the General pages and the facts are on it, so they
no longer sit one click away on About this repo. A repo that copied the two stylesheet-only patterns now has one
pattern to follow.

**Score:** 3

#### Pull Request

Every repo's hub is one page: About this repo folds into the home page

Plugins: dkj-policy, dkj-solutions

[PR #3308](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3308)

---

### DEPLOY: fix/3303-page-column-padding · 20261022-213405Z

The house style's page column (`.page-column`) sits closer under the header: it takes its own padding
of `--spacing-4` on top, sides `--spacing-4` and `--spacing-12` at the bottom, where `<main>` gave it
`--spacing-6` on top (#3303).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that takes the new `house-style.css` gets the tighter top on every page built on
`.page-column` without changing anything of its own.

**Score:** 2

#### Pull Request

The page column sits closer under the header: .page-column takes its own padding

Plugins: dkj-solutions

[PR #3310](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3310)

---

### DEPLOY: fix/3302-warning-1-darker-on-dark · 20261022-211931Z

The house style's warning background (`--warning-1`) is darker on the dark themes: `#2b1f0c` instead
of `#3a2a10`, the same lightness as the negative-message background beside it, so a notice no longer
reads as a lighter patch on a dark page. Light themes are unchanged (#3302).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that takes the new `house-style.css` gets the darker notice background on every
dark theme without changing anything of its own.

**Score:** 2

#### Pull Request

--warning-1 is darker on the dark themes

Plugins: dkj-solutions

[PR #3306](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3306)

---

### DEPLOY: fix/3304-visible-park-no-full-gate · 20261022-201122Z

A sweep that parks a visible result for the owner's look no longer runs `open-pr.ps1 -GatesOnly`
first. That run covered the whole suite pool, took about ten minutes even for a two-value colour
change, and was repeated anyway when the approved branch ships: `ship-pr` and the required CI check
both gate it before the merge.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A visible park in a sweep no longer runs the full gate pool first

Plugins: dkj-policy

[PR #3307](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3307)

---

### DEPLOY: fix/3301-site-header-mark-hugs-initials · 20261022-200117Z

The site header's mark ([#3301](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3301)) was a fixed
40px square with 12px initials in it, so most of it was empty space above and below the letters. It now sizes to
its initials: a thin padding round a `--text-h2` line, which makes the letters, and the mark, larger. The same
re-pin of [`house-style.css`](../plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css) carries
[#3299](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3299): two comments that still called the
hub "the Repository" now say "the hub's".

**Score:** 1

#### What makes this deploy extra special

Every page with a site header (each repo's hub, the brand book, and any app that uses the pattern) shows a
larger mark whose edges sit close to its initials. It is noticed when somebody points it out.

**Score:** 2

#### Pull Request

The site header's mark hugs its initials, and is larger

Plugins: dkj-solutions

[PR #3305](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3305)

---

### DEPLOY: fix/3294-hub-not-repository · 20261022-193830Z

The hub is called the hub everywhere again, now that "Repository" names the `/repository` page on it: in the
docs and comments, and in the functions, file and state file behind it (`Format-PluginRepoHubHtml`,
`hub/lib/repo-hub-page.ps1`, `%TEMP%\dkj-repo-hub-<leaf>-<hash>.json`). A hub server started under the
previous version is restarted at the next session start, as on any version change, so the state file's
name needs nothing done by hand.

**Score:** 1

#### What makes this deploy extra special

A repo that builds its own hub and calls the general banner function calls it `Format-RepoHubBanner` again
(it was `Format-RepositoryBanner` for one release); no consumer checkout on this machine calls either. The
banner's airsquats tally is kept under its pre-#3285 key again, so a count from before that release returns.

**Score:** 1

#### Pull Request

The hub is the hub again, in prose and in names

Plugins: dkj-policy, dkj-solutions

[PR #3300](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3300)

---

### DEPLOY: docs/close-records-at-once · 20261022-192118Z

A record (`awaiting-recurrences`) may now be closed as `not_planned` the moment it gets its label,
filing included, instead of only once it has gone quiet. A record is never ready work, so leaving it open
only crowds the issue list. The label and the `[RECORD]` prefix stay on, and the search before filing
already reads closed issues for that label, so a closed record is still found and reopened on its next
instance (Dave, October 22, 2026).

**Score:** 2

#### What makes this deploy extra special

A consumer's issue list can drop its records straight away. The rule is permissive, so nothing has to be
changed and no existing issue is affected.

**Score:** 2

#### Pull Request

Let a record be closed as not planned the moment it gets its label

Plugins: dkj-policy

[PR #3296](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3296)

---

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

