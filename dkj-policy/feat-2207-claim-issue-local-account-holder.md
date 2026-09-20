## feat/2207-claim-issue-local-account-holder

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

The taken refusal gains one NOTE naming a holder authenticated in gh here; the account list comes from the SAME gh auth status read claim-issue already makes, so no second call.

#### What was verified before anything was written

The report's reason is a code fact, not an inference: `Get-ActiveGhAccount` walked every account line
in `gh auth status`, kept one candidate and returned only the active one -- so every non-active
account was read and discarded at both call sites. The proposed repair therefore needs no new data
path, only the records that walk was already producing.

**One thing about the report is dated rather than wrong.** This machine currently has exactly one
account in `~/AppData/Roaming/GitHub CLI/hosts.yml` (`davekokbwj`), so the two-account state #2207
measured is not reproducible here today. The defect is structural and survives that: the discard is in
the code, and the refusal's wording is what the finding is actually about.

#### Where this goes further than the report proposed, and why

#2207 asked for the check on "a **non-active** account". That is the shape it measured, and it would
go blind on a split-identity checkout (#1315) -- where gh is active as one account and the commits name
another, so the holder can be the **active** gh account and still be a concurrent session here. The
decisive fact is that the holder is authenticated *on this machine*; active-ness is carried in the
record and named in the wording instead of being filtered on.

### CREATE

- [x] `git-identity-lib.ps1`: extract the `gh auth status` walk into `ConvertFrom-GhAuthStatus` (pure)
      plus `Get-GhAuthAccounts` (one capture), and make `Get-ActiveGhAccount` a reduction over them
      with an optional `-Accounts` so a caller that has already read them spends no second process.
      Both of its readings -- "the account flagged active" and "the last name seen where none is" --
      are preserved exactly.
- [x] `claim-issue-lib.ps1`: `Get-LocalAccountHolders` (the decision, case-insensitive) and
      `Format-ConcurrentSessionNote` (the wording, which is the actual repair).
- [x] `claim-issue.ps1`: one `Get-GhAuthAccounts` read feeding both questions, and the note printed
      inside the `taken` arm **above** the "ask whoever holds it" line it corrects.
- [x] The skill page documents the note, the measurement, why it is not narrowed to non-active, and
      that it costs no second `gh` call.
- [x] `build-shared-scripts.ps1` run -- 3 mirrors updated.

#### The 5.1 trap this hit on its first run, recorded because the lib already knew it

`New-Object System.Collections.Generic.List[object]` throws `ArgumentException` ("argument types do
not match") the moment `@()` wraps it on Windows PowerShell 5.1, and blames the `return` statement
rather than the construction. `ConvertFrom-CommitScanLog` in `claim-issue-lib.ps1` documents this in
full; both new functions now use `List[psobject]` and point at that note instead of restating it.

### TEST

- [x] `claim-issue.tests.ps1`: 337 passed, 0 failed (was 306) -- 30 new asserts across the three new
      functions plus the wiring. The `ConvertFrom-GhAuthStatus` block deliberately asserts
      `Get-ActiveGhAccount`'s answer against the *same* inputs, so the extraction cannot move the old
      behaviour under a suite that only tested the new function.
- [x] `git-identity-gate.tests.ps1`: 50 passed, 0 failed -- the other caller of the extracted walk.
- [x] Live: `claim-issue.ps1 2203 -DryRun` (held by `DaveKJohn`, not authenticated here) prints the
      ordinary refusal byte for byte, confirming the common case is untouched.
- [x] Rendered the measured two-account state through the libs end to end to read the actual output.
- [x] Full lint gate + every suite.

#### The named test gap

The script's **live** path with two accounts authenticated is not exercised by a suite, and is not
made so. Every path through `claim-issue.ps1` needs a tracker, an account with write access and an
issue it may edit -- the gap this suite's own header already names -- so an override for the account
list would still not make the run testable there. The decision and the wording are pure and fully
covered; the wiring is held by structural asserts on the script text, which is the same instrument
#1628, #1679 and #1639 are held by.

### DEPLOY: feat/2207-claim-issue-local-account-holder

`claim-issue`'s "held by somebody else" refusal can now see that the holder is a second account
authenticated in `gh` on this very machine, and says so -- the concurrent-session reading, which used
to be indistinguishable from a colleague elsewhere. The refusal itself is unchanged: same five
verdicts, same exit code, nothing newly blocked, and no extra `gh` call, because the account list is
the read the identity resolution was already making and throwing away. Where the holder is genuinely
somebody else's account, the output is byte for byte what it was.

**Score:** 3

#### What makes this deploy extra special

Every consumer of this workflow gets it, and it lands on the one step whose whole purpose is to stop
the same work being built twice -- the case it now reports is precisely the one it was blindest to.
The cost of the old silence is measured rather than hypothetical: two independent measurements of one
issue, eight minutes apart, on one machine. Not a 4, because it only changes what is printed inside a
refusal that already fired correctly, and only in a multi-account setup.

**Score:** 3

#### Pull Request

claim-issue names a holder that is a second gh account on this machine

