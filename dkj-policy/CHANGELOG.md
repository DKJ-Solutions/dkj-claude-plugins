# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/hub-without-brandbook · 20261022-103726Z

This repo's Repository (the hub on port 4870) no longer shows the brand book: its home page drops the Brandbook
link, its section is now called DKJ-Solutions and holds the DKJ repos page alone, and `/brandbook` is a 404
there. The hub had served a build of the `brandbook/` app at `/brandbook/` since #3210, rebuilding it with npm
on a stale visit; since #3283 the same app runs as this repo's product on a port of its own, from the tree, so
one brand book was visible on two ports. The product port is now the one place, and it starts at the root:
in dev, `/` is a page of its own (`brandbook/root.html`) linking the brand book at `/brandbook/`, and the
dev-preview hook hands out that root. The brand book's Home crumb, which pointed at a `/` the Vite server did not
answer, now lands on it (#3286). The shared General card, in
dkj-policy's `general-pages-lib.ps1`, no longer says the general pages server is not running when it is
handed no server rows, since it links nothing of that server. Every other DKJ-Solutions repo still gets the
brand book from the dkj-solutions plugin, unchanged.

**Score:** 2

#### What makes this deploy extra special

N/A: the source repo's own hub; no consumer's hub or brand book changes.

**Score:** N/A

#### Pull Request

The brand book lives on the product port alone, which starts at a root page linking it

Plugins: dkj-policy, dkj-solutions

[PR #3287](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3287)

---

### DEPLOY: feat/rename-repo-hub-to-repository · 20261022-095044Z

The Repo hub is now called the Repository, everywhere: the session-start line, the docs, the house-style
reference pages, and the functions, file and state file behind it (`Format-PluginRepositoryHtml`,
`hub/lib/repository-page.ps1`, `%TEMP%\dkj-repository-<leaf>-<hash>.json`). A hub server started under
the previous version is restarted at the next session start, as it already is on any version change, so
the new state file name needs nothing done by hand.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-policy` sees its session-start line open with `Repository:` instead of
`Repo hub:`; nothing has to be done for it. A repo that builds its own hub and calls the general banner
function calls it by its new name, `Format-RepositoryBanner` (it was `Format-RepoHubBanner`); no
consumer checkout on this machine calls the old one.

**Score:** 2

#### Pull Request

Rename the Repo hub to Repository

Plugins: dkj-policy, dkj-solutions

[PR #3285](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3285)

---

