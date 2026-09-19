## docs/2137-subagent-def-term

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

Dave's decision on #2137, September 19, 2026, taken from a three-option menu: **correct-on-edit**, not
a sweep. `subagent def` is the term for new writing; the 270 existing occurrences across 87 markdown
files are corrected when a file is edited for other reasons. That is the answer `CLAUDE.md` already
gives for the ~830 stale repo-name citations left by the September 10 rename, applied one noun over.

#### What this branch deliberately does NOT do

- **No sweep** -- not of the 270 markdown occurrences, and not of the 195 `.ps1` lines. A diff no gate
  reads, landing mid-way through a six-PR round whose reviewability is its stated design property
  (#2128), is the thing the chosen option rejects.
- **No path edits.** `feat/2131-subagent-def-filenames` is open under another account and owns every
  `*-agent.md` path -- including three lines in `README.md` and one in `plugins/dkj-subagents/README.md`
  that this branch also touches. This branch takes the **noun** on those lines and nothing else, so
  whichever of the two merges second resolves one word per line.
- **No `## Shared agent-def blocks` rename.** That heading carries five inbound anchors, one of them on
  the always-on path (`.claude/specialists/SPECIALISTS.md`). Correct-on-edit is exactly what that case
  is for.

#### The boundary, stated once so a later reader does not re-open it

The word `agent` stays wherever it is **read** rather than **spoken**: the `"agents"` key in all four
`plugin.json` manifests is Claude Code's own schema, and `scripts/agents/build-agent-defs.ps1` is a
path the tooling resolves.

### CREATE

- [x] Record the rule in the portable layer -- the technical writer's manual, beside the language convention
- [x] State the term and its boundary in `README.md`, where a reader meets the word
- [x] Repair the noun in the places where the contradiction stands on the line itself

### TEST

- [x] Lint gate green (`check-plugin-integrity.ps1`), its dead-link scan included
- [x] All suites green (118/118, 61 min)

### DEPLOY: docs/2137-subagent-def-term

Three renames moved the thing and left the noun: `agents/` became `subagents/` (#1698), the plugins
became `dkj-subagents-*`, and the defs themselves became `specialist-NN-NN-subagent.md` while this
branch was open (#2131, landed as #2147) -- while 270 occurrences across 87 markdown files still
said *agent def*, and `README.md` called the same file *"the agent definition"* two directories away
from `plugins/dkj-subagents/README.md` calling it *"the subagent definition"*.

**`subagent def` is now the term, and the 270 stale ones are corrected on edit rather than swept**
(Dave, September 19, 2026). That is the answer `CLAUDE.md` already gives for the ~830 repo-name
citations left by the September 10 rename, applied one noun over: both spellings read correctly, so
nothing is broken, and a sweep would buy consistency at the price of a diff no gate reads and nobody
can review -- landing mid-way through a six-PR round whose reviewability is its stated design
property.

The rule is portable and lives in the technical writer's manual, so it travels to every consuming
repo and applies to the next rename rather than only to this one. `README.md` now states the term and
its boundary where a reader meets the word, and the places where the contradiction stood **on the
line itself** are repaired: the section heading that defines the term, the bullet naming the file, and
the sentence that says which of the two is leading.

**The boundary is stated rather than left to a reader's judgement:** the word `agent` stays wherever
something *resolves* it instead of reading it -- the `"agents"` key in all four `plugin.json`
manifests is Claude Code's own schema, and `scripts/agents/build-agent-defs.ps1` is a path the
tooling reads. #1764 is what a wrong shape in those manifests costs: four of six plugins
uninstallable for a whole release.

**Score:** 3

#### What makes this deploy extra special

A consumer's technical writer gets the rule for every rename, not this one: new writing takes the new
noun, existing occurrences are corrected on edit, anything a machine resolves is out of scope, and
prose that contradicts itself on its own line is repaired at once rather than left to drift. Read on
demand from the manual, so it costs no always-on context.

**Score:** 2

#### Pull Request

Record 'subagent def' as the term for new writing, and repair the prose that contradicts the filename on its own line
