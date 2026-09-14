## fix/1972-compose-ruleset-call

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

#### What #1972 reports, and what the tree actually says

Four places claim `adopt-ci-floor.ps1` composes a ready-to-run `gh api` call for the ruleset change it
refuses to apply. It composes none: the only `gh api` line it ever prints is a READ. Verified against the
script before any repair was written -- the two arms that reach a ruleset change hand over prose
(the required-check `[gap]`) and a UI path (the queue).

The issue names three sites. There are **four** -- `.claude/specialists/lenses/05-15-extension.md:882`
carries the same claim and was not reported. Both scripts are byte-identical to their plugin mirrors, so
each repair lands twice.

Option 2 of the issue is the one taken, scoped: the required-check arm composes the call, because that is
the arm the docstring's argument rests on and the one #1971 needed. The queue arm keeps its UI handover --
a `merge_queue` payload asserts seven scheduling parameters that are policy nobody here has chosen, and the
control is plan-gated to the point where GitHub does not render the checkbox at all. What changes there is
the prose, which stops reading as if it covered both.

### CREATE

- [ ] `adopt-ci-floor.ps1`: the `[gap]` arm composes the paste-ready `gh api --method POST .../rulesets`
      call, with the trunk, the slug and the candidate check filled in from state the run already holds
- [ ] `$repoSlug` hoisted out of the rules-read `else` branch, so the composed call can name it on the
      `-RulesJsonOverride` path without tripping `Set-StrictMode`
- [ ] all four citations say WHICH ruleset instruction composes, and why the queue one does not --
      including the one scaffolded into every adopting consumer's `repo-settings.yml` header
- [ ] both plugin mirrors kept byte-identical

### TEST

- [ ] the composed block printed and read, not merely written
- [ ] `adopt-ci-floor.tests.ps1` covers the composed call and the caveat that goes with it
- [ ] lint gate + all suites green

### DEPLOY: fix/1972-compose-ruleset-call

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

adopt-ci-floor composes the ruleset call its docstring promises

