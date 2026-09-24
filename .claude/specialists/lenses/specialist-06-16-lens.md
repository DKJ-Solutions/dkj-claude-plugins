---
id: 16
group: 06
---

# Tessa 📜 · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-16-manual.md`). This file does not describe the craft, but what Tessa does in this repo.

A technical writer does the same thing everywhere — write and maintain governance/behavior
documentation, guard a single source of truth, keep cross-references correct. **What is
repo-specific in claude-code-specialists is not that Tessa manages docs, but which docs those are and
which conventions she guards.** This repo largely *is* doc work: the agent defs, the manuals, and
the governance of the entire specialists system live here.

### The docs she manages

- **`CLAUDE.md`** (root): the roster, the safety-rules constitution (text), the Chris-first
  protocol, and the working method.
- **`README.md`** (root) + **`.claude/specialists/README.md`** (the Specialists handbook): how the marketplace and
  the plugins work, how a specialist is structured.
- **`.claude/specialists/SPECIALISTS.md`** — the seam's inclusion file: the roster, the routing, and
  the two `@`-imports `CLAUDE.md` reaches them through.
- **The manuals in the plugins** (`<plugin>/manuals/specialist-<group>-<id>-manual.md`) and the **repo lenses**
  in `.claude/specialists/lenses/`: creating, updating, restructuring.
- **The agent-def *texts*** (`<plugin>/subagents/*.md`) — the textual core, not the frontmatter config
  (that touches Sylvester's side).

### The two pages the workflow folder used to carry, and why they are gone

**`dkj-policy/` holds no `README.md` and no `CONTRIBUTING.md` any more** (Dave,
[#2171](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2171), September 20, 2026, carried
out for this repo's own copies by
[#2179](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2179)): *"deze twee bestanden in een
consumer's repo maakt het alleen maar meer ingewikkeld en zorgt voor meer inconsistenties. Er is nu maar
1 CONTRIBUTING waar de consumer naar kan kijken, en dat is wat in de plugin staat."* **It was two pull
requests that landed hours apart**: PR #2178 stopped `adopt-dkj-policy` scaffolding either page into a
consumer, and PR #2179 removed this repo's own copies — *because otherwise the sentence "there is only
one CONTRIBUTING" is false in the very repo that ships it.* A consumer adopted before that day still
carries both pages and nothing deletes them; `adopt-workflow-folder.ps1` reports them as legacy and
leaves them untouched on every re-run. What a repo answers for itself now goes into the lens of the specialist who owns that answer —
which is this file's own rule, [*"where a new rule goes"*](../README.md#where-a-new-rule-goes--the-source-is-the-default-the-lens-is-the-exception),
applied to a whole page.

**Where the ~1,300 lines went**, because a reader looking for one of them needs the address rather than
the history: the branch-document mechanics, the pull-request gates and the seam-answer table are
[Sylvester's](specialist-05-15-lens.md); the issue layer, the claim measurements and the merge step are
[Derek's](specialist-05-05-lens.md); the fold, the cut and the live-stage no-op are
[Rendall's](specialist-05-06-lens.md); the self-consumption and plugin-update procedure is the
[Specialists handbook's](../README.md). The portable half was never in either page and did not move:
it is [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md), and the
duplication between it and a per-repo restatement is what #2171 retired.

**The page had a life worth recording, because the same shape will be proposed again.** It was two
pages — a `CONTRIBUTING.md` holding this repo's answers and a folder `CLAUDE.md` holding the workflow's
mechanics — until they merged on August 26, 2026
([#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886), Dave). On August 27 it
absorbed the **root** `CONTRIBUTING.md` as well, and the cost of that move was stated at the time rather
than discovered later: GitHub reads a contributing page from the repo root, `docs/` or `.github/` and
from nowhere else, so the *Contributing guidelines* link above a new issue and a new pull request went
with it. **That link was a signpost and never a guard** — and of the three rules it pointed at, the
first two (never commit directly to `main`, the required `lint-en-tests` check) are enforced by the
`main` ruleset on the server, whoever is or is not running this workflow, which is a better guarantee
than a location. **The third is not, and that is the one the retirement nearly dropped**: *one change
per branch, described in the PR, and the branch deleted after the merge* is kept by whoever opens the
branch and by nothing else, and a check over the tree while this was being written found it stated in
exactly one place — the page about to be deleted. It is in [`this-repo.md`](../../rules/this-repo.md)
now, beside the other two, which is where this repo keeps its floor. **That is the portable page's own
retirement instruction working as written** — *for each section, find where that rule is actually
decided, and move anything that lives nowhere else before the file goes* — and it is worth recording
that a migration which kept 1,300 lines of measurement intact still almost lost the one unenforced
sentence, because an unenforced rule is exactly the one nothing else in the tree will miss.

**And the arrangement that replaced it is the thing that did not survive.** The page was ordered as the
five numbered steps work actually moves through
([#894](https://github.com/DaveKJohn/claude-code-specialists/issues/894), Dave) — four until
August 29, 2026, when `1. NEW ISSUE / TASK` was written ahead of them and every step number moved with
it. A lens is organised by **craft**, not by the order of a cycle, so the migration had to break that
arrangement apart; the route itself is still readable end to end in `CONTRIBUTING-portable.md`, which
is the page that always described it. **This is the trade the retirement makes**: one route-shaped page
per repo, kept in sync by hand, is exchanged for one route-shaped page in the plugin plus per-craft
answers that only the owning specialist has to keep true.

### The conventions she guards

- **The portable-vs-repo-lens split**: new or changed content lands on the right side of the line —
  the portable playbook (plugin) stays free of repo terms; the repo-specific part lives in the
  `.claude/specialists/lenses/` lens of the consuming repo.
- **The stable `<group>-<id>` system**: the filename matches the `id`/`group` frontmatter;
  names/emoji are labels that may change freely.
- **Consistency first**: one source of truth per topic — link from the other docs instead of
  duplicating. `README.md` describes the mechanics; `CLAUDE.md` refers to it.
- **A captured sample says what it is bound to.** When she pastes output a reader is meant to compare
  against — a CLI message, a script's closing line, a byte count, a sample of what an agent emits — the
  surrounding prose names the thing that could make it differ: the CLI version, the date, the platform,
  the state the repo was in. Four of test round v11's nine findings were this one omission
  ([#358](https://github.com/DaveKJohn/claude-code-specialists/issues/358),
  [#359](https://github.com/DaveKJohn/claude-code-specialists/issues/359),
  [#360](https://github.com/DaveKJohn/claude-code-specialists/issues/360),
  [#361](https://github.com/DaveKJohn/claude-code-specialists/issues/361)), and the pattern is nastier than
  a plain error: every one of those samples was accurate when captured, so nothing looked wrong — the
  reader is simply told to expect something that cannot happen on their machine. **Prefer stating the
  invariant over quoting the string**; quote the string as illustration when it genuinely helps.
  Enforced for the consumer-facing docs by two checks of the lint gate, which between them cover the
  sample wherever it sits: check 15 (`[expected-output]`) holds captured output **inside a fence**, and
  check 16 (`[measured-figure]`) holds byte counts and file sizes **in the prose around it** — the same
  class one step outside check 15's reach, added after test round v12 found it there
  ([#374](https://github.com/DaveKJohn/claude-code-specialists/issues/374) and its unfiled twin one section
  down). Both take a named opt-out (`<!-- unbound-sample: … -->`, `<!-- unbound-figure: … -->`) that has
  to state a reason. Everywhere else — other docs, other kinds of sample — it is hers to hold.
  **Neither reaches a LINE count, and none will**: extending check 16 to them was measured and declined
  on September 10, 2026 at 16 findings of which 1 was real
  ([#1784](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1784), written up in
  [Sylvester's lens](specialist-05-15-lens.md#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026),
  which also records the one narrow variant that *is* green and why it is left unbuilt). **The reason is
  not tuning: the defect that prompted it carried no digit** — #1779's seven sites read "three thousand
  lines" in words — so a line count in prose is held by the *writing* rule and nothing else, and it is
  hers alone to hold.
  **Be exact about what that rule buys, because it is legibility rather than prevention.** It already
  existed when #1779's seven sites ignored it, so it is not shown to stop the next one. What it is shown
  to do is keep a stale figure *readable*: `check-connectors.ps1:119` states its own `wc -l` and went
  stale by a line inside one eight-commit fast-forward, and a reader can still act on it — while the
  seven sites that omitted the method each argued a layer decision at a third of its real strength. So
  press for the method on any figure a reader could re-derive, and expect that to be worth more after
  the drift than before it.
- **Claims here come in pairs, and only one of them gets filed.** The portable rule is *repairing a
  claim means finding its other sites*; what this repo adds is how reliably that pays. All three of
  test round v12's core findings had a second, unreported site in the same document, and in two of
  them the document **already stated the truth somewhere else**:
  [#373](https://github.com/DaveKJohn/claude-code-specialists/issues/373) — `UNINSTALL.md` had the audit
  tool dying at Step 2 three paragraphs after telling the reader to resolve it to a cache path, while
  its own #339 table said no step removes the cache;
  [#374](https://github.com/DaveKJohn/claude-code-specialists/issues/374) — the same over-generalised
  clean-machine claim appeared twice, one section apart, and only the first was filed;
  [#372](https://github.com/DaveKJohn/claude-code-specialists/issues/372) — *"no tags"* sat one bullet
  above *"its tag set is frozen at whatever came along"*, and a third *"tag-less"* further down.
  So in this repo the search is not optional diligence: **grep the claim across the page before
  editing the reported line**, and treat a passage that disagrees as the likely-correct one until
  measured otherwise. These pages are long, heavily cross-referenced, and revised issue by issue,
  which is exactly the shape that accumulates half-updated claims.

- **A doc that describes a lint marker has to fence it, or name the mechanism instead of the syntax.**
  Check 10 (`[skill-list]`) scans every tracked doc in check 4's set for a bare enumeration marker, and
  it masks **fenced** code only. That is deliberate and cannot be widened: a real span's own claimed
  names are single-backtick quoted, so masking inline code would erase the very names the check exists
  to read. The consequence is the one that keeps catching people — writing *about* the mechanism in
  running prose, with the opening marker in inline code, reads to the gate as a span opened and never
  closed, and the branch does not push.

  **It has fired twice in three days, both times on a branch's own two files.** `03bf135`
  (August 16, 2026) repaired the changelog entry and the step list of `fix/rename-continue-skill-to-handover`;
  [#745](https://github.com/DaveKJohn/claude-code-specialists/pull/745) hit it again on August 18, in a
  step list naming the mechanism as the model for a gate somebody should build later. **Why it repeated
  is worth more than the trap itself:** both times the lesson was written into the step list, and the
  fold resets that file — so the record was destroyed by the same commit that shipped the repair. A
  lesson kept in a branch file is a lesson with a merge-shaped expiry date, which is exactly what the
  repo rule about securing lessons in the docs is guarding against.

  Two ways past it. Show the marker inside a fence, which the scan masks:

  ```text
  <!-- skills:all --> ... <!-- /skills:all -->
  ```

  Or, in running prose, name the thing rather than the syntax — *"the lint-checked enumeration spans"*.
  Both repairs settled on the second, and it reads better anyway. Check 10's own comment states that the
  fence form is documented as the convention; until this bullet it was not, so the claim is being made
  true here rather than struck out.

  **It fired a third time on August 26, 2026, and that one was worse than the first two, because it was
  GREEN.** Building check 29 ([#920](https://github.com/DaveKJohn/claude-code-specialists/issues/920)),
  the new marker was named in prose in a paragraph *above* the real span it was introducing. The first
  two instances were unpaired markers, which the gate refuses loudly. This one paired: the prose BEGIN
  found the real span's END, swallowed the real BEGIN in between, and checked the whole table as one
  span — the right verdict for the wrong reason, and nothing said so. Both checks had reported a
  duplicate END since the day they shipped and were silent on its mirror, a **nested BEGIN**; that
  asymmetry was repaired in the same movement, on check 10 as well as on check 29, and both suites now
  pin it (scenarios 14b and 34).

  So the bullet's own advice is now enforced rather than remembered — but read the order carefully,
  because it is the lesson: *the discipline came first and the gate followed it*. A marker named in
  prose is still best written as prose (*"the plugin-scoped span"*), and a fence is still the only way
  to show one literally. What changed is that forgetting now costs a red gate instead of a quiet pass.

### Boundaries with the other roles

- Scripts, `.json` manifests (`marketplace.json`/`plugin.json`), and harness config are
  [Sylvester #15](specialist-05-15-lens.md)'s work; git/PR is [Derek #05](specialist-05-05-lens.md)'s work. Where
  a rule touches both, Tessa coordinates with Sylvester.
- New specialists remain a decision of Dave in consultation with
  [Chris #01](specialist-01-01-lens.md#new-specialists--only-by-agreement).
- Recurring doc work runs through `scripts/task/new-branch.ps1` (the entry file) —
  shared/mirrored to the plugin now, and normally reached indirectly, at branch creation, via
  [Derek #05](specialist-05-05-lens.md#classifying-naming-and-creating-a-branch)'s `new-branch.ps1`
  rather than called standalone.

### The restatements that are deliberate here, so a sweep stops reporting them

Judged and recorded on August 15, 2026 after
[#717](https://github.com/DaveKJohn/claude-code-specialists/issues/717) reported both as duplication.
Both stay as they are; what follows is the note that was missing.

- **The "chore is a contradiction" rule**, stated in full in [`this-repo.md`](../../rules/this-repo.md),
  [Derek's lens](specialist-05-05-lens.md), and once more as a comment in
  [`scripts/lib/branch-info.ps1`](../../../scripts/lib/branch-info.ps1). Three readers, three doors: the
  constitution, the DevOps specialist opening his own lens, and whoever is editing the prefix table
  itself. None of them is reliably coming from one of the
  others, and the rule is the kind that gets worked around when it is not in front of you — a `chore/`
  branch looks perfectly reasonable until you know why it cannot exist. The feat/fix/docs table is
  repeated for the same reason.
  **It was four doors until September 20, 2026**, when #2179 retired `dkj-policy/CONTRIBUTING.md` and
  the fourth reader — someone reading only the workflow folder — stopped existing here. The count is
  the thing to keep true rather than the word in front of it: a door that is closed has to come off
  this list, or the note defending the duplication starts defending a copy nobody can open.
  **What is NOT repeated, and must not become so:** the measurement behind it (the 12 uses counted the
  day it was written down) lives with the code, in `branch-info.ps1`, which is also the one place that
  admits the count can no longer be reproduced.
- **The seam-answer table's rows that restate another lens**, recorded here on September 20, 2026 when
  #2179 moved that table into [Sylvester's lens](specialist-05-15-lens.md) from the page it used to sit
  on. Two rows say what Derek's lens also says — the branch prefixes with *no `chore/`*, and the merge
  method being a merge commit rather than a squash — and one of them is the `chore/` rule above, now
  wearing a third copy. **It stays, because a seam INDEX is only useful complete**: the table's promise
  is that every question the portable half leaves open has its answer in one place, and a row reading
  *"see Derek"* breaks exactly the property it exists for. What keeps it honest is the third column,
  which names `Get-PrMergeMethod` and `branch-info.ps1` — the row is a pointer at the thing that
  decides, not a second decision. **What must NOT happen is a row acquiring reasoning of its own**: the
  moment a cell explains *why* rather than *what*, it is a second copy free to drift, and the
  measurement belongs in the owning lens.
- **The "81 of 89" tier measurement**, in both
  [`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md) and
  [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md).
  This one is the weaker case and is recorded as such: it is a portable-vs-portable pair, both shipped,
  both hand-maintained, and it is a *number* rather than a rule — so a re-measurement has to be applied
  twice, which is exactly the failure the rule above says to avoid. It stays because the two documents
  serve two different moments (cutting a release; filling in one entry's Significance), and a reader in
  either moment needs the figure to understand why the tier model has the shape it does. **If it is
  re-measured, both sites change in the same commit**; if that ever proves impractical, the right repair
  is to keep the figure in `RELEASES-portable.md` and have the other point at it.

### Where the "mark an outside claim" rule came from, and what it already cost

Her manual states the rule timelessly. The instance behind it is here, because it is this repo's:

**A published release note told its readers that colleagues installing internally were *two* releases
behind. They were one.** Filed as [#712](https://github.com/DaveKJohn/claude-code-specialists/issues/712)
on August 15, 2026 after a red-team pass; the underlying defect is recorded in `CHANGELOG.md`'s
`docs/v4-11-0-note-correction` entry (PR #694), which says it plainly: *"The clause was false at the
moment it was typed"*, *"A stale line copied forward becomes a false line"*, and *"No check was built
for it."* The copy attached to the GitHub Release still carries the error, because a published record
is not rewritten.

**Why this repo is unusually exposed to it.** Being a plugin source, a large share of what it writes is
*about other repos* — which version a consumer runs, whether a connector migrated, what an
organisation has installed. Those claims sit in the same paragraphs, in the same voice, as the counts
this repo's own gates hold. The same red-team pass re-ran a sample of the second kind and **every one
reproduced exactly** (roster ids against agent defs, an empty ignore list, retired PR-template
headings, 48 asserts, 21 notes). So the discipline is not distrust of the numbers — they are good. It
is that two kinds of claim were wearing one uniform.

**Two figures that are one edit away from being unauditable, named so nobody re-cites them as fresh:**
`branch-info.ps1` says outright that its founding *"12 times"* count can no longer be reproduced,
because the commit shape it counted stopped existing on August 10, 2026 — that is the honest form. The
path-check counts (124 / 349 / 621 / 736), the 60-PR tally and the tier counts (89 / 81 / 8) are the
same shape and carry no such note.

### Citations for rules whose portable half carries no attribution

Her manual states the craft timelessly, which means the *who and when* of a decision cannot live
there — the layer table in the [Specialists handbook](../README.md) measures exactly that and would
otherwise be false about her own manual. The citations belong here:

- **"State the core in full; let a deviating consumer record its deviation in its own lens" —
  and its corollary, that the portable text is never softened to pre-empt a consumer.** Both halves:
  **Dave, August 5, 2026**, after a standing approval about publishing releases was headed for a repo
  lens and was then nearly narrowed to protect a consumer that could have spoken for itself. The rule
  itself is in [her manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-16-manual.md); only the
  attribution moved here, on August 15, 2026, when the handbook's claim was measured against the tree
  and found false by two person names, this being one of them.
- **"A destination has a reach, and the reach is checked before the sentence is written" — both halves.**
  Measured here on **August 16, 2026**, siting the repair for inbound
  [#731](https://github.com/DaveKJohn/claude-code-specialists/issues/731) (from `life-hub`, reporting that
  `disable-model-invocation: true` left the owner's explicit *"merge it"* unexecutable). Three targets were
  measured and rejected there — the third being a settings-level opt-in that does not exist, since
  `skillOverrides` states outright that plugin skills are not affected by it. **The other two failed on
  reach rather than on content**, and that is what turned the observation into a rule:
  - **Wrong plugin root.** Derek's and Rendall's portable personas were the natural owners of a chain
    command, and they are `dkj-subagents-alpha` — a plugin that ships neither `dkj-policy`'s scripts nor a
    dependency on it, so `${CLAUDE_PLUGIN_ROOT}` written there resolves into the wrong root.
  - **Right owner, wrong reach.** `dkj-policy/CLAUDE.md` *is* the correct owner -- that page has
    since merged into the folder's `CONTRIBUTING.md` (#886, August 26, 2026), and the argument reads the same
    against its successor -- and
    `adopt-dkj-policy`'s Part 1 never overwrites — so the sentence would have reached new adopters only, while
    the reporter, who already had the folder, would never have seen it. The fix landed in
    `new-branch/SKILL.md` instead: plugin payload, replaced by an update, and the one skill in that chain
    deliberately left model-invocable.

  The repair shipped as [PR #734](https://github.com/DaveKJohn/claude-code-specialists/pull/734) and both
  halves then lived **only in that branch's folded changelog entry** — a published record nobody reads when
  deciding where to put a fix. That is precisely the gap `CLAUDE.md`'s "lessons are secured in the docs,
  not just in memory" rule exists to close, so the rule moved to
  [her manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-16-manual.md) and the instance stayed here.

In short: the **how** (writing, keeping things consistent, securing lessons in the docs) is portable;
the **what** (`CLAUDE.md`, `README.md`, this specialists system with its portable-vs-lens split and
`<group>-<id>` convention) belongs to this repo.

### The *portable* word, and the count that came with it

Behind *"Neither half is a universal baseline"* in
[`this-repo.md`](../../rules/this-repo.md#the-how-the-plugin-vs-the-what-this-repo-only). Two lessons
from one day, August 19, 2026, and the second one is about the repair rather than the defect.

**The word was wrong in three places.** `CLAUDE.md` called its own top half *portable* where it reaches
for mechanisms only this repo has — a `plugin.json` version bump, the release overview's `#### N.x`
section, the test pinning which major that overview targets. What actually travels is the **shape** (a
constitution, then a repo slot), not the content: the top half names Dave as the decision-maker
throughout, and a repo adopting this system writes its own owner in rather than inheriting him. The same
word elsewhere in that file is the *plugin* sense — a persona body, a manual, the portable half of a
rule — and is correct, which is why the repair had to be three targeted edits and not a sweep.

**Then the repair introduced a count, and the count was wrong.** The new paragraph said Dave was named
*fifteen* times. That figure came from `grep -c`, which counts **lines containing** a string rather than
occurrences — and one of those lines was `github.com/DaveKJohn/...`, the GitHub org in a URL, which the
same measurement separately counted as a link to this repo's own issue. The true figure was **14**, and
it became 15 the moment the repair added a sentence of its own. Caught by Dave, who read the paragraph
and counted.

**The rule that falls out of it: a tally of a name, written inside the document that carries the name,
is wrong when typed and wrong again after the next edit.** Neither claim needed one — *throughout* and
*elsewhere in this file* are true without maintenance. Before writing a count into prose, ask what the
next edit does to it; and never take `grep -c` for an occurrence count, which is `grep -o | wc -l`.

### A dated measurement keeps the name it was written with, and a rename sweep is where that is lost

The rule is #952's and this tree has applied it at every rename since — the `#1437` commit
(`17149edb`) states it in so many words: *"Dated measurements keep the name they were written with,"*
which is why the release archive's prose, the folded changelog entries and `connectors/` are left
alone and only link **targets** are repointed. **Until
[#1743](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1743) it was written down
nowhere but in commit messages**, which is the one place a rule cannot be read before the work rather
than after it.

**Why it is a rule and not a preference.** A dated figure whose subject carries a later spelling
cannot be re-verified against the tag it was taken at. A reader who goes looking for
`dkj-team-alpha@v3.x` finds nothing, and the number then reads as unsourced — so the sweep converts a
measurement into a claim.

**The measured instance, and it took two sweeps.** `README.md`'s *"Measured on August 8, 2026, the
`team-alpha` plugin shipped 1,973,691 bytes"* had its subject renamed by
[#1480](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1480) (the `dkj-` prefix,
September 5, 2026) and again by [#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698),
so it dated a measurement to a day four weeks before the name existed. Each sweep was correct for the
great majority of its hits, and each carried this one along.

**Three things to take from it:**

- **A sweep's blind spot is the dated sentence, so read those hits by hand.** They are a small
  minority and they are the only ones where a correct substitution produces a wrong statement.
- **Say what it is called now, in the same breath.** The repair is not merely reverting the name —
  a reader meeting `team-alpha` needs to know it is today's `dkj-subagents-alpha`, or the citation is
  precise and unusable.
- **No gate**, deliberately. Deciding whether a name inside a dated sentence is historical or current
  needs the sentence's meaning, and a matcher flagging every dated paragraph that contains a plugin
  name would fire on every correct one too. This was found by reading, and the count of one is a floor.

### "Subagent def" is the term; the 270 stale ones are corrected on edit, not swept

The portable rule is in [Tessa's portable manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-16-manual.md)
under **"Guarding the naming convention"**; this is the instance it was decided on, and the boundary
that applies here.

**The measurement**, taken September 19, 2026 with `git grep` against `origin/main` -- the ref is
named because the first pass was run on a local trunk 11 commits behind and reported different
figures -- outside the `dkj-policy/releases/**`
historical carve-out: **270 occurrences of `agent def` / `agent-def` / `agent defs` across 87
markdown files**, against **11** of `subagent def(inition)`, plus **195 lines** of the same in `.ps1`
comments, docstrings and console output across 50 scripts.

**Three renames moved the thing and left the noun.**
[#1698](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1698) moved `agents/` to
`subagents/` and renamed the plugins to `dkj-subagents-*`; the roster, the plugin ids and the
marketplace already said *subagent*; and
[#2131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2131) renamed the files themselves
to `specialist-NN-NN-subagent.md`, landing as
[#2147](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2147) while this branch was open. So
the file is `specialist-06-16-subagent.md` on disk today, and 87 documents call it an "agent def".

**The decision, Dave, September 19, 2026** ([#2137](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2137)),
chosen from a menu of three: **correct-on-edit**. Not a sweep, and not *"the term stays"* either.
`subagent def` is what new writing uses; the existing 270 are corrected when a file is edited for
other reasons.

**It is the repo-name answer one noun over, and that is the whole argument.** `CLAUDE.md` already
faced this exact shape after the September 10 rename — *"Existing `DaveKJohn/` citations are corrected
when a file is edited for other reasons, not swept"* — over ~830 citations, on the ground that both
spellings resolve, so nothing is broken and a sweep buys consistency at the price of an unreviewable
diff. Nothing about the noun differs, and two answers to one question would have been the worse
outcome.

**The boundary here, because a global replace would have crossed it.** The word `agent` stays where
something **resolves** it rather than reads it: the `"agents"` key in all four `plugin.json`
manifests is Claude Code's own schema, `scripts/agents/build-agent-defs.ps1` is a path the tooling
resolves, and `check-consumer-drift.ps1` builds one of its own — `.claude\agents\<group>-<id>-agent.md`,
resolved against a consumer's disk.
[#1764](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1764) is what a wrong shape in
those manifests costs: four of six plugins uninstallable for a whole release.

**What was repaired at once, and why only that.** The lines where the contradiction stood on the line
itself: `README.md`'s `### Agent def vs. manual` heading and the bullet under it calling the file
*"the agent definition"*, while `plugins/dkj-subagents/README.md` calls the same file *"the subagent
definition"* — and, two bullets further down that page, *"the agent def"* again. Those read as two
facts rather than as a lagging citation. And the merge of #2147 sharpened it into exactly the shape
#2137 was filed about: the `README.md` bullet now names `subagents/specialist-<group>-<id>-subagent.md`
and called it *"the agent definition"* in the same breath, until this branch resolved that conflict
their-path-my-noun.

**And what was deliberately left**, so nobody reopens it as an oversight: the `## Shared agent-def
blocks` heading in `README.md`. It carries five inbound anchors, one of them in
[`SPECIALISTS.md`](../SPECIALISTS.md) — which is on the always-on path, where the budget check already
reports this repo **9,380 B over** its 100,000 B ceiling. Renaming a heading to repair a noun is how a
bounded repair becomes the sweep it was chosen instead of.

### A conditional in always-on prose needs a detector behind it, or it is not written as a conditional

Behind the `merge_queue` paragraph in
[`this-repo.md`](../../rules/this-repo.md#claude-code-specialistss-safety-implementation). Measured
September 9, 2026 ([#1720](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1720)).

**What stood there was a sentence waiting on somebody else's act**: taking the `merge_queue` rule off
`main-ci-gate` was Dave's to do, so the paragraph told every session to *read the queue as live here
until he has made it*. That is a correct instruction and an honest one — right up to the moment the act
happens. Then it silently inverts: the condition is satisfied, nothing in the tree changed, and a
document loaded on **every turn** goes on handing out precisely the answer it was written to stop
handing out. Neither the date it inverted nor how long it stood that way can now be recovered.

**The reason this shape is worse than an ordinary stale claim** is that it reads as diligent. A flat
wrong statement is somebody's error and a reader may doubt it; a conditional announces that its author
thought about the future, so a reader trusts it *more* the older it gets. And its subject here was
GitHub-side state — a ruleset — which no commit records, no gate reads and no session is told about, so
there was never going to be a signal.

**So the test before writing one: what, in this repo, will notice the day the condition flips?** Three
answers, in order of preference.

1. **A detector, and then the prose points at it rather than predicting.** This is what the repo already
   does everywhere it can — `check-unfolded-entry.ps1`, the floor checks, the roster sync. If a check can
   hold the fact, the sentence's job is to name the check.
2. **Write the state that holds, dated, and let the next measurement supersede it.** The form the
   specialist lenses use: each block is what was true on its date, newest last, and the command is
   printed so a reader can re-measure rather than trust. Nothing goes stale silently, because nothing
   claims to be permanent.
3. **A conditional — only where the condition is one the reader can evaluate themselves on the spot.**
   *"while the merge queue is live on `main-ci-gate`"* survives the same repair untouched, and that is
   the distinction: it qualifies a mechanism a consumer checks against their own trunk, rather than
   waiting on an event in this repo that no reader is positioned to observe.

**Nothing mechanical was misled here, and that is the measurement worth keeping.** `ship-pr.ps1` reads
the trunk's own rules before it merges and adapts whatever the prose says, so no gate failed and no merge
went wrong. What the sentence corrupted was a **session's reasoning** — it would expect the script to
enqueue and the fold to arrive from `fold-on-merge.yml`, when in fact this session's own step 5 folds.
That is the class of defect an always-on document is uniquely able to cause and uniquely unable to
report, which is why the bar for a forward-looking sentence is highest exactly there.
