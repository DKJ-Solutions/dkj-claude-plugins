## fix/1951-sync-rules-single-log-walk

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

Replace the per-commit `rev-parse` walk in `Test-LiveContentIsOurs` with one `git log --raw`, which
returns the commit *and* the resulting blob id for every relevant commit in a single process.

#### The design problem, settled by measurement rather than by reading

#1951 named the part to design rather than drop in: a plain `--raw` prints **nothing** for a merge
commit, and `--full-history` (#1945, merged one day earlier) deliberately includes merges. The failure
direction is the dangerous one -- a blob the walk stops seeing makes live's content read as **foreign**,
which is the arm that overwrites the trunk.

Measured over **12 real paths** of this repo (4,910 commits, 29% merges), each variant against the
per-commit walk it would replace:

| variant | blobs LOST | blobs gained | speedup |
|---|---|---|---|
| plain `--raw` | **62** | 0 | ~50x |
| `--raw -m` | **0** | 0 | 6.5x - 99x |
| `--raw --cc` | **0** | 0 | 6.6x - 91x |

So the issue's warning is exact, and `-m` answers it. `--cc` measures identically and is **not** used:
it prints only where the result differs from *all* parents, which is a narrower emission for no gain,
and narrower is the wrong direction to be wrong in here.

### CREATE

- [x] `Test-LiveContentIsOurs` reads one `git log --full-history --format=%H --raw --no-abbrev -m`
      instead of one `git log` plus one `git rev-parse` **subprocess per commit**.
- [x] **`--no-abbrev` is load-bearing**: `--raw` abbreviates object ids by default, and the comparison
      is against a full 40-character id from `Get-GitRawBlobId`. Abbreviated, nothing would ever match
      and **every** path would read as foreign.
- [x] **No `-M`.** Rename detection would match a different path's history, which is exactly what the
      function's standing `--follow` warning refuses. The pathspec is unchanged; only the output format is.
- [x] The destination blob is read as the **last** id before the tab, which is true of both raw shapes
      (`:<m> <m> <src> <dst> <S>` and the combined `::...`) without a second parser. Only the pre-tab
      half is read, so a path that happens to look like an object id cannot enter the comparison.
- [x] An all-zero destination is a **deletion** and is skipped -- the same thing the old walk expressed
      as `Get-GitStoredBlobId` returning `''` for a path absent at that rev.
- [x] The `--` splatting lesson is carried over verbatim: written inline the `--` never reaches git, and
      for a path the trunk has DELETED that silently restores live's copy over a deliberate deletion.
- [~] `Get-GitStoredBlobId` is **not** removed, though this was its only caller. It is the one place the
      "read an id, never the bytes" scar is recorded -- the consumer's first version read content through
      a PowerShell pipeline, corrupted every blob it returned, and sent files that WERE ours to take-live.
      Deleting the function deletes that record. Retiring it is a surface change to a mirrored lib and is
      not this issue's subject.
- [x] Plugin mirror rebuilt (`scripts/sync/build-shared-scripts.ps1`): 1 mirror updated.

### TEST

- [x] `scripts/tests/sync-rules.tests.ps1` -- **172 asserts, 0 fail.** `sync-main.tests.ps1`: 158, green.
      Lint gate: **0 errors**.
- [x] **The existing suite did not cover the design decision, and that is the finding this branch turned
      up.** Dropping `-m` left all 165 asserts green, while the same drop loses 62 blobs across 12 real
      paths. #1945's merge case walks a branch whose blobs all sit on **ordinary** commits, and `--raw`
      prints those with or without `-m` -- so that merge is walked past, never read out of.
- [x] **The case that does cover it** builds a real conflicting `git merge --no-ff` and resolves it to a
      **third** content, so the blob's only home is the merge's own post-image. It asserts that premise
      first -- the blob is at the merge and at neither parent -- because otherwise it could pass for the
      wrong reason on some git version. Both parents' content is still found and content nobody committed
      is still foreign: the emission widened, the judgement did not.
- [x] **Negative proof, which the old case could not give**: with `-m` removed this suite fails
      `2 of 171`, naming the blob and the verdict that moved. Restored: 172 pass.
- [x] Check 35 `[fixture-git]` refused the new fixture's conflicting merge on its first run, correctly --
      the exit code is now read on the next statement, which both clears the check and proves the merge
      really conflicted. A merge that succeeded would leave a parent's blob in the tree and the case would
      assert nothing.

### DEPLOY: fix/1951-sync-rules-single-log-walk

`Test-LiveContentIsOurs` -- the rule deciding whether live's copy of a file is content this repo has held
before, and therefore whether the trunk is kept or overwritten -- asked git one question per commit, as a
separate `git rev-parse` **process** each time. On Windows that spawn was the dominant cost of the whole
rule, and #1945's `--full-history` had just multiplied the commit count by a measured 2.0-4.0x, so it
multiplied the process count by the same factor. It now reads one `git log --raw` for the whole walk.

Measured over 12 real paths here: identical blob sets, **6.5x to 99x faster**. `dkj-policy/CHANGELOG.md`
goes 10,306 ms to 107 ms over 558 commits; `CLAUDE.md` 6,584 ms to 77 ms over 358. The win lands exactly
where it matters, because the walk runs to the end only when nothing matches -- the foreign case this
rule exists for.

`-m` is what makes the swap safe rather than merely fast, and it was the whole of the design problem: a
plain `--raw` prints nothing for a merge commit, silently dropping every blob whose only home is a merge
-- measured at 62 lost blobs, in the direction that overwrites the trunk. The premise #1951 left
unmeasured, that a theme repo's per-path history stays single-digit, has stopped being load-bearing: the
cost no longer scales with the history at all.

**Score:** 3

#### What makes this deploy extra special

`sync-rules.ps1` is mirrored into `dkj-subagents-shopify`, so a store repo running `sync-main` gets this on
the next release. Nothing changes in what the sync decides -- the blob sets are identical on every path
measured -- so there is no behaviour for an operator to re-learn; a `sync-main` run over a long-lived path
simply stops taking seconds per file.

**Score:** 2

#### Pull Request

Test-LiveContentIsOurs answers its walk in one git call instead of one subprocess per commit
