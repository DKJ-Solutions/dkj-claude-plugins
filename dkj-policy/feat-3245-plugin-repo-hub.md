## feat/3245-plugin-repo-hub

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

#3245, as decided on the issue (maikel-bwj, October 21, 2026): the plugin serves the Repo hub in every
repo; a repo's own dev server is its product, one link on the hub; `OwnHub = $true` in `Get-DevPreview`
opts out; the session-start line names both; the General pages always start (which settles #3244's
second half). A visible result, so the branch stops for the owner's look.

### CREATE

- [x] The general pages server answers `/`, `/index.html` and `/hub` with the Repo hub
  (`hub/lib/repo-hub-page.ps1`), or a 303 to the repo's own hub under `OwnHub`.
- [x] `Get-DevPreview` takes `OwnHub`; the state file carries `product` and `mode`.
- [x] The hook starts the general pages first, whatever happens to the product, and prints one line with
  both links.
- [x] The placeholder server and its 4880-4889 range are retired; this repo states `OwnHub = $true`.
- [x] `hub/README.md` and the house-style docs describe the new model.

### TEST

- [x] `dev-preview-sessionstart` 265/0, `connector-dashboard` 196/0, `dev-pages` 274/0,
  `check-house-style` 88/0; `check-plugin-integrity` 0 errors.
- [x] `open-pr.ps1 -GatesOnly` before the park.

### DEPLOY: feat/3245-plugin-repo-hub

**The plugin now serves the Repo hub in every repo** (#3245). The general pages server, which already
served Artifacts, Issues, Release notes and SessionStart, answers `/` with the hub itself, on the same
origin as those pages. A repo that states `Get-DevPreview` sees its own dev server as the **Product**
card on that hub instead of in its place, and the session-start line names both:
`Repo hub: http://localhost:4890/ -- product: http://localhost:4321/... (started)`. A repo that wants its
own server to stay the hub states `OwnHub = $true` in `Get-DevPreview`. The General pages now start
whatever happens to the product, also when its port is taken. The placeholder server on 4880-4889 is
retired: a repo without `Get-DevPreview` gets the same plugin hub, with the setup cards.

**Score:** 4

#### What makes this deploy extra special

A repo whose dev server is its product no longer has to build a hub of its own: after this release its
session-start line hands out the plugin's hub beside the product. A repo whose own server should stay the
hub adds `OwnHub = $true` to `Get-DevPreview`; a `.vscode/settings.json` route for 4880 becomes one for 4890.

**Score:** 4

#### Pull Request

Repo hub: the plugin serves it in every repo, with the repo's own server as its product

