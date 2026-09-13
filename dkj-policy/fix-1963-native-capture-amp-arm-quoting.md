## fix/1963-native-capture-amp-arm-quoting

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

The & arm leaves argv quoting to Windows PowerShell 5.1, which corrupts three argument shapes -- an empty string, one containing a quote, and one with whitespace ending in a backslash. Give that arm a guard that refuses such an argument by name, and route open-pr's gh pr create through the -Utf8 arm, which already owns the tokeniser.

#### What the report got right, and the one thing it got wrong

The symptom stands and the mechanism is exactly as filed. What does NOT stand is the scope: the
report recorded an embedded quote as "escaped correctly and cannot re-open an argv boundary, so this
corrupts the one invocation rather than smuggling attacker-chosen flags". That is true of the
Start-Process arm, whose tokeniser does escape it -- and false of the arm the report is about.

Measured here against a compiled C# probe printing each argv element with its length. Three shapes
are mis-delivered by the `&` arm, not one:

| Value | `&` arm delivers | `-Utf8` arm delivers |
|---|---|---|
| `a b\` + `next` | `[a b" next]` | `[a b\] [next]` |
| `has"quote` + `next` | `[hasquote next]` | `[has"quote] [next]` |
| `` (empty) + `next` | `[next]` | `[] [next]` |

So an embedded quote swallows the following arguments too, and the empty string is dropped
entirely -- which shifts every later argument one position left.

### CREATE

- [x] Read the two arms and reproduce the report's case against a real argv parser
- [x] Measure the true scope -- 300 random argument sets: 129 mis-delivered on the `&` arm, 0 on `-Utf8`
- [x] Test the report's own candidate repair #2 (pre-tokenise, then hand to `&`) -- **7 of 300 still
      wrong**, so it is measurably not a repair; declined with the measurement rather than on taste
- [x] Derive the exact predicate and validate it: 800 cases, 190 broken, 0 false positives, 0 false negatives
- [x] Audit the call sites the report left unmeasured (its "Not measured" section)
- [x] Route `open-pr.ps1`'s `gh pr create` through `-Utf8` (candidate repair #1) -- **the repair**
- [~] A tree-wide guard refusing the three shapes -- built, measured, and **withdrawn**; filed as
      #1966 with every measurement. See below for why
- [x] Record the measurement in the lib itself, at the arm it is about
- [x] Mirror to both plugin copies via `build-shared-scripts.ps1`

#### Why the guard was withdrawn rather than shipped

It was built and it works: the three shapes are refused, by index and shape, never by value. It came
out again for a reason that only showed up once it ran.

**This lib is mirrored into the plugins and runs in consumers' repos.** A throw is therefore a
behaviour change for every consumer's existing scripts on their next plugin update -- a decision of a
different size than the prio-2 defect that surfaced it. Two things measured while it was in place
back that up:

- **It fires on legitimate test fixtures.** `ref-print-lib.tests.ps1` creates a branch whose name
  carries a quote, precisely to prove git accepts it. With the guard that fixture cannot run.
- **It catches almost nothing else here.** Instrumented across ten suites, the guard produced exactly
  **one** hit -- that fixture. The production audit below found one exposed site, and it is repaired
  by `-Utf8` directly.

So the class stays documented at the arm it belongs to, and the guard is #1966's to decide.

#### The call-site audit the report left open

The report named `open-pr.ps1:2122` and said which other sites take a caller-influenceable argument
was not measured. It is now, over every `&`-arm call passing a message, title or body:

- `open-pr.ps1:2122` -- `--title $prTitle`. **The one genuinely exposed site**, and the one repaired.
  Free text: a changelog heading, or since #1962 a bare commit subject.
- `fold-changelog-entry.ps1:1192` -- `commit -m $message`. Safe in practice: composed from branch
  names and PR numbers, and a branch name can hold none of the three shapes.
- `cut-release.ps1:1381,1385` -- literal messages.
- `park-lib.ps1:648` and `verify-resolved-issues.ps1:148` -- already use `-F`/`--body-file`, the
  file-based pattern that sidesteps argv entirely.

The remaining ~430 `&`-arm sites are not audited by hand. That residual risk is what #1966 is for;
this branch repairs the one site that was measured exposed and records the class where the next
reader of that arm will meet it.

### TEST

- [x] `native-capture.tests.ps1` -- four asserts pinning the repair: exactly one `gh pr create`
      invocation, it carries `-Utf8`, and it is still the line passing `$prTitle`. A source assert
      rather than a live call, because the alternative is creating a real pull request
- [x] `shared-scripts.tests.ps1` -- its `gh pr create` assert pinned the flags between the cmdlet and
      `-FilePath`, so it failed on the `-Utf8` it should have wanted. Widened to what it is actually
      for (the call goes through the helper), plus a second assert naming `-Utf8` outright
- [x] `native-capture.tests.ps1`: 156 pass, 0 fail
- [x] `shared-scripts.tests.ps1`: 810 pass, 0 fail
- [x] `ref-print-lib`, `script-contract`, `pr-issues`: pass
- [x] `check-plugin-integrity.ps1`: 0 errors

- [x] The full gate via `open-pr.ps1`: **all 103 suites passed in 153s (30 lanes)**

#### The 45-failure run, and why it is not in the list above

An earlier local run of all 103 suites reported 45 failures, and none of them were this branch's. It
was driven by hand at 32 lanes on one 18-core machine -- CI splits the same pool across four shards --
and a number of these suites calibrate their timeouts against machine load by design, so the
oversubscription is the finding. `open-pr`'s own gate ran the same 103 at 30 lanes and passed all of
them, which is the run cited above.

Two hours went into establishing that, and the cheap check existed the whole time: **instrumenting
the guard showed one hit across ten of the "failing" suites**, which already said the failures were
not the change. Take the baseline before reading a wall of red, not after.

### DEPLOY: fix/1963-native-capture-amp-arm-quoting

`Invoke-NativeCapture`'s `&` arm left argv quoting to Windows PowerShell 5.1, which mis-delivers
three argument shapes: the empty string (dropped, shifting every later argument left), a value
containing a quote (the quote is lost and the following arguments are swallowed), and a value with
whitespace ending in a backslash (it escapes its own closing quote and absorbs the rest of the
command line). Measured against a real argv parser, 129 of 300 random argument sets arrived wrong.

`open-pr`'s `gh pr create` is now routed through the `-Utf8` arm, which quotes its arguments itself:
a PR title carrying a quote or a trailing backslash no longer swallows `--body-file`, `--repo` and
every label into the title. That is the one call site measured exposed -- `$prTitle` is free text, a
changelog heading or (since #1962) a bare commit subject, and it is the only argument of that call a
person writes. The three shapes are now documented at the arm itself, so the next reader of it meets
the measurement rather than the assumption.

Anybody writing a PR title with a quote in it was silently exposed before, and the failure is a
*wrong* pull request rather than a broken one -- created with a mangled title and no body or labels
-- which is why it went unnoticed rather than unreported.

**Score:** 3

#### What makes this deploy extra special

**Both of the report's own candidate repairs were measured before either was built, and one of them
failed.** Candidate #2 -- give the `&` arm the same tokeniser -- is correct on every hand-picked
example and still wrong on 7 of 300 fuzz cases, because PowerShell 5.1 re-processes a token that
already carries quotes. Shipping it would have satisfied the report and been wrong, with a citation
attached.

**And the report's own scoping was off in the safe-sounding direction.** It recorded an embedded
quote as "escaped correctly and cannot re-open an argv boundary". That is true of the Start-Process
arm and false of the arm the report is about: a quote both loses itself and swallows what follows.
The empty string, unmentioned, is dropped outright. Verifying the *reason* rather than only the
symptom is what turned one shape into three.

**A larger repair was built, run, and withdrawn.** A guard refusing all three shapes at the arm makes
the class impossible rather than documented -- but this lib ships to consumers, so a throw changes
their scripts' behaviour on a plugin update, and instrumenting it here produced exactly one hit, in a
test fixture that uses a hostile branch name on purpose. It is filed as #1966 with every measurement
rather than carried in a prio-2 fix.

**Score:** 2

#### Pull Request

open-pr passes the PR title through the arm that quotes it, so a title with a quote cannot swallow the flags after it

