## fix/2399-claim-marker-author-check

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

The author check goes in `Get-ClaimRecords` itself rather than in each caller, which is the open
question #2399 left. Every caller judges records: its own (`-Release`, the resume) and other tags'
(the race, a take-over, the sweep). "The author is the account half of the marker's OWN tag" is the one
test that is right for both. #2395's branch (PR #2400) added the same check inside `Get-OwnTagClaims`
for `-ReleaseAll` alone. Once both land that check is redundant but harmless. The two branches touch
different functions in the same file.

### CREATE

- [x] `Get-ClaimRecords` drops a marker whose comment author is not its tag's account half, or has no
  author, or whose tag has no account half. Mirrored byte-identically into the plugin copy.
- [x] The `-Tag` section of the claim-issue skill page says so.

### TEST

- [x] `claim-issue.tests.ps1`: 480 passed, 0 failed. The issue's measured case (a
  `random-tracker-user` comment naming `DAVE-KOK-BWJ/DaveKJohn`) is now not returned. Also tested: a
  genuine marker beside a planted one returns only the genuine one; a planted earlier marker does not
  win the race; a planted marker does not park a free issue; the comparison is case-insensitive. The one
  existing assert that read an authorless marker as a record now asserts it is dropped, and a new assert
  keeps the StrictMode coverage for a record missing `createdAt`.
- [x] Review: Victor clean (every caller traced, including take-over and the older `swb-lane` markers).
  Sebastian confirmed the planted-marker gap is closed. He also found a separate gap: an account can
  backdate its OWN marker by editing an old comment of its own. That is a different attack, not
  introduced here, and it needs a different field, so it is filed as #2402 rather than folded in.

### DEPLOY: fix/2399-claim-marker-author-check

A claim marker was taken at its word. Anybody who could comment on an issue could write one naming
somebody else's tag, and `-Release`, the verdict, the sweep and the race all counted it. A marker now
counts only when the comment's author is the account its tag names (#2399).

**Score:** 2 -- closes a spoofing gap in tag-mode claims. Nothing changes for a genuine claim, because
gh always writes it as that account.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

claim-issue: a claim marker counts only when its author is the tag's own account

Plugins: dkj-policy
