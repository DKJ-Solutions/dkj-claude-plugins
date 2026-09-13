## feat/1948-assert-fixture-script-wiring

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

Give the #1934 fixture load guard a check, so that the wiring cannot be half-removed from a suite
without the gate saying so.

#### The rule as filed was measured first, and retired

#1948 proposed the sibling of check 35 `[fixture-git]`: *a suite that invokes a child `.ps1` and captures
BOTH its exit code and its output, and does not call `Assert-FixtureScriptLoaded` on the same statement
or the next, is a finding.* The issue also asked, correctly, that whoever picked it up measure the
false-positive rate before building it. Probed over `scripts/tests/` before a line was written:

| | |
|---|---|
| child-process `.ps1` invocations whose output is captured | **82** |
| of those, in a scope that judges | **11** |
| **findings** | **71** |

That is not a regression guard. #1934 wired **six** suites -- the six #1924 had measured failing -- and
the other ~65 were never wired at all, so the rule as filed answers *"should every suite be wired?"*
rather than *"is the wiring still there?"*. Born at 71 findings it is the shape this repo declined
outright for the stale-path check (124 findings, all false). The widening question is real and is filed
separately as [#1954](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1954).

**And the adjacency half is wrong independently of the count.** The six wire their call **two to four
statements** after the invocation -- `$out = ...`, `$code = $LASTEXITCODE`, then the verdict; `new-branch`
reads two redirect files first -- so check 35's *same-statement-or-the-next* rule reports all six of the
**wired** suites as findings. The model could not be copied one layer over as the issue expected.

#### So the subject is the wiring, not the invocation

A suite carrying **any** of the three parts must carry all three. That is self-anchoring: the file's own
content says whether it has adopted the helper, so no list of wired suites is maintained anywhere -- the
hand-listed-copy-list failure that #1693, #1865 and #1924 each ended up removing.

### CREATE

- [x] Check 41 `[fixture-script]` in [`check-plugin-integrity.ps1`](../scripts/lint/check-plugin-integrity.ps1),
      walking `scripts/tests/` for the three parts: the dot-source of `fixture-script-lib.ps1`, a call to
      `Assert-FixtureScriptLoaded`, and a call to `Write-FixtureScriptSummary`.
- [x] **A fourth fact: the summary's verdict is READ.** Printing it is not what fails the run --
      `Write-FixtureScriptSummary` *returns* whether something died on load and the caller turns that into
      an exit code (`$loadBroken = ...` then `if ($loadBroken)`, in all six). Drop only the read and the
      suite prints the block and exits **0**, which is the silence the lib exists to remove, wearing the
      guard's own output as proof that it is wired. Three spellings count as a read, and all three occur
      here: an assignment whose variable is read again, a condition, and an argument.
- [x] **Through the AST, never the line text** -- check 35's rule, and it applies with extra force to a
      *clearing* condition: a text match on the lib's name is satisfied by a comment or a string, which
      would clear a file that has genuinely lost the load. The dot-source is matched as a `CommandAst`
      whose invocation operator is `Dot`.
- [x] **A pair of brackets is not an escape hatch**: the wrapping is climbed once, for all discard
      spellings, exactly as check 35 does. A check whose arms disagree about wrapping teaches the shape
      that gets past it.
- [x] No second parse: the walk shares `Get-PsScriptCommandAsts` with checks 31, 33 and 35 (#1358), and
      the variable-read scan climbs to the root from the node rather than re-reading the file.
- [x] Entry 41 added to the `checks:list` span this file's own check 37 holds its headers against.
- [~] **One direction only.** A suite carrying none of the three parts is deliberately not a subject.
      Answering that here would be the 71-finding rule under another name; it is #1954.

### TEST

- [x] Nine scenarios (65-73) added to `check-plugin-integrity-commands.tests.ps1`, the suite that already
      owns the script-reading checks (31, 33, 34, 37): **101 asserts, 0 fail**, 20 of them new.
- [x] Each part dropped **on its own** -- three scenarios rather than one, because they fail differently
      and a single "something is missing" assert would pass while naming the wrong part. Each asserts the
      finding *names* the absent part.
- [x] The discarded-verdict case in **three** spellings (`| Out-Null`, `$null =`, assigned-but-never-read)
      plus a parenthesised discard, because that is the boundary this check shares with check 35.
- [x] **The discriminator, which matters as much as the findings**: a suite that runs a child with its
      output captured and carries none of the three parts is not reported. Get that wrong and this check
      silently becomes #1954's.
- [x] A bare mention of the lib in a comment and in a string is not a wiring.
- [x] **Born green on the real tree**: 7 files carry a part, all 7 carry all three, 0 exemptions.
- [x] **Negative proof against the real tree, with the real gate** -- not only against fixtures. Dropping
      the verdict from `fold-changelog.tests.ps1` and the summary from `park-branch.tests.ps1` -- the
      #1948 hazard verbatim -- gives **2 errors**, each naming the file and the missing part. Restored:
      0 errors.
- [x] Full gate and all suites green.

### DEPLOY: feat/1948-assert-fixture-script-wiring

`scripts/lib/fixture-script-lib.ps1` (#1934) is what makes a broken test fixture say so: without it, a
fixture missing a lib the copied acting script dot-sources **unguarded** kills the child during load, and
the suite reports the absence of the document the child never got far enough to write -- naming the absent
lib, the dot-source and load failure not at all. Six suites failed exactly that way on the #1917 branch;
`fold-changelog` alone turned 155 unexplained red asserts into 53 headlines that each named the missing
file.

It was wired into six suites in three parts, and **nothing asserted that any of the three was still
there**. An edit to an invocation helper that dropped a call would restore the whole class silently, with
every suite still green. Check 41 `[fixture-script]` refuses that: a suite carrying any part must carry
all three, and the summary's verdict must be *read* rather than printed and dropped -- because a run that
prints the load-failure block and then exits 0 is the worse of the two failures, wearing the guard's own
output as proof that it is wired.

The rule #1948 proposed was measured before it was built and not used: 71 findings over 82 invocations,
which is a proposal to wire 65 more suites rather than a regression guard, and its adjacency rule reports
all six *wired* suites as findings. That widening is real and is [#1954](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1954).
What shipped instead is self-anchoring, so it needs no list of wired suites -- which is the maintenance
failure #1693, #1865 and #1924 each ended up removing.

**Score:** 3

#### What makes this deploy extra special

Nothing here ships to a consumer: `scripts/tests/` is mirrored into no plugin, and the check reads only
that directory. It is maintenance-repo tooling, and the reader it serves is whoever next edits one of the
seven wired suites.

**Score:** N/A

#### Pull Request

The fixture-script load guard cannot be half-removed from a suite
