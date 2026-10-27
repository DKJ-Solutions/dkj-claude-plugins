# Changelog

## [Unreleased]

**11 / 16 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3605-trunk-autosync · 20261027-175608Z

A checkout's trunk now follows origin by itself. At every session start, a checkout standing clean on
its trunk and merely behind is fast-forwarded before the session checks run. It is silent when there is
nothing to report, and `DKJ_TRUNK_AUTOSYNC=0` turns it off. The new
[`sync-trunk`](../plugins/dkj-policy/skills/sync-trunk/SKILL.md) command does the same on request, and
with `-AllCheckouts` it covers every checkout on the machine. Nothing is ever stashed or rebased, and no
merge commit is ever created. A checkout off its trunk, with an uncommitted change or with local commits
origin lacks is left alone: the command says why, and the session-start step stays silent unless the
trunk is behind.

**Score:** 3

#### What makes this deploy extra special

You no longer pull the trunk by hand after every merge, in this repo or in any other checkout on your
machine. Work in progress is never moved.

**Score:** 3

#### Pull Request

Fast-forward a clean trunk automatically, at session start and across every checkout

Plugins: dkj-policy

[PR #3607](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3607)

---

### DEPLOY: fix/3591-session-start-no-lede · 20261027-172526Z

The session-start pages now open on their content too: the measurement's summary follows the figures it
sums up, the advice's verdict follows its steps, and the explainer lines under the Artifact's section
headings are gone, the same rule #3585 set for every other hub page
([#3591](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3591)).

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the entry above.

**Score:** N/A

#### Pull Request

Session-start page and template: no lede under a heading

Plugins: dkj-policy

[PR #3606](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3606)

---

### DEPLOY: fix/3602-second-issue-branch-refused · 20261027-171136Z

`new-branch` now refuses to cut a new branch for an issue when `origin` already carries another branch
for the same issue number (`<prefix>/<n>-*`). Two sweeps had parked two independent fixes for one
issue: the second sweep's claim refused, but its command chained `new-branch` after it with `;` and
cut the claim's output to its last line, so the refusal was never read. A resume of the existing branch
still works, and the run names that branch. The `sweep-issues` skill now says to run the claim on its
own and read its whole verdict before cutting a branch.

**Score:** 2

#### What makes this deploy extra special

A sweep, or two machines working one backlog, can no longer leave you two competing fixes for one issue
to compare by hand.

**Score:** 2

#### Pull Request

new-branch refuses a second branch for an issue that already has one on origin

Plugins: dkj-policy

[PR #3604](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3604)

---

### DEPLOY: fix/3596-banner-hub-offline · 20261027-170022Z

The airsquats banner on every hub page now says "hub offline, this hour is not counted" when its server stops
answering for about 30 seconds, instead of ticking towards an hour that will never be recorded. It clears itself
as soon as the server answers again.

**Score:** 3

#### What makes this deploy extra special

Whoever relies on the reminder learns at once that it has stopped working, instead of finding a lost hour afterwards.

**Score:** 3

#### Pull Request

The airsquats banner says so when its hub server stops answering

Plugins: dkj-policy

[PR #3603](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3603)

---

### DEPLOY: docs/3585-no-lede-under-headings · 20261027-164004Z

A hub page now opens on its `h1` and goes straight to its content: the one-line lead that stood under
every heading (a plugin's page, a section's page, a suite's page, Repository) is gone from the screen and
is the page's `<meta name="description">` instead. The house-style rules say the same for every
DKJ-Solutions app: no intro or explainer paragraph under a page heading, because screen height is scarce
([#3585](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3585)).

**Score:** 3

#### What makes this deploy extra special

Nothing beyond the entry above: one line per page moves from the screen into the page's metadata.

**Score:** N/A

#### Pull Request

House style: no intro paragraph under page headings

Plugins: dkj-policy, dkj-solutions

[PR #3598](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3598)

---

### DEPLOY: fix/3597-watcher-crosscheck-disconnect · 20261027-161128Z

The dev-preview watcher no longer trusts a single connect-state read before it stops a server. On a
machine with several accounts and fast user switching, that read came back inverted: the active console
session read as disconnected, and a disconnected one as connected. So after a switch to another account
and back, the watcher could stop the hub, or any server the dev-preview hook starts, in the session that
was using it. A disconnect now counts only when two other sources agree: the session is not the active
console session, and the Windows session list shows it as disconnected too. Any disagreement is read as
uncertain, and an uncertain read never stops a server.

**Score:** 2

#### What makes this deploy extra special

On a machine shared between accounts, switching to another account and back no longer takes down the
hub that was open before the switch.

**Score:** 2

#### Pull Request

dev-preview watcher acts on a disconnect only when the session list agrees

Plugins: dkj-policy

[PR #3601](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3601)

---

### DEPLOY: feat/release-note-grid · 20261027-160007Z

A release's own page now lays each note section out as a grid of cards, at most three across: every paragraph or bullet is a card, its bold opening sentence lifted into the card's own h3 under the section's h2, which stays above the grid as the house style requires, so a nine-point release reads as one screen instead of a long column. A section with a table, code or a sub-heading, or with a single point, is left as it was. On the hub the page now reads house colour tokens only: the template's own colour uses are rewritten to house tokens as it is served, in place of a layer that pointed its palette at them; the template itself keeps its palette for the Worker and BWJ-Development consumers.

**Score:** 3

#### What makes this deploy extra special

The hub's release notes page of every consumer shows each release's points side by side, at most three across, instead of one long column.

**Score:** 2

#### Pull Request

Release note pages lay the note out in a grid of three columns

Plugins: dkj-policy

[PR #3600](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3600)

---

### DEPLOY: fix/3595-hub-watch-disconnected-start · 20261027-153929Z

The hub and the product the SessionStart hook starts no longer stop about two minutes later on a machine where
Claude Code runs in a disconnected Windows session, as it does under a second account while another account
holds the console. The session watcher from v5.34.0 now counts a disconnect only after it has seen the session
connected, so it still stops a server whose session is left behind later.

**Score:** 4

#### What makes this deploy extra special

Every repo's hub stays up on a machine that switches Windows accounts, instead of going dark minutes after each session start.

**Score:** 4

#### Pull Request

A server started in an already disconnected session is not watched, so the hub no longer exits minutes after it starts

Plugins: dkj-policy

[PR #3599](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3599)

---

### DEPLOY: fix/3588-house-style-tag-fallback · 20261027-152421Z

The house-style session check no longer flags a consumer's copy that is exactly the released file. An
install tracks `main`, so between a house-style merge and the next cut the installed skill page named
the old tag beside the new checksums, and the check told a correct repo to replace its copy with itself.
A copy that fails the installed page is now judged again against the page as it reads at that tag. The
page is fetched only in that case, so a clean session makes no network call. A hand run of
`check-house-style.ps1` from an install does the same, and the skill tells a session that fetches the
files to check that page before it stops.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo's session no longer opens with a house-style warning it cannot clear in the days
between a house-style change and the release that carries it.

**Score:** 2

#### Pull Request

house-style check falls back to the skill page at its tag

Plugins: dkj-solutions

[PR #3594](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3594)

---

### DEPLOY: feat/3584-audience-note-only · 20261027-151359Z

The audience release note that `cut-release` drafts now has one section, *What changed*, in every repo. The two
organisational sections, *What it is worth* and *What was still open at this release*, are gone, and so is the
`Get-ReleaseNoteSections` seam that could only switch them off; a repo that still defines it changes nothing. The
`For whom` line names only the reader the note has, and the release-notes form check refuses either heading
written back by hand.

**Score:** 3

#### What makes this deploy extra special

Every repo's next release note arrives without the two sections nobody filled in, with nothing to configure.

**Score:** 3

#### Pull Request

The audience release note drops 'What it is worth' and 'What was still open' everywhere

Plugins: dkj-policy

[PR #3592](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3592)

---

### DEPLOY: fix/3590-internal-note-sections · 20261027-150206Z

The internal release note that `new-internal-note.ps1` drafts (the two-document flow) no longer carries
'What it is worth' or 'What was still open at this release': the note is its entry bullets under one
heading, as the audience note became with #3584. A consumer still on that flow writes neither section
again ([#3590](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3590)).

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the entry above: it removes two drafted headings from a retired flow's skeleton.

**Score:** N/A

#### Pull Request

Internal note no longer drafts 'What it is worth' and 'What was still open'

Plugins: dkj-policy

[PR #3593](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3593)

---

### DEPLOY: fix/3580-release-notes-empty-state · 20261027-145208Z

A repo that has adopted the workflow but never cut a release now gets an empty-state release-notes page
in its hub ("No release has been cut yet. The release notes appear here with the first cut.") instead of
a build error telling it to create files that would not help. `build-release-notes-page.ps1` answers that
state -- no history, or a history whose table has no release row -- with exit 3 and writes nothing.
Closes #3580.

**Score:** 2

#### What makes this deploy extra special

A consumer before its first release no longer sees a hub link that reads as a defect to repair.

**Score:** 2

#### Pull Request

The release-notes page shows an empty state, not a build error, before a repo's first release

Plugins: dkj-policy

[PR #3587](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3587)

---

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

