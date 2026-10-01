# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/figma-off-here · 20261001-202811Z

figma, enabled machine-wide, is now switched off in this repo's `.claude/settings.json`. Its 14 skill
descriptions (2,150 tokens, measured by `measure-session-start`) leave every session here. The reason is
recorded in Sylvester's lens.

**Score:** 2

#### What makes this deploy extra special

N/A: this changes only this repo's own settings, and no consumer takes them.

**Score:** N/A

#### Pull Request

figma switched off for this repo

[PR #2696](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2696)

---

### DEPLOY: fix/2693-null-plugin-roots-under-pwsh · 20261001-185244Z

Inside this repo: the plugin-tree lib no longer trusts `@($PluginRoots)` to drop a `$null`. That holds
in Windows PowerShell 5.1 and not in pwsh 7, and every CI-floor runner executes under pwsh while the
suites that reached this path ran under 5.1. A new `Get-PluginRootSet` filters it in the three loops,
and `fold-changelog.tests.ps1` now asserts that call itself, so the Linux pwsh job covers it.

**Score:** 2

#### What makes this deploy extra special

For the maintainer of a consuming repo that declares no plugins: `fold-on-merge` no longer fails on a
merge with `You cannot call a method on a null-valued expression` in `Get-PluginNameForPath`, so the
changelog entry folds on the runner instead of waiting for somebody to fold it locally
([#2693](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2693)).

**Score:** 3

#### Pull Request

The fold no longer crashes under pwsh in a repo with no marketplace

Plugins: dkj-policy

[PR #2694](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2694)

---

