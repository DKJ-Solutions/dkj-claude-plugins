## docs/remove-four-readmes

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

Continue removing READMEs that nobody reads and no session needs (after #2356). Four were picked on
inbound-link count; on reading, three qualify and one does not.

#### Scope decision

- **In:** `assets/avatars/README.md`, `plugins/README.md`, `plugins/dkj-subagents/subagent-shared/README.md`.
- **Out: `plugins/dkj-subagents/dkj-subagents-shopify/README.md`.** It is the only consumer-facing
  statement of the `Get-Shopify*` seams and of the live-theme guard's design, it travels in the plugin
  cache, and `adopt-shopify-floor`'s skill page links into it. Removing it means rehousing it into the
  skill pages, which is a separate piece of work.

### CREATE

- [x] `plugins/README.md` removed; everything on it was already in the root README's *Teams and
  workflows* section. The three pages that pointed at it (root README, `plugins/dkj-subagents/README.md`,
  `plugins/dkj-policy/README.md`) now point at that section.
- [x] `assets/avatars/README.md` removed; the root README's repo layout already says why the folder sits
  at the root and how it reaches every machine. The account table is dropped.
- [x] `subagent-shared/README.md` removed. The mechanism is already in the root README's *Shared
  agent-def blocks*; the adding-a-block steps and the four width decisions (BEGIN line, `filecontent-boundary`,
  `lens-optional`, `working-copy-boundary`) moved to Ravi's lens, *Why each circle is the width it is*. The
  lint's `[tool-block]` refusal, one test comment and Sylvester's lens now point there.

### TEST

- [x] Lint and test gates via `open-pr`.

### DEPLOY: docs/remove-four-readmes

Removed three READMEs nothing reads: `plugins/README.md` and `assets/avatars/README.md` duplicated
the root README, and the width decisions on `plugins/dkj-subagents/subagent-shared/README.md` now live in
[Ravi's lens](../.claude/specialists/lenses/specialist-06-24-lens.md#why-each-circle-is-the-width-it-is),
where the lint's `[tool-block]` refusal points.

**Score:** 1 -- prevents a reader following the lint's printed pointer, or a link, to a page that no
longer exists.

#### What makes this deploy extra special

Nothing reaches a subscriber: the only plugin-visible change is one sentence in `dkj-policy`'s README.

**Score:** N/A

#### Pull Request

Remove three READMEs nothing needs

