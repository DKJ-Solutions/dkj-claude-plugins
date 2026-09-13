## fix/1932-identity-refusal-128-derived

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

The contract change #1932 proposes is declined: after #1920 the refusal is gated on exactly 128, so the message is a derived constant rather than an assertion. What is missing is the derivation at the call site, plus the mirror.

#### What #1932 reported, and which half of it survived the check

The report has six things that can fail independently, and two of its own failed:

- **The symptom stands.** `scripts/task/new-branch.ps1` printed `exits 128 here` as a literal while
  `Test-GitCanCommit` returns a bool, so the call site never saw a code.
- **The reason does not.** The report says the wording "stops being accurate the moment `git var`
  acquires another non-zero exit". After #1920 -- merged at 13:24 on September 13, 2026, two hours
  *after* this issue was filed at 11:29 -- that function refuses on **exactly** 128 and returns
  `$true` for every other non-zero (`scripts/lib/git-identity-lib.ps1`). The refusal is therefore
  unreachable at any other code, and the message can never print for one.
- **The proposed repair is declined with it.** Returning the code alongside the verdict is a contract
  change across a SessionStart hook, `check-git-identity.ps1`, its plugin mirror and this script, to
  obtain a value this branch already knows.
- **And its closing claim is wrong.** "The check that would catch a future drift is the one this issue
  is asking for" -- `scripts/tests/new-branch.tests.ps1`'s (y) fixture sanity assert already requires
  exactly 128 from git's own probe before any other assert in that block may mean anything, which is
  the drift the issue feared.

What was left is smaller and real: the number was sound but **hand-typed in a third place**, beside the
two the lib's own comment says have to agree on it.

### CREATE

- [x] `scripts/task/new-branch.ps1`: compose the refusal's exit code from
      `git-identity-lib.ps1`'s `$GitAuthorIdentityUnknownExitCode` instead of a literal, and fall back
      to wording that claims **no** number where the constant is absent -- a lib from between inbound
      #1867 and #1920 carries `Test-GitCanCommit` without it, and that is the one payload whose refusal
      fires on any non-zero, where `exits 128` would be exactly the unproven claim #1932 describes.
- [x] Record at the call site why the number may be stated at all, and why the contract change was
      declined -- the reader who filed #1932 had no way to tell a derived constant from an assertion.
- [x] `plugins/dkj-policy/scripts/task/new-branch.ps1`: mirror byte-identical, per the shared-scripts
      drift lint.
- [~] Change `Test-GitCanCommit`'s contract -- dropped. See the section above: the premise expired
      before the issue was picked up.

### TEST

- [x] `scripts/tests/new-branch.tests.ps1`: assert the refusal names the code, in the (y) no-identity
      fixture. It guards the fallback rather than the happy path -- the sentence reads perfectly well
      without a number, so a composition that silently lost it would degrade the refusal's only
      measured detail with nothing on screen looking wrong.
- [x] Suite green: 280 asserts, and the new one passes against a live `exits 128`, which is the proof
      the constant is being read rather than the literal reinstated.

### DEPLOY: fix/1932-identity-refusal-128-derived

`new-branch`'s no-identity refusal now takes its exit code from the constant its guard actually gated
on, instead of carrying a third hand-typed copy of `128` -- and says no number at all where a
plugin payload predating #1920 supplies no constant to read. The call site records why the number is
sound, which is what a reader could not tell before: `Test-GitCanCommit` returns a bool, so the
message looked like an assertion about a measurement it never made.

**Score:** 2

#### What makes this deploy extra special

A consumer running this script from the plugin cache sees the refusal state the code its own guard
matched on. It matters most on the payload nobody is watching: a mirror built between inbound #1867
and #1920 refuses on **any** non-zero exit, and there the old sentence sent the reader to
`user.name`/`user.email` for a state that has nothing to do with either. Nothing is asked of anybody
-- no re-install, no config -- and the failure this prevents has not happened yet.

**Score:** 1

#### Pull Request

Say at the call site why the no-identity refusal may state exit 128

