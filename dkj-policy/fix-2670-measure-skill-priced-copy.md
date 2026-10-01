## fix/2670-measure-skill-priced-copy

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

#2670: `measure-skill` says `claude plugin details` prices the copy a session loads. Re-measured
October 1, 2026, from `smartwatchbanden`, whose install record pins dkj-policy 5.9.0: the command still
priced 5.11.0, the newest version on the machine. The issue's reason holds: the command takes no project
path and does not price the recorded copy. Which of the clone and the newest cache entry it reads was not
determined, and the fix doesn't depend on it.

### CREATE

- [x] Move `Get-InstalledVersionForRepo` from `session-start-lib.ps1` into `measure-skill-lib.ps1`
  (session-start-lib dot-sources it, so its caller is unchanged), with a `-UserHomeOverride` for fixtures.
- [x] `measure-skill.ps1` reads this checkout's install record. Where it differs from the priced version,
  it prints an `[INFO]` saying the figures are what a session here pays after its next update, and the
  tree-vs-payload line no longer claims "what a session loads today" in that case.
- [x] Correct the claim in the script docstring, `skills/measure-skill/SKILL.md`, and
  `session-start-lib.ps1`'s payload docstring and `source` label. Mirror rebuilt with
  `build-shared-scripts.ps1`.

### TEST

- [x] `measure-skill.tests.ps1`: new asserts on `Get-InstalledVersionForRepo` against a fixture
  administration (no file, this repo's record beats another checkout's newer one, pathless fallback,
  absent plugin), plus four on `Test-PricedIsLoaded`, the decision behind the new `[INFO]`. 101 pass.
- [x] `measure-session-start.tests.ps1`: 198 pass (its caller of the moved function, and the mirror
  byte-identity).
- [x] Live: `measure-skill -Plugin dkj-policy` here (record 5.11.0 = priced) prints no new line. With
  `-RootOverride` on smartwatchbanden (record 5.9.0) it prints the new `[INFO]`.

### DEPLOY: fix/2670-measure-skill-priced-copy

`measure-skill` no longer claims its figures are what a session in this checkout loads today when they
aren't. `claude plugin details` does not price the version recorded for this checkout in the plugin install
record (measured: it prices the newest version on the machine). So the report now reads that record and, where the two differ, says the figures are
what a session here pays after its next plugin update (#2670).

**Score:** 1

#### What makes this deploy extra special

If you run `measure-skill` in a checkout that has not yet taken the newest plugin update, it now says that
the costs shown belong to the newer version on your machine, not the version this checkout currently loads.

**Score:** 1

#### Pull Request

measure-skill names the gap between the version it priced and the version this checkout's install record pins

Plugins: dkj-policy

