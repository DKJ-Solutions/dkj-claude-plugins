## docs/3059-act-only-issue-closes

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

Inbound #3059: Maikel's rule that an issue stays open only while it will still change code goes into
`bwj-development/WORKFLOW-portable.md` step 4, beside the research block it closes with. The core parks
the same case under `awaiting-action-dev`. That conflict is filed as #3062 for the owner's decision rather
than settled here.

### CREATE

- [x] the rule, its one-question test, the move-the-code-step remedy and the smartwatchbanden measurement,
  in step 4
- [x] the stale "fails open with a warning on stderr" clause on the same page corrected to #3058's
  behaviour
- [x] the conflict with the core named in the text and filed as #3062

### TEST

- [x] docs only; the lint gate's link and prose checks run in `ship-pr`

### DEPLOY: docs/3059-act-only-issue-closes

`bwj-development`'s ticket-handling page now says that an issue stays open only while it will still change
code in the repo ([#3059](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3059), Maikel,
October 16, 2026). An issue whose remaining work is only an act outside the repo (a release, a publish in
the Shopify admin, an owner's decision) closes as completed with a research block naming that act. The
page gives the test, "does any step still change a file in the repo?", and says to move a lone code step
into the issue that already carries the related code work. The core still parks such an issue under
`awaiting-action-dev`, and which of the two yields is filed as
[#3062](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3062). The same page's description of
the go-live guard's fail-open is brought in line with #3058.

**Score:** 2

#### What makes this deploy extra special

In a store repo running `bwj-development`, a session closes an issue whose only remaining step is a store
act or a release, with a research block naming that act, instead of parking it. The open issues and the
`In Progress` column then show only work that can still be built.

**Score:** 3

#### Pull Request

An issue stays open only while it will still change code

