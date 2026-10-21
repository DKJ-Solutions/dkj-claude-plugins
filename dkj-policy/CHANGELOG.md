# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

