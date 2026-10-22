## fix/3294-hub-not-repository

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

Prose that calls the hub 'the Repository' says hub; the #3285 identifiers, file and state file go back to RepoHub, since Repository now names the /repository page.

### CREATE

- [x] The identifiers #3285 renamed go back to `RepoHub`: `Format-PluginRepoHubHtml`, `ConvertTo-PluginRepoHubName`,
  `Format-RepoHubBanner`, `Get-/Format-/ConvertFrom-/Read-/Write-RepoHubState(Path)`, `Test-RepoHubLocalUrl`,
  `$script:RepoHubChevron`, the source repo's `Format-RepoHubHtml` and `Get-RepoHubPages`, the file
  `hub/lib/repo-hub-page.ps1`, the state file `%TEMP%\dkj-repo-hub-<leaf>-<hash>.json` and the banner's
  `dkj-repo-hub-airsquats` key.
- [x] Prose that meant the hub says hub: the hook, `hub/README.md`, the hub libs, the dkj-solutions README,
  skill, patterns and manifest description, the brand book app's comments, three lenses, the source repo's
  dev server and tests. "Repository" stays only where it names the `/repository` page (its label, title and
  tests) and in the history lines that say the name moved.
- [~] `house-style.css`'s two comments: the file is sha256-pinned, so a comment edit forces a re-pin. Filed as #3299.

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors.
- [x] `dev-pages` 292/0, `dev-preview-sessionstart` 309/0, `connector-dashboard` 198/0.

### DEPLOY: fix/3294-hub-not-repository

The hub is called the hub everywhere again, now that "Repository" names the `/repository` page on it: in the
docs and comments, and in the functions, file and state file behind it (`Format-PluginRepoHubHtml`,
`hub/lib/repo-hub-page.ps1`, `%TEMP%\dkj-repo-hub-<leaf>-<hash>.json`). A hub server started under the
previous version is restarted at the next session start, as on any version change, so the state file's
name needs nothing done by hand.

**Score:** 1

#### What makes this deploy extra special

A repo that builds its own hub and calls the general banner function calls it `Format-RepoHubBanner` again
(it was `Format-RepositoryBanner` for one release); no consumer checkout on this machine calls either. The
banner's airsquats tally is kept under its pre-#3285 key again, so a count from before that release returns.

**Score:** 1

#### Pull Request

The hub is the hub again, in prose and in names

