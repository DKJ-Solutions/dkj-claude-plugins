# Changelog

## [Unreleased]

**14 / 23 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3576-record-recurrence-stays-closed · 20261027-115033Z

A new instance of a recurring problem is now only a comment on its closed `[RECORD]` issue. The record is no
longer reopened, so it stays closed through every recurrence. Before, the page said to reopen it and named
no step that closed it again, so the first recurrence left a record open for good (#3459). An issue still
waiting on its first recurrence is reopened as before. The workflow page and the comment the
`close-parked-recurrences` runner posts both say so.

**Score:** 2

#### What makes this deploy extra special

A consumer that follows the workflow page now logs a recurrence on a record as a comment instead of a
reopen, and once the CI floor is adopted again, its runner's close comment says the same.

**Score:** 2

#### Pull Request

A recurrence on a record is a comment only, and the record stays closed

Plugins: dkj-policy

[PR #3577](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3577)

---

### DEPLOY: fix/3569-product-outlives-its-session · 20261027-112722Z

A server the dev-preview hook starts no longer holds its port after its Windows session is left behind. A
watcher runs beside it in the same session and stops the server's whole tree once that session has been
disconnected for a minute. It exits with the server either way, and session 0 gets none. A holder that is
still in another logon session is named with that session's number and the one elevated command that frees
the port.

**Score:** 3

#### What makes this deploy extra special

On a machine where people switch Windows accounts, or leave a session disconnected instead of signing out,
the next session no longer starts without its product. The port is free about a minute after the switch. A
session that is started sooner, or a holder from before this release, gets the exact `Stop-Process`
command instead of a bare pid.

**Score:** 3

#### Pull Request

dev-preview: a server the hook starts no longer outlives its session

Plugins: dkj-policy

[PR #3574](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3574)

---

### DEPLOY: feat/3572-stale-park-external-waits · 20261027-110905Z

A sweep now also notices when an issue parked on another repo has stopped waiting. `claim-issue -Candidates`
reports an `awaiting-pull-external` issue as `stale-park` once its upstream pull request has merged and
that repo has published a release since. It does the same for an `awaiting-release-external` issue once
the repo it names has published a release after the park. It prints the two lines that unpark the issue,
so the issue is free for the same sweep. Before this, only `awaiting-pull` was ever read again.

**Score:** 2

#### What makes this deploy extra special

N/A -- a sweep in a consumer reads two more parked labels again; nothing changes for the person who takes
the next version unless they run sweeps on issues waiting on another repo.

**Score:** N/A

#### Pull Request

stale-park reads the two external waits

Plugins: dkj-policy

[PR #3575](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3575)

---

### DEPLOY: feat/hub-banner-slide · 20261027-105833Z

The hub banner no longer sits on every page all hour: it is hidden until airsquats are due, slides down when the hour turns, and slides back up once the box is ticked.

**Score:** 3

#### What makes this deploy extra special

The hub banner now appears only when airsquats are due, sliding in at the hour and out once ticked off, instead of a permanent countdown strip on every hub page.

**Score:** 2

#### Pull Request

Show the hub banner only while airsquats are due, sliding it down at the hour and back up once ticked off

Plugins: dkj-policy

[PR #3570](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3570)

---

### DEPLOY: feat/3558-fit-alarm-other-shells · 20261027-104848Z

The fit alarm, which warns at the bottom right when a hub page runs past the window it is read in, now
also appears on the release-notes pages and the hub's own home page, as well as on every other general
page ([#3558](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3558)). This repo's product
server's home and Connectors pages carry it too.

**Score:** 2

#### What makes this deploy extra special

The hub home page and the release notes now warn you, like every other hub page, when they do not fit
one screen.

**Score:** 2

#### Pull Request

Fit alarm on the release-notes pages and the product server's pages

Plugins: dkj-policy

[PR #3573](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3573)

---

### DEPLOY: feat/allow-tree-hub-server · 20261027-102329Z

A session in this repo can now serve the tree's own hub on a spare port without a permission refusal, so a
merged hub change can be looked at before the release that carries it to `:4892`. The allow rules name the
one server script and nothing wider.

**Score:** 2

#### What makes this deploy extra special

N/A -- a permission in this repo's own settings and a note in the source-repo section; no consumer takes
either.

**Score:** N/A

#### Pull Request

Allow a session to serve the tree's own hub without a permission refusal

Plugins: dkj-policy

[PR #3571](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3571)

---

### DEPLOY: feat/3563-long-pages-become-cards · 20261027-101351Z

The hub rule "a page with more than four sections becomes an overview of cards, each opening a page of its
own" is now written down in the house-style README and the `house-style` skill. The hub's page shell checks
it on every page it renders and puts a warning at the top of any page that breaks it. The House style page
under `/plugins/dkj-solutions/house-style` follows the rule itself: it shows 11 cards instead of 85 KB of
specimens in one column, and each section has its own page.

**Score:** 3

#### What makes this deploy extra special

Every repo running the hub gets the House style page as cards, with one page per section. A hub page that
grows past four sections now says so on the page itself, so the shape is caught as it happens instead of
being spotted later.

**Score:** 3

#### Pull Request

Hub pages: a long page becomes cards with a page each, written down and guarded

Plugins: dkj-policy, dkj-solutions

[PR #3567](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3567)

---

### DEPLOY: feat/3562-asana-reopen-card-back · 20261027-100117Z

When a GitHub issue linked to an Asana task is reopened, `asana-closed-message` now moves the card into
the board's `InDevelopment` section and marks the task incomplete if it was completed, after posting the
reopened message ([#3562](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3562)). Unlike the
review move (#3248) it does take a card out of `Completed`. Where the task is on several boards, or its
board has no single section with the `InDevelopment` code, the move is skipped and the message and the
untick still go out. The untick only ever sets `completed` to false. A store takes it by re-copying
`.github/scripts/asana-closed-message.ps1`, and the move needs `InDevelopment` in its
`Get-AsanaStageMap`; without it, only the untick happens.

**Score:** 3

#### What makes this deploy extra special

A reopened ticket's Asana card now goes back to In Progress and is unticked on its own, so the board
agrees with the "back in development" message instead of waiting for someone to drag it.

**Score:** 3

#### Pull Request

asana-closed-message: on a reopen, move the card to InDevelopment and mark it incomplete

Plugins: bwj-development

[PR #3568](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3568)

---

### DEPLOY: feat/test-gate-drilldown · 20261027-094730Z

In this repo the Test gate stops being one long scroll: an overview of cards drills down through the
breadcrumbs into a page per group and per suite, each fitting a screen of about 1300 x 900, and every hub
page now warns at its bottom right the moment it runs past the window.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub gets the same: the Test gate drills down from an overview (`/test-gate`) to a group
(`/test-gate/<group>`) and a suite (`/test-gate/<group>/<suite>`), and every hub page carries the fit
alarm. The house style's density rule now names a screen of about 1300 x 900, a guideline, instead of
1400 x 600.

**Score:** 3

#### Pull Request

Test gate: one screen per level, drill down by breadcrumbs, and a hub-wide overflow signal

Plugins: dkj-policy, dkj-solutions

[PR #3561](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3561)

---

### DEPLOY: docs/3557-sweep-lane-mode · 20261027-093501Z

`sweep-issues` now has a **lane mode** for a second sweep on the same machine
([#3557](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3557)). Open a detached worktree
beside the primary, start Claude Code there, and run the skill. Steps 0, 3 and 7 detach at `origin/main`
instead of checking out the trunk, and `ship-pr` runs from the lane unchanged: it merges and leaves the
fold to the CI fold runner (#2087). The `worktree-lane` page and script header no longer say a lane must
always hand back to ship, because that holds only in a repo without that runner.

**Score:** 3

#### What makes this deploy extra special

You can now run a second issue sweep beside a running one on the same machine, which roughly halves the
time a backlog takes when the gates prove it.

**Score:** 3

#### Pull Request

sweep-issues gets a lane mode: a second sweep in a worktree lane ships through the CI-fold arm

Plugins: dkj-policy

[PR #3564](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3564)

---

### DEPLOY: feat/hub-clock-card · 20261027-092452Z

The hub's home page links Test gate, Stopwatch and Logbook through one card, Clock, in the place the Test
gate's card held; it opens `/clock`, a page with a card for each, and their trails read Home > Clock > the page. A page
joins a group by a `Group` key in `Get-GeneralPages`, and a hub card stays one link.

**Score:** 2

#### What makes this deploy extra special

Every repo's hub home page shows one Clock card instead of the Test gate, Stopwatch and Logbook cards; all three are a click further, on `/clock`.

**Score:** 2

#### Pull Request

Group Test gate, Stopwatch and Logbook under one Clock card on the hub home page

Plugins: dkj-policy

[PR #3560](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3560)

---

### DEPLOY: feat/3550-specialists-page-plugin-cards · 20261027-091242Z

The product's Specialists page shows one card per specialist plugin
([#3550](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3550)), the core team first, each with
its specialist count, its total context cost and whether it is enabled here. Each card links to that
plugin's own page, `/specialists/<plugin>`, with its specialists and what each one costs. A plugin that is
not enabled here still gets a card, muted, and its page says no session here carries its listing.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own product pages; nothing a consumer runs changes.

**Score:** N/A

#### Pull Request

Specialists page: one card per specialist plugin

[PR #3559](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3559)

---

### DEPLOY: fix/3554-clearance-forecast-before-gates · 20261027-090056Z

`ship-pr` now prints a **clearance forecast** before its gates
([#3554](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3554)): whether this run will become
clearable once its PR is armed, or stays needed until the merge and the fold have run, for example because
the diff touches a repo-owned seam the merge-on-green sweep will not ship. It also prints the close-out a
session should relay when it backgrounds the run. That close-out opens with "Nothing waits on you" and
says how long to leave the window open. The later "Session can be cleared" verdict is unchanged.

**Score:** 3

#### What makes this deploy extra special

When you hand `ship-pr` to the background, the session can now tell you straight away whether you will
be able to close it once the PR is open, or must keep the window open until the merge, and it no longer
says it is "waiting".

**Score:** 3

#### Pull Request

ship-pr says before its gates whether this run will become clearable, with the close-out to relay

Plugins: dkj-policy, dkj-subagents-alpha

[PR #3556](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3556)

---

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

