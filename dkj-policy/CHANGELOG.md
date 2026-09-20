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

**22 / 44 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2180-entry-shape-per-branch-exclusion · 20260920-121300

Check 20 of the plugin-integrity gate now exempts a branch's own development document by the pattern
that names it, instead of by the shared filename it carried before September 3, 2026. The exclusion had
been built from a branch-less `Get-BranchFilePaths`, which answers the retired `dkj-policy/development.md`
-- so the per-branch rename silently undid it, the third site of that rename to be found this way. The
legacy names stay in the list beside the predicate, so a branch opened before the rename is still exempt.
The failure this removes is noise rather than silence, which is the opposite of the two sibling checks:
a branch document quoting a section count while explaining the entry format would have been reported as
stale prose and failed the gate.

**Score:** 2

#### What makes this deploy extra special

N/A -- a lint-gate exclusion inside this repo's own tooling. A consumer meets check 20 only through the
gate this repo runs on itself; nothing in their tree or their workflow changes.

**Score:** N/A

#### Pull Request

check 20 exempts the per-branch development document by pattern, not by its retired shared name

[PR #2195](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2195)

---

### DEPLOY: feat/2186-baseline-into-specialists-seam · 20260920-120053

`always-on-baseline.json` moves out of the workflow folder and into `.claude/specialists/`. The
workflow folder is where prose a person writes and reviews lives; this is the one file in it nobody
may hand-edit, and three of the four documents it measures are already in the seam.

Nothing happens to an existing consumer's baseline on a plugin update, deliberately:
`Get-AlwaysOnBaselinePath` now prefers whichever file is actually there, seam first and the workflow
folder second, so an un-migrated repo keeps reading and writing the copy it has and no second
baseline appears beside it. Migrating is one `git mv`, documented in `INSTALL.md` -- and it has to be
`git mv`, because a regenerated baseline looks identical and quietly resets the low-water mark.

A consumer notices nothing unless they go looking: the gate keeps reading their existing file, and
the migration is optional and one command. What it buys is that the folder a person reviews stops
holding a file no person may edit.

**Score:** 2

#### What makes this deploy extra special

The interesting half is what was NOT done. A hard path switch would have passed every gate and broken
nothing loudly, because a missing baseline is a first run and a first run never refuses -- so every
consumer's ratchet would have reset to that day's figure, silently, with the old file orphaned beside
it. For the one file whose entire value is a number carried forward, the silent arm is the expensive
one, and the fallback read exists to close it.

**Score:** 2

#### Pull Request

Move always-on-baseline.json into the specialists seam

Plugins: dkj-policy

[PR #2193](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2193)

---

### DEPLOY: feat/2168-written-name-guard · 20260920-114559

A rename step that forgets its row flip is refused now instead of shipping green.
`Get-SpecialistFileShapes` decides, per specialist kind, which filename spelling is **written** and
which are merely **read**, and the #2128 rename series moves one kind per step -- the files on disk
and that kind's `Current` row, two halves nothing paired. `AlsoRead` keeps every reader resolving
both, so a step that moved the files and left the row behind passed the lint gate, every suite and CI
(measured on #2165) while every writer went on composing the retired name into a fresh consumer. Two
of the four steps shipped exactly that way -- the Subagent row (#2131, found at the merge) and the
Lens row (#2133, found eight days later and repaired in #2167). Step F (#2135) closed while this branch
was open, correctly pairing both halves in one commit, so the round is done and the guard is for the
next one.

Check **3d** in `check-plugin-integrity.ps1` holds each kind's `Current` row against the names
actually on disk: 87 files today, being 26 subagent defs, 27 manuals, 4 personas and 30 lenses, and
it is born green. It refuses **both** half-states, because files moved without the row and a row
flipped without the files are one finding read from either side -- and it names which it found, since
every file of a kind on the other spelling is a row that did not travel while some of them is a move
that stopped half way, and the two have different repairs. A name matching NEITHER spelling is passed
over, so checks 3b, 3c and 6 keep sole ownership of it and no file gets two owners.

It reaches this tree only, and `Get-SpecialistFileShapes`' docstring says so where it used to say the
guard did not exist yet: a consumer meets a rename through a plugin update rather than by choosing
to, so their files sitting on the previous spelling is the dual-read layer doing its job. No row may
be pruned because a gate now watches it.

**Score:** 3

#### What makes this deploy extra special

N/A -- the check lives in `scripts/lint/check-plugin-integrity.ps1`, this repo's own gate: not in the
shared-scripts registry, not carried by any plugin, and not one of the runners `adopt-dkj-policy`
scaffolds into a consumer's CI. No subscriber of this service receives it, which is also why the
`minor` label came off #2168.

**Score:** N/A

#### Pull Request

a guard holds each specialist kind's written spelling against the names on disk

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2191](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2191)

---

### DEPLOY: docs/closeout-checks-live-subagents · 20260920-112936

The orchestrator now checks whether its own subagents are still alive before it says the session can be
cleared. A delegated agent announces its **report**, and a report is not a finish -- it can hand back
while work it forked is still running -- so the persona body says to read the agent list rather than
infer it from the last message received: a completion notice is the signal, a hand-back is not.

**It is deliberately not a rule about waiting.** The whose-clock rule is untouched, and an orchestrator
that starts sitting through its own subagents' background work has traded a wrong receipt for a wasted
session. What changes is the sentence, not the schedule: name the agent that is still running and what
its death would cost, and let the requester decide.

The measured instance behind it -- six agents on one assignment, five of them done and reporting alike,
the sixth reporting identically with 37 minutes still to run -- is in Chris's manual, which is read on
demand. That split is this repo's own convention and the budget gate's own instruction: the decision
belongs on the always-on path, the evidence for it does not.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-subagents-alpha` gets this on its next release, and it lands on the one line a
requester acts on without re-checking. The failure it removes is cheap almost every time -- a
backgrounded review dies with the harness and usually had nothing to say -- which is exactly why it
survives: a receipt that is wrong for free is a receipt nobody corrects. Here it was caught by the
requester rather than by the session.

**Score:** 2

#### Pull Request

The close-out checks whether its own subagents are still alive before it says cleared

Plugins: dkj-subagents-alpha

[PR #2190](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2190)

---

### DEPLOY: docs/2182-2185-lens-heading-and-ci-job · 20260920-111515

Two accuracy repairs in the lenses the #2179 migration touched, neither of which any gate can see.
Sylvester's lens shipped a duplicated `###` heading with an empty section behind it; Derek's lens sent
a session debugging a red check to a job that runs no PowerShell and never touches the repo. The second
is the one that cost something: it is the passage a session reads to understand why a merge is blocked,
and it named the summary job where it should have named the leg. Check 4 of the lint gate validates
anchor existence, not heading structure, and nothing at all reads prose against `ci.yml`, so both were
green on `main`.

**Score:** 2

#### What makes this deploy extra special

A repo lens is this repo's own file and travels in no plugin payload, so nothing here reaches a
consumer.

**Score:** N/A

#### Pull Request

Two accuracy repairs in the lenses the #2179 migration touched

[PR #2189](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2189)

---

### DEPLOY: docs/2179-folder-docs-into-lenses · 20260920-104941

`dkj-policy/` carries no prose pages any more. This repo's own `CONTRIBUTING.md` (1,132 lines) and
`README.md` (167) are gone, and the ~1,300 lines of measured answers they held now sit in the lens of
the specialist who owns each: the branch-document mechanics, the pull-request gates and the
seam-answer table with Sylvester; the issue layer, the claim measurements and the merge step with
Derek; the fold, the cut and the live-stage no-op with Rendall; keeping a checkout's plugins current in
the specialists handbook; and the pages' own history, plus the forwarding address to all four, with
Tessa. This is phase B of #2171 -- phase A is the plugin no longer scaffolding either page into a
consumer -- and it exists because *"there is only one CONTRIBUTING"* was false in the very repo that
ships the sentence.

Nothing was summarised away: the measurements keep their issue numbers and their dates, and what was
left behind is the half that only restated `CONTRIBUTING-portable.md`, which is the duplication #2171
retired. What the move costs is the one page that read as a route end to end; that route is still
readable, in the portable page that always described it.

The dead-link gate is what proves the retarget, and it found nine links the issue's count of fourteen
had missed: seven in the archived release notes, where the published-record rule permits a link target to
be repointed and forbids the prose around it to be rewritten, and two in the living `releases/` pages,
where the visible label was corrected along with the target. The always-on path **shrank by 79 B**, so
~1,300 lines moved at no session cost at all.

**Score:** 3

#### What makes this deploy extra special

A consumer following the worked example in `plugins/dkj-policy/README.md` was about to meet a 404: it
offered this repo's own `dkj-policy/CONTRIBUTING.md` as the model for writing down your own answers,
and that file stops existing here. It now points at the specialist lenses, and says in the same breath
why the page it used to name is gone -- so the example a consumer copies is the arrangement this
workflow actually recommends rather than the one it just retired.

**Score:** 2

#### Pull Request

The workflow folder's own README and CONTRIBUTING move into the specialist lenses

Plugins: dkj-policy

[PR #2181](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2181)

---

### DEPLOY: feat/2171-plugin-stops-scaffolding-folder-docs · 20260920-101131

`adopt-dkj-policy`'s Part 1 no longer writes `dkj-policy/README.md` or `dkj-policy/CONTRIBUTING.md` into a
consuming repo (Dave, #2171): two pages in the consumer's own tree only made that repo more complicated and
produced more inconsistency than they removed. **There is one `CONTRIBUTING` for a consumer to read and it
is the plugin's portable page**; what a repo answers for itself goes into its specialist lens, where the
rest of its repo-specific answers already live.

The refreshable fenced block (#1766) went with the page it lived in, along with its four top-up states and
the enabled-plugin read that composed its UPDATE chapter. That block existed because a page scaffolded once
is never corrected afterwards -- the right repair for a page the plugin OWNS -- and removing the page
answers the same defect one level up rather than contradicting it. With no fenced region left, *nothing that
already exists is ever touched* is true of this command without qualification for the first time.

**An existing copy is reported and never touched, and no delete command is printed.** A copy may carry the
only written statement of something that repo answered, and nothing here can tell that from a stale
scaffold. **The gates that READ those names are deliberately unchanged** -- `check-consumer-prose` runs its
detectors over both and `check-policy-drift` still lists them -- so a page still on disk keeps the standing
its repo gives it. Narrowing a gate to match would have retired it in the very repos whose pages are the
reason it exists.

The rank-order model now says the truth for both kinds of repo: the plugin's portable pages and skills sit
above the floor either way, and the middle rank is real only where a repo still carries the page it names.

**Score:** 4

#### What makes this deploy extra special

**This is a page a consumer was told to read, and the sentence that pointed at it shipped in the portable
half.** So the removal cannot be done in the scaffolder alone: a repo adopting today would have been handed
a rank model naming a file it never receives, and a repo that adopted earlier would have read that its
second layer no longer exists while the file sits in its tree and its gates go on reading it. Both readings
are wrong, and they are wrong in opposite directions -- which is why the portable page, the two skill pages
and the drift report all state the condition explicitly rather than picking one of the two repos to be
correct for.

**Nothing is removed from any consumer, on purpose.** The five repos holding these pages keep them, keep
their prose gate, and keep their rank 2. What they get on their next `adopt-dkj-policy` run is one `[legacy]`
line per page saying the plugin no longer authors it. That is the whole migration, and it is deliberately
not a command they can paste.

**Score:** 3

#### Pull Request

The plugin stops scaffolding a consumer's folder README and CONTRIBUTING

Plugins: dkj-policy

[PR #2178](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2178)

---

### DEPLOY: fix/2173-lint-gate-progress-record · 20260920-095105

The statusline no longer goes blank while a ship runs its lint gate. The lint gate is the step that runs
first, and on the measured ship (PR #2169) it took 78 seconds while publishing nothing, so a backgrounded
ship showed only its context line for exactly the stretch a reader is watching for -- and where the test
suites were already proved for the tree, the one long publisher that did exist never fired either, leaving
the whole pre-CI phase silent. `Invoke-WorkflowGates` now publishes a `lint gate (integrity check)` record
around its child call and removes it when the child returns, pass or fail.

It is an elapsed readout with no bar, and that is a decision rather than a shortfall: the integrity check
has no total number of checks to publish, and a bar over its very uneven checks would sit still for most of
the run. It publishes only at the top level of gate nesting, so the many suites that drive this function
over a fixture lint stay silent instead of repainting the test gate's own bar. `cut-release.ps1`'s separate
lint call is not covered.

The failure it prevents, named: a maintainer backgrounding a ship, seeing a blank statusline for ~90
seconds, and reasonably concluding the run had stalled.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. The progress bar and its statusline adoption are not in a
released version yet, so no consumer has the bar turned on to find this step missing from it.

**Score:** N/A

#### Pull Request

The lint gate publishes a progress record, so the statusline is no longer blank for the first part of a ship

Plugins: dkj-policy

[PR #2177](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2177)

---

### DEPLOY: fix/2172-seam-lib-retired-name · 20260920-093447

`Get-WorkflowFolderName`'s docstring names the retired folder name again. Two sentences in
`scripts/lib/seam-lib.ps1` whose whole job is to preserve the name the folder used to carry had been
overwritten with the name it carries now, so the walk order read `'dkj-policy', then
'workflow-davekjohn'` and the #1437 sentence read *'dkj-policy' became 'dkj-policy'*. Both say
`contributing-davekjohn` again. Prose only: the array below them was always correct, so no behaviour
changes -- what changes is that the docstring can again be used to check the array, which is the one
thing a mid-migration consumer depends on and the only place stating why the function walks three
names newest-first. The other eight rename sentences in the tree were read and all name the retired
folder correctly, so the sweep reached these two and nothing else.

**Score:** 2

#### What makes this deploy extra special

N/A -- an in-repo docstring. Nothing a consumer of these plugins can observe: the function's
behaviour, its argument list and the three names it walks are all unchanged.

**Score:** N/A

#### Pull Request

Get-WorkflowFolderName's docstring names the retired folder name again

Plugins: dkj-policy

[PR #2176](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2176)

---

### DEPLOY: fix/2174-reap-orphaned-tmp-record · 20260920-091329

The progress root no longer grows one small file per killed producer. `Get-LiveRunProgress` reaped
only `*.json`, so the `.tmp` a producer abandons when it is killed between the write and the move
was never looked at again -- and a killed producer is ordinary here, since a backgrounded ship dies
with its harness. It is swept now on the same pass, keyed on the name this lib itself writes and on
the pid embedded in it, so a `.tmp` somebody else put there is still evidence rather than litter.

Cosmetic and slow rather than visible: the statusline never parsed these, so no bar was ever wrong.
The failure it prevents is unbounded accumulation in `%LOCALAPPDATA%\dkj-run-progress\`.

**Score:** 1

#### What makes this deploy extra special

Nothing reaches a subscriber of the service: this is a per-developer cache directory on the machine
running the workflow, and nothing it holds is published, rendered or shipped.

**Score:** N/A

#### Pull Request

An orphaned .tmp progress record is reaped instead of accumulating forever

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2175](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2175)

---

### DEPLOY: feat/2135-persona-filenames · 20260920-084123

The four persona files -- Chris, Bianca, Derek and Rendall -- become `specialist-NN-NN-persona.md`,
closing the #2128 rename round. **No reader moves with them.** What makes this the written name is a
single row: `Get-SpecialistFileShapes`'s Persona entry, where `Current` takes the `specialist-` prefix
and `AlsoRead` keeps the bare spelling a consumer's cache may still be carrying. Every site that judges
or constructs the name -- lint check 3c, check 6b's persona-backed-manual construction,
`check-consumer-drift.ps1`, `check-roster-sync.ps1` and its mirror, and the `specialists-init`
bootstrap that both writes the orchestrator's `@`-import and probes the clone for it -- already reads
through that table, so a file left on the old name is still enumerated and still refused, because the
filter list derives from the same row.

That is not how this branch was originally written. It was cut before step A (#2130) and edited each
reader by hand; the merge that brought A through D in discarded those anchors in favour of main's
shape-driven ones. The round therefore ends the way step C ended, which is the property the table was
built for.

Two sites the issue named turned out not to be this step's, both verified against the tree rather than
taken from the report. `teardown.ps1`'s `@`-import recogniser matches on the **suffix** `-persona.md`,
which the prefixed name still carries, so the stated reason for changing it could not have held.
`bootstrap.ps1:856` and `:872` are lens literals belonging to #2133.

**Score:** 4

#### What makes this deploy extra special

A consumer's `SPECIALISTS.md` carries the orchestrator's body as a hardcoded absolute `@`-import into
the marketplace clone -- a clone that tracks `main` and advances on `claude plugin marketplace update`,
with no release, no version bump and no `plugin update` behind it. So this merge opens a window in which
any consumer that refreshes its clone before that line is edited loses Chris's entire persona body,
30,267 B of it, **in complete silence**: the rest of `CLAUDE.md` loads, the raw `@`-line stays in
context as inert text, and nothing is reported on stdout, on stderr or under `--debug`.

**This repo closed that window on itself rather than only documenting it for others.** Its
`SPECIALISTS.md` now carries both import lines, new one first -- the recipe #2134 published in
`INSTALL.md`, applied to the first of the six registered consumers. It was not a precaution: with the
single-line edit the budget gate reported the dead import and a 30,245 B shrink on this very checkout,
which is the measurement rather than the theory. The remaining five consumers take the same recipe,
and the old line comes out on both sides once the clone is refreshed.

**Score:** 5

#### Pull Request

The four persona files take the specialist- prefix, and the Persona row is what carries it

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2169](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2169)

---

### DEPLOY: fix/2167-lens-row-flip · 20260920-021714

`specialists-init` scaffolds a fresh consumer's lenses under the current name again. Step D of the
#2128 rename series moved all 30 lens files to `specialist-<g>-<id>-lens.md` but never flipped the
Lens row in `Get-SpecialistFileShapes`, so every WRITER went on composing the retired
`<g>-<id>-extension.md` -- into a consumer whose own tree carries the new spelling, and which the
migration note had just told to move away from it. `Current` now holds the new spelling and
`AlsoRead` the old, so an unmigrated consumer still resolves. No reader changes, which is the
property the table exists for. The two degraded writer arms in `bootstrap.ps1` move with it, and the
docstring now records why no gate could see the omission, that two of four steps have shipped it,
and where the guard that would pair the two halves is proposed (#2168).

One live defect travelled with it: `sync-roster`'s proposed roster row named the written spelling
even for a lens that already exists, so an un-migrated consumer would have been handed a link to a
path they do not have. It now names the file on disk where there is one -- the fix the same script's
stale-header line already carried.

**Score:** 3

#### What makes this deploy extra special

N/A -- this repo's audience is its own developers and the consumers of the plugin, not a subscriber
to a service.

**Score:** N/A

#### Pull Request

the Lens row flips to the new written spelling

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2170](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2170)

---

### DEPLOY: docs/2134-consumer-rename-migration · 20260919-235850

`INSTALL.md` gains a third migration section, for the `specialist-` filename rename. It is written
**before** the rename lands, because the persona half of it breaks outside every version gate: that
import resolves against the marketplace clone, which tracks `main` and advances on a refresh, so
instructions arriving afterwards are instructions nobody had when they needed them.

**Score:** 3

#### What makes this deploy extra special

A consumer whose `SPECIALISTS.md` still names the old orchestrator path loses Chris's entire body --
30,267 B of it -- and **nothing reports it**: not stdout, not stderr, not `--debug`. This section is
the only thing standing between that and the six registered consumers, and it hands them a recipe
with no broken window at all: carry both import lines through the overlap, which is sound exactly
because a dead `@`-import is inert. It also names the one verification that answers "does my import
resolve?" without opening a session to find out, and three consumer-side things the issue did not
list -- the markdown links in their own prose, the `always-on-baseline.json` key, and the fact that
their lenses need not move at all.

That last one is the part a consumer will feel most: the two halves of this rename are not equally
urgent, and only one of them is theirs to run today.

**Score:** 4

#### Pull Request

The consumer migration section for the specialist filename rename

[PR #2166](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2166)

---

### DEPLOY: feat/2133-lens-filenames · 20260919-232200

This repo's 30 repo lenses are now named `specialist-<group>-<id>-lens.md`, and every reference naming one
of them by its real path followed -- 84 files, 316 replacements, plus 43 link targets under
`dkj-policy/releases/**` whose prose is left exactly as written. **No reader moved with it**: step A
(#2130) had already put every one of them behind `Get-SpecialistFileShapes`, so what makes this the
written name is a row in that table and a `git mv`, not a sweep through the scripts.
`check-roster-sync.ps1` reports all 30 specialists rostered with a lens, the four main-loop personas
included -- they carry their id only inside that filename, which is what #2130's lookbehind fix exists
for. Step D of the rename plan in #2128.

The always-on baseline rose 348 B and every byte of it is filename: the path names lens files and each
one is nine bytes longer. Raised through the gate with that reason on the record rather than hand-edited.

**Score:** 3

#### What makes this deploy extra special

**A consumer's subagent defs now name a lens file their own tree does not have yet.** The defs that ship
to every consuming repo tell a specialist to read
`.claude/specialists/lenses/specialist-<group>-<id>-lens.md`, and a consumer who has not renamed still
holds `<group>-<id>-extension.md`. Their lenses are authored content, so nothing here renames them --
`bootstrap.ps1` is additive-only. The parenthetical those defs already carry names the **pre-seam**
`.claude/plugins/<family>/` and `.claude/extensions/` layouts, which is a different thing from the
current seam under its old filename, so it does not cover this.

What closes it is #2134, the migration section in `INSTALL.md`, which lands next and carries the `git mv`
for a consumer's own tree. Until they run it the named lens is simply not found, and the specialist
carries on without one -- no error and no report, the same silence any dead path has here.

**Score:** 4

#### Pull Request

Rename step D: this repo's 30 lenses to specialist-NN-NN-lens.md

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2165](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2165)

---

### DEPLOY: fix/2163-statusline-refresh-interval-seconds · 20260919-185355

The progress bar's timer was set in the wrong unit and so never fired: `refreshInterval` is in seconds,
this repo set `2000`, and Claude Code read that as 33 minutes -- so during a backgrounded gate the bar
stayed on whatever count it last drew and jumped to the true one only when the operator sent a message,
which is the moment they had stopped believing it. It is now `2`, in this repo's own settings and in what
`adopt-statusline.ps1` places, with the unit stated where the number is set and a test that refuses a
millisecond-sized value coming back. The statusline adoption is not in a released version yet, so no
consumer carries the wrong figure.

The failure it prevents, named: a released reader turning the progress bar on and finding it frozen for
the whole of every run they backgrounded, updating only when they speak. That has not happened outside
this repo, because the feature has not shipped.

**Score:** 1

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. No released copy of `adopt-statusline.ps1` carries the wrong
value, so there is no already-adopted settings file left holding it.

**Score:** N/A

#### Pull Request

The statusline refreshInterval is in seconds, not milliseconds

Plugins: dkj-policy

[PR #2164](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2164)

---

### DEPLOY: docs/2157-2158-capture-comment-accuracy · 20260919-181738

Two comments in the capture family now say something true. `Invoke-GitPark` told a reader that its
captured push output "can hold ErrorRecords as well as strings" and that `-match` against that array
would return elements rather than a boolean -- while the comment thirty lines above, in the same
function, correctly said the bound routes into the Start-Process arm and `Output` comes back as an
array of strings. Neither claim survived being checked: the arm produces strings here, and the `-match`
is inside `Get-GitPushFailureMessage`, whose `$Output` is `[string]`-typed, so an array never reaches
it as an array. The replacement says what the `Out-String` flatten is still for -- rendering the lines
*as lines*, where `$OFS` coercion would fuse them with spaces -- and why it deliberately is not
`Get-NativeOutputText`, the helper [#2154](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2154)
added for exactly this shape: the flattened text here is matched and never printed, so there is no
reader for an exception dump to reach.

**Both issues proposed a repair that was itself wrong, and neither was built as filed.**
[#2157](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2157) rested on
[#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155) having closed the `ErrorRecord`
class library-wide, which was not true when it was filed and became true while this branch was open --
so the comment rests on the half that held throughout, that a bounded capture answers from the
Start-Process arm. Its suggested rewording kept the `-match` clause that does not apply at that line.
[#2158](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2158) recorded the deliberate
`Get-NativeLineText` / `Get-ShopifyLineText` duplication as *inferred*, with "nothing in either file
says so"; `Get-NativeLineText` already said it, so what landed is the reciprocal note in the docstring
that was missing it, with the trade written out -- two libs that depend on nothing, two separate mirror
sets a shared eight-line source would have to land in, and the cost that nothing enforces the pair
staying in step.

**Score:** 1

#### What makes this deploy extra special

Nothing here changes what any consumer's scripts do -- the diff has no executable line in it. The three
files ship in `dkj-policy` and `dkj-subagents-shopify`, so the corrected text does reach every consuming
repo at the next release, and the reader it is worth something to is the one who opens either lib to
decide whether a flatten or a duplicated helper is still load-bearing. That reader was previously handed
a contradiction inside one function and a decision recorded in only one of the two files it governs.

**Score:** 1

#### Pull Request

Correct two stale comments about capture Output shape

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2162](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2162)

---

### DEPLOY: feat/2132-manuals-specialist-prefix · 20260919-164945

Every portable manual is now named `specialist-<group>-<id>-manual.md`, and what makes that the WRITTEN
name is a single row: `Get-SpecialistFileShapes`'s Manual entry, where Current takes the `specialist-`
prefix and AlsoRead keeps the bare spelling a consumer's cache may still be carrying. **No reader moved
with it** -- step A (#2130) had already put every one of them behind that table, which is the property
the table exists for, and a file left behind on the old name is still enumerated and still refused
because the filter list is derived from the same row. Step C of the rename plan in #2128.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. A manual is read through
`${CLAUDE_PLUGIN_ROOT}/manuals/...`, which resolves into the version-pinned plugin cache, so the agent def
and the manual it names travel together in one release and never disagree between two of them.

**Score:** N/A

#### Pull Request

The manuals are renamed to specialist-NN-NN-manual.md

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2161](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2161)

---

### DEPLOY: fix/2155-normalise-capture-output · 20260919-163935

A failure captured through `Invoke-NativeCapture` now reads as the command's own words. Before this,
every caller rendering `$res.Output | Out-String` on a failure path got a PowerShell exception dump
naming this lib's own source line instead of the reason -- and an empty stderr line came out as the
literal text `System.Management.Automation.RemoteException`. That is ~60 render sites across the
workflow's scripts, including refusals `prune-merged`, `ship-pr`, `open-pr` and `park-cycle` print. It
closes #2154's CLASS at the source; #2154 itself landed separately mid-branch and closed its own site
at the reader, so the two layers now sit on top of each other deliberately.

**Score:** 3

#### What makes this deploy extra special

It is a behaviour change to a lib mirrored into `dkj-policy` and `dkj-subagents-shopify`, so it reaches
every consumer's scripts. Nothing that works today starts failing: no caller in this tree reads an
`ErrorRecord` property off a capture's `Output`, and the container is deliberately unchanged. What
changes is that text which was already wrong becomes right -- a consumer matching on
`NativeCommandError` was matching the wrapper's noise, which is the defect rather than the contract.

**Score:** 3

#### Pull Request

Invoke-NativeCapture returns plain text on both arms, so a failure reads as the command's own words

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2160](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2160)

---

### DEPLOY: fix/2150-marker-column-gate · 20260919-161919

A new lint check, `[marker-column]`, holds a verdict marker to the **start** of the line a check
writes -- the convention the SessionStart hooks have silently depended on since #2142 anchored their
selector to `^\s*`. Before this, a future `Write-Host "note: [ERROR] ..."` in a check would have had
its finding dropped by the hook with no error, no red check and nothing in session context: the exact
failure the hooks exist to prevent, arriving through the front door.

The subject set is **derived from the hooks rather than listed** -- a subject is a script whose output
a hook reads through the anchored selector, so each hook contributes the markers its own
`Select-CheckMarkerLine` calls name and the check its own path literal names. A new hook brings its
check into scope on the day it is written, and no list goes stale. The markers are held per subject
rather than as one union, so a marker no hook selects from a given script is not reported and the
finding can name the hook that would do the dropping.

The unit is the **emitted line**, not the string literal: a `+` concatenation, a `-f` format string
and an argument array are all walked, with anything unknowable statically standing in as one
non-whitespace placeholder. That is what makes `("note: " + "[ERROR] x")` a finding, which the
per-literal shape the issue sketched would have passed.

Born green: 14 hook files, 8 of which select on markers, 15 check scripts, 69 marker emissions, 0
findings and 0 exemptions.

**Score:** 2

#### What makes this deploy extra special

Every repo running this workflow receives the hooks whose selector this convention protects, so the
guard travels with them. It changes nothing a consumer does and fires on nothing they have today --
it only stops a future check script from writing a line whose finding would never arrive.

**Score:** 1

#### Pull Request

A gate holds a check's verdict marker to the start of the line the hook selector anchors on

[PR #2159](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2159)

---

### DEPLOY: fix/2154-flatten-refusal-reason · 20260919-160659

A refusal captured from a native command now reads as **the command's own words**. `prune-merged`'s
verdict on a branch `git branch -d` declined was git's single line -- `error: the branch '<name>' is
not fully merged` -- followed by a `CategoryInfo` line, a `FullyQualifiedErrorId` line and a
source-line caret pointing into `native-capture-lib.ps1`: a file the operator never ran and cannot act
on, in the middle of the sentence telling them what to do. `Get-NativeOutputText` flattens each
captured line to the text the command actually wrote, and the seven failure-path renders in
`prune-merged.ps1` go through it. git's own `hint:` lines survive -- the repair must not trade an
exception dump for a truncation.

**It normalises at the reader, not at the capture, and that was the branch's one real decision.**
Making `Invoke-NativeCapture` hand back strings would fix every caller at once and change the result
shape for every caller in every consumer, which the lib's own `#1963`/`#1966` reasoning already calls a
decision of its own rather than a side effect of a repair. That reading is filed as [#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155), not dropped.

**Score:** 2

#### What makes this deploy extra special

`prune-merged.ps1` and `native-capture-lib.ps1` both ship in `dkj-policy`, so this lands in every
consuming repo that runs the tidy-up lanes: the next time a delete is refused there, the operator reads
git's three lines instead of twelve, and nothing points them at a file inside the plugin. Small, and on
a path nobody visits until something declines -- which is exactly when a readable message is worth the
most.

**Score:** 2

#### Pull Request

Render a refused git delete as git's own line, not a PowerShell ErrorRecord dump

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2156](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2156)

---

### DEPLOY: docs/2137-subagent-def-term · 20260919-155253

Three renames moved the thing and left the noun: `agents/` became `subagents/` (#1698), the plugins
became `dkj-subagents-*`, and the defs themselves became `specialist-NN-NN-subagent.md` while this
branch was open (#2131, landed as #2147) -- while 270 occurrences across 87 markdown files still
said *agent def*, and `README.md` called the same file *"the agent definition"* two directories away
from `plugins/dkj-subagents/README.md` calling it *"the subagent definition"*.

**`subagent def` is now the term, and the 270 stale ones are corrected on edit rather than swept**
(Dave, September 19, 2026). That is the answer `CLAUDE.md` already gives for the ~830 repo-name
citations left by the September 10 rename, applied one noun over: both spellings read correctly, so
nothing is broken, and a sweep would buy consistency at the price of a diff no gate reads and nobody
can review -- landing mid-way through a six-PR round whose reviewability is its stated design
property.

The rule is portable and lives in the technical writer's manual, so it travels to every consuming
repo and applies to the next rename rather than only to this one. `README.md` now states the term and
its boundary where a reader meets the word, and the places where the contradiction stood **on the
line itself** are repaired: the section heading that defines the term, the bullet naming the file, and
the sentence that says which of the two is leading.

**The boundary is stated rather than left to a reader's judgement:** the word `agent` stays wherever
something *resolves* it instead of reading it -- the `"agents"` key in all four `plugin.json`
manifests is Claude Code's own schema, and `scripts/agents/build-agent-defs.ps1` is a path the
tooling reads. #1764 is what a wrong shape in those manifests costs: four of six plugins
uninstallable for a whole release.

**Score:** 3

#### What makes this deploy extra special

A consumer's technical writer gets the rule for every rename, not this one: new writing takes the new
noun, existing occurrences are corrected on edit, anything a machine resolves is out of scope, and
prose that contradicts itself on its own line is repaired at once rather than left to drift. Read on
demand from the manual, so it costs no always-on context.

**Score:** 2

#### Pull Request

Record 'subagent def' as the term for new writing, and repair the prose that contradicts the filename on its own line

Plugins: dkj-subagents-alpha

[PR #2153](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2153)

---

### DEPLOY: docs/2144-swept-citation-class · 20260919-142241

The class #2139 opened is closed, and the reading that closed it is not the one the report proposed.
Three swept quotations are restored to what their releases actually shipped and **marked at the line**:
the `specialists-init` transcript in shipped payload (swept four times, marketplace name included --
`specialists@davekjohns-workshop`, not the "half-swept" pairing #2144 described), the
`measure-skill.tests.ps1` capture its own comment calls *"real output"* together with the `Source:` line
below it, and `INSTALL.md`'s layout table, whose single `v3.10.0`-onward row carried a path spelling no
release before `v4.33.0` ever held -- now three measured rows, which is the only thing a reader on an
old version can recognise themselves in.

**The decision #2144 asked for: an illustration is kept TRUE, never frozen.** A comment or a sample
showing the *shape* of a line quotes nothing, so freezing it only preserves an anachronism the reader
has to resolve. Five sites (two of them shared-script mirrors) now pair a current name with a version
that name actually had. A third form is named and deliberately left alone -- an **attribution**
(*"`dkj-policy` 4.21.0 shipped it"*) keeps today's name on purpose, because the name is how a reader
identifies the thing now while the version identifies the release. Without that third bullet the
convention reads as a mandate to sweep fourteen correct sentences.

**And #2144's proposed check was run rather than filed as an idea, and the answer is not to build it.**
*A name paired with a version older than the version that name first shipped in is always a swept
quotation* -- the detection half holds, the "always" does not. Over `*.md`, `*.ps1`, `*.json` and
`*.yml` outside the archived release history: **54 pairings, 3 of them swept quotations**, 5
illustrations, and 46 correct as written -- 32 synthetic test fixtures, where an invented version is the
point, and 14 attributions or dated notes, two of which pair a plugin name with the *Claude Code CLI's*
own version.

**The 54 is not the figure the decline rests on, and the first draft of this entry wrongly let it be.**
Excluding `scripts/tests/**` is one line and removes 32 by construction -- 3/22 strict, **8/22 actionable**
-- which beats the 12.5% a comparable candidate was declined at a few hundred lines up the same lens. What
carries the decline is the **floor**: 14 of those 22 are attributions, the form this branch decides to keep
writing, so after the repairs the tree holds zero true findings against fourteen standing false ones and
every future attribution adds another. Born red against correct prose, growing, and not improvable by
narrowing -- the stale-path decline's shape exactly. Declined at all three modes, with the `[INFO]` audit
declined on its own terms rather than as a hedge, and with one variant named as **untested** (restricting
to fenced blocks) so *"settled"* does not quietly cover it. The lens also records the proportionate
alternative, per its own rule that a decline naming no better route invites the same proposal again: check
the **marking** rather than the anachronism.

Marlowe red-teamed that verdict and returned **WOBBLES** -- the conclusion held, the argument did not, and
both this entry and the lens were rewritten on it. Worth recording, because the failure he caught is the
one this repo keeps naming: a real measurement, quoted accurately, chosen because it flattered the answer.

The portable half is in the technical writer's manual, which already carried a rename-sweep rule with
three exceptions. What it lacked is the part #2139 and #2144 measured: **the rule protects nothing on
its own**, because a find-and-replace is run by somebody who has not read it, and **shape is not
protection either** -- a quoted path survived three sweeps in one file while the same shape was swept
twice in another. The marking at the line is the whole guard.

**Score:** 3

#### What makes this deploy extra special

Three of the repaired documents are plugin payload a consumer receives at the next release --
`specialists-init/SKILL.md`, `plugin-versions/SKILL.md` and the technical writer's manual -- plus
`INSTALL.md`, which is the adoption page they read before any of it. **Nothing is asked of them and
there is no migration.** What changes is that the transcript in the adoption skill now quotes what that
CLI actually printed, so a consumer comparing their own output against it is comparing against
something real, and the layout table names the spelling their own stale `@`-import is likely to carry
instead of only today's. A consumer who has adopted the workflow also picks up the rename-sweep
convention, which matters the first time they rename anything of their own.

**Score:** 1

#### Pull Request

The swept-verbatim-citation class, closed

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2152](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2152)

---

### DEPLOY: fix/2142-anchor-hook-marker-match · 20260919-141223

Every session hook now counts a verdict marker only where its check wrote it, through one shared
`Select-CheckMarkerLine`, and `check-always-on-budget.ps1` sanitizes the tree-derived values it
prints the way the rest of this tree already does. Before this, a document able to put `[WARN]` or
`[ERROR]` on the always-on path had its own line forwarded into every session start -- and `[ERROR]`
made the hook print its over-the-limit headline and the whole report on a run that was in fact `[OK]`.
Reaching it needed content in the tracked import chain of the checkout being measured -- which is a
branch under review, not only the trunk: the check runs from `open-pr`, from CI and from a session
start against whatever is checked out, so a pull request touching an `@`-import line already tripped
it. So this is robustness rather than a closed hole, and the hole was one hop nearer than "already
merged" suggests. What it removes is the shape that goes wrong later, when somebody adds a field to a
report and does not know a sanitizer was load-bearing for it. The sweep is the bigger half: eight
hooks across two plugins were selecting this way, each with its own hand-written escape.

**Score:** 2

#### What makes this deploy extra special

N/A -- no subscriber of a service notices this. It changes which lines a session-start hook forwards
in a repo running this workflow, and the visible behaviour of every healthy repo is unchanged.

**Score:** N/A

#### Pull Request

Session hooks count a verdict marker only where the check wrote it

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2151](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2151)

---

### DEPLOY: fix/2141-xoxowildhearts-checkout-candidate · 20260919-135420

`check-connectors` reported `[SKIP] checkout ... not present on this machine` for the xoxowildhearts consumer while its checkout sat at `bwj-development/xoxowildhearts`, so nothing about that consumer was checked here. Its manifest lacked the `bwj-development/` candidate that its sibling `smartwatchbanden.json` gained in #1831 -- the fourth time a candidate fix reached one manifest of a pair and not the other (#1524, #1807, #1831). The candidate is appended, and `connectors.tests.ps1` now holds every manifest of one `siblingGroup` to the same set of layouts, so the next drift fails the gate rather than reading as an absent checkout.

**Score:** 3

#### What makes this deploy extra special

Maintainer-only: the register is read by this repo's own maintenance, and no subscriber of the service sees it. N/A.

**Score:** N/A

#### Pull Request

connectors/xoxowildhearts.json resolves the bwj-development/ layout, so check-connectors stops reporting a false SKIP

[PR #2149](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2149)

---

### DEPLOY: docs/2145-reader-site-count · 20260919-134205

The `feat/2130` entry claimed thirteen reader sites, that **all of it** now goes through the four-row
table, and that **no reader is edited again**. All three were wrong by one site, which step B (#2131)
found the moment it moved files and whose entry already carries the reason the sweep could not have
named it. The count now says what was converted instead of asserting a total, the two completeness
clauses are gone, and a paragraph under them records the miss and states that a later step still sweeps
before it moves anything.

It is corrected now rather than after the cut for one reason: the entry is still under
`## [Unreleased]`, so it is a live document, and four steps of the series (#2132, #2133, #2134, #2135)
are parked against it. A session picking one up reads *"no reader is edited again"* as a licence to skip
the sweep -- which is exactly the reasoning that let the fourteenth site through once already. After the
next cut the sentence is archived history and the carve-out for `dkj-policy/releases/**` applies.

**Score:** 2

#### What makes this deploy extra special

N/A -- the correction sits in the entry's tier-0 body, so it reaches this repo's own changelog release
document and nothing a subscriber installs or reads. No script, no plugin payload and no behaviour
changes.

**Score:** N/A

#### Pull Request

The #2130 entry's reader-site count and its completeness claims are corrected

[PR #2148](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2148)

---

### DEPLOY: feat/2131-subagent-def-filenames · 20260919-131555

Step B of the #2128 rename series, and the one with the most ways to go wrong: the 26 subagent
definitions become `specialist-<g>-<id>-subagent.md`, and the four `plugin.json` `agents` arrays that
name every one of them literally move in the same commit. #1764 is why that pairing is not optional --
a bad shape in those arrays made four of six plugins uninstallable for a whole release. Lint check 38
holds all 26 entries against a file on disk and reports 0 findings. The suffix change finishes #1698,
which moved `agents/` to `subagents/` and left the files inside called `<g>-<id>-agent.md`.

**The rename was the easy half.** #2130 had converted thirteen reader sites to one four-row table so
that a step like this one moves files and touches no reader -- and moving the files found a
fourteenth it had missed. `Get-PluginIds` (`check-connectors.ps1:377`) sliced the specialist id off
with `-replace '-(agent|persona)$'`, which matches nothing in `specialist-06-23-subagent`: the strip
left the whole base name standing and returned it as an id, so `$ownedIds` silently stopped holding
ids and the eight `[INFO]`/`[INVENTORY]` assertions filtering on it went red. Nothing threw. It
survived step A because it reads a *directory* rather than a filename pattern, and keeps its
convention in a `-replace` on the following line -- so neither the anchored globs nor the
`^(\d{2})-(\d{2})-...$` regexes step A was hunting named it, seven lines above a converted walk whose
comment describes this exact defect as fixed. It now goes through `Get-SpecialistFiles` +
`Get-SpecialistFileId`, with the directory leaf through `Get-SubagentDirPath`. A tree-wide sweep found
no second site; the entry's own claim of thirteen is corrected under #2145.

The second stale thing the merge exposed was the flip itself: the `Subagent` row in
`Get-SpecialistFileShapes` still named the old spelling as the written one, because this branch was
built before that table existed and could not have swapped a row that was not there. Swapped now, in
all four byte-identical copies, with the paragraph that read *"nothing has been renamed yet"* rewritten
-- from step B on, two of the four rows point in opposite directions, and that is the table's normal
state for the rest of the series rather than a defect in it.

**Score:** 3

#### What makes this deploy extra special

The renamed files are plugin payload, so a consumer receives them at the next release: after
`claude plugin update` their cache holds `specialist-<g>-<id>-subagent.md` and the old names are gone.
**Nothing is asked of them and there is no migration** -- every reader this workflow ships accepts both
spellings, which is what #2130 was built the release before for. The one case that is not covered is a
consumer's *own* script globbing `*-agent.md` inside the plugin cache; that is not a reader this repo
can see, and it is the whole of the exposure.

**Score:** 1

#### Pull Request

The subagent definitions become specialist-NN-NN-subagent.md, with the four plugin.json agents arrays

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2147](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2147)

---

### DEPLOY: docs/2139-frozen-citation-restore · 20260919-125659

Three verbatim citations that had been silently rewritten by the `dkj-`/`dkj-subagents-` renames are
restored to what the releases actually shipped, and marked so the next sweep leaves them alone. The
argument they belong to -- #1066's plugin-root boundary -- is evidence a reader is meant to check
against a tag, and a quotation that has been rewritten twice no longer carries that.

**Score:** 2

#### What makes this deploy extra special

N/A -- the citations sit in this repo's own lens and lint script. Nothing a subscriber of this
service installs or reads changes; the one instance that does sit in shipped plugin payload was
deliberately left to #2144.

**Score:** N/A

#### Pull Request

Restore the swept v4.22.0 citations and mark them as quotations

[PR #2146](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2146)

---

### DEPLOY: fix/2138-dead-import-is-not-unmeasurable · 20260919-124159

An unresolved `@`-import is now one of two things rather than one, and `check-always-on-budget.ps1`
says which. **Dead** -- the run can PROVE the file is absent, because the target is in the repo or
under a plugin marketplace root that exists on this machine -- is named as a dead import, and the
report says the whole document is silently missing from every session here. **Unprovable** -- which is
every CI runner, where there is no marketplace clone to prove anything with -- keeps the old wording
and the old silence exactly.

Those two words are the ones the code returns, and they are the only ones used for them here, in the
tests and in the PR title -- the copy edit found the first draft reaching for "unmeasurable" and
"unresolvable" as well. The branch NAME still carries "unmeasurable" and is left alone, because a
branch name is quoted in commits that have already landed. And **unmeasured** is a different thing
again: the pre-existing bucket for a document with no recorded figure, which a dead import may or may
not also be in.

The old report called every unresolved import "not measured and not recorded" and told the reader to
run it again on a machine where the import resolves. On the machine #2138 was measured on, that was
the machine they were already on.

It warns and does not refuse: the exit code still belongs to the budget, and a dead import is partly a
fact about the machine, so refusing would block a push over a plugin somebody has not installed. The
in-tree half is already a hard error in check 28 of `check-plugin-integrity.ps1`, which is the gate
that owns it.

One containment test answers both halves of that question -- `Test-PathIsUnder` -- and check 28 of
`check-plugin-integrity.ps1` now calls it too. Both had a bare `StartsWith` against a directory name
with no separator appended, so a sibling whose name merely starts with the root's read as being inside
it; in check 28 that meant reporting a dead link for a file the repo does not own. The branch's own code
review found the first one, on a green suite, because the draft guarded one comparison and pinned only
the guarded half.

Two smaller things came with it. A dead import is now reported even when the baseline happens to hold a
figure for it -- the question is asked ahead of the carried branch, so this lib's own memory cannot
hide the one failure it exists to surface, and the recorded bytes are still carried so the next branch
does not read as growth. And both lines of the block carry the `[WARN]` marker, because the
session-start hook forwards only the marked lines; the existing unmeasured block keeps its remedy on a
continuation line, which is why no session start has ever seen it.

**Score:** 3

#### What makes this deploy extra special

All four files ship in the `dkj-policy` payload -- the two libs, the check script and the
`always-on-sessioncheck` hook -- so every repo running this workflow gets this at the next release,
with nothing to do and no migration. For most of them it changes nothing: their imports resolve, and a
consumer with no marketplace root reads exactly as before.

For the ones it does reach, it is the difference between a session that quietly has no orchestrator
and a session that says so in its first four lines. The measured instance is a registered consumer
that ran that way for over a week with a gate on the machine that had already seen it, because the
gate's own sentence pointed the reader away from the repair. Nothing about the budget changes, and no
gate starts refusing anything.

**Score:** 3

#### Pull Request

a dead '@'-import is told apart from an unprovable one, and named as dead

Plugins: dkj-policy

[PR #2143](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2143)

---

### DEPLOY: feat/2130-dual-name-specialist-readers · 20260919-113832

The specialist filename readers now accept both conventions, so the #2128 rename can proceed one kind
at a time without a flag day. Four filename shapes -- manual, persona, subagent def, lens -- were
recognised by a scatter of independently anchored globs and `^(\d{2})-(\d{2})-...$` regexes. Thirteen
such sites in nine scripts are converted here, four of them held byte-identical to plugin mirrors, and
they now go through one four-row table in `check-report-lib.ps1`, on `Get-SubagentDirName`'s standing
doctrine: both are read, one is written. Each later step of the series swaps one row and moves that
kind's files. **Nothing is renamed by this change** and the tree is byte-unchanged apart from the
readers.

**Thirteen was not all of them, and this paragraph said it was** (#2145). It claimed that *all of it*
now goes through the table and that *no reader is edited again*; step B (#2131) moved files and found a
fourteenth, `Get-PluginIds` in `check-connectors.ps1`, which it converted -- that entry carries why the
sweep could not have named it. Both claims are struck here rather than left to travel into a release
note, because four steps of the series remain and a completeness claim reads as a licence to skip the
sweep on each of them. **A later step still sweeps for readers before it moves anything.**

Wiring them surfaced three defects that were already there. `build-agent-defs.ps1` had been walking
**zero of the 26 agent defs** since the `agents/` -> `subagents/` rename, invisibly, because the lint
check that would have reported the resulting drift builds its own set correctly. The roster check's
bootstrap-detection scan carried a hand-copied id pattern that had drifted tighter than its source, so a
roster whose ids sit only inside lens filenames read as no roster at all. And the shared lookbehind
would have quietly unrostered the four main-loop personas at step D, in a file no anchored-filename
sweep reaches.

**Score:** 3

#### What makes this deploy extra special

The three repaired readers travel to a consumer in the plugin payload -- `bootstrap.ps1`,
`teardown.ps1`, `sync-roster.ps1` and `check-roster-sync.ps1` -- so a consumer gets them at the next
release. Today they change one behaviour and prevent three. Changed: a consumer whose roster ids appear
only inside lens filenames is no longer told it was never bootstrapped, which is the `[BOOTSTRAP]` line
that suppresses every other finding under it. Prevented, once a kind is renamed: a bootstrap writing a
second empty lens over one the owner had filled in, a teardown leaving the other spelling behind, and a
roster check reporting a plugin as shipping no subagents at all. Nothing a consumer has to do, and no
migration -- which is the point of doing this before anything moves.

**Score:** 1

#### Pull Request

The specialist filename readers learn both conventions

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2140](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2140)

---

### DEPLOY: feat/2128-specialist-file-prefix · 20260919-105601

That a dead `@`-import is silent has been this repo's position since #874 and is why lint check 28
exists. It had never been measured, upstream documents none of it, and the #2128 rename plan turned on
it -- so it was measured in an isolated checkout. The silence is confirmed and total: the rest of the
file loads, and nothing is reported on stdout, on stderr, or under `--debug`.

**One detail of check 28's own wording turned out to be wrong**, in all three places it appears: it says
Claude Code *drops* the import, and the line is not dropped -- the raw `@path` survives in context as
inert text. That is worse rather than merely different, because the document is gone while something
that still looks like its import is sitting there. The wording is corrected.

It lands in the system-administration lens, beside the clone-versus-cache measurements it belongs with,
and **not** in `CLAUDE.md`. That was the first attempt, and the always-on budget gate refused it: the
path is already 9,380 B over its ceiling, so it may not grow, and evidence for a decision is exactly
what that gate says belongs in the owning specialist's lens. `CLAUDE.md` already points there for this
subject, so it needed no edit at all.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here ships to a consumer. The paragraph lands in this repo's own governance document, and
the rename it was measured for has not started; its six steps are #2130 through #2135.

**Score:** N/A

#### Pull Request

A specialist- prefix on every specialist file, and one suffix per kind

[PR #2136](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2136)

---

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

