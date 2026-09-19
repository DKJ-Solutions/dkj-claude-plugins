## feat/2128-specialist-file-prefix

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

#### What this branch delivers

Issue #2128 asks for a strict step plan **before** any file is renamed, because the rename is large.
This branch delivers **that plan and nothing else** -- no file is renamed here. The rename itself runs
in the follow-up branches this plan names, each with its own issue.

#### The true mapping, corrected against the tree

The issue names four conventions. Three of its paths and one of its examples do not match the tree, so
the mapping is restated here in the form the work will actually use:

| # | From | To | Count |
|---|---|---|---|
| 1 | `plugins/dkj-subagents/<plugin>/manuals/NN-NN-manual.md` | `specialist-NN-NN-manual.md` | 27 |
| 2 | `plugins/dkj-subagents/dkj-subagents-alpha/personas/NN-NN-persona.md` | `specialist-NN-NN-persona.md` | 4 |
| 3 | `plugins/dkj-subagents/<plugin>/subagents/NN-NN-agent.md` | `specialist-NN-NN-subagent.md` | 26 |
| 4 | `.claude/specialists/lenses/NN-NN-extension.md` | `specialist-NN-NN-lens.md` | 30 |

**87 files, and four corrections to the issue text:**

1. The issue writes `plugins/dkj-subagents/manuals`. That folder does not exist -- manuals, personas and
   subagents sit one level deeper, per plugin, and **four** plugins carry manuals and subagents
   (`-alpha`, `-ecomm`, `-lifehub`, `-shopify`), not one. The plan takes all four, because a convention
   applied to one plugin and not its siblings is the half-rename #1698 already paid for once.
2. Conventions 3 and 4 change the **suffix as well as the prefix** (`-agent` to `-subagent`,
   `-extension` to `-lens`). The issue's own examples say so; it is worth stating because a
   prefix-only sweep would silently leave both halves inconsistent.
3. The issue writes `02-09-subagent wordt specialist-01-01-subagent`. Read as `specialist-02-09-subagent`.
4. Only `01-01` carries both a manual and a persona; `03-02`, `05-05` and `05-06` are persona-only. The
   id matrix is otherwise 1:1 and **no renamed name collides with another**, verified across all 30 ids.

The suffix change in convention 3 finishes what #1698 started: that rename moved `agents/` to
`subagents/` but left the files inside called `NN-NN-agent.md`. Convention 4 aligns the filename with
the word the whole tree already uses in prose ("repo lens").

#### The measured reach

- **476 occurrences across 120 files** must move with the 87 renames.
- **150 occurrences across 70 files** sit in `dkj-policy/releases/**` and are **not swept** -- the
  existing historical carve-out in `.claude/rules/language-layers.md`. `CHANGELOG.md` holds none.
- **237** of the 476 are markdown links, which the lint gate's dead-link scan (check 4) catches.
  The remaining ~239 are backticked or bare mentions that **no gate reads**.

#### The four hazards, in descending order of danger

**1. The persona `@`-import breaks outside every version gate, and it fails completely silently.**

Every consumer's `SPECIALISTS.md` carries a hardcoded absolute line written by `bootstrap.ps1:811`,
naming `personas/01-01-persona.md` under `~/.claude/plugins/marketplaces/`. That path resolves against
the marketplace **clone**, which tracks `main` and advances on `claude plugin marketplace update` -- no
release, no version bump, no `plugin update`. `bootstrap.ps1` never rewrites this line once written
(`:838-839`, it is authored content), so renaming the file breaks the orchestrator import in every
already-adopted consumer the moment their clone advances past the rename commit.

**Measured in an isolated checkout, September 19, 2026** (this branch), because the behaviour is
undocumented and the plan turns on it. A `CLAUDE.md` holding a live import to a missing file:

- the rest of the file **loads normally** -- a broken import is not fatal;
- the raw `@missing-persona.md` line **stays in context** as inert text;
- **nothing is reported.** Not on stdout, not on stderr, not under `--debug`. Zero diagnostics.

So a consumer silently loses Chris's entire persona body -- 30,267 bytes per
`always-on-baseline.json` -- and the session continues as though nothing happened. This is the worst of
the three possible failure modes, and it is the hazard the plan is built around.

**2. Four specialists fall out of the roster check, through a negative lookbehind.**

`Get-RosterIdTokenPattern` (`scripts/lib/check-report-lib.ps1:1677-1678`) builds a pattern requiring
that the id is **not** preceded by a digit or a hyphen. In `.claude/specialists/SPECIALISTS.md` the four
main-loop personas carry their id **only** inside the lens filename in the roster table. Rename that to
`specialist-01-01-lens.md` and the id is now preceded by a hyphen, the lookbehind fails, and Chris,
Bianca, Derek and Rendall stop being recognised as rostered.

The subagent rows are unaffected -- they write bare ids. This is a **silent** break that survives fixing
every anchored `^(\d{2})-(\d{2})-...$` regex in the tree, because it is a different mechanism in a
different file.

**3. The lens convention is a CONSUMER-owned filename in six registered repos.**

`.claude/specialists/lenses/` lives in the consumer's own tree and holds their authored content.
Nothing in this repo renames it for them: `bootstrap.ps1` is additive-only and never overwrites, and
`teardown.ps1` removes only unfilled scaffolds. So a reader updated to the new name finds nothing and
`check-roster-sync.ps1:910` raises one `[ERROR]` **per specialist** at every session start -- for lenses
that are sitting right there, filled in, under the old name. That check ships in the **core** plugin's
`roster-sessioncheck` hook, so it fires in every consumer with the core team enabled.

Six registered connectors: `dkj-claude-plugins` (this repo), `life-hub`, `smartwatchbanden`,
`xoxowildhearts`, `djcylow-react`, `thumbnail-generator`.

**4. Thirteen reader sites, four mirror families, and 26 literal manifest paths.**

The four `plugin.json` manifests list all 26 subagent paths literally. Check 38 holds the manifest
against disk, and #1764 is the precedent for getting this wrong: a bad shape there made four of six
plugins uninstallable for a whole release. The readers themselves (`check-plugin-integrity.ps1`,
`check-roster-sync.ps1`, `check-report-lib.ps1`, `bootstrap.ps1`, `teardown.ps1`, `sync-roster.ps1`,
`build-agent-defs.ps1`, `find-specialist-mentions.ps1`, `check-connectors.ps1`,
`check-consumer-drift.ps1`) are anchored to the current convention by glob and by `^`-anchored regex;
several are held byte-identical across mirrors by the drift lint (check 8) and must change in the same
PR:

- `check-report-lib.ps1` -- **four** copies (root, `-alpha`, `-shopify`, `dkj-policy`)
- `check-roster-sync.ps1` -- two copies (root, `-alpha`)

#### The governing decision: this repo has never done an unguarded cutover, and should not start here

Three prior renames, three different techniques, all recorded:

| What moved | Technique | Where |
|---|---|---|
| The branch document (4x) | a **resolver over content** -- try every historical name, decide by what the file says it is | `Resolve-BranchFilePath` |
| Repo owner + repo name | a **retired-name list** matched alongside the current one | `Get-RetiredRepoNames` |
| `agent-shared/` (2x) | **no name-dependence at all** -- read the manifest instead | `plugin-tree-lib.ps1` |

**No equivalent resolver exists for these four filenames.** What exists is a scatter of independently
anchored globs and regexes across thirteen sites -- exactly the shape `Resolve-BranchFilePath`'s own
docstring warns about, where one convention was recognised by two different rules until they disagreed.

And #1698 adds the round rule: if any other rename is ever going to happen, do it in the same round --
two rounds pay the consumer migration twice.

#### Dave's two decisions, September 19, 2026

1. **The lens convention is renamed and all six consumers migrate.** Not a permanent dual-name state
   and not a dropped convention 4: the round ends with one convention everywhere. The dual-name readers
   from PR-A are the bridge, so nothing breaks on release day and each consumer repo does its own
   `git mv` when it suits; the old names are retired once the connector register shows all six are over.
2. **No persona compatibility shim.** The six consumers' `SPECIALISTS.md` import lines are updated by
   hand instead.

**The second decision reorders the sequence, and that is its whole cost.** The shim was what made the
persona rename safe at any moment; without it, that rename is the one step in the round that breaks
outside every version gate, silently, for any consumer whose marketplace clone advances before their
`SPECIALISTS.md` is edited. So it moves to **last**, and the manual consumer update follows it
immediately rather than at the end of the round. Everything before it is release-gated and can land at
any pace.

#### The plan: one release round, six sequenced PRs

Each PR leaves the lint gate green on its own, which is what makes the sequence reviewable. All six
land before a single release cut, so consumers migrate once.

- **PR-A -- the readers learn both names.** Add the dual-name layer (a `Resolve-SpecialistFilePath`
  resolver, or a retired-pattern list, per the prior art) to all thirteen reader sites and their
  mirrors. **Renames nothing**, so it is a no-op against today's tree and provably safe. This must
  exist before any file moves, and it is what lets a consumer's old-named lenses keep working. Fix the
  lookbehind (hazard 2) here.
- **PR-B -- subagent defs** (26 files) + the four `plugin.json` `agents` arrays + references. The
  manifest arrays are the highest-consequence edit in the round (#1764).
- **PR-C -- manuals** (27 files) + references.
- **PR-D -- this repo's own 30 lenses** + the roster table in `SPECIALISTS.md` + the lens key in
  `always-on-baseline.json`.
- **PR-E -- the migration documentation**, which lands **before** the persona rename so the
  instructions exist when the window opens: an `INSTALL.md` section (the third of its kind), the
  consumer-side `git mv` for the lenses, and the exact `SPECIALISTS.md` import line to replace.
- **PR-F -- the four personas** + the persona key in `always-on-baseline.json`. **Last, deliberately.**
  The moment this merges to `main`, every consumer that refreshes its marketplace clone before its
  `SPECIALISTS.md` is edited loses Chris's body with no diagnostic. The six manual consumer updates
  follow this merge immediately; treat them as part of the same act rather than as follow-up work.

**Two ordering constraints outside the sequence:**

- **PR #2129 lands first.** It is open now and edits `01-01-extension.md` and `05-05-extension.md` --
  two files PR-D renames. Merging it afterwards means resolving the rename by hand.
- **#1757's check runs before each of B through E merges.** Git's rename detection moves files cleanly
  and says nothing about retired names inside the lines a branch *adds*, so the added-lines grep from
  that issue is run against each branch before it merges.

### CREATE

- [x] Research the machinery that resolves the four conventions, and the consumer propagation reach
- [x] Measure what Claude Code does with a dead `@`-import, since the behaviour is undocumented
- [x] Verify the sharpest claims against the tree rather than taking the reports at face value
- [x] Write the step plan into this document
- [x] Put the two open decisions to Dave, and record his answers here
- [x] File the follow-up issues for the sequenced steps once the decisions are in -- #2130 … #2135
- [x] Give the plan a durable home: a comment on #2128, since this document is removed at the fold
- [x] Record the measured lesson in the system-administration lens, beside the clone-channel measurements
- [x] Correct lint check 28's wording, which the measurement showed to be wrong on one detail

### TEST

- [x] Lint gate + all suites green before the PR

### DEPLOY: feat/2128-specialist-file-prefix

That a dead `@`-import is silent has been this repo's position since #874 and is why lint check 28
exists. It had never been measured, upstream documents none of it, and the #2128 rename plan turned on
it -- so it was measured in an isolated checkout. The silence is confirmed and total: the rest of the
file loads, and nothing is reported on stdout, on stderr, or under `--debug`.

**One detail of check 28's own wording turned out to be wrong**, in all three places it appears: it says
Claude Code *drops* the import, and the line is not dropped -- the raw `@path` survives in context as
inert text. That is worse rather than merely different, because the document is gone while something
that still looks like its import is sitting there. The wording is corrected.

It lands in the system-administration lens, beside the clone-versus-cache measurements it belongs with,
and **not** in `CLAUDE.md`. That was the first attempt, and the always-on budget gate refused it: the
path is already 9,380 B over its ceiling, so it may not grow, and evidence for a decision is exactly
what that gate says belongs in the owning specialist's lens. `CLAUDE.md` already points there for this
subject, so it needed no edit at all.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here ships to a consumer. The paragraph lands in this repo's own governance document, and
the rename it was measured for has not started; its six steps are #2130 through #2135.

**Score:** N/A

#### Pull Request

A specialist- prefix on every specialist file, and one suffix per kind
