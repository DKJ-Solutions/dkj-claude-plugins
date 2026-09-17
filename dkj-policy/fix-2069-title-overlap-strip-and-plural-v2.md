## fix/2069-title-overlap-strip-and-plural-v2

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

Two filed defects in one place: `claim-issue`'s fifth pickup signal, the title-overlap scan from
#2018. #2069 is the missing `Format-ForConsole` on the branch names it prints -- the class #1858
closed one signal up, off the same `git branch -a` capture, reintroduced by a block written afterwards
that never acquired the call. #2070 is that block's lead line pluralising its noun and not the two
words agreeing with it. One branch because they are two lines of the same function pair, one test file
and one mirror pair. One commit, not two: the asserts for both land in the same file, so splitting by
subject would leave one commit with a suite that cannot pass.

#### Why this branch carries `-v2`, and what the first round measured

`fix/2069-title-overlap-strip-and-plural` was cut while this checkout stood on another session's
branch, so it inherited five commits of `fix/2056-already-done-three-state` -- 22 files, 1257
insertions of unlanded work a pull request from it would have carried along. `new-branch`'s base check
read `Base is current with origin/main`, which is true of the gap it measures (`HEAD..origin/<trunk>`,
and that branch had merged origin/main minutes earlier) and says nothing about the base being another
branch's tip. Rebuilt here from `origin/main` in a worktree, so the other session's working copy was
never touched. Filed as #2074; the first branch is superseded and its work is in this one.

**And rebuilding it is what found the real defect in the repair.** `origin/main` gained #2064's sixth
signal in the meantime, which reads `$overlaps[].Branch` back and puts each name to git. The first
round stripped on the way IN, which is one of the two placements #2069 proposed and is now the wrong
one -- see DEPLOY. A cherry-pick onto the current trunk is what surfaced it; the suite on the old base
was green.

Reading that signal to place the strip correctly also showed that its OTHER input arrives
pre-stripped: the fourth signal's names are collected from `$f.Branches`, which git cannot always be
asked about. Same class, different signal's input, out of scope here -- filed as #2075. This branch is
what makes it visible, because it states the rule in a comment.

#### The related parked branch, read before writing

`origin/docs/2066-title-overlap-section` shares words with both titles and the scan said so on each
claim. Read: two commits, `plugins/dkj-policy/skills/claim-issue/SKILL.md` and its own branch
document, no PR. It documents this signal and carries neither repair, so there is no collision -- but
it quotes the ungrammatical lead line verbatim as sample output, which this branch makes stale. Not
editable from here; recorded on #2066 instead.

### CREATE

- [x] `Format-TitleOverlapReport`: switch the verb and the pronoun with the noun, the way
      `Format-ParkedFixReport` already switches its own (#2070)
- [x] `claim-issue.ps1`'s fifth signal: strip the branch names into a copy the REPORT reads, leaving
      `$overlaps` carrying the ref as git wrote it for the sixth signal (#2069)
- [x] Mirrors rebuilt byte-identically via `build-shared-scripts.ps1`

### TEST

- [x] `claim-issue.tests.ps1`: the singular lead line pinned as a whole line -- what broke was the
      agreement between three words, not any one of them -- and the plural beside it, labelled as the
      regression guard it is, since the plural arm was never broken
- [x] `claim-issue.tests.ps1`: the fifth signal's block extracted on its own, because the existing
      `$scan` capture spans as far as the verdict switch and so contains it -- the fourth signal's
      calls would satisfy a strip assert written against `$scan` while this block printed raw
- [x] The seam asserted in BOTH directions: the report reads the stripped copy, and the scan and the
      sixth signal read the git-spelled capture. Neither half is a style preference and nothing else
      in the tree says so
- [x] Both repairs run for real: singular reads `1 branch ... shares ... on it`, plural unchanged,
      and a U+202E planted in a branch name comes out as a space
- [x] Full suite green in the worktree: 297 passed, 0 failed
- [x] Lint + tests gate via `open-pr.ps1`

### DEPLOY: fix/2069-title-overlap-strip-and-plural-v2

`claim-issue`'s title-overlap scan no longer prints a branch name it has not sanitised, and its lead
line now agrees with itself when it reports one branch -- which is the common case and the one #2018
itself measured.

The strip is the half with teeth. `git check-ref-format` enforces `\p{Cc}` and **accepts** `\p{Cf}`,
so a branch fetched from `origin` can carry U+202E or a zero-width run -- and the line it lands in is
the one whose whole job is to tell a reader which branch to go and look at before writing anything.
The fourth signal strips exactly these values, off exactly this `git branch -a` capture, at the
caller; the fifth signal was written one signal later and never acquired the call. The convention it
skipped is stated in `ConvertFrom-CommitScanLog`'s docstring -- *"neither free field is stripped here.
The caller prints them and the caller runs them through `Format-ForConsole`"* -- and the fourth
signal's caller holds up that end while the fifth signal's did not.

**Where it is placed is the part worth reading, because the obvious placement is wrong now.** #2069
proposed either stripping the names on the way into the scan or the report on the way out, and
between the filing and this repair #2064 decided it: its sixth signal collects
`$overlaps[].Branch` and puts each name back to git (`rev-list --count`, `ls-tree`). A name this
strip has rewritten is a ref git does not have, so stripping on the way in would leave that scan
silent exactly where it should report a prerequisite -- in the adversarial case the strip exists for,
and with no error anywhere. So the record keeps git's spelling and the **report** gets a stripped
copy, which is the same seam the weighing loop below it already draws between its printed `Branch`
field and the `$branch` it queries. The exclusion above needs the git spelling for the same reason,
which is why the strip also sits below it.

The lead line was the smaller slip and the more visible one: `1 branch ... share words ... though no
commit on them`. `$branchWord` already switched; the verb and the pronoun were left fixed at the
plural. They switch together now.

Both are held by tests the suite did not have, and the seam is asserted in both directions -- a strip
that creeps back onto the scan input would pass every behavioural test in the file, because on an
ordinary ASCII branch name the two placements are indistinguishable. The strip assert reads the fifth
signal's block **extracted on its own**: the existing `$scan` capture runs as far as the verdict
switch and therefore contains the fifth signal, so the fourth signal's own calls would have satisfied
it while this block printed raw. That is #2019's lesson one turn later, in the place it was filed
about -- the unit is a **value** that reaches the terminal, never a variable that looks like the
script's own.

**Score:** 3

#### What makes this deploy extra special

Both lines are shipped plugin payload, so a consumer's console is where they are read -- with nothing
beside them to compare against. That is the whole reason the grammar was worth filing rather than
leaving: it is the first line of a warning arguing that the reader should stop and look, and a
consumer cannot tell an unfinished sentence from house style. The strip closes a terminal-spoofing
route in a consumer's own checkout, where a branch name arrives off whichever remote they fetch, and
it does so without blinding the prerequisite scan that landed one release earlier. Nothing to do on
upgrade and no behaviour to relearn: the scan reports the same branches, printed safely and read
correctly.

**Score:** 2

#### Pull Request

The title-overlap scan sanitises the branch names it prints, and its lead line agrees with itself in the singular

