## feat/2120-resolves-exempt-matchers

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

Inbound [#2120](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2120), filed from
`BWJ-Development/smartwatchbanden`. `dkj-policy-bwj`'s `WORKFLOW-portable.md` carries a close ORDER for an
Asana-linked issue -- the paste-ready block goes onto the issue while it is OPEN, and closing it is a
person's confirmation that the block reached Asana -- so such a branch must ship with `-NoResolves`.
**Nothing read that rule.** Neither `open-pr.ps1` nor `ship-pr.ps1` reads the body of the issue `-Resolves`
names, so the one class of issue the rule carves out is indistinguishable from every other at the point the
flag is typed.

#### Verified on pickup, before anything was written

- **The symptom stands.** `grep -i asana` over `scripts/release/open-pr.ps1` and `ship-pr.ps1` in this tree
  returns nothing.
- **The reason stands.** The resolves gate fetches the open-issue *list* (`gh issue list --json number`)
  and never a body.
- **The proposed repair names mechanisms that exist.** `Get-SeamValue` (`seam-lib.ps1`), and a per-issue
  `gh issue view` in `verify-resolved-issues.ps1` and in `Get-ClosedIssueSet`.
- **The repo is right.** The gate is `dkj-policy`'s, its source is here, and the matchers are the
  consumer's to state.
- **One thing the report proposed is NOT built: a `Get-TicketMirrorMatchers` seam shared with the mirror.**
  The mirror's three matchers live in `dkj-policy-bwj`'s `asana-mirror.ps1`, which ships standalone into a
  consumer's `.github/`; `dkj-policy` cannot reference it, and the layering must not be inverted. So the
  matchers are DATA the consuming repo states, and `adopt-dkj-policy-bwj` proposes exactly the shapes that
  page already defines -- one definition per layer rather than a third.

### CREATE

- [x] `ConvertTo-ResolvesExemptMatchers` + `Get-ResolvesExemptFindings` in `scripts/lib/pr-issues-lib.ps1`
      -- the pure half: normalise/validate the seam's answer (rejections reported, never dropped), then
      match it against the fetched bodies, first matcher winning per issue.
- [x] `Get-IssueBodySet` in `scripts/lib/issue-state-lib.ps1` -- the impure half, `-Utf8`, bounded by the
      same resolve limit and the same network timeout as `Get-ClosedIssueSet` beside it.
- [x] The gate in `scripts/release/open-pr.ps1`, placed AFTER the resolves gate's own block rather than
      inside it: the set it judges is what the body will say at the MERGE, which is `-Resolves` plus any
      closing keyword already published on an open PR. Inside that block it would have been skipped by
      `-NoResolves` -- the very flag its own refusal recommends -- on exactly the resumed branch where the
      keyword is already live.
- [x] The `Get-ResolvesExemptMatchers` record in `scripts/lib/script-contract-lib.ps1` (`decide`,
      `Optional`), and the regenerated `config-blueprint.json`.
- [x] Docs: `CONTRIBUTING-portable.md`'s gate list, a section in the `open-pr` skill, the two paragraphs in
      `dkj-policy-bwj`'s `WORKFLOW-portable.md` that said nothing enforces this, the proposed seam in
      `adopt-dkj-policy-bwj` step 2, and the seam list in `dkj-policy-bwj`'s README.
- [x] The shared-script mirror regenerated.
- [x] **Every match bounded at two seconds**, from the security review: the two inputs are a pattern the
      consuming repo wrote and a body anybody who can open an issue wrote, which is the
      catastrophic-backtracking pair exactly. A timed-out match is reported as *unjudged* -- neither a
      block nor a silent pass -- the remaining matchers still run, and the result is therefore an object
      with `Findings` and `Unjudged` rather than a bare array.

#### This repo states nothing, deliberately

It runs no Asana mirror -- no `Get-Asana*` seam, no `asana-mirror.yml` -- so its own answer is the default,
and the gate is silent here. That is the seam working rather than a gap: the matchers name another system's
marker, so a built-in set would be one family's tracker imposed on every consumer.

### TEST

- [x] `scripts/tests/pr-issues.tests.ps1` -- 46 new asserts: the three accepted matcher shapes, a `$null`
      seam answer and an unwrapped single one, each rejection reason, first-matcher-wins,
      case-insensitivity, an unread body and an empty one, the match bound below, plus the call site (the
      seam read BEFORE any fetch and passed unwrapped, the union with the existing PR body, the refusal's
      wording). The suite runs 1061 asserts, all passing, against 1015 on `main`.
- [x] `scripts/tests/script-contract.tests.ps1` -- the record count 42 -> 43 and the undefined-seam counts,
      each with its reason in the assert message. 316 pass.
- [x] The lint gate and the full suite before the push, via `open-pr.ps1`.

### DEPLOY: feat/2120-resolves-exempt-matchers

`open-pr`'s resolves gate can now be TOLD which issues a merge must not close. A repo answers the optional
`Get-ResolvesExemptMatchers` seam in its own `scripts/repo-config.ps1` with the text that marks such an
issue -- a ticket-mirror marker, a task link -- and the gate fetches the body of every issue the merge would
close, refuses `-Resolves` on a match, and names `-NoResolves` as the way through. Unstated, which is every
repo's default and this one's, it judges nothing and makes no extra `gh` call: the seam is read before any
lookup, so a repo with no second tracker pays nothing for a rule that is not theirs. The set judged is what
the body will say at the merge -- `-Resolves` plus any closing keyword already published on the open PR --
because `-NoResolves` does not strip a keyword the body already carries, and a gate reading the flag alone
would be skipped by the very flag its own refusal recommends.

**Score:** 3

#### What makes this deploy extra special

**The rule this enforces was already written down, and that is exactly the problem it closes.**
`dkj-policy-bwj`'s `WORKFLOW-portable.md` has carried the paste-first close order since inbound #2049, naming
the `dkj-policy` interaction explicitly -- and nothing read it. Inbound #2120 measured what that costs: an
issue carrying an `asana-task:` marker shipped with `-Resolves`, the merge closed it, and the mirror posted
its fallback handover afterwards, carrying the literal `[ADD LINK]` placeholder it writes because CI cannot
know where the result is visible. The rule was followed correctly on other issues in the same period; the
difference was whether the session remembered.

**The report proposed sharing the mirror's own matchers, and that half is deliberately not built.** Those
three matchers live in `dkj-policy-bwj`'s `asana-mirror.ps1`, which ships standalone into a consumer's
`.github/`; `dkj-policy` cannot reference it without inverting the layering. So the matchers are data the
consuming repo states, and `adopt-dkj-policy-bwj` proposes exactly the shapes `WORKFLOW-portable.md` already
defines -- one definition per layer rather than a third. It proposes two of the three: the header-row
matcher is an anchored read of one table row, and the sole-URL matcher already covers that row's link. The
asymmetry is the right direction to be wrong in -- this gate refuses a close, so reaching slightly wider
stops a merge that wanted `-NoResolves` anyway, while the mirror's narrower matcher decides which task to
write to and must not guess.

**A matcher is data and never a predicate**, which is the other thing the report left open. A scriptblock
from `repo-config.ps1` would be the shorter seam and it would put repo-authored code inside the one gate
that decides whether a PR may be opened -- a throw in it takes the gate with it. Data can be validated,
printed back inside the refusal, and asserted without a repo; so an uncompilable pattern is reported and
skipped while the rest of the list goes on working, which is the one failure a repo cannot otherwise see.

**Two review findings are worth carrying, and the first is the same argument arriving by another road.** The
design refuses to run repo-authored CODE inside this gate on the ground that a throw in it would take the
gate down -- and the security review pointed out that an unbounded regex match is that failure by another
mechanism: a consumer's own pattern, a body crafted against it by anybody who can open an issue, and
`open-pr` hangs for whoever resolves that issue. So every match is bounded at two seconds and a timed-out
one is reported as unjudged rather than read as a pass. The reasoning was already written down; what it
had not been applied to was the one input the gate does not own.

**The second is a seam answer this repo does not have and a consumer plausibly does.** A repo saying "not
configured" with `return $null` -- behind a guard clause, say -- was read as ONE malformed matcher rather
than none, because `@($null)` is a one-element array holding nothing: the gate stayed correctly silent, and
printed a rejection for an entry nobody wrote on every PR open. The call site now passes the seam's answer
unwrapped, which is also what lets a repo state a single matcher without wrapping it, and both shapes are
asserted.

For a consuming repo this lands as a gate that is silent until they answer it. The two BWJ store repos get
it the moment they add the proposed function; every other consumer sees nothing change, which is the point.
`BWJ-Development/smartwatchbanden`'s repo-side `PreToolUse` hook was written as a temporary bridge citing
this issue and can come out once this reaches them.

**Score:** 3

#### Pull Request

The resolves gate can be told which issues must not be auto-closed
