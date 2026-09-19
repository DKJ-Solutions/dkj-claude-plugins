# Contributing as DaveKJohn

**This is the one page this folder has.** It was two — a `CONTRIBUTING.md` holding this repo's answers and
a `CLAUDE.md` holding the workflow's mechanics — and they merged on August 26, 2026
([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886), Dave): *"The CLAUDE.md in the
dkj-policy folder has no use as well. I want to merge that file with CONTRIBUTING as one
complete CONTRIBUTING file. Because that should be the center of this folder."*

**It sits on top of the repo's [`CLAUDE.md`](../CLAUDE.md) and wins over it on conflict** (Dave,
August 14, 2026). That page describes what holds here whether or not this plugin is installed — never
directly on `main`, branch + PR, CI green, and the three direct-on-`main` exceptions with their bounds. This
page carries what the **workflow** adds: the gates on the branch dossier, how those three exceptions actually
run, and the measurements behind them.

The split is worth what it costs for the reason that page gives: the root loads on **every** session, this
page only when a session touches this folder. A rule that bites only while the workflow is in play does not
belong on the always-on path.

**It layered over a second root page until August 27, 2026, and now carries that page's content instead**
(Dave, in the same instruction that moved `CHANGELOG.md` and the release history into this folder). The
repo's own `CONTRIBUTING.md` held the **standard workflow** — the three rules below — and it was kept at the
root deliberately, so it would still mean something the day the plugin was absent. What that produced in
practice was a reader handed from one page to another to learn how work reaches `main`. Everything the
contribution cycle produces or governs now lives in this folder, this page included, so the standard workflow
is simply stated here, first, ahead of anything the workflow adds to it:

1. **Never commit directly to `main`.** Every change travels on a branch and reaches `main` through a
   Pull Request.
2. **CI must pass before the merge.** The `main` ruleset requires the `lint-en-tests` status check; a
   merge attempted before it goes green returns `BLOCKED`.
3. **One change per branch**, described in the PR, and the branch is deleted after the merge.

**Those three still hold with no plugin installed**, which is what the root page existed to guarantee, and
they are guaranteed by something better than a location: the `main` ruleset enforces rules 1 and 2 on the
server, whoever is or is not running this workflow.

**What the move costs, stated here rather than discovered later.** GitHub reads a contributing page from the
repo root, `docs/` or `.github/` and from nowhere else, so the *Contributing guidelines* link it used to show
above a new issue and a new Pull Request is gone. That link was a signpost, never a guard — the rules it
pointed at are enforced by the ruleset and by CI — but a first-time contributor now arrives at
[`README.md`](../README.md) and this folder rather than at a page GitHub put in front of them.

**The cycle itself is described once, with the plugin**, naming the *seam* wherever a repo owns the answer
instead of asserting one repo's answer as the rule:

📄 **[The contribution cycle — the portable half](../plugins/dkj-policy/CONTRIBUTING-portable.md)**

Read that first. **This page is this repo's set of answers to it, arranged as the five steps work actually
moves through** (Dave, [#894](https://github.com/DaveKJohn/claude-code-specialists/issues/894)). That
arrangement is why there are exactly five numbered `##` sections below and nothing else, why each carries its
substeps as `###`, and why every gate sits as a `####` under the step where it fires rather than in a list of
its own.

**They were four until August 29, 2026**, when `## 1. NEW ISSUE / TASK` was written ahead of them (Dave) and
everything below shifted up by one. The page opened at the branch, so the layer that decides *whether there
is anything to branch on* — a colleague's ticket, or a finding somebody wrote down — was the one part of the
route it did not describe. Every step number moved with it, and so did the two anchors that pointed at one
from outside this page.

**Five `##` sections *in total*, which is why this page begins at step 1.** The two sections that used to sit
between the title and the first step — the seam table and the pointer list — were `##` as well, so the page
read as six top-level sections of which two were not steps. They moved to
[`README.md`](README.md) on August 26, 2026 (Dave), where a folder index is what they always were.

**The levels here moved twice in two days, in opposite directions, and both moves were right.** On
August 26, 2026 the four steps first became the document's own top level (`#`), while the cycle document and
`CHANGELOG.md` moved one *deeper* — those two gained a heading above their contents (`## [Unreleased]`, and a
document title that is no longer an H1). Later the same day this page moved one deeper again, to the numbered
`##` the spec asks for, which is what leaves its `#` for the page title alone.

---

## 1. NEW ISSUE / TASK

**This is the layer before a branch exists.** Step 2 opens a branch and writes the document that carries it;
this step is where the thing that branch is *for* comes from, and whether it is written down anywhere the
next person can find it. A request that only ever existed in a conversation is a request that gets built
twice, or half.

**Two headings, and they are kinds rather than steps** — the only `###` on this page that carry no number.
Work reaches a repo running this workflow two ways, and they fail differently: a **person** files a request
from a tracker outside the repo, or **Claude** finds something while doing other work. Neither precedes the
other, and numbering them would claim an order that does not exist.

**Both end in the same place: a GitHub issue in this repo.** That is what step 2 branches on, and it is why
the two halves sit under one step rather than in two places.

### Human

**Somebody else's tracker asks, and a GitHub issue here carries the analysis.** In the repos where this
happens, colleagues file in **Asana** and the repo answers with one issue per ticket, the Asana link in its
head. The issue is not a copy of the ticket: it is the layer between the request and the code — what was
asked in the requester's own words, what we already know, and then the gate that decides whether it can be
built at all.

**That gate is the reason the step exists.** A request written by somebody who is not going to build it is
incomplete in ways the builder otherwise discovers halfway through the branch. So the issue answers *do we
know enough?* before a branch is opened, in one of two fixed sentences with the reason behind it; at *no*,
the missing pieces go back to the requester and the work waits. **A ticket with open questions is not
built** — that is the standing agreement, and it is what keeps the discovery in front of the branch instead
of inside it.

**The rules are portable and travel with this plugin**, as this step's own section in
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md#ticket-work--the-layer-before-the-branch):
where the provenance boundary between a copied field and our own judgement sits, how to tell a gap from a
notice, why six kinds of question are not gaps, and what the log carries. **They were a page of their own,
`TICKETWORK-portable.md`, until August 30, 2026** — the portable cycle began at the branch, so the rules for
its first step sat outside the document that describes it and nothing in that document pointed at them
([#1123](https://github.com/DaveKJohn/claude-code-specialists/issues/1123)).

**A repo that receives ticket work writes the other half itself** — its tracker, its language, the form of a
ticket, its closed `State` vocabulary, and the border with its own research documents — as a local
`TICKETWORK.md` beside this page. `smartwatchbanden` is
the worked example.

**This half is a no-op in this repo, and that is an answer rather than an omission.** Nothing is filed into
this repository from a tracker upstream of it: Dave assigns directly, and what he assigns becomes a branch
under step 2 or an issue under `### Claude` below. So there is no local `TICKETWORK.md` here and no Asana
link in any issue head. **It is described anyway for the same reason step 5 is** — the workflow ships this
layer, the consumers running it do have that tracker, and a page that only documented what this repo
happens to use would leave them reading a route with a hole in it.

### Claude

**A finding becomes an issue, not a question at the end of the turn.** Something real that is outside the
assignment — a bug, a doc that has gone stale, a measurement that contradicts what a page claims, a decision
that is not yours to make — is filed and the assignment is finished. Dave has to be able to close a session
and clear its context without first answering everything that was found along the way, and the close-out
names the numbers so he can see what was parked rather than lost.

**Filing needs no permission, and asking for it is the same failure as not filing.** *"Shall I open an issue
for this?"* leaves the finding in the reply for Dave to answer, which is precisely what filing prevents.

**The question to answer first is not *may I* but *does it still stand*.** Read the code, the script or the
output that would have to be true for the finding to hold — the same treatment an inbound report gets,
applied to your own. Where it collapses, say so plainly instead of filing a weakened version of it. Where it
holds, the rest of the bar is short: search the tracker so you add to the existing thread rather than open
its duplicate, one subject per issue, and say what you **measured** and what you only **inferred**. Do not
file work you were asked to do, or a finding you can simply fix inside the assignment.

**An inconsistency is always filed**, whatever its size and whoever caused it — two statements in the tree
that cannot both be true. Where your own branch created it, file it anyway and say so in the issue, because
that is the reader's first question. Scoping a contradiction out of the work is a reason not to edit the
file; it is never a reason not to file it.

**The labels are the branch prefixes, which is what makes an issue readable as work.** `enhancement`, `bug`
and `documentation` map onto `feat/`, `fix/` and `docs/` and onto the changelog types they produce — see the
table in step 2.1 — so an issue already names the prefix its branch will get.

**`inbound` is the fourth label and it means something different.** It marks a core improvement discovered in
a *consuming* repo: the shared agent defs, manuals, personas and skills have one source, so a consumer files
here with [the inbound template](../.github/ISSUE_TEMPLATE/inbound-improvement.md) instead of patching its
own copy, and the improvement comes back to every consumer through a release. **On this side that is simply
the ordinary chain**, because this is the source — but not before the item is verified. A filed report is a
snapshot of the moment somebody wrote it, and **six things fail independently**: the symptom, the reason, the
proposed repair, the size, the subject and the repo. Getting one wrong produces a repair that satisfies the
report and is wrong, which is worse than the original defect because it now carries a citation. The
measurement behind each is in the
[`triage-inbound` skill](../.claude/skills/triage-inbound/SKILL.md).

**Claim an issue before working it** — and read the claim as well as write it: an issue that already carries
an assignee is somebody's. The tracker is the only thing two sessions share, so an unassigned issue is
indistinguishable from an untouched one, which is how the same repair gets built twice and discovered at the
merge. A claim with no branch and no recent activity is a question for Dave rather than a locked door.

**The step that performs it is [`claim-issue`](../plugins/dkj-policy/skills/claim-issue/SKILL.md)**, and it exists because this
rule was written down for as long as the workflow has and enforced by nothing — `gh issue edit <n>
--add-assignee @me`, left to a session to remember, to type, and to read the result of. Measured here on
September 5, 2026 ([#1456](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1456)): **0 of 67**
assigned issues carried `DaveKJohn`, an identity holding 132 merged PRs and 83 authored issues in the same
repo. That report's own corrective action was *behavioural*; the skill is what makes it mechanical, and it
does the three things the one-liner cannot — it never sends `@me` (see below), it **refuses on a closed
issue**, which `--add-assignee` claims silently, and it **refuses one somebody else holds**, which
`--add-assignee` joins. It writes one assignee and nothing else: the branch stays
[`new-branch`](../plugins/dkj-policy/skills/new-branch/SKILL.md)'s, one step later.

**`@me` writes whichever account `gh` holds, which is not always the one your commits will name.** It
resolves through the GitHub API, while the branch a second session correlates the claim with carries the
`git config user.name` identity — so a checkout with both claims under one name and commits under the other,
and nothing reports it. Measured September 3, 2026 ([#1315](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1315)):
`gh` was authenticated as `DaveKJohn` while `git` committed as `davekokbwj`, so the idiom above put the wrong
account on #1314 and it had to be corrected by hand. Since then
[`check-git-identity.ps1`](../scripts/lint/check-git-identity.ps1) reports the split from a SessionStart hook
in every repo that has this plugin, so a session is told before it claims anything. Where it fires, **claim by
name** until the two agree — which is what `claim-issue` does for you: it reads both identities and writes the
**git** one, because the commits are the half nothing can rewrite afterwards.

**These rules are Chris's, stated here rather than owned here.** The filing bar, the six inbound checks and
the claim live in the orchestrator's persona body, which ships with `dkj-subagents-alpha` — so where this paragraph
and that body disagree, the body is the source and this is the bug. They are written out anyway because a
contributor reading this page has no guarantee of having the plugin, and a route with a step that is only
legible to an agent is not a route.

Then step 2 opens the branch that carries it out, and the issue number goes in the DEPLOY body so the fold
carries it into [`CHANGELOG.md`](CHANGELOG.md) with the change that closed it.

---

## 2. DEVELOPMENT

**It was `NEW DEVELOPMENT TASK` until August 29, 2026** (Dave). The word carried its weight while this step
opened the page and a development task was the first thing that happened here; step 1 has owned the arrival
since earlier that day, so `NEW` had started claiming what the step above it does. The step numbers did not
move with the name — every `2.x` on this page and in [`README.md`](README.md) still points where it did.

### 2.1. Create the branch and the empty `<branch>.md`

**Two steps, one command, and that is the point rather than a shortcut.** `new-branch` does both: a branch is
never entry-less, so there is no moment at which the branch exists and its document does not. They are
numbered separately because the *order* matters to a reader — the branch is what the document belongs to —
not because anybody performs them apart.

`new-branch` creates the branch **and** its document in one move: a branch is never entry-less. The document
belongs to the **current branch** and exists only while one is open — the fold removes it at the merge, so on
the trunk it is simply not there. That absence is the trunk's normal state, not a file somebody deleted, and
it is why the file is named here without a link.

**The name IS the branch** — `fix/thing-v1` gets `dkj-policy/fix-thing-v1.md`, slashes
flattened and nothing else. **One per branch since September 3, 2026**
([#1255](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1255)), where it was a single shared
`development.md`, and **without the `development-` prefix since later that same day**
([#1335](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1335)). The prefix bought a reader
nothing the folder does not already say; what it quietly bought the tooling was a glob that could not reach
this folder's own pages, and that narrowing is now stated as an exclusion instead — see `ReservedNames` in
`Get-BranchFilePaths`. That shared path did not collide on checkout, which is what the old reasoning said, but it
collided on *merge*: every merge to `main` left every other open PR conflicting on it, and a conflicting PR
gets **no check suite at all** — so `lint-en-tests` could never go green and the PR could never merge. The
full measurement, including why the fold is not the fix and why a `.gitattributes` merge strategy would not
have worked either, is in
[`DEVELOPMENT-portable.md`](../plugins/dkj-policy/DEVELOPMENT-portable.md#why-the-name-carries-the-branch).
**Nothing identifies a document by its filename**, then or now: the fold and every gate that needs to know
which branch a document belongs to read it out of the document's own heading, which is what keeps a `-v2`
suffix free.

**Four `###` headings and never a fifth**, and nothing branch-specific above `### PLAN` (Dave, August 26, 2026).
PLAN, CREATE, TEST and DEPLOY are the whole top level; a section needing its own heading goes in as a `####`
under whichever of the four owns it, and everything between the title and `### PLAN` is the scaffolder's generic
guidance. **Both were conventions a writer kept, and now a gate refuses both here** — measured the day they
were stated, when `check-branch-entry.ps1` gave byte-identical output at four headings and at five. That
day closed the measurement; [§3.2.6](#326-the-shape-gate-on-the-document-around-the-entry) is what closed
the gap it left, and it carries which half holds in a consumer and which is this repo's own. Recorded --
both rules, and the reasoning behind each, though not the measurement itself -- in
[`DEVELOPMENT-portable.md`](../plugins/dkj-policy/DEVELOPMENT-portable.md).

**Pick the prefix by what actually changes**, not by which files move along: `docs/` is purely text, `feat/`
is a capability that is new or larger than it was, even when documentation comes with it.

| Type of work | Branch name | GitHub label | Changelog type |
|---|---|---|---|
| New or extended capability | `feat/<description>` | `enhancement` | Feat |
| Correction of an error in something existing | `fix/<description>` | `bug` | Fix |
| Documentation, workflow explanation, manual content | `docs/<description>` | `documentation` | Docs |

**There is no `chore/`, and `Test-BranchName` refuses it outright.** Chore is the name for work that lands
*directly on the trunk* under one of the named exceptions, so a chore branch is a contradiction. `Chore`
stays a recognised changelog **type** — every entry already written under it must still validate, and it is
what an unknown prefix falls back to. Recognise both, write one.

**A `-v<N>` suffix is optional and typed by hand — `new-branch` no longer completes it** (it did, from
August 23 to September 3, 2026; dropped because in 209 branches carrying it none was ever bumped to `-v2`,
and it broke a consumer wrapping the script for a branch whose name it does not own — inbound #1224). A
second cycle on the same subject is `docs/thing-v2`, typed deliberately; a rerun of `new-branch` on the same
name resumes that branch rather than opening the next one. The refusal on `final` in
[`branch-info.ps1`](../scripts/lib/branch-info.ps1) is the same rule from the other end: a name claiming to be
the last word is a prediction, and a hand-typed number is the honest form.

**Re-read the file after `new-branch` has written it.** It is the only file here written out of band, and an
editor tracking what it last read refuses the next write until it has read again — one read fixes it and
nothing is lost. The fold no longer joins that list: it removes the document rather than rewriting it, so
there is nothing left to re-read. The portable statement, with the measurement, is in
[`DEVELOPMENT-portable.md`](../plugins/dkj-policy/DEVELOPMENT-portable.md#the-file-is-written-under-you-once-per-cycle).

**The HTML comments are the form, not somebody's notes.** They say what a good answer looks like, and the fold
strips them on the way to `CHANGELOG.md`, so leaving one standing is not a defect. There is no template beside
the file and no empty copy on the trunk — the portable page is where the whole form can be read without a
branch open. **There is no `branch/templates/` any more either** (Dave, August 23, 2026): two generated
reference copies sat there because the working files were deliberately bare, and the merged document carries
its own guidance, so the reference and the file you write in are the same page.

### 2.2. Write `### PLAN`, `### CREATE`, `### TEST`

**Three phases, written in order, and each one is a list of `- [ ]` steps.** PLAN is what the work turns out
to be once it has been looked at rather than guessed at; CREATE is the steps that build it; TEST is the steps
that prove it. A step is open until it is resolved — `- [x]` done, or `- [~]` dropped **with the reason on the
line**, which exists so nobody ticks a box for work they did not do.

**The repo's standing gates are NOT written here as steps** (issue
[#1060](https://github.com/DaveKJohn/claude-code-specialists/issues/1060), August 29, 2026). TEST carries
what proves *this branch*; the lint gate, the test gate and the link gate fire on their own at 3.1 and
refuse on their own, so a step reading *"all suites green"* duplicates a gate rather than adding one. And the
duplicate is not free: `open-pr` **refuses to push while any step above DEPLOY is open**, so such a step can
only be ticked by running the suites by hand *before* the run that was going to run them anyway. Measured in
the session that filed #1060 — the hand-run exceeded the 120s foreground timeout and had to be backgrounded
twice, while `open-pr`'s own gate ran the same 54 suites in **59s** and **60s** immediately afterwards. See
3.4 for why the gate is the faster of the two, which is not the reason it looks like.

**A section needing its own heading goes in as a `####` under whichever phase owns it.** That is how the four
top-level headings stay four.

### 2.3. Write `### DEPLOY`

Its own step because it is written **last** and from a different question: the three phases above say what
must *happen*, DEPLOY says what the change *does*. See 2.5 for what "secured" means, and why the two are
separate numbers rather than one.

### 2.4. Verify every checkbox is resolved

**Nothing here is on your memory.** `open-pr` and `ship-pr` both refuse while a step above DEPLOY is still
open, and there is no `-Force`. This step is the moment to read the list rather than the moment to discover
one was missed — the step-list gate under 3.2 is the same question asked by a machine.

### 2.5. Wrap and secure DEPLOY: the development cycle is complete

**DEPLOY is written LAST, once TEST says so.** The other three phases carry the steps (`- [x]` done, `- [~]`
dropped with the reason on the line); `### DEPLOY: <branch>` **is** the changelog entry and folds
**verbatim** into `CHANGELOG.md` at the merge. Written while steps above it are still open it states an
intention, and no gate holds it against what landed. A checkbox inside that section is prose, and no gate
reads it as a step.

**Its links are written folder-relative to `dkj-policy/`, the whole document**, because the
DEPLOY section folds into `CHANGELOG.md`, which sits there — and so does this file, so a link that resolves
here resolves there too. `../scripts/x.ps1`, never `scripts/x.ps1` — the second resolves to
`dkj-policy/scripts/x.ps1`, which does not exist, so it reads correctly on the branch and is dead
once it lands, and `open-pr`'s link gate refuses it. This is what `<branch>.md`'s own header boilerplate
means by *"Relative links in that text resolve FROM THIS DIRECTORY."* (It was root-relative until issue
[#1041](https://github.com/DaveKJohn/claude-code-specialists/issues/1041), which moved the gate's base to the
changelog's own directory when `CHANGELOG.md` moved off the repo root.)

**The audience tier is `2` here, so the entry asks two questions rather than four.** Tier 0 needs no heading —
the `### DEPLOY: <branch>` line is its section and its answer goes directly underneath — and the one
audience tier gets `#### What makes this deploy extra special`. Both sit at the entry's own section level,
beside `#### Pull Request`. A repo that has stated *no* audience tier gets the older shape instead, a
`##### Tier N` sub-section per tier, nested one level deeper; that is the portable half's fallback and not what
you will see here.

**In each tier, the reason goes ABOVE the `**Score:**` line** — anything below it is discarded.

**And then the development cycle is complete, and the branch waits.** Nothing else happens on it until an
explicit *open the PR* command, which is step 3.1. That wait is short and usually implicit — see
[`CLAUDE.md`](../CLAUDE.md) for the two narrow classes of change where it is a real stop, and why everything
else runs straight through.

---

## 3. PULL REQUEST

### 3.1. Open the PR

**This is where the waiting ends.** Step 2.5 leaves the cycle complete and the branch parked on an explicit
*open the PR* command — see [`CLAUDE.md`](../CLAUDE.md) for the narrow set of changes that genuinely wait on
Dave's word, and for why the default is that they do not.

`open-pr.ps1` is the one entry point: it runs the lint and test gates first, then pushes, then opens the PR.
On an error or a failing suite **nothing is pushed and no PR is opened** — `-SkipLint` / `-SkipTests` are the
escape valves, and using one is a decision rather than a convenience.

**A gate that will not *finish* is a third case, and `-SkipTests` is the wrong answer to it**
([#1443](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1443), September 5, 2026). The test
gate runs the suites in parallel and works the lane count out from the core count; on this machine that is 16
lanes, and the harness killed two runs of it for running out of memory. `-MaxParallel <n>` — on `open-pr.ps1`
and forwarded by `ship-pr.ps1` — runs them **smaller** instead of not at all, so the branch still carries a
measurement. `-MaxParallel 4` passed the same 68 suites in 888s against the default's 716s: 24% slower, and
it finishes. The numbers, and why the default was deliberately left alone, are on the
[`open-pr` skill page](../plugins/dkj-policy/skills/open-pr/SKILL.md#when-the-test-gate-will-not-finish--maxparallel-not--skiptests).

Its own number because the three gates below fire *here*, at the push, and because what it publishes is fixed
at this moment: 3.2 is what it puts in the body, and 3.2.5 locks that body against later edits to the
document.

**One more gate fires here and reads nothing on the branch at all: the PR's label has to exist.** The label
comes from the branch prefix via the repo-owned seam table, and it used to go straight to
`gh pr create --label` — so a label that had been renamed or retired killed the create *after* every gate had
run and the branch was on `origin`, leaving a pushed branch with no PR. One `gh label list` now answers it
ahead of the lint and test gates. It refuses rather than falling back to a default label, because a repo whose
own workflow gates on the label would otherwise go green on a label that says nothing; the refusal names the
label, the prefix, the seam file and the labels that do exist. Measured in a consumer on September 1, 2026
(inbound [#1221](https://github.com/DaveKJohn/claude-code-specialists/issues/1221)), where two labels were
deleted org-wide because the issue **type** now carries that classification — the seam table was correct the
day before. Full mechanics on the [`open-pr` skill page](../plugins/dkj-policy/skills/open-pr/SKILL.md#the-label-gate-does-the-label-your-seam-names-still-exist).

### 3.2. Copy the last DEPLOY into the PR

`open-pr.ps1` composes the PR body from the document, and **the gates below read it on the way**. All but the last run
locally, before the push and before the merge; that one runs in CI, and it exists because the local gates are
escapable by not using the scripts. The repo's own lint and test gates are separate and stated in the [root `CLAUDE.md`](../CLAUDE.md):
`open-pr.ps1` runs [`check-plugin-integrity.ps1`](../scripts/lint/check-plugin-integrity.ps1) and then every
`scripts/tests/*.tests.ps1`, refusing to push on any error or failing suite.

**And before any of them, one thing that is not a gate: `open-pr.ps1` COMMITS that document if it differs
from `HEAD`** ([#1269](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1269), September 3, 2026).
Every reader above reads the working tree; the push ships `HEAD`; and the fold, the DEPLOY lock and the CI
check in 3.2.7 all read the committed copy. Measured on PR #1267: the run passed every gate against a
filled-in working copy, pushed the empty scaffold, published the filled-in body, and CI failed on arrival.
It commits that one file and nothing else — never `git add -A`, and anything else you had staged stays
staged. Why it commits rather than refusing, and why neither the dirty-tree warning nor the backing gate
covered it, are on the
[`open-pr` skill page](../plugins/dkj-policy/skills/open-pr/SKILL.md#the-document-commit-what-the-pr-says-is-what-the-branch-carries).

#### 3.2.1. the entry gate, on whether there is an entry at all

**September 8, 2026 ([#1632](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1632)).** Before any
of the gates below reads the entry, `open-pr.ps1` asks whether there *is* one:
`Test-DevelopmentEntryMissing` refuses a `dkj-policy/<branch>.md` whose DEPLOY section is gone.

**It is a separate gate rather than a widened scaffold gate, and that is the part only the code explains.**
The gate below refuses an entry still carrying the scaffolder's wording — so it works by *matching* strings.
Delete the section that carried them and there is nothing left to match: `Get-DevelopmentEntryText` falls back
to the whole document, hands the scaffold gate the guidance **preamble**, and that preamble carries no
scaffold marker because nobody scaffolded it. **So the scaffold gate passes by ABSENCE**, and the branch ships
with no entry text whatsoever — with the PR title and description composed out of the guidance. The fallback
cannot simply be narrowed, either: a legacy entry-only file *is* an entry from its first line, which is why
this is a second predicate beside it and not a stricter version of it.

**How a document reaches that state is not a deliberate deletion.** It is an edit that anchors on the first
phase heading as a plain string and truncates the file there. In a document scaffolded before
[#1654](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1654) that string occurs **twice** —
once as the real heading, and once inside the guidance blockquote describing it, which comes first — so the
cut lands on the wrong one and the body glues onto a sentence cut in half. Two documents shipped that way
(#1632 and #1644) before the gate existed. The guidance names that heading by position now, so a document
scaffolded since carries it once; every branch open across that change still carries both, which is why the
gate's own refusal keeps naming the literal as a diagnosis.

**`-Force` is honoured**, matching the scaffold gate below rather than being absolute. There is no document
this house wants pushed in this state, but the predicate reads a *shape*, and a consumer holding one nobody
here has seen must have a way past a gate that is wrong about them. The refusal names the file, says the fold
would otherwise paste the guidance into the changelog as the change description, and points at `new-branch`,
which is idempotent and restores the section.

**The same predicate runs in CI**, ahead of the same scaffold check in
[`check-branch-entry.ps1`](../scripts/lint/check-branch-entry.ps1) — one definition in
[`entry-scaffold-lib.ps1`](../scripts/lib/entry-scaffold-lib.ps1) rather than two free to disagree.

#### 3.2.2. the scaffold gate, on the changelog entry itself

**August 3, 2026.** `open-pr.ps1` refuses to push a branch whose entry still carries the wording
`new-branch.ps1` scaffolded it with — the placeholder title, the "to do / where I left off" heading, or the
fallback body. **Measured, after it had already shipped:** three of v3.2.0's twenty-one entries kept that
heading with a status appended behind it, and it reached the release notes *and* the per-plugin `CHANGELOG.md`
files that travel to consumers in the plugin cache. The window closes at the merge and closes **invisibly** —
the fold moves the entry into `CHANGELOG.md`, the next release moves it on into `releases/`, so by then the
place a reviewer would look is the one place it no longer is. Fenced code is excluded, so an entry documenting
this mechanism is not accused of it; the escape valve is deliberately separate from the lint and test skips,
because it overrules a judgement about content rather than skipping a tool. The wording lives in **one**
shared source ([`entry-scaffold-lib.ps1`](../scripts/lib/entry-scaffold-lib.ps1)) read by both the script that
writes it and the gate that refuses it — a copy in each would make the gate silently miss whatever the writer
changed.

**Two of those three strings are now recognised without being written** (August 6, 2026). The `branch/` split
moved the step list out of the entry, so the entry is no longer scaffolded with a to-do heading over a to-do
placeholder — its placeholder asks what the change *does*. The gate keeps refusing the retired wording, and
that is not politeness towards history: every branch in flight, here and in every consumer, carries an entry
with those strings right now, and consumers receive the new scripts through a plugin update rather than by
choosing to. A gate that forgot them would wave exactly those entries through. **Recognise both, write one** —
the same rule the tier line gets, and the same rule the folder rename got in step 3 below.

#### 3.2.3. the step-list gate, on the branch's own plan

**Dave, August 6, 2026.** A branch reaches a PR when its own plan is finished, so `open-pr.ps1` refuses to
push and `ship-pr.ps1` refuses to merge while the step half of `<branch>.md` has an unresolved step.
**Both**, deliberately: the requirement Dave gave is about the *merge*, and `open-pr` has an escape valve — a
PR opened through it, or by hand on github.com, would otherwise land with an unfinished plan.

**Three marks, not two.** `- [x]` is done, `- [~]` is dropped with the reason kept on the line, and a step
still carrying the scaffold's placeholder is refused whether or not it is ticked. The third mark is what makes
the gate safe to leave with no override at all: without it the only way past a step that turned out not to be
needed is to tick it, which teaches people to report work they did not do — and a gate that then says success
is worse than no gate. **A branch with no step list at all is not refused**: that is the one-commit typo fix,
and refusing it would make the mechanism ceremony.

**At the merge, this gate and the DEPLOY lock below read the branch's own commit — `refs/heads/<branch>` — and
not the checkout** (issue [#970](https://github.com/DaveKJohn/claude-code-specialists/issues/970),
August 27, 2026). `ship-pr` waits on CI, 10m57s on the run that measured this, and a session that backgrounds
the ship and starts the next piece of work has moved `HEAD` by the time the gates look. Measured then: the gate
refused PR #969 over `- [ ] TODO: the first step of this branch`, the scaffold TODO of a branch created *during*
the wait, while the PR's own document had no open step at all. **That instance failed safe and the inverse is
why it was repaired**: reverse the two documents — the shipping PR carries an unresolved step, the checkout has
since moved to a branch whose steps are all ticked — and the gate passes on somebody else's document and merges.
A gate with no `-Force`, satisfied by a file the PR does not contain, reports the requirement as met while
nothing checked it.

**The remedy is a different read, not a new refusal.** The other shape on the table was to refuse once `HEAD`
has moved since the run started, and it was declined: a backgrounded ship beside the next piece of work is the
ordinary shape of that window, so that guard would break the ordinary case in order to protect it. The commit
is also *provably* what merges — step 1 pushes the branch on every path through the script, a fresh PR and a
resumed one alike — and it needs no network, which matters in a gate that must not refuse because a token
expired. **The path is resolved against that same commit**, not merely read out of it: `Resolve-BranchFilePath`
chooses between the candidate names by reading each one, and resolving against the checkout would fail in the
silent direction — a name the branch does not carry reads as *no document at all*. One consequence worth
knowing: **a step ticked in the editor and not committed no longer satisfies the merge gate**, which is what
its own message has always asked for.

#### 3.2.4. the backing gate, on whether anything is behind the plan

**Dave, issue [#1026](https://github.com/DaveKJohn/claude-code-specialists/issues/1026),
August 28, 2026.** The step-list gate above asks whether the plan is *finished*. It cannot ask whether
anything was actually built, and nor can the three gates beside it: **all four read this document, and none
reads the diff**. So `open-pr.ps1` asks the second question — a plan reading as finished with **nothing
committed on the branch besides this document** does not become a PR.

**What it was measured on.** PR #1025 merged an entry describing two new rules in a manual whose edit was
never committed. The branch's whole diff was `<branch>.md`; the fold then *removes* that file, so the merge
delivered a changelog entry and no content at all. Every gate was green.

**The measurement is not new — its delivery is.** `park-cycle`'s backing note
([#960](https://github.com/DaveKJohn/claude-code-specialists/issues/960), repaired by #976) had already named
the count, named the state and given the instruction that would have prevented the merge. It wrote it into a
**commit body**, which is exactly right for the reader that note exists for — a session on a second device
picking the branch up from origin — and invisible to the session that is holding the uncommitted file and
about to open the PR. Both readers now ask one function, `Get-BranchBackingFinding`, so a park that alarms and
a gate that stays silent cannot disagree over one tree.

**Two shapes, two answers, and the split is by whose fault it is.** Work sitting uncommitted **in this working
copy** is this session's own omission and one `git commit` from repaired — that one is **refused**. **Nothing
uncommitted here either** means the work is not on this machine at all, which from here cannot be told apart
from a branch legitimately shipping its entry alone — that one is **said out loud and allowed**, because
refusing it would wedge the cross-device flow #960 exists to serve.

**It is `-Force`-able, unlike the step-list gate above.** The valve exists because a branch whose whole
deliverable really is the changelog entry is rare rather than impossible, and `-Force` still prints the warning
— a gate whose escape valve falls silent is a gate that quietly stopped existing.

**And the gates now say when they ran against a dirty tree.** This is the other half of the same measurement,
and it is a sentence rather than a refusal. The lint gate and the suites judge the **working tree**; the push
ships **HEAD**. On a clean tree those are the same thing and a green result is evidence about the PR; on a
dirty one they are not, and nothing said so — #1025's lint run walked the manual *with* both new rules in it
and reported zero errors. `Get-GateFingerprint` cannot answer this: it hashes the dirty list away, so it knows
*same tree as last time* and never *is this tree HEAD*. A dirty tree mid-flight is ordinary, so it is never
refused here; what was missing was only the line that stops a green result from being read as proof.

#### 3.2.5. the DEPLOY lock, on the section the PR published

**Dave, issue [#884](https://github.com/DaveKJohn/claude-code-specialists/issues/884), August 25, 2026.** The
DEPLOY section travels four times — this document, the PR body, `CHANGELOG.md`, the developer release notes —
and it has to be the same thing at every stop. So it is **fixed at the moment the PR opens**: `ship-pr.ps1`
refuses the merge when the document has since diverged from what the PR carries. No override, like the
step-list gate beside it.

**What it closes is a window that shuts invisibly.** An edit made after the review lands in `CHANGELOG.md` and
from there in the release notes having been seen by nobody — and the fold *removes* this document at the
merge, so the place a reviewer would compare the two is the one place it no longer is. The same shape as the
scaffold gate's own measurement, one document further along.

**The PR is the recorded copy, so the lock stores nothing.** Three mechanisms were weighed and Dave chose this
one: compare against the open PR. A fingerprint stamped into the document would add an artefact to the file
the fold consumes and have to be stripped again on the way out; a silent re-sync at merge time refuses nothing
and is therefore not a lock. `open-pr` already publishes the section, and reading it back *is* the comparison.

**It is checkable at all only because the section now travels verbatim.** Until the same issue,
`Get-PrDescription` dropped the `### DEPLOY:` heading and promoted every remaining one — so body and document
were two *renderings* of one section, and a comparison would have had to reproduce that transform to make
sense. The heading travels now, which reverses the August 9, 2026 promotion **on today's shape only**; the
legacy path keeps promoting, because there the H2 genuinely stays behind. The reasoning sits at both branches
in `pr-body-lib.ps1`. **An unreadable body is not a finding** — `gh` failing says something about the token or
the network, not about the section, and a gate that refused on that would be refusing on no evidence.

**Which copy of the document it compares is the paragraph at the end of 3.2.3**, and it matters more here than
there: this section is what step 5 folds verbatim into `CHANGELOG.md`, so a lock satisfied by a stray checkout's
document would be approving the fold of a section it never read.

#### 3.2.6. the shape gate, on the document around the entry

**September 8, 2026**
([#1650](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1650)). Two rules Dave enforced by
reading on August 26, 2026 — **four `###` headings and never a fifth**, and **nothing branch-specific above
`### PLAN`**, both stated under 3.1 — were checked in exactly one place: the CI gate below, which *reports*
rather than refuses. So none of the gates above ever saw them, and nothing refused a malformed document
before the push.

**What that cost, measured on this repo's own PR #1644.** Its document lost its `### PLAN` heading and most
of its guidance block to a splice that anchored on the string `### PLAN` — which occurs inside the guidance
blockquote as well, in the very line forbidding branch-specific content above it. Push, PR, the required
check, the merge and the fold all completed. Each gate above was right on its own terms: every step above
DEPLOY was resolved, DEPLOY matched what the PR published, and there was committed work behind the plan.

**And an advisory red is the wrong instrument here, for a reason peculiar to this document.** Step 5
**removes** `dkj-policy/<branch>.md` on a successful fold, so after the ship the red check points at a path
that no longer exists and a reader following it finds nothing to open. The evidence is destroyed by the thing
whose success it was warning about — a far weaker signal than an ordinary advisory failure, where the file is
still there to inspect.

**The repair was the seam, not a new rule.** Both rules are one function now,
`Get-DevelopmentShapeFindings` in `entry-scaffold-lib.ps1`, so `open-pr` refuses on them while the file is
still on disk and the author is still holding it, and the CI gate below reports exactly what it reported
before, on the same text, from the same code. **It fires between 3.2.2 and 3.2.3** — the numbering here is
reading order, and the run order asks three questions about one document: is there an entry, has it been
written, does the document around it still hold its form.

**`-Force`-able, like the scaffold gate above** and for its reason: the predicate reads a shape rather than
words, and a consumer holding a document nobody here has seen must have a way through a gate that is wrong
about them.

**The scoping is asymmetric, and that is the design rather than an inconsistency.** The heading count is the
source repo's own rule — [`DEVELOPMENT-portable.md`](../plugins/dkj-policy/DEVELOPMENT-portable.md) states
heading-blindness as a *feature*, because a consumer may keep headings of their own in a document they
adopted — so it runs behind `Test-IsWorkflowSourceRepo`, and the caller passes that answer in. The preamble
rule holds **everywhere**, because it reads the shape and not the text: the guidance block is blockquoted in
whatever language it was translated into.

**Two things this deliberately did not do.** `branch-entry` was **not** made a required check — that is a
ruleset change and Dave's own act, and it would put a check that *reports* significance in front of every
merge. And the CI half still reports rather than refuses, which is the design stated immediately below.

#### 3.2.7. the CI gate, because the gates above are local

**August 20, 2026** (inbound
[#789](https://github.com/DaveKJohn/claude-code-specialists/issues/789)). The gates above live in
`open-pr` and `ship-pr`, so every one of them is escapable by not using them: a branch pushed by hand, or a PR
opened in the GitHub UI, meets none of them. The convention was therefore enforced by whoever remembered the
scripts — and a convention that enforces nothing rots quietly, which matters here because `CHANGELOG.md` is
the only readable answer to "what is merged but not yet released".

**It re-checks every one of them but the backing gate, and that exclusion is deliberate** (August 28, 2026).
That gate's whole subject is what sits **uncommitted in a working copy**, and a CI runner has no working copy
— it checks out the commit, so its tree is clean by construction and the measurement there would always read
zero. A check that cannot fail is not a check, and adding one would state a guarantee CI is in no position to
make. The half of it that *is* visible from a commit — a branch whose diff is its development document alone
— stays local on purpose too: it is a judgement about whether a change was finished, which belongs where the
author can still act on it.

[`check-branch-entry.ps1`](../scripts/lint/check-branch-entry.ps1) closes that, and
[`.github/workflows/branch-entry.yml`](../.github/workflows/branch-entry.yml) is the handful of lines that call
it on every PR. **It adds no rule of its own** — it calls the same `Test-BranchChangelogIsFilled`,
`Get-EntryScaffoldFindings` and `Get-DevelopmentShapeFindings` that `open-pr` calls, and, given the PR
number, the same `Test-DeployLock` that `ship-pr` calls. So there is one definition of "written" in the
system, one of "in shape" and one of "diverged", rather than a second set in CI. **That claim only became
exact on September 8, 2026**: the shape rules were this script's own until 3.2.6 moved them out, which is
the whole of #1650 — a sentence promising no rule of its own, standing over the one rule that lived nowhere
else. **Reading a PR body is why the workflow carries read access to pull requests** — the entry
checks themselves need no token, no network and no PR, so the lock is opt-in by parameter and the gate stays
runnable on a branch that has none.

**Two consumers had already written this gate by hand, and both had drifted from the convention** — that is
the measurement behind shipping it rather than documenting it. Each refuses a merge over a missing significance
score, justified in one of them by *"tier 0 can never legitimately stay empty"*, while
`entry-scaffold-lib.ps1` reads **TIER 0 OWES NOTHING** and Dave placed that refusal at the release cut on
August 5, 2026, precisely so an author who has not settled a score is not blocked from merging over it. So the
shipped gate **reports** the significance and names the cut as where the refusal lives. It is simpler than the
hand-written version, not more complex: `Get-EntryScaffoldFindings` already catches the case those gates
reached for the score to catch — a freshly scaffolded entry, which carries an H2 and a title and so passes any
heading test.

**Its own workflow file, not a job in `ci.yml`**, and the trigger is the reason: `ci.yml` also runs on a push
to `main`, where there is no branch document at all. A job there would be red on the trunk after every merge.
The script answers the trunk case gracefully as well, but a gate should not need that grace to be pointed
correctly. **It is not in the `main` ruleset** — making a check required is a repo-settings change and
therefore Dave's, so today it reports on every PR and blocks nothing.

#### 3.2.8. the always-on budget gate, on what every session pays before any of this

**Dave, issue [#2037](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2037), September 16, 2026:**
*"find a durable way for ALL consumers to keep CLAUDE.md under 100.0k chars, because I notice it goes over
150k everywhere."* Every gate above judges the branch — its code, its entry, its plan. This one judges the
**always-on document path**: `CLAUDE.md` plus everything it `@`-imports, which every future session in this
repo reads before a single assignment is given.

**The finding is that measurement alone had already failed.** `measure-always-on.ps1` has reported this
figure since August 2026 and reaches no verdict by design
([#861](https://github.com/DaveKJohn/claude-code-specialists/issues/861)) — and all four measurable repos
went over 100,000 B anyway: 199,253 B, 150,202 B, 117,014 B, and this repo at **109,385 B**, the smallest of
them. A report that is portable, correct and ignored is the whole argument for a bound.

**The unit is the path and not the root file**, because `wc -c CLAUDE.md` misses the 30,267 B of orchestrator
persona that `SPECIALISTS.md` imports from the marketplace clone — 27.7% of this repo's total, and invisible
to the obvious check.

**A ratchet, not a cliff, and that is the choice it lives or dies on.** Every measurable repo was over on day
one, so a hard refusal is a gate that is `-Force`d once and never obeyed again. Instead the limit is
`max(budget, baseline)`: over the ceiling the recorded baseline holds and **growth** is refused, at or under
it the ceiling holds and **crossing** is refused. The baseline falls on its own whenever a branch measures
less — `open-pr` writes it and commits it with the branch's own document — and rises only under
`-Raise -Reason "<why>"`, which puts the reason in a tracked file where a reviewer can argue with it.

**The refusal names where the weight goes**, in the order the four classes pay: procedure a plugin already
ships on demand; layer-specific detail into `.claude/rules/*.md` with `paths:`; evidence, measurement and
declined-option history into the owning specialist's lens or a skill page; repo-specific craft detail into
that lens. A ceiling with no destination is a red check nobody can clear.

**Three carriers, one verdict, and only one of them writes.** `open-pr` before the push (with `-Record`),
`.github/workflows/always-on-budget.yml` on every PR, and the `always-on-sessioncheck` SessionStart hook,
which prints the headroom so the number is in front of whoever is about to add to it rather than discovered
at a red check. Every decision sits in `always-on-budget-lib.ps1`; the check script is the printing and the
exit code. CI and the hook never pass `-Record`: a read-only carrier that rewrote the ratchet's own memory
would be the one thing able to raise it with nothing in any diff to say so.

**And one premise the issue never weighed, which would have made the whole thing flap.** A CI runner has no
marketplace clone, so that 30,267 B persona import does not resolve there — the same commit would measure
109,385 B locally and 79,118 B in CI. The baseline therefore records every document's size **keyed by its
import target**, and a run that cannot resolve one carries the recorded figure and says so. A document that
is neither resolvable nor recorded is reported as **unmeasured** and never counted as zero: a path that looks
healthier than it is would be this mechanism failing in the direction nobody notices. For the same reason the
arithmetic is in **LF bytes** rather than on-disk bytes — a CRLF checkout is one byte per line above what the
repository stores, which is ~1.4% on a 1,346-line file: plausible, wrong, and enough to refuse a branch that
changed nothing.

**Like `branch-entry`, it is not in the `main` ruleset** — a required check is Dave's act, not a script's.

### 3.3. Check whether another PR is already merging

**One merge at a time, and a PR that arrives second waits its turn** (Dave,
[#912](https://github.com/DaveKJohn/claude-code-specialists/issues/912), August 26, 2026). Before the merge,
look at what else is open and green: `gh pr list --base main --state open`. If nothing else is on its way in,
this step costs one command and you move on.

**No gate enforces this, so it is on you.** Nothing in `open-pr.ps1` or `ship-pr.ps1` looks at the other open
PRs, and GitHub is happy to merge two at once — the same shape as the four-headings rule in the branch
document, and stated here for the same reason: a convention nobody writes down is a convention nobody keeps.

#### 3.3.1. Nothing else merging — go to 3.4

The normal case. The queue exists for the moment two pieces of work finish together, not as a step every
branch performs.

#### 3.3.2. Something else is merging — this PR joins the QUEUE and waits

**Two PRs cannot merge at the same time, and `CHANGELOG.md` is why.** Every branch's fold writes into the
same file at the same place — the top of `## [Unreleased]`, newest to oldest — and it writes there *after*
the merge, on `main`. Two folds racing each other break in the gap between the merge and the fold, which is
the state nothing reports: the PR is already merged, the entry has not landed, and every gate stays green
until a release trips over it.

**Two ways it breaks, and the second is worse than the first.** The later run's fold push is rejected as
non-fast-forward, so the entry sits unpushed on a local `main`; or `ship-pr.ps1` step 5 aborts on
`git merge --ff-only origin/main` before the fold runs at all, leaving the merge done and the entry still in
the branch document. Both are recoverable and neither announces itself. Waiting is cheaper than either.

**Waiting is the whole mechanism — there is no queue file and no lock.** The PR stays open and green; the
merge is simply not performed yet. A branch that waits costs nothing, because the DEPLOY lock
([3.2.5](#325-the-deploy-lock-on-the-section-the-pr-published)) has already fixed what this PR publishes:
time passing does not change it.

#### 3.3.3. The queue ahead has drained — sync with `main`, then merge

**Bring the branch up to date with `main` before merging it.** The PRs ahead have each folded an entry onto
the trunk, so `main` carries `CHANGELOG.md` content this branch has never seen. Fetch and merge `origin/main`
into the branch, and let CI run once more against the result.

**What that buys is hygiene, not ordering — and the distinction matters.** The fold always inserts at the top
of `## [Unreleased]` on whatever `main` it is standing on, so the order entries end up in follows the order
the PRs *merged*, not how fresh either branch was. Syncing a stale branch does not move its entry up. **The
queue is the thing that keeps the order**; this step keeps the branch from merging a tree it was never tested
against.

**And `ship-pr.ps1` step 5 is not this step.** It checks out `main`, fetches, and ff-merges `origin/main`
before folding — so the fold itself is never performed against a stale trunk. What it does not do is bring
the *branch* forward, which is what this step is.

### 3.4. Merge the PR

**The merge does not wait, with two exceptions.** The portable half leaves this to each repo, because it is a
governance decision rather than a configuration value. Here, a finished branch **opens, merges and folds in one
motion without waiting for Dave**. The lint gate, the test gate and CI prove this class of change is sound, and
anything that does turn out wrong is one revert PR away.

Two kinds of change stop and wait for his word: work with a **visible result** that has to be judged by eye,
and work that is **irreversible or outward-facing** (a release, a version bump, a tag, repo settings, or
publishing beyond the normal PR flow). The full statement is in
[the safety rules](../CLAUDE.md#never-directly-on-the-main-branch--via-branch--pr).

**The merge waits on one CI check and only one.** Both gates run as CI in
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — on every PR and every push to `main` — under the
job id **`lint-en-tests`**, which is the exact name the `main` ruleset requires as a passing status check. A
merge attempted before it goes green returns `BLOCKED`. That job id is deliberately not English, and renaming
it would silently break the ruleset binding — every future PR would sit unmergeable, waiting on a check that no
longer exists. See [`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md).

**And nobody sits through that check** (Dave, issue
[#985](https://github.com/DaveKJohn/claude-code-specialists/issues/985), August 27, 2026). `ship-pr.ps1` is
started as a **background** command and the session carries on: the merge cannot move before `lint-en-tests`
is green whichever way the script is run, so the only thing a foreground wait buys is a second look at a
result `open-pr`'s own gates gave minutes earlier. Measured on
[PR #980](https://github.com/DaveKJohn/claude-code-specialists/pull/980) that same day — `lint-en-tests`
**11m48s**, the same suites locally **292s** — and over 65 blocking runs a median CI leg of **8m 01s**, which
at 73 merged PRs in a week is **9h 45m** of session time.

**The condition is not optional, because step 5 checks out `main` in this tree.** So the next move after
backgrounding a ship is either a **lane** —
[`worktree-lane.ps1 -Name`](../plugins/dkj-policy/skills/worktree-lane/SKILL.md), the
worktree is where you build and the primary checkout is where you ship — or nothing at all. A close-out that
reads *"PR #N opened, shipping in the background"* is a finished assignment, not an open point. Anything else
started in the primary gets `HEAD` pulled out from under it mid-branch, which is the hazard the two gates in
3.2.3 and 3.2.5 were hardened against and that step 5 was not.

**And "anything else" includes a tidy-up, which is the half that does not read as starting something** (issue
[#1145](https://github.com/DaveKJohn/claude-code-specialists/issues/1145), August 30, 2026). Step 1 of the
ship — `open-pr`'s lint and test gates — is the one step that reads the **working tree**, for a minute or
more, and a second command in the same checkout during that minute moves it under them: `new-branch.ps1`
cutting a branch, `worktree-lane.ps1` moving the tree. Measured on
[PR #1144](https://github.com/DaveKJohn/claude-code-specialists/pull/1144): one suite of 55 red inside the
gate, green standalone on the same commit seconds later, because `dkj-policy/<branch>.md`
exists on the branch and not on the trunk and the suite walks every `*.md` under that folder. **No gate
refuses this** — `open-pr` reports it instead: a red whose tree moved says it is not trustworthy, and a green
whose tree moved is not recorded as gate evidence. Re-run the gate; do not go hunting the failure.

**The script that produced that measurement was repaired at the source** (issue
[#1147](https://github.com/DaveKJohn/claude-code-specialists/issues/1147), August 30, 2026). It was a
`prune-merged.ps1 -IncludeRemote` run borrowing the trunk to fast-forward it — and Chris's lens sends a
session to that exact command rather than let it classify `git ls-remote` output by hand, so the two
instructions collided and neither page said so. `prune-merged` now advances the trunk with
`git fetch <remote> <trunk>:<trunk>`, which writes a ref that `HEAD` is not on and moves no tree at all; the
one move it has left runs only when it reaps the branch you are standing on, and a branch under a gate is
unmerged by definition. **The detection above stays**, because it is the right repair for the class and
every other tree-mover in the clone is still there.

**And "nothing at all" is the default rather than a judgement call** (Dave, issue
[#1060](https://github.com/DaveKJohn/claude-code-specialists/issues/1060), August 29, 2026). A lane is for a
session that has *already been given* the next piece of work; where there is none, the session closes out and
stops, and Dave merges the moment he sees the check go green. **Hovering is the failure this closes**:
backgrounding the ship and then polling its log, or re-reading `gh pr view` until the check flips, is the
same wait wearing a different hat and costs the same 8m 01s. The portable statement of the rule — *ask whose
clock it is; a gate you must run yourself is run however long it takes, and somebody else's clock is not
waited on at any duration* — is in Chris's persona body, so every consumer of this workflow receives it.

**Nothing is lost by stopping, and that is the point.** `cycle-autopark` (issue
[#900](https://github.com/DaveKJohn/claude-code-specialists/issues/900)) has already pushed the branch's
document to `origin`, the PR carries the reasoning, and a backgrounded `ship-pr` merges and folds without
anybody watching. Where no ship was started at all, the branch simply stays parked: the PR is left green for
Dave, and the fold is a [`fold-changelog-entry.ps1`](../scripts/release/fold-changelog-entry.ps1) run on
`main` in the next session.

**And the last act is `git checkout main`** (Dave, August 29, 2026, on being told a session could be cleared
while the tree still stood on the branch). Everything above protects the *work*; none of it tidies the
*checkout*. A session that reports itself finished from a feature branch tells the requester two different
things at once — the terminal says the context can be cleared, `git status` says the work is mid-flight — and
the requester is right to believe the second one. So parking ends on the trunk, and only then is the close-out
honest.

**This is the one place where landing on a clean trunk is the goal rather than the trap.** Chris's lens
records the inverse: `ship-pr` step 5 leaves you on `main`, which reads as *ready* rather than as one command
away from committing to the wrong place. Both hold, and they are not in tension — the trunk is where a session
**ends**, and the branch check at the start of the next assignment is what stops it from being where the next
one silently begins.

**Why the gate beats a hand-run, since the obvious explanation is wrong.**
[`Invoke-TestSuiteGate`](../scripts/lib/native-capture-lib.ps1) is *not* an in-process pass — it launches
every suite as its own `powershell` child, exactly as a hand-run does. Two other mechanisms account for the
gap, and both are absent from a hand-run: the pool is **parallel** since issue
[#512](https://github.com/DaveKJohn/claude-code-specialists/issues/512), so the gate costs its slowest single
*file* instead of the sum (measured at 27 suites: 510s one at a time against 128-263s parallel), and
`open-pr` **records the pass** — `Test-GateEvidence` / `Save-GateEvidence` in
[`gate-lib.ps1`](../scripts/lib/gate-lib.ps1), keyed on a fingerprint of the tree — so a second run over an
unchanged tree is skipped entirely. A hand-run pays the sum and earns no credit towards the gate that follows
it.

**Two larger shapes were declined when this was written down**, and #985 stays open as their home. A
*green-and-unmerged reporter* at session start would have re-added half of the `session-status` reporter that
[#957](https://github.com/DaveKJohn/claude-code-specialists/issues/957) removed on purpose five minutes before
#985 was filed. A *detached watcher* that merges when the check passes would put the merge and the fold — a
commit landing directly on `main` under a named exception — behind a process nobody is reading.

**Backgrounding says nothing while it runs, and that is normal.** The output is buffered, so an empty log and
an idle `gh` child are not a stall. Judge progress from `git log` and `gh pr view`, never from the log file.

**A second check appears on every PR and does not block.**
[`.github/workflows/claude-code-review.yml`](../.github/workflows/claude-code-review.yml) runs an automated
review over the diff and posts inline comments, under the job id `claude-review`. It is advisory: the ruleset
names `lint-en-tests` and nothing else, so a red `claude-review` is a finding to read rather than a merge
blocker. On a pull request from a fork it fails by construction — GitHub withholds secrets from fork-triggered
workflows, which is the safe outcome and not a defect to work around.

**And a red one names its own reason, in the run that produced it — read that before filing anything.**
`ship-pr` prints it for you: on the path where the merge proceeds it fetches the failing check's annotations
and relays the sentence that workflow wrote about itself, so the reason lands in the same transcript as the
warning. Where that sentence reads `out of quota`, the review did not run at all — `CLAUDE_CODE_OAUTH_TOKEN`
is a subscription credential, its allowance is the one interactive work draws on, and re-running adds none of
it back. Nothing in the diff repairs it.

**Read the reason for WHICH of three limits it is — a session cap (hours), a weekly one (days), or an
individual spend limit an account admin has to raise — but do not plan around any reset TIME it names.** The
spend-limit case has no clock at all: it was measured on August 31, 2026, three runs reading "You've hit your
individual spend limit — ask your admin to raise it"
([#1164](https://github.com/DaveKJohn/claude-code-specialists/issues/1164)), and neither "wait hours" nor
"wait days" is the move there. Where a reset time *is* named, that half is upstream's, relayed rather than
vouched for, and it has been measured wrong: on August 29, 2026 a run failed at 18:02 UTC saying the weekly
limit reset on August 31, and two later runs reviewed successfully at 18:43 and 18:55 the same evening
([#1112](https://github.com/DaveKJohn/claude-code-specialists/issues/1112)). Why it came back early was not
measured and should not be guessed at. The practical reading: a stated reset is a ceiling, not a schedule, so
a later PR may well be reviewed long before it.

**This is worth a paragraph because reading it wrong is the expensive part.** Nine threads have been filed
here about `claude-review` red on every PR, and they did not all have the same cause: the early ones were
credential ([#891](https://github.com/DaveKJohn/claude-code-specialists/issues/891),
[#942](https://github.com/DaveKJohn/claude-code-specialists/issues/942)), and every one from
[#966](https://github.com/DaveKJohn/claude-code-specialists/issues/966) onward has been this quota state —
most recently [#1164](https://github.com/DaveKJohn/claude-code-specialists/issues/1164). #966 is the one that
cost something: it was filed against a log already reading `api_error_status: 429`, inferred an expired token
instead, and concluded that a secret needed rotating — and #1164 made the same read again, "looks expired,
recurrence of #966/#942", against three runs whose annotation already named an individual spend limit. So
read the reason the run gives before deciding which kind of failure it is; where it is the quota, there is
nothing to file.

Merge method: **`merge`** — a merge commit, not a squash (`Get-PrMergeMethod`).

### 3.5. Copy the last DEPLOY into `CHANGELOG.md` under `## [Unreleased]`, newest to oldest

### 3.6. Delete `<branch>.md`

**3.5 and 3.6 are one command, and the first direct-on-`main` exception.**
[`fold-changelog-entry.ps1`](../scripts/release/fold-changelog-entry.ps1) folds the entry into `CHANGELOG.md`
and clears it, and on request makes that commit itself — **bounded to `CHANGELOG.md` plus
`<branch>.md`**, which the same run removes. Since August 2, 2026 that bound is enforced rather than
merely intended: the commit names its paths, so nothing else in the tree can ride along. Committing stays
opt-in, because it is this exception being used.

**The scope grew by one path on August 6, 2026 and the exception did not widen with it**: the step list is
cleared by this run, so leaving it out would produce a commit that clears half the pair — the entry gone from
`main` while the step list still shows the merged branch's ticked boxes. That argument now only reaches a branch
cut before the two files merged, since one document is cleared in one move. See
[Rendall #06](../.claude/specialists/lenses/specialist-05-06-lens.md#changelog).

**The same run refreshes the pending tally** — the one line under `## [Unreleased]`, which reads
`**4 / 9 minor entries**`: how many of the pending entries reach this repo's audience tier, out of how many
are waiting, and which bump that work has earned. It is **derived, never accumulated**:
`Set-ChangelogPendingSummary` recounts the entries in the document it is about to
write, so no counter exists to drift and a hand-edited list is corrected by the next fold. The **cut**
rewrites it too, on the emptied document — the line sits in the changelog's head, which is exactly the part
a cut keeps, so without that second call a freshly released changelog would carry an intact count over an
empty list. Requested by Dave in
[#1515](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1515), and it adds no path to the
exception above: the tally is written into `CHANGELOG.md`, which is one of the two paths the fold commit
was already bounded to.

**It was a per-tier breakdown until September 7, 2026** — `**9 entries pending** -- 5 at tier 0, 4 at tier 2.
Tier 2 is this repo's audience: 4 of 9 reach it.` — and Dave's instruction on
[#1545](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1545) was to keep it short and
simple. What survived is the reach fraction and the bump; the buckets went, because they are one `grep` away
in the entries the line sits directly above. **The two numbers answer different questions and may differ**:
the fraction counts tier 2 and above, the bump follows tier 1 and above, so `**0 / 8 minor entries**` says
nothing reaches a subscriber while the version still owes a minor for what reaches management. Naming the
bump reversed a stated decision — the rule used to live only in `Test-ReleaseBumpEarned`, in `release-lib`,
which the fold does not load — and the way it was reversed is `Get-EntryEarnedBump` in `entry-scaffold-lib`,
the layer both callers already share, so there is **one** copy of the rule rather than the second one that
decision was written to prevent.

The pending entries, ranked furthest-reach-first, are in [`CHANGELOG.md`](CHANGELOG.md).

---

## 4. CUT RELEASE

A release here is **repo-wide and in lockstep**, which works because this repository holds *one* product whose
plugins are one system — see [One product, one repository](../README.md#one-product-one-repository). A second,
unrelated product would get its own repository and marketplace rather than joining this release train.

**A release only ever happens on Dave's explicit request.** It is the irreversible, outward-facing class from
step 3.4. Once asked for, the closing steps of that same checklist are covered by the request — including
publishing the GitHub Release. Step 5 below is the one part that is **not**.

**The step numbers below match [#894](https://github.com/DaveKJohn/claude-code-specialists/issues/894)
exactly, and they did not before.** That issue used to ask for a step creating *three* kinds of release note
under one root inside this folder. Its August 26, 2026 edit dropped that step, so section 4 is seven steps on
both sides and nothing is pending between them.

**The subject did not go away with it, and it is now settled.** It stood on its own as
[#914](https://github.com/DaveKJohn/claude-code-specialists/issues/914) and was carried out the same day: the
tier-0 root renamed `development` -> `changelog`, and it and `github/` moved out of the repo root into this
folder beside `audience/`. The three note roots are siblings now, `releases/` at the root holds nothing but
the release list, and the layout question the step was about has an answer rather than an owner.

### 4.1. The bump: tier 0 only is a PATCH, anything higher is a MINOR

This repo runs the shared floor unchanged. The portable half asks each repo to say so out loud where its own
rule is stricter than the gate's, because a contributor otherwise picks their bump type from the wrong rule.
**Here there is no stricter rule:** tier 0 only is a patch, tier 1 or higher earns a minor, and a major
additionally needs ten minors in the current major line. In code that is one line — the `EarnedBump` that
`Get-PendingRelease` computes in [`release-lib.ps1`](../scripts/lib/release-lib.ps1).

The audience of each release document follows the **tier**, not the bump, which is what keeps that looser rule
honest: a tier-1-only minor writes the internal note and no consumer document, so nobody outside is handed a
document about work they cannot see. Full model:
[the tier model](../plugins/dkj-policy/RELEASES-portable.md#the-tier-model) and
[what a release must earn](../plugins/dkj-policy/RELEASES-portable.md#what-a-release-must-earn).

### 4.2. Cut the `## [Unreleased]` section out of the changelog

### 4.3. Paste it into the development notes

### 4.4. Write the GitHub version

### 4.5. Publish it as a new tag

**4.2 through 4.5 are one command, and the second direct-on-`main` exception.**
[`cut-release.ps1`](../scripts/release/cut-release.ps1) bumps all plugin versions in lockstep, generates the
release notes, **empties `CHANGELOG.md` down to its intro**, commits that on `main`, and tags the version.
Deliberately no branch or PR — just like the fold. See
[Rendall #06](../.claude/specialists/lenses/specialist-05-06-lens.md#versioning--releases).

**Where those documents live**, since the step names and the tree do not line up by themselves: the changelog
notes are `dkj-policy/releases/changelog/<major>.x/<version>.md` and the GitHub notes
`dkj-policy/releases/github/<major>.x/<version>.md` — **the same answer here as in a consumer**,
which is the part that changed on August 26, 2026 (#914). Both trees sat at this repo's root until then, on
the reasoning that `Test-IsWorkflowSourceRepo` keeps a source's root files at the root. That reasoning covers
the files a repo would have anyway — its changelog, its release list — and these are not those: nothing
writes them but a cut, so they belong to the workflow wherever it runs. The seams
`Get-ReleaseChangelogNotesRoot` and `Get-ReleaseGithubNotesRoot` still answer this per repo; they simply no
longer answer it differently for the source. (The first of those was `Get-ReleaseDevelopmentNotesRoot` until
#947 the same day. #914 had left it, on the reasoning that renaming a seam is a contract change a consumer
has to act on — right about the cost, wrong about who pays it: `Get-SeamValue` takes an array of names, so
both read sites read the old name too and a consumer who defined it acts on nothing.)

**A major needs two commits ahead of it, and they run under this same exception** (Dave, August 9, 2026).
`cut-release.ps1` refuses to file a new major's row under the previous major's section and does not open the
new section itself, and the live assert in
[`release-lib.tests.ps1`](../scripts/tests/release-lib.tests.ps1) pins which major
[`releases/history.md`](releases/history.md) targets — so cutting `v4.0.0` took `b2cea9c` (the `#### 4.x` heading
plus its empty table header) and `1d2d3ff` (that pin, with the reason written above it) before the cut would
run at all. Both were made by hand, on `main`, while the exception on paper covered only the release commit
itself.

**Neither half is automated, and that is the decision rather than a gap.** Opening the section by hand is the
milestone moment the script deliberately leaves to a person, and the assert is the same fact written a second
time on purpose — a script that repointed it would remove the tripwire that caught the half-done edit here.
**A major is not rare**: `v1.0.0` through `v4.0.0` fell on July 14, July 23, July 30 and August 9, 2026, one
every nine days or so.

**Why this exception exists in this shape, and every alternative that was weighed and declined, is in
[Rendall #06](../.claude/specialists/lenses/specialist-05-06-lens.md#the-release-craft-received-from-claudemd-august-15-2026)**
— the entry format, the tier model and its audience knob, the significance rubric, the release documents and
their writing norm, the bump rules, and the measurements behind each. It was moved off the always-on path on
August 15, 2026, where it was 41,168 B and 32% of everything loaded before a word of work. **Read it before
changing any rule above**: most of what looks arbitrary here was measured there.

### 4.6. Write the audience version

**This is the third direct-on-`main` exception.** The cut generates the development notes and the audience
**draft**, then names the documents it deliberately did not write. The internal note has its own script
([`new-internal-note.ps1`](../scripts/release/new-internal-note.ps1)), which needs the development notes as
input and so can only run *after* the cut. Both are hand-written, and since **August 23, 2026 (Dave)** both are
committed **straight onto `main`** in the commit after the tag — bounded to those documents and to a cut that
was actually asked for. In this repo the audience note lands under [`releases/audience/`](releases/audience/)
in this folder, which is what `Get-ReleaseNoteRoot` answers.

**This reverses the August 4, 2026 answer, and the reversal is worth reading with what it reverses.** That day
Dave was offered the wider version — the release exception covering "the release *and* its written notes" — and
declined it, on the reasoning that already carries the bounds on the root page: an exception is only safe while
it stays the size it was granted at, which is what had to be repaired in `ship-pr.ps1` two days earlier. **That
argument was not overturned; it is why the third exception arrives with its paths written out.** What changed is
the judgement about which size is right. A release is one procedure, and running it across two routes left the
trunk holding a tagged release whose own notes were still in review — visible in the artefact rather than only
in the process, because `CHANGELOG.md` is empty from the cut onward and the document that replaces it is
elsewhere.

**The measured instance behind the old route stays true and stays here**, because it is what a future reader
will reach for if the question reopens:
[PR #432](https://github.com/DaveKJohn/claude-code-specialists/pull/432) shipped the `v3.2.0` internal note
through a branch and PR, gates green and entry folded, with nothing about being post-tag causing friction. So
the PR route was never *failing* — it was working and split in two, which is a different complaint and the one
that decided it.

**What does not change with the route.** The tag still holds the *draft*: the cut commits and tags in one
motion, so the written version lands in the following commit either way. And the gates still run — being off a
branch skips the PR, not the lint and the suites. `open-pr.ps1 -GatesOnly` is how you run them from the
trunk:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/open-pr.ps1 -GatesOnly
```

**The `releases/history.md` in this folder is the living index** — the cut inserts its own row, so never add
one by hand for a release a script will write. Its
[release list](releases/history.md#the-release-list) is what has actually been cut. Beside it,
[`releases/README.md`](releases/README.md) is a different document: this repo's answers to the portable
release page. They shared the name `README.md` until August 27, 2026, when the list moved into this folder
and had to stop.

**Everything under `releases/audience/` is a published record**: links may be repointed when a target moves,
prose is never rewritten. **What that protects is a line that was TRUE when it was published** — going stale
afterwards is the record working. A line that was **false when it was written** is not protected by it, and
correcting one restores the record rather than breaking it; the rule, and how to mark the correction, is in
[`RELEASES-portable.md`](../plugins/dkj-policy/RELEASES-portable.md#once-it-has-landed-it-is-a-published-record--and-that-protects-only-what-was-true).
**The worked example is one sentence carried across two adjacent notes**: the publication item in `4.10.0.md`
was true at its merge and overtaken an hour later — stale, deliberately untouched — while `4.11.0.md` inherited
it, updated the count without re-reading the target, and was therefore false on arrival and is corrected. That
is the failure to watch for here: **a stale line copied forward becomes a false line.**

### 4.7. Optional: wait for a `SHIP MAIN` or `PUSH LIVE` command

**Optional because it depends on one seam answer, and here that answer is no** (Dave,
[#894](https://github.com/DaveKJohn/claude-code-specialists/issues/894), August 26, 2026). Where
`Get-LiveStage` names a stage — a Shopify repo, where `main` still has to be pushed to a live theme before a
customer sees anything — the cut **stops here** and waits. Where it is empty, as it is in this repo, merging to
`main` already is publication and there is nothing to wait for.

**It sits at the end of step 4 rather than at the start of step 5, and the distinction is the point.** The
waiting is the last thing the *cut* does; what follows the command is step 5's single act. Putting the
condition inside step 5 read as though the cut had already finished, which is what this move corrects.

**That command is never covered by the request that authorised the cut.** A Release document describes a
version; a live push changes what customers see. Decision by Dave, August 5, 2026 — restated under 5.1, where
it bites.

**And where the answer is yes, this section is where the cut may not be — which is the shared page's call,
not this one's** (inbound
[#1378](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1378), September 4, 2026). A live
stage whose push can **fail or be partial** — no locking on the target, third parties writing to it, a
per-file rather than wholesale push — runs the push *first* and makes the cut its documented closing act,
because cutting first strands a tag, a Release and an audience document on a state no customer ever saw.
The condition, and why it is prose rather than a seam, are in
[`cut-release/SKILL.md`](../plugins/dkj-policy/skills/cut-release/SKILL.md).
Such a repo's checklist stops **before** 4.1 rather than at 4.7; nothing else about steps 4.1–4.6 changes.
Here the question does not arise, because `Get-LiveStage` is empty.

---

## 5. SHIP MAIN / PUSH LIVE

### 5.1. Publish and distribute the audience release notes

**The waiting moved up to 4.7, and this step is what happens after it** (Dave,
[#894](https://github.com/DaveKJohn/claude-code-specialists/issues/894), August 26, 2026). It used to be two
steps here — wait for `main` to be live, *then* publish — which put the condition and the act in the same
section as though the cut had already ended. It has not: 4.7 is the last thing the cut does, and it is where
the checklist stops and waits for a `SHIP MAIN` or `PUSH LIVE` command. So this section is now the single act
that command releases.

The ordering argument below is unchanged and is the reason the two are separate steps at all rather than one.

**This step is a no-op in this repo, and that is an answer rather than an omission.** `Get-LiveStage` returns
empty here: there is no separate live stage between `main` and the audience. Merging to `main` *is* publication
— the marketplace is read from this repository, so the next `claude plugin marketplace update` a consumer runs
sees whatever the trunk holds.

**It is not a no-op in every repo that runs this workflow, which is why the step exists.** A consumer with a
live stage — a Shopify repo, where `main` still has to be pushed to a live theme before a customer sees
anything — answers `Get-LiveStage` with that stage, and then the order in step 5 is load-bearing: the audience
notes describe what the audience can see, so publishing them before the push describes something that is not
there yet.

**Where a repo does have a live stage, that push is its own class of action.** A Release document describes a
version; a live push changes what customers see. So it is **never** covered by the request that authorised the
cut — it needs Dave's word of its own, separately, however far the release checklist has already run. Decision
by Dave, August 5, 2026.

