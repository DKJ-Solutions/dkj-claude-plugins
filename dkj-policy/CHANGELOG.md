# Changelog

## [Unreleased]

**5 / 5 minor entries** <!-- pending-tally -->

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

