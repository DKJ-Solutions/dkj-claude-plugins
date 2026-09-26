## fix/2525-unarmed-stranded-pr-sessioncheck

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

#2525: PR #2515 sat green, unmerged and unfolded for about two and a half hours while three later
pull requests shipped past it, and no session start reported it. `stranded-sweep-sessioncheck` (#2438)
reads only armed pull requests.

Verified on pickup: the PR's timeline shows `merge-when-green` added only at 11:05 UTC, by the hand
resume, so the original ship never armed it. Whether that ship died before arming or ran `-NoMerge`
cannot be read from the tracker. Either way the gap in the report stands, and the check has to word
both readings.

Chosen: a sibling check and hook rather than widening `check-stranded-sweep.ps1`. That check is gated on
`merge-on-green.yml`, and this hole also exists in a repo with no sweep. The judging is a pure function
beside the stranded verdict, sharing its settle block.

### CREATE

- [x] `Get-UnshippedPrVerdict` in `merge-on-green-lib.ps1`: not a draft, not a fork, not armed where a
  sweep exists, and required checks green for the settle window.
- [x] `scripts/lint/check-unshipped-pr.ps1`: this account's open pull requests (`--author <login>`),
  the cheap disqualifiers before any `gh pr checks`, bounded per call and in total, untrusted names
  scrubbed and the checkout line through `Get-PasteableRef`.
- [x] `plugins/dkj-policy/hooks/unshipped-pr-sessioncheck.ps1`, registered in `hooks.json`.
- [x] Registered as a shared script and mirrored; exempted in `source-repo-guard.tests.ps1`; the
  bounded-capture count moved 83 -> 85; a README row.

### TEST

- [x] `merge-on-green-lib.tests.ps1`: 14 new asserts on the verdict, 208 green.
- [x] `unshipped-pr-gate.tests.ps1` (new): 42 asserts against a fake `gh` and stub checks, green.
- [x] Live run against this repo: `[OK]`, 1.6 s.

### DEPLOY: fix/2525-unarmed-stranded-pr-sessioncheck

A new SessionStart hook, `unshipped-pr-sessioncheck`, lists your own open pull requests that are green,
settled and not armed with `merge-when-green`, with the command that resumes each ship
([#2525](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2525)). Until now a ship that died
before arming left such a pull request, with its branch document stranded off the trunk, and nothing
reported it: `stranded-sweep-sessioncheck` reads armed pull requests only. PR #2515 sat that way for
about two and a half hours. The report also says the pull request may be held back on purpose
(`ship-pr -NoMerge`), because the tracker cannot tell the two apart. It runs in a repo without a
merge-on-green sweep too, where the label changes nothing.

Scored for a session starting in a repo that runs this workflow. It sees a line only when a
pull request is actually owed a merge.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a session-start report, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

A session start now reports your green pull requests that no sweep will merge
