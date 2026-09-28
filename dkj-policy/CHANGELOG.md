# Changelog

## [Unreleased]

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: docs/2557-audience-tier-by-purpose · 20260928-060229Z

The two audience tiers now come with a test a repo can apply to itself: what the repo is **for**. A repo that is a means of selling or delivering something else answers 1. A repo that is the product its user relies on answers 2, and that user counts even when they are its own maintainer: as user they are tier 2, as developer tier 0. The same wording is in the tier model, the scaffold's reader sentence and the `Get-ReleaseAudienceTier` contract record ([#2557](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2557), answering [#2556](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2556)).

**Score:** 2

#### What makes this deploy extra special

A repo whose only user is its maintainer, such as a local single-user tool, can now see from the text that it has a tier-2 audience. Before this, every entry there honestly answered N/A for both tiers and earned a patch. Each new entry's guidance now names that reader, and the adoption question names it too.

**Score:** 3

#### Pull Request

Audience tiers: the test is what the repo is for, so a tool's own maintainer-as-user is tier 2

Plugins: dkj-policy

[PR #2563](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2563)

---

### DEPLOY: fix/2555-unanswered-decide-seams · 20260927-230034Z

`check-script-contract` now tells an unanswered `decide` seam apart from a harmless optional one. A `decide` seam states what the repo IS, so its fallback is an answer nobody chose; until now it printed the same `[INFO]` as a `copy` seam, and the session check called the repo `in sync`. It now adds one non-counting `[UNANSWERED]` line naming every such seam, and the session check forwards it in place of the in-sync verdict. Exit codes and tallies are unchanged. This repo now states the four `decide` seams it used to leave undefined on purpose, each returning its fallback, so a considered answer can be told from an unasked one here too ([#2555](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2555)).

**Score:** 3

#### What makes this deploy extra special

A repo on this workflow now sees, at session start, the questions only it can answer that it never has -- named in one line, such as `Get-ReleaseAudienceTier`, whose silence costs every changelog entry two empty tier sections. Answering each one, with any value including the fallback, clears the line.

**Score:** 3

#### Pull Request

check-script-contract: report unanswered 'decide' seams as their own class, and stop the session check calling that state in sync

Plugins: dkj-policy

[PR #2561](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2561)

---

