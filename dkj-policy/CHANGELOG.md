# Changelog

## [Unreleased]

**5 / 7 minor entries** <!-- pending-tally -->

### DEPLOY: feat/repo-card-split · 20261028-135859Z

A DKJ repo's own page in the hub (`/connectors/dkj/<name>`) no longer shows one wide Repo card. It shows two cards side by side, each titled with its own `h2`. **GitHub** holds visibility, open issues and PRs, the last push and the link. **This machine** holds the register check's status, the checkout, the last commit, the plugins, the checks, the drift, the manifest, the findings and the session command. The description line and the `Repo` group head are gone. Every fact now sits on one line: the last commit reads `<age> · <subject>`, cut off with an ellipsis, with the whole text on hover. A `min-width: 0` on the cards keeps the pair from widening the page into a horizontal scroll. The underlying `.grid-2` track shape is filed as #3614.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub is this repo's own dev server, so nobody who takes a release sees this page.

**Score:** N/A

#### Pull Request

A DKJ repo's page splits its Repo card into a GitHub card and a This machine card

[PR #3617](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3617)

---

### DEPLOY: fix/3610-card-slot-link-guard · 20261028-134828Z

`Format-HubCardLinkHtml` now refuses an `<a>` in any of its four markup slots. The card is already one link,
and a link inside it broke the card in the browser. A caller that passes one fails with a message naming
the slot (#3610).

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Format-HubCardLinkHtml refuses a link in its markup slots

Plugins: dkj-policy

[PR #3618](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3618)

---

### DEPLOY: fix/3613-live-push-short-flags · 20261028-133056Z

The Shopify live-theme guard now also blocks a live push written with the short flags: `-a` for
`--allow-live`, `-l` or `--live` for live, and combined clusters such as `-la`. A push naming the
live theme by name is caught through the `-a` it needs. A preview push, including one wrapped in
`powershell -Command`, and every pull stay allowed (#3613).

**Score:** 3

#### What makes this deploy extra special

A Shopify consumer's live theme is guarded against `shopify theme push -l -a` and
`-t <live name> -a`, which used to pass. A session that pushes to live has to carry the authorisation
marker however it spells the flags.

**Score:** 3

#### Pull Request

guard-live-theme catches a live push written with short flags

Plugins: dkj-subagents-shopify

[PR #3615](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3615)

---

### DEPLOY: feat/card-grid-padding · 20261028-125307Z

Every container of cards in the house style -- a `.grid-2`, a `.grid-3`, and a repo's own card grid marked with the
new house class `.card-grid` -- now keeps at least 12px of padding round its cards, so a card never touches the
edge of its group. The group stands on a surface one step off the page, and each card in it one step further, so on
a dark theme the cards read a little lighter than their group and the group a little lighter than the page (on a
light theme each step is a little darker). The DKJ repos page under Connectors is the first page to use `.card-grid`.

**Score:** 2 -- small; noticed if somebody points it out

#### What makes this deploy extra special

A DKJ-Solutions app that takes the next house-style copy sees its card groups gain 12px of padding and a surface of their own, and can put
`.card-grid` on a card grid of its own.

**Score:** 2 -- small; a slightly roomier card group in every app on its next copy

#### Pull Request

Every container of cards keeps at least 12px of padding

Plugins: dkj-policy, dkj-solutions

[PR #3612](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3612)

---

### DEPLOY: feat/lens-map-card · 20261028-095953Z

The product's `/connectors/dkj` is now a card per DKJ repo, in the hub's card form three to a row: its
GitHub facts, its checkout here and, where it is registered under `connectors/`, its status mark. Each
card opens a page of its own, `/connectors/dkj/<name>`, holding three cards:

- **Repo** -- its description, GitHub facts and link, its checkout's state and the session to copy;
- **Connector** -- what `check-connectors.ps1` reports for it, or that it is not registered;
- **Lenses** -- what its checkout's `.claude/specialists/lenses/` holds: the filled-in lenses a table, big
  to small, by id, specialist name and size, a filled-in lens still marked `VUL-IN` tagged, and the
  scaffolds one line under it. "Filled in" is read from the text (any line that is not frontmatter, a
  heading, a quote or a comment), because the `VUL-IN` marker turned out not to say it.

The DKJ page's Connected repos table, its On GitHub grid and its Issues card are gone: what each held per
repo is on that repo's page. The BWJ and Other pages are unchanged.

The shared card link, `Format-HubCardLinkHtml`, gained `-TitleBadgeHtml` (a status mark right after the
label), and its docstring now says its markup slots hold no `<a>` (#3610).

**Score:** 2

#### What makes this deploy extra special

Every hub card in a DKJ app keeps its title on one line: the house style cuts a label or `h2` that does not
fit the card's width off with an ellipsis, a mark after it keeping its place. An app takes it with the
release's pinned `house-style.css`, so a long name no longer pushes a card taller than its neighbours.

**Score:** 2

#### Pull Request

A page per DKJ repo on /connectors/dkj, holding what its specialist lenses say

Plugins: dkj-policy, dkj-solutions

[PR #3611](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3611)

---

### DEPLOY: feat/hub-to-toolbox · 20261028-002441Z

The hub is called Toolbox on screen: the session-start line opens with `Toolbox:`, the site header
tags the repo's name `toolbox`, and the first crumb on every toolbox page reads Tools instead of Home.
A product's own pages keep Home. The code, the `/hub` route and the `OwnHub` key are unchanged.

**Score:** 2

#### What makes this deploy extra special

Every user of the plugin sees the hub under its new name, Toolbox, with Tools as its first crumb;
nothing has to be done to take it.

**Score:** 2

#### Pull Request

The hub is called Toolbox, and its Home crumb Tools

Plugins: dkj-policy

[PR #3582](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3582)

---

### DEPLOY: feat/3608-default-theme-pair · 20261027-204641Z

The hub's `DefaultTheme` gains a second form beside the single theme id; the single form renders byte-identically.

**Score:** 1

#### What makes this deploy extra special

A DKJ-Solutions repo whose product opens in a light/dark theme pair can now state the same pair for the plugin's
hub and general pages, `DefaultTheme = @{ Light = 'blue'; Dark = 'sky' }` in `Get-DevPreview`, so on a dark OS the
hub no longer opens in the light theme while the product opens in the dark one. See the
[hub README](../plugins/dkj-policy/hub/README.md).

**Score:** 3

#### Pull Request

Hub: let DefaultTheme state a light/dark theme pair

Plugins: dkj-policy

[PR #3609](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3609)

---

