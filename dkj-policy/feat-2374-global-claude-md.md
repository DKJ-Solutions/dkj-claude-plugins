## feat/2374-global-claude-md

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

A consumer's own CLAUDE.md keeps contradicting the plugin, so the governance moves into one CLAUDE.md the dkj-policy plugin ships (plus a dkj-policy-bwj extension), and a consumer's CLAUDE.md shrinks to the import.

#### Decisions (Dave, September 23, 2026)

- ~~A consumer's `CLAUDE.md` keeps a short repo block of **facts** below the import -- trunk, public or
  not, owner, purpose -- and no rules.~~ **Superseded, same day, during a sweep.** A `CLAUDE.md` holds
  **only** `@`-import lines -- the dkj-policy constitution, plus the dkj-policy-bwj extension where
  installed, plus any other plugin import. Everything repo-specific -- including the facts the first
  version of this decision still allowed below the import -- moves to the specialists' lenses or an
  unscoped `.claude/rules/<name>.md`. This source repo gets the same treatment: its whole former repo
  slot moves to `.claude/rules/this-repo.md`, and root `CLAUDE.md` shrinks to a one-line title plus the
  three imports.
- The source repo runs the same model: its constitution moved into the plugin, and its repo-specific
  facts and mechanics now live in `.claude/rules/this-repo.md` rather than in a repo slot inside
  `CLAUDE.md` itself.

### CREATE

- [x] `plugins/dkj-policy/CLAUDE.md`: the constitution and the general working practices, moved out
  of the root `CLAUDE.md` and made repo-neutral ("the owner" where it named Dave). The old text's
  contradiction -- "a PR always waits for Dave's explicit word" beside the no-waiting default -- is
  resolved in the move.
- [x] `plugins/dkj-policy/dkj-policy-bwj/CLAUDE.md`: the BWJ extension, pointers to its four chapters
  only, extending and never overriding.
- [x] Root `CLAUDE.md`: both imported by relative path (the source's own branch copy, measurable in
  CI); the repo slot's "holds on its own" and "top half" statements rewritten.
- [x] 14 links into the moved sections repointed, plus two dead anchors the lint found (an archived
  release note, Tessa's lens).
- [x] `CONTRIBUTING-portable.md`: the plugin's `CLAUDE.md` joins the top rung, and the safety rules
  leave the "not legislated here" list.
- [x] `consumer-prose-sessioncheck`: a `[WARNING]` with the paste-ready line, for the consumer's own
  marketplace name, wherever a consumer's `CLAUDE.md` does not import the constitution. The exit code
  and the two existing detectors are untouched.
- [x] `specialists-init` scaffold: the second prose line asks for facts instead of "governance and
  safety rules"; the old literal stays in `Legacy` so the teardown still recognises it.
- [x] `adopt-dkj-policy` (new Part 1 subsection) and `adopt-dkj-policy-bwj` step 6: the import lines.
- [x] Superseding pass: root `CLAUDE.md` reduced to a one-line title plus the three `@`-imports, no
  prose left at all.
- [x] `.claude/rules/this-repo.md` created (new, unscoped, no `paths:` frontmatter): the whole former
  repo slot moved in, with the owner fact and the relative-vs-absolute import fact added at the top,
  and every relative link inside it rewritten to resolve from `.claude/rules/`.
- [x] Every anchor into the moved root `CLAUDE.md` sections repointed across the tree (grepped on
  `CLAUDE.md#`): `.claude/rules/language-layers.md`, `SECURITY.md`, `.claude/skills/triage-inbound/SKILL.md`,
  `.claude/specialists/README.md` (3), `.claude/specialists/SPECIALISTS.md` (1),
  `.claude/specialists/lenses/specialist-01-01-lens.md`, `-06-25-lens.md` (2), `-06-16-lens.md` (2),
  `-05-15-lens.md` (1), `-05-06-lens.md` (2), plus the external GitHub blob URL in
  `plugins/dkj-policy/DEVELOPMENT-portable.md`. `plugins/dkj-policy/CLAUDE.md#safety-rules` anchors were
  left untouched -- that file did not move.
- [x] `plugins/dkj-policy/CLAUDE.md`, `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md` and
  `plugins/dkj-policy/CONTRIBUTING-portable.md` (3 spots): "facts below the import" reworded to
  "imports-only, facts in an unscoped rule or a specialist's lens" throughout.
  `dkj-policy-bwj`'s own `CLAUDE.md` and its adopt skill's step 6 already only described the import
  line and needed no change.
- [x] `dkj-subagents-alpha`'s `specialists-init` skill, step 3: now branches on whether `dkj-policy` is
  also installed, since that step predates #2374 and used to tell every consumer to hand-write safety
  rules straight into `CLAUDE.md`.

### TEST

- [x] Review: Victor (no correctness defects; the ERROR+WARNING combination is now asserted), Edith
  (four wording fixes, incl. a stale `CLAUDE.md#safety-rules` pointer in the lens scaffold), Sebastian
  (the marketplace name is now slug-only before it reaches session context).
- [x] `consumer-prose-gate.tests.ps1`: 102/102, including the new constitution-import cases (warning
  and exit 0 without the line, silence with an unresolved absolute line, the marketplace name read
  off a cache-shaped path, the hook forwarding the warning).
- [x] `teardown.tests.ps1`: the legacy scaffold line is still recognised, and a fresh bootstrap never
  writes it.
- [x] `check-plugin-integrity.ps1`: 0 errors. `check-always-on-budget.ps1`: the path shrank by
  2,307 B (110,314 -> 108,007).
- [x] Re-run the lint and test gates after the imports-only rework: `check-plugin-integrity.ps1` 0
  errors; consumer-prose-gate 122/122, measure-always-on 85/85, teardown 245/245, always-on-budget
  135/135; `build-shared-scripts.ps1 -Check` in sync. The always-on walk now counts unscoped
  `.claude/rules/*.md` (it was blind to them, so the move first read as a false 37 KB shrink); the
  honest delta is a small shrink against the 108,023 B baseline.
- [x] Review of the rework: Victor (root-prose detector: comment close by containment, column-0
  imports, one leading H1 -- fixed and pinned), Sebastian (only an unindented `paths:` scopes a rule --
  fixed and pinned), Edith (two stale "below" references in the moved text -- fixed).

### DEPLOY: feat/2374-global-claude-md

The rules a repo runs under now ship with `dkj-policy` itself: one [`CLAUDE.md`](../plugins/dkj-policy/CLAUDE.md)
holding the constitution and the general working practices, plus a
[`dkj-policy-bwj` extension](../plugins/dkj-policy/dkj-policy-bwj/CLAUDE.md) for the BWJ repos. A
consumer's own `CLAUDE.md` now holds **only** the `@`-import line(s) and nothing else -- no rules, no
facts, no repo block. A repo's own facts (trunk, public or not, owner, purpose) move to an unscoped
rule such as `.claude/rules/<name>.md`, loaded every session exactly as `CLAUDE.md` was; a fact that
belongs to one specialist alone moves to that specialist's own lens. The
`consumer-prose-sessioncheck` hook warns at session start where the import line is missing and prints
it for the consumer's own marketplace name; the `specialists-init` scaffold stops inviting a local
constitution. This repo runs the same model, one step further than the branch's original plan: its
constitution moved into the plugin, and its former repo slot -- everything specific to this repo that
used to sit inside `CLAUDE.md` -- moved whole into `.claude/rules/this-repo.md`. Root `CLAUDE.md` is
now a one-line title plus the three `@`-imports, and nothing else.

**Score:** 4

#### What makes this deploy extra special

N/A -- a repo-governance change; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

One global CLAUDE.md shipped by dkj-policy, imported by consumers

