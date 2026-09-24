# Adoption — connecting your repo to the specialists

**This page is the work that is yours no matter how the plugins reached you.** Installing them is a
separate matter and may already have been done for you: if your organisation publishes this family
through a marketplace of its own, the registration and the install happened once, centrally, and you
should not repeat them. If you came here to install it yourself, that half is
[Installing it yourself](#installing-it-yourself) below, and you do it first.

What is on *this* page is the same in both cases. The plugins give you a team; connecting it to your
repo — the bootstrap, the roster, the lenses — is what turns that team into one that knows where it
is. **An unfilled lens does nothing.** That sentence is the reason this page exists as its own
document rather than as the back half of an install manual.

**Why the procedure is what it is** — which step was added when, and what was measured to justify it —
is not on this page. It lives in the release record:
[`releases/history.md`](../dkj-policy/releases/history.md) indexes every version with the changes
behind it. This page tells you what to do; that one tells you why it changed.

> **Budget most of the time for the last step.** The bootstrap places the whole seam in seconds and the
> adopt skills of step 3 are minutes. Step 4 — writing your roster and filling your lenses — is writing,
> and on a repo of ordinary size it is closer to half a day than to a command. That is not a warning
> about this page being slow; it is where the value is.

## Before you begin

Three things have to be true, and only the first one might not be:

1. **The plugins are installed *and* enabled for this repo — two acts, not one.** If you install
   them yourself, that is [Installing it yourself](#installing-it-yourself). If they arrived through your organisation, this
   is already done — the specialists appear in your session as `@dkj-subagents-alpha:<name>` subagents.
2. **You have restarted the session since that happened.** A skill that ships inside a plugin only
   becomes available once the session has loaded the plugin.
3. **`specialists-init` is in your slash list.** That is the check for both of the above at once: if it
   is not there, nothing below will work and the problem is upstream of this page.

> **Read point 1 as two acts, because the half that can be missing leaves no trace** (inbound
> [#1076](https://github.com/DaveKJohn/claude-code-specialists/issues/1076)). *Enabled* is a key in
> **your** `.claude/settings.json`; *installed* is a record on the **machine**, in
> `~/.claude/plugins/installed_plugins.json`, keyed by this repo's path. Set the key and skip the
> install, and every surface a person can see says the adoption is done while the session has no
> skills, no subagents and no hooks — measured on a repo that ran that way for a full working day.
>
> **Point 3 is the check, and it is deliberately the slash list rather than anything the session says
> about itself.** Several skills in this family ship with `disable-model-invocation: true` — their page
> is kept out of the model's context on purpose, and the slash command still works — so a healthy
> session's own skill listing is *shorter* than what the plugins ship, and a number read off it proves
> nothing. If `/specialists-init` is missing, the install record is the first thing to check; the
> plugin-free query for it is act 6 of [Installing it yourself](#installing-it-yourself).
>
> **Nothing will raise this for you, and that is structural.** The four checks in this family that
> report *"enabled here but not installed for this path"* all ship **inside** the plugin that is not
> installed, so the one repo they were written for is the one repo they cannot speak in. A quiet
> session start is not an all-clear here.

## Installing it yourself

**Skip this section if the plugins arrived through your organisation.** Every command here names the
**public** source `DKJ-Solutions/dkj-claude-plugins`; running them against an organisation's own channel
does not fail loudly, it quietly adds a second channel pointing somewhere else.

**1. Write your repo's own `.claude/settings.json`** (create `.claude/` beside your `README.md` if it is
not there). Strict JSON; if you already have one, merge these two keys into it. `dkj-subagents-alpha` is
the only plugin you need — add a line per add-on team you want, and `dkj-policy` only if you deliberately
want that workflow.

```json
{
  "extraKnownMarketplaces": {
    "dkj-claude-plugins": {
      "source": { "source": "github", "repo": "DKJ-Solutions/dkj-claude-plugins" }
    }
  },
  "enabledPlugins": {
    "dkj-subagents-alpha@dkj-claude-plugins": true
  }
}
```

**2. Restart your Claude Code session.** A session start is what registers the marketplace; without it
the next command fails with `Marketplace … not found`.

**3–4. Refresh, then install — from your repo's root, one install per plugin you enabled.**

```powershell
claude plugin marketplace update dkj-claude-plugins                             # never skip: install does not refresh
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project    # once per plugin
```

`--scope project` is not optional — without it the install goes machine-wide and writes no
`projectPath`, with no error.

**5. Restart your Claude Code session again.**

**6. Verify — from your repo's root.** This query needs no plugin, which is why it is the check:

```powershell
$root = (Get-Location).Path
(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |
  ForEach-Object { $n = $_.Name; $_.Value | Where-Object { $_.projectPath -eq $root } |
    ForEach-Object {
      $payload = if ($_.installPath -and (Test-Path -LiteralPath $_.installPath)) { 'payload present' } else { 'PAYLOAD MISSING' }
      "$n -> $($_.scope) $($_.version) $($_.gitCommitSha) [$payload]" } }
```

**One** `project` line per plugin, ending in `payload present`. Then `/specialists-init` must be in your
slash list, and the four steps below start.

**Staying up to date** afterwards is the `update-plugins` skill (with `dkj-policy` enabled), or by hand:

```powershell
claude plugin marketplace update dkj-claude-plugins
claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project
```

### Why six acts, and the measurements behind each

**Step 0 above is six acts in order, and here is why there are six rather than a shorter guess** (inbound
[#297](https://github.com/DaveKJohn/claude-code-specialists/issues/297)). This procedure used to be
described at three entry points with three different counts — *four acts* on this page, *three acts* in
[`specialists-init`](dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md#chicken-and-egg--step-0-is-done-by-the-user)
and *three steps* in an earlier version of this page — the same path, no step missing anywhere, three
different numbers. A reader following it for the first time has the count as their only check on whether
they skipped something, and three counts remove exactly that. Two of the three were also counting
different things: an early revision raised the count from three to four by making the refresh an act,
while `specialists-init`'s step 0 has that refresh too and still said three. The unit is now **acts** —
individual things you do — everywhere it is counted; verifying counts as an act because leaving it out is
the failure the next paragraph calls silent and self-camouflaging: a reader who ticks off five and stops
has never checked that the install exists.

**The step count moved from three to four on August 3, 2026** (inbound
[#408](https://github.com/DaveKJohn/claude-code-specialists/issues/408)). Filling the lenses was always
part of the procedure and was disclosed in a trailing clause reading *"at your own pace"*, which reads as
optional polish on a page that had already announced three steps — while it is in fact the largest step
and the one where the system starts being useful. This page was renamed `QUICKSTART.md` → `ADOPTION.md`
in the same change, for the matching reason: the label promised a size the content never had.

**And it moved from three to four again on August 20, 2026** (inbound
[#784](https://github.com/DaveKJohn/claude-code-specialists/issues/784)) — running each enabled
plugin's `adopt-*` skill became a step of its own, because a consumer cannot infer a skill's
existence from a plugin's presence and was meeting the rest of their adoption one session-check
`[ERROR]` at a time. That is Step 3 below.

**It was five until August 1, 2026**, when #329 made the first restart an act of its own, on every page
describing this path at once. Folding it into act 1 would have kept the number at five, and folding it
into another act is exactly what had kept it unwritten while it was already required.

> **And if you sweep for these counts, make the sweep emphasis-tolerant** (inbound
> [#305](https://github.com/DaveKJohn/claude-code-specialists/issues/305)). A naive sweep shaped
> `(one|two|…|seven) (acts?|steps?)` **misses markdown emphasis**: against `specialists-init/SKILL.md` it
> found nothing, because the text there reads `**five** steps` — the asterisks sit between the two words.
> Written `(…)\*{0,2} \*{0,2}(acts?|steps?)` it surfaces that line, and others a naive sweep would miss
> entirely. Two lessons worth keeping if count-linting is ever built: a sweep that returns few hits is not
> evidence of few instances, and a file a given PR touched is not automatically covered by that PR's
> verification.

> **The marketplace is a cached clone, which is why the refresh is an act and not a formality**
> (inbound [#282](https://github.com/DaveKJohn/claude-code-specialists/issues/282) for the behaviour,
> [#284](https://github.com/DaveKJohn/claude-code-specialists/issues/284) for an earlier version of this
> page having omitted it). `plugin install` compares against the consumer's cached copy of the
> marketplace, not against the source repo: minutes after `v3.0.2` was tagged and pushed, a fresh
> project-scoped **install** produced `3.0.1` and reported `✔ Successfully installed`. Nothing in that
> output hints the version is stale. And the correct version of this block in `specialists-init`'s own
> step 0b cannot cover for an omission on this page, for the same reason this page exists at all: that
> skill does not exist until the install has happened.

> **The install is not a formality, and leaving it out fails silently** (inbound
> [#274](https://github.com/DaveKJohn/claude-code-specialists/issues/274), measured in a consumer during
> the 3.0.0 adoption round). An install is **project-scoped** — `installed_plugins.json` keys every
> record by `projectPath` — so the two settings keys plus a restart give you no *working* install and
> no error. What the reader gets instead is a session with neither the skill nor the session-start
> hooks, which is indistinguishable from a healthy one: "no hooks because the plugin is not loaded" and
> "no hooks because all is well" print the same nothing.

> **They do not, however, produce *nothing* — and that is the sharper trap** (inbound
> [#327](https://github.com/DaveKJohn/claude-code-specialists/issues/327),
> [#355](https://github.com/DaveKJohn/claude-code-specialists/issues/355)). Measured on a virgin
> profile with the marketplace registered and the cache present, a **single session start** wrote a
> full project-scoped record, with the correct `projectPath`, `version` and `gitCommitSha`, while that
> same session loaded nothing at all: the record is written *after* the load phase, so only the next
> session gets the plugin. Measured again after three session starts, its `installPath` named a
> directory that **did not exist**. So a record is a claim, not evidence — run the install, and verify
> by the **surface** (is the bootstrap skill in your slash list, did the session hooks print, does
> Chris open the turn) rather than by the administration.
>
> **`--scope project` carries that same weight, and the later update is the same pair of commands:**
> `claude plugin marketplace update <marketplace>` and then
> **`claude plugin update <plugin>@<marketplace> --scope project`** (inbound
> [#279](https://github.com/DaveKJohn/claude-code-specialists/issues/279), the 3.0.1 round; the refresh
> half is inbound [#282](https://github.com/DaveKJohn/claude-code-specialists/issues/282)). All of them
> default to `--scope user`; the install then writes a machine-wide record with no `projectPath`, and
> the update refuses outright on a project-scoped install. Project scope is the intended model for
> this family (Dave, July 30, 2026) — it gives each repo **its own install record**, and every other
> document here assumes it.
>
> **What project scope does *not* promise is that the record stays put** (inbound
> [#296](https://github.com/DaveKJohn/claude-code-specialists/issues/296)). A record described as
> *"pinned to the version it was tested against"* did not survive being measured. On July 31, 2026 both
> of `life-hub`'s project-scoped records moved `3.0.4 → 3.0.5` in a **single** write to
> `installed_plugins.json`, their `lastUpdated` stamps 70 ms apart — while that repo's own session issued
> no `claude plugin` command at all. Checked afterwards against every session transcript on the machine
> for that day: **26** `claude plugin` invocations, and not one in the window the write falls in. So
> something other than an explicit command can advance a project-scoped record, and "pinned" was a
> property of the bookkeeping rather than of the repo. (What the same measurement *did* explain: the
> marketplace clone moving minutes earlier was a deliberate `marketplace update` from another session on
> the machine — that half is not mysterious.)
>
> Practically: project scope is still the right model and still what every document here assumes —
> what changes is that you should **read your record rather than trust it**. On a machine with several
> consumers and several sessions, `installed_plugins.json` is the only place your actual version is
> written down; the install output does not name a version at all.
>
> **Verify with the `projectPath` record, not with `claude plugin list`** — that command is not
> repo-scoped and has reported a plugin as `enabled`, at `project` scope, in a repo that held no install
> record of its own and loaded nothing. The exact query is the one in
> [Installing it yourself](#installing-it-yourself) above, act 6. This documentation
> path is the only thing a new consumer has, because until the plugin loads, the skill that would
> say otherwise does not exist.

> **And one thing no document mentioned until this one:** every file `specialists-init` writes uses
> **LF** line endings and `CLAUDE.md` gets **no trailing newline**, on Windows too. Harmless while
> nothing is committed, but on a repo whose files are CRLF this is the same class of lasting diff
> `claude plugin install` can leave behind — and the missing final newline turns any later hand-edit of
> `CLAUDE.md` into a two-line diff. If your repo cares, normalise once after the bootstrap.

## Consumption

A consuming repo adds this marketplace via `extraKnownMarketplaces` in `.claude/settings.json` and
enables the desired plugins via `enabledPlugins` — and then, because an install is **project-scoped**,
runs `claude plugin marketplace update <marketplace>` followed by
`claude plugin install <plugin>@<marketplace> --scope project` from that repo's root for each of
them, exactly as [Installing it yourself](#installing-it-yourself) above walks through: the settings
keys alone leave you without a working install, without the flag the command
defaults to a machine-wide `user` install instead, and without the refresh it can serve an *older*
version and still report success.

**Seeing which release you're on — `plugin.json`.** Each plugin folder carries a `.claude-plugin/plugin.json`
whose `version` is the release it belongs to, bumped in lockstep across every plugin — see
[Versioning](dkj-policy/README.md#versioning) for the lockstep mechanics. Because
`claude plugin update` pins the cache to a specific version, the
cached `version` is *exactly* the installed release. The full history of that release lives in the source
repo's `CHANGELOG.md` and `dkj-policy/releases/` — and a consumer has both, because
the marketplace source is a git clone of the whole repository at
`~/.claude/plugins/marketplaces/<marketplace>/`, not a per-plugin extract.

That last fact is why the per-plugin `CHANGELOG.md` and `RELEASE.md` card were **retired on August 8,
2026**. They existed to give a reader a history inside the plugin cache; measured, the reader already
had the real one, and the 11,684 lines across those ten files were a second copy free to disagree with
it. One repository, one product, one changelog.

**One canonical channel — mind the old repo names.** The marketplace is named `dkj-claude-plugins`
(repo `DKJ-Solutions/dkj-claude-plugins`) and that is the only channel **for a reader who registers it
themselves**; use that name in `extraKnownMarketplaces`. If this copy reached you through an
organisation's own marketplace, that channel is the canonical one for you and this paragraph is about
the public source it was mirrored from — do not register a second one alongside it. The source repo has
been renamed twice and transferred to a new owner once, and every old name and the old owner keep
pointing at the same repo via **GitHub redirects** — the full detail, including the one condition that
must hold for those redirects to keep working (nothing may ever be created at the old paths), is in that
repo's own [`this-repo.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/.claude/rules/this-repo.md#repo-citation--one-owner-name).
**There is no second source to mirror to.** However, the local marketplace clone of an old registration
can lag behind (it was once cloned at an older commit and doesn't converge to the new `HEAD` on its
own), so an install on that channel silently yields an older plugin version. If you run into this:
update the marketplace registration (a marketplace update) or re-add it under `dkj-claude-plugins` — a
fresh install should always use `DKJ-Solutions/dkj-claude-plugins`.

## Which release am I on?

Read the `version` in your cached `<plugin>/.claude-plugin/plugin.json`. It travels with the plugin
cache, so once `claude plugin update` has pinned your install to a version, that number is exactly the
release you are on. Every plugin bumps in lockstep, so any one of them answers the question.

For **what changed** in that release, read the source repo's `CHANGELOG.md` and `dkj-policy/releases/`
in the marketplace clone you already have — `~/.claude/plugins/marketplaces/dkj-claude-plugins/`. See
[Consumption](#consumption) above for the mechanics.

A newly added **skill** additionally needs a session restart before it becomes visible, and the
skill counters `/reload-plugins`/`/reload-skills` print are not reliable evidence either way — see
[Versioning](dkj-policy/README.md#versioning).

## Invocation

Once enabled, the specialists can be invoked with the **plugin name as namespace**:
`@dkj-subagents-alpha:<name>`, `@dkj-subagents-lifehub:<name>`, `@dkj-subagents-shopify:<name>`, or `@dkj-subagents-ecomm:<name>`.

## Where this runs: Chat, Cowork, and Claude Code

Anthropic's Claude product has three relevant surfaces: **Chat** (a conversation), **Cowork** (a
working-session mode — desktop generally available, web/mobile in beta as of July 2026 — for
non-code knowledge work, positioned alongside Claude Code, which stays the tool for software
engineering), and **Claude Code** itself. See
[claude.com/product/cowork](https://claude.com/product/cowork) for Cowork's own positioning. This
matters operationally: a **skill**
bundled in a plugin works across all three surfaces, but a **subagent** or a **hook** runs only in
Cowork and in Claude Code — in a plain Claude.ai Chat session they show up grayed out (see
[Use plugins in Claude](https://support.claude.com/en/articles/13837440-use-plugins-in-claude)).
Concretely for this family: the specialists roster (the subagents under Chris), the
SessionStart hooks the enabled plugins ship (read them in each plugin's `hooks/hooks.json` — a
hand-written list here was named as three and went stale twice inside two days) and the Stop hooks
`cycle-autopark` and `closeout-gate`
function in Claude Code and in Cowork, but not in a plain Claude.ai Chat session — only the skills
(`fold-changelog`, `open-pr`, `ship-pr`, `new-branch`, `claim-issue`, `sweep-issues`, `park`, `fix-mojibake`,
`specialists-init`, `specialists-teardown`, `sync-roster`, `start-task`, `adopt-shopify-floor`,
`cut-release`, `adopt-dkj-policy`,
`release-notes-page`, `sync-main`, `push-preview`, `archive-theme`, `theme-lifecycle`, `live-preflight`,
`check-branch-entry`, `check-policy-drift`,
`prune-merged`, `tidy-machine`, `plugin-versions`, `update-plugins`, `check-fanout`,
`measure-skill`, `measure-closeouts`, `worktree-lane`, `report-issue`, `adopt-dkj-policy-bwj`, `publish-page`,
`build-backlog-page`, `golive-block`,
`orchestrator`) remain available there.

**`orchestrator` is on that list for a reason worth reading twice.** Everything else there is a
convenience that survives; that one is the *conductor*. Where the roster and the hooks fall away, it is
what puts Chris back in the conversation — so the layer this section shows as unavailable has a route in
through the one column that is.

Skills themselves are Anthropic's general **Agent Skills** mechanism — organized folders of
instructions/scripts/resources that an agent discovers and loads progressively (name + description
always loaded, the `SKILL.md` body only on trigger, other resources on demand) — exactly what
this family already uses to distribute its skills via the marketplace (see the
[Anthropic engineering post](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
and the [docs](https://code.claude.com/docs/en/skills)). Not confirmed: whether Cowork runs on the
Claude Agent SDK, or whether a Cowork subagent shares its definition format with — or is
interchangeable with — a Claude Code subagent.

## Which half needs a repository — the Claude App map

The section above answers *which mechanisms* a surface supports. This one answers the question that
turned out to matter more: **which of this family's contents can do their job when there is no repository
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
`publish-to-business.ps1` overwrites a business marketplace repo from the source on every run; since
[#683](https://github.com/DaveKJohn/claude-code-specialists/issues/683) it publishes the subset
`Get-BusinessMarketplacePlugins` names — the four teams — and rebuilds the
manifest to match. The workflow is not offered there because it is not there. No per-entry hide flag was
invented: the manifest format has none, and one would need Claude to honour it, while a plugin that did
not travel cannot be offered by anything.

**The marketplace keeps its name.** `dkj-claude-plugins` is the key in every consumer's
`enabledPlugins` (`dkj-subagents-alpha@dkj-claude-plugins`), so the filtered marketplace is the *same*
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

## What this gives you

Instead of one generic Claude, you work with a **team of specialized Claudes under one Chief of
Staff (Chris)**: every assignment is classified and delivered to the specialist with the right
playbook — a DevOps engineer for branches and PRs, a technical writer for docs, a copy editor
and code/security reviewers for the independent final pass before a PR or merge. Your repo stays in
charge: the governance (your `CLAUDE.md`, your safety rules) remains yours; the plugins only supply
the team and its playbooks.

The system consists of **teams and a workflow**: the repo-neutral core team `dkj-subagents-alpha` (always
enable it), three optional add-on teams, and exactly one **way-of-working** plugin, chosen from the two
the marketplace offers. Which specialists live in which plugin and who they are meant for is covered in
[`dkj-subagents/README.md`](dkj-subagents/README.md).

**The workflow slot is different in kind, so decide about it deliberately rather than by habit — and
"decide" now means deciding whether to fill it at all.** One plugin answers "how does work move through
this repo": `dkj-policy`, which carries no specialists at all but is DaveKJohn's own branch,
changelog and release method as skills plus scripts (`new-branch`, `open-pr`, `ship-pr`,
`fold-changelog`, `cut-release`, `park`, `fix-mojibake` among others). **Leaving the slot empty is what
this page's default settings block does, and it is a complete answer** — your repo keeps the way of
working it already had. Two consequences worth knowing before you enable the one that exists:

- **Enabling it later is a plain enable + re-run of `specialists-init`**, which then adds the config it
  needs. Nothing has to be undone — and that sentence is finally true rather than merely short. It said
  the same thing until August 20, 2026 while it was **false**, because a second workflow then had to be
  set to `false` in the same edit or `dkj-subagents-alpha`'s `workflow-sessioncheck` hook reported
  `[ERROR] 2 workflows are enabled at once` at the *next* session start — one step after the commit that
  switched, so the wrong state got committed, pushed and reviewed first (inbound
  [#785](https://github.com/DaveKJohn/claude-code-specialists/issues/785)). Both the second plugin and
  that hook were removed on August 26, 2026
  ([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)), so there is nothing left to
  turn off and nothing left to warn you.
- **Enabling it makes your repo owe it two files** — `scripts/repo-config.ps1` (repo name, lint gate)
  and `scripts/lib/branch-info.ps1` (your branch-prefix table). `specialists-init` scaffolds both, and a
  session check tells you if a function is missing; **answering them is step 3**, below. Enable no
  workflow and you are asked for neither.

> **If your `.claude/settings.json` still names `workflow-default`, remove that line.** It was the
> plugin that used to hold this slot by default. The id resolves to nothing at your next
> `claude plugin marketplace update`, and nothing warns you — the hook that would have had an opinion
> about your workflow keys is the one that went with it.


## The four steps

**Step 1 — run the bootstrap skill.** In the new session, invoke `specialists-init`. It sets up —
purely additively, without overwriting anything — the **lens-only** persona lenses (including
Chris) + an empty repo-lens scaffold per specialist in **the seam**
(`.claude/specialists/lenses/`), one `@`-import at the bottom of your `CLAUDE.md` pointing at that
seam (which in turn imports Chris's portable body from the plugin install + his repo lens), and
two proposals for safety settings, for your own review: `settings.suggested.jsonc` (annotated — why
each rule is there) and `settings.proposed.json` (the same rules already merged into your
`settings.json`, so adopting them is one replacement rather than a hand-merge). The details of this
path — why it takes six manual acts before the skill even exists to invoke — are under
[Why six acts, and the measurements behind each](#why-six-acts-and-the-measurements-behind-each) above;
this page numbers the install as "step 0" and this one as "step 1", because the underlying history
numbers from before the point where the four steps start.

> **The adoption commit lands on the trunk, and it is the one exception — it is spent by using it**
> (inbound [#1085](https://github.com/DaveKJohn/claude-code-specialists/issues/1085)). Everything this
> step and the next two write — the seam, the lenses, the two script scaffolds, the `@`-import, and the
> whole `dkj-policy/` folder if you enabled that workflow — is one sizeable commit, and it
> **cannot** go through the branch-and-PR cycle it is installing. That is not a preference: `new-branch`
> refuses without `scripts/lib/branch-info.ps1`, which is one of the files this step writes, so before it
> there is no branch to put the work on. The gates are downstream of the same commit for the same reason
> — the lint gate needs the `Get-LintScript` your repo answers in step 3, the test gate needs a suite
> that does not exist yet, and the CI entry gate needs a workflow file step 3 places.
>
> So commit it directly, **say so in the commit message**, and let the cycle start with the *next*
> change. Worth writing down because the documents you are handed on the same day say the opposite as a
> rule: `dkj-policy`'s contribution page describes a cycle in which every change goes
> through a branch and a PR, and a `CLAUDE.md` written from this family's scaffolding carries "never
> directly on `main`" as a safety rule. A reader who takes those literally on day one has a
> contradiction with two exits, and both are wrong — hand-building a branch and a PR that can meet none
> of the gates, or hesitating over the only commit that can possibly happen next.

**What it should report, so you can check it rather than trust it** (inbound
[#337](https://github.com/DaveKJohn/claude-code-specialists/issues/337)). With only the core `dkj-subagents-alpha`
plugin enabled, the closing line reads:

```
Done: 4 persona-lens(es) created, 0 already present; 15 lens-scaffold(s) created, 0 already present;
2 script-scaffold(s) created, 0 already present.
```

**4 personas + 15 subagent scaffolds = 19 lens files** in `.claude/specialists/lenses/`, plus 2 script
scaffolds and 1 `@`-import. Those figures used to appear only in the skill's own `SKILL.md`, which a reader
sees *after* invoking it — i.e. after the moment they would have needed them. This page is meticulous about
counting everywhere else (*"the count is part of the check, not a detail"*, as the install verification below puts it), and this was the
one step where the script prints numbers with nothing to compare them against.

**Read each pair as `created + already present`, not as a fixed number.** The sum is what this page
promises; the split depends on what your repo already had. A **fresh** repo — this step's own audience —
gets everything under `created`, which is the sample above. A repo that already had, say,
`scripts/repo-config.ps1` sees that one move to `already present` instead. So a figure that is *higher*
than the sample is not an error, and neither is one that is lower: what matters is that each pair adds up
and that the skill names anything it skipped. If you enabled an add-on team as well, expect its
specialists on top of these. `dkj-policy`, on the other hand, changes nothing here: it carries no
specialists, so this sample's numbers hold whether or not it is enabled alongside `dkj-subagents-alpha`.

> The sample above was itself the finding: until August 2, 2026 it showed `0 script-scaffold(s) created,
> 2 already present` — captured in a repo that already had them, and therefore inverted for exactly the
> fresh-repo reader this section was written for (inbound
> [#358](https://github.com/DaveKJohn/claude-code-specialists/issues/358)). The guidance covered only the
> "lower than this" direction, so the one number that could not match had no explanation.

**And one thing it does that no document mentioned:** every file it writes uses **LF** line endings and
`CLAUDE.md` gets **no trailing newline**, on Windows too. Harmless while nothing is committed, but on a repo
whose files are CRLF this is the same class of lasting diff
`claude plugin install` can leave behind — and the missing final newline turns any
later hand-edit of `CLAUDE.md` into a two-line diff. If your repo cares, normalise once after the
bootstrap.

**Step 2 — restart and verify.** Start again and check that Chris takes the floor. What that looks
like: the turn **names the specialist the work belongs to, and why**, before doing it — Chris's ritual
step is *"This one is for \<name\> — \<reason\>."* So on an ordinary request you should see something
like:

```text
**This one is for Rebecca (Research Specialist)** — "what's in this repo" is internal repo
exploration, her domain.
```

**Check for the invariant, not for a fixed string** (inbound
[#361](https://github.com/DaveKJohn/claude-code-specialists/issues/361)). A named owner with a stated reason
is what the persona guarantees and what proves the orchestrator loaded; the exact shape is not fixed.
Some repos add a house style on top — a fixed header line per turn, emoji and all — but that is a rule
those repos write into their own `CLAUDE.md`, not something this plugin ships. Until August 2, 2026 this
step told you to look for `🧭 Chris — intake & routing`, which no bootstrapped repo emits: a
verification a fresh consumer could not pass, on the step that exists to prove the install worked.

**Step 3 — run the adopt skill of every plugin you enabled.** Step 1 places the seam; it does not answer
the questions the *other* plugins ask of your repo, and **an install writes nothing into a repo at all** —
it is a clone into the plugin cache. Every plugin that owns repo state ships its own `adopt-*` skill to
close that gap, and until you run it, a session check reports what is missing at every session start.
The set as of this release:

| skill | shipped by | what your repo lacks without it | what reports it |
|---|---|---|---|
| `adopt-dkj-policy` | `dkj-policy` | two independent things, either order: **Part 1** — `dkj-policy/` itself, the only location the shared scripts read the branch dossier and the release documents from; **Part 2** — the seam values that state the shared way of working, answering what step 1 only *scaffolded* (`scripts/repo-config.ps1` and `scripts/lib/branch-info.ps1`) | `script-contract-sessioncheck` |
| `adopt-shopify-floor` | `dkj-subagents-shopify` | the live-theme guard's id half, a starter `.theme-check.yml`, and the CI gate that runs it | `shopify-floor-sessioncheck` |

**Enumerate it from your own slash list rather than from this table.** A plugin added after this release
brings its own adopt skill, and the table cannot know about it; the rule is what does not go stale —
*every plugin you enabled that owns repo state ships an `adopt-*` skill, and you owe it one run.* Your
slash list holds exactly the ones your enabled plugins ship, namespaced as `<plugin>:adopt-*`, so it
answers the question for your repo rather than for the repo this page was written in. `dkj-subagents-alpha` is the
exception that shows the shape: its adopt skill **is** `specialists-init`, which is step 1.

**All of them are additive and a dry run by default** — each prints exactly what it would do and writes
nothing until you add `-Apply`, so reading the plan first costs you nothing and none of them can
overwrite work of yours. `adopt-dkj-policy`'s Part 2 and `adopt-shopify-floor` both **append to
`scripts/repo-config.ps1` and need it to exist**, which is what step 1 placed. And this step is yours
whichever channel the plugins arrived on: an adopt skill writes into *your repo*, not onto the machine,
so a centrally published install does not cover it.

**It is minutes, and it deliberately sits before the largest step.** Doing it now clears the session
checks that would otherwise sit red through the whole of step 4 — and a reader who cannot tell a standing
`[ERROR]` from a mistake of their own learns to scroll past the session check, which is the failure this
family warns about everywhere else: *a check that fires every time is the check nobody reads on the day
it is right.*

> **This step did not exist until August 20, 2026, and the page named none of these skills** (inbound
> [#784](https://github.com/DaveKJohn/claude-code-specialists/issues/784)). The consumer that reported it
> worked through the three steps as written and then spent a second day on follow-up rounds, each one
> triggered by a session-check `[ERROR]` reporting something this page never mentioned — all of it
> discoverable up front, none of it discovered up front. The shape was the defect rather than the
> wording: the page described a one-plugin world, while a real install is `specialists-init` **plus one
> adopt step per enabled plugin that owns repo state**. A consumer cannot infer a skill's existence from
> a plugin's presence, so only this page can say it.

**Step 4 — write the roster and fill the lenses.** This is the step where the system starts being
useful, and it is by a wide margin the largest one. The three steps above give you a team that knows its craft
and nothing about your repo; the lenses in the seam (`.claude/specialists/lenses/`) are where you say
what each specialist serves *here*. An unfilled lens does nothing — it is a scaffold with a `VUL-IN`
slot, not a default.

**The honest cost: budget half a day's worth of writing, not a command.** Concretely, on a repo of
ordinary size (measured during the August 3, 2026 adoption that produced inbound
[#408](https://github.com/DaveKJohn/claude-code-specialists/issues/408)):

- Chris's lens first — the roster and the routing table. Everything else refers back to it.
- Then the specialists that actually have work in your repo. In that measurement, 20 of the 25
  placed lenses got repo-specific content; the rest stayed `VUL-IN` on purpose.
- **A lens may stay empty, and that is a state rather than a backlog item.** Fill it on the day that
  specialist first has work.

Two things reliably surface in this step and are not caused by it, so plan for them rather than
diagnose them: a `.gitignore` that excludes `.claude/` and therefore the whole seam — check that
before you write anything, because every gate stays green while your lenses are untracked — and a
`scripts/repo-config.ps1` older than the current script contract (`Get-RosterPath`,
`Get-RosterIgnoredIds`), which `scripts/sync/check-script-contract.ps1` reports for you and step 3's
`adopt-dkj-policy` (Part 2) is what answers.

The worker specialists can be invoked directly as `@dkj-subagents-alpha:<name>` from the moment Step 2 is
done — with an empty lens they simply answer out of their portable playbook.

> **Do not attribute this half hour to the installer.** `specialists-init` places the seam, 25 lens
> files, the roster scaffold, the settings proposal and the `@`-import in **seconds**. The time here is
> yours, spent writing — which is why it is a numbered step rather than a closing remark.

## Delivering the orchestrator from the plugin — verified, deliberately not switched on

Enabling the plugin delivers the **worker subagents**, but not the **conductor** (Chris) or the
governance/hooks layer, so the skill **`specialists-init`** above (from `dkj-subagents-alpha`, the core
team) closes that gap in a consuming repo. Because a plugin skill cannot hook itself in, the path has to
be two-stage — install, then bootstrap — rather than one.

> **One half of the old reason for this is false, and it matters for
> [Removal: the teardown gap](#removal-the-teardown-gap) below.** The two-stage path used to be justified
> with "a plugin injects no main-loop context and edits no `CLAUDE.md`". The second half is true and
> documented. The first is not: a plugin **can** activate one of its own agents as the main thread via a
> root `settings.json` — and the `@`-import is both the only reason the bootstrap exists and the single
> worst thing left behind on uninstall. Finding:
> [issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215).

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
  wording was internally inconsistent anyway: his fixed ritual has always said *"execute according to
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
3. **Chris ships as a persona, not a subagent, so there is no `subagents/specialist-01-01-subagent.md` to point at.**
   Creating one is not a formality: that file's `tools:` and `model` would become **the whole main
   thread's** tool policy and model.

The body is therefore ready and the switch is not thrown. Flipping it is Dave's call, now on a fact
instead of an unknown: the collision resolves silently and positionally, so a consumer who enables a
second `agent`-setting plugin gets a different orchestrator without being told.

## Removal: the teardown gap

> **Status: closed on July 30, 2026.** Every item of the target shape below carries its own *Settled on*
> marker, and [issue #221](https://github.com/DaveKJohn/claude-code-specialists/issues/221) is closed. The
> section is kept in full rather than trimmed to a verdict, because the **measurements** are the reason
> the design ended up the way it did — the 26 orphaned lens files, the import that actively broke, the
> 101 specialist mentions across 492 lines, the resolver that took the daily git workflow down with it.
> A future change that finds this shape inconvenient should have to argue with the numbers, not with a
> conclusion. What is *not* closed and deliberately so: delivering Chris from the plugin's own
> `settings.json` ([#215](https://github.com/DaveKJohn/claude-code-specialists/issues/215)) — the mechanism
> is verified above and the switch is Dave's to throw.

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
and tested without restructuring anything first.
[`specialists-teardown`](dkj-subagents/dkj-subagents-alpha/skills/specialists-teardown/SKILL.md)
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
  [#254](https://github.com/DaveKJohn/claude-code-specialists/pull/254)), with the source repo migrated onto it as
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
  (structure preserved, never overwriting), so the workflow survives the uninstall. The source repo is the
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
        ├── specialist-01-01-lens.md
        ├── specialist-05-05-lens.md
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
before diagnosing "the specialists stopped loading" as a bug in your own repo.

## Undoing it — the half that is yours

Adoption is reversible by design, and the reversal is **two** removals that do not do each other's job:
taking the family out of *your repo*, and taking the plugin off *the machine*. The first is this page's
mirror image and is yours whatever channel you are on. The second is an install, so it belongs to
whoever did the installing — if that was your organisation, it is not yours to undo.

**Out of your repo** is the `specialists-teardown` skill: it removes the seam
(`.claude/specialists/`), the `@`-import in your `CLAUDE.md`, the settings proposal and the scaffolds
you never filled in. It is a **dry run by default**, because a script that deletes things in somebody's
repo should have to be asked twice — and the preview doubles as the inventory you say yes to. It
classifies before it removes: a lens still carrying its `VUL-IN` marker is generated and goes, a lens
**you filled in is yours** and is reported rather than touched. Read the `[remove]` and `[KEEP]` lines
rather than what is left on disk; a `[KEEP]` means *still there*, not *still working*.

**Off the machine** comes second, because the teardown skill ships inside the plugin you would be
uninstalling. From your repo's root, once per plugin, then remove the `enabledPlugins` and
`extraKnownMarketplaces` keys from your `.claude/settings.json` and restart — a leftover
`extraKnownMarketplaces` key lets a session start rebuild the install by itself:

```powershell
claude plugin uninstall dkj-subagents-alpha@dkj-claude-plugins --scope project
```

`claude plugin marketplace remove dkj-claude-plugins` is **machine-wide**: it drops every install record
on that marketplace, including other checkouts'. Run it only when this was the last checkout on the
machine using the family.

**What stays behind is not debt, mostly.** Your history stays — a changelog that mentions specialists
is an accurate record of something that happened. Lenses you wrote stay, as files nothing reads any
more. Roster rows and specialist names in your own prose stay, because no rule a script could apply
safely knows where a roster row ends and your writing begins.

**One leftover keeps talking, and it is the one to act on.** If the bootstrap created your `CLAUDE.md`,
two of its lines are its own — and `CLAUDE.md` is loaded into every session as project instructions. So
that file goes on telling every future session, in the channel that outranks its defaults, that this
repo is governed by a system that is no longer installed. The teardown reports those lines instead of
deleting them, deliberately: an `@`-import *loads* something, so removing it is safe and necessary, but
cutting sentences out of somebody's governance file to satisfy a counter is the wrong side of that
boundary. Delete them yourself, and the repo is genuinely free.

## Reporting back or improving something

- **An improvement to the shared core** (an agent def, playbook, persona, or skill): don't rework it
  locally, but report it as an issue on the source repo with the label `inbound` — an
  [issue template](../.github/ISSUE_TEMPLATE/inbound-improvement.md) is ready for that. It is processed
  through that repo's own chain, and the improvement comes back to every consumer via a release.
- **Repo-specific additions** belong in your own repo lenses in the seam
  (`.claude/specialists/lenses/`) — those are yours and do not travel with the plugin.

### Filing one needs no permission — and a session will not assume that on its own

**Say this to your session out loud, in your repo's own words, if you want it to report anything during
the adoption.** Opening an issue on somebody else's repository is an outward-facing publishing act, and
an agent given no statement to the contrary is *right* to hold it back. This route is the deliberate
exception, and nothing in a fresh consumer's context says so yet.

**Measured, inbound [#1094](https://github.com/DaveKJohn/claude-code-specialists/issues/1094).** A
session working from this very page found two real defects, verified both against the tree, wrote them
into its own run log — and filed neither. Not carelessness: the rule that would have said otherwise
lives in the orchestrator's body and in the agent-def bodies, and **a pre-bootstrap main loop has
neither**. Chris arrives through the `@`-import `specialists-init` writes, so he is in context only
*after* the bootstrap and a restart — one step later than the moment a consumer meets the most friction
and has the most worth reporting. That is a structural gap rather than something further down this page
can close; what you can do is state the rules yourself, before the adoption starts.

The three that matter here, all of them the orchestrator's:

1. **Filing needs no permission, and asking for it is the same failure as not filing.** *"Shall I open
   an issue for this?"* leaves the finding with you to answer, which is exactly what filing exists to
   prevent.
2. **Search that tracker before proposing a fix — it is a correctness step, not tidiness.** The source
   of truth for what a check was *built to prevent* is the issue that produced it; the code is the
   source of truth only for what it currently *does*. A proposal that touches a guardrail needs both.
3. **A constraint you have inferred is verified before you obey it.** A tool's refusal is not the
   owner's policy until you have read what the repo actually says. The expensive failure is not doing
   something forbidden — it is declining work that was always permitted, because a refusal arrives
   phrased as authority while a capability you never looked for announces nothing at all.

**The ordinary filing bar still applies, and none of it is a permission gate:** verify it still stands,
one subject per issue, say what you measured versus what you inferred, and don't file work you were
asked to do or a finding you can simply fix where you are.

> **If you keep your own `CLAUDE.md` safety rules, check them against this.** A rule of the shape
> *"publishing anything externally — issues on other repos, a gist, an external post — needs explicit
> permission"* is common, sensible, and **forbids this route** unless it carves the route out by name.
> The source repo had exactly that contradiction in its own constitution and repaired it on the day
> this section was written.
