## fix/2264-hook-stdin-console-guard

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

Half A of #2264: the separable IsInputRedirected guard on guard-working-copy.ps1 and
guard-live-theme.ps1. The timeout half depends on #2249's mechanism, which is unlanded.

#### What this branch does NOT carry, and why

#2264 asks for two things and names them as separable itself: the missing **guard** on the two hooks
that lack one, and a **bound** on the four unbounded reads. This branch is the guard only.

The bound's mechanism did not exist in this tree when the branch was cut. #2264 stated it as settled
-- "the table is in `Get-HookPayloadRaw`'s docstring" -- and it was not there: `session-cache-lib.ps1`
still carried `ReadToEndAsync()` and the docstring carried no table. #2249 itself called that shape
"likely to work and was not tried". Its branch was one park commit touching only its own document,
claimed under another account an hour before this branch was cut. So the mechanism was somebody's live
work, and writing a second copy of it here would have been the duplicate this workflow's pickup checks
exist to prevent.

The two halves touch disjoint files, which is what made this branch safe to build alongside it rather
than a thing to ask about: #2249 owned `session-cache-lib.ps1`, `adopt-statusline.ps1` and
`show-progress.ps1`; this branch owns the two hooks and one new suite.

#### And #2249 LANDED while this branch was in flight, which is the most useful thing that happened

It merged as #2270 between this PR opening and `ship-pr` reaching the merge, and it replaced
`[Console]::In.ReadToEnd` with `[Console]::OpenStandardInput().CopyToAsync()` in all six of its sites.
The new suite's matcher knew only the old idiom, so its count fell from 10 to 4 and it **went red in
CI** -- while every local run before the push had been green.

That is the mechanism working rather than a defect in it, and the suite had said so in advance: the
floor's own comment named this exact event, argued that a new way of reading stdin needs the same
guard, and concluded that going red is how the suite says the matcher must learn the new shape instead
of quietly stopping at the old one. It was written as a prediction and collected as a measurement four
hours later. The matcher now names both shapes, and a third will do the same thing again.

**It also found a second thing nothing else would have.** #2249's shape puts its guard four RAW lines
above its read, with two lines of comment between them -- so the three-line window missed it even once
the pattern matched. The window now counts CODE lines rather than lines, which follows the code instead
of the commentary; in a tree where comment density varies far more than code density, that is the
measurement the heuristic actually wanted.

#### And one correction to #2264 itself, measured rather than argued

Its exposure table says `guard-live-theme.ps1`'s exposure is "a wedge blocks the tool call", and puts
`guard-working-copy.ps1` apart as the one whose `hooks.json` entry does not pipe the payload straight
in. Both entries are the same shape -- `p=$(cat); printf '%s' "$p" | powershell ...` -- so in both the
**shell** drains stdin to EOF and hands PowerShell a pipe it then closes. A never-closed harness
handle wedges that `cat`, not the `[Console]::In.ReadToEnd()` in either file.

That matters for the half this branch is not doing: the two hooks with the highest firing rates, and
therefore the whole of #2264's cost objection, are the two the bound would not repair. #2264 asked for
this to be checked per hook rather than assumed; it is checked, and the answer moves one row.

### CREATE

- [x] `guard-working-copy.ps1`: read stdin only where a handle is redirected, with the reason and the
      deliberate absence of a `try/catch` written down (it would convert #2217's fail-CLOSED wrapper
      path into a fail-open one).
- [x] `guard-live-theme.ps1`: the same guard, arguing separately why "no handle" is not the
      "unparseable payload" its own fail-towards-CHECKING rule is about.
- [x] `scripts/tests/hook-stdin-guard.tests.ps1`: a new suite that counts the family **out of the
      tree** instead of from a list, since a wrong hand-count is what produced both #2249 and #2264.

### TEST

- [x] The new suite: 15 passed, 0 failed. It reports 10 code sites across 7 source files (three are
      mirrored pairs), all guarded.
- [x] It goes RED on the defect: reverting `guard-working-copy.ps1`'s guard by hand gives
      `14 passed, 1 failed`, naming the file and line. Restored afterwards.
- [x] And red on the defect wearing a comment: `$raw = [Console]::In.ReadToEnd() <# fallback #>`
      is reported as an unguarded site rather than skipped as prose -- the classifier gap the code
      review found, closed and then proved with the exact shape it named.
- [x] The floor is the SITE count (10), not the file count (7), so one half of a mirrored pair
      losing its guard cannot pass.
- [x] A literal prefilter ahead of the per-line scan: same file set, same matcher, identical 10
      sites, and the suite drops from ~4.4s to 1.71s -- the cost check measured 75-80% of its
      wall-clock going into comment tracking over ~183,000 lines to find ten of them.
- [x] After #2249 landed mid-flight: the matcher names both read shapes, the window counts code
      lines, and the tree is back to 10 sites -- all guarded, 15/0.
- [x] And red on the NEW shape too: removing the guard above the `CopyToAsync` read in
      `session-cache-lib.ps1` gives `14 passed, 1 failed`, naming that file and line. Restored.
- [x] No regressions in the three suites that own this ground: `guard-working-copy.tests.ps1`
      32/0, `guard-live-theme.tests.ps1` 110/0, `hook-fail-closed.tests.ps1` 43/0.
- [x] Both hooks exit 0 on an empty payload, down each one's own documented degradation path.
- [x] The full lint gate and every suite, via `open-pr.ps1`.

#### The test gap, stated rather than papered over

Group 1 reads the SOURCE, because the behaviour is unreachable from a test process: the failing case
needs a child whose stdin is a live console, and a suite is spawned with stdin redirected -- since
#2233 the gate redirects every lane's stdin to an empty file deliberately. Guarded and unguarded both
return immediately there, so a behavioural assert would pass on the defect. What is asserted
behaviourally is the value the guard produces.

### DEPLOY: fix/2264-hook-stdin-console-guard

Running either of this workflow's two command guards by hand -- the first thing anybody does when a
git or a theme command is refused and they want to know why -- used to hang on line one with nothing
printed, waiting on a console read for a Ctrl+Z that is never coming. Both now read stdin only where
there is a handle to read, which is the guard the other five members of this family already carried.
A new suite counts that family out of the tree rather than from a list, because a wrong hand-count is
what let these two sit unguarded through two separate sweeps. It proved itself within hours: a
neighbouring branch changed how six of those sites read stdin, and the suite went red on the spot
rather than reporting the shrunken family as a clean one.

**Score:** 3

#### What makes this deploy extra special

A consumer of this workflow gets the same repair, and it reaches the guard protecting their live
Shopify theme as well as the one protecting their working copy. Nothing about how either guard judges
a command changes, so there is nothing to act on -- what changes is that the guard can be questioned
by hand on the machine it just refused something on.

**Score:** 2

#### Pull Request

Two PreToolUse guards no longer block on a console read when run by hand

