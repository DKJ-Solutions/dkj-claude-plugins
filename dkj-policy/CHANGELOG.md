# Changelog

## [Unreleased]

**6 / 15 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3675-consumers-folder · 20261030-151405Z

The register of repos that install this marketplace's plugins is now `consumers/`, the name the rest
of the tree already used for those repos, and no longer one that collides with MCP connectors
([#3675](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3675)). Its check is
`scripts/sync/check-consumers.ps1`, the dashboard server is `serve-consumer-dashboard.ps1`, and the
suites are `consumers.tests.ps1`, `consumer-sessioncheck.tests.ps1` and `consumer-dashboard.tests.ps1`.
`check-connectors.ps1` stays as a forwarder, because a hook installed before this release finds the
source checkout by that file and runs it. It can go once every install has this release.

**Score:** 1 -- the forwarder prevents a failure that has not happened: without it, every session
start beside a source checkout on `main` would read that checkout as absent until its plugins were
updated.

#### What makes this deploy extra special

**The SessionStart hook is renamed: `connector-sessioncheck` is now `consumer-sessioncheck`.** That is
a public interface change. Every session start in a repo with `dkj-policy` installed prints its lines
under the new name, and the dispatcher's timing line reads `consumer` where it read `connector`.
Nothing has to be done to take it, but anything that matches the old name (a filter, a note, a
script that reads the session-start output) has to follow.

**Score:** 2

#### Pull Request

Rename connectors/ to consumers/

Plugins: bwj-development, dkj-policy, dkj-solutions, dkj-subagents-alpha, dkj-subagents-shopify

[PR #3693](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3693)

---

### DEPLOY: fix/3666-connector-check-finds-renamed-source · 20261030-144253Z

The connector session check looked for the source checkout only under the repo's old folder names, so
in a consumer beside a fresh clone named `dkj-marketplace` it reported no source checkout and skipped
the register checks without saying anything was wrong. It now finds the checkout under the new name
as well.

**Score:** 1

#### What makes this deploy extra special

A consumer session on a machine whose source checkout is named `dkj-marketplace` runs the register
checks again (consumer registration, lens inventory, agent-def drift) instead of skipping them.

**Score:** 1

#### Pull Request

The connector session check finds a source checkout named dkj-marketplace

Plugins: dkj-policy

[PR #3692](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3692)

---

### DEPLOY: docs/3689-recurrence-of-completed-issue · 20261030-141048Z

The filing rules covered a new instance of a record and of an `awaiting-recurrences-first` issue, but
not of an ordinary issue closed as *completed* whose repair did not hold. Three sessions handled the
same case two ways (#3288, #3687). [`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md)
now says what to do: comment on the closed issue, and convert it to a record in the same movement
(`awaiting-recurrences`, `[RECORD]`, the close reason changed to *not planned*, left closed).

**Score:** 2

#### What makes this deploy extra special

A session in a consuming repo that finds a recurrence of a closed, completed issue now has one route:
comment on it and make it a record, instead of filing a new issue beside it.

**Score:** 2

#### Pull Request

A recurrence of an issue closed as completed makes it a record

Plugins: dkj-policy

[PR #3690](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3690)

---

### DEPLOY: feat/3664-connectors-last-two · 20261030-134647Z

The connector register names the dkj-marketplace ids for the last two consumers, dkj-thumbnail-generator
and djcylow-react, so every registered consumer has moved
([#3664](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3664)).

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping.

**Score:** N/A

#### Pull Request

Register the last two consumers under dkj-marketplace ids

[PR #3685](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3685)

---

### DEPLOY: fix/connector-file-names · 20261030-131306Z

The connector register's rule is one `<repo>.json` per connected repo, and three manifests still
carried a retired name: `dkj-claude-plugins.json` is now `dkj-marketplace.json`, `life-hub.json` is now
`dkj-lifehub.json`, and `thumbnail-generator.json` is now `dkj-thumbnail-generator.json`. Every script
reads the file name off disk, so nothing behaves differently; the README, Sylvester's lens, one comment in
`check-connectors.ps1` and the self-manifest case in `connectors.tests.ps1` follow the new names. Test
fixtures that invent their own register files are left as they are.

**Score:** 1 -- a reader looking for a repo's record by its name no longer has to know its old one.

#### What makes this deploy extra special

N/A -- the register lives in this repo only and ships to no consumer.

**Score:** N/A

#### Pull Request

Connector manifests named after the repo they register

[PR #3688](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3688)

---

### DEPLOY: feat/marketplace-card-h2 · 20261030-125902Z

The hub's Marketplace overview no longer carries a `dkj-marketplace` h2 above its cards; each card's title
(`dkj-subagents`, `dkj-policy`) is the page's h2 instead.

**Score:** 1

#### What makes this deploy extra special

N/A -- a dev-hub page of this repo; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The Marketplace overview drops its section h2, and its cards' titles are h2s

[PR #3686](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3686)

---

### DEPLOY: fix/product-header-name · 20261030-123223Z

The product server's site header and page titles named the repo `dkj-claude-plugins`, its name before the
rename; they name it `dkj-marketplace` now.

**Score:** 2

#### What makes this deploy extra special

N/A -- the product server is this repo's own development hub; no consumer takes it.

**Score:** N/A

#### Pull Request

The product pages name the repo dkj-marketplace again

[PR #3684](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3684)

---

### DEPLOY: feat/connectors-group-sections · 20261030-114237Z

The Consumers page is now three sections, DKJ, BWJ and Other, each under an h2 of its own. Under each sit that group's repo cards, one level up from where they
were and an h3 each: every DKJ repo's card, as on the DKJ page, and a card per registered BWJ and Other repo
that opens its details on the group's page. The pages moved from `/connectors` to `/consumers`, so the url matches their h1 Consumers; an old
address lands on its new page.

**Score:** 2

#### What makes this deploy extra special

N/A -- a page of this repo's own dev server, which no consumer runs.

**Score:** N/A

#### Pull Request

The Consumers page shows each owner group as a section with its repos' cards

[PR #3682](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3682)

---

### DEPLOY: fix/marketplace-teams-page · 20261030-104603Z

`/marketplace/dkj-subagents` is the specialist teams' page again, and it now groups them: the core team
alone under an **Alpha** heading, the other teams under **Extensions**. The move of dkj-policy's
add-ons onto its own page (in #3680, the same day) had made the server read that address as a plugin
called `dkj-subagents`, which does not exist, so it answered 404. The address is now parsed in one lib
function, `Resolve-MarketplaceAddress`, which a unit test holds to every level; the server's own fixture has
no teams, so its 404 assert could not tell the two readings apart.

**Score:** 3

#### What makes this deploy extra special

N/A: the product hub runs only in this repo's own checkout; no consumer serves it.

**Score:** N/A

#### Pull Request

/marketplace/dkj-subagents shows the specialist teams again instead of a 404

[PR #3681](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3681)

---

### DEPLOY: feat/hub-performance-card · 20261030-095251Z

The hub's home page has a Performance card in SessionStart's place. Its `/performance` page holds the
SessionStart and Clock cards, and the Clock keeps the Test gate, the Stopwatch and the Logbook. Every page
under those two now has Performance in its trail, and the hub shows a page that sits two groups deep under
its top-level group's card.

**Score:** 2

#### What makes this deploy extra special

A user of any repo's toolbox finds SessionStart and the Clock one click deeper, behind the new Performance card.

**Score:** 2

#### Pull Request

A Performance card on the hub, holding SessionStart and Clock

Plugins: dkj-policy

[PR #3678](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3678)

---

### DEPLOY: feat/marketplace-section-head · 20261030-093702Z

The product's Marketplace overview opens its card grid with an h2 naming the marketplace, `dkj-marketplace`,
and its cards carry h3 titles under it. dkj-policy's two add-ons, bwj-development and dkj-solutions, moved
off the overview into an Add-ons section at the top of dkj-policy's own page, each at `/marketplace/dkj-policy/<name>`. The Marketplace pages moved from `/plugins` to `/marketplace`,
so a page's url matches its h1; every old `/plugins` address answers a 303 to the same page under
`/marketplace`, and the old Specialists addresses now land there directly.

**Score:** 2

#### What makes this deploy extra special

The product's local dev pages are this repo's own; nobody who takes a release sees them.

**Score:** N/A

#### Pull Request

The Marketplace page moves to /marketplace and groups its cards under a dkj-marketplace heading

[PR #3680](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3680)

---

### DEPLOY: feat/plugins-page-sections · 20261030-092308Z

The hub's Installed plugins page now splits its cards into two sections, each with an h2: **dkj-marketplace**
for the plugins from this marketplace, and **MCP** for those from any other marketplace (Figma's). The card
names under them are h3s, and a section with no card in it is left out. `Format-HubCardLinkHtml` takes
`-Heading 3` for this.

**Score:** 2

#### What makes this deploy extra special

The plugins page in every DKJ repo's hub is grouped by where a plugin comes from, so the Figma connector no
longer sits between the DKJ plugins.

**Score:** 2

#### Pull Request

Plugins page grouped under dkj-marketplace and MCP headings

Plugins: dkj-policy

[PR #3679](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3679)

---

### DEPLOY: feat/toolbox-ai-cards · 20261030-084927Z

The Toolbox has an AI card. Its page holds a Claude section, an h2 over three cards titled with an h3: Rules, Skills
and Specialists, each a landing page of its own with nothing on it yet (Tools > AI > Rules). Hub groups can now nest,
and a `Section` group is a heading on its parent's page instead of a card and a page. The Specialists page holds a Lenses section, which
has a card for every specialist lens the repo keeps in `.claude/specialists/lenses/`, named after its file, and
each opens on a page with that lens's text.

The house style no longer gives a headed group (a `.grid-2` or `.grid-3` opening on a `.grid__head`) an extra
`--spacing-5` above it in the page column: the column's own `gap` is now the only space between its blocks, on every
page that renders with `house-style.css`.

**Score:** 2

#### What makes this deploy extra special

Every repo's Toolbox shows the new AI card, though the pages under it are still empty. And every DKJ-Solutions page
that groups cards under an h2 sits a little tighter: the group loses the extra space above it.

**Score:** 2

#### Pull Request

An AI card on the Toolbox, with a Claude card holding Rules, Skills and Specialists

Plugins: dkj-policy

[PR #3676](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3676)

---

### DEPLOY: feat/3672-register-mesowise · 20261029-231733Z

The connector register now names dkj-maplestory-classic-mesowise, so the session check covers its
plugins and a later rename or marketplace move lists it among the consumers
([#3672](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3672)).

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping.

**Score:** N/A

#### Pull Request

Register dkj-maplestory-classic-mesowise in connectors/

[PR #3674](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3674)

---

### DEPLOY: feat/3664-connectors-new-ids · 20261029-225335Z

The connector register names the dkj-marketplace ids for the three consumers that have migrated:
dkj-lifehub, smartwatchbanden and xoxowildhearts. Two consumers remain on the old ids until they move
([#3664](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3664)).

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping.

**Score:** N/A

#### Pull Request

Register the three migrated consumers under dkj-marketplace ids

[PR #3673](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3673)

---

