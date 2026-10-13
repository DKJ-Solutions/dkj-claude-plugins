# Changelog

## [Unreleased]

**5 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2961-scaffold-feature-label · 20261013-113132Z

The `specialists-init` scaffold's prefix-table example now suggests `Label = 'feature'` for `feat/`, the
name the source tracker uses since #2764, where it still suggested GitHub's old `enhancement`
([#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). Existing branch tables are
untouched: a consumer keeps whatever label its own table names.

**Score:** 2

#### What makes this deploy extra special

A repo that runs `specialists-init` from this release on is offered `feature` for its `feat/` pull
requests, the same label the source tracker uses, instead of a name the source already retired.

**Score:** 1

#### Pull Request

specialists-init scaffold suggests the 'feature' label for feat/

Plugins: dkj-subagents-alpha

[PR #2965](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2965)

---

### DEPLOY: docs/2960-bwj-readme-hooks-row · 20261013-111718Z

The `bwj-development` README's `hooks/` row now says **three** hooks and describes the PostToolUse
`asana-link-pickupcheck.ps1` beside the two it already named
([#2960](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2960)). The failure it prevents: a
reader of the layout table who never learns that a hook comments on every issue pickup.

**Score:** 1

#### What makes this deploy extra special

No behavior changes; a store's maintainer reading the plugin's layout table sees the hook that was
already running in their sessions.

**Score:** 1

#### Pull Request

bwj-development README: the hooks/ row names all three hooks

Plugins: bwj-development

[PR #2964](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2964)

---

### DEPLOY: fix/2959-sessioncheck-resolves-exempt-seam · 20261013-110048Z

The bwj-development session check now reports a store whose `scripts/repo-config.ps1` states no
`Get-ResolvesExemptMatchers`. Without that seam dkj-policy's resolves gate lets a pull request close an
Asana-linked issue, so the merge closes it before its go-live block is on it and the Asana task gets a
bare closed message, as measured in xoxowildhearts (#2959).

**Score:** 2

#### What makes this deploy extra special

A store that never stated `Get-ResolvesExemptMatchers` is told so at session start, so a merge can no
longer close an Asana-linked issue before its go-live block is posted without anyone having been warned
(#2959).

**Score:** 3

#### Pull Request

closed-message-sessioncheck reports a store without Get-ResolvesExemptMatchers

Plugins: bwj-development

[PR #2962](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2962)

---

### DEPLOY: fix/2957-golive-post-accepts-referencing-pr · 20261013-095525Z

`build-golive-block -Post` now accepts an open or merged pull request that **references** the issue, as
well as one that closes it
([#2957](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2957)). `bwj-development`'s own rule
ships an Asana-linked issue with `-NoResolves`, so its PR never closes it. The landing check from #2930
read closing references only, so on exactly the issues the block exists for `-Force` was the only way
through. Measured twice in `BWJ-Development/smartwatchbanden` on October 13, 2026. Only pull requests
in the same repo count.

**Score:** 3

#### What makes this deploy extra special

A store session posting the go-live block after a `-NoResolves` ship no longer gets a refusal telling it
to use `-Force`, and the refusal it can still get names both PR shapes.

**Score:** 3

#### Pull Request

golive-block -Post accepts a pull request that references the issue

Plugins: bwj-development

[PR #2958](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2958)

---

### DEPLOY: feat/2954-pin-house-style-tag · 20261013-091726Z

The `house-style` skill no longer fetches the brand book's stylesheet and theme script from `main`, which
moves and can be pushed past review. It now pins them to the release tag `house-style-v1`, and it carries
each file's sha256, so a session that gets different bytes stops and reports them instead of inlining them.
A change to the house style now reaches the apps only after the brand book tags it and the skill is repointed
in a plugin release. That rule is on the skill page and in the extension's `CLAUDE.md`.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app copies only a house style the owner has released. An unreviewed push to the brand book
can no longer slip into its next copy of an executable theme script.

**Score:** 2

#### Pull Request

house-style skill: pin the brandbook fetch to tag house-style-v1

Plugins: dkj-solutions

[PR #2956](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2956)

---

