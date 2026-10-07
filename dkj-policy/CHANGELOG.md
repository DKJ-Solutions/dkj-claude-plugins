# Changelog

## [Unreleased]

**2 / 3 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2877-asana-default-assignee · 20261007-125643Z

`report-issue` can now assign the Asana task it creates. A new optional seam,
`Get-AsanaDefaultAssignee` in `scripts/repo-config.ps1`, names an Asana user GID, and step 2 passes
it as `assignee` on the same `create task` call
([#2877](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2877)). It applies only to a task
the procedure creates. A colleague's own ticket that is moved into `Filed` keeps its assignee.
`$null` is the default and creates the task unassigned, as before. `adopt-bwj-development` proposes the
seam, and the bwj-development README lists it.

**Score:** 2

#### What makes this deploy extra special

A store whose owner wants every new card on their own desk answers one function. The card then lands
in that person's *My Tasks* instead of waiting unseen on the board. Nothing changes until the seam is
answered.

**Score:** 3

#### Pull Request

report-issue: assign the created Asana task to a configured person

Plugins: bwj-development

[PR #2883](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2883)

---

### DEPLOY: feat/2878-golive-task-block · 20261007-124624Z

`golive-block` now says how to write a block that hands the requester a new task rather than a
result to look at ([#2878](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2878)). The
prose follows a fixed order: first the goal and what happens when the reader does nothing, then the
click route walked once with a non-admin account, then one worked example on the reader's own page,
and the exceptions last. When the model changes, the whole instruction is rewritten rather than only
the delta. `WORKFLOW-portable.md` points to it. The headings and the script are unchanged.

**Score:** 2

#### What makes this deploy extra special

A colleague who is handed a new task in a go-live block gets the goal, a click route that works with
their own account, and an example, in that order. Before, the block could give them the latest delta
and a list of system names.

**Score:** 3

#### Pull Request

golive-block: guidance for a block that teaches a colleague a new task

Plugins: bwj-development

[PR #2886](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2886)

---

### DEPLOY: docs/2879-shopify-store-switch-research · 20261007-123507Z

A research finding, posted as [a comment on #2879](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2879#issuecomment-6038099604), explains why the claude.ai Shopify connector has to be switched by hand between the two store repos, and what can make that easier. A second connector or a per-project Admin MCP is not available. Shopify CLI `store auth`/`store execute` gives a per-store channel for scripted reads, but the token lifetime has to be measured before any skill depends on it. The recommendation is a store-mismatch check that catches the wrong store at the first call ([#2880](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2880)). The research also confirmed that `guard-live-theme` does not see `shopify store execute --allow-mutations` ([#2881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2881)).

**Score:** 2

#### What makes this deploy extra special

N/A -- a research document in the source repo; no plugin ships anything new from it.

**Score:** N/A

#### Pull Request

Research: switching the claude.ai Shopify connector between store repos

[PR #2882](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2882)

---

