# connectors/ — the registry of connected repos

This is the registry of **which repos have installed this family's plugins and whether they are
still in sync with this repo** — one `<repo>.json` manifest per connected repo, directly in this
directory, each containing the extension inventory per plugin. The connector *is* the repo. This
README is the doctrine; the manifests are the data.

**The registry deliberately lives at the family level, next to the plugin directories — not inside
them.** The marketplace sources point to the plugin directories themselves, so this registry does
*not* travel with consumers' plugin caches: this way, no consumer sees another's manifests
(decision by Dave, July 16, 2026, after the security review). The registry is workshop
administration.

## The doctrine: this repo is the source of truth

claude-code-specialists works like a **Customer Data Platform**: all changes to shared plugin content
(agent defs, manuals, persona bodies, skills) **land here first**, and are only then synced out to
the connected repos — never the other way around (see the safety rules in
[`plugins/dkj-policy/CLAUDE.md`](../plugins/dkj-policy/CLAUDE.md), which the repo's own
[`CLAUDE.md`](../CLAUDE.md) imports). If an improvement nevertheless originates in a consumer, that
is an **inbound signal**: the change is first brought back here and then synced out again.

**The standing inbound route** (agreed with Dave, July 16, 2026): if a session in a consuming repo
discovers core improvements (something for the shared agent defs, manuals, persona bodies, or
skills — not lens work), that session does not build it itself, but opens an **issue on this repo**
with the label **`inbound`** — template:
[`inbound-improvement`](../.github/ISSUE_TEMPLATE/inbound-improvement.md). This way nothing
gets lost and every workshop session has a visible backlog; the workshop processes it through the
normal chain (branch → reviews → PR → release bump on Dave's word), after which the consumer gets
it back via the plugin update. The only legitimate bridge on the consumer side is a deliberately
temporary note in its own repo lens, which disappears again after the sync.

An important nuance — **what syncs and what doesn't**:

- **Synced (source here):** the portable persona bodies (everything above the
  `## Specific to this repo` marker) and all plugin content itself (agent defs, manuals, skills).
- **Not synced (repo-specific):** the `## Specific to this repo` slot of each extension — the repo
  lens differs per consumer and belongs there. The registry only tracks *that* a lens exists,
  never what it contains.
- **Why extensions cannot live only here:** the session in a consuming repo reads the lens files
  at runtime from its **own checkout** (agent defs refer to them, and the orchestrator's persona
  is loaded via an `@`-import in the repo CLAUDE.md). The copy in the consumer is therefore
  technically necessary; this registry + the check keep it honest.

## Privacy boundary (hard rule)

This repo is **public**. Manifests therefore contain **metadata** only: repo name, plugin,
extension inventory (only `<group>-<id>` numbers), and a relative checkout path. **Never** lens
content, absolute machine paths, or other data from the (private) consuming repos. The relative
`localCheckout` paths reveal the sibling layout of the local checkouts; that is a deliberately
accepted degree of transparency (security review, July 16, 2026).

**A candidate list widens that in degree, not in kind, and the bound is unchanged.** Since
[#1524](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1524) `localCheckout` may hold
several relative paths, so a manifest can reveal the sibling layout of more than one machine. Every one
of them is still a **relative** path inside the scope root — a folder name and nothing else — and the
rule the review actually drew still holds without amendment: **no absolute paths, no usernames, no home
directories**, in the field or in `notes`. Record a layout because a machine genuinely has it, not to
be thorough about machines nobody uses.

## The manifest format

```json
{
  "repo": "DKJ-Solutions/life-hub",
  "visibility": "private",
  "localCheckout": "../life-hub",
  "plugins": [
    {
      "id": "dkj-subagents-alpha@claude-code-specialists",
      "extensions": ["01-01", "05-05"]
    }
  ],
  "notes": ""
}
```

- `localCheckout` is **relative to the root of this repo** (the workshop checkout); if the
  checkout is not on the machine, the check skips it. Absolute paths and paths outside the scope
  root are rejected by the check.

  **It may also be a LIST, when the layout genuinely differs per machine** — the first candidate
  present on the machine running the check wins, and where none resolves the `[SKIP]` names all of
  them:

  ```json
  "localCheckout": [
    "../../bwjecommerce/smartwatchbanden",
    "../../GitHub/bwjecommerce/smartwatchbanden"
  ]
  ```

  A plain string keeps working and stays the normal answer; reach for the list only once a second
  machine has been *measured* to place that checkout somewhere else. The guardrails are on the field
  rather than on its first element: one absolute path anywhere in the list rejects the whole manifest,
  and an empty list is rejected as malformed rather than reported as an absent checkout.

  **Why a list rather than picking a machine** ([#1524](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1524),
  September 6, 2026). Both BWJ manifests recorded a `davekokbwj/` path that exists on neither machine
  holding those checkouts, and the cost is not that the path was wrong — it is *how* a wrong path is
  reported. A path that does not resolve produces `[SKIP] checkout ... not present on this machine`: a
  sentence that **asserts an absence**, exits 0, and suppresses the whole connector block. On the
  machine that finding was measured from, one such skip covered four `[INFO]` lines and a drift check
  reading 26 missing agent-defs. A wrong-but-loud value would have been repaired the day it drifted; a
  false skip taught nobody anything, so writing one machine's answer in and leaving the others silently
  skipped would only move the defect rather than close it.

  **Manifests that share a `siblingGroup` carry the same candidate layouts**
  ([#2141](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2141)). They sit on the same
  machine layout, so a candidate one of them needs is a candidate all of them need -- and adding one to a
  single manifest is what produced the fourth false `[SKIP]` in this class, after #1524, #1807 and #1831.
  `connectors.tests.ps1` case 6b compares the lists with the repo folder taken off each candidate, so
  the pair cannot drift apart unnoticed. A layout still goes into a group only once a machine has been
  measured to place a checkout there, per the rule above; the invariant then carries it to the siblings.
- `plugins` contains, per installed plugin, that plugin's `extensions` inventory.
- **A plugin rename does not get written into `plugins[].id` on the day the rename lands here — only
  after the consumer itself has migrated.** The same "registry data should follow reality" discipline
  that already governs the `extensions` inventory (see
  [Persona drift](#persona-drift-how-to-read-a-drifted-report-doctrine)) applies to the id itself: this
  register records what a consumer HAS, not what it is expected to have next, so a manifest still
  naming an old id after a plugin has been renamed here is not stale — it is accurate, right up until
  that consumer actually runs the reinstall. Writing the new id ahead of that reinstall would have the
  outbound half of [the check](#the-check) report a registered extension as missing from a plugin the
  consumer never installed, turning the register itself into a false alarm about a migration nobody
  performed.

  **This paragraph and the check disagreed for a few hours, and the check was the one that was wrong**
  (August 9, 2026). Written on the day the teams/workflows rename landed, it described the intended
  behaviour of a register that the check was at that moment reporting four `[ERROR]` lines against —
  because resolving a plugin id through the marketplace, which the check had started doing a few
  branches earlier, turns a renamed-upstream id into a failed lookup indistinguishable from a malformed
  one. Both collapsed into *"invalid or unknown plugin field"*. The check now tells the two apart and
  reports an id the marketplace no longer declares as an `[INFO]`: this consumer has not migrated,
  which is a state rather than a defect. Worth keeping as a shape, not just as a fix — a document
  written to describe a mechanism is not evidence about it, and this one was published a branch before
  anybody ran the thing it described.
  **The one carve-out is this repo's OWN record, and it is narrow on purpose** (Dave, September 10,
  2026, on [#1769](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1769)). The rule
  above holds because the register and the consumer are two parties, so writing a new id here before
  that consumer reinstalls is this side claiming something about the other. For
  [`dkj-claude-plugins.json`](dkj-claude-plugins.json) they are one party: this repo consumes itself,
  so its `.claude/settings.json` and its record live in the same tree and can land in the same commit.
  When they do, nothing is claimed ahead of anything — and the alternative is worse in a measurable
  way. During the marketplace rename the self-record was deliberately held back, and
  `connectors.tests.ps1` case 6 then failed on precisely the disagreement the check exists to report,
  which `open-pr.ps1` turns into a refusal; the only other way through was opening the rename's own
  pull request with `-SkipTests`, i.e. the test gate off on the largest merge this repo has made.
  **The carve-out is the self-record and nothing else.** Every other consumer migrates its record on
  the day it reinstalls, exactly as the paragraph above says, and "we are doing a big rename" is not a
  second carve-out.
- **`siblingGroup` is optional, and it is the one field that says two consumers are meant to run the
  same floor.** Give two or more manifests the same value and
  [`check-consumer-siblings.ps1`](#sibling-divergence-mechanisms-one-consumer-has-and-its-sibling-does-not)
  compares their tooling layers; a manifest without the field is in no group and is never compared.
  Today `bwj-store` names the two BWJ stores and nothing else does.

  **It is DECLARED rather than inferred, and that is the whole design of the field**
  ([#1869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1869)). Inferring the grouping —
  from a shared plugin set, say — is the obvious alternative and is wrong in a way no error message
  would ever show: every consumer of this marketplace shares `dkj-policy`, so a plugin-set inference
  puts `life-hub` in a group with a Shopify store and then reports a personal-life repo as missing a
  theme-archive mechanism. The grouping is a statement about **intent** — *these two repos are meant to
  run the same floor* — and intent is something somebody writes down.

  **It says nothing about what a consumer HAS**, which is what keeps it outside the
  "register what is, not what should be" discipline the `plugins[].id` rule above draws. A group label
  is a statement about this repo's own intent for two consumers, so it can be written the day the
  intent exists rather than the day either consumer changes.
- `notes` is the human summary/explanation; updated when something changes substantively, not on
  every check.
- **The manifest deliberately has no version bookkeeping (anymore)** (decision by Dave, July 20,
  2026): the check reads the actually installed version from the machine record
  (`installed_plugins.json`), and a `syncedVersion` field duplicating those numbers produced
  nothing but maintenance PRs while nobody was watching the signals anymore.
- **A machine can hold several records for one checkout, and then the check refuses to guess**
  (#240, July 29, 2026). Measured: one repo registered at three versions at once, because
  `~/.claude.json` held several project records for it in two path spellings. The check used to take
  the first record whose path resolved and stop — an arbitrary pick presented as a fact, on which the
  session hook's `[OK]`/`[ERROR]` then rested. It now collects every match: agreeing records (two
  spellings of one directory are not two answers) are reported as before, while disagreeing ones
  produce an `[ERROR]` naming all versions found and withholding the source comparison, because while
  they disagree no version claim about that consumer can be trusted. Cleaning up the duplicate project
  records is Claude Code's own state, not something this repo writes to.

## The check

[`scripts/sync/check-connectors.ps1`](../scripts/sync/check-connectors.ps1) runs the two-way
check across all manifests: plugin still enabled, registered extensions present (outbound),
unregistered extensions flagged (inbound), the machine version against the source, whether the
consumer's CI runners still name paths that exist here (#1805 — the one check whose subject is a path
*into* this tree), whether that consumer reaches into this tree *at all* (#1850, below), and per
consumer the content drift check
([`check-consumer-drift.ps1`](../scripts/lint/check-consumer-drift.ps1)). Run it at the
start of a workday or session:

```powershell
.\scripts\sync\check-connectors.ps1                  # everything
.\scripts\sync\check-connectors.ps1 -SkipDrift       # registry checks only (fast)
.\scripts\sync\check-connectors.ps1 -RemoteRunners   # also judge the CI runners of absent consumers
```

**`-RemoteRunners` is the one switch here that turns something ON, and it exists because of a blind
spot rather than for speed** (#1808). Every other check reads the consumer's local checkout, so a
consumer that is not checked out on the machine you are running from is `[SKIP]` and nothing about it
is read — which is correct for an extension inventory or a machine record, and lands badly on the CI
runner check: those runners name a path *into this tree*, and a consumer nobody visits is exactly the
one whose stale path nobody has noticed. Measured September 10, 2026: of the six registered
connectors, three were `[SKIP]` on this machine, including both of the two whose runners were red.

With the switch, an absent consumer's `.github/workflows/*.yml` are read from its default branch over
the GitHub API and judged by the same code the local half uses. It is **off by default and stays
that way**: this script is what `connector-sessioncheck.ps1` runs at every session start, and a
network call per absent connector does not belong on that path. Where the read cannot be made — no
`gh`, no credential, a repository this token cannot see — it says so per connector and quotes what the
API answered, rather than falling through to a silence that would read as an all-clear.

**And the runner check could not tell an unadopted consumer from a clean one, which is a different
blind spot in the same place** (#1850, September 11, 2026). That check judges paths a runner *names*,
so a consumer running none of the three runners names none, produces no finding, and reads exactly
like a fully adopted repo. Measured: `DaveKJohn/djcylow-react` registers the full core-team adoption
and lists the workflow plugin, and its entire `.github/workflows/` is one `ci.yml` — no
`branch-entry.yml`, no `fold-on-merge.yml`, no `verify-resolved.yml` — and the register reported it
green. The lib's own docstring had written the limit down (*"a finding here is therefore always about
a path that IS named; the absence of one is never evidence that a consumer is clean"*) without closing
it.

It is now reported, as an **`[INFO]`**, on both routes — the disk and, under `-RemoteRunners`, the
network, where it replaces what used to be deliberate silence. `[INFO]` rather than `[ERROR]` is this
register's own line, the same one drawn above for an unmigrated plugin id: the two halves of
`adopt-dkj-policy` that place those runners are optional and separate from enabling the plugin, so
their absence is a **state that may be a decision**, while a runner naming a path this tree no longer
has is red on every pull request with nobody able to learn it from their side. The finding says so and
points at `notes` for recording a deliberate answer. Two bounds worth knowing: it is asked only of a
manifest that **names the workflow plugin** (nothing else scaffolds those runners), and never of this
repo's own record — this tree runs those scripts by local path, being the one every consumer checks
out, so it is the only registered repo that can never produce a reference.

Syncing itself remains **pull-based per consumer**: each connected repo pulls changes in its own
session, under its own governance — this registry signals, it never writes cross-repo.

### Lens naming: the signal the dual-name layer's retirement is keyed on

**The register is now able to answer the one question its own retirement sentence asks of it**
([#2289](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2289), September 22, 2026).
The `#2128` rename round shipped a **dual-name layer** (#2130): every reader of a specialist file
resolves both the written spelling and the tolerated one, so a release could land without breaking a
consumer whose own lens files still carried the old name. That layer is temporary by construction, and
Dave's decision 1 of September 19, 2026 fixed its expiry — *"the old names are retired once the
connector register shows all six are over."*

**The register could not show it.** Every manifest stores bare ids (`"01-01"`) and zero filenames — by
design, and the privacy boundary above is part of why. The one check that does resolve a consumer's
lens file, [`check-consumer-drift.ps1`](../scripts/lint/check-consumer-drift.ps1), resolves it in order
to compare its **body**, and never reports which of the two spellings it found. So the sentence
governing the retirement was waiting on a signal no run could produce, and a bridge whose expiry cannot
be established is a permanent one by default.

`check-connectors.ps1` therefore measures it, per connector and then across the register:

```
  [LENS-RETIREMENT] 25 lens file(s), all on the also-read spelling (<g>-<id>-extension.md) -- not migrated yet, which is a state and not a defect.

-- lens naming across the register (the #2130 dual-name layer's retirement condition) --
  [lens naming] checked 3 of 6 -- not present on this machine: ...
  over:      DKJ-Solutions/dkj-claude-plugins
  not over:  BWJ-Development/smartwatchbanden, BWJ-Development/xoxowildhearts
  [LENS-RETIREMENT] NOT YET: 2 of 6 connectors still carry the also-read spelling, so the condition is FALSE and the dual-name layer stays. 3 of the 6 could not be measured here, so this is NOT the full list of what still has to migrate.
```

Four things about it are deliberate:

- **Measured, never declared.** There is no `lensNaming` field in the manifest and there must not be:
  that would be hand-maintained state about somebody else's tree, which is exactly what the
  `plugins[].id` rule above exists to forbid — writing a consumer's migration into the register ahead of
  the consumer performing it turns the register into a false alarm about a migration nobody ran. A
  directory listing costs nothing and cannot lie.
- **Not a finding.** It is neither `[ERROR]` nor `[INFO]`, so it does not count and the session hook
  does not surface it. A consumer on the old spelling is **not broken** — the dual-read layer is there
  precisely so each repo can do its own `git mv` when it suits.
- **Three endings, not two.** *Not answerable from this machine* is a different fact from *not yet*, and
  only the third ending may ever be read as the window being open. "All six are over" is a claim about
  six repos and this machine holds some subset of them, so the coverage is stated before the verdict and
  a partial run never says `MET` — the same rule the `[COVERAGE]` lines already carry (#221). A connector
  whose checkout resolves but holds **no** lens file counts as unmeasured too, never as migrated.
- **And a measured *not yet* outranks an unreached connector**
  ([#2298](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2298)). The two arms are both
  about coverage, which makes the cautious one look like the one that should win — but they are not on
  the same axis. A connector measurably on the also-read spelling settles the condition as **false**,
  and nothing an unreached one holds can make it true again, so answering *not answerable* there states
  less than the run established. The coverage claim is not dropped; it moves into that line, because
  without it `NOT YET: 2 of 6` reads as the complete migration list, which on partial coverage it is
  not. The green ending keeps exactly the gate it had: it is still reachable only when nothing is behind
  **and** nothing is unreached or empty.
- **The marker is `[LENS-RETIREMENT]`, not `[LENS-NAMING]`** (#2298).
  [`check-roster-sync.ps1`](../scripts/sync/check-roster-sync.ps1) already prints the latter for an
  unrelated fact — that *its own* naming vocabulary is older than the tree it is reading (#2219) — and
  two checks emitting one token is a collision whoever greps either one pays for. Scoped honestly: no
  hook selects either token, so this was never a session-start ambiguity.
- **Lens only.** The dual-read layer covers four kinds, and the other three — manual, persona, subagent —
  live in a consumer's **plugin cache** rather than in their own tree, so their retirement is keyed on
  which versions are still installed somewhere, not on this register. The roll-up's closing line says so;
  `Get-SpecialistFileShapes`' banner in `check-report-lib.ps1` is the place that decides any of it.

**Retiring a spelling is a deliberate act with its own issue -- [#2292](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2292) -- and never a tidy-up folded into a rename** —
and the green line above is the evidence that act may be *proposed*, not a licence to perform it.

## Maintenance: drift lint

Through the `github` marketplace source, the Claude Code CLI clones and caches this repo itself for
every consumer, so no physical copy in the consuming repo is needed and thus no sync step either —
every consumer literally consumes the same files. Left over from a transition, however, a consuming
repo may still have an outdated local copy of an agent def that is by now shared here.
[`scripts/lint/check-consumer-drift.ps1`](../scripts/lint/check-consumer-drift.ps1) (invoked
per consumer as part of the `check-connectors.ps1` run above, or standalone) compares such a local
copy (read-only, changes nothing) with the canonical version here and reports `MISSING` (already
migrated), `IDENTICAL` (dead copy, safe to remove), or `DRIFTED` (inspect first before removing). The
cleanup itself happens in the consuming repo, not by this script. The same script's persona-body
comparison is covered separately below, see [Persona drift](#persona-drift-how-to-read-a-drifted-report-doctrine).

```powershell
./scripts/lint/check-consumer-drift.ps1 -ConsumerPath C:\path\to\life-hub
./scripts/lint/check-consumer-drift.ps1 -ConsumerPath C:\path\to\smartwatchbanden
```

## Sibling divergence: mechanisms one consumer has and its sibling does not

The drift lint above runs **source → consumer**, and so does every other check on this page. This one
runs **consumer → consumer**:
[`scripts/sync/check-consumer-siblings.ps1`](../scripts/sync/check-consumer-siblings.ps1) compares the
tooling layers (`scripts/`, `.github/`, `.claude/`) of the consumers that share a `siblingGroup`.

```powershell
./scripts/sync/check-consumer-siblings.ps1
./scripts/sync/check-consumer-siblings.ps1 -Group bwj-store -SkipAliasCheck
```

**Why it exists, measured September 11, 2026 in the two BWJ stores**
([#1869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1869)): of the 48 tooling paths
they share, **47 have diverged, and the one that has not is a verbatim template this marketplace
ships**. The load-bearing instance is `scripts/task/prune-merged.ps1` — inbound
[#815](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/815) asked for it centrally,
`dkj-policy` 4.21.0 shipped it, one store replaced its copy with a forwarder on August 28 and the other
still carried its own 120-line version three weeks later. **The inbound route worked; nothing
propagated the result to the second consumer.** So *"shipped centrally"* and *"used centrally"* are
different facts, and until now nothing was watching the gap between them.

**This register was asked for in order to make exactly that visible.**
[`xoxowildhearts.json`](xoxowildhearts.json)'s own notes say so — *"the register is where the two
Shopify consumers diverging can be seen"* — and it had never been given the check that reads it that
way. This is that check.

The finding classes, answering different questions:

| class | what it means |
|---|---|
| `ONLY-IN` | a comparable path present in exactly one member. The `prune-merged` case. |
| `PARTIAL` | a comparable path present in some members but not all — only reachable in a group of three or more. |
| `DRIFTED` | a comparable path present in every member, with differing content. The 47. |
| `ALIASED` | one capability (an exported function name) at **different paths** in two members. |
| `SHIPPED` | a path a plugin in **this marketplace already publishes**. An adoption gap, not divergence. |

**`SHIPPED` is the class that says the mechanism already has an owner**
([#1885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1885)). The three lanes above it are
consumer-to-consumer, so a script both stores re-implement reads as `DRIFTED` and one that only one of them carries
reads as `ONLY-IN` — and neither sentence contains the fact that decides what to do about it. The result
was upside down: the **cheapest** convergence, *adopt what already exists*, was the one nothing could
see, while the expensive kind — decide an owner, move the mechanism, release, adopt — was the only kind
reported. Measured on the BWJ pair the day it was added, it names six, including `prune-merged.ps1`
itself and `scripts/tests/test-lib.ps1`, which `dkj-policy-bwj` had begun shipping hours earlier.

**It adds and never reclassifies, and the match is on filename.** A `SHIPPED` path is still reported as
`ONLY-IN` or `DRIFTED` beside it, because a filename is weak evidence and a wrong match must cost a
reader one file to open — never a real divergence finding silently dropped from the report. The index is
bounded to `.ps1` for the same reason: every plugin ships a `README.md`, so a basename index over all
files would answer *"already shipped"* for every README in every consumer. The opposite bound is real
and no report closes it — a consumer that **renamed** its copy is invisible here, and `ALIASED` is the
lane with any chance of finding it.

**`ALIASED` is the class no path comparison can make, and it is why the names having drifted apart
matters.** `market-domains.ps1` here against `market-urls.ps1` there share no path, no filename and no
line — and both export `Get-MarketPreviewUrls` and `Write-MarketPreviewUrls`. A path comparison reports
two unrelated absences; this reports one duplicated mechanism, with the shared function names as the
evidence, strongest pair first. It is computed over the `ONLY-IN` set alone, which is a scoping
property rather than a shortcut: a path present in every member cannot be aliased, so the files whose
content has to be read are exactly the ones already reported.

**What is deliberately not compared.** The specialist lenses, `SPECIALISTS.md`, `scripts/repo-config.ps1`,
`.claude/memory/` and the GitHub boilerplate are repo-specific **by design** — for each of them
*agreement* would be the defect, not divergence. On the BWJ pair those exclusions remove 27 of the 48
shared paths, so the report is 21 actionable findings rather than 48 with the real ones buried. The test
suites are **not** excluded, and that is deliberate: two consumers testing the same shared lib twice is
precisely the duplication being hunted.

**It reports and refuses nothing** (Dave, September 11, 2026, choosing the detector-first shape over
moving ownership immediately). A detector changes no ownership and needs no consumer to adopt anything,
which is what lets it run today against repos whose convergence is still an open decision.
`-FailOnFinding` exists for a repo that later wants a gate; nothing in this workflow passes it.

**One read route per group, always.** Members are read over `gh` (one git-trees call each, blob shas,
no content transferred) or off a resolved `localCheckout`, and a group whose members cannot all be read
the same way is reported as unreadable rather than compared — a blob sha against a content hash would
report every path in the group as drifted, a false alarm indistinguishable from the finding the check
exists to make.

## Persona drift: how to read a DRIFTED report (doctrine)

Recorded after the drift investigation of July 17, 2026 (Rebecca; dossier
`persona-drift-doctrine`), which established across all seven reports at the time: **zero**
deliberate changes to portable bodies, one genuine lag, and six false positives caused by one
structural path difference.

- **There is no "deliberately divergent" status for the portable body.** Practice confirms the
  model: repo-specific content belongs in the `## Specific to this repo` slot (the lens), and a
  desired change to the portable part goes through the inbound route above — never as a permanent
  local divergence. So the check does not need to facilitate or mark deliberate drift.
- **Lens-only personas produce no body drift.** A correctly set-up persona lens (in the seam,
  `.claude/specialists/lenses/`) no longer carries a body copy -- the
  portable body comes from the plugin install via an `@`-import. Since #64 the index line is
  location-independent plain text (no path-depth link), so there is nothing left to normalize.
  `check-consumer-drift.ps1` recognizes the `> Repo-lens (lens-only persona)` blockquote and
  reports such a lens as `LENS-ONLY`; a consumer with an old, full body copy is still compared for
  real body drift.
- **A `DRIFTED` persona therefore always means a work item**: either lag (the source has moved on
  — refresh the copy from the source in a session of the consumer itself), or a not-yet-returned
  consumer change (bring that back through the inbound route first). Don't dismiss it, don't leave
  it sitting.
- **After a refresh, also update the manifest** (`notes`, and the `extensions` inventory if lenses
  were added or removed): the investigation found an already-performed refresh that was still
  administratively booked as open — the registry data should follow reality.
- **Update the `extensions` inventory in the same change that lands the lens — nothing will remind
  you later.** "Exists in the consumer but is not in the register" is an `[INFO]`, and the session
  hook surfaces only `[ERROR]` lines, so a drifted inventory is invisible at session start; it takes
  a deliberate run of `check-connectors.ps1` to find. On July 29, 2026 such a run found eleven of
  them at once, six in the register of *this* repo — the lenses had landed with the adopt-the-six
  change (PR #212) and the inventory was simply never updated alongside. The rule above ("after a
  refresh") was already there and was not enough, because it reads as a follow-up step and a
  follow-up step is exactly what goes missing. Treat the inventory as part of the lens change, not
  as bookkeeping that trails it.

## The session check (automatic)

The **`dkj-policy`** plugin carries a **SessionStart hook**
([`hooks/hooks.json`](../plugins/dkj-policy/hooks/hooks.json) +
[`connector-sessioncheck.ps1`](../plugins/dkj-policy/hooks/connector-sessioncheck.ps1)) that, when a
session starts, locates the workshop checkout and runs the connectors check there.

**It moved out of the core on August 8, 2026, and the reason is what this register is.** The check
reads *this* register — Dave's own list of his own repos — and looks for a local workshop checkout to
run it from. That is one person's multi-repo administration, not a craft any consumer shares, so a repo
that merely enabled the specialists was running a session hook about somebody else's repos. It now
travels with the opt-in workflow, which is where the rest of that way of working lives. A consumer
who does not enable that workflow never sees it — which, since only Dave's repos are in the register, is the
correct outcome for everyone else.

In the repos that do carry it — life-hub and smartwatchbanden among them — two guardrails from the
security review apply: the found path is **verified** first (a marker check on the marketplace name in
`.claude-plugin/marketplace.json` — never run code on a guessed path), and outside the workshop
the check is **scoped** to the repo's own manifest, so a session never gets another consumer's
registry data into its context. Beyond that the hook is deliberately soft: no verified workshop
checkout means a notice and nothing more, only **blocking signals** (`[ERROR]`/`[DRIFTED]`) end up
as a compact summary in the session context, and the hook never blocks a session start (always
exit 0, read-only). `[INFO]` signals — registry administration about the sync state and the
registration of consumers: sometimes something to update here, often the business of another
machine or user, but in no case work worth interrupting a session start for — deliberately stay
silent at session start (decision by Dave, July 20, 2026); they are visible on a deliberate run of
`check-connectors.ps1` in the workshop. From this follows
a classification rule for extensions of the check (security review advice, July 20, 2026): a new
signal category that may be security-relevant (e.g. an indication of tampering) must never be
classified as `[INFO]`, but as `[ERROR]` — otherwise it silently stays out of sight at session
start.

**First named exception to that silence: `[UNREGISTERED]`** (July 28, 2026). "This repo has no manifest
in the register" was filed as `[INFO]`, and the consequence was the worst possible reading: a
brand-new consumer got `connector-sessioncheck: no errors.` — a positive all-clear for a repo this
workshop cannot see at all (no plugin-version check, no lens inventory, no agent-def drift). Found
after a third consumer had been running, and filing inbound issues, unregistered for days without
anyone noticing. `check-connectors.ps1` therefore also emits a **non-counting `[UNREGISTERED]`** line
that the hook does surface, next to the no-errors verdict rather than under it — nothing is wrong with
the plugin install there, only with this workshop's view of it, so the exit code stays 0 and the
per-signal `[INFO]` line stays suppressed.

This is deliberately *not* a relaxation of the `[INFO]` rule above. That rule was justified as "often
the business of another machine or user"; this signal is the exact opposite — it is about the repo the
session is in, and it is actionable there. The mechanism is the same one `check-roster-sync` uses for
`[ORPHANS]` (inbound #204): a dedicated non-counting token, rather than promoting the finding to
`[ERROR]` and putting a red line plus a non-zero exit code in every session of a repo somebody
deliberately chose not to register.

**Second named exception, one step further in: `[INVENTORY]`** (July 29, 2026). The repo *is*
registered, but its entry lists fewer lenses than the repo actually holds — the `[INFO]` at check 3.
Same failure mode as the first exception, and it had already happened: a deliberate run found eleven
of these at once, six of them in **this repo's own entry**, where the lenses had landed with the
adopt-the-six change (PR #212) and the inventory was simply never updated alongside. Nothing had
surfaced it for a day, because the finding is an `[INFO]` and the hook shows only `[ERROR]` lines. The
["update the inventory in the same change"](#maintenance-drift-lint) rule was added at the same time,
but a rule alone was demonstrably not enough — the earlier "after a refresh, also update the manifest"
rule was already on the books when this drift happened.

Scoped exactly as narrowly as the reasoning allows: `check-connectors.ps1` emits the marker **only for
the connector whose checkout is the repo the session is in** — the workshop's own `localCheckout: "."`
entry on a full sweep, or the consumer's own entry under `-OnlyConsumer`. Every other connector's
inventory drift stays an `[INFO]` and stays silent, so the `[INFO]` rule's justification ("often the
business of another machine or user") keeps applying wherever it is actually true. Decision by Dave,
July 29, 2026.

**Third named exception, and the first that is not about the register's view: `[NOT-INSTALLED-HERE]`**
(August 9, 2026, [#533](https://github.com/DaveKJohn/claude-code-specialists/issues/533)). Here the
register is right and the *machine* is wrong: a plugin is enabled for this repo and has no install
record for this checkout, so a session here loads none of it — no skills, no subagents, no hooks. Check
4 reports that as an `[INFO]`, and the reasoning for keeping it one is sound for a consumer this check
is merely walking: the install may legitimately belong to another machine, so the state is not
conclusive. That second reading **does not exist for the repo the session is running in**, which is
where the marker is added — the same `Test-IsSessionRepo` scoping as `[INVENTORY]`, for the same reason.

What made it necessary is that the two artefacts that could have spoken both could not. A mid-session
`git pull` carried this repo across the plugin rename: `.claude/settings.json`, the register and the
plugin tree all moved to the new names in one fast-forward while `installed_plugins.json` kept the old
record, leaving **both** enabled plugins without an install record. The `[INFO]` was suppressed by the
hook, and `check-roster-sync`'s marker of the same name is unreachable at session start **by design** —
a session start writes the record itself before any hook can look (see `roster-sessioncheck.ps1`). So
the repo ran with none of its own specialist surface, the one plugin line in the session context
reported a version gap on a plugin that was no longer enabled, and it was found by hand.

Non-counting like the other two: nothing is wrong with the source, only with what this machine has of
it, so the exit code stays 0 and the per-signal `[INFO]` still stays suppressed. In the hook it takes
the headline when it fires — a session running without the surface it thinks it has outranks a register
finding about a repo that otherwise works — and the register notices are printed next to it rather than
under it.

**Fourth named exception, one level further OUT than `[INVENTORY]`: `[UNLISTED]`** (September 10, 2026,
[#1775](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1775)). `[INVENTORY]` is about a
lens the register's own plugin block forgot to list; this one is about a **whole plugin block** the
register forgot — an id enabled in the consumer's settings chain that this manifest's `plugins` array
does not name at all, so the per-plugin loop that checks 2-4 run under never even reaches it. Nothing
about that plugin is checked: not the extension list, not the machine version, nothing — and the loop,
by construction, cannot report an absence it was never handed.

Measured against this repo's own register at the time: five of the six plugins `.claude/settings.json`
enables sat outside that loop. One of the five happened to coincide with a manifest entry naming that
plugin's *old*, retired id — which is reported as an `[INFO]` by the loop's own guard clause (the
`if ($null -eq $pluginDir)` branch that runs BEFORE checks 2-4 and skips a plugin block entirely on a
miss, `retired` being one of its three ways to miss) — so it read as covered while the *current*,
enabled id itself was still never examined; the other four produced no line anywhere in the run. Filed
as `[INFO]` at check 5 for the same reason `[INVENTORY]` is:
a register that is merely behind is not a fault to interrupt a session over, and a deliberate run should
still list every one. Same `Test-IsSessionRepo` scoping as `[INVENTORY]`/`[NOT-INSTALLED-HERE]`, for the
same reason — every *other* connector's under-registration stays an `[INFO]` and stays silent, because
that is genuinely the maintainer's business rather than this session's.

**Scoped to this register's own marketplace, not to every id a consumer might enable.** An id naming a
different, unrelated marketplace is not this register's business at all and is silently left out of the
comparison — this register only ever describes what a consumer has of the plugins *this* repo publishes,
and a third-party id is outside that scope by construction, not merely uninteresting.

**A NEW TOKEN, DELIBERATELY, RATHER THAN A FOURTH MEANING FOR `[INVENTORY]`.** The two subjects are one
level apart — an extension missing from a plugin block the register already lists, versus a plugin block
missing outright — and folding them under one marker would make the hook's summary unable to say which
of the two is true. `[UNLISTED]` says exactly what happened: present in the consumer, absent from the
list.

**A version verdict says which commit it was read at** (August 9, 2026,
[#533](https://github.com/DaveKJohn/claude-code-specialists/issues/533)). Every `source on vX` in a run
comes from a `plugin.json` in the workshop checkout, read at that moment — and the session hook forwards
it into a context that keeps it for hours. A `git pull` in that window ages the claim with nothing to
show for it, which is not hypothetical: a session started at `faa7273` (source v3.6.0), the checkout
moved to `855fd40` (source v3.9.0) at 10:24, and the line already in context still said v3.6.0. It was
repeated as current fact, because an undated claim is indistinguishable from a fresh one.

So the run header names the commit: `== check-connectors -- 4 manifest(s) -- source read at 5becd87 ==`,
and the hook lifts that value into its summary line with a pointer to `git rev-parse --short HEAD`. Two
properties worth keeping when this is touched: it is printed **once at run level**, because it is the
same answer for every finding and repeating it per line costs the reader on every line to say nothing
new; and the hook **lifts it rather than measuring its own**, because the commit that matters is the one
the versions were read at, and a second `git` call could put a wrong timestamp on a right number — worse
than none, since it invites trust. No git, no header, no stamp: an omitted stamp is honest.

**Registering a new consumer is a workshop-side, manual step, and nothing can do it for you.** The
manifest lives here while the install happens in the consumer, and this registry never writes
cross-repo — so the `specialists-init` skill closes the loop from the other side: after bootstrapping a
consumer it prints a **paste-ready manifest block** (repo name derived from the git remote, the lens
inventory per plugin, `visibility` and `localCheckout` left as `VUL-IN` because it cannot know them),
which then lands here through the normal branch + PR flow. This hook is one of the named, repo-neutral
exceptions to the rule that plugins carry no hooks/skills — the full list is in
[Sylvester's repo lens](../.claude/specialists/lenses/specialist-05-15-lens.md#what-lives-here-and-what-doesnt), and it has grown since
this paragraph first named its two siblings — and shrank again on August 26, 2026: three SessionStart
hooks (`connector-sessioncheck` and `script-contract-sessioncheck` in `dkj-policy`,
`roster-sessioncheck` in the core team), two Stop hooks (`cycle-autopark`, also
`dkj-policy` — the first hook here that *acts* instead of reporting, #900 — and `closeout-gate`, the
first that *refuses*, #2050) plus the skill
`specialists-init`. Mind the **version gate**: consumers only receive the
hook after a release bump plus `claude plugin marketplace update <marketplace>` and
`claude plugin update <plugin>@<marketplace> --scope project` (neither the refresh nor the scope flag
is optional — see [Installing it yourself](../plugins/ADOPTION.md#installing-it-yourself)) + session restart on
their side.

The same gate applies to a newly added **skill** file.
Watch out here in particular: the `/reload-plugins`/`/reload-skills` skill counters are no proof
that this hook has landed for a consumer — treating a reload notice as that confirmation is exactly
the trap from #186.
