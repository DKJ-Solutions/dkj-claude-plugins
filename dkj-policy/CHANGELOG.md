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

**2 / 8 minor entries** <!-- pending-tally -->

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

