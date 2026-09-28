# Changelog

## [Unreleased]

**5 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2565-prepare-release-reads-repo-config · 20260928-100738Z

`prepare-release` reads the store's `scripts/repo-config.ps1` again (inbound
[#2565](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2565)). Since the #2509 hardening it had
dropped the dot-source, so every seam read its default: no store domain, no live theme id, the changelog
looked for at `CHANGELOG.md`, and each step then reported a plausible skip instead of a fault. A fixture run
now pins that the repo's own seams are read, and that a config which throws degrades to a warning naming
only the exception's type.

**Score:** 2

#### What makes this deploy extra special

A store running `prepare-release` on 5.9.0 got a runbook with no push command and every scoped step
skipped, in a repo that had answered every seam. After this release the skill works as documented there.

**Score:** 3

#### Pull Request

prepare-release dot-sources repo-config.ps1 again

Plugins: dkj-policy-bwj

[PR #2575](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2575)

---

### DEPLOY: docs/2562-sweep-stop-condition · 20260928-095412Z

Inside this repo: the `sweep-issues` skill page gains a short section naming when the loop ends.

**Score:** 1

#### What makes this deploy extra special

For whoever runs `/dkj-policy:sweep-issues`: the skill now states that the sweep goes on until no
`free` issue is left, and that the close-out `ship-pr` prints after each issue is not the end of the
sweep. It used to stop after the first shipped issue.

**Score:** 3

#### Pull Request

sweep-issues states its stop condition, so one shipped issue is not the sweep's close-out

Plugins: dkj-policy

[PR #2573](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2573)

---

### DEPLOY: fix/2560-update-plugins-install-when-no-record · 20260928-093321Z

Inside this repo: `update-plugins.ps1` step 2 no longer hands `claude plugin update --scope project`
to a plugin with no install record for this checkout. It runs `claude plugin install <id> --scope
project` instead, which is the command `plugin-versions.ps1` already prescribes for that state, and the
summary counts it as installed. The test suite's older scenarios gained a record for this checkout,
since they were written against the state this fixes.

**Score:** 2

#### What makes this deploy extra special

For whoever runs `update-plugins` in a checkout where the plugins are enabled but were never installed
there: the run used to move **another checkout's** install record and then report success. It now
installs into the checkout it was run from, so the receipt at the end agrees with the summary above it.

**Score:** 3

#### Pull Request

update-plugins installs where this checkout has no install record, instead of updating another checkout's

Plugins: dkj-policy

[PR #2571](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2571)

---

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

