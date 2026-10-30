# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

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

