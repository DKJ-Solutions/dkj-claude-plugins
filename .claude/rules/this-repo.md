# This repo — dkj-claude-plugins

**The owner is Dave (DaveKJohn); wherever the constitution says "the owner", that is him here.**

**The root [`CLAUDE.md`](../../CLAUDE.md) imports the constitution by relative path**, where a consumer
uses the absolute marketplace path: this repo *is* the source, so it loads the branch's own copy.

**This file holds facts about the repo and nothing else** — the constitution's split
([#2374](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2374)). It loads into every
session, so the mechanics and the history behind each fact live in the lens of the specialist who owns
them, and this file points there
([#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448)).

---

## Specific to this repo (claude-code-specialists)

- **The home repo of one product** — the Claude Specialists system — and the **single source of truth**
  for every shareable subagent definition. One product, one repository, one marketplace, and lockstep
  versioning *within* it is correct: [Tessa's lens](../specialists/lenses/specialist-06-16-lens.md#one-product-one-repository).
- **It consumes itself, with every plugin in the marketplace enabled** in
  [`.claude/settings.json`](../settings.json) (Dave, September 8, 2026) — for validation: the repo that
  ships a plugin is also a repo that loads it. Only the core team and `dkj-policy` have real work here,
  plus `dkj-policy-bwj`'s ticket-handling chapter. The roster is in
  [`SPECIALISTS.md`](../specialists/SPECIALISTS.md); what enabling all six costs, and why the Shopify
  floor check is told there is no store, is in
  [Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#the-six-plugins-enabled-here-and-what-that-costs).
- **A session here runs the installed copy, not this tree** — so a change reaches a session after a
  release, while the CI runners scaffolded into consumers track `main` and reach them at once. **Name
  the two channels together or name neither**:
  [Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#updating-the-plugins--in-every-other-checkout-of-this-repo).

### Language

**Repo content is English** — every layer, the script layer included. **The session-reply language is
separate and follows the user.** The per-layer detail and its deliberate exceptions are in
[`language-layers.md`](language-layers.md), path-scoped so it loads only when you touch one of those
layers; the system-wide norm is in
[the technical writer's portable manual](../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-16-manual.md#what-tessa-covers).

### Repo citation — one owner name

**Cite this repo as `DKJ-Solutions/dkj-claude-plugins`** in every new GitHub URL, `gh --repo` argument
and `owner/name` reference. Neither retired spelling — `DaveKJohn/claude-code-specialists` or
`DKJ-Solutions/claude-code-specialists` — may ever be recreated, because both resolve only through a
redirect. Old citations are corrected when a file is edited for other reasons, not swept; the two
renames, `Get-RetiredRepoNames` and the one-command `origin` fix are in
[Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#repo-citation--the-two-renames-behind-the-one-owner-name).

### Structure — where everything lives

The layout is in [Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#repo-layout); how the tree reached it is in
[Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#how-the-plugin-tree-got-its-current-address).

### claude-code-specialists's safety implementation

**These are facts about how this repo meets the constitution, not rules of their own.** The mechanics
are on [`CONTRIBUTING-portable.md`](../../plugins/dkj-policy/CONTRIBUTING-portable.md). **Where this
section and either plugin page disagree, the plugin page wins**, and the disagreement is a defect in
this section.

- **The trunk is `main`.** All changes go via a `<prefix>/<short-name>` branch and a PR to `main`,
  **one change per branch**, and the branch is deleted after the merge. Valid prefixes
  ([`branch-info.ps1`](../../scripts/lib/branch-info.ps1)): `feat/`, `fix/`, `docs/`. **`chore/` is
  refused** (Dave, August 7, 2026): chore is work that lands directly on the trunk under a named
  exception, so a chore branch is a contradiction.
- **The lint and test gates run before every PR**, locally through `open-pr.ps1` and again as the
  required CI check. What each gate checks, the workflow's branch-document gates, the staleness guard,
  and the post-merge fold runners are in
  [Sylvester's lens](../specialists/lenses/specialist-05-15-lens.md#what-sylvester-owns-here); why the
  checks have the shape they do, and every rule measured and declined, is in
  [the same lens](../specialists/lenses/specialist-05-15-lens.md#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026).
  **Read it before changing a check.**
- **Three bounded exceptions land directly on `main`**, and read end to end they are one procedure:
  1. The **fold commit** after a merge — bounded to `dkj-policy/CHANGELOG.md` and the branch's
     development document (named by its resolver, `Resolve-BranchFilePath`), which the same run removes.
  2. The **release commit**, only on explicit request — the lockstep version bump, the generated
     release notes, the changelog emptied to its intro, and the tag `vX.Y.Z`. A major also takes two
     preparation commits, bounded to the new section in `dkj-policy/releases/history.md` and the assert
     in `release-lib.tests.ps1` that pins the major.
  3. The **release-notes commit** after the tag — bounded to the hand-written documents of a cut that
     was actually asked for.

  **An exception is only safe while it stays the size it was granted at.** How each runs, and the
  measurements behind them, are in
  [the release lens](../specialists/lenses/specialist-05-06-lens.md#versioning--releases).
- **This repo is `public`**, deliberately, so the `github` marketplace source reads without auth. So
  **nothing confidential** goes in it: no personal information, credentials or secrets. A measurement
  taken in a private consumer quotes only the fragment the finding turns on:
  [Tessa's lens](../specialists/lenses/specialist-06-16-lens.md#the-conventions-she-guards).
- **Changes to shared agent defs land here first**, and only then reach the consumers. Because this repo
  *is* the source, **the shared source is the default home for a lesson learned here, not the lens**
  (Dave, August 4, 2026); personas and manuals carry no repo-specific detail at all, while skills carry
  the evidence behind a procedure:
  [Tessa's lens](../specialists/lenses/specialist-06-16-lens.md#where-a-new-rule-goes--the-source-is-the-default-the-lens-is-the-exception).

### The how (the plugin) vs. the what (this repo only)

The **how** (everything via branch + PR, lessons learned in the docs, the constitution above any
convenience) is the imported constitution, which reaches every consumer through the absolute
`@`-import. The **what** (the marketplace structure, the language, the `main` trunk and its exceptions,
the scripts and the lint gate) belongs to this repo alone and sits in this file.
