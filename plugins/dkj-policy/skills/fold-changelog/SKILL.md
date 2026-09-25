---
name: fold-changelog
description: >-
  Fold a branch's changelog entry into CHANGELOG.md via the shared, centralized fold script from the
  plugin (single source of truth, issue #81) -- so a consumer does not have to duplicate this script
  locally. Use this on main, immediately after merging a branch, to fold the entry
  (the DEPLOY section of dkj-policy/<branch>.md, or an older branch/ pair, or a pre-split
  <branch-name>.md in the repo root) into CHANGELOG.md --
  a flat ranked list with no section headings, where each entry lands at the position its own
  Significance sections rank it at (furthest reach first, highest significance first within a tier) -- and then
  clear it: every folded entry's file is deleted, the development document included, so the trunk carries no branch document between branches.
disable-model-invocation: true
---

# fold-changelog — the shared fold for consumers

This is the **plugin mirror** of `fold-changelog-entry.ps1`: the same tested source as in the
source repo, shared here so consumers (life-hub, smartwatchbanden, …) do not duplicate it.
The background is in [issue #81](https://github.com/DaveKJohn/claude-code-specialists/issues/81).

## Why the entry file exists at all

**A branch never edits `CHANGELOG.md` directly.** Every branch would be modifying the *same* section of
the same file, so with more than one branch open at a time that guarantees merge conflicts — on a file
where a conflict is pure noise, because the two entries never actually disagree. Instead each branch
writes its **own** entry file, and this skill folds it in after the merge, when the conflict window is
already closed.

**The entry is the DEPLOY section of `dkj-policy/<branch>.md`** — one document per
branch, named after it, so two branches never write the same path and a merge cannot conflict them. (It was
a single shared `development.md` until September 3, 2026, on the argument that git tracks it per branch;
that is true of checkout and not of merge, and the cost is written up in `DEVELOPMENT-portable.md`.) The
phases above that section are the step list; they are never folded, and the document's own heading — not its
filename — is what the fold reads the branch name back off in order to find the PR.

**Which means the fold splits before it folds** (August 23, 2026). It takes the section from the DEPLOY
heading down and leaves the plan where it is — publishing somebody's ticked checkboxes as a change
description is exactly what that boundary prevents. Older shapes still fold whole: a `branch/` pair, and a
pre-split root entry file, are entries from their first line and have no boundary to find.

**Every one of them is deleted, and none is rewritten** (Dave, August 23, 2026). The document exists for
the lifetime of a branch: `new-branch` creates it and the fold removes it, so between branches the trunk
carries no branch document at all. It used to be rewritten to an empty **reset state** instead — opening
with an H1 and carrying a warning not to write there — and that H1 was load-bearing, because it stopped the
trunk's own empty file being folded as if it were a change. Nothing has to do that job now: a second fold
finds no file.

**A pre-split entry still folds.** Before August 6, 2026 the entry was a `<branch-name>.md` in the repo
root — branch `feat/new-plugin` → `feat-new-plugin.md` — and any branch created before that date still
carries one. The fold finds both forms and **deletes** the root one, since it is named after a branch that
is now merged. If you are on such a branch: **never add a suffix** like `-fix` or `-v2`, not even on a
second attempt. Without `-Branch` the fold recovers the branch from the file name, so a suffix breaks the
PR lookup.

**The entry body carries the description; the fold adds what only exists after the PR.** An entry is one
`###` heading naming the branch, with two named `####` sections under it — the same block in the entry file
and in `CHANGELOG.md`, so what a contributor writes is exactly what lands. The fold **strips the guidance
comments** on the way and writes the PR line into `#### Pull Request`:

```markdown
### DEPLOY: feat/short-name · 20260806-114230Z

…why it matters at this reach…

**Score:** 2

#### What makes this deploy extra special

…or one line saying why it reaches nobody there…

**Score:** N/A

#### Pull Request

Short strong title

[PR #123](https://github.com/…/pull/123)
```

**The entry opens with the change's two audiences, lowest first, and neither names a tier number.**
Tier 0 answers directly under the DEPLOY heading; the audience tier answers under
`#### What makes this deploy extra special`, which means whichever single tier the repo has stated
(`Get-ReleaseAudienceTier`). **Not every change reaches that audience** — that is why these are blocks rather
than the table they replaced, where a missing row read as an omission, and why the second one can answer
`N/A` with a line saying why. Where a repo has stated no audience tier, each tier the model has gets a
`##### Tier N` sub-section instead, tier 0 among them, exactly as before.

**It was six sections until August 16, 2026 and is two since** (Dave). The heading absorbed the branch ID
and, through the branch it names, the type; the PR title moved into the section that already held the PR's
other facts; and `Significance` lost a heading that only asked again what the section above it asks.
**Every retired heading is still read**, so an entry written before this — in your changelog or on a branch
in flight — folds unchanged.

The scaffolder fills in the heading and the PR title. The fold adds what does not exist until the merge,
one fact per place: the **`PR #NN` link** as the last line of the entry's own `#### Pull Request` section,
and the **moment it landed** stamped on the entry's own `### DEPLOY:` heading (see below — it stood on the
`Pull Request` heading before August 23, 2026). The separator is a middot in both.
**The ENTRY heading is left exactly as its author wrote it, except for that stamp** — the fold rewrites
nothing else but the comments it strips.

**The consumer document is the exception, and only for the heading.** Its reader is a consumer, who has no
branch — so there the heading is replaced by the entry's PR title, exactly as the PR number and
the merge date are dropped there for being internal administration. `CHANGELOG.md` and the developer notes
keep the branch heading.

**An entry file written before this format still folds.** It carries an `###` heading with the type as a
middot field and, where the repo had adopted tiers, an impact table or a `Tier: N` line. An entry file
lives only on a branch, so that shape is not distant history — any branch opened before the format
changed still has one. The fold **re-levels the whole block to `###`** as it lands, and says so on the
console: it measures the level the entry was actually written at and shifts every heading in it by that one
delta, so the entry's own sections move down with it. A heading at the wrong level in that list is not an
entry boundary to any reader of it, so the entry would otherwise be absorbed into the one above and inherit
its PR link — and lifting the heading *alone* would put it level with its own sections, which is the same
defect from the other side: one entry read as several.

**The date is the fold's** (Dave, August 5, 2026). The scaffolder runs when
the *branch* is created, so any date it wrote was the branch's birth date — a branch opened on Monday and
merged on Thursday was filed as Monday's work, in the one document whose subject is when things landed.
So the entry carries what the author knows and the fold adds what only the merge knows. It comes
from the PR's own merge timestamp rather than from the clock, because a fold does not always run in the
same minute as its merge.

**And since August 23, 2026 it stands on the `### DEPLOY:` heading** (Dave), where it stood on the
`Pull Request` heading for four days and on the closing line before that. It is the date the change
*landed*, and that is the line saying *what* landed. It is the only stamp left: the document's own heading
carried a creation stamp until September 3, 2026, and nothing read it back. Both shapes of this one are
read back: an entry carrying the stamp on `Pull Request` still parses. The closing line keeps the clickable
`[PR #N](url)` and nothing else: one fact, one place. An entry folded without a PR gets neither, because
there is nothing to read either off.

## The one formatting rule: a body sub-heading is `#####`, never `###` or `####`

**`###` makes it a separate change.** Every `###` in `CHANGELOG.md` is read as one entry, so a body
sub-heading at that level becomes a phantom entry — one that declares no impact, therefore reads as an
undeclared tier 0, and gets its own block in the release record.

**`####` makes it a seventh section, and can cost the entry a declaration.** The named sections sit at
that level, and a section ends at the next heading of that level or above — so a stray `####` truncates
whichever section it lands in. The dangerous version is a *misspelled* section heading (`Branch Type`):
the parser looks for the exact text, so the entry silently loses the declaration the tier and significance
gates read.

Use `#####`, or bold. The lint gate checks both halves in the entry file and in `CHANGELOG.md`.

**What makes this worth a rule is *when* it bites.** The entry file looks perfectly fine on its own, and
fine in the changelog after folding. The damage only appears once the release cut lifts the body into the
release notes and any per-plugin changelog — in the artifact a reader finally sees. Measured on a real
release, where a body's two subheadings came out looking like two extra release categories.
**Inspect the generated notes before pushing a release**; that is what the cut's `-NoPush` is for.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/fold-changelog-entry.ps1" -Branch <prefix>/<name>
```

**In the source repo, run its own copy instead — `scripts/release/fold-changelog-entry.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

Without `-Branch` it folds everything it finds: `dkj-policy/<branch>.md` if it holds an entry, plus
any pre-split entry file in the root. An optional `-RepoRoot <path>`
overrides which repo root the script writes to — for a consumer that runs the fold from a
temporary/detached worktree (e.g. a `ship-pr.ps1` that checks out main elsewhere) and wants the fold
to land there instead of wherever `CLAUDE_PROJECT_DIR`/git-root would otherwise resolve to (issue
#101); omitted, behavior is unchanged. The script:

1. Folds each entry into `CHANGELOG.md`, with the PR number + link included (retrieved via
   `gh pr list` — keyed on `-Branch`, or on the name in the document's heading, or for a pre-split entry
   on its file name).
2. Clears it afterwards: **`dkj-policy/<branch>.md` is removed** — one deletion, which
   clears the plan along with the entry since they are sections of one file. A pre-split root entry file is
   removed as it always was, and an older `branch/` step list is removed beside it.

**Where it lands is the top of the list.** `CHANGELOG.md` is a fixed head followed by a flat list of `###`
entries, **newest first**: the entry being folded is the most recently merged one, so it leads. The head is
`# Changelog` and the `## [Unreleased]` heading with the pending tally under it, and **the fold re-applies it on
every run** (#2486): whatever prose an older intro carried is replaced, so every repo's head is identical. A
document with no entries yet simply gets the first one.

**It ranked on the Significance sections until August 16, 2026**, and the argument for that was that the
cut empties this list, so document order at cut time is what the release documents inherit. That held for
one section only: the release notes rank themselves from tier 1 up and the consumer document always ranks
at tier 2, so both read the scores rather than the order. The one section that does inherit is the
development notes' tier 0 — which asks to be chronological, and was getting score order instead. The
scores are untouched and still decide both the release documents' order and the version bump.

**Nothing is consumed.** The `Tier: N` line of a pre-format entry, and the Significance sections of a current one,
both travel into `CHANGELOG.md` intact. That is a change from when the document had one section per tier: the
*section heading* stated the reach then, so the fold stripped the line. With no heading above the entry,
stripping it would leave the entry declaring nothing — and every downstream reader would take it as tier 0,
which is silent, correct-looking, and wrong in the direction that empties a release document. The documents
that travel outward strip both declarations themselves, at the moment they render.

**An entry that declares nothing is tier 0**, the harmless end: forgetting to classify can never promote
work into a consumer-facing document. The run says so out loud, because such work cannot carry a release on
its own where the repo's release cut checks tiers. **An entry that declares a reach but no significance is
also reported and still folds** — it sinks to the bottom of its tier, which is exactly where a reader of an
unranked entry would put it, and the same place it would rank from if it were scored last.

**What stops the fold before it touches anything**, reported for every entry at once rather than one file at
a time — a fold-all that failed halfway would leave earlier entries folded and their source files deleted:

- a tier the model has no meaning for (`Tier: 5`, `Tier: two`, or an impact row `| 5 | 3 | … |`);
- a significance cell off the scale (`| 2 | 9 | … |`).

**And one refusal that arrives after the entry has been read: a branch the changelog already carries an
entry for.** The fold used to write a second one and report both runs as a success — measured in a
consumer as two entries, same branch, same text, two PR numbers, with nothing downstream refusing them
either: the cut counts a duplicate twice in its tier breakdown and prints it twice in the published note,
under two links that both work. The refusal names the PR of the entry already there, leaves the entry file
on disk and ends the run non-zero, so `ship-pr` sees it. `-Force` folds anyway.

**The branch name is the key, and the merge stamp is not** — the fold writes that stamp at fold time, so a
duplicate carries a different one, which is why nothing matched. A second cycle on the same subject is a
`-v2` branch by construction, so two entries naming one branch is not a state this cycle reaches
legitimately. The entry *text* is not a key either: two branches may describe the same change in the same
words.

**Refusing is safe here for a reason that does not generalise.** This page says elsewhere that a missing
score is folded anyway rather than refused, and that still holds: an entry that is refused for a missing
score leaves merged work with no record at all, while a duplicate that is refused leaves the record
already standing. There is nothing to lose by stopping, which is what makes this the one place a refusal
costs nothing.

**And that gate reads a trunk it has actually checked, because one repo is worked from more than one
device.** Until inbound #1405 it read `CHANGELOG.md` from the **working copy** and nothing else, which on
a second checkout is a snapshot of whatever that tree last pulled — so a branch the other device had
already folded read as "no entry yet", with complete confidence. Two guards close that, and they fail
independently:

- **Before the gate reads**, the fold fetches `origin/<trunk>` and **refuses a trunk that is behind it**,
  naming how far. `-SkipTrunkCheck` folds anyway. This is deliberately a *different* flag from `-Force`:
  that one waves through a judgement about **content** (the changelog already names this branch), this one
  waves through a **measurement of the checkout** — the same split `open-pr` draws with
  `-SkipLint`/`-SkipTests`. A repo with no `origin/<trunk>` ref at all — no remote, or a clone that has
  never fetched — is *unmeasurable* rather than behind, and folds exactly as it always did.

  **This refusal exits `2` rather than `1`, and it is one of exactly two places in the script that
  return a code of their own** (inbound #1586; the other is the raced push below, `3`). It is still
  non-zero, so a person sees the same refusal it always was. The code exists for **one** caller: `fold-on-merge`,
  the CI job re-triggered by *every* push to the trunk. There a trunk that moved between the job's
  checkout and this pre-pass means the push that moved it has its own run of the same job queued behind
  this one, reading a tip that includes it — so that run stands down green instead of leaving a red on
  the trunk describing a state that is already gone. What makes the stand-down lossless is **where this
  refusal sits**: in a pre-pass, before a single entry is folded, so the run has written nothing. A
  refusal that could follow a partial fold must never borrow this code.
- **After a rejected push**, the fold says *why* it was rejected. This is the half a pre-pass structurally
  cannot cover, because the measured failure was a **race** rather than a stale checkout: the trunk was
  current when the gate read it, and the other device folded the same branch inside the window before the
  push. No check at the top of a run can close a window that opens after it.

**Why the second one matters more than it looks.** The step used to report `git push exited 1` plus git's
own "the remote contains work that you do not have locally" — the same sentence a plain divergence gives,
at the one moment the two need **opposite** actions. If the remote merely moved, the fold commit is real
work and has to be integrated and pushed. If the other device already folded this branch, the commit is a
duplicate, and pushing it by hand — which is what this step used to advise — produces exactly the
two-entries-one-branch state the gate above exists to prevent. So the run now names how far the trunk
moved and which commits did it, reads the remote's changelog straight out of the fetched ref, and reports
per branch whether its entry is already upstream, **how many times**, and whether the **body** matches the
one this run just wrote. Bodies rather than whole blocks, because both devices stamp the heading at their
own fold time and no two stamps can match.

Where every entry the commit carries is already upstream, the closing advice inverts to **"Do NOT push
this commit by hand"**. Where any of them is not, the ordinary "push by hand" verdict stands — a genuine
divergence must never be reported as a duplicate, or its author would strand the entry for good.

**And that inverted verdict exits `3`, the script's second code of its own** (issue #1792). Every line of
the diagnosis above has just established that the fold **happened** — the entry is upstream, present once,
with a body identical to the one this run wrote — so the run did not fail at the thing it was asked to do;
it lost a race to whoever folded first. The code exists for the caller standing on the far side of that
race: `ship-pr`, which merged the PR seconds earlier and has no other way to tell "somebody else folded
it" from "the fold refused or crashed". Reading it as an ordinary failure cost a **correct** ship —
measured on PR #1789, 2026-09-10, where `fold-on-merge` folded first, the two commits had identical trees,
`origin/<trunk>` was right, and the shipping session was nonetheless told the ship had failed and left
holding a trunk diverged 1/1 that its own constitution reserves every obvious way out of to a person.

**`2` and `3` are deliberately not one code.** After `2` nothing was written and there is nothing to clean
up; after `3` a commit is sitting on the local trunk. A caller that conflated them would either invent a
leftover that does not exist or stay silent about one that does — and since this script repairs neither,
silence is the one outcome worse than the hard failure. It remains true that only a run whose **every**
named entry is upstream reaches `3`; a fold-all where one entry is genuinely new keeps `1`, because that
commit carries work.

**It diagnoses and stops, repairing nothing, deliberately.** The fold commit is on the trunk by then, and
every route off a trunk — a reset, a rebase, a merge commit — is a history operation a repo's safety rules
reserve to the operator. Being exact about the state is the whole job here. That boundary is the point:
in the incident this came from, the tooling put a correct-looking commit on the trunk and then left the
operator in a state their own constitution forbade every route out of.

**Two refusals disappeared with the sections, and both are structural rather than relaxed:** "could not find
the heading — stopping" (issue #178) has no heading name left to mismatch, and "this repo declares no section
for tier N" has no mapping left to miss — a tier the repo does not use is now a position in the list rather
than an error.

**The script can make that commit itself, and normally should: `-Commit`, or `-Push` to commit and push
in one step.** Both are **opt-in**, so without either the fold is left in the working tree for you to
commit by hand — which is how it ran until August 2, 2026, and four hand-typed fold commits in a single
session is what earned the flags. Committing stays opt-in deliberately: on most repos this commit lands
directly on the main branch, which is a governance exception the repo grants, not something a script
should assume.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/fold-changelog-entry.ps1" `
  -Branch <prefix>/<name> -Push
```

**The subject is typed `fold:`, and names the branch and its PR:**

```text
fold: <branch> changelog (#NN)                     one entry
fold: 3 changelogs: a (#1), b (#2), c (#3)         a fold-all run
```

The PR number is looked up from the merge; a fold whose PR cannot be determined simply drops it, and a
fold whose *branch* cannot be determined falls back to the entry's file name — the subject always names
something. It was typed `chore:` until August 10, 2026: folding is a named act with its own script and
its own governance exception, while `chore` said only "housekeeping", and `fold:` is the same choice
[`ship-pr`](../ship-pr/SKILL.md) made for `merge: <branch> (#NN)` one commit earlier, so a merge and its
fold read as a pair. **Nothing parses this subject**, so every `chore: fold ...` in your existing log
stays exactly as valid as it was and there is nothing to migrate.

**The commit names its paths**, so `CHANGELOG.md`, the entries it folded and any legacy step list it removed are
the only things that can land in it however messy the working tree is. That scope limit is the point rather than tidiness: where this
commit runs under a "never commit directly to main, except the fold" exception, an unscoped
`git add -A` would let anything else in the tree ride along under that exception. It is enforced by git
now instead of by care.

## Two things that go wrong in practice

**Check that you are really on the main branch before folding** (`git branch --show-current`).
`gh pr merge --delete-branch` promises in its help to clean up the local branch too, and in practice
turned out to be able to simply leave the local checkout **on the merged branch**. Measured July 16,
2026: the fold then ran there, and the changes had to be moved over by hand afterwards. Do not trust the
flag; trust the check.

**Working from more than one machine: always fold with `-Branch`.** Without it the script folds
*everything* it finds — including a pre-split entry file belonging to a merge that another machine is
still folding, which then lands twice. So `git pull` first, then fold your own branch by name. If your
fold push is rejected because you are behind origin, that is harmless: pull and retry.

## When your branch contradicts an entry that is already folded but not yet released

An entry sits in `CHANGELOG.md` from the moment it is folded until the next release cut. In that window
it is **not history** — it is a claim waiting to be published, and the branch you are on right now can
be the thing that makes it false.

**Correct it in place. Do not supersede it in your own entry.** Both entries reach the reader in the
same release document, so a "this was reversed the next day" paragraph three entries down publishes the
contradiction rather than resolving it — and if your entry ranks above the stale one, the reader meets
the correction before the claim it corrects.

**The measured instance**
([#876](https://github.com/DaveKJohn/claude-code-specialists/pull/876) →
[#875](https://github.com/DaveKJohn/claude-code-specialists/issues/875), August 24, 2026): an entry
declared its new script *"deliberately repo-local… nothing about it ships. That is the point rather than
an omission."* The next branch, within the day, registered that script in the plugin. The false half was
never the description of what shipped — it was the **principle** the section had reached for. That is
the half to withdraw, and where a section's factual answer still stands (there, an audience score of
`N/A` for a change that genuinely reached nobody) it stays as it is.

Two limits worth keeping straight:

- **Only while it is pending.** Once a release is cut, that entry is what a version said at the time
  and a later edit is a rewrite of the record. Then a new entry *is* the right instrument.
- **The withdrawal is signed, not silent.** Say what the section originally claimed and why it is being
  withdrawn. A quietly edited entry teaches its next reader nothing, and the reasoning that went wrong
  is usually more reusable than the sentence that carried it.

## Closing step: branch cleanup (#163)

The fold is the **last step of the PR chain**, so branch cleanup belongs here as its fixed
closing step -- not something to remember per repo or per time:

- **Remote** -- a well-configured repo deletes the head branch automatically on merge (the GitHub
  setting *"Automatically delete head branches"*, `deleteBranchOnMerge: true`; see the
  `specialists-init` setup checklist). Nothing to do by hand. **`ship-pr` now tells you when that
  setting is off**, right after the merge that left a branch behind, with the one-line `gh api` command
  to switch it on -- because being named in a setup checklist read once at init turned out not to reach
  anybody ([#815](https://github.com/DaveKJohn/claude-code-specialists/issues/815)).
- **Local** -- GitHub never touches your own clone, and since
  [#815](https://github.com/DaveKJohn/claude-code-specialists/issues/815) this is a script rather than
  two commands to remember: the [`prune-merged`](../prune-merged/SKILL.md) skill. It fast-forwards the
  trunk, drops stale remote-tracking refs, and deletes only the local branches whose merge it can
  **prove** -- an ancestor of the trunk, or a branch whose PR is merged. Anything else, including a
  parked branch, is kept and reported. `-DryRun` looks first.

  By hand, if you would rather, it is these two on `main` after the fold:

  ```powershell
  git fetch --prune            # drop stale remote-tracking refs (origin/<merged-branch>, ...)
  git branch -d <merged-branch>  # remove the merged local branch
  ```

  `git fetch --prune` matters even when the remote branch was auto-deleted: the stale
  remote-tracking refs otherwise pile up in the local clone until pruned. And note what it does *not*
  prove -- it only drops refs for branches **already gone** from the remote, so a clean local list is no
  evidence at all that the remote is clean. That is `git ls-remote --heads origin`.

## Requirements in the consumer

The script is repo-agnostic, but reads a small block of repo data from the **root** of the consumer
(dual-context: it resolves the repo root via `${CLAUDE_PROJECT_DIR}`):

- `scripts/repo-config.ps1` with `Get-RepoName` (for the `gh --repo` calls). This is the only
  repo-specific file fold needs -- it derives the PR number via `gh pr list` and the entry file name, and
  thus does not dot-source `branch-info.ps1` (unlike `open-pr`). **No changelog-structure seam is read any
  more**: `Get-ChangelogTierHeadings` and the legacy `Get-ChangelogHeading` are retired, because a flat
  document has no section headings to configure. A consumer that still defines either is unaffected --
  nothing calls them.
- A `CHANGELOG.md`. Its head is not the repo's to write: the fold replaces everything above the
  `## [Unreleased]` heading (or, where there is none yet, above the first `###` entry) with the fixed head.
- `git` and a logged-in `gh` CLI.

If `repo-config.ps1` is missing -- typical on a clean consumer -- the script stops before the
dot-source with a clear pointer instead of a raw error (#86). The `specialists-init` bootstrap
puts it in place as a `VUL-IN` scaffold; fill it in (see the source repo as a model) before you use
this skill.

## Important

- **Run this on main, after the merge** (after the PR has been merged) — then the PR number exists.
- The script only touches `CHANGELOG.md` and the entries it folds -- which since the merge is one file
  fewer, because the step list is a section of the document it already removes; nothing else.
- This script is maintained in the source repo; do not modify it locally in the consumer. A
  change lands first in the source (`scripts/release/fold-changelog-entry.ps1`) and then travels via
  a release to the plugin mirror — guarded by the shared-scripts drift lint.
