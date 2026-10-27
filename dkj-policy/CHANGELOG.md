# Changelog

## [Unreleased]

**2 / 4 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3581-first-release-bump · 20261027-141622Z

A first release in a repo with no plugins and no tag no longer gets two answers that cannot both be followed:
`cut-release` accepts `-Bump` and counts it from 0.0.0, so the tier gate's "What the pending work does earn:
-Bump minor" runs as written and cuts v0.1.0.

**Score:** 2

#### What makes this deploy extra special

A repo cutting its first release follows the refusal's own advice instead of guessing the `-Version` it implies.

**Score:** 2

#### Pull Request

cut-release accepts -Bump on a first release, so the tier gate's advice runs

Plugins: dkj-policy

[PR #3589](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3589)

---

### DEPLOY: feat/plugins-product-card · 20261027-140810Z

The product's home page gains a third card, Plugins, and `/plugins` lists every plugin
`.claude-plugin/marketplace.json` ships, one link card each saying its kind, version and whether this repo enables it -- the specialist
teams sharing one card, `dkj-subagents`, with a page of their own -- and
each plugin has its own page under it: what it holds (subagents, personas, skills, hook
commands), its source path, and its full description in paragraphs. It is the tree, read on every request. The
hub's own Plugins page stays what this checkout enables.

**Score:** 2

#### What makes this deploy extra special

N/A -- a page of this repo's own product server, which no consumer runs.

**Score:** N/A

#### Pull Request

A Plugins card on the product's home page, listing every plugin this marketplace ships

[PR #3586](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3586)

---

### DEPLOY: feat/github-hub-card · 20261027-135157Z

The hub's Repository card and page are now called **GitHub**, and the card carries the GitHub logo instead of the
branch drawing. The page still lives on `/repository`, so every existing link keeps working.

**Score:** 2

#### What makes this deploy extra special

Every repo running dkj-policy shows its hub card as GitHub, with the GitHub logo, from the next release on.

**Score:** 2

#### Pull Request

The hub's Repository card and page are called GitHub, with a GitHub logo

Plugins: dkj-policy

[PR #3583](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3583)

---

### DEPLOY: feat/3566-one-hub-card-component · 20261027-130047Z

Every card link on the hub is now the one house card. `Format-HubCardLinkHtml` gained the slots the
hand-written variants existed for: a headline figure on a line of its own, a status badge in the icon's
place, the label as an `h2`, and an `id` and extra classes. SessionStart, Plugins, Stopwatch, Logbook, Test
gate, Connectors and Specialists use it, keeping what each card shows. The suite that refuses a hand-written
card now allows only that function, so a new overview cannot add a shape of its own again.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub's overview cards look alike and keep their content; nothing changes for the person who takes
the next version beyond that.

**Score:** N/A

#### Pull Request

Hub cards: one card component, every variant moved onto it

Plugins: dkj-policy, dkj-solutions

[PR #3579](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3579)

---

