## fix/1956-shared-discard-unwrap

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

#### What #1956 filed, and the one question it left open

Checks 35 `[fixture-git]` and 41 `[fixture-script]` in `scripts/lint/check-plugin-integrity.ps1` each
carried their own implementation of the same two rules: climb out of any wrapping to the outermost
pipeline a call sits in, then ask whether the result is discarded. Check 41's own comment said so in as
many words -- *"exactly as check 35 does and for the same reason"*.

The issue deliberately did not decide the shape, and named the thing to settle first: check 35 tracks a
`[void]` cast through the climb and check 41 does not, so *"whoever picks it up should check whether that
difference is real or just how each was written."*

#### It is real, and it was a live false negative

Measured against the real check before anything was changed, with
`[void](Write-FixtureScriptSummary ...)` inside a function:

| position of the cast-away call | findings |
|---|---|
| as the function's **last** statement | **0** -- cleared as a read |
| one line further up | 1 -- reported |

Check 41 climbed straight through the `ConvertExpressionAst` without noticing the cast, so the call
reached the implicit-return arm and was cleared as PowerShell's last-statement-is-the-value rule -- while
`[void]` is precisely what stops a last statement being a return value. The same call, the same cast, two
answers depending on what followed it.

That is check 35's own recorded lesson -- *"a check whose three arms disagree about wrapping teaches the shape
that gets past it"* -- arriving one level up, which is exactly what #1956 predicted would happen with two
copies.

### CREATE

- [x] `Get-DiscardedOuterPipeline` added beside `Get-EnclosingFunction`, returning the outermost
      pipeline, whether the result is `Discarded`, and whether a `[void]` cast was crossed
- [x] check 35 rewired onto it -- the climb and all three discard spellings now come from the function
- [x] check 41 rewired onto it, and the discard is asked FIRST rather than subtracted from the arms
      afterwards, because the implicit-return arm cannot tell a cast-away last statement from a
      handed-back one

### TEST

- [x] scenario 78b pins the repaired arm in both positions -- a `[void]` cast is a discard as a
      function's last statement and one line further up, and the two have to agree
- [x] the lint gate is green and both coverage lines report the same counts as before the extraction
      (`[fixture-git]` 108 files / 0 findings, `[fixture-script]` 108 files / 7 wired / 0 findings), so
      the change is behaviour-preserving on the real tree apart from the repaired arm
- [x] all suites green

### DEPLOY: fix/1956-shared-discard-unwrap

Two checks in the plugin-integrity gate each carried their own copy of the same rule -- climb out of any
wrapping, then ask whether the result is thrown away. That rule had already been repaired once inside
check 35, whose header records the bug: only the `[void]` arm walked out of `(...)`, so
`$null = (& git ...)` and `(& git ...) | Out-Null` were both silently skipped, and it draws the lesson
that **a check whose three arms disagree about wrapping teaches the shape that gets past it**.

With two copies that lesson applies one level up, and the second copy had already drifted. Check 41
climbed through a `[void]` cast without noticing one, so `[void](Write-FixtureScriptSummary ...)`
standing as a function's last statement was cleared as an implicit return -- 0 findings, against 1 for
the identical call one line further up. A discarded verdict is the failure that check exists to catch,
and this was it wearing a cast.

Both now call one `Get-DiscardedOuterPipeline`, so the next repair to the rule is made once. On the real
tree nothing else moves: both coverage lines report exactly the counts they did before.

**Score:** 2

#### What makes this deploy extra special

Nothing here ships to a consumer. `scripts/lint/` is not mirrored into any plugin and the checks read
only this repo's own tree, so the reader served is whoever next edits either check.

**Score:** N/A

#### Pull Request

The discard/unwrap rule is one function, not a copy per check
