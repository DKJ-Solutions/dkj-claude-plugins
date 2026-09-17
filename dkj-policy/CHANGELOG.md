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

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2043-closeout-fillable-template · 20260917-103912

The close-out reminder the chain-ending scripts print now hands over a line to fill in rather than
describing the shape to compose: `<what happened> -- see PR #1885. [Filed #<n>.] Session can be
cleared.`, with the citation slot already answered from the run's own knowledge. The three parts, the
ceiling and the rehousing rule are unchanged; only the delivery is.

It is the fifth repair of a rule that keeps losing, and the first taken after verifying that the
previous one was in force and still lost. Inbound #2043 asked for the print to be moved last -- it was
already last, the final statement of `ship-pr.ps1`. What put ~35 lines under it was the child
processes' output arriving after the parent's, which no placement can fix and whose cause does not
reproduce in this repo -- filed on its own as #2044. That **retires** the placement repair without
arguing for this one: a template printed in a buried position is exactly as buried as prose was, so
this change does not repair the ordering and is not offered as doing so. What it stands on is the
report's other argument, independent of where the line lands -- **a shape that is described has to be
composed, and a shape that is handed over has to be filled.** The general lesson banked alongside it is
that **last in the file is not last on the screen**.

**Score:** 3

#### What makes this deploy extra special

Every repo running this workflow gets the new line at every `open-pr`, `ship-pr`, `park-branch`,
`fold-changelog-entry` and `cut-release`, on its next plugin update. Nothing to do and nothing breaks
-- the parameters, the suppression and the bypass clause are untouched -- but what a session reads at
the end of every chain changes wording.

**Score:** 3

#### Pull Request

The close-out receipt hands over a fillable template instead of describing one

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2047](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2047)

---

### DEPLOY: fix/2044-child-output-to-host · 20260917-091623

A child process's narration could arrive after everything its parent printed, so where a line was placed
stopped predicting where it was read. `ship-pr.ps1`, `cut-release.ps1` and `verify-pushed-merges.ps1`
each started their children with `& powershell`, which hands the child's stdout to the parent script's
**success stream** -- its return value -- while the parent's own `Write-Host` narration goes to the
information stream. The two reach one console in printed order only while nothing consumes the success
stream; pipe such a run, capture it, or `Tee-Object` it, and the narration prints live while every
child is collected and replayed at the end. The output is not scrambled, which is what made it hard to
read as a defect: it is every parent line in file order, then every child line in file order.

All five narrating spawns across the three scripts now route through `| Out-Host`, which keeps the
child's text with the narration and leaves the success stream empty -- where a child's console output
never belonged. `$LASTEXITCODE` is unaffected, and `2>&1` is deliberately not used.

The repair went further than #2044 asked. The issue named `ship-pr.ps1` alone and expected to need three
consumer-side facts before anything could change; none was needed, because the reproduction it had
already written only had to be run through a pipe. Going looking then found the same defect in two
sibling scripts it had not reported. `../scripts/tests/ordering-passthrough.tests.ps1` pins both halves:
that the defect is real, and that no narrating spawn in either copy of `scripts/release/` is left
unrouted.

**Score:** 3

#### What makes this deploy extra special

A consumer is where this was measured -- a ship whose output arrives grouped rather than interleaved
costs a debugging session to explain, and #2044 was filed only after a second issue had already been
misdiagnosed from the resulting screen order. Consumers running a ship in a foreground shell see no
change at all; those who pipe, capture or background one get output they can read in order again.
Conditional reach is why this is not scored higher: nothing was blocked, and the workflow no longer
depends on placement anyway.

**Score:** 2

#### Pull Request

A child process's output no longer lands after everything the parent printed

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2046](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2046)

---

