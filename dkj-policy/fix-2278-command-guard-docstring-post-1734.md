## fix/2278-command-guard-docstring-post-1734

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

#### What was verified before anything was written

The report's symptom, reason and proposed repair all still stand, checked against the tree rather
than taken from the issue:

- `#1734` is CLOSED (September 9, 2026) and its work landed.
- `plugins/dkj-subagents/dkj-subagents-shopify/hooks/guard-live-theme.ps1` dot-sources this lib and
  says so in its own header (`AND THE MACHINERY ABOVE NO LONGER LIVES IN THIS FILE`).
- `scripts/lib/shared-scripts-lib.ps1` carries the second registry entry,
  `command-guard-lib-shopify`, and its neighbour reads the old copy as historical.

One thing the report did not name, found in the same paragraph and repaired with it: the sentence
directly above it still said **"The twin under plugins/dkj-policy/scripts/lib/ is its released
mirror"**. That second mirror is exactly what #1734 added, so the singular is the same staleness one
sentence up -- there are three identical copies now, and the drift lint holds all three.

### CREATE

- [x] Rewrite the passage in the past tense, keeping the reasoning: #1669 extracted the lib and left
      the copy standing for a stated reason, #1734 took the second-mirror route and retired it.
- [x] Correct "the twin ... is its released mirror" to name both mirrors.
- [x] `scripts/sync/build-shared-scripts.ps1` -- both mirrors updated from the source copy.

### TEST

- [x] The file is still pure ASCII (repo convention for `.ps1`) and the docstring is still one
      comment block.
- [x] `check-plugin-integrity.ps1` and the suites, via `open-pr.ps1`'s gate -- including the
      shared-scripts drift lint, which is what proves the two mirrors match the source.

### DEPLOY: fix/2278-command-guard-docstring-post-1734

`command-guard-lib.ps1`'s docstring described the arrangement #1734 replaced. It told a reader of a
security-relevant lib that `guard-live-theme` **still** carries its own copy of this logic, which may
have drifted -- exactly the hazard #1734 removed -- and pointed at #1734 as an open filing. A reader
acting on it would go hunting for a second copy to reconcile, or decline to change this file on the
ground that a divergent twin exists. The passage is now in the past tense, the way
`guard-live-theme.ps1`'s own header already reads it, and it names where the route landed: the
`command-guard-lib-shopify` registry entry and the `$PSScriptRoot`-relative dot-source. The
reasoning behind the deferral is kept, because it is what the `-TextTools` parameterisation rests on.
The sentence above it was stale in the same way and is repaired with it -- one mirror named where
there are two, the second being the one #1734 created.

**Score:** 2

#### What makes this deploy extra special

N/A -- a docstring in an internal lib. Nothing a subscriber of a service reaches, and nothing about
what any script does.

**Score:** N/A

#### Pull Request

command-guard-lib.ps1's docstring describes the arrangement #1734 replaced
