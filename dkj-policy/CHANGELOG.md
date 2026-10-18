# Changelog

## [Unreleased]

**7 / 18 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3122-dev-server-restarts-on-moved-head · 20261018-180247Z

This repo's dev server no longer keeps serving the code it started on after a pull or a branch switch.
It notes the commit it loaded, and the first page asked for after HEAD has moved answers with a short
"restarting" notice that reloads itself, while the server hands its port to a fresh copy of itself on
the new code. The hub's "Source at" now names the commit the pages were actually built from, so it can
no longer read the new commit while the old code runs. Static files skip the check.

**Score:** 3

#### What makes this deploy extra special

N/A -- the server is this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The dev server restarts itself when the checkout's HEAD has moved

[PR #3124](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3124)

---

### DEPLOY: fix/3120-house-style-comment-prose · 20261018-175119Z

This repo's own test gate runs the house-style check over this tree, and a comment here was what tripped
it (`scripts/lib/dev-pages-lib.ps1`): a sentence before a comma no longer blocks a PR.

**Score:** 2

#### What makes this deploy extra special

`check-house-style` no longer fails a DKJ-Solutions repo's PR over a house class named in a comment or a
string before a comma (`# the same .grid-2, which ...`), which until now needed a reworded comment or an
allowlist entry that exempted the real class for the whole file.

**Score:** 2

#### Pull Request

check-house-style no longer reads prose before a comma as a selector

Plugins: dkj-solutions

[PR #3123](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3123)

---

### DEPLOY: feat/hub-pages-grid-head · 20261018-172955Z

The Repo hub's two Pages cards stand under one **Pages** heading spanning the row, and each card is titled
one level lower: **This repo** and **General**. **About this repo** takes the same shape, its heading above
its card rather than inside it, and every heading carries a short line saying what is under it.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub lives on this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

a grid heading over the Repo hub's two Pages cards

[PR #3121](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3121)

---

### DEPLOY: feat/issues-page · 20261018-162753Z

The dev server's Repo hub has an **Issues** page: the open GitHub issues by priority and by where they
stand (free, parked on an `awaiting-*` label, or claimed), and the last 28 days of flow -- opened against
closed per week, and what was closed by kind, priority and how it was closed.

**Score:** 3

#### What makes this deploy extra special

N/A -- the page lives on this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

Adds `/issues` to the Repo hub of this repo's dev server: a map of the GitHub issues (the open board and
four weeks of flow), read with `gh` and cached for five minutes. A visible result, so it waits for the
owner's look before merging.

[PR #3117](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3117)

---

### DEPLOY: fix/release-notes-page-width · 20261018-153451Z

The release-notes template's column now follows the page width a reader picks in the house settings
panel: Phone narrows it to 360px and Full lifts its maximum, where it used to stay at 52rem whatever was
picked while only the breadcrumb bar moved. Fluid keeps the template's own reading column. The rules key
off the attribute the house theme script sets, so a page without that script, a Worker-served one
included, renders exactly as before.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions repo that serves its release notes with the house theme script gets a width setting that
actually applies to the notes, after its next plugin update and page rebuild.

**Score:** 2

#### Pull Request

The release-notes page follows the house page-width setting

Plugins: dkj-policy

[PR #3118](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3118)

---

### DEPLOY: feat/3115-house-style-v0.4.0 · 20261018-134044Z

The `house-style` skill now fetches from the brand book's `v0.4.0` release
([DKJ-Solutions/dkj-brandbook@v0.4.0](https://github.com/DKJ-Solutions/dkj-brandbook/releases/tag/v0.4.0)). Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.
The settings panel of every page the dev server renders now offers the page width -- fluid, phone or
full -- remembered per device like the theme ([#3115](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3115),
brand book #203). The repoint's safety read now accepts a second storage key where it is a house
`dkj-` name, which is what let this release through; a foreign key is still refused.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app that takes the plugin's `assets/house-style/` copy gets the width choice in its
settings panel without writing a line, and can opt out with `settings(el, { widths: false })` where
its layout has no page column.

**Score:** 2

#### Pull Request

Repoints the `house-style` skill and the four vendored copies to `dkj-brandbook` `v0.4.0`, which adds the
fluid/phone/full page width to `DKJTheme.settings()`. The repoint's safety read is relaxed from "one
storage key" to "only house `dkj-` keys", hardened after review. A visible result: it waits for the
owner's look at the dev server's settings panel before merging.

Plugins: dkj-solutions

[PR #3116](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3116)

---

### DEPLOY: feat/3112-harvest-artifacts · 20261018-130135Z

The Artifacts register behind the dev server's `/artifacts` page is no longer kept by hand
([#3112](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3112)). The new repo-local
`harvest-artifacts` skill reads this machine's session transcripts and adds every Artifact or Claude
Docs doc a session here published that the register lacks; it only adds, so a title or kind corrected
in the register by hand is kept. A dry run unless `-Apply`.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server and its register are this repo's own maintenance tools; nothing a plugin user installs changes.

**Score:** N/A

#### Pull Request

The Artifacts register is filled from the session transcripts

[PR #3114](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3114)

---

### DEPLOY: feat/artifacts-page · 20261018-123507Z

The dev server gains an Artifacts page (`/artifacts`), linked from the Repo hub: every claude.ai
Artifact a session in this repo has published -- pages, decks and documents -- newest first, each with
its kind, its dates and one line on what it shows. The list is a committed register,
`scripts/dashboard/artifacts.json`, seeded from this repo's session transcripts; a url that is not a
claude.ai Artifact link is shown without an href, so a register edit cannot inject a link.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server is this repo's own maintenance tool; nothing a plugin user installs changes.

**Score:** N/A

#### Pull Request

The dev server lists every Artifact made for this repo

[PR #3113](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3113)

---

### DEPLOY: fix/3108-release-notes-page-house-style · 20261018-121205Z

The release-notes page on this repo's dev server now carries the house style and opens with the
breadcrumb bar back to the Repo hub, like the other pages under it
([#3108](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3108)). The page is dressed as
it is served. The shared template and the page a Worker publishes are untouched.

**Score:** 2

#### What makes this deploy extra special

N/A -- this repo's own dev server only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The release-notes page carries the house style and the breadcrumb bar

[PR #3110](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3110)

---

### DEPLOY: feat/3094-default-theme-lilac · 20261018-115225Z

The dev server's pages (the connector dashboard, the repo hub and the pages it links) open in the
brand book's `lilac` theme, this repo's default, instead of following the OS between `teal` and `sky`.
A theme a viewer picked by hand still wins.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Dev server: the pages default to the brand book's lilac theme

[PR #3111](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3111)

---

### DEPLOY: feat/3097-repo-hub · 20261018-111834Z

The dev server's index (`/`) in this repo is now the **Repo hub**: a page in dkj-brandbook v0.3.0's form
whose Pages card links the connector overview (now at `/connectors`), the release notes, the SessionStart
measurements and the test-gate durations
([#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)). Every page's breadcrumb starts
at Repo hub.

**Score:** 3

#### What makes this deploy extra special

In every DKJ-Solutions repo the session-start line now opens with `Repo hub:` instead of
`Repo dashboard:`, and the placeholder page carries the same name, the term the brand book adopted in
v0.3.0. Nothing to do: a repo's own index takes the new name when it next follows the brand book.

**Score:** 2

#### Pull Request

Dev server: the Repo hub on / links connectors, release notes, SessionStart and test gate

Plugins: dkj-solutions

[PR #3109](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3109)

---

### DEPLOY: fix/3106-repoint-body-refresh · 20261018-101158Z

The pull request the house-style repoint runner opens now tells its reader to ship with
`ship-pr.ps1 -RefreshBody` once the DEPLOY tiers are scored
([#3106](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3106)). Its body is not open-pr's
and carries no DEPLOY section, so the branch-entry check and ship-pr's DEPLOY lock refused every such
pull request until somebody found that step by hand, as #3105 did. Only this repo's own CI is touched.

**Score:** 2

#### What makes this deploy extra special

N/A -- a CI workflow of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

House-style repoint PR body names ship-pr -RefreshBody after scoring

[PR #3107](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3107)

---

### DEPLOY: feat/house-style-v0-3-0 · 20261018-093108Z

The `house-style` skill now fetches from the brand book's `v0.3.0` release
([DKJ-Solutions/dkj-brandbook@v0.3.0](https://github.com/DKJ-Solutions/dkj-brandbook/releases/tag/v0.3.0)). Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.

**Score:** 2

#### What makes this deploy extra special

An app that takes the new copy can declare one default theme with `<html data-theme-default="teal">`
instead of a light/dark pair, and can build a navigation list of links with `a.menu-item` and a one-line
`.menu-item__sub` description. Both are opt-in: an app that changes nothing renders exactly as before,
since `data-theme-light`/`data-theme-dark` are still read and no token was renamed or removed.

**Score:** 2

#### Pull Request

house-style skill: repoint at dkj-brandbook v0.3.0

Plugins: dkj-solutions

[PR #3105](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3105)

---

### DEPLOY: fix/3103-repoint-absent-branch · 20261018-090522Z

The house-style repoint runner's open-PR check no longer fails on the first run for a brand-book release:
`git ls-remote --exit-code` answering 2 for an absent branch was left in `$LASTEXITCODE`, which the
runner's appended `exit $LASTEXITCODE` turned into a failed step, so no repoint pull request was ever
opened (run 39112387739, `v0.3.0`). The step now treats 0 and 2 as answers, fails on any other exit, and
ends with an explicit `exit 0`. Only this repo's own CI is touched.

**Score:** 3

#### What makes this deploy extra special

N/A -- a CI workflow of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

the house-style repoint workflow no longer fails when its branch is not on origin yet

[PR #3104](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3104)

---

### DEPLOY: feat/3100-house-style-auto-repoint · 20261018-082828Z

A dkj-brandbook release now reaches this repo as a pull request within a day, opened by a scheduled
runner ([#3100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3100)). It repoints the
`house-style` skill's links, commit and checksums, updates the retired-name list and replaces both
vendored copies; a file carrying a spelling the skill forbids stops it before any pull request, and a
changed theme script waits for a person to read its diff. It never merges: whoever ships it scores the
entry. Nothing changes for a repo that uses the house style until
such a repoint is released.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

house-style: open the repoint PR automatically on a dkj-brandbook release

Plugins: dkj-solutions

[PR #3102](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3102)

---

### DEPLOY: feat/3097-dev-server-pages · 20261018-074844Z

This repo's dev server has three pages under the Repo dashboard: **Connectors** (`/connectors`, the
connector overview `/` shows), **SessionStart** (`/sessionstart`, the always-on document path every
session loads, per document, against its budget) and **Test gate** (`/test-gate`, the per-suite CI
durations from `scripts/tests/suite-durations.json`, and the suites not recorded yet). The hub that
links them from `/` follows once the brand book releases its index block
([#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)).

**Score:** 3

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Dev server: the connector overview at /connectors, and pages for the SessionStart and test-gate measurements

[PR #3101](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3101)

---

### DEPLOY: fix/3096-tidy-lane11-remote-plugins · 20261017-223402Z

`tidy-machine`'s lane 11 no longer reports a url-sourced plugin, such as `figma` from the official
marketplace, as retired, and no longer hands over an uninstall of it: it reads the marketplace clone with
`-IncludeRemote`, so a plugin the manifest still names counts as listed whether or not the clone holds a
copy ([#3096](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3096)).

**Score:** 3

#### What makes this deploy extra special

Anyone running `tidy-machine` with a url-sourced plugin installed was told to uninstall a live plugin;
pasting that command removed it.

**Score:** 3

#### Pull Request

tidy-machine lane 11: a url-sourced plugin is no longer reported as retired

Plugins: dkj-policy

[PR #3099](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3099)

---

### DEPLOY: fix/3095-house-style-property-access · 20261017-221912Z

`check-house-style` no longer reads a property access inside a call's closing parens, followed by an
object literal, as a selector styling a house class: a "selector" with an unbalanced paren is skipped,
and nested functional pseudo-classes now fold fully
([#3095](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3095)).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo whose script reads a property named like a house class (`.sort`, `.card`) and
passes an object literal on the same statement no longer gets a red house-style gate it cannot act on.

**Score:** 2

#### Pull Request

check-house-style: a property access followed by an object literal is no selector

Plugins: dkj-solutions

[PR #3098](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3098)

---

