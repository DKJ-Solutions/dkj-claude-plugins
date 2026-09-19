## docs/2157-2158-capture-comment-accuracy

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

Two prio-1 comment repairs from Victor's review of [#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155),
filed separately because neither was in that branch's diff. Comment and docstring text only -- no
executable line changes on this branch.

#### Both reports arrived with a reason that does not hold, and the repairs differ from what they proposed

Verified against the tree before either was written, per the `triage-inbound` rule that a report's
*reason* is checked as well as its symptom:

- **#2157** says that since #2155 "neither arm of `Invoke-NativeCapture` returns `ErrorRecord`s any
  more". It does not: #2155 is **still open**, and `Get-NativeOutputText`'s own docstring says in
  capitals that it "NORMALISES AT THE READER, NOT AT THE CAPTURE" -- the `&` arm still hands back
  `ErrorRecord`s. What is true is the report's *sharper* half, which it states itself: this call site
  is always bounded, so it always routes to the Start-Process arm, whose `Output` is an array of
  strings.
- **#2157's suggested repair is false too.** It proposes keeping the clause that "`-match` against an
  array returns the matching elements rather than a boolean, which is reason enough on its own". There
  is no `-match` at that line: `Get-GitPushFailureMessage` takes `[string]$Output`, so an array is
  coerced before any match runs. Adopting the suggestion verbatim would have replaced one false
  statement with another -- and given it a citation.
- **#2158** records as *inferred* that the duplication was deliberate, and says "nothing in either file
  says so". One file already does: `Get-NativeLineText`'s docstring names the separation and points at
  `shopify-cli-lib.ps1`'s header, which argues it at length with two measured reasons. So the repair is
  the narrow half of what the issue anticipated -- the reciprocal note, in the one docstring that was
  missing it -- not a unification and not a pair of new notes.

#### And #2157's own target contradicted the comment 30 lines above it

`Invoke-GitPark` already said, over the bound: "-TimeoutSeconds routes into the Start-Process arm,
which returns an ARRAY OF STRINGS rather than the & operator's objects." Thirty lines down the same
function said the array "can hold ErrorRecords as well as strings". Both were load-bearing for a reader
deciding whether the `Out-String` flatten still matters, and they cannot both be true.

### CREATE

- [x] `scripts/lib/park-lib.ps1` -- replace the push-failure comment with what the flatten is actually
      for: a faithful multi-line rendering for a `[string]`-typed parameter, rather than PowerShell's
      `$OFS` coercion fusing git's lines onto one. Name both retired claims, so a reader meeting the old
      wording elsewhere can tell it was retired rather than copied wrong.
- [x] Same file -- say why it stays `Out-String` and does **not** become `Get-NativeOutputText`: the
      flattened text is matched and never printed (all three arms of `Get-GitPushFailureMessage` return
      a fixed sentence and none interpolates `$Output`), so no reader exists for an exception dump to
      reach. That is the question the next person will ask, given #2154 added the helper for this shape.
- [x] Same file -- the deferral 30 lines above pointed at "the array reason the comment below gives",
      which is no longer the reason given. Now points at the reason without naming it.
- [x] `scripts/lib/shopify-cli-lib.ps1` -- write the trade into `Get-ShopifyLineText`'s docstring: the
      two measured reasons this lib depends on nothing, the two separate mirror sets a shared source
      would have to land in, and the cost nothing enforces -- change one body, change both.
- [x] `scripts/lib/native-capture-lib.ps1` -- cite #2158 on the existing note in `Get-NativeLineText`
      and point at the sibling docstring, so the decision is reachable from either end.
- [x] `scripts/sync/build-shared-scripts.ps1` -- four mirrors regenerated (`native-capture-lib` into
      `dkj-policy` and `dkj-subagents-shopify`, `park-lib` into `dkj-policy`, `shopify-cli-lib` into
      `dkj-subagents-shopify`).

### TEST

- [x] `check-plugin-integrity.ps1` + every suite, via `open-pr.ps1`'s gate -- including check 27
      (`[script-ascii]`), which the new comment text has to satisfy, and the shared-scripts drift lint
      over the four regenerated mirrors.
- [~] No new assert. Dropped deliberately: the diff changes no executable line, and there is nothing a
      test can hold a comment to. Recorded as a test gap rather than covered with a string match on
      comment text, which would fail on the next honest reword.

### DEPLOY: docs/2157-2158-capture-comment-accuracy

Two comments in the capture family now say something true. `Invoke-GitPark` told a reader that its
captured push output "can hold ErrorRecords as well as strings" and that `-match` against that array
would return elements rather than a boolean -- while the comment thirty lines above, in the same
function, correctly said the bound routes into the Start-Process arm and `Output` comes back as an
array of strings. Neither claim survived being checked: the arm produces strings here, and the `-match`
is inside `Get-GitPushFailureMessage`, whose `$Output` is `[string]`-typed, so an array never reaches
it as an array. The replacement says what the `Out-String` flatten is still for -- rendering the lines
*as lines*, where `$OFS` coercion would fuse them with spaces -- and why it deliberately is not
`Get-NativeOutputText`, the helper [#2154](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2154)
added for exactly this shape: the flattened text here is matched and never printed, so there is no
reader for an exception dump to reach.

**Both issues proposed a repair that was itself wrong, and neither was built as filed.**
[#2157](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2157) rested on
[#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155) having closed the `ErrorRecord`
class library-wide -- it is still open, and the `&` arm still produces them -- and its suggested
rewording kept the `-match` clause that does not apply at that line.
[#2158](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2158) recorded the deliberate
`Get-NativeLineText` / `Get-ShopifyLineText` duplication as *inferred*, with "nothing in either file
says so"; `Get-NativeLineText` already said it, so what landed is the reciprocal note in the docstring
that was missing it, with the trade written out -- two libs that depend on nothing, two separate mirror
sets a shared eight-line source would have to land in, and the cost that nothing enforces the pair
staying in step.

**Score:** 1

#### What makes this deploy extra special

Nothing here changes what any consumer's scripts do -- the diff has no executable line in it. The three
files ship in `dkj-policy` and `dkj-subagents-shopify`, so the corrected text does reach every consuming
repo at the next release, and the reader it is worth something to is the one who opens either lib to
decide whether a flatten or a duplicated helper is still load-bearing. That reader was previously handed
a contradiction inside one function and a decision recorded in only one of the two files it governs.

**Score:** 1

#### Pull Request

Correct two stale comments about capture Output shape

Plugins: dkj-policy, dkj-subagents-shopify
