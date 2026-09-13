## feat/1966-native-capture-argv-guard

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

#### What this branch is for

[#1966](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1966) -- build the guard
[#1963](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1963) measured and deliberately
withdrew. `Invoke-NativeCapture`'s `&` arm leaves argv quoting to Windows PowerShell 5.1, and three
argument shapes do not survive it: the empty string is dropped, a value carrying `"` loses the quote
and swallows what follows, and whitespace plus a trailing `\` escapes the closing quote PowerShell
added. #1963 repaired the one call site it had measured exposed and left ~430 others unaudited.

#### The measurement, re-taken here rather than cited

#1963's figures were reproduced independently on September 14, 2026, against a compiled C# probe that
prints each argv element with its length -- because a report's numbers are the reporter's inference and
the repair is built on the predicate, not on the story.

- the three shapes confirmed, each with the exact mis-delivery the issue names;
- the predicate -- empty, **or** contains `"`, **or** contains whitespace and ends in `\` -- fuzzed over
  **800 random argument sets**: 239 predicted broken, 239 actually broken, **0 false positives and 0
  false negatives**;
- a trailing backslash *without* whitespace confirmed deliverable, which is why that clause is one and
  not two -- `C:\repo\` is an everyday argument.

#### The objection #1963 left open turned out to run the other way

#1963 recorded that a guard "fires on legitimate test fixtures" -- `ref-print-lib.tests.ps1` passes a
branch name carrying a quote to `git check-ref-format` to prove git accepts it -- and treated that as an
exception the guard would need.

Measured rather than assumed, and it is not an exception: **that call was already broken.** Through the
`&` arm, `fix/a"b` reaches git as `fix/ab`, and git echoes `fix/ab` back at exit 0. The assert proving
git accepts a quote in a ref name had never once tested a quote. The fixture's repair is `-Utf8`, which
makes it test what it claims -- and the premise was re-measured under that faithful delivery: all
seventeen hostile names are genuinely git-legal, so every assert stays green and one of them becomes
real. **A false green is what this refusal turns red**, which is the argument for shipping it rather
than an objection to it.

#### Why it is safe to change behaviour for consumers

This lib is mirrored into the plugins and runs in consumers' repos, which is what made #1963 withdraw
the guard. The answer is that it fires **only on arguments that were already being mis-delivered**: no
consumer call that works today starts throwing. What changes is that a call which was silently handing
the child a different command line now says so.

#### What is deliberately NOT built

- **No escape valve.** The objection that would have needed one dissolved (above), and there is no
  legitimate caller of the `&` arm that wants an undeliverable argument -- by definition it cannot have
  what it asked for.
- **No silent reroute to `-Utf8`.** That arm returns `Output` as an array of strings where this one
  returns pipeline objects, so switching on an argument's *content* would change a caller's result shape
  on exactly the days a title happened to carry a quote -- the data-dependent surprise `-Utf8` exists to
  end.
- **#1963's candidate repair #2 is recorded as measurably wrong** so it is not re-proposed: giving the
  `&` arm the same tokeniser is right on every hand-picked example and still wrong on 7/300, because
  PowerShell 5.1 re-processes a token that already carries quotes.

### CREATE

- [x] `Get-NativeArgumentDefect` in `scripts/lib/native-capture-lib.ps1` -- the pure predicate, one value
      in, the shape name out (`empty` / `quote` / `trailing-backslash`) or `''` where it is deliverable.
- [x] `Get-NativeArgumentRefusal` -- pure, the whole argument list in, the refusal message out. Names the
      **index and the shape and never the value** (#1313: an argument here can carry a token or a remote
      URL, and nobody redacts what we compose), and points at `-Utf8` and the file-based idiom.
- [x] `Invoke-NativeCapture`'s `&` arm throws it, ahead of the EAP dance so a refused call touches
      nothing.
- [x] The withdrawal note in that arm replaced with the decision, the safety argument, and the two
      alternatives recorded as wrong.
- [x] `scripts/tests/ref-print-lib.tests.ps1` -- `Test-GitAcceptsRef` routed through `-Utf8`, with the
      measurement that it was asking git about the wrong string.
- [x] Plugin mirrors regenerated (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `native-capture.tests.ps1`: the classification table including every near-miss that must **not** be
      refused; the refusal message asserted to name index and shape and to carry neither half of a
      token-bearing URL; the `&` arm asserted to throw on each of the three shapes, **with `-Utf8`
      asserted to carry that same value intact beside each one** -- a guard whose remedy does not work is
      a wall.
- [x] No false negatives, measured against a real argv parser rather than against the predicate itself:
      every value the predicate calls deliverable is put through the `&` arm for real and must come back
      byte-identical. The mirror direction cannot be measured post-guard by construction -- the arm now
      throws on exactly those -- and the classification table is what pins it; that limit is stated in
      the suite rather than glossed.
- [x] `native-capture.tests.ps1` -- 199 pass, 0 fail.
- [x] `ref-print-lib.tests.ps1` -- 444 pass, 0 fail.
- [x] `check-plugin-integrity.ps1` -- 0 errors.
- [x] Every suite in `scripts/tests/` run as the sweep for call sites the guard now refuses.

### DEPLOY: feat/1966-native-capture-argv-guard

`Invoke-NativeCapture`'s `&` arm now **refuses** the three argument shapes Windows PowerShell 5.1
cannot hand to a child faithfully -- the empty string, a value containing `"`, and whitespace plus a
trailing `\` -- instead of silently handing the child a different command line at exit code 0. The
refusal names the argument's index and shape, never its value, and points at `-Utf8`.

The predicate is exact rather than cautious: fuzzed over 800 random argument sets against a real argv
parser, 0 false positives and 0 false negatives. A trailing backslash *without* whitespace stays
deliverable, so ordinary path arguments are untouched.

It fires only on arguments that were **already** being mis-delivered, which is what makes it safe to
ship to consumers: no call that works today starts throwing. This repo's own suite carried one such
call -- `ref-print-lib.tests.ps1` was asking git whether `fix/ab` is a legal ref name while claiming to
ask about `fix/a"b`, and passing -- so the class is demonstrated rather than hypothetical. That fixture
now goes through `-Utf8` and tests what it claims.

**Score:** 3

#### What makes this deploy extra special

It closes a class rather than a case. #1963 repaired the one call site it could measure and left ~430
unaudited; this converts that unmeasured risk into a loud refusal at the one place every one of them
goes through. And the objection that had kept it withdrawn -- that it would break legitimate hostile-name
fixtures -- was found on measurement to be a false green in this repo's own suite, so building the guard
repaired a test that had never tested its subject.

**Score:** 2

#### Pull Request

Refuse the three argv shapes the & arm cannot pass faithfully
