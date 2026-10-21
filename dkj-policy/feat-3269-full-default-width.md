## feat/3269-full-default-width

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

Issue #3269 (inbound from dkj-lifehub): an app that sets no `data-width-default` opens at `fluid`,
because that is `resolveWidth()`'s last fallback. The owner wants `full` as the house default.

#### The no-script case stays fluid -- a decision for the owner's look

The issue leaves open whether `house-style.css` without the script should render full too. It does
not, here: the stylesheet alone also serves e-mail, Artifacts and static reports, which have no settings
panel to narrow an unbounded column back to a reading width, and making it full would need a new
`fluid` rule plus a changed `main` default in every consumer at once. Reverse it at the review if the
owner wants the two cases identical.

### CREATE

- [x] `house-theme.js`: the last fallback in `resolveWidth()` is `'full'`; the header comment follows.
- [x] `README.md` (*The page width is part of the settings panel*): the order ends in `full`, the
  example `data-width-default` names `fluid`, and why the no-script column stays fluid.
- [x] `skills/house-style/SKILL.md`: the `house-theme.js` sha256 names the new bytes; the cut repoints
  the tag, as every house-style branch before this one left it.

### TEST

- [x] No suite pins the fallback (searched for `resolveWidth` and the `fluid` literal); the release
  rebuild of `assets/brandbook/` carries the new script into the built brand book.
- [ ] The owner looks at an app without `data-width-default` and sees it open at full width.

### DEPLOY: feat/3269-full-default-width

Every DKJ-Solutions page that runs `house-theme.js` and sets no `data-width-default` now opens at
**full** width instead of the 1080px fluid column (#3269). A width picked in the settings panel still
wins, and an app's own `data-width-default` still decides its default. Without the script the column
stays fluid.

**Score:** 3

#### What makes this deploy extra special

An app that relied on the implicit `fluid` opens wider after the update. To keep the old look, set
`<html data-width-default="fluid">`.

**Score:** 3

#### Pull Request

House style: full is the default page width

