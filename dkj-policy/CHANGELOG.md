# Changelog

## [Unreleased]

**6 / 8 minor entries** <!-- pending-tally -->

### DEPLOY: feat/remove-asana-mirror · 20261005-082732Z

The `asana-mirror` CI workflow is retired from `dkj-policy-bwj` (Dave, October 5, 2026): the two
templates are gone, and `adopt-bwj-development` no longer copies them. The helpers `build-backlog-page`
and `build-golive-block` still use now live in `scripts/lib/asana-task-lib.ps1`. The template's
self-containment suite went with it, and the tests, docs, skills and lenses describe the new state.

**Score:** 3

#### What makes this deploy extra special

Closing a GitHub issue in a BWJ store no longer posts anything on the Asana task, and the card is no longer
moved through the board. The go-live block stays on the GitHub issue, and you paste it into the task by
hand where the task needs it. To finish the job in a store repo, delete `.github/workflows/asana-mirror.yml`
and `.github/scripts/asana-mirror.ps1`, and drop `Get-GithubStatusMap` from `scripts/repo-config.ps1`.
`report-issue` still files the card in `Filed`.

**Score:** 4

#### Pull Request

Retire the asana-mirror CI workflow from dkj-policy-bwj

Plugins: bwj-development, dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2804](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2804)

---

### DEPLOY: docs/2796-parking-labels-at-filing · 20261004-101059Z

An issue whose next step waits on something other than work now carries its `awaiting-*` parking label
from the moment it is filed, for all five labels rather than `awaiting-decision` alone. The rule now
sits beside the `prio-N` and `minor` filing rules in Chris's lens, which every session here loads, so it
is read when an issue is filed. Before, a waiting issue could be filed unparked and look like free work
to both pickup routes.

**Score:** 2

#### What makes this deploy extra special

`CONTRIBUTING-portable.md` now says once that every parking label (`awaiting-decision`, `awaiting-pull`,
`awaiting-event`, `awaiting-first-recurrence`, `awaiting-more-recurrences`) goes on in the same
`gh issue create` as the `prio-N`. Before, it said that only for `awaiting-decision`. A consumer's
waiting issues are parked from the start rather than picked up by a sweep that has nothing to build.

**Score:** 2

#### Pull Request


Every parking label goes on at filing, not only awaiting-decision

Plugins: dkj-policy

[PR #2797](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2797)

---

### DEPLOY: feat/2793-drop-live-lint-smokes · 20261004-094241Z

The test suites no longer run the whole lint gate over the live repo just to check that it passes. `bootstrap-drift` drops that run entirely, which is ~70% of the heaviest suite. `fix-mojibake` now runs only the encoding tool behind check 14, and checks the gate's own parse of its file count against what the tool prints. `subagent-shared` keeps its run for the two coverage lines it reads, and no longer asserts the exit code. The CI lint job and `open-pr`'s local gate already run that command in every PR. Locally, `bootstrap-drift` went from 76.8 s to 23 s and `fix-mojibake` lost a 45.8 s gate run. The CI before/after with `measure-suites` comes from the runs after the merge.

**Score:** 2

#### What makes this deploy extra special

Nothing a consumer runs changes: these are this repo's own suites and gate notes.

**Score:** N/A

#### Pull Request

bootstrap-drift and fix-mojibake no longer rerun the full lint over the live repo

Plugins: dkj-policy

[PR #2794](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2794)

---

### DEPLOY: docs/2791-english-tracker-always-on · 20261004-083650Z

The rule that issue titles and bodies, PR bodies and commit messages are English, whatever language a
session replies in, now sits in the shared filing rules every persona and subagent carries, rather
than only in the technical writer's on-demand manual. The manual keeps the reasoning and points there.

**Score:** 2

#### What makes this deploy extra special

A consumer's tracker stops filling with issues, PR bodies and commits in the session-reply language,
because the session that files them now carries the rule on every turn.

**Score:** 3

#### Pull Request

Put the English-tracker rule on the always-on filing path

Plugins: dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2792](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2792)

---

### DEPLOY: feat/2788-rename-policy-extensions · 20261004-080146Z

The two `dkj-policy` extensions were renamed after their organisation:
`dkj-policy-bwj` is `bwj-development` and `dkj-policy-dkjs` is `dkj-solutions`
([#2788](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2788)). An extension is now
recognised by a list in `claude-md-import-lib.ps1` rather than by its name prefix. A retired name is
mapped to its current one, so the adopters still owe and write the current import line, and the
integrity gate fails until the list matches the plugin folders.

**Score:** 3

#### What makes this deploy extra special

A migration is required for a repo that enables either extension. The marketplace no longer declares
the old ids, so after this release nothing of the extension loads until `.claude/settings.json` enables
the new name and it is installed. The old `CLAUDE.md` import points at a folder that is gone, and nothing
fails loudly. The session-start check warns once for each old name, `adopt-workflow-folder.ps1 -Apply`
rewrites the old import line in place, and [ADOPTION.md](../plugins/ADOPTION.md#consumption) gives the
three steps.

**Score:** 5

#### Pull Request

Rename the dkj-policy extensions to bwj-development and dkj-solutions

Plugins: bwj-development, dkj-policy, dkj-solutions, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2790](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2790)

---

### DEPLOY: fix/2786-docs-prefix-no-documentation-label · 20261004-074745Z

A `docs/` pull request in this repo now goes out without a label, because the `documentation` label is
retired here too: an issue is always a `feature` or a `bug`
([#2786](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2786), following
[#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 1

#### What makes this deploy extra special

For a new consumer running `specialists-init`: the commented example prefix table no longer proposes a
`documentation` label for `docs/` or `chore/` branches, so it no longer suggests the label #2783
retired.

**Score:** 1

#### Pull Request

This repo's docs/ prefix stops labelling PRs 'documentation'

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2789](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2789)

---

### DEPLOY: feat/2784-awaiting-event-label · 20261003-143652Z

New parking label `awaiting-event`, purple like the rest of the awaiting-* family, for an issue that
waits on an external event or date, such as a launch or a third party's release
([#2784](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2784)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue states the event or date, and
the label comes off once it has happened.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-event`. A sweep no longer has to hold a date-bound issue out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A fifth parking label: awaiting-event

Plugins: dkj-policy

[PR #2787](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2787)

---

### DEPLOY: docs/2783-bwj-no-documentation-label · 20261003-141409Z

In a BWJ store repo every issue is now filed as either a `feature` (something new being added) or a
`bug` (something that exists and has to change), doc findings included. There is no third kind any
more, and the `documentation` label is no longer set or created. The adoption skill (step 4) shows how
to give the open issues still carrying `documentation` their kind and take it off, and a `docs/` pull
request goes out without a label
([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

BWJ: every issue is a bug or a feature, and the documentation label goes

Plugins: bwj-development

[PR #2785](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2785)

---

