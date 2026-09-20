---
id: 25
group: 06
---

# Nolan ⚡ · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-25-manual.md`). This file does not describe the craft, but what Nolan measures in this repo and with whom he works.

A performance engineer does the same thing everywhere — measure resource cost and trim it without
losing function. **What is repo-specific in claude-code-specialists is not that Nolan measures, but
which loading chains, docs and gates fall under him here, and the mechanism already in place that gives
him levers to pull.**

**Two resources since August 10, 2026, and the second one is why the widening happened.** Nolan owned
token/context budget alone, and the honest state of that half is that its easy room is spent — the
sections below record two verdicts of *leave it alone*, reached by measuring. Meanwhile a release here
takes about thirty minutes, of which roughly seventeen is gate time, and nobody owned that. Measured on
pickup: Nolan is named 12 times in this repo's record and **all 12 are in `1.x` and `2.x`**, the last
around August 2 — no work at all across the twelve releases of `3.x` and `4.x`. That is not a specialist
who does little; it is a proven craft whose one resource ran out of surface while a second was going
unmeasured. Decision by Dave, August 10, 2026, over the alternative of a separate build/CI specialist:
the craft is the same, only the bill differs.

### What Nolan measures here

- **The deliberate loading strategy** described in
  [`CLAUDE.md`](../SPECIALISTS.md#the-claude-specialists--who-does-what): only Chris's operating
  manual loads automatically (via the `@` import at the bottom of `CLAUDE.md`, because he is
  involved in every assignment); every other specialist's portable playbook + repo lens is read
  **on demand**, at the moment Chris assigns work to them — "deliberate, to save context/tokens".
  Nolan checks whether that boundary still holds as the roster grows: does a new persona/subagent
  stay on-demand, or has something crept onto the automatic path that doesn't need to be there?
- **The size of agent-defs, manuals, and personas** across the plugins
  (`plugins/*/subagents/*-subagent.md`, `*/manuals/*-manual.md`,
  `specialists/personas/*-persona.md`): a manual/agent-def that has grown well past what its craft
  needs is a cost on every load, not a one-time read.
- **The `subagent-shared/` mechanism** (see [Sylvester #15](specialist-05-15-lens.md) and
  [Ravi #24](specialist-06-24-lens.md)) as a *frugality lever*, not just a DRY tool: a rule that lives once
  in `subagent-shared/<name>.md` and is filled into N agent-defs by the generator costs one edit instead
  of N, and Nolan can point to it as evidence when a savings proposal is "promote this to a shared
  block" rather than "trim this in each of the N places separately".
- **Repeated context across a chain**: whether a multi-specialist chain (see
  [Chris #01](specialist-01-01-lens.md#chains-multiple-specialists-in-sequence)) re-reads the same doc
  more than once where a single, targeted read would do.

### How to measure it — `claude plugin details` (July 28, 2026)

There is an authoritative measurement; do not estimate from file sizes:

```powershell
claude plugin details dkj-subagents-alpha@dkj-claude-plugins
```

It reports **Always-on** (tokens the plugin adds to *every* session through its listing text — skill
descriptions, agent descriptions, command names, whether or not anything fires) and **On-invoke** per
component, computed via the `count_tokens` API for the active model. The baseline measured at v2.10.0:

| | tokens |
|---|---|
| Plugin total, always-on | **~3.505** |
| — 15 agent descriptions | ~2.260 |
| — 7 skill descriptions | ~1.245 |
| SessionStart hook | 0 — reported as *"harness-only — no model context cost"* |

**The finding this produced, and the reason it is written down.** The `CLAUDE.md` roster used to spell
out all 15 subagents with their descriptions. Those descriptions are **already** in every session — the
~2.260 above — so the table was paying twice for the same information. Removing them shrank `CLAUDE.md`
by 2.799 characters, **~750 tokens per session**.

**Since September 10, 2026 that table has a hole in it, and the instrument does not say so.** The
inventory's `Agents (N)` counts only defs found by convention in a plugin's default `agents/` directory.
The four team plugins name their defs by path in the manifest's `agents` key — `subagents/` is not the
default directory, so the key is what the validator requires — and against Claude Code 2.1.267 those
defs **load in a session** while the inventory counts **zero** of them. So for every one of the four,
`claude plugin details` now prints `Agents (0)` and an Always-on total that is **skills only**: alpha
reads ~819, and the ~2.260 of agent descriptions the row above measures is simply absent from it. The
figure is not wrong about what it covers; it is silent about what it omits.

**Two ways that misleads, both measured
([#1771](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1771)).** A share computed
against that total reads as *"the skill descriptions account for effectively ALL of this plugin's
always-on cost"* — false by roughly a factor of four for alpha. And `Agents (0)` reads as *"this plugin
ships none"*, which is what produced #1771: a report concluding the four team plugins register no
specialists at all, filed against a session that had all 26 of them in its own agent list.
`measure-skill.ps1` now says both things out loud rather than leaving the reader to notice, and its
suite pins them.

**How to settle a claim like that, since `plugin details` cannot.** Build a throwaway local marketplace
with one plugin, put two agent defs in a non-default directory, name only **one** of them in the `agents`
key, install it **fresh** into a scratch project, and then **dispatch each one** from a real session
(`claude -p`). Measured that way: the named def returns its word, and the unnamed one in the same
directory comes back `Agent type '<name>' not found`. That is what makes the key's behaviour a
**reporting** defect rather than a loading defect.

**Two ways that method goes wrong, both met on the first attempt.** Asking a session to *list* its
`subagent_type` values is not a measurement — a model can answer it from belief, so the run has to
**invoke**. And installing one def, then adding the second by updating the plugin in place, measures the
resolved snapshot rather than the key: the CLI says `Restart to apply changes`, and the absent def is
then absent for the wrong reason. Ship both defs in the first version, list the resolved cache before
dispatching, and the reading is unambiguous. The general lever, which is this lens's own subject applied
to itself: **an instrument that reports a component is not evidence that the component loads, and the
only thing that is, is loading it.**

Be precise about that second number's provenance: `claude plugin details` uses the `count_tokens` API,
but it only measures *plugins*. A `CLAUDE.md` delta has no such command, so ~750 is a character-based
estimate — good enough to decide by, not a measured figure like the ~2.260. The first attempt landed at
~660 because the explanation that had to replace the rows was written *into* `CLAUDE.md`, which is
loaded every session; moving it into this lens (read only when Nolan is called in) recovered the rest.
That is the general lever: **the justification for a trim does not belong on the always-on path.**

Two things that make this generalizable rather than a one-off:

- **Personas are the opposite case.** Only *agents* appear in the always-on listing. The four
  persona-only specialists (Chris, Bianca, Derek, Rendall) appear in none, so the roster table is the
  only place they exist for a session — their rows are not duplication and must stay. Any future
  trimming has to keep that asymmetry.
- **The check constrains the shape of the trim.** `check-roster-sync` scans the roster text for each
  `<group>-<id>` token, so the ids have to stay present even when the prose goes. Dropping the rows
  entirely would have produced 15 false "no roster row" errors. Hence: keep a compact id line, drop the
  descriptions — a trim that needed no change to any shared script.

### Chris's always-on path — measured, verdict: leave it alone (July 28, 2026)

The open question from the roster trim, now answered. `CLAUDE.md` `@`-imports two files, so three
documents load in full on every session:

| always-on | characters | ~tokens |
|---|---|---|
| `CLAUDE.md` | 24.388 | ~6.600 |
| Chris's portable body (`personas/01-01-persona.md`) | 6.628 | ~1.800 |
| Chris's repo lens (`specialist-01-01-lens.md`) | 12.274 | ~3.300 |
| **documents total** | **43.290** | **~11.700** |
| plus the plugin listing (`claude plugin details`) | | ~3.505 |

So roughly **~15.200 tokens are spent before a single assignment is given.** Chris's lens, at ~3.300,
is the largest single specialist file in the repo and the only one on the automatic path.

> **The token column here is computed at 3.70 chars/token, which was calibrated in 2026 and found to be
> ~19% too generous** — see [the calibration below](#the-conversion-factor-calibrated--and-the-layer-re-measured-at-it-august-15-2026).
> The character counts are measurements and stand; the tokens derived from them are under-stated.
> Left as computed rather than restated, because this table records what was believed on July 28.

Broken down by section: routing table 3.023 chars · chains 2.784 · gatekeepers 2.250 · Dave rules
1.589 · new-specialists 945 · intro 897.

**The verdict is that there is no free win here, and that is worth recording** — the roster case made
this look like the same kind of target, and it is not. Two traps, both hit while measuring:

- **The routing table's "Repo lens" column looks like duplication and is not.** Thirteen links of an
  apparently uniform `<g>-<id>-extension.md` shape, so the obvious trim is to state the pattern once and
  drop the column. That breaks it: the group prefix is **not** derivable from the display number.
  Derek #05 is `05-05`, but Rebecca #07 is `03-07`, Rendall #06 is `05-06` and Tycho #18 is `04-18`. That
  column is the only always-on place the group lives. Do not remove it.
- **The gatekeepers section restates safety rules `CLAUDE.md` already carries in full**, both always-on
  — the one genuinely reducible ~600 tokens. But it is deliberate reinforcement at the point of use, and
  Claude Code's own guidance is explicit that instructions are context rather than enforced
  configuration, so *how* they are written affects how reliably they are followed. Cutting it therefore
  trades tokens for adherence. That is a different kind of decision than removing a description that was
  already in context twice.
  **DECIDED (July 29, 2026): keep it. Do not revisit this as a token saving.** Dave deferred the call
  until after the trim; the trim happened (`CLAUDE.md` 328 → 282 lines, the language detail
  path-scoped), and the same session produced the evidence that settles it. The session-reply language
  rule sits in `CLAUDE.md`, always-on, never compacted away — and it was **broken anyway**, for an entire
  session, until Dave pointed it out. So always-on presence demonstrably does *not* guarantee adherence.
  That cuts one way: a second statement at the point of use is not redundancy, it is the second chance
  that the first statement measurably needs, and ~600 tokens is a cheap price for one. The reducible
  tokens are real; the thing they buy is more valuable. Reversible in one PR if Dave disagrees.

**The lever this leaves.** Reduce cost by moving content *off* the automatic path rather than deleting
it: `CLAUDE.md` at ~6.600 tokens is the biggest item and was 277 lines against the documented target of
under 200, and path-scoped `.claude/rules/` files load only when Claude touches matching files. That is
the direction with room in it — not Chris's lens.

### `.claude/rules/` — the verified rules of the lever (July 29, 2026)

The lever above rests on a claim that was **unverified** when it was written. It has now been checked
against the docs, and the answer constrains it in a way worth knowing *before* moving anything:

| at `/compact` | what happens |
|---|---|
| project-root `CLAUDE.md` and rules **without** `paths:` | re-injected from disk |
| rules **with** `paths:` frontmatter | **lost until a matching file is read again** |

Two consequences, and together they define the whole trade:

- **A rule without `paths:` saves nothing.** It loads unconditionally with the same priority as
  `CLAUDE.md`, so relocating text there is filing, not trimming. **The scoping is the saving** — if a
  candidate cannot be given a `paths:` list, it is not a candidate.
- **A `paths:`-scoped rule is not always-on, by design.** After a compaction it is gone until Claude
  reads a matching file. So the test for a candidate is: *is this content inert until someone opens a
  matching file?* If yes, the scoping is self-healing — touching the layer reloads the rule. If the
  content must hold regardless of which files a turn touches, it belongs in `CLAUDE.md` and no amount
  of tidiness changes that.

**Worked example, and the trap inside it.** The `### Language` section (65 lines, the largest in
`CLAUDE.md`) was mostly per-layer detail about `scripts/**`, `.github/**` and `releases/**` — textbook
path-scoped material, and it moved to `.claude/rules/language-layers.md`, taking `CLAUDE.md` from 328 to
**282 lines**. But the section also contained one sentence that had to stay: *the session-reply language
follows the user*. That governs every turn regardless of files touched, so path-scoping it would have
silently weakened it after the first compaction — and it is a rule that had already been broken in
practice earlier the same day. **Read a candidate section for the one sentence that is not about the
files, before moving the block.** The docs' own phrasing of the escape hatch is the tell: *"If a rule
must persist across compaction, drop the `paths:` frontmatter or move it to the project-root
`CLAUDE.md`."*

Remaining candidates in `CLAUDE.md`, by size, with the test applied: the roster/routing table (53 lines)
**fails** it — routing is needed at intake, before any file is read; the safety rules (34 + 31 lines)
**fail** it — they must survive compaction; `## The Claude Specialists` (46 lines) **fails** it. So the
easy room is now spent, and what is left is the judgement call recorded above rather than more
relocation.

### The always-on path, re-measured — it has grown 158% (August 14, 2026)

The July 28 table above is the baseline, and it is now badly out of date in the direction that matters.
Re-measured on `73579e8`, with the seam document that did not exist then:

| always-on | July 28 | August 14 | |
|---|---|---|---|
| `CLAUDE.md` | 24,388 chars | **73,298** | 277 → **875 lines** |
| Chris's repo lens (`specialist-01-01-lens.md`) | 12,274 | 19,405 | |
| Chris's portable body (`personas/01-01-persona.md`) | 6,628 | 11,075 | |
| `.claude/specialists/SPECIALISTS.md` (the seam) | *did not exist* | 7,982 | a fourth document on the path |
| **total** | **43,290 · ~11,700 tokens** | **111,760 · ~30,205 tokens** | **+158%** |

> **Same caveat, and here it matters more: the token figures use 3.70 chars/token and are ~19% low**, and
> this table omits the plugin listings entirely. Corrected in
> [the calibration below](#the-conversion-factor-calibrated--and-the-layer-re-measured-at-it-august-15-2026);
> the byte column stands and the **+158%** is unaffected, because a ratio of two figures converted at the
> same wrong factor is right.

**`CLAUDE.md` is at 4.4× the target this repo set itself.** The July 28 note records it as *"277 lines
against the documented target of under 200"* and named moving content off the automatic path as the lever
with room in it. Seventeen days later it is 875. Nothing about that is an accident of one branch: it is
what recording the reasoning behind every decision costs when the decisions come at a release every nine
days.

**The lever is unchanged and the constraint on it is unchanged**, so this is a re-measurement rather than
a new proposal: the `paths:`-scoped candidates were assessed above and the easy room was spent then. What
has arrived since is a large, genuinely path-scoped body — the release, changelog, tier and significance
machinery, inert until somebody touches `dkj-policy/**`, `CHANGELOG.md` or runs a cut. It is also
the body with the worst failure mode if scoped: a rule that is gone after a `/compact` is gone in the
middle of a release, which is exactly when it is being followed.

**So the number is recorded and the cut is not made.** That is Dave's call on his own governance document,
and the honest framing is that this is a trade between context cost and the risk of a rule vanishing
mid-release — not a tidying job. Recorded because a measurement that is seventeen days and 158% stale is
worse than none: it invites the next reader to plan against ~11,700 tokens that have not been true for a
fortnight.

### The conversion factor, calibrated — and the layer re-measured at it (August 15, 2026)

**Every always-on token figure in the two tables above is under-stated, and the cause is one number
nobody had ever checked.** Both convert at **3.70 characters per token**, a factor that entered these
notes on July 28 and was inherited unexamined through three re-measurements. It is wrong by about 19%,
in the direction that makes the layer look cheaper than it is.

**How it was calibrated, since the lens's own rule is *do not estimate from file sizes*.**
`claude plugin details` is the authoritative count and it only prices *plugins* — but that is enough,
because what is wanted is the ratio and not the tool's coverage. Ten skill pages of this repo's own
prose, each sized on disk and token-counted by the `count_tokens` API behind that command:

| n | min | median | mean | max |
|---|---|---|---|---|
| **10** | 2.95 | **3.12** | 3.07 | 3.23 |

Spanning 5,002 B to 47,434 B, and the spread is tight enough to decide on. **3.12 is the factor to use
here**; anything derived at 3.70 is low by 19%. The reported on-invoke figures are rounded to two
significant figures, so the ratio is good to a few percent — not to three digits.

**The layer, re-measured at 3.12 and with the plugin listings included** (they were omitted from both
earlier tables, which is the second half of the under-count):

| always-on | bytes | ~tokens | basis |
|---|---|---|---|
| `CLAUDE.md` | 73,298 | ~23,500 | 3.12 |
| Chris's repo lens (`specialist-01-01-lens.md`) | 21,462 | ~6,900 | 3.12 |
| Chris's portable body (`01-01-persona.md`) | 11,051 | ~3,500 | 3.12 |
| `.claude/specialists/SPECIALISTS.md` (the seam) | 7,982 | ~2,600 | 3.12 |
| **documents** | **113,793** | **~36,500** | |
| `dkj-subagents-alpha` listing | — | 3,009 | **API-measured** |
| `dkj-policy` listing | — | 2,317 | **API-measured** |
| **total** | | **~41,800** | range ~40,600–43,900 |

**~41,800 tokens, not ~30,205.** The plugin listing has also *fallen* since v2.10.0 — 3,009 against the
~3,505 baseline for `dkj-subagents-alpha`, despite the same 15 agents — so the growth is entirely in the
documents.

**THE PERSONA MEASURED IS THE MARKETPLACE COPY, AND THAT IS NOT A DETAIL.** `SPECIALISTS.md` imports
Chris's body from `~/.claude/plugins/marketplaces/…`, not from `plugins/dkj-subagents/…` in the tree. On the day
of this measurement that clone sat ten commits behind `main` and the two files differed by **1,243 B**:
12,294 B in the repo, **11,051 B actually loaded**. The table above reports what the session loads. The
difference is not error to smooth away — it is **queued cost that arrives at the next plugin update**,
and it is the always-on face of the consequence
[`CLAUDE.md`](../../../CLAUDE.md#specific-to-this-repo-claude-code-specialists) already records: through
the `github` source the team sees the last *pushed* plugins. Resolve the load path before measuring it.

**WHERE THE COST IS: IT IS NOT DIFFUSE, IT IS ONE SUB-ITEM.** `CLAUDE.md` stood at 875 lines in 9
sections on the day of this measurement (re-derive with `wc -l CLAUDE.md` and `grep -c '^## '` — it is
526 in 3 as of September 10, 2026), and breaking it down was the finding rather than the total:

| | bytes | share of `CLAUDE.md` |
|---|---|---|
| `### claude-code-specialists's safety implementation` | **58,893** | **80%** |
| the other 8 sections combined | 14,405 | 20% |

Inside that section, one bullet — `**Two deliberate exceptions to "never directly on main"**` — is
**42,191 B over 485 lines**, against 10,400 B for the gates bullet and 6,188 B for the other six
together. And inside *that* bullet:

| | bytes | lines |
|---|---|---|
| 1. the fold commit | 959 | 10 |
| **2. the release commit** | **41,168** | **474** |

**Sub-item 2 of a two-item list is 56% of `CLAUDE.md` and ~13,200 tokens — 32% of the entire always-on
layer, paid on every turn of every session.** It carries the tier model, the significance rubric, the
audience-tier knob, the two-document merge, the `highlights/`→`audience/` rename and the measurements
behind each.

**The lever, and the one that does NOT apply.** `.claude/rules/` scoping **fails** on most of this block
and that is worth stating plainly so nobody proposes it a third time: much of it must hold *before*
anyone opens a release file — the major-needs-two-commits rule is needed at the decision, not at the
file — and a rule lost to a `/compact` mid-release is gone exactly when it is being followed. The
August 14 note said so and was right.

**What does apply is a lever this repo invented on July 28 and then used once.** That note's conclusion
was *"the justification for a trim does not belong on the always-on path"*, and it generalises:
**the decision belongs on the always-on path; the evidence for it does not.** Almost all of the 41,168 B
is evidence, and its destination already exists and is already named — `CLAUDE.md` itself records
(August 4, 2026) that [Rendall #06's lens](specialist-05-06-lens.md) *"holds the release craft itself"*. That
lens is 39,253 B, read on demand, and costs nothing per session. Probed for overlap, it is already a
mix rather than a clean move: the 62/38 note split, `Get-ReleaseMajorMinMinors` and "10 minors" appear
in **both**, while the significance rubric (13 references), the `highlights/` rename (8) and
`Get-ReleaseAudienceTier` appear only in `CLAUDE.md`. So part is duplication —
[Ravi #24](specialist-06-24-lens.md)'s — and part is relocation — [Tessa #16](specialist-06-16-lens.md)'s.

**Priced, so the choice can be made on a number rather than on a feeling:**

| option | saving per session | cost |
|---|---|---|
| leave it | 0 | nothing; ~41,800 tokens buys a team that does not re-litigate settled decisions |
| move the evidence, keep every operative rule | **~12,000 (29%)** | one PR of careful surgery; the risk is a rule mistaken for evidence and moved with it |
| correct the factor only | 0 | ~20 minutes, and every future cost decision here stops being 19% wrong |

**The last one is this section**, and it is worth having on its own: the first two are a judgement about
the governance document and the third is arithmetic. **The honest counter-argument to the second, kept
beside it:** the growth these notes keep recording is
[the repo's own rule](../../../CLAUDE.md#general-working-practices) working as designed — lessons are
secured in the docs — and moving the evidence does not stop it, it only redirects where it lands.

### The Claude Code best-practices page, held against this repo (August 14, 2026)

[Issue #657](https://github.com/DaveKJohn/claude-code-specialists/issues/657) asked for the official
[best practices](https://code.claude.com/docs/en/best-practices) to be measured against what this repo
already does, rather than adopted wholesale. Done, per practice:

| practice | state here |
|---|---|
| **Give Claude a way to verify its work** | **Fully adopted, and then some.** Three gates (`check-plugin-integrity`, `check-script-contract`, `check-roster-sync`), 36 test suites, CI as a required check, plus `open-pr`/`ship-pr` refusing on a red gate. The page's escalation ladder ends where this repo starts. |
| **Explore first, then plan, then code** | Adopted as a rule rather than a mechanism: an inbound item is verified before it is routed, and a report's *reason* is checked before its symptom is repaired. Since #655 the branch's own plan is PLAN → CREATE → TEST. |
| **Provide specific context in prompts** | The requester's side; nothing for this repo to build. |
| **Configure the environment** | Adopted except for one item: the pruned `CLAUDE.md`. See the re-measurement above — this is the single practice the repo visibly and knowingly diverges from. |
| **Communicate effectively** | Bianca #02 is an entire specialist for interview-to-spec. |
| **Manage the session** | Adopted, and the mechanism changed on August 27, 2026: `lock` and `handover` were the checkpoint/resume pair, with a reporter behind both, until [#957](https://github.com/DaveKJohn/claude-code-specialists/issues/957) removed all three — the branch's own development document had taken the job over, and it is a checkpoint that survives a context clear *and* a machine, which a gitignored file never did. `park` carries the branch itself across. |
| **Automate and scale** | The shared-scripts layer, and an adversarial review step the page suggests: Marlowe reviews the *conclusion* while the other reviewers check the craft. |
| **Avoid the failure patterns** | The over-specified `CLAUDE.md` is the one being lived. The trust-then-verify gap is closed by the gates. |

**The conclusion is that there is one gap, it is known, and it is deliberate.** Recorded here rather than
turned into work, because the page's test — *"would removing this cause mistakes?"* — has an uncomfortable
answer for most of this document: it records **why** decisions were made, and this repo has repeatedly paid
for re-deriving a decision whose reasoning was lost. That is not the same kind of content the page is
warning about, and the honest response is to say so rather than to prune towards a number.

### Wall-clock here — the gates, and the baseline measured at v4.2.0 (August 10, 2026)

Nolan owns wall-clock as of this date, and this repo spends it almost entirely on **gates**. There is no
application to profile: what costs time is what runs before work is allowed to land. Measured during the
`v4.2.0` cut rather than estimated:

| what runs | measured | when it runs |
|---|---|---|
| `check-plugin-integrity.ps1` (**27** checks; 26 when measured) | **9.2–10.6s**, n=3, idle machine ([below](#the-gate-records-saving-measured-on-the-case-it-was-built-for-august-16-2026)) | before every push, and inside the cut |
| the test suites — 30 then, **43** now | **205–232s** then; **196–235s** at 40 suites, n=5 ([below](#the-gates-wall-clock-is-one-suite--re-measured-n5-august-16-2026)); **139.7–195.0s, median ~170s** at 43 post-split, n=11, idle machine ([below](#the-gate-records-saving-measured-on-the-case-it-was-built-for-august-16-2026)) | inside `cut-release`, inside `open-pr`, and again in CI |
| CI `lint-en-tests` | **median 8m 01s**, range 5m 06s–10m 06s (p90 9m 39s) over **65** blocking runs (August 23, 2026); was **median 7m 23s** over 63 on August 11 | every PR; blocks the merge |
| a full release, end to end | **28m 03s**, measured at `v4.4.0` (August 11, 2026) — all of it blocking | per release, ~1.6× per day at the August cadence |

**Apply the count-the-invocations rule before proposing anything here, because this repo trips it.** The
same 30 suites run **three times** per release-with-documents — once in the cut, once in `open-pr`, once in
CI — so a change that halves the suite saves three times what a single run suggests, and a change that
skips one run saves a third while proving less. That triple is **deliberate**: the release commit does not
travel via a PR and therefore meets no CI, which is why the cut runs the suites itself
([the release lens](specialist-05-06-lens.md#why-the-release-commit-takes-no-pull-request) records that the cut
used to run the lint alone and was the least-gated commit in the workflow). Do not propose removing it
without reading that decision.

**The blocking/non-blocking split matters more here than the totals.** The release commit's own CI runs
*after* the push and blocks nobody; the PR's `lint-en-tests` blocks the merge and is the single largest
thing a person waits on. A proposal that shortens the first is worth close to nothing.

**And that single largest thing was priced per WEEK on August 23, 2026, which is a bigger number than the
per-run figure suggests.** 73 PRs merged in seven days, so at the re-measured median the blocking leg alone
is **9h 45m per week**. The 135 `push` runs in the same window (median 8m 05s, indistinguishable from the
blocking leg) block nobody and are deliberately not in that total. Three CI runs happen per branch — the PR
check, the merge push, the fold push — and exactly one of them is a cost under the rule above.

**Two things that number does NOT show, and both belong beside it.** First, how much of those 9h 45m
actually held a person up is **not in the repo**: it depends on whether the ship ran in the foreground, and
no git or gh timestamp records that. Treat it as the ceiling of any saving, never as the saving. Second, the
frequency lever was checked here rather than assumed available — median PR size over that window was **5
changed files and 201 added lines**, with 26 of 73 touching three files or fewer. That is not
over-splitting, so combining PRs would mean combining unrelated work into one branch, which the
entry-per-branch model pays for in traceability. The lever exists; it is not free, and it is not this
lens's to spend.

**The repair that was chosen instead converts the cost rather than shrinking it** — `worktree-lane.ps1`,
which lets a branch be built in its own worktree while another ships, moving that time from blocking to
non-blocking without touching a gate. Note which rule that satisfies: it is not a faster gate and it proves
exactly as much. The alternative on the table was a one-line change to `ship-pr.ps1`; it was measured as
saving two commands per lane and **nothing in wall-clock**, and declined on that trade rather than
overlooked. The mechanics are in
[Derek's branch hygiene](specialist-05-05-lens.md#branch--repo-hygiene).

**The median also drifted up between the two measurements** — 7m 23s (n=63, August 11) to 8m 01s (n=65,
August 23), **+38s, +8.6% in twelve days** — and the table row now carries both. Nothing was proposed about
it: one re-measurement is a data point, not a trend, and the honest next step is a third reading rather than
a hunt for a cause. Worth knowing before quoting the row from memory.

**The frequency lever was live in this repo, was counted, and was DECLINED** (Dave, August 11, 2026).
Batching entries per cut would have been a real reduction needing no code at all; the counterweight is that
`plugin.json`'s version is one of the two update gates, so releasing less often is delivering later. Both
halves are counted in number 3 below — which also replaced the ~17 minutes this paragraph used to estimate
with a measured cost that differs per bump type — and the answer is **no cap on the cadence**. Do not
propose batching here as a saving without new evidence that the ceiling has moved.

**THREE NUMBERS WERE OWED, AND ALL THREE WERE COUNTED ON THE DAY THEY WERE ASKED FOR** (August 11, 2026;
the list was written that morning as *"the next release owes three numbers, and the first is a gap Nolan
left himself"*). All three are counting, not building. **The third differed from the other two in what its
count bought**: they end in a finding, while that one ended in a choice that was Dave's — **and he made it
the same day, declining the lever**. Do not read its table as a recommendation in either direction; it was
priced on both sides so the choice could sit with the person who owns the delivery side, and it did. The
original wording is kept above rather than replaced, because a list of open questions is worth something
only while it says when each one was opened.

1. **ANSWERED at `v4.4.0`, August 11, 2026: a release takes 28m 03s, and 15m 44s of that is gates.** Clock
   started at 10:24:11 before the cut and stopped at 10:52:14 when the Release was published; every leg came
   from a git or CI timestamp rather than from recall. **All 28 minutes blocked a person**, in one serial
   chain — the only non-blocking cost was the release commit's own CI run on `main` (7m 48s), which finished
   inside the writing and nobody waited for. The gate share breaks down as 231s of suites inside the cut,
   200s of the same suites when the note's pull request opened, and 8m 36s of `lint-en-tests` on that pull
   request, which is **56%** of the release and the only place a real reduction can come from. The full table
   is in [`releases/audience/4.x/4.4.0.md`](../../../dkj-policy/releases/audience/4.x/4.4.0.md).

   **Two cautions travel with the number, and they matter more than it does.** That release carried **two**
   entries against `v4.2.0`'s seven, so it measures the clock well and the writing gain not at all — less to
   read is less to write, and nothing here shows the merged-document model is faster than the two-document
   one. And ~30 min was the figure being reasoned about all along: 28m 03s **confirms** the estimate rather
   than improving on it, which is the honest reading of a first measurement.

   **What running it exposed: the document cannot time its own publication.** The note is frozen for its
   pull request while its CI, merge and publish are still running, so the frozen subtotal was 9m 42s of the
   28m 03s — two thirds of the release unmeasurable from inside the file. Step 0a is split into two passes
   now, the second adding the total in its own pull request afterwards. Recorded because the instinctive
   repair — publish the Release earlier — is the wrong one, and is refused in the skill.

   The original reason this was first: **`v4.3.0` improved the release and produced no post-change figure in minutes.**
   The whole cycle ran against *"why does a release take about thirty minutes"*, the hand-written half
   measurably shrank, and the result was reported as **43% fewer words** — a proxy, reported because words
   were what somebody had counted. The gate time *was* re-measured and was unchanged (~13 of the ~30
   minutes); the end-to-end figure was captured neither before nor after, and a baseline cannot be taken
   retroactively. The portable half of that lesson is in
   [Nolan's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-25-manual.md) under *report in the unit the
   question was asked in*.
2. **ANSWERED August 11, 2026: 9 of the 30 suites can change behaviour on a markdown-only diff — so
   "markdown-only, therefore skip the second local run" does not hold in this repo.** Measured over all 30
   files in `scripts/tests/*.tests.ps1` (count confirmed: exactly 30), and every one of the 30 resolved with
   a cited line rather than a guess: **9** read this repo's own real markdown for content and can flip on a
   docs-only diff; **21** build and read only their own fixtures in a temp directory and cannot; **0** were
   undecidable from the source.

   The nine, each with the evidence that makes it a measurement rather than an opinion:

   | suite | what real markdown it reads |
   |---|---|
   | `subagent-shared.tests.ps1` | recursively enumerates every real `*-subagent.md` and `*-persona.md` and asserts the shared-block marker is present in each |
   | `bootstrap-drift.tests.ps1` | reads the real `specialist-01-01-persona.md` for a retired heading, and asserts the real `specialists-init/SKILL.md` names every persona id on disk |
   | `cut-release-guardrail.tests.ps1` | `git ls-files -- '*.md'` — the real tracked-markdown list — held against `cut-release.ps1`'s reserved-root allowlist, so a new root `.md` file can fail it |
   | `pr-body.tests.ps1` | the real `.github/pull_request_template.md` and the shipped reference template held byte for byte |
   | `repo-config.tests.ps1` | the real `CHANGELOG.md` via `Get-ChangelogPath` for retired section headings, and `Get-MojibakePaths` against the real repo root |
   | `teardown-protocol.tests.ps1` | extracts a `Where-Object` from the real `specialists-teardown/SKILL.md` and executes it — its own docstring says outright that rewriting the doc turns the suite red |
   | `script-contract.tests.ps1` | the real `cut-release/SKILL.md`, asserting its text contains `Get-LiveStage` |
   | `shared-scripts.tests.ps1` | copies the real `.github/pull_request_template.md` into a fixture and asserts every comment line was substituted and no checkbox survives |
   | `release-lib.tests.ps1` | the real release list via `Get-ReleaseHistoryPath` -- `dkj-policy/releases/history.md`, in the workflow folder since August 27, 2026 -- asserting the overview targets major `'4'` — the live pin `CLAUDE.md` already records |

   **Two findings worth keeping beside the number.** First, the counter-intuitive result is the one that
   most needed checking, and it held: `check-plugin-integrity.tests.ps1` — the lint-gate suite, which
   exercises checks over agent defs, manuals, personas, skill pages and the changelog — is in the 21. Every
   one of those documents is written by the test into its own fixture; its only use of the real repo root is
   to copy `.ps1` libraries in. The obvious guess (the lint-gate suite must be one of the ones that reads
   real docs) pointed at the wrong nine. Second, `release-lib.tests.ps1`'s major pin and the stale tier table
   in that same list sit in one file but different parts — the pin reads the `#### 4.x` heading
   and the table under it, not the tier table — so repairing that table would not trip the assert. Worth
   stating for whoever opens that repair.

   **The time figure carries its own caveat, by the rule directly above applied to itself.** The nine, run
   standalone, came to **108.6s measured for nine suites invoked individually** — an upper bound, not a
   share of the gate: nine separate PowerShell process starts, against 231s for all thirty inside one
   process. It is not reported as a percentage of the gate, because doing so would restate a proxy as the
   measurement.

   For the second local run, that is the finding: on this repo's own 30 suites, a markdown-only diff is not
   safe to treat as script-free. Whether any run is dropped, skipped, or made conditional on that basis is a
   change to this repo's safety rules and is Dave's call, not a conclusion of this measurement.
3. **COUNTED AND DECIDED August 11, 2026 — THE CADENCE STAYS UNCONSTRAINED. Do not reopen this as a
   saving.** Dave's answer, in his own words: *"ik wil gewoon kunnen snijden wanneer ik wil, dat moet niet
   begrensd worden."* The count below stands and is worth keeping; what it bought was the ability to
   decline the lever knowing its size, rather than assuming it away. The reasoning is at the end of this
   item, under **the decision**.

   The whole lever is worth under four hours per ten days, and its first step is worth twelve times its
   last.

   *The question as it was first written, kept for the record and no longer the state of play:* 16 releases
   in the 10 days to August 10, 2026, each carrying a fixed gate cost that does not shrink with the number
   of entries in it. Batching is a lever needing no code; the counterweight is Dave's and it is real —
   `plugin.json`'s version is one of the two update gates, so releasing less often is delivering later.

   **The count had to be redone, and the recount is the reason to distrust a cadence figure that has sat
   for a day.** Re-measured over the 10 days to August 11 it is **16 releases** again — the same number
   over a different window and a **different mix**: 13 minor, 1 major, 2 patch, with the `3.0.x` patch era
   rolled out of the window. Over the last **seven** days there is **not one patch**, which matters because
   the two bump types do not cost the same. In that same window `main` took **77 merges, 73 of them
   released and 4 not** — and those four are exactly the four entries pending in `CHANGELOG.md`, which is
   the cross-check that says the merge list and the release list are being read consistently.

   **The fixed cost per release, split by what a bump actually triggers.** A patch writes no hand-written
   document, so it opens no pull request and therefore meets no blocking CI — measured, not assumed:
   the hand-written tree held a document for every minor in the window and **none** for `3.1.1` or `3.1.2`.
   (Measured against `releases/consumer/3.x/` and `releases/internal/3.x/`, the two directories that carried
   those documents then; they were merged into `releases/audience/3.x/` on August 12, 2026, one document per
   version, so the count is now read from that single tree and is unchanged.)

   | release kind | blocking gate cost | what it is made of |
   |---|---|---|
   | minor / major (carries a document) | **14m 34s** | 231s suites in the cut · 200s the same suites at `open-pr` · **443s** median `lint-en-tests` on that pull request |
   | patch (no document, no pull request) | **3m 51s** | the 231s cut suites alone |

   The two local legs are cited from [`releases/audience/4.x/4.4.0.md`](../../../dkj-policy/releases/audience/4.x/4.4.0.md),
   which took them from git timestamps. **The 7m 48s CI run on the release commit is excluded** because it
   blocks nobody.

   **THE CI LEG IS A DISTRIBUTION, AND WRITING IT AS ONE RUN WAS THE MISTAKE THIS ENTRY EXISTS TO CORRECT**
   (August 11, 2026, hours after the count above was first recorded). It was written as `v4.4.0`'s **8m 36s**
   — correctly cited, and unrepresentative. The very next pull request came in at **6m 25s**, 25% below it,
   which prompted counting the population instead of collecting a second anecdote. Over every successful run
   of `ci.yml`:

   | runs | n | min | median | p90 | max |
   |---|---|---|---|---|---|
   | `pull_request` — the blocking one | **63** | 5m 17s | **7m 23s** | 8m 36s | 9m 27s |
   | `push` — blocks nobody | 134 | 5m 03s | 7m 16s | 8m 33s | 9m 24s |

   **`v4.4.0`'s run sits exactly on the p90.** So the figure first recorded here was the slow tail presented
   as the fixed cost, and the 6m 25s that exposed it was not an outlier at all — it falls between the minimum
   and the median. The two distributions are near-identical, which says this is **runner variance rather than
   anything about the event type**, and it removes the tempting explanation that a docs-only diff runs faster.
   The median is what the model uses; the range is kept beside it because a cost with a 4m 10s spread should
   never again be quoted as a point. The portable half of this lesson is in
   [Nolan's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-25-manual.md) under *a cost that varies per
   run is counted over its population*, alongside the unit rule it is the sibling of — so it applies to every
   per-run cost he is asked about, not only to a CI gate.

   **The local legs have spread too, and it is not yet counted.** Three observations exist — 231s in the cut,
   200s and 226s at `open-pr` — so they are an n=1 and an n=2 standing next to an n=63. They are left as
   measured rather than silently averaged: their spread is smaller in absolute terms, and inventing a
   distribution from two points would repeat, at smaller scale, exactly the error this entry corrects.

   **One caveat inherited from the superseded figure is kept.** `v4.4.0`'s note states *15m 44s* of gates
   while its own three components sum to *15m 47s* — a 3-second discrepancy, left standing rather than
   smoothed. It no longer affects the model, since that total is not what is used here, but it is a live note
   about that document's internal arithmetic.

   **Priced at that cost, the window's 16 releases spent 3h 31m 38s of blocking gate time in 10 days —
   21.2 minutes per day.** One caveat travels with that figure and does not weaken it: **nine of the
   sixteen predate August 7**, when `fix/release-runs-the-suites` (#514) made the cut run the suites, so
   their *historical* bill was lower. This is a re-pricing of past volume at today's cost, which is the
   only pricing a decision about future cadence can use — not a reconstruction of what was actually paid.

   **What batching buys and what it costs, on the same data.** The saving is simulated against the **real
   73 merge timestamps**; the delivery cost is *measured* as merge → next tag, because
   [`README.md`](../../../README.md#versioning) states that a merge without a release is invisible to
   consumers. Today that latency is **mean 7.45h**, median 5.72h, p90 17.40h, max 25.29h.

   | cadence | releases | gate time /10 days | saves | mean latency | costs | per hour of latency |
   |---|---|---|---|---|---|---|
   | **as it runs now** | 16 | 3h 32m | — | 7.45h | — | — |
   | one per day | 8 | 1h 57m | **1h 35m** | 10.92h | +3.47h | **27.4 min** |
   | one per 2 days | 5 | 1h 13m | **2h 19m** | 23.70h | +16.25h | 8.5 min |
   | one per 3 days | 3 | 0h 44m | **2h 48m** | 34.30h | +26.85h | 6.3 min |
   | one per week | 2 | 0h 29m | **3h 03m** | 88.85h | +81.40h | 2.2 min |

   **Two findings, neither of which is the choice.** The **ceiling is low**: even one release per ten days
   saves at most **3h 17m**, so the entire lever is worth under four hours per ten days — worth knowing
   before anyone spends engineering time chasing it. And the **first step is the efficient one**: 16 → 8
   captures **48%** of that ceiling for +3.5h of latency, while each step after it buys less and costs
   much more, from 27.4 minutes saved per added hour of delivery delay down to 2.2 at weekly. A cadence
   decision is therefore not a slider where further is better.

   **Correcting the CI leg moved every figure in this section by about 7% and changed none of its
   conclusions**, which is itself the useful thing to know. The scenarios scale by a common factor, so the
   ceiling stays under four hours, the 48% capture is unchanged, and the first step remains worth roughly
   twelve times the last. A cost model whose shape survives a 25% error in its largest component is one
   worth deciding on; that is a different statement from the model being precise.

   **Three limits on the simulation, stated because the table looks more precise than it is.** It holds
   the 73 merge timestamps constant — defensible, since batching changes when work is *published* and not
   when it is finished, but an assumption and not a measurement. "One per day" yields **8** releases and
   not 10, because two days in the window saw no merge after the anchor. And the latency column is a
   **lower bound on delivery, not delivery**: the second update gate is the consumer's marketplace cache,
   which sits on their side and does not move with this repo's cadence.

   **One observation on the consumer side, reported as one observation.** This session's connector hook
   read smartwatchbanden at **v4.1.0** against a source at v4.4.0 — three releases and roughly 20 hours
   behind, meaning those three marginal releases had delivered that consumer nothing yet. It tempers the
   cost side, and it is a single moment for a single consumer: the register keeps no update history, so
   there is no second point to put beside it and **no measured consumer update cadence exists**. Anyone
   arguing the delivery side from this number is arguing from n=1.

   **THE DECISION: no cap, no rule, nothing to build** (Dave, August 11, 2026). Cutting stays available
   whenever he wants it. Three things make this a decision rather than a deferral, and they are written
   down so the next reader does not mistake it for one:

   - **The size of the prize is what settles it.** The entire lever is at most **~20 minutes per day** of
     blocking gate time, and that time is the releaser's own waiting. Twenty minutes a day does not buy a
     standing rule that removes the freedom to ship on demand. Had the ceiling been four hours a day the
     same table would have argued the other way — which is precisely why counting it first was worth doing.
   - **There was never a mechanism to change, only a habit.** A release happens on Dave's explicit request
     ([`CLAUDE.md`](../../../CLAUDE.md#never-without-daves-explicit-permission)), so the 16 releases in the
     window were 16 requests. A cadence policy could only ever have been a self-imposed constraint on his
     own asking, plus a brief telling Rendall to propose fewer. Both were declined.
   - **The counterweight ran in the same direction, which is unusual and worth noting.** Batching would
     have traded the releaser's minutes for consumers' hours — `plugin.json`'s version being one of the two
     update gates. Almost always a cost question has a genuine trade in it; here the cheap side and the
     fast-delivery side agreed, so declining costs nothing on either.

   **What this closes.** Nolan's third open number is answered *and* acted on. The lever is not "not yet
   evaluated" — it is measured, priced and declined, and reviving it needs new evidence that the ceiling
   has moved (a materially slower gate, or a much higher release rate), not a re-reading of this table.

**None of the three is a gate, deliberately.** They are measurements whose answers decide what is worth
building; a check refusing a release over a missing number would cost every release something in order to
guard a decision nobody has made yet.

### The gate's wall clock is ONE suite — re-measured, n=5 (August 16, 2026)

[#714](https://github.com/DaveKJohn/claude-code-specialists/issues/714) reported the local gate at
**322.5s** against the baseline above — *"about +40%"*, with the growth *"diffuse, not one offender"*.
Re-measured in the gate's own pool (the same `Start-Process` loop, `MaxParallel 16`, 18 cores, all **40**
suites green, per-suite start offset and duration recorded), the number is lower and the diagnosis
inverts:

| run | total | `check-plugin-integrity.tests.ps1` inside that run |
|---|---|---|
| 1 | 212.97s | 212.82s |
| 2 | 196.46s | 196.27s |
| 3 | 199.04s | 198.88s |
| 4 | 206.69s | 206.54s |

**The total IS that one suite, to a tenth of a second, in every run.** It starts first (alphabetically)
and it finishes last; every other suite is done by **126.9s**, after which one process runs alone for
another 70–86 seconds with 15 of 16 lanes empty. Standalone the same suite takes **160.2s**, so roughly
40s of its in-pool time is contention from its 39 siblings — and that is the *only* way a new suite
lengthens this gate. The growth is diffuse in origin and **singular in effect**: nothing that fails to
shorten that one file can shorten the gate.

**A fifth reading arrived before this was merged, and it is quoted rather than dropped: 235s** — the
gate's own run inside `open-pr` on this very branch, lint first, 40/40 green. It is the highest of the
five and sits just above the old baseline's top end. It stays in because the band **is** the finding: a
figure that moves between 196s and 235s on one idle machine, and to 322s on a busy one, is not a figure
anyone should read a 40% regression out of.

**The +40% does not reproduce, and that is a finding about the metric, not about the code.** Five idle
runs land at **196–235s** — around the 205–232s baseline recorded when there were 30 suites, now with 40.
#714's 322.5s and the 326s reproduction were both taken on August 15 during the team-wide review, i.e. on
a machine running many agents at once. Because the wall clock is one single-threaded process, it measures
what else the machine is doing at least as much as it measures the suites. **State the machine state and
the n beside this number, or it says nothing** — the same discipline the release figures in this document
already carry.

**Halving the lanes is inside the noise, so it is not a saving.** `MaxParallel 8` measured **194.3s**,
with the other 39 suites still finishing at 153.2s and 41s of headroom to spare. 19s against a 196–235s
spread is not a result at n=1 per configuration, and it is not proposed as one.

**IT WAS BUILT THE SAME DAY, AND THE CEILING BELOW WAS ROUGHLY RIGHT** (Dave approved the split;
`check-plugin-integrity.tests.ps1` is now four suites over one shared fixture builder). Measured in the
same harness, four post-split runs: **142.4 / 145.5 / 170.3 / 169.9s**, against 196–235s before —
about **-25%**, and the two 170s runs came with a busier machine and a visibly larger contended sum
(2,082s against 1,597s), which is the load-sensitivity above showing up again rather than a second
effect. The four parts run 121.9 / 106.8 / 75.1 / 54.6s in the first of those, so the gate is bounded by
`-entries` and `roster-sync` together instead of by one file — the 86-second single-lane tail is gone.
Asserts unchanged at 234 (48 + 42 + 69 + 75), which is the number that makes "nothing was dropped"
checkable.

**And the honest footnote, because it is the kind of thing that gets left out.** The first post-split
pooled run had **two red suites** — `bootstrap-drift` and `fix-mojibake`, both on their *live-repo* lint
assert, both green alone, and both already named in
[Sylvester #15](specialist-05-15-lens.md) as suites that fail under a parallel fan-out. The next three runs
were clean, and eight lint runs launched alongside the four new suites could not reproduce it. So: not
diagnosed, not attributed to the split, and not hidden. What did change is that all three of those
asserts now print what the gate actually reported, because *"expected 0, got 1"* was everything either
of them said, and that cannot tell a collision from a real finding.

**What a repair would have to be, and its measured ceiling.** The floor for the local gate is that suite:
160.2s standalone. Split it and the gate becomes bounded by the next chain to finish, which ends at
**153.2s** — roughly **-25%**, twice per release-with-document, and nothing for CI, whose four lanes make
it a different shape (its median has not moved: 456s, n=34). The suite runs the gate **111 times** over a
single fixture it mutates scenario by scenario, so a split needs a shared fixture builder and boundaries
where that fixture is canonical. That is a project rather than an edit, it touches the most load-bearing
suite in the repo, and it is **proposed, not built** — the decision is Dave's.

**And the assert count in the table above was one suite's, not the gate's.** #714 reported *"38 suites,
234 asserts"*; **234 is exactly what `check-plugin-integrity.tests.ps1` prints for itself**. Summed over
all 40 suites' own summary lines the real figure is **4,206**. The row above carried "210 asserts" for
the same reason and no longer states one — at 30 suites the total was never in the low hundreds either.
This is [Chris's fifth intake pattern](specialist-01-01-lens.md#the-dave-rules) — the finding is real and its
**size** is wrong — in its fourth instance, and again on a report this team wrote itself.

### The gate record's saving, measured on the case it was built for (August 16, 2026)

`v4.12.0`'s release note left this open in its own words: *"The gate record has not been measured on the
case it was built for. Its saving shows only when a branch is opened in one step and shipped in a later
one. This release did neither."* **[PR #734](https://github.com/DaveKJohn/claude-code-specialists/pull/734)
is that case**, and it is measured here while the evidence is still readable.

**The saving is a difference, so both halves are measured — not one half and an assumption.**
On this machine, deliberately idle, all suites green, `-SkipLint`/`-SkipTests` never used (they record
nothing, so a run using them measures something else):

| what `ship-pr` would have paid | n | range | taken |
|---|---|---|---|
| the lint gate (`check-plugin-integrity.ps1`) | 3 | 9.2 – 10.6s | mean **9.9s** |
| the test gate, **43** suites | 6 | 139.7 – 195.0s | median **193.2s** |
| **what it paid instead** — one fingerprint + one evidence read per gate | 10 | 130.9 – 249.5ms | mean **162ms** |

**About 203 seconds of gate, replaced by about a sixth of a second — a ratio near 1,250:1.** That is the
number the release note was waiting for. It is a per-ship saving in the split-step case only; a branch
opened and shipped in one motion never had the duplicate to begin with.

**The field number agrees, and it was measured a different way.** #734's `open-pr` recorded both gates at
`12:02:29Z` and opened the PR four seconds later; CI went green at `12:09:54Z` and the merge landed at
`12:10:21Z` — a **CI-green-to-merge gap of 27 seconds**. Against the historical slow mode for exactly this
shape (median 264.5s, below) that implies a field saving of ~237s, which reconciles with the 203s of gate
above plus roughly 30s of genuine merge-and-fold work. Two methods, ~15% apart, agreeing on three minutes.

**The historical comparator was recounted rather than quoted, and it SURVIVED** — which is worth recording
precisely because the four instances above did not. `gate-lib.ps1`'s docstring claims 293 merged PRs split
bimodally: 205 within 60s (median 14s), 83 at a median of 263s, i.e. 28.3%. Recomputed from `gh` over 281
matched merges: **187 fast (median 13s), 78 slow (median 264.5s), 27.8%**, with the same void between the
modes and the same interior peak at 240–300s. The counts differ because `gh run list` truncates older runs,
not because the shape does. **A figure that holds on recount is still worth the recount** — that is the
only way to tell it apart from one that does not.

**Three things this measurement is NOT, stated because each is an easy misreading:**

- **The 249s-on-28.3% figure is not this saving.** It is the historical excess the record was *designed
  against*, computed before the fix existed. It is the comparator, never the result.
- **"lint skipped" and "tests skipped" are one data point, not two.** Both gates consult a single
  fingerprint computed once per run (`Get-GateFingerprint`), so the pair is one decision printed twice.
  The 162ms above therefore times the whole path once, not each gate separately.
- **Six merges is not six firings.** PRs 728–734 all landed fast (`8 · 14 · 16 · 16 · 9 · 27s`), but the
  record only fires on a split-step ship. Two are now confirmed to be one — #734 and #735 ([below](#the-second-firing-measured-deliberately-rather-than-waited-for-august-16-2026)) — and the
  rest are consistent with the result without being independent evidence for it.

**A side finding on the suite band itself, kept separate rather than folded in.** The four post-split runs
recorded above (142.4 / 145.5 / 170.3 / 169.9s) are the optimistic end of a wider band. Combining them with
the six here gives n=10 at 43 suites, on two different sessions:

```text
139.7  142.4  145.5  168.0  169.9  170.3  174.2  183.0  193.0  193.3  193.5  195.0
```

Median **~172s**, spread **139.7–195.0s**. The post-split improvement over the pre-split 196–235s is real;
the **-25%** headline is the best case rather than the typical one. Four of the six runs here sat in a
2-second band at 193.0–195.0, so the fast readings are the outliers, not the norm. This does not change
the saving — every second of that band is saved either way — and it is recorded here rather than swept
into the `-25%` claim, per the rule that a size gets its own measurement.

**The last two readings are `open-pr`'s own, on the branch that carried this section: 168s and 183s, 43/43
green both times** — quoted rather than dropped, following the same precedent the section above set when
its fifth reading arrived late. They are the useful kind of confirmation, because the gate took them
rather than the person arguing for the median, and both land inside the band. That is what moves
*"median ~172s"* from a summary of one session's runs to a figure independent runs reproduce.

### The second firing, measured deliberately rather than waited for (August 16, 2026)

The section above rests on one firing in the wild (#734) plus a bench reconstruction, and said so. **The
second firing was then produced on purpose, on this repo's own next ship**, because the chain offers it for
free: `ship-pr` calls `open-pr` internally, so running `open-pr` first and `ship-pr` afterwards *is* the
split-step case, and the gates had to run before the merge either way.

| | gates | wall clock |
|---|---|---|
| `open-pr` on PR #735's tree | ran for real, 43/43 green | **198.6s** end to end |
| `ship-pr`'s internal `open-pr`, minutes later, same tree | **both skipped** | — |
| #735 merged after CI went green | — | **15s** |

Both skip lines printed, and the merge landed 15 seconds after the required check went green — against the
**264.5s** historical median for exactly this shape. #734 was 27s. **n=2, on two branches, both in the fast
mode.**

**The 198.6s is the better cost figure than the ~203s bench estimate above**, and it is the one to quote:
it is a whole `open-pr` invocation measured in the chain rather than a lint number and a suite number added
together. The bench figures stay because they are what decompose it.

**One constraint is worth recording, because it decides the order of operations.** `Get-GateFingerprint`
hashes HEAD, so *any* further commit voids the evidence and the next run re-gates. Two suite readings taken
during this exercise (the 183s above, and the 198.6s total) could therefore either be committed to this
document **or** be followed by a skipping ship — not both on one branch. The firing was worth more than the
data point, so the readings landed here on the follow-up instead. Anyone reproducing this should expect the
same fork rather than discover it mid-run.

**What this does NOT establish.** Two firings confirm the mechanism and place it in the fast mode; they are
not a distribution. The 27s and 15s differ by more than the skip itself costs (162ms), so nearly all of
that spread is merge-and-fold work and network, not the record — which is the honest reading of why a
third, fourth and fifth firing would move the figure very little. **Do not extrapolate a per-merge saving
from these two gaps**; the saving is the gate that did not run, and that number is 198.6s.

### The merge wait, measured over its population — n=100 (August 21/22, 2026)

`ship-pr.ps1` waits for **every** check a PR has rather than for the one the `main` ruleset requires.
Whether that costs anything was written down twice from tiny samples, both times by this role, and both
times wrong in the same direction — first at n=1, then at n=3, the second quoted in a **published**
release note as *"two to one"* for the non-required check governing the wait. Population: **n=100** paired
pull-request runs, 2026-08-14 to 2026-08-21, read from the Actions history rather than from a stopwatch.

| check | median | p90 | max | spread |
|---|---|---|---|---|
| `lint-en-tests` (**required**) | 7m 46s | 9m 17s | 10m 06s | tight |
| `claude-review` (not required) | **2m 47s** | 14m 10s | 23m 23s | **33-fold** |

**Which check governs the merge wait: CI on 77 of 100, `claude-review` on 23.** What waiting on the
non-required check actually costs, per pull request:

| | |
|---|---|
| median extra wait | **0s** |
| mean | 80s |
| p90 | 5m 00s |
| worst case | 16m 05s |
| total over 100 PRs | 2h 13m — **14.5%** of all merge wait |

In roughly three quarters of pull requests the review has already finished before CI, so the wait costs
nothing at all. The entire cost sits in a tail of **23** runs, median excess there 4m 46s. **The tail is
not growing**: oldest 20 median 177s against newest 20 median 186s — inherent variance, not a regression.

**The decision was A plus B: leave the wait alone, make it legible** (Dave, August 24, 2026,
[#831](https://github.com/DaveKJohn/claude-code-specialists/issues/831)). `ship-pr` now prints which check
finished last and governed the merge, its duration, whether the repo's own ruleset requires it, and — when
a non-required check governed — how much later it finished than the last required one. The selection is a
pure function in [`pr-issues-lib.ps1`](../../../scripts/lib/pr-issues-lib.ps1) with its own asserts, because
the `gh` call around it cannot be covered by a suite.

**Option C — merging on the required check alone — was on the table with both sides quantified and was
DECLINED.** It buys median 0s, p90 5m, worst case 16m 05s, and costs the guarantee that a review has been
seen before the merge. That is a trade of coverage for time rather than a saving, so it was never Nolan's
to take (see the boundary below), and it was put up as a trade rather than as an improvement.

**What was deliberately NOT measured, and why it matters to C.** Whether the long reviews are the **large
diffs**. If they are, C removes the wait precisely where the review has most to say — the worst available
place to make that trade. B produces exactly the data needed to answer it, which is the argument for
having done B first. Re-ask C when that question has an answer, not before.

#### C was taken on September 8, 2026 — and NOT because anybody re-argued it (Dave, [#1602](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1602))

`ship-pr` now blocks on the required checks only and reports the non-required ones at step 8, after the
fold. **The measurement above is untouched and was reconfirmed a third time** — 21.2% governance over
n=99 laps against this table's 23% over n=100 — so nothing here was found wrong. What changed is that
the cost being traded stopped being the one this section priced.

**In August the wait cost TIME. Since September 3, 2026 it can also cost a LAP**, and that class did
not exist when C was declined. [#1292](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1292)
added the staleness gate: `ship-pr` refuses the merge when `main` gained a commit after the certifying
run was created. The trunk goes on moving while step 3 waits, so a commit landing in the stretch between
the last **required** check and the last check of **any** kind voids a certificate that was valid the
moment before — and the refusal is correct on the gate's own terms, because that commit genuinely is
untested against this branch. The price is a whole further CI cycle. Measured per **lap** rather than per
merged PR, because a merged PR's `gh pr checks` reports only its final head and so drops precisely the
laps that refused:

| n = 99 ci.yml `pull_request` laps, 2026-09-05 → 2026-09-08 | |
|---|---|
| a non-required check governed the wait | 21 (21.2%) — median tail 191s, max 753s |
| certificate voided, after #1592's fold discount | 25 (25.3%) |
| **voided ONLY inside the non-required tail** | **5 (5.1%)** — what C removes |
| voided inside the tail *and* before it | 0 |

**The predicate, beside the number** ([#1750](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1750)).
The population is every `ci.yml` `pull_request` run between `2026-09-05 17:58Z` and `2026-09-08 10:51Z`,
one row per lap; the window per lap is `[run.created_at, last_check.completed_at]` — ending at the **last
check of any kind**, which is what makes the two tail rows mean anything; voided is `main` gaining a
first-parent commit inside it; and the discount is `Test-IsFoldOnlyCommit` itself, re-run over the same 99
laps and reported identical. A rate without those four cannot be re-measured, only argued with — which is
the general lesson, and the reason this paragraph exists at all.

**The voiding row is unreconciled, and it is the one to be careful with.** A re-measurement over the same
four days scored **3 of 193 laps (1.6%)** against this table's 25.3%. The window is the obvious suspect —
that pass ended its own at `run.updated_at`, inside the tail — but the table bounds the window's share at
5: tail-only is 5 and tail-and-before is 0, so narrowing to the required check's conclusion moves 25.3% to
**20.2%** and no further. The residual is in the *discount*: this sample discounted 12 of its 37 raw
voidings (32%), the re-measurement 39 of 42 (93%), against a trunk that ran 114 folds in 255 first-parent
commits (**44.7%**) over those same four days by the real classifier. Neither pass is shown wrong and the
direction is identical in both, which is all the decision below rests on — but **a decision sized off
25.3% is being sized off the half that is still open**. The three governance rows are not in dispute.

**5.1% is the mean and the mean is the wrong statistic here.** All five sit on ONE day, the busiest in
the sample: **5 of the 8 tail-governed laps that day (62.5%)** lost a lap, against **0 of 13** across the
three quieter days. The governance share and the tail length are flat across all four days, so what moves
is the trunk's own rate — which is
[#1592](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1592)'s title measured: two sound
decisions that do not converge **on a busy trunk**.

**And the coverage half of the trade turned out not to exist.** This section priced C as costing "the
guarantee that a review has been seen before the merge". Read against the code, there has never been such
a guarantee: `Get-MergeBlockVerdict` has returned `Blocked = $false` for a red non-required check since
[#943](https://github.com/DKJ-Solutions/claude-code-specialists/issues/943), and step 3 printed *"a check
FAILED but the merge is not blocked … Continuing to step 4"* and merged. So the pre-merge wait decided
**when that sentence was printed**, not whether the merge happened. Be exact about what the wait did
guarantee — the review had **concluded and been reported** before the merge — and about what C actually
costs, which is the window in which a human who is watching could intervene. `ship-pr`'s own step-3
invitation (*"Nothing here needs YOU — background this run"*) is an instruction not to be sitting in it.

**The August precondition is still unanswered, and it is now a residual rather than a gate.** Whether the
long reviews are the large diffs was not measured then and is not measured now. It no longer blocks C,
because C's cost was never the review coverage it was thought to be — but it is exactly the question that
sizes what is left: if long reviews are large diffs, C moves the report past the merge precisely where the
review has most to say. **Worth measuring; do not treat the reversal as having answered it.**

**The lesson for this role, and it is the mirror of the one below.** That lesson is *a cost that varies
per run is counted over its population*. This one is **a decision is only as current as the cost classes
that existed when it was taken**. C was declined on a correct measurement of the wrong cost — correct in
August, incomplete by September, and nothing in the record said so, because a measurement carries its
date and not its assumptions. So when a decision is cited to close a question, check what has been built
since it was taken, not only whether its numbers still hold.

**The lesson this role broke twice in one release.** *A cost that varies per run is counted over its
population, not cited from one run.* The 33-fold spread above is why: any single reading of
`claude-review` is almost uninformative, and two readings that both came out of the tail read as a
tendency. That is also Chris's fifth intake pattern — the finding is real and its **size** is wrong —
in its fifth instance, and again on a report this team wrote itself.

### The always-on figure is now regenerable, and what that closed (August 24, 2026)

**Every table above was produced by hand**, and this section is where that stops. `wc -c` had been typed
against this path four times — July 28, August 14, August 15 and August 24 — and the notes above record
the consequence three separate times in their own words: *a measurement in a document that nothing
regenerates goes stale silently*. It did, in the most expensive way available: **the 3.70 factor was
inherited unexamined through three re-measurements** and was ~19% too generous, so every derived token
figure was under-stated while looking precise.

[`scripts/maintenance/measure-always-on.ps1`](../../../scripts/maintenance/measure-always-on.ps1) now
answers it, with [`measure-context-lib.ps1`](../../../scripts/lib/measure-context-lib.ps1) underneath. It
walks `CLAUDE.md`'s `@`-imports and reports per document and per section. **Re-run it rather than citing
the number below.** As of that day:

| always-on document | bytes |
|---|---|
| `CLAUDE.md` | 29,044 |
| Chris's repo lens | 18,056 |
| Chris's persona — **the marketplace copy, which is what loads** | 16,585 |
| `SPECIALISTS.md` | 8,005 |
| **total** | **71,690 B, ~22,978 estimated tokens** |

**Four things it does that a hand-count kept getting wrong**, each one a rule from this lens turned into
code rather than remembered:

- **The factor lives in the lib with its provenance** — 3.12, n=10, min 2.95, max 3.23, calibrated
  August 15 — so it can no longer be inherited by copying a table.
- **The byte column is labelled a measurement and the token column an estimate, in the output.** `do not
  estimate from file sizes` is about the subject the count_tokens API prices; **it does not price
  documents**, so here an estimate is the only answer available and the honest move is to label it every
  time. The plugin listings stay `measure-skill`'s, and the report says so rather than absorbing them.
- **It resolves the load path.** The persona that loads is the marketplace clone's copy: 16,585 B against
  21,860 in the tree, so **5,275 B is queued cost** — named, not smoothed. **It arrives on a
  `claude plugin marketplace update` and not on a plugin update**, which this bullet had the wrong way
  round until [#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812). The clone is
  the right answer here for a reason that does not generalise: this document is reached by an absolute
  `@`-import naming a path inside the clone, and an `@`-import is a filesystem path rather than a plugin
  lookup. Everything a plugin *ships* — a skill, a hook, an agent def — loads from the extracted payload
  under `~/.claude/plugins/cache/` instead, and that copy moves only on a release. Two artefacts, two
  load paths; the measurement is in
  [the system-administration lens](specialist-05-15-lens.md).
- **The sections must sum to the file, or no table is printed.** A plausible wrong share is worse than a
  refusal, which is `measure-skill`'s own parse-check reasoning applied to arithmetic.

**And the growth has not stopped, it has moved.** Since August 15 `CLAUDE.md` fell 44,254 B while the
**portable persona grew 5,534 B**, with the 5,275 above still queued. So the lever this lens has named
three times — move the evidence, keep the decision — redirects where growth lands rather than ending it,
exactly as the August 15 counter-argument said. The layer it has moved into is the one that reaches every
consumer.

### The boundary this measurement replaced a skill for (August 24, 2026)

Issue [#861](https://github.com/DaveKJohn/claude-code-specialists/issues/861) asked for a portable
`prune-claude` skill that would judge an instruction document block by block. It was argued down and Dave
accepted the verdict, and the reason belongs in this lens because it is a **cost** argument:

**A rule shipped portable costs a consumer nothing until it applies. A skill costs every consumer session
its description, whether it ever fires or not.** So `portable-first` — the standing default for a way of
working — does **not** extend to tooling that carries a per-session cost. There the test comes first: do
consumers actually have the condition it treats? Here they do not. `CLAUDE.md` is large in this repo
because this is the *source* that records every decision about the system; a consumer's is not. The
precedent that had it right is `triage-inbound`: **repo-local, and a net relocation** — 94 lines moved
*out* of an always-on lens — rather than net-new cost in three repos.

Two more of this role's own rules were broken while making that recommendation, and both are worth
naming because they are cheap to apply and were skipped: **the firing frequency was never asked for**
(`measure-skill` leaves that column blank on the rule that a guessed frequency is worse than a blank
one — but for *whether to build a thing at all*, frequency is the deciding figure), and **the thing being
proposed would have broken the rule it existed to teach**.

### A gate verdict that moves is a load reading — n=5, and the caller is not a variable (August 28, 2026)

[#1033](https://github.com/DaveKJohn/claude-code-specialists/issues/1033) was filed out of the `v4.22.0`
cut, where the gate answered three different ways on one tree: **54/54 green in 443s** inside
`cut-release.ps1`, **11 of 54 failed in 626s** when `Invoke-TestSuiteGate` was driven from the session
afterwards, and one of those eleven **green alone** in a fresh process. The report read that spread as
the gate depending on *who invoked it* — a session that had dot-sourced `native-capture-lib.ps1` and
`repo-config.ps1` against a fresh process — and drew the consequence that CI, which dot-sources both, is
on the failing side while the release route is on the passing one.

**That axis does not exist.** `cut-release.ps1` dot-sources exactly those two libs (lines 262 and 275)
before it calls the gate, so the green run and the red run had *identical* state; and CI runs
`-MaxParallel ([Environment]::ProcessorCount)` on a **four**-core runner, which is four lanes, not the
eighteen the red run used. The report's central inference is falsified by the two files it names.

Re-measured on `f2ca263f` — the same tree, one markdown file later, which no suite reads — across every
axis the report did name, **five full runs, all 54/54 green**:

| run | lanes | console | machine | total |
|---|---|---|---|---|
| A | 16 (the default, `cores-2`) | CP 850 | idle | **194s** |
| B | 18 (the CI shape) | CP 850 | idle | **216s** |
| C | 18 | CP 65001 (UTF-8, the agent-session shape) | idle | **203s** |
| D1 | 18 | CP 850 | a second identical gate beside it | **421s** |
| D2 | 18 | CP 850 | ditto | **419s** |

**D is the row that pays for the table.** Two gates side by side — 36 suites over 18 cores — land on
**421s and 419s**, which is the release's own *green* 443s to within 5%. So 443s was never this gate's
cost; it was a reading of what else that machine was doing, and the cost on that tree is **~200s**. The
626s red is 3.2x idle, i.e. heavier still. This is the same discipline the n=5 section above already
states — *state the machine state and the n beside this number, or it says nothing* — arriving a second
time, and this time the figure that went stale was one written into a **published release note**.

**And the phenomenon is not new, which is the finding worth keeping.** Red under the gate, green alone,
on these same suites, has now been recorded three times: the `Start-Job` fan-out of August 12, 2026 (6 of
31, all green alone) in [Sylvester #15](specialist-05-15-lens.md), the two post-split reds of August 16
(`bootstrap-drift`, `fix-mojibake`) in the honest footnote above, and these eleven. Six of the eleven run
the lint gate over the live tree and five do not, so the live-repo collision covers part of it and no
reproduction has ever been obtained for the rest. What cost that release **22m 01s** was therefore not
the flake but the *search*: the standing response — re-run the red suite alone before believing its
assert — was already written down twice, in two lenses the gate's own output points at neither of. The
pointer now lives in `Invoke-TestSuiteGate`'s docstring, beside the converse rule from inbound #821 that
was already there.

### A figure with no scope and no machine — CI re-measured, n=12 (September 3, 2026)

[#1314](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1314) was filed out of
`fix/ship-pr-stale-ci-certificate`, which wrote **three** *"full gate"* figures for one test set and had
each of them read as the same measurement:

| written as | seconds | what its own wording covered |
|---|---|---|
| *"Full lint gate and all 61 test suites pass (608s, matching CI's own runner)"* | **608s** | lint **and** the suites, explicitly bundled |
| *"`check-plugin-integrity.ps1` (0 errors) followed by `Invoke-TestSuiteGate` ... 61/61 passed in 471s"* | **471s** | the suites alone; lint's cost reported beside it, not in it |
| *"`Invoke-TestSuiteGate` over all 61 suites, parallel, exactly as CI runs it: 61/61 passed in 360s"* | **360s** | ditto |

**The three are not interchangeable and nothing on the branch said which was which.** The report's own
re-run on that tree put the parts at **75s** of lint and **401s** of suites at sixteen lanes
(`[Environment]::ProcessorCount - 2` on an 18-thread box) — 476s together, close enough to 471s that
either reading is available: 471s folding lint in despite its wording, or the 111s gap to 360s being
ordinary load variance, which the
[`Invoke-TestSuiteGate` docstring](../../../scripts/lib/native-capture-lib.ps1) already documents at that
scale (421s/419s against ~200s idle).

**And none of the three is "matching CI's own runner", which is the half worth keeping.**
[`ci.yml`](../../../.github/workflows/ci.yml) runs lint and the suites as **two sequential steps** with
`-MaxParallel ([Environment]::ProcessorCount)` on `windows-latest` — four cores, as the step's own
comment says, because a hosted runner has nobody sitting at it. Measured here over the twelve most recent
successful `lint-en-tests` runs on the trunk, per step from the jobs API:

| | min | median | max |
|---|---|---|---|
| lint step | 20s | **30s** | 35s |
| test-suites step | 656s | **906s** | 949s |
| the two together | 676s | **936s** | 983s |

**CI costs about 2x the local reading — and that is the smaller of the two findings.** 936s against the
local 476s is a difference in *lanes*, not in the change: sixteen against four. The larger finding is the
**band**: 676–983s is a 1.45x spread inside one environment, wider than the 360–608s spread the three
branch figures were being reconciled across. So the disagreement those three figures looked like was
never big enough to be a finding in the first place — which is the population rule in
[the n=5 section above](#the-gates-wall-clock-is-one-suite--re-measured-n5-august-16-2026) arriving from
the other direction: there a figure moved because the machine was busy, here two figures differ by less
than one machine's ordinary noise.

**Where the rule went, and why not here.** Both halves are portable — a consumer running these gates
meets this on day one — so neither stayed in this lens. The measurement discipline is a hard rule in
Nolan's own manual (*"a gate figure names what it included and which machine produced it"*, the scope-and-machine
sibling of the unit, sample, factor and copy rules), and the DEPLOY-section half is
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md)
rule 8, because a figure written there folds into `CHANGELOG.md` and then into a release document. This
section is the evidence they cite, which is this repo's convention for where a measurement lives.

**And this branch's own gate produced the sharpest instance available, after the rule was written.**
`open-pr` on `docs/gate-figure-scope-and-machine-v1` ran `check-plugin-integrity.ps1` clean and then
**all 62 suites in 89s** — same machine as the report, same sixteen lanes, same day. Against the
report's **401s** that is a **4.5x** spread with no code between them, which is a larger factor than
either the CI comparison above (2x) or the load pair in the docstring (421s against ~200s idle). The
suite count also moved from 61 to 62 in the hours between the two readings, which is why nothing in
the rule is anchored to a suite count: the population changes under the figure as well as around it.

**The tooling states one of the two facts, and on the wrong line.**
[`Invoke-TestSuiteGate`](../../../scripts/lib/native-capture-lib.ps1) prints the lane count when it
*starts* — `test gate: running all 62 test suites for the gate (16 at a time)...` — and its summary
line carries only the count and the seconds: `test gate: all 62 suites passed in 89s.` The summary is
the line that gets quoted, and #1314's own three figures have exactly its shape
(*"61/61 passed in 471s"*). So the repo's gate hands a session a figure stripped of the fact the rule
above requires, on the one line anybody copies. Filed as
[#1318](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1318) rather than fixed here:
it is a script change, this branch is documentation, and the fix wants a test.

**The three figures themselves needed no repair.** They sit only in
`dkj-policy/development-fix-ship-pr-stale-ci-certificate.md`, in its CREATE and TEST
sections; `fold-changelog-entry.ps1` folds **only** DEPLOY and removes the document, so none of them
reaches the trunk, and a grep over `scripts/`, `plugins/` and `dkj-policy/` finds them
nowhere else. The convention gap was the whole issue.

### Inside the invocation — where a plateau suite's time actually goes (September 3, 2026)

[#1358](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1358) reported a plateau of five
suite files at 189-232s and named two candidate levers: split the files further, or reduce the
**per-invocation** cost of the 168 child `powershell` runs the four `check-plugin-integrity-*` suites make.
It left the second unpriced in its own words -- *"it is not obvious without measuring which half of that
~4.5s per invocation is the lint's own work."* Measured, on an idle 32-core workstation, over the fixture
those suites build:

| | per invocation | share |
|---|---|---|
| process spawn | 0.097s | 7% |
| parse of the lint's 3419 lines | 0.115s | 8% |
| dot-source its 11 libs | 0.071s | 5% |
| **fixed overhead before any check runs** | **0.283s** | **21%** |
| the 30 checks' own work | 1.079s | 79% |
| **total** | **1.362s** | |

**So it is a fifth, not a half** — and that answers the question in the direction that closes the lever
rather than opening it. Removing all of the fixed overhead would need the suites to stop spawning a process
per assert, and the lint calls `exit`, so in-process invocation is a rewrite of the fixture's contract for
21%. Not proposed.

**The 4.5s in the report was a CI figure divided by an invocation count**, which folds four-lane contention
on a four-core runner into what looks like a per-call cost. The two agree once the machine is stated: 52
invocations x 1.12s is 58.7s, and that is what the heaviest suite measures standalone here. **Those suites
are ~100% their lint invocations**, to within a second, which is the fact that makes per-invocation cost the
whole lever for them.

**What was actually duplicated was the AST walk, not the parse either comment worried about.** Two
non-skippable checks -- barred-skill and shopify-cli -- each called `ParseFile` and then
`FindAll(CommandAst)` over the same file set. Over this repo's 184 script files one such pass is 1.413s, of
which the **walk is 1.157s** and the parse only 0.256s; a second pass off a shared cache is 0.014s. Sharing
it (`Get-PsScriptCommandAsts`) measured **-12.6%** across the four suites -- 58.7/55.7/51.0/34.5s to
50.8/48.9/44.7/30.3s -- with every assert count unchanged at 108/95/78/59, and ~1.4s off the real lint gate.
It retains 25,476 AST nodes for ~72MB of heap, which is the cost and is stated at the accessor.

#### The reconstruction trap — two of the five were never plateau members

**The gate recorded no per-suite duration** — it does now, and closing that is what
[PR #1364](https://github.com/DKJ-Solutions/claude-code-specialists/pull/1364) was for; read
[the section below](#the-instrument-and-what-it-immediately-changed-september-3-2026) for what the first
recording showed. The trap itself is unchanged and still worth knowing, because the misleading timestamps
are still in every log: the gate buffers each suite's output until that suite completes, so
`entry-scaffold`'s log lines all land within 2.7ms of each other. A log timestamp gives a suite's
**finish** time, and subtracting the shard's start is a duration only for a suite that started at `t0`.

With 4 lanes that means queue positions 1-4. Taken by stride over the 65-suite pool, the four
`check-plugin-integrity-*` files sit at positions 3, 3, 3 and 4 of their shards -- so **#1358's figures for
them are exact, exactly as it claimed**. But `entry-scaffold` is 5th of 16 in its shard and `new-branch` 9th
of 16, so both reconstructions include lane wait. Standalone here `entry-scaffold` is **17.0s**, against the
51-59s of the suites whose CI numbers are sound; at the 3.6-4.0x local-to-CI ratio this lens then believed
in it predicts ~65s, not the 189s reported. `new-branch` at 52.8s predicts ~190-210s and is plausibly a real
member.

**THAT RATIO TURNED OUT NOT TO EXIST, AND THIS PARAGRAPH IS WHERE IT WAS USED HARDEST**
([#1713](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1713), September 9, 2026). The
"3.6-4.0x faster on a developer machine" figure was stated as a fact in a shipped lib, its recorder and the
hints file that recorder writes — and measured the other way round: one suite ran 759.1s **solo** on an
18-thread workstation against a 290.9s mean over three 4-lane CI runs, i.e. 2.6x *slower*, while a third
configuration (the whole pool, 32 threads, 30 lanes, ~255s wall) agrees with neither. So there is no divisor,
and the two predictions above are arithmetic on a constant that is not one. **The conclusion they were used
to reach still stands, and not on their strength**: the section below records that the *recorded* CI numbers
put about a dozen suites in that band, which is what actually settled `entry-scaffold`'s membership. The
prediction is left in place rather than deleted because it is the worked example of the trap — a
reconstruction is only as good as its `t0` assumption, and a conversion is only as good as a ratio that
holds.

**So the plateau is four files, not five, and `entry-scaffold` should not be split.** This is
[Chris's fifth intake pattern](specialist-01-01-lens.md#the-dave-rules) again -- the finding is real and its
**size** is wrong -- on a report this team wrote itself, which is where it keeps happening. The lesson is
narrower than "check the numbers": a reconstruction is only as good as its `t0` assumption, and the report
stated that assumption correctly for the four files it verified and then silently extended the method to two
it had not.

**And "four, not five" is itself only as good as the reconstruction it corrected** — see the section below,
where the recorded numbers make the band about a dozen suites. The correction above stands as far as it
goes: `entry-scaffold` really is not a member, and the four `check-plugin-integrity-*` figures really were
exact. What it got wrong is the same thing it was correcting for, one level up — it re-derived a *membership
list* from the same reconstructions instead of waiting for the instrument.

### The instrument, and what it immediately changed (September 3, 2026)

The section above ends by proposing a decision off reconstructions. **@maikel-bwj retitled
[#1358](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1358) instead** — from a
five-file plateau at named seconds to *"the band of heavy suite files ... **first make the gate record
per-suite durations**"* — and that ordering was right. PR #1364 built it: `Invoke-TestSuiteGate` records
each suite's duration **and the offset at which its lane opened**, prints them slowest first, and marks the
one that set the makespan.

**The first recorded run reordered the top of the list.** All 65 suites, **30 lanes on a 32-core
workstation**, 91s total (reproduced at 92s):

| suite | duration | lane opened |
|---|---|---|
| `new-branch.tests.ps1` | **89.7s** | +1.1s **← set the makespan** |
| `check-plugin-integrity-links.tests.ps1` | 83.8s | +0.2s |
| `check-plugin-integrity-docs.tests.ps1` | 82.8s | +0.2s |
| `fold-changelog.tests.ps1` | 78.2s | +0.3s |
| `check-plugin-integrity-entries.tests.ps1` | 78.1s | +0.2s |
| `sync-main.tests.ps1` | 69.4s | +13.8s |
| `prune-merged.tests.ps1` | 65.1s | +2.8s |
| `check-plugin-integrity-commands.tests.ps1` | 61.1s | +0.2s |
| `bootstrap-drift.tests.ps1` | 58.8s | +0.1s |
| `roster-sync.tests.ps1` | 57.7s | +6.4s |
| `shared-scripts.tests.ps1` | 54.3s | +12.5s |
| `script-contract.tests.ps1` | 53.7s | +8.9s |

Two facts nothing could see before: **`new-branch` sets the makespan**, where #1358 had it second behind
`check-plugin-integrity-links`; and **seven suites in that band appear in none of the five** —
`fold-changelog`, `sync-main`, `prune-merged`, `bootstrap-drift`, `roster-sync`, `shared-scripts`,
`script-contract`. The retitle's wording is the accurate one.

**State the lane count with any figure from this table.** It is a 30-lane workstation reading, not the
4-lane shape the required check runs, and #1351 measured 3.7x between those regimes. CI prints its own
table per shard now, so the comparison is a log read.

**The lesson, which is Nolan's and not a one-off.** Two rounds of this issue were spent arguing about which
files are expensive while the instrument that answers it did not exist and was cheap to build. A
measurement whose method carries an unstated assumption does not merely risk being wrong — it *reads as
data*, so the argument moves to what to do about it rather than to whether it is true. **Build the
instrument before the argument**, and where a figure has to be derived, print the derivation's assumption
next to it: the reason the table carries the lane offset at all is that a duration alone cannot be checked
against the pool's makespan by a reader who does not know when the suite began.

**Still open on #1358:** the split, now genuinely unpriced again. It is not four files and not five, the
makespan-setter is a different suite than the report named, and nothing about it should be decided off this
workstation table rather than a 4-lane CI one.

### The gate's nine hours, measured twice — the scheduler is at its floor and the lever is one file (September 9, 2026)

[#1703](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1703) reported *"~9 hours of CPU
per PR: 84 suites, 2,009s over 16 lanes"*, and said plainly that everything in it was inference until
somebody ran the gate **unpiped** and kept the full table — the caller had piped through
`Select-Object -Last 40`, which cut off exactly the rows above 55.8s. Two full tables now exist, and they
answer the issue's question 1 while retiring its headline metric.

**n=2 on the 18-thread workstation, both green, both unpiped:**

| | lanes | makespan | lane-seconds | longest file | lower bound `max(file, work÷lanes)` | makespan ÷ bound |
|---|---|---|---|---|---|---|
| reading 1 | 12 | 1,806s | 21,512s (5.98 h) | 1,617.1s | 1,793s | **100.8%** |
| reading 2 | 16 | 1,021s | 16,008s (4.45 h) | 1,020.7s | 1,021s | **100.0%** |

**THE SCHEDULER IS AT ITS FLOOR — 99.2% and 100.0% of the theoretical minimum — so the queue order is not
the lever and neither is the pack.** That is the finding worth keeping, because everything visible points
the other way and the wrong repair is one step away. `scripts/tests/suite-durations.json` really had gone
stale: recorded September 4 from runs 33842129201 and 33812817842, it listed **65 of the 84** suites, so
[the charge-the-maximum rule](../../../scripts/lib/native-capture-lib.ps1) priced 19 of them at 236.8s each
— **4,499s of phantom weight against a 3,552s real pool**, 56% of what the bin-pack was allocating from.
Trivial suites bought the opening lanes on it (`claim-issue` 21.0s dequeued at +0.9s, `consumer-check-lib`
19.2s at +1.1s) while `teardown` (582.9s) waited until +1,175.1s. Every sentence there is true, and
together they are worth **at most 13s of 1,806**.

**AND THE TWO READINGS SIT IN DIFFERENT REGIMES, which is why n=1 would have been the wrong evidence.** At
12 lanes the pool is work-bound (1,793s of work against a 1,617s longest file); at 16 it is
critical-path-bound and the pool simply **is** `check-plugin-integrity-links.tests.ps1` — 1,020.7s against
a 1,021s makespan, #714's regime exactly. So on this machine adding lanes past ~16 buys nothing at all, and
the only local lever left is inside that file.

**ON CI the refresh is worth exactly 0s, measured rather than assumed.** Refreshed from runs 34345773827,
34345361764 and 34334137051 (3-run mean, 84 of 84, pool **4,661s**), then both hint sets simulated through
`Get-TestSuiteShardOrder`'s own LPT pack and longest-first queue and scored against today's real durations:

| CI, 4 shards × 4 lanes | makespan on the binding shard |
|---|---|
| stale hints (65 of 84) | 374s |
| refreshed hints (84 of 84) | **374s** |

Because `new-branch.tests.ps1` alone is **373.8s** against a 291s work bound (4,661 ÷ 16). **CI is
critical-path-bound on one file too, and no partition beats a file.** That is the 4-lane table
[the #1358 section above](#inside-the-invocation--where-a-plateau-suites-time-actually-goes-september-3-2026)
asked for before anyone priced the split: the gap a split of `new-branch` could buy is **83s, 22% of the
shard**, and the makespan-setter is that file, not one of the four `check-plugin-integrity-*` suites the
earlier reports named. **The two machines disagree about which file to split** — CI says `new-branch`,
this workstation says `check-plugin-integrity-links` — and CI is the one that blocks a merge. The hints
file was refreshed anyway and the commit says 0s: a truthful table is what the next simulation reads,
which is the only reason this one could be run.

**WHERE THE WORK IS, which is question 1's answer.** Six files carry **8,140s of reading 1's 21,512
lane-seconds — 37.8%** — and they are ~100% cold `powershell` children, each a full lint run over a
fixture: `check-plugin-integrity-links` 66 invocations, `new-branch` 56, `fold-changelog` 54, and 44 each
for the other three `check-plugin-integrity-*`.

**THE HEADLINE METRIC DOES NOT SURVIVE, and this is the part to carry forward. Lane-seconds are not CPU.**
`wall × lanes` charges a *blocked* lane as though it were working, and under this gate most are. The proof
is in the two readings above: **lane-seconds FELL from 21,512 to 16,008 when lanes went UP from 12 to 16**,
on one machine, one day, one tree. Work does not behave that way; queueing does. Decomposed on the heaviest
suite, four readings of one file:

| `check-plugin-integrity-links.tests.ps1` | |
|---|---|
| CI, 4 lanes (3-run mean) | 290.9s |
| this workstation, **alone** | 759.1s |
| this workstation, 16-lane pool | 1,020.7s |
| this workstation, 12-lane pool (busier machine) | 1,617.1s |

So **2.61× is the machine and the rest is contention.** The same 84 suites are **4,661 lane-seconds on CI
and 16,008-21,512 here**: the pool has no size, it has a size *per concurrency and per load*. A figure of
the `wall × lanes` shape is reported as lane-seconds, with its lane count, and never as CPU. The ordinary
band is worth knowing too — two 16-lane readings on the same tree minutes apart came in at 923s (open-pr's
own gate) and 1,021s, so ~10% is noise and nothing under that is a finding.

**TWO THINGS MEASURED HERE THAT ARE NOT REPAIRED HERE.**

- **The local-to-CI ratio is stated backwards in three copies of a shipped lib.** `Invoke-TestSuiteGate`'s
  docstring, `record-suite-durations.ps1`, and the note the latter writes into every regenerated
  `suite-durations.json` all say these suites run *"3.6-4.0x faster on a developer machine"*. Measured
  above, this machine is **2.61× slower** solo. The justification the claim exists to carry — never pack CI
  from a workstation reading — is untouched and if anything stronger, since the direction is not fixed
  either. Filed as [#1713](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1713) rather than
  swept: it sits in the source lib plus its two plugin mirrors under the shared-scripts drift lint, it is
  plugin payload, and replacing one wrong constant with another off n=1 is the error it is describing.
  **Repaired in [#1722](https://github.com/DKJ-Solutions/claude-code-specialists/pull/1722)** (September 9,
  2026), and deliberately without a replacement number: all three copies now say there is no ratio to divide
  out and that the sign is not fixed either. The paragraph higher up this lens keeps its two predictions as
  the worked example of the trap.
- **A resident-interpreter count taken mid-drain is not an orphan count.** Reading 1 opened with
  `40 powershell processes already resident` and 36 were still up seconds after it returned, which reads
  exactly like [#1464](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1464)'s leak and is
  not one: with the machine quiet, four remain and all four are parented by `Code.exe` or `claude.exe`.
  #1464 is about a **killed** run; both of these exited 0. The reading was retracted before it became a
  finding, which is the only reason it is written down.

**AND ONE THING THE MEASURING ITSELF EXPOSED.** `Invoke-TestSuiteGate` prints `== <suite> ==` per completed
suite and no index, so a run gives no sense of how far along it is or how much is left — on a pool that
takes 15-30 minutes locally, the operator's only signal is walls of suite output arriving in completion
order. Filed as [#1717](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1717). The counter
written to watch these two runs also belongs here, because the obvious one is wrong: `grep -c '^== '`
returns 175 of 84, since `test-suite-gate.tests.ps1` prints the same header over its own fixture. Dedupe
against the suites that actually exist — the identical trap `record-suite-durations.ps1` documents for its
duration rows.

**Repaired under [#1717](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1717) itself**
(September 9, 2026) -- the issue rather than its pull request, because the number is the one that was
knowable while this sentence was being written; the changelog entry carries the PR. The measurement above is
kept as written because it is what the repair was built from. The gate
now prints one line as each lane opens and one as each suite leaves one -- started, done and running out of
the run's own total, plus its own elapsed clock -- so the counter this paragraph describes writing no longer
has to exist. **The dedup problem did not go away; it moved into the gate, which is the only party that can
solve it**: each line carries a `[depth N]`, so a fixture's own nested run is filtered out by
`progress \[depth 1\]` instead of by knowing which suites exist on disk. What is deliberately still absent
is a remaining-time estimate: it would have to come from `suite-durations.json`, and that is the CI-seconds
file the #1713 paragraph above says does not convert to this machine at all.

### The `-Seen` repair, re-measured — the +11% is the CALL, not the second pass (September 20, 2026)

[#2203](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2203) was filed because #2199's
branch shipped a repair whose *recovery* had only ever been established by inspection: the second
dedup pass was provably gone from the diff, and nobody had shown the per-call cost came back. Two
earlier sessions tried and neither would stand behind a figure — one measured `main` itself tripling
mid-run under unchanged code. **This is the third attempt, and the machine stayed quiet through all
of it.**

**The method, and the one thing that made it work.** Isolated in-process, one fresh `powershell
-NoProfile` per batch, the three libs dot-sourced from a scratchpad copy of that commit, one warm-up
call, then 300 timed calls of `Get-ConsumerProseDocuments -Documents .. -RepoRoot ..` over a synthetic
30-lens fixture whose `CLAUDE.md` `@`-imports one of those lenses — so kinds 1 and 3 overlap on
exactly one path, which is the case `-Seen` exists for. Two things the earlier attempts did not do:

- **The batch order ROTATES every round**, so a monotonic drift cannot land on one variant. The first
  attempt's own note — 37 to 86 ms per call for identical code depending on run order — is what this
  answers.
- **The contention pre-flight brackets EVERY BATCH, before and after.** Per *round* was tried first and
  is too coarse: a round that opened at 2,279 ms came back with one batch at 76 ms/call against its
  own 43 ms band, because the contention arrived mid-round. A batch whose two brackets are not both
  in band is discarded, not interpreted.

The pre-flight is the issue's own recipe — a fixed CPU-bound loop, no filesystem, no object
machinery, compared against its own earlier band in the same session. It earned its keep immediately:
in the second run it went from 2,279 ms to 4,405 ms between rounds 4 and 5, and every per-call
figure in that window roughly tripled. `Get-Counter` for `% Processor Time` still errors on this
box (`c0000bb9`), so the self-timed band is the only instrument there is, and it is enough.

**The figures.** n=5 per variant, rotated, every batch bracketed in band (2,187-2,256 ms, a 3% spread).
All four return an identical 33-row corpus, so this compares the same work:

| variant | commit | ms/call (median, range) | vs `main` |
|---|---|---|---|
| `main` before #2199 | `8fc89977` | 36.68 (36.49-36.76) | — |
| the promotion, two passes | `97434724` | 40.85 (40.74-41.01) | **+4.17 ms, +11.4%** |
| the `-Seen` repair, one pass | `4375cdee` | 40.90 (40.55-41.05) | **+4.22 ms, +11.5%** |
| `4375cdee` with only the CALL SITE inlined | built for this | 36.62 (36.53-37.13) | **-0.06 ms, -0.2%** |

**So the answer to the question as asked is: the repair does not move it.** `-Seen` is +0.05 ms
against the two-pass shape it replaced — inside the noise of a measurement whose per-variant spread
runs 0.27 to 0.60 ms. The regression is real and reproduces at the same percentage the first
session measured (+11-12%), on a fixture whose absolute band is different because it is a
different fixture.

**And the fourth row is why that is not a dead end.** Take the `-Seen` commit's own file and change one
thing — restore the caller's kind-3 block to `main`'s inline walk, leaving the shared function defined
and merely unused — and the cost is back on `main`'s band exactly. **Everything else on that branch is
free**: the new function's presence, the fail-closed slug guard, the two `try`/`catch` wraps, and the 185
lines the file grew by, nearly all of them docstring. What is left is the boundary crossing itself --
one parameter binding and one 29-element array marshalled back per invocation — with the `try`/`catch`
measured out separately below and the caller-side re-append it forces being 29 `List.Add` calls.

**Which makes the docstring's implicature wrong rather than its measurement.** `+6 to +7 ms, +11-12%`
was correctly measured against the two-pass shape; what does not follow is that the *re-adding loop*
was what cost it. It could not have been — that loop is 29 `HashSet.Add` calls, microseconds — and
the bisect says so directly. Filed as
[#2210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2210) for the branch owner, because
which way to take it (keep the shared function and accept 11% on an always-on path, inline the call
site, or something else) is a design call on a parked branch and not this measurement's to make.

**The `try`/`catch` question, stated as a number so it stops being an order-of-magnitude claim.** A bare
`try` with no exception thrown, measured as the delta between two otherwise identical 300,000-iteration
loops run in both orders, 4 repeats: **0.09 us median per entry, 0.22 us worst, one reading negative**
-- i.e. at or below the noise floor of a loop whose own iteration costs ~18.5 us. Two entries per call
is ~0.2 us against a ~37 ms call: **0.0005%**. The issue's own estimate ("single-digit microseconds,
three orders of magnitude under the noise floor") was conservative by about two further orders.

**One caveat that is worth carrying, because it would otherwise be rediscovered.** Timing the lens
walk's four seam primitives individually (`Get-EnabledPlugins` 1.9 ms, `Get-SeamPaths` 0.2 ms,
`Get-SpecialistFiles` 2.0 ms, 30x `Get-PathRelativeToDirectory` 11.0 ms) sums to ~15 ms against a lens
half that measures ~37 ms in place — identically in every variant. **Component isolation does not sum
to the whole here**, so it cannot be used to attribute anything; the attribution above rests entirely on
the A/D bisect, which compares two whole calls and does not depend on the decomposition. Kinds 1 and 2
together are 0.65 ms, so this always-on path is the lens walk and nothing else.

### Boundaries with the other roles

- A duplication finding is still a duplication first: Nolan may flag the token cost, but the dedup
  act itself stays with [Ravi #24](specialist-06-24-lens.md).
- The loading mechanism itself — harness config, the generator/lint scripts, `settings.json` —
  stays with [Sylvester #15](specialist-05-15-lens.md); Nolan says *what* should get cheaper, Sylvester
  builds it if it is config/script work.
- Rewriting the actual doc/manual/agent-def text for leanness stays with
  [Tessa #16](specialist-06-16-lens.md); Nolan advises on where and how much, Tessa does the rewrite.
- A **test suite's** duration is a cost finding and a testing decision at once: Nolan reports the
  seconds and how often they are spent, [Tycho #18](specialist-04-18-lens.md) decides what an assert
  protects and whether narrowing it gives something up. The suites here are `scripts/tests/*.tests.ps1`
  and the gate that runs them is `open-pr.ps1`, so the *script* half of any repair is
  [Sylvester #15](specialist-05-15-lens.md)'s and the *coverage* half is Tycho's.
- **The safety rules are not Nolan's to trade.** The three gates exist because
  [`CLAUDE.md`](../../../CLAUDE.md#claude-code-specialistss-safety-implementation) says so, and several
  of them were built after a measured failure. Nolan may quantify what one costs and put a
  coverage-for-time trade on the table with both sides numbered; whether to take it is Dave's.

In short: the **how** (measuring cost, proposing savings, staying out of the execution) is portable;
the **what** (this repo's deliberate on-demand loading strategy, the size of its agent-defs/manuals,
the `subagent-shared/` lever, and the three-times-per-release gate bill) belongs to this repo.
