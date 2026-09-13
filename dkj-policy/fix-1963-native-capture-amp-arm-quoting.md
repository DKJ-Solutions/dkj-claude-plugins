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
- [x] `Test-NativeArgumentUnfaithful` + `Get-NativeArgumentUnfaithfulReason` in `native-capture-lib.ps1`
- [x] The guard in the `&` arm -- refuses, naming the index and the shape, never the value
- [x] Audit the call sites the report left unmeasured (its "Not measured" section)
- [x] Route `open-pr.ps1`'s `gh pr create` through `-Utf8` (candidate repair #1)
- [x] Mirror to both plugin copies via `build-shared-scripts.ps1`

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

The remaining ~430 `&`-arm sites are not audited by hand and do not need to be: the guard converts
that unmeasured risk into a loud refusal naming the index, which is what the report asked for and
could not get from a list.

### TEST

- [x] `native-capture.tests.ps1` -- 12 new asserts: the three unfaithful shapes, four faithful ones
      (an ordinary Windows path among them, so the predicate cannot refuse everyday arguments), the
      guard firing, its message naming the index, its message NOT echoing the value, and `-Utf8`
      succeeding on the same call
- [x] `native-capture.tests.ps1`: 165 pass, 0 fail
- [x] `check-plugin-integrity.ps1`: 0 errors
- [x] Full suite gate, as CI runs it

### DEPLOY: fix/1963-native-capture-amp-arm-quoting

`Invoke-NativeCapture`'s `&` arm left argv quoting to Windows PowerShell 5.1, which mis-delivers
three argument shapes: the empty string (dropped, shifting every later argument left), a value
containing a quote (the quote is lost and the following arguments are swallowed), and a value with
whitespace ending in a backslash (it escapes its own closing quote and absorbs the rest of the
command line). Measured against a real argv parser, 129 of 300 random argument sets arrived wrong.

That arm now refuses such an argument instead of mis-delivering it, naming the index and the shape
-- never the value, since an argument here can carry a token. And `open-pr`'s `gh pr create` is
routed through the `-Utf8` arm, which owns the tokeniser: a PR title carrying a quote or a trailing
backslash no longer swallows `--body-file`, `--repo` and every label into itself.

Everyone who runs this workflow gets the repair, and anybody writing a PR title with a quote in it
was silently exposed before. It is a wrong PR rather than a broken one -- created with a mangled
title and no body or labels -- which is why it went unnoticed rather than unreported.

**Score:** 3

#### What makes this deploy extra special

The reported repair was measured before it was built, and it failed. The issue offered pre-tokenising
the `&` arm as candidate #2; it is correct on every hand-picked example and still wrong on 7 of 300
fuzz cases, because PowerShell 5.1 re-processes a token that already carries quotes. A repair that
satisfies the report and is wrong would have shipped carrying a citation.

The silent-reroute alternative was declined for a stated reason rather than overlooked: the `-Utf8`
arm is provably correct here, but it is a different mechanism whose `Output` is an array of strings
rather than pipeline objects. Switching on the *content* of an argument would change the shape of a
caller's return value on exactly the days a title happened to contain a quote -- the data-dependent
surprise that `-Utf8` was itself introduced to end.

**Score:** 2

#### Pull Request

Invoke-NativeCapture's & arm refuses an argument Windows PowerShell 5.1 cannot pass faithfully

