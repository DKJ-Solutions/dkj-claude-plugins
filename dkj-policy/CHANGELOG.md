# Changelog

## [Unreleased]

**10 / 11 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2581-untrack-wrangler-cache · 20260928-112224Z

Wrangler's own account cache (`.wrangler/cache/wrangler-account.json`, holding a Cloudflare account id
and an account e-mail) was tracked on `main` in this public repo. It is untracked now, and an anchored
`/.wrangler/` rule in `.gitignore` keeps a wrangler run from the repo root from adding it again. The
copy in history is a separate decision for the owner, #2582. (#2581)

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Untrack the root .wrangler/ cache and ignore it

[PR #2583](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2583)

---

### DEPLOY: fix/2574-progress-bar-per-checkout · 20260928-110844Z

The statusline's progress bar now shows only the runs of the checkout the session is in (inbound
[#2574](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2574)). Records sit in one directory
per machine, so a ship in another repo's window used to draw in every session, and read as a gate running
in the repo in front of you. Each record now carries its writer's working directory, and the statusline
draws a record only when that path and the session's workspace contain each other. A record from an
older writer, or a session whose payload names no workspace, is shown as before.

**Score:** 2

#### What makes this deploy extra special

Anyone working in two repos at once sees only their own repo's gate and ship in each window, instead of a
bar that looks like work running where it is not.

**Score:** 2

#### Pull Request

The statusline draws only the progress of runs in this session's own checkout

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2580](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2580)

---

### DEPLOY: fix/2566-live-push-list-skips-deletions · 20260928-105429Z

Inside this repo: `Get-LivePushRows` in `scripts/lib/live-push-rules.ps1` gained a `-DeletedPaths` set and a
`deleted` verdict, and `live-preflight.ps1` and dkj-policy-bwj's `prepare-release.ps1` now feed it from a
`--diff-filter=D` read, with rename detection off in every range read.

**Score:** 2

#### What makes this deploy extra special

For whoever prepares a store's live push: a theme file deleted since the last release is no longer
offered as a `push` row. That row claimed a change `--only` cannot make, and the file stayed on live
unnoticed. Each such file is now listed under `held` as deleted and still on live, with its own step
saying the store delete is a separate decision. A renamed file's old path, which used to be in no list
at all, is reported the same way.

**Score:** 3

#### Pull Request

live push list lists files deleted in the range as push rows

Plugins: dkj-policy-bwj, dkj-subagents-shopify

[PR #2576](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2576)

---

### DEPLOY: docs/2558-visible-result-stays-on-branch · 20260928-104254Z

A branch parked for the owner's visual review now keeps the checkout on that branch. The constitution's visible-result rule says so, and Chris's "it ends on the trunk" rule no longer fires on a park: that chain is not finished, since its next step is the owner looking at the working copy. The trunk follows the merge. A session that moves on to other work in the same checkout, like a sweep, hands over through the repo's own preview route instead ([#2558](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2558), [#2559](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2559)).

**Score:** 2

#### What makes this deploy extra special

An owner reviewing a UI change can look at it straight away. The session no longer switches to the trunk after parking, which reverted the running app to the old screen and left them nothing to judge.

**Score:** 3

#### Pull Request

A branch parked for the owner's visual review keeps the checkout on that branch, in the constitution and in Chris's trunk rule

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2579](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2579)

---

### DEPLOY: fix/2569-publish-page-wrangler-oauth · 20260928-103105Z

Inside this repo: `publish-page.ps1` gained a second publish route for when `CLOUDFLARE_API_TOKEN`
is absent, with two small functions in `page-publish-rules.ps1` and end-to-end tests against an
`npx.cmd` shim.

**Score:** 2

#### What makes this deploy extra special

For whoever publishes a BWJ page from a machine that is logged in with `npx wrangler login`: the
publish now works without an API token. It goes through `wrangler kv key put/get --remote` and is
proved with the same SHA-256 read-back. A login to a different account is refused, and the message
names both routes.

**Score:** 3

#### Pull Request

publish-page publishes through a wrangler OAuth session when CLOUDFLARE_API_TOKEN is absent

Plugins: dkj-policy-bwj

[PR #2578](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2578)

---

### DEPLOY: docs/2567-audience-asana-link-from-marker · 20260928-102112Z

The BWJ ticket-handling page now says which Asana task an audience release item links to (inbound
[#2567](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2567)). It is the task the mirror's
three matchers resolve, marker first, and never the first Asana URL in the issue body. A reference line
naming the CRO test a build came from is context, not the ticket.

**Score:** 2

#### What makes this deploy extra special

A colleague reading a store's release notes finds their own development ticket linked, and not the CRO
test it came out of.

**Score:** 2

#### Pull Request

An audience item's Asana link is resolved by the mirror's matchers, never the first URL

Plugins: dkj-policy-bwj

[PR #2577](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2577)

---

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

