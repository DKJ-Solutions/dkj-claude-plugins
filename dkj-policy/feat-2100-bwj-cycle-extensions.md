## feat/2100-bwj-cycle-extensions

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

#### What #2100 asks for, and where each half lands

Two steps are added to the `dkj-policy` cycle **when `dkj-policy-bwj` is installed beside it**, and
nothing before the step list changes. Neither half becomes a fifth chapter: each lands in the chapter
whose subject it already is, so no chapter-count literal, README table or structure test moves.

1. **The storefront-visibility step** -- the last step under `### CREATE`, always asked, and ticked
   only once a person has confirmed they looked at the preview. Subject: previews, so it lands in
   `PREVIEW-portable.md`, whose "What this page does not decide" list loses the half that is now
   decided.
2. **The go-live half of the paste-ready block** -- the date, the version and the live URLs, added to
   the block `WORKFLOW-portable.md` already defines, rather than as a second message beside it.

The plugin README gains a short index naming the two, because a reader who installs both plugins has
nowhere else that answers *what does my cycle gain*.

### CREATE

- [x] `PREVIEW-portable.md`: the storefront-visibility step, and the amended does-not-decide list
- [x] `WORKFLOW-portable.md`: the go-live half of the paste-ready block
- [x] `README.md` (plugin): the "what the cycle gains here" index, linking both
- [x] `README.md` (root) + plugin README: the two skill listings the lint gate enumerates
- [x] `scripts/lib/golive-block-rules.ps1`: the pure half -- next release date, predicted version, the block text
- [x] `scripts/task/build-golive-block.ps1`: the runnable half, with `-Post`
- [x] `skills/golive-block/SKILL.md`: the skill every script in this family lives in
- [x] `plugin.json`: the description names the two cycle steps
- [~] Is the change visible in the frontend / storefront? -- dropped: nothing here renders (portable
      pages, a lib, a task script, a skill page), and this repo is outside chapter three's reach
      anyway: no theme, no store, nothing to preview. Written into this branch's own list on purpose,
      as the first instance of the step it adds.

### TEST

- [x] `scripts/tests/dkj-policy-bwj.tests.ps1` covers the new lib and the new block text -- 358 asserts green
- [x] the lint gate is green (0 errors); the full suite run is `open-pr`'s own gate and is not pre-run here

### DEPLOY: feat/2100-bwj-cycle-extensions

`dkj-policy-bwj` now states what installing it does to `dkj-policy`'s cycle, and it is exactly two steps
with nothing before the step list touched. **The last step under `### CREATE` is always
`Is the change visible in the frontend / storefront?`** -- dropped with its reason where nothing renders,
and otherwise a preview theme, a comment on the GitHub issue carrying the steps and every URL, and
`- [x]` only once a **person** confirms they looked. Being last is the enforcement: `dkj-policy`'s own
step-list gate refuses the push and the merge while it is open, so an unconfirmed preview stands between
the work and the PR -- and an agent may never tick it itself, because it can prove a theme exists and
never that somebody looked at it. **And just before the issue closes, the paste-ready block gains its
go-live half**: the next release day, the version that release is on course for, and the live storefront
URL per market, written by the new `build-golive-block.ps1` behind the `golive-block` skill.

Neither half became a fifth chapter. Each landed in the chapter whose subject it already is -- previews,
and ticket handling -- so no chapter count, README table or structure assert moved; the plugin README
carries an index instead, which is the one thing neither chapter answers on its own. `PREVIEW-portable.md`
also loses half of a "what this page does not decide" bullet that stopped being true: it disclaimed the
trigger as well as the judgement, which left the trigger to memory.

Three things the mechanism deliberately will not do, all measured as the expensive direction elsewhere in
this workflow. It **never writes `[ADD LINK]`** -- that placeholder is CI's, which cannot know the link,
and a session can, so a link it was not given is a sentence it does not write. It **never promises**:
*"Planned to go live"*, because a tier-1 entry landing on the Friday turns a predicted patch into a minor,
and this block is the one surface a colleague quotes back. And it **guesses nothing** -- no `v*` tag or an
unreadable pending tally means no version in the sentence, and a repo with no declared markets gets no URL
list. The version is read off the tally the fold already writes rather than re-derived, because the tier
parser lives in `dkj-policy`'s libs and this plugin's scripts may not reach a second plugin's folder.

**Score:** 3

#### What makes this deploy extra special

For the two BWJ store repos this changes the working day: every branch now ends its CREATE list with a
question that holds the PR until a person has actually looked at the preview, and every ticket a colleague
filed now comes back with a date, a version and a live link instead of only *"it is done"*. Both are
things they had to remember before, and the first is now held by a gate rather than by memory. The source
repo gets the second half only, and there the URL list is simply empty -- it declares no markets.

**Score:** 4

#### Pull Request

The two cycle steps dkj-policy-bwj adds: the storefront-visibility step under CREATE, and the go-live half of the paste-ready block
