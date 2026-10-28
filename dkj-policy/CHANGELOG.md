# Changelog

## [Unreleased]

**3 / 3 minor entries** <!-- pending-tally -->

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

