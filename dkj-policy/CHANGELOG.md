# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

