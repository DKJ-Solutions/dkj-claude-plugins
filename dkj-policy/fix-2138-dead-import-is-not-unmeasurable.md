## fix/2138-dead-import-is-not-unmeasurable

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Issue #2138: a registered consumer had been importing the ORCHESTRATOR's body from a marketplace path
whose two halves were retired on September 9 and 10, 2026 -- ten and nine days before this branch --
and nothing reported it. The detector already existed: the always-on budget gate resolves every
`@`-import and names the ones that did not resolve.

#### One half of the report's reasoning did not survive verification, and the repair changed with it

The issue names two reasons nothing caught it. The first stands: lint check 28 in
`check-plugin-integrity.ps1` deliberately excludes an import outside the repo, and that exclusion is
right for CI -- #874 argued it by name, because a runner has no marketplace clone and erroring there
would fail every PR for a correct file.

The second does not. It says the budget gate "is a gate somebody runs, not a session-start check".
`plugins/dkj-policy/hooks/always-on-sessioncheck.ps1` has been exactly that since #2037, and it
already forwards every `[WARN]` line it prints. Read against the tree, the defect is not that the
finding never reaches a session -- it is what the finding SAYS when it gets there:

```
[WARN]  not measured and not recorded: '<the retired path>'
        Run this once on a machine where the import resolves, so the baseline records a figure CI can carry.
```

That instruction cannot help, because the reader is already on such a machine. So this branch builds
neither of the three repairs the issue floated. It adds the discriminator the wording was missing.

#### The discriminator, and why it does not touch check 28

An import that does not resolve is two different facts, and only one of them is the repo's to fix:

- **dead** -- the absence is PROVABLE here: the target is in the repo, which this run is reading, or it
  is under the plugin marketplace root and that root exists on this machine. A machine holding a plugin
  administration that does not contain the named marketplace is not a machine that cannot see.
- **unprovable** -- nothing can be concluded. A CI runner has no marketplace root at all, which is
  #874's premise, kept rather than narrowed.

The exclusion check 28 carries stays exactly as it is. What is added is that its reasoning was always
CONDITIONAL, and there is now one function that tests the condition instead of assuming it.

### CREATE

- [x] `Get-PluginMarketplaceRoot` and `Get-ImportAbsenceKind` in `scripts/lib/measure-context-lib.ps1`
- [x] `Get-AlwaysOnMeasurement` gains a `Dead` row set, asked AHEAD of the carried branch -- a figure in
      the baseline says what a document used to cost, never that anything still loads it
- [x] `Get-AlwaysOnBudgetVerdict` passes `Dead` through to the reporting layer
- [x] `check-always-on-budget.ps1` prints the dead block, splits the unmeasured block so one line never
      gets both remedies, and stops telling a reader a DEAD carried term is "no marketplace clone on
      this machine"
- [x] both `[WARN]` lines of the dead block carry the marker, because `always-on-sessioncheck.ps1`
      forwards only the marked lines -- the existing unmeasured block puts its remedy on a continuation
      line, which is why no session start has ever seen it
- [x] the importing file is printed repo-relative in both blocks, so one field is not rendered two ways
      in one report
- [x] `always-on-sessioncheck.ps1`'s comment states which two kinds of warning now reach it, from the
      side the check script cannot see
- [x] `Test-PathIsUnder`, after code review: the first draft guarded the marketplace-root comparison
      against the sibling-prefix trap and left the repo-root comparison three lines above it bare, with
      the suite pinning only the guarded half. One function now answers both, and check 28 of
      `check-plugin-integrity.ps1` -- which carried the identical bare comparison -- calls it too
- [x] mirrors rebuilt with `scripts/sync/build-shared-scripts.ps1`

### TEST

- [x] `scripts/tests/always-on-budget.tests.ps1`: 24 new asserts, 81 passed / 0 failed. The two proofs
      and the two non-proofs, including a name-prefix sibling of EACH root -- the branch code review
      found unpinned -- plus `Test-PathIsUnder` directly; the
      carried-AND-dead regression, which is the one this lib's own memory could hide; that the verdict
      carries `Dead`; that the check WARNS and does not refuse; that the remedy sits on a `[WARN]` line;
      and the CI shape, where the same target is unprovable and both externals fall back to unmeasured
- [x] driven against the real broken consumer, read-only: the dead import is named, with the remedy,
      and the run still exits 0
- [x] driven through the hook itself with `-CheckScriptOverride`/`-ConsumerPathOverride`: both marked
      lines arrive at a session start
- [x] this repo's own path is unchanged -- 4 documents measured, `[OK]`, no dead import

#### Not repaired here, and why

The consumer itself is a change in that repo. And the reason nothing in THIS repo noticed is a
separate defect with its own mechanism: `connectors/xoxowildhearts.json` carries no `localCheckout`
candidate that resolves on this machine's layout, so `check-connectors.ps1` reports a false `[SKIP]`
for the one consumer that was broken. Filed as #2141 -- the fourth recurrence of a class that already
has #1524, #1807 and #1831.

### DEPLOY: fix/2138-dead-import-is-not-unmeasurable

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
