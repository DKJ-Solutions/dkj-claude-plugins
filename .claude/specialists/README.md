# .claude/specialists

The home of the **Claude Specialists** system *as this repo consumes it itself*, plus the harness it
runs in. This document is both the floor plan of this directory and the **specialists handbook** —
Chris's reference work in case of doubt. It records three things: (1) the **layout** of `.claude/`
itself; (2) **how a specialist is structured** — as persona or subagent, the two-part split of every
manual, and the stable-id system; and (3) **how the specialists here are organized among
themselves**. It is **not a replacement** for the safety rules or the routing.

> **This repo is an outlier.** claude-code-specialists is the marketplace repo of one product; the
> specialists system lives here as the plugins under `plugins/` — a stack of teams plus an opt-in
> workflow (see [`../../README.md`](../../README.md)) — and the repo also consumes that system here
> **itself**. It enables **all six** of the marketplace's plugins, so that the repo that ships a
> plugin is also a repo that loads it (Dave, September 8, 2026; the reasoning and what it costs are in
> [the repo slot of `CLAUDE.md`](../../CLAUDE.md#specific-to-this-repo-claude-code-specialists)). Only
> `dkj-subagents-alpha` (the core team) and `dkj-policy` carry real work here, so the team is small and
> focused on maintaining this product (agent defs, manuals, docs, tooling), not the broad team of a
> content repo. The other four are enabled for validation — and they are validation of two different
> kinds: the three add-on teams ship specialists nothing here routes to, while `dkj-policy-bwj` ships
> no agents at all.

- The constitution remains [`../../CLAUDE.md#safety-rules`](../../CLAUDE.md#safety-rules).
- **Chris still takes in and routes every assignment** — see his fixed ritual in
  [`lenses/01-01-extension.md`](lenses/01-01-extension.md).

## Layout of this directory

This directory **is the seam** (issue #221): `../../CLAUDE.md` carries one line —
`@.claude/specialists/SPECIALISTS.md` — and everything specialist-shaped hangs off it. The point is
removability: a teardown is "one directory and one line", not an edit through hundreds of woven-in
lines. It buys nothing in tokens, and must not be sold that way — an imported file loads at launch
just like inline text.

- **`SPECIALISTS.md`** — the **inclusion**: Chris's body import, his lens import, and this repo's
  roster + routing. The single file `CLAUDE.md` names.
- **`lenses/`** — the **repo layer** of the specialists system: one file per specialist,
  `<group>-<id>-extension.md`, flat (ids are unique family-wide). There are two kinds:
  - **Subagent lens** — for every specialist that arrives as a subagent from an enabled team plugin
    (the core team's are in the [index below](#index-of-the-extensions-present); the add-on teams' are
    listed per plugin in [`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing)): only the
    `## Specific to this repo` part, which
    supplements the portable playbook in the plugin with the context of this repo. The subagent
    reads the plugin playbook + this lens together; the agent def points to both.
  - **Persona lens (lens-only)** — for the persona-only specialists (Chris, Bianca, Derek, Rendall), who run
    in the main conversation instead of as subagents. The main loop loads no plugin subagents, so the
    **portable body** comes straight from the plugin install via an `@` import: Chris always
    (`@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-subagents/dkj-subagents-alpha/personas/01-01-persona.md`,
    stated in [`SPECIALISTS.md`](SPECIALISTS.md) rather than in `CLAUDE.md` itself — the seam spends
    two of the four allowed import hops), Derek and Rendall on demand from that same path. **Bianca
    is the fourth persona and currently has no trigger**: her body would load the same way, but
    nothing in [Chris's lens](lenses/01-01-extension.md) routes an assignment to her, so in practice
    she is never read here. That is a statement of the present, not a defect to route around — this
    repo does no intake interviews. The day it does, she needs a routing row like Derek's and
    Rendall's, and until then the honest reading of the table below is "has a lens, has no caller".
    The
    extension itself is therefore **lens-only**: only the repo-specific `## Specific to this repo`
    part, no copy of the body — just like the subagent lens. That way every portable behavioral rule
    lives in one place (the plugin), not duplicated.
- **Subagent definitions — from this marketplace's own team plugins, not local.** The compact,
  executable form of a specialist (`<group>-<id>-agent.md`) is **not** kept by this repo in a local
  `.claude/agents/` directory: they come from the team plugins of this very marketplace, enabled via
  [`settings.json`](../settings.json) and invocable as `@<plugin>:<name>` —
  `@dkj-subagents-alpha:<name>` for the core team, and the same shape for each add-on team.
- **`settings.json`** — the harness config: `extraKnownMarketplaces` (the `github` source
  `DKJ-Solutions/claude-code-specialists` — the repo points to itself) + `enabledPlugins`, which holds
  **all six** of the marketplace's plugins rather than the core team alone — read the file for the
  list, since a spelling of it here is one plugin away from going stale.
  [Sylvester #15](lenses/05-15-extension.md)'s domain.

## How a specialist is structured

The general model — persona vs. subagent representations, the manual/agent-def split, the
portable-craft-vs-repo-lens split, and persona templates as a third artifact — is the plugin
family's concept and lives in one canonical place: the root README's
[Manuals — the split model](../../README.md#manuals--the-split-model).
This section records only how that plays out **concretely in this repo**.

### Persona or subagent — one specialist, two representations

Which specialists here are a subagent lens vs. a persona lens (lens-only), and where their files
live, is inventoried in [Layout of this directory](#layout-of-this-directory) above — not repeated
here. What follows are the rules that build on that split:

**Rules:** where a manual and an **agent def** both exist, the **manual is leading**; the agent def is
the executable abbreviation. The *principle* and the manuals belong to
[Tessa #16](lenses/06-16-extension.md); the agent-def config (frontmatter, tools, model) belongs to
[Sylvester #15](lenses/05-15-extension.md). **Chris remains a persona** — he is the only one who can
**ask** Dave anything. [Tessa #16](lenses/06-16-extension.md) guards the two-part manual split
(portable body vs. repo lens) on every change here.

**A persona may back a manual too, and that pairing is leading in neither direction**
([#1017](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1017), August 28, 2026). Until
that day the lint gate's check 6b required an agent def behind every manual, so the two sentences
above read together as *"the leading half is the manual, and Chris may not have one"* — and Chris,
uniquely, paid for it in tokens: he is loaded on **every** turn, so every rule the gate kept out of a
manual sat on the always-on path. Measured before the split, his persona was 25,674 B, about 35% of
that path; three sections came off it for **5,166 B**.

**What "leading" means for such a pair is different and narrower, and the root README states it** —
[Manuals — the split model](../../README.md#subagent-def-vs-manual--two-files-one-specialist) is this
model's one canonical home, as the section above says. In short: split by **when** each half is
needed, not by authority. What belongs here is only what it cost *this* repo. Chris's three moved
sections — the phase model, parallel delegation, the six inbound checks — are each unknowable at the
start of a turn, which is exactly why none of them was ever worth a session's context. Bianca, Derek
and Rendall have no manual and are untouched in both directions, so this changed one file's loading
and nothing else about how the four personas work here.

### Where a new rule goes — the source is the default, the lens is the exception

**This repo is the source of the specialists system, so a lesson learned here belongs in the shared
source unless it genuinely only applies here** (Dave, August 4, 2026). The lens exists for what a
*consumer* would have to differ on — not as the convenient place to write things down because it is the
file already open. Writing a portable rule into the lens is how the source ends up thinner than the repo
that maintains it: measured that day, Rendall #06's portable persona was **1,700 bytes** while his repo
lens had grown to **26,914** — sixteen times larger, holding the release craft itself rather than
anything specific to this repo.

**Which of the three layers a rule belongs in follows from what the layer already carries**, a
convention the repo has held consistently rather than one invented here. Re-measured **August 15,
2026** across `dkj-subagents-alpha`'s **15 manuals, 4 personas and 4 skills** — count each category with
`grep -rho` over `manuals/`, `personas/` and `skills/`, and the table reproduces:

| layer | holds | repo-specific detail (measured) |
|---|---|---|
| **persona / manual** | the craft itself, stated timelessly | **none** across all 19 files — 0 issue numbers, 0 repo names, 0 person names. The one `vX.Y.Z` a regex finds is Rendall's *"How he sounds"* line, an invented example of speech rather than a real version |
| **skill** | a procedure, with the evidence that shaped it | **yes** — **250** such references across the 4 skills (137 issue numbers, 93 repo names, 15 versions, 5 person names), e.g. a measured character limit attributed to the consumer repo it was hit in |
| **repo lens** | what this repo does differently, and the local measurement | yes |

**The previous figures are kept here as the thing that went wrong, because the failure is instructive**:
this table read *"14 manuals, 4 personas and 9 skills"* and *"103 references across the 9 skills"*, and
by August 15 none of the three counts held — a manual had been added, and the August 8 workflow split
had moved nine of `dkj-subagents-alpha`'s skills into `dkj-policy`, leaving four. **`CLAUDE.md` points at
this table as the evidence for the whole source-vs-lens doctrine**, so a reader who checked it found the
numbers wrong and had no way to tell whether the doctrine was wrong with them. The claim itself was
false too, by exactly two person names — both now moved to the lens that should have held them, which
is the convention this table describes, applied to itself.

**A measurement in a document that nothing regenerates goes stale silently.** State the date and the
method, as above, so the next reader can re-run it in one command instead of trusting it.

So the practical test for a lesson learned: **is it a timeless statement about the craft** → persona or
manual, stripped of every number. **Is it a procedure step someone will walk, whose reason rests on a
measurement** → the skill, measurement included; that is why the skills carry evidence and the manuals
do not. **Is it only true here** → the lens. When the same rule has both a portable half and a local
half, split it: the rule and its generic reason go to the source, and the lens keeps a short citation
naming where it was measured.

**A consequence worth knowing before you reach for the lens out of habit:** a rule written in the source
reaches every consumer through the next release, while the same rule in the lens reaches nobody but this
repo — and the two are indistinguishable while you are typing.

### Stable id + group — the filename is `<group>-<id>`

Every specialist has a fixed, numeric **`id`** (permanent identity, never changes) and belongs to a
**group** (organizational unit: **01 = Leadership, 02 = Staff, 03+ = teams**). The repo layer is
named `<group>-<id>-extension.md`; the portable playbook `<group>-<id>-manual.md` and the
agent def `<group>-<id>-agent.md` live in the plugin. **Name, emoji, and title are labels** — they
may change freely; the filename and link paths hang off `id`/`group`, not the name. **The lint gate
guards this** ([Sylvester #15](lenses/05-15-extension.md)): every filename matches the
frontmatter (`id:` and `group:`).

**So a rename never breaks a reference — it only leaves the name behind in prose**, and
[`scripts/sync/find-specialist-mentions.ps1`](../../scripts/sync/find-specialist-mentions.ps1) is the
tool for that half. Run it bare for the overview (which rename is cheap and which is not), or with
`-Name <specialist>` for every live mention grouped by the layer it sits in: **context** (read by a
model each session), **docs** (read by a human on GitHub), **scripts** and **tests** (where the one
rename this repo has done deliberately *kept* the old name as attribution), and **history** (counted,
never rewritten — the published-record rule). It also splits each layer into **link text** and
**prose**, because those are two different decisions: the link target already carries the id, so the
text beside it is reading aid, while a name in prose is the content itself.

**It is a tool, not a gate, and that was decided rather than defaulted into** (August 13, 2026). A
check matching on names is the shape this repo has already been bitten by — the name-matching
candidate measured for the entry-format check produced six findings, all six false. Worse, Sean →
Sebastian (`a437df9`, July 22, 2026) deliberately left mentions standing, so a gate would need an
exemption list holding exactly what that rename decided to keep. **A gate that is argued with is a
gate that gets switched off.** This one prints; the reader decides.

**The measurement that made it worth building:** a rename's cost is not uniform. Measured with the
script itself, against the tree as it stood before the branch that added it, Chris had **179** live
mentions across 59 files against Sebastian's **46** across 18 — a factor of four. Nothing before this
could tell you that number *before* you started.

**The same pass answered the question that prompted it**, which was whether the name in a link should
become the id (`[#16]`) or the filename (`[06-16-extension]`) so a rename would need no edit there.
Three measurements against that same tree said no:

| | |
|---|---|
| link text is a small share | **97 of 1,291** live mentions — 7.5%, so it reaches a fourteenth of the problem |
| `#16` is already taken | **2,404** `#nnn` references outside `releases/` and `CHANGELOG.md`; `#12` is both Gwen and a PR number |
| the filename form costs more | 88 link texts of the form `[Name #NN]` average **10.3** characters against 15 for `<gg>-<ii>-extension` — **+46%**, in files loaded every session |

And roughly a quarter of those link texts are grammatically part of the sentence
(`[Rendall #06](…)'s domain`, `[Tessa #16](…) guards the split`), where a bare id or filename reads as
a file doing a person's work.

## The team here

Small and maintenance-focused. Chris leads; the rest executes.

```
[group 01] Chris 🧭 #01  (Chief of Staff — orchestrator, persona)
│
├─ [group 03] Rebecca 🔬 #07  (research specialist)
├─ [group 04] Tycho 🧪 #18  (test engineer)
├─ [group 05] Derek 🐙 #05 (DevOps, persona) · Rendall 🎬 #06 (release, persona) · Sylvester ⚙️ #15 (system administration)
└─ [group 06] Tessa 📜 #16 (technical writer) · Edith 🔍 #17 (copy editor) · Victor 🧐 #19 (code reviewer) · Sebastian 🛡️ #23 (security engineer) · Ravi ♻️ #24 (refactoring specialist) · Nolan ⚡ #25 (performance engineer) · Marlowe 🕵️ #29 (investigative journalist)
```

**This tree is who has work here, not who is available.** Six more arrive with the **core team**
plugin, whose crafts this maintenance repo rarely calls on. Those six are in the index below with
their lenses — but they are not reachable the same way, and the difference is worth knowing before
you type a name:

- **Invocable today as subagents** — Paula 📅 #09, Vera 📊 #11, Gwen 🎨 #12, Cody 💻 #13 and
  Auden 🖋️ #30. Each ships an agent def, so `@dkj-subagents-alpha:<name>` reaches them.
- **Not invocable** — Bianca 🎙️ #02, who ships as a **persona** (`personas/03-02-persona.md`, no
  agent def). Personas run in the main conversation, and the only one loaded here is Chris; Derek and
  Rendall are read on demand when work reaches them. Nothing reaches Bianca — see the persona-lens
  note above.

## Index of the extensions present

The full roster + routing lives in [`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing) — the
seam's inclusion file, which `../../CLAUDE.md` imports; the list below is purely navigation to the
repo lenses themselves.

**Every specialist an enabled plugin ships has a lens file, without exception** — so `lenses/` holds
more files than this table has rows. **The table is the core team's roster**; the eleven that arrive
with the three add-on teams are listed per plugin in
[`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing) rather than repeated here. A lens marked
*scaffold* is an empty `VUL-IN` template waiting for that specialist's first work here — **the intended
state, not a backlog item**, exactly as
[`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing) states it.

| # | Specialist | Repo lens | Agent def |
|---|---|---|---|
| 01 | Chris 🧭 — Chief of Staff | [`lenses/01-01-extension.md`](lenses/01-01-extension.md) | — (persona-only) |
| 02 | Bianca 🎙️ — Biographer | [`lenses/03-02-extension.md`](lenses/03-02-extension.md) *(scaffold)* | — (persona-only) |
| 05 | Derek 🐙 — DevOps Engineer | [`lenses/05-05-extension.md`](lenses/05-05-extension.md) | — (persona-only) |
| 06 | Rendall 🎬 — Release Manager | [`lenses/05-06-extension.md`](lenses/05-06-extension.md) | — (persona-only) |
| 07 | Rebecca 🔬 — Research Specialist | [`lenses/03-07-extension.md`](lenses/03-07-extension.md) | `@dkj-subagents-alpha:rebecca` |
| 09 | Paula 📅 — Project Planner | [`lenses/02-09-extension.md`](lenses/02-09-extension.md) *(scaffold)* | `@dkj-subagents-alpha:paula` |
| 11 | Vera 📊 — Data Analyst | [`lenses/04-11-extension.md`](lenses/04-11-extension.md) *(scaffold)* | `@dkj-subagents-alpha:vera` |
| 12 | Gwen 🎨 — Graphic & Front-end Designer | [`lenses/04-12-extension.md`](lenses/04-12-extension.md) *(scaffold)* | `@dkj-subagents-alpha:gwen` |
| 13 | Cody 💻 — App Developer | [`lenses/04-13-extension.md`](lenses/04-13-extension.md) *(scaffold)* | `@dkj-subagents-alpha:cody` |
| 15 | Sylvester ⚙️ — System Administrator | [`lenses/05-15-extension.md`](lenses/05-15-extension.md) | `@dkj-subagents-alpha:sylvester` |
| 16 | Tessa 📜 — Technical Writer | [`lenses/06-16-extension.md`](lenses/06-16-extension.md) | `@dkj-subagents-alpha:tessa` |
| 17 | Edith 🔍 — Copy Editor | [`lenses/06-17-extension.md`](lenses/06-17-extension.md) | `@dkj-subagents-alpha:edith` |
| 18 | Tycho 🧪 — Test Engineer | [`lenses/04-18-extension.md`](lenses/04-18-extension.md) | `@dkj-subagents-alpha:tycho` |
| 19 | Victor 🧐 — Code Reviewer | [`lenses/06-19-extension.md`](lenses/06-19-extension.md) | `@dkj-subagents-alpha:victor` |
| 23 | Sebastian 🛡️ — Security Engineer | [`lenses/06-23-extension.md`](lenses/06-23-extension.md) | `@dkj-subagents-alpha:sebastian` |
| 24 | Ravi ♻️ — Refactoring Specialist | [`lenses/06-24-extension.md`](lenses/06-24-extension.md) | `@dkj-subagents-alpha:ravi` |
| 25 | Nolan ⚡ — Performance Engineer | [`lenses/06-25-extension.md`](lenses/06-25-extension.md) | `@dkj-subagents-alpha:nolan` |
| 29 | Marlowe 🕵️ — Investigative Journalist | [`lenses/06-29-extension.md`](lenses/06-29-extension.md) | `@dkj-subagents-alpha:marlowe` |
| 30 | Auden 🖋️ — Academic & Long-form Writer | [`lenses/06-30-extension.md`](lenses/06-30-extension.md) *(scaffold)* | `@dkj-subagents-alpha:auden` |

The six scaffolds mark specialists who rarely have work in this maintenance repo — Bianca's intake
interviews, Paula's timelines, Vera's dashboards, Gwen's visuals, Cody's application code, Auden's
long-form writing. On the day one of them first has work here,
[Tessa #16](lenses/06-16-extension.md) fills the lens in before that specialist is deployed.
**The three add-on teams — `dkj-subagents-ecomm`, `dkj-subagents-lifehub` and `dkj-subagents-shopify` — are on here,
and their eleven lenses are empty for a different reason: they will stay empty.** The six
scaffolds above are waiting; those eleven are not. Those plugins are enabled so that the repo that
ships a plugin is also a repo that loads it — validation, not a roster — and this repo is not a
webshop, a Shopify store or a personal-life repo, so [Chris does not route to
them](lenses/01-01-extension.md#the-roster--routing-table--which-assignment-goes-to-whom) at all. **Do
not treat those eleven as a backlog**: a filled-in lens for one of them would describe work this repo
does not have. Same reasoning, in
[`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing) and [the repo slot of
`CLAUDE.md`](../../CLAUDE.md#specific-to-this-repo-claude-code-specialists).

## This organization changes with the team

The team and its organization come about **in consultation with Dave** and may change — exactly as
new specialists only come about by agreement (see
[Chris #01](lenses/01-01-extension.md#new-specialists--only-by-agreement)). If the organization
changes, Tessa updates this document.

## Measured instances kept off the always-on path

**Everything below is evidence, and that is why it is here.** The always-on document path —
`CLAUDE.md` and everything it `@`-imports — is read by every session before a single assignment is
given, so the rule a measurement supports belongs there and the measurement itself does not. This
handbook is loaded on demand, which makes it the destination. Each entry names the rule it stands
behind, so the two can be read together when that is what a session actually needs.

**Add to this section rather than to a lens when a measurement outgrows the sentence it justifies**,
and measure before and after with
`scripts/maintenance/measure-always-on.ps1` — the point is the path getting smaller, not the prose
moving.

### The three ways a briefing fails, measured here

Behind *"Verify the stand against the repo, not against a handover text"* in
[Chris's lens](lenses/01-01-extension.md#the-dave-rules). Three modes, three instances, none of which
the mode above it would have caught.

**Truncated — July 29, 2026.** Dave's self-verifying start prompt arrived **three times, identically
truncated** at the same character: it broke off mid-word inside open point 2 and resumed at the tail
of a bullet whose subject was gone, taking one pitfall with it entirely, the opening of another, and —
unknowably — any open points numbered after 2. Asking again did not help; the channel would not carry
it. The visible points looked complete, which is exactly the danger.

**Stale — the same day, and again on August 4, 2026.** A briefing's *expectations* go stale as well as
its facts: that July 29 prompt kept predicting the one `[INFO]` that
[#257](https://github.com/DKJ-Solutions/claude-code-specialists/pull/257) had already removed. On August 4
a briefing *and* a memory note *and* every local command agreed the tree was clean while a
fully-planned parked branch sat on the remote, overtaken hours earlier by work merged from a different
branch — which is what put `git ls-remote --heads origin` in the checklist. Note which sources were
wrong there: not a truncated channel this time, but two of Chris's own artefacts. That is the argument
for reading the repo rather than for reading a *better* summary.

**Transcribed — August 19, 2026.** A briefing that is complete, current, and states a **cause that does
not exist**: a lock six minutes old, correct about its subject (inbound
[#747](https://github.com/DKJ-Solutions/claude-code-specialists/issues/747)) and wrong about the mechanism,
while the report it summarised had named the right line. Neither truncation nor staleness but
*transcription*, and it survived every check in force at the time. Its rule lived in the `/handover`
skill until that skill was removed
([#957](https://github.com/DKJ-Solutions/claude-code-specialists/issues/957), Dave); the mode is a property
of summaries rather than of any one command, so a recap Dave types, a `/loop` prompt, a branch
document's PLAN section and a post-compaction summary are all the same artefact from this rule's point
of view. What was repo-specific about it is that the report and the pickup were the same team an hour
apart — the same shape as the fifth inbound pattern in the `triage-inbound` skill, and the same
argument for recounting even when the report is your own.

**The portable half of this rule reaches no consumer.** It travelled in the payload of the skill that
was removed, and this handbook does not travel. That is a gap recorded here rather than pretended away.

### Why `Get-RosterIgnoredIds` is empty

Behind *"Adopting a specialist that arrives with a plugin update is the default and needs no
approval"* in [`SPECIALISTS.md`](SPECIALISTS.md#the-team-roster--routing).

Five of the six specialists who rarely have work here were left off the roster and registered in
`Get-RosterIgnoredIds` instead (Bianca joined them briefly on July 28, 2026). That list turned out
never to have been a decision: it was introduced by the same commit that built the roster check,
pre-populated to keep that new check quiet, and justified in the code as *"a documented choice in
`CLAUDE.md`"* while `SPECIALISTS.md` only ever said those specialists had no lens **yet**. Dave, asked
about it on July 28, 2026, did not recognise the list as his — so the six were adopted and the list is
empty.

The shape is worth keeping separately from the outcome: a check was made quiet by a list, and the list
then cited a document that did not say what it was cited for. Neither half is visible from the other,
which is why the entry survived until somebody asked whose decision it was.

### The branch check fires on the follow-up assignment

Behind *"The check runs at the start of every assignment, not every session"* in
[Chris's lens](lenses/01-01-extension.md#the-gatekeepers-as-implemented-here).

Measured August 10, 2026. `ship-pr.ps1` switches to `main` in order to fold, so a successful chain ends
with the session on the trunk and the tree clean. Dave caught it after **seven** files had been edited
there; nothing was committed, so a `git checkout -b` carried the work across intact and the cost was
zero.

**The shape is what makes it recur.** It fires on a *follow-up* assignment inside one conversation —
*"do the next thing"* — where no new session and no fresh intake prompts the ritual, and it is the
**previous chain's success** that put you in the wrong place. A check tied to session start would
therefore never catch it, which is why the rule is worded against the assignment instead.
