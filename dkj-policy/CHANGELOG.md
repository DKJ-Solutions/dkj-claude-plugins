# Changelog

## [Unreleased]

**5 / 8 minor entries** <!-- pending-tally -->

### DEPLOY: docs/3528-house-style-h2-18px · 20261026-154751Z

The house-style README's Type row now gives `h2` as 18px, matching `--text-h2` in the stylesheet; it
still read 24px after the token moved on October 25, 2026
([#3528](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3528)).

**Score:** 1

#### What makes this deploy extra special

A DKJ-Solutions app author reading the house-style rules no longer gets a wrong `h2` size; the
stylesheet itself did not change.

**Score:** 1

#### Pull Request

House-style README states h2 at 18px

Plugins: dkj-solutions

[PR #3530](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3530)

---

### DEPLOY: feat/3518-closed-message-phone-factory · 20261026-153748Z

`bwj-development`'s `closed-message-sessioncheck` now checks `phone-factory` too, for the
`asana-closed-message` workflow alone. That repo adopted it on October 26, 2026
(BWJ-Development/phone-factory#15), so a missing or drifted copy, a missing `ASANA_PAT` or an unstated
`Get-ResolvesExemptMatchers` is reported there at session start. `adopt-bwj-development` step 1 copies that
pair there and leaves `asana-prio-label` out, because that workflow was not decided there
([#3518](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3518)).

**Score:** 2

#### What makes this deploy extra special

phone-factory's maintainer gets the same session-start warning the two stores get when the closed message
cannot reach the Asana task. The measured case is phone-factory's own: #3's closed message failed on a missing
`ASANA_PAT`, and nothing in the session reported it.

**Score:** 2

#### Pull Request

bwj-development: extend asana-closed-message reach to phone-factory

Plugins: bwj-development

[PR #3529](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3529)

---

### DEPLOY: fix/3524-armed-ship-clearance · 20261026-151651Z

A close-out after a backgrounded ship no longer tells the requester to keep the session open when the PR
is already armed `merge-when-green` and the checkout is back on `main`. Chris's persona and manual now
name that case as a plain clearance, matching the line `ship-pr` has printed since #3442. The second-session
advice stays for what really dies with the harness: an unarmed ship, a subagent, a local-only wait. The
`ship-pr` skill page adds why the run must not go through `tail`: the clearance line never reaches the
session until the run ends (#3524).

**Score:** 2

#### What makes this deploy extra special

In a consuming repo, the orchestrator stops warning that a session must stay open while an armed pull
request ships, and says plainly that it can be cleared.

**Score:** 2

#### Pull Request

Clear the session plainly when a backgrounded ship is armed merge-when-green

Plugins: dkj-policy, dkj-subagents-alpha

[PR #3527](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3527)

---

### DEPLOY: fix/brandbook-shared-theme · 20261026-145517Z

The brand book now opens in the product's theme, lilac, and keeps whatever theme was picked on any other page of
the product port, because it stores the pick under the same `general-pages` key. A repo preview inside it still
opens in that repo's own default theme while no theme has been picked.

**Score:** 2

#### What makes this deploy extra special

N/A: the brand book is this repo's own dev preview; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The brand book shares the product's theme: lilac by default, under the general-pages key

[PR #3526](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3526)

---

### DEPLOY: fix/3473-drop-local-timing-hooks · 20261026-143209Z

This repo no longer wires the Stopwatch and Logbook hooks itself in `.claude/settings.json`
([#3473](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3473)). The installed release ships them in
`dkj-policy`'s own `hooks/hooks.json` since #3470, so each prompt and each turn's end ran both hooks twice; the
second copy was a no-op under the store's mutex and cost two extra PowerShell processes per event.

**Score:** 1

#### What makes this deploy extra special

A change to this repo's own harness config; it reaches no reader who takes the next version.

**Score:** N/A

#### Pull Request

Drop this repo's own Stopwatch and Logbook hook wiring

Plugins: dkj-policy

[PR #3525](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3525)

---

### DEPLOY: feat/logbook-speed-tones · 20261026-141646Z

The hub's Logbook overview colours each finished run's time line by its work time: green under 15 minutes, orange under 45, red
from 45 on. The time spent waiting on the owner does not count, and a run
whose work time was not measured is read off its whole time. The page footer names the bounds.

**Score:** 2

#### What makes this deploy extra special

Every repo running the dkj-policy hub sees at a glance which assignments were quick and which ran long, without reading each card's time.

**Score:** 2

#### Pull Request

Logbook cards coloured green, orange or red by work time

Plugins: dkj-policy

[PR #3522](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3522)

---

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

