# Changelog

## [Unreleased]

**5 / 9 minor entries** <!-- pending-tally -->

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

