# Changelog

## [Unreleased]

**4 / 11 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3639-stopwatch-h1-above-group · 20261028-231550Z

The hub's Stopwatch pages follow the house rule that the `h1` is never framed: the overview, the Logbook, a label's page and a run's page now set their `h1` above the card group instead of inside its surface.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

the Stopwatch pages set their h1 above the card group

Plugins: dkj-policy

[PR #3641](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3641)

---

### DEPLOY: fix/3637-canonical-house-style-not-a-copy · 20261028-230422Z

A session in `dkj-claude-plugins` no longer opens with a warning to replace the canonical house stylesheet
with the last release's file, a step that would revert work merged since that cut
([#3637](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3637)). The two files in
`plugins/dkj-policy/assets/house-style/` are now named as the source and still read for the redefine check.
Every other copy, in every repo, is held to the pin as before.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

the source repo's canonical house style is not held to the installed pin

Plugins: dkj-solutions

[PR #3640](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3640)

---

### DEPLOY: feat/specialists-card-under-plugins · 20261028-223647Z

The Specialists pages are merged into the specialist teams' Plugins pages: the product home page drops
its Specialists card, a team's card on `/plugins/dkj-subagents` counts its specialists and their full
read, a team's own page shows its facts and then its specialists with what each costs, and a
specialist's page sits under its team. An old `/specialists` address redirects to the same page at its
new one.

**Score:** 2

#### What makes this deploy extra special

N/A: the product's own dev pages, which no consumer takes.

**Score:** N/A

#### Pull Request

Merge the Specialists pages into the specialist teams' Plugins pages

[PR #3638](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3638)

---

### DEPLOY: fix/3620-report-orphan-hub-processes · 20261028-215705Z

A session now starts with a line naming every hub server and `dev-preview-watch` process that has outlived
the run that started it, with its memory and the `Stop-Process` line that ends it
([#3620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3620)). `tidy-machine` lists the same
thing as its lane 13. One killed gate had left 26 such processes holding about 2.3 GB, and nothing said
so. The healthy session hub is left alone, and nothing is stopped for you.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

name every hub process that outlived the run that started it, at session start and in tidy-machine

Plugins: dkj-policy

[PR #3634](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3634)

---

### DEPLOY: fix/3614-grid-2-minmax-tracks · 20261028-214803Z

House style: a `.grid-2` row no longer widens the page when one of its cards holds a one-line nowrap
element such as an ellipsised description or a `code` command. Its tracks now shrink like `.grid-3`'s,
`minmax(0, 1fr)`, and so does the single column below 760px (#3614).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that sets two cards side by side no longer scrolls sideways when one of them holds
a long single line; a local `min-width: 0` workaround for it can go.

**Score:** 2

#### Pull Request

House style: .grid-2 tracks shrink below a card's min-content

Plugins: dkj-policy, dkj-solutions

[PR #3635](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3635)

---

### DEPLOY: feat/3630-house-style-60-30-10 · 20261028-171028Z

The house-style README now reads a theme's colours by the 60-30-10 rule
([#3630](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3630)): the paper (`--paper-*`) is the 60%,
the theme's colour (`--primary`, with `--muted`) the 30%, and the text (`--fg-*`) the 10%. No token or value
changes; it is the grouping a page and a repo layer are held to.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

House style: read a theme's colours by the 60-30-10 rule (Paper 60, Primary 30, Text 10)

Plugins: dkj-policy

[PR #3632](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3632)

---

### DEPLOY: feat/3629-house-style-specimens-in-dkj-policy · 20261028-165357Z

The house style's specimens page moved from `/plugins/dkj-solutions/house-style` to
`/plugins/dkj-policy/house-style`, beside the files it documents
([#3629](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3629)). Every repo running the toolbox now
reaches it, BWJ-Development's included, where `dkj-solutions` is never enabled. The House style card sits on the
`dkj-policy` plugin page, and the old address redirects to the new one.

**Score:** 2

#### What makes this deploy extra special

A BWJ-Development repo's toolbox now has a House style page under Plugins > dkj-policy, showing every token,
theme and component of the stylesheet that toolbox renders with. A bookmark to the old address still lands.

**Score:** 1

#### Pull Request

The house style specimens page moves to dkj-policy, so every repo running the toolbox reaches it

Plugins: dkj-policy, dkj-solutions

[PR #3631](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3631)

---

### DEPLOY: feat/h1-never-framed · 20261028-164121Z

A new house-style rule: the `h1` is never framed. `house-style.css` now clears any border, outline, shadow and background on every `h1`. The README (rule 6) and the `house-style` skill state the layout half too: a page's `h1` stands on the page itself, never inside a card, panel or bordered box. The hub follows it already: its group pages (`/clock` among them) and the SessionStart pages had their `h1` inside the card group's surface, and now set it above the group. Alongside it, `.page-column` stacks its blocks with a `--spacing-3` gap instead of `--spacing-5`, so every page built on it is a little tighter. A repo whose own layer gave its `h1` a frame through a plain `h1` selector loses that frame when it takes this copy. A rule on a class of the repo's own still wins, and the rule says it must not be written.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app takes this the next time it copies the house style. On the hub, the group pages and the SessionStart pages now show their `h1` above the cards rather than inside the group's surface. The rule exists so that no app starts framing it.

**Score:** 2

#### Pull Request

the h1 is never framed

Plugins: dkj-policy, dkj-solutions

[PR #3627](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3627)

---

### DEPLOY: fix/3626-cut-release-stale-section-lines · 20261028-162619Z

`cut-release` no longer names the two audience-note sections #3584 removed
([#3626](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3626)). The GitHub Release body now
points at the attached notes for "whether you need to act" only. The cut's console says the drafted note
holds the audience section, or only its header where no entry reached the audience tier.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

cut-release's console and Release body no longer name the two note sections #3584 removed

Plugins: dkj-policy

[PR #3628](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3628)

---

### DEPLOY: fix/3619-merge-on-green-actions-read · 20261028-160541Z

The merge-on-green runner that `adopt-ci-floor` places now also grants its job token `actions: read`
([#3619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3619)). `checks: read` and `statuses: read`
(#3491) were not enough: `gh pr checks --required` also reads the workflow run behind each check run, so a
private repo's picker still could not read its required checks and still merged nothing. A re-run of
`adopt-ci-floor` now names a runner without the scope under `[scope]`. When the required-check read
fails, the picker now prints the first line of the error instead of only "could not be read".

**Score:** 3

#### What makes this deploy extra special

In a private repo, merge-when-green had still never merged anything, and this release is the one that fixes it.
Add `actions: read` under `permissions:` in `.github/workflows/merge-on-green.yml`, or delete that file and run
`adopt-ci-floor -Apply` again. A re-run of `adopt-ci-floor` tells you whether your runner needs it.

**Score:** 3

#### Pull Request

merge-on-green: the job token also reads actions, so a private repo's picker can read its required checks

Plugins: dkj-policy

[PR #3624](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3624)

---

### DEPLOY: fix/3620-suite-servers-owner-watch · 20261028-155416Z

A hub server that a test suite starts through the dev-preview hook is now stopped once that suite's process
has ended ([#3620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3620)). The suite sets
`DKJ_DEV_PREVIEW_OWNER_PID` to its own pid, and `dev-preview-watch` stops the server's tree when that process
is gone. Until now a killed gate never reached the suite's own cleanup, and one kill left 26 servers and
watchers holding about 2.3 GB. A real session never sets the variable, so its hub still outlives the session
for the next one to reuse.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

a hub server a test suite starts is stopped when that suite's process ends, even when the gate was killed

Plugins: dkj-policy

[PR #3625](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3625)

---

