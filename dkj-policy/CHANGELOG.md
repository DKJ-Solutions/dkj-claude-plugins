# Changelog

## [Unreleased]

**7 / 17 minor entries** <!-- pending-tally -->

### DEPLOY: docs/2750-issue-labels-not-types · 20261003-115007Z

`report-issue` no longer sets a GitHub issue type. It classifies an issue by label: `bug` for a defect
in existing behaviour, `feature` for a capability the store does not have yet, and neither for
everything else, which counts as a task. Where the Asana board has a `Github Type` field, it is filled
from that label. `adopt-dkj-policy-bwj` now checks for `bug` and `feature` and prints the create line
for whichever is missing. Both were deleted from the BWJ stores in September, so a store has to create
them before the next filing that uses one.

**Score:** 3

#### What makes this deploy extra special

Nothing beyond the switch itself.

**Score:** N/A

#### Pull Request

dkj-policy-bwj: classify issues by label, not by GitHub issue type

Plugins: dkj-policy-bwj

[PR #2772](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2772)

---

### DEPLOY: fix/2752-flag-plugin-tree-in-consumer-pr · 20261003-114702Z

**Inside this repo:** the residual that #2746 left open, a planted plugin tree in a consumer, now has a
CI check, pinned by `branch-entry-gate.tests.ps1`. The step is in the consumer runner only. This
repo's own `branch-entry.yml` runs its own tree's scripts on its own PRs.

**Score:** 1

#### What makes this deploy extra special

**For a consumer that calls the reusable branch-entry runner:** its branch-entry check now goes red on a
pull request whose tree tracks a path shaped like an installed plugin's, or a symlink or submodule under
a `.claude` name, and an annotation says why. The allow rules `specialists-init` proposes run a workflow
script at such a path without a prompt, with `-ExecutionPolicy Bypass`. A glob can pin the path's shape
but not its location, so a plugin tree committed into the repo would have run unprompted. Callers get the
check without re-adopting and without any extra token scope. A repo still on a full copy of the runner
does not get it. It is a flag, not a guarantee: it binds only where the check is required. It prevents a
failure that has not happened yet.

**Score:** 1

#### Pull Request

The consumer's branch-entry check flags a pull request that tracks a plugin-shaped path

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2770](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2770)

---

### DEPLOY: feat/2737-score-achievable-floor · 20261003-113415Z

The efficiency score on the `measure-session-start` page now measures how far the session start is
from the floor you can actually reach, not from an empty start. The floor is what Claude Code ships
itself plus the always-on documents up to their budget, which are always-on on purpose. A start with
nothing above it scores 100. The always-on path growing inside its budget no longer moves the score,
and only a byte over the budget counts against it. Before this, the score was capped near 43 in this
repo even with every action done. It now reads 66 on the same figures
([#2737](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2737)). The first render after the
update shows a jump in the score that comes from the new formula, not from a change in the session.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

measure-session-start: score against an achievable floor

Plugins: dkj-policy

[PR #2766](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2766)

---

### DEPLOY: docs/2767-bwj-label-comments-reversed · 20261003-112354Z

Comments and one `open-pr` skill paragraph no longer say BWJ's issue *type* carries the bug/feature
classification; they say it did then, and point at #2750, which brings the labels back.

**Score:** 1

#### What makes this deploy extra special

Nothing beyond the wording.

**Score:** N/A

#### Pull Request

Label-gate comments stop claiming BWJ classifies by issue type

Plugins: dkj-policy

[PR #2771](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2771)

---

### DEPLOY: feat/2764-enhancement-label-becomes-feature · 20261003-111316Z

The `enhancement` label on the source tracker is now `feature`, and a `feat/` pull request here is
labelled `feature`. Consumers keep whatever label their own branch table names.

**Score:** 1

#### What makes this deploy extra special

Nothing beyond the rename itself.

**Score:** N/A

#### Pull Request

The enhancement label is renamed to feature

Plugins: dkj-policy

[PR #2768](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2768)

---

### DEPLOY: feat/2756-bug-and-feature-inbound · 20261003-110038Z

An inbound report is now filed as `bug-inbound` when something the plugins ship is wrong, or as
`feature-inbound` when something is missing, each with its own issue template. Every specialist's
shared instructions say which to pick. The single `inbound` label is gone from the source tracker, so a
session on an older release that files with `--label inbound` gets an error from `gh` until it
updates.

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the label split itself.

**Score:** N/A

#### Pull Request

The inbound label splits into bug-inbound and feature-inbound

Plugins: dkj-policy, dkj-policy-dkjs, dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2763](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2763)

---

### DEPLOY: fix/2748-low-prio-labels-orange · 20261003-104752Z

The two low priority labels are now oranges: `prio-1` `FFA726`, leaning to yellow, and `prio-2`
`F57C00`, leaning to red. Yellow is free for another label family. `adopt-triage-labels` prints the new
colours for a tracker that does not have the labels yet. It matches existing labels by name, so a
tracker that already has them keeps its colours until someone runs `gh label edit`.

**Score:** 1

#### What makes this deploy extra special

Nothing beyond the colour change itself.

**Score:** N/A

#### Pull Request

prio-1 and prio-2 move into the orange family, freeing yellow

Plugins: dkj-policy, dkj-policy-bwj

[PR #2753](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2753)

---

### DEPLOY: feat/2759-sweep-decisions-skill · 20261003-103847Z

New skill `/sweep-decisions`: it goes through every open issue parked on `awaiting-decision` (or its
former name `needs-decision`) with you in one sitting. Each one is checked first (already answered,
overtaken by a merged PR, or not yet a choice), then put to you as a short menu, four at a time, with
"Not now" and "Drop it" beside the issue's own options. Your answer goes on the issue as a comment and
the label comes off, so the next `/sweep-issues` finds it free with the decision in its thread.

**Score:** 3

#### What makes this deploy extra special

It is the other half of `sweep-issues`: between the two, nothing on the tracker waits without a route
that reaches it.

**Score:** 2

#### Pull Request

sweep-decisions: put every issue parked on awaiting-decision to the owner in one pass

Plugins: dkj-policy

[PR #2761](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2761)

---

### DEPLOY: fix/2751-integrity-shared-parse-cache · 20261003-102824Z

`check-plugin-integrity.ps1` now parses each `.ps1` once and walks it once per run, and every check that
reads a script shares that pass. Before this, a run paid four parses and three full walks per file:
check 5 parsed again for the errors, `exec-policy/script` for the tokens plus a second CommandAst walk,
and `shopify-force` for the assignments. Over this repo's 451 scripts that work came to 13.8-17.1s,
and it now takes 4.4-5.4s. A new assert keeps the gate down to a single parse site, because the sharing
#1358 introduced eroded with nothing to hold it
([#2751](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2751)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

check-plugin-integrity: one parse per .ps1, shared across the checks

[PR #2762](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2762)

---

### DEPLOY: feat/2757-awaiting-pull-label · 20261003-101718Z

New parking label `awaiting-pull`, purple like the rest of the awaiting-* family, for an issue that
cannot start until another issue has landed through its pull request
([#2757](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2757)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. It comes off when the blocking PR
merges.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-pull`.

**Score:** 2

#### Pull Request

Add the awaiting-pull parking label to the purple family

Plugins: dkj-policy

[PR #2760](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2760)

---

### DEPLOY: fix/2749-park-refuses-merged-branch · 20261003-100139Z

`park-branch` (and `new-branch -Park` on a resumed branch) no longer re-pushes a branch that has
already merged. It used to report "nothing new to commit" and push, which recreated the remote head the
merge had deleted, and then `prune-merged -IncludeRemote` listed it as a merged head to delete again.
Now a branch the trunk already contains is refused with exit 1, nothing is pushed, and the message
points you at `prune-merged`. A branch with nothing on it yet still parks as before, even once the
trunk has moved on.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

park refuses a branch that has already merged, instead of recreating its deleted remote head

Plugins: dkj-policy

[PR #2758](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2758)

---

### DEPLOY: feat/2741-awaiting-decision-label · 20261003-095111Z

The parking label `needs-decision` is now `awaiting-decision`, in the purple (`5319E7`) of the other
awaiting-* labels, because an issue waiting on the owner's choice is waiting like they are
([#2741](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2741)). The old name stays matched
by the claim and sweep skip defaults and by the issue dashboard. On a tracker that still has the old
name, `adopt-triage-labels` prints a `gh label edit` rename rather than a create, so every issue keeps
its label.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one rename for `needs-decision`.
Nothing breaks if they skip it, because the old name still parks the issue.

**Score:** 2

#### Pull Request

Rename needs-decision to awaiting-decision, in the purple family

Plugins: dkj-policy

[PR #2755](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2755)

---

### DEPLOY: fix/2746-allow-rules-anchored-on-plugin-path · 20261003-094037Z

The `settings.suggested.jsonc` that `specialists-init` proposes no longer allows a `new-branch`,
`open-pr` or `ship-pr` script just because its path contains `dkj-policy`. Each rule now requires the
install path's shape (`.claude`, `plugins`, `cache`, the plugin, `scripts`, the script), so a script
placed in your repo's own `dkj-policy/` folder through a pull request prompts like any other. This
narrows the rule rather than pinning a location: a pull request that adds a `.claude/plugins/` tree to
your repo still deserves a careful look (#2752). The
`gh repo edit --delete-branch-on-merge` rule is now exact, so it no longer allows `--visibility` or other
flags. Rules you already pasted are unchanged: re-run `specialists-init` and paste the new allow lines
to pick this up.

**Score:** 3

#### What makes this deploy extra special

The drift suite now reads each generated rule back as a pattern and runs it against real commands, so
it pins what the rule allows rather than how it is spelled.

**Score:** 2

#### Pull Request

specialists-init: anchor the allow rules on the plugin install path, make the gh rule exact

Plugins: dkj-subagents-alpha

[PR #2754](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2754)

---

### DEPLOY: fix/2739-refresh-suite-durations · 20261003-093117Z

The CI shard-packing hint `scripts/tests/suite-durations.json` has been regenerated from three
October 2 PR runs. It now covers all 153 suites, where it had 141, and none is charged the maximum any
more. Nolan's lens now says the "do not re-open" reason expired when CI became work-bound
([#2739](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2739)). Whether this closes the
70-80s shard overshoot is still to be measured over several PR runs.

**Score:** 2

#### What makes this deploy extra special

N/A. CI wall-clock inside this repo only, and nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

Refresh suite-durations.json at 153 suites

[PR #2747](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2747)

---

### DEPLOY: fix/2736-session-start-keyed-on-repo · 20261003-091530Z

`/measure-session-start` now keeps one page per repo: `Sessiestart-context · <repo>`. Running it in a
second repo no longer finds the first repo's page, and no longer computes deltas between two different
trees or republishes over another repo's history. A previous page whose data names another repo, or no
repo at all, is refused as history with an `[ERROR]` that says whose page it is. Pages published before
this change name no repo, so the next run in each repo starts a fresh page and leaves the old one alone.

**Score:** 3

#### What makes this deploy extra special

The repo key travels inside the page's own data, not only in its title. A title can be matched by
mistake, but the data block decides, so the guard holds even when a session picks the wrong artifact.

**Score:** 2

#### Pull Request

measure-session-start: key the published page on the repo, so a second repo never reads or overwrites the first one's history

Plugins: dkj-policy

[PR #2745](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2745)

---

### DEPLOY: fix/2735-session-start-no-out-dir · 20261003-085508Z

`/measure-session-start` no longer fails at step 2 on a Windows machine whose temp path has an 8.3
short name. Step 2 now downloads the previous page to the Artifact tool's own default folder and copies
it into the scratch directory, so the tool never sees an `out_dir` it refuses.

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the repair. Steps 3 and 7 keep `<scratch>` on purpose, because they pass it to
PowerShell rather than to the Artifact tool.

**Score:** N/A

#### Pull Request

measure-session-start step 2: download the previous page without out_dir

Plugins: dkj-policy

[PR #2744](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2744)

---

### DEPLOY: fix/2733-xoxo-connector-ids-flip-back · 20261003-084111Z

The consumer register named five plugin ids the `xoxowildhearts` consumer stopped enabling on
September 13, so every session start in this repo printed five `[ERROR]`s claiming plugins that are
enabled were not -- and hid the real ids behind an `[UNLISTED]` line. The ids now match what the
consumer enables, and those false errors are gone.

**Score:** 2

#### What makes this deploy extra special

It is the flip-back the #1906 note predicted, taken on the evidence that note asked for: the consumer
itself migrated, measured on its `main`, so the register follows it rather than churning.

**Score:** 1

#### Pull Request

connectors/xoxowildhearts.json: plugin ids back to @dkj-claude-plugins (#1906 flip-back)

[PR #2743](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2743)

---

