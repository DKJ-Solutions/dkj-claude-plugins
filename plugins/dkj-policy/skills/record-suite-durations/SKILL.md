---
name: record-suite-durations
description: >-
  Write this repo's scripts/tests/suite-durations.json -- the per-suite CI durations the test gate packs
  its shards from and the hub's Test gate page shows -- from the table the plugin's gate printed in real
  CI runs. Use it when the hub's Test gate page shows its empty state, after a suite has been added or
  has grown, or when a shard has become the slow one. Needs gh and a CI that runs the suites through the
  plugin's gate; -DryRun writes nothing.
---

# record-suite-durations -- the gate's CI cost, written down where the gate and the hub read it

**It ships because every consumer's Test gate page was empty**
([#3474](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3474)). The hub's Test gate page
reads `scripts/tests/suite-durations.json`, and until this skill only the source repo could write that
file.

## The CI contract -- what your CI has to do for this to read it

Three things, and nothing about job names or shards:

1. **The suites are `scripts/tests/*.tests.ps1`.** That is the directory the gate runs and the hub page
   reads; there is no setting for another one.
2. **A CI workflow runs them through the plugin's gate** -- `open-pr.ps1 -GatesOnly`, or
   `Invoke-TestSuiteGate` directly. That gate prints a per-suite table in the run's log, one line per
   suite:

   ```text
      249.2s  new-branch.tests.ps1  started +40.9s
   ```

   Those lines are what this script reads. A step that runs the suites some other way prints none, and
   the run is refused as tableless rather than read as zero.
3. **The run's log is readable through `gh run view --log`** by the account you run this as.

A sharded CI is read the same as a single job: every row in the run's log is a sample.

## Run it

From the root of the consuming repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/record-suite-durations.ps1" -RunId <id>[,<id>...] -Machine 'windows-latest, 4 lanes'
```

**In the source repo, run its own copy instead** -- `scripts/maintenance/record-suite-durations.ps1`.

**Take pull-request runs, two or three of them.** The suites are noisy under the gate, so one run is
one draw; the file holds the mean per suite and names the runs it came from. A trunk push that skipped
the suites carries no table and is refused. The run id is in the link
`gh pr checks <pr> --json name,link` prints for any job of that run.

**Several ids: one comma-separated string.** Under `-File`, a space-separated second id binds to the
next positional parameter, `-RepoRoot`, and the script stops on it with the comma form spelled out.

| parameter | what it does |
|---|---|
| `-RunId` | the CI run ids to read, comma-separated |
| `-Machine` | what the runs were measured on, shown on the hub page. Omitted, the value already in the file is kept; a first write without it records `not stated` |
| `-RepoRoot` | the repo to write into. Defaults to the session's project, otherwise the git root |
| `-DryRun` | print the twelve slowest suites and the pool total, and write nothing |

**Commit the file.** It is a hint the gate reads on every run, not a cache: a suite it does not list
is charged the largest recorded value, so a new suite starts early instead of last.

## What it refuses to do

- **Take a workstation's figures.** The file is only ever written from CI runs: a local reading does not
  convert into a CI one, and packing CI shards off it lands worse than no file at all. The script's own
  docstring carries the measurement.
- **Guess.** A suite with no row in the runs is left out of the file and named in a warning, never
  written with an estimate. A row naming no suite in `scripts/tests` -- a fixture table, a suite since
  renamed -- is dropped.
- **Reach a verdict.** It writes the means and gates nothing.
