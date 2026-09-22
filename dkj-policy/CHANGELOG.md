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

**11 / 17 minor entries** <!-- pending-tally -->

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

