## fix/2459-update-plugins-user-shadow

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

Resolves #2459. `Get-PluginUpdateScope` answers one scope per plugin and prefers the checkout's own
record, so a path-less `user` record beside it was never updated. Step 2 now adds it as a second target.

### CREATE

- [x] `update-plugins.ps1` (root + plugin mirror): collect the path-less `user` records beside a checkout record, update them in step 2 and print them under `-DryRun`; the summary counts them separately
- [x] `update-plugins` SKILL.md: say why one scope per plugin was not enough

### TEST

- [x] `update-plugins.tests.ps1` scenarios 12 (both records updated, `managed` left alone, summary) and 13 (`-DryRun`): 73 pass, 0 fail

### DEPLOY: fix/2459-update-plugins-user-shadow

`update-plugins` now also updates a plugin's path-less user-scope record when that record sits beside
this checkout's own. Until now one run moved the checkout's records and left those behind, so its own
receipt reported them behind (a session can load the older one, #2442) while its summary said
`0 failed`. Measured on v5.7.0 -> v5.8.0: 5 of 7 plugins behind straight after the run, closed by hand
with five `--scope user` commands. The extra update is not gated on the version, because both records
matched before the run. A path-less `managed` record is left alone.

Tier 0 is scored for a session that runs `update-plugins` on a machine carrying such a shadow.

**Score:** 3

#### What makes this deploy extra special

N/A. It is a maintenance script and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

update-plugins also updates the path-less user-scope shadow

