## feat/2788-rename-policy-extensions

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

Rename the two dkj-policy extensions after their organisation (Dave, October 4, 2026): `dkj-policy-bwj`
becomes `bwj-development` and `dkj-policy-dkjs` becomes `dkj-solutions`. Without the shared prefix an
extension is recognised by a list instead (`Get-PolicyExtensionList`), and a consumer still on an old name
gets a migration path for its retired id and its import line.

### CREATE

- [x] Move both plugin folders, the `adopt-bwj-development` skill and the bwj suite, and replace the old names across the tree (not in connector registers, which record what a consumer has, nor in archived release-note text)
- [x] `claude-md-import-lib.ps1`: the extension list, the retired-name map, `Get-RetiredExtensionImports`, and `Add-ClaudeMdImportLine -ReplacePattern`, mirrored to both plugins
- [x] The adopters rewrite a retired import line in place; `check-consumer-prose` warns on a retired id and a retired import line
- [x] `check-plugin-integrity`'s plugin-kind check classifies a listed extension and holds it to `plugins/dkj-policy/`
- [x] Repoint archived release-note link targets to the new folders, keeping their text
- [x] Restore the two rename-history lines the bulk replace rewrote
- [x] Prose: the adopt-dkj-policy skill, CONTRIBUTING-portable and the scripts README name the new rule; ADOPTION.md gives consumers the three-step migration

### TEST

- [x] `bwj-extension-import.tests.ps1`: the list equals the plugin folders, retired ids map, a retired line is rewritten in place with its CRLF kept (48 pass)
- [x] `consumer-prose-gate.tests.ps1`: both retired-name warnings fire, none on a migrated repo (142 pass)
- [x] `check-plugin-integrity.ps1`: 0 errors; roster, script-contract and unfolded-entry gates green
- [x] The other suites the rename touches pass locally

### DEPLOY: feat/2788-rename-policy-extensions

The two `dkj-policy` extensions were renamed after their organisation:
`dkj-policy-bwj` is `bwj-development` and `dkj-policy-dkjs` is `dkj-solutions`
([#2788](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2788)). An extension is now
recognised by a list in `claude-md-import-lib.ps1` rather than by its name prefix. A retired name is
mapped to its current one, so the adopters still owe and write the current import line, and the
integrity gate fails until the list matches the plugin folders.

**Score:** 3

#### What makes this deploy extra special

A migration is required for a repo that enables either extension. The marketplace no longer declares
the old ids, so after this release nothing of the extension loads until `.claude/settings.json` enables
the new name and it is installed. The old `CLAUDE.md` import points at a folder that is gone, and nothing
fails loudly. The session-start check warns once for each old name, `adopt-workflow-folder.ps1 -Apply`
rewrites the old import line in place, and [ADOPTION.md](../plugins/ADOPTION.md#consumption) gives the
three steps.

**Score:** 5

#### Pull Request

Rename the dkj-policy extensions to bwj-development and dkj-solutions
