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

**14 / 27 minor entries** <!-- pending-tally -->

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

