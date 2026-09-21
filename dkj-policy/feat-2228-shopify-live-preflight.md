## feat/2228-shopify-live-preflight

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

Give a Shopify store repo one shared step between a merged trunk and a live theme push: derive the push list mechanically, run the gates, verify the live theme, hand that list to the drift check as an array, take the verified backup, and print the push command without the authorisation marker. It verifies and reports; it never pushes and never writes the marker. Resolves #2228.

#### What was verified before any of it was built

The report's own claims were held against the tree first, the way an inbound item is picked up here.
Three held and one did not:

- **The gap is real.** `dkj-subagents-shopify` ships `push-preview`, `sync-main`, `backup-live-theme`,
  `archive-theme`, `sweep-preview-themes`, `adopt-shopify-floor`; every one of them sits before the
  merge or after the push. Nothing stood at the push.
- **The seams it names exist.** `Get-ShopifyLiveThemeId`, `Get-ShopifyLivePushMarker`,
  `Get-ShopifyTrunkIsLive`, `Get-ShopifyThemeEstateStore` and `Get-ChangelogPath` are all in the tree
  -- the push marker in `hooks/guard-live-theme.ps1`, the rest in the task scripts.
- **The eight theme directories already existed**, as a local `$ThemeDirs` literal on one line of
  `sync-main.ps1` -- so the preflight would have been a second copy of them.
- **"It would introduce no new seam" did NOT hold**, and the exception is named rather than smuggled
  in. Every *fact* it needs exists; what does not is the *path* of the consumer's drift check, because
  that script is still consumer-side. `Get-ShopifyDriftCheckPath` is therefore optional with a
  conventional default, and documented as a bridge that stops having a job the day `live-snapshot.ps1`
  moves up here.

#### What was deliberately NOT done, and why

- **`live-snapshot.ps1` was not moved up.** #2228 calls it "a strong candidate to move in the same
  release", and it lives in `smartwatchbanden`, which this session cannot reach -- so the honest
  answer is a documented seam to it rather than a rewrite of a file nobody here has read. The move
  stays available as its own piece of work.
- **The bump rule was not restated.** Which bump a pending set earns is one rule, owned by the release
  workflow. Step 4 *calls* it where the repo has a local copy and says it could not read otherwise; a
  second copy inside a Shopify plugin would be free to drift from the gate that enforces it.

### CREATE

- [x] `scripts/lib/live-push-rules.ps1` -- the pure rules: the eight theme directories, the push-list
      classification, the numeric release-tag pick, the push command, the verdict fold.
- [x] `scripts/task/live-preflight.ps1` -- the nine-step run, cost-ordered so the eight-minute backup
      is last of the acting steps.
- [x] `scripts/task/sync-main.ps1` -- `$ThemeDirs` now reads `Get-ShopifyThemeDirectoryNames` instead
      of carrying its own literal, so the eight are one definition.
- [x] `scripts/task/backup-live-theme.ps1` -- the synopsis restated in terms of what it GUARANTEES
      rather than where it is called from, both moments named with the trade-off, `-DryRun` documented
      as a first-class preflight caller, and the closing line stops asserting one of the two readings.
      No behavioural change: `CREATE -> VERIFY -> ROTATE` is verbatim.
- [x] `scripts/lib/shared-scripts-lib.ps1` -- two registry entries, so both new files travel in
      `dkj-subagents-shopify`'s payload; mirrors regenerated with `build-shared-scripts.ps1`.
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/skills/live-preflight/SKILL.md` -- the page, with
      every parameter documented (the skill-param gate holds it to that).
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/README.md` -- the preflight's seam table, and why
      it reads no marker at all.
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/skills/theme-lifecycle/SKILL.md` -- the backup is
      no longer described as the closing step of a cut in a page that now has two callers.
- [x] `README.md` -- `live-preflight` added to both canonical skill-list spans.

### TEST

- [x] `scripts/tests/live-push-rules.tests.ps1` -- 57 asserts, weighted towards the negative cases:
      the paths that must not be pushed, the tag that must not win, the empty list that must not
      become a command, the step state that must not read as a pass.
- [x] The suite asserts that `sync-main.ps1` no longer carries its own copy of the eight directories.
      The whole argument for moving the set was that two copies drift; a suite that did not check the
      second site would leave exactly the drift it was meant to prevent.
- [x] `check-plugin-integrity.ps1` -- green, 0 errors. It caught two real findings on the first run
      (both canonical skill-list spans in the root README missing the new skill), which were fixed.
- [x] The full test gate -- every `scripts/tests/*.tests.ps1`.

#### What is deliberately not driven

`live-preflight.ps1` itself, for the reason `push-preview.ps1` and `backup-live-theme.ps1` give: every
path in it reaches git, the Shopify CLI against a real store, or a consumer's `repo-config.ps1`, and a
suite must not be able to reach a store. That is exactly why everything judgeable without a network was
put in the lib. Unpinned as a result: the ordering of the nine steps and the git derivation of sync
provenance.

### DEPLOY: feat/2228-shopify-live-preflight

`dkj-subagents-shopify` had nothing standing between a merged trunk and a live theme push. Everything
it shipped sat before the merge (`push-preview`, `sync-main`) or after the push (`backup-live-theme`,
`archive-theme`, `sweep-preview-themes`), so the one moment in the cycle where a mistake is visible to
paying customers was assembled by hand, per release, from prose. `live-preflight.ps1` is that step: it
verifies the trunk, runs the repo's own gates, derives the push list from the range instead of from the
changelog, reports what the pending entries owe, checks the live theme by id *and* by role, hands the
list to the drift check **as an array**, takes one verified backup as the rollback point, prints the
push command, and previews the aftercare. It verifies and reports -- it never runs `shopify theme push`
and never writes the authorisation marker, both by construction rather than by discipline. The eight
theme directories stopped being a literal in `sync-main.ps1` and became one definition both scripts
read. `backup-live-theme.ps1` gained no behaviour and lost a sentence: its header stated one caller's
choice as a property of the script, and now states what it guarantees.

**Score:** 2

#### What makes this deploy extra special

A Shopify store repo gets the step its release day was missing, and notices it the next time it ships.
Two hand-assembly failures that had already cost that store something are now closed in code rather
than in prose: deriving the push list, where 61 changed files held 11 that exist on a theme and the
other 50 do not -- their own `CLAUDE.md` warns about it in words, which is what a rule looks like when
nothing enforces it -- and passing that list on, where a `powershell -File` call flattened it into one
string, snapshotted zero files, printed a green "safe to push", and left a release with no rollback
artefact and nothing saying so. The backup they already had now runs *before* the push where they want
it there, which turns it from a baseline of what shipped into a rollback point -- worth having because
a Shopify push is per file, has no locking, and can arrive partially, so a backup taken afterwards has
captured the broken state. Nothing about the backup's own mechanism moved. It arrives on the next
plugin update; a repo that answers no new seam still gets every step except the drift check, which
says out loud that it could not run rather than passing.

**Score:** 4

#### Pull Request

A live-push preflight for dkj-subagents-shopify
