## fix/1924-fixture-dep-seed-from-script

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

#### The gap, in one word

`fixture-lib-deps.tests.ps1` exists to stop a hand-listed fixture lib copy going stale against what is
dot-sourced. Its own synopsis states the scope: *"no hand-listed fixture lib copies ... may go stale
against what **those libs** dot-source"* -- for each copied **lib**, whether that lib's own siblings were
copied too. It never asked the same question about the **script under test**.

On the #1917 branch that cost six suites: ~25 acting scripts gained
`. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')`, unguarded, and `fold-changelog` went 155
asserts red, `prune-merged` 73, `park-branch` 18, while `new-branch`, `worktree-lane` and
`entry-scaffold` died on load. This gate reported all 26 of its asserts passed throughout.

#### What was measured before anything was built

A naive widening -- seed the walk from every dot-source the copied script has -- is **not** born green.
Measured on the clean tree: **10 subjects report**, and every one of them is a **conditional**
dot-source that a fixture legitimately declines to carry. `source-repo-guard-lib.ps1` is in eight of
the ten, and its refusal cannot fire in a fixture at all, which carries no `marketplace.json`.

Narrowed to the dot-sources that run **at load** -- top level, outside any `if`/`try`/function/loop --
the same walk reports **none**, and still reports the whole of the measured class: `check-report-lib.ps1`
was dot-sourced unguarded at the top of all ~25 scripts. That is the asymmetry this branch builds: a
copied **lib** is read for all its dot-sources, a copied **script** for its load-time ones only.

#### The one survivor, and the mechanism it needed

`source-repo-guard.tests.ps1` copies `check-branch-entry.ps1` into an away directory in order to watch
the guard **refuse** it -- the run exits 1 before any other lib is reached, so the fixture is right not
to carry the other five. `Get-FixtureCopiedLibName`'s own docstring predicted exactly this case under
&#35;1693 and specified the answer in advance: *"a declared opt-out on that suite -- NOT another entry in
the exemption list"*. #1924 is the first instance, so the mechanism is built to that specification.

### CREATE

- [x] `script-contract-lib.ps1`: `-UnconditionalOnly` on `Get-ScriptDotSourceTargets`, plus
      `Test-AstRunsAtLoad`. One switch and one `continue` inside the walk that already resolves these
      paths -- the alternative was a rival variable-resolving walker next door, which is the defect this
      function's own caller was reviewed for. Default off, so the SessionStart contract check is
      untouched. The memo key carries the mode.
- [x] `fixture-dep-lib.ps1`: `Get-FixtureCopyDestinationLiteral` factored out, so the lib reader and the
      new script reader share one parse; `Get-FixtureCopiedScriptPath` reads a copied acting script as a
      repo-relative **path** (a leaf could not be found again); `Get-FixtureDepFinding` seeds the closure
      from those scripts and `Get-FixtureDepReport` counts a script-only fixture as a subject.
- [x] The declared opt-out: `# fixture-dep: script-not-loaded <path> -- <why>`, read from the parser's
      **comment tokens**. The reason is part of the syntax, so a malformed directive fails loud instead
      of silently disarming the gate.
- [x] `source-repo-guard.tests.ps1` carries the one declaration in the tree, with its reason at the copy.
- [x] Mirror rebuilt (`build-shared-scripts.ps1`) -- `script-contract-lib.ps1` travels to `dkj-policy`.

### TEST

- [x] The reconstruction, which is this suite's standing way of proving a widening catches what it was
      built for rather than merely staying quiet: a synthetic acting script with an unguarded top-level
      dot-source, a guarded one and an in-function one beside it. Reported: the unguarded one, alone.
- [x] **A correctness bug the code review found, in the load-time rule itself.** A script block was in
      the conditional list outright, which is right for one that is stored and called later and wrong for
      `& { ... }` -- invoked where it stands, and an idiom this tree uses on purpose to keep a seam's
      temporaries out of the caller's scope. `check-plugin-integrity.ps1` resolves its changelog seam that
      way at top level with an unguarded `. seam-lib.ps1` inside, so the gate read clean over exactly the
      #1917 shape. The block is now stepped THROUGH and the invocation's own ancestry decides, which keeps
      the same idiom inside an `if` correctly conditional -- both shapes are in that one real file, and
      both are now asserted. Verified on it: `seam-lib.ps1` is load-time, `entry-scaffold-lib.ps1` is not.
- [x] **A false claim the copy edit found**, in a comment of mine: the two readers were said to share one
      parse while each was doing its own read-and-parse. Repaired by making the claim true -- a
      destination memo keyed on the file's identity, the same shape and the same #1693 lesson as the
      walker's own -- rather than by weakening the comment. Asserted with the rewrite-at-the-same-path
      case that memo can fail on.
- [x] `fixture-lib-deps.tests.ps1` -- 49 asserts pass (was 26). The tree-wide pass reports 13 subjects,
      **0 findings**, 14 copied acting scripts and 1 declared opt-out.
- [x] A red the opt-out reader actually had: matched on raw text first, so this suite's own here-string
      fixtures counted and the tree-wide figure read **3** where the tree holds **1**. Comment tokens
      separate a declaration from data; the assert that pins it is written to that shape.
- [x] `script-contract.tests.ps1` -- 316 pass (was 311): the six dot-source shapes, that the default
      answer is unchanged, and that the memo tells the two questions apart at one timestamp.
- [x] `source-repo-guard.tests.ps1` 46, `shared-scripts.tests.ps1` 809 -- unchanged and green.
- [x] `check-plugin-integrity.ps1` -- 0 errors.
- [x] Cost, **one report call per fresh process**, three processes each -- which is how the suite
      actually uses it: **2162-2169 ms** before, **3073-3110 ms** after. The whole of the difference is
      parsing the twelve acting scripts nothing read before, which is the work rather than an overhead.
      For scale, the gate's slowest suites run 155-237s.
- [x] The first cost figure written here was **wrong, and wrong in the flattering direction**: three
      calls in ONE process, where the memos are warm from the second call on. Read that way the change
      looked like an improvement (731 ms to 471 ms) because the new destination memo serves runs 2 and 3.
      Nothing calls it twice in a process, so that figure measured a path this repo does not take.

### DEPLOY: fix/1924-fixture-dep-seed-from-script

The fixture dependency gate now reads the **script** a fixture copies, not only the libs -- closing the
one-word gap that let it report 26 green asserts while six suites were broken by exactly the class it
exists to catch. A copied script is held to its **load-time** dot-sources only, which is measured rather
than tidy: the wider rule reports ten subjects on a clean tree and all ten are conditional dependencies a
fixture is right not to carry.

**Score:** 3

#### What makes this deploy extra special

The widening was measured before it was written, and the measurement changed it twice -- first from every
dot-source to load-time ones, then from a raw text match to the parser's comment tokens, when the opt-out
reader counted this suite's own fixtures and reported 3 declarations where the tree holds 1. Both reds are
written into the file as asserts rather than into a commit message. And the opt-out it needed was
specified in advance, under #1693, by the docstring of the reader it sits beside: this is the first
instance of a case that was described two issues before it appeared.

**Score:** N/A

#### Pull Request

Seed the fixture dependency walk from the copied SCRIPT, not only the copied libs
