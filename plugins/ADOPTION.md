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
the [root README](../README.md).

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
path are in the
[root README › Adoption](../README.md#adoption-the-bootstrap-path) — which counts the install as
"step 0" and this one as "step 1", because it numbers from before the point where this page starts.

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
