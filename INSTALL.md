# Install

> **First: did you go and get these plugins, or did they arrive?** Everything on this page registers a
> marketplace and installs from it, and every command here names the **public** source
> `DKJ-Solutions/dkj-claude-plugins`. If your organisation publishes this family through a marketplace
> of its own — a private mirror, an Enterprise channel — then the registration and the install were done
> once, centrally, and **the commands below are not yours to run**. Running them anyway does not fail
> loudly; it quietly adds a second channel pointing somewhere else, which is the one thing an
> organisation's own marketplace exists to prevent.
>
> What is still yours in that case is the part this page calls **adoption**: connecting your own repo,
> running the bootstrap, and filling your lenses. Start at
> [Adoption](#adoption--how-to-connect-your-repo) and skip the Quickstart entirely.
>
> Reported from a business mirror on August 14, 2026, inbound
> [#664](https://github.com/DaveKJohn/claude-code-specialists/issues/664): a republished copy carries
> this page verbatim, and nothing in it told the reader which copy they were holding.

## Quickstart — the commands, and nothing else

**This half is the short one.** Two settings keys, five commands (the default now enables and installs
two plugins, not one), one verification query, two restarts, and one adopt run per plugin that owns repo
state. Every caveat, every measurement and every
failure mode behind them lives in
**[Adoption](#adoption--how-to-connect-your-repo)**, the second half of this page — the full manual,
which this half is the summary of.

> **Read the adoption half instead if any of this is true**: this is a machine that has adopted the
> family before (a leftover user-scope marketplace makes half of Step 1 silently unnecessary —
> [which of the three machine states are you in?](#which-of-the-three-machine-states-are-you-in));
> it is a fresh Windows profile ([before you start](#before-you-start) — the execution
> policy alone will stop you); or **you are an agent executing this for someone**
> ([where it has to stop](#if-an-agent-is-doing-this-for-you--where-it-has-to-stop) —
> two of these acts are ones you structurally cannot perform).
>
> **Read neither half, and go straight to
> [Migrating from the old plugin names](#migrating-from-the-old-plugin-names) instead, if you already
> have this family installed under the ids it used before it split into teams and a workflow** —
> `specialists@claude-code-specialists` and its siblings. That is a third procedure, not a shorter or
> longer version of either half below.

### Step 1 — enable and install

**1. Write your repo's own `.claude/settings.json`** (create `.claude/` beside your `README.md` if it
is not there). A complete, pasteable file; if you already have one, merge these two keys into it.
Strict JSON — no comments, no trailing commas. `dkj-subagents-alpha` is the only plugin you need: **there is no
default workflow to receive**, and a repo that enables none keeps the way of working it already had. Add a
line per add-on team you want, and add `dkj-policy` only if you deliberately want that method (see
[Enabling the workflow](#enabling-the-workflow)).

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

**2. Restart your Claude Code session.** A session start is what registers the marketplace; without
it, the next command fails with `Marketplace … not found`.

**3–4. Refresh, then install — from your repo's root, one install per plugin you enabled.**

```powershell
claude plugin marketplace update dkj-claude-plugins                     # never skip: install does not refresh
claude plugin marketplace list                                               # came the entry from YOUR repo's settings?
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project    # once per plugin
```

`--scope project` is not optional — without it the install goes machine-wide and writes no
`projectPath`, with no error.

**5. Restart your Claude Code session again.**

**6. Verify — from your repo's root.** The install output names no version at all, so this query is
the only place your version is written down.

```powershell
$root = (Get-Location).Path
(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |
  ForEach-Object { $n = $_.Name; $_.Value | Where-Object { $_.projectPath -eq $root } |
    ForEach-Object {
      $payload = if ($_.installPath -and (Test-Path -LiteralPath $_.installPath)) { 'payload present' } else { 'PAYLOAD MISSING' }
      "$n -> $($_.scope) $($_.version) $($_.gitCommitSha) [$payload]" } }
```

**One** `project` line per plugin, ending in `payload present`. The count is part of the check.
Anything else — empty output, two lines for one plugin, `local`, `PAYLOAD MISSING` — is covered in
[Connecting in five steps](#connecting--the-install-step), in the adoption half below.

> **Writing `enabledPlugins` is not installing, and a repo can look completely adopted without it**
> (inbound [#1076](https://github.com/DaveKJohn/claude-code-specialists/issues/1076)). Steps 1–2 above
> are two separate acts on two separate files: the settings key is **yours**, in your repo; the install
> record is the **machine's**, in `~/.claude/plugins/installed_plugins.json`, keyed by `projectPath`.
> Set the key and skip the install and everything a person can see says the adoption is done — the
> settings file names both plugins, a `CLAUDE.md` written afterwards describes them as project-scoped —
> while a session gets **no skills, no subagents and no session hooks at all**. Measured on a repo that
> ran in that state for a full working day, two merged PRs and a release: the only way to drive the
> workflow was to call the shipped `.ps1` files by absolute path into the plugin cache, which is the
> shape that then met [#1075](https://github.com/DaveKJohn/claude-code-specialists/issues/1075)'s
> permission problem. The two compound, and this is the one to fix first.
>
> **The query above is the check, precisely because it needs no plugin.** It reads a machine file, so it
> answers whether the install happened even when nothing else can.
>
> **Do not use the session's own skill listing as the check.** Several skills ship with
> `disable-model-invocation: true`, which is deliberate and removes their page from the model's context
> while leaving the slash command intact — so a *healthy* session lists fewer skills than the plugin
> ships, and a count read off that listing means nothing. Ask the **slash-command menu** instead: after
> the second restart, `/specialists-init` must be in it, and `/new-branch` too if you enabled the
> workflow. A count of skills is not a durable check for a second reason — the number changes with every
> release that adds one.
>
> **And nothing will tell you.** Four separate detectors in this family report exactly this state —
> `roster-sessioncheck`, `connector-sessioncheck`, `check-roster-sync` and the bootstrap's own
> `claude plugin install --scope project` line — and **all four ship inside the plugin that is not
> installed**. A plugin's SessionStart hook is plugin surface too, so the repo missing the record is
> precisely the repo where the warning cannot fire. Their silence here is not an all-clear; it is the
> symptom. That is why this verification is a step you run rather than a check you wait for.

### Step 2 — run the bootstrap skill

In the new session, invoke `specialists-init`. It places the persona lenses, an empty lens scaffold
per specialist, two script scaffolds, one `@`-import in your `CLAUDE.md` and a settings proposal —
purely additively, in seconds. Check its closing `Done:` line against
[what it should report](#connecting--the-install-step).

### Step 3 — restart and verify

Restart once more and check that Chris takes the floor: the turn **names the specialist the work
belongs to, and why**, before doing it. Look for that invariant, not for a fixed string.

### Step 4 — run the adopt skill of every plugin you enabled

An install writes **nothing** into your repo — it is a clone into the plugin cache — and Step 2 answers
only what `dkj-subagents-alpha` needs. Every other plugin that owns repo state ships its own `adopt-*` skill:
`adopt-dkj-policy` (`dkj-policy`), `adopt-shopify-floor`
(`dkj-subagents-shopify`). Your slash list holds exactly the ones your enabled plugins ship, namespaced as
`<plugin>:adopt-*`, and each is additive and a dry run until you add `-Apply`. Skip this and a session
check reports what is missing at every session start — which is how a consumer ends up discovering the
rest of their adoption one `[ERROR]` at a time (inbound
[#784](https://github.com/DaveKJohn/claude-code-specialists/issues/784)). The full step, with what each
skill places and what reports it, is
[step 3 on the adoption page](plugins/ADOPTION.md#the-four-steps).

### Step 5 — write the roster and fill the lenses

**This is the big one, and it is not optional.** Steps 1–4 give you a team that knows its craft and
nothing about your repo; the lenses in `.claude/specialists/lenses/` are where you say what each
specialist serves *here*, and an unfilled lens does nothing. Budget writing time, not typing time —
[step 4 on the adoption page](plugins/ADOPTION.md#the-four-steps) states the cost and the two things
that reliably surface while you do it.

### Enabling the workflow

**There is no default workflow, and that is the answer rather than a gap.** Your repo already has a way
of working before any plugin is installed — its branch conventions, its contribution guide, its release
steps — so a plugin claiming the slot by default would claim something that was never empty. Enable
`dkj-policy` if you deliberately want *that* method; enable nothing and the specialists use plain
git/gh against your own conventions.

A second plugin, `workflow-default`, used to hold the slot and describe itself as "the workflow a repo
gets when it has not chosen one". It was removed on August 26, 2026
([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)) for exactly the reason above.
**If your `.claude/settings.json` still names it, remove that line** — the id resolves to nothing at your
next `claude plugin marketplace update`, and nothing warns you.

To turn the workflow on, add its key to `enabledPlugins`, then repeat Step 1's refresh + install for it
and restart. It asks your repo for two files it reads — `scripts/repo-config.ps1` and
`scripts/lib/branch-info.ps1` — which the next `specialists-init` run scaffolds. Turning it back off
removes nothing it already wrote: your entry files and your config stay, and the skills that read them
stop.

**Nothing counts your enabled workflows any more, and that is worth knowing rather than discovering.**
Until #886 the core team's `workflow-sessioncheck` hook counted the enabled ids beginning with
`workflow-` on every `SessionStart` and printed an `[ERROR]` at two or more, naming the settings layer
that enabled each. It was retired together with the second plugin, because one plugin cannot collide with
itself. There is nothing to get wrong here today — but if this family ever ships a second workflow, no
session start will tell you both are on.

### Staying up to date — the two commands

Two commands, from your repo's root, one pair per plugin:

```powershell
claude plugin marketplace update dkj-claude-plugins
claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project
```

**Before running them, check whether you are behind at all.** Once `dkj-policy` is installed, the
`plugin-versions` skill answers that per checkout — one read-only run, no arguments, on any machine. It
prints, per enabled plugin, the version and commit this checkout installed against the marketplace
clone's version and HEAD, then a per-plugin verdict — up to date, update this plugin, or refresh the
clone — with the command for each. It supersedes the hand-run `installed_plugins.json` query for the
*"am I current?"* question. That query keeps the one job the skill cannot do — telling you the install
happened at all — because the skill ships inside the plugin and is silent when the plugin is what is
missing.

Same scope flag, same reason. **The version number is not the code** — the clone these commands read
tracks `main`, not the tag, so your `gitCommitSha` is the truth about your session and your `version`
only tells you which release notes to read. A new *skill* needs a session restart before it appears;
a new *specialist* needs a roster and lens catch-up (`sync-roster`). Your install record can also
move, be adopted by another directory, or be orphaned by renaming your checkout, all without you
asking. All of that, measured:
[Staying up to date in the adoption half](#staying-up-to-date).

### Getting out again — the short answer

Adoption is reversible by design: **[UNINSTALL.md](UNINSTALL.md)**. Two removals, out of your repo
and off your machine, in that order — the teardown skill ships inside the plugin you would be
uninstalling.

### Reporting back

An improvement to the shared core (an agent def, playbook, persona, or skill) is not reworked
locally: file it as an issue on this repo with the label `inbound` — there is an
[issue template](.github/ISSUE_TEMPLATE/inbound-improvement.md). Repo-specific additions belong in
your own lenses, which do not travel with the plugin.

---

## If this machine has more than one checkout

> **Read this before step 3 of any of the three migration sequences below.** It changes nothing about
> the commands. It changes how many times you run them, and where the second and third checkouts start.

An install record is keyed on the folder it was written for, so each of the migrations below is per
machine **and** per checkout: three checkouts on this family means running the sequence three times.
**`claude plugin marketplace remove` is the one command in it that is not per checkout.** It drops the
marketplace registration machine-wide, and it takes every install record keyed on that marketplace with
it — including the records of checkouts that have not migrated yet, and that no command in your run has
named.

**"Every record keyed on that marketplace" has a second axis, and it is the one that bites inside a
single checkout.** Records are stored under `<plugin>@<marketplace>`, so retiring the marketplace half
cannot be selective by plugin: the `remove` also takes **this** checkout's records for plugins your
step 2 never mentioned. That is why each sequence below reinstalls more ids than it uninstalled, and it
applies to a machine with exactly one checkout too
([#1824](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1824)).

Measured on September 11, 2026, on one machine with three checkouts, read before and after
from `~/.claude/plugins/installed_plugins.json`:

| records on the machine | count |
|---|---|
| before starting | 16, over three checkouts |
| after step 2 in the first checkout only (six uninstalled) | 10 |
| after that checkout's step 3 and step 4 | 6 — its own six under the new name, and nothing else |

The ten records belonging to the other two checkouts were gone, silently, without either checkout being
named by any command in the run and without either having been touched.

**So step 3 is two commands with two different reaches, and only the first one is machine-wide.**
`marketplace remove` drops the registration for the whole machine, so it is run **once**;
`marketplace add … --scope project` writes the marketplace source key into **the repo you run it in**
(that is what the scope flag is for, and why this page insists on it), so every checkout needs its own.

**For the second checkout and every one after it, that makes the sequence:** skip step 2, whose
uninstalls have no record left to find; skip step 3's `marketplace remove`, already done; then run step
3's `marketplace add` and step 4 exactly as written. What is left there is a plain install of the new
ids, which reaches the same end state.

**Run step 2 there anyway and it fails in two different ways, neither of which names the real cause.**
Measured verbatim on the second checkout, September 11, 2026, on the single CLI version that run was
made with — so expect the wording to move and the shape not to:

```text
Failed to uninstall plugin "dkj-team-alpha@claude-code-specialists": Plugin "dkj-team-alpha@claude-code-specialists" not found in installed plugins
Failed to uninstall plugin "dkj-policy@claude-code-specialists": Plugin "dkj-policy@claude-code-specialists" is not installed in project scope. Use --scope to specify the correct scope.
```

**The two lines came off one checkout that held both a team plugin and the workflow under the old
marketplace name**, so between them they span what two of the sequences below cover separately. Do not
try to match the pair to the step 2 you are standing in: what carries over is the two **shapes** of
failure, not this particular pair of ids.

**The second one is the actively misleading one:** it reads as a scope mistake of yours, and
`--scope project` was correct. Nothing is wrong with your machine and there is nothing to repair — the
record it is looking for was taken by a command you ran in a different folder. Carry on at step 3's `add`.

**It is bookkeeping, not data loss.** An install record is what tells a session which plugins this folder
has; installing writes it again, which is what step 4 does anyway. What the machine-wide removal costs is
the **procedure**, not your repos.

**Where this paragraph stops, so you can judge it:** one machine, one CLI version, three checkouts.
Whether `marketplace remove` treats `user`-scope records the same way is untested
([#1820](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1820)). **And `--scope` is not the
fence it might look like, though not for the reason this paragraph used to give:** it said the flag lives
on `add` rather than on `remove`, which is simply wrong — `claude plugin marketplace remove --help` on CLI
`2.1.268` documents it, as *"Remove the marketplace declaration from a specific settings scope"* (measured
September 11, 2026, while repairing the sibling page's half of this;
[#1823](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1823)). The conclusion survives the
correction and the reason changes: what the flag governs is which settings scope the **declaration** comes
out of, and the reach above was measured without it, so nothing here establishes that it narrows the
records.

---

## Migrating off the `dkj-team-*` ids (#1698, September 9, 2026)

> **This section is for a repo that has this family's teams installed under the ids they used up to
> September 9, 2026** — `dkj-team-alpha@claude-code-specialists` and the three add-on teams. Like the
> section below it, this is a rename and nothing else: no team gained or lost a specialist, a manual, a
> skill or a hook on the day it happened.
>
> **The workflow PLUGIN ids (`dkj-policy`, `dkj-policy-bwj`) are unchanged — but their INSTALL ids are
> not, and step 3 below drops their records.** An installed id is `<plugin>@<marketplace>`, and step 3
> retires the marketplace half for **everything** on this machine, not only for the four teams it names.
> So if you have a workflow plugin installed, step 4 reinstalls it — the lines are there, and
> [#1824](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1824) is why.

| old plugin id | new plugin id |
|---|---|
| `dkj-team-alpha@claude-code-specialists` | `dkj-subagents-alpha@dkj-claude-plugins` |
| `dkj-team-ecomm@claude-code-specialists` | `dkj-subagents-ecomm@dkj-claude-plugins` |
| `dkj-team-lifehub@claude-code-specialists` | `dkj-subagents-lifehub@dkj-claude-plugins` |
| `dkj-team-shopify@claude-code-specialists` | `dkj-subagents-shopify@dkj-claude-plugins` |

**Why the names moved.** *Team* is this family's own word for a group of specialists; *subagent* is Claude
Code's word for what those plugins actually ship, and it is the word your own harness uses when it loads
them. The four now say what is in the box in the vocabulary of the thing that opens it. Nothing about how
they stack changed: the core team is still the one every repo enables, and the add-on teams still add to
it rather than replacing it.

**What did NOT get a prefix, deliberately.** `dkj-scaffold-subagents` was considered on the same day and
declined: on the agent anatomy *every* plugin here is scaffold, so the prefix would be a constant, and a
constant belongs in the namespace — which `dkj-` and `@dkj-claude-plugins` already are.

```powershell
# 1. Refresh -- do this first, every time
claude plugin marketplace update claude-code-specialists

# 2. Uninstall the retired ids -- skip whichever you never enabled.
#    Keep the OLD @claude-code-specialists spelling: uninstall resolves against your
#    install record, which still holds it, not against the catalogue.
claude plugin uninstall dkj-team-alpha@claude-code-specialists --scope project
claude plugin uninstall dkj-team-ecomm@claude-code-specialists --scope project
claude plugin uninstall dkj-team-lifehub@claude-code-specialists --scope project
claude plugin uninstall dkj-team-shopify@claude-code-specialists --scope project

# 3. Re-register the marketplace under its new name -- the marketplace itself was
#    renamed on the flag day, so your machine must drop the old registration and add
#    the new one. A plain refresh cannot do this: the name is part of the id.
#    The `remove` is MACHINE-WIDE and is the only command here that is. It drops EVERY
#    install record keyed on the old marketplace -- every plugin and every checkout,
#    not just the ids step 2 named. So it ends the migration of every OTHER checkout
#    on this machine early, AND it takes this checkout's other plugins with it, which
#    is why step 4 below puts back every plugin you had, not just the renamed ones.
#    The `add` is per checkout -- that is what --scope project means.
#    With more than one checkout, read "If this machine has more than one checkout"
#    above first: there you skip the remove and start at the add.
claude plugin marketplace remove claude-code-specialists
claude plugin marketplace add DKJ-Solutions/dkj-claude-plugins --scope project

# 4a. Refresh the new marketplace, then install the new team ids -- only the ones you had
claude plugin marketplace update dkj-claude-plugins
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-ecomm@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-lifehub@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-shopify@dkj-claude-plugins --scope project

# 4b. The workflow, if you had one -- its PLUGIN id did not change, which is exactly
#     why this is easy to skip, but step 3 took its install record with the teams'.
#     Still on `contributing-davekjohn`? Run the section below instead of these two.
claude plugin install dkj-policy@dkj-claude-plugins --scope project
# Only BWJ's two store repos need this one:
claude plugin install dkj-policy-bwj@dkj-claude-plugins --scope project
```

**5. Restart your Claude Code session.**

`--scope project` is not optional here any more than it is anywhere else on this page. Expect the
uninstalls, the `marketplace add`, and the installs to rewrite `.claude/settings.json` on the way, the
same rewriting behaviour [documented above](#connecting--the-install-step): the `dkj-team-*`
`enabledPlugins` entries come out, the `dkj-subagents-*` ones go in, the marketplace source key is
repointed at `dkj-claude-plugins`, and any diff beyond that is formatting. **A workflow entry you
reinstalled at 4b is repointed at the new marketplace in the same pass** — it looks like a change to a
plugin this section said it was not touching, and it is the marketplace half of its id moving, nothing
more. **That file is the CLI's to edit, so it is not on the list below** — the list is what the CLI
leaves for you.

### The two things inside your repo that the id swap does not fix

**1. The `@`-import of the orchestrator's body** names a path inside the marketplace clone, and both
halves of that path moved: `plugins/dkj-teams/dkj-team-alpha/` is now
`plugins/dkj-subagents/dkj-subagents-alpha/`. The shape test in the section below still applies verbatim
— an import whose path does not contain `plugins/dkj-subagents/<team>/` or `plugins/dkj-policy/` is stale,
whatever it contains instead — and this rename is simply the newest thing it catches.

**2. Your `connectors/` register, if you keep one.** `check-connectors.ps1` resolves each record's id
against the marketplace, so a record still naming `dkj-team-alpha@` is reported as an `[INFO]` and **the
whole block for that plugin is then skipped** — no enabled-in-settings check, no extensions check, no
version check, silently, until somebody edits the record. That is the same cost the two renames before
this one paid, recorded in `connectors/dkj-claude-plugins.json`'s own notes. Update the record when
you migrate, not before: the register says what a consumer **has**, so an id changed ahead of the
uninstall/install is a second wrong answer rather than a head start.

### What you will see change inside the plugin, and can ignore

Each team's payload directory `agents/` is now `subagents/`, declared by an `"agents"` key in the plugin
manifest that **lists every subagent file by path**. This is internal to the package: nothing you write
names that directory, and every reader this family ships reads **both** leaf names, new first, so a
machine holding a pre-rename version in its plugin cache keeps resolving. `skills/` is deliberately
**not** renamed alongside it — the plugin format always scans the default `skills/` directory in addition
to any custom one, so a custom skills directory can only ever add, never move.

> **If you tried to install a team plugin on `v4.33.0` and it refused, that is why.** That release
> declared the key as `"agents": "./subagents/"` — a directory — and the installer accepts only paths to
> `.md` **files**, so all four team plugins answered
> `Validation errors: agents: Invalid input` and installed for nobody
> ([#1764](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1764)). Run
> `claude plugin marketplace update` to pick up the repaired manifests, then install as usual. Nothing on
> your side caused it and nothing on your side needs changing.

---

## Migrating off `contributing-davekjohn` and `bwj-codex` (#1437, September 5, 2026)

> **This section is for a repo that has this family installed under the ids it used up to
> September 5, 2026** — `contributing-davekjohn@claude-code-specialists` and, in BWJ's two store repos,
> `bwj-codex@claude-code-specialists`. It is shorter than the section below because it is a rename and
> nothing else: no plugin gained or lost a skill, a script, a gate or a seam on the day it happened.

| old plugin id | new plugin id |
|---|---|
| `contributing-davekjohn@claude-code-specialists` | `dkj-policy@dkj-claude-plugins` |
| `bwj-codex@claude-code-specialists` | `dkj-policy-bwj@dkj-claude-plugins` |

**Why the names moved.** `dkj-policy` is the top rung of the order this family legislates — the page that
outranks a consumer's root `CLAUDE.md` on every subject it addresses — and `contributing-davekjohn` named
only one of the things it does. `dkj-policy-bwj` is a ministry under it: the same policy, narrowed to the
two repos it binds. Nothing about the precedence rule changed; the names now say what the rule already did.

```powershell
# 1. Refresh -- do this first, every time
claude plugin marketplace update claude-code-specialists

# 2. Uninstall the retired ids -- skip whichever you never enabled.
#    Keep the OLD @claude-code-specialists spelling: uninstall resolves against your
#    install record, which still holds it, not against the catalogue.
claude plugin uninstall contributing-davekjohn@claude-code-specialists --scope project
claude plugin uninstall bwj-codex@claude-code-specialists --scope project

# 3. Re-register the marketplace under its new name -- the marketplace itself was
#    renamed on the flag day, so your machine must drop the old registration and add
#    the new one. A plain refresh cannot do this: the name is part of the id.
#    The `remove` is MACHINE-WIDE and is the only command here that is. It drops EVERY
#    install record keyed on the old marketplace -- every plugin and every checkout,
#    not just the ids step 2 named. So it ends the migration of every OTHER checkout
#    on this machine early, AND it takes this checkout's other plugins with it, which
#    is why step 4 below puts back every plugin you had, not just the renamed ones.
#    The `add` is per checkout -- that is what --scope project means.
#    With more than one checkout, read "If this machine has more than one checkout"
#    above first: there you skip the remove and start at the add.
claude plugin marketplace remove claude-code-specialists
claude plugin marketplace add DKJ-Solutions/dkj-claude-plugins --scope project

# 4a. Refresh the new marketplace, then install the new workflow ids
claude plugin marketplace update dkj-claude-plugins
claude plugin install dkj-policy@dkj-claude-plugins --scope project
# Only BWJ's two store repos need the second one:
claude plugin install dkj-policy-bwj@dkj-claude-plugins --scope project

# 4b. Your teams, if you have any -- this section renames nothing about them, so step
#     2's short list reads as the whole reach; step 3 dropped their records anyway.
#     Still on `dkj-team-*`? Run the section above instead: it uninstalls those first.
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-ecomm@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-lifehub@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-shopify@dkj-claude-plugins --scope project
```

**5. Restart your Claude Code session.**

### Your folder, and what happens if you do not rename it

The workflow's own root folder is named after the plugin, so its current name is **`dkj-policy/`** and the
`adopt-dkj-policy` skill's Part 1 scaffolds that name from now on. **Renaming your existing folder is optional
and nothing breaks if you leave it**: `Get-WorkflowFolderName` prefers whichever folder is actually there,
newest name first, and every seam default is composed from its answer — so a repo still holding
`contributing-davekjohn/` (or `workflow-davekjohn/`, from the rename before this one) keeps its changelog,
its release history and its branch documents exactly where they are.

What that costs is one thing worth knowing before you decide: **the scaffolder writes the new name.** Run
the `adopt-dkj-policy` skill's Part 1 in a repo that still has the old folder and you get a second folder beside the one
holding your history. So either rename yours in one commit —

```powershell
git mv contributing-davekjohn dkj-policy
```

— or leave it alone and do not re-run the scaffolder. The half-way state is the one to avoid.

**If you rename it, your seams may need repointing too.** A repo that STATED `Get-ChangelogPath` or any of
the four release-note roots in its own `scripts/repo-config.ps1` wrote the folder name into that answer;
a repo that left them at the computed default did not, and is carried across for free. `check-script-contract`
names every seam you have stated, which is the fastest way to see which of the two you are.

### `bwj-codex/SYNC-LOG.md`, for the two store repos

The sync log's location is a seam — `Get-ShopifySyncLogPath` — so this rename does not move it. The
recommended answer is now `'dkj-policy-bwj/SYNC-LOG.md'`; a repo that keeps answering
`'bwj-codex/SYNC-LOG.md'` is answering the seam correctly and stays where it is. Move it only if you want
the folder to match the plugin, and move the seam answer in the same commit.

---

## Migrating from the old plugin names

> **This section is for a repo that already has this family installed under the plugin ids it used
> before it split into teams and a workflow** — `specialists@claude-code-specialists`,
> `specialists-lifehub@claude-code-specialists`, `specialists-shopify@claude-code-specialists`,
> `specialists-ecomm@claude-code-specialists`, or `specialists-workflow-davekjohn@claude-code-specialists`.
> It is neither the quickstart above (you are not adopting for the first time) nor the adoption manual
> below (you are not connecting a repo that has never seen this family) — it is a third procedure, and
> it earns its own section because a mechanical id swap alone silently loses something neither of the
> other two ever had to account for. Read [Decide your workflow first](#decide-your-workflow-first)
> before you run a single command.

| old plugin id | new plugin id |
|---|---|
| `specialists@claude-code-specialists` | `dkj-subagents-alpha@dkj-claude-plugins` |
| `specialists-lifehub@claude-code-specialists` | `dkj-subagents-lifehub@dkj-claude-plugins` |
| `specialists-shopify@claude-code-specialists` | `dkj-subagents-shopify@dkj-claude-plugins` |
| `specialists-ecomm@claude-code-specialists` | `dkj-subagents-ecomm@dkj-claude-plugins` |
| `specialists-workflow-davekjohn@claude-code-specialists` | `dkj-policy@dkj-claude-plugins` |

Every plugin is now either a **team** (who the specialists are) or a **workflow** (how work moves
through the repo) — see
[Teams and workflows](README.md#teams-and-workflows--whats-the-difference) in the root README for
what each one is and does. Teams stack, exactly as your old plugins did; a workflow does not, which is
the one genuinely new rule in this table rather than a renaming of an old one.

### Decide your workflow first

**Which half of this applies to you depends on one thing: whether you had
`specialists-workflow-davekjohn` enabled.**

- **If you did**, its replacement in the table — `dkj-policy` — is a workflow, so a
  straight swap carries your answer across and you are covered -- note that the id has been renamed twice
  since: from `workflow-davekjohn` to `contributing-davekjohn`
  ([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)) and from that to `dkj-policy`
  ([#1437](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1437)), so the name in the table
  is the one to enable.
- **If you did not**, the table gives you back every team and leaves you with **no workflow enabled at
  all** — because none of the ids you are removing was one, so the swap has nothing to carry over.
  That is the case for every consumer in this project's own register, and it is the part of the
  migration that will not announce itself afterwards: your session keeps working, your specialists
  keep answering, and nothing says that a question which did not use to exist now sits unanswered.
  Enabling none is a legitimate answer and the session check stays deliberately quiet about it — which
  is exactly why nothing will remind you.

Decide on purpose, before you touch a command, whether you want the one plugin that answers it:

- **Nothing enabled** — a complete answer, and the ordinary one. Your repo keeps the conventions it
  already has, and the specialists work against those with plain git/gh. A `workflow-default` plugin used
  to occupy this position and describe it as a workflow of its own; it was removed on August 26, 2026
  ([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)), because an empty slot needed
  no plugin to represent it.
- **`dkj-policy`** — the specific branch, changelog and release model. It asks your repo for two
  files it reads, `scripts/repo-config.ps1` and `scripts/lib/branch-info.ps1` — already covered under
  [Enabling the workflow](#enabling-the-workflow), which applies here unchanged: the `specialists-init` run
  under [After the reinstall](#after-the-reinstall) below scaffolds both.

Install it, or deliberately do not. **Neither is a real answer** — the specialists then use plain
`git`/`gh` and follow whatever your repo already does — and nothing will ever remind you of that state,
which is the whole reason to pick it on purpose rather than by omission. There is no longer a second
workflow to be refused alongside it, and no session check counting them: both went with `workflow-default`
on August 26, 2026. Carry your choice into the install command below.

### The command sequence

Refresh before you touch anything else: `install` does not do it for you, and a stale cache serves a
plausible-looking, previous version with no error to say so — the full measurement is under
[Staying up to date](#staying-up-to-date). Then take out every old id you had enabled, then put in its
replacement plus the one workflow you decided on above, then restart.

> **The order below looks wrong and is not, and this is the one thing worth measuring rather than
> reasoning about.** The refresh replaces the marketplace catalogue with one that lists only the NEW
> ids, and the uninstalls that follow name the OLD ones — so the obvious worry is that the CLI refuses
> to remove a plugin its catalogue no longer advertises. **Measured on 2026-08-09**, on the source repo
> itself, in exactly this order: after
> `claude plugin marketplace update claude-code-specialists` the uninstalls of
> `specialists@claude-code-specialists` and `specialists-workflow-davekjohn@claude-code-specialists`
> both returned `✔ Successfully uninstalled plugin`. `uninstall` resolves against your install record,
> not against the catalogue. What is *not* claimed here is anything about whether `uninstall` refreshes
> the cache — nobody has tested that, and this page has been caught generalising an untested claim from
> one verb to another once before.

```powershell
# 1. Refresh -- do this first, every time
claude plugin marketplace update claude-code-specialists

# 2. Uninstall every old id you had enabled -- skip whichever you never enabled.
#    Keep the OLD @claude-code-specialists spelling: uninstall resolves against your
#    install record, which still holds it, not against the catalogue.
claude plugin uninstall specialists@claude-code-specialists --scope project
claude plugin uninstall specialists-lifehub@claude-code-specialists --scope project
claude plugin uninstall specialists-shopify@claude-code-specialists --scope project
claude plugin uninstall specialists-ecomm@claude-code-specialists --scope project
claude plugin uninstall specialists-workflow-davekjohn@claude-code-specialists --scope project
```

```powershell
# 3. Re-register the marketplace under its new name -- the marketplace itself was
#    renamed on the flag day, so your machine must drop the old registration and add
#    the new one. A plain refresh cannot do this: the name is part of the id.
#    The `remove` is MACHINE-WIDE and is the only command here that is. It drops EVERY
#    install record keyed on the old marketplace -- every plugin and every checkout,
#    not just the ids step 2 named. So it ends the migration of every OTHER checkout
#    on this machine early, AND it takes this checkout's other plugins with it, which
#    is why step 4 below puts back every plugin you had, not just the renamed ones.
#    The `add` is per checkout -- that is what --scope project means.
#    With more than one checkout, read "If this machine has more than one checkout"
#    above first: there you skip the remove and start at the add.
claude plugin marketplace remove claude-code-specialists
claude plugin marketplace add DKJ-Solutions/dkj-claude-plugins --scope project

# 4. Refresh the new marketplace, then install the new ids
claude plugin marketplace update dkj-claude-plugins

# 4a. The core team -- everyone runs this one
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project

# 4b. The add-on teams -- ONLY the ones you uninstalled in step 2. Delete the other lines.
claude plugin install dkj-subagents-lifehub@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-shopify@dkj-claude-plugins --scope project
claude plugin install dkj-subagents-ecomm@dkj-claude-plugins --scope project

# 4c. The workflow -- opt-in. Uncomment it only if you deliberately want this method.
# claude plugin install dkj-policy@dkj-claude-plugins --scope project
```

**5. Restart your Claude Code session.**

`--scope project` is not optional here any more than it is anywhere else on this page — see
[Step 1](#step-1--enable-and-install) for what it costs to leave off. Expect the uninstalls, the
`marketplace add`, and the installs to rewrite `.claude/settings.json` on the way, the same rewriting
behaviour [documented above](#connecting--the-install-step): the old `enabledPlugins` entries come out,
the new ones go in, the marketplace source key is repointed at `dkj-claude-plugins`, and any diff beyond
that is formatting.

### After the reinstall

Once the new session comes up, re-run `specialists-init` (see [Step 2](#step-2--run-the-bootstrap-skill)
above). It is purely additive, so a repo that already has its seam, its lenses and its roster keeps all
of that; it only adds what the newly installed plugin brings — a new add-on team's specialists, or
`dkj-policy`'s two script scaffolds. Then verify the same way a fresh install does: the
`installed_plugins.json` query under [Step 1](#step-1--enable-and-install) above, read against your new
ids rather than your old ones. One `project` line per plugin you just installed, each ending in
`payload present`, is what you are checking for — the count is part of the check here exactly as it is
for a first-time adopter.

### The two things inside your repo that the id swap does not fix

**Re-running `specialists-init` will not repair either of these, and that is correct rather than a
shortcoming: it never overwrites** (inbound
[#555](https://github.com/DaveKJohn/claude-code-specialists/issues/555), measured on 2026-08-09 in a repo
that had just completed the swap). Its report says so out loud —

```text
[keep]   .claude/specialists/SPECIALISTS.md already exists -- not overwritten.
[keep]   CLAUDE.md already has the orchestrator import(s).
Done: 0 persona-lens(es) created, 4 already present; 0 lens-scaffold(s) created, 21 already present; ...
```

— so both repairs below are yours to make by hand, once, in your seam. `sync-roster` does not do them
either: it creates missing lens scaffolds and prints roster rows to paste, and it never rewrites an id that
is already there or touches an import. That is what it says of itself; this is a gap beside it, not a bug
in it.

**1. The `@`-import of the orchestrator's body names a path inside the marketplace clone, and that path
changed too.** Two things moved at once — the plugin's **id** and its **directory** — and only the first is
in the table above.

**And there is more than one "before", so test by SHAPE rather than by matching a literal.** The directory
moved twice under the old plugin ids, and which of the two your import names depends only on when you last
updated — a fact your file does not state. The reliable test needs no version at all:

> **Any import whose path does not contain `plugins/dkj-subagents/<team>/` or `plugins/dkj-policy/`
> is stale, whatever it contains instead.**

The second half of that test moved on September 5, 2026
([#1467](https://github.com/DaveKJohn/claude-code-specialists/issues/1467)): `plugins/workflows/` became
`plugins/dkj-policy/`. It costs a reader nothing in practice — a workflow ships no personas and no
manuals, so nothing imports out of one — and the shape test names it only so the rule stays complete.

Every layout this family has shipped, measured against this repo's own tags — the first four are what
you might find, the last is what you are moving to:

| the layout your import names | shipped by | what a team's folder looked like |
|---|---|---|
| the two-level product folder | `v1.1.0` – `v3.1.2` | `claude-code-plugins/claude-specialists/specialists/` |
| the flat plugin folder | `v3.2.0` – `v3.9.0` | `plugins/specialists/` |
| the teams/workflows split | `v3.10.0` – `v4.30.0` | `plugins/teams/team-alpha/` |
| the `dkj-` prefix | `v4.31.0` – `v4.32.0` | `plugins/dkj-teams/dkj-team-alpha/` |
| **current** — the team side renamed to subagents | `v4.33.0` onward | `plugins/dkj-subagents/dkj-subagents-alpha/` |

**Every path in that table is quoted as its own tag holds it — do not sweep it.** The whole point of the
column is that a reader on an old version can recognise their own spelling, so rewriting the historical
rows into today's names empties the table of the only thing it is for. It happened once already: the last
three rows were a single `v3.10.0`-onward row carrying the `dkj-subagents` spelling, which no release
before `v4.33.0` ever held (#2144).

Read the same five rows for an add-on team (`specialists-shopify` → `plugins/dkj-subagents/dkj-subagents-shopify/`) and
for the workflow — with one exception worth knowing before you go looking for it: the workflow plugin
**first shipped in `v3.8.0`**, so it never existed under the two-level layout; its flat form was
`plugins/specialists-workflow-davekjohn/`. There is no two-level form of that path to find.

So the line in your `.claude/specialists/SPECIALISTS.md` changes as follows — **bound to this repo's
layout at `v5.5.0`, which is the last row above, and to the marketplace name `dkj-claude-plugins`;
substitute yours if you registered it under another name**:

```text
# before -- EITHER of these, depending on how long ago you last updated
@~/.claude/plugins/marketplaces/claude-code-specialists/claude-code-plugins/claude-specialists/specialists/personas/01-01-persona.md
@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/specialists/personas/01-01-persona.md

# after -- the line you want
@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-subagents/dkj-subagents-alpha/personas/01-01-persona.md
```

**If neither literal matches your file, do not conclude the repair is not yours** — apply the shape test
above instead. That is the failure this section is written around: a consumer searching for a quoted
line, finding nothing, and reasonably reading that as *"this one does not apply to me"* while their
orchestrator runs bodyless. If you want to know which form to expect before you look, the verification
query in [Step 1](#step-1--enable-and-install) prints the version and commit your install record names —
run that one rather than a shortened variant, for the reasons stated there.

**This one fails silently, which is why it is first.** Claude Code drops an `@`-import it cannot resolve
**without a word**: the roster around it renders, the session looks entirely normal, and the orchestrator
runs without its ritual and its delegation rules. The one thing that will tell you is the core team's
`roster-sessioncheck` hook, which reports it as a blocking `[ERROR]` at session start — it did exactly that
in the measured case. If you would rather not construct the path yourself, read it off this repo, which
consumes its own plugin: its
[`.claude/specialists/SPECIALISTS.md`](.claude/specialists/SPECIALISTS.md) carries the import in its
current, correct form.

**2. Every `<plugin>:<name>` id in your roster still names a plugin that no longer exists.** The
**names did not change** — 21 of them in the measured case, all still present — so this is purely the
prefix, which is exactly the kind of mechanical rename a reader's eye slides over:

| before | after |
|---|---|
| `specialists:paula` | `dkj-subagents-alpha:paula` |
| `specialists-lifehub:<name>` | `dkj-subagents-lifehub:<name>` |
| `specialists-shopify:liam` | `dkj-subagents-shopify:liam` |
| `specialists-ecomm:sergio` | `dkj-subagents-ecomm:sergio` |

**The rename changes no count, which is worth knowing before you start editing.** In the measured repo — three
teams enabled — it was 4 personas + 21 subagents = 25 both before and after, every name still present. For
`dkj-subagents-alpha` on its own the figures are the ones [Step 2](#step-2--run-the-bootstrap-skill) prints. So if a
count moves while you are rewriting prefixes, you have edited one line too many.

### If you call the shared workflow scripts yourself

**Two things `dkj-policy@4.0.0` changed that a consumer building on those scripts has to act on**,
neither of which was named as a breaking change when it shipped (inbound
[#556](https://github.com/DaveKJohn/claude-code-specialists/issues/556) and
[#557](https://github.com/DaveKJohn/claude-code-specialists/issues/557), both measured on 2026-08-09). If
you only ever invoke the skills, both are handled for you and you can skip this.

**`scripts/release/new-changelog-entry.ps1` is gone.** It existed in `specialists@3.1.2` and does not exist
in `dkj-policy@4.0.0`; what it did now lives in `scripts/lib/entry-scaffold-lib.ps1` plus
`scripts/task/new-branch.ps1`. Resolved through the documented seam it fails **loudly** — the lookup says
the script does not exist in the plugin — so nothing goes quietly wrong; the problem was that nothing said
it was coming.

- **What to call instead: `scripts/task/new-branch.ps1 -Name <branch> -Title "<title>"`.** The obvious
  objection is that it also *creates* a branch, and the case the old script served is a branch that already
  exists — a Dependabot PR, say. It handles that: the script is **idempotent on an existing branch**, it
  checks the branch out rather than failing, and writes the two files beside it. So the replacement covers
  the old caller after all; it simply does more than the name it replaced.
- One difference to expect: a branch prefix your own table does not know (`dependabot/…`) is a **soft
  warn**, not a refusal, and the entry's type falls back to whatever `Get-EntryFallbackType` says.

**The branch's own file moved out of your repo root.** A branch used to carry `<branch-name>.md` beside
your `README.md`; it now carries one `dkj-policy/<branch>.md`, which holds both jobs as
sections — `### PLAN` / `### CREATE` / `### TEST` for what still has to happen, and
`### DEPLOY: <branch>` for what the change does. It was a pair under `dkj-policy/branch/`
between August 6 and August 23, 2026, with reference copies under `branch/templates/`; both are gone, and
the guidance those copies held is inside the document.

- **Look for a gate keyed on the old name before you use the `new-branch` skill.** The measured case was a
  CI step asserting that `"$(echo "$BRANCH" | tr '/' '-').md"` exists in the repo root — which fails
  **after** the work is done rather than before it starts. Nothing but reading both files together would
  have warned you.
- **Your branches already in flight are safe.** The fold, the PR gate and the lint all still recognise a
  root `<branch>.md` **and** either `branch/` pair — "recognise every one, write one" — so nothing has to be
  migrated in a hurry. It is the *gate* that has to learn the new location, not the entries. The resolver
  reads which file NAMES your branch rather than which one exists, which is what keeps a half-finished
  branch whole after the trunk gains the new document.
- **Nothing is generated beside the document any more.** `branch/templates/` was written into your repo and
  refreshed on drift, because the file you typed in was deliberately bare. The merged document carries its
  own guidance, so there is one fewer directory and nothing left for you to keep current.

**And one seam function in your `scripts/repo-config.ps1` may now be dead code.** `Get-ChangelogHeading`
named the `##` section a folded entry was filed under; `CHANGELOG.md` has no section headings any more — it
is an intro, then `## [Unreleased]`, then one `###` per change — so nothing reads that function, and `check-script-contract`
no longer names it either (inbound
[#561](https://github.com/DaveKJohn/claude-code-specialists/issues/561)). **Nothing reports this**, which is
the point of mentioning it: if you still define it, possibly with a test around it, it answers a question
nobody asks. Delete it when convenient; leaving it costs nothing but a reader's time.

That retirement has a consequence worth knowing before your next fold, and it is the one thing in this
section that is not merely tidy-up: **the shared scripts now assume your `CHANGELOG.md` is that flat list.**
If yours still carries section headings, `cut-release.ps1` refuses by name — and `fold-changelog-entry.ps1`
now refuses too, listing each `##` block it cannot read and leaving your entry file untouched. **That second
refusal is on `main` and reaches you at your next refresh, whether or not a release has been cut** — the
cached clone tracks `main` rather than the tag, which is the asymmetry
[the version is not the code](#staying-up-to-date) describes. Until it arrived, the fold wrote the entry
**above** your first section heading and reported success, visible only if you opened the file afterwards.
So: migrate the document, or keep folding by hand — both are answers, and the refusal tells you which blocks
are in the way.

### If your lenses sit on the pre-seam path

**A named caveat, stated as it stands rather than smoothed over: this has not been repaired in code.**
A repo lens lives in one of two places — the seam (`.claude/specialists/lenses/`, which does not name
any plugin) or, for a repo that adopted before the seam existed, the pre-seam path
`.claude/plugins/claude-specialists/<plugin>/`, where `<plugin>` is the plugin's own folder name. On
that second path the plugin name is part of the path a reader constructs, and this migration changed
exactly that name — `specialists` became `dkj-subagents-alpha`, `specialists-shopify` became `dkj-subagents-shopify`, and
so on for the rest of the table above. A repo still on the pre-seam path is therefore left looking for
its lenses under the *old* folder name while every specialist now reads from the new one, and finds
nothing there.

This has not been fixed by a script or a lint rule, because no consumer in this repo's own connector
register is confirmed to be in that state — repairing a state nobody has been measured to occupy would
be exactly the pre-emptive fix this family's own working method argues against building. If it does
bite you, the fix is one `git mv`: rename that one directory from the old plugin name to the new one
(`git mv .claude/plugins/claude-specialists/specialists .claude/plugins/claude-specialists/dkj-subagents-alpha`,
and the matching rename for any add-on team you had) — or, the better long-term move, since it is what
this page already recommends to anyone still on that layout regardless of this migration, move onto the
seam instead, per [The seam, specified](README.md#the-seam-specified) in the root README.

**The seam itself is unaffected by all of this, and most readers are already on it.**
`.claude/specialists/lenses/` does not encode a plugin name anywhere in its path, so nothing about this
rename touches it, and nothing about the content of any lens you have written changes either — see
[What does not change](#what-does-not-change) next.

### What does not change

- **Skill names.** Only the plugin prefix in front of them moved; the names themselves — `new-branch`,
  `open-pr`, `specialists-init`, and the rest — did not.
- **The marketplace name**, `dkj-claude-plugins`, and the source you registered it under in
  `extraKnownMarketplaces`.
- **The lens-family path segment**, `claude-specialists`, used by a pre-seam lens directory (see above)
  — it names the family, not any one plugin, so this rename does not touch it.
- **The seam itself**, `.claude/specialists/`, and everything under it — your roster, your routing
  table, your chains.
- **Your repo lenses' content.** Nothing about what you wrote in them changes; only where a plugin
  folder is found, for the pre-seam layout specifically, does.

---

## Adoption — how to connect your repo

This page is for those who did **not** build the Claude Specialists system: a colleague with a repo
of their own who wants to work with the specialists team. Everything below is the common thread —
the deeper explanation sits behind the links and is deliberately not repeated here.

**Why the procedure is what it is** — which step was added when, and what was measured to justify it —
is not on this page. It lives in the release record: [`releases/history.md`](dkj-policy/releases/history.md)
indexes every version with the changes behind it. This page tells you what to do; that one tells you
why it changed.

> **Budget well over an hour, and know where it goes.** Measured August 6, 2026: this file is ~9,300
> words (~47 min at 200 wpm) and
> [`specialists-init`'s `SKILL.md`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md) another ~5,600
> (~28 min) — call it **~75 minutes** for a first-time adopter. Both pages grow, so treat
> that as an order of magnitude. The time is not in the typing: the bootstrap places the whole seam in
> seconds. It is in **Step 4**, writing your roster and filling your lenses.

### What you get

Instead of one generic Claude, you work with a **team of specialized Claudes under one Chief of
Staff (Chris)**: every assignment is classified and delivered to the specialist with the right
playbook — a DevOps engineer for branches and PRs, a technical writer for docs, a copy editor
and code/security reviewers for the independent final pass before a PR or merge. Your repo stays in
charge: the governance (your `CLAUDE.md`, your safety rules) remains yours; the plugins only supply
the team and its playbooks.

The system consists of **teams and a workflow**: the repo-neutral core team `dkj-subagents-alpha` (always
enable it), three optional add-on teams, and exactly one **way-of-working** plugin, chosen from the two
the marketplace offers. Which specialists live in which plugin and who they are meant for is covered in
the [root README](README.md).

**The workflow slot is different in kind, so decide about it deliberately rather than by habit — and
"decide" now means deciding whether to fill it at all.** One plugin answers "how does work move through
this repo": `dkj-policy`, which carries no specialists at all but is DaveKJohn's own branch,
changelog and release method as skills plus scripts (`new-branch`, `open-pr`, `ship-pr`,
`fold-changelog`, `cut-release`, `park`, `fix-mojibake` among others). **Leaving the slot empty is the
default and a complete answer** — your repo keeps its own conventions, which it never stopped having.
A second plugin, `workflow-default`, used to be enabled here to represent that emptiness; it was removed
on August 26, 2026 ([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886)). Two
consequences worth knowing before you enable the one that is left:

- **Enabling it later is a plain enable + re-run of `specialists-init`**, which then adds the
  config it needs. Nothing has to be undone first.
- **Enabling it makes your repo owe it two files** — `scripts/repo-config.ps1` (repo name, lint gate)
  and `scripts/lib/branch-info.ps1` (your branch-prefix table). `specialists-init` scaffolds both, and a
  session check tells you if a function is missing. Enable nothing and you are asked for neither.

### Before you start

**Three things have to be true before Step 1's first command, and none of them used to be written down
anywhere in this family** (inbound
[#334](https://github.com/DaveKJohn/claude-code-specialists/issues/334), measured August 1, 2026 on a
**virgin Windows user profile**, CLI `2.1.220`). On a machine that has been in use for a while all three
were satisfied long ago — which is exactly why they stayed invisible until someone adopted this system
on a new profile.

1. **Claude Code is installed and `claude` actually runs.** This page assumes a working `claude` and
   deliberately prints no install command of its own — it would go stale here. Start at Anthropic's
   [setup documentation](https://code.claude.com/docs/en/setup) instead. `claude --version` is the
   check; `claude doctor` prints read-only diagnostics when it fails.
2. **You are signed in.** Authentication hangs off your user profile, so on a fresh profile this is a
   real step even when the binary is already on the machine.
3. **On Windows, raise the execution policy — otherwise none of the PowerShell blocks on this page
   run.** A fresh Windows profile defaults to `Restricted`, which blocks **every** `.ps1`, and on an npm
   install `claude` itself resolves to one: measured, `ExternalScript …\npm\claude.ps1` comes ahead of
   `Application …\npm\claude.cmd`. So `claude plugin marketplace update …` — Step 1's first command —
   fails with a `PSSecurityException` on an untouched profile. One command settles it; no administrator
   rights, and it touches nothing under `~/.claude`:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

#### Which of the three machine states are you in?

**The two above are a *virgin profile* and a machine where all three were satisfied long ago. There
is a third, and it is the most likely one for anyone reading this page a second time** (inbound
[#401](https://github.com/DaveKJohn/claude-code-specialists/issues/401), measured August 3, 2026): a
machine that has adopted this family **before** and whose teardown never reached
[`UNINSTALL.md`](UNINSTALL.md) Step 5 — *"the one removal no command does for you"*. That page says
outright that Step 5 is manual, so a leftover **user-scope marketplace registration** is the
*expected* condition of any second adoption, not an accident of one machine.

Two commands identify it before you start:

```powershell
claude plugin marketplace list
Get-Content "$env:USERPROFILE\.claude\settings.json"
```

If `~/.claude/settings.json` still carries an `extraKnownMarketplaces` entry for this family, you are
in this state. What follows from it:

- **Step 1's restart act — and its `marketplace add` alternative — are silently unnecessary.** The
  marketplace already resolves, machine-wide. Measured: with the two keys freshly written into the
  repo's own `.claude/settings.json`, **in the same session and with no restart**,
  `claude plugin marketplace update` returned `✔ Successfully updated marketplace` and `exit=0`.
- **So #329's failure message will not appear — and its absence is not evidence that anything
  worked.** A reader who notices the page predicted a failure that did not happen has nothing to look
  it up in, and the natural reading (*"my state is ahead of the document, so maybe other acts are
  optional too"*) is exactly the wrong lesson before act 3, which is load-bearing.
- **And your repo's own `extraKnownMarketplaces` key is never exercised.** The marketplace resolves
  from user scope; the project-scoped key contributes nothing to the run. Type the repo slug wrong,
  or paste the block into the wrong `.claude/` (the [#335](https://github.com/DaveKJohn/claude-code-specialists/issues/335)
  confusion), and you still get a green refresh, a green install and healthy `project` records — the
  verification query in act 6 **cannot** catch it, because it reads `installed_plugins.json`, which
  says nothing about how the marketplace was found. The defect surfaces later, on another machine or
  once the user-scope key is finally removed, with nothing connecting it back here.

The one-line close is in act 3 below: after the refresh succeeds, run `claude plugin marketplace list`
and confirm the entry came from **your repo's** settings. This is the page's own discipline (*"a
record is a claim, not evidence"*, *"verify it by the surface"*) applied to the half of Step 1 that
had no check at all.

**If `claude` is still not found right after an install, close your editor completely rather than
opening another tab.** Every window spawned from a running editor inherits that editor's environment,
so a `PATH` that was just extended is invisible in a new tab or a terminal opened from it. Honest
scoping: this one is partly an artefact of the route that measurement took — npm was chosen there to pin
a specific CLI version, and Anthropic's own Windows installer handles `PATH` itself. It is here as a
symptom worth recognising, not as a step of this procedure.

**And if you are handing this page to an agent instead of reading it yourself, have it read the file
rather than a summary of it.** That is a plausible first move for a new consumer — paste the link into
Claude Code and say *"set this up for me"* — and it was measured (inbound
[#338](https://github.com/DaveKJohn/claude-code-specialists/issues/338)): `WebFetch` on the raw URL refused
a verbatim request outright, and on an ordinary summarising question it returned content that did not
match the file. It described the document as *"8,000+ characters"*, a fraction of its real size, and it
**invented an enumeration for Step 2** that this page does not contain. Nothing here can fix a fetching
tool; two things do work. Save the raw file to disk and have the agent read it from there, or point it at
the marketplace clone once you have one — and check any count it quotes against the document itself,
because the counts on this page are load-bearing.

#### If an agent is doing this for you — where it has to stop

**The paragraph above is about *reading* the page. This one is about *executing* it, and the two have
different answers: the procedure below contains acts an agent structurally cannot perform** (inbound
[#402](https://github.com/DaveKJohn/claude-code-specialists/issues/402), measured August 3, 2026 during a
delegated adoption from the instruction *"here is the link, install the plugin"*). Of Step 1's six
acts an agent can do four; of the five steps it can complete two.

| Act / step | Agent | Why |
|---|---|---|
| Step 1 act 1 — write the two settings keys | ✅ | An ordinary file edit. |
| Step 1 act 2 — **restart the session** | ❌ | It runs *inside* the session it would restart. |
| Step 1 act 3 — `marketplace update` | ✅ | |
| Step 1 act 4 — `install`, per plugin, `--scope project` | ✅ | |
| Step 1 act 5 — **restart the session** | ❌ | Same reason as act 2. |
| Step 1 act 6 — the `projectPath` verification query | ✅ | Ran verbatim under Windows PowerShell 5.1, no adjustment. |
| Step 2 — `specialists-init` | ❌ | The skill ships in the plugin only the *next* session loads. |
| Step 3 — Chris takes the floor | ❌ | Same restart. |
| Step 4 — the adopt skills | ✅ | Skills of plugins the session has already loaded, and a dry run first. |
| Step 5 — roster and lenses | ⚠️ | Possible, but it is authoring about *your* repo — see Step 5. |

`/reload-plugins` is not a way out, and this page already says so under
[Staying up to date](#staying-up-to-date) for a different reason: it does not load a skill file that
was not loaded before.

**So the correct end of a delegated Step 1 is a handoff, and the agent should say so rather than
work it out.** What it hands back: the output of act 6, and the two acts plus two steps that remain,
in the order they must happen. What makes this worth spelling out is that the state it stops in is
**the one state that reads as healthy from every angle** — three correct `project` records, right
sha, payload on disk, and a session with no `specialists-init` and no Chris. Identical in symptom to
the [#327/#355 failure](#connecting--the-install-step) this page teaches you to fear, and benign: the
restart simply has not happened yet. An agent that does not know this has two plausible wrong moves —
report `✔ Successfully installed` and call the adoption done, leaving a consumer who believes they
have the specialists and has never seen one; or go looking for `specialists-init`, not find it, and
conclude the install failed, at which point every diagnostic on this page points it at a broken
record instead of a pending restart.

One wording note, because it is the line that produced the confusion: Step 2 says *"in the new
session, invoke `specialists-init`"*. For a delegated adoption there is no shared reading of who
"you" is at that line — the natural one is that whoever executed Step 1 continues, and that reading
is impossible to satisfy.

### Connecting — the install step

> **One *step* here, six *acts* inside it — a different unit, not a different path.** Step 1
> below is enable → **restart** → refresh → install → restart → verify, which the
> [root README](README.md#adoption-the-bootstrap-path) and
> [`specialists-init`](plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md#chicken-and-egg--step-0-is-done-by-the-user)
> both count as its six acts ("step 0" in their numbering). Saying so is the point: those two pages once
> counted the same procedure as *four* and *three*, and this page's step count made a third number
> (inbound [#297](https://github.com/DaveKJohn/claude-code-specialists/issues/297)). Nothing was missing from
> any of them — but if you are cross-reading and the counts differ, the count is exactly what you would
> use to check whether you skipped something.

**Step 1 — enable *and* install the plugins.** The first half is one file: **your repo's own**
`.claude/settings.json`. `.claude/` is a directory in the root of your repository, beside your
`README.md` — **create it if it is not there**, and on a repo that has never used Claude Code it will
not be.

> **`.claude` means two different places in this document, and from here on the difference matters**
> (inbound [#335](https://github.com/DaveKJohn/claude-code-specialists/issues/335)). `.claude/` in **your
> repo** holds your settings, your seam and your lenses; it travels with the repo and it is yours.
> `~/.claude/` — on Windows `$env:USERPROFILE\.claude` — is the **machine** administration: the
> marketplace clone, the plugin cache, and the `installed_plugins.json` that the verification query
> below reads. Same name, two locations. Wherever this page prints a full path, it means the machine
> one. On the fresh profile this was measured on, neither existed yet, and one consumer reasonably read
> *"in your repo's `.claude/`"* as something still to be **installed** rather than **created**.

Set the marketplace source and the plugins you want in it (always the core team; a workflow only if you
deliberately want `dkj-policy`'s method — there is no default one, see
[Enabling the workflow](#enabling-the-workflow) in the quickstart half; an add-on team only if your repo has
that domain). What follows is a **complete, pasteable file** — if you already have a
`.claude/settings.json`, merge these two keys into the object that is there instead of pasting over it:

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

Claude Code parses that file as **strict JSON**: no comments, no trailing commas. An earlier version of
this page printed the two keys as a `jsonc` fragment — comment line on top, no outer braces — which does
not parse when pasted as printed, and `jsonc` as a label suggests the comment would be fine (#335).

This repo is public, so the source can be read without GitHub authentication; Claude Code clones
and caches it by itself. **But writing those keys is not the whole of Step 1, and the order is not
free.**

**First: restart your Claude Code session once, now.** The marketplace is registered by a **session
start**, not by writing the key — measured in three states on a virgin profile (inbound
[#329](https://github.com/DaveKJohn/claude-code-specialists/issues/329)): without the settings file the
refresh command below fails; **with** the settings file, in the same session, it still fails; after one
session start in the repo it succeeds. The failure is easy to misread — on CLI `2.1.220` it reads:

```
✘ Failed to update marketplace(s): Marketplace 'claude-code-specialists' not found.
  Available marketplaces: claude-plugins-official
```

The wording is version-bound and may differ on your CLI; what does not vary is that a "not found" here
means the marketplace has not been registered yet, never that you typed the name wrong. That reads as a
typo in the name, and it is not — it is a missing step. Until this was measured it was
the state of the very first executable command on this page for every consumer who had never had this
marketplace: a dead end, with nothing in the document to get past it.

**If you would rather not restart at that point**, `claude plugin marketplace add` registers it inside
the running session — measured, the refresh below then succeeded immediately, no restart. Two things to
get right, because this command does not follow the pattern of the others on this page:

```powershell
claude plugin marketplace add DKJ-Solutions/dkj-claude-plugins --scope project
```

It takes a **source** (a URL, path, or GitHub repo) where everything else here uses the marketplace
*name*, and it defaults to `--scope user`, which would declare the marketplace machine-wide in
`~/.claude/settings.json` rather than in your repo's — the
[#279](https://github.com/DaveKJohn/claude-code-specialists/issues/279) defect, rebuilt in a fourth command.
The `--scope project` above comes from the CLI's own `--help` (`user (default), project, or local`, CLI
`2.1.220`); #329's measurement was taken at the default scope, so treat the flag as documented rather
than measured and confirm with `claude plugin marketplace list` where it landed. Note also what `add`
does *not* do: measured, it left `installed_plugins.json` at `{}` and loaded no skills or subagents into
the running session. It makes the marketplace findable and installs nothing.

**Then the install** — an install is *per repo*, so run one command per plugin you listed, from the root
of your repo, preceded once by a refresh of that cached clone:

```powershell
claude plugin marketplace update dkj-claude-plugins                     # 1. refresh the cache first
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project    # 2. then install, per plugin
# and line 2 again for each add-on team you enabled, and for dkj-policy if you enabled it
```

**Line 1 matters most right here, because this is the command the failure was measured on.** Without
it, the install happily gives you the **previous** version and reports `✔ Successfully installed` —
measured on July 30, 2026 with a fresh `install`, not an `update` (the full account, and what `update`
does differently, is under [Staying up to date](#staying-up-to-date)). A stale cache produces a green line and a plausible
version number, so the only symptom is a session quietly missing whatever the release added. That is
easily mistaken for the restart problem described under
[Staying up to date](#staying-up-to-date) — a new skill needing a session restart — and is a
different cause with a different fix.

**And when line 1 succeeds, check *where the marketplace came from* before you run line 2.** This is
the one check act 3 lacked, and it costs a command (inbound
[#401](https://github.com/DaveKJohn/claude-code-specialists/issues/401)):

```powershell
claude plugin marketplace list
```

A green refresh proves the marketplace resolves — not that it resolved from **your repo**. On a
machine carrying a leftover user-scope registration (see
[Which of the three machine states are you in?](#which-of-the-three-machine-states-are-you-in)) the
refresh, the install and the record query all come back green while the key you just pasted
contributed nothing. That is the state where a mistyped repo slug, or a block pasted into the wrong
`.claude/`, survives every check on this page and surfaces on somebody else's machine.

**Keep `--scope project` on that line.** `claude plugin install` defaults to `--scope user`, which
installs machine-wide and writes no `projectPath` at all — so you would get the one thing the
sentence above says this step is for, wrong, without any error. Same flag on the way back out:
`claude plugin update` has the same default and simply fails on a project-scoped install (see
[Staying up to date](#staying-up-to-date)).

**Expect that install to rewrite the `settings.json` you just wrote** (inbound
[#295](https://github.com/DaveKJohn/claude-code-specialists/issues/295)). This is worth saying out loud
because `.claude/settings.json` is usually a **tracked** file, so the change shows up in `git status`
and looks like something went wrong. Measured on July 31, 2026 in throwaway repos with
`core.autocrlf false`: `claude plugin install … --scope project` re-serialises the whole file — key
order changes, nested objects get expanded onto separate lines — and in two of the fixtures it also
**removed a UTF-8 BOM** and **added a missing final newline**. It may also write LF into a CRLF file
(git says `LF will be replaced by CRLF the next time Git touches it`), which on a Windows repo is a
second, lasting source of diff.

**Whether that diff is only formatting depends on one thing: was `enabledPlugins` already there?**
Both halves are measured (inbound
[#303](https://github.com/DaveKJohn/claude-code-specialists/issues/303), July 31, 2026):

- **Key already present** — the order above, where act 1 (enable) writes it before act 3 (install) runs.
  Then the content stays **equivalent**: no plugin is switched on that was not on before, and any diff is
  formatting. What you cannot count on is that there will be **no diff at all**. An earlier edition of this
  page said the file stays *byte-identical* and that *"the install writes only when there is something to
  write"*, on the strength of a single SHA256 comparison in `claude-code-specialists`. Round v10 falsified the
  general form (inbound
  [#336](https://github.com/DaveKJohn/claude-code-specialists/issues/336)): on a fresh Windows profile, with the
  key present and written in exactly this order, `claude plugin install … --scope project` **rewrote the
  file anyway** — `enabledPlugins` moved in front of `extraKnownMarketplaces` and the nested `source` object
  was expanded onto separate lines. The likeliest reading is that the workshop's file already happened to
  match the serialiser's own layout, which makes the old claim true of *that file* rather than of "key
  already present" as a category. So: **expect a formatting diff even when the key is there, and expect no
  behavioural change.** Round v12 closed the evidence gap v10 left: a hash pair captured at the moment of
  the install, key already present, written in exactly this order — SHA256
  `F694FB44…BF15EFA8` (224 bytes) before, `EB8834F7…AB275E4A` (246 bytes) after. Not byte-identical, and
  the 22 added bytes are precisely the two changes described above. **Behaviourally equivalent, textually
  different** is now measured rather than inferred.

  **On the path this page prescribes, that pair is reproducible — so it is a check you can actually use**
  (inbound [#385](https://github.com/DaveKJohn/claude-code-specialists/issues/385)). Round v13 hit both hashes
  exactly, on a second profile: `F694FB44…BF15EFA8` at 224 bytes before, `EB8834F7…AB275E4A` at 246 after,
  and the +22 is the two changes described above, to the byte. That is not luck. Step 1 has you paste the
  printed block into a file that does not exist yet, so the "before" bytes are the block; and the CLI's
  serialiser is deterministic, so the "after" follows from it. Matching them tells you two things at once:
  you pasted the block intact, and the install did what it is supposed to do.

  **Only match them if that is the path you took.** An earlier edition of this line said the hashes were
  not something to match at all, which took a usable check away from the reader following the instructions.
  The warning still holds for everyone else: if you already had a `.claude/settings.json`, formatted it
  yourself, or merged the keys into an existing file, your two values will differ from these *and* from
  each other, and only the difference between them means anything.
- **Key absent** — then the install **adds `enabledPlugins`, with `true` per plugin**, and that is not
  formatting: it switches the plugins **on** in a tracked governance file. Measured in
  `DaveKJohn/life-hub`, which is deliberately plugin-clean between adoption rounds, so the key was
  nowhere. And this is not an exotic ordering: it is exactly what a **repair install** or a reinstall
  does — the prescribed move after a record has gone missing (see
  [Staying up to date](#staying-up-to-date)).

`claude plugin uninstall … --scope project` edits it too, on purpose: it removes your plugin's entry
and leaves `"enabledPlugins": {}` behind. All of it is the CLI's doing — the plugin's own scripts never
touch this file, which the `specialists-teardown` skill says of itself as well. So a **formatting** diff
here is expected rather than suspect; an **added `enabledPlugins` block** is the one change in this
paragraph you would want to see in code review. And if your repo has an opinion about JSON formatting,
this is the file that will lose the argument.

**What those two keys do on their own is an open question, and this page no longer claims they do
nothing.** It used to say so in bold. Measured on a virgin profile with the marketplace registered and the
cache present, a **single session start** — no command run, no file changed — wrote a full,
project-scoped install record with the correct `projectPath`, `version` and `gitCommitSha`,
indistinguishable from the one the install above produces (inbound
[#327](https://github.com/DaveKJohn/claude-code-specialists/issues/327)). The session that writes it still
loads nothing itself: the record is written *after* the load phase, so only the next session gets the
plugin. Whether that makes the two commands above redundant has not been tested end to end — so run
them. They are the route this page can vouch for, and one of them is what puts a version in the record at
all.

**Then restart your Claude Code session** and check that it worked — but **not with `claude plugin
list`**. That command is not repo-scoped: it reports install records beyond your repo, so it can show
a plugin as `enabled` in a repo that has no install at all. Check the record for *your* repo, from
its root:

```powershell
$root = (Get-Location).Path
(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |
  ForEach-Object { $n = $_.Name; $_.Value | Where-Object { $_.projectPath -eq $root } |
    ForEach-Object {
      $payload = if ($_.installPath -and (Test-Path -LiteralPath $_.installPath)) { 'payload present' } else { 'PAYLOAD MISSING' }
      "$n -> $($_.scope) $($_.version) $($_.gitCommitSha) [$payload]" } }
```

**One** `project` line per plugin you listed is what you want — the count is part of the check, not a
detail. **And it has to end in `payload present`.** The record names an `installPath`; nothing writes
that record and the files it points at in the same act, so the path can be absent while every other
field is correct. That last check is why this query has a fourth field at all — see the blockquote
below. The last field is the commit the payload came from, and it answers a different question than the
version does: see [Staying up to date](#staying-up-to-date) under *"the version is not the code"*. Empty output means nothing was installed here. *Two* lines for the same plugin is a stray second
record, which a repair install can create rather than prevent, and a line reading `local` was written by
a session start rather than by you; both are covered under
[Staying up to date](#staying-up-to-date). Do run it — if the install did not happen, the skill from
step 2 and the session hooks are simply absent, and that looks exactly like a session where everything
is fine.

> **The installed record with the inert session — the one state that reads as healthy from every angle**
> (inbound [#327](https://github.com/DaveKJohn/claude-code-specialists/issues/327)). Measured on a virgin profile:
> a **single session start**, with no command run, wrote a full `project`-scoped record with the correct
> version and sha — and **that same session loaded nothing at all**: no `specialists-*` skills, no subagents,
> no session-hook output, no routing announcement. The record is written *after* the session's load phase.
>
> **And the second measurement was a notch worse than the first** (inbound
> [#355](https://github.com/DaveKJohn/claude-code-specialists/issues/355), round v11). Above, the payload at least
> sat in the cache, so the *next* session got the plugin. Measured again on a fresh profile after **three**
> session starts and still zero `claude plugin` commands, the record read `project 3.1.0` with the right sha
> — and `installPath` pointed at a directory that **did not exist**. No cache directory, no payload, nothing
> to load in any session, ever. That is why the query above now checks the path instead of only the fields:
> a record is a claim, not evidence.
>
> Every angle you would normally trust says fine. The record says installed, project scope, correct sha. The
> checks that read that record agree. And the session is completely inert. So do not verify the adoption by
> the record alone — **verify it by the surface**: is `specialists-init` in your slash list, did the
> session-start hooks print anything, does Chris open the turn? `UNINSTALL.md` makes the same point from the
> other side (*"a session that loads no plugin has no hooks to complain"*), and it is the same discipline in
> both directions: absence of complaint is not evidence, because the thing that would complain is the thing
> that did not load.
>
> **What follows from this.** It is a second, independent reason why the `[NOT-INSTALLED-HERE]` marker never
> appears at a session start: not only has the state already been written away, there is **no hook running to
> report it** — the hooks ship in the plugin this session did not load.
>
> **And a session start does not make the two `claude plugin` commands redundant.** Measured: two keys, two
> restarts, six locations read without running a single command. A session start does *half* the job — it
> registers the marketplace and writes a complete, correct-looking record — but never fetches the payload.
> `marketplace update` + `install` are the pair that does.

**Steps 2 to 5 are on their own page now: [ADOPTION.md](plugins/ADOPTION.md).** Running the bootstrap skill,
verifying that the orchestrator took the floor, running each enabled plugin's adopt skill, and writing
your roster and lenses are the same work
whether you installed these plugins yourself or your organisation published them to you -- while
everything above this line is an install, which for many readers has already been done centrally and
must not be repeated. That is the seam, and inbound
[#664](https://github.com/DaveKJohn/claude-code-specialists/issues/664) is where it was measured.

### Staying up to date

Updates are *announced* via **releases** — the version bump and the notes — and
getting one takes **two** commands, from your repo's root. What actually lands in your cache is a
different question, answered under [the version is not the code](#staying-up-to-date) further down: the
clone these commands read tracks `main`, not the tag.

```powershell
claude plugin marketplace update dkj-claude-plugins          # 1. refresh the marketplace cache
claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project   # 2. then update, per plugin
```

The `plugin-versions` skill (shipped by `dkj-policy`) packages the installed-vs-clone comparison this
section describes into one read-only run, with a per-plugin verdict on which command — if any — closes
the gap. It reads the marketplace clone you already have, so it is a *staying-current* check, not a
substitute for the install verification above.

**Keep line 1 in the procedure — and here is exactly what each command was measured to do, because
the two differ and an earlier version of this page generalised them.**

- **`install` does not refresh the cache, and that is now measured twice.** First on July 30, 2026,
  minutes after `v3.0.2`: the cached clone still sat on the pre-release commit, so a fresh
  `claude plugin install … --scope project` produced **3.0.1**. Reproduced on July 31 right after
  `v3.0.5` was tagged, deliberately and as a **controlled pair on the same machine within the same
  minute**: without the refresh the install produced **3.0.4** and left the clone exactly where it was,
  and with the refresh a second fresh folder produced **3.0.5**. So the refresh is what makes the
  difference for this verb — nothing else.
  **And the output cannot warn you, even in principle:** `✔ Successfully installed plugin:
  specialists@claude-code-specialists (scope: project)` names the scope and **no version at all**. The
  install record is the only place the version appears, which is exactly why the verification step in
  Step 1 queries `installed_plugins.json` instead of reading a success line.
- **`update` refreshed the cache by itself when measured.** On July 31, 2026 (CLI `2.1.220`), with the
  cached clone verifiably still on the pre-release commit — it did not even contain the release commit
  — a bare `claude plugin update … --scope project` from a consumer's root moved `3.0.3 -> 3.0.4`, and
  the clone itself advanced to the release commit during that run. So for `update`, the explicit
  refresh was **not** required here. (The command is elided as `…` on purpose: spelled out with its
  `plugin@marketplace` target it reads as an instruction to run, which is what check 11 in the lint
  gate enforces flags on — the repo's convention for quoting a command as the *subject* of a
  measurement is the ellipsis.)
- **And within ONE version string, neither of them moves anything at all** (September 10, 2026, CLI
  `2.1.267`, [#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)). This is the
  case the two measurements above do not cover: both were taken while the version number was changing.
  Taken in order on one machine, with the clone's payload for `4.33.0` carrying a skill the installed
  payload did not: the refresh advanced the clone **104 commits** and left every extracted payload
  byte-identical, with `installed_plugins.json` unchanged to the byte; `update … --scope project` then
  answered *"already at the latest version (4.33.0)"* and extracted nothing; a fresh `install …
  --scope project` answered *"already installed"* and extracted nothing either. So **both verbs decide
  on the version string**, and content that lands on `main` without a bump is unreachable by the pair —
  not stale by hours, but until the next cut.
- **What a session loads is the extracted payload, not the clone, and that is what makes the point
  above bite.** A record in `installed_plugins.json` carries an `installPath` into
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version-or-sha>/`, and the running process holds a
  lease at `<installPath>/.in_use/<pid>` for the life of the session — measured live, with the clone
  holding none, and corroborated by `claude plugin details` pricing the payload's component inventory
  rather than the clone's. The clone is the catalogue and the source an extraction copies from. **The
  one thing that does load from the clone is a document your repo names by an absolute `@`-import**
  (the orchestrator's body), which is why a refresh visibly moves that one document and nothing else.
- **`uninstall` removes the record and leaves the payload standing — per plugin, which is the half
  [UNINSTALL.md](UNINSTALL.md#what-is-left-behind-honestly) had not measured.** That page already
  establishes, correctly, that the cache directory follows the *marketplace* rather than the install
  ([#339](https://github.com/DaveKJohn/claude-code-specialists/issues/339)); what was open is what an
  uninstall of ONE plugin does to that plugin's own trees. Measured September 10, 2026 on
  `dkj-team-lifehub@claude-code-specialists --scope project`: the record went, both of its extracted
  trees stayed. The harness marks such a tree with `.orphaned_at` and sweeps on its own schedule, but
  marking is not reaping — 30 of 41 trees on that machine were marked, 22.2 MB of 32.6 MB, the oldest
  mark six days old and its tree still there. `tidy-machine`'s lane 12 reports this; nothing in this
  family removes one.

**Why line 1 stays in front of both:** for `install` it is load-bearing — skip it and you get the
previous version, twice measured. For `update` it is idempotent insurance: the `update` behaviour is one
measurement on one CLI version, and a stale cache is invisible by construction, so the procedure
guarantees freshness instead of depending on the CLI continuing to do it for you. What is *not* claimed
is that skipping it makes an `update` serve the previous version; that was a generalisation from the
`install` measurement, and it did not survive being tested.

So a version number is one of **two** gates. `claude plugin update` compares version numbers only, and
it compares them against a **cached copy** of the marketplace rather than against the workshop
directly — a copy that `update` was measured to refresh for itself and `install` was measured not to.
On what schedule the cache refreshes when nothing asks was never established, which is why the explicit
command belongs in the procedure rather than a hope that it has caught up.

**The scope flag on the second command is not optional either.** Without it the command defaults to
user scope and does not act on a project-scoped install. **What it prints depends on your CLI version,
so treat the wording as version-bound and the flag as the invariant** (inbound
[#359](https://github.com/DaveKJohn/claude-code-specialists/issues/359)). On `2.1.220` it names the scope
and the settings file, and then suggests `claude plugin disable … --scope local` — **which is not the
step to follow**: that writes a local disable key on top of your project setting and leaves the install
in place. Earlier releases said *"Plugin `specialists` is not installed at scope user"*, literally true
and easy to misread as "not installed at all". Whatever the phrasing, the failure means the command
looked in the wrong scope. Do not answer it by re-running the install either: a scopeless install adds
a **second, machine-wide record** beside the project one. For **what changed**, read
[`CHANGELOG.md`](dkj-policy/CHANGELOG.md) and [`releases/`](dkj-policy/releases/history.md) — and you already have both,
because your marketplace source is a git clone of the whole repository at
`~/.claude/plugins/marketplaces/dkj-claude-plugins/`, not a per-plugin extract.

**A plugin folder used to carry its own `CHANGELOG.md` and a `RELEASE.md` card; both were removed on
August 8, 2026.** They existed to give you a history inside the plugin cache, and the sentence above is
why they were not needed: the real history was always one directory up. Two copies of the same record
can disagree, and this one did — the cards also could not answer "which release am *I* on", which they
had to be corrected to admit (inbound
[#384](https://github.com/DaveKJohn/claude-code-specialists/issues/384)). The question is answered by
the `version` in your cached `<plugin>/.claude-plugin/plugin.json`, and by the section directly below.

**The version is not the code, and on this marketplace the two routinely disagree.** The cached clone
this family installs from **checks out `main` and tracks `origin/main`** — not the newest tag. So any
refresh fast-forwards it to `main` and the install copies *that* tree, while `plugin.json` still carries
whatever version the last release bumped it to. Every commit merged after a release therefore ships to
consumers immediately, under the previous release's version number.

Measured twice, from both directions (inbound
[#313](https://github.com/DaveKJohn/claude-code-specialists/issues/313), July 31 – August 1, 2026, CLI
`2.1.220`):

- **Without a command.** A consumer moved `3.0.6 → 3.0.8` on its own and landed on `main`, three commits
  past the `v3.0.8` tag. `version` read `3.0.8`; `gitCommitSha` was the fold commit of a PR merged after
  the release. The payload genuinely differed — the same `SKILL.md` hashed differently on the tag and in
  the installed cache — and `3.0.7` was never cached at all, so that release's fixes were skipped over
  entirely.
- **With the documented commands.** The two-command procedure at the top of this section, run
  deliberately in the workshop repo, produced exactly the same state: `version 3.0.8`, sha on `main`. So
  this is not an artefact of some unknown scheduler — **the documented update path cannot deliver a tagged
  release**, because the source it reads is a branch.

What that means for you, plainly: the version number tells you which release notes to read, and the sha
tells you which code you are running. Only the second is the truth about your session. Two practical
consequences — the family's own measuring discipline of *"pin source locations against the release tag"*
does not hold in a consumer, so pin against the sha your record names; and a bug you cannot reproduce
against the tag may still be real, because you were never on it. What remains genuinely unestablished is
what *triggers* the unasked refresh — that a refresh moves you to `main` is settled, when one happens by
itself is not.

**One part of what your session loads is not covered by that sha at all: the persona bodies** (inbound
[#330](https://github.com/DaveKJohn/claude-code-specialists/issues/330)). Look at the imports
`specialists-init` writes into `.claude/specialists/SPECIALISTS.md` and you will see they point into
`~/.claude/plugins/marketplaces/<marketplace>/…`, **the clone** — while your install record's `installPath`,
`version` and `gitCommitSha` describe a different directory, the version-pinned copy under
`…/plugins/cache/<marketplace>/<plugin>/<version>/`. The two were hash-identical when this was measured, so
there was no divergence to see; they are simply not the same source, and nothing keeps them in step. A
`marketplace update` fast-forwards the clone — and therefore the body your next session loads — while
`version` and `gitCommitSha` do not move, because the refresh does not touch the cache.

**This is deliberate, and worth knowing before anyone "fixes" it.** The import points at the clone because
that path is *durable*: the version-pinned cache directory is cleaned up after an update, so an import into
it would leave the orchestrator's body failing to load at all after your first refresh. A stale-but-loading
body beats a pinned-and-gone one. The cost is this asymmetry, and the honest statement is that
`gitCommitSha` is the truth about the payload the record names, not about every file your session reads.
If a persona behaves differently from what the release notes describe, the clone is where to look:
`git -C "$env:USERPROFILE\.claude\plugins\marketplaces\<marketplace>" rev-parse HEAD`.

**Read your install record rather than assume it, because it can move — or be taken away — without you
asking** (inbound [#296](https://github.com/DaveKJohn/claude-code-specialists/issues/296) and
[#301](https://github.com/DaveKJohn/claude-code-specialists/issues/301)). Project scope gives your repo its
own record; it does not freeze it, and it does not guarantee it will still be there tomorrow.

- **It moves.** Measured July 31, 2026: both project-scoped records of a real consumer went
  `3.0.4 → 3.0.5` in a **single** write, timestamps 70 ms apart, while that repo's session ran no
  `claude plugin` command at all — checked afterwards against every session transcript on the machine for
  that day.
- **It can be taken.** Same day, reproduced **twice**: a *session start* in an unrelated directory
  rewrote this file and **adopted an existing record**, leaving the repo it belonged to with no install.
  Once the victim was a real consumer; once it was the workshop repo itself. The `installedAt` stamps are
  the proof — the CLI sets that to *now* on a real install, so a record carrying an older repo's stamp was
  not created where it ended up.
- **It can be orphaned, by an ordinary directory rename.** The record is keyed on `projectPath` and
  nothing rewrites that key, so **renaming or moving the checkout leaves the record behind, naming a path
  that no longer exists** — the repo at its new path has no record and loads nothing. Measured August 3,
  2026 in the workshop repo itself, whose directory was renamed to match the marketplace's new name: the
  next session's `enabledPlugins` was still perfectly correct while the only record on the machine named
  the old folder. Unlike the two above, this one is predictable — if you move a checkout, plan the
  re-install into the same move — and it is the cause `check-report-lib.ps1` has always named in code
  without any reader-facing document saying it.

**The second one is the expensive one, because nothing tells you.** No command was run, no file in your
repo changed, `git status` is clean — and a session that loads no plugin has no hooks to complain,
because the hooks are *in* the plugin. So it looks exactly like a session where everything is fine.

Since `v3.0.7` the checks run the `projectPath` query for you and say
`[NOT-INSTALLED-HERE]` when an enabled plugin has no record for this path; the workshop's connector check
says it about each registered consumer, which is the vantage point that still works when a consumer has
gone quiet. **Do not expect that line at a session start, though, and this is measured rather than
assumed** (inbound [#314](https://github.com/DaveKJohn/claude-code-specialists/issues/314)): a session start
*writes the missing record itself*, so by the time any hook can look the state has healed. Run against
exactly that fixture — three plugins enabled, one with no record anywhere on the machine — the hook
printed the line on no branch at all. It is reachable by a **deliberate** run in a repo where a record
went missing and no session has started since, and from the workshop about a consumer. What survives a
session start is a record of the wrong *shape*, which since `v3.0.9` the checks report as
`[RECORD-SHAPE]`: `local` where this family assumes `project`, or two records where it assumes one. None of this is a reason to avoid project scope — it is a reason not to treat "the version I
installed" as a lasting fact. The `projectPath` query from
[Step 1](#connecting--the-install-step) is the answer to *"what am I actually running?"* — not the last
release notes you read, and not the install output, which names no version at all. If it comes back
empty, re-install from that root — and note that this is the case where the install **adds
`enabledPlugins`** rather than merely reformatting it (see [Step 1](#connecting--the-install-step)).

**Check that query again *after* a repair install, because the repair can leave two records where you
wanted one.** Measured in `DaveKJohn/life-hub` on July 31, 2026, CLI `2.1.220` (inbound
[#315](https://github.com/DaveKJohn/claude-code-specialists/issues/315)): re-installing at project scope
against a path that already carried a record **added a second one beside it** instead of correcting it,
reporting `✔ Successfully installed … (scope: project)` both times. Two lines for one plugin is not a
display quirk — it is the stray second record, and the count in that query is the only signal you get.

**Read the paths before you act on that count, though — one repair produces two lines legitimately.**
After repairing the renamed-directory case above, the expected state *is* two records: one naming the
directory that no longer exists, one naming the new root. That pair is not #315's stray duplicate — #315's
two records name the **same** path — and it needs no cleaning: a record whose `projectPath` does not
resolve cannot be about this repo, so `Get-InstallRecord` skips it rather than counting it, and a
`check-roster-sync` run immediately after such a repair reports no duplicate and no `[RECORD-SHAPE]`.
Editing `installed_plugins.json` by hand to remove the dead line buys nothing and risks the file the
whole administration rests on.

**And there is a third scope this family's documents had not accounted for: `local`.** The CLI does name
it — re-measured on August 1, 2026, CLI `2.1.220`, and worth stating precisely because an earlier version
of this sentence claimed the opposite: `install`, `uninstall` and `disable` each print
*"user, project, or local"* in their own `--help`, and `update` prints a fourth, `managed`. So the flag
list was never the gap; **these pages were**, which is why the state was met by a reader with nothing to
look it up in. It is what a *session start* writes — enabling a plugin is enough for one to create a missing record, and to flip an existing
`project` record to `local`, with no command run, no file in your repo changed, and nothing reporting it
(inbound [#314](https://github.com/DaveKJohn/claude-code-specialists/issues/314)). Two consequences worth
holding on to: the "enabled but not installed" state **heals itself**, so a check that looks for it will
usually find nothing rather than confirm health; and the state you are actually left in is `local`, which
the rest of this family's documents do not assume anywhere. Remove such a record with `claude plugin
uninstall <plugin>@<marketplace> --scope local` — at `--scope project` it refuses with *"Plugin … is
installed in local scope, not project"*, literally true and easy to misread as "not installed at all" —
then re-install at project scope from the repo root, refresh first. That `uninstall` also writes
`"enabledPlugins": {}` into `.claude/settings.local.json`, the same way the project-scoped one does in
`.claude/settings.json`.

When an update adds a **new specialist**, your repo's roster (the specialists table in your
`CLAUDE.md`) and its lenses don't update themselves. The `roster-sessioncheck` SessionStart hook
flags at session start any enabled agent that is missing from your roster **or** has no repo-lens;
type `/dkj-subagents-alpha:sync-roster` to stage the catch-up — it creates the missing lens scaffold and
proposes a roster row for you to review. It never edits your `CLAUDE.md` or commits: you place the
change on a branch under your own governance. You can also run
`scripts/sync/check-roster-sync.ps1` yourself for the full report.

When an update adds a **new skill**, restart your Claude Code session before you go looking for it.
`/reload-plugins` and `/reload-skills` only reload the skill set that is already loaded, not a new
skill file from an updated plugin version. So a slash command that did not exist in the previous
release stays absent until you restart — `claude plugin update`'s own `Restart to apply changes.` is
literally true here. Don't trust the skill counter those two commands print as evidence either way:
it excludes any skill with `disable-model-invocation: true`, and **skills from the team plugins and the
workflow plugin alike carry that flag** — `dkj-subagents-alpha`'s `specialists-init`, `specialists-teardown` and
`sync-roster`, and `cut-release`, `fold-changelog`, `open-pr` and `ship-pr` from
`dkj-policy`. So an unchanged count, or even `0 skills`, proves nothing about whether a new
skill has actually landed. The only reliable check is the slash list itself.

### Getting out again

Adoption is reversible by design, and the procedure has its own page: **[UNINSTALL.md](UNINSTALL.md)** —
the mirror of this one. Two things from it are worth knowing *before* you adopt rather than after. The
removal is **two** removals, out of your repo and off your machine, and they are done in that order
because the teardown skill ships inside the plugin you would be uninstalling. And if you build on the
shared workflow scripts, that dependency is not something a teardown can undo for you — the page says
what to do about it while you still can.

### Reporting back or improving something

- **An improvement to the shared core** (an agent def, playbook, persona, or skill): don't
  rework it locally, but report it as an issue on this repo with the label `inbound` — an
  [issue template](.github/ISSUE_TEMPLATE/inbound-improvement.md) is ready for that. The
  workshop processes it through its own chain, and the improvement comes back to all consumers via
  a release.
- **Repo-specific additions** belong in your own repo lenses in the seam
  (`.claude/specialists/lenses/`) — those are yours and do not travel with the plugin.
