## fix/2155-normalise-capture-output

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

#### The decision this branch carries out

#2155 was filed as a decision rather than a repair: should `Invoke-NativeCapture`'s `&` arm normalise
`Output` to strings? Dave decided **yes**, September 19, 2026, on three things the issue did not have.

**One: the premise of #2155 was not in the tree WHEN THIS BRANCH OPENED, and stopped being true while
it was open.** Recorded in both halves rather than rewritten, because the second half is the more
useful one: #2154 landed on `main` mid-branch, from another session, and its repair arrived carrying a
`Get-NativeLineText` **byte-identical in name and body** to the one written here -- two sessions, the
same function, discovered at the merge. Neither pickup check could have caught it: #2154 was a
different issue with its own assignee, and its branch was a bare `park:` scaffold, so the parked-fix
scan on #2155 had nothing to match. Reconciled by keeping both layers -- their `Get-NativeOutputText`
at the reader, this decision's normalisation at the capture -- and by rewriting the docstring paragraph
in which their helper argued AGAINST the decision that has since been taken. What follows was the state
at open: the issue said #2154's repair had already added `Get-NativeOutputText` and moved seven renders
in `prune-merged.ps1` onto it, and it had not -- that function existed nowhere, and
`origin/fix/2154-flatten-refusal-reason` was a single `park:` commit carrying only its branch document.

**Two: the current shape is measurably wrong, not merely inconsistent.** Measured here against a
`powershell.exe` child writing three stderr lines, the middle one empty:

- `Output` holds an `ErrorRecord` per line, and `$res.Output | Out-String` -- the idiom at ~60 sites --
  renders the first one as a full PowerShell exception dump naming `native-capture-lib.ps1:1177`, the
  tilde run, `CategoryInfo` and `FullyQualifiedErrorId`.
- The EMPTY line stringifies as the literal `System.Management.Automation.RemoteException`, because an
  `ErrorRecord`'s `ToString()` falls back to the type name when its exception message is empty.
- The `-Utf8` arm returns the same three lines as plain strings, the middle one empty.

**Three: this tree had already taken the same decision, for a lib mirrored the same way.**
`scripts/lib/shopify-cli-lib.ps1` states it outright -- *"OUTPUT IS STRINGS, NEVER ErrorRecords, and
that is a repair rather than a preference"* -- with the same measured cause and the normaliser already
written as `Get-ShopifyLineText`. That moves the consumer objection #2155 weighed: the exposure is not
*"calls that work today start failing"* but *"a consumer parsing the wrapper's noise is parsing a
defect"*, which is the #1966 test coming back the same way it did there.

#### What was verified of the issue's own measurements

- **Holds:** no caller reads `.TargetObject`, `.Exception` or `-is [ErrorRecord]` off a **capture's**
  `Output`. `scripts/lib/repo-root-lib.ps1:115` does test the element type, but on a direct `& git`
  outside this lib -- it is not a caller of this function and is not affected.
- **Holds:** the `-Utf8` arm returns strings.
- **Corrected:** the `$res.Output | Out-String` count is 60 in `scripts/**`, not 63.
- **Answered rather than performed:** the issue named an audit of "which of the remaining ~56 sites can
  actually render a failure" as the cheap next step. Normalising at the source makes that audit moot --
  every site renders correctly now, whether or not it can fail -- so it is deliberately not done. 223
  of the 256 `Invoke-NativeCapture` call sites outside the lib and the suites use the `&` arm.

#### The one thing deliberately NOT changed

The **container**. Wrapping the pipeline in `@()` would have been the obvious spelling and would have
turned every single-line capture into a 1-element array -- a second behaviour change riding along on a
decision that was only about the element type. Assigning a pipeline follows exactly the same unrolling
rule the bare `&` operator followed here: `$null` / scalar / array. Three asserts in the suite refuse
the other spelling.

### CREATE

- [x] `Get-NativeLineText` added to `scripts/lib/native-capture-lib.ps1` -- `TargetObject` first
      (the raw stderr line, string-typed, empty string and all), `Exception.Message` as the fallback.
      Named one word over from its sibling `Get-ShopifyLineText`, so the kinship is visible.
- [x] Both branches of the `&` arm normalise through it in the pipeline -- IN the pipeline, so the
      container is untouched. (`arm` is the lib's own word for the `&` / `-Utf8` split; `-DiscardStderr`
      is a branch of the first, not a third arm.)
- [x] `Get-NativeOutputText` was deliberately NOT added here -- and then arrived on `main` from #2154
      mid-branch, so it is KEPT rather than removed. It is not redundant after this change: it trims
      and normalises line endings, which `Out-String`'s console-width padding does not, and it is the
      only correct reader for an `Output` that came from an older plugin release where the `&` arm had
      not been repaired yet. Its docstring argued AGAINST this decision while the decision was open;
      that paragraph is rewritten rather than left, because an argument for a road not taken reads as
      current policy once the fork is behind you.
- [x] #2154's own suite block repaired for the same reason: it proved the helper's worth by asserting
      the defect still reproduced on a capture, which #2155 makes false. The contrast now comes from a
      raw `& git ... 2>&1`, which is both still true and the exact shape the helper still exists for --
      so the block proves more than it did, not less.
- [x] Four passages in the lib that argued FROM the element-type difference updated rather than left
      to go quietly stale -- the `Output` docstring, the `-Utf8` mechanism note, the `-TimeoutSeconds`
      consequence note, and #1963's "a silent reroute is not the cheap alternative" block, whose
      strongest half this change removes. That last one says so explicitly instead of dropping it.
- [x] The two mirrors rebuilt via `scripts/sync/build-shared-scripts.ps1` (`dkj-policy`,
      `dkj-subagents-shopify`).

### TEST

- [x] `scripts/tests/native-capture.tests.ps1` -- two new blocks: the element type on every entry, the
      empty line surviving as empty, the caller's rendered text carrying the command's words and none
      of the five tells of wrapper noise, the container held at `$null` / scalar / array,
      `-DiscardStderr` still dropping stderr through the pipeline, and `Get-NativeLineText` itself
      including the `TargetObject`-first order and its fallback. **256 pass, 0 fail.**
- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors.
- [x] #2154's own site reproduced against the repaired lib in a throwaway repo: a refused
      `git branch -d` now renders git's three lines (`error: the branch ... is not fully merged`
      plus two hints) where it rendered the exception dump before.
- [x] Exit code still measured through the normalising pipeline: 100/100 runs of `cmd /c exit 7`.
- [x] The #1966 argument refusal still fires on the three undeliverable shapes.
- [x] Reviewed in parallel by Victor #19, Edith #17 and Sebastian #23. No correctness and no security
      findings; two review findings were applied on the branch -- the exit code asserted on the
      zero-object pipeline (the one shape where a reader would most expect `$LASTEXITCODE` to be lost),
      and six copy-edit corrections including a parenthetical that dated `Get-ShopifyLineText`'s repair
      to #2155 and a comment naming four tells where the code checks five. Two findings outside this
      diff were filed rather than fixed here: #2157 (`park-lib`'s now-stale flattening rationale) and
      #2158 (`Get-NativeLineText` and `Get-ShopifyLineText` are the same function in two libs that do
      not depend on each other -- a dependency decision, not a cleanup).

### DEPLOY: fix/2155-normalise-capture-output

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
