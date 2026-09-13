---
name: check-branch-entry
description: Answer whether this branch carries a WRITTEN changelog entry, the way the CI gate answers it -- so you learn it before the push rather than from a red check. Use it on a branch whose work is finished, when a PR was opened outside open-pr, or when a red "Branch entry" check needs explaining. It adds no rule of its own: it calls the same functions open-pr calls, and -- given a PR number -- the same DEPLOY-lock function ship-pr calls, so a section edited after the PR opened is refused here too. It reports the significance rather than refusing on it, because that refusal belongs to the release cut.
---

# check-branch-entry -- is the entry written?

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-branch-entry.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

**Read-only.** It opens one file and exits 0 or 1. Nothing is written, nothing is pushed.

## What it is for, and why it ships

The branch entry is a convention this plugin ships every reader of, and until August 20, 2026 **nothing
enforced it**. `open-pr` refuses to push an entry that has not been written, and `ship-pr` refuses to
merge while a step is unresolved -- but both are **local**, so a branch pushed by hand or a PR opened in
the GitHub UI meets neither. The convention was enforced by whoever remembered to use the scripts, and a
convention that enforces nothing rots quietly: the entry is the first thing to fall away once it gets
busy, and six months later the changelog does not mention half the work.

So this is the same answer as a script, callable from CI. `adopt-dkj-policy`'s Part 1 places the workflow that
calls it (`.github/workflows/branch-entry.yml`), and this skill is for asking the question yourself.

**It adds no rule of its own**, and that is the design rather than modesty. It calls
`Test-BranchChangelogIsFilled`, `Test-DevelopmentEntryMissing`, `Get-EntryScaffoldFindings` and
`Get-DevelopmentShapeFindings` -- the same functions `open-pr` calls -- and, when you pass `-Pr`,
`Test-DeployLock`, the one `ship-pr` calls. So there is exactly one definition of "written" in the system,
one of "in shape" and one of "diverged". **The claim is only exact from September 8, 2026**: the shape
rules were this script's own until then, and a page promising no rule of its own stood over the one rule
that lived nowhere else -- source repo
[#1650](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1650). Both existing consumers wrote this gate by
hand in shell before it shipped, which is a second definition in every repo, free to drift from the fold
that reads the first one; inbound
[#789](https://github.com/DaveKJohn/claude-code-specialists/issues/789) is the report, and both had
already drifted.

**The lock, with `-Pr` (issue #884).** The DEPLOY section travels four times -- your document, the PR body,
`CHANGELOG.md`, the release notes -- and it is **fixed at the moment the PR opens**, because that is what
the review approved and what the fold takes. So an edit to that section after the PR exists is refused:
`ship-pr` refuses the merge, and this gate is the half that a PR merged from the GitHub UI still meets.
Put the section back to what the PR published, or republish it deliberately with `open-pr.ps1
-RefreshBody`, so the change is reviewable where the review happens.

**An unreadable PR body is not a finding**, the same tolerance `ship-pr` applies: `gh` failing says
something about the token or the network, not about the section, and refusing on that would be refusing on
no evidence.

## What it refuses, and what it deliberately does not

| state | answer |
|---|---|
| the entry file is missing | **exit 1** -- the branch declares nothing. `new-branch` is idempotent; run it here. |
| the document **declares the trunk** | **exit 1** -- an empty document left behind by a fold that ran under the older behaviour, not an entry. Told apart by the branch NAME in the heading, not by its level. |
| the entry is **scaffolded but not filled in** | **exit 1**, naming each field still waiting. This is the case a heading test lets through, because the scaffold already writes a heading and a title. |
| the **DEPLOY section no longer matches the PR** (with `-Pr`) | **exit 1**, naming the first line the PR body does not have. The section is fixed once the PR opens. |
| the PR body **cannot be read** (with `-Pr`) | **exit 0**, said out loud -- a statement about the token, not about the section. |
| **no `-Pr` given** | the lock is skipped and the run says so. Every other check above still runs. |
| the **significance** is not settled | **exit 0**, with the finding printed and the release cut named as where the refusal lives. |
| the branch prefix is **exempt** | **exit 0** -- see the seam below. |
| the branch is the **trunk** | **exit 0**, said out loud: the trunk is where having no document at all is the *designed* state. |

**The significance is reported, never refused, and that is the one thing to know before you compare this
against a gate you wrote yourself.** A score is a judgement about a finished change, and an author who has
not settled it is not blocked from merging over it -- that refusal sits at the release cut (Dave,
August 5, 2026). Both hand-written consumer gates refuse it, one of them reasoning that "tier 0 can never
legitimately stay empty", while this system's own rule reads **TIER 0 OWES NOTHING**: an entry whose score
lines are blank carries no number, so its reach *is* tier 0, which is a complete answer that owes nothing.

## Parameters

| parameter | what it does |
|---|---|
| `-Branch` | the branch to judge. Defaults to the current one. **CI has to pass this**: a `pull_request` checkout is a detached merge commit, so `git rev-parse --abbrev-ref HEAD` answers `HEAD` there, and the script refuses rather than guessing. |
| `-Pr` | the PR number to hold the DEPLOY section against, which turns the **lock** on. Omitted, the lock is skipped and the run says so -- every other check here needs no PR, no token and no network, and that stays true. Pass it on a finished branch to answer *"does my PR still say what my document says?"* before `ship-pr` refuses the merge over it. |

## The seam it reads

| seam | default | what it decides |
|---|---|---|
| `Get-EntryGateExemptPrefixes` | `sync` | branch prefixes that owe no entry, without their slash. A mirror or sync branch carries somebody else's work rather than your repo's, so it has nothing to declare -- both existing consumers reached that answer independently. |

**An unknown prefix is not exempt**, deliberately: a typo in a prefix would otherwise skip the gate in
silence. And the seam **replaces** the default rather than adding to it, so a repo that names its own list
keeps `sync` only by including it.

**`open-pr` reads the same answer, and since
[#1962](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1962) that is one function rather than
two copies.** It has to: this gate waves an exempt branch through as owing no entry, while `open-pr`
composes a PR title from the entry and nothing else -- so the one branch shape this gate deliberately
passes was the one shape `open-pr` could not name a PR for. On an exempt branch it now names the PR from
`-Title`, or from that branch's own oldest commit subject. Both scripts call
`Get-BranchEntryExemptPrefix` in `entry-scaffold-lib.ps1`, so they cannot drift apart about which branches
owe an entry.
