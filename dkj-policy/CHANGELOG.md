# Changelog

Everything merged since the last release sits under **`## [Unreleased]`**, **newest first**: **one `###` per
change**, and under it two named `####` sections. The `###` heading is the change's own —
`` DEPLOY: `<branch>` `` and the moment it
landed — and the text directly beneath it answers what a reader arrives with: what the change deploys to
`main`. Then `#### What makes this deploy extra special` for the second audience, and `#### Pull Request`.
Every level here moved one deeper on August 26, 2026, when the pending section above them was introduced and
the development cycle beside them shifted to match; entries written before that day carry the whole set one
level shallower and are read exactly as they always were.
The tier numbers live in the parser rather than in any heading. That second heading said `PR` rather than
`deploy` for one day, August 24 to 25, 2026, and `change` for the four days before that; every wording it
has ever carried is still read, so an entry below written under any of them is parsed exactly as it always
was — including the four written under `PR`, which are in the list below right now. Entries written
before August 23, 2026 carry that first answer under a `###` question of its own with the second nested
at `####` beneath it; entries before August 16 carry the longer set of headings that shape replaced, and
every earlier shape is read exactly as it always was. Every release ever cut is listed in
[`releases/history.md`](releases/history.md) — each with its date, type and title, and a link to what that
release was worth. How the mechanism works (entry files, the Significance sections, folding) is described in
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md), the page that ships with
the workflow.

Each change declares its own **reach**, and per audience how much it **weighs** there — one `##### Tier N`
sub-section per tier where a repo writes them numbered, each closing with its score; here the audience tier
carries a named heading beside the others instead. This list does not order on it: it is a record of what
landed, so it reads in the order things landed. What the declaration decides is what the **release
documents** lead with — they rank themselves on it — and what may be released at all, because **the bump
follows the highest tier pending**: **tier 0 only earns a patch**, **tier 1 or higher earns a minor**, and
a **major** recaps ten minors. So a changelog holding nothing but tier 0 is a patch waiting to be cut, not
a release with nobody to announce it to.

**The line directly under `## [Unreleased]` is a tally, and nobody types it.** It reads
`**4 / 9 minor entries**`: how many of the pending entries reach the audience this repo publishes to, out of
how many are waiting for the next release, and which bump that work has earned. The two numbers answer
different questions and may differ — the fraction counts tier 2 and above, the bump follows tier 1 and
above — so `**0 / 8 minor entries**` says nothing reaches a subscriber while the version still owes a minor
for what reaches management. It is
**derived from the entries below it every time it is written**, by the fold that adds one and the cut that
removes them all, so it holds no state of its own and a hand-edited count is simply corrected on the next
fold. It ends with an HTML comment that marks it as machine-written; that marker is what the next run
replaces, so anything else written in this space is left alone.

---

## [Unreleased]

**28 / 43 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2263-suite-bound-scaling · 20260922-184312

`Invoke-TestSuiteGate` bounded every suite at a fixed 1,800s, and #2255 measured what that costs on a
loaded machine: a 9-lane run spent 31 minutes to end red over `check-plugin-integrity-docs.tests.ps1`,
which passed all 188 of its asserts standalone minutes later. The bound was blind to the one thing that
decides whether a suite reaches it -- how fast the machine is actually going.

It now scales with that. As each suite finishes, the gate compares what it spent against the cost
`suite-durations.json` records for it, and the ratio of the two is how much slower this run is going
than the recording; the per-suite bound is that ratio applied to 1,800s, clamped between 1,800s and
3,600s. Nothing is converted between machines -- both halves of the ratio are seconds from the same
suites in the same run -- which is why this does not re-open the per-suite derivation #2255 declined.
Applied to the run that produced the failure, the pace reads 2.72x and the bound would have been
3,600s against the 1,820s that file needed.

**It can only ever loosen.** A run at or faster than the recorded pace is bounded at exactly 1,800s, so
no currently-green run can be turned red; an explicit `-SuiteTimeoutSeconds` and the `-1` off switch are
untouched. The cost is stated rather than hidden: on a machine slow enough to reach the ceiling, a
genuine wedge is now reported after 60 minutes instead of 30.

The issue proposed scaling by the **lane count**. Instrumented, contention runs the other way -- one
suite takes 3.7x longer under 23 busy siblings than under 3 -- so that shape would have been most
generous exactly where suites run fastest. The 9-lane run was slow because the machine was starved,
which is also why only 9 lanes opened; the lane count reports the cause rather than being it.

**Score:** 4

#### What makes this deploy extra special

`native-capture-lib.ps1` is mirrored into `dkj-policy`, so every consumer running this workflow's test
gate gets the scaled bound. It lands hardest where it is worth most: a slow or loaded machine is the one
that reaches an 1,800s bound on a green suite, and also the one least able to afford a second full gate
run spent hunting a wedge that was never there. A consumer with no `suite-durations.json` is unaffected
-- no recorded cost means no pace, and no pace resolves to exactly the bound they have today.

**Score:** 3

#### Pull Request

The per-suite test-gate bound now scales with the machine state that actually slows a suite down

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2273](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2273)

---

### DEPLOY: fix/2271-guard-exception-message-prints · 20260922-182527

A `$_.Exception.Message` reads like text this workflow wrote and is not: .NET composes the sentence
and then interpolates the offending input into it, which in these scripts is routinely somebody
else's. Measured here, a consuming repo whose `scripts/repo-config.ps1` fails to parse puts its own
source line -- newlines and square brackets intact -- straight into a `Write-Warning`, and one that
`throw`s supplies the whole message. That output is forwarded into session context by the
SessionStart hooks, which is the line-forging vector the foreign-text guards exist for. Every console
print of an exception message now passes a strip: 34 sites under `scripts/**` via
`Format-SafeProseToken`, seven in the `dkj-policy-bwj` template via its own `Format-ForConsole`, and
the nine hook catch-alls via an inlined chain, because there the lib may be the very thing that
failed to load. A new suite asserts the three measurements the sweep rests on and scans the tree so
the 51st site cannot be written unguarded.

**Score:** 3

#### What makes this deploy extra special

Nothing to migrate and nothing to run -- a consumer gets this with the next release, and the only
visible difference is on a day something was already broken: an error line is now one line, with
brackets shown as parentheses. What changes underneath is that a repo's own file can no longer put
a forged line or a counted `[ERROR]` marker into a session start it did not author.

The sweep also went further than the issue measured, in two directions worth knowing about. The
issue reported 34 sites from a `scripts/**` grep; the eight SessionStart hook catch-alls sit outside
that path and are the highest-severity members of the class, since their output is precisely what
reaches session context. And the class already had one correctly guarded site -- two files away from
its own capture, so a same-line grep reported none. Both are recorded as registry entry 15, which
also states the bound the new tree scan still has: it proves no site prints one inline unguarded, not
that the indirect route is clean. A ninth hook joined the class from the trunk while this branch was
open, which is why that scan now reads every hook rather than every `*-sessioncheck.ps1`.

**Score:** 2

#### Pull Request

Every console print of an exception message passes the prose guard

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2316](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2316)

---

### DEPLOY: fix/2312-merge-fetch-depth-falsy-zero · 20260922-165021

`ci.yml`'s conditional `fetch-depth` on the merge-commit checkout (#2303) never actually reached
`0`: GitHub Actions expressions treat the number `0` as falsy, so `cond && 0 || 1` silently fell
through to `1` on every push, regardless of `cond`. Fail-closed, so this cost no safety margin --
the full suite ran on every merge commit exactly as it did before #2303 -- but it meant the
suite-skip #2303 was built for had never actually fired. Fixed by quoting both arms as strings
(`'0'` / `'1'`), which GitHub Actions never treats as falsy, plus a new assert pinning that a bare
unquoted `0` cannot return to this line unnoticed.

**Score:** 2

#### What makes this deploy extra special

N/A -- a CI-internal fix to this repo's own `.github/workflows/ci.yml`; nothing here is mirrored
to a consumer.

**Score:** N/A

#### Pull Request

ci.yml's merge-commit fetch-depth no longer falls through the falsy-zero && / || trap

[PR #2313](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2313)

---

### DEPLOY: fix/2307-mid-run-budget-wall-clock · 20260922-163148

`park-cycle.tests.ps1`'s mid-run-budget case no longer measures anything in real time. A network
budget's deadline can now be stated in a **file** -- `New-NativeCaptureBudget -ExpiresFile`,
`park-cycle.ps1 -BudgetDeadlineFile` -- and is re-read on every budget question, so the suite's `gh`
shim moves it from inside the call instead of the case sitting idle until it falls due. What moves is
the deadline, not the clock: real time still runs and a budget still genuinely expires.

That case had gone red on CI twice, on the same two asserts, at ~7s of tolerance (#2077) and at ~15s
(#2307), each time costing a blocked merge and a full re-run. A third number would have failed the
same way, because the tolerance and the wall clock the case spends are one number: the budget starts
before the process does, so everything before the first call has to fit inside it, and the case cannot
end before it falls due. Timed banner to first assert on a workstation, the case went from 18.3s to
2.4s.

The trigger is recorded where it belongs rather than repaired: `Get-TestSuiteShardOrder` charges an
untimed suite the pool maximum, which is right for its own purpose and also **relocates suites it does
not name** -- a 0.7s addition priced at 669.1s moved this suite into a differently loaded shard, and the
branch that added it got the red. Its docstring now says so.

**Score:** 3

#### What makes this deploy extra special

N/A. A consumer running this workflow gets one optional parameter nobody types and a lib seam that is
inert unless it is passed: `park-cycle`'s behaviour under the Stop hook, by hand, and with either
existing budget knob is byte for byte what it was. What is fixed is this repo's own required check.

**Score:** N/A

#### Pull Request

The mid-run budget test case stops depending on how fast the machine is

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2311](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2311)

---

### DEPLOY: fix/2296-workflow-job-timeouts · 20260922-161759

Every job in `.github/workflows/` now declares `timeout-minutes`, and so does every job this workflow
scaffolds into a consuming repo. Until now none did, so a wedged job ran to GitHub's six-hour default --
and the damage is not a red check but a check that never registers at all: `lint-en-tests` `needs:` the
suite shards, so a wedged shard leaves the required check unreported, which reads as *still running* to
`ship-pr`, to the ruleset and to anyone looking at the pull request. Measured on run 35728958033, where
`suites (2)` sat in progress for 38 minutes against a normal ~13 and a local re-run of the identical
shard that finished every suite in 344s; the branch could not merge until somebody cancelled the job by
hand, which itself took about eight minutes to land.

The caps are read off run history rather than chosen: 10 on `lint` (max 1.5m), 5 on the summary job
(max 0.1m), 10 on each short runner (all under 1m), 60 on the two agent jobs, whose runtime is the
model's work rather than a script of this repo's. The one on `suites` is picked against a second number
instead -- `ship-pr`'s required-check registration wait is also 1800s, so a cap of 30 or more would time
the job out at the same moment the shipping session gives up and teach it nothing. At 25, roughly twice
the worst shard ever observed, the shard goes red and `ship-pr` reads a failed check with a job log
behind it.

This does not replace the in-process suite bound and is not another argument about its constant.
`$script:GateSuiteTimeoutSeconds` reaps a wedged child *with an attribution*, and here it never fired --
so whatever wedged sat below the level a bound inside the process can reach.

**Score:** 3

#### What makes this deploy extra special

A consumer's scaffolded runners get the same treatment, which is the half no gate in this repo could
ever see: a wedge in an adopted `branch-entry`, `always-on-budget`, `fold-on-merge`, `verify-resolved`,
`repo-settings`, skeleton `ci`, `theme-check` or `asana-mirror` job blocks that repo's own required check
with nobody watching, and the write-capable ones would spend six hours holding a standing credential.
Nothing already scaffolded changes on its own, and the pickup runs along three separate routes rather
than one: the first six arrive on a consumer's next `adopt-dkj-policy` run, `theme-check` on
`adopt-shopify-floor`, and `asana-mirror` on `adopt-dkj-policy-bwj`.

**Score:** 2

#### Pull Request

Every CI job declares timeout-minutes, so a wedged job cannot hold the required check for six hours

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-shopify

[PR #2300](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2300)

---

### DEPLOY: feat/2304-split-critical-path-suites · 20260922-160144

The CI gate was bound by one test file. `check-plugin-integrity-docs.tests.ps1` recorded 669.1s
against a 391s work bound over 16 lanes, so the gate's 11.5 min was that file's duration and not the
pool's -- the other 120 suites ran free in its shadow. It is now four suites, partitioned on
gate-invocation count, and the family's longest part went 235.8s to 64.3s standalone. All 188 asserts
are preserved and were verified by running the four parts, exactly as the first split of this family
held itself to its own count in #714.

This is step 1 of #2304: the critical path moves to the next heaviest file rather than to the work
bound, so the shard count does not change and the issue stays open for the remaining three.

**Score:** 3

#### What makes this deploy extra special

#1358 priced this exact split and declined it -- correctly, when the file was 221.8s and the gap was
~15s. It was 669.1s when the decision was revisited, so the gap had become 278s: 40% of the gate. The
decision never became wrong, the thing it was measured on changed underneath it, and nothing reported
that. The split also surfaced a latent order dependency between two checks that only held while they
shared a file -- the standing lesson being that a cost-based partition may not depend on which
scenario runs first, and that such a dependency is invisible until somebody wants to split on weight.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-docs into four suites: CI was bound by one 669s file

[PR #2310](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2310)

---

### DEPLOY: feat/2303-conditional-merge-commit-suite-skip · 20260922-154718

CI no longer re-runs the full ~11-minute, four-shard test suite on a `merge:` push to `main` when
the merged PR's own head SHA already carries a green required check and `main` had not advanced
(net of fold commits) since the run that certified it -- prices and answers #2303, which measured
that 46% of a day's CI runs land on the trunk and the `merge:` half of those re-tests a tree
`ship-pr` had just certified as non-stale. Unlike #1300's fold shortcut, this cannot be decided
from the commit subject alone (a UI merge carries no such guarantee), so CI re-derives the fact
from GitHub's own records instead of trusting the commit that claims it, reusing the identical
pure functions `ship-pr.ps1`'s own pre-merge staleness gate already relies on. Fail-closed
throughout: an unreadable check, an undateable run, or `main` having actually moved all fall back
to running the suites in full.

**Score:** 3

#### What makes this deploy extra special

N/A -- a CI-internal change to this repo's own `.github/workflows/ci.yml` and the scripts it
calls; nothing here is mirrored to a consumer (unlike `ci-fold-lib.ps1`, this repo's own internal
suite gate is never shipped), so no subscriber of the plugin marketplace is affected.

**Score:** N/A

#### Pull Request

CI on a merge commit skips the suites when the merged PR is already independently re-certified fresh

[PR #2308](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2308)

---

### DEPLOY: fix/2288-summary-asserts-unmeasured-capture · 20260922-153046

`update-plugins.tests.ps1` went red under gate load at roughly the rate #2114 measured -- about a
coin flip per full run -- and for a reason that repair had left standing. #2114 gave `Assert-CleanExit`
a third state for a capture whose exit code was never measured, on the stated bound that everything
else in a scenario is unaffected by it. Two asserts are not: `update-plugins.ps1` counts such a
capture as a failure, by a decision #2081 argued and #2114 accepted, so its green summary line is
never printed in precisely the runs the tolerance waves through -- and scenario 1 was asserting that
green line. They are now asserted through `Assert-Summary`, which holds a measured run to the green
summary and an unmeasured one to the red summary the script is specified to print instead. A run that
prints neither still fails, so the scenario keeps proving something about the summary rather than
being excused from it.

**Score:** 1

#### What makes this deploy extra special

Nothing to migrate and nothing to run: this is a test suite in the source repo, and no consumer
carries it. What it buys is that a gate and a CI leg stop going red on a documented race that nobody
can act on, which is the failure mode that teaches a reader to skim red checks.

The measurement worth keeping is the shape rather than the rate. #2114 repaired the assert the race
lands on **first** and reasoned about the rest by class -- commands, ids, scopes, order -- which was
right for every assert except the one composed from the failure counters. So the lesson is that the
bound to check is not "is this assert about the exit code" but "is this assert downstream of a value
the unknown feeds".

**Score:** N/A

#### Pull Request

The update-plugins summary asserts survive an unmeasured capture, as its exit assert already does

[PR #2309](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2309)

---

### DEPLOY: fix/2298-harden-lens-naming-rollup · 20260922-151146

The lens-naming roll-up from #2289 gets three corrections. Its marker becomes `[LENS-RETIREMENT]`, so it
no longer shares a token with `check-roster-sync.ps1`, which prints `[LENS-NAMING]` for the unrelated
fact that its own naming vocabulary is older than the tree it reads (#2219). Its verdict now lets a
measured `NOT YET` outrank an unreached connector, carrying the unmeasured count into that same sentence.
And a test-only `-ConnectorsRootOverride` gives the roll-up the seam it needs to be tested at all.

The precedence is the half that changes an answer. Both arms are about coverage, which makes the cautious
one look like the one that should win -- but they are not on the same axis: a connector measurably on the
also-read spelling settles the condition as FALSE, and nothing an unreached one holds can make it true
again. On the live register -- 1 over, 2 behind, 3 unreached -- the run printed `NOT ANSWERABLE FROM THIS
MACHINE` while the answer, *no*, was in hand. The green ending keeps exactly the gate it had: still
reachable only when nothing is behind **and** nothing is unreached or empty.

The seam exists because the roll-up fires only on a full-register sweep, which is precisely what
`-Manifest` -- that suite's isolation everywhere else -- switches off, so its verdict logic landed with
zero assertions on it. Scenario 14 now covers all three endings, the part-migrated state, the grouping
and the narrowed run.

**Score:** 3

#### What makes this deploy extra special

It is a signal being made trustworthy in the same week it was built. A readiness check exists to be read
once, months later, by somebody deciding whether a compatibility layer may be removed -- which is the
worst possible moment to discover that its verdict understated what it measured, or that nothing ever
asserted its verdict at all.

For a subscriber of this workflow nothing changes in behaviour: no new error, no new exit code, no new
session-start line. What changes is what a deliberate run of the connector check tells them when part of
the register is out of reach, which is the normal case rather than the exception.

**Score:** 2

#### Pull Request

The lens-naming roll-up: a marker of its own, a verdict that does not understate what it measured, and the seam that pins both

[PR #2305](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2305)

---

### DEPLOY: fix/2237-workflow-facts-crlf · 20260922-145824

`adopt-ci-floor` reads a job's `name:` on a CRLF checkout, so a Windows consumer is no longer handed a
ruleset requiring a check GitHub never reports.

`Get-WorkflowFacts` collected job keys and job names with two regexes, both anchored on `$`. .NET's
multiline `$` matches only immediately before a `\n`, so against a CRLF file the name capture's
`[^\r\n]*` stopped at the `\r` and the anchor failed -- collecting no names at all -- while the key
capture survived the same file by accident, its `\s*$` absorbing the `\r` first. The text is normalised
to LF once on read now, which closes the class rather than the two instances visible today.

**The damage reached past the wrong note it was reported as.** `$prJobIds` then held one id where LF
holds two, and one is exactly the count the paste-ready ruleset call auto-fills on -- so a consumer with
a single named job in a single `pull_request` workflow was handed a ruleset requiring the job KEY, while
GitHub reports that check under its NAME. A required check that never reports leaves every pull request
pending forever. On LF the same tree declines to auto-fill and prints the candidate list, so the bug
moved the script onto the branch it would otherwise have refused.

Reported from `BWJ-Development/xoxowildhearts` as inbound #2237.

**Score:** 4

#### What makes this deploy extra special

A subscriber of this workflow on Windows -- which is the reporting consumer's own configuration -- could
follow a printed instruction into a merge outage on their trunk. It reaches only a consumer who adopts
the CI floor without a required check already in place, but for that consumer the failure is total and
the cause is three layers from the symptom.

**Score:** 4

#### Pull Request

Get-WorkflowFacts reads a job `name:` on CRLF too

Plugins: dkj-policy

[PR #2306](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2306)

---

### DEPLOY: fix/2295-capturedir-empty-race · 20260922-143220

#2295 measured `test-suite-gate.tests.ps1`'s capture-retention asserts going red in CI at random,
twice in one hour on two unrelated branches, always in CI and never standalone: `CaptureDir` came
back empty on a run that should have kept it, once for a genuinely timed-out suite and once for an
ordinary failing one.

The retention decision (in `Invoke-TestSuiteGate`'s own `finally` block) judged whether a suite's
output survived by calling `(Get-Item -LiteralPath $f).Length -gt 0` the instant the pool reaped it.
That races the exact ambiguity this file already named and built a fix for, twice, elsewhere
(#1679, #1731, #1252): `$proc.WaitForExit()` returning true says the CHILD process exited, not that
`Start-Process`'s own pipe-to-file copy -- running on its own thread, in this process -- has caught
up, and a grandchild that inherited the handle can hold it a moment longer still. Under CI
contention that gap widens rather than closes, which is exactly the class #2255 already measured
for this same pool one door over. `Write-GateCaptureBlock` already reads these same files through
`Read-NativeCaptureFile`'s settle-budget-aware probe when it PRINTS them a few lines above the
verdict -- the retention check was the one remaining reader of a reaped suite's capture file that
still used the unprotected form, so it could (and did) disagree with what the console had just
shown.

The retention check now reads through the same settle-aware probe, bounded by the same
`$script:NativeCaptureSettleMilliseconds` budget the print path already spends, so a suite whose
output legitimately arrived -- just not by the instant `Get-Item` was called -- is no longer read as
having written nothing and its whole capture directory deleted out from under it.

**Score:** 2 -- an occasional, CI-only false-red on the required check (`lint-en-tests`), costing a
full CI cycle plus a judgement call each time it fires; most PRs never touch this path at all.

#### What makes this deploy extra special

`scripts/lib/native-capture-lib.ps1` mirrors into every consumer that runs this workflow's test
gate as their own CI check, so the same race -- deleting a failing suite's kept evidence under the
consumer's own CI contention -- was reachable there too, not only in this repo's CI.

**Score:** 1 -- a reliability fix for a race a consumer would rarely hit and would have read as "the
gate deleted my evidence," not as something to act on.

#### Pull Request

guard the capture-retention asserts against an empty CaptureDir race

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2301](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2301)

---

### DEPLOY: fix/2297-exercise-guards-in-review · 20260922-141728

The code reviewer and the security engineer now carry a standing rule that a guard, matcher, validator
or sanitiser in the material under review is **run** against input designed to defeat it, rather than
read -- and that reporting "no findings" on one nobody exercised is a false report. It arrives as one
shared block (`guard-exercised`) in both agent defs, so it fires on every invocation regardless of how
the review was asked for, with the craft reasoning and the measurement behind it in each portable
manual. Measured on PR #2290: asked generically, the review returned no findings on a newly added lint
check; asked specifically what unguarded spellings it would wrongly pass, the same reviewer ran it and
found four defects -- the worst certifying a call site as guarded while it stripped nothing.

The act is bounded rather than open-ended: the guard is run as the **subject** of the review and never
obeyed, its body is read for side effects before it is called, the function is copied into a scratch
file instead of the module around it being loaded, and a guard that cannot be exercised safely is
reported as a finding rather than run anyway.

**Score:** 3

#### What makes this deploy extra special

Every repo that installs `dkj-subagents-alpha` gets the rule on its next plugin update, and it changes
what a review is worth there: a reviewer that reads a guard and reports clean is the failure mode this
closes, and it needed no prompt to produce. Noticed the first time either specialist is put on a diff
that adds a check.

**Score:** 3

#### Pull Request

A guard in the diff is exercised against adversarial input, not read

Plugins: dkj-subagents-alpha

[PR #2299](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2299)

---

### DEPLOY: feat/2289-lens-naming-readiness-signal · 20260922-135444

`check-connectors.ps1` can now answer the question the #2130 dual-name layer's retirement is keyed on:
which spelling each registered consumer's repo lenses are actually written in. A non-counting
`[LENS-NAMING]` line per connector, and a roll-up across the register that states its coverage before
its verdict — `NOT ANSWERABLE FROM THIS MACHINE`, `NOT YET`, or `ALL N ARE OVER`, and only the third
opens the window. The classifier behind it, `Get-SpecialistNamingState`, reads the shapes table rather
than any literal, so a future rename step that flips a row cannot leave the report describing the wrong
file.

Dave's decision of September 19, 2026 retires the old lens names *"once the connector register shows all
six are over"*, and the register could not show it: manifests store bare ids and no filenames, and the
one check that does resolve a lens file resolves it to compare its **body**. A bridge whose expiry
cannot be established is a permanent one by default, which is what #2289 measured. The signal is
**measured, never declared** — no `lensNaming` manifest field, on the same ground the `plugins[].id`
rule already stands on: hand-maintained state about somebody else's tree turns the register into a false
alarm about a migration nobody ran.

Run on the real register it reports 3 of 6 connectors reachable on this machine, 1 over and 2 not —
so the honest answer today is that the window is not yet answerable, which is exactly the fact that was
previously unobtainable. #2292 is the retirement tracker the issue's other half asks for.

**Score:** 3

#### What makes this deploy extra special

Nothing a consumer runs changes. `check-connectors.ps1` and the `connectors/` register are
source-repo-only — a consumer's session check runs `plugin-versions` in `-Brief` mode instead — and the
new classifier travels in the plugin payload unused by any consumer-side caller. The `[LENS-NAMING]`
lines are deliberately neither `[ERROR]` nor `[INFO]`, so they do not count and no session hook surfaces
them: a consumer still on the old spelling is **not broken**, which is the entire purpose of the layer
being measured.

**Score:** N/A

#### Pull Request

The lens-naming readiness signal the #2130 dual-name retirement is keyed on

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2294](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2294)

---

### DEPLOY: fix/2284-claim-absorbed-issue · 20260922-131923

An issue a pull request declares it closes is no longer left unowned on the tracker. Before the push
`open-pr` reads the assignees off the open-issue list it already fetches and, for each issue this PR
declares, claims an unassigned one under the account `claim-issue` would resolve, warns when somebody
else holds it, and says nothing when the list could not be read.

It closes the one route into a branch that no pickup check can see: a finding filed mid-branch and
repaired on the branch already in flight is never *started*, so it is never claimed -- and the next
session is correct to read it as untouched. Measured at a conflicting pull request, a hand-resolved
conflict, three corrected documents and a second ship.

**Score:** 4

#### What makes this deploy extra special

The assignee field stops lying by omission. Until now it answered "is somebody working this?" only for
issues somebody *started*; the issues most likely to be worked twice were exactly the ones it was silent
about, because they were created by the session that went on to repair them.

For a subscriber of this workflow it is one line in an `open-pr` run they will mostly not notice -- and
on the day two people are on one board, it is the difference between a refusal at pickup and a conflict
at the merge.

**Score:** 3

#### Pull Request

A declared issue is claimed at the push, so an issue absorbed mid-branch stops reading as unowned

Plugins: dkj-policy

[PR #2293](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2293)

---

### DEPLOY: fix/2280-strip-tree-paths-json-keys · 20260922-125809

`hook-stdin-guard.tests.ps1` printed a tracked file path and a `hooks.json` event key raw, at four
sites across two groups, into a CI log on a public repository. Both classes now pass
`ref-print-lib.ps1`'s strip -- `Get-DisplayPath` for the paths, `Get-DisplayRef` for the key -- and the
site is registered as entry 14 of the standing print-site list, which is the part that outlives the
repair. The suite is the first entry on that list that is not a script: a sweep looking for foreign-text
prints in the tooling read past it, because a test suite does not look like a place this workflow
prints.

A second guard came out of the branch's own review. Asserting that the strip FUNCTIONS work leaves the
four repaired lines free to be un-repaired by a later edit, so the suite now also scans its own source
and holds each line printing a scanned value to naming a strip -- per VALUE, not per line, because the
per-line form passed a line that guards its path and prints the JSON key beside it raw, which is the
reported defect itself.

**Score:** 2

#### What makes this deploy extra special

The list entry ships to every consumer of `dkj-policy`; the suite does not. So what a consumer receives
is one more entry on the page they read to find every place this workflow prints somebody else's words
-- and the reason it was missed, which is the reusable half. No behaviour of theirs changes, and there
is no live exploit to have been exposed to: the tree holds three `hooks.json` files, all at reviewed
paths. The failure this prevents is a tracked path or a JSON key carrying a `\p{Cf}` run -- an RTL
override or a zero-width sequence -- repainting a public CI log so it reads as something other than
what it says. `check-plugin-integrity.ps1`'s `tracked-name` check does not hold a path to that class,
and no lint has an opinion about a JSON key at all.

**Score:** 1

#### Pull Request

hook-stdin-guard.tests.ps1 routes its printed tree paths and JSON event keys through the console strip

Plugins: dkj-policy

[PR #2290](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2290)

---

### DEPLOY: fix/2283-ship-pr-refusal-signal · 20260922-122815

`ship-pr`, `open-pr`, `fold-changelog-entry`, `cut-release` and `park-branch` now end a refusal with a
`[REFUSED]` line naming what did and did not happen -- printed on the error stream the host already used,
and followed by an explicit `exit 1`. `ship-pr`'s says which side of the merge it stopped on, because a
refusal after the merge leaves the fold owed, and that is the opposite of nothing having happened.

The defect it closes is that a backgrounded run reported `completed (exit code 0)` for a run that merged
nothing (measured on PR #2282): the refusal's only machine-readable signal is the process exit code, and
every recorded invocation of these scripts is read through a pipe, which reports its own `0` instead. The
scripts' exit codes were never wrong -- unpiped they are 1 -- so the repair had to move the verdict into
the output rather than into the exit path the report named.

**Score:** 4

#### What makes this deploy extra special

It is the half of a chain ending that was missing. A finishing run has printed a close-out receipt since
#1884; a refusing one printed a PowerShell error record and nothing that said *this run did not finish*.
The two endings are symmetrical now, and the asymmetry had been costing exactly what it was bound to cost:
a session reading the cheap signal and closing out on the wrong one of the two.

For a subscriber of this workflow the change is invisible until a run refuses -- and then it is the
difference between reading a stack trace and reading a verdict. Nothing about which runs refuse changed.

**Score:** 3

#### Pull Request

A refused chain-ending run says so in its LAST LINE, not only in an exit code a pipe throws away

Plugins: dkj-policy

[PR #2286](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2286)

---

### DEPLOY: feat/2279-cpu-time-in-lane-timeout-verdict · 20260922-121322

A lane the test gate kills at its bound now reports what its process tree actually consumed -- the
whole tree's CPU over its lifetime, and how much of that it consumed in the last three seconds before
the kill -- directly under that suite's own `TIMED OUT` header.

**It answers ONE of the two questions #2279 asked, and the other turned out to be unanswerable.**
That issue's table wanted three cases separated: a suspended machine, a wedged lane and a deadlocked
tree. This file's own `$script:GateSuspendGapSeconds` block already records #1941's deadlock at 0.23s
across 29 children over 141 MINUTES, which is indistinguishable from #2231's wedge at 0.58s over 22 --
so no CPU reading separates those two, and this does not claim to. What it does separate is "something
was running" from "nothing was running", which is precisely the question the console had been handing
to the reader with a whole standalone re-run attached to it (#2255, whose own measurement cost a second
full gate run on a suite that was merely slow).

It also settles the implementation question #2279 left open. `TotalProcessorTime` reads the direct
child only, and every wedge in this family sits in a grandchild -- so the reading is taken from one
`Win32_Process` CIM snapshot of the machine and walked down the tree. Measured against a real busy
grandchild (3.45s of CPU over a 3s window, all of it two levels down) and a real idle one (0.000s).

Nothing about when a lane is reaped changed. The bound, the grace window and the kill are exactly what
they were; the sweep now marks, measures and then kills in the same pass, three seconds later in it.
And it does not reopen the suspend question, which that same block declines CPU for on grounds that
are untouched here: nothing added credits, reaps or kills anything -- it composes sentences.

**Score:** 3

#### What makes this deploy extra special

N/A -- this repo's subscribers consume the plugins, and the test gate is a development-time tool that
runs before a release exists. A consumer running the shared `native-capture-lib.ps1` does get the
better diagnosis on their own gate, but only ever as a maintainer of their own repo, never as a
subscriber to anything this repo ships.

**Score:** N/A

#### Pull Request

The test gate's timeout verdict reports the lane tree's CPU time

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2291](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2291)

---

### DEPLOY: fix/2230-guard-retracted-release-notes · 20260922-115804

`Build-ReleaseNoteDraft` selected a release's audience-facing entries by tier alone, with no way to see
that a later pending entry retracts an earlier one -- so a build that reached the trunk and was reverted
before the cut was drafted as delivered work, in the author's own confident words, in the one document
an employer or commissioner reads to learn what their money bought (measured in `BWJ-Development/smartwatchbanden`
v2.44.0: two of three retracted features survived into a published management release-notes page).

The repair is the issue's own suggested shape, in full rather than the weaker report-only fallback: an
optional `Retracts: <branch>, <branch>` line on the entry that undoes earlier work, read and resolved
across the whole pending changelog (`Resolve-ReleaseRetractions`), an unresolvable target refused at cut
time rather than read as "nothing to withhold," and the withheld branches named in an HTML comment in the
audience document so the person finishing the draft sees the decision instead of a silent gap. `CHANGELOG.md`,
its changelog note and the generated GitHub Release body are untouched -- all three are records of what
reached the trunk, and the retracted work did too. The field is optional and absent from every existing
entry, so an ordinary release is byte-for-byte unchanged; asserted directly in `release-lib.tests.ps1`.

**Score:** 2

#### What makes this deploy extra special

The reader here is the party that runs the upgrade -- a consuming repo (life-hub, smartwatchbanden, and
every other repo that installs `dkj-policy`) cutting its own release with `cut-release.ps1`. Most releases
carry no retraction and this change is invisible to them. When one does, it is exactly the failure the
issue measured: a deliberately-pulled build announced as shipped, in a document that has already been read
by the time anyone notices -- "the one error in this whole cycle that a consumer cannot correct after the
fact," in the issue's own words. Rare, but when it fires it protects a real published document from a
confidently wrong sentence rather than merely tidying prose.

**Score:** 3

#### Pull Request

Guard cut-release against drafting a retracted change as delivered work

Plugins: dkj-policy

[PR #2287](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2287)

---

### DEPLOY: fix/2278-command-guard-docstring-post-1734 · 20260922-114235

`command-guard-lib.ps1`'s docstring described the arrangement #1734 replaced. It told a reader of a
security-relevant lib that `guard-live-theme` **still** carries its own copy of this logic, which may
have drifted -- exactly the hazard #1734 removed -- and pointed at #1734 as an open filing. A reader
acting on it would go hunting for a second copy to reconcile, or decline to change this file on the
ground that a divergent twin exists. The passage is now in the past tense, the way
`guard-live-theme.ps1`'s own header already reads it, and it names where the route landed: the
`command-guard-lib-shopify` registry entry and the `$PSScriptRoot`-relative dot-source. The
reasoning behind the deferral is kept, because it is what the `-TextTools` parameterisation rests on.
Two further clauses in the same paragraph were stale in the same way and are repaired with it: one
mirror named where there are two (the second being the one #1734 created), and check-report-lib cited
as having two readers when #1917 made it three. That second count is dropped rather than corrected,
because this one sentence has now carried a stale count twice.

**Score:** 2

#### What makes this deploy extra special

N/A -- a docstring in an internal lib. Nothing a subscriber of a service reaches, and nothing about
what any script does.

**Score:** N/A

#### Pull Request

command-guard-lib.ps1's docstring describes the arrangement #1734 replaced

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2285](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2285)

---

### DEPLOY: fix/2248-guard-raw-foreign-text-prints · 20260922-111836

Four classes of foreign text -- characters typed by somebody outside this repo -- reached a console
unstripped. **Two of the four sat on a line where a neighbouring value *was* guarded**, which is what
makes those two misses rather than judgements: `adopt-ci-floor.ps1` printed the consumer's own
workflow filename raw next to a job id it sent through `Get-DisplayRef`, and `sync-main.ps1` printed
the `Get-ShopifySyncLogPath` seam answer raw next to a branch name it guarded on the same line. The
other two had no guarded neighbour to be measured against -- the required-check context name sat
beside that same raw filename, and `check-consumer-siblings.ps1` carried no strip of any kind
anywhere in the file. (#2248 itself said three; that was its own count, and it does not survive a
reading of the trunk.) All
four are now guarded -- `Get-DisplayPath` for the paths and filenames, `Get-DisplayRef` for the
required-check context name, `Format-SafePathToken` for `check-consumer-siblings.ps1`, whose lines
reach session context through `Write-Info` where a square bracket can be counted as a hook marker.

The repair went further than the report at one site. `check-consumer-siblings.ps1`'s
`$label`/`$f.Member`/`$f.Members` are the same connector-manifest `repo` field that
`check-connectors.ps1` already guards at six sites, so they are guarded here too; `$f.Class` and the
`$where` clause are this repo's own values and are deliberately left alone, with the reason in the
code rather than in anyone's memory.

**Then the regression pin written for that repair found two more sites the repair had missed** --
`$label`, the same manifest field, printed completely raw at the `$unreadable` line and the
per-member `read` line earlier in the same file (#2272). They were guarded here rather than
deferred, because registry entry 13 had by then been rewritten to say this site was repaired:
leaving them would have made the entry false the day it was written, which is the exact failure the
entry describes.

**#2272 was then shipped by somebody else first, and that is worth recording rather than tidying
away.** It was filed here and folded into this branch without anyone claiming it on the tracker, so
it read as unowned and another session correctly picked it up and landed it as PR #2275 while this
branch was in review. Their repair guards `$label`; this branch's also guards `$inv.Reason`, via
`Format-SafeProseToken` -- a composed sentence carrying foreign text only in its two
`Get-GitHubInventory` arms, guarded at the print rather than at composition because the same value
is carried into a live `?ref=` API call. The two were reconciled by merging the trunk in and
keeping the superset. The cost was a conflicting pull request and a re-ship, and the cause was one
missing claim: the tracker is the only thing two sessions share, and an issue absorbed into an open
branch is still an unclaimed issue to everybody else.

**This also corrects a claim the registry was making.** #2247 asserted of `adopt-ci-floor.ps1` that
"this is an accuracy defect in the registry, not an unguarded site -- nothing is exploitable today",
and that was false: two more values at the same site were unguarded, one of them on the very line the
assertion cited as proof. Registry entries 4, 8 and 13 each said their value prints RAW and was not
repaired; all three now describe the guard and the line it sits on. What each entry said about how
the *list itself* fails is kept, because that outlives the repair.

One value was deliberately not touched. `$_.Exception.Message` stays raw, here and at 33 other
console sites -- .NET composes that sentence, but it interpolates the offending path into it, so a
guarded path can come back unguarded in the second half of the same line. Whether to strip all 34, or
only where the exception's own input was foreign, or to state in the registry that the class is out
of scope, is a repo-wide decision rather than a one-line patch inside an unrelated fix. Filed as
#2271 with the measurement.

**Score:** 2

#### What makes this deploy extra special

Two of the three scripts ship to consumers and run in their own tree: `adopt-ci-floor.ps1`, whose
whole job is to read a consuming repo's `.github/workflows/` and ruleset and report what it found,
and `sync-main.ps1`. Both are mirrored into the plugin payload, so the values repaired in them are
the reader's own text being read back to them on their own console. `check-consumer-siblings.ps1`
is **not** in that group -- it has no plugin mirror and runs only here, as this repo's own
maintenance tool, taking consumer data as input. Its half of this fix reaches no subscriber and is
tier 0 work; the score below is for the two that do ship.

Nothing was exploited and this prevents a failure that has not happened, so the failure is worth
naming precisely: a format character in a workflow filename, or in a required-check name a
third-party integration built out of branch- or PR-derived text, makes the floor report say something
other than what it means -- an RTL override reverses a verdict line, a zero-width run welds two names
into one that reads as a legitimate third, an escape sequence repaints the terminal. These scripts
print verdicts a person acts on, which is the whole reason the guard exists everywhere else in the
workflow. Reaching the consumer needs a release; nothing they run today changes on its own.

**Score:** 1

#### Pull Request

Guard the foreign text that adopt-ci-floor, sync-main and check-consumer-siblings printed raw

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2282](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2282)

---

### DEPLOY: fix/2276-live-theme-stdin-contract · 20260922-104858

`guard-live-theme.ps1`'s header now states the assumption its no-handle branch rests on: the
`hooks.json` wrapper drains the payload with `$(cat)` and pipes it back into PowerShell, so
`IsInputRedirected` is true on every call the harness makes and the `exit 0` path is unreachable from
any command a session can cause. It also states what breaks if that ever stops -- this guard would
degrade towards ALLOWING, the one direction its own fail-towards-CHECKING rule forbids, on a subject
that cannot be un-published. `hook-stdin-guard.tests.ps1` gains a third group holding the half that is
reachable: every hooks.json command that drains the payload must hand it back, counted out of the tree
rather than hand-listed. The pipe is anchored to the invocation that actually runs the guard, so an
unrelated `| powershell` elsewhere in the command vouches for nothing and a typo'd `||` is not a pipe;
`pwsh` counts as an interpreter, since this repo ships a CI template that uses it. Each narrowing has
its own counter-case. Removing the pipe from either shipped wrapper now turns the gate red.

The failure it prevents, since it has not happened: a future edit to either PreToolUse wrapper that
drops the `printf | powershell` re-pipe. Nothing would fail -- both guards would go on exiting 0 on an
empty payload, which is their documented behaviour -- and the live-theme guard would be silently
waving through publishes, deletes and live pushes in production instead of only in the hand-run case
the branch was built for.

**Score:** 1

#### What makes this deploy extra special

A Shopify consumer auditing the live-theme guard now meets that assumption in the file itself rather
than reconstructing it from the wrapper. Nothing the guard does changes.

**Score:** 1

#### Pull Request

guard-live-theme records the stdin contract its no-handle branch depends on

Plugins: dkj-subagents-shopify

[PR #2281](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2281)

---

### DEPLOY: fix/2272-guard-repo-field-two-more-sites · 20260922-103528

`check-consumer-siblings.ps1` printed a sibling's own manifest `repo` field raw at two console
sites -- the per-member "read" line and the "not compared" line built from it -- both sitting just
above the block df25f9f6 (#2248) already guarded with `Format-SafePathToken`. A `repo` field
carrying an embedded newline forged a second console line; both sites now go through the same
guard as their neighbours, so the whole loop treats this manifest field consistently.

**Score:** 1

#### What makes this deploy extra special

Same value class and same script as #2248: a sibling checkout's own manifest text, read back to
the person running the comparison. Nothing was exploited, and this closes the two sites #2248's
own widening did not reach.

**Score:** 1

#### Pull Request

Guard the manifest repo field at the two console sites df25f9f6 (#2248) missed

[PR #2275](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2275)

---

### DEPLOY: feat/avatars-assets-folder · 20260922-101346

The three GitHub-account avatars move out of the repo root into `assets/avatars/`, with a README
stating the fixed path every machine reaches them at and why the folder is root material rather than
plugin payload. `README.md`'s **Repo layout** gains the matching bullet.

Small, and noticed the moment somebody looks for those images or at the root listing: the root is
back to its entry documents, and "where are the avatars" has an answer that holds on every machine
instead of per download folder.

**Score:** 2

#### What makes this deploy extra special

Nothing reaches the subscriber of this workflow. The folder is this repo's own material, deliberately
outside the plugin payload, so no consuming repo receives it in a cut or has anything to adopt.

**Score:** N/A

#### Pull Request

GitHub-account avatars in assets/avatars/

[PR #2277](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2277)

---

### DEPLOY: fix/2255-suite-bound-basis · 20260922-094657

The per-suite timeout in `Invoke-TestSuiteGate` carried a comment claiming **"no suite can reach it by
being slow"**, sized off the slowest row in `suite-durations.json` (`new-branch.tests.ps1`, 290.2s on a
four-lane hosted runner). That sentence is what tells a reader a 1,800s timeout means a wedge -- the
reading that made #2233 diagnosable -- and it has been false since #2232 recorded
`check-plugin-integrity-docs.tests.ps1` at 415.5s. A 9-lane run of this repo's 121 suites then reached
the bound on that file, which passed all 188 of its asserts standalone on the same checkout minutes
later.

The comment now carries both readings that bracket the bound instead of the CI one alone, retracts the
false sentence against the run that falsified it, and records why the bound stays a fixed constant
rather than being derived from `suite-durations.json`: that file is measured on CI, a local reading does
not convert into a CI one and the sign is not even fixed, so a derived bound would be tightest exactly
where the machine is slowest.

The correction is also printed. A red verdict naming a timed-out suite now adds that a slow suite can
reach the bound, so the timeout is not by itself a wedge, and names the one measurement that separates
the two -- a standalone re-run of that suite. The comment is read by whoever maintains the lib; the
verdict line is read by whoever just lost half an hour, and that is where the false reading cost its
second full gate run.

**Score:** 3

#### What makes this deploy extra special

`native-capture-lib.ps1` is mirrored into `dkj-policy`, so every consumer running this workflow's test
gate gets the corrected verdict. It lands hardest where it is worth most: a slow machine is the one that
reaches an 1,800s bound on a green suite, and also the one least able to afford a second full gate run
spent hunting a wedge that was never there.

Nothing changes for a run that does not time out, and the constant itself is untouched.

**Score:** 2

#### Pull Request

The 1800s suite bound no longer claims a basis that a measured run has already exceeded

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2262](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2262)

---

### DEPLOY: fix/2264-hook-stdin-console-guard · 20260922-093846

Running either of this workflow's two command guards by hand -- the first thing anybody does when a
git or a theme command is refused and they want to know why -- used to hang on line one with nothing
printed, waiting on a console read for a Ctrl+Z that is never coming. Both now read stdin only where
there is a handle to read, which is the guard the other five members of this family already carried.
A new suite counts that family out of the tree rather than from a list, because a wrong hand-count is
what let these two sit unguarded through two separate sweeps. It proved itself within hours: a
neighbouring branch changed how six of those sites read stdin, and the suite went red on the spot
rather than reporting the shrunken family as a clean one.

**Score:** 3

#### What makes this deploy extra special

A consumer of this workflow gets the same repair, and it reaches the guard protecting their live
Shopify theme as well as the one protecting their working copy. Nothing about how either guard judges
a command changes, so there is nothing to act on -- what changes is that the guard can be questioned
by hand on the machine it just refused something on.

**Score:** 2

#### Pull Request

Two PreToolUse guards no longer block on a console read when run by hand

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2269](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2269)

---

### DEPLOY: feat/2265-declared-settings-at-the-moment-of-change · 20260922-092503

A GitHub-side setting -- a merge switch, a ruleset rule, a required check -- can be a decided answer with
a measured reason, and until now nothing pointed a session at that reason before it proposed changing
one. The declaration has been machine-readable since #1726, but its only runner is a daily schedule, so
its earliest catch is after the change and after whatever the change let through. Two pointers close that:
a hard rule in the system administrator's portable manual (read the declaration first, and an empty
declaration means nothing is watched rather than that a setting is free to move), and a line in
`ship-pr`'s CI-wait invitation -- the block that already answers *what do I do about this wait* now also
answers *not that*, naming how many settings the repo declares and the one command that prints them with
their reasons. The line is derived from `Get-ExpectedRepoSettings`, never asserted, so a repo that
declares nothing gets no line at all.

**Score:** 3

#### What makes this deploy extra special

Nothing to migrate and no behaviour changes: both halves are pointers, and the session-side guard that
#1726 weighed and declined stays declined. For a consumer of this workflow the manual travels with the
core team plugin and the `ship-pr` line travels with `dkj-policy`, where it stays silent until that repo
declares settings of its own -- the same rule that keeps `ship-pr`'s watch from naming a CI check it
cannot vouch for, applied to a repo's settings.

**Score:** 2

#### Pull Request

Point a session at the declared GitHub-side settings before it proposes changing one

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2274](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2274)

---

### DEPLOY: docs/2242-fold-stamp-heading-drift · 20260922-090154

Corrects the tree's ~15-site drift about where the fold's merge stamp lands: the entry's own
`### DEPLOY:` heading since August 23, 2026, not the `Pull Request` heading that carried it from
August 19–23. Left untouched: passages that correctly describe that August 19–23 window as history,
and the lint's duplicate-section errors, which are about the closing PR *link* rather than the stamp.

**Score:** 3 -- self-contradicting comments and docstrings (a summary line disagreeing with its own
body) are exactly the kind of drift that misleads the next person to touch this code.

#### What makes this deploy extra special

`DEVELOPMENT-portable.md` and `CONTRIBUTING-portable.md` are the only description a consumer has of
where their changelog's ordering key lives; the stale text pointed at the wrong heading.

**Score:** 1 -- prevents a consumer debugging their changelog's ordering from looking at the
`Pull Request` heading, finding no stamp, and concluding the fold is broken.

#### Pull Request

Correct the stale 'Pull Request heading' claims about the fold's merge stamp

Plugins: dkj-policy

[PR #2268](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2268)

---

### DEPLOY: fix/2249-bound-stdin-read · 20260922-084156

A SessionStart hook could hang a session start forever and print nothing while doing it. The timeout
that was supposed to stop that never ran: `[Console]::In` is a `SyncTextReader` on Windows PowerShell,
so `ReadToEndAsync()` completed on the calling thread before the `Wait()` bounding it was ever reached.
On a redirected handle nobody closes, the read blocked for as long as the session lasted -- measured at
15 s and still going, at no CPU at all. The read now goes through the raw stdin stream, which queues to
the thread pool and leaves the calling thread free to time out, so the bound binds. The same repair
went into the two neighbours that had no bound at all: the status line and the shim that wires it up,
both of which run every couple of seconds and would otherwise have left one more stuck process behind
on every refresh.

**Score:** 3

#### What makes this deploy extra special

A second defect surfaced in the same three lines and was fixed with them: the payload was being decoded
with the OEM console codepage rather than UTF-8, so any accented character in a path came through
mangled. Harmless for the session id, which is a UUID, and not harmless for the working-directory field
other readers in this family take a repo root from.

For a consumer of this workflow, nothing changes about how anything is used and no migration is needed;
a failure that had not visibly happened yet can now no longer happen. The read costs about 80 ms where
it used to cost about 15, which is the price of the bound actually binding, and it is stated in the code
beside the measurement rather than left for somebody to find.

**Score:** N/A

#### Pull Request

Bound the hook stdin read so an open handle cannot wedge a session start

Plugins: dkj-policy

[PR #2270](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2270)

---

### DEPLOY: fix/2259-predossier-double-merge-stamp · 20260922-082715

The fold wrote the merge moment twice on a pre-dossier entry -- once on its heading, once on the closing
`[PR #NN](url)` line -- because its gate still asked whether the entry had a `'Pull Request'` section, a
question the stamp writer stopped acting on on August 23, 2026. The gate now reads
`Test-EntryHeadingTakesMergeStamp`, which shares `Set-EntryMergeStamp`'s own scan, so the two cannot
answer differently. Nothing changes for an entry written in the current shape.

**Score:** 2

#### What makes this deploy extra special

A consumer of this workflow meets the fold through the plugin mirror, so the duplicate landed there too.
It prevents a failure that has not happened yet, and the failure is namable: any branch parked before
August 6, 2026 -- here or in a consuming repo -- carries a pre-dossier entry, and folding one now writes
the landing date in two places at once.

**Score:** 1

#### Pull Request

A pre-dossier entry no longer folds with the merge date written twice

Plugins: dkj-policy

[PR #2266](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2266)

---

### DEPLOY: fix/2250-gh-not-started-wording · 20260922-074056

Six `gh` reads composed their own sentence about an unmeasured exit code, so a `gh` that is **not
installed** -- a state #2234 deliberately reports with `ExitCodeUnknown` set, to keep the ~63 audited
sites working untouched -- was described as one that ran, and the reader was sent to a re-run that
cannot settle a missing dependency. Each now asks `Test-NativeCommandStarted` first, and names the
install as the remedy.

Two of the six say something different on purpose. `check-repo-settings.ps1` and
`check-connectors.ps1` sit behind a `Get-Command gh` guard that has already proved gh is on PATH, so
*"gh is not installed"* would be a cause the same run has measured to be false -- the class of
unmeasured diagnosis this whole family exists to stop printing. What is reachable at those two is a gh
that was found and still could not be launched, and their sentences say that instead.

At `ship-pr.ps1` the repair also reaches one layer out of what the report named: the enclosing
`Write-Warning` closed with *"so a re-run normally settles it"*, which is the same false advice in the
same printed sentence.

**Score:** 2

#### What makes this deploy extra special

Every one of these sentences is what a consumer reads in the window this workflow keeps measuring
against itself: adopting it before installing the GitHub CLI. The gate runners are the sharpest of
them -- `check-branch-entry.ps1` runs in a consumer's CI, and `ship-pr.ps1` prints its line while
merging -- and both told that reader to try again, forever, instead of naming the one thing that would
fix it. `check-consumer-siblings.ps1` reaches the same reader through `-Source github`, which bypasses
its own availability gate.

**Score:** 2

#### Pull Request

Six gh sites no longer say a missing gh ran, nor advise a re-run that cannot settle it

Plugins: dkj-policy

[PR #2261](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2261)

---

### DEPLOY: fix/2252-refresh-suite-durations · 20260922-072057

`scripts/tests/suite-durations.json` is re-recorded from three post-merge CI runs, and it repairs more
than the row #2252 reported. `script-contract.tests.ps1` moves from 98.8s to **208.9s**, which is the
+12 child spawns #2236 added plus the contention of a pool that has grown since. But the file was also
**eleven days and 30 suites stale**: it listed 91 of the 121 suites in the tree, and
`Invoke-TestSuiteGate` charges an unlisted suite the largest recorded value -- so it was packing 30
suites at 290.2s each when they total **266.5s between them**. The packer believed the lightest
thirty suites in the pool were its heaviest. Every row is now a measured mean rather than a ceiling.

**Score:** 2

#### What makes this deploy extra special

N/A. The file is this repo's own CI packing hint; nothing in it ships in a plugin payload, so no
consumer reads it and none of their gates change.

**Score:** N/A

#### Pull Request

Refresh the recorded CI suite durations from post-2236 runs

[PR #2260](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2260)

---

### DEPLOY: fix/2234-native-capture-launch-failure · 20260922-032338

`Invoke-NativeCapture` threw when the executable was absent, so a caller got an exception where the
whole point of the function is that it gets a verdict. Under `$ErrorActionPreference = 'Stop'` -- which
every task script in this workflow sets on line 1 -- that ended the run rather than the one call. It now
returns a capture carrying a new `NotStarted` field, and the two optional `gh` calls that used to die
degrade the way their own docstrings already promised.

The report measured the `Start-Process` arm. The `&` arm threw too, earlier and for a different reason:
command discovery raises `CommandNotFoundException`, which is terminating regardless of
`$ErrorActionPreference`, so the function's own preference dance never reached it. Both arms are
repaired -- a fix on one would have left `gh` fatal on every unbounded call in the family, which is most
of them.

`ExitCodeUnknown` is set on the new state deliberately, so all 63 bounded call sites keep working
untouched; `NotStarted` only says which of the two reasons it is. The four sites that needed more than
that got it: two that composed a sentence around a number that is now `$null`, and two that would have
spent a re-ask relaunching a command that is not installed.

**Score:** 3

#### What makes this deploy extra special

Anyone adopting this workflow before installing the GitHub CLI -- the first hour of every adoption --
met this as a dead `new-branch` run that created no branch and no development document. On such a
machine `fold-changelog.tests.ps1` also ran red, 20+ asserts across four fixture scenarios, every one
reporting a fold that never ran; that half is felt by whoever runs this repo's suites without `gh`,
not by a consumer, who never runs them. And `claim-issue`'s documented *no account* refusal never
printed on the one machine state it was written for, because the read above it threw first. All three
are gone.

**Score:** 3

#### Pull Request

Invoke-NativeCapture returns a verdict instead of throwing when the executable cannot be started

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2258](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2258)

---

### DEPLOY: feat/2243-sweep-issues-skill · 20260922-001336

A backlog worked by several machines at once had one procedure in this marketplace and it was a
**prompt block** in `dkj-policy-bwj` -- pasted by hand into a fresh session per machine, with its claim
written as prose for a session to type and its race resolution releasing the issue from both sides of a
tie. `sweep-issues` is that procedure as a skill in `dkj-policy`, and `claim-issue.ps1` gains the claim
it needs: **`-Tag`**, which claims with a marker comment carrying `machine/account` instead of with an
assignee. Both halves of that tag are load-bearing and both were measured -- two accounts sharing a
machine name and two machines sharing an account each produced an ambiguous claim
([#701](https://github.com/BWJ-Development/smartwatchbanden/issues/701)) -- and the assignee is still
written beside it as the tracker's visible signal rather than as the claim. `Resolve-ClaimRace` reads
the markers back and names the **winner** (earliest comment, ties broken on the node id, which is
arbitrary and identical for every reader) so exactly one session keeps the issue and the losers release
their own marker. `-Verify` answers in an exit code whether THIS tag still holds an issue, which is what
the resume step needs and the sharpest place a vague claim costs; `-Release` drops this tag's own
markers and nothing else; `-Candidates` reads the whole board in one call and judges it without writing
anything, because between choosing and claiming sits the question of whether the issue is this repo's
work at all ([#722](https://github.com/BWJ-Development/smartwatchbanden/issues/722)). The default
assignee mode is untouched throughout, and the tag verdict is mapped onto its vocabulary so the
parked-fix, prerequisite and title-overlap scans all still run.

**Score:** 4

#### What makes this deploy extra special

A consumer repo gets a way to put several machines on one backlog without the two failures that shape
costs: building the same issue twice, and a session resuming somebody else's branch because the claim
could not name a machine. Before this, the only shared claim was an assignee -- which two checkouts
under one GitHub account write identically, and which refuses an issue carrying the name of the
colleague who owns the ticket, measured at three of fourteen open issues on one board. The skill also
carries the stop that a parallel round most wants to skip: where the result has to be judged by eye it
parks the branch and takes the next issue rather than opening a pull request on work nobody has seen.

**Score:** 3

#### Pull Request

Sweep an issue backlog with several machines, claiming by tag

Plugins: dkj-policy

[PR #2257](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2257)

---

### DEPLOY: docs/2247-foreign-text-registry-sweep · 20260921-224745

The registry of every console this workflow prints foreign text to -- in
[`new-branch`'s skill page](../plugins/dkj-policy/skills/new-branch/SKILL.md) -- goes from **seven
entries to thirteen**, after the first sweep anybody ran on purpose. #2247 reported one missing site and
suggested a sweep might be the right repair; it was. Entry 8 is `adopt-ci-floor.ps1`, the reported one.
Entry 9 is the find that mattered: `check-report-lib.ps1`'s `Format-SafeToken` family is a **fourth
hand-typed strip mechanism**, a `\p{C}` pattern with its own three-issue lineage and thirteen caller
files across `scripts/lint/`, `scripts/sync/`, `scripts/task/` and `scripts/maintenance/`, and it had
been invisible for as long as the list existed. Entries 10 to 13 are a branch document's own prose
quoted back at it, GitHub's required-check names, `check-fanout`'s shrinkage report, and
`check-consumer-siblings.ps1`. Entries 1 and 4 are edited rather than duplicated, per the page's own
rule that a new caller inside a listed site is an edit to that entry: `park-cycle.ps1` relays entry 1's
value and prints entry 4's, `tidy-machine.ps1` prints entry 4's, and entry 4 had a value it never named
at all -- `sync-main.ps1`'s raw `$rel`.

**#2247's own premise was false, and the page now says so.** It asserted the site it reported was fully
guarded and that "nothing is exploitable today"; reading that site instead of the report about it found
two raw, uncapped values beside the guarded ones -- one of them sharing a line with a value #2247 had
checked and called safe. The repair for those is **#2248**, deliberately not on this branch: this one
makes the list true, not the scripts safe. The closing overclaim -- that a reader "now has the list" --
is retired for the same reason the sentence before it was: a reader has, at most, every place found so
far. Growing three to seven incidentally and seven to thirteen in one deliberate pass argues the
technique works, not that it is exhausted.

**Score:** 3

#### What makes this deploy extra special

N/A -- a maintenance registry inside a skill page this workflow ships. Its reader is whoever audits
where this workflow prints somebody else's characters, which is this repo's own kind of reader; a
subscriber of a service notices nothing about it. The two unguarded sites it now names are real, but
what a consumer would notice is their repair, and that is #2248 rather than this change.

**Score:** N/A

#### Pull Request

The foreign-text print registry goes from seven sites to thirteen, after the first deliberate sweep

Plugins: dkj-policy

[PR #2256](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2256)

---

### DEPLOY: feat/2236-adoption-gap-reported · 20260921-221327

Every `adopt-*` command is safe to re-run and correctly finds nothing to do, and that is exactly why
nothing told an already-adopted repo when one of them GAINED a file. The script-contract session check now
reads which files each adoption part places and forwards what is missing as a non-counting `[UNADOPTED]`
line, wording a part that has *some* of its files ("has been run here and has since GAINED a file", naming
when that file joined) apart from one that has none. Two guards keep it from being a nag -- silent in a repo
with no workflow folder, and in the repo that publishes this workflow -- and a repo that decided against a
part names it in `Get-DeclinedAdoptions` to answer the line for good.

**Score:** 3

#### What makes this deploy extra special

A consumer learns at their next session start that part of their CI floor is missing, which until now they
could learn only by running the command they did not know existed. Measured in one: `xoxowildhearts` had
Part 1's entry gate and none of Part 3's three runners, so neither its fold nor its resolves verification
could survive a merge its shipping session never observed, with every check green throughout. The register's
own detector could not see it, being any-or-none rather than per-command.

**Score:** 4

#### Pull Request

A consumer's session reports which adopt-* steps its tree is missing

Plugins: dkj-policy

[PR #2254](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2254)

---

### DEPLOY: fix/2233-gate-lane-stdin · 20260921-203304

A test-gate lane is no longer handed the gate's own stdin. `Invoke-TestSuiteGate` redirected stdout and
stderr and said nothing about stdin, so every suite inherited the gate's handle and passed it on to
whatever it spawned. Where the gate itself runs under a pipe nobody closes, a child that reads stdin to
end-of-stream blocked forever -- zero CPU, no output, no error -- and #1941's per-suite deadline then
converted that into a 30-minute red naming a timeout rather than a defect. Each lane now gets an empty
file instead, at both spawn sites, so the read returns at once. Measured on the three suites that
wedged: all three now pass through the gate under exactly the condition that wedged them, the slowest
in 70s against a 30-minute refusal.

**Score:** 4

#### What makes this deploy extra special

Anyone running this workflow's own gate gets it: `open-pr` could not open a pull request at all on a
machine in this state, and the half-hour it took to refuse is the shape that gets a gate bypassed by
habit rather than by decision. The repair is at the pool, so it covers every suite at once rather than
the three that happened to be caught.

**Score:** 3

#### Pull Request

A test-gate lane no longer hands its suite the gate's own stdin

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2251](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2251)

---

### DEPLOY: fix/2239-teardown-suite-pool-flake · 20260921-200553

`teardown.tests.ps1` no longer fails the gate when a child `powershell.exe` dies without a word while the
suite is building a fixture. It builds the fixture again once, prints a `[NOTE]` line so the occurrence is
counted rather than invisible, and lets anything the child actually said stand as the failure.

The cause of the child dying is not established: the failure was seen once in two pool runs at 22 lanes
and was not reproduced. If a `[NOTE]` line ever shows up in a gate log, that is the next data point, and
with it the n=5 this repo asks for before a moving verdict is trusted.

**Score:** 1 -- prevents a failure that has already happened once: a red gate on a tree nobody touched,
found while measuring the gate for #2232.

#### What makes this deploy extra special

Nothing here reaches a consumer; it is one test suite. What it adds for the next reader is the argument for
why retrying is safe here and would not be for the general case: the retry keys on a state the code under
test cannot produce (a silent non-zero exit), so it cannot hide a real defect.

**Score:** N/A -- this reaches nobody outside this repo; the suite is not plugin payload.

#### Pull Request

teardown.tests.ps1 builds its fixture again once when the bootstrap child dies silent

[PR #2244](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2244)

---

### DEPLOY: docs/2238-handover-client-state-reset · 20260921-191234

`PREVIEW-portable.md` now states the second question a preview handover owes its reader: pinning the
control settles which THEME renders and settles nothing about what the browser REMEMBERS. Preview and
live share an origin, so they share `localStorage`, `sessionStorage`, IndexedDB and a feature's own
cookie -- and a reviewer carrying a stored value sees the change in both tabs, which reads as the change
being absent. Where the visible effect depends on persisted client state the handover now owes a reset
step, in the *how to see the change* block, and the reset is a private window -- with the devtools
fallback named as the weaker reset it is, since clearing one key leaves the same origin's cookies and
IndexedDB standing. The first consequence bullet under *What the control URL is* is scoped to say what
it does and does not settle, because following it as written is what produced the undiscriminating
handover this came from. `README.md`'s chapter-three paragraph carries the rule too, so a reader
working from the index learns the reset step exists.

**Score:** 3

#### What makes this deploy extra special

N/A -- a portable page this plugin ships to BWJ's stores. The reader is whoever builds a preview
handover there, which is this repo's own kind of reader one hop out, and no subscriber of a service
notices a rule about how a review link is assembled.

**Score:** N/A

#### Pull Request

A handover owes a client-state reset when the visible effect depends on persisted browser state

Plugins: dkj-policy-bwj

[PR #2246](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2246)

---

### DEPLOY: fix/2224-stale-clone-import-remediation · 20260921-182435

`check-roster-sync`'s dead-import finding used to close with `Repair the path`, and named only causes
that imply the roster path is wrong. For a `~/`-relative import that is the wrong instruction: such a
path resolves into the machine-wide marketplace clone, which tracks the trunk and advances on
`claude plugin marketplace update` alone -- not on a release, a push or a `plugin update`. So the
likeliest cause is a stale clone, and editing the path reverts one that is already correct. Measured
here on September 20, 2026: the persona rename of #2128 had landed on the trunk while this machine's
clone sat 510 commits back, the orchestrator's body was silently absent from every session, and the
finding pointed at the one file that carries the rename. The finding now splits by import class --
the clone class leads with the refresh and makes the edit conditional on it failing, the in-tree class
is unchanged because a refresh cannot help it.

**Score:** 3

#### What makes this deploy extra special

The check ships to every consumer, and the rename it misdiagnoses is live right now: `INSTALL.md`
walks consumers through exactly this import-line migration, so a consumer whose clone has not caught
up meets this finding at session start and is told to undo the edit the guide just asked them to make.
Following it costs them the orchestrator in both directions -- the old path is dead after the refresh,
the new one before it -- with nothing reporting either state. The repair is wording only: no gate
changes, no behaviour beyond which sentence the reader acts on.

**Score:** 3

#### Pull Request

A dead marketplace import no longer tells you to edit the path when the clone is simply stale

Plugins: dkj-subagents-alpha

[PR #2245](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2245)

---

### DEPLOY: docs/2232-gate-wall-clock · 20260921-150342

The gate's wall clock was re-measured at 121 suites, because #2232 reported ~90 minutes and asked whether
that was #1703's degraded band returning or simply a pool 41% larger than the last table. It is neither.
On an idle 24-core workstation the whole pool runs in **421.2s at 22 lanes**, and the makespan sits at
**101.4% of `max(longest file, work÷lanes)`** — the scheduler is at its floor, exactly the regime the
September 9 reading found at 16 lanes, and the pool simply *is*
`check-plugin-integrity-docs.tests.ps1` (415.5s). The 41% more suites are absorbed by lanes that were
idle behind that file anyway: work ÷ lanes is 268.4s, 147s below it. The ~90 minutes was
[#2233](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2233) — three suites blocking forever
on a redirected-but-never-closed stdin and released only by the 1,800s per-suite bound. The section also
records why #2232's own utilisation threshold reads this pool backwards, and that a gate figure quoted
without naming how the run was started is unreadable.

**Score:** 3

#### What makes this deploy extra special

Nothing here changes what a consumer runs — it is one section in a repo lens. What it buys the next
reader is the two things this measurement cost to learn. First, that a **utilisation number has a ceiling
set by the longest file**: this pool could not have exceeded 64.6% however perfect the scheduler, it
scored 63.7%, and the threshold #2232 proposed in good faith would have sent the next session looking for
growth instead of at the one file that sets the whole wall clock. Second, that **a wall clock measured on
a workstation carries that session's stdin**, invisibly — the same tree, minutes apart, reports 421s or
half an hour depending on a handle nobody names, and the gate's output does not mention it. Both are the
kind of thing that is obvious once written down and expensive every time it is not.

**Score:** N/A — this reaches nobody outside this repo. It is a lens section, not plugin payload, and no
consumer reads it.

#### Pull Request

The gate at 121 suites, measured: 7 minutes and critical-path-bound on one file

[PR #2241](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2241)

---

### DEPLOY: feat/2228-shopify-live-preflight · 20260921-135351

`dkj-subagents-shopify` had nothing standing between a merged trunk and a live theme push. Everything
it shipped sat before the merge (`push-preview`, `sync-main`) or after the push (`backup-live-theme`,
`archive-theme`, `sweep-preview-themes`), so the one moment in the cycle where a mistake is visible to
paying customers was assembled by hand, per release, from prose. `live-preflight.ps1` is that step: it
verifies the trunk, runs the repo's own gates, derives the push list from the range instead of from the
changelog, reports what the pending entries owe, checks the live theme by id *and* by role, hands the
list to the drift check **as an array**, takes one verified backup as the rollback point, prints the
push command, and previews the aftercare. It verifies and reports -- it never runs `shopify theme push`
and never writes the authorisation marker, both by construction rather than by discipline. The eight
theme directories stopped being a literal in `sync-main.ps1` and became one definition both scripts
read. `backup-live-theme.ps1` gained no behaviour and lost a sentence: its header stated one caller's
choice as a property of the script, and now states what it guarantees.

**Score:** 2

#### What makes this deploy extra special

A Shopify store repo gets the step its release day was missing, and notices it the next time it ships.
Two hand-assembly failures that had already cost that store something are now closed in code rather
than in prose: deriving the push list, where 61 changed files held 11 that exist on a theme and the
other 50 do not -- their own `CLAUDE.md` warns about it in words, which is what a rule looks like when
nothing enforces it -- and passing that list on, where a `powershell -File` call flattened it into one
string, snapshotted zero files, printed a green "safe to push", and left a release with no rollback
artefact and nothing saying so. The backup they already had now runs *before* the push where they want
it there, which turns it from a baseline of what shipped into a rollback point -- worth having because
a Shopify push is per file, has no locking, and can arrive partially, so a backup taken afterwards has
captured the broken state. Nothing about the backup's own mechanism moved. It arrives on the next
plugin update; a repo that answers no new seam still gets every step except the drift check, which
says out loud that it could not run rather than passing.

**Score:** 4

#### Pull Request

A live-push preflight for dkj-subagents-shopify

Plugins: dkj-subagents-shopify

[PR #2235](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2235)

---

### DEPLOY: fix/2217-pretooluse-guards-fail-open · 20260921-092704

Two guards this workflow ships -- the live-theme guard and the working-copy guard -- used to fail open:
when PowerShell could not start (out of memory, a failed type initializer), no line of the guard ran and
Claude Code let the command through. Their `hooks.json` entries are now a small bash wrapper that turns
that failure into a refusal, but only for a call the guard exists for: a command naming a Shopify theme,
or a dispatched subagent running git. Every other call behaves exactly as before, so a machine with an
unhealthy PowerShell is not locked out. The wrapper assumes the hook shell is bash, the documented
default wherever Git Bash is installed; a machine without it runs the hook in PowerShell, where the
wrapper does not parse, so the guard does not run there.

**Score:** 3

#### What makes this deploy extra special

A store or a repo running the Shopify or policy plugin is now protected in the condition where its
machine is least healthy: a `shopify theme publish` or a live push no longer goes through just because
PowerShell ran out of memory at that moment, and a subagent's `git checkout` no longer reaches a
checkout holding uncommitted work. Nobody notices this until the failure it prevents would have
happened -- measured on smartwatchbanden, four start failures on one guard in the transcripts. The one
subscriber who does notice something is a machine without Git Bash, whose guard stops running; that is a
cost of the fix, and it lands only when the plugins are next updated.

**Score:** 1

#### Pull Request

Both PreToolUse guards now fail closed when PowerShell cannot start, for the calls they exist for

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2223](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2223)

---

### DEPLOY: feat/clean-release-title · 20260921-065510

A release is named `Release Version vX.Y.Z`, derived from its tag, and nothing composes that name any
more. `cut-release.ps1` printed a `--title "<tag> - <short title>"` placeholder, so what a release was
CALLED came from whatever sentence the person cutting it invented at that moment -- an authoring
decision taken at the most expensive step of the procedure, by whoever happened to be running it, and
the one artefact in this workflow that no gate could check. Two cutters produced two conventions.

**The short description is not removed, which is the distinction the whole change turns on.** It keeps
its own row -- the first line of the generated Release body, and the last column of the release
overview -- and `-Title` still feeds both. That parameter's own help has read *"short description of the
release as a whole"* since it existed, so the parameter was never the thing that claimed to be a title;
one printed line was. Nothing about the release documents changes.

Two neighbouring repairs came with it rather than being swept in: the parameter help now says outright
that it is not the name, and the milestone section offered `Release version X.Y.Z` as a *legitimate
fallback title* for a release too broad to summarise -- true before this change and misleading after it,
since that is now simply the name. It says to omit `-Title` instead, which is the same advice with the
stale half removed.

**Score:** 3

#### What makes this deploy extra special

A consumer cutting their next release sees a different command printed, and their releases stop being
named after a sentence somebody wrote on the spot. Nothing is asked of them and nothing is refused:
the line is printed for a person to paste, so a repo that prefers its own convention types its own
`--title` exactly as before -- this changes what the workflow RECOMMENDS, not what it permits.

Their already-published releases are untouched, and renaming one is a `gh release edit` they may run or
skip; the release documents, the overview table and the description row are all unchanged, so there is
no migration and nothing to re-adopt.

**Score:** 2

#### Pull Request

The release name is always Release Version vX.Y.Z

Plugins: dkj-policy

[PR #2229](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2229)

---

