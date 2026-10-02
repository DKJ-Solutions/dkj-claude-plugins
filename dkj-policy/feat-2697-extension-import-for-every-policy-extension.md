## feat/2697-extension-import-for-every-policy-extension

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

Generalise the import-line tooling over every `dkj-policy-<slug>` extension instead of bwj alone
(#2697). The set comes from the repo's own enables, so a new extension needs no code change.
`adopt-workflow-folder.ps1` becomes the writer for every enabled extension, because `dkj-policy-dkjs`
ships no scripts.

### CREATE

- [x] `claude-md-import-lib.ps1`: `Test-PolicyExtensionName`, `Get-PolicyExtensionNames`,
      `Get-ExtensionImportLine`, `Get-ExtensionImportPattern` and `Test-ExtensionImported` replace the
      bwj-only pair. The marketplace segment is read off any `dkj-policy-*` payload. Mirrors synced.
- [x] `check-consumer-prose.ps1`: one warning per enabled extension whose line is missing.
- [x] `adopt-workflow-folder.ps1`: writes each enabled extension's line below the constitution.
- [x] `adopt-extension-import.ps1` (bwj) moved onto the generic functions.
- [x] Docs: the adopt-dkj-policy skill page, the dkj-policy-dkjs README and the scripts README.

### TEST

- [x] `bwj-extension-import.tests.ps1` (36), `consumer-prose-gate.tests.ps1` (138) and
      `adopt-workflow-folder.tests.ps1` (156) are green, with new asserts for dkjs, for two extensions
      at once, for a disabled extension, for name validation, and for every extension in the tree
      shipping its `CLAUDE.md`.

### DEPLOY: feat/2697-extension-import-for-every-policy-extension

Inside this repo: `claude-md-import-lib.ps1` loses `Get-BwjExtensionImportLine` and
`Test-BwjExtensionImported`. In their place come per-extension functions keyed on a validated
`dkj-policy-<slug>` name, with the set of extensions derived from the repo's enabled plugin ids. The
session check and both adopters use them, and the suites cover dkjs alongside bwj.

**Score:** 2

#### What makes this deploy extra special

For a DKJ-Solutions repo maintainer who enables `dkj-policy-dkjs`: the `adopt-dkj-policy` run now
writes that extension's `CLAUDE.md` import directly below the constitution import, so the line no longer
has to be added by hand. The `consumer-prose-sessioncheck` hook now warns while the line is missing. It
did that for `dkj-policy-bwj` only. The same holds for any later `dkj-policy-*` extension, and a repo
that enables two gets both lines
([#2697](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2697)).

**Score:** 3

#### Pull Request

Every dkj-policy extension's CLAUDE.md import is written and checked, not dkj-policy-bwj alone

