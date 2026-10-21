# Changelog

## [Unreleased]

**5 / 6 minor entries** <!-- pending-tally -->

### DEPLOY: docs/close-first-recurrence · 20261021-215855Z

An issue parked under `awaiting-recurrences-first` is now closed as `not_planned` at once, keeping its label
and its `[RECORD]` prefix, instead of *may be closed* while it waits. The label is the marker and the
search before filing already reads closed issues, so the open list holds only work.

**Score:** 2

#### What makes this deploy extra special

A repo running this workflow sees its parked recurrence issues closed rather than open.

**Score:** 2
#### Pull Request

An issue waiting for its first recurrence is closed at once; the label is the marker

Plugins: dkj-policy

[PR #3282](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3282)

---

### DEPLOY: feat/3274-brandbook-home-about · 20261021-214748Z

The brand book app no longer draws a Repo hub specimen or previews of other repos' hubs (#3274):
`/brandbook/repo-hub` and `/brandbook/dashboards` are the showcase now, like any other path under it. The hub's
form is laid down once, in the house-style README and its two stylesheet-only patterns. The brand book's crumb
back to the hub reads Home.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo's brand book loses its Repo hub section; a repo building its own hub starts from the
house-style README and `patterns/repo-dashboard.html` plus `patterns/repo-about.html`.

**Score:** 2

#### Pull Request

Brand book app: remove the Repo hub specimen and the hub previews

Plugins: dkj-solutions

[PR #3281](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3281)

---

### DEPLOY: feat/3270-home-and-about · 20261021-210601Z

The Repo hub is two pages now (#3270). **`/` is the repo's home page**, a portal: its `h1` is the repo's
name, then its Products, one link to **About this repo**, and in a DKJ-Solutions repo the **Brand book**.
**`/about` holds the repo itself**: its own pages, the general pages (Artifacts, Issues, Release notes,
SessionStart) and its facts. The first crumb on every page reads **Home**. The plugin's hub and this
repo's own both take the form, and the house-style README and its two patterns lay it down; the brand
book's React specimen follows in #3274.

**Score:** 4

#### What makes this deploy extra special

Every repo's hub opens on a page with the repo's name and its products, and the general pages move one
click further, to About this repo. A repo that serves its own hub (`OwnHub`) takes the new form from the
house-style README and `patterns/repo-dashboard.html` plus `patterns/repo-about.html`.

**Score:** 4
#### Pull Request

Repo hub: '/' becomes the home page, the repo itself moves to 'About this repo'

Plugins: dkj-policy, dkj-solutions

[PR #3279](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3279)

---

### DEPLOY: fix/3273-release-freshness-mixed · 20261021-204425Z

The session-start release check no longer says "this session runs dkj plugins vX" when the enabled dkj
plugins load different versions (#3273). When a user-scope install sits beside an older project-scope
one, or the plugins of one checkout were updated apart, it now reports `[MIXED]`. It names each plugin's
version and scope, and asks for `/dkj-policy:update-plugins` when one of them is behind GitHub's newest
release.

**Score:** 2

#### What makes this deploy extra special

Nothing to do on update: the new line appears by itself at the next session start.

**Score:** N/A

#### Pull Request

release-freshness-sessioncheck reports [MIXED] when the enabled dkj plugins load different versions

Plugins: dkj-policy

[PR #3277](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3277)

---

### DEPLOY: fix/3275-hub-stale-plugin-version · 20261021-203111Z

The dev-preview hook no longer reuses a hub that this checkout started under another plugin version (#3275).
After an update it stops that server and starts the new version's on the same port, and the session's line
reads `(restarted: it ran another plugin version)`. Before this, a server from v5.26.0 kept running after the
move to v5.27.0, and its `/` redirected to itself (`ERR_TOO_MANY_REDIRECTS`). A server started by hand from a
relative path is still reused.

**Score:** 3

#### What makes this deploy extra special

After an update the Repo hub link opens the hub again, without anyone stopping the old server by hand.

**Score:** 2

#### Pull Request

dev-preview hook restarts a hub server that runs from another plugin version

Plugins: dkj-policy

[PR #3276](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3276)

---

### DEPLOY: feat/3269-full-default-width · 20261021-195449Z

Every DKJ-Solutions page that runs `house-theme.js` and sets no `data-width-default` now opens at
**full** width instead of the 1080px fluid column (#3269). A width picked in the settings panel still
wins, and an app's own `data-width-default` still decides its default. Without the script the column
stays fluid.

**Score:** 3

#### What makes this deploy extra special

An app that relied on the implicit `fluid` opens wider after the update. To keep the old look, set
`<html data-width-default="fluid">`.

**Score:** 3

#### Pull Request

House style: full is the default page width

Plugins: dkj-solutions

[PR #3272](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3272)

---

