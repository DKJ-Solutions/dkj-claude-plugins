## feat/2913-notes-page-url-in-closeout

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

Inbound #2913. `publish-page.ps1 -Kind notes` is the one script holding the URL at the moment it is
proven to serve the page, so the receipt prints itself there (#1884), not through a lens rule.

### CREATE

- [x] `Format-BwjPageCloseOut` in `page-publish-rules.ps1`: a `Close-out:` line with the URL for `notes`,
  nothing for `backlog`
- [x] `publish-page.ps1` prints it on both verified exit paths (wrangler and the KV API), never on `-DryRun`
- [x] The `publish-page` skill page says the cut's receipt ends with that link

### TEST

- [x] `bwj-page-publish.tests.ps1` covers both kinds and both exit paths, green on its own

### DEPLOY: feat/2913-notes-page-url-in-closeout

`publish-page -Kind notes` now ends with a `Close-out:` line that carries the release-notes page URL,
once the read-back has proven what the URL serves. A BWJ store cut's receipt ends with that link, so
the page that goes to management is in the close-out rather than in a lens or the scroll-back
([#2913](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2913)).

**Score:** 2

#### What makes this deploy extra special

The person running a store cut gets the management link handed to them in the receipt, in both store
repos.

**Score:** 2

#### Pull Request

publish-page prints the release-notes URL as the cut's close-out line

