# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: feat/3035-check-house-style · 20261015-142218Z

A new `check-house-style` gate in the `dkj-solutions` plugin
([#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035)) checks three things. Every
vendored `house-style.css` and `house-theme.js` must be the copy the `house-style` skill pins. The repo's
own layer must not redefine a house token or restyle a house class app-wide. And it must not use a token
name the brand book retired. The gate runs in CI through a reusable workflow and, read-only, at session
start. This repo's connector dashboard passes it.

**Score:** 3

#### What makes this deploy extra special

In a DKJ-Solutions repo with this plugin, a new session-start line now reports a drifted copy of the
house style, a redefined house token or class, or a retired token name such as `--muted` or `--good`, with
file and line. To block a pull request on the same findings, a repo adds the few-line caller from the
`house-style` skill page, which calls `reusable-house-style.yml`. A false positive is answered with a
reason in `Get-HouseStyleAllowlist` in `scripts/repo-config.ps1`.

**Score:** 3

#### Pull Request

house-style: a check-house-style gate

Plugins: dkj-solutions

[PR #3037](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3037)

---

