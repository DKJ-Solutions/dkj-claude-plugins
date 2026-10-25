# Changelog

## [Unreleased]

**2 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3468-own-hub-product-card · 20261025-191149Z

This repo's own hub now opens its grid with a Product card linking the brand book's dev server, as the plugin's
hub does in every consumer ([#3468](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3468)). The url
comes from the dev-preview hook's state file and is believed only as a plain loopback url, the plugin hub's own
rule. Where the file names none, the card says the server is not running.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

The source repo's own hub links its product, as the plugin's hub does

[PR #3469](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3469)

---

### DEPLOY: feat/3462-cut-stops-own-product · 20261025-184331Z

`cut-release.ps1` now stops this checkout's own dev-preview product when it holds a release build's folder, rather
than refusing the cut ([#3462](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3462)). The product is
the one `Get-DevPreview` states (its `Product` beside an own hub, or the server itself). Only a listener on its
ports that the hook's ownership rule reads as this checkout's is stopped, as the tree of the nearest process naming
the root, and the cut names the pid and says that the next session start restarts it. A holder it does not
recognise still refuses the cut before the gates, as it did under #3353. The cut refused at both v5.30.0 and v5.31.0
until the brandbook dev server was stopped by hand.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

cut-release stops this checkout's own product dev server instead of refusing

Plugins: dkj-policy

[PR #3466](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3466)

---

### DEPLOY: feat/3463-hub-config-drift · 20261025-183409Z

In a DKJ-Solutions repo, the dev-preview SessionStart line now names three things that keep a repo from
following a hub change ([#3463](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3463)). `OwnHub = $true`
is named as a plain fact (`own hub (OwnHub): hub releases do not reach it`), because it
stays a supported opt-out. `OpenInVsCode` with no hub port (4890-4899) routed in `.vscode/settings.json`, and a
`Name` still stated in `Get-DevPreview`, are named together as `config drift`. The source repo, which runs the
hub from its own tree, is not named for its `OwnHub`.

**Score:** 3

#### What makes this deploy extra special

A maintainer of a DKJ-Solutions repo sees on the next session's first line why a hub change did not reach
that repo, or why the hub opens in the system browser, and what to delete or route.

**Score:** 2

#### Pull Request

Hub: name the config drift that keeps a DKJ repo from following a hub change

Plugins: dkj-policy

[PR #3467](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3467)

---

### DEPLOY: docs/3461-release-title-lens · 20261025-182411Z

Rendall's lens no longer tells a cut to pass `-Title "Release version X.Y.Z"`: it says the Release name
comes from the tag and `-Title` is omitted unless the release has one theme, matching the `cut-release`
skill and the cuts since 5.26.0 (#3461).

**Score:** 1 -- prevents a cut from following the lens and writing `Release version X.Y.Z` into `history.md`'s description column again.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Rendall's lens: the release name comes from the tag; -Title is omitted unless a release has one theme

[PR #3465](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3465)

---

### DEPLOY: docs/h1-matches-breadcrumb · 20261025-145714Z

The house style now states that a page's `h1` reads exactly what its current breadcrumb reads, the same
words and the same case, so the bar and the page never name one page in two ways. The home page under a site
header carries no `h1` and is the one page the rule does not reach. The rule is in the house-style README
under "Every page: the breadcrumb bar", and the `house-style` skill names it beside the breadcrumb bar.

**Score:** 2

#### What makes this deploy extra special

A repo that builds pages on the house style gets one more rule to hold its pages to: the `h1` and the
current crumb are written from one name.

**Score:** 3

#### Pull Request

A page's h1 reads the same as its current breadcrumb

Plugins: dkj-solutions

[PR #3460](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3460)

---

