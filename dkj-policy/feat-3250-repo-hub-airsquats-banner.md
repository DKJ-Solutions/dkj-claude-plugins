## feat/3250-repo-hub-airsquats-banner

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

#3250 (Dave): a general banner on the Repo hub with a timer that resets every hour; when it runs out, a
tone and a "10 airsquats" checkbox; the timer keeps running either way, and unticked airsquats stack up.
A visible result, so the branch stops for the owner's look and opens no PR.

#### Choices made, for the owner's look

- **Both hub indexes, one helper**: `Format-RepoHubBanner` in the plugin's `general-pages-lib.ps1`,
  called by this repo's `Format-RepoHubHtml` and the placeholder hub every repo without a
  `Get-DevPreview` gets. A repo whose own server is its hub (dkj-recipes, see #3245) does not get it.
- **The timer counts down to the next full hour**, so it reads the same in every tab and after a reload.
- **Stacking is one checkbox showing the total** (10, 20, 30 ...), and ticking it clears the total.
- **An hour counts only while a hub page is open** (or reopened within two minutes), so a hub closed
  overnight does not show a stack it never announced. The state is the browser's own (localStorage).
- **Placed directly under the intro, above Pages**, in house classes only (`.notice`, `.msg`). The house
  style's Repo hub form (`assets/house-style/README.md`, "The Repo hub") has no such block yet; if the
  owner approves the banner, that table gets its row before the merge.

### CREATE

- [x] `Format-RepoHubBanner` (markup and inline script) in `plugins/dkj-policy/hub/lib/general-pages-lib.ps1`
- [x] called under the intro in `scripts/lib/dev-pages-lib.ps1` and `plugins/dkj-policy/hub/lib/dev-preview-placeholder.ps1`
- [x] The owner's look at the preview (approved, October 21, 2026); then the Repo hub table in the house-style README gets the block, as row 6a

### TEST

- [x] `dev-pages.tests.ps1` (278) and `dev-preview-sessionstart.tests.ps1` (202): the banner's place,
  its hidden box, a script that keeps state locally and makes no request; `connector-dashboard` (196) green
- [x] `open-pr -GatesOnly`: the lint gate green

### DEPLOY: feat/3250-repo-hub-airsquats-banner

The Repo hub now carries a general banner (#3250): a countdown to the next full hour, and when an hour
has passed, a short tone and a **10 airsquats** checkbox. The countdown keeps running whether or not the
box is ticked, and every unticked hour adds another 10, so the box shows the total owed; ticking it
clears the total. It is on this repo's hub and on the placeholder hub, in house classes only, and its
state stays in the browser.

**Score:** 2

#### What makes this deploy extra special

A repo served by the placeholder hub shows the banner on its index from the next release.

**Score:** 2

#### Pull Request

Repo hub: an hourly airsquats banner

