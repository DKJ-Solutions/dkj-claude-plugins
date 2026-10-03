# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

