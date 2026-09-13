## fix/1962-exempt-branch-pr-title

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

#### What the report said, and what was verified before anything was written

Inbound [#1962](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1962), from
`BWJ-Development/smartwatchbanden` on `sync/live-2026-09-13`. All six pickup checks were run against the
tree before routing:

- **Symptom** -- stands. `Get-EntryGateExemptPrefixes` is read by `check-branch-entry.ps1` and by nothing
  else; `open-pr.ps1` contains no exemption at all.
- **Reason** -- stands. Every entry gate in `open-pr` sits behind `Test-Path $entryPath`, so an
  entry-less branch passes all of them and dies at the nameless-PR refusal, which is *after* the push.
- **Repair** -- both proposed shapes name mechanisms that exist. Both were taken: the commit subject is
  the default so a caller passing nothing still gets a named PR, and `-Title` is the override.
- **Size, subject, repo** -- one defect, in this repo's own shared script, reaching every consumer.
- **The side observation** -- also stands, and is repaired here: the legacy root fallback was
  unconditional, so a branch with no entry in either place ended up quoting `<repo>/<branch>.md`, a
  location nothing has written since August 19, 2026.

### CREATE

- [x] `Get-BranchEntryExemptPrefix` in `entry-scaffold-lib.ps1` -- the seam, the default and the prefix
      split in one place, returning the matched prefix so the caller can quote it
- [x] `check-branch-entry.ps1` calls it instead of owning the rule inline
- [x] `Get-ExemptBranchTitleWords` in `pr-body-lib.ps1` -- pure: `-Title`, else the oldest commit subject
- [x] `open-pr.ps1` composes an exempt branch's title from it, honours `-Title` there and nowhere else,
      and splits the nameless-PR refusal into its two situations
- [x] the legacy root entry path is taken only where that file actually exists
- [x] the script contract records `open-pr` as the seam's second reader, via `entry-scaffold-lib`
- [x] the shared-script mirrors regenerated

### TEST

- [x] `pr-body.tests.ps1` -- `Get-ExemptBranchTitleWords`: precedence, the oldest subject, the empty
      answer the caller refuses on, and that `Get-PrTitle` still owns the composition
- [x] `entry-scaffold.tests.ps1` -- `Get-BranchEntryExemptPrefix`: the default, the near-miss typo, the
      no-slash form, degenerate input, and the seam replacing rather than extending the default
- [x] `branch-entry-gate.tests.ps1` -- the gate's existing end-to-end exemption cases now run through the
      shared function, which is the proof the move changed no behaviour; plus source-text asserts that
      `open-pr` actually calls both functions and that `-Title` is still ignored elsewhere
- [~] an end-to-end assert that `open-pr` names an exempt branch's PR -- **dropped, and named as a test
      gap rather than faked.** The create path is past the push and past `gh`, so no fixture reaches it.
      Both halves are under test as pure functions and the wiring is asserted on the source text, which
      is this repo's existing convention for exactly this.
- [x] the full lint + test gate

### DEPLOY: fix/1962-exempt-branch-pr-title

`open-pr` can now open a pull request for a branch that owes no changelog entry. A prefix listed in
`Get-EntryGateExemptPrefixes` -- `sync` by default -- is exempt from the entry gate, and
`check-branch-entry` passes such a branch for exactly that reason; but the PR title has been composed
from the entry and nothing else since #506, so the one branch shape the CI gate deliberately waves
through was the one shape `open-pr` could not name. It refused *after* running the lint gate, every
suite and the push, with a message telling the author to fill in a title section they must not write --
an entry on a mirror branch folds somebody else's edits into `CHANGELOG.md` as this repo's own work.

The exemption is now one function, `Get-BranchEntryExemptPrefix`, called by both scripts, so they cannot
disagree again about which branches owe an entry. On an exempt branch the title comes from `-Title` if
one was passed, otherwise from the branch's oldest commit subject off the trunk -- its own opening
statement, which a mirror script already writes descriptively. `-Title` is honoured **there and nowhere
else**: #506 removed a *second* source of the title, and an exempt branch has no entry to be a second
source of. Where such a branch genuinely has nothing to be named after, the refusal says that in its own
terms and asks for a commit or a `-Title`.

The report's side observation is repaired with it: the retired root entry path is now taken only when
that file exists, so a refusal naming a path names one that is merely missing rather than one that
exists nowhere.

**Score:** 4

#### What makes this deploy extra special

This closed the only gated route a consumer had for a sync PR. `sync-main.ps1` opens its own PR with a
bare `gh pr create`, which runs no gates; routing it through `open-pr` instead is the documented reason
that wrapper exists, and with `open-pr` unable to name such a PR the only remaining option was the
ungated one. A consumer running mirror branches gets that route back with the next plugin update, with
nothing to configure -- and a consumer that has never run one is unaffected, since the branch shape this
touches is the one their prefix list does not contain.

**Score:** 3

#### Pull Request

open-pr names an entry-exempt branch's PR from its own commit subject
