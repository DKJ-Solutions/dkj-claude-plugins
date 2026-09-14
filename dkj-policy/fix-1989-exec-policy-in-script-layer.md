## fix/1989-exec-policy-in-script-layer

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

#### What this is the other half of

[#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989), split out of
[#1985](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1985) on the day that one landed.
#1985 repaired the **markdown** layer -- 85 printed invocations across 32 documents -- and added check 42
to hold it. The same defect sits one layer over, in the `.ps1` comment-based help (`.EXAMPLE`) and in a
handful of printed operator hints, and #1985 deliberately left it: born at 43 source findings, it is a
sweep to propose rather than a regression guard, which is the trade check 41's header records this repo
declining at 71.

**The issue asked for a decision before any code**: sweep the script layer, or declare comment-based help
out of scope. Swept -- the two printed hints settle it, because they are output a reader copies rather
than documentation, and a `.EXAMPLE` block is what `Get-Help` prints to somebody about to type the command.

#### The dependency, and how it resolved

Check 42 did not exist on `main` when this branch was claimed: it sat on the parked, un-PR'd
`fix/1985-bypass-in-printed-commands`, and three of the 44 measured sites were already rewritten there.
PR [#1992](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1992) merged while this was being
prepared, so the widening lands on the real check rather than on a second copy of it.

### CREATE

- [x] The 73 sites swept -- 36 files, source and plugin mirror alike, `-ExecutionPolicy Bypass` inserted
      immediately after the `-NoProfile` each one already carried. `build-shared-scripts.ps1` reports 0
      mirrors updated afterwards, so source and mirror were swept consistently rather than one following
      the other.
- [x] Check 42 widened to the script layer, as a **second pass with its own `[exec-policy/script]`
      coverage line** rather than a second check number. The rule is one rule -- a printed command names
      an execution policy -- and check 4's `[link-scan/lenses]` is the established shape for one rule
      reporting over two subject sets.
- [x] The header's `THE SCRIPT LAYER IS DELIBERATELY NOT A SUBJECT` block replaced by the three
      narrowings and the measurement behind each, and the markdown pass's coverage note repointed: it
      claimed the `.ps1` layer was born at 43 findings and was not a subject, and both halves are now
      false.

#### The three narrowings, each measured before it was written

The naive rule over `.ps1` is born at **93 findings tree-wide**, against check 42's 0 over the documents.
A script holds three things a page does not, and each needed its own answer:

- **The invocation must BEGIN its line, or a line of the string it sits in.** A command somebody pastes
  is the whole of its line; prose naming the form is a fragment of a sentence. 93 -> 75, and all 18
  dropped are correct -- 5 prose sites and 13 fixture strings whose content is a `& powershell` call.
  The string half is not decoration: `check-fanout.ps1`'s printed hint begins the line of the string and
  not the line of the file, so a file-line rule alone would have missed the strongest case for sweeping.
- **A command the script RUNS is never a subject**, read off the AST rather than by looking for a leading
  `&`. `-ExecutionPolicy` sets `PSExecutionPolicyPreference`, which a child process inherits, so those
  invocations are correct as they stand. The parser also covers the shapes an `&` rule misses -- an
  assignment, a pipeline, the operator on the line above.
- **The fixture layer is excluded, as a LAYER and not as an exemption list.** A suite proving this check
  fires has to contain what the check forbids, so a gate reaching into `scripts/tests/` would be arguing
  with its own evidence. Of the 75 subjects, exactly **2** sit under a `tests/` folder and both are check
  42's own markdown fixtures. Nothing real is lost: a suite prints no operator hint, because nobody
  pastes out of one.

### TEST

- [x] `check-plugin-integrity.ps1`: **0 error(s)**, with `[exec-policy/script] checked 78 ... 0 finding(s),
      with 25 match(es) skipped as prose and 7 skipped as a command the script RUNS` over 202 script files
      -- the 312 check 5 parses, less the 110-file fixture layer.
- [x] Probed against the hazard rather than only asserted green: `check-fanout.ps1` reverted to the bare
      form reports all three of its sites, the printed hint at `:147` among them, and fails the run.
- [x] And probed in the **negative** direction, which is where a "not reported" assert is worthless on its
      own: with the AST narrowing disabled, scenario 55g fails and the suite goes to `1 failed, 158
      passed`. The narrowing is load-bearing rather than decorative.
- [x] `check-plugin-integrity-docs.tests.ps1`: **159 asserts**, eight of them new -- the `.EXAMPLE` defect
      reported with file and line, prose *not* reported, a run command *not* reported in either shape, a
      printed hint inside a string *reported*, the fixture layer silent, and `RemoteSigned` clearing it.
- [x] `build-shared-scripts.ps1`: 0 mirrors updated, the rest already in sync.

### DEPLOY: fix/1989-exec-policy-in-script-layer

The script layer now prints what the document layer prints: every `powershell` invocation a reader is told
to run carries `-ExecutionPolicy Bypass`, in `.EXAMPLE` help and in the two operator hints a script writes
to the screen. 73 sites across 36 files, and check 42 has a second pass that keeps it that way
([#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989)). #1985 repaired the 85 markdown
occurrences and deliberately left this half filed rather than swept; this is that file being closed.

**The interesting part is not the sweep, it is what the same rule costs one layer down.** Over documents
check 42 was born green at 85 subjects. Over `.ps1` the identical rule is born at **93 findings**, because
a script holds three things a page does not: prose *about* the invocation form, fixture strings that must
*model* the defect, and real invocations the script *runs*. Each got a narrowing, and each was measured
before it was written rather than argued for.

**The invocation must begin its line, or a line of the string it sits in** -- a command somebody pastes is
the whole of its line, while prose naming the form is a fragment of a sentence. That takes 93 to 75, and
all 18 dropped are correct. The string half carries its weight: `check-fanout.ps1`'s hint begins the line
of the *string* and not of the file, so a file-line rule would have missed the case that most deserved
sweeping.

**A command the script runs is read off the parser, not off a leading `&`.** `-ExecutionPolicy` sets
`PSExecutionPolicyPreference`, which a child inherits, so a script-to-script call is correct bare -- and
the AST also catches the shapes an `&` rule misses: an assignment, a pipeline, the operator a line above.

**The fixture layer is excluded as a layer, not as an exemption list.** A suite that proves this check
fires has to contain what it forbids. Measured rather than assumed: of the 75 subjects exactly 2 sit under
a `tests/` folder, and both are check 42's own markdown fixtures. Born green at 73, 0 exemptions.

**Score:** 2

#### What makes this deploy extra special

A consumer runs these scripts, not just reads them. The sweep reaches the plugin-carried copies -- the
`dkj-policy` lint and task scripts, the Shopify theme scripts, `sync-roster.ps1` -- so `Get-Help` on any of
them now prints a command that survives a Windows machine sitting at the default `Restricted`, and
`ship-pr.ps1`'s hand-back hint can be pasted straight out of the terminal. Small, and invisible until the
moment somebody copies a line; that moment is exactly when the old form cost them a failed run and a
detour into why.

**Score:** 2

#### Pull Request

The script layer's printed commands carry -ExecutionPolicy Bypass, and check 42 now reaches them

