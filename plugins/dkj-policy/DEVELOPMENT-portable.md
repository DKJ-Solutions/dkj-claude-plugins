# `<branch>.md` — the portable half

Everything a branch needs to carry lives in **one file**:
`dkj-policy/<branch>.md` — one document per branch, named after it, inside the
workflow's own root folder where everything portable gathers. (It was the single shared
`development.md` until September 3, 2026; [see below](#why-the-name-carries-the-branch) for what that
cost and why it changed.) It has two halves with two
different readers, and they are sections of one document rather than two files:

| half | subject | who reads it | lifetime |
|---|---|---|---|
| `### PLAN` · `### CREATE` · `### TEST` | what still **must happen** | whoever is working on the branch | removed at the merge; never folded |
| `### DEPLOY: <branch>` | what the change **does** | whoever reads `CHANGELOG.md` later | folded at the merge, then removed with the rest |

It is written by the shared
[`scripts/task/new-branch.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/task/new-branch.ps1)
at the moment the branch is created. You do not create it by hand, and you do not delete it.

**How to read this page.** It travels with the plugin, so two conventions keep it true in every tree it
lands in — the same two `RELEASES-portable.md` states for itself. *This repo* always names the **source
repo** the page was written in
([claude-code-specialists](https://github.com/DKJ-Solutions/claude-code-specialists)) — its measurements travel
as the evidence behind the rules, never as your repo's own record. And links into the source's script tree
are **absolute** on purpose; the file every adopting repo has of its own is named in code rather than
linked, because the copy that matters is yours.

**That second convention is not this page's habit — it is what the plugin cache forces on every file a
plugin ships**, and it is worth stating in full once, here, because nothing about it is visible from
inside the source repo. An installed plugin is read from

```text
~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
```

so the plugin's **own directory is the root**. Three things that exist in the source tree are simply gone:
the `plugins/` level, the family level (`teams/`, `workflows/`), and every sibling plugin — each sibling is
a separate versioned directory, not a neighbour you can reach with `../`. A relative link that walks out of
the plugin root therefore resolves perfectly where it was written and lands on nothing where it is read.
**So a relative link in plugin payload must resolve inside its own plugin; anything further away is written
as an absolute URL.** The source repo enforces this as a gate check of its own rather than trusting the
convention, and the reason it stopped trusting it is the measurement: seventeen links in five files had
drifted past the convention, and resolved inside the *installed* copies rather than the source tree, all
seventeen were dead. Inbound
[#1066](https://github.com/DaveKJohn/claude-code-specialists/issues/1066).

**There is no template beside it, and there is nothing missing.** Until August 23, 2026 the two files this
replaces were scaffolded **bare** — headings and nothing else — with a reference copy under
`branch/templates/` carrying an HTML comment over every field saying what a good answer looks like. Inbound
[#810](https://github.com/DaveKJohn/claude-code-specialists/issues/810) is what that arrangement cost: an
author met the guidance in the neighbouring file or not at all, and wrote two pages of prose under a heading
whose own hint said the short answer was the normal one. **The guidance is in the document now**, and the
fold strips HTML comments on the way to `CHANGELOG.md` — so leaving a block standing is not a defect, and
nobody has to remember to delete one.

**Which makes this page the reference.** The document exists only while a branch is open — `new-branch`
creates it, the fold removes it at the merge — so on the trunk there is no copy to open and read. Until
August 23, 2026 there was: the file was rewritten to an empty state and that copy was what you looked at to
see the whole form at once. It is this page that carries that now, and the swap is deliberate rather than a
loss. A file scaffolded into your repo is written once and never again, so it cannot be improved after you
adopt it; this page reaches you with every plugin update.

## The heading

```markdown
## feat/thing
```

**The heading is the branch and nothing else** (Dave, September 3, 2026). It carried a title word, the
branch in backticks and the branch's creation stamp — `` # Development: `feat/thing` · 20260823-101500 ``
— and every part of that had a reason that has since run out. The title said what the file is, which the
filename now says; the backticks delimited the branch name for the readers below, which they no longer
need; and the stamp recorded when the branch began, which nothing ever read back. What the changelog
orders by is the **merge** stamp, and that one stands on the `### DEPLOY:` heading itself (Dave,
August 23, 2026, where it sat on the `#### Pull Request` heading before that), written by the fold from
the pull request's own merge moment.

The **DEPLOY heading keeps its title word** — `### DEPLOY: feat/thing` — and that asymmetry is deliberate
rather than an oversight. That heading travels into your changelog, where it stands beside other entries
and has to say which of the four phases it is; this one opens a file whose name already says so.

**The branch name in the heading is machine-read.** It is how the fold finds the PR to look up, and how
`new-branch` decides whether this document is already somebody's: any name other than the trunk's is a
branch's work and is not written over. A heading naming the **trunk** is the empty state and may be
overwritten — that state is no longer produced, since the fold removes the document rather than emptying
it, but a repo updating from an older plugin has one on its trunk until its next fold clears it, so it is
still recognised. Every shape the heading has ever had is read; only today's is written.

### The version suffix

A branch name **may** end in **`-v<N>`**, and a second development cycle on the same subject keeps the name
and bumps the number — `feat/thing`, then `feat/thing-v2`. It is **typed by hand**: `new-branch` uses the
name exactly as given and nothing rejects a `-vN`.

**`new-branch` used to complete `-v1`** on any name that carried no suffix — from August 23 to
September 3, 2026. It was dropped because the case it served had not occurred: in 209 branches that reached
a merge carrying the suffix, none was ever bumped to `-v2`, while every caller paid for the rewrite. It was
also the direct cause of inbound #1224 — a consumer wrapping the script for a branch whose name it does
**not** own (a Dependabot PR branch) had a second branch, `<their-name>-v1`, created, committed to and
pushed, leaving the entry on a branch the pull request does not point at.

`new-branch` stays idempotent: running it again on the same name *resumes* that branch, which is what
makes it safe to reach for twice and what the `-Park` flow needs. Nothing scans for the lowest free
number — **a bump is a decision you state by typing `-v2`**, which is also exactly how the rule was given.
The `final` refusal in `branch-info.ps1` points you at a hand-typed `-vN` as the honest form.

**It is the same rule `final` was already refused for.** A branch named for being the last word on
something is a prediction, and the prediction is wrong often enough that the next round has to be called
`final-2`. A number makes no claim about being the last one.

## The step list: PLAN, CREATE, TEST

The plan is yours. It is never folded and never travels, so it may hold whatever helps you pick the branch
back up — notes, links, a scratch list. What scripts read out of it is the **step marks**, wherever they
stand.

`new-branch` scaffolds **one open step**, so the gate below has something to refuse.

### The four phases, and why one of them takes no steps

The document is scaffolded with **PLAN**, **CREATE** and **TEST** as headings, and **DEPLOY** is the fourth
phase — written by the formatter that owns what goes in it, because that section *is* the changelog entry.
So a branch moves through a recognisable arc instead of an ad-hoc list. **Four `###` headings, never a
fifth**: anything else you need is a `####` under one of them. The step half of the gate still reads step
marks only, so a heading of any level is invisible *to that half* and the arc stays drawn on top of the
mechanism rather than inside it.
**A phase with nothing under it is not a finding**: a branch that had nothing to test says so by leaving
that heading bare, exactly as a branch with no step list at all is permitted.

**Two shape rules, and only one of them is checked in your repo.** `open-pr.ps1` **refuses** a
document whose region between the title and the first `###` carries anything but the guidance block —
before the push, since source-repo issue #1650; `check-branch-entry.ps1` **reports** the same finding in
CI, from the same function, because that gate names things rather than blocking them — that
one holds **everywhere**, because it reads the shape rather than the text: guidance is blockquoted
whatever language it has been translated into, so a `>`-less paragraph there is this branch's own content
sitting where every branch document is identical. The **heading count** is refused only in the repo that
maintains this workflow, deliberately: heading-blindness is what lets a repo that adopted this document
keep headings of its own, and a check that refused those would refuse correct files. Both rules were added
in the source repo on August 26, 2026 after the same document broke each of them within one afternoon —
issues [#898](https://github.com/DaveKJohn/claude-code-specialists/issues/898) and
[#899](https://github.com/DaveKJohn/claude-code-specialists/issues/899). The preamble one had been broken
by two sessions in a row, in the same position, which is what makes it a shape the document invites rather
than a slip. **Why that one is not tidiness:** the stray paragraph sat flush under the guidance with no
heading between them, so it *read* as guidance — and a reader who finds one branch's status inside a
generic block learns to distrust the whole block, including the rules that do apply everywhere.

**But an empty phase is a statement, and on a branch whose work *was* judgement that statement is
false.** Verifying a report, choosing between two designs, establishing that a claim still holds —
none of it produces an artefact until the writing starts, so the arc offers it no home and the path of
least resistance is to record only the writing, which is the least interesting half. **Those are PLAN
steps**, written like any other: `- [x] Verify the claim still stands: <what you read, and what it
said>`. A branch whose PLAN is empty because nobody wrote the plan down reads exactly like one that
arrived needing no plan, and no gate can tell those apart — which is why this is a convention for
whoever is writing rather than a check on them.

**And TEST answers with a reason rather than with nothing.** Where no automated test was added, `- [~]`
is what says so: *no suite, and here is why* — the existing gates already cover it, the surface does not
lend itself to one, the change is prose. Leaving the heading bare stays permitted and stays no finding;
it is simply the weaker of the two answers wherever there **was** a reason, and the reason is the half a
later reader can use. Raised in the source repo as
[#846](https://github.com/DaveKJohn/claude-code-specialists/issues/846), on a branch whose defining work
was deciding two open questions and verifying seven reported claims against the tree, and whose PLAN and
TEST were both empty.

**TEST is where the branch verifies ITSELF, and that is the phase's whole job.** Give Claude a check it
can run — a suite, a gate, a build, a rendered result to compare — and the session changes character: it
becomes one you can walk away from instead of one you have to watch. The development document names *when* and
*where* that happens, because a check with no place in the arc gets run when someone remembers to. **A
branch reaches DEPLOY once it has verified itself here**, and TEST is the phase that says what was run and
what came back.

**And "reaches DEPLOY" means WRITES it, which is not the same as arriving at it.** The two read alike and
only one survives a failing suite: an entry composed while TEST is still open says what the branch was
*going* to do, and every gate that runs at the push reads the step marks rather than the prose — so nothing
compares the two. Then the suite turns something up, the change grows a commit, and the entry that folds
into `CHANGELOG.md` still describes the version that did not ship. Write the section once TEST is resolved;
[rule 6](#rules) carries the timing and the one field that is deliberately excepted from it.

**So `- [~]` means "no SUITE", never "no verification".** Those are two different sentences and only the
first one is ever true of a finished branch. A dropped step still names what stands in for the suite —
*"no suite: the lint gate and the existing suites cover this, and `open-pr` runs them before the push"* —
because that is what a later reader, and any evaluator judging whether this branch is done, can actually
use. A TEST phase whose content is only *"nothing to test"* is an assertion, not a verification; nothing
was named, and the document says so in a way that reads as though something had been.

**Cite a standing gate as COVERAGE, never as an outcome.** Adding *"all green"* to that line looks like the
stronger answer and is the weaker one: the gates fire at the push, under their own power, so at the moment
the step is written that result does not exist yet — and the only way to make it exist is to hand-run the
very suites the push is about to run. The step list is what makes that hand-run compulsory rather than
merely tempting: `open-pr` refuses to push while any step above DEPLOY is open, so a line claiming a green
gate cannot be resolved until somebody has run the gate by hand. Measured in the source repo as
[#1060](https://github.com/DaveKJohn/claude-code-specialists/issues/1060) — the hand-run overran its
foreground timeout and had to be backgrounded twice, while the gate's own run of the same suites finished
in under a minute immediately afterwards. Write what the gate covers, which is true at the moment you
write it.

**Two shapes are honest and neither is a suite.** One reports a result the session has actually seen — a
check the phase cannot make automatic, a rendered page compared by eye, an output read against what it
should say — as long as it records that the check was run and what it showed. The other names the standing
gate that covers the change and stops there, without an outcome, precisely because that gate has not run
yet. What is *not* a verification is either shape claiming a result nobody has seen: a step ticked because
the change looks correct, or a gate reported green before it fired. That is the failure
[rule 3](#rules) already names from the other side, met here at the phase that exists to prevent it.

**Where the cycle is driven by [a goal condition](#driving-the-cycle-to-its-end-a-goal-condition), this is
the half the evaluator can see.** That evaluator judges from what the session has surfaced and runs nothing
of its own, so a check whose result lands in the transcript is what lets the condition resolve at all — and
a TEST phase that only claims to be done leaves it nothing to read.

**DEPLOY takes no steps of its own** (Dave, August 14, 2026,
[#655](https://github.com/DaveKJohn/claude-code-specialists/issues/655)). It is not a step, it is the
**result** — the part that travels, folding into `CHANGELOG.md` at the merge while the rest of the document
goes with it. A checkbox under it could only be a lie.

That also explains a rule which otherwise looks arbitrary: a step written for *after* the merge is refused.
Post-merge is DEPLOY's territory, and DEPLOY is a description rather than a checklist. A DEPLOY checkbox
could only be unresolvable — the list must be clear before `open-pr` will push — or ticked before it
happened.

**A checkbox inside the DEPLOY section is prose, not a step**, and no gate reads it as one. The step gate
splits the document at the DEPLOY heading and counts only above it, which it has to: an entry legitimately
describes work in that shape, and this page's own rules below show all three marks.

The phase names come from the wording seam, so a repo can rename them; supplying an empty list switches
them off and restores the plain step list.

### Before the plan: explore first, then plan

**Read before you write, and let the harness hold you to it.** Jumping straight to code produces code that
solves the wrong problem, and the PLAN phase is where that is prevented rather than detected. So the work
before the plan happens in **plan mode**: Claude reads files, runs commands to explore, and proposes a
plan, but does not edit anything — edits stay blocked until the plan is approved. Enter it with `Shift+Tab`
or by prefixing one prompt with `/plan`; a whole session can start there with
`claude --permission-mode plan`, and a repo can make it the default with `"defaultMode": "plan"` in
`.claude/settings.json`. Approving the plan is what leaves plan mode, so the transition out of exploring is
a deliberate act rather than a drift.

**The order matters, and getting it wrong stalls step one on its own scaffold.** `new-branch` *writes a
file* — the development document — so it cannot run while plan mode is still blocking edits. The
sequence is therefore:

1. **Explore in plan mode.** Read the code, the docs and the history that bear on the assignment. Answer
   the questions the assignment raises. Change nothing.
2. **Propose the plan and have it approved.** That approval is what exits plan mode.
3. **`new-branch`.** Now the branch and this document come into being.
4. **Write the PLAN steps** — from what the exploration established, not from what it guessed.

**Which is also why the PLAN phase has steps at all.** What exploration produces is exactly what
[the phase guidance above](#the-four-phases-and-why-one-of-them-takes-no-steps) asks for: verifications
and decisions, each written as a step with what it read and what that said. A branch that explored first
and recorded nothing has thrown away the only part of that work a later reader can use.

### Driving the cycle to its end: a goal condition

**A development cycle has a verifiable end state, which is exactly what `/goal` is for.** Set the
condition once and Claude keeps working toward it without being prompted each step: after every turn a
small fast model judges the condition and, while it does not hold, another turn starts instead of control
coming back to you. One goal is active per session, setting it starts a turn immediately, `/goal` on its
own shows the state, and `/goal clear` removes it.

**Write the condition so this document's own gates prove it.** The evaluator **runs no commands and reads
no files** — it judges only what Claude has already surfaced in the conversation. So a condition must be
something Claude's own output demonstrates, and for a branch that is the gate output the phases already
depend on:

```text
/goal every step above the DEPLOY heading in dkj-policy/<branch>.md is resolved
and open-pr reports the lint and test gates green, or stop after 20 turns
```

The turn clause is not decoration: a goal with no bound can run a long way on a wrong premise, and Claude
reports progress against that clause each turn for the evaluator to judge.

**A goal ends in one of three ways, and only one of them means the branch is blocked.** Reading them as one
is the mistake worth naming, because two of them look alike from the outside:

| how it ends | what the harness does | what the branch does |
|---|---|---|
| **Met** | clears the goal, records it achieved | continue into DEPLOY — the cycle is finished |
| **Impossible** | clears the goal, records it failed **with a reason** | **park the branch, and the blocker becomes its own issue on its own cycle** |
| **A stall** — no tool use for several turns | stops the loop, warns, hands control back with **the goal still set**; evaluation resumes on your next prompt | nothing. This is not a verdict about the work |

**So a stall is not a reason to park anything.** The goal is still standing and the harness is waiting for
a prompt; treating it as a blocker throws away a branch over a loop that simply went quiet. Only the
**Impossible** verdict is the harness saying the condition can never be satisfied — and that is the moment
the branch is parked and a new issue is filed, so the blocker gets a cycle of its own instead of holding
this one open. That is the same shape a session's own close-out uses for an unexpected blocker.

**Two more endings belong to the environment rather than to the work.** An error you have to fix —
authentication, an exhausted balance, a context overflow auto-compaction could not clear, an unavailable
model — clears the goal with a warning naming the cause; fix it and set the goal again. And **background
work defers evaluation**: while a subagent or a background shell command is still running, that turn is not
judged at all, which matters in any repo that ships from the background — the goal is waiting, not stalled.

**The cycle does not depend on any of this, and that is deliberate.** `/goal` is part of the hooks system,
so it is unavailable in a folder that has not been trusted and in a session with hooks disabled. Every
phase, every mark and every gate on this page holds exactly as it does without it. What a goal adds is that
nobody has to prompt the cycle forward turn by turn — a strong default, not a requirement.

## The DEPLOY section — the changelog entry

```markdown
### DEPLOY: feat/thing-v1 · <the merge stamp the fold writes>
```

`new-branch` already writes this shape, so on a fresh branch you are filling in a form rather than starting
from a blank page. **What it fills in for you** is the heading — which names the branch, so the type is
already there in its prefix — and the PR title you gave it at `-Title`. What is left for you is the reason
and the score under each tier the file carries.

**The merge stamp is on this heading** (Dave, August 23, 2026), where it sat on the `Pull Request` section
heading for four days. It is the date the change *landed*, and this is the line that says *what* landed.
Neither the number nor the date exists while you are writing; the fold writes both.

**A relative link in this section resolves from wherever your `CHANGELOG.md` sits — not, in general, from
this directory.** The fold copies this text verbatim into that file, so the link has to be written for where
it *lands* rather than for where you are typing it.

**Which directory that is, is one seam, and the shipped default puts it beside this document.**
`Get-ChangelogPath` answers it; left unset, a repo that publishes no plugin marketplace gets
`dkj-policy/CHANGELOG.md` — the same directory this file is in, where the link that already reads
correctly in front of you *is* the correct one. A repo whose changelog is at the root gets the opposite, and
there the correct form looks wrong until it moves:

```markdown
See [the lib](scripts/lib/release-lib.ps1).       <- correct where the changelog is at the ROOT
See [the lib](../scripts/lib/release-lib.ps1).    <- correct where it sits BESIDE this document
```

**You do not have to work out which one you are.** The guidance block at the top of your own
`dkj-policy/<branch>.md` states your repo's answer in one sentence, composed by
`new-branch` from the same seam `open-pr`'s link gate resolves against — so the file you are typing in and
the gate that refuses cannot disagree about the base.

The instinct produces whichever form reads correctly in front of you, and until August 21, 2026 nothing said
otherwise: a consumer merged two `../../scripts/...` links that landed at the root pointing outside the repo,
with every gate green (inbound
[#806](https://github.com/DaveKJohn/claude-code-specialists/issues/806)). `open-pr`'s **link gate** refuses
it now and prints the form the destination needs, so the correction is one edit rather than a guess.

**That repair then assumed the root for another two weeks**, which is inbound
[#967](https://github.com/DaveKJohn/claude-code-specialists/issues/967): once the changelog isolated by
default, the gate demanded the dead form and refused the live one in exactly the repos it had been shipped
to. Both halves are the same lesson twice — the base is where the text lands, and where that is is a fact
about your repo rather than about the form.

**Write the whole document by whichever rule your answer gives**, plan included: the head carries no links in
the scaffold, and one rule for one file is the only version anybody can apply while writing.

**The PR title is the first line of the `Pull Request` section** (Dave, August 7, 2026;
[#506](https://github.com/DaveKJohn/claude-code-specialists/issues/506)). `open-pr` composes the PR title
as `<branch type>: <that line>` rather than taking one on the command line, so the sentence is written
once — at `new-branch -Title` — and what the PR is called, what `CHANGELOG.md` says and what the release
documents carry are the same words by construction. Write it **without** a `feat:`/`fix:`/`docs:` prefix:
the branch name already states the type and `open-pr` puts it in front.

**It used to be a section of its own, and both homes are still read.** `Get-EntryPrTitle` owns that answer:
a section headed `Branch title` — `Branch description` before it — wins wherever one is present, and
otherwise the title is the `Pull Request` section's first line, skipping the `Plugins:` line and the
`[PR #N]` footer that the fold appends underneath it. So `CHANGELOG.md`, every release document and any
branch still in flight under the older shape fold unharmed. **Ask the seams rather than this page** for
which sections exist today: `Get-EntryWrittenSectionKeys` is what a writer emits,
`Get-EntrySectionHeadings` gives each one's heading text, and `Get-EntrySectionRetiredNames` the names that
are recognised but must never be written again. Recognise both, write one.

### The two tiers

**Two tiers are asked about: tier 0, and the one audience tier this repo has.** Tier 0 can always be filled
in — every change matters to the people who maintain this repo, if only a little. For the audience tier the
answer may well be *"this reaches nobody here"*, and you say so:

| block | who notices | answer it with |
|---|---|---|
| the DEPLOY section's own opening text | this repo's own developers — **tier 0** | a score, always |
| `#### What makes this deploy extra special` | a subscriber of the service — **this repo's audience, tier 2** | a score, or `N/A` if no subscriber would notice |

**Tier 0 has no heading of its own**, and the DEPLOY heading is its section (Dave, August 23, 2026). It was
`#### Tier 0`, then a `###` question of its own; the question went away when the entry became a section of
this document, because the heading above it already asks it. The audience tier's heading moved **up** a
level in the same change — it is the entry's first inner heading now, at the same level as `Pull Request`.

**Neither heading names a tier, and that is deliberate** (Dave, August 19, 2026). An author filling one in
is answering a question rather than classifying a reader, and the second heading **resolves** to whichever
audience tier the repo has stated, so the form stops naming a number that is only right for repos answering
2. The tiers still exist exactly as before; they live in the parser instead of in the prose. **A repo that
has stated no audience tier keeps the older shape**, a `##### Tier N` sub-section per tier the model has with
tier 0 among them, because a heading with no tier to resolve to would read as tier 0 and empty its release
documents.

**Which of the two audience tiers you get is a repo-level fact, not a per-entry choice** (Dave, August 12,
2026). Tier 1 (management and the employer/commissioner) and tier 2 (the subscriber of a service) are two
kinds of reader rather than two rungs, and a repo has exactly one: it is stated once in
`Get-ReleaseAudienceTier`, and the scaffolder writes only that one. This repo answers **2**, being a service
rather than a product. A repo that has stated nothing is asked about both, exactly as before the knob
existed — and a tier this repo no longer asks about is still *read* wherever an older entry carries one, so
none of the 97 entries written under the cumulative model stops folding.

Each section carries **why it matters at that reach**, then **`**Score:** N`** — 1 to 5 against the rubric
`new-branch` prints when it writes the file. The tier decides which release documents the entry appears
in; the score decides where in each of them it sits.

**`N/A` needs its reason too**, and that is the point of answering rather than leaving a blank: *"no
consumer can observe this at all"* is information, and it survives into the record. A blank cannot say
that — it means both "reaches nobody" and "nobody has got to this yet", and the gate has to be able to tell
those apart. **The reach is the highest tier with a number**, so an `N/A` costs nothing but a sentence.

**When an entry *retires* something an earlier release note told the reader to start doing, the
audience tier is never `N/A`.** The test to apply is *"did an earlier note tell them to adopt this?"*,
not *"could an end user of a published product see it?"* — the second is the tier-1 webshop-customer
test, and reaching for it in a tier-2 repo is exactly what produced the measured miss (inbound
[#1061](https://github.com/DaveKJohn/claude-code-specialists/issues/1061)): the entry that retired
`/lock` and `/handover` in v4.21.0 scored `N/A` with the reasoning *"never anything an end user of a
published product could see"* — true of a webshop customer, false of the person running this
workflow, who **is** the tier-2 subscriber here. Measured in this repo's own audience notes: the
convention's *arrival* earned 13 mentions across four notes (4.13.0 through 4.16.0), one of them the
front-of-note item a reader had to act on; its *retirement* earned zero, in either the 4.21.0 note
that removed it or the 4.22.0 note after it. An arrival is news that writes itself — there is
something new to describe. A retirement leaves nothing behind to describe, which is precisely why it
needs the explicit test rather than the instinct of "is there anything left to say here."

**And a retirement is actionable for the reader for a reason that holds every time, not only in this
instance: nothing reaches into a consumer's tree to clean up after a removed convention.** A retired
skill leaves live artefacts behind on the consumer's side — a file, a `.gitignore` line, a documented
habit — that nothing in the plugin's adoption path will ever touch, because that path is strictly
additive. The audience note is the only thing that can tell the reader those artefacts are now
stale, which is why scoring the retirement `N/A` does not just under-report it; it removes the one
route the news had.

**The ladder is gone, and with it the second reading it forced.** Until August 12, 2026 a scored tier 2
*owed* a tier-1 section, and `open-pr` refused an `N/A` there by name. Measured before removing it: of this
repo's 89 tier-1 sections, **81 existed only because a tier-2 section sat above them** — the same reach
argued twice, in a second register, for a reader who here is the same person. What remains enforced is that
every tier the file *does* carry has a reason, `N/A` ones included, and that the audience tier a repo asks
about is answered before a PR opens.

### Four things about this shape, each of which someone has got wrong before

- **The PR line is not yours to write.** The fold fills `#### Pull Request` from the merge itself.
- **Nothing may use `###` inside the section, and `####` only for its named headings.** A `###` becomes a
  *separate change* the moment the fold pastes this into `CHANGELOG.md` — one that declares no impact, so it
  reads as tier 0. A `####` collides with the named headings, truncating whichever one it lands in. Use
  `#####` or bold. Your lint gate checks this where you have one — the source repo's does, reading the DEPLOY
  section out of the document rather than the whole file.
- **The `###` headings are exact.** They are what the parsers look for; a misspelling means the entry
  silently loses that declaration and the gates read nothing.
- **The score is scaffolded empty**, and that is a question rather than a default. Tier 0 is a harmless
  final answer about *reach*, but any number written into `**Score:**` for you would be a guess at a
  ranking — and this repo has measured what a guessed ranking costs. The release cut refuses a release
  whose tier-1-or-higher entries have not answered.

**And an empty field is refused, which is what replaced the `TODO:` lines.** The form writes no visible
placeholder anywhere, so `open-pr` measures instead of matching: it names the description, the body and
any tier whose reason is still blank. That catches the untouched entry the placeholders used to catch
*and* the one whose placeholder was deleted rather than answered.

### When your entry contradicts one already pending, name it — and leave that one alone

`[Unreleased]` holds every entry merged since the last release, and they ship as **one** release note.
So two entries in that block can disagree: a question filed out of one branch and answered in another,
both landing between the same two cuts. Each is accurate as history — it says what its own branch decided
on the day — and together they tell the reader both that the tool warns and that it refuses, with nothing
saying which sentence describes the version they installed.

**The correction travels with the newer entry, never backwards.** Your DEPLOY section gains a short
paragraph naming the pending entries it overtakes, quoting the claim it supersedes, and stating that this
one is current. The superseded entries are not edited.

This is the [published-record rule](RELEASES-portable.md#once-it-has-landed-it-is-a-published-record--and-that-protects-only-what-was-true)
one stage earlier, and for the same reason. A line that was **true when it was written** and has since
been overtaken is stale, not false, and going stale is the record working; amending it to say something
its branch did not do writes a decision into history that was never taken there. An entry is also the
only durable record of **why a branch held back** — the asymmetry it declined to settle, the follow-up it
filed — and that reasoning is what the next reader needs when the question comes round again. Rewriting it
destroys that to repair a rendering.

**Nothing detects this, and nothing is built to.** The fold has no notion of one entry superseding
another; it pastes a section into a list. The author of the later branch is the only person who knows the
earlier claim exists, and normally knows it well — the superseding branch is usually the one the earlier
entry filed the issue for. So this is a habit at the moment you write DEPLOY, not a gate: **before you
write that a behaviour changed, grep `[Unreleased]` for what it used to be.**

The measured instance is
[#1424](https://github.com/DaveKJohn/claude-code-specialists/issues/1424) in the source repo — three
entries in one block, two of them stating that the branch scaffolder only warns on a stale base and the
third being the branch that made it refuse.

## Why one file and not two

Two files used to do these two jobs, and before them one file did both badly. The one-file version was
scaffolded with a bold *to do / where I left off* heading **and** folded verbatim into `CHANGELOG.md`, so
"replace this whole block before the PR" had to be a written instruction rather than something the format
made obvious. It did not always happen: three of v3.2.0's twenty-one entries shipped with that heading and a
status appended behind it, into the release notes *and* into the per-plugin `CHANGELOG.md` files that travel
to consumers.

**Splitting them fixed that, and the split then cost something of its own** (Dave, August 23, 2026). The two
jobs genuinely are different — one asks what the change does, the other what is left — but putting them in
two documents meant the plan a branch is working through and the claim it will make were never on one
screen. An author who has just ticked the last box is now looking at the paragraph they have to write next.

**What made the merge safe is that the confusion the split removed is structural now.** The entry is a
*named section* with the branch in its heading, not the whole file: the fold takes that section, the step
gate counts only above it, and the scaffold gate reads only inside it. Nothing has to be "replaced before
the PR", because nothing is doing two jobs at once.

**There is also no `Where I left off` any more** (Dave, August 23, 2026). It asked the author to write down
what the step list already says: an unticked box *is* where you left off, and a second account of it beside
the list is one that can disagree with the list. A parking note still has a place — `new-branch -Park
-Intent` writes it as the opening paragraph of `PLAN`, still without a heading — because that is the one
thing the marks genuinely cannot carry: what you decided and have not written down anywhere yet.

**It sat above the phases until #908** (August 26, 2026), and that is worth knowing if you have a branch in
flight from an older version of this workflow. The region between the title and the first phase heading is
generic guidance, identical in every branch document in every repo, and the CI gate reads it: a note there
is refused as branch content the moment the entry is written. Move it under one of the four — `PLAN` for a
parking note — and the gate goes quiet.

## Why the name carries the branch

**One document per branch: `dkj-policy/<branch>.md`**, where `<branch>` is the
branch name with its slashes flattened — `fix/thing-v1` becomes `fix-thing-v1.md`. Two
branches therefore never write the same path.

**The name is the branch and nothing else** (Dave, September 3, 2026). It was `development-<branch>.md`
for a few hours on the day the per-branch form arrived, and the prefix bought a reader nothing the folder
did not already say. It bought the *tooling* one thing, which is worth knowing if you fork any of this: it
made `development-*.md` a glob that could not reach this folder's own permanent pages. With the prefix gone
the shared scripts exclude those pages by name instead — your changelog above all, since every folded entry
in it declares a branch and would otherwise read as a document waiting to be folded.

**This reversed a decision, and the reversal was measured** (September 3, 2026). The name used to be the
fixed `development.md`, on the argument that it could not collide because *git already tracks this file per
branch, so each branch carries its own version of the same path and a checkout swaps them.* That is true of
**checkout** and says nothing about **merge**, which is where the collision actually lives. Every merge to
the trunk puts the merged branch's document there, and every other open branch then conflicts with it —
`add/add` if it has never taken the trunk in, `modify/delete` afterwards — without anybody touching those
branches.

**What that cost is why this is not a tidiness change.** A conflicting pull request has no merge ref, so the
forge creates **no check suite at all** for it; where a green required check is what permits a merge, a check
that was never created can never go green. The pull request cannot merge, so it stays open, so the next merge
conflicts it again. Measured in this workflow's own source repo: all four open pull requests were conflicting
and this document was the *only* conflicting path in three of them.

**The fold is not the answer, and that was measured before this was written.** Simulating a completed fold —
the trunk with the document deleted — against those same four pull requests cleared the two `add/add` cases
and left the two `modify/delete` cases conflicting. Deleting the trunk copy changes the conflict's *shape*,
not its existence. Nor is a `.gitattributes` merge strategy, which this page used to recommend as the cheap
repair: a forge computes mergeability with its own machinery rather than your merge drivers, and a `union`
merge of this document would produce one declaring two branches — which is the one thing every reader of it
resolves on.

**The old decision's second half was right and is preserved.** The pre-August-2026 per-branch form cost *a
repo root that filled up with other people's in-flight work* — and that was about the **root**, not about the
filename. These documents live in the workflow's own folder, beside `CHANGELOG.md`, so the root is untouched
and a relative link written in a DEPLOY section still resolves after the fold.

**And the trap that form set is deliberately not rebuilt.** It made the fold guess the branch out of the
*filename*, which is why a `-v2` suffix was once forbidden: a suffix broke the match and the cleanup after
it. Here the filename is a **write convention and a read candidate, never the authority**. The resolver
still identifies a document by the branch it **declares** in its own heading, and it discovers candidates by
pattern rather than by trusting a name — so a branch renamed after its document was written still resolves,
a document written by hand under a mismatched name still resolves, and `-v2` costs nothing.

**One argument for the fixed name expired earlier and is recorded so nobody reinstates it.** It ran: unique
names would make the reset state impossible, since the warning on the trunk exists only because the file
exists there. On August 23, 2026 (Dave) the document became branch-lifetime and the trunk stopped carrying a
copy at all, so there is no reset state to protect.

## On the trunk there is no file at all

**The document exists for the lifetime of a branch and no longer** (Dave, August 23, 2026). `new-branch`
creates it, the fold removes it at the merge, and between branches your workflow folder holds its pages and
its directories and nothing else. So if you open that folder on the trunk and the document is not there,
that is the trunk in its normal state rather than something somebody deleted.

Until that day it was rewritten to a **reset state** instead: the same document, with the trunk's name in
its heading, a warning under it saying not to write here until a branch exists, no scaffolded step, and
placeholder text where the two stamps go. It was retired because an empty placeholder is a permanent
resident of the one folder a repo reads to learn the convention, and because this page is the better home
for what that copy was really for — seeing the whole form at once.

**A repo updating from an older plugin still has one**, written by its last fold under the old behaviour.
Nothing has to be done about it: the next fold removes it. Everything below that describes recognising a
trunk-declaring document is about exactly that case.

**How such a document is told from a written one is the branch NAME, not the heading level**, and that
changed with the merge. The two files it replaces each opened with an `#` while empty and the entry with an
`##` once written, so one look at the first line answered it. One document cannot use that test: its `##` is
its title in both states, and the `###` below it is a section of it. So the test is the name — the trunk's
while the document is empty, yours once it is not. It used to be what made folding twice impossible; the
fold removes the file now, so a second run simply finds nothing.

**And on August 26, 2026 that stopped being a preference and became the only test that works.** Both level
pairs moved one deeper, which put this document's title at the level an entry used to occupy — so the
level-based test would now read an empty trunk document as a foldable change and hand the fold an empty entry
to paste in, on the trunk, unprompted. `Test-IsChangelogEntryFile` therefore answers on the declared name
*before* it looks at any depth: a document naming the trunk is a reset, full stop. The lesson generalises past
this one function — **the name survives a re-level and the level does not**, so anything load-bearing keys on
the name.

## The file is written under you, once per cycle

`new-branch` writes it when the branch is created. That is an **out-of-band write event**, and it is the
only one of its kind in a repo: no other file is written alternately by a script and by whoever is editing
it. It was two until August 23, 2026 — the fold used to rewrite the file after the merge, and now removes
it, so there is nothing left to re-read at that end of the cycle.

So **read it again whenever a script has just touched it**, before your next edit. An editor that tracks
what it last read refuses the write otherwise — *"file has been modified since read"* — and the refusal
lands on the **first** write after the script, which in practice means the second and later branches of one
sitting rather than the first. Nothing is lost and nothing is broken: one read re-syncs it and the write
goes through. Measured over three full cycles in a single session: two refused writes, three stale notices,
nothing clobbered. What it costs, if you are not expecting it, is a line that reads as a failing tool.

Both scripts say so where they print that path, which is the half that reaches whoever ran them; this page
is the half that reaches whoever did not. **The guard itself is not a defect and is not something a repo can
or should switch off** — it is what stops an edit silently overwriting an out-of-band change nobody saw, and
this is exactly the file where out-of-band changes are routine.

## Rules

1. **The DEPLOY section holds the entry block and nothing around it** — no preamble, no warning. That is
   what makes it pasteable into `CHANGELOG.md` in one go, which is its whole reason for existing. It opens
   with the branch, and that is what lands in the changelog.
2. **Links are written for where the DEPLOY section LANDS** — the directory your `CHANGELOG.md` sits in,
   which is beside this document on the shipped default and the repo root wherever `Get-ChangelogPath` says
   so. The guidance block in your own cycle document names your answer; your lint gate, where you have one,
   checks them from there.
3. **Every step is resolved before the PR.** `open-pr.ps1` and `ship-pr.ps1` both refuse while anything
   is unresolved. Three marks:

   ```text
   - [ ] not done yet          -> blocks the PR and the merge
   - [x] done
   - [~] dropped -- <why it turned out not to be needed>
   ```

   `- [~]` exists because a plan legitimately grows items that stop making sense. Without it a gate
   teaches people to tick boxes for work they did not do, and then reports success — worse than no gate.
   A dropped step keeps its line and its reason, which is the half worth reading later. **There is no
   `-Force` for this gate**; the dropped mark already is the way past a step that should not be done.
   The three marks are *shown* in the document's own guidance, and the gate does not read them there — it
   strips comments before it counts, exactly as it already ignores them inside a fence. Without that, every
   freshly scaffolded branch would report four open steps: its own, plus the three the form uses to explain
   itself.
4. **A step still carrying the scaffold's own placeholder is refused, ticked or not.** Ticking the
   scaffolded first step without replacing it reports a plan as finished that was never written. The trunk
   copy shows the phases **empty** — a reference whose first line is somebody else's TODO gets copied in —
   but the file a branch actually gets carries one open step, so the gate has something to refuse (Dave,
   August 6, 2026).
5. **Work that happens after the merge is not a step.** Opening the PR, waiting for CI, merging, folding,
   publishing a GitHub Release, taking a measurement that only exists once the run is over — none of it
   belongs under a phase heading. It is what the DEPLOY section *describes*, in prose, once it has happened.

   **Neither mark fits it, and that is the whole argument.** The gate above runs *before* the push, so at
   the moment it reads the list the step cannot be done. `- [x]` reports work that has not happened;
   `- [~]` says the step turned out not to be needed, when it is needed and simply comes later. The only
   way to satisfy the gate is rule 3's own named failure — ticking a box to get past it, after which the
   run reports success.

   **Measured across the 105 branches that have carried a step list** (August 13, 2026): **17** wrote a
   post-merge step. **4** left it open, where it blocked the PR. **14** ticked it in advance — provably in
   advance, because the fold clears this file at the merge, so a ticked PR step can only have been
   written before the push existed. And one branch is in both counts:
   `docs/check-20-and-inbound-catch-up` hit the gate on `- [ ] Lint + tests green, then PR + merge + fold`
   and the next commit changed nothing but that box to `- [x]`. Two other branches reached the right answer
   on their own and dropped the step with the reason on the line, which is what this rule generalises.

   **No gate enforces this, deliberately.** A check would have to recognise a post-merge step by its
   wording, and `open-pr`, `merge` and `fold` are also the subjects of perfectly ordinary steps — *"`open-pr.ps1`:
   recognise the new placeholder alongside the two legacy ones"* is real work on a branch. Separating the two
   needs an exclusion list, which is the shape this repo has been bitten by often enough to stop reaching
   for it (see the declined checks in the source repo's
   [`CLAUDE.md`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/CLAUDE.md#claude-code-specialistss-safety-implementation)).
   The convention is cheap to follow and the failure is self-correcting: write it as a step and the gate
   stops you.
6. **Fill in every tier the DEPLOY section carries once TEST is resolved, and before the PR.** How far the
   change reaches decides which release documents the entry appears in; what it weighs there decides where
   in each of them it sits — see
   [the contribution cycle](CONTRIBUTING-portable.md#significance--two-questions-one-per-reach).

   **The lower bound is the half that was missing** (Dave, August 24, 2026,
   [#867](https://github.com/DaveKJohn/claude-code-specialists/issues/867)). This rule named only *before
   the PR*, which permits the whole section on day one — and a DEPLOY written while steps above it are
   still open states an **intention**, not a result. Nothing holds it against what landed: the step gate
   splits the document at that heading and counts only above it, so what folds into `CHANGELOG.md` is
   whatever was written before the work was finished. The measured instance is the branch that ran
   immediately before the issue was filed: PLAN and CREATE fully ticked, **TEST three steps open** — and
   those steps written as results rather than as checks — with DEPLOY complete and both tiers scored.

   **One field of the section is the deliberate exception, and it is not a loophole:** the PR title, which
   `new-branch -Title` writes at creation. `open-pr` composes the PR title from it rather than taking one
   on the command line, so it is typed once and cannot disagree with itself — and unlike the entry prose,
   it is genuinely known before the work starts. What waits for TEST is the entry's own text and its tier
   scores, which are claims about what the change *did*.
7. **Never edit `CHANGELOG.md` from a branch.** Every branch would be editing the same region of the
   same file; that is the merge conflict this document exists to avoid.
8. **A wall-clock figure in the DEPLOY section names what it included and which machine produced it.**
   This section folds into `CHANGELOG.md` and from there into a release document, so a number written
   here outlives the branch that measured it — and a gate timing is the kind that gets lifted and
   re-quoted as a constant. Two facts make it re-usable, and the number implies neither: **what ran
   inside it** (a lint gate and a test gate summed, or one of them alone) and **where** (how many
   parallel lanes, on what kind of box). Measured instance: one branch wrote three *"full gate"* figures
   — 608s, 471s and 360s — of which the first bundled lint with the suites and the other two, by their
   own wording, did not, and all three were then read as answering the same question.

   **Where the claim is about the gate that BLOCKS THE MERGE, quote that job's own figure, not a local
   reading.** By rule 5 it only exists once the run is over, which is exactly why the local number is
   the tempting one to write; but the two are not the same experiment, and the blocking job's history
   covers many runs where a local reading is a single draw. In the source repo the same two gates cost
   ~476s locally at sixteen lanes and a median **936s** across twelve CI runs on a four-core runner —
   about 2x — with the CI band alone spanning 676–983s. A local figure is still worth writing down. It
   simply says what your machine did, and has to say so.

## What happens at the merge

[`scripts/release/fold-changelog-entry.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/release/fold-changelog-entry.ps1),
run on `main` right after the merge:

1. **splits the document at the DEPLOY heading** and takes that section — the plan above it never travels;
2. **strips any HTML comments** — the guidance is the form rather than the answer;
3. inserts the entry at the **top** of `CHANGELOG.md`'s list — that document is newest-first — with the
   PR link written into `#### Pull Request` and the merge moment stamped on the DEPLOY heading;
4. **removes the document** — one deletion, which clears the plan along
   with the entry because they are sections of the same file, and leaves the trunk without a copy;
5. commits exactly those two paths.

The branch name it needs for the PR lookup comes from the document's own heading — the file name does not
carry it, which is why the branch is named in the document rather than only in the scaffolder's head.

**What lands in `CHANGELOG.md` is that section as it stands** — the DEPLOY heading and everything under it,
answers and all. That is a deliberate choice by Dave (August 6, 2026), taken over the alternative he was
offered: a fold that reads the dossier and emits a slimmer block. He declined it, and the reason holds up —
a fold that rewrote the entry would be a *second* definition of the entry format living inside the fold,
which is the drift this repo has already paid for in the fence readers, the scaffold wording and the tier
sections. One shape, written once, read everywhere.

## Working from more than one machine

Park a branch with
[`scripts/task/park-branch.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/task/park-branch.ps1),
or create it with `new-branch.ps1 -Park`: both push with no PR, and both take the whole document — the plan
is the half that says what was still in flight, so parking the description without it defeats the point.
That used to require naming two files; it is one path now.

**They differ in what else comes along, and the commit says so** (#507): `-Park` commits *only* that file,
leaving anything you had staged for your own next commit exactly where it was, while `park-branch` commits
*everything* outstanding. The subjects read `park: <branch> (the branch files only)` and
`park: <branch> (all outstanding work)`. They were the same sentence until August 7, 2026, which meant that
afterwards nothing told you which half of your work had reached origin.

Before picking a parked branch back up, measure its plan against `main`. A plan that reads as current is
not evidence that it is — see the `park` skill for what to check and why.

### The park commit says what is behind the plan — read it before you rebuild anything

Automatic parking publishes the development document **and nothing else**, which is the bound that keeps it
from pushing work nobody asked to publish. It has one perverse consequence, measured on August 27, 2026
(issue #960): a branch whose work sits uncommitted in *another* machine's working copy arrives on origin as
a document reading `- [x]` eight times over, with no commit behind a single tick. From origin, **ticked and
committed** and **ticked and uncommitted somewhere else** are the same document — and the more complete the
ticks, the more convincing the wrong reading. A session picking that branch up in good faith either
rebuilds work that already exists, or opens a PR that merges 161 lines the fold then deletes.

So every automatic park commit carries a `Backing:` line in its body:

```text
park: feat/adopt-something-v1 (the branch files only)

Backing: 8 of 8 step(s) resolved; nothing else committed on this branch; 12
file(s) uncommitted in the working copy this park came from.
This plan reads as FINISHED and no work behind it is on origin. That work is
uncommitted in the working copy this park came from -- it is not missing. Do
NOT rebuild it, and do not open a PR that would merge this document alone: ask
that checkout to commit and push first.
```

Four things about it are deliberate:

- **It is a note, never a gate.** A park that refused because it disliked the shape of the plan would be
  worse than the misleading document, because then the plan would not reach the other machine at all.
- **Counts, never filenames.** The uncommitted figure describes work nobody asked to publish; listing
  those paths would leak the shape of unrelated work onto a public branch.
- **The alarm paragraph fires only on the finished shape** — no step open, at least one resolved, nothing
  else committed. "Any resolved step with no commit behind it" would fire on nearly every early park,
  because a planning step ticked before a line of code exists is the ordinary case, and an alarm that
  fires on almost every park is one nobody reads by the time it matters.
- **It is measured on the machine that holds the invisible work**, at the one moment it becomes invisible.
  Nowhere else can take that measurement: from origin those files do not exist.

`git log -1 --pretty=%B origin/<branch>` is how the note is read back, and it is worth knowing that it is
now the only way. A reporter used to print it under every parked branch automatically — and to say so
plainly where there was none (a branch parked by hand, or one whose last commit is `new-branch`'s push at
creation, which stamps no note because at creation there is nothing behind the plan yet). That reporter
went with `/lock` and `/handover` on August 27, 2026. Nothing about the note itself changed: it is still
stamped, still on the commit, and still an **echo** rather than a recount — the figures describe a working
copy the reading machine cannot see, so a local recount could only be confidently wrong.
