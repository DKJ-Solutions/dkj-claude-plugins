## fix/3344-ci-wait-unregistered-check

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Issue #3344. The measured cause differs from the stated one (comment on the issue): `lint-en-tests`
registers only after the suite shards it waits on, so `gh pr checks --required` reads empty for the whole
suite run. The certificate read that as "not registered", which is never in flight, and the #2317 wait
never started.

### CREATE

- [x] `Get-CiTestCertificate -AllChecksJson`: an unregistered named check is in flight while another check on the same head is pending
- [x] `Wait-CiTestCertificate` passes the reader's `AllChecksJson` through; open-pr reads every check at both call sites
- [x] plugin mirrors of `gate-lib.ps1` and `open-pr.ps1` byte-identical again

### TEST

- [x] `gate-lib.tests.ps1` section 18b: busy versus idle head, another commit, an unparseable payload, a red check, and the wait loop's certified and settled exits (316 pass)
- [x] the cause measured live on PR #3345: `--required` answered "no required checks reported" from 12:32 to 12:40, while `suites (1..5)` ran

### DEPLOY: fix/3344-ci-wait-unregistered-check

A re-ship no longer runs the local suites while CI is still running them
([#3344](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3344)). The required check
`lint-en-tests` registers only after the suite shards it waits on have finished. For the whole suite run,
`gh pr checks --required` answers "no required checks reported", so open-pr read that state as "no
certificate" and ran the pool: 447s on PR #3334. `Get-CiTestCertificate` in `scripts/lib/gate-lib.ps1`
now also reads every check on the head. A named check that has not registered counts as in flight while
another check on that exact commit is still pending, so open-pr waits for it (#2317). Once nothing is
pending and the check is still absent, the local suites run as before.

**Score:** 3

#### What makes this deploy extra special

A repo running `dkj-policy` whose required check also waits on other jobs (`needs:`) takes the same
wait through the mirrored `open-pr.ps1`. A re-ship there waits for CI instead of re-running every suite
locally.

**Score:** 2

#### Pull Request

open-pr waits for CI while the required check has not registered but the head's other checks are still running

