---
name: measure-closeouts
description: >-
  Measure how the CLOSE-OUT actually behaves on this machine against its stated three-line ceiling,
  across every recorded session -- so a change to the close-out rule can be evaluated instead of
  guessed at. Use it before and after any repair to close-out wording or mechanism, when a receipt
  keeps over-running and you want the rate rather than an impression, and to see the delta against a
  stored baseline. It reads the session transcripts in place and emits only counts -- never transcript
  content -- always exits 0, and is deliberately not a gate.
---

# measure-closeouts — the close-out ceiling, counted instead of argued about

The close-out rule has been repaired six times and lost six times: the three permitted shapes (#849),
the receipt rule (August 27, 2026), the bounded filing line (#1402), the duplication-then-ceiling order
(#1408), the printed shape at the chain's end (#1884), and the fillable template (#2043).

**Every one of them correctly diagnosed the previous failure and did not prevent the next**, and #2048
asked why. The answer is that **none of them was ever measured**: each was evaluated by waiting to see
whether the owner complained again — a sample of one, arriving weeks later, from whichever repo they
happened to be in. A repair judged that way cannot be told from a repair that did nothing.

This script is the missing instrument. It does not improve the close-out; it makes the next change to
it checkable.

## The two populations it refuses to conflate

A transcript's last assistant message is **not** automatically a close-out. Most sessions end wherever
the person walked away — mid-explanation, mid-question — and holding those to a receipt's ceiling
would manufacture a violation rate out of nothing.

| population | what it is | status |
|---|---|---|
| **ALL** | every session's final assistant message | **context only** — never a verdict |
| **CHAIN** | the final assistant message *after* the session's last chain-ending script (`ship-pr`, `open-pr`, `fold-changelog-entry`, `park-cycle`, `cut-release`) | **the governed set** — exactly where `Write-CloseOutReceipt` prints, so the only set a verdict may be read off |

## What it found on the day it was written

September 17, 2026 — 10 project directories, 328 sessions, 263 in the governed population:

| | |
|---|---|
| over the 3-line ceiling | **222 / 263 — 84%** |
| over 6 lines | 146 / 263 — 56% |
| median / mean / p90 / max lines | 7 / 8.5 / 16 / 76 |

**So the rule has never been in force anywhere.** Six complaints are six of two hundred and
twenty-two, which reframes every previous repair: they were not guardrails that kept slipping, they
were advice against an 84% baseline nobody had counted.

It also settles the leading hypothesis, that the trigger is volume of work: `r = 0.207` over n=263 —
statistically real, about **4% of the variance**, and **not the cause**. The smallest quarter of
sessions still averages 5.8 lines against a ceiling of 3, so removing the volume effect entirely would
leave the rule broken.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-closeouts.ps1"
```

**In the source repo, run its own copy instead** — `scripts/maintenance/measure-closeouts.ps1`. The
plugin cache holds the last *released* mirror and so lags its own source by however many merges have
landed since; the script carries the source-repo guard and refuses that case rather than handing back
a plausible stale number.

With no arguments it measures every project directory on this machine and prints both populations,
plus the delta against the stored baseline if there is one. Nothing is written.

## Parameters

| parameter | what it does |
|---|---|
| `-TranscriptRoot <path>` | Where the session transcripts live. Defaults to `~/.claude/projects`. |
| `-Ceiling <n>` | The stated ceiling in non-empty lines. Defaults to `3` — "two or three lines", from the orchestrator's own body. Blank separators are excluded, because the ceiling is about how much a person has to read. |
| `-Project <wildcard>` | Limit to project directories whose name matches. Default: all of them. Use it to read one repo's rate on its own. |
| `-UpdateBaseline` | Write the CHAIN population's headline figures to the baseline, so the next run after a repair prints the delta instead of a bare number. **Off by default**: a baseline overwritten by accident is how a regression becomes the new normal without anybody deciding it. |
| `-BaselinePath <path>` | Where `-UpdateBaseline` reads and writes. It has a correct default in both copies — see below; pass it only to put the baseline somewhere else. |
| `-Json` | Emit the figures as JSON on stdout instead of the human report, for a caller that wants the numbers. |

### The baseline, and where it lands in each copy

`-UpdateBaseline` stores the CHAIN population's headline figures so the **next** run prints a delta
instead of a bare number. `-BaselinePath` decides where, and it has a correct default in both copies —
it is an override, not something you have to remember:

| running from | baseline lands in | why |
|---|---|---|
| the repo this script is maintained in | `baselines/closeout-ceiling.json` beside the script | where the committed baseline already sits |
| **the plugin mirror** (a consumer) | `dkj-policy/baselines/closeout-ceiling.json` in **your** repo | `$PSScriptRoot` is the version-scoped plugin cache, which the next `claude plugin update` replaces — a baseline written there is lost without anybody being told |

The parent directory is created if it does not exist. **Commit the file**: a baseline nobody can diff
is the same sample of one this whole script exists to replace.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-closeouts.ps1" -UpdateBaseline
```

## What this is NOT

- **Not a gate, and it must not become one.** It always exits 0, reads only, and reaches **no verdict
  about any single close-out** — the same boundary, for the same reason, as `measure-always-on.ps1`
  beside it. What was missing was never the judgement, it was the number. Whether a blocking mechanism
  should exist at all is a separate, open decision ([#2050](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2050)).
- **Not a reader of your content.** The transcripts are read in place and never written to. Only line
  counts, character counts and tool-call counts leave the script — which is what makes it safe to run
  in a repo whose measurements are published while the sessions they came from stay private.
- **Not repo-scoped.** It measures the machine, across every project directory on it. `-Project`
  narrows the report, not the read.

## Why it is here at all

It was built in the repo that maintains this workflow and, on its own numbers, that repo is the
**least** affected: 50%, against 97% and 88% in the two worst. The two worst are consumers, and every
close-out complaint on the record came from a consumer. An instrument that only measures the machine
least affected by what it measures is the wrong way round — so it ships
([#2051](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2051)).
