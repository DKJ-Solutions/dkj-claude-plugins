---
name: specialists-init
description: >-
  Bootstrap the Claude Specialists system in a new consuming repo: hook up the orchestrator
  (Chris) via one @-import in CLAUDE.md pointing at the seam (which in turn imports his portable
  body from the plugin install + his lens-only repo lens), put the plugin's other main-loop personas
  and the subagents in place as lens-only scaffolds in the seam plus the script-config scaffolds, and
  deliver a governance/safety-hooks proposal.
  Use this when the shared `dkj-subagents-alpha` plugin is installed and enabled but the conductor and the
  governance layer are still missing ("the workers are there, Chris is not").
disable-model-invocation: true
---

# specialists-init — the adoption path for a new consumer

The shared `dkj-subagents-alpha` plugin delivers the **worker subagents** (Sylvester, Tessa, Edith, Victor,
Tycho, …). What a plugin **cannot** do is edit a consumer's `CLAUDE.md`. That is exactly where the gap
sits: **Chris** (the orchestrator) is loaded via an `@`-import in the repo `CLAUDE.md`; the plugin's
**other personas** stand ready as lens-only files in the seam and are read on demand. This skill sets
that up, plus the governance and safety layer that differs per repo.

> **One half of that used to be stated too broadly, and the correction matters here.** A plugin *can*
> inject always-on main-loop context — a root `settings.json` with an `agent` key activates one of its
> own agents as the main thread. Verified, and deliberately **not** switched on: it would change every
> consumer's main loop from a version bump they did not read, and a second `agent`-setting plugin
> silently wins on load order. The reasoning is in
> [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#delivering-the-orchestrator-from-the-plugin--verified-deliberately-not-switched-on)
> and [issue #215](https://github.com/DaveKJohn/claude-code-specialists/issues/215). So this skill exists
> because of the `CLAUDE.md` half, which is true on its own.

## Chicken-and-egg — step 0 is done by the user

This skill lives inside the `dkj-subagents-alpha` plugin, so it only becomes available once the plugin is
**installed for this repo** and the session has been restarted. The skill cannot hook itself up. Step 0
is therefore manual, and it is **six acts, in this order** — enable, restart, refresh, install, restart,
verify — grouped below as `0a` (acts 1 and 2), `0b` (acts 3 and 4) and `0c` (acts 5 and 6).

**And so is the invocation itself — permanently, for every consumer, by decision rather than by
oversight.** This skill carries `disable-model-invocation`: a session cannot start it, the `Skill` tool
refuses, and the same flag keeps this page — including the `bootstrap.ps1` route documented further down
— out of a model's context entirely, so it cannot even learn the skill exists. The owner types
`/dkj-subagents-alpha:specialists-init`, and there is **no per-repo escape**: `skillOverrides` only ever
restricts (there is no value meaning *"let the model invoke this after all"*), and it does not reach
plugin skills at all. Settled on August 29, 2026 (inbound
[#1096](https://github.com/DaveKJohn/claude-code-specialists/issues/1096)) against the alternative of
dropping the flag, which would have put this skill's description in every session of every consumer,
forever, for something that happens once per repo. **The price of keeping it is that no message may
name this skill with a bare imperative** — the reader those messages address is usually the model, and
an instruction it is structurally forbidden to follow leaves it with the plugin cache and an absolute
path as the only remaining move. Four places name the command **and the actor** for that reason: the
two SessionStart hooks — `roster-sessioncheck.ps1` (through `check-roster-sync.ps1`'s `[BOOTSTRAP]`
line) and `script-contract-sessioncheck.ps1` (through `check-script-contract.ps1`'s) — plus
`adopt-config.ps1`'s `[STOP]` and the `orchestrator` skill page. Each of them says
`/dkj-subagents-alpha:specialists-init` in full and then says the repo owner has to type it.

> **A runbook that describes itself as executable end to end by a session is wrong about this step**, and
> that is worth stating once rather than rediscovering it in every testrun: adoption stops here until the
> owner types the command, by design.

> **The count is deliberately the same six as in
> [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#why-six-acts-and-the-measurements-behind-each)** (inbound
> [#297](https://github.com/DaveKJohn/claude-code-specialists/issues/297)). This page said *three acts* while
> that one said *four* and the page carrying this procedure said *three steps* — the same path, nothing
> missing anywhere, three different numbers, and the pages link to each other for exactly this step.
> (That third page was a root `INSTALL.md` until September 24, 2026; its install step now sits in the
> adoption page's own *Installing it yourself* section.) For a reader following it the first time the count is the only check they
> have on whether they skipped something. The letters stay, because they are what the rest of this page
> refers to; the number now counts the same unit as the README.
>
> **It was five until August 1, 2026**, when
> [#329](https://github.com/DaveKJohn/claude-code-specialists/issues/329) measured that a session start is
> what registers the marketplace — making the first restart an act of its own here, in the claude-code-specialists README
> and in the adoption page in the same change. The letters absorbed it (`0a` is now two acts) rather than
> the count staying at five.
>
> **That adoption page is [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/plugins/ADOPTION.md).** It has been three
> documents under four names: `QUICKSTART.md` until August 3, 2026 (inbound
> [#408](https://github.com/DaveKJohn/claude-code-specialists/issues/408)), then `ADOPTION.md` with a
> short commands-only `QUICKSTART.md` beside it, then both merged into `plugins/INSTALL.md`, and since
> August 14, 2026 split again — this time on **audience** rather than length (inbound
> [#664](https://github.com/DaveKJohn/claude-code-specialists/issues/664)): the install plumbing stayed
> behind as a root `INSTALL.md`, and adoption became its own page again. That root page was retired on
> September 24, 2026, and the install commands moved into the adoption page as a section of their own.
>
> **Its step count went from four to three in that split, and the missing one is this skill's own
> neighbour.** What used to be its Step 1 — enabling and installing — is the plumbing that moved out,
> because for a reader whose organisation published these plugins to them it has already happened.
>
> **And back to four on August 20, 2026** (inbound
> [#784](https://github.com/DaveKJohn/claude-code-specialists/issues/784)), when the other plugins' adopt
> skills became a step of their own. The page had named none of them, describing a one-plugin world while
> a real install is this skill **plus one adopt step per enabled plugin that owns repo state** — so the
> reader met the rest of their adoption one session-check `[ERROR]` at a time. So if you are
> cross-reading, expect **four steps** there and **six acts** here for step 0, and note that those six
> acts are condensed there into the *Installing it yourself* section ahead of the four steps.

**0a — enable, then restart once.** Verify that the consumer has this in `.claude/settings.json`:

```jsonc
"extraKnownMarketplaces": {
  "dkj-claude-plugins": { "source": { "source": "github", "repo": "DKJ-Solutions/claude-code-specialists" } }
},
"enabledPlugins": {
  "dkj-subagents-alpha@dkj-claude-plugins": true
  // plus a domain plugin of choice, e.g. "dkj-subagents-shopify@dkj-claude-plugins": true
}
```

**Then restart the session once, before `0b`.** Writing `extraKnownMarketplaces` does not register the
marketplace; a **session start** does. Measured on a virgin profile in three states (inbound
[#329](https://github.com/DaveKJohn/claude-code-specialists/issues/329)): without the settings file the
refresh below fails, with the settings file in the same session it still fails, and after one session
start it succeeds — reporting `Marketplace 'claude-code-specialists' not found` until then, which reads as a
misspelled name rather than a missing act. `claude plugin marketplace add <owner>/<repo> --scope project`
registers it without a restart if that is preferable; keep the scope flag, because `add` defaults to
`user`.

**0b — install, per plugin, from the repo root, at project scope.** A plugin install is
**project-scoped**: `~/.claude/plugins/installed_plugins.json` keys every install by `projectPath`. Do
not count on the settings keys to produce that entry — they are not the documented route, and what they
do on their own is now an open question rather than "nothing": on a virgin profile with the marketplace
registered, a single session start was measured to write a full project-scoped record by itself (inbound
[#327](https://github.com/DaveKJohn/claude-code-specialists/issues/327)), in a session that loaded no plugin.
So run, from the root of the consuming repo, one command per plugin listed in `enabledPlugins`:

```powershell
claude plugin marketplace update dkj-claude-plugins   # first: refresh the cached marketplace
claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project
# plus each domain plugin, e.g.:
claude plugin install dkj-subagents-shopify@dkj-claude-plugins --scope project
```

**That first line matters if the marketplace is already cached on this machine, and skipping it
installs an old version with a success message.** Measured in `claude-code-specialists` on July 30, 2026,
minutes after `v3.0.2` was tagged and pushed: the cached clone still sat on the pre-release commit, so
the install produced **3.0.1** and reported `✔ Successfully installed`. Reproduced as a controlled pair
on July 31 right after `v3.0.5`, same machine and same minute: **without** the refresh a fresh folder got
`3.0.4` and the clone did not move; **with** it, a second fresh folder got `3.0.5`. Unlike `plugin
update`, `install` does **not** refresh for itself — so for this command the line is load-bearing rather
than insurance. And the output cannot tell you: the success line names the **scope and no version at
all**, which is why step 0c below verifies against the install record. `claude plugin marketplace update claude-code-specialists` followed by a `plugin
update` then moved it `3.0.1 -> 3.0.2` in one step. A refresh mechanism exists (the command reports
`Refreshing marketplace cache (timeout: 120s)`), so a cache does not stay stale indefinitely; on what
schedule it refreshes by itself was not established, which is why the explicit line is in the
procedure. On a machine that has never seen this marketplace the first line is a harmless no-op.

**`--scope project` is not optional here, and leaving it off fails quietly.** `claude plugin install`
defaults to `--scope user` (`claude plugin install --help` states it outright), which writes a record
with **no `projectPath` at all** — machine-wide, active in every repo on the machine, and precisely
not the per-`projectPath` entry the paragraph above says this step exists to create. Nothing errors:
the install reports success, and the only word distinguishing the two is `(scope: user)` in its own
output line. Project scope is the intended model for this family — it is what both real consumers
carry, it gives each repo **its own install record**, and every other document here is written against
it.

**It does not, however, promise that the record stays put** (inbound
[#296](https://github.com/DaveKJohn/claude-code-specialists/issues/296)). This paragraph used to claim
project scope *"keeps a repo pinned to the version it was tested against"*, and that did not survive
measurement: on July 31, 2026 both of `life-hub`'s project-scoped records moved `3.0.4 → 3.0.5` in a
**single** write, `lastUpdated` stamps 70 ms apart, while that repo's session issued no `claude plugin`
command — confirmed afterwards against every session transcript on the machine for that day (26
invocations, none in the window of the write). So "pinned" was a property of the bookkeeping, not of the
repo.

**And the consequence is not small, which is what the next round established** (inbound
[#301](https://github.com/DaveKJohn/claude-code-specialists/issues/301)). A project-scoped record can also be
**taken away**: a *session start* in another directory rewrites this file and does so by **adopting an
existing record**, leaving the repo it belonged to with no install at all. Reproduced twice on July 31,
2026 (CLI `2.1.220`), with no `claude plugin` command run in either case:

| | what was taken, and from whom |
|---|---|
| 14:32:31.795Z | a throwaway directory gained three records; two carried `installedAt` stamps belonging to **`life-hub`**, whose two `project` records were gone. All three `lastUpdated` identical — one write. |
| 16:01:48.239Z | same recipe, fresh directory; one record carried **`claude-code-specialists`'s own** `installedAt`. The workshop — this very repo — had lost its project install to a scratch folder. |

`installedAt` is what proves adoption rather than creation: the CLI sets it to *now* on a real install,
so a record bearing an older repo's stamp did not come into being there. Restored with
`claude plugin install … --scope project` from each real root.

**So the record is not merely mutable, it is removable by something outside your repo** — and then there
is no version to read, only silence. The owner gets no signal: no command run, no file in the repo
changed, `git status` clean. Only `installed_plugins.json` got quieter. That is precisely the state
step 0c below calls silent and self-camouflaging, arrived at *after* a correct adoption. **Read your
record instead of trusting it**, and read it more than once:
`~/.claude/plugins/installed_plugins.json` is the only place your version is written down — the install
success line names the scope and no version at all — and the query for it is in step 0c below.

Since `v3.0.7` you do not have to remember to: the checks run that same `projectPath` query themselves
(inbound [#302](https://github.com/DaveKJohn/claude-code-specialists/issues/302)). `check-roster-sync` emits
a `[NOT-INSTALLED-HERE]` line, and the workshop's `check-connectors` says it about each registered
consumer — which matters here, because a repo that loads nothing cannot report for itself: the hook that
would is inside the plugin that is not loading. What was **not** established is the trigger. Two
attempts with a barer setup (a git repo, one enabled plugin, a session, no bootstrap) produced no record
and no adoption; the recipe that fired had three enabled plugins — one of them with no record anywhere —
plus a bootstrapped tree with an `@`-import. Which of those factors carries the weight is unknown, as is
the rule by which a victim record is chosen. This is CLI behaviour, not plugin code.

**Reported upstream on July 31, 2026:**
[anthropics/claude-code#76759](https://github.com/anthropics/claude-code/issues/76759#issuecomment-5146633011).
That issue already documented the *write* — a session start driven by `enabledPlugins` writing
`installed_plugins.json` — on Linux and CLI `2.1.207`; the reproduction above was added there as the
**consequence** it had not covered: the write can carry another project's `installedAt`, and that project's
record is gone afterwards. A comment rather than a new issue, deliberately: same root behaviour, and
duplicating a well-written report is worse than adding to it. The plausible mechanism named there is
[#75392](https://github.com/anthropics/claude-code/issues/75392) — `install --scope project` overwriting
that file instead of merging — which, if the session-start write shares those semantics, explains the loss
directly. **Nothing in this plugin depends on that being fixed**: the checks now detect the state locally
(see the paragraph above), which is the part this repo controls.

**The same default bites on the way back out, which is where it is actually expensive.** `claude
plugin update` also defaults to user scope, so on a project-scoped install the plain command fails:

```
✘ Failed to update plugin "dkj-subagents-alpha@claude-code-specialists": Plugin "specialists" is not installed at scope user
```

That message is literally true and reads as *"this plugin is not installed"* on a machine where it
demonstrably is — so the obvious next move is to re-run the install, which adds a **second,
user-scope record** beside the project one and makes the plugin appear machine-wide. Update with the
flag instead, from the consuming repo's root, one command per plugin:

```powershell
claude plugin marketplace update dkj-claude-plugins
claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project
```

Both lines — but the reason is stated per command now, because the shared version of it was tested and
broke. The stale-cache measurement above is on **`install`**. On **`update`**, measured July 31, 2026
(CLI `2.1.220`) right after `v3.0.4` with the cached clone verifiably still on the pre-release commit, a
bare `claude plugin update … --scope project` moved `3.0.3 -> 3.0.4` **and advanced the clone itself
during the run** — so the refresh was not required there, and "a stale cache means a no-op reported as
up-to-date" does not hold for `update`. Keep the pair anyway: it is idempotent, it is one extra command,
and a stale cache is invisible by construction because it reports success with a plausible version
number — so the procedure guarantees freshness rather than relying on the CLI to keep doing it. This
pair is what every "pick up the new release" pointer in this family means — in
[`sync-roster`](../sync-roster/SKILL.md), in `scripts/sync/check-script-contract.ps1`, in the
[adoption page](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#installing-it-yourself), and in the release notes. Read a bare
`claude plugin update` anywhere as shorthand for these two lines.

**0c — restart, then verify before invoking.** Verify rather than assume, because **the failure this
catches is silent and self-camouflaging**: in a session where the install never happened, this skill
is absent *and* the session-start hooks are absent — and "no hooks because the plugin is not loaded"
reads exactly like "no hooks because everything is in order". Nothing in the session announces the
difference.

**Do not verify with `claude plugin list` alone — it is not repo-scoped, and it will tell you
everything is fine in a repo that has no install.** Measured in `DaveKJohn/claude-code-specialists` on
July 30, 2026: that repo has `enabledPlugins` set and **no install record of its own** (the only
`projectPath` in `installed_plugins.json` pointed at a different repo), and the plugin was
demonstrably not loaded — no `specialists:*` subagents, no skills, no session hooks. That "no record of
its own, and the only one points elsewhere" is now diagnosed rather than merely observed: it is the
record adoption described in step 0b, measured here a day before the mechanism was reproduced. The
record had **moved**, not never existed — worth knowing, because the two call for different actions
(re-install here, versus go find out whether this repo was ever adopted). Run from that repo's root, the
list nevertheless reported:

```
❯ specialists@davekjohns-workshop   Version: 3.0.1   Scope: project   Status: ✔ enabled
```

**Quoted as the CLI printed it that day — do not sweep.** `specialists` and `davekjohns-workshop` are
what the plugin and the marketplace were called at v3.0.1; both names have been renamed since, and
**four** later sweeps had each rewritten this line, leaving it quoting a string the CLI never emitted.
The test is whether a name is a pointer somebody follows or a quotation somebody checks: this one is
checked, against a tag, and the tag does not change (#2144).

The command enumerates install records beyond the current repo, so a green line is no evidence that
*this* repo is installed. Exactly why it reports the way it does was not established and is
deliberately not recorded here as a mechanism; what matters is that the output cannot carry the
verdict. Note too that the "you may see duplicates, just check each plugin appears as `enabled` at
all" reading — which earlier editions of this step recommended — steers you past the one signal that
would expose a stray second record.

**Check the record for this repo instead.** Run from the root of the consuming repo:

```powershell
$root = (Get-Location).Path
(Get-Content "$env:USERPROFILE\.claude\plugins\installed_plugins.json" -Raw | ConvertFrom-Json).plugins.PSObject.Properties |
  ForEach-Object { $n = $_.Name; $_.Value | Where-Object { $_.projectPath -eq $root } |
    ForEach-Object { "$n -> $($_.scope) $($_.version) $($_.gitCommitSha)" } }
```

**Read the two right-hand fields as two different answers, because they are: `version` identifies the
*release*, `gitCommitSha` identifies the *code*.** They can disagree, and when they do only the second one
is true. Round v8 measured a consumer whose record read `version 3.0.8` while the sha was three commits
past the `v3.0.8` tag — unreleased `main` — and the payload genuinely differed (the same file hashed
differently on the tag and in the installed cache). `plugin.json` carries `3.0.8` on both commits, so the
version string cannot express the difference; the sha was the only field that could, and it was printed
nowhere (inbound
[#313](https://github.com/DaveKJohn/claude-code-specialists/issues/313)).

**Do not try to resolve the release tag in the cached clone — that comparison is not answerable there**
(inbound [#322](https://github.com/DaveKJohn/claude-code-specialists/issues/322)). Earlier editions of this step
prescribed `git … rev-list -n1 v3.0.8` against
`~\.claude\plugins\marketplaces\claude-code-specialists` and offered a binary reading: equal means the release,
different means `main`. Three measured facts about that clone break it:

- it is **shallow** (`.git/shallow` present) and its fetch refspec is
  `+refs/heads/main:refs/remotes/origin/main` — main-only. **That does not mean the clone is tag-less**
  (inbound [#372](https://github.com/DaveKJohn/claude-code-specialists/issues/372)): the initial `git clone`
  brings along any tag pointing at history it fetched, and both measured clones had them — a fresh one
  carrying `v3.1.1`, an older one carrying 66 tags. An earlier edition of this bullet said *"no tags"*, and
  that was simply wrong;
- **its tag set is frozen at whatever came along when the clone was created**, and drifts further behind
  with every release. Measured the same day on two machines: newest tag **`v2.7.3`** on one and
  **`v3.0.8`** on another, while both served a `3.0.9` payload;
- **so the command succeeds on one machine and fails on another, for the same version.** The example above
  resolved fine where the clone happened to carry `v3.0.8` and returned
  `fatal: ambiguous argument 'v3.0.8'` where it did not.

That last one is why this is worse than a broken command: the reading had no branch for `fatal:`, and the
natural interpretation of a failure is *"not equal, so I am on `main`"* — which in the measured case was
**exactly backwards**, because that consumer's sha *was* the release tag's commit. An instruction that
inverts its answer on some machines and not others cannot be verified by the reader who runs it once.

**If the `fatal: ambiguous argument` line is what you get, that is expected and it is evidence of
nothing** — the tag is simply not in your clone.

**And there is a third outcome, which is the one to actually worry about: the tag resolves, and lies.**
This family's release tags are **annotated**, so `rev-parse <tag>` returns the *tag object*, not the commit
it points at. Measured on a clone sitting exactly on the `v3.1.1` release commit (round v12, August 2,
2026):

```text
git rev-parse v3.1.1        -> 12b2d1b6a80a336c134fb7b86f2d4ec6fe21b1ee   (the annotated tag OBJECT)
git rev-parse HEAD          -> 4b1a74dadbd2e37b1e254ad4f6f233451ea7cde3
git rev-parse "v3.1.1^{}"   -> 4b1a74dadbd2e37b1e254ad4f6f233451ea7cde3   (the COMMIT -- equals HEAD)
```

No `fatal:`, no missing tag — just two different shas on a clone that is **on** the release. The naive
reading, *"different, so I am on `main`"*, is the same inversion this whole block exists to prevent,
reached from the opposite direction: the old failure mode was *the tag is absent*, this one is *the tag is
present and needs peeling*. **If you resolve a tag locally at all, peel it with `^{}`** — otherwise you are
comparing a tag object against a commit, which can never match.

**What you can answer locally** is a narrower question — is the cache I installed from at the same commit
the clone sits on now?

```powershell
git -C "$env:USERPROFILE\.claude\plugins\marketplaces\claude-code-specialists" rev-parse HEAD
```

That works on a shallow clone and does not care which tags it happens to carry — it names no tag at all,
which is the point. Note what it is not: the clone and the version-pinned install
cache your record names in `installPath` are **two different directories**, so this tells you about the
clone, not about your payload. It is honest about what is knowable here.

**To identify the release, ask the source rather than the cache** — the tags live there:

```powershell
gh api repos/DKJ-Solutions/claude-code-specialists/tags --jq '.[] | select(.name=="v3.0.9") | .commit.sha'
```

That route has no peeling problem to worry about: the API's `.commit.sha` is the commit already, annotated
tag or not. Equal to your record's `gitCommitSha` means you are on that release; different means you are
on `main` — the marketplace clone tracks `main`, not the tag, so that happens without anyone asking
for it, and it is not something you can fix from here.

**One** line per plugin you enabled, each saying `project`, is the green you need — and the *count*
carries as much of the verdict as the word does.

**No line at all for a plugin means this repo has no record for its own path** — go back to step 0b. Note
what that does *not* mean: it is not evidence that the plugin is not loading. A session start can demote an
existing `project` record to a pathless `user` one (see the fourth bullet below), and this query filters on
`projectPath` — so a plugin can be missing from the output entirely while its skills and subagents are
plainly present in the session. Measured in `DaveKJohn/life-hub` on August 1, 2026 (inbound
[#323](https://github.com/DaveKJohn/claude-code-specialists/issues/323)): the core plugin was absent from its
own repo's query while 4 skills and 15 subagents were loaded from it. The action is the same either way;
the reason matters, because "empty" reads as "nothing installed" and here it meant "installed, but no
longer keyed to this path".

**Two lines for the same plugin is the stray second record this step warns about just above, and it is not
hypothetical — but the trigger is narrower than it first looks: it is a scope MISMATCH, not the mere
existence of a record.** Both halves are measured, a day apart, CLI `2.1.220`:

- **A record at a *different* scope accumulates.** In `DaveKJohn/life-hub` on July 31, 2026 (inbound
  [#315](https://github.com/DaveKJohn/claude-code-specialists/issues/315)) a project-scoped install run against
  a path that already carried a **`local`** record **added a second record beside it** rather than
  correcting it, and both reported `✔ Successfully installed`.
- **A record at the *same* scope is replaced cleanly.** Reproduced deliberately on August 1, 2026 against
  `3.0.9` (inbound [#325](https://github.com/DaveKJohn/claude-code-specialists/issues/325)): a project-scoped
  install against a path that already had a **`project`** record left **one** record, with a fresh
  `installedAt` — and the query afterwards printed exactly the one-line-per-plugin green this step defines.

**Why the narrower statement matters more than the correction.** Read as *"a path that already had a
record"*, the warning fires against the **normal, safe** repair — re-installing at project scope over a
project record, which is the ordinary way to restore a repo, and precisely what step 0b prescribes. A reader
who believed the broad version had no safe repair left at all. So the rule to carry away is one line:
**before a repair install, read the scope of what is already there** — remove at *that* scope first, or the
install adds beside it. That also fits the CLI's uninstall behaviour, which is scope-keyed throughout, and it
makes the fourth state below consistent: a repair install against a demoted, pathless record is itself a
scope mismatch, so the duplicate would come back.

Three scopes can turn up in that output, and the third one is not in the CLI's flag list. A fourth state
turns up as **no output at all**:

- **`project`** — what you want: this repo's own record, keyed by `projectPath`.
- **`user`** — the scopeless install from 0b's warning. It works machine-wide, but it is not the model
  the rest of these documents assume.
- **`local`** — **written by a session start, not by you.** Enabling a plugin is enough: a session start
  creates a missing record itself, and flips an existing `project` record to `local`, with no command run
  and nothing announcing it (inbound
  [#314](https://github.com/DaveKJohn/claude-code-specialists/issues/314)). It changes what the green above
  means without changing a single file in your repo. Remove such a record with `claude plugin uninstall
  <plugin>@<marketplace> --scope local` — at `--scope project` the same command refuses with *"Plugin
  … is installed in local scope, not project"*, which is easy to misread as "not installed" — and then
  re-install at project scope from this repo's root, refresh first, per step 0b.
- **nothing — the `project` record was demoted to a pathless `user` one.** Also written by a session start,
  and the most confusing of the four because the plugin **vanishes from this query** while it keeps working.
  Measured in `DaveKJohn/life-hub` on August 1, 2026 (inbound
  [#323](https://github.com/DaveKJohn/claude-code-specialists/issues/323)): in a single write, an existing
  `project` record was rewritten to `scope: user` with its `projectPath` **removed** — the original
  `installedAt` preserved, so it is a rewrite and not a fresh install. The repo then has no record of its
  own, and the fix is the same as for `local`: re-install at project scope from this root. **You do not have
  to spot this by eye.** Since inbound
  [#323](https://github.com/DaveKJohn/claude-code-specialists/issues/323) the roster session check reports it as
  a `[RECORD-SHAPE]` line with that remedy, so an ordinary session start names it for you.

**Do not expect a second session to repair any of these.** It was the natural assumption — a session start
writes records, so surely the next one restores what it broke — and it is wrong. Measured: after the first
session start rewrote the administration, a second fresh session left `installed_plugins.json` untouched to
the tick and reported exactly the same thing. The state is stable, so it waits for you.

Then confirm the session actually loaded it: after the restart the `specialists-init` skill is in
your slash list and the session-start hooks have reported. Once both checks are green, invoke this
skill.

## What the skill does

**Before any of it: establish that PowerShell exists on this machine.** This skill ends in a
`powershell` call, and there are environments where that command is simply not there -- a Linux cloud
container, a colleague's Mac, the Claude app with no repo connected. Ask once:

```powershell
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
```

If that answers `command not found` (exit 127), **stop and say so, before step 0**. `pwsh` is not a
substitute to reach for here: these scripts target Windows PowerShell 5.1 and this repo's own CI runs
them on `shell: powershell` rather than `pwsh` for that reason.

The reason to check at the front rather than to let the call fail is that the script is the *last*
thing this page asks for. It cannot half-run -- it never starts -- but everything above it can:
marketplace registration, a plugin install over the CLI, up to two session restarts. Arriving at a
call that cannot work on this box after all of that is the failure, and nothing before it gives a
signal. Measured in an environment with no repo at all, inbound
[#669](https://github.com/DaveKJohn/claude-code-specialists/issues/669) B2.

Run the bundled bootstrap script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/specialists-init/bootstrap.ps1"
```

The script performs only **safe, additive** actions — it never overwrites existing content:

**Where the lenses land — the seam (issue #221).** A **fresh** consumer gets one directory and one
line: lenses flat in `.claude/specialists/lenses/`, everything else behind
`.claude/specialists/SPECIALISTS.md`, and a single `@`-import in `CLAUDE.md`. A consumer that
**already has a lens tree** on the pre-seam plugin path (`.claude/plugins/<family>/<plugin>/`) keeps
writing there — this script never relocates a file the repo owner owns, and splitting the surface
across both paths would be worse than either. Migrating is your act, **five** steps — numbered 0 to 4 —
described in [`plugins/ADOPTION.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/ADOPTION.md#the-seam-specified). Every reader accepts both
layouts. **Step 0 is the `.gitignore` check, and it is the one that can cost you the lens tree**, so it
is named here rather than left to the count: in a repo that ignores `.claude/*` with an exception for the
old path, moving the lenses to the seam drops them out of version control with every gate still green
and `git status` silent.

> Found while fixing inbound [#297](https://github.com/DaveKJohn/claude-code-specialists/issues/297), which
> was about the *adoption* path being counted three different ways. This line said *four steps* about a
> list the README numbers **0 to 4**, and it links to that list — so a reader who counted items 1 to 4
> would skip step 0 for the very reason it is numbered zero. Same class, higher stakes: the miscount and
> the destructive step were the same step.

1. **Persona lenses (lens-only)** — for **every** main-loop persona the plugin ships, puts a
   `*-extension.md` in place in the lens directory chosen above, only if it is not already there. The
   lens carries **no body copy** — only the repo-lens slot; the portable body comes via an `@`-import
   directly from the plugin install. The set is read from the plugin's own `personas/` payload rather
   than from a list here, and it currently holds **four**: Chris `01-01`, Bianca `03-02`, Derek `05-05`,
   Rendall `05-06`. The closing line of the run states the number it actually placed — that count is
   the authority, and it grows on its own when a release adds a persona (inbound #275: this text named
   three while the script placed four, so a reader had to reconcile the prose with the counter).
2. **Empty lens scaffolds** — for each subagent of the **enabled** plugin(s), puts an empty
   `VUL-IN` scaffold in place in that same directory (never overwriting). This makes it
   visible from the first install where the repo-specific tasks per specialist are to be filled in;
   the agent-def automatically reads the lens along once it is filled. In the seam the directory is
   **flat**: `<group>-<id>` is unique family-wide, so several enabled plugins share one `lenses/`.
3. **Script-config scaffolds (#86)** — puts `scripts/repo-config.ps1` and `scripts/lib/branch-info.ps1`
   in place as `VUL-IN` scaffolds (never overwriting, with an **empty** branch table — the taxonomy
   differs per repo). Without these two files, the shared workflow skills `open-pr`/`fold` break on
   a clean consumer over a missing file.
4. **The import(s)** — ensures `CLAUDE.md` carries the orchestrator at the bottom. In the seam that is
   **one** line, `` `@.claude/specialists/SPECIALISTS.md` ``, and that file carries the body import, the
   lens import and this repo's roster slot; on the pre-seam path it stays the two imports it always was
   (portable body + repo lens). Creates a minimal `CLAUDE.md` scaffold if it is missing.
5. **Settings proposal — two files, and only one of them is meant to be pasted.** It writes
   `.claude/settings.suggested.jsonc`, the **annotated** proposal, with both permission halves + a
   hooks **stub**; and beside it `.claude/settings.proposed.json`, the **merged end result** — your
   own `settings.json` key for key with those halves folded in, as strict JSON with no comments and
   no hooks stub. Neither touches `settings.json` itself: the placement stays yours.

   **The merged file arrived on August 30, 2026
   ([#1124](https://github.com/DaveKJohn/claude-code-specialists/issues/1124)), because the annotated
   one could not be copied in one move and two of the three reasons had already been papered over
   with warnings.** The comments are illegal in the destination (#1097, warned). The hooks path is a
   placeholder (#363, warned). And the third, warned about nowhere: **the destination is not empty.**
   `.claude/settings.json` holds `enabledPlugins` and `extraKnownMarketplaces` — the two keys that got
   you this far — and the proposal does not contain them, so a whole-file paste deletes both. What you
   are left with is a settings file that parses perfectly and loads nothing: no skills, no subagents,
   no SessionStart hooks, and no message of any kind. That is
   [#1076](https://github.com/DaveKJohn/claude-code-specialists/issues/1076)'s state (3 → 0 hooks,
   6 → 0 skills, 15 → 0 subagents across one restart), reached by a different route — and reached in
   **the one act this family reserves for you**, since a session may not widen a permissions file.

   Reported by a repo owner rather than by the runner adopting for them: *"if I have to do this
   myself, I want to be able to copy and paste the whole file with no extra steps."* That is a fair
   expectation of a file whose entire purpose is to be copied, and more warning text does not meet it.

   **When no merged file is written, and why that is the right answer.** If `.claude/settings.json`
   cannot be read whole — it does not parse, it parses to something other than an object, or its
   `permissions` key is not an object — the bootstrap writes **no** merged file and says which of the
   three it found. A merge composed from a file that could not be fully read would drop part of it
   while carrying the label *"safe to paste"*, which is the reported defect arriving through its own
   fix. The annotated proposal is still placed, and the next-steps then walk you through the hand-merge
   **naming the two keys that must survive it**.

   **`permissions.allow` is the half that arrived on August 29, 2026
   ([#1075](https://github.com/DaveKJohn/claude-code-specialists/issues/1075)), and it is filled only
   when a workflow plugin is enabled** — the three entry points that workflow's cycle is made of
   (`new-branch`, `open-pr`, `ship-pr`) in both tool shapes, plus the one `gh repo edit` form the
   workflow assumes. `cut-release` is deliberately not in it: a release is worth a prompt. Enable no
   workflow and the half is emitted **empty, saying why** — there is no scripted entry point to
   permit, which is a state rather than an omission.

   Until that half existed, this file carried `deny` alone: a consumer who followed the adoption to
   the letter got a repo that forbade five things and permitted nothing, and **the one person who
   may widen a permissions file is you** — a session cannot place these rules for itself, and must
   not try. That is what makes shipping the lines part of the adoption rather than a convenience.

   **The paths in those rules are wildcarded on purpose, so do not "fix" them into absolute paths.**
   `${CLAUDE_PLUGIN_ROOT}` resolves to the version-pinned install
   (`…/cache/<marketplace>/<plugin>/<version>/`), so a rule naming today's root stops matching at
   your next plugin update — silently, while still reading as covered.
6. **Register proposal** — prints a paste-ready **connector manifest** for the *workshop* repo: the
   repo name derived from the git remote, plus one row per **enabled plugin of this marketplace**,
   carrying that plugin's lens inventory (personas included).

   **Every such plugin, including the ones that ship no `subagents/`** — those get `"extensions": []`,
   a true statement about a plugin that ships no lenses and the shape the register's readers already
   handle. Until August 29, 2026 the rows were built from the lens inventory instead, so a plugin with
   no agents could not reach the block at all and the workflow plugin was silently missing from every
   pasted manifest ([#1084](https://github.com/DaveKJohn/claude-code-specialists/issues/1084)). That
   is not cosmetic: the register is read **per plugin**, so a missing row takes the consumer out of
   the version view for that plugin — and an absent row looks exactly like a plugin they never
   enabled. A plugin from **another** marketplace stays out, and the run says which of the two any
   skipped plugin is.

   `visibility` and `localCheckout` stay `VUL-IN`, because this script cannot know them — it has no
   idea where the workshop checkout sits relative to this repo, and a guessed path is exactly what
   the register's marker check exists to prevent. Printed, never written: the register lives in the
   workshop and deliberately never receives cross-repo writes.

## Finishing up (manual — the judgment-call steps)

After the script:

1. **Fill in the repo lens.** Every `*-extension.md` put in place in the seam has an
   `## Specific to this repo (VUL-IN)` slot. Replace it with the repo-specific context: the roster/
   routing (Chris), the branch/PR conventions (Derek), the release mechanics (Rendall). The portable
   body lives in the plugin install (not in the lens) and is loaded along via the `@`-import — the
   marketplace's drift lint guards the lenses against the canonical source.

   **Replacing that heading is not cosmetic — it is the signal `specialists-teardown` reads.** That
   script decides what to remove by looking for `(VUL-IN)` in a heading, at **any** level, so a lens
   still carrying one anywhere is classified as an untouched scaffold no matter how much you wrote
   underneath it. Filling the slot heading is therefore what makes your lens safe from a later
   teardown.

   **If this repo was bootstrapped before August 2026, check the lens TITLES too.** Older versions of
   this script wrote the marker into the title as well — `# <group>-<id> · repo lens (VUL-IN)` — and
   filling a lens never touches its title, so the marker survived and the teardown read authored repo
   knowledge as disposable. Measured in a consumer with 24 lenses: three filled specialist lenses
   holding 153 lines between them were all listed for removal, and `-Apply` would have taken them. The
   dry run is the default, so nothing was lost — but the dry run is exactly what you read before
   deciding to apply, and it named the wrong files. Current versions mark the slot only; a one-time
   sweep for `^#.*\(VUL-IN\)` over your lenses closes it for an older repo
   ([#451](https://github.com/DaveKJohn/claude-code-specialists/issues/451)).
2. **Adopt the settings — replace `.claude/settings.json` with `.claude/settings.proposed.json`.**
   One move, nothing to reconstruct: that file is already your `settings.json` with the permissions
   folded in — strict JSON, no comments to strip, no hooks stub, and every key you had still in it.
   Then delete both proposals.

   **Read the annotated `.jsonc` for *why* each rule is there; do not paste it.** It is an explanation,
   and it holds the permission halves and nothing else — while `settings.json` already holds
   `enabledPlugins` and `extraKnownMarketplaces`. Overwrite the file with it and you delete both, and
   what you get is a settings file that parses perfectly and loads nothing at all (see step 5 above and
   [#1124](https://github.com/DaveKJohn/claude-code-specialists/issues/1124)).

   **If the run said no merged file was written, this step is a hand-merge and those two keys are what
   you must carry across.** That happens when `settings.json` cannot be read whole; the notice names
   which shape it found. Everything below applies to that path.

   **Strip the `//` lines as you copy.** The proposal is **JSONC** — its extension announces that
   comments are legal, and in that file they are. `settings.json` and `settings.local.json` are
   **strict JSON**, where they are not, and this instruction is the only thing standing at the boundary
   it sends you across.

   **The failure is silent and total, which is why it gets its own paragraph.** Claude Code does not
   partially apply a settings file it cannot parse — it ignores the whole file. One carried-over comment
   therefore switches off the `deny` half (`git push --force`, `git reset --hard`, `rm -rf`), the
   `allow` half, `enabledPlugins` and `extraKnownMarketplaces` together, and the only signal is a single
   startup line reading `Settings (.claude/settings.json): Invalid or malformed JSON` — a parse error,
   not *"your safety rules are off"*. Measured in the testrun-2 adoption on August 29, 2026: the copy
   was otherwise perfect — no trailing comma, no structural error — and six comment lines were the
   entire defect (inbound
   [#1097](https://github.com/DaveKJohn/claude-code-specialists/issues/1097)).
   [#335](https://github.com/DaveKJohn/claude-code-specialists/issues/335) established the same reader
   model for the QUICKSTART fragment — *"the block is labelled `jsonc`, which suggests comments are
   fine"* — but its repair landed there and never reached the instruction that moves this file.
3. **Write the governance.** The `CLAUDE.md` scaffold is bare. **Where `dkj-policy` is also installed,
   do not fill this file in at all** — `CLAUDE.md` holds only the `@`-import line(s), and the safety
   rules ship with that plugin; that plugin's own `adopt-dkj-policy` skill covers the import and where
   this repo's own facts then go (an unscoped `.claude/rules/<name>.md`, never `CLAUDE.md` itself). Only
   a repo running `dkj-subagents-alpha` **without** `dkj-policy` needs to write its own safety rules and
   working method directly into the scaffold (see an existing consumer as a model).
4. **Enable auto-delete of merged branches (#163).** Turn on the GitHub repo setting
   *"Automatically delete head branches"* (`deleteBranchOnMerge: true`) — via the repo settings UI
   or `gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true`. That makes remote
   branch cleanup automatic on merge; the local-clone cleanup (`git fetch --prune` +
   `git branch -d <branch>`) stays the fixed closing step of the fold (see the `fold-changelog`
   skill).
5. **Restart the session.** The new `@`-import and config only become active on a **restart** of
   Claude Code.
6. **Register the repo in the workshop.** Take the printed manifest block, fill in the two `VUL-IN`
   fields, and land it as `connectors/<repo>.json` in the marketplace repo via that repo's normal
   branch + PR flow. Skip this and the workshop stays blind to this repo: no plugin-version check, no
   lens-inventory check, no agent-def drift check.

   **Do not count on a reminder — on a plain consumer there is none.** The `[UNREGISTERED]` line does
   exist, but it comes from `check-connectors.ps1`, and `connector-sessioncheck` only runs that script
   when it finds a **verified workshop checkout on this machine**. A consumer does not have one; the
   workshop's own maintainer does. Measured in round v13 on an unregistered repo — every session of the
   round printed exactly this and nothing further (inbound
   [#383](https://github.com/DaveKJohn/claude-code-specialists/issues/383)):

   ```text
   connector-sessioncheck: no verified workshop checkout found on this machine -- check skipped.
   ```

   That is defensible behaviour: the check has nothing to check against. It does mean the safety net
   under this step catches the reader who needs it least. And this is the step most easily left lying —
   it asks for a PR in *another* repo, afterwards, once the adoption already works — so treat it as one
   nobody will nudge you about.

## Important

- **Do not overwrite.** If a `*-extension.md`, a scaffold, or the `@`-imports already exist, the
  script leaves them alone. The skill is safe to invoke repeatedly.
- **The personas are templates, not subagents.** They deliberately have no agent-def; they run in the
  main loop. Do not modify the portable body locally — a body change lands first in the marketplace
  (`personas/`), not in a consumer (just like a shared agent-def).
