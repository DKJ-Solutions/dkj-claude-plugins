## fix/1906-xoxowildhearts-plugin-ids

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

#### What this branch does

`connectors/xoxowildhearts.json` registered five plugin ids suffixed `@dkj-claude-plugins`. That was
measured on 2026-09-11 (#1769) against `BWJ-ecommerce/xoxowildhearts` -- the repo #1902 has since
established is the abandoned one. The live repo, `BWJ-Development/xoxowildhearts`, enables all five as
`@claude-code-specialists`. This branch writes what the consumer HAS, per decision A (Dave, 2026-09-10).

#### Why it is not deferred behind #1905

#1906 as filed concluded "#1905 first" -- if the consumer migrates, the current value becomes correct
on its own, so writing the retired name would record a state about to change (the 2026-08-20 precedent
in this manifest's own notes). That precedent's condition is an **in-flight consumer branch**, and
there is none: #1905 is filed in THIS repo, so the consumer has not seen it; the repo-slug redirect
still resolves, so their installs are functional and nothing forces a migration; and their PR #212
(merged 2026-09-13T04:40Z) redid the `dkj-subagents-*` family rename by hand on the live repo while
leaving the marketplace name alone. Decision A governs instead. Dave's call, this session.

#### Scope

The `repo` field is NOT touched -- #1902 landed it on `main` at 483b1a3b while this issue was being
read. This branch is the second field of that same fact, and nothing else here is re-checked.

### CREATE

- [x] The five plugin ids read `@claude-code-specialists`
- [x] A dated `CORRECTED 2026-09-13 (#1906)` note recording the measurement, the direction, the three
      whole-id match sites it would have cost, and that this may flip back if #1905 is carried across
- [x] The 2026-09-11 `MIGRATED` note is corrected in place by that new sentence rather than rewritten,
      per #952 -- it keeps the wording it was measured with

### TEST

- [x] The manifest still parses as JSON (asserted in the edit itself, before writing)
- [x] `check-plugin-integrity.ps1` + all suites green
- [x] `check-connectors.ps1` -- this consumer's block is a `[SKIP]` on this machine (no `localCheckout`
      resolves), so the change is latent here by design and cannot be exercised end to end

### DEPLOY: fix/1906-xoxowildhearts-plugin-ids

The consumer register recorded five plugin ids the live `xoxowildhearts` repo does not enable. They
were measured against the repo it replaced, so `check-connectors` would have reported five false
`[ERROR]`s reading "is NOT (or no longer) enabled" about five plugins that are enabled -- and the
unlisted-plugin check would have skipped all five as a third-party catalogue, staying silent on
exactly what it was built to catch. Latent only because no machine currently holds that checkout.

**Score:** 2

#### What makes this deploy extra special

It is the second field of one fact -- the consumer moved repositories -- and the half that decides
which way a register follows a consumer that has NOT migrated. Decision A says the register records
what a consumer has, so this writes the retired marketplace name deliberately, and says in the file
that it may flip back.

**Score:** 2

#### Pull Request

connectors/xoxowildhearts.json records the plugin ids the live consumer actually enables
