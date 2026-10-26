# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: feat/connectors-group-pages · 20261026-140548Z

The product's Connectors page is now an overview of three cards, one per owner group -- DKJ, BWJ and Other, in that
order, each headed by an h2 and showing its repo count and status summary -- and each card opens a page of its own
at `/connectors/dkj`, `/connectors/bwj` or `/connectors/other` holding that group's overview table and repo cards.
No Connectors page carries tiles or a lead any more. The hub serves the new paths and the product's dev server
relays them; a group page's re-run comes back to that same page.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Connectors page is this repo's own dev page; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Connectors page: one card per owner group, each with its own page

[PR #3523](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3523)

---

### DEPLOY: feat/3493-house-style-components · 20261026-135008Z

The house style gains the components that until now existed only in this repo's brandbook app, the first
step of retiring it ([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)). The CSS
gate, the checksum and an allowlist entry for the app's own copies moved with it.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app that takes the next copy of `house-style.css` gets alerts, banners, panels, chips,
tags, filter chips, steppers, a search combobox, value boxes, stat rows, bill/compare/calc tables, date
rows, figures and prose as house classes. An app that already styles a class of the same name (MesoWise:
`.chip`, `.help`, `.amount`, `.calc`, `.verdict`, `.question-head`) now collides with the house name, and
its `check-house-style` gate says so: it renames its class or adopts the house one.

**Score:** 4

#### Pull Request

House style: the brandbook app's missing components move into house-style.css

Plugins: dkj-solutions

[PR #3521](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3521)

---

