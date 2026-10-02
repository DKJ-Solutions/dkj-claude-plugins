## feat/2700-closed-message-carries-the-block

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

#### Scope: #2700 and #2703 are one change

Dave's decision on #2700 (October 2, 2026) merges the `ready` and `closed` messages into one closed
message carrying the go-live block. That only works if the block reaches Asana at the close without a
paste, which is #2703's ask, so this branch resolves both. The route is the one #2700's last comment
names: the CI mirror's close comment carries the block the session left on the issue.

#### Parked for the owner's eye, no pull request

The message is what a colleague reads in Asana, and how `html_text` renders there has not been seen by
eye. So this branch stops before a PR (a visible result). Not touched: #2701's blank line before the
closing `---`, held by another sweep.

### CREATE

- [x] `golive-block-rules.ps1`: header and closed line fixed and English (`Format-GoLiveClosedLine`),
      `TE BEKIJKEN OP` first, a framing sentence saying no paste is needed (`Get-GoLiveBlockLead`).
- [x] `asana-mirror.ps1`: the closed form reworded; `Get-PasteBlockSections`,
      `Select-SessionPasteBlockSections`, `ConvertTo-AsanaStoryHtml`, `New-ClosedMessageHtml`; event mode
      and the close sweep post the one closed message; the marker reads `is now closed` and the legacy
      `is closed` still counts as told; the backstop opens with the automation header.
- [x] `build-golive-block.ps1` messages, the golive-block and report-issue skills, `WORKFLOW-portable.md`,
      the README, and the plugin/marketplace description: no paste, the close sends it.
- [x] Filed #2708: PREVIEW-portable's copy button on the block has no paste left to serve.

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: the new closed form, the legacy marker, the closed line, the heading
      order, the carried sections (old and new header, backstop skipped), the HTML conversion, and the
      not-planned and no-block cases. 511 asserts pass.
- [x] The full gate, run here because the branch stops before a PR (`open-pr -GatesOnly`).

### DEPLOY: feat/2700-closed-message-carries-the-block

Inside this repo: `asana-mirror.ps1` gains the closed-message composer (`Get-PasteBlockSections`,
`Select-SessionPasteBlockSections`, `ConvertTo-AsanaStoryHtml`, `New-ClosedMessageHtml`), and its close
marker becomes `is now closed`, with the old `is closed` kept as a legacy match.
`golive-block-rules.ps1` composes the header and closed line once for both languages and puts
`TE BEKIJKEN OP` first. `dkj-policy-bwj.tests.ps1` pins the new forms and the carry.

**Score:** 2

#### What makes this deploy extra special

For a BWJ store maintainer: the go-live block no longer has to be pasted into the Asana task. When the
issue closes, `asana-mirror` posts it on the task as its one closed message: *"GitHub issue
[owner/repo#n](...) is now **closed**. It can be reopened anytime..."*, then the block's sections with
`TE BEKIJKEN OP` first. The headings arrive bold, the links as links, and every line break intact. The
separate *ready to test* close comment is gone, so the colleague reads one message instead of two
([#2700](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2700),
[#2703](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2703)). A store repo picks it up
by refreshing its copy of `asana-mirror.ps1` through `adopt-dkj-policy-bwj` step 1, which diffs rather
than overwrites.

**Score:** 4

#### Pull Request

The go-live block reaches Asana as the one closed message, carried by the CI mirror

