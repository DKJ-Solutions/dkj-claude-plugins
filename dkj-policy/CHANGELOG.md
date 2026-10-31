# Changelog

## [Unreleased]

**3 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: feat/house-style-on-product · 20261031-111530Z

The house style's specimens are on this repo's product, at `/marketplace/dkj-policy/house-style` with a page per
section and a card on the product's dkj-policy page, read from this tree on every request. The toolbox here
sends its own house-style pages there once a release carries the redirect; in every other repo the toolbox
keeps serving them, since only the source repo holds the canonical `specimens.html`.

A plugin's page on the product has no Description card any more: its description is behind a "?" right of the
`h1`, shown as a tooltip while the pointer is on it or it has focus. `Format-GeneralPageHtml` takes it as `-Info`,
and the house style gains `.page-title`, the `h1` and its `.page-info-button` on one row, so a page still opens on its
`h1` alone (#3585).

**Score:** 2

#### What makes this deploy extra special

Every plugin's own description is rewritten for the person who installs it: what it gives you, when to enable it and
what it needs, without the internal terms the old ones were written in. It is the text `claude plugin details` and
the toolbox's Plugins page show, so it reaches every user with the next release. The redirect itself fires only in
the house style's source repo, so no consumer's toolbox changes.

**Score:** 2

#### Pull Request

The house style's specimens on the product port; the toolbox redirects there in the source repo

Plugins: bwj-development, dkj-policy, dkj-solutions, dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #3702](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3702)

---

### DEPLOY: fix/3698-house-style-scss-interpolation · 20261030-175934Z

`check-house-style` reads an SCSS interpolation (`.a-#{$n}`) in a stylesheet as part of the selector
it sits in, so an interpolated rule of the repo's own scopes the house classes nested inside it, like any
other domain class ([#3698](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3698)).

**Score:** 1

#### What makes this deploy extra special

A DKJ-Solutions repo whose SCSS nests a house class inside an interpolated selector of its own no longer
gets a `[redefine]` finding for it.

**Score:** 2

#### Pull Request

check-house-style still flags a house class nested in an interpolated SCSS selector

Plugins: dkj-solutions

[PR #3700](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3700)

---

### DEPLOY: fix/3697-btn-edge-in-grid-card · 20261030-173410Z

A plain `.btn` on a card inside a `.grid-2`, `.grid-3` or `.card-grid` now draws its edge in `--muted`, so it
stays visible beside a `.btn--primary` in every theme
([#3697](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3697)). Before, its border was the card's own
edge colour, one paper step from the card, and on a dark theme it barely showed. A repo that worked around this
with a class of its own can drop that class once it takes this version.

**Score:** 2 -- a button edge that was hard to see, noticed when somebody points at it.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A plain .btn on a card inside a grid keeps a visible edge

Plugins: dkj-policy

[PR #3701](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3701)

---

### DEPLOY: fix/3694-house-style-scss-nesting · 20261030-172451Z

`check-house-style` now reads a nested rule in a `.css`, `.scss`, `.less` or `.pcss` file together with
the rules around it ([#3694](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3694)). A house
class nested inside a rule of the repo's own (a `.menu-item` rule inside `.thumb-card`) is composition,
as it already was written out flat, and no longer a `[redefine]` finding; nested only inside an element
or an at-rule it still is. The skill page says so under check 2.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo that writes its styles in SCSS no longer has to flatten its nested house-class
compositions, or allowlist them, to pass the house-style gate: the gate and the skill's own rule now
agree.

**Score:** 3

#### Pull Request

check-house-style reads a nested SCSS selector as an app-wide redefinition of a house class

Plugins: dkj-solutions

[PR #3699](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3699)

---

### DEPLOY: fix/3695-killed-product-not-reused · 20261030-165759Z

When a session starts after the trunk has moved, the dev-preview hook restarts the repo's product
server, and it now really restarts it
([#3695](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3695)). Before, a stopped server that
took more than 5 seconds to free its port was reported `already running`, and a moment later nothing
listened at all. The replacement now starts on the same port once it is free, or on the next free port
in the range. Where there is none, the line says so instead of naming a server that is gone. The hub's
restart after a plugin update follows the same rule.

**Score:** 2 -- the product link from the session start line pointed at nothing, which the owner
notices the first time they open it.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

dev-preview: a killed outdated product server is never reported as reused

Plugins: dkj-policy

[PR #3696](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3696)

---

