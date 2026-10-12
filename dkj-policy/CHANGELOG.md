# Changelog

## [Unreleased]

**22 / 23 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2945-asana-prio-label-sync · 20261012-125435Z

In `bwj-development`, the Asana `Prio-Score` -> `prio-N` label sync is back, as a second copied workflow, `asana-prio-label`. It was retired with the `asana-mirror` workflow on October 5. It runs when an issue is opened or edited and once a day over every open issue. It puts exactly one of `prio-1` to `prio-4` on the issue and leaves the labels alone when there is no readable score. A failed Asana read fails the run instead of passing green. `adopt-bwj-development` copies it into the two stores, and `closed-message-sessioncheck` reports a missing or stale copy ([#2945](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2945)).

**Score:** 3

#### What makes this deploy extra special

In a BWJ store repo, an issue linked to a scored Asana ticket gets its priority label without anybody typing it, so the backlog page ranks it again. A store takes it by re-running `adopt-bwj-development`. The session check names the two missing files until it has.

**Score:** 3

#### Pull Request

The Asana Prio-Score -> prio-N label sync is back, as its own workflow

Plugins: bwj-development

[PR #2948](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2948)

---

### DEPLOY: feat/2943-golive-live-since · 20261012-123133Z

`build-golive-block` takes `-LiveSince <date>` for an issue that closes after its change went live, which is the normal case for one parked `awaiting-release`, or work pushed live on its own. The block then reads *Het staat live sinds ...* / *It has been live since ...* instead of naming the next release day. It also drops the private-window caveat on the live URLs and the "last moment before a customer sees it" line in the ask. A date after today is refused, and so is `-LiveSince` beside `-From` or `-ReleaseDay` ([#2943](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2943)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, the closed message on a ticket that is already live now tells the requester it is live, and since when. Before, it told them it would go live next Monday, and #190 had to be closed with a hand-written comment instead.

**Score:** 2

#### Pull Request

golive-block -LiveSince: a block for a change that is already live

Plugins: bwj-development

[PR #2947](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2947)

---

### DEPLOY: fix/2942-triage-label-color-drift · 20261012-122347Z

`adopt-triage-labels` now compares the colour of every canonical label that already exists, not just its name. A label in another colour is reported `[drift]` with a paste-ready `gh label edit --color` line beside it, still printed and never run, and the summary counts it. The comparison reads the repo's own `Get-TriageLabels` answer, so a repo that wants its own colours declares them there. Descriptions are not compared. Closes #2942.

**Score:** 2

#### What makes this deploy extra special

A consumer whose tracker has a parking or priority label in the wrong colour now sees it named, with the one command that fixes it, where the report used to call it fine.

**Score:** 2

#### Pull Request

adopt-triage-labels reports a wrong-colored canonical label as [ok]

Plugins: dkj-policy

[PR #2946](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2946)

---

### DEPLOY: feat/2940-asana-origin-reach-label · 20261012-121358Z

In `bwj-development`, an issue made from an Asana ticket now carries the reach label by construction. WORKFLOW-portable sections 2 and 8 and `report-issue` say so. When `claim-issue` or `new-branch` picks up an issue that links an Asana task but lacks the label, `asana-link-pickupcheck` prints a `REACH LABEL MISSING` line with the `gh issue edit` that adds it. Until now only the issue -> card direction was enforced, by `guard-asana-mirror`. Both hooks now read the label's name through one function, `Get-ProjectReachLabel` ([#2940](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2940)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, a ticket a colleague filed in Asana no longer drops out of the minor backlog because whoever copied it into GitHub forgot the reach label. The pickup names the missing label and gives the command that adds it.

**Score:** 2

#### Pull Request

An issue made from an Asana ticket carries the reach label, and pickup flags one that does not

Plugins: bwj-development

[PR #2944](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2944)

---

### DEPLOY: fix/2938-warn-two-awaiting-labels · 20261012-115749Z

`claim-issue` now reads the rule [#2936](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2936)
wrote down, that an issue carries at most one `awaiting-*` label. Where an issue carries two or more
parking labels, the single-issue claim prints a `TWO PARKING LABELS:` line under its `PARKED:` verdict,
and `-Candidates` adds the same sentence to the skip reason. It is advisory only, refuses nothing, and
makes no extra `gh` call ([#2938](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2938)).

**Score:** 2

#### What makes this deploy extra special

A session claiming or sweeping an issue with two parking labels now gets told which ones they are,
instead of having to spot the second label itself. The failure this prevents is the lapsed label that
nobody takes off.

**Score:** 1

#### Pull Request

claim-issue warns when an issue carries two awaiting-* labels

Plugins: dkj-policy

[PR #2941](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2941)

---

### DEPLOY: docs/2936-one-awaiting-label · 20261012-110037Z

`CONTRIBUTING-portable.md` now states that an issue carries at most one `awaiting-*` parking label. Setting one replaces any other, in the same `gh issue edit`. Where the wait is transitive, meaning the issue waits on a pull request whose own issue is parked on something else, the issue takes the label for that root wait instead of `awaiting-pull`, and its body names the blocking issue. A record is the one exception: it keeps `awaiting-recurrences`, because that label governs how it is closed. Closes #2936.

**Score:** 2

#### What makes this deploy extra special

A consumer's sessions stop stacking two parking labels on one issue, because the rule they label by now says which single label wins.

**Score:** 2

#### Pull Request

An issue carries at most one awaiting-* label

Plugins: dkj-policy

[PR #2939](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2939)

---

### DEPLOY: docs/2935-maikel-co-owner · 20261012-103950Z

Maikel (`maikel-bwj`) is now an owner of this repo with the same approval rights as Dave: `.claude/rules/this-repo.md` names both, so every owner gate in the constitution (visible results, releases, repo settings, publishing) accepts either one's word. The lens gates that said "wait for Dave's word" now say "the owner"; decisions attributed to Dave by name and date stay his. Closes #2935.

**Score:** 3

#### What makes this deploy extra special

N/A -- governance of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

Maikel is a co-owner with the same approval rights as Dave

[PR #2937](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2937)

---

### DEPLOY: fix/2930-golive-post-waits-for-a-pr · 20261012-100943Z

`build-golive-block -Post` now waits until the issue's work is in a pull request. It refuses while no open or merged PR closes the issue, or while it cannot read that. `-Force` makes a deliberate early post. `-OutFile` still works at the preview, so the handover page keeps its copy. The skill page and PREVIEW-portable now place the post at the PR step, after the owner's look
([#2930](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2930)).

**Score:** 2

#### What makes this deploy extra special

A store owner no longer finds a closed message with a release date on work they have not looked at yet. Measured on xoxowildhearts#402, where the block went on nine seconds after the preview handover.

**Score:** 3

#### Pull Request

build-golive-block -Post waits until the issue's work is in a pull request

Plugins: bwj-development

[PR #2934](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2934)

---

### DEPLOY: feat/2929-ruleset-allowed-merge-methods · 20261012-100110Z

`check-repo-settings` can now watch a ruleset's `allowed_merge_methods`
([#2929](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2929)). Declare
`ruleset.allowed_merge_methods` in the repo-settings seam and the check reads it from the trunk's
`pull_request` rule as a sorted set. A ruleset that lets squash back in then turns the check red, where
before only the repo's own merge switches could be watched. Where no `pull_request` rule applies, the
field reads as unreadable, not as an empty set. Measured at smartwatchbanden#900: a ruleset allowed
`merge,squash,rebase` while the tooling merges with `merge`.

**Score:** 2

#### What makes this deploy extra special

A repo that depends on merge commits, a store's reconciliation-base sync among them, can now have the
scheduled settings check guard the ruleset as well as the repo switches.

**Score:** 2

#### Pull Request

check-repo-settings reads a ruleset's allowed_merge_methods

Plugins: dkj-policy

[PR #2932](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2932)

---

### DEPLOY: fix/2928-pickup-asks-and-one-task-one-issue · 20261012-095336Z

The Asana pickup check no longer stays silent on an issue that neither links nor mentions Asana. It asks the session whether the issue started from an Asana task, because that evidence can sit on the task alone. It also names an Asana task that is already linked from another open issue, since section 8 says one GitHub issue per ticket. Section 8 now tells a developer starting from a task to file through `report-issue`
([#2928](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2928)).

**Score:** 2

#### What makes this deploy extra special

A store team picking up an issue that was filed by hand from an Asana task is asked about it before any work starts, rather than finding out when the requester never hears back. Measured in xoxowildhearts: #401 and #402 came from one task, never said so, and ran the chain unnoticed.

**Score:** 3

#### Pull Request

The Asana pickup check asks about an unmentioned issue and warns when one task is linked from two issues

Plugins: bwj-development

[PR #2931](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2931)

---

### DEPLOY: feat/2925-reconcile-base-prints-merge · 20261012-094001Z

`sync-main -ReconcileBase` now prints the whole finish of the reconciliation base, not only how to
open its PR: `gh pr create`, then `gh pr checks <branch> --watch`, then `gh pr merge <branch> --merge`.
It also says that whoever runs the sync merges it, with no review to wait for, because the branch
changes no file ([#2925](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2925)). At
smartwatchbanden#892 the PR was opened with the printed line and then left open behind a comment
asking somebody else to merge it, blocking the follow-up.

**Score:** 2

#### What makes this deploy extra special

A store colleague running a conflicted sync gets a finish they can paste to the end, so the follow-up
work is no longer blocked on a PR nobody knew was theirs to merge.

**Score:** 2

#### Pull Request

sync-main -ReconcileBase prints the whole finish, merge included

Plugins: dkj-subagents-shopify

[PR #2927](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2927)

---

### DEPLOY: fix/2923-tier0-na-names-the-score-line · 20261012-093037Z

The refusal for a tier-0 `N/A` now names the heading its Score line sits under, so the reader no longer has to work out which line "tier 0" means. When the audience tier carries a number at the same time, the refusal says the two answers look swapped and how to move them. `open-pr` no longer says "Correct the table" for an entry that has no table
([#2923](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2923)).

**Score:** 2

#### What makes this deploy extra special

A session that put its two scores in each other's slot gets one refusal that names the fix, not a retry loop. Measured in smartwatchbanden, where the loop ran across most of an hour.

**Score:** 2

#### Pull Request

The tier-0 N/A refusal names the Score line it means and spots a swapped pair

Plugins: dkj-policy

[PR #2926](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2926)

---

### DEPLOY: fix/2919-asana-link-pickup-check · 20261012-091710Z

`bwj-development` now warns at pickup when an issue names Asana but links no Asana task
([#2919](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2919)). After `claim-issue` or
`new-branch` picks up an issue, a new PostToolUse hook, `asana-link-pickupcheck`, reads it. Where the
title or body mentions Asana and neither a marker, a header row nor a task URL links one, it tells the
session to write both halves of the link before any work. A colleague's bug copied with a plain
`gh issue create` (xoxowildhearts#404) had run the whole chain that way, and the requester would have
heard nothing when it shipped. The hook starts PowerShell only when one of those two scripts runs.

**Score:** 2

#### What makes this deploy extra special

A colleague who reports a bug in Asana hears back when it ships, because the session is now told at
pickup when the issue it works on has lost the link to their task.

**Score:** 3

#### Pull Request

bwj-development warns at pickup when an issue from Asana links no task

Plugins: bwj-development

[PR #2922](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2922)

---

### DEPLOY: fix/2918-golive-block-checks-asana-link · 20261012-090906Z

`build-golive-block` now checks the issue's Asana link before it promises anything. It uses
`Resolve-AsanaTaskRef`, the matcher `asana-closed-message` uses. The issue body may link no task, or
more than one. Then the lead no longer says *"no paste needed"* and `-OutFile` warns. `-Post` refuses
until the `<!-- asana-task: <gid> -->` marker is added, and `-Force` covers an issue that is
GitHub-only. A print-only run still reads nothing
([#2918](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2918)).

**Score:** 2

#### What makes this deploy extra special

A store team no longer tells a requester "no paste needed" on an issue whose close reaches nobody.
Measured on xoxowildhearts#404: an Asana-filed bug, unlinked, got that promise, and its reporter would
have heard nothing when it shipped.

**Score:** 3

#### Pull Request

build-golive-block checks the issue links an Asana task before promising the closed message carries the block

Plugins: bwj-development

[PR #2921](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2921)

---

### DEPLOY: feat/2917-awaiting-info-client · 20261012-084728Z

The `awaiting-more-info` parking label is now `awaiting-info-client`, so it says who owes the answer, in
the same shape as `awaiting-decision-client`
([#2917](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2917)). `claim-issue`, the sweeps,
the issue dashboard and the BWJ closed message still answer to the old name, because a tracker keeps it
until somebody renames it there. `adopt-bwj-development` prints the in-place rename:
`gh label edit awaiting-more-info --name awaiting-info-client --color 5319E7`.

**Score:** 2

#### What makes this deploy extra special

A BWJ store team that parks a ticket on its requester uses a new label name, and renames the label on its
tracker once, with the command above. Nothing stops working before they do.

**Score:** 3

#### Pull Request

Rename the awaiting-more-info label to awaiting-info-client

Plugins: bwj-development, dkj-policy

[PR #2920](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2920)

---

### DEPLOY: feat/2913-notes-page-url-in-closeout · 20261012-083008Z

`publish-page -Kind notes` now ends with a `Close-out:` line that carries the release-notes page URL,
once the read-back has proven what the URL serves. A BWJ store cut's receipt ends with that link, so
the page that goes to management is in the close-out rather than in a lens or the scroll-back
([#2913](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2913)).

**Score:** 2

#### What makes this deploy extra special

The person running a store cut gets the management link handed to them in the receipt, in both store
repos.

**Score:** 2

#### Pull Request

publish-page prints the release-notes URL as the cut's close-out line

Plugins: bwj-development

[PR #2916](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2916)

---

### DEPLOY: fix/2912-sync-heads-first-parent · 20261012-081645Z

`live-preflight` and `prepare-release` no longer drop our own merged files from the live push list
after a trunk-into-sync merge. A merge of the trunk *into* a `sync/` branch names that branch in its
subject, so it was read as a sync and the trunk's commits it brought over were counted as the sync's.
Their paths were classified `sync-owned` and held back, and the live-push record would have written
them `live`. The sync heads are now read on the trunk's first-parent line only, where just the merge
that brought the sync in appears
([#2912](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2912)).

**Score:** 2

#### What makes this deploy extra special

A store team's push list stops silently losing merged work. Measured in xoxowildhearts, the halved
`theme.css` from #358 would have stayed off live while the changelog said it shipped.

**Score:** 4

#### Pull Request

Sync provenance reads sync heads on the trunk's first-parent line only

Plugins: bwj-development, dkj-subagents-shopify

[PR #2915](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2915)

---

### DEPLOY: fix/2911-obligations-read-reach-section · 20261012-080317Z

`prepare-release` now finds go-live obligations written in an entry's reach section
(`#### What makes this deploy extra special`), not only in the text above it. In a tier-1 store that
section is where an author writes what somebody must do after the live push. At smartwatchbanden
v2.47.0 the run reported 0 obligations across 37 entries while one sat there: *"Once this is live,
test 0212-26 can be switched off in Convert."* Only the Pull Request section, a title and a link, is
still left out
([#2911](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2911)).

**Score:** 2

#### What makes this deploy extra special

A store team preparing a release on Friday sees, in step 6, the experiments and settings they must
switch after Monday's push, where it printed an empty list before.

**Score:** 3

#### Pull Request

prepare-release reads go-live obligations in an entry's reach section too

Plugins: bwj-development

[PR #2914](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2914)

---

### DEPLOY: fix/2909-closed-message-bold-state-word · 20261009-105047Z

In a BWJ store repo's Asana comments, only the state word is bold now: the reopened line reads "is
**reopened:**" where it read "**is reopened:**". A not-planned close that keeps `awaiting-more-info` on
now posts "is **closed:** there is not enough information to start development yet. Once the questions
above are answered, the issue will be reopened and the work picks up again." -- the wording the
requester fixed in #2902's thread -- instead of "**is on hold:** it is closed as not planned until more
information comes in, and is reopened when it does."

**Score:** 2

#### What makes this deploy extra special

A store repo picks this up only by copying the new `asana-closed-message.ps1` template into
`.github/scripts/`, since the copy there does not update itself.

**Score:** 2

#### Pull Request

asana-closed-message: bold only the state word, and post the on-hold wording fixed in #2902

Plugins: bwj-development

[PR #2910](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2910)

---

### DEPLOY: fix/2907-closed-message-trust-by-permission · 20261009-101038Z

`asana-closed-message` now carries the go-live block when its author is an org member whose membership is
private. The workflow token reads such a member as `CONTRIBUTOR`, so until now the block was dropped and
the Asana task got the bare closed line, logged as "none was on the issue". The author of a block comment
with an untrusted association is now asked about by repo permission, and the block is carried when that
answers admin or write. Every block comment that is carried this way or dropped is logged with its
association and permission, and a dropped block is logged as dropped.

**Score:** 3

#### What makes this deploy extra special

A store repo picks this up only by copying the new `asana-closed-message.ps1` template into
`.github/scripts/`, since the copy there does not update itself. Whether the workflow token may read the
permission endpoint is not yet measured on a runner. The first close after the copy says which: the log
shows either `carried on repo permission` or `permission could not be read`.

**Score:** 3

#### Pull Request

asana-closed-message: trust a go-live block by its author's repo permission, so private org members' blocks are carried

Plugins: bwj-development

[PR #2908](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2908)

---

### DEPLOY: feat/2904-awaiting-recurrences-labels · 20261009-081837Z

The two recurrence labels are renamed so they read as one pair: `awaiting-first-recurrence` is now
`awaiting-recurrences-first` and `awaiting-more-recurrences` is now `awaiting-recurrences`. Every old name
is still matched by `open-pr`'s record gate, both pickup routes and the issue dashboard, and
`adopt-triage-labels` prints the `gh label edit` that renames each label in place. Either label may now be
closed as `not_planned` with the label kept while it waits, and a recurrence reopens it; a record whose root
cause is repaired is still closed as completed. The search before filing reads closed issues too
(`gh issue list --state all --label ...`), in the shared filing bar, `report-issue` and
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md).

**Score:** 3

#### What makes this deploy extra special

A consumer should run `adopt-triage-labels` after updating and paste the two `gh label edit` lines it
prints, so its tracker carries the new names: a session filing with the new label name otherwise fails on
a label the tracker does not have yet. Long-parked recurrence issues can now be closed as not planned
without losing them.

**Score:** 4

#### Pull Request

Rename the recurrence labels to awaiting-recurrences(-first) and let them close as not planned

Plugins: bwj-development, dkj-policy, dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2906](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2906)

---

### DEPLOY: feat/2902-not-planned-on-hold-message · 20261009-073052Z

`bwj-development`'s `asana-closed-message` template gains a third message. `Get-ClosedMessageDecision`
now returns which message a run posts, and a close as not planned that still carries `awaiting-more-info`
is the on-hold message. The workflow template passes the issue's labels to the script for that. The
docs that said a not-planned close always posts nothing now say when it does not.

**Score:** 2

#### What makes this deploy extra special

A BWJ store's `asana-closed-message` workflow now tells the Asana task that an issue is **on hold** when
it is closed as not planned with the `awaiting-more-info` label kept on. Until now that close posted
nothing, so a session that wanted the requester to hear about it had to close the issue as completed,
and the task then read *"is now closed"* while a question was still open. A close as not planned without
the label, or as a duplicate, still posts nothing. The workflow and its script are taken together at the
re-adopt; a new script under an old workflow gets no labels and stays silent as before.
Requested in [#2902](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2902).

**Score:** 2

#### Pull Request

asana-closed-message posts an on-hold message on a not-planned close while waiting for info

Plugins: bwj-development

[PR #2903](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2903)

---

### DEPLOY: fix/2899-cut-release-origin-check · 20261008-071817Z

`cut-release.ps1` now fetches `origin/main` and refuses unless local `main` is exactly that, naming
the commits it is behind or ahead. It checks twice: before the gates, and again after them, before the
first write, because the gate minutes are when merges land. A refusal there leaves the tree untouched,
where before a merge during the gates left a local release commit and tag that only an owner-gated
`reset --hard` could unpick. `-SkipOriginCheck` is the escape valve, and a repo with no `origin` remote
skips the check on its own and says so.

**Score:** 3

#### What makes this deploy extra special

If you cut releases with `cut-release`, a release can no longer be built on a `main` that is behind
GitHub: the cut stops before it writes anything and tells you to `git merge --ff-only origin/main`. With
`-NoPush` the command it prints is now a single atomic push, so a rejected `main` can no longer publish
the tag on its own.

**Score:** 2

#### Pull Request

cut-release refuses a main that is not origin/main

Plugins: dkj-policy

[PR #2901](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2901)

---

