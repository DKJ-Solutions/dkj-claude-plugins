# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2735-session-start-no-out-dir · 20261003-085508Z

`/measure-session-start` no longer fails at step 2 on a Windows machine whose temp path has an 8.3
short name. Step 2 now downloads the previous page to the Artifact tool's own default folder and copies
it into the scratch directory, so the tool never sees an `out_dir` it refuses.

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the repair. Steps 3 and 7 keep `<scratch>` on purpose, because they pass it to
PowerShell rather than to the Artifact tool.

**Score:** N/A

#### Pull Request

measure-session-start step 2: download the previous page without out_dir

Plugins: dkj-policy

[PR #2744](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2744)

---

### DEPLOY: fix/2733-xoxo-connector-ids-flip-back · 20261003-084111Z

The consumer register named five plugin ids the `xoxowildhearts` consumer stopped enabling on
September 13, so every session start in this repo printed five `[ERROR]`s claiming plugins that are
enabled were not -- and hid the real ids behind an `[UNLISTED]` line. The ids now match what the
consumer enables, and those false errors are gone.

**Score:** 2

#### What makes this deploy extra special

It is the flip-back the #1906 note predicted, taken on the evidence that note asked for: the consumer
itself migrated, measured on its `main`, so the register follows it rather than churning.

**Score:** 1

#### Pull Request

connectors/xoxowildhearts.json: plugin ids back to @dkj-claude-plugins (#1906 flip-back)

[PR #2743](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2743)

---

