# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

