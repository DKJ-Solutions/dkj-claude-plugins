## fix/2733-xoxo-connector-ids-flip-back

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Inbound #2733: `connectors/xoxowildhearts.json` still registered the five plugin ids as
`@claude-code-specialists`, the state #1906 wrote deliberately while the consumer had not migrated, and
said might flip back. Verified before repairing: the consumer's `origin/main` (58986cd, 2026-10-02)
enables all five as `@dkj-claude-plugins` since 71f112f (2026-09-13), so decision A's precondition
holds and the register follows its consumer.

### CREATE

- [x] Rewrite the five ids in `connectors/xoxowildhearts.json` to `@dkj-claude-plugins`
- [x] Append a dated `FLIPPED BACK 2026-10-03 (#2733)` paragraph to its `notes`, per #952 leaving the
  earlier sentences in the names they were written with

### TEST

- [x] The manifest parses, and lists the five `@dkj-claude-plugins` ids
- [x] `check-connectors.ps1` on this machine: the five false `is NOT (or no longer) enabled` errors and
  the `[UNLISTED]` line for xoxowildhearts are gone; the remaining lines for it are genuine (a machine
  record behind the source, and two unpinned CI refs)

### DEPLOY: fix/2733-xoxo-connector-ids-flip-back

The consumer register named five plugin ids the `xoxowildhearts` consumer stopped enabling on
September 13, so every session start in this repo printed five `[ERROR]`s claiming plugins that are
enabled were not -- and hid the real ids behind an `[UNLISTED]` line. The ids now match what the
consumer enables, and those false errors are gone.

**Score:** 2

#### What makes this deploy extra special

It is the flip-back the #1906 note predicted, taken on the evidence that note asked for: the consumer
itself migrated, measured on its `main`, so the register follows it rather than churning.

**Score:** 1

#### Pull Request

connectors/xoxowildhearts.json: plugin ids back to @dkj-claude-plugins (#1906 flip-back)
