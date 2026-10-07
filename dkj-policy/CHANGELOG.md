# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: feat/2869-retire-cro-label · 20261007-080040Z

The `CRO` label is retired across the BWJ procedure
([#2869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2869)). `report-issue` classifies
an issue by its kind (`bug` or `feature`) and the reach label only. `WORKFLOW-portable.md` replaces the
section on the label with a short note on its retirement, and `adopt-bwj-development` no longer creates
it. Where a store already has the label, it stays as history; nothing deletes it.

**Score:** 2

#### What makes this deploy extra special

After the update, a session filing an issue in a BWJ store no longer adds `CRO` to an issue raised by
the CRO team. That issue gets the kind and the reach label like any other. Nothing has to be done in a
store. Deleting the existing label from `smartwatchbanden` or `xoxowildhearts` is a repo setting, which
the owner changes by hand.

**Score:** 2

#### Pull Request

Retire the CRO label: report-issue classifies bug or feature only

Plugins: bwj-development

[PR #2872](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2872)

---

