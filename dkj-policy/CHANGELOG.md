# Changelog

## [Unreleased]

**5 / 7 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2709-tier-zero-refuses-na · 20261002-092240Z

**A tier 0 answered `N/A` is now refused before the merge.** `open-pr` and the CI `branch-entry` check
refuse it, and so does the release cut. DEVELOPMENT-portable gives tier 0 a score, always, but no gate read
that rule, so PR #2706 shipped one through both. It is now a malformed value, refused like an off-rubric
score. `check-branch-entry` now refuses malformed values the way `open-pr` does, where before it only
reported them. A blank tier-0 score still passes
([#2709](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2709)).

**Score:** 2

#### What makes this deploy extra special

For a maintainer of a repo running this workflow: an entry with tier 0 written as `N/A` is refused at
`open-pr` and by the `branch-entry` CI check, naming the rule, so it gets fixed on the branch rather than
on the trunk. A green `branch-entry` check now also means no malformed score.

**Score:** 2

#### Pull Request

The entry gates refuse N/A on tier 0, which always takes a score

Plugins: dkj-policy

[PR #2711](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2711)

---

### DEPLOY: docs/2699-entry-tier-0-scored · 20261002-091058Z

Inside this repo: one pending changelog entry, PR #2706's, now scores its tier 0 rather than answering
N/A, so the next release counts it as the change it is.

**Score:** 1

#### What makes this deploy extra special

N/A: a pending entry's wording reaches no user of what this repo ships.

**Score:** N/A

#### Pull Request

The #2699 changelog entry scores its tier 0 instead of N/A

[PR #2710](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2710)

---

### DEPLOY: fix/2701-golive-closing-rule-blank-line · 20261002-084959Z

**The go-live block's last paragraph no longer renders as a big bold heading on GitHub.** Both composers
(`build-golive-block` and the `asana-mirror` CI backstop) put the closing `---` directly under the last
line of text, and Markdown reads a line followed by `---` as a heading. Each now leaves a blank line
before that rule, and a test holds both to it
([#2701](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2701)).

**Score:** 2 -- noticed in the rendered comment once pointed out; the text itself was always correct.

#### What makes this deploy extra special

A colleague reading the issue comment on a BWJ store repo now sees the closing sentence as a normal
paragraph rather than a heading. They take this in with the next plugin update, and nothing needs doing.

**Score:** 2

#### Pull Request

golive-block: a blank line before the closing rule, so the last paragraph is not an H2

Plugins: dkj-policy-bwj

[PR #2707](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2707)

---

### DEPLOY: docs/2699-off-board-asana-ticket · 20261002-083549Z

Inside this repo: `report-issue`'s step 2 gains the off-board case, for an Asana-originated ticket that
sits in another project. Its source is this tree's `plugins/dkj-policy/dkj-policy-bwj/skills/report-issue/SKILL.md`.

**Score:** 2

#### What makes this deploy extra special

For a BWJ store maintainer filing an issue from a colleague's Asana ticket that lives in another project
(`SEO`, a workload overview): `report-issue` now says what to do instead of prescribing a card move and
two field writes that Asana refuses. It skips those writes, still links the task and posts the
`created:` comment, and names the one act left to a person, adding the task to the board, after which
the daily sweep stages it like any other card
([#2699](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2699)).

**Score:** 2

#### Pull Request

report-issue: say what to do when an Asana-originated ticket is not on the repo board

Plugins: dkj-policy-bwj

[PR #2706](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2706)

---

### DEPLOY: fix/2702-release-freshness-confirms-current · 20261002-082018Z

`release-freshness-sessioncheck` used to be silent when the running release matched GitHub's newest, so a quiet session start meant either "current" or "could not check". Now a probe that actually read a tag always says something: the existing warning when behind, and one confirmation line when current or ahead. Every failure (no clone, offline, a timeout, no tag at all) is still silent, so it never claims "up to date" without having checked. Resolves #2702.

**Score:** 2

#### What makes this deploy extra special

A new session now shows *dkj plugins are up to date: this session runs v5.12.0*, so whether to run update-plugins is no longer guesswork.

**Score:** 3

#### Pull Request

release-freshness-sessioncheck confirms visibly when the dkj plugins are up to date

Plugins: dkj-policy

[PR #2704](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2704)

---

### DEPLOY: fix/figma-off-here · 20261001-202811Z

figma, enabled machine-wide, is now switched off in this repo's `.claude/settings.json`. Its 14 skill
descriptions (2,150 tokens, measured by `measure-session-start`) leave every session here. The reason is
recorded in Sylvester's lens.

**Score:** 2

#### What makes this deploy extra special

N/A: this changes only this repo's own settings, and no consumer takes them.

**Score:** N/A

#### Pull Request

figma switched off for this repo

[PR #2696](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2696)

---

### DEPLOY: fix/2693-null-plugin-roots-under-pwsh · 20261001-185244Z

Inside this repo: the plugin-tree lib no longer trusts `@($PluginRoots)` to drop a `$null`. That holds
in Windows PowerShell 5.1 and not in pwsh 7, and every CI-floor runner executes under pwsh while the
suites that reached this path ran under 5.1. A new `Get-PluginRootSet` filters it in the three loops,
and `fold-changelog.tests.ps1` now asserts that call itself, so the Linux pwsh job covers it.

**Score:** 2

#### What makes this deploy extra special

For the maintainer of a consuming repo that declares no plugins: `fold-on-merge` no longer fails on a
merge with `You cannot call a method on a null-valued expression` in `Get-PluginNameForPath`, so the
changelog entry folds on the runner instead of waiting for somebody to fold it locally
([#2693](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2693)).

**Score:** 3

#### Pull Request

The fold no longer crashes under pwsh in a repo with no marketplace

Plugins: dkj-policy

[PR #2694](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2694)

---

