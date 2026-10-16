# Changelog

## [Unreleased]

**12 / 16 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3078-ship-pr-diverged-trunk · 20261016-141753Z

`ship-pr` no longer merges a PR it cannot fold locally (inbound #3078). When this checkout's `main` carries
commits that `origin/main` lacks, usually the redundant fold commit of an earlier ship that lost the fold
race, the run now stops before anything is pushed and prints the log to read and the two commands that
realign the trunk. When the fast-forward still fails after the merge, it first checks whether `origin/main`
already carries the fold. If it does, it says so instead of reporting a fold that is still owed.

**Score:** 3 -- a false "fold is still owed" after a merge, met in dkj-brandbook on PR #167

#### What makes this deploy extra special

A maintainer who ships several branches in a row with `fold-on-merge` active is no longer left with a
merged PR and a refusal that names a state that does not exist. The stop now comes before the merge, where
it costs nothing.

**Score:** 3

#### Pull Request

ship-pr refuses a trunk ahead of origin before the merge, and checks upstream before saying the fold is owed

Plugins: dkj-policy

[PR #3079](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3079)

---

### DEPLOY: docs/3072-bwj-overview-texts · 20261016-135041Z

The `bwj-development` row in the teams README and the plugin's marketplace description no longer say
that closing an issue tells Asana nothing, or that the plugin ships one hook
([#3072](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3072)). Both now say that the
`asana-closed-message` workflow posts on the task when an issue is closed, reopened or parked on hold,
and that four hooks ship. They match the plugin's own README again, so a maintainer editing the
plugin no longer has two overview texts contradicting the one they are editing.

**Score:** 1

#### What makes this deploy extra special

A reader browsing the marketplace sees the plugin described as it actually behaves. Before this
change they read that a close goes unnoticed on Asana, which has not been true since October 5.

**Score:** 1

#### Pull Request

bwj-development overview texts say what the plugin does now

Plugins: bwj-development

[PR #3075](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3075)

---

### DEPLOY: docs/3073-reopen-only-for-code · 20261016-134302Z

In a BWJ store, a closed issue is now reopened only when a file in the repo has to change (#3073).
Admin-only work, such as a metaobject, a metafield, a setting or content, never reopens it. Where the
requester can do that work themselves, the session answers with an instruction they can follow now and
next time. Where they cannot, development does the admin act without reopening and without a go-live
block.

**Score:** 2 -- prevents a reopened/closed pair on a task for work that never touched the repo

#### What makes this deploy extra special

A requester stops seeing "back in development" on their task for admin-only follow-ups, and gets an
instruction to do such work themselves next time.

**Score:** 2

#### Pull Request

bwj-development: reopen only when repo code changes; admin-only follow-ups go to the requester

Plugins: bwj-development

[PR #3077](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3077)

---

### DEPLOY: feat/3070-notify-live · 20261016-132827Z

The `bwj-development` plugin gains `notify-live`. It is a script a person runs right after a store
release's live push and cut. It tells the Asana task of every issue that release carried, if that task
was told the result "becomes visible with the release", that the work is now live, as version vX.Y.Z,
and that the review can start. The message repeats the go-live block's own closing ask, in the block's
language. It is a dry run until `-Post`, it never tells a task twice, and `prepare-release`'s runbook
now prints it as the step after the cut (#3070).

**Score:** 3 -- a hand step that used to be missing

#### What makes this deploy extra special

A requester whose closed message said "visible with the release" is now told when that release is out.
Until now they had to work out for themselves whether that day's release carried their work. The store
maintainer gains one step on release day, and the runbook prints it.

**Score:** 3

#### Pull Request

bwj-development: tell each carried issue's Asana task when its release goes live

Plugins: bwj-development

[PR #3074](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3074)

---

### DEPLOY: feat/3069-closed-message-intros · 20261016-130027Z

In `bwj-development`, the message a closed issue posts on its Asana task now opens with where the
task goes ([#3069](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3069)). Every close as
completed opens with *"GitHub issue owner/repo#n is now **closed**: this Asana task is now in
review."*. Only the line under it differs:

- a visible change invites a reopen, as before;
- a block that names a planned release day (no `-LiveSince`) says the result becomes visible with
  that release. `build-golive-block` marks such a block with
  `<!-- asana-paste-block-kind: after-release -->`;
- a research close says *"Nothing has changed. Read the outcome below."*, replacing #3017's *"the
  Asana task is ready for review"*.

The not-planned on-hold close opens with *"this Asana task has been cancelled, because there is not
enough information to start development."*. It never says "in review". The `golive-block` skill and
`WORKFLOW-portable.md` now say `-Research` is only for when nothing changed on the store or in the
repo, so a store-admin act that is already live takes the go-live form with `-LiveSince`.

**Score:** 3

#### What makes this deploy extra special

A BWJ store maintainer takes the new `asana-closed-message.ps1` through `adopt-bwj-development`, and
their colleagues read the new intros on the next close. Blocks posted before this version carry no
after-release marker, so they keep the plain reopen line.

**Score:** 3

#### Pull Request

bwj-development: closed messages open with the task's destination; -Research only when nothing changed

Plugins: bwj-development

[PR #3071](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3071)

---

### DEPLOY: feat/dashboard-owner-groups · 20261016-122013Z

The connector dashboard (`scripts/dashboard/serve-connector-dashboard.ps1`) now groups its repos as
**BWJ repos**, **DKJ repos** and **Other repos**. A repo's group is read from the owner in its connector
manifest's `repo` slug (`BWJ-Development`, `DKJ-Solutions`, anything else), so a newly registered repo
lands in the right group without an edit; inside a group the order is unchanged, worst status first,
then by name, and a group with no repos is left out.

The page's h1 is the repo's name, `dkj-claude-plugins`. A card headed **Connected repos** holds a table
per group, the group named in the first column head, all sharing one fixed column set so their columns
line up. A second card headed **Issues** carries an h3 per group and a house `mini-card` per repo with its
details. Each group opens with a rule above its h3 and a line under it counting its repos and each
status, worst first (`3 repos · 1 needs action · 1 not on this machine · 1 in sync`), and a repo's name
in its card is set a size below that h3, so a group heading no longer reads as part of the card above.

The Overview's **Errors** and **Notes** columns are gone: the tiles at the top count both, and each repo's own lines are in its Issues card. So is its **Checkout** column. What a checkout is checked out on and whether it holds
uncommitted work said nothing about the repo, so the card no longer shows it either: it shows the last
commit on the checkout's trunk, read from local refs. Nothing is fetched.

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local tool for this repo's maintainers and is not shipped in any plugin.

**Score:** N/A

#### Pull Request

Connector dashboard groups repos by owner: BWJ, DKJ and other

[PR #3068](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3068)

---

### DEPLOY: fix/3062-extension-may-close-act-only · 20261016-120740Z

The core's `CONTRIBUTING-portable.md` now permits an extension to close an act-only issue as completed,
with a record of the act and of who performs it, instead of parking it under `awaiting-action-dev`
([#3062](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3062), Maikel, October 16, 2026).
`bwj-development` uses that permission through its #3059 rule. That rule had contradicted the core, and
since the core wins, that rule would have had to give way. A repo without such an extension still parks the issue. The
`sweep-issues` skill's parking step says the same.

**Score:** 2

#### What makes this deploy extra special

Nothing changes in how either kind of repo works. What it prevents: a session in a `bwj-development`
repo reads both pages, applies "the core wins" and parks an act-only issue under `awaiting-action-dev`,
where the extension says to close it. That has not happened yet.

**Score:** 1

#### Pull Request

An extension may close an act-only issue instead of parking it

Plugins: bwj-development, dkj-policy

[PR #3067](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3067)

---

### DEPLOY: feat/3064-repo-dashboard-label · 20261016-114424Z

The dev-preview hook's session-start line now opens with `Repo dashboard:` in every DKJ-Solutions repo
([#3064](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3064), the owner's term, October 16,
2026). It used to open with whatever word each repo chose through `Get-DevPreview`'s `Name` (Showcase,
connector dashboard, dev-preview), so the same page had three names. The plugin now fixes the label, the
placeholder's included. A `Name` a repo still states is ignored rather than refused, so delete it at your
next edit. The hook's lines about its own setup (skipped, config unreadable, a config it cannot run) keep
the `dev-preview:` prefix, because that word names the mechanism.

**Score:** 2

#### What makes this deploy extra special

In every DKJ-Solutions repo, the link to the repo's local page at session start now reads
`Repo dashboard: http://localhost:...`, whatever the repo once called it.

**Score:** 2

#### Pull Request

dev-preview: one fixed label, Repo dashboard

Plugins: dkj-solutions

[PR #3065](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3065)

---

### DEPLOY: docs/3059-act-only-issue-closes · 20261016-104312Z

`bwj-development`'s ticket-handling page now says that an issue stays open only while it will still change
code in the repo ([#3059](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3059), Maikel,
October 16, 2026). An issue whose remaining work is only an act outside the repo (a release, a publish in
the Shopify admin, an owner's decision) closes as completed with a research block naming that act. The
page gives the test, "does any step still change a file in the repo?", and says to move a lone code step
into the issue that already carries the related code work. The core still parks such an issue under
`awaiting-action-dev`, and which of the two yields is filed as
[#3062](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3062). The same page's description of
the go-live guard's fail-open is brought in line with #3058.

**Score:** 2

#### What makes this deploy extra special

In a store repo running `bwj-development`, a session closes an issue whose only remaining step is a store
act or a release, with a research block naming that act, instead of parking it. The open issues and the
`In Progress` column then show only work that can still be built.

**Score:** 3

#### Pull Request

An issue stays open only while it will still change code

Plugins: bwj-development

[PR #3063](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3063)

---

### DEPLOY: fix/3058-guard-fail-open-visible · 20261016-102909Z

`guard-stale-paste-block` now tells the session when it let a command through unchecked
([#3058](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3058)). Each fail-open path used to
write its warning to stderr and exit 0, which Claude Code never shows the model, so a close with no go-live
block went through in smartwatchbanden#946 and nothing in the session said the check had been skipped.
The hook now prints PreToolUse JSON whenever something was not checked: `additionalContext` for the model,
and `permissionDecision: "ask"` when the unchecked command is a `gh issue close`, because a close has no
later check that can still stop it.

**Score:** 3

#### What makes this deploy extra special

In a store repo running `bwj-development`, a hand close of an Asana-linked issue that the guard could not
check now stops at a permission prompt that names the issue, instead of quietly posting the bare closed
line to the Asana task. A ship the guard could not check still runs, and the session is now told so.

**Score:** 3

#### Pull Request

guard-stale-paste-block makes a fail-open visible to the session

Plugins: bwj-development

[PR #3061](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3061)

---

### DEPLOY: fix/3056-one-retired-extension-repair · 20261016-101309Z

The repair for an enabled plugin id under a retired extension name (`dkj-policy-bwj`,
`dkj-policy-dkjs`) is now composed by one helper, `Get-RetiredExtensionRepair` in
`scripts/lib/claude-md-import-lib.ps1`
([#3056](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3056)).
`consumer-prose-sessioncheck`, `plugin-versions` and `update-plugins` had each written that sentence out
for themselves, so a change to the command in one would drift from the other two. The tests for all three
now assert the helper's sentence itself. The session check's warning also gains the settings step and the
repo's own marketplace name in place of a `<marketplace>` placeholder.

**Score:** 2

#### What makes this deploy extra special

A consumer still enabling a retired extension name sees the same repair as before, now worded alike in
all three places. Nothing changes in how they work.

**Score:** N/A

#### Pull Request

One helper composes the retired-extension repair

Plugins: bwj-development, dkj-policy

[PR #3060](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3060)

---

### DEPLOY: fix/3055-retired-plugin-id-in-update-tools · 20261016-095331Z

`update-plugins` and `plugin-versions` now recognise a retired plugin id
([#3055](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3055)). A checkout still enabling
`dkj-policy-bwj` or `dkj-policy-dkjs` (renamed in #2788) made `update-plugins` call
`claude plugin update` on a name the marketplace no longer declares and count it as `FAILED`, which
turned the whole checkout red in an `-AllCheckouts` sweep. The `plugin-versions` receipt printed at
the end of the run then advised a marketplace refresh that step 1 of the same run had just done. Now
`update-plugins` skips that id and names its successor, and `plugin-versions` reports it as `retired`
with the real repair: enable the successor and install it.

**Score:** 2

#### What makes this deploy extra special

An `update-plugins` run in a repo that has not migrated off a retired extension name no longer reports
failure. It names the one change that fixes it, instead of advising a refresh that cannot help.

**Score:** 1

#### Pull Request

update-plugins and plugin-versions recognise a retired plugin id

Plugins: dkj-policy

[PR #3057](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3057)

---

### DEPLOY: fix/3053-trusted-root-guard-exemption · 20261016-092814Z

`merge-on-green` can ship a PR in this repo again
([#3053](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3053)). The runner runs
`ship-pr.ps1` from a `trusted-main` checkout of the trunk while `CLAUDE_PROJECT_DIR` names `pr-branch`,
and the source-repo guard refused that as a released copy, because the two are separate clones and
`pr-branch` carries both the marketplace and its own copy. So PR #3051 sat green and armed through
every sweep. `-TrustedRoot` (and `open-pr`'s `-SeamRoot`) now declares that tree in
`DKJ_GUARD_TRUSTED_ROOT`, the guard exempts a script inside it, and the fold and
`verify-resolved-issues` children inherit the declaration. The plugin cache is still refused.

**Score:** 2

#### What makes this deploy extra special

A consumer has no marketplace, so the guard never refused it and nothing changes for it.

**Score:** N/A

#### Pull Request

merge-on-green can ship in the source repo: the own-copy guard exempts the declared trusted tree

Plugins: dkj-policy, dkj-subagents-shopify

[PR #3054](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3054)

---

### DEPLOY: fix/3049-update-plugins-conflicting-scopes · 20261015-214246Z

`update-plugins` now updates every install record a checkout holds for a plugin, at each scope those
records name ([#3049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3049)). Where a
checkout's records disagreed on scope (a `project` and a `local` record side by side, a state a
session start can produce), the run fell back to one `--scope project` call and left the other record
behind, under `0 failed`, while its own receipt said `CONFLICTING`. A path-less `user` record beside
them was skipped as well. Now each scope gets its own `claude plugin update`, `managed` excepted, and the
disagreement is named before step 1.

**Score:** 2

#### What makes this deploy extra special

`update-plugins` no longer leaves a second copy of a plugin behind in a checkout that holds two install
records for it, so a session there stops loading the older version after a run that reported success.

**Score:** 2

#### Pull Request

update-plugins updates every disagreeing checkout record, one call per scope

Plugins: dkj-policy

[PR #3051](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3051)

---

### DEPLOY: fix/3038-connector-dashboard-test-windows · 20261015-201744Z

`connector-dashboard.tests.ps1` failed on loaded CI shards and passed on a rerun
([#3038](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3038)), first in group 3's page
asserts, then in group 2's stalled-connection assert. Its 3s read window held about a 3x margin over
the measured unloaded latency, so it now reads for 15s and waits up to 30s for the server to start. A
passing run costs nothing extra, and a stalling server still fails, because the stalling client stays
open until after its assert. Group 3 now asserts its start-up on its own, so a recurrence says which
window it overran.

**Score:** 1

#### What makes this deploy extra special

A test suite of this repo's own CI only; nothing a plugin user installs or runs changes.

**Score:** N/A

#### Pull Request

connector-dashboard tests: widen the read and start-up windows that a loaded CI runner overran

[PR #3052](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3052)

---

### DEPLOY: feat/update-plugins-all-checkouts · 20261015-192917Z

`update-plugins` takes a new `-AllCheckouts` switch that runs the update in every checkout on the
machine holding a plugin install record, in one command. The checkouts are read off
`~/.claude/plugins/installed_plugins.json`, so no folder list is kept. A checkout that is not on its
trunk, or that has uncommitted changes under `.claude/`, is skipped, so a mid-work branch is never
touched ([#1890](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1890)'s concern). Each
checkout is handed its own root explicitly, because a session's `CLAUDE_PROJECT_DIR` would otherwise
send every child run to the session's repo. Records whose folder is gone are counted in one line.

**Score:** 3

#### What makes this deploy extra special

Updating the plugins in every repo on a machine is now one command instead of one run per repo:
`update-plugins.ps1 -AllCheckouts`, or ask for "update all repos". Repos on a feature branch or with
uncommitted `.claude/` changes are skipped and listed, and `-DryRun` shows every command first.

**Score:** 3

#### Pull Request

update-plugins -AllCheckouts: update every checkout on this machine in one run

Plugins: dkj-policy

[PR #3050](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3050)

---

