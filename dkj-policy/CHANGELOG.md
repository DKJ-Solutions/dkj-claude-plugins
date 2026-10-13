# Changelog

## [Unreleased]

**9 / 12 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2976-connector-dashboard · 20261013-154611Z

This repo now runs the `dkj-solutions` dev-preview hook, and what it starts is a **connector dashboard**
([#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976)): one page on
`http://localhost:4870/` with every repo registered under `connectors/`, its status, its plugins, its
local checkout's branch and state, and every error and note `check-connectors.ps1` reports for it, worst
first. It reads the check's own report rather than a second copy of its rules, binds to `127.0.0.1` only
and refuses a foreign `Host`. The hook itself is still unreleased, so it starts the dashboard from the
first session after the next release; until then it starts by hand
(`scripts/dashboard/serve-connector-dashboard.ps1 -Port 4870`).

**Score:** 3

#### What makes this deploy extra special

Nothing a consumer runs changes: the dashboard and its seam are this repo's own.

**Score:** N/A

#### Pull Request

Connector dashboard served through the dev-preview hook

Plugins: dkj-solutions

[PR #2979](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2979)

---

### DEPLOY: fix/2973-djcylow-connector-owner · 20261013-144755Z

The connector record for `djcylow-react` names its new owner, `DaveKJohn/djcylow-react`, after the repo
left the DKJ-Solutions organisation because DJ Cylow has its own brand
([#2973](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2973)). The `dkj-solutions`
extension needs no exception: its scope line already excludes a repo outside the organisation. Without the new owner, `check-connectors` would refuse
the whole block on a machine holding the checkout, because its `origin` no longer matches the record.

**Score:** 1

#### What makes this deploy extra special

Nothing a consumer runs changes.

**Score:** N/A

#### Pull Request

The djcylow-react connector names its new owner, DaveKJohn

[PR #2975](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2975)

---

### DEPLOY: feat/2971-control-char-gate · 20261013-143401Z

The integrity gate now refuses a C0 control character in a tracked text file, naming the file, the line
and the code point ([#2971](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2971)). A BEL
byte from a PowerShell backtick escape reached a `.md` while #2968 was built, and no check read file
content for control bytes. The tree measured clean, so the check is born with no exemptions. The
system-administration manual lists the backtick-escape trap beside the other PowerShell traps.

**Score:** 2

#### What makes this deploy extra special

A consumer reads the new trap in the system-administration manual; the gate itself runs in this repo
only.

**Score:** 1

#### Pull Request

The integrity gate refuses a C0 control character in tracked text content

Plugins: dkj-subagents-alpha

[PR #2974](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2974)

---

### DEPLOY: feat/2968-stale-paste-block · 20261013-135218Z

A go-live block posted before an issue's last reopen no longer reaches the Asana task as the result of the
next round ([#2968](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2968)). A new
`bwj-development` PreToolUse hook refuses a `ship-pr.ps1` or `open-pr.ps1` run while an issue it closes
carries such a stale block, and names the command that posts the fresh one; it is an accident guard that
fails open, with a warning, when it cannot read the issue. `build-golive-block.ps1 -Post` accepts that
fresh block without `-Force`, and the `asana-closed-message` workflow withholds a stale block and says
the result message for this round follows. Hook, script and workflow judge the block by one predicate.

**Score:** 3

#### What makes this deploy extra special

A requester whose ticket was reopened and reworked is no longer sent the previous round's preview link and
description as the new result: the closed message either carries this round's block or says it follows.
A store repo takes the workflow change by re-adopting the `asana-closed-message` template.

**Score:** 3

#### Pull Request

Refuse a merge, and carry no block, when the go-live block predates the issue's last reopen

Plugins: bwj-development

[PR #2972](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2972)

---

### DEPLOY: docs/2961-feature-label-every-consumer · 20261013-124731Z

`feature` is now the `feat/` label in every DKJ-Solutions repo, where it used to be left to each repo's
own branch table ([#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). The
`dkj-solutions` extension states it in a new tracker-labels chapter and in its `CLAUDE.md`, and Derek's
lens no longer says a consumer keeps whatever its own table names.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo whose `scripts/lib/branch-info.ps1` still maps `feat` to `enhancement` moves over:
rename the tracker label first (`gh label edit enhancement --name feature`, which keeps it on every
issue and PR), then point the table at `feature`. The
[`dkj-solutions` README](../plugins/dkj-policy/dkj-solutions/README.md#the-tracker-labels--feature-and-bug-in-every-repo)
gives both steps. Five repos needed it on October 13, 2026: `dkj-brandbook`, `dkj-etf-tracker`,
`djcylow-react`, `dkj-music-library` and `dkj-recipes`.

**Score:** 4

#### Pull Request

feature is the feat/ label for every DKJ-Solutions consumer

Plugins: dkj-solutions

[PR #2970](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2970)

---

### DEPLOY: feat/2967-dev-preview-hook · 20261013-121650Z

`dkj-solutions` now ships a dev-preview SessionStart hook
([#2967](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2967)). A repo that states
`Get-DevPreview` in its `scripts/repo-config.ps1` (the command with `{port}`, the port or port range,
and optionally the URL path, a prerequisite and a VS Code hand-off) gets its local dev server started,
or reused, at `startup`, `resume` and `clear`. It also gets a clickable localhost link, which reaches
the session too. A server counts as this checkout's only when its command line, or its nearest
ancestors', names this checkout's root, so a foreign app, another clone or a worktree is never taken
for it. A repo that states nothing pays nothing. This replaces the per-repo copies in `dkj-brandbook`,
`dkj-etf-tracker` and `life-hub`, each of which can drop its own script and define the seam instead
([README](../plugins/dkj-policy/dkj-solutions/README.md#the-dev-preview-hook)).

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions repo with a dev server gets its preview link at every session start by stating one
function, instead of copying and maintaining a hook of its own.

**Score:** 3

#### Pull Request

dkj-solutions ships the dev-preview SessionStart hook: a repo states Get-DevPreview and gets its localhost link at session start

Plugins: dkj-solutions

[PR #2969](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2969)

---

### DEPLOY: docs/2963-lens-docs-no-label · 20261013-114546Z

Derek's lens no longer maps `docs/` to the retired `documentation` label: its branch table and two
paragraphs now say a `docs/` branch carries no label, as `branch-info.ps1` has since #2783
([#2963](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2963)).

**Score:** 1

#### What makes this deploy extra special

The lens is this repo's own; no consumer reads it.

**Score:** N/A

#### Pull Request

Derek's lens: a docs/ branch carries no label, as branch-info.ps1 says

[PR #2966](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2966)

---

### DEPLOY: fix/2961-scaffold-feature-label · 20261013-113132Z

The `specialists-init` scaffold's prefix-table example now suggests `Label = 'feature'` for `feat/`, the
name the source tracker uses since #2764, where it still suggested GitHub's old `enhancement`
([#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). Existing branch tables are
untouched by the scaffold; how a DKJ-Solutions repo moves its table to `feature` is the
`dkj-solutions` README's, from the next entry for #2961.

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

