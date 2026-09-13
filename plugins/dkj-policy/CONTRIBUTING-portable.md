# The contribution cycle — the portable half

This is the cycle the `dkj-policy` scripts run: an issue, a branch, its `dkj-policy/<branch>.md`, a Pull
Request that has to get past its gates, a merge, and a fold. **It is written to be read in any repo that
enables this plugin**, which is why it names the *seam* wherever a repo owns the answer, rather than stating
one repo's answer as the rule.

**Your repo answers this document.** Every place below that says "your repo declares X" points at a
function in your own `scripts/repo-config.ps1` or `scripts/lib/branch-info.ps1`. Those answers belong
beside this file, in a `## Specific to this repo` section of your own root `CONTRIBUTING.md` — the same
split this plugin's family uses everywhere else: the portable half travels with the plugin, the local half
stays in the repo. Read this page for the cycle; read your own page for the values.

**Where the scripts actually live.** They are not in your repo. Each one is invoked out of the plugin
install, which resolves itself through `${CLAUDE_PLUGIN_ROOT}`:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" -Name "<prefix>/<short-name>" -Title "…"
```

Each step below names the **skill** that owns the full detail for its script, and those skills are the
single source for their own flags and behaviour — this page is the connective tissue between them, not a
second description of each one. **Step 1 names none, and is the only step that does not**: no script runs
it, which is exactly why it was the step this page went without. A repo that keeps a local copy of any of
these scripts has taken on a second source; [`scripts/README.md`](scripts/README.md) says why that is the
one thing to avoid.

**One commit in your repo's history did not come through this cycle, and could not have.** The commit
that *adopted* this workflow lands directly on the trunk — the seam, the lenses, the script scaffolds
and this folder, in one go — because `new-branch` refuses without `scripts/lib/branch-info.ps1`, and
that file is one of the things the adoption writes. Before it there is no branch to put the work on;
after it, the cycle below applies to everything. The gates are downstream of the same commit for the
same reason: the lint gate needs the script your repo names, the test gate needs a suite, and the CI
entry gate needs a workflow file the adoption places. **It is one exception and it is spent by using
it** — so if your repo's history opens with a trunk commit, that is the one, and every change after it
belongs on a branch (inbound
[#1085](https://github.com/DaveKJohn/claude-code-specialists/issues/1085)).

---

## Precedence — full adoption, or none

Enabling `dkj-policy` is not a customisation layered beside a consumer's own root
`CLAUDE.md` — it is a policy that outranks it, deliberately (Dave, September 5, 2026). From the moment
the plugin is installed, this page and the sibling portable pages it ships with stand above whatever the
consumer's root `CLAUDE.md` says on the same subject, full stop.
[Further down](#a-third-rank-sits-above-both-and-nothing-named-it-until-inbound-1379) that ranking is
worked out in detail, for the branch/PR/release mechanics this plugin actually legislates. What belongs
here, ahead of the cycle itself, is the choice that sits above even that detail.

**The choice is binary, and there is no third position.** A consumer either installs this plugin and
runs the cycle below in full, or it does not install it and keeps its root `CLAUDE.md` as its own,
entire, unchallenged policy. There is no blend, no partial adoption, no keeping the scripts while
overriding the rule that governs them. One ship, one captain: a repo that installs the crew does not
also get to steer from the passenger deck.

**Where the two disagree on a subject this plugin actually addresses, the plugin is the one that is
right.** A root `CLAUDE.md` clause that contradicts what this page or a sibling portable page says is
not a customisation somebody chose — it is a standing error nobody has corrected yet, because nothing
reads the two documents together and only one of them can be true once the plugin is installed. Fixing
it is ordinary work in the consumer's own repo: an edit to that `CLAUDE.md`, on that repo's own branch +
PR route, made by that repo's own contributor — never something a plugin update reaches into a
downstream repo to rewrite silently. **Finding those places is the `check-policy-drift` skill's job**,
and it is deliberately a separate act from this page: it lays every legislating document out in rank
order and hands the reading to the session, because telling a restatement from a pointer is a judgement
about prose. This page states the target the correction moves toward; that skill finds where a repo
stands relative to it, and neither of them edits anything.

**A second plugin that extends this workflow does not settle its own place in the order — it points at
the one stated here.** The whole ranking, including where a companion plugin sits inside the top rung,
belongs to [the section further down](#a-third-rank-sits-above-both-and-nothing-named-it-until-inbound-1379),
which is the corollary above applied one layer up: a copy of a rank order in a sibling plugin fails the
same way a consumer's copy does, on the day this page moves and the copy does not. What a companion's
page carries is a sentence naming its own rung and a link back — `dkj-policy-bwj`'s
`WORKFLOW-portable.md` is the built instance.

---

## The cycle

### 1. New issue or task — where the work comes from

**Nothing runs this step but a person.** Everything else in the cycle has a script behind it; this one
happens when somebody — a colleague, or an agent that has just found something — decides a thing is worth
writing down. It is a step because step 2 opens a branch and a branch needs a thing to be *for*: a request
that only ever existed in a conversation is one that gets built twice, or half.

**Two kinds, and they are kinds rather than sub-steps.** Work reaches a repo running this workflow two
ways, and the two fail differently. Neither precedes the other, so neither is numbered. **Both end in the
same place: one issue in the repo the branch will be opened in**, which is what step 2 branches on.

**Human — somebody else's tracker asks.** In a repo that does not choose its own work, the request arrives
from Asana, Jira, Linear or a shared inbox, written as a desired outcome rather than an instruction. The
issue in your repo is not a copy of that ticket: it is the layer between the request and the code, and its
job is to answer *do we know enough?* before a branch exists. **A request with open questions is not
built** — that is what keeps the discovery in front of the branch instead of halfway inside it. The rules
for the whole layer are [**Ticket work**](#ticket-work--the-layer-before-the-branch) below. **A repo where
nothing arrives that way says so and moves on**; that is an answer rather than a gap.

**Claude — a finding becomes an issue, not a question at the end of the turn.** Something real that is
outside the assignment — a bug, a doc gone stale, a measurement that contradicts what a page claims, a
decision that is not yours to make — is filed, and then the assignment is finished. Whoever asked for the
work has to be able to close the session and clear its context without first answering everything found
along the way, so the close-out names the numbers rather than the findings. **Filing needs no permission,
and asking for it is the same failure as not filing**: *"shall I open an issue for this?"* leaves the
finding in the reply for them to answer, which is precisely what filing prevents. **The question to answer
first is not *may I* but *does it still stand*** — read the code, the script or the output that would have
to be true for it to hold, and where it collapses say so plainly instead of filing a weakened version. The
rest of the bar is short: search the tracker so you add to the existing thread rather than open its
duplicate, one subject per issue, and say what you **measured** and what you only **inferred**.

**And it is written in your repo's workflow language, not in the language the conversation happened in**
(Dave, September 11, 2026, [#1875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1875)). An
issue is the **form** rather than the message — the same split [the two language
questions](#what-your-repo-answers) draw between a ticket's headings and the reply that goes back to a
person — so it takes one answer per repo and
keeps it: a tracker whose language changes with whoever was at the keyboard cannot be searched by the
colleague who did not file it, and the title is the half that reaches every list, every filter and every
mirror. **In the family that ships this plugin the answer is English**, in a consuming repo exactly as in
the source, and a session replying in another language still files in English — the reply language is free
per session and was never the issue's. The one thing that stays in its own language is a person's own
words: a request quoted from their ticket, and the message written back to them.

**A repo adopting this workflow inherits the rule, not the answer.** What this page requires is that your
repo *has* one answer and that agent and human filings share it; which language that is belongs in the
table under [What your repo answers](#what-your-repo-answers), beside the two language rows already there.
A repo that never states it gets the failure this rule was written for: every session picks the language of
the conversation it happened to be in, and the drift is invisible until somebody searches.

**Those rules are stated here and owned elsewhere.** They are an orchestrator's, and they ship with the
`dkj-subagents-alpha` plugin — which this workflow does not depend on, so a repo can run this cycle with none of
them in context. Where this section and that persona body disagree, the body is the source and this is the
bug. They are written out anyway because a contributor reading this page has no guarantee of having that
plugin, and **a route with a step that is only legible to an agent is not a route**.

**Claim an issue before working it**, and read the claim as well as write it — an issue already carrying an
assignee is somebody's. The tracker is the only thing two sessions share: neither sees the other's branch,
so an unassigned issue is indistinguishable from an untouched one, which is how the same repair gets built
twice and discovered at the merge.

**[`claim-issue`](skills/claim-issue/SKILL.md) performs it**, and it exists because a rule enforced by
memory alone is one that gets skipped — measured in this plugin's own source repo, where **0 of 67**
assigned issues carried the identity holding 132 merged PRs there. It does the three things the obvious
one-liner cannot: it never sends `@me` (which binds to your `gh` account, not the one your commits will
name), it **refuses a closed issue**, which `gh issue edit --add-assignee` claims silently, and it
**refuses one somebody else holds**, which that command joins. It writes one assignee and nothing else —
the branch stays step 2's.

**Whether your issue labels line up with your branch prefixes is decided here rather than at step 2.** An
issue whose label already names the prefix its branch will get reads as work; one that does not is
classified twice. Your prefixes are your own (step 2) and your labels are your tracker's — **nothing in
this plugin reads either**, so that alignment is a convention you keep rather than one a gate holds you to.
Priority is the same kind of label — nothing here reads it either — and `task/adopt-triage-labels.ps1`
prints (never creates) a `gh label create` line for whichever of the four canonical `prio-1`..`prio-4`
rungs your tracker is missing, so adopting the convention costs one command instead of four typed by hand.

**Exactly one label is the exception, and it is the only one this workflow prescribes: the reach label.**
An issue that will land above tier 0 carries it, and `minor` is its default name. It is prescribed where
your other labels are not, because it is not a free-standing convention: it is
[the tier model](RELEASES-portable.md#the-same-scale-on-an-issue--the-reach-label) — the scale your repo
already answers on every changelog entry it writes, and the one that already decides patch versus minor —
read one step earlier, on the issue instead of on the entry. `Get-ReachLabel` states the string GitHub
stores, so a repo whose colleagues know the axis by another word renames the label and answers the seam;
the axis is unaffected, and a repo that answers nothing is already right.

### 2. Branch — and its two files come along in the same move

[`skills/new-branch/SKILL.md`](skills/new-branch/SKILL.md) · `new-branch.ps1`

Creating the branch writes its working document, so **a branch is never entry-less**. It has two halves
with two different readers:

| half of `dkj-policy/<branch>.md` | subject | lifetime |
|---|---|---|
| `### PLAN` · `### CREATE` · `### TEST` | what still **must happen** — the step list | removed at the merge; never folded |
| `### DEPLOY: <branch>` | what the change **does** — the entry that folds into your changelog | folded at the merge, then removed with the rest |

**One document per branch, named after it** — `<branch>.md`, the branch name and nothing else, with its slashes
flattened, so two branches never write the same path. It was the fixed `development.md` until September 3,
2026, on the argument that git already tracks it per branch: true of **checkout**, and silent about
**merge**, which is where the collision actually lives — every merge to the trunk left every *other* open
pull request conflicting on that one path, and a conflicting PR gets no check suite at all, so a required
check can never go green and the PR can never merge. What that cost, and why the fold is not the answer
either, is in [`DEVELOPMENT-portable.md`](DEVELOPMENT-portable.md#why-the-name-carries-the-branch).

**And it exists only while a branch is open**: `new-branch` creates it, the fold removes it at the
merge, so on the trunk there is no copy. It used to sit there in an empty state carrying a warning not to
write in it; a repo updating from an older plugin still has that copy until its next fold clears it, and
what marks it is the **trunk's name in its heading**, which is what stops the fold mistaking it for an
entry. The full convention is spelled out in
[`DEVELOPMENT-portable.md`](DEVELOPMENT-portable.md), which travels with this plugin; the
guidance for every field is inside the document itself, so there is no reference copy to keep current.

**The branch name is validated by your own lib, not by the plugin.** `new-branch` calls
`Test-BranchName` out of `scripts/lib/branch-info.ps1`, which lives in **your** repo — so which prefixes
are valid, which GitHub label each earns, which changelog type each produces, and which names are refused
outright are all yours (`Get-BranchTypes` / `Get-BranchInfo`). `specialists-init` scaffolds a starting
version of that file; changing it is an ordinary edit in your repo, not a fork of anything shared. An
unknown prefix is a soft warning rather than a refusal, and falls back to the type your
`Get-EntryFallbackType` names.

So how many prefixes there are, whether a given one exists, and what your repo refuses on sight are
questions this page deliberately cannot answer for you — check your own table rather than assuming the
source repo's.

**The DEPLOY section holds the entry block and nothing around it**, so it pastes into your changelog in
one go. The entry is one heading with two `####` sections under it:

```text
### DEPLOY: <your branch> · <stamp>

#### What makes this deploy extra special
#### Pull Request
```

**The headings carry what three sections used to.** The `###` names the branch — so the branch *type* is its
prefix — and the stamp on that same heading is the moment the branch landed, written by the fold. That is
the only stamp: the document's own heading is the branch and nothing else, because nothing ever read the
moment it began back. A section restating any of them would be one fact in two places.

**The entry holds both tiers, and neither names a number.** Tier 0's reason goes directly under the DEPLOY
heading — that heading IS its section; the audience tier gets `#### What makes this deploy extra special`, and it
means the one tier your repo has stated in `Get-ReleaseAudienceTier`. Each carries its reason and its
`**Score:**`; that is the description, written once per audience rather than once as prose and again per tier.
**A repo that has stated no audience tier gets the older shape instead** — a `##### Tier N` sub-section for
every tier the model has, tier 0 included — because a heading with no tier to resolve to would read as tier 0
and empty your release documents.

`Pull Request` opens with **the PR title** — the sentence you gave `-Title`, which `open-pr` puts the
branch type in front of. The number and the landing date go underneath it, written by the fold from the
merge: neither exists yet, and a date written now would be the branch's birth date rather than its
landing date.

**Every heading this replaced is still read**, so an entry already in your changelog, or on a branch in
flight, keeps folding exactly as it did. Nothing has to be migrated.

**Those section names are repo-owned prose.** A repo whose changelog is not in English sets its own through
`Get-EntrySectionHeadingOverrides` in `scripts/repo-config.ps1`, alongside the guidance comments
(`Get-EntryGuidanceOverrides`), the significance wording (`Get-EntrySignificanceWordingOverrides`) and the
step-list wording (`Get-BranchFileWordingOverrides`). If your headings do not read like the skeleton above,
that is the seam doing its job — compare against your own file, not against this one. The word `Tier` is
the exception: it is a machine-read key that the writer, the PR gate and the fold all match on literally,
so it is never translated.

**The guidance is in the document** — an HTML comment over every field, saying what a good answer looks
like. The fold strips comments on the way to your changelog, so leaving one standing is not a defect.

### 3. Work, and keep the plan current

Write the entry's description as you go, and resolve every step in the step list before the PR: `- [x]`
done, or `- [~]` dropped with the reason kept on the line. **Steps 4 and 5 both refuse while anything is
still `- [ ]`, and there is deliberately no `-Force` for it** — the dropped mark already is the way past a
step that turned out not to be needed, so nobody is ever pushed into ticking a box for work they did not
do.

A branch with **no** step list at all is not refused: that is the one-commit typo fix.

### 4. Open the PR

[`skills/open-pr/SKILL.md`](skills/open-pr/SKILL.md) · `open-pr.ps1`

**No title is passed.** It is composed as `<branch type>: <the entry's Branch title>`, so the sentence is
typed once — at `new-branch -Title` — and the PR, the changelog and the release documents cannot disagree
about what the change is called.

**The body comes from your own `.github/pull_request_template.md`, and that one file cannot travel with
the plugin.** GitHub reads it only from that path in your repo, so unlike everything else in this cycle it
has to be a copy rather than an import. **`adopt-dkj-policy` Part 1 makes that copy for you** — it places
the file alongside the branch-entry gate, from the plugin's own reference, under the same never-overwrite
rule as everything else it writes, so a template you already have is left exactly as it is
([#1843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1843)). The reference stays published at
`${CLAUDE_PLUGIN_ROOT}/templates/pull_request_template.md` to read and to diff against, and **the whole
interface is one line: the placeholder** the script recognises verbatim, which is where the description is
inserted. Break it and nothing errors; you get PRs whose body has no description.

**And having no file at all is quieter still, which is why the adoption places it rather than advising it.**
`open-pr` builds its body only when that path exists, so a repo without one gets a PR with **no body at
all** — no description, no form — and no warning to say why. The warning that block does carry fires on a
placeholder that does not *match*, which is a different state and the only one anybody had been told about.

**The shipped reference is that one line and
no heading at all, which is the normal shape rather than a broken one** — `-RefreshBody` reads where the
placeholder sits, so with nothing above it the description is the body's leading section. Everything you
add below it is the form's, and every heading there is a boundary the refresh will not cross. The
[`open-pr` skill](skills/open-pr/SKILL.md) carries that promise, the recognised strings, the
`Get-PrDescriptionPlaceholder` seam for a line of your own, and — worth reading before you copy the
reference — the measurement behind why nothing else survives in it, which is a method to re-run on your
own history rather than an answer to inherit.

**First, the script COMMITS your development document, if it differs from `HEAD`.** That
one file and nothing else — never `git add -A`, so anything else you had staged stays staged. It has to,
because every reader of that document inside the script reads your **working tree** while the push ships
`HEAD`, and the fold, the merge-time gates and the CI gate below all read the **committed** copy. A document
written but not committed therefore published a PR body describing a section the branch did not carry, and a
CI check that had to fail on arrival. Measured in the source repo on September 3, 2026
([#1269](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1269)); the
[`open-pr` skill](skills/open-pr/SKILL.md) has why it commits rather than adding a fifth refusal.

Then, before anything is pushed, the script runs two gates:

- **your lint gate**, whose path your repo declares in `Get-LintScript` (`scripts/repo-config.ps1`). Every
  repo has a different one, and this is the only repo-specific part of `open-pr`;
- **the test gate** — every `scripts/tests/*.tests.ps1`, plus whatever the optional `Get-TestCommands` in
  your `scripts/repo-config.ps1` names (an `npm test`, a `pytest`) for a repo whose tests are not all
  PowerShell. Each command fails the gate exactly like a failing suite; a repo that states nothing keeps
  the bare convention.

On an error or a failing suite nothing is pushed and no PR is opened. If your repo also runs those gates as
CI, the merge waits on whatever status check your branch protection requires; both the workflow and the
name of that check are yours, and your own page is where they are written down.

**A repo that cannot have a required check is not left open, and this is worth knowing before you go
looking for the setting.** A private repository on the GitHub Free plan cannot have branch protection at
all — `gh api ... /branches/main/protection` answers *"Upgrade to GitHub Pro or make this repository
public to enable this feature"* — and that is the shape most new repos start in. Two things hold there
without any configuration: `ship-pr` waits for **every** check the PR has rather than only the required
ones, so the wait works with no ruleset; and where nothing is required, the merge verdict cannot tell
*"this repo requires nothing"* from *"the required checks have not reported yet"*, so it **refuses** on a
red check instead of proceeding. The repo without a ruleset is therefore guarded conservatively rather
than left unguarded — you simply cannot be told which check governed, because no check governs.

Further gates judge the branch's own paperwork rather than its code, and none of them is advisory —
the [`open-pr` skill](skills/open-pr/SKILL.md) is the full account of each:

- **the entry gate** — the branch document's DEPLOY section is *gone*, so there is no entry for the fold to
  move into the changelog. It runs **before** the scaffold gate below because that gate cannot ask this: a
  deleted section carries none of the wording it matches on, so it passes by **absence** and the branch ships
  with its PR description composed out of the guidance. `-Force` is honoured, and `new-branch` is idempotent —
  run it on the branch to restore the section;
- **the scaffold gate** — an entry still carrying the wording the scaffolder wrote, or a description, body
  or tier reason still empty once the guidance comments are stripped. `-Force` is the escape valve here,
  deliberately separate from `-SkipLint`/`-SkipTests`, because it overrules a judgement about content
  rather than skipping a tool;
- **the shape gate** — the document *around* the entry: a phase heading gone, or branch content sitting in
  the generic block above the first phase. It reads the shape rather than the words, so a guidance block you
  translated passes and your own paragraph there does not; the heading-count half is the source repo's own
  rule and never fires here. `-Force` for the same reason as above;
- **the step-list gate** — any step still `- [ ]`, as in step 3 above. No `-Force`. It runs a second time at
  the merge, and there it judges the branch's own commit rather than the checkout, because the merge may be
  minutes of CI away from the moment you started it — the [`ship-pr` skill](skills/ship-pr/SKILL.md) has the
  two measurements behind that;
- **the impact gate** — the Significance sections; see below;
- **the resolves gate** — a plain `#123` in a PR body closes nothing on GitHub, so issues a PR resolves are
  passed as `-Resolves` and written as their own `Closes #<n>` lines.

**These are the ones worth knowing before you push, not the whole set** — `open-pr` also refuses on a
machine-local path in the entry, a link that will not survive the fold, an empty PR title, a label your seam
names that does not exist, and a remote that has moved under you, and `ship-pr` adds the backing gate and the
DEPLOY lock. The list above is deliberately a selection rather than an inventory: a page that tried to name
every gate would go stale on the next one added, and the skill pages already carry each in full. What matters
here is the property they share, which the count never was.

**All of them are local, and that is the hole the CI gate closes** (inbound
[#789](https://github.com/DaveKJohn/claude-code-specialists/issues/789)). A branch pushed by hand, or a PR
opened in the GitHub UI, meets none of them — so the convention was enforced by whoever remembered to use
the scripts. `check-branch-entry.ps1` ships for exactly that, and the `adopt-dkj-policy` skill's Part 1 places the six
lines of workflow that call it. **It re-uses the same functions**, so there is one definition of
"written" rather than a second one in every repo's CI: that is not a nicety, and two consumers measured
what the alternative costs — both wrote a gate in shell, and both refused a merge over a missing
significance score, which is a refusal this workflow deliberately places at the **release cut** instead.
The shipped gate reports the significance and merges anyway.

### 5. Merge

[`skills/ship-pr/SKILL.md`](skills/ship-pr/SKILL.md) · `ship-pr.ps1` — open, wait for CI, merge and fold in
one motion, using the merge method your `Get-PrMergeMethod` names.

**Run it in the background.** The merge waits on the required status check whatever you do, so holding a
session open for it buys a second look at a result the local gate already gave. Measured in the source repo
on August 27, 2026: `lint-en-tests` at **11m48s** against the same suites locally at **292s**, and over 65
blocking runs a median CI leg of **8m 01s** — 9h 45m a week at 73 merged PRs. **One condition comes with it:**
step 6 checks out the trunk in the tree the script was started from, so the session's next move is either a
lane ([`skills/worktree-lane/SKILL.md`](skills/worktree-lane/SKILL.md)) or nothing at all. Both halves, and
the two larger shapes that were declined, are in the
[`ship-pr` skill](skills/ship-pr/SKILL.md#the-wait-runs-in-the-background-and-that-is-the-default).

**A *not-required* check that fails does not block the merge — `ship-pr` merges past it and relays what
that check wrote about itself**, but only a **titled** failure annotation (`echo "::error
title=<name>::<why>"`). GitHub's runner writes untitled ones, so an advisory check that fails without a
titled `::error::` line is silent beside the red mark on purpose. The
[`ship-pr` skill](skills/ship-pr/SKILL.md#when-a-not-required-check-fails-the-merge-proceeds-and-ship-pr-relays-the-reason)
has the one-line form and the reasoning.

**Whether a finished branch is allowed to run through that motion on its own, or has to wait for a person's
word, is your repo's rule** — and one of the few things on this page that no seam can answer, because it is
a governance decision rather than a configuration value. Write it in your own `CONTRIBUTING.md` or
`CLAUDE.md` and link it from there; a contributor who has to guess will guess from whichever repo they last
worked in.

#### The staleness race, and what this workflow does about it

**A pull request is certified by CI against the base it was branched from, and the trunk moves after
that.** The certificate then describes a merge that is no longer the merge about to happen. That is the
race, and every repo running this workflow has it.

**Detect-and-rebase is the answer, and it is the one every repo can run.** `ship-pr` reads the moment the
run behind your required check was *created*, counts what the trunk gained after it, and **refuses the
merge** when the answer is not zero — naming the commits, the commands that bring the branch forward,
and `-SkipStaleCheck` for a window you have judged harmless. It converges by repetition rather than by
construction: bring the branch forward, CI re-runs against the current trunk, ship again.

**The first of those commands is a `git checkout` back onto the branch, and that is not a courtesy.**
`ship-pr` hands your tree back to the trunk the moment the PR exists, and this gate fires long after that
— past the whole CI wait — so by then you are normally standing on the trunk rather than on the branch
the fetch and the merge are about. (Normally, not always: the hand-back declines on a dirty tree, or
where another worktree already holds the trunk, and the checkout is then a harmless repeat.) Run the
other two on the trunk and nothing fails: the merge fast-forwards your local trunk and prints a diffstat
that reads exactly like the branch moving forward, the push is a no-op, and the next thing to say
anything is `ship-pr` itself, one full CI cycle later, complaining about the wrong problem. So the
refusal prints the branch name it read before it moved you.

**It needs a required status check to have a certificate to read.** With none named, `ship-pr` says so and
skips the step rather than inventing a verdict — which is honest and is also blind, so making one check
required on your trunk is the single thing that turns this mechanism on. `adopt-merge-queue` reports where
you stand on it.

##### A merge queue is SUPPORTED, and is no longer prescribed

**It used to be this workflow's policy for every repo, and it is not any more** (Dave, September 7, 2026,
[#1546](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1546)). A queue removes the race by
construction rather than by repetition, which is genuinely stronger — and **most repos running this
workflow are not allowed to have one.** GitHub's own GA terms: merge queue is available on private repos
only on **Enterprise Cloud**, and otherwise only on **public** repos owned by organizations. On Free, Pro or
Team the *Require merge queue* rule is not offered at all; GitHub hides the checkbox rather than disabling
it, so it reads as a UI mystery rather than as an entitlement.

**The policy was set in the one repo where that constraint cannot be felt**, which is what made it look
universal: this workflow's source repo is public, so it qualifies through the public clause while every
private consumer does not. Measured September 7, 2026 — the source repo `public` on plan `free` (eligible),
the consumer `BWJ-Development/smartwatchbanden` `private` on plan `team` (the checkbox absent). That
consumer built the entire floor — both runners placed, the `merge_group` trigger added, `FOLD_PUSH_TOKEN`
working — before the missing checkbox surfaced
([#1540](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1540)).

**A prescription most readers cannot follow is worse than no prescription**: it turns an ineligible repo's
correct state into an open `[gap]`, and sends its owner looking through the ruleset UI for a control that
is not rendered. So the queue is now one option among the repos that can have one, and detect-and-rebase is
what the workflow actually relies on.

**Where a repo does run one, everything below still applies and `ship-pr` still handles it.** Under a queue
`gh pr merge` does not merge: gh's own help says the pull request "will be added to the merge queue" —
added, exit 0, not merged. So `ship-pr` reads the trunk's rules before it merges and, where it finds a
queue, **enqueues, ends successfully, and folds nothing**. The queue merges the PR against the projected
merge (the trunk's tip plus whatever is queued ahead of it) minutes later, in a process your session never
observes.

**Three things have to be in place, and only the third belongs to the queue.** None of them arrives with
the plugin, because none of them is plugin payload:

1. **A fold runner.** The fold ran as `ship-pr`'s own next step after its own merge call returned. **Any
   merge your session does not observe skips it** — a queue merge, and equally a PR merged from the GitHub
   UI by anybody at all. The branch document then sits on the trunk unfolded, your changelog never receives
   the entry, and a release cut in that window misses the change. So it moves to a workflow triggered by
   the push the merge produces. **Every repo wants this, queue or no queue**, because the UI merge button
   exists in all of them. Under a queue it additionally needs a push credential of its own, because a
   `merge_queue` rule blocks the default token's push to the trunk.
2. **A resolves-verification runner** (step 6). Same shape and the same reason: the issues still close —
   GitHub honours a body's closing keywords on any merge — but nothing checks that they did, and nothing
   repairs the case the check exists for, a body that carried a plain mention instead of a keyword. Also
   every repo's, for the UI-merge reason above.
3. **A `merge_group` trigger on every workflow carrying a *required* check — QUEUE ONLY.** Without it that
   check never runs for a queue entry, never reports, and **every merge fails**: a total merge outage, not
   a degradation, and invisible until the first merge after the switch. In a repo with no queue this is
   inert, so leaving it out costs nothing.

**`adopt-merge-queue` reports all three**, and it is Part 3 of the [`adopt-dkj-policy`
skill](skills/adopt-dkj-policy/SKILL.md): it places the two runners, says whether a required check exists
at all — the one detect-and-rebase reads — and, for a repo that has chosen a queue, prints the ruleset
command **without running it**. Switching a queue on is a repo-settings change and therefore the owner's,
never a script's.

**A fourth file rides along in that same command, and it is unrelated to the queue** (issue #1843): a
scheduled `repo-settings.yml` runner that checks whether a GitHub-side repo setting still matches what
your own `scripts/repo-config.ps1` declares (`Get-ExpectedRepoSettings`). It needs neither a queue nor a
merge to matter — it runs on a schedule — and it never touches `FOLD_PUSH_TOKEN`. See the skill page's
own section on it for what it checks and why it travels here.

**And it does not report a missing queue as a gap.** Adopting one is a choice, and for most repos it is not
even an available one, so a repo with no `merge_queue` rule is in the ordinary state rather than an
unfinished one. `ship-pr` tells you where you stand from the other side: under a queue with no fold runner
in your tree, its closing lines say so instead of promising a fold that is not coming.

**Read the trigger warning as conditional, because the reverse mistake is expensive.** A consumer who
follows *"make your CI check required"* and then adds a `merge_group` trigger to a workflow that cannot
serve one has done work for a queue they do not have; a consumer who switches a queue on **without** that
trigger has stopped every merge in the repo. The required check is for detect-and-rebase and every repo
wants it. The trigger is for the queue and only a repo with one does.

### 6. Fold

[`skills/fold-changelog/SKILL.md`](skills/fold-changelog/SKILL.md) · `fold-changelog-entry.ps1`

On the trunk, right after the merge, the fold moves the entry into your changelog, appends the PR link as
its closing line, stamps the landing moment onto the `Pull Request` heading, strips the guidance comments,
and **removes the branch document** — so the trunk is ready for the next branch and the merged branch's
ticked-off steps do not greet whoever opens it. It commits that directly on the trunk, naming exactly those
paths so nothing else in the tree can ride along.

The entry is inserted at **the top of the list**: `CHANGELOG.md` is newest-first, a record of what landed
in the order it landed. Insert-only, never a re-sort — the fold commit goes straight onto the trunk, so a
bug must be able to misplace at most the entry being folded.

**The Significance sections still have to be right before the merge**, for two other reasons: the release
documents rank *themselves* on those scores, and the version bump follows the highest tier pending. What
they no longer decide is this document's order.

Where your repo has a plugin tier — declared by `Get-ReleasePluginTier` — the fold also derives a
`Plugins:` line from the PR's files, which the release documents read. A repo with no plugins never sees
that line.

**And it refreshes a one-line tally at the top of the pending list** — `**4 / 9 minor entries**`: how many
of the entries waiting for the next release reach your repo's audience tier, out of how many are pending,
and which bump that work has earned. It answers *how big is this release going to be* without anybody
counting, and it is **derived rather than accumulated**:
the line is recounted from the entries in the document about to be written, so there is no counter to drift
and an entry added or removed by hand is corrected by the next fold. The **release cut** rewrites it too,
on the emptied document — the line lives in the changelog's head, which is the part a cut keeps, so
otherwise a freshly released changelog would carry an intact count over an empty list.

**The two numbers answer different questions and may differ** — worth knowing before reading the line as a
contradiction. The fraction counts entries at or above your **audience** tier; the bump follows tier **1 or
higher**. So in a repo whose audience is 2, `**0 / 8 minor entries**` is correct and says something precise:
eight entries pending, none of them reaching a subscriber, and the version still owes a minor because some
of them reach management. The fraction is who *notices*; the bump is what the version *owes*. Where your
repo has stated **no** audience tier the fraction is dropped rather than shown as `0 / 8` — a `0` there
would report an unanswered seam as an absence of reach.

Your repo needs no heading for it: the tally anchors on the pending heading where you have one and on the
first entry where you do not, which is the shape the scaffolded changelog has. Every word of it is
overridable through `Get-ChangelogPendingSummaryOverrides`, like the rest of the generated prose, so a
changelog kept in another language stays in it — the bump word included, and its placeholders are
reorderable, because a translation rarely wants them in English order. **Three of that seam's keys were
retired with the per-tier shape** on September 7, 2026 (`Lead`, `Bucket`, `AudienceShare`); the two that
replaced them are `Share` and `NoShare`. Only keys the defaults carry are read, so an answer for a retired
key is silently *inert* rather than an error — if you had translated the old line, re-answer it. The line ends with an HTML comment that identifies it as
machine-written — that marker is the only thing a later run replaces, so a note of your own in that space
is never overwritten, and quoting the marker in your intro (in a fence or in inline backticks) is read as
a quotation rather than as the line itself.

---

## Ticket work — the layer before the branch

This is the `Human` half of step 1, in the repos that do not choose their own work: a request arrives from
somebody else's tracker, written as a desired outcome rather than an instruction, and somebody has to
decide whether it can be built at all before a branch is worth creating. **Skip this section if nothing
reaches your repo that way** — nothing else in the cycle depends on it.

**These are rules, not a format.** Every one of them exists because it was got wrong first, and the
reasoning is the part worth having — a copied checklist would lose exactly the half that makes each rule
survive contact with a request that does not fit it. Nothing below prescribes a filename, a folder, a
language, or a set of section headings. Those are yours, and
[What your repo answers](#what-your-repo-answers) says which.

**A repo may layer a stricter, tracker-specific rule on top of this step, packaged as its own
workflow.** `dkj-policy-bwj` is the worked example: it fixes, for BWJ's two Shopify store repos, that a
discovered issue is filed on GitHub first and mirrored to Asana as a colleague-facing variant, with
the Asana task resolved automatically from the GitHub issue's close. Such an add-on **extends** this
step — it does not replace the cycle around it — which is what keeps a second workflow plugin from
colliding with this one.

### Where this comes from, stated rather than discovered in review

**One repo, one day.** The workflow below was built in `BWJ-ecommerce/smartwatchbanden` on
2026-08-11, over five rounds against six real tickets, and donated upward on Dave's decision. There is no
second consumer running a ticket layer today, so this arrived **without the duplication that normally earns a
promotion** — the usual test for moving something into the shared core is that it exists in two places, and
this existed in one. That was weighed and overruled deliberately.

**And a second harvest, from the same repo, on 2026-08-31.** Rules 11 to 13 were written down there from
2026-08-12 onwards — in the page holding that repo's *answers*, not its rules — and only came up here when
that page was folded into its contributing page and every paragraph had to be sorted into one half or the
other. None of the three names a tracker, so they were always craft rather than answers. **That they sat on
the wrong side of the seam for three weeks is the point worth keeping:** an inbound issue is filed when
something is *wrong*, and a rule in the wrong file is not wrong, so nothing was ever going to report it.
Reading a consumer's answers page occasionally is the only thing that finds this class.

**What follows from that, for you.** Two things. First, the rules carrying explicit decisions — 2, 4 and 6
below, and 14 — are the ones to keep even where they are inconvenient; the first three are what the five
rounds were spent on, and 14 came back later as an inbound report from the same repo.
Second, **the vocabulary has not met a second tracker**, so treat every name in this section as an example of a
role rather than a term to adopt. If a rule reads as obviously wrong for your tracker, the rule is the thing
to re-measure — file it back as an inbound issue rather than working around it silently.

---

### The one structural rule: where the provenance boundary is

A ticket file mixes two kinds of statement, and they age completely differently:

- **copied from the tracker** — the request, its priority, its deadline, who filed it. True on the day it
  was copied and slowly false afterwards, because the tracker keeps moving and the file does not.
- **our own** — what we worked out, what we measured, what we decided, what we are doing next. Written once
  and still true later.

**So the file states, once, the date the copied half was last checked against the tracker.** One date for
the whole block, not one per field — a per-field date invites nobody to update any of them. Everything above
that line is a snapshot; everything below it does not rot.

This is the rule that makes the rest safe, and it is the one most likely to be skipped as bookkeeping.
Measured in the originating repo before it existed: **30 undated copies of tracker state across six files**,
with no way to tell which were current and no gate on any of them.

**Read-only is about the copied *content*, not about the source tracker as a whole.** Its one field you
do change is its state, and rule 14 covers when — taking a request in is a move the person who filed it
can see.

Beyond that boundary, a ticket file needs to answer four things in some order — what we know, whether we
know enough, what happens next, and what has happened so far. The rules below are about how each of those is
answered. How you name them is your business.

---

### Where the ticket lives, and the fields you therefore do not write

**This section says *file* throughout, because that is the shape it was measured in. Read it as *the
ticket*, wherever yours lives.** A folder of markdown is one answer; a row in a tracker you host
yourself — an issue, a board card — is another, and every rule survives the swap. One thing changes,
and it is stated in none of them: **a tracker you host already owns some of these fields, and what it
owns natively is not written a second time in the body.**

**Two trackers are in play, and only one of them is meant here.** The section opens on somebody
else's — the **source**, where the request came from, which you do not control and which the
provenance boundary above exists to date your copy of. The one meant in this passage is the
**host**: where your own ticket sits, when it is not a file. Read the rule against the source
instead and you delete the snapshot that boundary exists to protect, which is the opposite of what
it says.

| a host tracker typically owns | so |
|---|---|
| **the title**, in a field of its own | the body does not open by repeating it. No rule below prescribes a heading — but nothing below prompts the question either, and a ticket transcribed out of a file brings its `# H1` along with it. |
| **the list**, with its filters and columns | that list *is* the index of rule 10, so you have one whether or not you asked for one, and the rule becomes one about which columns it shows. |
| **open/closed, and labels** | **not** a substitute for rule 7's field. Two values are not a vocabulary, and rule 7 asks for one that is closed *and* covers every stage — so the field stays, whether you carry it in labels or in the body. This is the one that reads as a duplicate and is not. |
| **an author and a creation date** | which record who transcribed the ticket and when — not who filed the request and when they filed it. Those two are copied state: they belong in the snapshot half above the provenance line, and they stay written down. |

**The test is which field you would be maintaining in two places**, and where the answer is none, the
rule costs you nothing. It is written down because the shape the section was measured in prompts
nobody to ask.

**Measured in the originating repo on 2026-09-02**, after its eleven ticket files were moved verbatim
into its tracker and a twelfth was written from these rules rather than copied: **12 of 12 carried
their title twice**, once in the tracker's own field and once as the first line of the body. The
twelfth is the one worth noticing — nothing about it was migration residue. It was written from this
page, and this page did not prompt the question.

---

### The rules

#### 1. The decision is a section, not a mood

"Do we know enough to build this?" is answered **in one word, with the reason underneath** — and what hangs
below it follows from that answer. A reader who needs only the decision is done after one section, and does
not have to infer it from the length of the notes.

The reason is not optional. A one-word answer with no reason is the thing a later reader cannot check, in
exactly the way an unexplained score is.

#### 2. The test is *can we build what they ask* — not *is it a good idea*

Two different questions, and only the first is ours to answer before starting. Conflating them is what turns
a buildable request into a blocked one: the request is perfectly clear, we are simply unconvinced, and
"unconvinced" gets written down in the place reserved for "unclear".

**Measured: three of six tickets flipped from blocked to buildable** on this rule alone, one of them after
seven weeks of sitting still.

An explicit decision, and the one to keep when it feels wrong.

#### 3. Six kinds of question are not gaps

A gap is something whose absence stops us. These six get mistaken for gaps and are not — each learned the
hard way:

| not a gap | why |
|---|---|
| **verification** | needed to *prove* the fix afterwards, not to know what to do now |
| **an offer of ours** | widening a request that was already complete — ours to propose, not theirs to answer |
| **a caveat** | belongs with the notices (rule 4) and never needs an answer at all |
| **our own unfamiliarity** | a name or tool *we* do not recognise is something to ask internally |
| **work that is ours** | nobody supplies what we are paid to produce |
| **anything measurable on the product itself** | see rule 5 |

Two of those have sharp edges worth stating. **Unfamiliarity**: a "who is X" question was nearly sent out
about a colleague the requester works with daily — which reads as though we have not been paying attention,
and costs more than looking it up. **Work that is ours** has a real border rather than a bright line:
translating a *label* is ours, supplying *content* is theirs. A UI string in five languages is never a
question; a page of copy in five languages is.

#### 4. A gap and a notice look identical and do the opposite

*I cannot continue* and *I can continue, and you should know this* are the same shape on the page and
opposite in effect. Mixed into one list, every caveat reads as a blocker and buildable work sits still.
Keep them apart, structurally.

**And the attitude inside a notice is mandated: we build what is asked.** Whether the request is wise is not
our call — we state the risk and stop. That means *"flagging X; say the word and I build it as described"*
and specifically **not** *"can you explain how that relates?"*, which hands the burden back and converts a
notice into a blocker while sounding more collaborative.

An explicit decision.

#### 5. Measure the product before writing down a gap — and measure more than one instance

If the request is about something a user can see, **look at it first**. Most questions about observable
behaviour are answerable in less time than it takes to write the question, and a question sent out is at
minimum a day of latency and at worst a ticket that stops for weeks.

**Measured: two gaps that had blocked a ticket since 24 June** — which text block, and whether it contains
headings — were both answered with `curl` and `grep` in the time it took to ask.

**The sub-lesson is the expensive half.** The first measurement there was *wrong*, because it keyed on a
class that happened to exist on the one page checked (an artefact of content pasted out of Word). One
instance is an anecdote: **measure the structure, not what the first example happens to contain.** A
confident wrong measurement is worse than an open question, because nobody re-checks it.

#### 6. At a *yes*, the questions leave the reply entirely

If we know enough, we need nothing, so we **ask nothing**. The reply carries notices and nothing else.

Where a choice is genuinely still open, **make it, state the default, and say it is reversible** — *"the
same section appears on product pages; I am including those unless you say otherwise"*. A question in a
message reads as a request to wait even when it is not meant that way, and the requester cannot tell the
difference between "blocked on you" and "just checking".

An explicit decision.

#### 7. The heading never carries a status

A heading like *"the reply that was sent"* is written when the reply is **finished** — which is precisely
the moment nobody has sent it yet. So it is false on creation, and because it reads as done, nobody comes
back past it. **All six files in the originating repo were wrong this way on day one.**

State lives in a **field with a closed vocabulary**, not in prose and not in a heading. Closed is the
operative word: if a value needs a qualifying clause appended to cover the later stages, the vocabulary has
too few words in it, and the qualifier is where the lying starts.

Your stages are yours. The originating repo runs eight, from *draft* through *question sent* and *answer
received* to *buildable*, *building*, *delivered* and *closed*.

#### 8. One list, with the answer under the gap it unblocks

Gaps and the questions in the outgoing message are the same things said twice, and two lists of the same
thing diverge. Measured: **31 items against 29**, together **66% of all words in the folder**, already out
of step in a way no gate could catch.

Keep **one** list. Each gap points at the question that carries it, or says why it has none. The message
keeps its own numbering, because it is a message to a person and has to read like one.

**And an incoming answer lands under the gap it answers**, with its date and author. This is the rule that
pays off longest: in a tracker, the answer arrives in the same feed as the question and both scroll away,
so the file is the only place the pair stays together.

#### 9. The log is append-only, newest first, and holds references rather than descriptions

What was decided, what was rejected and why, when a question went out — and once built, a **reference**:
the PR it was built in, the version it shipped in. Never a fourth description of a change that the changelog
and the release documents already carry (see
[step 6](#6-fold) for the three that exist already).

**A log cannot rot dishonestly**, which is the structural argument for having one: a log with no recent
entries correctly says nothing has happened. That is exactly where a status field lies.

#### 10. The index carries only what you need to pick a file

Two things: what state each ticket is in, and whose move it is. Nothing else.

Anything else copied into an index is a third copy of something that already has a home, and it drifts from
the file below it. Measured: priority and "waiting on" were both copied up, and both drifted.


#### 11. The judgment lives at the gate, not with the evidence

The section that gathers what you know **collects and does not conclude**; the section that decides opens
with the decision. Keeping the two apart is what makes rule 1 checkable — a verdict written at the foot of
the evidence reads as a summary of it, and a summary is exactly what a gate must not be.

The originating repo reached this after two wrong shapes in a single day: first a section per question with
the verdict inside each one, then one question-section ending in a `### Conclusion`. Both put the decision
where a reader had to have read everything to find it.

**The split is by role, not by topic.** Our own measurements are evidence however much work they took, and
they belong with what we know; what is left at the gate is the judgment plus the questions only the
requester can answer. Naming that section is the same rule once more — name it after the research and our
own work migrates into it, name it after the questions and it describes only the *no* case, when a ticket
that passes with no question at all still passes through it.

#### 12. Every message lives at its own gate, and the closing one carries no question

There are exactly two moments at which something goes out: **the question**, while there is not enough to
build on, and **the closing**, once what was asked has been delivered. Between them no message is due, and
the two are never the same shape.

**The closing message carries no question at all** — not an open offer, not a *"let me know if…"*, not a
*"would you like me to also…"*. A question there hands the ball back at the exact moment the requester needs
to do nothing, and it makes a statement conditional: the reader concludes somebody is waiting on them. If
something really does need answering it is a gap — it opens a new round at the gate and the decision returns
to *no*. If it is not worth that, it is not worth the sentence.

**Searching for a question mark does not check this.** Measured over six tickets: **five asked a question in
their delivery message**, two of them with no question mark anywhere (*"let me know"*, *"if you want those
included as well, just say"*), while two of the question marks that were present turned out to be `?page=`
and `?sort_by=` inside a URL. Read the message instead, and ask of each paragraph whether the requester has
to **do** anything with it.

This is rule 6 seen from the other end of the work: there a *yes* empties the reply, here the delivery does.

#### 13. Three rules for a message to a person

The outgoing text is read by a colleague rather than by us, and each of these was got wrong first:

1. **Claim only what is on your own screen** — what the code does, what a live page's source contains, what
   the ticket or an earlier reply says. Not what a search engine wants and not what is customary in a field
   that is not ours: neither can be defended in the exchange that follows, and both take the answer out of
   the hands of the specialist you are writing to. Where the concern is real it is a notice, and rule 4's
   attitude governs it — **report the risk and stop**, without asking them to justify it.
2. **No disclaimer about your own level of knowledge.** Said once it is honest; repeated across tickets it
   reads as apologising, and it invites the reader to discount everything after it. Put the question as a
   choice that is theirs to make.
3. **Never refer to a number the reader cannot find.** The numbering is ours — rule 8 keeps it that way
   deliberately — and the requester has never seen that list. Measured: a reply opened with *"I can already
   answer your second question"* when the colleague had asked no numbered questions at all, but had answered
   three of ours. Worse, two numberings were running in that ticket, and under the reading he would have
   picked, the sentence promised something that was not delivered. **A number is a reference to us and a
   guess to him** — name the question instead.

#### 14. Taking a request in is a move the requester can see

The provenance boundary treats the source tracker as read-only, and for what you *copy* from it that is
right. It is not right for the one thing the source owns that you also **change**: its state. A request
taken in has moved — from *nobody has looked at this* to *this is tracked where the work happens* — and
the person who filed it is watching that column, not your repo. So the row advances **when the ticket
document is created**, not when a branch opens and not when it ships. An issue that exists here while
the source still says *new* reads, to the filer, as a request nobody picked up — which is exactly what
the issue disproves — and the colleague chasing it chases it in the one place with no answer.

**"Automatically" is how this step gets described once it is habitual, and a reader who believes it is
handled will not do it.** Measured in the originating repo on 2026-09-02: a request was filed as an
issue and the source board left on its intake column; over an hour later the task's own last-modified
time still predated the issue. Nothing was going to move it.

Two things are yours to answer. **Which column** the row advances to on pickup — one target, picked
once. **And which board**, when the request sits on more than one: advance only the board that tracks
*your* delivery state; a requester's intake board still describes the request accurately after you have
picked it up, so moving its card says something false. Advancing every board the request touched was
the first mistake made with this rule.

This is the pickup end of a symmetry some repos already run at the other end — the introduction names
one, a tracker-specific layer that resolves the source task from the issue's close. Both ends are one
idea: the source's state is not yours to copy, and it is yours to advance.

An explicit decision.

---

### What your repo answers

Nothing in this section is configurable through a seam, because none of it is read by a script. It is a set of
rules a person applies, so adopting it means writing your own answers next to it — the same split the rest
of this plugin uses:

| yours to decide | notes |
|---|---|
| **which tracker the request comes from, and where the boundary is** | the whole page assumes the request originates somewhere you do not control |
| **where a ticket lives, and what it is named** | a folder and a file naming, or a row in a tracker you host yourself — including where research material sits relative to the tickets |
| **which fields your host tracker already owns** | only if it hosts your tickets rather than a folder doing it; see [Where the ticket lives](#where-the-ticket-lives-and-the-fields-you-therefore-do-not-write) |
| **the language of the form** | section names, field names, the state vocabulary — one answer per repo |
| **the language of the outgoing message** | not one answer per repo; see below |
| **the language your repo's own issues are written in** | one answer per repo, and agent filings share it with human ones — [step 1](#1-new-issue-or-task--where-the-work-comes-from). It is the form question one layer out, so a repo that answered it there has already answered this |
| **every section and field name** | the roles above are the rule; the names are not |
| **the state vocabulary** | rule 7 requires it to be *closed*, not to be these eight values |
| **whether there is an index at all** | rule 10 applies if you have one, and a host tracker gives you one whether or not you wanted it |
| **which column pickup advances the source row to, and on which board** | rule 14 — one target column, and only the board that tracks your delivery state when the request sits on several |

**The language is two questions, and only the first has one answer per repo.** The **form** — the section
names, the field names, the state vocabulary — is workflow rather than subject matter, so a repo picks a
language once and is done; the argument for picking English is that a colleague who does not read your prose
can still open a file and recognise its structure without translating every heading first. These pages are
English because the plugin is — the plugin's answer to its own version of the question, not yours. The
**outgoing message** — the reply of rules 6 and 8 — is the opposite: it is verbatim what a person receives,
so its language is a property of **whoever filed the ticket**, and it can differ from one file to the next.
The instruction is therefore *look up who filed it before you write*, not *write in language X*.

**Measured in the originating repo, 2026-08-12.** It had answered "Dutch" for the whole file, on a reason
that reads as sound: the outgoing message goes to colleagues, and those colleagues are Dutch-speaking.
**Some of them are not** — the rule had quietly generalised from the requesters seen so far to every
requester there will ever be. One answer per repo is the shape that fails here, and it fails silently:
nothing is wrong until the first request arrives from somebody who cannot read the message.

### What deliberately is not here

**No template file, and no scaffolding script.** Both were offered and declined for now. A template fixes
the shape, and the shape is the half that has met exactly one tracker; a skill would wrap a script, and
this layer has none — every other skill in this plugin exists because a `.ps1` needed documenting.

Those are the pieces to build **once a second repo runs this**, at which point there is something real to
generalise from rather than one repo's five hours. Until then, the rules travel and the shape stays local.

---

## Significance — two questions, one per reach

Every entry answers one reach per block — the DEPLOY heading's own text for tier 0, `#### What makes this
deploy extra special` for your audience tier. **The tier says how far the change reaches**, and therefore which
release document the entry appears in:

| tier | who notices |
|---|---|
| `0` | only this repo's own developers — docs, config, internal work |
| `1` | management and the employer/commissioner get something out of it |
| `2` | a subscriber of the service notices it |

Tiers 1 and 2 are two **kinds** of audience, not two rungs, and the webshop worked example is what
separates them: a webshop's customers buy a product and never read a release note, so its audience is `1`
even though its customers are literally "consumers" — while a repo that IS the service somebody subscribes
to answers `2`.

**The significance says how much it weighs for that reader**, and therefore where in the list it sits — the
most consequential change leads instead of sitting wherever its branch prefix happened to put it.

**Score it against the rubric your repo declares**, in `Get-EntrySignificanceRubricLevels`. You do not have
to go looking for it: `new-branch` prints the rubric when it writes the file, and the guidance in
the document points back at that printout. The bands are anchored on purpose — an unanchored ordinal
scale invites false precision, and the anchors are what make the number a measurement rather than a mood.
**The `Why` above each score is the lasting half**: the rubric says which band, the `Why` says why *this*
change is in it, and that is the only part a reader a year later can use.

**Two tiers are in the file: tier 0, and the one audience tier your repo has** (Dave, August 12, 2026).
Tier 1 (management and the employer/commissioner) and tier 2 (the subscriber of a service) are two **kinds**
of reader rather than two rungs of a ladder, and a repo has exactly one — decided before any entry is
written, and stated once in `Get-ReleaseAudienceTier` in your own `scripts/repo-config.ps1`. A shop selling a
**product** answers `1`: its buyers never read a release note, while management and whoever pays for the work
do. A repo that **is** the service somebody subscribes to answers `2`. **State nothing and you are asked
about both**, exactly as before the knob existed — so three sections in your file means the question is still
open on your side, not that anything is broken.

Where a change reaches nobody at the level you *do* ask about, write `N/A` in the score and say in one line
why. **That is an answer, not a gap** — a blank means both "reaches nobody" and "nobody has got to this yet",
and a gate has to be able to tell those apart. The reach is the **highest tier carrying a number**, so an
`N/A` costs a sentence and nothing else, and the reasoning behind a negative claim survives into the record.

**Tier 0 is the one tier that cannot be `N/A`**: every change reaches its own repo's developers at least a
little. The floor is a score of 1.

**The cumulative ladder is gone, and the measurement is why.** It used to be that `N/A` at tier 1 under a
scored tier 2 was refused by name, on the reasoning that a change consumers notice is also a change
colleagues get something out of. That reasoning holds for a repo with two genuine audiences and produces
nothing but duplication for the far more common repo with one: in the source repo, **81 of 89 tier-1 sections
existed only because a tier-2 section sat above them** — the same reach argued twice, in a second register,
for a reader who was the same person. What is still enforced is that every tier the file carries has a
reason, and that the audience tier is answered before a PR opens.

**The scores do not have to ascend, and that was true under the ladder too.** Tier 0 may legitimately score
below the audience tier, because these are different readers and not nested ones. A defect that exists only
outside your repo is worth a great deal to whoever is outside it and almost nothing at home.

**A tier your repo no longer asks about is still read.** Every entry already folded, here and in every
consumer's tree, was written under the cumulative model and carries all three — so nothing already written
stops folding, and an extra answered tier is never refused. Recognise both, write one.

**The score cells are scaffolded empty on purpose.** The tier defaults to 0 because 0 is a harmless final
answer about reach; a *score* has no harmless value, so any number scaffolded for you would be a guess at a
ranking.

**Do not infer any of it from your branch prefix.** The prefix decides the entry's *type*, which the entry
states under its own heading; it predicts nothing about impact. A `docs/` branch can carry a tier-2 change
and a `feat/` branch a tier-0 one. The repo this plugin comes from measured it: its single most
consequential change for a consumer — a marketplace rename that broke every existing install — arrived on
a branch whose prefix put it at the bottom of the document.

---

## Releases — a different cycle

[`skills/cut-release/SKILL.md`](skills/cut-release/SKILL.md) · `cut-release.ps1`

Everything above is the **contribution cycle**: everyone runs it, on every branch. Cutting a release is a
separate cycle with different rules, and the fact that the fold commits directly on the trunk must not be
read as something this page grants to ordinary contributions.

The one part worth knowing from here is the gate on the bump, because it is easy to mistake for your own
policy. **The shared gate refuses a bump the pending entries have not earned**: tier 0 only is a patch,
tier 1 or higher earns a minor, and a major additionally needs the number of minors your
`Get-ReleaseMajorMinMinors` names. It also refuses a release whose tier-1-or-higher entries carry no
score, because an unscored entry cannot be placed.

**That is a floor, not your policy.** A repo may legitimately draw the line tighter — reserving a minor for
what a customer notices, say, because a minor there forces a stakeholder-facing document into existence.
The gate cannot tell a stricter policy from a mistake, so it enforces only the floor and your own page is
where the stricter rule is written. If your two rules differ, say so out loud where a contributor picks
their bump type; both allowing a patch is not the same as agreeing.

Which documents a release writes, how they are foldered, and whether a stakeholder-facing consumer
document is generated at all are yours too (`Get-ReleaseNotesGrouping`, `Get-ReleaseConsumerBumps`,
`Get-ReleasePluginTier`). The cut-release skill covers all of it.

---

## The two contributing layers, and which one wins

A repo running this workflow carries **two layers**, deliberately (Dave, August 14, 2026):

- a **floor** — what holds before any plugin is consulted, and what stays meaningful the day the plugin
  is absent: a fresh checkout, a teardown, a contributor who installed nothing. Normally that is your
  root `CONTRIBUTING.md`;
- `dkj-policy/CONTRIBUTING.md` (the `adopt-dkj-policy` skill's Part 1 scaffolds it) is the
  **workflow's layer**: everything this plugin owns, plus your repo's answers to its seams. **Where the
  two disagree, the workflow's page wins.**

So adopting this workflow never rewrites your root page — the folder file arrives beside it and takes
precedence only where they conflict.

**Which file carries the floor is yours, and the source repo answers it differently from the
recommendation.** On August 27, 2026 it deleted its root `CONTRIBUTING.md` and kept the floor in its
`CLAUDE.md`, on the grounds that an always-on document already stated the same three rules — never
directly on the trunk, a branch + PR, the required CI check — and a second copy is a thing to keep in
sync rather than a safety net. **Nothing in this workflow depends on that choice**: every gate reads your
branch's own `<branch>.md`, never a contributing page, so both answers work.

**The recommendation is still the root page, for two reasons that have nothing to do with the gates.**
GitHub links a root `CONTRIBUTING.md` from the new-issue and new-pull-request pages and from the
repository sidebar, and it recognises that file only in the root, `.github/` or `docs/` — a page in
`dkj-policy/` gets none of that surfacing. And it is the file a drive-by contributor looks
for by name. Both matter most in a public repo with contributors who have installed nothing, which is
precisely the reader the floor exists for. Keep the root page unless you can say why your repo is not
that case.

**If you do retire the root page, inventory it section by section BEFORE you delete it.** That is the
step that makes the removal safe rather than merely tidy, and it is cheap: for each section, find where
that rule is actually decided — your root `CLAUDE.md`, a seam lib, a gate, this page — and move anything
that lives **nowhere else** before the file goes. Most of a drifting root page is restatement and moves
nowhere; the danger is the minority that is not. Measured in one consumer on August 27, 2026: of seven
sections, six were restatements of its root `CLAUDE.md` and three rules lived only on the page being
deleted — one of them a **safety rule about pushing to the live theme**. Deleting the page without that
pass would have dropped a live-push rule in silence, and no gate in that repo would have said a word,
because no gate reads a contributing page. That is the whole reason this is an instruction rather than
a suggestion: the failure is silent by construction.

**And the drift that prompts the removal is itself the evidence for doing the pass.** The same page's
gate list named three test suites on a day its root `CLAUDE.md` named ten. A page far enough out of date
to be worth retiring is exactly the page whose contents you can no longer predict from memory.

### A third rank sits above both, and nothing named it until inbound #1379

**Both layers above are consumer documents, and a consumer document only ever comes second.** Everything
this section has ranked so far is one repo's own floor against that same repo's workflow folder — it never
said where the law that ships **with this plugin** — this page, the sibling portable pages, and the
skills that carry their mechanics — sits relative to either. That is a real vacuum rather than an implied
answer, and a consumer filled it in good faith the other way up: it declared its `CLAUDE.md` the
constitution, supreme over its own contributing page on any disagreement. Both rules read as reasonable in
isolation, and together they invert: this page says the workflow's page wins, the consumer says its floor
wins and is the only place a rule is ever changed. The measured instance is
[#1378](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1378) — `cut-release`'s own
mechanics fix a cut-then-push order, the consumer's `CLAUDE.md` documented push-then-cut, and the
disagreement did not read as drift. It read as the constitution exercising a supremacy it had declared in
writing, and no gate could flag it, because no gate reads a contributing page or a `CLAUDE.md`.

**So the complete order, on the matters this plugin actually legislates, is three ranks and not two:**

```
the plugin's portable pages + skills   (the shared law)
        >  dkj-policy/CONTRIBUTING.md  (this repo's answers to its seams)
        >  the floor                   (root CONTRIBUTING.md, or CLAUDE.md where the repo keeps its floor there)
```

**The names say the order, since September 5, 2026 (#1437).** This plugin was called
`contributing-davekjohn` until that day, which named one of the things it does rather than what it is. It
is `dkj-policy` now -- the top rung, the shared law -- and a companion is `dkj-policy-<who>`, a ministry
under it holding one narrower brief. Nothing in the ranking changed with the names; what changed is that
the ranking is now legible from the plugin list alone, without reading this page first. A repo installing
`dkj-policy-bwj` can see it sits under `dkj-policy` before it has read a word of either.

**The top rung has an order of its own as soon as a second workflow plugin is installed, and it is still
one rank rather than a fourth.** `dkj-policy` legislates the cycle itself — the branch, the
branch document, the gates, the fold, the cut — and a companion workflow plugin extends one step of that
cycle for a named set of repos rather than replacing any of it; `dkj-policy-bwj` is the built instance, and it
extends the ticket-work step for two Shopify store repos. So **where two plugin pages speak to the same
question, this plugin's page wins and the companion's is read as an extension, never as an override.**
Where the companion legislates something these pages have no opinion on — which is the normal case and
the whole reason it exists — the two never meet and there is nothing to rank.

**A companion names its own rung on its own page and points back here rather than restating this block**,
which is the corollary below applied to a plugin instead of to a consumer. The rank order is stated once,
in this section; `WORKFLOW-portable.md` carries a pointer at it and the sentence *"this page is the middle
of three"*, and nothing else. A second copy of the order in a sibling plugin would fail exactly the way a
consumer's copy does — not on the day it is written, but on the day this block moves and the copy does not.

**Scoped as narrowly as it should be.** This ranking governs only what the plugin actually legislates —
the branch/PR/release mechanics, the gates, the tier model, the shapes described on these portable pages.
A repo's own rules that the plugin has no opinion on — its live theme's id, its store domain, its
front-end tokens, the safety rules it runs under — are not in that set at all, and nothing here outranks
them. Restating that scope matters because the failure this section describes looks exactly like
diligence: a repo folds a shared rule into its always-on `CLAUDE.md` *in order to* keep one document
self-contained, and the fold is where the divergence gets in.

**The rank alone will not be obeyed, so here is the corollary that actually keeps it: a consumer document
may point at a shared law, state this repo's answer to a seam the law names, or say nothing about it. It
may not restate the law in its own words.** A restatement is a copy, and a copy does not fail on the day
it is written — only on the day the plugin's answer moves under it and the copy does not move with it.
This is the same rule this workflow already applies one layer down, to code: a returned local copy of a
shared function is not a bug on day one, it is a bug the day the two diverge (`check-script-contract.ps1`
exists for exactly that shape). A manifest-driven check for the prose version of it was measured in the
source repo and declined ([#1380](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1380)):
a section that restates a law almost always also names the mechanism it is talking about, so a pointer
test cannot tell correct deference from restatement-with-citation-and-override — the same distinction,
one layer up, that `check-script-contract.ps1` gets to skip because a function call is unambiguous where
a sentence is not. The numbers are in that repo's own system-administration lens, not shipped here.

**One narrow slice of it IS enforced, and you will meet it at a session start rather than in a review.**
The decline above is about reading what a *sentence* means; a **filename** needs no reading, so the
`consumer-prose-sessioncheck` SessionStart hook greps your own always-on documents — your `CLAUDE.md`
and everything it `@`-imports — plus your `dkj-policy/README.md` and `CONTRIBUTING.md`, for
every name this workflow's branch document has been *renamed away from*. Your changelog and your
`releases/` are never read: a folded entry correctly names the file of its own day. When it fires it
names the document, the line and the retired name, and the repair is always the same — replace the
sentence with a pointer at the page that owns the answer.

**It exists because this corollary had no delivery at all**
([#1389](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1389)). That document has been
renamed seven times, twice inside one day, and the *tooling* was built rename-proof for it; the prose
describing it to you was not, and nothing reads your `CLAUDE.md`. Measured: both live consumers of this
workflow were still stating a retired name as current, one day and six days after the rename, and no
mechanism existed by which either of them could have found out.

**A second narrow slice is enforced the same way, by the same hook in the same pass, and it is aimed at
THIS section — the rank order itself.** `consumer-prose-sessioncheck` also greps those documents for a line declaring your own
`CLAUDE.md` the winner over this page's layer: the two tokens `CLAUDE.md` and `wins`/`wint` sitting
directly beside each other, with nothing between them but markdown. Adjacency is the whole rule, and it
is what makes the check safe to run against prose — *"this page wins"* over `CLAUDE.md` is this ranking
stated **correctly**, and a check that merely looked for both words nearby would report it as loudly as
the inversion. A hit inside a `"…"` quotation is skipped: a page quoting a rule it has retired is
narrating, not declaring.

**It is the one contradiction the decline above proved nobody could see**
([#1415](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1415)). A pointer test only ever
flags a section that cites nothing, so a section that names this page and then overrides it four lines
later sits among the findings such a test *suppresses* — invisible by construction, and invisible from
both ends in practice, since you read your own page and follow it while the source repo never reads your
page at all. Measured when the check was built: one live consumer carried two standing inversions, in
its `CLAUDE.md` preamble and in its own `dkj-policy/CONTRIBUTING.md`.

**Both slices are one hook and one pass over your pages, and that is a cost decision rather than a
tidiness one** ([#1421](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1421)). They
shipped as two hooks for a day: two process launches, two loads of this workflow's libraries and two
walks of the same handful of documents, paid at every session start in your repo, forever. Measured on a
fixture carrying both defects, 990 ms for the pair against 533 ms merged — **~457 ms of every session
start**. You get one report that may carry either block or both; a run never stops at the first defect it
finds.

**If you genuinely want your own constitution to lead, that is a seam answer, not a sentence.** The
check reports rather than adjudicates, but the repair it names is the honest one: say so where the
plugin asks to be told, instead of overriding this page in prose that only your own readers ever see.

**A fourth move exists, and nothing named it until inbound
[#1388](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1388): a law this plugin
deliberately DELEGATES, with no seam and no page of its own answering it either.**
`cut-release/SKILL.md`'s "Which comes first, the cut or the push" block is the measured instance: it
declines to build a `Get-LiveStageCutOrder` seam on purpose — the order is a sentence a person walks
past in a checklist, not a value any script reads — and tells a repo running the non-default order to
state that order **in its own `CLAUDE.md`**, because the standing rule authorising it has to live there
anyway. Read against the three moves above, that instruction looks like the forbidden one: it is not
pointing at the law, there is no seam to hold this repo's answer to, and staying silent would leave the
order genuinely undocumented anywhere a reader could find it. It is none of the three because the
premise behind the three does not hold here — there is no shared prose *for* a consumer's page to
duplicate. The corollary polices copies of a law the plugin states somewhere; here the plugin has
decided not to state an answer at all, and asked the consumer to.

**The two are told apart by asking whether a plugin page states the law's answer anywhere.** Where one
does — this page, a sibling portable page, a skill's own reasoning — a consumer restating that answer
is the forbidden copy, exactly as before. Where a plugin page explicitly declines to answer and says so
(`cut-release` Block 2's "No seam, deliberately"), a consumer's prose is not a copy of anything: it is
the only place that repo's answer is ever written down, and the corollary has nothing to say against
it. **This fourth move is scoped to that explicit decline** — a plugin page has to name the delegation,
the way `cut-release` does, or the gap reads as an oversight rather than a deliberate fourth door, and
a consumer cannot tell the two apart on its own.

**Read this section end to end before writing a repo's own layering answer.** "Which file carries the
floor is yours" and "the workflow's page wins" above are still both true and both local to the two
consumer layers; this third rank does not change either, it completes the sentence neither of them ever
finished.
