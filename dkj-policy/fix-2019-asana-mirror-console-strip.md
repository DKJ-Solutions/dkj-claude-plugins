## fix/2019-asana-mirror-console-strip

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

#### What #2019 reported, and what verifying it changed

The report names two print sites in `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`,
both printing `$task.name` -- an Asana task's own title, free text any colleague with board access
types through the web UI -- straight to a CI log. Both stand. Its line numbers (1319, 1327) had
drifted to 1246 and 1254 by the time it was picked up, and to 1287 and 1295 after `main` gained
#2017's commit during this pickup; the sites are the same two.

**The size it reports is smaller than the subject, and that is the one thing verification changed.**
`Get-IssueLinkState` prints the GitHub project board's STATUS names on its ambiguity line
(`Select-ProjectStatus`'s `Candidates`, now line 1438) -- single-select option names typed by
whoever configures the org's project board, through a web UI, needing no push access to any
repository. Same class, same file, same absence of a guard. Three sites, not two.

**Checked and NOT a finding**, so nobody widens this later on a hunch:

- the stage **code** on those same lines -- `Get-StageFromSectionName` captures `([0-9]+[A-Za-z]*)`
  and `Test-AsanaStageMap` validates a config-supplied code against `^[1-9][0-9]*[A-Za-z]*$`, so no
  control or format character can reach the console through it. #2016's change of that value from
  `[int]` to a string adds no site;
- `$ref.Candidates` at lines 1267 and 1483 -- Asana GIDs, matched out of a URL by `[0-9]+`;
- `$($own.NeedsInfoLabel)`, `$($own.FieldName)`, `$Label`, `$PrioFieldName` -- all off this repo's
  own `scripts/repo-config.ps1`, which is the same trust level as the script itself;
- `$($_.Exception.Message)` at the six API-failure lines -- the authoring party there is Asana's or
  GitHub's own HTTP stack rather than a person with board access, which is a different class from
  the one this branch is about. Left alone deliberately rather than overlooked.

#### Why the strip is hand-typed a fourth time

The template ships **standalone**: `adopt-dkj-policy-bwj` copies it into a consumer as
`.github/scripts/asana-mirror.ps1`, where none of this repo's libs exist -- so `Get-DisplayRef`
cannot be called and a dot-source would name a path that is not there. That is a stronger reason
than the one keeping the three libs apart, and it is also why entry 6 went unguarded: every other
site got the strip when its own lib acquired one, and this file has no lib.

`claim-issue-lib.ps1`'s `Format-ForConsole` is the contract copied, name included, because it is
exactly right here -- strip to a space, collapse nothing, trim nothing. A task name is quoted
evidence, so re-spacing it makes it no longer what the board says, which is why `Get-DisplayRef`
would have been the wrong function even if it had been reachable.

**No cap.** `new-branch` caps a commit subject at 120 so the half of the sentence saying what to DO
is never pushed off a terminal. This script's only console is a GitHub Actions log, which wraps
rather than truncating, so a cap here would destroy evidence and buy nothing.

### CREATE

- [x] `Format-ForConsole` added to `templates/asana-mirror.ps1`, with the docstring carrying the
      standalone argument and the accepted cost (a name in Arabic or Hebrew loses its ordering marks)
- [x] the two `$task.name` sites and the project-board status names put through it

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: the function's behaviour (ANSI, OSC, U+202E, U+200B, C1 0x9B, a
      newline, a printable non-ASCII name that must survive, empty and `$null`), the three call sites
      asserted over the source because each is a `Write-Host` no fixture can reach without a live
      Asana, and the class compared character for character against all three libs
- [x] the escape literals are built with `[char]0x..` -- `` `e `` is PowerShell 7 and decodes as a
      literal `e` under 5.1, which is how the first run of these asserts failed
- [x] `check-plugin-integrity.ps1` + every suite green

### DEPLOY: fix/2019-asana-mirror-console-strip

`asana-mirror.ps1` -- the CI script this workflow ships to a BWJ store -- printed an Asana task's own
name and a GitHub project board's status names to its log without stripping anything. Both are free
text a colleague types through a web UI, needing no push access to any repository, so an ANSI or OSC
escape run in either repainted the CI log it landed in and an RTL override or a zero-width run made
the line read as something other than what it says -- on the one line whose job is to say which card
moved where. All three sites now go through a `Format-ForConsole` the template carries itself,
because it ships standalone into a consumer where none of this repo's libs exist.

`new-branch`'s list of the places this workflow prints somebody else's words to a console goes from
five entries to six, and records that the class is now typed in a fourth place outside the libs.

**Score:** 3

#### What makes this deploy extra special

N/A. This repo's audience tier is the consumer running the workflow, and the change is invisible to
them until a task name actually carries a control character: the CI log reads exactly as before for
every name that does not. It prevents a failure rather than removing one somebody has hit.

**Score:** N/A

#### Pull Request

asana-mirror strips control and format characters out of the Asana and project-board text it prints
