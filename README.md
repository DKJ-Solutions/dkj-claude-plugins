# claude-code-specialists

**The Claude Specialists system**, designed by Dave (DaveKJohn). Instead of one generic Claude, you
work with a **team of specialized Claudes** under one Chief of Staff: every assignment is classified
and delivered to the specialist (subagent) with the right playbook — a DevOps engineer for branches
and PRs, a technical writer for docs, a copy editor for the final pass, and so on.

This repository is that product's **source and its marketplace**: the **plugins** that together make
up the system — a stack of **teams** (who the specialists are) plus an opt-in **workflow** (how work
moves through the repo) — plus the machinery that builds, lints and releases them. It is the **single
source of truth** for every shareable subagent definition — a consuming repo points here instead of
keeping its own copies, and enables or disables **per plugin** which teams and workflow it needs.

## Start here

| I want to… | Go to |
|---|---|
| **connect my own repo — just the commands** | **[INSTALL.md, the quickstart half](INSTALL.md#quickstart--the-commands-and-nothing-else)** — five steps, the commands and nothing else, linking down for every caveat. |
| **connect my own repo — and know why** | **[INSTALL.md, the adoption half](INSTALL.md#adoption--how-to-connect-your-repo)** — the full, measurement-backed adoption manual for someone who did not build this, ~47 min (August 6, 2026). Read its *Before you start* section first if the machine is new or has adopted this family before. |
| **disconnect it again** | [UNINSTALL.md](UNINSTALL.md) — the install page's mirror: the repo teardown and the machine-side removal, in the order they have to happen. |
| **I already adopted this, under the old plugin names** | [INSTALL.md, migrating from the old plugin names](INSTALL.md#migrating-from-the-old-plugin-names) — a third procedure, neither the quickstart nor first-time adoption: the old ids (`specialists@claude-code-specialists` and its siblings) mapped onto the new teams and workflow. |
| know **what this promises my repo** | [The plugin serves the consumer's repo](#the-plugin-serves-the-consumers-repo) — the specialist teams adapt to your way of working, and nothing arrives unasked; `dkj-policy` is the exception, and installing it is choosing to be governed by it. |
| know **what the words mean** (agent, subagent, scaffold, harness) | [The vocabulary](#the-vocabulary--where-these-plugins-sit-inside-an-agent) — where these plugins sit inside an agent, and why none of them is named after an agent. |
| know **which plugin does what** | [Teams and workflows](#teams-and-workflows--whats-the-difference) |
| know **how a specialist is built** | [Manuals — the split model](#manuals--the-split-model) |
| know **how a repo consumes this** | [Consumption](#consumption) · [Versioning](#versioning) |
| know **where this runs** (Chat / Cowork / Claude Code) | [Where this runs](#where-this-runs-chat-cowork-and-claude-code) |
| **contribute a change** | [`dkj-policy/CONTRIBUTING.md`](dkj-policy/CONTRIBUTING.md) — one page: the standard branch + PR workflow, which holds with no plugin installed, and the entry, the fold and the cut layered on top of it |
| see **the version history** | [`releases/history.md`](dkj-policy/releases/history.md) |

Everything below this table is the underlying explanation, and the page is long on purpose: it is the
architecture record as much as the landing page. **[INSTALL.md](INSTALL.md) holds both
entrances — its [quickstart half](INSTALL.md#quickstart--the-commands-and-nothing-else) is the
short one, its [adoption half](INSTALL.md#adoption--how-to-connect-your-repo) the full one** —
this file is what you read when the install page's answer was not enough, or when you are changing the
system rather than adopting it.

## One product, one repository

**Every product gets its own repository, and therefore its own marketplace.** This repository holds
**one** product — the Claude Specialists — and that is a rule rather than a coincidence.

It used to be framed the other way around: a *workshop* meant to become the home for every future
plugin, with the specialists as its first family among more to come. That design does not survive a
second, unrelated product, because the release train is repo-wide: one `CHANGELOG.md`, one `vX.Y.Z`
tag, and a version bump in lockstep across every plugin. Land an unrelated product beside this one and
it gets bumped for work it never had, one tag covers two products, and one changelog mixes two
histories. So the next product gets its own repository and its own marketplace, and the directory
layer that used to stand by to hold a second family here has been removed.

**What was retired is the framing, not the word — decided August 15, 2026, and written down here
because it keeps being reported as drift.** The *name* went: "the workshop repo" was used in 32 places
as a live name for this repository, next to the correct term in the same paragraph in several of them,
which reads to a newcomer as two repositories one of which they cannot find. Those all say "the source
repo" now. But **"the workshop" as a role word survives, in 310 places**, and deliberately: it describes
what this side of the marketplace *does* — it is where the plugins are built — and nothing about the
one-product rule makes that untrue. Sweeping it would be a prose-sensitive rewrite across 61 files of
shipped plugin content, buying consistency at the price of worse sentences, and the measurement behind
that call is in
[#720](https://github.com/DaveKJohn/claude-code-specialists/issues/720). The three references to the
literal old repository name `davekjohns-workshop` are the historical record of the rename and are
correct as past tense.

**The nuance, so nobody repairs the wrong thing later: lockstep *within* this product is correct.**
The plugins are one system — a stack of teams plus an opt-in workflow — and a consumer running
`dkj-subagents-alpha` alongside `dkj-subagents-shopify` needs matching versions. What was wrong was never the lockstep;
it was housing unrelated products in a single release train. The lockstep in
[`cut-release.ps1`](scripts/release/cut-release.ps1) therefore needs no change, and the versioning
problem dissolved with the reorganisation instead of needing a fix. (That script *was* changed later
the same day, for an unrelated reason — it became a shared plugin script under
[#417](https://github.com/DaveKJohn/claude-code-specialists/issues/417), with what differs per repo
moved into the seam. The lockstep behaviour is untouched: the release artefacts it produces here are
byte-identical to what the unshared script produced.)

Decision by Dave, August 3, 2026.

## The plugin serves the consumer's repo

**A consuming repo is unique and has its own way of working, and the specialists adapt to it. That is
their strength.** This repository's way of working — the branch-and-entry model, the tier ladder, the
fold, the cut, the gates — is *this* repo's answer to a problem, not a standard a consumer is expected
to adopt. Nothing travels outward **unasked** that assumes otherwise.

**That last word is a correction, and this section's title is now only half true** ([#1699](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1699),
September 9, 2026). The sentence above was written on August 8, 2026, when the split it describes had
just been made and one claim could still cover everything that shipped. It cannot any more, because the
two kinds of plugin stand in opposite relations to a consumer's own rules:

- **A team adapts to the repo it lands in.** `dkj-subagents-alpha` and the add-on teams describe a *craft*,
  and a craft that overrode its host would be worth less, not more — which is what the test question
  below is for.
- **`dkj-policy` is adopted BY the consumer, and it wins — on the cycle, not on everything.** The
  workflow's own page says so: *"it sits on top of the repo's `CLAUDE.md` and wins over it on
  conflict"* (Dave, August 14, 2026, in
  [`dkj-policy/CONTRIBUTING.md`](dkj-policy/CONTRIBUTING.md)). [`CLAUDE.md`](CLAUDE.md) restates it
  from the other side **with its scope attached**, and the scope is the half worth quoting: *"where the
  two disagree, the plugin's page wins. It does not replace anything below; it adds the workflow's own
  mechanics."* So what yields is the way work moves — the branch, the gates, the fold — and not a
  repo's answers about itself, which the portable page keeps as a **seam** it never fills in.
  That this reaches outward at all, rather than being a local arrangement between two files in this
  repo, is visible in a mechanism the plugin ships:
  [`check-consumer-prose.ps1`](scripts/lint/check-consumer-prose.ps1) runs as a **SessionStart check in
  a consumer** and reports that repo's own always-on prose when it declares that *its* `CLAUDE.md`
  wins. It is **advisory** — like every session check here, it reports and refuses nothing — so read it
  as evidence of which way the rule points, not as enforcement.

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
[`scripts/repo-config.ps1`](scripts/repo-config.ps1) looks like the seam that makes the workflow
adaptable, and its 19 functions genuinely do let a consumer change the trunk name, the merge method and
the folder grouping. But those are *parameters* of a single changelog model, and the model itself is
fixed in [`entry-scaffold-lib.ps1`](plugins/dkj-policy/scripts/lib/entry-scaffold-lib.ps1). A consumer
could tune our way of working; they could not have their own. And
[`check-script-contract.ps1`](plugins/dkj-policy/scripts/sync/check-script-contract.ps1) *enforces*
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
answer is safe to take. The [`adopt-dkj-policy`](plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md)
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

**The scaffold here has two halves, and they are the same two the next section names in this repo's own
words.** `dkj-subagents-*` encodes **who acts** — the personas, their craft rules, their tool access.
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
`@`-import and its `connectors/` register entry. The full walkthrough is in INSTALL.md's own
[Migrating off the `dkj-team-*` ids](INSTALL.md#migrating-off-the-dkj-team--ids-1698-september-9-2026)
section.

What the three declined renames earned instead is this section and each plugin's `displayName` — the
label a person reads when choosing what to install. Both were free there: none of those three ids
changed, so `dkj-policy`, `dkj-policy-bwj` and a would-be `dkj-scaffold-core` left no consumer anything
to migrate. The fourth id did change, and the paragraph above is its migration cost, not a footnote to
this one.

## Teams and workflows — what's the difference?

**A plugin is either a team — who the specialists are — or a workflow — how work moves through the
repo.** That split arrived on August 8, 2026, when the branch/release workflow moved out of the core
into a pack of its own — the packaging consequence of
[the plugin serves the consumer's repo](#the-plugin-serves-the-consumers-repo). Read the table with
that split in mind: `dkj-subagents-lifehub`, `dkj-subagents-shopify` and `dkj-subagents-ecomm` are add-on teams,
`dkj-policy` is the one answer offered to the workflow question, and only the core team is
for everyone. **Teams stack** — a consuming repo enables `dkj-subagents-alpha` plus as many add-on teams as its
domain calls for. **Workflows are opt-in** — a repo that enables none keeps the way of working it
already had. There is one general workflow, `dkj-policy`, plus one deliberately narrow,
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
repos) and, since [#1382](https://github.com/DaveKJohn/claude-code-specialists/issues/1382), what a
`sync/` branch owes instead of a changelog entry. It decides nothing about branch naming, what an
ordinary change owes before a PR, or what a release is.
The two do not hand the specialists two contradicting answers to one question; they answer different
questions. The retired guard's reasoning still holds for a *third* workflow that overlaps either of
these — nothing counts them, so adding one means making this call again on the merits.

**The naming rule outlived the count that justified it, on a reason of its own.** Lint check 23
(`[plugin-kind]`) in [`check-plugin-integrity.ps1`](scripts/lint/check-plugin-integrity.ps1) holds every
published plugin to being a team or a way of working **by name**, and holds two of those name shapes to a
directory as well: `dkj-subagents-*` under `plugins/dkj-subagents/`, and `*-policy` / `*-policy-*` under
`plugins/dkj-policy/`. It used to say the hook counted a workflow by
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
| [`dkj-subagents-alpha/`](plugins/dkj-subagents/dkj-subagents-alpha/) | **The core team.** Fifteen repo-neutral specialists who work the same way in *every* repo (research, systems administration, technical writing, copy editing, code review, security review, and testing, among others). Also carries the persona templates of the main loop (Chris/Bianca/Derek/Rendall) and the bootstrap skill `specialists-init`. | **Every** consuming repo — this is the foundation, always enable it. |
| [`dkj-subagents-lifehub/`](plugins/dkj-subagents/dkj-subagents-lifehub/) | **An add-on team.** Five specialists for a personal information hub / brain-based knowledge repo (Astrid, Fiona, Hugo, Ian, Onyx). Deliberately domain-flavored: they know their repo and teammates by name. | Only a life-hub-style repo. |
| [`dkj-subagents-shopify/`](plugins/dkj-subagents/dkj-subagents-shopify/) | **An add-on team.** Three specialists for a Shopify store repo (Liam · Liquid, Sandra · store management, Steven · configuration) plus four domain skills of its own (`adopt-shopify-floor`, `push-preview`, `start-task`, `sync-main`). Also deliberately domain-flavored. | Only a Shopify repo (e.g. smartwatchbanden). |
| [`dkj-subagents-ecomm/`](plugins/dkj-subagents/dkj-subagents-ecomm/) | **An add-on team.** E-commerce specialists for a commercial webshop repo of any platform (Sergio · SEO, Craig · CRO, Sean · performance/SEA). Platform-agnostic, and complementary to a platform team rather than exclusive. | Any commercial webshop repo — including a Shopify repo alongside `dkj-subagents-shopify`. |
| [`dkj-policy/`](plugins/dkj-policy/) | **The workflow — a way of working, not a team.** DaveKJohn's own branch-and-entry model, packaged so a repo can *choose* it: the workflow skills (`new-branch`, `open-pr`, `ship-pr`, `fold-changelog`, `cut-release`, `park`, `fix-mojibake`, `adopt-dkj-policy` and the rest — the plugin's own README carries the full list), their shared scripts, the session hooks that belong to running this across several repos, and one Stop hook that keeps a branch's development document on `origin` (#900). Also ships a **config blueprint** — the source's own answers to the repo-owned seam, with the reasoning behind each — which `adopt-dkj-policy`'s Part 2 places or proposes (see below). Carries **no specialists** — it changes how the existing ones work, not who they are. | Only a repo that deliberately wants *this* way of working on top of its own. |
| [`dkj-policy-bwj/`](plugins/dkj-policy/dkj-policy-bwj/) | **A narrow, additive workflow.** BWJ's codex — the binding rules its two Shopify store repos operate under. Three chapters: **ticket handling** — a discovered issue is filed on GitHub first, mirrored to Asana as a colleague-friendly variant, and closing the GitHub issue only makes a CI workflow (shipped as a template) post that the work is ready to test and move the card to `ReadyToTest` — it never resolves the task itself; and **the sync log** — a `sync/` branch is exempt from the changelog by design and owes `dkj-policy-bwj/SYNC-LOG.md` instead, written by `dkj-subagents-shopify`'s `sync-main.ps1`; and **the preview handover** — where a preview is owed, the handover is a pair per market, the preview beside the live control, whose URL pins the live theme id because `preview_theme_id` sets a cookie and the bare URL then keeps serving the preview; and that pair travels as one link to a published page with a QR code per market, never as a table of URLs a terminal wraps past selecting and a phone cannot scan. Two skills (`report-issue`, `adopt-dkj-policy-bwj`), no specialists, no hooks. Extends only the ticket-work step of `dkj-policy`, what a sync branch owes, and what a preview handover contains and how it travels; contradicts nothing it decides. | Only BWJ's two store repos; requires `dkj-subagents-alpha` **and** `dkj-policy` — the sync chapter also expects `dkj-subagents-shopify`. |

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
stated plainly under [Adoption](#adoption-the-bootstrap-path): no branch scripts, no `branch-info.ps1`
to fill in, and a `repo-config.ps1` holding the roster half alone.

### The e-commerce-related plugins

Two of the plugins serve a **commercial webshop** and are built to work together:

- **`dkj-subagents-shopify`** — the *platform* layer: theme code, store management, configuration for a Shopify store.
- **`dkj-subagents-ecomm`** — the platform-agnostic *disciplines* that any webshop needs: SEO, CRO, and performance/SEA.

They sit on different axes — one is "which platform," the other is "which marketing disciplines" — so they complement rather than replace each other. A **Shopify** store repo typically enables **both**; a **non-Shopify** webshop enables just `dkj-subagents-ecomm`. The other plugins — `dkj-subagents-alpha` (the core team), `dkj-subagents-lifehub` and the workflow plugin `dkj-policy` — fall outside this e-commerce grouping. This is a reading aid, not a packaging change: every plugin is still enabled or disabled on its own.

## What lives here and what doesn't

**Does live here:** the plugin folders under [`plugins/`](plugins/) with **subagent definitions**
(`agents/`) and the **portable playbook** per specialist (`manuals/<group>-<id>-manual.md`) that the
agent def reads in via `${CLAUDE_PLUGIN_ROOT}/manuals/`. The core team (`dkj-subagents-alpha`) additionally
carries two things that cover the **main-loop layer** (see
[Adoption: the bootstrap path](#adoption-the-bootstrap-path)): the **persona templates**
(`personas/<group>-<id>-persona.md`) of the orchestrator + main-loop specialists (Chris, Bianca, Derek,
Rendall), and the **repo-neutral bootstrap skill** `specialists-init`.

**Doesn't:** governance (`CLAUDE.md`, the workflow rules), safety hooks, or MCP config. Those stay
at repo level deliberately, because they differ per repo (or are safety-critical). The plugins
deliberately carry **no safety/guardrail hooks** and **no repo-specific skills** — with a few named,
repo-neutral exceptions: the skill `specialists-init` (the adoption path itself), and a set of
informational SessionStart hooks that never block, read-only with one stated exception —
`claude-home-sessioncheck`, which keeps a snapshot of your `~/.claude` plugin administration while it
reads healthy so a clobber of it is restorable (#1609), and touches nothing in any repo —
`roster-sessioncheck` (roster-drift
signaling) in the **core team**, and in **`dkj-policy`** the rest, among them
`connector-sessioncheck` (sync signaling), `script-contract-sessioncheck` (signals when a repo's own
workflow libs no longer expose a function the shared scripts call) and `consumer-prose-sessioncheck`
(signals when a repo's own always-on prose contradicts the plugin — a convention the plugin has renamed
still stated as current, [#1389](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1389),
or that repo's own `CLAUDE.md` declared above the workflow's contributing layer,
[#1415](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1415) — two detectors over one
corpus read once, merged into a single hook by
[#1421](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1421)); see the
[connectors README](connectors/README.md). **The set is not enumerated in prose anywhere** — it was, as
three, and went stale twice inside two days as hooks were added; each plugin's `hooks/hooks.json` is the
one place that cannot.

**And since August 26, 2026 one hook that acts rather than reports**, which is a real widening of that list
and named as such: `cycle-autopark` (a **Stop** hook, in `dkj-policy`) commits and pushes the
branch's `<branch>.md` to `origin` after every turn, until a PR publishes it
([#900](https://github.com/DaveKJohn/claude-code-specialists/issues/900)). It writes to git, so it is not
read-only — but it is still not a *guardrail*: it blocks nothing, refuses nothing, and exits 0 on every
outcome. What earns it a place beside the read-only set above is that it is repo-neutral and touches exactly one
document, whose path the shared resolver decides; the four bounds that keep it that narrow are in the
`park` skill.

**Those last two moved out of the core on August 8, 2026, and the reason is the doctrine rather than
tidiness.** `connector-sessioncheck` reads a register of *Dave's own* repos, and
`script-contract-sessioncheck` demands that a repo supply functions for scripts that now ship in the
opt-in workflow. Both ran in every consuming session, so a repo that had only enabled the specialists
was being audited against somebody else's way of working at every session start.

**The "no repo-specific skills" rule has one more named exception, and it sits with the add-on teams:
a team may ship domain skills of its own, shared by every repo that enables it.**
`dkj-subagents-shopify` is the only one that does, so a reader hunting a domain skill has one plugin
to open rather than a guess among three. This sentence named the lifehub and Shopify teams until
September 9, 2026 — a two-of-three list written before the e-commerce team existed, pointing at the
one of the two that has never shipped a skill
([#1749](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1749)).

### Repo layout

The full picture, top-level folder by folder:

- **`.claude-plugin/marketplace.json`** — the marketplace definition: the plugins (teams and workflow alike) with their `source`.
- **[`plugins/`](plugins/)** — the plugin source, split by kind (its own
  [README](plugins/README.md) states that split side by side, with the test question that decides
  which kind a new plugin is): the teams under
  [`plugins/dkj-subagents/`](plugins/dkj-subagents/) (`dkj-subagents-alpha`, `dkj-subagents-lifehub`, `dkj-subagents-shopify`, `dkj-subagents-ecomm`) and
  the policy at [`plugins/dkj-policy/`](plugins/dkj-policy/) — the prime ministry's own files at that
  root, and its one ministry `dkj-policy-bwj` a level inside it — each of those two directories carrying
  its own README for what belongs in it
  and the rules that govern it. One folder per plugin, each carrying
  `agents/`/`manuals/`/`personas/`/`skills/` plus its own `plugin.json` — and beside the four teams
  **[`plugins/dkj-subagents/subagent-shared/`](plugins/dkj-subagents/subagent-shared/)**, the canonical source of the shared
  agent-def blocks described under
  [Shared agent-def blocks](#shared-agent-def-blocks--one-source-for-the-verbatim-boundaries). See
  [Manuals — the split model](#manuals--the-split-model) for the manual/agent-def/persona split.
  `subagent-shared/` belongs under `plugins/` rather than at the root because it is plugin *source*: its
  generator writes those blocks into plugin agent defs. It sits under `dkj-subagents/` rather than one level
  up because **every** file carrying a shared block is a team's — 30 agent defs and personas across the
  four teams, none in either workflow — so a level up described a reach it does not have. It is a
  directory inside a kind directory that is not a plugin, and nothing has to be told so: a script asks
  the marketplace which plugins exist, and this folder is in no marketplace.
- **[`connectors/`](connectors/)** — the register of which repos have each plugin installed and whether
  they are in sync (see its own [README](connectors/README.md)). At the root, deliberately **not** under
  `plugins/`: it is maintenance data read by `scripts/sync/check-connectors.ps1`, not payload, and it
  must not travel along with the plugin cache.
- **`scripts/lib/`, `scripts/lint/`, `scripts/release/`, `scripts/sync/`, `scripts/agents/`,
  `scripts/task/`, `scripts/tests/`** — the shared helpers (`branch-info.ps1`, `release-lib.ps1`,
  `subagent-shared-lib.ps1`, and `plugin-tree-lib.ps1`, which answers which plugins this repo publishes
  and where each folder sits, so no other script has to encode the layout), the lint gate + drift
  check, the changelog/PR/release scripts (incl.
  `cut-release.ps1`), the connectors check (`check-connectors.ps1`), the agent-def generator
  (`build-agent-defs.ps1` — fills in the shared blocks from `plugins/dkj-subagents/subagent-shared/`), and the tests.
  [`scripts/README.md`](scripts/README.md) is the directory-by-directory map, with the entry points and
  the gates on the branch dossier. A
  mirrored copy for consumers lives inside the plugins — the sync/check scripts in `dkj-subagents-alpha`, the
  branch/release workflow in `dkj-policy` — see its own
  [README](plugins/dkj-policy/scripts/README.md).
- **`dkj-policy/`** — the workflow's own root folder (named `contributing-davekjohn/` from August 27
  until September 5, 2026, #1437), and since August 27, 2026 the home of
  every document the contribution cycle produces or governs. Its
  [`CONTRIBUTING.md`](dkj-policy/CONTRIBUTING.md) is the centre of it: the standard branch +
  PR workflow, which holds with no plugin installed, and this repo's answers to the workflow's seams on
  top of it. Beside it sit [`CHANGELOG.md`](dkj-policy/CHANGELOG.md), the open branch's
  `<branch>.md` while one is open, and `releases/` — what a cut *generated*
  (`changelog/<X>.x/<X.Y.Z>.md`, the complete note per version, and `github/<X>.x/<X.Y.Z>.md`, that
  version's GitHub Release body), the hand-written note per version under `audience/`, the dated list of
  every release ever cut in
  [`releases/history.md`](dkj-policy/releases/history.md), and this repo's seam answers in
  [`dkj-policy/releases/README.md`](dkj-policy/releases/README.md). The cutting process itself travels
  with the plugin as
  [`RELEASES-portable.md`](plugins/dkj-policy/RELEASES-portable.md).
- **`.claude/`** — the repo layer, on the seam described under
  [The seam, specified](#the-seam-specified): `specialists/SPECIALISTS.md` (the inclusion carrying the
  body import, the lens import and the roster), `specialists/lenses/` (this repo's own repo lenses),
  the Specialists handbook `specialists/README.md` next to them, `rules/` (path-scoped rules), and
  `settings.json` (harness config; see [Consumption](#consumption)).
- **The root documents** — this `README.md`, `CLAUDE.md` and
  `SECURITY.md`, plus the two consumer-facing procedures [`INSTALL.md`](INSTALL.md) and
  [`UNINSTALL.md`](UNINSTALL.md) — those sat a level down beside the plugins until
  [#664](https://github.com/DaveKJohn/claude-code-specialists/issues/664) moved them here, which is
  what keeps them out of the published marketplace without any exclusion list having to remember
  them — and
  **`.github/`** (`pull_request_template.md`, the issue templates + three workflows: `workflows/ci.yml`,
  the CI gate that runs the lint + test suites on every PR and push to `main`, plus
  `workflows/claude.yml` and `workflows/claude-code-review.yml`, which answer an `@claude` mention and
  review each PR. Only `ci.yml`'s job blocks a merge; see [`CONTRIBUTING.md`](dkj-policy/CONTRIBUTING.md)).

## Consumption

A consuming repo adds this marketplace via `extraKnownMarketplaces` in `.claude/settings.json` and
enables the desired plugins via `enabledPlugins` — and then, because an install is **project-scoped**,
runs `claude plugin marketplace update <marketplace>` followed by
`claude plugin install <plugin>@<marketplace> --scope project` from that repo's root for each of
them; the settings keys alone leave you without a working install, without the flag the command
defaults to a machine-wide `user` install instead, and without the refresh it can serve an *older*
version and still report success (see [Versioning](#versioning)). The canonical enable-a-plugin
walkthrough (the
settings snippet, the cache refresh, the per-plugin install, the restart, the install-record
self-check, running the bootstrap skill) is in
[INSTALL.md](INSTALL.md#adoption--how-to-connect-your-repo) — five steps, for those who
didn't build the system, with its
[quickstart half](INSTALL.md#quickstart--the-commands-and-nothing-else) as the commands-only
front door; the way back out is its mirror,
[UNINSTALL.md](UNINSTALL.md). This section keeps only the two marketplace-wide facts that matter
beyond any one consumer:

**Seeing which release you're on — `plugin.json`.** Each plugin folder carries a `.claude-plugin/plugin.json`
whose `version` is the release it belongs to, bumped in lockstep across every plugin. Because
`claude plugin update` pins the cache to a specific version (see [Versioning](#versioning)), the
cached `version` is *exactly* the installed release. The full history of that release lives in this
repo's [`CHANGELOG.md`](dkj-policy/CHANGELOG.md) and [`dkj-policy/releases/`](dkj-policy/releases/) — and a consumer has both, because
the marketplace source is a git clone of the whole repository at
`~/.claude/plugins/marketplaces/<marketplace>/`, not a per-plugin extract.

That last fact is why the per-plugin `CHANGELOG.md` and `RELEASE.md` card were **retired on August 8,
2026**. They existed to give a reader a history inside the plugin cache; measured, the reader already
had the real one, and the 11,684 lines across those ten files were a second copy free to disagree with
it. One repository, one product, one changelog.

**One canonical channel — mind the old repo names.** The marketplace is named `claude-code-specialists`
(repo `DKJ-Solutions/claude-code-specialists`) and that is the only channel **for a reader who registers it
themselves**; use that name in `extraKnownMarketplaces`. If this copy reached you through an
organisation's own marketplace, that channel is the canonical one for you and this paragraph is about
the public source it was mirrored from — do not register a second one alongside it. This repo has been renamed twice — first from `claude-specialists`, then from
`davekjohns-workshop` (August 3, 2026) — and an old name keeps pointing at the same repo via a
**GitHub rename redirect**, so a marketplace still registered under one of them refers to exactly the
same repo. **And on September 2, 2026 the owner changed as well** — the repo was transferred from the
personal account `DaveKJohn` into the **`DKJ-Solutions`** organisation, so
`DaveKJohn/claude-code-specialists` now resolves through a **transfer redirect** and a registration under
the old owner keeps working exactly like one under an old name. That redirect carries one condition the
rename redirects do not: it holds only for as long as nothing is created at the old path, so
**`DaveKJohn/claude-code-specialists` must never be recreated.** There is **no second source** to mirror
to. However, the local marketplace clone of such an
old registration can lag behind (it was once cloned at an older commit and doesn't converge to the new
`HEAD` on its own), so an install on that channel silently yields an older plugin version. If you run
into this: update the marketplace registration (a marketplace update) or re-add it under
`claude-code-specialists` — a fresh install should always use `DKJ-Solutions/claude-code-specialists`.

## Versioning

Every plugin (one folder under [`plugins/`](plugins/)) carries its own `version` in its
`plugin.json`. On a release those versions move **in lockstep** — they all get the same number under
one repo-wide tag `vX.Y.Z`, which is correct precisely because this repository holds
[one product](#one-product-one-repository). **That version number is one of two update gates**:
`claude plugin update <plugin>@<marketplace> --scope project` compares nothing but version numbers
(and needs that same scope flag, for the same reason the install does) — but it compares them against
the consumer's **cached** copy of this marketplace, not against this repo. So `claude plugin
marketplace update <marketplace>` belongs in front of it. What each command was measured to do differs,
and the adoption page states it per command: **`install` does not refresh** — it served the *previous*
version minutes after `v3.0.2` (July 30, 2026) and again after `v3.0.5` (July 31, as a controlled pair:
without the refresh `3.0.4`, with it `3.0.5`) — while a bare **`update`** refreshed the cached clone
itself and still moved `3.0.3 -> 3.0.4`. So the refresh is load-bearing in front of an install and
idempotent insurance in front of an update; it stays in front of both. With both gates passed, a consuming repo (including this
repo itself, which consumes itself) only pulls in merged changes after the `version` has been
bumped — a merge without a release stays invisible to consumers, and a shared agent-def change
therefore always lands here first, never the other way around. The full mechanics — cutting a
release, the three release documents, the lint guardrails — are in
[`RELEASES-portable.md`](plugins/dkj-policy/RELEASES-portable.md#cutting-a-release),
with this repo's release list in [`releases/history.md`](dkj-policy/releases/history.md) and its own answers to the
workflow in
[`dkj-policy/releases/README.md`](dkj-policy/releases/README.md).

## Manuals — the split model

Every specialist in these plugins is built from up to three files, physically split by audience and
by what's portable versus repo-specific: the **manual** (the portable playbook, split from the repo
lens), the **agent def** (the executable abbreviation), and — for the main-loop specialists only —
a **persona template**.

### The manual: portable craft + repo lens

A specialist handbook splits into a **portable** part (repo-neutral, identical in every repo: the
craft, the hard rules, the tone) and a **repo lens** (the `## Specific to this repo` part: which
content/context of that repo the specialist serves). The portable part lives in
`plugins/<plugin>/manuals/<group>-<id>-manual.md` in this marketplace; the consuming repo keeps only
the lens in `.claude/specialists/lenses/<group>-<id>-extension.md`. The agent def points to both.

**All four teams have now been migrated** — every handbook lives here in the `manuals/` folder of
its plugin, and every consuming repo keeps only its repo lens in `.claude/specialists/lenses/`:

- **`dkj-subagents-alpha` (the core team)** → `plugins/dkj-subagents/dkj-subagents-alpha/manuals/` (Paula, Rebecca, Vera, Gwen, Cody, Tycho,
  Sylvester, Tessa, Edith, Victor, Sebastian, Ravi, Nolan, Marlowe, Auden).
- **`dkj-subagents-lifehub` (an add-on team)** → `plugins/dkj-subagents/dkj-subagents-lifehub/manuals/` (Astrid, Fiona, Hugo, Ian, Onyx).
- **`dkj-subagents-shopify` (an add-on team)** → `plugins/dkj-subagents/dkj-subagents-shopify/manuals/` (Liam, Sandra, Steven).
- **`dkj-subagents-ecomm` (an add-on team)** → `plugins/dkj-subagents/dkj-subagents-ecomm/manuals/` (Sergio, Craig, Sean).

### Agent def vs. manual — two files, one specialist

Every specialist in these plugins consists of two files, each with its own job:

- **`agents/<group>-<id>-agent.md` — the agent definition**, the executable form. The frontmatter
  (`name`, `description`, `tools`, `model`) is what Claude Code reads to register the subagent;
  the `description` is also the routing signal the main loop uses to pick a subagent. The body is
  deliberately just a compact operational core (working method, boundaries, deliverable format) and
  refers to the playbook for the actual craft.
- **`manuals/<group>-<id>-manual.md` — the playbook**, the full description of the craft: the
  hard rules, the trade-offs behind them, and the personality & tone. It is read on demand — by the
  subagent itself when in doubt, and by the main loop (the orchestrator that assigns the work and
  the personas that are not subagents).

**The manual is leading; the agent def is the executable abbreviation.** You change a craft rule in
the manual; you only touch the agent def when the operational core or the tool set changes. The two
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

### Persona templates — a third artifact alongside agent def and manual

The orchestrator and the main-loop specialists (Chris #01, Bianca #02, Derek #05, Rendall #06) run in
the **main loop**, not as subagents. A plugin *can* inject always-on main-loop context — a root
`settings.json` with an `agent` key activates one of its own agents as the main thread — but that route
is **verified and deliberately not switched on**, because it changes every consumer's main loop from a
version bump they did not read, and a second `agent`-setting plugin silently wins on load order
([issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215); the same correction has
been in [`specialists-init`'s page](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md) since
that decision, and this sentence was the copy it never reached). An intake conversation moreover
requires direct back-and-forth with the client. They therefore
deliberately have **no** agent def; their portable source lives in
`plugins/dkj-subagents/dkj-subagents-alpha/personas/<group>-<id>-persona.md` as a **self-contained template** (portable body
+ a repo-lens placeholder). The consumer loads the **portable body straight from the plugin install**
via an `@` import in its `CLAUDE.md` (the orchestrator always, the other personas on demand). The
local extension `.claude/specialists/lenses/<group>-<id>-extension.md` is
therefore **lens-only**: only the repo-specific `## Specific to this repo` part, no body copy. The
drift lint (see the [connectors README](connectors/README.md#maintenance-drift-lint)) recognizes
such a lens-only extension and reports it as `LENS-ONLY`. The lint's agent-def↔manual coupling
deliberately leaves personas alone (they have no agent def).

## Shared agent-def blocks — one source for the verbatim boundaries

A number of bullets in the **Boundaries** section are word-for-word identical across
many agent defs — the **inbound rule** and the **automation-first rule** even across all 26 (every
agent def in every plugin). Such governance belongs *in* the
agent-def body (always loaded, also for a directly invoked worker subagent), but Claude Code has no
native transclusion in an agent def — what's written there is there, literally. To still maintain
those blocks in **one place** instead of in every agent def, a **build-and-lint** model applies:

- The canonical text of each shared block lives in `plugins/dkj-subagents/subagent-shared/<name>.md` (a sibling of
  the four team folders — every file carrying a block is a team's).
- In an agent def the block appears between sentinels:
  `<!-- BEGIN shared:<name> … -->` … `<!-- END shared:<name> -->`. The content really is there (self-contained), but is marked as generated.
- **Never edit between the sentinels.** Change the source file and run
  [`scripts/agents/build-agent-defs.ps1`](scripts/agents/build-agent-defs.ps1) — all agent defs
  carrying the block are updated. The lint gate
  ([`check-plugin-integrity.ps1`](scripts/lint/check-plugin-integrity.ps1), check 7) fails as
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

Current blocks — one canonical source file each under `plugins/dkj-subagents/subagent-shared/`, so the directory
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

and the lint gate ([`check-plugin-integrity.ps1`](scripts/lint/check-plugin-integrity.ps1),
check 10) then verifies the span's backtick-quoted names against the real skill set on every run.
Three rules govern when and how to reach for it:

- **Wrap tightly.** The extraction is character-based (so the sentinels may sit inline, mid-sentence,
  not just around a standalone bullet list as shown above), but *every* backtick-quoted term inside
  the span counts as a claimed skill name — so the span must close around just the skill names,
  nothing else in backticks.
- **Only for a genuinely complete enumeration.** A deliberately partial or illustrative list (e.g.
  INSTALL.md's slash-only subset) gets no marker — marking it would turn an intentional subset
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

Opt-in for the same measured reason as the other two: the **root** `scripts/README.md` is a
deliberate *subset* of the same registry — only what a person invokes by hand — so a blanket rule
keyed on filename would be born needing an allow-list for every lib, hook-only script and generator
there. The sentinel is what lets the 1:1 table be gated without first answering the subset table's
question.

## Where this runs: Chat, Cowork, and Claude Code

Anthropic's Claude product has three relevant surfaces: **Chat** (a conversation), **Cowork** (a
working-session mode — desktop generally available, web/mobile in beta as of July 2026 — for
non-code knowledge work, positioned alongside Claude Code, which stays the tool for software
engineering), and **Claude Code** itself. See
[claude.com/product/cowork](https://claude.com/product/cowork) for Cowork's own positioning. This
matters operationally for the skills/subagents/hooks split described under
[What lives here and what doesn't](#what-lives-here-and-what-doesnt): a **skill**
bundled in a plugin works across all three surfaces, but a **subagent** or a **hook** runs only in
Cowork and in Claude Code — in a plain Claude.ai Chat session they show up grayed out (see
[Use plugins in Claude](https://support.claude.com/en/articles/13837440-use-plugins-in-claude)).
Concretely for claude-code-specialists: the specialists roster (the subagents under Chris), the
SessionStart hooks the enabled plugins ship (read them in each plugin's `hooks/hooks.json` — a
hand-written list here was named as three and went stale twice inside two days) and the Stop hook
`cycle-autopark`
function in Claude Code and in Cowork, but not in a plain Claude.ai Chat session — only the skills
<!-- skills:all -->(`fold-changelog`, `open-pr`, `ship-pr`, `new-branch`, `claim-issue`, `park`, `fix-mojibake`,
`specialists-init`, `specialists-teardown`, `sync-roster`, `start-task`, `adopt-shopify-floor`,
`cut-release`, `adopt-dkj-policy`,
`release-notes-page`, `sync-main`, `push-preview`, `archive-theme`, `check-branch-entry`,
`check-policy-drift`,
`prune-merged`, `tidy-machine`, `plugin-versions`, `update-plugins`, `check-fanout`,
`measure-skill`, `worktree-lane`, `report-issue`, `adopt-dkj-policy-bwj`, `orchestrator`)<!-- /skills:all -->
remain available there.

**`orchestrator` is on that list for a reason worth reading twice.** Everything else there is a
convenience that survives; that one is the *conductor*. Where the roster and the hooks fall away, it is
what puts Chris back in the conversation — so the layer this table shows as unavailable has a route in
through the one column that is.

Skills themselves are Anthropic's general **Agent Skills** mechanism — organized folders of
instructions/scripts/resources that an agent discovers and loads progressively (name + description
always loaded, the `SKILL.md` body only on trigger, other resources on demand) — exactly what
claude-code-specialists already uses to distribute its skills via the marketplace (see the
[Anthropic engineering post](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
and the [docs](https://code.claude.com/docs/en/skills)). Not confirmed: whether Cowork runs on the
Claude Agent SDK, or whether a Cowork subagent shares its definition format with — or is
interchangeable with — a Claude Code subagent.

## Which half needs a repository — the Claude App map

The section above answers *which mechanisms* a surface supports. This one answers the question that
turned out to matter more: **which of this repo's contents can do their job when there is no repository
at all** — a Claude App user with the plugins installed and nothing checked out. The two questions look
alike and come apart immediately: a skill is available on every surface, and a skill that ends in
`powershell -File ...\open-pr.ps1` is available and useless.

**The rule, so a new item can be classified without re-running the sweep.** Applied to the *item*,
in order:

1. **Does it ship an executable** — a `.ps1` in its own folder, or a `hooks.json` that invokes one?
2. **Do its instructions send the reader to run one, or to read or write a path in the consuming repo?**
3. Otherwise it is portable.

Three candidate rules were weighed and this one was kept because it is the only one that can be
*checked*: "does it shell out" misses the wrappers that shell out one level down, and "does it assume a
git branch" is a judgement about prose. Test 1 is a directory listing; test 2 is
`grep -rl '\.ps1' plugins --include='*.md'`, which returned **30** files against the tree on August 15,
2026 — 28 of them true, and the two that were not are the interesting part.

**The verdict has three values, not two, and that is the finding.** A binary map has to round the two
`grep` survivors — Ravi's agent def (`06-24`, which names the shared-block generator) and Liam's
(`04-20`, which names `new-branch.ps1`) — either into "App-safe", handing an App user a step that cannot
run, or out of their team, losing a whole specialist over one line. Neither is right, because a
specialist's *craft* is portable and one step of one procedure is not. So:

| verdict | meaning | who |
|---|---|---|
| **portable** | works with no repository | the personas, manuals, and 13 of 15 `dkj-subagents-alpha` agent defs; the shared blocks in `subagent-shared/`; the `orchestrator` skill |
| **degraded** | works, minus a named step | Ravi `06-24` and Liam `04-20` — one step each, both of them a script |
| **repo-bound** | cannot function at all | both workflow plugins whole; `dkj-subagents-alpha`'s three PowerShell skills and its one SessionStart hook; `dkj-subagents-shopify`'s `start-task` |

**What the Claude App package is: a filtered publication, not a second repository.**
[`publish-to-business.ps1`](scripts/release/publish-to-business.ps1) already overwrites
`BWJ-ecommerce/claude-plugins-bwj` from here on every run; since
[#683](https://github.com/DaveKJohn/claude-code-specialists/issues/683) it publishes the subset
[`Get-BusinessMarketplacePlugins`](scripts/repo-config.ps1) names — the four teams — and rebuilds the
manifest to match. The workflow is not offered there because it is not there. No per-entry hide flag was
invented: the manifest format has none, and one would need Claude to honour it, while a plugin that did
not travel cannot be offered by anything.

**The marketplace keeps its name.** `claude-code-specialists` is the key in every consumer's
`enabledPlugins` (`dkj-subagents-alpha@claude-code-specialists`), so the filtered marketplace is the *same*
marketplace with fewer entries, not a second one under a new key.

**The unit is the plugin, and the degraded items travel.** `dkj-subagents-alpha`'s three PowerShell skills and
two hooks go to the App target along with everything else in that plugin, because the plugin published
there has to be byte-identical to the plugin released here — otherwise its version number stops meaning
one thing. They are handled where they can be handled without forking: the hooks are simply inert in a
plain Chat session, and `v4.9.0` ([#672](https://github.com/DaveKJohn/claude-code-specialists/issues/672))
made all three skills non-model-invocable and had each name its PowerShell dependency in its own
description, so the model cannot walk a user into one.

**How the sync stays honest.** The publication has always refused a manifest naming a folder that did
not travel. Filtering makes the *reverse* possible — a plugin folder that travels while the manifest
never mentions it — and that one is silent: nothing errors, Claude simply never offers it, and the
manifest reads as a complete marketplace to anyone who checks it instead of the tree. Both directions
are hard stops now, and a keep-list naming a plugin the manifest does not have is a third, because a
typo there would quietly exclude the plugin it meant to keep and report success.

## How we use skills — and what we deliberately don't

<!-- skills:all -->Most skills in claude-code-specialists today (`fold-changelog`, `open-pr`, `ship-pr`,
`new-branch`, `claim-issue`, `park`, `fix-mojibake`, `specialists-init`, `specialists-teardown`,
`sync-roster`, `start-task`, `adopt-dkj-policy`, `adopt-shopify-floor`,
`release-notes-page`, `sync-main`, `push-preview`, `archive-theme`, `check-branch-entry`, `check-policy-drift`,
`prune-merged`, `tidy-machine`, `plugin-versions`, `update-plugins`, `measure-skill`, `worktree-lane`, `check-fanout`) are a thin wrapper around a script — procedural
**mechanism** (branch, claiming an issue on the tracker before the work on it starts, PR, ship, fold,
bootstrap, teardown, roster-sync, encoding repair, reading a
repo's own conventions, placing an add-on team's operational floor, pushing a branch to its own preview
theme, backing a theme up with a committed receipt before it leaves the store,
the reading copy of the release notes, laying the repo's law-bearing documents out in rank order
so a session can read them against each other, reaping the local branches a merge left behind, telling
whether this checkout's installed plugin matches the marketplace clone and which command closes any
gap, closing that gap in one command instead of one per plugin, pricing what a skill costs the sessions that carry it, giving a branch its own worktree so
another one can ship, and reading the working copy on both sides of a dispatched fan-out to say whether
a subagent discarded any of it). `cut-release`, `orchestrator`, `report-issue` and `adopt-dkj-policy-bwj`<!-- /skills:all --> are the
deliberate exceptions: a checklist with no script of its own (see below); a skill that must not have
one — `orchestrator` reads a persona file into the conversation, and the environment it exists for is
precisely the one where `powershell` is absent; and the two `dkj-policy-bwj` procedures, which run over
`gh` and the Asana MCP with a judgement call in the middle (the colleague-facing translation) rather
than a transform a script could carry. Either way, the specialists' craft and judgment
live in the persona/manual context (agent defs), not in skills. That's a deliberate split, but it
also means we currently use only one half of what Agent Skills can carry.

**One shape used to be illustrated here and no longer is: two skills sharing one script.** `lock` and
`handover` were the only such pair — the same reporter, differing only in what each did with the answer
— and they are the reason the shared-scripts registry names a script's *documenting page* rather than
its callers. Both were removed on August 27, 2026
([#957](https://github.com/DaveKJohn/claude-code-specialists/issues/957), Dave), along with the reporter
behind them. The registry field is unchanged and still answers that question; what it has lost is its
worked example, so the relationship it was built for now runs only in the other direction —
`ship-pr` and `cut-release` each name two scripts.

The unused half is a noted opportunity, not an open task: of the three progressive-disclosure levels
described in [Where this runs](#where-this-runs-chat-cowork-and-claude-code) above, none of our
skills use level 3 (bundled reference material/templates/examples) — all of them sit at level 1/2. A
repeatable specialist *procedure* — a review or copy-edit checklist, for instance — could become a
knowledge-skill with bundled reference material, which would then work on every surface, including a
plain Chat session where subagents and hooks are unavailable.

That doesn't mean maximizing skill usage everywhere. The discipline is: add a skill only where it
makes a repeatable procedure or piece of knowledge genuinely portable, and where that value covers
the maintenance cost. Living example: `cut-release` is **two** things with the same name, and keeping
them apart is the discipline. Its **script**, `scripts/release/cut-release.ps1`, is a shared, mirrored
script like the rest of the workflow — it became one on August 3, 2026
([#417](https://github.com/DaveKJohn/claude-code-specialists/issues/417)), with everything that
legitimately differs per repo read from optional seam functions in
[`scripts/repo-config.ps1`](scripts/repo-config.ps1) rather than baked in. It used to be deliberately
repo-only, on the argument that reading `.claude-plugin/marketplace.json` and bumping every
`plugin.json` in lockstep is a structure only a marketplace has; the seam answered that by making the
plugin half optional, so a repo without plugins simply does not declare it (see its record in
[`scripts/lib/script-contract-lib.ps1`](scripts/lib/script-contract-lib.ps1), and the retirement of the
"out of scope" note in
[`scripts/sync/check-script-contract.ps1`](scripts/sync/check-script-contract.ps1), which held both
until the registry moved out). Its **skill** is a different artifact: the closing steps every release
shares once the version bump is committed (tag + push, branch cleanup), as a checklist with no script
of its own (issue #177). That checklist also covers the GitHub Release, whose body is the highest
release tier the repo has and whose other tiers go along as
attachments — a manual closing step this repo takes at every release (see
[RELEASES-portable.md](plugins/dkj-policy/RELEASES-portable.md#cutting-a-release)),
just not one `cut-release.ps1`
itself automates. *Which* bumps get a Release is repo policy and lives in the release manager's lens,
not in the portable checklist.

Cowork is positioned for non-code knowledge work; claude-code-specialists is a code/plugin-maintenance
repo, so Claude Code is the right tool here and the repo stays deliberately Claude-Code-centric.
Cowork's value sits in other, non-code work — not in this repo.

## Invocation

Once enabled, the specialists can be invoked with the **plugin name as namespace**:
`@dkj-subagents-alpha:<name>`, `@dkj-subagents-lifehub:<name>`, `@dkj-subagents-shopify:<name>`, or `@dkj-subagents-ecomm:<name>`.

## Which release am I on?

Read the `version` in your cached `<plugin>/.claude-plugin/plugin.json`. It travels with the plugin
cache, so once `claude plugin update` has pinned your install to a version, that number is exactly the
release you are on. Every plugin bumps in lockstep, so any one of them answers the question.

For **what changed** in that release, read [`CHANGELOG.md`](dkj-policy/CHANGELOG.md) and
[`dkj-policy/releases/`](dkj-policy/releases/) in the marketplace clone you already have —
`~/.claude/plugins/marketplaces/dkj-claude-plugins/`. See [Consumption](#consumption) above for
the mechanics.

A newly added **skill** additionally needs a session restart before it becomes visible, and the
skill counters `/reload-plugins`/`/reload-skills` print are not reliable evidence either way — see
[Staying up to date](INSTALL.md#staying-up-to-date) in the adoption page for the full detail.

## Adoption: the bootstrap path

> **New here?** The shareable beginner route is
> [INSTALL.md](INSTALL.md#adoption--how-to-connect-your-repo) — get connected in five
> steps, for those who didn't build the system, with its
> [quickstart half](INSTALL.md#quickstart--the-commands-and-nothing-else) as the
> commands-only front door and [UNINSTALL.md](UNINSTALL.md) as its mirror for the way back out. Below
> is the underlying explanation.

Enabling the plugin delivers the **worker subagents**, but not the **conductor** (Chris) or the
governance/hooks layer, so the skill **`specialists-init`** (from `dkj-subagents-alpha`, the core team) closes
that gap in a consuming repo. Because a plugin skill cannot hook itself in, the path is two-stage:

> **One half of the old reason for this is false, and it matters for
> [Removal: the teardown gap](#removal-the-teardown-gap) below.** This section used to justify the
> bootstrap with "a plugin injects no main-loop context and edits no `CLAUDE.md`". The second half is
> true and documented. The first is not: a plugin **can** activate one of its own agents as the main
> thread via a root `settings.json` — and the `@`-import is both the only reason the bootstrap exists
> and the single worst thing left behind on uninstall. Finding:
> [issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215).

### Delivering the orchestrator from the plugin — verified, deliberately not switched on

The mechanism was read from the docs rather than assumed (July 29, 2026), because the whole bootstrap
path turns on whether it exists:

- **It does what the issue claimed.** *"Plugins can include a `settings.json` file at the plugin root
  to apply default configuration when the plugin is enabled. Currently, only the `agent` and
  `subagentStatusLine` keys are supported."* And: *"Setting `agent` activates one of the plugin's
  custom agents as the main thread, applying its system prompt, tool restrictions, and model."*
  Unknown keys are silently ignored, and `settings.json` takes priority over `settings` in
  `plugin.json`.
- **The compaction worry dissolves in this route rather than being small.** The context-window
  reference flags exactly one startup block as not re-injected after `/compact` — the **skill**
  descriptions (*"Only skills you actually invoked get preserved"*). Agent descriptions carry no such
  flag. More decisively: a main-thread agent's body **is** the system prompt, which travels with every
  request by construction. There is nothing left to compact away.
- **The blocker is gone as of this release.** Chris's body used to say he *"never executes anything
  himself"*, which is workable as a role inside a general-purpose loop and crippling as a system
  prompt. It now forbids **unattributed** work rather than typing: every action is taken in the owning
  specialist's name, announced first, under their craft rules — by handing off to a subagent where
  subagents exist, and otherwise by Chris doing that specialist's work under their name. The old
  wording was internally inconsistent anyway: ritual step 5 has always said *"execute according to
  their trade rules"*.

**So why is the switch still off?** Three reasons. The first used to be an unknown and is now a
measured fact — which changes its weight without removing it:

1. **Two enabled plugins that both set `agent`: the last one silently wins.** Settled by experiment
   on July 29, 2026 (Claude Code 2.1.220), because it is not on the plugins page and not in the
   reference. Two throwaway plugins, each with an `agent` in its root `settings.json` pointing at its
   own agent, run in both orders along **both** load paths — repeated `--plugin-dir`, and the real
   consumer path (`enabledPlugins` + `extraKnownMarketplaces`). In all four runs the **last-listed**
   plugin won, and not merely its system prompt: the winner's `model` came through too (sonnet-5 for
   one, haiku for the other), so the whole agent config travels. Ordering is positional, not
   alphabetical — reversing the order reverses the winner. There is **no error and no warning**; the
   harness knows and says so only at debug level:
   `[DEBUG] Plugin "expbeta" overrides setting "agent" (previously set by another plugin)`.
   So the behaviour is now written down, but the hazard is real and worse than a hard failure: a
   consumer who enables any other plugin that also sets `agent` loses their orchestrator to
   whichever plugin happens to sit last, with nothing on screen to say so.
2. **It changes every consumer's main loop on their next plugin update**, from a version bump they did
   not read. Outward-facing and effectively irreversible for anyone who pulls it before a revert.
3. **Chris ships as a persona, not a subagent, so there is no `agents/01-01-agent.md` to point at.**
   Creating one is not a formality: that file's `tools:` and `model` would become **the whole main
   thread's** tool policy and model.

The body is therefore ready and the switch is not thrown. Flipping it is Dave's call, now on a fact
instead of an unknown: the collision resolves silently and positionally, so a consumer who enables a
second `agent`-setting plugin gets a different orchestrator without being told.

- **Step 0 (manual, six acts in order).** (1) Put the marketplace source + `enabledPlugins` in
  `.claude/settings.json` (see [Consumption](#consumption) above),
  (2) **restart** the session once — a session start is what registers the marketplace, and without this
  act 3 fails with `Marketplace '<marketplace>' not found` (inbound
  [#329](https://github.com/DaveKJohn/claude-code-specialists/issues/329)), (3) refresh
  the cached marketplace with `claude plugin marketplace update <marketplace>`, (4) run
  `claude plugin install <plugin>@<marketplace> --scope project` **from the consumer's root, once per
  enabled plugin**, (5) **restart** the session — only then is the skill available — and (6) **verify the
  install record** before going on.

  > **Why six, and why the same six everywhere** (inbound
  > [#297](https://github.com/DaveKJohn/claude-code-specialists/issues/297)). This procedure is described at
  > three entry points, and they used to count it as *four acts* here, *three acts* in
  > [`specialists-init`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md#chicken-and-egg--step-0-is-done-by-the-user)
  > and *three steps* in the [adoption page](INSTALL.md#connecting--the-install-step) — the same path, no
  > step missing anywhere, three different numbers. A reader following it for the first time has the
  > count as their only check on whether they skipped something, and three counts remove exactly that.
  > Two of the three were also counting different things: #284 raised this page from three to four by
  > making the refresh an act, while `specialists-init`'s step 0 has that refresh too and still said
  > three. The unit is now **acts** — individual things you do — on both pages; the adoption page keeps
  > *steps* as its own unit because its Step 1 **is** all six acts above, and it now says so. Verifying
  > counts as an act because leaving it out is the failure the next blockquote calls silent and
  > self-camouflaging: a reader who ticks off five and stops has never checked that the install exists.
  >
  > **The step count moved from three to four on August 3, 2026** (inbound
  > [#408](https://github.com/DaveKJohn/claude-code-specialists/issues/408)), on the adoption page, in
  > `specialists-init` and here in one change. Filling the lenses was always part of the procedure and
  > was disclosed in a trailing clause reading *"at your own pace"*, which reads as optional polish on a
  > page that had already announced three steps — while it is in fact the largest step and the one where
  > the system starts being useful. That page was renamed `QUICKSTART.md` → `ADOPTION.md` in the same
  > change, for the matching reason: the label promised a size the content never had.
  >
  > **And it moved from three to four on August 20, 2026** (inbound
  > [#784](https://github.com/DaveKJohn/claude-code-specialists/issues/784)) — running each enabled
  > plugin's `adopt-*` skill became a step of its own, because a consumer cannot infer a skill's
  > existence from a plugin's presence and was meeting the rest of their adoption one session-check
  > `[ERROR]` at a time. The install page's quickstart is **five**, one more, since its Step 1 is the
  > install this page's step 0 covers.
  >
  > **It was five until August 1, 2026**, when #329 made the first restart an act of its own on all three
  > pages at once. Folding it into act 1 would have kept the number at five, and folding it into another
  > act is exactly what had kept it unwritten while it was already required.

  > **And if you sweep for these counts, make the sweep emphasis-tolerant** (inbound
  > [#305](https://github.com/DaveKJohn/claude-code-specialists/issues/305)). The sweep that aligned the
  > entries above was shaped `(one|two|…|seven) (acts?|steps?)`, and that regex **misses markdown
  > emphasis**: against `specialists-init/SKILL.md` it found nothing, because the text there reads
  > `**five** steps` — the asterisks sit between the two words. Written
  > `(…)\*{0,2} \*{0,2}(acts?|steps?)` it surfaces that line, and one more the original sweep never
  > showed: a fourth counting of the seam migration in
  > [`specialists-teardown`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-teardown/SKILL.md). Two lessons worth keeping
  > if count-linting is ever built: a sweep that returns few hits is not evidence of few instances, and a
  > file the same PR touched is not automatically covered by that PR's verification.

  > **The marketplace is a cached clone, which is why the refresh is an act and not a formality**
  > (inbound [#282](https://github.com/DaveKJohn/claude-code-specialists/issues/282) for the behaviour,
  > [#284](https://github.com/DaveKJohn/claude-code-specialists/issues/284) for this page having omitted
  > it). `plugin install` compares against the consumer's cached copy of the marketplace, not against
  > this repo: minutes after `v3.0.2` was tagged and pushed, a fresh project-scoped **install**
  > produced `3.0.1` and reported `✔ Successfully installed`. Nothing in that output hints the version
  > is stale. And the correct version of this block in `specialists-init`'s own step 0b cannot cover
  > for the omission here, for the same reason this path exists at all: that skill does not exist until
  > the install has happened.

  > **The install is not a formality, and leaving it out fails silently** (inbound
  > [#274](https://github.com/DaveKJohn/claude-code-specialists/issues/274), measured in a consumer during
  > the 3.0.0 adoption round). An install is **project-scoped** — `installed_plugins.json` keys every
  > record by `projectPath` — so the two settings keys plus a restart give you no *working* install and
  > no error. What the reader gets instead is a session with neither the skill nor the session-start
  > hooks, which is indistinguishable from a healthy one: "no hooks because the plugin is not loaded" and
  > "no hooks because all is well" print the same nothing.
  >
  > **They do not, however, produce *nothing* — and that is the sharper trap** (inbound
  > [#327](https://github.com/DaveKJohn/claude-code-specialists/issues/327),
  > [#355](https://github.com/DaveKJohn/claude-code-specialists/issues/355)). This block read *"produce
  > no install and no error"* until September 4, 2026, and `INSTALL.md` had already retired that absolute
  > — *"this page no longer claims they do nothing"* — while this one kept it. Measured on a virgin
  > profile with the marketplace registered and the cache present, a **single session start** wrote a
  > full project-scoped record, with the correct `projectPath`, `version` and `gitCommitSha`, while that
  > same session loaded nothing at all: the record is written *after* the load phase, so only the next
  > session gets the plugin. Measured again after three session starts, its `installPath` named a
  > directory that **did not exist**. So a record is a claim, not evidence — run the install, and verify
  > by the **surface** (is the bootstrap skill in your slash list, did the session hooks print, does
  > Chris open the turn) rather than by the administration. Mechanics:
  > [Connecting — the install step](INSTALL.md#connecting--the-install-step).
  >
  > **`--scope project` carries that same weight, and the later update is the same pair of commands:**
  > `claude plugin marketplace update <marketplace>` and then
  > **`claude plugin update <plugin>@<marketplace> --scope project`** (inbound
  > [#279](https://github.com/DaveKJohn/claude-code-specialists/issues/279), the 3.0.1 round; the refresh
  > half is inbound [#282](https://github.com/DaveKJohn/claude-code-specialists/issues/282)). All of them
  > default to `--scope user`; the install then writes a machine-wide record with no `projectPath`, and
  > the update refuses outright on a project-scoped install. Project scope is the intended model for
  > this family (Dave, July 30, 2026) — it gives each repo **its own install record**, and every other
  > document here assumes it. Full mechanics of the refresh half:
  > [Staying up to date](INSTALL.md#staying-up-to-date).
  >
  > **What project scope does *not* promise is that the record stays put** (inbound
  > [#296](https://github.com/DaveKJohn/claude-code-specialists/issues/296)). This sentence used to say it
  > keeps a consumer *"pinned to the version it was tested against"*, and that claim did not survive
  > being measured. On July 31, 2026 both of `life-hub`'s project-scoped records moved `3.0.4 → 3.0.5`
  > in a **single** write to `installed_plugins.json`, their `lastUpdated` stamps 70 ms apart — while
  > that repo's own session issued no `claude plugin` command at all. Checked afterwards against every
  > session transcript on the machine for that day: **26** `claude plugin` invocations, and not one in
  > the window the write falls in. So something other than an explicit command can advance a
  > project-scoped record, and "pinned" was a property of the bookkeeping rather than of the repo.
  > (What the same measurement *did* explain: the marketplace clone moving minutes earlier was a
  > deliberate `marketplace update` from another session on the machine — that half is not mysterious.)
  >
  > Practically: project scope is still the right model and still what every document here assumes —
  > what changes is that you should **read your record rather than trust it**. On a machine with several
  > consumers and several sessions, `installed_plugins.json` is the only place your actual version is
  > written down; the install output does not name a version at all. The query is under
  > [Staying up to date](INSTALL.md#staying-up-to-date).
  >
  > **Verify with the `projectPath` record, not with `claude plugin list`** — that command is not
  > repo-scoped and reported a plugin as `enabled`, at `project` scope, in this very repo while it
  > held no install record of its own and loaded nothing. The exact query is in
  > [`specialists-init` step 0c](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md). This documentation
  > path is the only thing a new consumer has, because until the plugin loads, the skill that would
  > say otherwise does not exist.
- **Step 1 (the skill).** Invoke `specialists-init`. The bundled
  [`bootstrap.ps1`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/bootstrap.ps1) performs only **additive**
  actions: for a **fresh** consumer it writes the seam — lens-only persona templates and an empty
  `VUL-IN` lens scaffold per enabled subagent into `.claude/specialists/lenses/` (never overwriting),
  `.claude/specialists/SPECIALISTS.md` carrying the body import, the lens import and the roster slot,
  and **one** `@`-import at the bottom of `CLAUDE.md` (or a scaffold if there is none). A consumer that
  already has a lens tree on the pre-seam path keeps it, and keeps its two imports — see
  [The seam, specified](#the-seam-specified). It also writes **two** settings proposals: the annotated
  `settings.suggested.jsonc` (both `permissions` halves + a hooks **stub**), which explains why each rule
  is there, and `settings.proposed.json` — the same rules already merged into a copy of the repo's own
  `settings.json`, as strict JSON, so adopting them is *replace one file with the other* rather than a
  hand-merge. It touches `settings.json` itself in neither case: the placement, and filling in the repo
  lens, are manual work afterwards (repo-specific), after which one more **restart** activates the new
  context.

  > **The agent defs and manuals still name the pre-seam path** (`.claude/plugins/<family>/<plugin>/…`)
  > when they tell a specialist where its lens lives. That is accurate rather than stale: both layouts
  > are read, and every consumer that adopted before this release still has its lenses exactly there.
  > Sweeping those 57 files is a documentation pass for the day the consumers have migrated, deliberately
  > not folded into the mechanism change.

## Removal: the teardown gap

> **Status: closed on July 30, 2026.** Every item of the target shape below carries its own *Settled on*
> marker, and [issue #221](https://github.com/DaveKJohn/claude-code-specialists/issues/221) is closed. The
> section is kept in full rather than trimmed to a verdict, because the **measurements** are the reason
> the design ended up the way it did — the 26 orphaned lens files, the import that actively broke, the
> 101 specialist mentions across 492 lines, the resolver that took the daily git workflow down with it.
> A future change that finds this shape inconvenient should have to argue with the numbers, not with a
> conclusion. What is *not* closed and deliberately so: delivering Chris from the plugin's own
> `settings.json` ([#215](https://github.com/DaveKJohn/claude-code-specialists/issues/215)) — the mechanism
> is verified and the switch is Dave's to throw.

**The requirement, set by Dave on July 29, 2026.** A consumer must be able to **install and uninstall
these plugins at any moment**, and after an uninstall it must be able to *stand fully free*: no
lingering reference to a specialist, a manual, a persona, or a roster anywhere in the repo. Adoption
is reversible by design, not a one-way door.

**Read as "no *live* reference" — the hand measurement forced that distinction, and it is the working
reading until Dave says otherwise.** Taken literally, "no reference anywhere in the repo" is both
unreachable and undesirable for any repo that ever adopted the plugin, because its own history records
the adoption: measured in `davekokbwj/smartwatchbanden` (July 29, 2026), `CHANGELOG.md` (3) and
`releases/development/*` (43) mention specialists, and every one of those is an accurate record of
something that happened. **History is finished business, not debt, and is never rewritten** — the same
reasoning that lets this family's archived release notes keep their original language. The requirement
therefore bites on what is *live*: nothing that a **session loads**, a **script resolves**, or a **gate
depends on** may still point at the plugin. That reading is what makes the goal testable, and it sorts
the leftovers below by how much they actually cost — a resolver that throws is a different order of
problem from a roster row nobody reads.

**The bootstrap path above has no counterpart.** `specialists-init` builds up; nothing tears down. It
was measured against the `life-hub` consumer on July 29, 2026 rather than estimated:

| what an uninstall leaves | measured |
|---|---|
| Agent defs, manuals, persona bodies, skills, shared scripts | **gone cleanly** — plugin-owned |
| The three `SessionStart` hooks (and, since #900, the `Stop` hook beside them) | **gone cleanly** — plugin-owned, via `${CLAUDE_PLUGIN_ROOT}` |
| Lens files under `.claude/plugins/` | **26 git-tracked files**, now referencing nothing |
| The two `@`-imports in `CLAUDE.md` | one **actively breaks** — it points into the marketplace cache |
| Specialist mentions in `CLAUDE.md` | **101**, across 492 lines |
| Scripts that exist only for specialists | e.g. `rename-specialist.ps1` |
| `scripts/repo-config.ps1`, `scripts/lib/branch-info.ps1` | the script contract, written for the shared scripts |

The half that is already right is worth stating plainly: **everything the plugin owns disappears
correctly.** Hooks included — they are registered by the plugin's own `hooks/hooks.json`, not in the
consumer's `settings.json`, so they leave with it. The gap is entirely on the consumer side.

**One row of that table needs qualifying, though, and it is the row that reads as reassuring.** The
shared scripts do vanish cleanly — but a consumer does not call them from nowhere. It calls them through
a resolver of its own that locates the marketplace cache, and that resolver **throws** once the cache is
gone. Measured in `davekokbwj/smartwatchbanden` (July 29, 2026): `scripts/lib/plugin-paths.ps1` is that
resolver and three operational scripts dot-source it — `start-task.ps1`, `open-pr.ps1`,
`fold-changelog-entry.ps1`. So "gone cleanly" describes the *plugin's* side of the boundary only; on the
consumer's side the same removal takes the daily git workflow down with it. This is not clutter a
teardown can classify away, it is a **hard runtime dependency**, created by adopting the shared-script
model in the first place — which is why it belongs in the target shape below rather than in the skill.

### Why "delete everything" is the wrong goal

Consumer-side content is not one thing but three, and only one of them is disposable:

1. **Plugin-owned, portable** — agent defs, manuals, personas, skills, hooks, shared scripts. Already
   correct: it lives in the plugin and vanishes on uninstall.
2. **Consumer-owned but plugin-shaped** — the lens files, the roster, the routing table, the chains.
   The *repo owner* wrote this about their *own* repo, but it is built entirely on plugin concepts.
   Valuable, and meaningless without the plugin.
3. **Consumer-owned and genuinely independent** — the branch taxonomy in `branch-info.ps1`, the
   changelog convention, "never directly on `main`". This survives an uninstall as a useful repo
   agreement — but it is currently *phrased* in specialist terms ("Derek opens the PR"), which turns a
   still-valid rule into a reference to a character that no longer exists.

So a teardown that deletes indiscriminately destroys governance and repo knowledge the owner authored,
which is worse than leaving clutter. **The actual defect is not that too much lives in the consumer —
it is that category 2 is *woven in* rather than *bolted on*.** 101 mentions spread through one file
cannot be removed cleanly; one import pointing at one directory can.

### What exists now: the `specialists-teardown` skill

**Built July 29, 2026** — the third item of the target shape below, and the half that could be built
and tested without restructuring anything first. [`specialists-teardown`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-teardown/SKILL.md)
is the bootstrap's mirror image: where `specialists-init` is strictly **additive** and never
overwrites, the teardown is strictly **subtractive** and never deletes what the owner wrote.

It classifies before it removes, along exactly the three categories below:

| category | what happens |
|---|---|
| generated and untouched (a lens still carrying its `VUL-IN` marker, an unfilled script scaffold, the `@`-imports, both settings proposals) | **removed** |
| authored by the owner (a filled-in lens) | **reported, never touched** |
| owned by the repo anyway (a real `repo-config.ps1`, a filled branch table) | **reported as yours to keep or drop** |

The `VUL-IN` marker is the test, because that is the exact contract the bootstrap writes those files
under — its absence means somebody edited the file, which makes the file theirs. It is a content test
rather than a timestamp or hash on purpose: a reformat or a merge does not make content authored.

**Dry run by default**; `-Apply` acts. Two things it deliberately refuses to do: it never edits
`.claude/settings.json` (disabling the plugin is the owner's act, and the bootstrap never wrote that
file either — the symmetry cuts both ways), and it never removes roster rows or repo prose from
`CLAUDE.md`. The only lines it touches there are the two `@`-imports, safe because an import naming a
persona body or an extension lens is knowably bootstrap-written — the same property that let
`check-roster-sync` stop counting them as roster rows (#227).

**Measured round-trip** (`scripts/tests/teardown.tests.ps1`): bootstrap a fixture → 24 items placed →
teardown removes 22 and keeps the 2 the owner filled in, with the owner's own `CLAUDE.md` prose intact.

**What it still cannot finish, and why that is the seam's problem rather than the skill's.** A repo that
authored lenses and roster sections is not blank afterwards: those are reported, not removed. As long as
specialist content is woven through `CLAUDE.md` instead of sitting behind one inclusion, no script can
finish the job without guessing where a roster row ends and the owner's prose begins.

### What the ideal shape looks like

- **Category 2 behind a single seam.** All specialist content reachable through one inclusion, so
  teardown is "remove one directory and one line" instead of editing 492 lines by hand. **Settled on
  July 29, 2026** — specified below, written by the bootstrap and matched by the teardown
  ([#253](https://github.com/DaveKJohn/claude-code-specialists/pull/253),
  [#254](https://github.com/DaveKJohn/claude-code-specialists/pull/254)), with this repo migrated onto it as
  the first consumer ([#255](https://github.com/DaveKJohn/claude-code-specialists/pull/255)). The paperwork
  lagged a day behind the machinery: 120 occurrences of the pre-seam path across 57 files were still
  telling every consumer the old location
  ([#261](https://github.com/DaveKJohn/claude-code-specialists/pull/261)), and `sync-roster` was still
  *writing* there ([#262](https://github.com/DaveKJohn/claude-code-specialists/pull/262)).
- **Category 3 written plugin-neutrally**, so it stays true after an uninstall instead of pointing at
  a departed persona. **Settled on July 30, 2026 — and the honest version of "settled" is worth stating,
  because the item as written could not be done at all.** The rewording is the *owner's* governance prose:
  a plugin that rewrote *"Derek opens the PR"* into *"changes go in via a branch and a PR"* on its way out
  would be doing exactly the damage the three-category classification exists to prevent. What a script can
  do is **find** them, and that is what the teardown now closes with — a **free-standing audit** listing
  every live reference by `file:line`, split into the three cases that have different answers: an **id**
  (a roster row — usually delete), a **name** (a still-valid rule phrased through a character — usually
  reword), and a **plugin-only contract function** (`Get-RosterPath`/`Get-RosterIgnoredIds` — delete the
  line, keep the file). The choice is per line, which is why it reports lines. A clean repo gets `[FREE]`,
  and a test asserts the closed loop: apply the reword the audit advises and the audit reaches `[FREE]`,
  so its findings are actionable rather than noise. Report-only, and it runs on a dry run too — a preview
  that cannot say what would still be left is not an inventory.
- **A `specialists-teardown` beside `specialists-init`.** Symmetric by construction: whatever the
  bootstrap puts down, the teardown can take away, because it is the same inventory. **Built on
  July 29, 2026** — see [the section above](#what-exists-now-the-specialists-teardown-skill).
- **Shared scripts that survive their own absence.** The operational scripts are plugin-owned on
  purpose (#81), but the consumer-side resolver that reaches them throws once the plugin is gone, so an
  uninstall breaks the repo's git workflow rather than merely leaving debris behind. Either the resolver
  degrades to a clear, actionable failure, or the consumer keeps local copies — and whichever it is
  should be a stated part of adoption, since no teardown can decide it afterwards. **Settled on
  July 29, 2026, in two steps.** The teardown first learned to *warn*: it reports every `.ps1` under
  `scripts/` that reaches into the cache, plus what depends on it, and removes none of them. Then it
  learned to *solve* it — `-VendorScripts` copies the shared payload into the consumer's own `scripts/`
  (structure preserved, never overwriting), so the workflow survives the uninstall. This repo is the
  proof the model works: its own `scripts/` copies are byte-identical to the plugin's, asserted on every
  test run.
- **Consumer gates that announce when they stop applying.** A consumer that lints its own lens files
  keeps that check after the teardown, and in the measured repo it *silently skips* the lens category
  once the directory is gone: green, and checking nothing. Right for a deliberate teardown, wrong for an
  accidental loss — a silent skip cannot tell an operator's removal from a bad merge or a wrong path. A
  skip that says it skipped costs one line and keeps the gate honest.

  **Settled on July 30, 2026, and the defect was sharper than this bullet described.** The gate did not
  skip the category quietly and print nothing; it printed a **verdict with no coverage**.
  `check-consumer-drift`'s persona section closed with *"Persona drift is INFORMATIONAL: 0 drifted."* —
  and against a repo with no lens files at all, that was the whole output of the section. *"0 drifted of
  0 compared"* and *"0 drifted of 4 compared"* were the same sentence. Not a false pass: a true
  statement that reads as a different, false one, which is harder to catch than silence.

  The fix is one shared, non-counting `Write-Coverage` helper in `scripts/lib/check-report-lib.ps1` —
  plugin-owned, so it travels — and a `[COVERAGE]` line closing **every** category in
  `check-plugin-integrity` (ten of them) and the persona section of `check-consumer-drift`. Coverage is
  context, never a finding: it moves no exit code and no signal count, because a legitimately empty
  category must not break its own gate. Applied to all ten deliberately — a partial rollout recreates
  exactly the asymmetry that caused this, and the lens category (the one a teardown removes) is counted
  separately from the scan total for the same reason.

  **What this cannot reach, stated plainly rather than implied.** A consumer's *own* lint — the script
  its `Get-LintScript` points at — is the repo owner's code. No plugin can make it honest; the helper is
  available to it, and adopting it is the owner's act. The measured repo's silent skip lives there, and
  it is listed here as the owner's item, not as one this family can close for them.
- **Lens files off the plugin path.** `.claude/plugins/claude-specialists/` looks like plugin
  property and is in fact git-tracked consumer content — which is exactly why it reads as orphaned
  debris after an uninstall. **Settled on July 29, 2026** as part of the seam: lenses live in
  `.claude/specialists/lenses/`, a path that says whose content it is.

**Order matters here.** Every further addition woven into a consumer's `CLAUDE.md` raises the cost of
the untangling, so the seam is worth settling before more content lands on that path — and
[issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215) is the same problem seen
from the other side, not merely a token saving: a plugin-delivered Chris removes the `@`-import, which
is the worst artifact in the table above.

### The seam, specified

The shape above, made concrete. **One file, one line** — a fresh consumer's whole specialist surface:

```text
<consumer>/
├── CLAUDE.md                          # ONE specialists line, nothing else
└── .claude/specialists/
    ├── SPECIALISTS.md                 # the inclusion: body import, lens import, roster slot
    └── lenses/
        ├── 01-01-extension.md
        ├── 05-05-extension.md
        └── <group>-<id>-extension.md  # one per specialist, flat: ids are unique family-wide
```

`CLAUDE.md` carries `@.claude/specialists/SPECIALISTS.md` and nothing more. Everything that used to be
woven through it — the two imports, the roster table, the routing, the chains — lives behind that line.

**Four verified facts this rests on, each of which would have sunk it:**

1. **Nested imports work.** *"Imported files can recursively import other files, with a maximum depth
   of four hops."* The seam spends two: `CLAUDE.md` → `SPECIALISTS.md` → body/lens. A lens may still
   import something of its own without hitting the ceiling.
2. **A path in backticks is not an import.** *"Import parsing skips Markdown code spans and fenced code
   blocks."* So documentation may name `` `@.claude/specialists/SPECIALISTS.md` `` freely, and only the
   bare line loads.
3. **The roster survives compaction.** *"Project-root CLAUDE.md survives compaction: after `/compact`,
   Claude re-reads it from disk and re-injects it."* An import is part of that file's expansion, so the
   roster comes back with it — unlike a `paths:`-scoped rule, which does not.
4. **It is not a token saving, and must not be sold as one.** *"Splitting into `@path` imports helps
   organization but doesn't reduce context, since imported files load at launch."* The seam buys
   **removability**, nothing else.

**What it changes about a teardown.** Today an authored lens survives while the import that loaded it is
removed, leaving an orphan — and the roster is 43 lines scattered across 6 sections that no script can
safely cut. After the seam there is exactly **one** orphan with a name: `SPECIALISTS.md`, holding the
roster the owner wrote, reported as *"no longer loaded by anything — move what you still want into
`CLAUDE.md`, or delete it."* An unbounded hand-editing job becomes one file and one decision.

The import line is still removed even when `SPECIALISTS.md` is authored, and that is deliberate: it is
the line that makes the content *live*, which is exactly what the requirement bites on.

**Existing consumers are not moved.** The bootstrap stays strictly additive — it never relocates a file
somebody else's repo owns — so:

| consumer state | the bootstrap writes | readers accept |
|---|---|---|
| **fresh** (no lens anywhere) | the seam | the seam **and** all three legacy layouts |
| **already adopted** (lenses in a legacy dir) | keeps using that dir, adds new lenses beside the existing ones | unchanged |

Readers change in exactly one place: `Get-LensDirCandidates` gains the seam as its most canonical
candidate, ahead of the three it already walks. Writers pick their target from whether a legacy tree
exists. **Migrating is the owner's act**, five steps, none of them automatic — and **step 0 is the one that can
cost you the tree**:

0. **Check your `.gitignore` first.** If it ignores `.claude/*` with an exception for the old path (e.g.
   `!.claude/plugins/`), add `!.claude/specialists/` and **commit that before moving anything**. Measured
   in `davekokbwj/smartwatchbanden` on July 30, 2026: its lenses are tracked *only* because of the
   pre-seam exception, so moving them to the seam would drop them out of version control **with nothing
   looking wrong** — every gate stays green (the readers accept the seam, which is the point) and
   `git status` is silent (they are ignored). Reversed order and the move lands untracked, so the commit
   that would have captured it has nothing to capture. An ignore rule written against a path is a bet
   that the path will not move; this is the moment that bet is called in.
1. `git mv .claude/plugins/<family>/<plugin>/*-extension.md .claude/specialists/lenses/`
2. Create `.claude/specialists/SPECIALISTS.md` and move the roster, routing table and chains into it.
3. Replace the two `@`-imports in `CLAUDE.md` with the single seam line.
4. Run the roster check and the lint gate, then restart the session.

**The one fragility the seam concentrates rather than removes.** The body import resolves into the
marketplace cache, which is *outside* the working directory, and for such an import Claude Code shows a
one-time approval dialog — *"If you decline, the imports stay disabled and the dialog doesn't appear
again."* That was already true of the two-line form. What changes is the blast radius: decline once and
the single line delivers nothing, silently and permanently, until you clear that decision. Worth knowing
before diagnosing "the specialists stopped loading" as a bug in this repo.

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
   [`check-plugin-integrity.ps1`](scripts/lint/check-plugin-integrity.ps1) holds both halves of that
   pairing, so getting this step wrong is caught before the PR merges rather than by a reader noticing
   the plugin sits somewhere its name does not claim.
3. **The marketplace entry** — register the plugin in
   [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) with a repo-relative
   `source`.
4. **The specialists** — `agents/<group>-<id>-agent.md` + `manuals/<group>-<id>-manual.md` per
   member, following the `<group>-<id>` convention (a globally unique `id`).
5. **The docs that enumerate the plugins** — this README (the plugin count, the
   [teams-and-workflows table](#teams-and-workflows--whats-the-difference), the [invocation list](#invocation),
   the manuals list under [Manuals](#manuals--the-split-model), and whether the team is mutually
   exclusive with the others or complementary) and [`INSTALL.md`](INSTALL.md), both
   halves.
6. **The gates** — `scripts/agents/build-agent-defs.ps1 -Check`,
   [`scripts/lint/check-plugin-integrity.ps1`](scripts/lint/check-plugin-integrity.ps1), and
   the `scripts/tests/*.tests.ps1` suites, all green.

**A new *product*, on the other hand, does not belong here at all** — it gets its own repository and
its own marketplace. See [One product, one repository](#one-product-one-repository).

## Contributing

Changes to this repo go through a branch + Pull Request to `main`, and that much holds whether or not
any plugin is installed — it is the **standard workflow**, three rules long, and since August 27, 2026 it
opens [`dkj-policy/CONTRIBUTING.md`](dkj-policy/CONTRIBUTING.md) rather than a page
of its own at the root. **The branch dossier, the changelog entry that folds at the merge, the significance
model and the release cut are the `dkj-policy` layer on top**, and they are described further
down that same page — this repo's answers — over
[`CONTRIBUTING-portable.md`](plugins/dkj-policy/CONTRIBUTING-portable.md), the half
that travels with the plugin. Where the two disagree, the plugin's page wins.

The governance is in [`CLAUDE.md`](CLAUDE.md): the safety rules, the three direct-on-`main` exceptions
and their bounds, and this repo's own gates. **The roster and the routing are not there** — they sit
behind the one seam line at its foot, in
[`.claude/specialists/SPECIALISTS.md`](.claude/specialists/SPECIALISTS.md) and the lenses beside it,
which is what [The seam, specified](#the-seam-specified) is for.

## Want to know more?

- **Connecting your own repo?** Follow
  [INSTALL.md](INSTALL.md#adoption--how-to-connect-your-repo) — connect in five steps, for those
  who didn't build the system, or its
  [quickstart half](INSTALL.md#quickstart--the-commands-and-nothing-else) if you only want the
  commands.
- **Disconnecting it again?** [UNINSTALL.md](UNINSTALL.md) is its mirror — the repo teardown and the
  machine-side removal, in the order they have to happen.
- **Releases** — the full version history is in [`releases/history.md`](dkj-policy/releases/history.md); the
  cutting-a-release mechanics travel with the workflow plugin as
  [`RELEASES-portable.md`](plugins/dkj-policy/RELEASES-portable.md), with this repo's
  answers to it in
  [`dkj-policy/releases/README.md`](dkj-policy/releases/README.md).
