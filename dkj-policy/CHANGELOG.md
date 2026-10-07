# Changelog

## [Unreleased]

**4 / 4 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2875-closed-message-comment-read · 20261007-084535Z

The `asana-closed-message` template now reads an issue's comments through REST
(`gh api repos/<owner>/<repo>/issues/<n>/comments --paginate`), which the workflow's `issues: read`
covers, instead of `gh issue view --json comments`
([#2875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2875)). On the runner the old read
returned nothing for an issue that carried a trusted go-live block, so the Asana task got the bare
closed line. A failed read is no longer silent: the run log shows gh's exit code and error, and its
last line says the comments could not be read rather than that no block was on the issue. The bare
closed message still goes out in that case. The suite pins the REST call, the parsing of paginated
output and the two log lines.

**Score:** 3

#### What makes this deploy extra special

A requester whose store issue closes as completed gets the go-live block on the Asana task again,
where the old read dropped it on the runner. A store picks the fix up by copying the template again
(`adopt-bwj-development` step 1) after the update; until then it keeps the old read.

**Score:** 3

#### Pull Request

bwj-development: asana-closed-message reads comments through REST and logs a failed read

Plugins: bwj-development

[PR #2876](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2876)

---

### DEPLOY: feat/2871-closed-message-sessioncheck · 20261007-083532Z

`bwj-development` gains a SessionStart check, `closed-message-sessioncheck`
([#2871](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2871)). In `smartwatchbanden` and
`xoxowildhearts` it reports three things. The first is an `asana-closed-message` workflow or script that
was never copied. The second is a copy that differs from the template the installed plugin ships. The
third is an `ASANA_PAT` secret that is not visible to the repo. Before this, a store that skipped
`adopt-bwj-development` step 1 lost every closed and reopened message on its Asana tasks without a
word. It is silent in every other repo, and also when it cannot read the secret list.

**Score:** 3

#### What makes this deploy extra special

After the update, a session in a store whose closed-message workflow is missing or outdated, or has no
`ASANA_PAT`, says so at start, and names the `adopt-bwj-development` step that repairs it. The same line
appears after a later template change (such as #2870) until the store takes the new copy.

**Score:** 3

#### Pull Request

bwj-development: a session check reports a store whose asana-closed-message copy is missing, stale, or has no ASANA_PAT

Plugins: bwj-development

[PR #2874](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2874)

---

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

