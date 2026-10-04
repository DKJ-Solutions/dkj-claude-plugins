---
name: measure-suites
description: Measure what this repo's test suites cost on CI -- pool total, per-family totals, the slowest shard, and the per-suite changes -- for one set of CI runs or as a before/after comparison of two. Use before and after a change meant to make the suites or the gate cheaper, when a shard has grown slow and you want to know which suites did it, and when refreshing scripts/tests/suite-durations.json (its writer, record-suite-durations, is documented here too). Read-only; it writes nothing and reaches no verdict.
---

# measure-suites -- the suites' CI cost, counted instead of summed by hand

**It exists because the comparison was done by hand twice in two days**
([#2775](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2775)): the Testsuite-atlas on
October 2, 2026, and a before/after check of #2774 on October 3. Both needed
`record-suite-durations.ps1` pointed at scratch copies of `scripts/tests` so it would not rewrite the
committed file, an ad-hoc sum per family, and `gh run view --json jobs` for each shard.

**It is repo-local**, beside `triage-inbound`: it reads this repo's own CI workflow (the sharded
`suites (<n>)` jobs and the table the gate prints in their logs), so nothing here ships in a plugin.

## Run it

```powershell
# one set: the full table, slowest first
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-suites.ps1 -BaselineRunId <id>[,<id>...] -Top 0

# before/after, with families
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-suites.ps1 `
  -BaselineRunId <before-ids> -RunId <after-ids> `
  -Family 'integrity=check-plugin-integrity-*,bwj=bwj-*;bwj-development.tests.ps1'
```

**Take PR runs.** Both trunk pushes a ship leaves behind normally skip the suites -- the `fold:` push by
its subject (#1300), the `merge:` push whenever the merge-commit certificate holds (#2303) -- and
their jobs go green having measured nothing. A run without a table throws rather than reading as zero.
The run id is in the link `gh pr checks <pr> --json name,link` prints for any job of that run.

**Several ids, several families: one comma-separated string each.** Under `-File` PowerShell passes a
space-separated list to the next positional parameter, so `-BaselineRunId 111,222` is the form.

| parameter | what it does |
|---|---|
| `-BaselineRunId` | the "before" set, or the only set |
| `-RunId` | the "after" set; omit it for a one-set report |
| `-Family` | `name=glob`, several globs joined by `;`; a suite may count in more than one family |
| `-Top <n>` | per-suite rows to print (largest change, or slowest); default 10, `0` prints all |
| `-Json` | the figures as JSON instead of the report |

## Reading it

- **Pool total** sums each suite's mean across the set's runs. It is CPU-seconds spread over four lanes
  per shard, not a wall-clock anybody waits.
- **Slowest shard** is the wall-clock that decides when the required check goes green: the mean over the
  set of each run's slowest `suites (<n>)` job.
- **One run is one draw.** The suites are noisy under the gate (#1033), and the report says so when a
  set holds one run. Two or three runs a side is what a claim in a changelog entry should rest on.
- **Rows dropped** counts table rows naming no suite in this tree: the fixture table
  `test-suite-gate.tests.ps1` prints, and any suite a change renamed or deleted. Across a rename, the
  baseline loses that suite's rows, so read the pool delta with it in mind.

## Refreshing `suite-durations.json` -- the other script on this page

`scripts/maintenance/record-suite-durations.ps1 -RunId <ids>` **writes** the per-suite means that
`Invoke-TestSuiteGate` packs its shards from. That is its only job; its `-DryRun` prints just the twelve
slowest suites and the pool total. Use `measure-suites` to look, and this script to commit what you saw.
The two share one parser (`scripts/lib/suite-durations-lib.ps1`), so they cannot disagree about which
rows count. Why the file is only ever refreshed from CI runs is in the script's own docstring.
