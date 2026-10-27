# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

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

