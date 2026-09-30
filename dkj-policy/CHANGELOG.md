# Changelog

## [Unreleased]

**9 / 12 minor entries** <!-- pending-tally -->

### DEPLOY: feat/disable-addon-teams · 20260930-215833Z

The three add-on teams (`dkj-subagents-ecomm`, `dkj-subagents-lifehub`, `dkj-subagents-shopify`) are
switched off in this repo's own `.claude/settings.json`. They had no work here and cost every session
about 2.9k tokens. They are set to `false` rather than removed, so a user-scope setting cannot switch
them back on. Their entries in the self-connector record, their 11 empty lenses and their roster rows go
with them, so no gate and no session-start check reports them. What is given up is the early warning:
a broken add-on plugin no longer surfaces at this repo's own session start. Sylvester's lens says how
to switch one back on for a validation pass.

**Score:** 2

#### What makes this deploy extra special

N/A. Only this repo's own settings change. No consumer's installed plugins or shipped files change.

**Score:** N/A

#### Pull Request

Disable the three add-on teams in this repo's own settings

[PR #2668](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2668)

---

### DEPLOY: docs/2665-split-chris-persona-second-pass · 20260930-205630Z

Chris's always-on persona is 6.1 KB smaller (27,937 -> 21,819 B), about 2,000 tokens less per session.
The full waiting and claim rules now live in
[Chris's manual](../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-01-01-manual.md),
which loads on demand. The persona keeps the core of each rule and says when to read the rest. The
inbound route is shorter, and its six checks were already in the manual. Every heading stays where it
was.

Tier 0 is scored for every session in every consumer. The saving reaches each consumer with the next
release.

**Score:** 2

#### What makes this deploy extra special

N/A. It is instruction text for sessions, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Second split of Chris's persona

Plugins: dkj-subagents-alpha

[PR #2666](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2666)

---

### DEPLOY: fix/2659-no-ampersand-chains-in-hints · 20260930-142756Z

Three recovery hints the shipping scripts print, from the fold, from `open-pr`'s backing gate and from
the missing-check-suite note, no longer join two commands with `&&`. They print on separate lines, or
join with `;` inside a sentence, so they paste into Windows PowerShell 5.1 as they are.

**Score:** 1

#### What makes this deploy extra special

Prevents a failure nobody has reported yet: pasting one of these hints into Windows PowerShell 5.1 as
printed fails with *"The token '&&' is not a valid statement separator in this version"*. That happens at
the exact moment the hint is needed, which is after something has already gone wrong.

**Score:** 1

#### Pull Request

Printed console hints no longer chain commands with '&&'

Plugins: dkj-policy

[PR #2663](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2663)

---

### DEPLOY: fix/2655-preview-step-scaffolded · 20260930-140024Z

`new-branch` can now close CREATE with steps a repo names through a new optional seam,
`Get-BranchClosingSteps`, written as open steps after the first one. `adopt-dkj-policy-bwj` proposes it
for the two store repos with the preview question. So *"Is the change visible in the frontend /
storefront?"* is finally written as the last CREATE step, and the step-list gate holds the PR on it, as
[`PREVIEW-portable.md`](../plugins/dkj-policy/dkj-policy-bwj/PREVIEW-portable.md) always said it did.
Until now nothing wrote it
([#2655](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2655)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, the preview handover stops depending on memory once `Get-BranchClosingSteps` is
added to `scripts/repo-config.ps1` (adopt-dkj-policy-bwj, step 2). Every branch created after that
carries the preview question and cannot reach its PR until it is answered. Branches already open get
the line by hand.

**Score:** 3

#### Pull Request

The preview question is scaffolded as the last CREATE step in the store repos

Plugins: dkj-policy, dkj-policy-bwj

[PR #2661](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2661)

---

### DEPLOY: fix/2651-npx-cmd-on-windows · 20260930-134630Z

On Windows, the issue dashboard, the release-notes page and the BWJ page publisher now print
`npx.cmd wrangler ...` instead of `npx wrangler ...`, so the commands they hand over run in PowerShell
under the default execution policy. The deploy step prints on its own line and is no longer joined to
`cd` with `&&`, which Windows PowerShell 5.1 rejects.

**Score:** 2

#### What makes this deploy extra special

Whoever deploys one of these pages from Windows PowerShell can paste the printed commands as they are,
where before each one failed, either as a blocked script (*"running scripts is disabled on this
system"*) or, for the joined `Next:` line, as a parse error on `&&`.

**Score:** 2

#### Pull Request

Print npx.cmd on Windows, where the default execution policy blocks npx.ps1

Plugins: dkj-policy, dkj-policy-bwj

[PR #2660](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2660)

---

### DEPLOY: feat/dashboard-number-label-colours · 20260930-132109Z

The issue dashboard lists the open issues newest first, each led by its issue number instead of a 1..n position,
draws every label in its own GitHub colour, and tints every issue a sweep must skip red.

**Score:** 2

#### What makes this deploy extra special

A repo running the optional issue dashboard sees its rows keyed by the number it already uses, with labels it can recognise at a glance, after re-running -EmitWorker and redeploying.

**Score:** 2

#### Pull Request


The issue dashboard lists newest first, leads with the issue number and draws labels in their GitHub colours

Plugins: dkj-policy

[PR #2658](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2658)

---

### DEPLOY: feat/2656-asana-automation-comments · 20260930-130919Z

The three automated Asana comments of the BWJ ticket flow (issue created, closed, reopened) now use fixed forms, with the
issue as a link: *"— GitHub automation 🤖"* and one sentence, its verb (created, closed, reopened) in bold. The
close update no longer lists the closing pull request, and a reopen now says the task is back in
development.

**Score:** 3

#### What makes this deploy extra special

A store takes the CI half by copying the new `templates/asana-mirror.ps1` over its
`.github/scripts/asana-mirror.ps1`. The CREATED comment comes with the plugin update itself.

**Score:** 3

#### Pull Request

The three Asana automation comments in their fixed form

Plugins: dkj-policy-bwj

[PR #2657](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2657)

---

### DEPLOY: feat/2653-asana-comment-back · 20260930-123802Z

`report-issue` now writes back to an Asana task an issue was made from. The issue link goes on the
first line of the task's description, and one comment in a fixed form goes on the task:
`— New GitHub Issue (automation)`, then *"GitHub issue <url> is created and in development."* A task
the skill creates itself now carries `Tracked on GitHub:` as its first line as well.

**Score:** 2

#### What makes this deploy extra special

A colleague who files a request in Asana now sees on the task itself that it has been picked up and
where it is tracked, without opening GitHub.

**Score:** 3

#### Pull Request

report-issue: comment back on the Asana task an issue was made from, and put the issue link at the top of the task

Plugins: dkj-policy-bwj

[PR #2654](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2654)

---

### DEPLOY: feat/dossier-parks-issue · 20260930-114905Z

A `dossier` issue is now parked like `needs-decision` and `awaiting-recurrence`. `sweep-issues` skips it,
`claim-issue <n>` warns that it is parked, and the issue dashboard shows it as Waiting.

**Score:** 2

#### What makes this deploy extra special

A repo that sweeps its issues no longer spends a pickup on a dossier that cannot be finished in one repair.

**Score:** 2

#### Pull Request


A dossier is parked, so the sweep and the claim skip it

Plugins: dkj-policy

[PR #2652](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2652)

---

### DEPLOY: feat/2649-dashboard-org-mode · 20260930-100945Z

The dashboard worker and `issue-dashboard.ps1` gain an org mode. The logic now keys issues on repo and
number, and its rows carry `repo`. `blocking` is now a list of `{number, repo}`, and nothing outside
the worker reads it. Repo mode's pages, order and output are unchanged, and the suite pins that.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now cover a whole GitHub organization instead of one repository. Run
`issue-dashboard.ps1 -Org <login> -InitToken -EmitWorker` once per organization. Each organization gets
its own worker, token and directory, so several dashboards can be deployed from one checkout. A blocker
in another repository of the same organization now orders normally instead of sinking to the bottom.
Each organization needs a fine-grained PAT of its own, with that organization as resource owner. Setup
is in [the `issue-dashboard` skill](../plugins/dkj-policy/skills/issue-dashboard/SKILL.md).

**Score:** 3

#### Pull Request

The issue dashboard gains an org mode: one worker for every repo of a GitHub org

Plugins: dkj-policy

[PR #2650](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2650)

---

### DEPLOY: fix/2647-dashboard-toml-backtick · 20260930-090915Z

`issue-dashboard.ps1 -EmitWorker` now writes a `wrangler.toml` that wrangler accepts. A PowerShell
escape had split one comment line and left a bare `px wrangler ...` line in the file. The suite now
checks every line of the emitted file, so this class of break is caught before the file reaches wrangler.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now actually be deployed. Until now, a first `npx wrangler deploy` of the
dashboard stopped with `Invalid TOML document: illegal character in key`. A `wrangler.toml` written
by the old version stays broken, because the script never rewrites it. In that file, put `#` back at
the start of the line that begins with `px wrangler secret put`, or delete the file and re-run
`-EmitWorker`.

**Score:** 3

#### Pull Request

issue-dashboard writes a wrangler.toml that wrangler accepts

Plugins: dkj-policy

[PR #2648](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2648)

---

### DEPLOY: fix/2644-shared-stray-token-finder · 20260930-075243Z

The release-notes page and the issue dashboard now share one stray path-token finder
([#2644](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2644)), and neither script behaves
differently. The failure it prevents has not happened yet: a repair to the orphaned-token guard (#1444)
landing in one script and not the other.

**Score:** 1

#### What makes this deploy extra special

N/A -- nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

One shared stray path-token finder for the release-notes page and the issue dashboard

Plugins: dkj-policy

[PR #2646](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2646)

---

