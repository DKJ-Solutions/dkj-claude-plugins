## fix/2000-quota-red-check

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

Dave reversed the stay-red policy (September 14, 2026). Downgrade ONLY `api_error_status` 429, where the
workflow's own text says a re-run adds nothing; everything else -- 529, an unknown status, the pre-SDK
setup class -- stays red, because there it is actionable.

#### The issue's own diagnosis is refuted, and that is recorded rather than quietly fixed past

#2000 was filed as "the sixth rotation of the same credential", reading the job log's env block --
`ANTHROPIC_API_KEY:` arriving empty -- as the credential being absent. It is not. The failure annotation
on run 34867311142 already named the cause:

> You've hit your org's monthly spend limit - ask your admin to raise it at claude.ai/settings/usage

That is the third of the three 429 kinds this workflow already documents (#1164): a spend cap, which no
clock resets and no rotation touches. There is nothing to rotate, and a seventh rotation would have been
the #966 misdiagnosis for the eighth time -- against a run whose own diagnostic had printed the answer.
The issue's TITLE already carries the correction; its body does not, so the repair follows the title.

#### So the repairable part was never the credential

Two things were true at once: the review genuinely cannot run, and the red tick beside it is not
actionable by anybody reading the pull request. Seven issues have now been filed against this one check
(#891, #913, #942, #966, #1055, #1164, #2000), and #2000's closing line is the finding -- "every PR
carries a red check nobody should act on, which is the failure mode where a genuinely red one stops being
noticed."

#### The decision, and its bound

Dave chose to stop the check being red (September 14, 2026), reversing the "AND THE CHECK STAYS RED ON
THAT, deliberately" paragraph the workflow had carried since #966. **The downgrade is scoped to 429 and
nothing else**, and the line is drawn where this file's own text already drew it: the 429 headline says
*re-running adds none*. Every other failure is something somebody can act on -- a 529 is transient and a
re-run is a real remedy, an unexpected status is unknown, and the pre-SDK class #1245 found was a missing
GitHub App install. A green check would have buried that one.

### CREATE

- [x] `continue-on-error: true` on the review step -- it DEFERS the verdict, it does not take it; the
      decision step at the foot of the job is the only step with an opinion about the colour
- [x] both diagnostic steps rekeyed from `failure()` to `steps.claude-review.outcome == 'failure'`. With
      the verdict deferred, `failure()` is false everywhere in this job, so a condition left that way does
      not error -- it silently skips the diagnostic, which is the #966 silence restored by accident
- [x] the capped, single-lined status published to `$GITHUB_OUTPUT` by the step that already bounded it
      (#1118's treatment carried forward), rather than re-derived unbounded somewhere else
- [x] a decision step: `429` exits 0, and the catch-all -- **including an empty status** -- exits 1
- [x] the reversed paragraph rewritten in place, naming the decision, its date, and what the old argument
      got right, so the next reader does not repair it back
- [x] the annotation deliberately untouched: same `::error` level, same title, same text, still written
      on a 429. It renders whatever the job's conclusion is, so the reason a PR went unreviewed stays
      exactly as readable as it was

### TEST

- [x] 13 asserts added to `scripts/tests/pr-issues.tests.ps1`, in the block that already reads this
      workflow's text for the reason that block gives: a workflow is the one caller no suite gets to run
- [x] they pin the DIRECTION OF THE FAIL-SAFE rather than the wording -- exactly one exempt status, one
      `exit 0`, one `exit 1`, and the default branch being the failing one
- [x] the `failure()` assert is the one that would have caught the mistake made while writing this: a
      condition left on `failure()` prints nothing and looks like a healthy repo
- [x] **discrimination proven**: with the workflow stashed back to the trunk's version, 11 of the 13 go
      red
- [x] `pr-issues.tests.ps1`: **973 asserts, 0 failed**. Full lint + test gate via `open-pr.ps1`
- [~] this change cannot be exercised by its own pull request. The action validates that the workflow is
      byte-identical to the copy on the default branch and, where it is not, **exits successfully in nine
      seconds without reviewing** -- documented at the top of the file since #968. So this PR's own
      `claude-review` tick is green for a reason unrelated to the change, and the first real exercise is
      the next PR opened after this lands

### DEPLOY: fix/2000-quota-red-check

`claude-review` went red on every pull request, and the cause was not a credential. The failure annotation
had already named it -- the org's monthly spend limit, the third of the three 429 kinds this workflow
documents (#1164) -- which no clock resets and no rotation touches. #2000 was filed as a sixth credential
rotation; there was nothing to rotate.

**The check no longer goes red when the account is out of quota** (Dave, September 14, 2026), reversing
the paragraph this workflow had carried since #966. That argument was not wrong about what a red check
MEANS; it was wrong about what a red check DOES after the seventh consecutive one. Seven issues have been
filed against this one check -- #891, #913, #942, #966, #1055, #1164 and #2000 -- and a signal that fires
on every pull request is not a signal.

**The downgrade is scoped to 429 and nothing else**, on the line this file already drew: that headline
says *re-running adds none*, and no act available to a reader of the check changes it. Everything else
stays red because there something can be done -- a 529 is transient and a re-run is a real remedy, an
unexpected status is unknown, and the pre-SDK class is a missing GitHub App install (#1245), which a green
check would have buried. The empty status falls into the failing branch by construction, so a diagnostic
step that dies under its own `continue-on-error` makes the check red rather than green.

**The legibility work is untouched, which is the half worth protecting.** The annotation keeps its level,
its title and its text and is still written on a 429; it renders whatever the job's conclusion is. What
goes away is the red tick beside it, and with it ship-pr's "a check FAILED but the merge was not blocked"
paragraph -- the line that was printing on every ship.

**Score:** 3

#### What makes this deploy extra special

The one way this change can go wrong is silently. `continue-on-error` defers the verdict, so a decision
step that stopped re-failing -- or a diagnostic left keying on `failure()`, which is now false everywhere
in this job -- would turn every failure green, including the setup defects somebody genuinely has to act
on. That regression prints nothing and looks like a healthy repo. Thirteen asserts pin the direction of
the fail-safe against the workflow's own text, 11 of them go red against the trunk's version, and the
`failure()` one is there because that exact mistake was made while writing this and caught by a test
rather than by a reader.

**Score:** 2

#### Pull Request

Stop claude-review going red when the account is out of quota, and keep it red for everything else
