# Changelog

## [Unreleased]

**9 / 10 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2683-rename-dossier-label-to-record · 20261001-125032Z

Repo-internal half: this tracker's collecting issues carry `record` instead of `dossier`, and every
gate and pickup route reads both names.

**Score:** 2

#### What makes this deploy extra special

A consumer's collecting-issue label is now called `record`. Nothing breaks on update: `open-pr` still
refuses to close an issue carrying `dossier`, and both pickup routes still skip it. Running
`adopt-triage-labels` prints the one `gh label edit` that renames the label in place, issues and all.

**Score:** 3

#### Pull Request

The collecting-issue label is renamed from dossier to record

Plugins: dkj-policy

[PR #2689](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2689)

---

### DEPLOY: fix/2677-ci-skeleton-ignores-plugin-gates · 20261001-124022Z

`adopt-ci-floor` no longer counts the plugin's own pull-request gates (`branch-entry`,
`always-on-budget`) as the repo's CI. Measured in a consumer (#2677): running Part 1 before Part 3,
the documented order, suppressed the `ci.yml` skeleton and left only those two pull-request-only gates
as candidate checks, so no check could be made required. Part 3 now offers the skeleton and pre-fills
the ruleset with `ci` whichever order the parts ran in.

**Score:** 2

#### What makes this deploy extra special

A maintainer adopting dkj-policy in a new repo now gets a CI workflow to require from Part 3 even after
running Part 1 first, instead of a ruleset naming a check that never runs.

**Score:** 3

#### Pull Request

adopt-ci-floor: the plugin's own PR gates no longer suppress the CI skeleton

Plugins: dkj-policy

[PR #2684](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2684)

---

### DEPLOY: docs/awaiting-recurrence-record-prefix · 20261001-121821Z

Repo-internal: how this tracker titles its own parked issues.

**Score:** 1

#### What makes this deploy extra special

A consumer following `CONTRIBUTING-portable.md` now titles an `awaiting-recurrence` issue `[RECORD] ...`
as well as a dossier, so both kinds of long-open parked issue read apart from small findings in any
issue list. A convention, enforced by nothing.

**Score:** 2

#### Pull Request

An awaiting-recurrence issue's title starts with [RECORD] too

Plugins: dkj-policy

[PR #2686](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2686)

---

### DEPLOY: docs/dossier-record-title-prefix · 20261001-103813Z

Repo-internal: the rule is how this tracker titles its own collecting issues.

**Score:** 1

#### What makes this deploy extra special

A consumer following `CONTRIBUTING-portable.md` now titles a dossier `[RECORD] ...`, so a long-running
collecting issue reads apart from a small finding in any issue list, without opening its labels. Nothing
enforces it; it is a convention, like the label itself.

**Score:** 2

#### Pull Request

A dossier's title starts with [RECORD]

Plugins: dkj-policy

[PR #2685](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2685)

---

### DEPLOY: fix/2681-ruleset-bypass-actors · 20261001-102730Z

The paste-ready ruleset that `adopt-ci-floor` prints now carries a repository-admin bypass actor, and
says why: without one, the required check refuses the fold's direct push to the trunk, so every fold
after the next pull request was blocked
([#2681](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2681)).

**Score:** 3

#### What makes this deploy extra special

A consumer who follows Part 3 of `adopt-dkj-policy` to the letter no longer gets a trunk nothing can
fold onto. A ruleset already pasted from the old output still needs the bypass actor added by hand.

**Score:** 4

#### Pull Request

adopt-ci-floor's composed ruleset carries a repository-admin bypass actor, so the fold can land

Plugins: dkj-policy

[PR #2682](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2682)

---

### DEPLOY: fix/2664-measure-skill-dmi-not-always-on · 20261001-101138Z

`measure-skill` no longer counts a skill whose frontmatter sets `disable-model-invocation: true` as
always-on cost. A session never lists such a skill, so its description was in the printed total but in no
context. Such a skill now reads `0 (not listed; priced N)`, and each plugin line gives the printed total
next to what a session actually pays (#2664). For `dkj-policy` at v5.11.0 that is 3,000 of the 5,710 printed.

**Score:** 2

#### What makes this deploy extra special

If you use `measure-skill` to judge what your plugins cost a session, the always-on figures now match what
a session loads. Skills that only run when typed no longer inflate the total.

**Score:** 1

#### Pull Request

measure-skill prices disable-model-invocation skills at 0 always-on, since a session never lists them

Plugins: dkj-policy

[PR #2680](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2680)

---

### DEPLOY: fix/2667-always-on-strip-html-comments · 20261001-100019Z

The always-on measurement now counts what a session actually loads. Block-level HTML comments
(`<!-- ... -->` on lines of their own) are on disk but are stripped by the harness before the document
reaches the session. `measure-always-on`, the always-on budget gate and `always-on-sessioncheck` still
counted them, and overstated this repo's path by about 1 kB. The comment bytes are now left out of every
size the walk reports, and `measure-always-on` lists them per document in a block of their own.

**Score:** 2

#### What makes this deploy extra special

A consumer's always-on figure and budget headroom grow by whatever their always-on documents hold in
HTML comments, so a comment is now a free place for rationale on the always-on path. For a repo with no
such comments nothing changes.

**Score:** 1

#### Pull Request

measure-always-on and the budget gate leave out the HTML comments the harness strips

Plugins: dkj-policy, dkj-policy-bwj

[PR #2679](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2679)

---

### DEPLOY: docs/2671-model-edit-decodes-u-escape · 20261001-095031Z

The system-administration manual's trap section and the language-layers rule now record that the
model's own `Edit` and `Write` decode a typed code-point escape into its character. The result is pure
ASCII, so the script-ASCII gate passes it. Both pages give the remedy: compose the escape, as in
`('\' + 'u003c')`, and read the written line back by code point. It reproduced in Markdown while this
was being written, so it is not specific to `.ps1`.
Resolves [#2671](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2671).

**Score:** 2

#### What makes this deploy extra special

N/A. A documentation note for whoever edits the scripts. It changes nothing a subscriber takes.

**Score:** N/A

#### Pull Request

Record the model-Edit/Write \u-escape decode trap

Plugins: dkj-subagents-alpha

[PR #2676](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2676)

---

### DEPLOY: fix/2670-measure-skill-priced-copy · 20261001-094109Z

`measure-skill` no longer claims its figures are what a session in this checkout loads today when they
aren't. `claude plugin details` does not price the version recorded for this checkout in the plugin install
record (measured: it prices the newest version on the machine). So the report now reads that record and, where the two differ, says the figures are
what a session here pays after its next plugin update (#2670).

**Score:** 1

#### What makes this deploy extra special

If you run `measure-skill` in a checkout that has not yet taken the newest plugin update, it now says that
the costs shown belong to the newer version on your machine, not the version this checkout currently loads.

**Score:** 1

#### Pull Request

measure-skill names the gap between the version it priced and the version this checkout's install record pins

Plugins: dkj-policy

[PR #2675](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2675)

---

### DEPLOY: feat/sessioncheck-remote-staleness · 20261001-092720Z

A new `dkj-policy` SessionStart hook, `release-freshness-sessioncheck`, warns the user visibly when
GitHub carries a newer release of the dkj plugins than the one the session is running. It names both
versions and the `update-plugins` skill. Until now nothing did: `connector-sessioncheck` compares against
the local marketplace clone, which only moves on `claude plugin marketplace update`, and every
session-start hook printed plain text that reaches the model but never the user. The new hook compares
release tags rather than commits, so work merged between releases does not trigger it. It is silent
when the session is current, offline or unable to check. The network probe runs once per session and is
bounded at five seconds.

**Score:** 3

#### What makes this deploy extra special

A consumer who falls behind a release now sees a warning in the terminal at session start, telling them
to run `/dkj-policy:update-plugins`. Before this they had to guess. A current session costs about one
`git ls-remote` per session start and shows nothing.

**Score:** 3

#### Pull Request

release-freshness-sessioncheck: warn the user at session start when a newer dkj release is out

Plugins: dkj-policy

[PR #2674](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2674)

---

