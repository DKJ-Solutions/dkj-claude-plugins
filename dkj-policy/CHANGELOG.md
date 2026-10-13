# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: feat/2954-pin-house-style-tag · 20261013-091726Z

The `house-style` skill no longer fetches the brand book's stylesheet and theme script from `main`, which
moves and can be pushed past review. It now pins them to the release tag `house-style-v1`, and it carries
each file's sha256, so a session that gets different bytes stops and reports them instead of inlining them.
A change to the house style now reaches the apps only after the brand book tags it and the skill is repointed
in a plugin release. That rule is on the skill page and in the extension's `CLAUDE.md`.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app copies only a house style the owner has released. An unreviewed push to the brand book
can no longer slip into its next copy of an executable theme script.

**Score:** 2

#### Pull Request

house-style skill: pin the brandbook fetch to tag house-style-v1

Plugins: dkj-solutions

[PR #2956](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2956)

---

