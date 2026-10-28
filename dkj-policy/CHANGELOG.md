# Changelog

## [Unreleased]

**2 / 2 minor entries** <!-- pending-tally -->

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

