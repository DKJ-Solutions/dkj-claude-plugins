# dkj-policy — one particular way of working, packaged so a repo can choose it

**This is DaveKJohn's own branch-and-entry model, and the name says whose it is on purpose.** It is not a
baseline every consumer inherits and not a standard: it is one answer to *how does work move through this
repo*, offered as something a repo can deliberately pick up. There is no sibling to inherit instead: what
a repo has until it chooses this one is its own way of working, which it never stopped having.

**And once a repo has picked it up, this workflow's pages take precedence over its own — on the cycle**
([#1699](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1699), September 9, 2026). The
paragraph above is about the *install*, and it is easy to read as a promise about the *obedience* too —
it is not. The scope is the part to read carefully, and the source repo's own `CLAUDE.md` states it in
the same breath as the precedence: the workflow's page wins where the two disagree, and *"it does not
replace anything below; it adds the workflow's own mechanics."* So what yields is how work moves — the
branch, the gates, the fold — and not your repo's answers about itself.

**The two directions are deliberate and not in tension: nothing arrives unasked, and enabling this is
choosing to be governed by it.** What stays yours is the *values* —
[`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md) names a **seam** wherever a repo owns the answer
rather than stating one repo's answer as the rule, so the trunk name, the merge method and the audience
tier remain yours. The cycle is not. And the specialist *teams* are the other way round entirely — a
craft adapts to the repo it lands in — which is why they are separate plugins rather than one.

**One mechanism makes the direction visible, and it is advisory.** This plugin ships a SessionStart
check, [`check-consumer-prose.ps1`](scripts/lint/check-consumer-prose.ps1), whose supremacy detector
reports your repo's own always-on prose when it declares that *your* `CLAUDE.md` wins. It reports and
refuses nothing — like every session check here — so it tells you which way the rule points rather than
stopping anything.

**It carries no specialists.** A workflow changes how the existing ones work, not who they are; the
specialists come from [the teams](https://github.com/DKJ-Solutions/claude-code-specialists/tree/main/plugins/dkj-subagents/). Enabling this without `dkj-subagents-alpha` gives you skills with
nobody to invoke them.

**This folder is the government, and its ministries sit inside it.** `dkj-policy` is the prime ministry:
its own files are at this root, and a ministry — a deliberately narrow layer extending one step of the
cycle for one set of repos — is a sub-directory beside them, the way
[`dkj-policy-bwj/`](dkj-policy-bwj/) is. A ministry is a separate published plugin with its own manifest
and its own opt-in, so it is never enabled by enabling this one; nesting states the rank order, not a
bundle. Until September 5, 2026 this directory was `plugins/workflows/` and carried a README of its own
about the *kind*; that page is folded into this one, and what remains of it — the naming and directory
rule the lint gate enforces — is one level up in
[`../README.md`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/plugins/README.md),
beside the same rule for teams
([#1467](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1467)).

## What it is, in one paragraph

A branch is never entry-less: creating one writes the two files it works in — a changelog entry and a step
list — and the branch cannot reach a PR until both are answered. The entry declares **how far the change
reaches** (a tier) and **what it weighs** for each audience (a score), and that pair decides where it lands
in `CHANGELOG.md` and which release documents it appears in. The merge folds the entry into the changelog;
a release empties the changelog into dated notes and moves a tag. Gates on the branch's own paperwork hold
the whole thing together, and none of them is advisory.

**The cycle itself is written out in [`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md), beside this
file.** That is the page to read — and the page to point your own contributors at — because it names the
seam wherever your repo owns the answer instead of asserting one repo's answer as the rule. Pair it with a
`## Specific to this repo` section on whichever page carries your floor -- normally your root
`CONTRIBUTING.md`, and see that page's closing section for when it is not -- holding your values; the source
repo's
[own answers](https://github.com/DKJ-Solutions/dkj-claude-plugins/tree/main/.claude/specialists/lenses)
are a worked example of that half.

**That link has moved twice, and both moves are why this sentence is worth reading twice.** It pointed at
the source's ROOT `CONTRIBUTING.md` until August 27, 2026, which #980 deleted -- so the worked example
this page offered a consumer was a 404, while the sentence around it still told them to put their values
in a root page unconditionally. It then pointed at that repo's `dkj-policy/CONTRIBUTING.md`, which
[#2171](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2171) retired on
September 20, 2026: **a per-repo restatement beside the portable page above was what made two pages out
of one contributing page, which is the duplication that issue removed.** The source repo keeps its floor
in `CLAUDE.md` and puts each of its own answers in the lens of the specialist who owns it; which file
carries yours is still your answer to make.

**And if your work arrives from somebody else's tracker, that layer is step 1 of the cycle rather than a
page of its own.** [The ticket-work section](CONTRIBUTING-portable.md#ticket-work--the-layer-before-the-branch)
carries it: how to tell a request that cannot be built from one we are merely unconvinced by, which six
kinds of question are not blockers, and why a status in a heading is always false. Rules only, no template —
they come from one repo and one day, which the section says out loud.

**It was a fourth portable page, `TICKETWORK-portable.md`, until August 30, 2026.** What retired it was not
its size but its reach: the cycle document began at the branch and never mentioned it, so a reader following
that cycle end to end met neither the section nor the step it described
([#1123](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1123)).

The full reasoning — the tier model, why the fold rewrites nothing, what a release must earn — ships with
this plugin: [`RELEASES-portable.md`](RELEASES-portable.md) for the release workflow and
[`DEVELOPMENT-portable.md`](DEVELOPMENT-portable.md) for the branch's own document, beside
[`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md) for the cycle that connects them.

## What is in this folder

| what | what it holds |
|---|---|
| [`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md) | the contribution cycle in prose, seam-named — the human-facing half, meant to be read alongside your own repo's answers |
| [`RELEASES-portable.md`](RELEASES-portable.md) | the release workflow: the tier model, what a release must earn, the release documents, and how one is cut. Your own answers belong in your specialist lens rather than in a page of their own; your release list is `dkj-policy/releases/history.md` |
| [`DEVELOPMENT-portable.md`](DEVELOPMENT-portable.md) | the document a branch works in: its two halves, the dossier form, the three step marks, the version suffix, its branch-long lifetime, and what the fold does at the merge |
| [`skills/`](skills/) | the skills a specialist invokes — this is where most of the workflow lives |
| [`scripts/`](scripts/) | the scripts and libs those skills run, mirrored from the source repo's own `scripts/`. **Never edit a file there** — see [its README](scripts/README.md) |
| [`hooks/`](hooks/) | SessionStart checks that never block, all belonging to running this across several repos — read-only with **one** stated exception, `claude-home-sessioncheck`, which reports fixture pollution of your `~/.claude` plugin administration and keeps a snapshot of that one file while it reads healthy, so a clobber is restorable rather than merely re-installable (#1609); it touches nothing in any repo — among them `connector-sessioncheck`, `script-contract-sessioncheck`, `consumer-prose-sessioncheck` (your own always-on prose contradicting this workflow — two detectors over one corpus read once, since #1421: a convention this workflow has renamed, still stated as current, #1389, and your own `CLAUDE.md` declared the winner over this workflow's contributing layer, inverting the rank order, #1415) — plus two **Stop** hooks that do more than report: `cycle-autopark` pushes the branch's `<branch>.md` to `origin` after every turn, until a PR publishes it (#900), and `closeout-gate` **refuses** a turn whose close-out runs past the band the repo states, once per work chain (#2050). That second one is the only thing in this plugin that blocks a turn, and it is **off in every repo that does not answer `Get-CloseOutGateBand`** — absence and a malformed answer both mean off, and every path in it that cannot answer its question exits 0. **The set is deliberately not counted here**: this cell said "two" and went stale twice inside two days, and [`hooks/hooks.json`](hooks/hooks.json) is the one place that cannot |
| [`blueprint/`](blueprint/) | the source's own answers to the repo-owned seam, with the reasoning behind each — read by the `adopt-dkj-policy` skill's Part 2 |
| [`templates/`](templates/) | the one file in this cycle that has to be **copied** rather than imported: `pull_request_template.md`. GitHub reads a PR template only from `.github/` in your own repo — so the `adopt-dkj-policy` skill's Part 1 makes that copy on adoption, never overwriting one you already have (#1843), and what stays here is the reference to read and to diff against. See the [`open-pr` skill](skills/open-pr/SKILL.md) for the one promise it makes: the placeholder line |

| [`dkj-policy-bwj/`](dkj-policy-bwj/) | **not this plugin's payload — a ministry under it.** BWJ's codex: the binding rules its two Shopify store repos (smartwatchbanden, xoxowildhearts) operate under, in four chapters — and **the reach differs per chapter**: ticket handling alone also binds this plugin's own source repo, admitted September 14, 2026 in commit `b9b2a65a` ([#1982](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1982)), because a discovered issue is the one subject that exists here too. **Ticket handling** — file on GitHub first, mirror to Asana as a colleague-friendly variant; closing the GitHub issue only makes a CI template post that the work is ready to test and move the card to `ReadyToTest`, and never resolves the task itself. **The sync log** — a `sync/` branch is exempt from the changelog by design and owes `dkj-policy-bwj/SYNC-LOG.md` instead ([#1382](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1382)). **The preview handover** — a preview is a pair per market, the preview beside the live control ([#1874](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1874)), reaching the reviewer as one link to a published page with a QR code per market rather than as a table of URLs ([#1873](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1873)). **The theme lifecycle** — the release cut backs the live theme up as a verified baseline and rotates the previous one out, and a live push is followed by a sweep of the spent previews this repo created; every delete is bounded by a reserved name prefix this repo wrote rather than by a theme's role, so a theme somebody else created is never in the delete set ([#1965](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1965)). Four skills (`report-issue`, `adopt-dkj-policy-bwj`, `publish-page`, `build-backlog-page`), no specialists, no hooks. Separately published and separately enabled; it has [its own README](dkj-policy-bwj/README.md) |

**No `subagents/`, no `manuals/`.** Those belong to a team, and a workflow that shipped one would be
answering the question the other directory owns.

## The skills

**All of them, deliberately — and the heading no longer says how many.** A partial list of an enumerable
set is worse than none: a reader who finds one of their skills undocumented here cannot tell which of the
two documents is wrong. It has been wrong three times, and every time a number is what made the gap look
like a decision:

- nine rows under the heading "The nine skills" while the directory held twelve — `lock`, `handover` and
  `prompt` had each arrived without one (all three are gone now:
  [#882](https://github.com/DKJ-Solutions/claude-code-specialists/issues/882) retired `prompt` and
  [#957](https://github.com/DKJ-Solutions/claude-code-specialists/issues/957) the other two, both Dave's);
- thirteen rows against fourteen directories — `check-branch-entry` had shipped without a row and stayed
  missing until August 21, 2026, when `prune-merged` was added and the set was recounted;
- fourteen rows against sixteen directories, under a heading still reading twelve — `measure-skill` and
  `worktree-lane` both absent, repaired here
  ([#873](https://github.com/DKJ-Solutions/claude-code-specialists/issues/873), August 26, 2026).

**Dropping the count is the cheaper half of the repair, and it has been tried on its own before — it did
not stop the drift, it only made it quieter.** So it is gone from the heading and from the layout table
above — and since August 26, 2026 the table below is **machine-checked**, which is the half that actually
closes the recurrence. The source repo's lint gate holds marked enumeration spans to the real skill set,
and this table now carries one.

**It took a second marker to get there, and the reason is worth keeping**, because it is a property of the
older check rather than of this document. The marketplace-wide `skills:all` span (`[skill-list]`, check 10
of `scripts/lint/check-plugin-integrity.ps1`) could not serve here on two counts:

- **Its canonical set is repo-wide.** It is built from every published plugin's `skills/`, so it holds a
  span to *all* the skills the marketplace ships. This table enumerates one plugin's, so a span there would
  report every team plugin's skills as missing.
- **Every backtick-quoted token inside its span counts as a claimed name**, so that span has to close around
  nothing but the names. A two-column table cannot honour it: three rows below carry a backticked path or
  flag in their second column.

The `skills:plugin` span (`[skill-list-plugin]`, check 29) is the plugin-scoped sibling that answers both
([#920](https://github.com/DKJ-Solutions/claude-code-specialists/issues/920)). It resolves the plugin from the
**document's own path** rather than from anything written in the marker, and it reads each row's **link
target** — `skills/<name>/SKILL.md` — instead of its backticks, so prose and backticked paths anywhere else
in a row cost nothing. Adding a skill to this plugin without adding a row now turns the source repo's
gate red rather than relying on somebody remembering. *Count when you add one* has been retired; the
check counts. That gate runs where this plugin is **maintained**, not where it is installed — nothing
below changes for you, and nothing here asks you to run anything.

<!-- skills:plugin -->

| skill | when |
|---|---|
| [`adopt-dkj-policy`](skills/adopt-dkj-policy/SKILL.md) | right after installing, in either order — **Part 1** scaffolds `dkj-policy/`, the one folder in your root where everything portable gathers (an install alone writes nothing into your repo); **Part 2** reads the blueprint, places what states the shared way of working, proposes the rest |
| [`claim-issue`](skills/claim-issue/SKILL.md) | an issue number has been named as the work — puts your account on it first, and refuses a closed one or one somebody else holds. Before the branch, because the tracker is the only thing two sessions share |
| [`sweep-issues`](skills/sweep-issues/SKILL.md) | issues have piled up and several machines should work them at once — claims by TAG (machine/account), so a claim names the machine even where two checkouts share one GitHub account, settles a two-machine race on the tracker's own timestamps, and stops where a result has to be judged by eye |
| [`new-branch`](skills/new-branch/SKILL.md) | starting any piece of work — creates the branch and its `dkj-policy/<branch>.md` in one move |
| [`park`](skills/park/SKILL.md) | handing an unfinished branch to another machine: push, no PR |
| [`worktree-lane`](skills/worktree-lane/SKILL.md) | one branch has to be built while another one ships — opens a branch in its own worktree, and hands it back when it is ready to ship |
| [`open-pr`](skills/open-pr/SKILL.md) | the work is committed — runs the four gates, pushes, opens the PR with the title and body composed from the entry |
| [`ship-pr`](skills/ship-pr/SKILL.md) | open → wait for CI → merge → fold, in one motion |
| [`fold-changelog`](skills/fold-changelog/SKILL.md) | the fold on its own, after a merge done by hand |
| [`check-branch-entry`](skills/check-branch-entry/SKILL.md) | the CI gate on the branch dossier — the same two checks `open-pr` runs, where a hand-pushed branch cannot escape them |
| [`check-policy-drift`](skills/check-policy-drift/SKILL.md) | your own `CLAUDE.md` and this plugin's pages may be saying different things — lays every legislating document out in rank order so you can read them against each other. Report-only; it edits nothing |
| [`prune-merged`](skills/prune-merged/SKILL.md) | merged branches have piled up in the clone — reaps the local ones it can prove are merged, and leaves every other one alone |
| [`tidy-machine`](skills/tidy-machine/SKILL.md) | the wider clutter, in one command and eleven lanes — stale worktree lanes, branches whose PR was **closed** without merging, expired backups, old stashes, install records naming a checkout or a plugin name that is gone, fixture trees under your temp directory. It deletes only what `prune-merged` can already prove and hands the rest over with the command |
| [`plugin-versions`](skills/plugin-versions/SKILL.md) | unsure whether this checkout is on the current plugin release — shows, per enabled plugin, the version installed for this checkout against the marketplace clone's version and HEAD, with a verdict on whether a plugin update is due |
| [`update-plugins`](skills/update-plugins/SKILL.md) | `plugin-versions` reports something behind and you want to close the gap in one command instead of one per plugin — refreshes the marketplace clone, updates every plugin this checkout enables, then prints `plugin-versions`' own receipt |
| [`check-fanout`](skills/check-fanout/SKILL.md) | work is about to be handed to subagents while the checkout holds uncommitted edits — reads the working copy before the dispatch and again after, and reports only what SHRANK: a change that is gone, or a stash entry that is. Report-only, and it cannot restore |
| [`cut-release`](skills/cut-release/SKILL.md) | the release: the bump, the notes, the tag, and the closing steps the script does not automate |
| [`release-notes-page`](skills/release-notes-page/SKILL.md) | after a release — builds the hand-written notes into one browsable page for the reader they are written for, and optionally the Cloudflare Worker that hosts it |
| [`fix-mojibake`](skills/fix-mojibake/SKILL.md) | repairing encoding damage in markdown |
| [`measure-skill`](skills/measure-skill/SKILL.md) | pricing what a skill costs the sessions that carry it — always-on against on-invoke tokens, the delta against a stored baseline, and the wall-clock of the script behind it |
| [`measure-closeouts`](skills/measure-closeouts/SKILL.md) | the close-out rule keeps being repaired and keeps losing — counts how the receipt actually behaved against its three-line ceiling across every recorded session, so the next repair can be measured instead of judged by whether a complaint arrives |

<!-- /skills:plugin -->

## What it expects from your repo — the seam

The shared scripts dot-source two **repo-owned** files, so the parts that legitimately differ per repo are
answered by the repo rather than baked into the plugin:

- **`scripts/repo-config.ps1`** — the seam: the trunk name, the lint script, the merge method, the release
  grouping, and the rest.
- **`scripts/lib/branch-info.ps1`** — your branch taxonomy: which prefixes exist and what each one means.

`specialists-init` (from `dkj-subagents-alpha`) scaffolds both, and **the `adopt-dkj-policy` skill's Part 2 fills them in**: it *places*
the answers that state a shared way of working and *proposes* — never places — the answers that state what
your repo **is**. A `decide` answer is deliberately never written as a stub, because a stub returning a
placeholder overrides a documented fallback that is usually right; absent beats wrong.

## One workflow, and no guard on it any more

**There is no default workflow, and that is the answer rather than a gap.** A sibling plugin,
`workflow-default`, described as *"the workflow a repo gets when it has not chosen one"*, existed until
August 26, 2026; removing it was Dave's call on a simple reading. **A consuming repo already has its own
way of working before any plugin is installed** — its contributing rules, its branch conventions, its
release steps, written by whoever runs it. A plugin asserting itself as the *default* method claims a
slot that was never empty. So the honest shape is one opt-in and no baseline: enable nothing here and
you keep exactly what you had, which is what you wanted.

**Two enabled workflow plugins would hand the specialists two contradicting answers to the same
question** — how a branch is named, what a change owes before it can open a PR, what a release is — with
nothing in the session saying which one is this repo's. That was not hypothetical while a second one
existed: this plugin and `workflow-default` genuinely disagreed, by design, about whether a branch owes
an entry at all.

**Both the sibling and the guard were retired on August 26, 2026**
([#886](https://github.com/DKJ-Solutions/claude-code-specialists/issues/886)). The `workflow-sessioncheck`
hook that counted enabled ids beginning with `workflow-` is gone, along with the plugin whose existence
made two of them reachable. Nothing counts them now, so adding a second workflow to this family means
answering the question above again rather than trusting a check that is no longer there.

**`dkj-policy-bwj` is a second workflow, added August 31, 2026 -- as `bwj-codex`, renamed on September 5 (#1437) -- with that question answered.** It shares
none of the contradictions above: it extends only the *ticket-work* step — how a discovered issue is
filed and mirrored to Asana in BWJ's two Shopify store repos and, for ticket handling alone, this
plugin's own source repo (admitted September 14, 2026, commit `b9b2a65a`) — and says nothing about
branch naming, the pre-PR bar, or releases. It **requires** this plugin rather than competing with
it. A repo that enables both gets one branch-and-release discipline and one ticket rule layered on
its front, not two
answers to one question. The retired guard's reasoning still applies to any *third* workflow that
overlaps either of these.

**And the collision this plugin could have with your own contributing rules is answered by isolation
instead.** Its changelog and its releases live inside **its own folder**, so what it writes never lands
in your repo's root and never competes with the conventions you already had. Keeping both side by side is
a supported answer, which is the reason there is no default to switch away from.

Disabling this plugin removes nothing it already wrote to your repo — your entry files and your config
stay; the skills and scripts that read them stop.

## Enabling it

Part of the adoption path in [`INSTALL.md`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/INSTALL.md);
[`UNINSTALL.md`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/UNINSTALL.md) is the mirror. It requires the core team `dkj-subagents-alpha`, which
every consuming repo enables anyway. Enabling or disabling it is an ordinary plugin change rather than a
migration, and there is no second one to switch between: the two directions are **on** and **off**.

## Updating it

**A release *announces* a new version of this plugin; nothing delivers it.** Getting one is two
commands, run from the root of the repo that consumes it:

```powershell
claude plugin marketplace update dkj-claude-plugins                   # 1. refresh the cache first
claude plugin update dkj-policy@dkj-claude-plugins --scope project    # 2. then update, per plugin
```

Then **restart the session** — a skill or a hook that arrived with the update is not in a session that
started before it. If you also run the ministry, the same pair updates it, with `dkj-policy-bwj` in
place of `dkj-policy`: it is separately published and separately installed, so updating this plugin
leaves it exactly where it was.

**`plugin-versions` tells you, per machine, whether the pair is even due.** This plugin ships it as a
skill (`plugin-versions`): one read-only run in the consuming checkout prints, per enabled plugin, the
version and commit that checkout installed against the marketplace clone's version and HEAD, with a
per-plugin verdict — up to date, update this plugin, or refresh the clone — and the command for each.
It reads the clone that checkout already holds, so it cannot see whether the clone itself trails
`origin`; between two releases nothing can.

**Both things those commands touch are per-machine state, and that is the whole reason this section
exists.** The marketplace is a cached git clone under `~/.claude/plugins/marketplaces/`, and the install
record is a per-machine file keyed on the **folder path** of the checkout the install was run in. So a
version you picked up on one machine changes nothing on the next one — your other laptop, a colleague's
clone of the same repo, a second checkout of it beside the first — and nothing in a session tells you:
the workflow keeps working, at whatever version that machine last installed. **Every machine runs the
pair itself**, in every checkout it holds. A checkout that is renamed or moved loses its install record
the same silent way
([#1449](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1449)).

**Neither part of the pair is optional, and only one of them is load-bearing for `update`.** Skip line 1
and `install` was measured serving the *previous* version, twice — while `update` was measured refreshing
the clone for itself, so keeping line 1 in front of it is insurance rather than a repair, because a stale
cache is invisible by construction. Line 2 is where the flag matters: drop `--scope project` and the
command looks in user scope and does not act on a project-scoped install at all. Both measurements — and
why the version number is not the code you are running — are in the family's
[Staying up to date](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/INSTALL.md#staying-up-to-date),
which is the page to read; they are not restated here.

**And the pair moves nothing at all between two releases, which is the limit worth knowing before you
run it** (measured September 10, 2026, Claude Code 2.1.267,
[#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)). What a session loads is
not the clone: it is an extracted copy under `~/.claude/plugins/cache/`, named by the `installPath` of
your checkout's install record and frozen when that record was last written. A
`claude plugin marketplace update` advanced the clone 104 commits and left every one of those copies
byte-identical, and `update` and `install` both then declined on the **version string** alone —
*"already at the latest version"*, *"already installed"*. So the unit that reaches a session is a
**release**, and a fix that lands on `main` without a version bump reaches nobody, however many times
the pair is run. The exception is a document your own repo names by an absolute `@`-import into the
clone — the orchestrator's body is one — which the refresh alone does move.

**What can need catching up afterwards, and what tells you.** The shared scripts this plugin ships
dot-source the two **repo-owned** libs named in [the seam](#what-it-expects-from-your-repo--the-seam),
so a newer version can call a function your checkout has never had. That is the incident
`script-contract-sessioncheck` exists for
([#147](https://github.com/DKJ-Solutions/claude-code-specialists/issues/147): the first `new-branch` run
after an update crashed on `The term 'Test-BranchName' is not recognized`), and it names the missing
functions at the next session start; the [`adopt-dkj-policy`](skills/adopt-dkj-policy/SKILL.md) skill's
**Part 2** fills them in, and its **Part 1** is the same catch-up one level up, for a folder document or
the CI gate a newer version scaffolds. Both are additive and dry-run by default, so running them again
in an already-adopted repo is safe.

**What an update never touches is your own `dkj-policy/` folder** — your changelog, the documents of the
branches you have open, your answers to the seam. Those are your repo's files: this plugin carries the
conventions, never your answers to them, which is also why disabling it leaves all of them in place. So
an update cannot lose work in flight. The one thing worth timing is the script contract above: the
scripts a branch runs come out of the cache, so the quiet moment to update is between branches rather
than under an open one.
