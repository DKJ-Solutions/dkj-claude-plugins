## fix/2836-claim-tag-checkout

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

#### Issue

[#2836](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2836), with its inbound duplicate
[#2838](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2838): two sweeps on one machine under
one account wrote one claim tag, so each read the other's claim as `mine`.

#### Direction chosen

The checkout id goes into the machine half (`machine:checkout/account`), not a per-session nonce: the
step-6 resume runs in a new session in the same checkout, which a nonce would read as `[NO]`. A hash, not
the path, because the path carries a user name onto the tracker.

### CREATE

- [x] `Get-CheckoutClaimId`, `Get-ClaimTagRelation`, `Format-ClaimHolderNote`; `Get-ClaimTag -Checkout`
- [x] `claim-issue.ps1` passes the checkout root; `-Candidates` and `-Verify` explain a same-machine holder
- [x] plugin mirrors of the lib and the script, byte-identical
- [x] `sweep-issues` and `claim-issue` skill pages state the new tag

### TEST

- [x] review: Victor #19 (no bugs; legacy take-over test added) and Sebastian #23 (no findings)

- [x] `claim-issue.tests.ps1`: 580 passed, 0 failed, with the new asserts for the id, the tag, the verdict
  in both directions, the relation, the `-Candidates` reason and the legacy take-over

### DEPLOY: fix/2836-claim-tag-checkout

A sweep's claim tag now names the checkout as well as the machine and the account:
`machine:checkout/account`, where the checkout is the first 8 hex digits of a hash of its root path.
Two sweeps on one machine under one account, in two checkouts or worktree lanes, now claim apart, and
`-Candidates` no longer reads the other's claim as `mine`.

**Score:** 3

#### What makes this deploy extra special

If you run more than one sweep on a machine, each one now claims under its own tag, so it can no longer
pick up and rebuild an issue the other sweep is still working on. A claim written by an older version
names no checkout and shows as `held`, with a note that it belongs to this machine and account. Read its
branch, and run `claim-issue <n> -Tag -TakeOver` if the work is yours.

**Score:** 3

#### Pull Request

A claim tag names the checkout, so two sweeps on one machine no longer read each other's claim as mine

