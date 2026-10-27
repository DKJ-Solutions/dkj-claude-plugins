# Changelog

## [Unreleased]

**4 / 10 minor entries** <!-- pending-tally -->

### DEPLOY: docs/3552-sweep-continues-past-visible-park · 20261027-084148Z

A sweep no longer ends at the first result that has to be judged by eye. It parks that branch on
`origin` with `awaiting-review-dev` and a comment on what to look at, returns to the trunk and carries on
with the next issue; the close-out lists every parked branch with the `git checkout` line that shows it
([#3552](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3552)). The constitution now names
the sweep as the one carve-out from "the checkout stays on that branch until the owner has looked"; a
single assignment still stays on its branch, and no visible result is merged unseen.

**Score:** 3

#### What makes this deploy extra special

A sweep over a backlog of visible results now handles all of them in one run, where it used to stop
after the first one. You look at each parked branch afterwards by checking it out.

**Score:** 3

#### Pull Request

sweep-issues: a visible result parks the issue and the sweep continues

Plugins: dkj-policy, dkj-subagents-alpha

[PR #3555](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3555)

---

### DEPLOY: feat/3549-merge-dkj-repos-into-connectors · 20261027-083154Z

The DKJ repos have one page instead of two with the same title
([#3549](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3549)): the DKJ group's connector page,
`/connectors/dkj`, now also shows every DKJ-Solutions repo on GitHub with its checkout here and a session to
open there, between its Connected repos table and its Issues card. The product home page drops its DKJ repos
card, and `/dkj-repos` redirects to the merged page.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own product pages; nothing a consumer runs changes.

**Score:** N/A

#### Pull Request

Merge the DKJ repos card into the /connectors/dkj page

Plugins: dkj-policy

[PR #3553](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3553)

---

### DEPLOY: fix/3547-freshness-restart-after-update · 20261026-223340Z

A session whose dkj plugins were updated after Claude Code started -- `update-plugins` inside the
session, then `/clear` -- is no longer told it is up to date while older copies still run. The release
check now says which plugins were updated after the start, and that only restarting Claude Code loads
them ([#3547](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3547)).

**Score:** 2

#### What makes this deploy extra special

N/A: a corrected session-start line; nothing a consumer runs or configures changes.

**Score:** N/A

#### Pull Request

release-freshness-sessioncheck: say [RESTART] when install records were updated after the process started

Plugins: dkj-policy

[PR #3548](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3548)

---

### DEPLOY: fix/3545-house-style-inline-check-width · 20261026-220440Z

The `house-style` skill's check before inlining `house-theme.js` said the script may store nothing but
the theme choice, while the script also remembers the page width (`dkj-width`), so a session read
literally had to stop and report on every pinned copy. The check now names both settings-panel keys.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo taking the house style no longer has its session stop on a correct `house-theme.js`
because it stores the chosen page width.

**Score:** 2

#### Pull Request

house-style skill: the inline check allows the stored page width

Plugins: dkj-solutions

[PR #3546](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3546)

---

### DEPLOY: fix/3540-restore-product-port · 20261026-215314Z

This repo has a product port again ([#3540](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3540)):
its `Get-DevPreview` no longer opts out with `OwnHub`, so the session start hands out the dkj-policy plugin's hub,
as in every other repo, and the connector dashboard as the product beside it. The product's home page opens on a
card back to the hub, then Connectors, Specialists and DKJ repos; the general pages are the hub's alone. The
suite selection the old own hub showed on its Test gate went with it.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own dev server; no plugin behaviour a consumer runs changes.

**Score:** N/A

#### Pull Request

This repo has a product port again: the plugin's hub, and the connector dashboard as the product

Plugins: dkj-policy

[PR #3544](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3544)

---

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

