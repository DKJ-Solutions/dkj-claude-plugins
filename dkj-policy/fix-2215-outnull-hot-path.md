## fix/2215-outnull-hot-path

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

Issue #2215 filed the `| Out-Null` idiom as a cost on the always-on path and left three decisions
open: which sites, which replacement, and whether a lint gate is owed. This branch answers the first
two by measurement and declines the third with its reason.

**Three of the issue's own figures did not survive verification, and the scope changed with them.**
The counter-example count (`1` existing `[void]` site) is 39; two of the three functions it named as
hot-path candidates (`Get-SpecialistFiles`, `Get-LensDirCandidates`) carry no `.Add()` and no
`Out-Null` at all; and its `~30 pipelines per call` was written against the pre-#2199 inline walk,
which #2199 has since promoted into `Get-ConsumerLensPaths`. The 107-site count is correct.

**And the issue looked at the wrong method.** It grepped `.Add(...) | Out-Null` and so never saw
`$buffer.Append(...) | Out-Null` in `Get-ProseParagraphUnits`, which runs **per line of every corpus
document** -- ~21,000 lines over 973,000 characters here. That single pair of sites, not the `.Add()`
ones, is where the time actually was.

### CREATE

- [x] Verify the report against the tree before repairing it -- three figures corrected, scope re-derived.
- [x] Replace the idiom at the 14 sites on the always-on path, in `scripts/lib/entry-scaffold-lib.ps1`:
      the corpus walk (`Get-ConsumerProseDocuments`, `Get-ConsumerLensPaths`) and the detectors it
      feeds (`Get-ProseParagraphUnits`, `Get-SupremacyDeclaration`, `Get-RetiredDocNameMention`).
- [x] Use `[void]`, not `$null =` or `.AddRange()` -- see TEST for why.
- [x] Mirror to `plugins/dkj-policy/` via `scripts/sync/build-shared-scripts.ps1` (drift lint).
- [~] No lint rule added. Dropped deliberately -- 106 remaining sites would be 106 findings on day
      one, all true and nearly all cold, which is the shape `check-plugin-integrity` already declined
      once (the stale-path check, 124 findings all false). A gate scoped to "the always-on path" would
      have to encode which functions those are, and that set has moved twice in three weeks (#2188,
      #2199). Left to #2215's own decision 3 if Dave wants it revisited.

### TEST

**Measured on this repo's own tree, A/B/A (baseline, patched, baseline again) to rule out drift.
Corpus: 34-36 documents, 973,293 characters, 2,097 paragraph units.**

| path | baseline A | patched | baseline B | change |
|---|---|---|---|---|
| both detectors, the real session-start work | 1,370.6 ms | **393.4 ms** | 1,272.1 ms | **-70%, 3.4x** |
| paragraph parse alone (`Get-ProseParagraphUnits`) | 1,649.1 ms | **248.1 ms** | 1,725.6 ms | **-85%, 6.7x** |
| corpus assembly alone (`Get-ConsumerProseDocuments`) | 79.2 ms | **57.4 ms** | 79.9 ms | **-28%** |

**Output is byte-identical on every path**, checked rather than assumed: both detectors' full findings
(rel, line, match, text) over the whole corpus diff clean, as do the corpus path list (36 paths) and
the paragraph-unit count and segment maps.

**Why `[void]` and not the alternatives.** Measured in-process, 300 iterations x 3, appending 29
strings to a `List[string]`: `| Out-Null` 5.88 ms/call, `[void]` 0.249 ms, `$null =` 0.207 ms. `[void]`
and `$null =` are within noise of each other and `[void]` is this tree's established spelling (39
existing sites against the 107 filed). `.AddRange()` fits only the one whole-collection site and would
have needed a `[string[]]` cast there, so it buys nothing the loop form does not.

**The sharper reason the idiom is pure waste on most of these sites:** `List<T>.Add()` returns
**void**, so `| Out-Null` there suppressed nothing whatsoever -- it built and tore down a pipeline to
discard a value that was never produced. The existing `$segStart.Add(...)` two lines from a patched
site already had no `| Out-Null`, which is the tree stating the same fact. `StringBuilder.Append()`
and `.Clear()` do return a value, so those two genuinely needed suppressing, and `[void]` is the cheap
way to do it.

- [x] Lint gate + all suites green (`check-plugin-integrity.ps1`, `scripts/tests/*.tests.ps1`).
- [~] No new test suite. Dropped: this is a mechanical, output-identical substitution with no new
      branch or boundary, and the existing consumer-prose suites already pin the detectors' output --
      which is exactly what the identity check above re-verified. A suite asserting "no `| Out-Null`
      here" would be the declined lint rule wearing a different hat.

### DEPLOY: fix/2215-outnull-hot-path

The consumer-prose session check got roughly three times faster. It runs from a SessionStart hook in
every adopted consumer -- at every start, resume, clear and compact -- and on this repo's own tree the
two detectors behind it now take **393 ms where they took ~1,320 ms**, for byte-identical findings.

The repair is one idiom, at the 14 places it sits on that always-on path: `$x.Add(...) | Out-Null`
builds and tears down a whole pipeline per call, and `[void]$x.Add(...)` does not. Most of the win is
not in the appends issue #2215 counted but in `$buffer.Append(...)` inside the paragraph parser, which
runs once per line of every document in the corpus -- ~21,000 lines here. That parse alone went from
~1,690 ms to 248 ms.

The other 106 sites in the tree are left alone on purpose, and no lint rule was added to chase them:
they are overwhelmingly cold, and a check that reported all of them would be 106 true findings nobody
should act on.

**Score:** 3

#### What makes this deploy extra special

N/A -- this repo's subscribers are the consuming repos, and what they receive is the same session
check producing the same findings, faster. Nothing they run, configure or read changes.

**Score:** N/A

#### Pull Request

The always-on corpus walk stops paying a pipeline per list append
