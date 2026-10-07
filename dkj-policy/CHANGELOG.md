# Changelog

## [Unreleased]

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2870-reopened-message-wording · 20261007-081402Z

The reopened message that `asana-closed-message` posts on the Asana task now reads *"GitHub issue
<ref> **is reopened:** this Asana task is now back in development."* It used to read "reopened: this
Asana task is back in development."
([#2870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2870)). It now has the same form as
the created and closed lines. Both the plain-text and the html_text builder changed, and the test pins
the new line.

**Score:** 2

#### What makes this deploy extra special

A requester whose store issue is reopened reads the new line on their Asana task. A store picks it up by
copying the template again (`adopt-bwj-development` step 1) after the update; until then it posts the
old wording.

**Score:** 2

#### Pull Request

bwj-development: the reopened message reads 'is reopened: this Asana task is now back in development.'

Plugins: bwj-development

[PR #2873](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2873)

---

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

