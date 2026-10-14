# Changelog

## [Unreleased]

**11 / 22 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2995-dashboard-unknown-tags · 20261014-094755Z

The connector dashboard no longer shows a repo as `In sync` while `check-connectors.ps1` reports a
marker for it. The parser kept only the `[ERROR]`, `[INFO]`, `[OK]` and `[SKIP]` tags, so
`[INVENTORY]`, `[UNLISTED]`, `[UNREGISTERED]` and `[NOT-INSTALLED-HERE]` were dropped. It now keeps
every bracketed tag and reads a tag other than those three as a note. The repo then shows as
`Has notes` and the marker appears in its card
([#2995](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2995)). No marker fires today,
so this prevents a failure that has not happened yet: a repo reading as in sync while its register
entry is behind.

**Score:** 1

#### What makes this deploy extra special

N/A: the dashboard is a local maintenance view of this repo, and no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard keeps every signal tag the check prints

[PR #3000](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3000)

---

### DEPLOY: fix/2991-fake-gh-smart-app-control · 20261014-080824Z

`guard-stale-paste-block.tests.ps1` no longer fails at random on a Windows machine running Smart App
Control. The suite compiles a fake `gh.exe`, and Smart App Control refused about one build in four, so the
hook's fail-open path turned every case red with "could not resolve which repo". The suite now starts
the fake once and rebuilds it when it is refused
([#2991](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2991)).

**Score:** 2

#### What makes this deploy extra special

N/A. The suite is not shipped, and no consumer's behaviour changes.

**Score:** N/A

#### Pull Request

Recompile the fake gh.exe when Smart App Control blocks it

[PR #2994](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2994)

---

### DEPLOY: fix/2989-vendored-house-style-check · 20261014-075848Z

The connector dashboard's test suite now checks that its vendored copy of the house style hashes to
the checksums the `house-style` skill pins. The skill's repoint procedure now names that copy. The
next repoint to a new `house-style-v<N>` tag therefore turns the suite red until the dashboard's two
files move as well. Before, they stayed on the old tag without anyone noticing (#2989).

**Score:** 1

#### What makes this deploy extra special

N/A: the check and the vendored copy exist only in this repo. The sentence added to the skill page
addresses whoever performs a repoint here, and a consumer's use of the skill is unchanged.

**Score:** N/A

#### Pull Request

Hold the dashboard's vendored house style to the skill's checksums

Plugins: dkj-solutions

[PR #2993](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2993)

---

### DEPLOY: fix/dashboard-theme-accents · 20261014-071949Z

The connector dashboard now carries the chosen theme across the whole page. Before, the theme showed
only on its two buttons. The theme colour now also appears in a band along the top, a rule under the
header, a top border on every card, the tile figures, the links and the overview table head. All of it
is done in the page's own layer, on the house `--primary` tokens.

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local maintenance view of this repo, and no consumer receives it.

**Score:** N/A

#### Pull Request

Dashboard carries the chosen theme beyond its buttons

[PR #2992](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2992)

---

### DEPLOY: fix/dashboard-house-style-v2 · 20261013-214843Z

The connector dashboard now runs on `house-style-v2`: its vendored stylesheet and theme script were
still the v1 copies after #2986 repointed the skill. The theme choice moved from a card at the bottom of
the page to the house settings button, fixed in the top right corner.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dashboard is served only on this repo's own checkout; no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard on house-style-v2, with the settings button

[PR #2990](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2990)

---

### DEPLOY: feat/2986-house-style-v2 · 20261013-212508Z

The `house-style` skill now points at the brand book's `house-style-v2` tag
([#2986](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2986)), with its commit and both
checksums re-measured here.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that takes its next copy of the house style gets the settings button,
`DKJTheme.settings(el)`: a round toggle that opens the theme picker, a reset and a slot for the app's
own controls, instead of a toggle each app builds itself.

**Score:** 2

#### Pull Request

house-style: repoint to house-style-v2, the settings button

Plugins: dkj-solutions

[PR #2988](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2988)

---

### DEPLOY: fix/2978-figma-off-again · 20261013-200257Z

The figma plugin is switched off in this repo again
([#2978](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2978)). Removing its `false` key
on October 2 let the machine's own settings turn it back on, at about 2,150 tokens per session.

**Score:** 1

#### What makes this deploy extra special

N/A: this repo's own harness config, and no consumer takes it.

**Score:** N/A

#### Pull Request

settings: figma is off here again, the false key restored

[PR #2985](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2985)

---

### DEPLOY: fix/2982-lifehub-register-catchup · 20261013-164522Z

The life-hub connector record registers what the consumer actually carries: the five
`dkj-subagents-lifehub` lenses and the `dkj-solutions` plugin
([#2982](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2982)). Both now fall under the
extension and version checks.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: life-hub registers dkj-solutions and the five lifehub lenses

[PR #2984](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2984)

---

### DEPLOY: fix/2980-lifehub-connector-repo · 20261013-163144Z

The connector register names life-hub's renamed repo, `DKJ-Solutions/dkj-lifehub`
([#2980](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2980)). Until now the session
check reported an `[ERROR]` against that checkout's origin and skipped its whole block.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: life-hub names its renamed repo, DKJ-Solutions/dkj-lifehub

[PR #2983](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2983)

---

### DEPLOY: feat/2977-awaiting-review-label · 20261013-161810Z

Two new parking labels say that an issue waits on somebody's look at a result, not on a choice
([#2977](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2977)). `awaiting-review-dev` is
the owner's look, and `awaiting-review-client` is the look of the client or requester outside the dev
team. `sweep-issues`, the claim defaults and the issue dashboard skip both, so they are treated like
the other `awaiting-*` labels. `sweep-issues` now sets `awaiting-review-dev` when it parks a visible
result and removes it again when that result is approved. `sweep-decisions` walks neither label.

**Score:** 2

#### What makes this deploy extra special

A consumer who runs `adopt-triage-labels` is offered two new labels to create. Once a preview is
waiting for someone to look at it, the issue drops out of every sweep until the label comes off.

**Score:** 2

#### Pull Request

Add awaiting-review-dev and awaiting-review-client parking labels

Plugins: dkj-policy

[PR #2981](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2981)

---

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

