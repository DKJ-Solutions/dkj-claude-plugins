# The teams — who the specialists are

**Every plugin in this directory is a team: a set of specialists a repo can enable.** Its sibling
[`../dkj-policy/`](../dkj-policy/) holds the other kind of plugin, which answers a different question —
not *who* the specialists are, but *how* work moves through the repo. That split is the organising
idea behind both directories, and it is argued in full below under
[Teams and workflows — what's the difference?](#teams-and-workflows--whats-the-difference).

**This page absorbed the marketplace-wide architecture record on September 24, 2026**, when the root
`README.md` was retired (branch `docs/retire-root-readme`). Everything below the directory-local
sections was moved here faithfully rather than rewritten —
dated decisions, measurements and issue numbers are kept as recorded. The other pieces of that root
document went to [`../ADOPTION.md`](../ADOPTION.md) (consumption, the bootstrap path, removal,
invocation, where this runs), [`../dkj-policy/README.md`](../dkj-policy/README.md) (versioning, the
skills-design philosophy), [`../../.claude/specialists/lenses/specialist-06-16-lens.md`](../../.claude/specialists/lenses/specialist-06-16-lens.md)
(one product, one repository) and
[`../../.claude/specialists/lenses/specialist-05-15-lens.md`](../../.claude/specialists/lenses/specialist-05-15-lens.md)
(the repo layout).

## What is in here

| Folder | The specialists it adds |
|---|---|
| [`dkj-subagents-alpha/`](dkj-subagents-alpha/) | The **core team** — the repo-neutral specialists who work the same way in every repo, plus the persona templates of the main loop and the bootstrap skill `specialists-init`. |
| [`dkj-subagents-lifehub/`](dkj-subagents-lifehub/) | An **add-on team** for a personal information hub / brain-based knowledge repo. |
| [`dkj-subagents-shopify/`](dkj-subagents-shopify/) | An **add-on team** for a Shopify store repo: theme code, store management, configuration. |
| [`dkj-subagents-ecomm/`](dkj-subagents-ecomm/) | An **add-on team** for a commercial webshop of any platform: SEO, CRO, performance/SEA. |

**Which repo enables which is stated once, and not here.** The
[plugin table](#teams-and-workflows--whats-the-difference) below carries the "who it's for" column,
how the two add-on axes relate, and how many specialists each team ships. This page names the folders
so the directory is readable on its own; it deliberately stops short of restating that table twice,
because a second copy of it is free to disagree with the first — and the disagreement would be
invisible, since nobody reads both copies in one sitting.

## Teams stack; a repo enables as many as its domain calls for

`dkj-subagents-alpha` is the foundation and belongs in every consuming repo. Each further team **adds
specialists**, so enabling two of them raises no conflict — a Shopify store repo that is also a
commercial webshop legitimately enables `dkj-subagents-shopify` and `dkj-subagents-ecomm` alongside the core. That is
the property that separates this directory from `../dkj-policy/`: a team hands the repo more
colleagues, while a workflow hands it an answer to a question that can only have one.

**That used to read "where **at most one** plugin may be enabled at a time", and it had been false
twice over.** [#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886) retired the check
that counted enabled workflows, and `dkj-policy-bwj` has been a second enabled one since August 31,
2026 — additive rather than competing, which is why it is safe. The distinction the sentence exists to
draw survives: stacking teams is *free*, while a second way of working has to be shown not to answer a
question the first one already answers.

## The name is load-bearing, and so is sitting here

A team's name and its location are checked together, and that pairing has moved twice since it first
became enforceable. **Since August 9, 2026** the pairing has been checked rather than merely
conventional — lint check 23 (`[plugin-kind]`) in
[`check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1) holds every published
plugin to it; on that day the checked name was `dkj-team-<name>` under `plugins/dkj-teams/`. **Since
September 9, 2026** ([#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698)) the
pairing the check holds is `dkj-subagents-<name>` under `plugins/dkj-subagents/`; bare `team-*` and the
retired `dkj-team-*` are still accepted as names, but held to no location at all, because the directory
they once pointed at — `plugins/dkj-teams/` — no longer exists to hold them to.

The half that matters is the naming, and until August 26, 2026 the reason sat one directory over: the
core team's `workflow-sessioncheck` hook counted enabled workflows **by the `workflow-` prefix and
nothing else**, so a plugin whose name did not say which kind it was would be invisible to that count.
[#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886) retired that hook along with
`workflow-default`, and the naming rule kept its teeth on a reason of its own: **the directory half is
derived from the name.** A plugin matching no known shape is held to no location rule at all, so an
unclassifiable name switches the check off for itself rather than merely reading untidily.

**This page used to claim the two sides of that pairing were asymmetrical in different ways, and now
they are asymmetrical in the same way.** It read *"a workflow is named `workflow-<name>` and lives under
`plugins/workflows/`"*; since [#1467](https://github.com/DaveKJohn/claude-code-specialists/issues/1467)
that directory is `plugins/dkj-policy/` and names the **government** rather than the kind, so only
`*-policy` and `*-policy-*` are held to a location there — `workflow-*`, `contributing-*` and `*-codex`
are still accepted as names and held to no directory at all. **The teams' half caught up to that same
shape on September 9, 2026**
([#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698)): only `dkj-subagents-*`
is held to `plugins/dkj-subagents/` now, and bare `team-*` together with the retired `dkj-team-*` are
accepted as names and held to no directory at all — which is exactly why it is worth saying here, on
the page a reader consults precisely because they assume the two halves match.

## What a team folder holds

- **`.claude-plugin/plugin.json`** — the manifest, carrying the `version` that is bumped in lockstep
  with every other plugin in this repo.
- **`subagents/specialist-<group>-<id>-subagent.md`** — the subagent definition per specialist, which Claude Code loads
  into every session of a repo that has the plugin enabled.
- **`manuals/specialist-<group>-<id>-manual.md`** — the portable playbook the subagent def reads in on demand. The
  split between the two, and the repo lens that completes it on the consumer's side, is described under
  [Manuals — the split model](#manuals--the-split-model).
- **`skills/`, `hooks/`, `scripts/`, `personas/`** — optional, and only where a team genuinely needs
  them. In practice `dkj-subagents-alpha` is the one carrying all four, because the adoption path, the roster
  and workflow session checks and the sync scripts belong to the core rather than to any domain team;
  `dkj-subagents-shopify` ships four domain skills, and the other two teams are specialists and manuals only.

## `subagent-shared/` — in this directory, and not a team

The verbatim boundary blocks shared across agent defs live in
[`subagent-shared/`](subagent-shared/), here beside the teams rather than one level up. It is **not** a
plugin and never travels as one: it is the source a generator writes *into* these folders. See
[Shared agent-def blocks](#shared-agent-def-blocks--one-source-for-the-verbatim-boundaries) below.

**Why here and not under `plugins/`, where it sat until August 17, 2026.** Every file that carries a
shared block is a team agent def or a team persona — 30 of them across all four teams, and **zero** in
either workflow plugin. So the folder's reach already ended at this directory, and sitting a level up
described a scope it does not have. Two things follow from the move, one of them a behaviour change:

- **It travels with the teams it feeds.** `publish-to-business.ps1` removes a kind-directory once it
  holds no plugin, so a publish carrying no team no longer carries the source of those teams' blocks
  either. Before, it travelled unconditionally.
- **Nothing had to learn where it went.** Every script that asks which plugins exist reads
  `.claude-plugin/marketplace.json` through `plugin-tree-lib.ps1`, so a directory that is in no
  marketplace is not a plugin wherever it sits — including here, sharing a prefix with the four that
  are. That is also why the `[plugin-kind]` rule below does not read this folder as a team missing its
  `team-` prefix: it is anchored on the published set, not on a sweep of this directory.

## Enabling one in your own repo

Adding this marketplace and enabling the teams you want is the adoption path, described end to end in
[`../ADOPTION.md`](../ADOPTION.md) — the install commands, the adoption steps, and the way back out.

## Teams and workflows — what's the difference?

**A plugin is either a team — who the specialists are — or a workflow — how work moves through the
repo.** That split arrived on August 8, 2026, when the branch/release workflow moved out of the core
into a pack of its own — the packaging consequence of
[the plugin serves the consumer's repo](#the-plugin-serves-the-consumers-repo), below. Read the table
with that split in mind: `dkj-subagents-lifehub`, `dkj-subagents-shopify` and `dkj-subagents-ecomm` are
add-on teams, `dkj-policy` is the one answer offered to the workflow question, and only the core team
is for everyone. **Teams stack** — a consuming repo enables `dkj-subagents-alpha` plus as many add-on
teams as its domain calls for. **Workflows are opt-in** — a repo that enables none keeps the way of
working it already had. There is one general workflow, `dkj-policy`, plus one deliberately narrow,
additive one — see below.

**"At most one workflow" was a checked rule until August 26, 2026, and it is recorded here rather than
quietly dropped** ([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)). A
SessionStart hook in the core team, `workflow-sessioncheck`, counted the enabled plugin ids whose name
started with `workflow-` and printed an `[ERROR]` at two or more, naming each id together with the
settings layer that enabled it — because a conflict introduced from the machine layer looks identical
from inside the repo to one the repo caused. It never blocked and it wrote nothing.

**What removed it was removing the second workflow.** The rule's whole force came from `workflow-default`
existing to collide with: two enabled workflows would hand the specialists two contradicting answers
about how a branch is named, what a change owes before it can open a PR, what a release is. With one
plugin left there is no second answer, and #886 settled the wider question the other way too — this
workflow keeps its changelog and its releases in **its own folder**, so it stands beside a repo's own
contributing rules instead of competing with them. **The cost is stated rather than hidden:** if a second
workflow is ever added here, nothing will notice both being enabled, so that day means answering the
question again rather than finding the check gone.

**That day came on August 31, 2026, and the question was answered rather than skipped:
`dkj-policy-bwj` is a deliberate second workflow.** It is safe alongside `dkj-policy`
because it is **additive and non-overlapping** — it extends only the *ticket-work* step that sits
before a branch (how a discovered issue is filed and mirrored to Asana in BWJ's two Shopify store
repos and, for ticket handling alone, this plugin's own source repo, admitted September 14, 2026,
commit `b9b2a65a`) and, since [#1382](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1382),
what a `sync/` branch owes instead of a changelog entry. It decides nothing about branch naming, what
an ordinary change owes before a PR, or what a release is.
The two do not hand the specialists two contradicting answers to one question; they answer different
questions. The retired guard's reasoning still holds for a *third* workflow that overlaps either of
these — nothing counts them, so adding one means making this call again on the merits.

**The naming rule outlived the count that justified it, on a reason of its own.** Lint check 23
(`[plugin-kind]`) in [`check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1) holds
every published plugin to being a team or a way of working **by name**, and holds two of those name
shapes to a directory as well: `dkj-subagents-*` under `plugins/dkj-subagents/`, and `*-policy` /
`*-policy-*` under `plugins/dkj-policy/`. It used to say the hook counted a workflow by
the `workflow-` prefix and nothing else; now the teeth are internal — **the directory half is derived
from the name**, so a plugin matching none of those shapes has its location held against nothing at all,
and an unclassifiable name switches the check off for itself.

**Since [#1467](https://github.com/DaveKJohn/claude-code-specialists/issues/1467) the remaining
shapes — `workflow-*`, `contributing-*`, `*-codex` — are accepted by name and held to no location, and
that is a real narrowing.** `plugins/workflows/` used to name the *kind*; it is `plugins/dkj-policy/` now
and names the **government**, so there is no directory left to send a stranger's `workflow-*` plugin to.
Ordering one into this government would be worse than saying nothing, and refusing the name outright
would make this family's renames somebody else's problem — so the shapes stay recognised and lose only
their directory half.

**[#1480](https://github.com/DaveKJohn/claude-code-specialists/issues/1480) applied that same reading to
the team side, where it had not reached.** Bare `team-*` joined the name-only group when this family's own
teams took the `dkj-` prefix: a prefixless `team-*` is now precisely what *somebody else's* team is called,
and `dkj-team-*` carried the directory rule in its place. The alternative — keeping `team-*` pointed at
`plugins/dkj-teams/` and adding `dkj-team-*` beside it — cost nothing until the day a stranger publishes
a plugin named `team-something`, which was the one case the rule was there for. **The team side itself
moved on again on September 9, 2026** — `dkj-team-*` → `dkj-subagents-*`, `plugins/dkj-teams/` →
`plugins/dkj-subagents/` — under [#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698);
the directory rule rides along with the name, unaffected, exactly as this paragraph describes.

| Plugin | What it is | Who it's for |
|---|---|---|
| [`dkj-subagents-alpha/`](dkj-subagents-alpha/) | **The core team.** Fifteen repo-neutral specialists who work the same way in *every* repo (research, systems administration, technical writing, copy editing, code review, security review, and testing, among others). Also carries the persona templates of the main loop (Chris/Bianca/Derek/Rendall) and the bootstrap skill `specialists-init`. | **Every** consuming repo — this is the foundation, always enable it. |
| [`dkj-subagents-lifehub/`](dkj-subagents-lifehub/) | **An add-on team.** Five specialists for a personal information hub / brain-based knowledge repo (Astrid, Fiona, Hugo, Ian, Onyx). Deliberately domain-flavored: they know their repo and teammates by name. | Only a life-hub-style repo. |
| [`dkj-subagents-shopify/`](dkj-subagents-shopify/) | **An add-on team.** Three specialists for a Shopify store repo (Liam · Liquid, Sandra · store management, Steven · configuration) plus four domain skills of its own (`adopt-shopify-floor`, `push-preview`, `start-task`, `sync-main`). Also deliberately domain-flavored. | Only a Shopify repo (e.g. smartwatchbanden). |
| [`dkj-subagents-ecomm/`](dkj-subagents-ecomm/) | **An add-on team.** E-commerce specialists for a commercial webshop repo of any platform (Sergio · SEO, Craig · CRO, Sean · performance/SEA). Platform-agnostic, and complementary to a platform team rather than exclusive. | Any commercial webshop repo — including a Shopify repo alongside `dkj-subagents-shopify`. |
| [`dkj-policy/`](../dkj-policy/) | **The workflow — a way of working, not a team.** DaveKJohn's own branch-and-entry model, packaged so a repo can *choose* it: the workflow skills (`new-branch`, `open-pr`, `ship-pr`, `fold-changelog`, `cut-release`, `park`, `fix-mojibake`, `adopt-dkj-policy` and the rest — the plugin's own README carries the full list), their shared scripts, the session hooks that belong to running this across several repos, and one Stop hook that keeps a branch's development document on `origin` (#900). Also ships a **config blueprint** — the source's own answers to the repo-owned seam, with the reasoning behind each — which `adopt-dkj-policy`'s Part 2 places or proposes (see below). Carries **no specialists** — it changes how the existing ones work, not who they are. | Only a repo that deliberately wants *this* way of working on top of its own. |
| [`dkj-policy-bwj/`](../dkj-policy/dkj-policy-bwj/) | **A narrow, additive workflow.** BWJ's codex — the binding rules its two Shopify store repos operate under. Four chapters: **ticket handling** — a discovered issue is filed on GitHub first, mirrored to Asana as a colleague-friendly variant, and closing the GitHub issue only makes a CI workflow (shipped as a template) post that the work is ready to test and move the card to `ReadyToTest` — it never resolves the task itself; and **the sync log** — a `sync/` branch is exempt from the changelog by design and owes `dkj-policy-bwj/SYNC-LOG.md` instead, written by `dkj-subagents-shopify`'s `sync-main.ps1`; and **the preview handover** — where a preview is owed, the handover is a pair per market, the preview beside the live control, whose URL pins the live theme id because `preview_theme_id` sets a cookie and the bare URL then keeps serving the preview, and that pair travels as one link to a published page with a QR code per market, never as a table of URLs a terminal wraps past selecting and a phone cannot scan; and **the theme lifecycle** — added September 13, 2026: the release cut backs the live theme up as a verified baseline and rotates the previous one out, and a live push is followed by a sweep of the spent preview themes this repo created, both keyed on a reserved name prefix so a theme somebody else created is never touched and the live theme is refused by id and by role. Four skills (`report-issue`, `adopt-dkj-policy-bwj`, `publish-page`, `build-backlog-page`), no specialists, no hooks. Extends only the ticket-work step of `dkj-policy`, what a sync branch owes, what a preview handover contains and how it travels, and what the theme estate owes at a push and a cut; contradicts nothing it decides. | BWJ's two store repos for all four chapters, or this plugin's own source repo for ticket handling alone (admitted September 14, 2026, commit `b9b2a65a`); requires `dkj-subagents-alpha` **and** `dkj-policy` — the sync and theme-lifecycle chapters also expect `dkj-subagents-shopify`. |

In short: **`dkj-subagents-alpha` is the foundation; everything else is optional, along two different axes.**
`dkj-subagents-lifehub` and `dkj-subagents-shopify` describe what *kind* of repo it is, so a repo
enables at most one of those; `dkj-subagents-ecomm` is orthogonal — it applies to any commercial
webshop regardless of platform, so a webshop repo can enable it *on top of* a platform team (a
Shopify store repo, for instance, enables both `dkj-subagents-shopify` and `dkj-subagents-ecomm`). The
core is written repo-neutrally (no repo names, paths, or script names — that context comes from the
consumer's repo lens); the add-on teams name their domain explicitly, because only a matching repo
enables them.

**The workflow slot sits on neither team axis, and the plugin in it answers a different question than
"what kind of repo is this".** `dkj-policy` carries an owner's name because it is *his* branch
discipline, not a standard. A repo that adopts the specialists gets colleagues; it does not get somebody
else's branch discipline along with them — and since August 26, 2026 that is true **by there being
nothing in the slot to receive**, rather than by a `workflow-default` plugin standing in the slot to
impose nothing. The measurement that forced the split: of what the core used to ship, **9%** described a
craft and **47%** was workflow machinery — so most of what a consumer received was a way of working they
had never chosen. What that costs a repo which enables **only** the core team, no workflow at all, is
stated plainly in [`../ADOPTION.md`](../ADOPTION.md): no branch scripts, no `branch-info.ps1`
to fill in, and a `repo-config.ps1` holding the roster half alone.

### The e-commerce-related plugins

Two of the plugins serve a **commercial webshop** and are built to work together:

- **`dkj-subagents-shopify`** — the *platform* layer: theme code, store management, configuration for a Shopify store.
- **`dkj-subagents-ecomm`** — the platform-agnostic *disciplines* that any webshop needs: SEO, CRO, and performance/SEA.

They sit on different axes — one is "which platform," the other is "which marketing disciplines" — so they complement rather than replace each other. A **Shopify** store repo typically enables **both**; a **non-Shopify** webshop enables just `dkj-subagents-ecomm`. The other plugins — `dkj-subagents-alpha` (the core team), `dkj-subagents-lifehub` and the workflow plugin `dkj-policy` — fall outside this e-commerce grouping. This is a reading aid, not a packaging change: every plugin is still enabled or disabled on its own.

## The plugin serves the consumer's repo

**A consuming repo is unique and has its own way of working, and the specialists adapt to it. That is
their strength.** The source repo's own way of working — the branch-and-entry model, the tier ladder,
the fold, the cut, the gates — is *its* answer to a problem, not a standard a consumer is expected to
adopt. Nothing travels outward **unasked** that assumes otherwise.

**That last word is a correction, and this section's title is now only half true**
([#1699](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1699), September 9, 2026). The
sentence above was written on August 8, 2026, when the split it describes had just been made and one
claim could still cover everything that shipped. It cannot any more, because the two kinds of plugin
stand in opposite relations to a consumer's own rules:

- **A team adapts to the repo it lands in.** `dkj-subagents-alpha` and the add-on teams describe a *craft*,
  and a craft that overrode its host would be worth less, not more — which is what the test question
  below is for.
- **`dkj-policy` is adopted BY the consumer, and it wins — on the cycle, not on everything.** The
  workflow's own page says so: *"where the two disagree, the workflow's page wins"* (Dave,
  August 14, 2026, in
  [`CONTRIBUTING-portable.md`](../dkj-policy/CONTRIBUTING-portable.md)). The source repo's own
  `.claude/rules/this-repo.md` restates it
  from the other side **with its scope attached**, and the scope is the half worth quoting: *"where the
  two disagree, the plugin's page wins. It does not replace anything below; it adds the workflow's own
  mechanics."* So what yields is the way work moves — the branch, the gates, the fold — and not a
  repo's answers about itself, which the portable page keeps as a **seam** it never fills in.
  That this reaches outward at all, rather than being a local arrangement between two files in one
  repo, is visible in a mechanism the plugin ships:
  [`check-consumer-prose.ps1`](../../scripts/lint/check-consumer-prose.ps1) runs as a **SessionStart
  check in a consumer** and reports that repo's own always-on prose when it declares that *its*
  `CLAUDE.md` wins. It is **advisory** — like every session check here, it reports and refuses
  nothing — so read it as evidence of which way the rule points, not as enforcement.

**Opt-in is what reconciles the two, and it describes the INSTALL rather than the obedience.** Nobody
is handed this way of working: `dkj-policy` is enabled by choice and absent by default, and the
enforcement moved out with it, so a repo that works differently is told nothing at session start. What
installing it means is that the consumer has chosen to be governed by it — and from that moment the
adaptation runs the other way, with the consumer's own page yielding on the cycle. The August 8
sentence is not wrong about what it was about; it is one claim where two are now needed, which is what
happens to a sentence written while there was effectively one plugin family.

**The exception is the author, and it is a real one.** Dave runs these plugins across several of his
own repos and deliberately uses one way of working across them, deviating only where the domain forces
it — a Shopify store repo differs from a knowledge repo in what it does, not in how work moves through
it. So his way of working has to be *available*, as something he can switch on per repo, without being
what a stranger receives by default.

That gives one test question, and it applies to everything added to a plugin from here on:

> **Does this describe a *craft*, or a *way of working*?**
> A craft is portable and adapts to the repo it lands in — it belongs in the shared core.
> A way of working belongs to whoever authored it, and is therefore opt-in.

**Why it had to be written down: the core did not pass its own test.** Measured on August 8, 2026, the
`team-alpha` plugin — `dkj-subagents-alpha` today, by way of
[#1480](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1480), which put the `dkj-` prefix
on the four teams on September 5, 2026, and
[#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698), which renamed them again on
September 9 — shipped 1,973,691 bytes, of which the
personas, agent defs and manuals — the craft
itself — were 175,672, or **9%**. Against that, the shared scripts, the seven workflow skills and the
session hooks together came to 923,277 bytes, or **47%**: machinery that implements one particular way
of working. The persona layer itself was clean, and that is worth stating precisely, because it locates
the leak — no file under `personas/`, `manuals/` or `agents/` names `CHANGELOG.md`, `branch/`,
`open-pr`, `ship-pr` or `cut-release`. How a specialist was *described* had never been the problem. What
shipped alongside them was.

**The sharpest instance, because it is the one that reads as compliance.**
[`scripts/repo-config.ps1`](../../scripts/repo-config.ps1) looks like the seam that makes the workflow
adaptable, and its 19 functions genuinely do let a consumer change the trunk name, the merge method and
the folder grouping. But those are *parameters* of a single changelog model, and the model itself is
fixed in [`entry-scaffold-lib.ps1`](../dkj-policy/scripts/lib/entry-scaffold-lib.ps1). A consumer
could tune our way of working; they could not have their own. And
[`check-script-contract.ps1`](../dkj-policy/scripts/sync/check-script-contract.ps1) *enforces*
that they supply those functions — so a repo that worked differently was not adapted to. It was told at
every session start that it was misconfigured.

**What the packaging now does about it.** Both files named above are in the paths they are because the
47% moved out on the same day: the workflow skills, their scripts, the two session hooks that audit a
repo against this way of working, and the libs only those scripts read now ship as
[`dkj-policy`](#teams-and-workflows--whats-the-difference) — enabled by choice, absent
by default. The enforcement went with them, which is the half that mattered most: a repo that works
differently is no longer told anything at session start, because the checker that had the opinion is
not there. And `specialists-init` stops scaffolding what it cannot justify — a consumer without the
pack receives no `branch-info.ps1` and a `repo-config.ps1` holding only the two functions the core
itself reads.

Decision by Dave, August 8, 2026; packaged the same day.

**And for a repo that does want this workflow, the seam now comes with its answers.** Splitting the
enforcement out fixed the repo that works differently; it left the repo that works the *same* way
re-deriving twenty values by hand, because the checker only ever named the **fallback** a shared script
uses — never what this repo chose, or why. The pack therefore ships a **config blueprint**: each seam
function with the source's own text, comments and reasoning included, and a marker saying whether that
answer is safe to take. The [`adopt-dkj-policy`](../dkj-policy/skills/adopt-dkj-policy/SKILL.md)
skill's Part 2 reads it, **places** what states the shared way of working, and **proposes** — never places — what
states what a repo *is*, in a document a person works through.

The two markers are a second, independent axis from the roster/workflow split, and
`Get-ReleasePluginTier` is why: it sits in the workflow half, so the split says it travels, and `$true`
would tell a storefront repo it publishes plugins. One field could not carry both answers. A `decide`
value is never written as a stub either, which is a mechanism rather than a courtesy — a stub returning
a placeholder overrides a documented fallback that is usually right, so absent beats wrong. Issue
[#456](https://github.com/DaveKJohn/claude-code-specialists/issues/456); decisions by Dave, August 8, 2026.

## The vocabulary — where these plugins sit inside an agent

**Every plugin in this marketplace is *scaffold*.** Not one of them is an agent, and not one of them is
a harness. That is worth stating once in the terms the field uses, because three of those terms already
mean something narrower in this tree — and because a naming proposal built on the overlap reached
[#1697](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1697) before anything had been
measured against it.

The anatomy, as [Hugging Face's agent glossary](https://huggingface.co/blog/agent-glossary) defines it —
*"An agent is a model plus everything around it that lets it act, not just respond"* —
which the post itself compresses to **Agent = Model + Harness**:

| The term, as the source defines it | What it is here |
|---|---|
| **harness** — *"the execution layer inside the agent: it calls the model, handles its tool calls, decides when to stop"* | **Claude Code itself** — plus the **hooks** a plugin ships, which run in that execution layer rather than in the model's context |
| **model** | whichever Claude model the session runs on |
| **scaffold** — *"the behavior-defining layer around the model: system prompt, tool descriptions, how the model's responses get parsed, what it remembers across steps"* | **every plugin here** — the personas, the manuals, the agent defs, the skills |
| **agent** | the **running session**: harness + model + this scaffold. Never a directory and never a file |
| **subagent** — *"an agent called by another agent to handle a specific subtask"* | what a session spawns from a `subagents/*.md` definition |
| **policy** — *"the behavior an agent follows: given any situation, it defines the probability of taking each possible action"* | what `dkj-policy` encodes, in prose instead of weights: work is finished → open a PR; a merge landed → fold the entry; a finding appears → file an issue |

**The scaffold here has two halves, and they are the same two this page names in its own words.**
`dkj-subagents-*` encodes **who acts** — the personas, their craft rules, their tool access.
`dkj-policy` encodes **what follows** — given a situation in a repo, which action comes next. "Team" and
"workflow" are this repo's names for those halves, and they are deliberately not agent-anatomy terms:
they answer *what does this give me*, which is the question somebody choosing a plugin actually has. The
bridge is the point of the table above — **the workflow plugin is the policy half of the scaffold** — and
neither vocabulary has to give way to the other.

**Three of these words carry a second, narrower meaning in this tree. Read them in context:**

- **`scaffold`** is also the empty **`VUL-IN` scaffold** a repo lens starts life as (`bootstrap.ps1`),
  and the **scaffold gate** that refuses a changelog entry still carrying `new-branch.ps1`'s own wording
  (`entry-scaffold-lib.ps1`). Both are older than this section and both stay.
- **`agent`** carries the informal sense — the whole running assistant — alongside Claude Code's
  structural sense, where it names a **subagent definition** under `agents/` and the main thread is
  called *the main conversation* instead. This repo means the structural sense wherever it writes *agent
  def*, and calls the running thing *the session*.
- **`policy`** is an ML term of art in the source above and an ordinary English word in `dkj-policy`'s
  name. Both readings land in the same place here, which is unusual and is the reason that name survived
  review: a document saying *in situation X, do Y* is a policy in either sense.

**`specialist`** is this repo's own word and has no equivalent in either vocabulary: a subagent
definition carrying a persona, a craft and a repo lens. The core team is nineteen of them — fifteen that
ship as subagents in `subagents/`, and four main-loop personas in `personas/`.

### Three plugin-id renames declined, one carried out (Dave, September 9, 2026)

[#1697](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1697) proposed carrying the
anatomy into the plugin ids: `dkj-policy` → `dkj-agent`, `dkj-policy-bwj` → `dkj-scaffold-bwj`, a new
`dkj-scaffold-core`, and `dkj-teams`/`dkj-team-*` → `dkj-subagents`/`dkj-subagents-*`. Three of those
were declined and the reasoning is recorded here, because it is the kind of proposal that arrives again:

- **`dkj-agent` is the one name the source rules out.** *"A policy is not an agent. The policy defines
  behavior; the agent is the full system that acts."* And `plugins/dkj-policy/**` ships no `agents/`
  directory at all, so the name would promise subagents the plugin does not carry — the exact failure it
  was meant to cure.
- **`scaffold` cannot distinguish one plugin from another**, because on the definition above every
  plugin here is scaffold. A prefix every member carries is a constant, and a constant belongs in the
  namespace — which `dkj-` and `@dkj-claude-plugins` already are. It would also collide with the two
  established senses listed above, in a tree that has spent real effort keeping them sharp.
- **`dkj-scaffold-core` cannot reach its own content.** `${CLAUDE_PLUGIN_ROOT}` resolves per installed
  plugin and does not cross plugin boundaries. `dkj-policy-bwj` already demonstrates the consequence:
  nested inside `plugins/dkj-policy/` on disk, it still has to cite `CONTRIBUTING-portable.md` by
  absolute URL. Moving that page into a plugin of its own would break every same-directory link in the
  workflow's pages plus the skills and hooks that resolve through that variable.
- **A plugin rename is not a `claude plugin update`.** It is uninstall, install under the new id, and a
  `settings.json` edit — in every consumer, by hand, plus each consumer's own `SPECIALISTS.md`, whose
  `@`-import carries the full marketplace path. Three prior rename rounds are recorded in `connectors/`,
  and each left `check-connectors.ps1` unable to resolve the retired id, skipping that plugin's whole
  drift check until somebody edited the register.

**The fourth — the team side to `dkj-subagents-*` — survived on the merits and paid that cost the same
day, under [#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698).** Every
consumer running `dkj-team-alpha` or one of its siblings owes exactly the migration the reasoning above
warned of: uninstall, install under the new id, the `settings.json` edit, plus its own `SPECIALISTS.md`
`@`-import and its `connectors/` register entry. That walkthrough lived in a root `INSTALL.md`, retired
on September 24, 2026; the release notes of that version carry it.

What the three declined renames earned instead is this section and each plugin's `displayName` — the
label a person reads when choosing what to install. Both were free there: none of those three ids
changed, so `dkj-policy`, `dkj-policy-bwj` and a would-be `dkj-scaffold-core` left no consumer anything
to migrate. The fourth id did change, and the paragraph above is its migration cost, not a footnote to
this one.

## Manuals — the split model

Every specialist in these plugins is built from up to three files, physically split by audience and
by what's portable versus repo-specific: the **manual** (the portable playbook, split from the repo
lens), the **agent def** (the executable abbreviation), and — for the main-loop specialists only —
a **persona template**.

### The manual: portable craft + repo lens

A specialist handbook splits into a **portable** part (repo-neutral, identical in every repo: the
craft, the hard rules, the tone) and a **repo lens** (the `## Specific to this repo` part: which
content/context of that repo the specialist serves). The portable part lives in
`plugins/<plugin>/manuals/specialist-<group>-<id>-manual.md` in this marketplace; the consuming repo keeps only
the lens in `.claude/specialists/lenses/<group>-<id>-extension.md`. The agent def points to both.

**All four teams have now been migrated** — every handbook lives here in the `manuals/` folder of
its plugin, and every consuming repo keeps only its repo lens in `.claude/specialists/lenses/`:

- **`dkj-subagents-alpha` (the core team)** → `dkj-subagents-alpha/manuals/` (Paula, Rebecca, Vera, Gwen, Cody, Tycho,
  Sylvester, Tessa, Edith, Victor, Sebastian, Ravi, Nolan, Marlowe, Auden).
- **`dkj-subagents-lifehub` (an add-on team)** → `dkj-subagents-lifehub/manuals/` (Astrid, Fiona, Hugo, Ian, Onyx).
- **`dkj-subagents-shopify` (an add-on team)** → `dkj-subagents-shopify/manuals/` (Liam, Sandra, Steven).
- **`dkj-subagents-ecomm` (an add-on team)** → `dkj-subagents-ecomm/manuals/` (Sergio, Craig, Sean).

### Subagent def vs. manual — two files, one specialist

Every specialist in these plugins consists of two files, each with its own job:

- **`subagents/specialist-<group>-<id>-subagent.md` — the subagent definition**, the executable form. The frontmatter
  (`name`, `description`, `tools`, `model`) is what Claude Code reads to register the subagent;
  the `description` is also the routing signal the main loop uses to pick a subagent. The body is
  deliberately just a compact operational core (working method, boundaries, deliverable format) and
  refers to the playbook for the actual craft.
- **`manuals/specialist-<group>-<id>-manual.md` — the playbook**, the full description of the craft: the
  hard rules, the trade-offs behind them, and the personality & tone. It is read on demand — by the
  subagent itself when in doubt, and by the main loop (the orchestrator that assigns the work and
  the personas that are not subagents).

**The noun is `subagent def`, and the retired `agent def` still appears throughout these documents.**
Both name the same file. The old spelling is corrected as files are edited for other reasons rather
than swept — the same answer this repo gives for the citations left by every other rename
([#2137](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2137), September 19, 2026), and
for the same reason: both read correctly, so nothing is broken, while a sweep would buy consistency
at the price of a diff nobody can review. What does **not** change is anything a machine *resolves*:
the `"agents"` key in every `plugin.json` is Claude Code's own schema, and
[`scripts/agents/build-agent-defs.ps1`](../../scripts/agents/build-agent-defs.ps1) is a path the tooling
reads. A citation may lag; a lookup may not.

**The manual is leading; the subagent def is the executable abbreviation.** You change a craft rule in
the manual; you only touch the subagent def when the operational core or the tool set changes. The two
are kept deliberately separate: they serve different readers (the harness vs. humans and the main
loop), the router-critical `description` and tool set should not sway along with every textual
refinement, and the portable-vs-repo-lens model above relies on manuals as standalone, lintable
documents. Moreover, the manual format is the common denominator across the whole team: the
persona-only specialists (Chris, Derek, Rendall) have no agent def, but do have a full playbook as a
template in `personas/` (see below).

**A persona may also back a manual of its own, and then the pair works differently from an agent def
and its manual** ([#1017](https://github.com/DaveKJohn/claude-code-specialists/issues/1017),
August 28, 2026). An agent def is an *abbreviation* of its manual — the same craft, less of it — which
is what lets one be leading. A persona and its manual are two halves of one body split by **when they
are needed**: the persona holds what applies before the assignment is known, the manual what applies
once a particular situation has arrived. Neither outranks the other, and the test for where a rule
goes is timing rather than importance — a rule that governs every turn stays in the persona however
long it is, a rule that governs one kind of situation moves however short it is.

**This matters for exactly one specialist, and only because of how he loads.** A persona is read on
demand like anything else, except the orchestrator's, which an `@` import pulls into **every** turn —
so he was the one specialist for whom "no manual" meant "every rule on the always-on path". The lint
gate said so literally: check 6b required an agent def behind every manual, and he has none by design.
It now accepts a persona as a backer, and requires that persona to **name** the manual, for the same
reason 6a makes an agent def name its own — the persona is the only half that gets loaded, so an
unnamed manual is a file nothing would ever read. A persona with no manual stays the ordinary case.

**The exception — a rule that keeps the subagent from walking into a wall belongs in both.** The
division above assumes the subagent consults its manual at the moment it matters. For a rule about
*what the craft is*, that holds: it notices the gap and looks it up. It does not hold for a rule
about *what it will otherwise attempt and fail at* — there it does not know anything is missing, so
it never becomes "in doubt", never opens the manual, and hits the wall instead. Such a rule goes in
the agent def in compact form **as well as** in the manual in full: the manual keeps the reasoning
and the trade-offs, the agent def guarantees it is actually read. Keep the two in step when either
changes.

Sylvester #15 is the worked example (July 27, 2026). His working method opened with *"read before
writing, always merge — never overwrite"*, which silently assumes he can write to a permissions file
at all. He cannot: the auto-mode classifier blocks every write to `settings.json` /
`settings.local.json`, by design. He ran into that block in two consecutive pieces of work and had
to improvise a recovery mid-task both times — while the correction, had it been written down, would
have sat unread in his manual. Fixing only the manual would have produced a third collision.

### Persona templates — a third artifact alongside subagent def and manual

The orchestrator and the main-loop specialists (Chris #01, Bianca #02, Derek #05, Rendall #06) run in
the **main loop**, not as subagents. A plugin *can* inject always-on main-loop context — a root
`settings.json` with an `agent` key activates one of its own agents as the main thread — but that route
is **verified and deliberately not switched on**, because it changes every consumer's main loop from a
version bump they did not read, and a second `agent`-setting plugin silently wins on load order
([issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215); the same correction has
been in [`specialists-init`'s page](dkj-subagents-alpha/skills/specialists-init/SKILL.md) since
that decision, and this sentence was the copy it never reached). An intake conversation moreover
requires direct back-and-forth with the client. They therefore
deliberately have **no** agent def; their portable source lives in
`dkj-subagents-alpha/personas/specialist-<group>-<id>-persona.md` as a **self-contained template** (portable body
+ a repo-lens placeholder). The consumer loads the **portable body straight from the plugin install**
via an `@` import in its `CLAUDE.md` (the orchestrator always, the other personas on demand). The
local extension `.claude/specialists/lenses/<group>-<id>-extension.md` is
therefore **lens-only**: only the repo-specific `## Specific to this repo` part, no copy of the body. The
drift lint (see the [connectors README](../../connectors/README.md#maintenance-drift-lint)) recognizes
such a lens-only extension and reports it as `LENS-ONLY`. The lint's agent-def↔manual coupling
deliberately leaves personas alone (they have no agent def).

## Shared agent-def blocks — one source for the verbatim boundaries

A number of bullets in the **Boundaries** section are word-for-word identical across
many agent defs — the **inbound rule** and the **automation-first rule** even across all 26 (every
agent def in every plugin). Such governance belongs *in* the
agent-def body (always loaded, also for a directly invoked worker subagent), but Claude Code has no
native transclusion in an agent def — what's written there is there, literally. To still maintain
those blocks in **one place** instead of in every agent def, a **build-and-lint** model applies:

- The canonical text of each shared block lives in `subagent-shared/<name>.md` (a sibling of
  the four team folders — every file carrying a block is a team's).
- In an agent def the block appears between sentinels:
  `<!-- BEGIN shared:<name> … -->` … `<!-- END shared:<name> -->`. The content really is there (self-contained), but is marked as generated.
- **Never edit between the sentinels.** Change the source file and run
  [`scripts/agents/build-agent-defs.ps1`](../../scripts/agents/build-agent-defs.ps1) — all agent defs
  carrying the block are updated. The lint gate
  ([`check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1), check 7) fails as
  soon as a marked region deviates from its source (a hand edit or a forgotten rebuild), just like
  the drift lint for consumers.
- **The personas carry blocks too, and the generator writes both.** A persona is prose rather than a
  bullet list under **Boundaries**, so its block sits under its own `##` heading instead of dangling as
  a stray bullet — the sentinels and the rule about not editing between them are identical. This is the
  one part of the model that took a widening (August 8, 2026): the two specialists whose craft *is* a
  way of working, the DevOps engineer and the release manager, ship as personas, so a shared block about
  process could never have reached its primary readers while the generator walked `agents/` alone. Note
  what did **not** widen with it — the lint's agent-def↔manual coupling still leaves personas alone,
  because that check is about a pairing personas genuinely do not have.

Current blocks — one canonical source file each under `subagent-shared/`, so the directory
listing is always the up-to-date enumeration: `inbound-behaviour`, `laziness-automation`,
`language-behavior`, `no-conversation-history`, `no-commit-push-pr`, `repo-way-of-working`,
`lens-optional`, `browser-compatibility`, `webcontent-boundary`, `filecontent-boundary`,
`changelog-entry-boundary`, `design-owner-boundary`,
`storefront-preview-boundary`, and `artifact-publishing-boundary` — fourteen. Nothing checks that count
against the directory, which is how this sentence came to name twelve of them; the directory is the
authority and this list is a convenience. This way changing a shared boundary
costs one edit + one build, not a
manual change in every agent def that carries it.

## Marking a complete skill enumeration

The skill set is spread across several plugin folders, which makes "list/count all skills" a
recurring way for prose to drift out of sync. The same sentinel idea as the shared agent-def blocks
above applies here, one level lighter: an author who writes a prose enumeration that is meant to be
**the complete skill set** wraps it in a BEGIN/END HTML-comment marker:

```
<!-- skills:all -->
- `skill-name`
...
<!-- /skills:all -->
```

and the lint gate ([`check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1),
check 10) then verifies the span's backtick-quoted names against the real skill set on every run.
Three rules govern when and how to reach for it:

- **Wrap tightly.** The extraction is character-based (so the sentinels may sit inline, mid-sentence,
  not just around a standalone bullet list as shown above), but *every* backtick-quoted term inside
  the span counts as a claimed skill name — so the span must close around just the skill names,
  nothing else in backticks.
- **Only for a genuinely complete enumeration.** A deliberately partial or illustrative list (e.g.
  a slash-only subset in a walkthrough) gets no marker — marking it would turn an intentional subset
  into a permanent false positive.
- **Showing the syntax literally needs a fence, not inline code.** The check masks fenced code
  blocks before it looks for markers, precisely so a paragraph like this one can show the literal
  syntax without being misread as a real span (as happened once during development). A single pair of
  backticks does *not* get that treatment — a claimed skill name inside a real span is itself
  backtick-delimited, so there is no way to tell "this is an example" apart from "this is a claimed
  name" in inline code. A fence is the only safe way to display the marker literally.

This is opt-in, not a generic prose scan: a doc with zero spans passes silently. See the check's
docstring in `check-plugin-integrity.ps1` for the full mechanics.

### The plugin-scoped sibling, for a table that enumerates ONE plugin

The two rules above are also the two reasons that marker cannot serve a document listing the skills of
a single plugin: its canonical set is the whole marketplace, and *wrap tightly* is unmeetable in a
two-column table whose second column is prose. Since August 26, 2026 there is a second, separately
opt-in marker for that case ([#920](https://github.com/DaveKJohn/claude-code-specialists/issues/920)),
checked by **check 29** (`[skill-list-plugin]`):

```
<!-- skills:plugin -->
| [`skill-name`](skills/skill-name/SKILL.md) | anything at all in this column |
<!-- /skills:plugin -->
```

It differs from its sibling in exactly two respects, and in nothing else — same fence masking, same
hard errors on an unpaired or nested marker, same silent pass on zero spans:

- **The plugin is the document's own.** It is resolved from the file's path, not named in the marker,
  so the marker cannot claim a plugin the document does not live in. A span in a file that belongs to
  no published plugin is a hard error rather than a silent skip, and the finding points at
  `skills:all` as the marker that would have served.
- **A claim is a link target, never a backtick.** Only a link resolving to
  `<this plugin>/skills/<one>/SKILL.md` counts; prose, backticked paths, flags and links elsewhere are
  ignored. So there is no *wrap tightly* rule here — the table needs no rewriting to be markable.

Reach for it when a document enumerates one plugin's skills, and for `skills:all` when it enumerates
the marketplace's. Neither is generic: measured over all four plugins, a rule that simply required
every plugin README to list its skills would be born with 8 findings on two documents that never
claimed to enumerate anything.

### The third sibling, for a table that enumerates a folder's SHARED SCRIPTS

Both markers above answer *which skills does this list*. Since September 6, 2026 a third answers
*which shared scripts does this list*
([#1491](https://github.com/DaveKJohn/claude-code-specialists/issues/1491)), checked by **check 32**
(`[shared-script-list]`):

```
<!-- shared-scripts:mirror -->
| Script | What it is | Skill |
|---|---|---|
| `task/new-branch.ps1` | anything at all in these two columns | anything at all |
<!-- /shared-scripts:mirror -->
```

Its canonical set is `Get-SharedScriptPairs` — the registry in `scripts/lib/shared-scripts-lib.ps1`
that decides which scripts are mirrored into which plugin — narrowed to the mirrors landing **at or
below the marked document's own folder**, and relativized against it. So the same marker means one
folder's worth of scripts in `plugins/<p>/scripts/README.md` and the whole plugin's in
`plugins/<p>/README.md`, where the rows would then carry the deeper `scripts/…` paths. A span in a
file under no published plugin is a hard error, exactly as for `skills:plugin`.

**A claim is the row's first cell** — the first backticked token in it — and neither sibling's rule
would serve here: the table's second column is running prose carrying backticked flags and function
names, and its third links a `SKILL.md` rather than the script. A header row, a separator and prose
between rows carry no backticked first cell and are passed over without a rule of their own.

**This is not check 8.** That one holds each mirror's *content* against its source, so it proves the
file on disk is the right file. Nothing before this asked whether the page that tells a consumer
*which files exist* still names them all — which is how `plugins/dkj-policy/scripts/README.md` went
stale against its own registry three times (three rows in August 2026, then the header and the
destination split, then 21 rows in
[#1486](https://github.com/DaveKJohn/claude-code-specialists/issues/1486)) while every gate stayed
green. Each repair was a hand pass, which resets the clock rather than stopping it.

Opt-in for the same measured reason as the other two: a README beside a scripts folder may
deliberately list a *subset* of the same registry — the **root** `scripts/README.md` did, only what a
person invokes by hand, until it was removed on September 23, 2026 — so a blanket rule keyed on
filename would be born needing an allow-list. The sentinel is what lets a 1:1 table be gated without
first deciding that for every other one.

## Adding a new team

An add-on team is its own plugin folder — but adding one touches more than that folder, because the
docs enumerate the plugins and go stale silently if you forget them. The full checklist (learned from
adding `dkj-subagents-ecomm`) is written for a **team**; a **workflow** carries no specialists, so it would
differ at step 4:

**One step left this list on August 9, 2026, and it is worth saying which.** It used to open with the
plugin folder and then ask you to add that folder's `agents/` directory to a hand-written list in the
drift lint — a step that existed only because a script kept its own copy of "which plugins are there".
Both of that check's lists are now derived from the marketplace entry in step 3, so registering the
plugin *is* covering the drift check. The two lists had already fallen out of step with each other by
one plugin when this was measured, which is the argument: a checklist item is a reminder, and a
reminder is what a derivation makes unnecessary.

1. **The plugin folder** `plugins/<plugin>/` with `.claude-plugin/plugin.json` (the lockstep
   `version`, matching the other plugins). That is the whole of it since August 8, 2026 — a new plugin
   used to owe a `CHANGELOG.md` intro and a `RELEASE.md` card as well, and both were retired with the
   documents themselves.
2. **The name, and where it sits.** `dkj-subagents-<name>` under `plugins/dkj-subagents/`, `<name>-policy-<ministry>`
   under `plugins/dkj-policy/` — for a **team**, always the first; a **workflow** is the rare exception, see
   the diverging note at step 4 below. Since August 9, 2026 this is not a style preference, and since
   [#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886) the reason is a different
   one: the prefix used to decide whether the core team's `workflow-sessioncheck` hook counted the
   plugin at all, and that hook is retired. What remains is stronger for being local — **the directory
   rule is derived from the prefix**, so a name matching neither is held to no location rule at all.
   Lint check 23 (`[plugin-kind]`) in
   [`check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1) holds both halves of that
   pairing, so getting this step wrong is caught before the PR merges rather than by a reader noticing
   the plugin sits somewhere its name does not claim.
3. **The marketplace entry** — register the plugin in
   [`.claude-plugin/marketplace.json`](../../.claude-plugin/marketplace.json) with a repo-relative
   `source`.
4. **The specialists** — `subagents/specialist-<group>-<id>-subagent.md` + `manuals/specialist-<group>-<id>-manual.md` per
   member, following the `<group>-<id>` convention (a globally unique `id`).
5. **The docs that enumerate the plugins** — this page (the plugin count, the
   [teams-and-workflows table](#teams-and-workflows--whats-the-difference), the
   [manuals list](#manuals--the-split-model)) and
   [`../ADOPTION.md`](../ADOPTION.md) (the invocation list, and whether the team is mutually
   exclusive with the others or complementary).
6. **The gates** — `scripts/agents/build-agent-defs.ps1 -Check`,
   [`scripts/lint/check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1), and
   the `scripts/tests/*.tests.ps1` suites, all green — run from the repo root, so the paths above are
   relative to it rather than to this page.

**A new *product*, on the other hand, does not belong here at all** — it gets its own repository and
its own marketplace. See
[One product, one repository](../../.claude/specialists/lenses/specialist-06-16-lens.md#one-product-one-repository)
in Tessa's repo lens.
