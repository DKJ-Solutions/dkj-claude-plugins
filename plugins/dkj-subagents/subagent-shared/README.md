# `subagent-shared/` — one source for the boundaries that appear verbatim in many agent defs

**This directory is not a plugin.** It is the canonical source of the blocks that a generator writes
*into* the team folders beside it: it is plugin **source**, but it ships in no plugin of its own.

**Why it sits inside `teams/` rather than one level up, where it lived until August 17, 2026.** Every
file that carries a shared block is a team's — 30 agent defs and personas across all four teams, and
**none** in either workflow plugin. A level up said the blocks reach the whole marketplace; they reach
this directory. Two consequences, only the first of them a behaviour change:

- it now travels to a published marketplace exactly when at least one team does, because
  `publish-to-business.ps1` prunes a kind-directory once it holds no plugin. Before the move it
  travelled on every publish, including ones carrying no team at all;
- nothing had to be told where it went. Scripts ask `.claude-plugin/marketplace.json` which plugins
  exist, so a directory in no marketplace is not a plugin wherever it sits — including here, sharing a
  path prefix with the four that are.

## Why the text is copied at all

A number of bullets under **Boundaries** are word-for-word identical across many agent defs — the inbound
rule and the automation-first rule across **all 26**, the repo's-way-of-working rule and the
findings-become-issues rule across all 26 plus the four personas. Such governance belongs *in* the
agent-def body, because that body is always loaded, including for a worker subagent somebody invoked
directly. But Claude Code has no transclusion in an agent def: what is written there is there, literally.

So the text really is duplicated on disk, and the duplication is made safe by being **generated**. One
source file, one build, and a gate that fails the moment a copy stops matching.

## The rule

> **Never edit between the sentinels.**

In an agent def or a persona the block sits between
`<!-- BEGIN shared:<name> … -->` and `<!-- END shared:<name> -->`. To change it: edit the file **here**,
then run [`scripts/agents/build-agent-defs.ps1`](../../../scripts/agents/build-agent-defs.ps1), which
rewrites every carrier. Lint check 7 in
[`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) fails as soon as a marked
region deviates from its source — whether from a hand edit or a forgotten rebuild — and
`build-agent-defs.ps1 -Check` answers the same question without writing.

### The BEGIN line is generated too, and it deliberately points nowhere

It reads `<!-- BEGIN shared:<name> -- GENERATED, do not edit here -->`, and that wording has one source:
`Format-SharedBeginSentinel` in
[`subagent-shared-lib.ps1`](../../../scripts/lib/subagent-shared-lib.ps1). Until August 14, 2026 the expander
copied the line through unchanged, so the text sat hand-maintained in **178** places with nothing
holding it — and it said `GENERATED, edit subagent-shared/<name>.md`.

**That path resolves in this repo and nowhere else.** This directory sits *outside* every plugin root,
so it does not travel in the package: for a consumer the instruction pointed at a file they do not have.
Inbound [#669](https://github.com/DKJ-Solutions/claude-code-specialists/issues/669) C2 reported it as a dead
pointer, which understates it — three lines below, in the same agent def, the `inbound-behaviour` block
says *"You do not modify the shared core locally"* and names the issue route. The pointer told a reader
to do what the paragraph it introduces forbids.

**Both remedies #669 proposed were weighed and declined.** *Shipping this directory in the package* hands
a consumer a file they may open but which is not the source — precisely the confusion the inbound route
exists to remove. *Repointing it at this repo* would add 178 references to a repo the reader cannot write
to, straight against C4 of the same report. And for the only reader who can act on it — a
maintainer here — the pointer is redundant: `shared:<name>` maps to `subagent-shared/<name>.md` by
construction. Measured: dropping it takes those 178 lines from **17,332 to 13,027 bytes**.

**Half of that middle reason expired on September 2, 2026, and the decision stands on what is left.** It
was written as *"178 references to a **personal** repo"* — and this repo is no longer personal, having been
transferred from `DaveKJohn` into the `DKJ-Solutions` organisation. The account type was never what made
the pointer wrong, though: a consumer still cannot write here, and the other two reasons are each
sufficient on their own. Recorded rather than swept, because a find-and-replace would have left the
sentence arguing from a premise that no longer exists.

**Owning the line is what makes it a rule rather than a habit.** The builder and lint check 7 both compare
the whole file against the expander's output, so a reworded sentinel is rebuilt by the one and reported by
the other — with no check of its own, and no exemption list.

## What each block is for

The directory listing is the enumeration: one `.md` per block, and the filename is the `<name>` in the
sentinel. **How many agent defs carry a block is a per-block decision, not a default.** A block is added
to the specialists the rule applies to, which is what keeps a boundary about storefront previews out of a
copy editor's context.

| block | roughly who carries it |
|---|---|
| `repo-way-of-working` · `findings-become-issues` · `inbound-behaviour` · `laziness-automation` | everyone — these are the family's constitution |
| `language-behavior` | everyone who writes anything |
| `filecontent-boundary` · `lens-optional` | every agent def, all 26; no persona — see below |
| `no-conversation-history` · `no-commit-push-pr` | the specialists who deliver material rather than land it |
| `working-copy-boundary` | every agent def that holds `Bash`, and no persona — the circle is the capability, see below |
| `browser-compatibility` · `webcontent-boundary` · `artifact-publishing-boundary` · `design-owner-boundary` · `changelog-entry-boundary` · `storefront-preview-boundary` | the narrow circles whose craft touches that surface |
| `guard-exercised` | the two who pass judgement on a guard before it lands — the code reviewer and the security engineer |

Run `build-agent-defs.ps1 -Check` for the exact carrier count per block; a table of numbers here would be
a second statement of something the generator already knows, and would go stale the first time a
specialist joins a circle.

### Why `filecontent-boundary` is in all 26 rather than in a circle

It is the second-widest block, and the width was a decision rather than a default — the per-block rule
above says so. Inbound
[#668](https://github.com/DKJ-Solutions/claude-code-specialists/issues/668) offered the narrower option:
insert it only into the specialists that *act* on file content, not the ones that merely locate it. That
line was measured against the roster and does not hold. **All 26 agent defs carry `Read`, `Grep` and
`Glob`**, and a specialist that greps a file and reports what it found has already relayed the content
into a context that acts on it — the locating/acting split describes what a specialist intends, not what
reaches the next reader. A boundary with a hole shaped like "I was only looking" is not one.

**The web block is the deliberate contrast, and the two texts differ because their arrival does.**
`webcontent-boundary` sits in exactly two agents, because two hold fetch tools, and it can lean on *you
went and fetched this*. File content cannot: it did not arrive because a specialist reached for it, it
was simply within reach. So this block says instead that **a file being present says nothing about who
wrote it or why** — the sentence the web version has no need of.

**The personas deliberately do not carry it.** They run in the main loop of a repo whose own `CLAUDE.md`
is loaded, which is the layer that already answers for what is in that tree. The exposure this block
guards is the one the subagents have: an assignment that points them at files nobody in the conversation
has read.

### Why `lens-optional` has exactly the same 26 carriers

Same scope, and for a reason that is the mirror image rather than a copy. Inbound
[#669](https://github.com/DKJ-Solutions/claude-code-specialists/issues/669) C1 measured that **all four**
specialists put on that assessment hit the same friction first and independently: look for the repo lens,
fail to find it, continue on the plugin source. Every agent def names its lens in its opening sentence,
so every agent def could produce that hunt — the width follows the pointer, and the pointer is in all 26.

**A persona cannot be in that position.** It is loaded *through* the consuming repo's `CLAUDE.md`, so a
persona reading this would already be proof that a repo exists. Giving it the block would be reassuring
it about a state it can never be in.

The per-file half of the same repair sits in those opening sentences: they now say the lens is in the
consuming repo **"if it has one"**. Both halves are needed, and neither is sufficient. The pointer alone
would still leave a specialist deciding for itself what a missing file means; the block alone would sit
under **Boundaries** contradicting a sentence twenty lines above it.

### Why `working-copy-boundary`'s circle is a TOOL rather than a craft

Every other block on this page is scoped by craft — who writes prose, who touches a storefront, who
delivers material rather than landing it. This one is scoped by **capability**: the 11 agent defs whose
`tools:` line names `Bash`, and no persona. A block is placed where the rule applies, and the rule here
applies wherever `git` can be typed at all.

**What it cost to have no such block, measured September 8, 2026
([#1665](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1665)).** A code review needed
to compare a branch against `main`, ran `git stash`, met stash entries left by other sessions, hit a
conflict popping them, and settled it with `git checkout HEAD -- <file>` on three files. Those three
files were the **orchestrating session's** uncommitted work — four edits made after the branch's last
commit — and they went without an error, a notice or a refusal. The review's own report ended
`No repo content was altered` and `the working tree is back to git status clean, matching this commit
exactly`; both sentences were true of the committed tree and wrong about the work in front of it.

**The reviewer was reading its boundary correctly.** `specialist-06-19-subagent.md` said *"does not correct the code
and does not land it"*, and a `git stash` corrects nothing and lands nothing — so the prohibition genuinely
did not reach it. That is why the block's first bullet says out loud that this is *not* the editing
boundary in another register: the gap was not carelessness but a rule whose subject was the wrong verb.

**Why the circle is not "the reviewers", which is what the report proposed.** Two independent
corrections, in opposite directions:

- The report's table listed **five** reviewers holding `Bash` and named Marlowe #29 among them. He holds
  `Read, Grep, Glob, WebSearch, WebFetch, Skill` — no `Bash` — so a block placed on that table would
  have put the rule in a context that cannot break it and, worse, would have read as complete.
- **Seven of the 11 carriers are not reviewers at all** — a majority, so "the reviewers" was not merely
  an undercount but the wrong noun. The app developer, the test engineer, the systems administrator and
  the refactoring specialist hold `Bash` beside `Edit`/`Write`, and so do all three of
  `dkj-subagents-ecomm`'s specialists (SEO #26, CRO #27, performance/SEA #28), none of whom appears in any
  review chain. A `git stash` from a test run or a pagespeed measurement discards exactly the same three
  files as one from a review. Their legitimate editing is what makes the distinction the block draws
  load-bearing rather than pedantic: **files in your scope, through your own tools, yes; the tree, the
  index and any ref, never.**

  This enumeration was itself wrong on its first draft — it said "four" and named only the
  `dkj-subagents-alpha` half, which is the same miscount by craft that the bullet above corrects in the
  original report. Recorded rather than quietly fixed, because it is evidence for the width decision
  rather than an embarrassment: reasoning about this circle from the crafts one happens to have in mind
  produced the wrong answer twice in one afternoon, and only `grep` over `tools:` got it right.

**No persona carries it, and that is the mirror of the other two exclusions above rather than a copy.**
The DevOps engineer and the release manager ship as personas and mutating the working copy *is* their
craft — a checkout, a merge, the fold's step onto the trunk. Giving them this block would forbid the work
they exist to do. The personas are also not the exposure: this hazard is a **dispatched** subagent
sharing one checkout with a session that is still editing in it, and the parallel review chain in Chris's
lens (six specialists on one diff while the orchestrator keeps working) is precisely that arrangement.

**And because this circle is a capability, a check can keep it — which is the half that makes it
durable.** Every other block's circle is a craft judgement, and lint check 7 has never had an opinion
about a sentinel pair that is *absent*: it compares the inside of a pair against its source. That is
right for a craft block and wrong here, because "holds `Bash`" is decidable. So `working-copy-boundary`
is the subject of **lint check 36**, which reads `Get-ToolRequiredSharedBlocks` in
[`subagent-shared-lib.ps1`](../../../scripts/lib/subagent-shared-lib.ps1) — a `tool -> block` table — and
reports any agent def that names the tool and carries no block. Without it the circle held only as long
as somebody remembered: a specialist gaining `Bash` later, or one edited `tools:` line, would sit
silently outside the boundary with every gate green — the same enforced-by-memory shape as the defect
itself, arriving through the maintenance door. The reverse direction is deliberately not checked:
carrying a block you are not obliged to is a decision somebody can make, carrying none you are is the
defect. It was reported by the red-team pass on this branch, before the block had shipped.

**Whether a reviewer should instead be dispatched into a worktree of its own** — removing the hazard
mechanically rather than by instruction — is a separate decision, filed as
[#1667](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1667). It is not an alternative to
this block: a reviewer sometimes reviews work that is not committed yet, which is exactly what a fresh
worktree does not have.

## Personas carry blocks too

**The generator started walking `personas/` as well as `agents/` (as that directory was named then) on
August 8, 2026.** A persona is prose
rather than a bullet list under **Boundaries**, so its block sits under its own `##` heading instead of
dangling as a stray bullet; the sentinels and the never-edit-between-them rule are identical.

The widening was not cosmetic. The two specialists whose craft *is* a way of working — the DevOps engineer
and the release manager — ship as personas, so a shared block about process could never have reached its
primary readers while the generator walked `agents/` alone.

**What deliberately did not widen with it:** the lint's agent-def↔manual coupling still leaves personas
alone, because that check is about a pairing personas genuinely do not have.

## Adding a block

1. Write the canonical text as `<name>.md` here — the body only, no sentinels and no heading.
2. Add the `<!-- BEGIN shared:<name> … -->` / `<!-- END shared:<name> -->` pair to each agent def or
   persona that should carry it, with nothing between them.
3. Run `scripts/agents/build-agent-defs.ps1`, then the lint gate.

The DRY judgement about *when* a rule has earned promotion to a shared block — rather than being restated
in two places that are free to disagree — belongs to
[Ravi #24](../../../.claude/specialists/lenses/specialist-06-24-lens.md). The mechanism is described once more,
from the reader's side, in the root README under
[Shared agent-def blocks](../../../README.md#shared-agent-def-blocks--one-source-for-the-verbatim-boundaries).
