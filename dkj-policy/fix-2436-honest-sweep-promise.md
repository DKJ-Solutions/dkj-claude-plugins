## fix/2436-honest-sweep-promise

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

Step 1 of #2436's plan: ship-pr stops promising the merge-on-green sweep for a PR the sweep will
refuse on the executed-path rule (#2338). Steps 2 and 3 are their own subjects and are filed as
#2438 (make the stranded state visible after the session dies) and #2437 (run ship-pr from a
trusted trunk tree). Step 4's tests ride along with step 1.

### CREATE

- [x] `Get-MergeOnGreenSweepRefusal` in `merge-on-green-lib.ps1`: parses `gh pr view --json
      files,changedFiles` and returns `Get-MergeOnGreenExecutedPathHit`'s answer. One predicate,
      fail-closed on an unreadable payload like the picker.
- [x] `ship-pr.ps1` reads it once before arming. On a refusal the arm message and the CI-refusal
      message say the sweep will NOT finish it and to re-run ship-pr from a session. The PR is still
      armed, because the label is the record that a ship began.
- [x] Plugin mirrors copied byte-identical.

### TEST

- [x] `merge-on-green-lib.tests.ps1`: the helper and the picker agree on #2433's shape, #2435's
      shape, a docs PR and a truncated list; empty or non-JSON payloads refuse; structural asserts
      that both promise sites branch on the refusal and that it is read before the arm. 122/122 pass.
- [x] Live check against real payloads: #2433 returns the exact reason the sweep logged, and #2434
      returns none.

### DEPLOY: fix/2436-honest-sweep-promise

`ship-pr` now promises that the merge-on-green sweep will finish a PR only when the sweep can. For a
PR whose diff touches code the runner would execute from the branch, it names that path at arm time
and says that, if this run does not finish, somebody has to re-run ship-pr from a session. It is
read through the same executed-path predicate the sweep refuses on (#2338), so the two cannot disagree (#2436).

**Score:** 2

#### What makes this deploy extra special

Anyone who runs `ship-pr` on a PR that changes scripts or workflows is now told that the automatic
backstop will not cover it, so a green PR no longer sits unmerged while it looks owned.

**Score:** 2

#### Pull Request

ship-pr promises the merge-on-green sweep only where the sweep will not refuse it

Plugins: dkj-policy

