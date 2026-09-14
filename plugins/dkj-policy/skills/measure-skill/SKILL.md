---
name: measure-skill
description: >-
  Measure what a skill COSTS and how fast the script behind it runs -- always-on tokens (paid by
  every session whether the skill fires or not), on-invoke tokens (paid per firing), the delta
  against a stored baseline, and the wall-clock of the script it drives. Use it before adding a
  skill, when a plugin's session cost has grown, or to find which skills are carrying that cost. It
  drives `claude plugin details` rather than estimating from file sizes, so the figure is the
  authoritative one; it is read-only by default and is not a gate. It also covers the always-on
  document path -- `CLAUDE.md` plus everything it `@`-imports -- measured per document and per section.
---

# measure-skill — what a skill costs, before somebody asks

A skill's **description** is paid by every session in every consumer, whether it ever fires or not.
Its **body** is paid per firing. Both were unmeasured in the repo that maintains these plugins until
this script existed, and the growth was real: 7 skill descriptions cost **~1,245** tokens at
`v2.10.0`, while 18 across two enabled plugins cost **~3,650** at `v4.17.0` — nearly 3×, never
re-measured in between.

**This page is itself one of the figures it reports.** Its own description costs always-on tokens in
every session that has this plugin enabled, which is the argument for keeping it short rather than a
joke at its own expense.

## What it measures, and what it deliberately does not

| dimension | who owns it |
|---|---|
| always-on + on-invoke tokens, per skill, with a baseline delta | **this skill**, pass 1 |
| wall-clock of the script behind a skill | **this skill**, pass 2 — read-only invocations only |
| the always-on **document** path — `CLAUDE.md` plus its `@`-imports, per document and per section | **this skill**, via [`measure-always-on.ps1`](#the-second-script-on-this-page--the-always-on-document-path) — a different subject: what the repo's own instruction documents cost, not what the plugins cost |
| frontmatter, dead links, parameter coverage, printed install commands | `check-plugin-integrity.ps1`, which carries a numbered check for each. Not duplicated here: two verdicts on one subject is worse than one. |
| whether the skill actually WORKS — does it fire, does it beat no-skill | `claude plugin eval`. Designed for, not built. See [Pass 3](#pass-3--effectiveness-designed-not-built) below. |

**It computes no token count of its own, deliberately.** Pass 1 parses `claude plugin details`, whose
figures come from the `count_tokens` API for the active model. A second, file-size-based estimate would
produce a number that disagrees with the authoritative one — the failure the performance lens names
directly: *do not estimate from file sizes*.

**It is not a gate and must not become one.** `open-pr` already spends ~10s of lint plus ~170s of
suites, and CI's `lint-en-tests` has a median of **7m 23s** and blocks every merge. A skill's cost
changes on the scale of releases, not commits.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-skill.ps1"
```

**In the source repo, run its own copy instead** — `scripts/maintenance/measure-skill.ps1`. The plugin
cache holds the last *released* mirror and so lags its own source by however many merges have landed
since.

With no arguments it measures **what a session here actually pays**: every plugin enabled for this
repo, read from the settings chain. Pass 1 only, nothing is written.

## Pass 1 — cost

Per skill: always-on, the delta against the baseline, on-invoke, and its share of the plugin's
always-on total. Ranked by always-on, because that is the figure paid unconditionally.

Two rules are enforced by the script rather than left to whoever reads the output:

- **It names the copy it measured.** `claude plugin details` prices the **installed payload** — the
  extracted copy under `~/.claude/plugins/cache/` that a session loads — not the tree, and not the
  marketplace clone, which is what this said until
  [#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812). Where payload and tree
  differ the report says so, because the difference is *queued cost arriving at the next release* — not
  error to smooth away.
- **The "fires how often" column is left empty.** An on-invoke figure without a firing frequency is not
  a cost, and a guessed frequency is worse than a blank one. Fill it in yourself; the script will not
  invent it.

**The parse is the weak point, and it fails loudly.** The per-component table is human-formatted output
whose shape the CLI owns. Two cross-checks run before any figure is printed: the rows must sum to the
printed `Always-on` total within tolerance, and every skill the component inventory names must have
produced a row. Either failing is an `[ERROR]` and **no table is printed for that plugin** — a
plausible wrong number is worse than a refusal.

**Failing loudly is only a virtue where the failure is real**, and this refused two of six enabled
plugins over output that was entirely intact ([#1771](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1771)).
The CLI prints **no per-component table at all** for a plugin whose inventory declares no skills and no
agents — there is nothing to tabulate, and `Always-on: ~0 tok` corroborates it. So an empty table is
judged against that inventory rather than on its own: no rows **and** something owed is still the
`[ERROR]`, no rows and nothing owed is an `[INFO]` naming why, and an inventory that could not be read at
all stays the `[ERROR]` the check was written for.

**And it says what the figures do NOT cover.** The inventory's `Agents (N)` counts only defs found by
convention in a plugin's default `agents/` directory. A def named by the manifest's `agents` key **loads
in a session** and is counted as **0** — measured with a two-plugin control against Claude Code 2.1.267 —
so for such a plugin every always-on figure here, its printed total included, is **skills only**. The
report states that rather than letting a 100% share imply the skills are the whole cost, and rather than
letting `Agents (0)` read as *ships none*: that second misreading is what #1771 was filed on.

Two notations share one table and both are handled: `~3.031` is **3031** (the dot is a thousands
separator) while `~1.3k` is **1300**. A parser that read the first as 3.031 would under-report by a
factor of a thousand and still look entirely plausible, which is why the sum check exists.

## Pass 2 — speed

Opt-in. It times the script behind a skill and reports min/median/max with the machine state and `n`.

**It will not run a script that has no declared read-only mode, and that is the whole safety model.**
Timing the script behind `cut-release` by invoking it would cut a release. So a script is timed only
where its registration in the shared-scripts registry carries a `MeasureArgs` key naming a harmless
invocation; everything else is reported as **not measured**, by name, with the reason. The declaration
lives beside the registration rather than in a list inside the measuring script, because a second
hand-written list is one a newly shared script falls out of silently.

Pass 2 needs that registry and therefore runs only in the repo that maintains these scripts. In a
consumer it reports `[SKIP]` with the reason; **pass 1 works everywhere**, since it needs nothing but
the `claude` CLI.

## Pass 3 — effectiveness (designed, not built)

The question pass 1 cannot answer: *does this skill earn its always-on tokens?* A skill that scores no
better than no skill at all is a pure loss however elegant it is, and the metric that says so is the
**score delta per always-on token**.

`claude plugin eval` already provides the engine — cases, graders, `--runs`, and an `--ablation
with-without` arm that scores the same cases with the plugin removed. It is not wired up here, and
building it is separate work: this repo has **zero** eval suites, so pass 3 starts with authoring
cases via `claude plugin eval init`.

Four flags are non-negotiable whenever that work does happen, and they are recorded here so the first
person to run it does not have to rediscover them:

- **`--no-publish`** — the HTML report otherwise goes to claude.ai. Publishing outside the normal PR
  flow is the repo owner's decision, not a side effect of a measurement.
- **`--max-cost-usd <ceiling>`** — `--runs` defaults to 3 per case, and each run is a real agent.
- **no `--scaffold`** — that runs author-supplied bash as you.
- **`--ablation with-without`** — the delta is the entire point; a bare score does not say whether the
  skill was needed.

## Parameters

| parameter | what it does |
|---|---|
| `-Plugin <name...>` | Which plugin(s) to measure, as `<name>@<marketplace>` or just `<name>`. Default: every plugin enabled for this repo — i.e. what a session here actually pays. |
| `-Skill <name...>` | Limit the report to these skill names. Default: every skill the plugin's inventory names. |
| `-IncludeSpeed` | Also run pass 2. Off by default because it executes scripts — and it executes only those whose registration declares a read-only invocation. |
| `-Runs <n>` | Timed runs per script in pass 2. Default `3`, the smallest n that yields a median. |
| `-BaselinePath <path>` | The cost baseline to compare against. Default: `scripts/maintenance/baselines/skill-cost.json`. |
| `-UpdateBaseline` | Record the measured cost figures instead of only comparing against them. **Merges**: a run narrower than the file updates its own rows and leaves the rest standing. |
| `-OutFile <path>` | Also write the markdown report to this path, for pasting into a lens or a dossier. |

**A comma-separated value works**, and that is not free: `powershell -File <script> -Skill a,b,c` does
not parse PowerShell syntax for the arguments after the script path, so `a,b,c` arrives as one string.
The script splits it, because that invocation form is the documented one.

## Examples

```powershell
# What does a session here pay, and which skills carry it?
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-skill.ps1"

# One skill, with the wall-clock of the script behind it
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-skill.ps1" `
  -Plugin dkj-policy -Skill cut-release -IncludeSpeed -Runs 5

# Record the baseline, so the NEXT run reports the growth
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-skill.ps1" -UpdateBaseline

# A markdown report to paste into a lens
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-skill.ps1" -OutFile skill-cost.md
```

## What it writes

Nothing, unless asked. `-UpdateBaseline` rewrites the baseline file and `-OutFile` writes the report;
without either, the script reads and prints. The baseline is **committable**: token counts come from an
API rather than from the machine that ran the script, so the file means the same thing everywhere.
Pass-2 timings are machine-dependent and are deliberately **not** stored — a median that travelled to
another machine would be a figure nobody could reproduce.

---

## The second script on this page — the always-on document path

**`measure-always-on.ps1` measures what a session pays before a single assignment is given:**
`CLAUDE.md` plus everything it `@`-imports, per document and per section. It is a different subject
from pass 1 above — that one prices what the **plugins** cost, this one prices what the repo's **own
instruction documents** cost.

**It sits on this page rather than on one of its own, and that is the rule rather than a shortcut.**
Only a skill's *description* is paid by every session, so a second page would have charged every
consumer for a tool most of them run once — while the subject (session cost), the owner (the
performance specialist) and the honesty rule below are already this page's. **Which skill, not
whether** ([#875](https://github.com/DaveKJohn/claude-code-specialists/issues/875)).

Run it from the root of the repo you want measured:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1"
```

**In the source repo, run its own copy instead** — `scripts/maintenance/measure-always-on.ps1` — for
the same reason as pass 1: the plugin cache holds the last *released* mirror.

**Bytes are a measurement, tokens are an estimate, and the output says which is which every time.**
No API prices a document: `count_tokens` prices the subject pass 1 reports, which is why *do not
estimate from file sizes* governs there and not here. Here an estimate is the only answer available,
so the factor is calibrated rather than guessed and lives in `measure-context-lib.ps1` with its
calibration attached — it was inherited unexamined at 3.70 through three hand measurements and was
~19% too generous, so every figure derived from it was under-stated while looking precise.

**It reaches no verdict about what should move, and it is not a gate.** It always exits 0. The two
things it can find that really are defects are printed loudly and adjudicated by nobody here: an
`@`-import that does not resolve costs a session that whole document while nothing errors, and
sections that fail to sum to their file mean this script's arithmetic is wrong rather than the repo.

**It reports the copy that LOADS.** Where a document is imported from the marketplace clone rather
than from the tree, the report names both and prints the difference — that gap is queued cost arriving
at the next `claude plugin marketplace update`, not noise to smooth away. **An `@`-imported document is
the one thing that does load from the clone**; everything a plugin ships loads from the installed
payload instead, and that copy moves only on a release
([#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)).

### Parameters

| parameter | what it does |
|---|---|
| `-RepoRoot <path>` | The repo to measure. Default: `CLAUDE_PROJECT_DIR` in a consumer, otherwise the git root of the working directory. |
| `-Root <path>` | The root document of the path. Default: `CLAUDE.md` in that repo root. |
| `-Depth <1-6>` | The deepest heading level that still opens a section of its own. Default `3`. Both useful readings happen at different depths: shallow tells you one section is most of the file, deep tells you which sub-item inside it is. |
| `-Top <n>` | How many sections to list per document. Default `8`; `0` lists all of them. |
| `-Documents` | Skip the section breakdown and print only the per-document table. |

### Examples

```powershell
# What does this repo's instruction path cost, per document and per section?
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1"

# Every section, read deep -- which sub-item is carrying the document
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1" -Depth 4 -Top 0

# The per-document table only, no section breakdown
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1" -Documents
```

**It writes nothing, ever** — no baseline and no `-OutFile`, deliberately. A cost baseline means the
same thing on every machine because the numbers come from an API; these numbers are about the tree
that was just read, and the tree is already in git.
