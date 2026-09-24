## fix/2426-init-own-payload-subagents

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

Resolve the running plugin's own subagents/ from its own root before any cached version, and print a notice when an agents directory yields zero recognised defs

### CREATE

- [x] `Get-PluginAgentsDir` in `bootstrap.ps1`: for the running plugin itself (`$PluginName -eq
      (Get-OwnPluginName $OwnPluginRoot)`), resolve `subagents/` (then legacy `agents/`) directly
      under `$OwnPluginRoot`, before the parent-based sibling probe and the market-wide
      highest-cached-version fallback. Both layouts (source: `$OwnPluginRoot` is the plugin dir
      itself; cache: `$OwnPluginRoot` is `.../<plugin>/<version>`) resolve correctly through this
      one direct check. Every other plugin keeps the untouched cross-plugin resolution.
- [x] Scaffold loop in `bootstrap.ps1`: count RECOGNISED subagent defs (files that produced a
      `$defId`), not enumerated files, per plugin; when an agents directory was found but yields
      zero recognised defs, print a `[notice]` (Yellow) naming the plugin, the resolved directory,
      and what was searched for -- both `Get-SpecialistFileId`/`Get-SpecialistFiles`'s two known
      spellings (`specialist-<g>-<i>-subagent.md`, legacy `<g>-<i>-agent.md`) and the fallback
      `*-agent.md` filter used without that lib.
- [x] Tycho: regression test covering half 1 -- a consumer whose cache holds the OWN plugin at an
      older version alongside a higher-numbered cached version of the same plugin (a stale running
      payload), asserting `Get-PluginAgentsDir`/the bootstrap resolves the running version's own
      `subagents/`, not the highest-numbered cache.
- [x] Tycho: regression test covering half 2 -- an agents directory that exists but whose file
      names match neither known spelling, asserting the `[notice]` fires exactly once, names the
      plugin and the directory, and that the closing counts stay honest (no scaffold created).
- [x] Victor: code review of both `bootstrap.ps1` changes (correctness of the own-plugin equality
      check in both layouts, the recognised-vs-enumerated count, wording of the new notice). Sound;
      independently reproduced 3 red asserts on the pre-fix code. The one in-branch finding -- the
      test comment naming a different verification method than the one used -- is corrected.

### TEST

Added two cases to `scripts/tests/bootstrap-drift.tests.ps1` ("own-plugin dual-version cache: the
RUNNING payload wins, not the highest" and "an agents directory that recognises nothing prints a
`[notice]`"). Ran the full suite: **212/212 asserts pass** on the fixed `bootstrap.ps1`. Both new
cases were confirmed to fail against the pre-fix code: reproduced via a throwaway fixture copy built
from `git show HEAD:.../bootstrap.ps1` (never touching the tracked working tree), where the own-plugin
scaffold came from the wrong (higher-numbered, non-running) cached version and the `[notice]` never
printed -- `git diff` on `bootstrap.ps1` confirmed Sylvester's fix was untouched throughout.

### DEPLOY: fix/2426-init-own-payload-subagents

`specialists-init` reads the subagent definitions of the payload that is actually running, rather than those
of the highest version in the plugin cache, and says so when a directory it found holds no definition it
recognises. Prevents a stale payload from scaffolding zero subagent lenses behind a closing count that read
as a clean result (#2426).

**Score:** 2

#### What makes this deploy extra special

A consumer running `specialists-init` from an older installed payload than the newest one cached now gets a
lens for every subagent it enables, instead of none and no word about it; where a directory still yields
nothing, a notice names the directory and what was looked for.

**Score:** 2

#### Pull Request

specialists-init reads its own payload's subagents and says when a found directory yields none

