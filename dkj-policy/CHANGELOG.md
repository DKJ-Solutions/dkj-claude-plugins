# Changelog

## [Unreleased]

**2 / 3 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3097-dev-server-pages · 20261018-074844Z

This repo's dev server has three pages under the Repo dashboard: **Connectors** (`/connectors`, the
connector overview `/` shows), **SessionStart** (`/sessionstart`, the always-on document path every
session loads, per document, against its budget) and **Test gate** (`/test-gate`, the per-suite CI
durations from `scripts/tests/suite-durations.json`, and the suites not recorded yet). The hub that
links them from `/` follows once the brand book releases its index block
([#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)).

**Score:** 3

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Dev server: the connector overview at /connectors, and pages for the SessionStart and test-gate measurements

[PR #3101](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3101)

---

### DEPLOY: fix/3096-tidy-lane11-remote-plugins · 20261017-223402Z

`tidy-machine`'s lane 11 no longer reports a url-sourced plugin, such as `figma` from the official
marketplace, as retired, and no longer hands over an uninstall of it: it reads the marketplace clone with
`-IncludeRemote`, so a plugin the manifest still names counts as listed whether or not the clone holds a
copy ([#3096](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3096)).

**Score:** 3

#### What makes this deploy extra special

Anyone running `tidy-machine` with a url-sourced plugin installed was told to uninstall a live plugin;
pasting that command removed it.

**Score:** 3

#### Pull Request

tidy-machine lane 11: a url-sourced plugin is no longer reported as retired

Plugins: dkj-policy

[PR #3099](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3099)

---

### DEPLOY: fix/3095-house-style-property-access · 20261017-221912Z

`check-house-style` no longer reads a property access inside a call's closing parens, followed by an
object literal, as a selector styling a house class: a "selector" with an unbalanced paren is skipped,
and nested functional pseudo-classes now fold fully
([#3095](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3095)).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo whose script reads a property named like a house class (`.sort`, `.card`) and
passes an object literal on the same statement no longer gets a red house-style gate it cannot act on.

**Score:** 2

#### Pull Request

check-house-style: a property access followed by an object literal is no selector

Plugins: dkj-solutions

[PR #3098](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3098)

---

