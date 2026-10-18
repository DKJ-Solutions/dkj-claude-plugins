# Changelog

## [Unreleased]

**4 / 9 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3094-default-theme-lilac · 20261018-115225Z

The dev server's pages (the connector dashboard, the repo hub and the pages it links) open in the
brand book's `lilac` theme, this repo's default, instead of following the OS between `teal` and `sky`.
A theme a viewer picked by hand still wins.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Dev server: the pages default to the brand book's lilac theme

[PR #3111](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3111)

---

### DEPLOY: feat/3097-repo-hub · 20261018-111834Z

The dev server's index (`/`) in this repo is now the **Repo hub**: a page in dkj-brandbook v0.3.0's form
whose Pages card links the connector overview (now at `/connectors`), the release notes, the SessionStart
measurements and the test-gate durations
([#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)). Every page's breadcrumb starts
at Repo hub.

**Score:** 3

#### What makes this deploy extra special

In every DKJ-Solutions repo the session-start line now opens with `Repo hub:` instead of
`Repo dashboard:`, and the placeholder page carries the same name, the term the brand book adopted in
v0.3.0. Nothing to do: a repo's own index takes the new name when it next follows the brand book.

**Score:** 2

#### Pull Request

Dev server: the Repo hub on / links connectors, release notes, SessionStart and test gate

Plugins: dkj-solutions

[PR #3109](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3109)

---

### DEPLOY: fix/3106-repoint-body-refresh · 20261018-101158Z

The pull request the house-style repoint runner opens now tells its reader to ship with
`ship-pr.ps1 -RefreshBody` once the DEPLOY tiers are scored
([#3106](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3106)). Its body is not open-pr's
and carries no DEPLOY section, so the branch-entry check and ship-pr's DEPLOY lock refused every such
pull request until somebody found that step by hand, as #3105 did. Only this repo's own CI is touched.

**Score:** 2

#### What makes this deploy extra special

N/A -- a CI workflow of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

House-style repoint PR body names ship-pr -RefreshBody after scoring

[PR #3107](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3107)

---

### DEPLOY: feat/house-style-v0-3-0 · 20261018-093108Z

The `house-style` skill now fetches from the brand book's `v0.3.0` release
([DKJ-Solutions/dkj-brandbook@v0.3.0](https://github.com/DKJ-Solutions/dkj-brandbook/releases/tag/v0.3.0)). Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.

**Score:** 2

#### What makes this deploy extra special

An app that takes the new copy can declare one default theme with `<html data-theme-default="teal">`
instead of a light/dark pair, and can build a navigation list of links with `a.menu-item` and a one-line
`.menu-item__sub` description. Both are opt-in: an app that changes nothing renders exactly as before,
since `data-theme-light`/`data-theme-dark` are still read and no token was renamed or removed.

**Score:** 2

#### Pull Request

house-style skill: repoint at dkj-brandbook v0.3.0

Plugins: dkj-solutions

[PR #3105](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3105)

---

### DEPLOY: fix/3103-repoint-absent-branch · 20261018-090522Z

The house-style repoint runner's open-PR check no longer fails on the first run for a brand-book release:
`git ls-remote --exit-code` answering 2 for an absent branch was left in `$LASTEXITCODE`, which the
runner's appended `exit $LASTEXITCODE` turned into a failed step, so no repoint pull request was ever
opened (run 39112387739, `v0.3.0`). The step now treats 0 and 2 as answers, fails on any other exit, and
ends with an explicit `exit 0`. Only this repo's own CI is touched.

**Score:** 3

#### What makes this deploy extra special

N/A -- a CI workflow of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

the house-style repoint workflow no longer fails when its branch is not on origin yet

[PR #3104](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3104)

---

### DEPLOY: feat/3100-house-style-auto-repoint · 20261018-082828Z

A dkj-brandbook release now reaches this repo as a pull request within a day, opened by a scheduled
runner ([#3100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3100)). It repoints the
`house-style` skill's links, commit and checksums, updates the retired-name list and replaces both
vendored copies; a file carrying a spelling the skill forbids stops it before any pull request, and a
changed theme script waits for a person to read its diff. It never merges: whoever ships it scores the
entry. Nothing changes for a repo that uses the house style until
such a repoint is released.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

house-style: open the repoint PR automatically on a dkj-brandbook release

Plugins: dkj-solutions

[PR #3102](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3102)

---

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

