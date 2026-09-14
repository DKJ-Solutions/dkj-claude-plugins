## feat/bwj-adopt-third-repo

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

Gate only: adopt-dkj-policy-bwj step 0 and report-issue's Before-you-start check admit dkj-claude-plugins. The four portable law pages, plugin.json and marketplace.json stay at two stores by Dave's explicit scope choice.

### CREATE

- [x] `adopt-dkj-policy-bwj/SKILL.md`: step 0 rewritten -- three-name list, the heading widened off
      "BWJ store repo", and the retired "no legitimate third adoption target" argument replaced by
      what the admission costs in a public source repo.
- [x] `adopt-dkj-policy-bwj/SKILL.md`: frontmatter description names the three permitted repos.
- [x] `report-issue/SKILL.md`: frontmatter and the Before-you-start gate name the same three, with a
      pointer to step 0 rather than a second copy of the reasoning.
- [~] The four portable law pages, `plugin.json` and `marketplace.json` -- dropped on Dave's explicit
      scope choice (gate only). The contradiction that leaves is filed as #1982.
- [~] A test pinning the three names -- dropped: no suite asserts the list today, and
      `dkj-policy-bwj.tests.ps1` already pins the invariant it does care about (exactly one
      label-existence check in step 4). Adding one is worth its own branch, not a rider on this one.

### TEST

- [x] `check-plugin-integrity.ps1` + every suite, via `open-pr.ps1`.

### DEPLOY: feat/bwj-adopt-third-repo

`dkj-policy-bwj`'s two skills refused to run anywhere but BWJ's two Shopify stores. They now admit a
third repo by name -- `dkj-claude-plugins`, the plugin's own source -- which until today step 0 named
as the *most likely wrong* target, precisely because the templates it copies live there. The check
itself is unchanged and so is the measurement behind it (#1522): what changed is the verdict for that
one name, and step 0 now carries what the admission costs in a public repo whose tracker receives
every consumer's inbound reports.

**Score:** 2

#### What makes this deploy extra special

N/A -- a consumer of this marketplace gains nothing. The three-name list is this source repo letting
itself run a procedure it ships; the two BWJ stores it was written for are unaffected, and every
other repo is refused exactly as before.

**Score:** N/A

#### Pull Request

The BWJ adoption gate admits the plugin's own source repo as a third target
