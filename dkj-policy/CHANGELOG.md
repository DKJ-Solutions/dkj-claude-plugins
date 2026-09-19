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
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

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

**6 / 14 minor entries** <!-- pending-tally -->

### DEPLOY: docs/2127-inbound-prio-carve-out · 20260919-093551

The priority-label rule now says whose rule it is. *"Every issue filed here carries a priority
label"* read as a property of the tracker, which bound a consumer's session filing inbound to a
label set it has no reason to know -- and the portable layer had already decided the opposite,
prescribing only the reach label to a consumer. The rule now binds the **filer**, an `inbound` issue
is outside it by design, and the rung is set here at triage. The `triage-inbound` skill carries that
step beside its six verification checks; Derek's lens carries the measurement, including why a
default rung in the issue template was declined rather than left undone. The always-on statement was
rewritten byte-neutral, so the correction costs no session a single byte.

**Score:** 2

#### What makes this deploy extra special

N/A -- this is a governance clarification in this repo's own lenses and one of its skills. Nothing a
consumer installs changes: the portable layer already said what this now says, which is the whole
argument for the carve-out.

**Score:** N/A

#### Pull Request

The priority-label rule states its scope: it binds sessions working in this repo, not a consumer filing inbound

[PR #2129](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2129)

---

### DEPLOY: feat/2120-resolves-exempt-matchers · 20260918-180452

`open-pr`'s resolves gate can now be TOLD which issues a merge must not close. A repo answers the optional
`Get-ResolvesExemptMatchers` seam in its own `scripts/repo-config.ps1` with the text that marks such an
issue -- a ticket-mirror marker, a task link -- and the gate fetches the body of every issue the merge would
close, refuses `-Resolves` on a match, and names `-NoResolves` as the way through. Unstated, which is every
repo's default and this one's, it judges nothing and makes no extra `gh` call: the seam is read before any
lookup, so a repo with no second tracker pays nothing for a rule that is not theirs. The set judged is what
the body will say at the merge -- `-Resolves` plus any closing keyword already published on the open PR --
because `-NoResolves` does not strip a keyword the body already carries, and a gate reading the flag alone
would be skipped by the very flag its own refusal recommends.

**Score:** 3

#### What makes this deploy extra special

**The rule this enforces was already written down, and that is exactly the problem it closes.**
`dkj-policy-bwj`'s `WORKFLOW-portable.md` has carried the paste-first close order since inbound #2049, naming
the `dkj-policy` interaction explicitly -- and nothing read it. Inbound #2120 measured what that costs: an
issue carrying an `asana-task:` marker shipped with `-Resolves`, the merge closed it, and the mirror posted
its fallback handover afterwards, carrying the literal `[ADD LINK]` placeholder it writes because CI cannot
know where the result is visible. The rule was followed correctly on other issues in the same period; the
difference was whether the session remembered.

**The report proposed sharing the mirror's own matchers, and that half is deliberately not built.** Those
three matchers live in `dkj-policy-bwj`'s `asana-mirror.ps1`, which ships standalone into a consumer's
`.github/`; `dkj-policy` cannot reference it without inverting the layering. So the matchers are data the
consuming repo states, and `adopt-dkj-policy-bwj` proposes exactly the shapes `WORKFLOW-portable.md` already
defines -- one definition per layer rather than a third. It proposes two of the three: the header-row
matcher is an anchored read of one table row, and the sole-URL matcher already covers that row's link. The
asymmetry is the right direction to be wrong in -- this gate refuses a close, so reaching slightly wider
stops a merge that wanted `-NoResolves` anyway, while the mirror's narrower matcher decides which task to
write to and must not guess.

**A matcher is data and never a predicate**, which is the other thing the report left open. A scriptblock
from `repo-config.ps1` would be the shorter seam and it would put repo-authored code inside the one gate
that decides whether a PR may be opened -- a throw in it takes the gate with it. Data can be validated,
printed back inside the refusal, and asserted without a repo; so an uncompilable pattern is reported and
skipped while the rest of the list goes on working, which is the one failure a repo cannot otherwise see.

**Two review findings are worth carrying, and the first is the same argument arriving by another road.** The
design refuses to run repo-authored CODE inside this gate on the ground that a throw in it would take the
gate down -- and the security review pointed out that an unbounded regex match is that failure by another
mechanism: a consumer's own pattern, a body crafted against it by anybody who can open an issue, and
`open-pr` hangs for whoever resolves that issue. So every match is bounded at two seconds and a timed-out
one is reported as unjudged rather than read as a pass. The reasoning was already written down; what it
had not been applied to was the one input the gate does not own.

**The second is a seam answer this repo does not have and a consumer plausibly does.** A repo saying "not
configured" with `return $null` -- behind a guard clause, say -- was read as ONE malformed matcher rather
than none, because `@($null)` is a one-element array holding nothing: the gate stayed correctly silent, and
printed a rejection for an entry nobody wrote on every PR open. The call site now passes the seam's answer
unwrapped, which is also what lets a repo state a single matcher without wrapping it, and both shapes are
asserted.

For a consuming repo this lands as a gate that is silent until they answer it. The two BWJ store repos get
it the moment they add the proposed function; every other consumer sees nothing change, which is the point.
`BWJ-Development/smartwatchbanden`'s repo-side `PreToolUse` hook was written as a temporary bridge citing
this issue and can come out once this reaches them.

**Score:** 3

#### Pull Request

The resolves gate can be told which issues must not be auto-closed

Plugins: dkj-policy, dkj-policy-bwj

[PR #2126](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2126)

---

### DEPLOY: fix/2121-gate-lane-count-memory · 20260918-170256

The test gate's automatic lane count is the lower of two reservations now, not just one: the machine's
cores minus two, and its free physical memory divided by a measured 512 MB per lane. Until now it
reasoned about cores alone, while what a lane actually exhausts is memory -- every lane is a
`powershell` child that spawns children of its own. On the machine that filed #2121 that default was 30
lanes, and at 30 lanes the gate reported 44 of 116 suites red, then 43 on a rerun of the same tree,
naming different suites each time; a 6-lane run of that tree found the two real failures. A verdict a
session cannot trust is worse than a slow one, and the cost of the other direction is small: 4 lanes
finish the same suites 24% slower than 16 and they finish.

A run whose lanes were set by memory now says so, with the free figure, the per-lane budget and the
count the cores would have allowed. That is the half of the report that was not about the number: the
`-MaxParallel` knob has existed since #1443 and worked, and nothing anywhere pointed a session at it or
suggested the lane count was why a third of the pool was red.

Nothing changes for CI, which passes its own lane count explicitly, or for any caller that passes
`-MaxParallel`. A machine whose memory query cannot be answered falls back to exactly the core formula
it had before.

**Score:** 4

#### What makes this deploy extra special

N/A -- this is the gate a developer of this repo and its consumers runs before a push. No subscriber of
anything this repo ships meets it.

**Score:** N/A

#### Pull Request

The test gate's automatic lane count accounts for memory as well as cores

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2125](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2125)

---

### DEPLOY: fix/2115-repo-root-decoding · 20260918-155721

Every repo-root read in this workflow now asks a question a console code page cannot corrupt. `git
rev-parse --show-toplevel` returns a RAW path, and Windows PowerShell 5.1 decodes a native child's
stdout with `[Console]::OutputEncoding` -- so in a checkout under an accented directory name it
returned a well-formed string that matched nothing, and what followed was a `Test-Path` miss reported
as *"cannot determine the repo root"*, or a silent skip in the branch of a session hook with no
`CLAUDE_PROJECT_DIR` to fall back on. The read is now `--is-inside-work-tree --show-cdup`, whose output
is a run of `../` segments and no filename at all, joined onto a base PowerShell already holds
correctly; the second flag is not decoration, because `--show-cdup` alone exits 0 inside `.git` where
`--show-toplevel` exits 128. One definition in `scripts/lib/repo-root-lib.ps1`, mirrored into the three
plugins that carry a reader, 18 call sites converted plus the two that may not reach a lib, and a
repo-wide guard that refuses the flag anywhere in the tree.

**Score:** 3

#### What makes this deploy extra special

It is **latent here and live for a consumer**, which is the shape that accumulates. This checkout's
path is ASCII, so nothing here has ever failed on it; a consumer whose checkout sits under an accented
directory name is the ordinary case on a non-English Windows box -- `C:\Users\<name>\Bureaublad\...`,
a company folder with a diacritic -- and the shared libs and lint checks this workflow mirrors into
their plugin cache are exactly the files that would fail there.

The lesson worth keeping is about the **sweep**, not the flag. #2110's sweep concluded *"every other
reader is already correct"* while about twenty call sites were reading it, because its predicate --
*"neither forces `core.quotePath=true` nor passes `-Utf8`"* -- silently assumed its own repair was
available. `core.quotePath` governs the path output of the porcelain that consults it, and `rev-parse`
is not such a porcelain: under the forced flag `ls-files` returns `"café.md"` ASCII-quoted while
`rev-parse --show-toplevel` returns raw UTF-8. A predicate that names a repair reads as *"these sites
are fine"* where it means *"these sites do not use a mechanism that could not have helped them"*.

**Score:** 4

#### Pull Request

Repo-root reads ask a question no code page can corrupt

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2123](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2123)

---

### DEPLOY: feat/2103-progress-bar-reaches-consumers · 20260918-153030

The background progress bar reaches consumers. #2101 built it in this repo and deliberately mirrored
none of it: `native-capture-lib.ps1` reached `run-progress-lib.ps1` through a **guarded** dot-source,
so in a consumer the `Test-Path` failed and the gate behaved exactly as it had. That was a parked
state, not a destination. Registering the lib as a shared pair is what turns the guard's false arm
into its true one -- in `dkj-policy` and in `dkj-subagents-shopify`, which carries the second mirror of
the file that reaches for it -- without editing `native-capture-lib.ps1` again. The statusline that
draws the bar is mirrored beside it.

The third part is new machinery, because `statusLine` is a **settings** key: `plugin.json` has no such
key, a plugin-root `settings.json` supports only `agent` and `subagentStatusLine`, and
`${CLAUDE_PLUGIN_ROOT}` is not expanded there. Nothing a plugin ships can place it, so
`adopt-statusline.ps1` does -- Part 5 of `adopt-dkj-policy`, dry-run by default like its siblings.

**What it places is a shim rather than a path, and that is the decision the part is built around.**
The plugin cache is keyed by version, so writing today's cache path into a consumer's settings would
leave them rendering that payload after every future update: still working, still stale, and reported
by nothing. Copying the two scripts into the consumer trades it for two live copies drifting each
release with no lint over them. The shim is one file that never changes, resolving the installed
payload at render time -- so the settings path cannot go stale and the logic stays where a release can
reach it. An existing `statusLine` is never replaced: there is one per settings file, so the run leaves
it alone and prints the block.

Where several install records name this repo -- which a marketplace rename produces, and this repo
renamed its own on September 10, 2026 -- the shim takes the most recently updated rather than whichever
the file happens to list first. Resolving that tie by enumeration order would have rendered a stale
payload permanently with nothing saying so: the same failure the shim exists to prevent, one layer in.

**Score:** 3

#### What makes this deploy extra special

A subscriber of this workflow gets the progress bar at all, which until now existed only in the repo
that built it. The visible half is a status line that keeps rendering while a backgrounded gate or CI
wait shows nothing anywhere else; the durable half is that the path they adopt cannot be stranded by
the next plugin update. It needs one command -- `adopt-statusline.ps1 -Apply` -- and it takes nothing
away from a repo that already has a status line of its own.

**Score:** 3

#### Pull Request

The progress bar reaches consumers: run-progress-lib mirrored, show-progress shared, and the statusLine seam in adopt-dkj-policy

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2122](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2122)

---

### DEPLOY: fix/2117-neutral-reopen-comment · 20260918-144639

`asana-mirror`'s reopen comment told the requester the work was being worked on again and to hold off
testing. The workflow knows neither: a reopen means the work was picked up again OR that the ticket
has gone back to the requester, and in the second case both halves are false -- the expensive half
being the one that tells the person who now has to act to sit still. The comment reports the state
change, names both readings without picking one, points at the issue for which applies, and says
plainly that it is not a request to test. Its two docstrings, `asana-mirror.yml`'s dropped-reopen
argument, `WORKFLOW-portable.md` and the plugin README follow it, and the suite pins the new contract
so restoring the old sentence fails.

**Score:** 3

#### What makes this deploy extra special

The report offered a second shape -- let the `needs-info` label choose the sentence -- and it is
declined on the measurement rather than on taste. No label was set on the three issues the report was
written from; they were simply reopened, so the label-absent branch would have printed the same false
sentence on all three cards. It also contradicts the script's own rule that a label event moves the
card and says nothing. The mechanism for it exists, so this is a decision and not a shortage of seam.

Two review findings are worth carrying, because both are about a tick made in good faith on half a
job. Victor found a second docstring twenty lines above the one that was repaired, still asserting
the retired claim -- the CREATE step had been worded as though the file held one. Edith found the
same concept phrased two ways across the four places that describe it, including the shipped card
text, which read "it may be being worked on again": the cost of splitting one sentence across three
hands, and the reason the copy edit was applied in one.

For a consuming repo this lands as a changed message on a colleague's Asana card, which they read
rather than the issue. It arrives when they re-adopt the template, and it is noticed the next time an
issue is reopened.

**Score:** 3

#### Pull Request

asana-mirror's reopen comment no longer asserts why the issue was reopened

Plugins: dkj-policy-bwj

[PR #2119](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2119)

---

### DEPLOY: fix/2110-git-path-decoding · 20260918-143440

Two git reads whose answer is a PATH no longer depend on the console code page. `fold-changelog-entry`
splits the paths it is about to commit into tracked and untracked with a `git ls-files` whose output it
then COMPARES -- so a mis-decoded name failed that comparison, dropped out of `git commit -- <paths>`,
and the run printed *"git never tracked them ... the fold deleted them from disk all the same"* about a
file it had just deleted. `find-specialist-mentions` built its whole scan set from a bare
`@(git ls-files 2>$null)`: a mis-decoded name keeps its `.md` tail, passes the extension filter and then
cannot be opened, so the file left the mention scan silently -- the one failure a report whose job is
*"do not miss a place"* must not have. Both now force `core.quotePath=true` and decode with
`Convert-GitQuotedPath`, the repair [`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md)
prescribes and #2109 applied one caller over; the second is routed through `Invoke-NativeCapture` as
well, so its exit code is readable instead of swallowed.

The fold's instance is LATENT today, and it is the only one whose safety rests on a constraint in
another file: everything that comparison tests is named after the branch, and `branch-info.ps1` holds a
branch name to ASCII. The code now says so, which it did not before -- and says which path is *not* on
either side of it, since `CHANGELOG.md` enters the commit's pathspec without ever being compared.

**Score:** 2

#### What makes this deploy extra special

N/A -- neither reader reaches a consumer as behaviour. The fold is mirrored into every consumer's
`dkj-policy` cache, but its instance is latent for the reason above, and the mention scan is a
source-repo reporter that never travels.

**Score:** N/A

#### Pull Request

Two more git path readers decode with the console code page

Plugins: dkj-policy

[PR #2118](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2118)

---

### DEPLOY: feat/2104-backgrounded-call-progress · 20260918-131800

The progress bar now covers a backgrounded call this workflow does not own. A `PostToolUse` hook reads
the structured `backgroundTaskId`, finds the shell actually running the command, and publishes a record
attributed to **that** process -- so the existing liveness test shows the bar while the run lives and
removes it within two seconds of the run ending. There is no completion event for a backgrounded shell
and no state to poll; measured, both. `Write-RunProgress` gained `-WriterPid` for it, and existing
producers are untouched.

**Score:** 3

#### What makes this deploy extra special

Three of the issue's own premises changed under measurement, and the one it did not have turned out to
be the decisive one: liveness is the writer's process, so a 400 ms hook could not be the writer at all.
The whole design is the answer to that -- attribute the record to the shell, and the mechanism that
already exists does the rest.

It is also a reminder about what a unit test cannot buy. Every decision here is driven from a payload
string, 38 asserts, all green -- and the first real backgrounded call published nothing, because both
sides of the comparison were fixtures and the shell re-quotes what it is handed.

**Score:** N/A

#### Pull Request

The progress bar covers a backgrounded call this workflow does not own

Plugins: dkj-policy

[PR #2113](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2113)

---

### DEPLOY: fix/2114-unmeasured-capture-not-a-failure · 20260918-130202

`update-plugins.tests.ps1` asserted `exit 0` on eight scenarios while the script it drives is
specified to exit 1 whenever a capture comes back with no measurable exit code -- a state measured at
2.8% per capture, which over a run's ~30 captures is roughly a coin flip. The suite now asserts on the
work done and tolerates that one documented state, counted and reported apart rather than folded into
the pass count. The script is untouched: counting an unmeasured capture as a failure is #2081's stated
decision and it still holds.

**Score:** 2

#### What makes this deploy extra special

The report that produced it was wrong, and the correction is the useful part. It was filed as the script
failing to consult `ExitCodeUnknown`; the script consults it and the counting is argued at the exact
line. What made that misreading easy is worth keeping: the shim was called with the right ids at the
right scopes and the run still exited 1, which reads as a defect and is in fact the specification.

The other half is arithmetic. A per-capture probability is not a per-run one, and 2.8% quoted as a rare
race becomes an even-odds failure once a suite makes thirty captures. The number was in the tree all
along; nobody had multiplied it.

**Score:** N/A

#### Pull Request

The update-plugins suite stops asserting an exit code a documented race owns

[PR #2116](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2116)

---

### DEPLOY: feat/2101-background-progress-bar · 20260918-105021

A progress bar for the runs a session cannot see. A backgrounded `Bash` call streams no stdout to any
visible surface, so the two longest waits in this workflow -- the test gate and `ship-pr`'s CI watch --
now **publish** their progress to a small per-user record, and a new `statusLine` command
(`scripts/task/show-progress.ps1`, at a 2-second refresh) draws it: `[#####-------] 37/84  test gate
(7 running)  +6m12s` while the gate runs, `... ship-pr: CI on PR #2103  +11m48s` while the watch does.
Liveness is the writer's **process** and never the record's age, so a run blocked for twelve minutes
keeps its bar while a run that was killed loses it within seconds. A fraction nobody measured is never
invented: a wait with no counts gets an elapsed readout and deliberately no bar, and there is no ETA
anywhere. Consumers are unaffected -- the dot-source into `native-capture-lib.ps1` is guarded, so that
file stays byte-identical to its two plugin mirrors and the gate behaves there exactly as it did.

**Score:** 4

#### What makes this deploy extra special

N/A -- nothing here reaches a subscriber of this service. The bar is wired into this repo's own
`.claude/settings.json`, and `statusLine` is a settings key rather than a plugin component, so no
consumer receives it from a release; the shared files that changed carry a guarded dot-source and behave
in a consumer exactly as they did before. Shipping it outward is #2103, and that is the change a
subscriber would notice.

**Score:** N/A

#### Pull Request

A progress bar for work the terminal cannot show

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2106](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2106)

---

### DEPLOY: fix/2109-tracked-name-code-page · 20260918-103318

The `[tracked-name]` check now reads git's path list as ASCII on the wire and decodes it itself, so it
fires on the machine where a mangled name is created instead of only in CI after the push.

It read `git ls-files -z` and let Windows PowerShell 5.1 decode the bytes with
`[Console]::OutputEncoding`. The whole subject of the check is a name made of bytes no ordinary code
page has an opinion about -- so on cp850 the U+F03A it exists to catch arrived as three unrelated
characters in no class at all. Measured on the commit that produced the case: the local gate reported
`checked 761 -- 0 finding(s)` and CI, on a console whose code page differs, failed the SAME commit with
the finding. That inverts the guard -- it went blind on the developer machine where such a name is
created and spoke only once the object was in the remote's store forever.

The repair is the one [`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md) already
prescribes for this class: `core.quotePath=true` plus `Convert-GitQuotedPath`, because every candidate
code page agrees below 0x80. Dropping `-z` costs the newline guarantee nothing -- git C-quotes a
control character in every `core.quotePath` setting, so such a path is still one record.

Resolves [#2109](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2109).

A guard that only fires in CI reports damage instead of preventing it. Anyone running the lint gate on
a non-UTF-8 console -- the default on a Dutch or German Windows box -- now gets the answer at the point
where it is still free, and notices it the moment they touch that part.

**Score:** 3

#### What makes this deploy extra special

Internal to this repo's own lint gate. Nothing a subscriber runs or upgrades changes.

**Score:** N/A

#### Pull Request

check 43 reads git's path list through the console code page

[PR #2112](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2112)

---

### DEPLOY: fix/2107-premise-reads-unmeasured-exit · 20260918-101548

A test suite read an exit code that had never been measured as though it were a refusal, so
`ref-print-lib.tests.ps1` went red on a premise -- reporting that git rejects a branch name it
accepts. The reading is now three-state, and an unmeasured capture is reported rather than asserted
on. The same blindness in the opposite direction, where the unreachable half went green on nothing,
is closed by the same helper.

**Score:** 3

#### What makes this deploy extra special

The interesting half is not the red that was visible. Six of the eight premise call sites failed
loudly on an unmeasured capture; the other two passed silently on one, and nothing in the repo would
ever have reported that. A guard asserted as defence in depth had a state in which it proved nothing
and said so to no one.

It is also a defect of reading rather than of mechanism: `ExitCodeUnknown` has existed since `#1931`,
six files already consult it, and this suite simply did not. The repair is to consult the field that
was built for exactly this, not to add anything new.

**Score:** N/A

#### Pull Request

The ref-print premise assert reads an unmeasured exit code as a refusal

[PR #2111](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2111)

---

### DEPLOY: feat/2102-release-gate-rerun · 20260918-095038

The release-notes commit no longer pays for the test gate it cannot use. open-pr.ps1 -GatesOnly
-NoteTreeOnly asks whether every path differing from HEAD sits inside the release-note tree the
third direct-on-main exception already bounds that commit to, and only where that is PROVEN does it
skip the suites -- the lint gate runs either way. On the v5.5.0 cut that second gate leg cost 325s
over one hand-written markdown file: one of the two runs that together are 652s of a 1,166s release, 56%
of it spent on the same 114 suites twice. What the switch leaves standing is the lint half, 27s here
against 249s for the suites; the cut never split its own 325s, so neither figure is credited to it.

The skip is a deduction rather than a favour because the suites have no coverage of that tree to lose.
Moving the whole release tree aside and running all 114 turned four red: one on an existence assert over
a path list, which a cut only satisfies more firmly, and three because they run the lint script over the
live repo as a smoke assert. The suites' entire coverage of a release note IS the lint gate.

It proves rather than filters, which is what makes it survivable: #2102 declined a docs-only path
predicate by name, on the grounds that a wrong matcher is silent. This answers no to an unreadable git,
a repo naming no note tree, a clean tree, one stray path, and a rename dragging a note out of the tree --
so being wrong costs a full gate run rather than a skipped one, and the fallback is byte-for-byte the
un-flagged run.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow gets the switch and the measurement behind it through the plugin, and
their own release-notes commit stops paying for a gate that cannot reach a different verdict there. It
is opt-in and scoped to -GatesOnly, so a consumer who never types it sees no change at all.

**Score:** 2

#### Pull Request

The release-notes gate re-run, measured

Plugins: dkj-policy

[PR #2108](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2108)

---

### DEPLOY: feat/2100-bwj-cycle-extensions · 20260918-081829

`dkj-policy-bwj` now states what installing it does to `dkj-policy`'s cycle, and it is exactly two steps
with nothing before the step list touched. **The last step under `### CREATE` is always
`Is the change visible in the frontend / storefront?`** -- dropped with its reason where nothing renders,
and otherwise a preview theme, a comment on the GitHub issue carrying the steps and every URL, and
`- [x]` only once a **person** confirms they looked. Being last is the enforcement: `dkj-policy`'s own
step-list gate refuses the push and the merge while it is open, so an unconfirmed preview stands between
the work and the PR -- and an agent may never tick it itself, because it can prove a theme exists and
never that somebody looked at it. **And just before the issue closes, the paste-ready block gains its
go-live half**: the next release day, the version that release is on course for, and the live storefront
URL per market, written by the new `build-golive-block.ps1` behind the `golive-block` skill.

Neither half became a fifth chapter. Each landed in the chapter whose subject it already is -- previews,
and ticket handling -- so no chapter count, README table or structure assert moved; the plugin README
carries an index instead, which is the one thing neither chapter answers on its own. `PREVIEW-portable.md`
also loses half of a "what this page does not decide" bullet that stopped being true: it disclaimed the
trigger as well as the judgement, which left the trigger to memory.

Three things the mechanism deliberately will not do, all measured as the expensive direction elsewhere in
this workflow. It **never writes `[ADD LINK]`** -- that placeholder is CI's, which cannot know the link,
and a session can, so a link it was not given is a sentence it does not write. It **never promises**:
*"Planned to go live"*, because a tier-1 entry landing on the Friday turns a predicted patch into a minor,
and this block is the one surface a colleague quotes back. And it **guesses nothing** -- no `v*` tag or an
unreadable pending tally means no version in the sentence, and a repo with no declared markets gets no URL
list. The version is read off the tally the fold already writes rather than re-derived, because the tier
parser lives in `dkj-policy`'s libs and this plugin's scripts may not reach a second plugin's folder.

**Score:** 3

#### What makes this deploy extra special

For the two BWJ store repos this changes the working day: every branch now ends its CREATE list with a
question that holds the PR until a person has actually looked at the preview, and every ticket a colleague
filed now comes back with a date, a version and a live link instead of only *"it is done"*. Both are
things they had to remember before, and the first is now held by a gate rather than by memory. The source
repo gets the second half only, and there the URL list is simply empty -- it declares no markets.

**Score:** 4

#### Pull Request

The two cycle steps dkj-policy-bwj adds: the storefront-visibility step under CREATE, and the go-live half of the paste-ready block

Plugins: dkj-policy-bwj

[PR #2105](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2105)

---

