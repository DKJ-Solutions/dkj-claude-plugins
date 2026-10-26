# Changelog

## [Unreleased]

**2 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: feat/sessionstart-section-pages · 20261026-213937Z

The hub's SessionStart page was one long column of seven sections, each a wide table or block, so finding
one part meant scrolling past the rest. It is now shaped like the Stopwatch page: an overview of seven
cards, each naming its section with one headline figure (the path against the budget, the efficiency
score, the open actions), and each opening a page of its own at `/sessionstart/<section>`. A failed or
over-budget measurement is still warned about on the overview.

**Score:** 3

#### What makes this deploy extra special

Every repo running the hub gets the new SessionStart overview on its next plugin update: the same numbers,
now one card per section, each with its own page.

**Score:** 2

#### Pull Request

SessionStart: one card and one page per section

Plugins: dkj-policy

[PR #3543](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3543)

---

### DEPLOY: feat/dkj-repos-cards · 20261026-194924Z

The hub's DKJ repos page is now one card per repo, three to a row like the Stopwatch overview, under the page's h1: the four tiles, the lead and the Repos heading are gone, and each checked-out repo's session command, with its Copy button, sits in that repo's own card instead of a list of its own.

**Score:** 2

#### What makes this deploy extra special

N/A: a page of this repo's own hub, which no consumer takes.

**Score:** N/A

#### Pull Request

The DKJ repos page shows each repo as a card

[PR #3542](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3542)

---

### DEPLOY: feat/specialists-under-plugins · 20261026-193544Z

The hub's Specialists page now sits one level below Plugins, at `/plugins/dkj-subagents-alpha/specialists`,
linked as a card from that plugin's page instead of from the home page; `/specialists` sends an old link
there. `Format-PluginPageHtml` takes `-Cards` for a hub's own pages below a plugin.

**Score:** 2

#### What makes this deploy extra special

N/A: the new `-Cards` parameter is optional and unused on the plugin's own general pages server, so a
consumer's hub looks the same.

**Score:** N/A

#### Pull Request

Specialists page under its plugin on the hub

Plugins: dkj-policy

[PR #3541](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3541)

---

### DEPLOY: fix/3537-ignore-brandbook-residue · 20261026-175546Z

The root `.gitignore` now ignores `/brandbook/`, so the build output the retired brandbook app left behind
(`node_modules/`, `dist/`, `.vite/`) no longer makes a checkout dirty after pulling #3535, and
`cut-release`, `new-branch`, `sync-main` and `prune-merged` run there again
([#3537](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3537)).

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own checkouts only; no plugin ships it.

**Score:** N/A

#### Pull Request

Ignore the retired brandbook app's build residue at the root

[PR #3539](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3539)

---

### DEPLOY: fix/3534-logbook-sweep-own-folds · 20261026-173934Z

The hub's Logbook cuts a `/sweep-issues` run only at the folds its own session made, so two sweeps in one
checkout no longer take each other's issues as laps and count them twice. A ship's step-log marks now
name the Claude Code session that ran them; marks written before this still cut every sweep, as before
([#3534](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3534)).

**Score:** 2

#### What makes this deploy extra special

A repo's maintainer reading `/logbook` after two sweeps side by side sees each issue once, under the
sweep that shipped it.

**Score:** 1

#### Pull Request

Logbook: a sweep is cut only at its own session's folds

Plugins: dkj-policy, dkj-subagents-shopify

[PR #3538](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3538)

---

