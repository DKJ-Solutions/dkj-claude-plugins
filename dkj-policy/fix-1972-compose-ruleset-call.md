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

Five places claim `adopt-ci-floor.ps1` composes a ready-to-run `gh api` call for the ruleset change it
refuses to apply. It composes none: the only `gh api` line it ever prints is a READ. Verified against the
script before any repair was written -- the two arms that reach a ruleset change hand over prose
(the required-check `[gap]`) and a UI path (the queue).

The issue names three sites -- the `.DESCRIPTION` line, the `$repoSettingsRunner` scaffold comment, and
`check-repo-settings.ps1`. There are **five** -- `.claude/specialists/lenses/05-15-extension.md:882` carries
the same claim and was not reported, and the `.SYNOPSIS` line carries a worse version of it, attributing the
printed command to "a repo that has CHOSEN a merge queue," which matched neither the old behaviour nor the
new. Both scripts are byte-identical to their plugin mirrors, so each repair lands twice.

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
- [ ] all five citations say WHICH ruleset instruction composes, and why the queue one does not --
      including the one scaffolded into every adopting consumer's `repo-settings.yml` header
- [ ] both plugin mirrors kept byte-identical
- [ ] the copy edit's own sweep: four consumer-facing sites that MISATTRIBUTE the composed call to the
      queue arm, found after the five above were already fixed -- `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md`,
      `plugins/dkj-policy/CONTRIBUTING-portable.md`, `plugins/dkj-policy/scripts/README.md`, and this
      repo's own `.github/workflows/repo-settings.yml`, brought in line with the `$repoSettingsRunner`
      template it is otherwise hand-maintained beside

### TEST

- [ ] the composed block printed and read, not merely written
- [ ] `adopt-ci-floor.tests.ps1` covers the composed call and the caveat that goes with it
- [ ] lint gate + all suites green

### DEPLOY: fix/1972-compose-ruleset-call

`adopt-ci-floor.ps1` said in five places that it composes the exact `gh api` call for the ruleset it
refuses to apply, and composed none -- the only `gh api` line it ever printed was a read. The sentence
was load-bearing rather than decorative: `IT NEVER FLIPS THE SETTING, AND THAT IS A RULE RATHER THAN A
LIMITATION` rests on it, so refusing to write was proportionate *because* the reader was handed the call.
Without it the command refused to write and refused to say what to write, which is a weaker bargain than
the one its own docstring defends. Measured while working #1971: three sentences read, no call found, and
the payload reconstructed by reading another repo's live `main-ci-gate` through `gh api` and diffing it --
precisely the "went looking through the ruleset UI" failure that section exists to prevent.

The claim is now true where it carries the argument. The `[gap]` arm -- the one that fires when the trunk
has no required status check, which is #1971's own situation -- prints a paste-ready PowerShell block: a
here-string holding the ruleset JSON, piped into `gh api --method POST repos/<slug>/rulesets --input -`.
It targets `refs/heads/<trunk>` rather than `~DEFAULT_BRANCH`, because the trunk this run was told about
is the authority and need not be the default branch. Where exactly one job id exists across the workflows
that trigger on `pull_request`, that check is filled in; otherwise the placeholder stands and every
candidate is printed with the workflow it came from, so choosing is a copy from a list rather than a hunt.
It still never runs the call, and the strictly-additive, dry-run-by-default contract is untouched --
printing a command is not applying one.

**The merge-queue instruction deliberately stays a UI pointer, and the prose now says so.** That is not
the same rule said twice for two targets: the required-check payload has exactly one free choice, which
the tree can usually answer itself, while a `merge_queue` rule asserts seven scheduling parameters --
merge method, grouping strategy, three limits, two timeouts -- that are policy nobody here has chosen, on
a control GitHub does not even render outside the plans that may have one. All five citations were
reworded to name which instruction composes and why the other does not, including the one scaffolded into
every adopting consumer's `repo-settings.yml` header. **Two of the five were not in the report**: the lens
at `.claude/specialists/lenses/05-15-extension.md` carried the same claim, and separately the
`.SYNOPSIS` line carried a worse version of it -- it attributed the printed command to "a repo that has
CHOSEN a merge queue," which matched neither the old behaviour nor the new. Three from the issue plus
these two is five.

One thing the repair had to move out of the way: `$repoSlug` lived inside the `else` branch of the
rules-read block, so under `Set-StrictMode -Version Latest` it was undefined on the `-RulesJsonOverride`
path -- the path the suite takes and the one the printed call needs the slug on. It is hoisted; the `gh`
fallback stays inside the network-reading branch, because a run with an override file and no network has
no way to answer it and is owed a placeholder instead.

**The copy edit that followed found the claim had spread further than those five.** Four consumer-facing
pages attributed the composed call to the queue arm specifically -- the one arm that, after this branch,
composes nothing at all: the `adopt-dkj-policy` skill page, `CONTRIBUTING-portable.md`, the scripts
README's own table row, and this repo's own scaffolded `.github/workflows/repo-settings.yml`, which still
carried the sentence the `$repoSettingsRunner` template wrote before it was reworded here. Each is now
corrected to name the required-check arm as the one that composes and the queue as the one that stays a
UI pointer. **The real total this branch corrects is nine** -- the five citations above plus these four.

**Score:** 3

#### What makes this deploy extra special

A consumer adopting this workflow with no ruleset on their trunk is handed the call that creates one,
instead of a paragraph telling them a required check is what turns the staleness guard on. The same run
also stops telling them, in a comment it writes into their own repo, that a call it never composed is
waiting further down the file.

**Score:** 3

#### Pull Request

adopt-ci-floor composes the ruleset call its docstring promises
