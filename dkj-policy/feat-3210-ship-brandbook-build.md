## feat/3210-ship-brandbook-build

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

#3210, decided (a) by the owner on October 20, 2026: the `brandbook/` React app's build ships with
`dkj-solutions`, built at release and served by the general pages server, and the PowerShell Brandbook page
(`ConvertFrom-HouseStyleAssets` + `Format-BrandbookPageHtml`) is retired. A plugin is installed from the git
tree at its tag, so "shipped" means committed into the plugin folder by the release commit.

### CREATE

- [x] `cut-release.ps1` (source and mirror): a new optional seam, `Get-ReleaseBuilds`, read and checked before
      the first write (paths inside the repo, Target a folder inside a plugin, Output ignored by git), its
      commands run after the gates and before the first write (a failure, or a build that dirties what git
      sees, aborts with nothing written), and Output copied over Target beside the version pins.
- [x] The seam's contract record in `script-contract-lib.ps1` (both copies), the exact count 50 -> 51 in
      `script-contract.tests.ps1`, and the blueprint rebuilt.
- [x] `scripts/repo-config.ps1` answers it: `brandbook/` -> `plugins/dkj-policy/dkj-solutions/assets/brandbook`,
      and the house-style allowlist names that folder (the bundled stylesheet) instead of the retired page's lib.
- [x] `dkj-solutions-pages-lib.ps1`: the PowerShell page and its model are gone; the path rules for the build
      (`ConvertTo-BrandbookRelPath`, `Get-BrandbookContentType`) move here from the source repo's
      `dev-pages-lib.ps1`, with `Resolve-BrandbookFile`, `Get-BrandbookBuildDir` and a page for a plugin copy
      that ships no build.
- [x] `serve-general-pages.ps1` serves the shipped build under `/brandbook/` (303 from `/brandbook`), and this
      repo's hub resolves its own build through the same function.
- [x] Review (Victor #19, Sebastian #23): `npm ci --ignore-scripts`, a post-build check for source maps and local user
      paths, the Output emptied before the build, `git -C` on the dirty check, and a `-LiteralPath` copy.
- [x] Docs: the release-commit bound in `.claude/rules/this-repo.md`, the hub and `dkj-solutions` READMEs, and
      `brandbook/README.md`.

### TEST

- [x] `cut-release-drive.tests.ps1`: the happy path ships a fixture build into the release commit; a failing
      command, an unignored Output and a source map in the output each refuse before the first write (114 asserts green).
- [x] `dev-pages`, `dev-preview-sessionstart`, `connector-dashboard`, `script-contract` and `config-blueprint`
      suites green.
- [x] A simulated first cut (the real build copied into `assets/brandbook/` and added intent-to-add): the
      house-style gate and `check-plugin-integrity.ps1` both pass over it; the copy was removed again.

### DEPLOY: feat/3210-ship-brandbook-build

`cut-release.ps1` reads a new optional seam, `Get-ReleaseBuilds`: builds it runs after its gates and copies into
a plugin in the release commit, checked before the first write and refusing a failed build or one that touches
a file git sees. This repo uses it to ship the `brandbook/` app, so the PowerShell Brandbook page in
`dkj-solutions` is retired and there is one brand book to keep current, not two.

**Score:** 3

#### What makes this deploy extra special

In every DKJ-Solutions repo, the Repo hub's Brandbook is now the full brand book app (every component, its
headings list and the repo previews) instead of a smaller PowerShell page, at `/brandbook/` on the general
pages server, from the next release on.

**Score:** 3

#### Pull Request

The brandbook app's build ships with dkj-solutions and replaces the PowerShell Brandbook page

