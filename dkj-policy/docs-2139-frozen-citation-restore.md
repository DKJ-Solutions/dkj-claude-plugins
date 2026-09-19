## docs/2139-frozen-citation-restore

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

Restore the lens citation to what v4.22.0 shipped, and the same in check-plugin-integrity.ps1's own swept line; mark both as quotations. The wider class is filed separately.

#### What the verification changed

#2139's symptom holds and its repair direction is right, but its stated REASON does not survive
reading the tree, so the repair is wider than it proposed:

- It argued the script's copy survived *"because a `.ps1` comment was not in either sweep's file
  set."* The `.ps1` was in all three sweeps' file sets -- its own `team-alpha 4.21.0` line was swept
  by `17149edb`, `eaeb832b` and `e262121d`, eight lines below a path citation nothing has touched
  since `7769d1e1`. What survived is the SHAPE of the token, not the file type.
- The lens carries a SECOND swept citation #2139 did not report -- `dkj-team-alpha` 4.21.0 on the
  line after the one it named, swept once rather than twice.
- Verified one step past the issue: line 123 of `cut-release/SKILL.md` AT THE TAG `v4.22.0` reads
  `../../../../teams/team-alpha/manuals/06-25-manual.md` verbatim, and `v4.22.0:plugins/teams/`
  holds `team-alpha`. So the restored spelling is checked against the release, not inferred from
  `git log`.

### CREATE

- [x] Restore the lens path citation to `teams/team-alpha/...` and mark it as quoted-not-swept
- [x] Restore the lens's second citation to `team-alpha` 4.21.0, `contributing-davekjohn` 4.22.0
- [x] Restore and mark the same swept line in `scripts/lint/check-plugin-integrity.ps1`
- [x] Mark the surviving path citation in that script, which carried no marking of its own
- [x] Record the corrected mechanism in the lens, with the mechanical detection rule it implies
- [~] Build a check for the class -- not done here. It touches check 28's guardrail, whose intent
      belongs to whoever owns #874, and #2139 calls it an open design question. Filed as #2144.

### TEST

- [x] Lint gate green (`check-plugin-integrity.ps1`): 0 errors, check 27 `[script-ascii]` included,
      which the .ps1 edits had to stay inside
- [x] All suites green via `open-pr.ps1`

### DEPLOY: docs/2139-frozen-citation-restore

Three verbatim citations that had been silently rewritten by the `dkj-`/`dkj-subagents-` renames are
restored to what the releases actually shipped, and marked so the next sweep leaves them alone. The
argument they belong to -- #1066's plugin-root boundary -- is evidence a reader is meant to check
against a tag, and a quotation that has been rewritten twice no longer carries that.

**Score:** 2

#### What makes this deploy extra special

N/A -- the citations sit in this repo's own lens and lint script. Nothing a subscriber of this
service installs or reads changes; the one instance that does sit in shipped plugin payload was
deliberately left to #2144.

**Score:** N/A

#### Pull Request

Restore the swept v4.22.0 citations and mark them as quotations

