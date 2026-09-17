# Changelog

Everything merged since the last release sits under **`## [Unreleased]`**, **newest first**: **one `###` per
change**, and under it two named `####` sections. The `###` heading is the change's own —
`` DEPLOY: `<branch>` `` and the moment it
landed — and the text directly beneath it answers what a reader arrives with: what the change deploys to
`main`. Then `#### What makes this deploy extra special` for the second audience, and `#### Pull Request`.
Every level here moved one deeper on August 26, 2026, when the pending section above them was introduced and
the development cycle beside them shifted to match; entries written before that day carry the whole set one
level shallower and are read exactly as they always were.
The tier numbers live in the parser rather than in any heading. That second heading said `PR` rather than
`deploy` for one day, August 24 to 25, 2026, and `change` for the four days before that; every wording it
has ever carried is still read, so an entry below written under any of them is parsed exactly as it always
was — including the four written under `PR`, which are in the list below right now. Entries written
before August 23, 2026 carry that first answer under a `###` question of its own with the second nested
at `####` beneath it; entries before August 16 carry the longer set of headings that shape replaced, and
every earlier shape is read exactly as it always was. Every release ever cut is listed in
[`releases/history.md`](releases/history.md) — each with its date, type and title, and a link to what that
release was worth. How the mechanism works (entry files, the Significance sections, folding) is described in
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

Each change declares its own **reach**, and per audience how much it **weighs** there — one `##### Tier N`
sub-section per tier where a repo writes them numbered, each closing with its score; here the audience tier
carries a named heading beside the others instead. This list does not order on it: it is a record of what
landed, so it reads in the order things landed. What the declaration decides is what the **release
documents** lead with — they rank themselves on it — and what may be released at all, because **the bump
follows the highest tier pending**: **tier 0 only earns a patch**, **tier 1 or higher earns a minor**, and
a **major** recaps ten minors. So a changelog holding nothing but tier 0 is a patch waiting to be cut, not
a release with nobody to announce it to.

**The line directly under `## [Unreleased]` is a tally, and nobody types it.** It reads
`**4 / 9 minor entries**`: how many of the pending entries reach the audience this repo publishes to, out of
how many are waiting for the next release, and which bump that work has earned. The two numbers answer
different questions and may differ — the fraction counts tier 2 and above, the bump follows tier 1 and
above — so `**0 / 8 minor entries**` says nothing reaches a subscriber while the version still owes a minor
for what reaches management. It is
**derived from the entries below it every time it is written**, by the fold that adds one and the cut that
removes them all, so it holds no state of its own and a hand-edited count is simply corrected on the next
fold. It ends with an HTML comment that marks it as machine-written; that marker is what the next run
replaces, so anything else written in this space is left alone.

---

## [Unreleased]

**7 / 8 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2064-prerequisite-branch-signal · 20260917-160011

`claim-issue` now asks a sixth question at pickup, and it is the first one that is not about
ownership: **is a surfaced branch in my way rather than racing me?** Where the parked-fix or
title-overlap scan names a branch, the step weighs it -- how far ahead of the trunk it is -- and holds
the paths the issue's own text cites against the trunk. A path that is **absent from the trunk and
present on that branch** reaches its own verdict: *PREREQUISITE, NOT A COMPETITOR*, with the ordering
handed to the owner.

The five signals before it all answer *is somebody mid-flight on this work?*, which is why the
strongest ends in *ASK THEM BEFORE YOU WRITE ANYTHING*. Measured on the #2051 pickup (#2064): that
verdict fired on `origin/fix/2048-closeout-repair-strategy`, and reading settled it -- the commit
merely *mentioned* #2051 because it had filed it. What nothing named was that #2051's subject,
`scripts/maintenance/measure-closeouts.ps1`, existed only on that branch, so every route to the issue
ran through it landing first. No other check can see that: `triage-inbound`'s *subject does not exist*
is about a name that names nothing, while a subject on an unmerged branch greps, opens and has
history -- present to every check, and blocking the work exactly as hard as absence.

Three endings, deliberately not two. A prerequisite found; every cited path already on the trunk; or a
body citing no path at all, where the overlap question was never asked. Printing *not a dependency*
where nothing was tested is the failure this signal exists to remove, one layer in.

Advisory, like every signal in this family -- a claim that blocks costs the whole assignment (#1485).
What it does change is the closing line: where both verdicts fire the headline names **both**, because
they are different questions and naming one sends the reader to the block that settles the other.

Free on an ordinary claim: nothing surfaced, no git call made. Where something was surfaced the bill is
one `rev-list` per branch plus **one** `ls-tree` on the trunk carrying every cited path at once -- the
per-branch read runs only for the paths the trunk turned out to lack, which is normally none. Weights
are measured against `origin/<trunk>` where it exists, because a local trunk sitting behind origin
reports landed commits as unlanded and inflates a branch in the one direction this must not err.

Noticed the first time a pickup lands behind somebody else's branch, which is the day it saves the
whole detour.

**Score:** 3

#### What makes this deploy extra special

It is the first pickup signal that answers a question the others were not asking. The five before it
add evidence on one axis -- who else is working this -- and #2064's cost was a verdict that was
*correct on that axis* and pointed at the wrong question: the reader spent the time working out why
the branch mattered, from a block that had already told them to ask about ownership. Widening an
existing verdict would have made weaker evidence share a headline with stronger, which #2018 refused
by name one signal earlier; a second question gets its own block and its own hedges instead.

The issue body is read for the first time here, and it is read as **data**: bounded to path-shaped
tokens with a directory and an extension, URLs stripped first, nothing absolute, no `..`, no
option-shaped token, and none of it printed verbatim. Anybody who can open an issue writes that text,
and it now reaches a git argument list.

**Score:** 2

#### Pull Request

A surfaced branch is weighed, so a prerequisite is not read as a competitor

Plugins: dkj-policy

[PR #2071](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2071)

---

### DEPLOY: feat/2051-mirror-closeout-instrument · 20260917-154400

The close-out instrument now ships to the consumers it measures worst. `measure-closeouts.ps1` landed
in #2048 as a source-repo maintenance script, which was the wrong way round for what it measures: per
repo, close-outs over the three-line ceiling ran `smartwatchbanden` 97%, `xoxowildhearts` 88%,
`claude-code-specialists` 86%, `thumbnail-generator` 67% -- and the repo that owns the instrument is
its best performer at 50%. The two worst were consumers who could not run it, and every close-out
complaint on the record came from a consumer.

It is registered, mirrored byte-identically into `dkj-policy`, and documented by its own
`measure-closeouts` skill page rather than filed under `measure-skill`'s, whose subject is what a skill
costs in tokens. Two things the mirror needed came with it: the source-repo guard, so a stale cached
copy is refused instead of reporting a plausible number, and a baseline that lands in the consumer's
own repo rather than in the plugin cache the next update replaces.

**Score:** 3

#### What makes this deploy extra special

A consumer of this workflow gains an instrument they could not run before, and it needs nothing
configured: it reads `~/.claude/projects` rather than the repo, is read-only, always exits 0, and only
counts leave it -- no transcript content -- so it is safe in a repo whose measurements are published
while its sessions stay private. It costs one more always-on skill description in every session that
enables `dkj-policy`, which was weighed and accepted rather than discovered.

**Score:** 3

#### Pull Request

The close-out instrument ships to the consumers whose rates are worst

Plugins: dkj-policy

[PR #2063](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2063)

---

### DEPLOY: feat/2050-closeout-gate · 20260917-151732

Step 6 of the ritual now has a gate instead of a seventh piece of advice. A Stop hook refuses a
close-out over this repo's band and asks for it again, once per work chain; every other turn, and
every repo that has not answered the new seam, is untouched.

**Score:** 3

#### What makes this deploy extra special

Six repairs to the close-out are on the record and all six were advice. #2048 built the instrument and
measured the baseline none of them had ever been argued against -- 84% of close-outs over the stated
ceiling, which means the rule had never been in force anywhere. This is the first one that can be
measured rather than judged by whether a complaint arrives.

It also reverses a written doctrine, narrowly: `cycle-autopark.ps1` says a Stop hook never blocks, and
that stays true of `cycle-autopark`. The exception is bounded to a measured over-run on a turn that
ended a work chain in a repo that opted in by name.

**Score:** 2

#### Pull Request

A close-out gate: a Stop hook that blocks a receipt over the band

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2065](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2065)

---

### DEPLOY: fix/2055-preview-theme-name-length · 20260917-150335

`Get-RepoPreviewThemeName` now bounds a branch's preview theme name to Shopify's 50-character
ceiling (inbound #2055). A branch name long enough to compose past it used to reach the platform and
come back as `Name is too long (maximum is 50 characters)` -- after the run had already announced
which theme it was creating, so the push read as half-done. A name that FITS is returned unchanged,
so every preview theme that exists today keeps its name and stays findable; only an over-long one is
rewritten, as `<prefix><truncated branch part>-<6 hex of SHA256(the full name)>`.

The bound belongs in the shared builder rather than at the caller because three call sites compose
this name and all three have to agree on one string: `push-preview.ps1` creates the theme, and
`sweep-preview-themes.ps1` composes it again -- once for the current branch and once for every branch
still alive -- in order to SPARE it. A ceiling applied outside the builder would leave the sweep
composing a name it no longer recognises as spared, which is silent and destructive.

The discriminator is not decoration: plain truncation maps every branch sharing a long enough head
onto one theme name, so two branches would push over each other onto a preview that looks correct
from both.

A consumer whose branch names run long cannot create a preview theme at all today; everyone else sees
no change, because a name that fits is untouched. Noticed the moment that consumer pushes.

**Score:** 3

#### What makes this deploy extra special

It closes the class rather than the instance. `Get-RepoPreviewThemeName` already refused a name
illegal at the CLI -- a `/` in it -- and its own docstring named that as its job; the length ceiling
is the same kind of rule from the same vendor, and it was the one case the function did not cover.

**Score:** 2

#### Pull Request

Get-RepoPreviewThemeName bounds the theme name to Shopify's 50-character limit

Plugins: dkj-subagents-shopify

[PR #2059](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2059)

---

### DEPLOY: fix/2048-closeout-repair-strategy · 20260917-143821

The close-out ceiling is now measured instead of argued about. `measure-closeouts.ps1` reads this
machine's recorded sessions and reports how the close-out actually behaved, separating the two
populations that matter -- every session's final message, and the close-outs that follow a
chain-ending script, which is the set the ceiling governs and the only set a verdict may be read off.

It answers the question inbound #2048 called open and real. Over 328 sessions, 263 of them real
close-outs: **84% exceed the three-line ceiling, 56% exceed even six, and the median is seven.** So the
rule has never been in force anywhere -- five complaints are five of two hundred and twenty-two -- and
every previous repair was advice against a baseline nobody had counted, evaluated by waiting for the
next complaint. That is a sample of one, which cannot tell a repair that worked from one that did not,
and it is the mechanism behind the pattern the report identified.

It also settles the report's leading hypothesis, that the trigger is volume of work: measured,
`r = 0.207` over n=263 -- real, about 4% of the variance, and not the cause, because the smallest
quarter of sessions already averages 5.8 lines against a ceiling of 3.

Nothing about what the close-out print says was changed, deliberately. The finding is about how
repairs are evaluated, and the instrument plus its recorded baseline is what lets the next change here
be shown to have done something.

**Score:** 4

#### What makes this deploy extra special

N/A -- this repo's audience tier is the developers maintaining it. The instrument reads session
transcripts on the machine it runs on and ships to no consumer in this change.

**Score:** N/A

#### Pull Request

The close-out repair strategy, investigated across five recurrences

Plugins: dkj-policy

[PR #2057](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2057)

---

### DEPLOY: fix/2049-asana-block-before-close · 20260917-125439

`dkj-policy-bwj` reverses the order of its Asana notification: the paste-ready block is written by the
session that shipped the work, while the issue is still **open**, and closing the issue is a person's
confirmation that the block reached Asana. It is gated on the issue having a linked Asana task rather
than on the `CRO` label, which was narrower than the need. `asana-mirror` still writes a block on the
`closed` event, but only where no block is already there -- it is the backstop now, not the route.

The old order could not be repaired in place. Its comment appeared underneath an item that had just
left every open-issue view; a missed event was never detected afterwards; and the link inside it was a
placeholder that CI cannot fill, because "where the result can be viewed" depends on what the ticket
was about. The session that built the thing is the one party that knows that link.

**Score:** 2

#### What makes this deploy extra special

A store repo running `dkj-policy-bwj` has to act, in two places. Re-copy `templates/asana-mirror.ps1`
into `.github/scripts/` -- an install writes nothing into a repo -- or the old CRO-gated comment keeps
running. And ship an Asana-linked issue with `-NoResolves` from now on: a `Closes #<n>` has GitHub
close the issue at the merge, before anybody has written a block and with nobody's confirmation, which
bypasses the whole rule silently.

In exchange the requester stops being told where to look by a comment nobody reads, on a ticket
nobody reopens, with the link still reading `[ADD LINK]`.

**Score:** 5

#### Pull Request

The paste-ready Asana block is written before the issue closes, by the session that shipped it

Plugins: dkj-policy, dkj-policy-bwj

[PR #2053](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2053)

---

### DEPLOY: fix/2043-closeout-fillable-template · 20260917-103912

The close-out reminder the chain-ending scripts print now hands over a line to fill in rather than
describing the shape to compose: `<what happened> -- see PR #1885. [Filed #<n>.] Session can be
cleared.`, with the citation slot already answered from the run's own knowledge. The three parts, the
ceiling and the rehousing rule are unchanged; only the delivery is.

It is the fifth repair of a rule that keeps losing, and the first taken after verifying that the
previous one was in force and still lost. Inbound #2043 asked for the print to be moved last -- it was
already last, the final statement of `ship-pr.ps1`. What put ~35 lines under it was the child
processes' output arriving after the parent's, which no placement can fix and whose cause does not
reproduce in this repo -- filed on its own as #2044. That **retires** the placement repair without
arguing for this one: a template printed in a buried position is exactly as buried as prose was, so
this change does not repair the ordering and is not offered as doing so. What it stands on is the
report's other argument, independent of where the line lands -- **a shape that is described has to be
composed, and a shape that is handed over has to be filled.** The general lesson banked alongside it is
that **last in the file is not last on the screen**.

**Score:** 3

#### What makes this deploy extra special

Every repo running this workflow gets the new line at every `open-pr`, `ship-pr`, `park-branch`,
`fold-changelog-entry` and `cut-release`, on its next plugin update. Nothing to do and nothing breaks
-- the parameters, the suppression and the bypass clause are untouched -- but what a session reads at
the end of every chain changes wording.

**Score:** 3

#### Pull Request

The close-out receipt hands over a fillable template instead of describing one

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2047](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2047)

---

### DEPLOY: fix/2044-child-output-to-host · 20260917-091623

A child process's narration could arrive after everything its parent printed, so where a line was placed
stopped predicting where it was read. `ship-pr.ps1`, `cut-release.ps1` and `verify-pushed-merges.ps1`
each started their children with `& powershell`, which hands the child's stdout to the parent script's
**success stream** -- its return value -- while the parent's own `Write-Host` narration goes to the
information stream. The two reach one console in printed order only while nothing consumes the success
stream; pipe such a run, capture it, or `Tee-Object` it, and the narration prints live while every
child is collected and replayed at the end. The output is not scrambled, which is what made it hard to
read as a defect: it is every parent line in file order, then every child line in file order.

All five narrating spawns across the three scripts now route through `| Out-Host`, which keeps the
child's text with the narration and leaves the success stream empty -- where a child's console output
never belonged. `$LASTEXITCODE` is unaffected, and `2>&1` is deliberately not used.

The repair went further than #2044 asked. The issue named `ship-pr.ps1` alone and expected to need three
consumer-side facts before anything could change; none was needed, because the reproduction it had
already written only had to be run through a pipe. Going looking then found the same defect in two
sibling scripts it had not reported. `../scripts/tests/ordering-passthrough.tests.ps1` pins both halves:
that the defect is real, and that no narrating spawn in either copy of `scripts/release/` is left
unrouted.

**Score:** 3

#### What makes this deploy extra special

A consumer is where this was measured -- a ship whose output arrives grouped rather than interleaved
costs a debugging session to explain, and #2044 was filed only after a second issue had already been
misdiagnosed from the resulting screen order. Consumers running a ship in a foreground shell see no
change at all; those who pipe, capture or background one get output they can read in order again.
Conditional reach is why this is not scored higher: nothing was blocked, and the workflow no longer
depends on placement anyway.

**Score:** 2

#### Pull Request

A child process's output no longer lands after everything the parent printed

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2046](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2046)

---

