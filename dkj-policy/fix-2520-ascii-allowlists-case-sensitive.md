## fix/2520-ascii-allowlists-case-sensitive

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

#2520 names four ASCII allowlists that use case-insensitive `-match`. A sweep of the tree found the
same defect in more identifier allowlists that gate a value before it becomes a path segment, a
command-line argument or an API call. All of them are one subject, so they are repaired together.
Regex *parsers* that only extract text and do not gate a value stay as they are. So do the hex-SHA
checks: no non-ASCII character case-folds into `a-f`, and git accepts an upper-case SHA.

### CREATE

- [x] `-cmatch`/`-cnotmatch` at the four named sites: `Test-BranchName`, `Test-PluginNameSlug`,
  `Test-PluginMarketplaceSlug`, `Test-GitHubLoginShape`
- [x] ...and at the same-class sites the sweep found: `Test-GitHubOwnerNameSlug`,
  `pick-merge-on-green.ps1`'s branch check, `New-ScratchPath`'s label and extension,
  `Get-IssuePathCitations`' path token, `check-plugin-integrity.ps1`'s specialist `name:` check,
  `publish-to-business.ps1`'s slug detection, `bootstrap.ps1`'s three slug checks, and
  `page-publish-rules.ps1`'s BaseUrl check
- [x] Plugin mirrors synced with `build-shared-scripts.ps1`

### TEST

- [x] Kelvin-sign assertions in `branch-info`, `check-report-lib`, `claim-issue` and `native-capture`
  suites, plus an upper-case refusal for the lowercase plugin-name slug; all four suites green

### DEPLOY: fix/2520-ascii-allowlists-case-sensitive

The workflow scripts' ASCII allowlists no longer let a look-alike letter through
([#2520](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2520)). They follow the paste-safe
guards #2516 repaired. Branch names, plugin and marketplace slugs, GitHub logins and `owner/name` slugs,
scratch-path labels, and paths cited in an issue body were all checked against an explicit ASCII class
with a case-insensitive match. So the Kelvin sign (U+212A) passed as `k`, and the "lowercase" plugin-name
check admitted upper case. Every one now matches case-sensitively. Every plain-ASCII value that
was valid before is still valid. The only newly refused values are non-ASCII look-alikes and upper
case where a check says lowercase.

**Score:** 1

#### What makes this deploy extra special

N/A -- internal guards in the workflow scripts; no subscriber of a service runs anything new.

**Score:** N/A

#### Pull Request

The ASCII allowlists match case-sensitively, so the Kelvin sign is refused
