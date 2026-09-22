## fix/2284-claim-absorbed-issue

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

#### The gap, and why nothing already in the tree can close it

[#2284](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2284): `claim-issue` is bound to the
act of **starting** an issue -- its own page says so, and its examples are *"fix issue 1234"* and
*"pick up #87"*. An issue can enter a branch's scope without anybody starting it: a finding filed
mid-branch, judged in scope, and repaired on the branch already in flight. Nothing announces a pickup,
so the skill is never invoked, and on the tracker that issue reads exactly like an untouched one.

Verified against the tree, one check at a time:

- **`claim-issue`** -- documented as the first move when an issue number IS the assignment. Filing and
  absorbing is not that shape, so nothing prompts it. Confirmed: its own trigger sentence.
- **`new-branch`'s `-Resolves` already-done check** -- reads the issue *before the checkout*. There is no
  new branch here.
- **`open-pr`'s `Get-TargetIssueWarnings`** -- resolves an issue to a **pull request**, so it finds a
  rival only once one exists. In the measured case the rival landed after the PR was opened.
- **the parked-fix and title-overlap scans** -- the checks built for exactly this collision. Both live
  *inside* `claim-issue`, which is never called.

**The measurement (September 22, 2026).** #2272 was filed from
`fix/2248-guard-raw-foreign-text-prints` and absorbed into it -- correctly, since that branch had already
rewritten registry entry 13 to say the site was repaired. Another session read it as unowned, picked it
up exactly as it should, and shipped it as PR #2275. PR #2282 then went `CONFLICTING` on
`scripts/sync/check-consumer-siblings.ps1`: a trunk merge, a hand conflict resolution, three documents
corrected and a second ship. Nobody broke a rule -- an unassigned open issue is an unowned one.

#### Which of the three shapes, and why

The issue offers three and argues for none. **Option 3 (documentation only) is not enough on its own**,
by this tree's own standard: `claim-issue`'s skill page says it in as many words -- *a rule enforced by
nothing but memory is one that gets skipped* -- and that sentence is the reason the skill exists at all,
since the claim was written down long before it had a step. So the repair is a mechanism, with the
documentation beside it rather than instead of it.

**Option 1 -- a claim taken at the moment the tooling can first SEE the absorption.** That moment is the
run that declares `Closes #<n>`, which is `open-pr`. It is late -- the collision above happened days of
work earlier -- and it is the earliest point at which anything mechanical can know, so it is a backstop
rather than a cure. Option 2 (re-running the resolves check on every push) comes free with it: `open-pr`
runs on every push and on every ship, so a rival that lands mid-review is now reported on the next run.

#### The two narrowings that make it safe to WRITE rather than warn

- **The declared set, never the mentioned one.** This workflow prescribes citing issues in prose, so
  claiming every mention would make the assignee field meaningless across a backlog nobody is on --
  which is the failure #2284 names by name. `Closes #<n>` is the author stating this branch repairs that
  issue, so claiming it writes strictly less than the body this run is about to publish already does.
- **A read that did not answer is never "free".** `Get-ClaimGapVerdict` has four states, and 'unknown'
  is the one that matters: an issue the open list could not account for is left alone. Read the other
  way round, a failed query would hand out claims on other people's work.

### CREATE

- [x] `scripts/lib/pr-issues-lib.ps1` -- `ConvertFrom-OpenIssueList` (the numbers AND the assignees off
      one payload, preserving the `$null`-versus-empty contract the resolves gate depends on) and
      `Get-ClaimGapVerdict` (four states). Both pure, so a suite asserts them without a network.
- [x] `scripts/release/open-pr.ps1` -- the open-issue query asks for `number,assignees` (one more field
      on a call this run already makes, so the check costs no round trip), and the claim check runs at
      the foot of the resolves block: claim an unassigned declared issue, warn on a foreign holder, say
      and write nothing on an unread list. It never refuses.
- [x] The account comes from `Resolve-ClaimAccount`, never `@me` (#1315). Both libs are dot-sourced
      guarded and the call is probed, on closeout-lib's reasoning: a consumer's mirror arrives by plugin
      update rather than by choice.
- [x] `plugins/dkj-policy/skills/claim-issue/SKILL.md` -- filing is not claiming, the measured
      collision, and that `open-pr`'s backstop does not replace claiming it yourself.
- [x] `plugins/dkj-policy/skills/open-pr/SKILL.md` -- the claim check, its table and its five bounds.
- [x] Plugin mirrors rebuilt.

### TEST

- [x] `scripts/tests/pr-issues.tests.ps1` -- the `$null`-versus-empty contract, the assignee parse
      including three schema-drift shapes, all four verdict states, the case-insensitive login
      comparison, and the structural asserts on `open-pr`: the declared set and not the mentioned one,
      the single query, never `@me`, the guarded loads, and that nothing on this path exits.
- [x] All 1122 asserts in that suite pass.
- [x] Security review on the diff (the write is new, and this script is mirrored into every consumer's
      plugin cache, so it runs in other people's repositories). **No blocking findings.** What was traced
      end to end: `$resolveIssues` can only be filled from the author's own `-Resolves`, a closing keyword
      already published on this branch's own PR body, or `$Body` -- never from any issue's title, body or
      comments, and never from the mentioned set. Every value reaching the `gh` argument array is
      shape-constrained: the number is `[int]` throughout so it cannot begin with `-`, the repo comes from
      repo-config, and the account passes `Test-GitHubLoginShape`, whose pattern structurally forbids a
      leading `-` -- so a hostile local `git config user.name` cannot produce a flag. No tracker-authored
      text is read at all: the query asks for `number,assignees`, and only logins reach output.

- [x] Code review on the diff. **One real bug, repaired here:** the account resolution called
      `Get-GitUserName` **without `-RepoRoot`**, while both other call sites in the tree
      (`claim-issue.ps1`, `check-git-identity.ps1`) thread it. Without it that function drops its `-C` and
      reads the **current directory's** config -- and `open-pr.ps1` never calls `Set-Location`, so that is
      wherever the caller stood, which outside a checkout is the **global** config. The skill page's
      promise, *"it claims under the account `claim-issue` would resolve"*, was therefore not guaranteed
      by the code. Worse, the first version of the assert pinned the call *as written*, so it documented
      the gap instead of catching it; the assert now pins `-RepoRoot` and refuses the bare form.

#### Two further review findings, recorded rather than built

- **The assignee map can stay unfetched on one resumed shape.** The open-issue fetch is gated on
  `$mentions.Count -gt 0 -or $resolveList.Count -gt 0`, while `$resolveIssues` can also come from a
  `Closes #<n>` already published on the branch's own PR body. On a resumed run where the keyword exists
  *only* there, the map is `$null` and the check reads that issue as 'unknown' and does nothing. **Never
  wrongly** -- 'unknown' is the safe state by design -- and self-limiting: whichever run first published
  that keyword had `-Resolves` explicit, so the fetch happened and the claim was taken then. Widening the
  gate would buy a re-verification of a claim already made, at one query on every resumed run.
- **The login-extraction loop is duplicated** between `ConvertFrom-OpenIssueList` and
  `Get-AssigneeLogins`. Not shared, and the reason is a dependency rather than taste: `Get-AssigneeLogins`
  lives in `claim-issue-lib.ps1`, which `open-pr` loads **guarded** because a consumer's mirror may
  predate it -- so `pr-issues-lib.ps1`, which is loaded unguarded and much earlier, cannot call into it.
  Sharing would mean moving that function to a third lib, which is a larger change than the six lines it
  would save. The two also parse different payload shapes (`issue view` wraps one array; `issue list`
  gives one per record), so only the inner half is common.

#### The one security advisory, and why it is declined rather than built

The review noted that the only lever over the new write is `-NoResolves`, which also drops the closing
keyword -- so a consumer wanting the PR without the claim has no narrower switch. Declined, for now and
with the reason recorded rather than left implicit: the write is a SELF-claim, bounded to what this run is
about to declare it closes, and it is undone by one `gh issue edit --remove-assignee`. A `-NoClaim` would
be a third flag on a gate that already carries two, and the case for it is hypothetical -- nobody has
wanted it yet. If somebody does, that is the moment to add it, and this paragraph is what they should read
first.

### DEPLOY: fix/2284-claim-absorbed-issue

An issue a pull request declares it closes is no longer left unowned on the tracker. Before the push
`open-pr` reads the assignees off the open-issue list it already fetches and, for each issue this PR
declares, claims an unassigned one under the account `claim-issue` would resolve, warns when somebody
else holds it, and says nothing when the list could not be read.

It closes the one route into a branch that no pickup check can see: a finding filed mid-branch and
repaired on the branch already in flight is never *started*, so it is never claimed -- and the next
session is correct to read it as untouched. Measured at a conflicting pull request, a hand-resolved
conflict, three corrected documents and a second ship.

**Score:** 4

#### What makes this deploy extra special

The assignee field stops lying by omission. Until now it answered "is somebody working this?" only for
issues somebody *started*; the issues most likely to be worked twice were exactly the ones it was silent
about, because they were created by the session that went on to repair them.

For a subscriber of this workflow it is one line in an `open-pr` run they will mostly not notice -- and
on the day two people are on one board, it is the difference between a refusal at pickup and a conflict
at the merge.

**Score:** 3

#### Pull Request

A declared issue is claimed at the push, so an issue absorbed mid-branch stops reading as unowned
