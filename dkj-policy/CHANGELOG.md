# Changelog

## [Unreleased]

**2 / 3 minor entries** <!-- pending-tally -->

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

