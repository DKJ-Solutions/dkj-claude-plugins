## docs/2238-handover-client-state-reset

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

Inbound [#2238](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2238): `PREVIEW-portable.md`
says one thing about browser state -- *pin the control to the live id* -- and it is scoped to which
theme renders. A change whose visible effect depends on what the browser REMEMBERS is not covered by
it, because preview and live share an origin and therefore one `localStorage`. Verified on pickup: the
page has exactly one mention of browser state, at the bullet the report names, and no mention of
`localStorage`, `sessionStorage`, IndexedDB or a private window anywhere in the plugin.

#### What the repair is, and what it is not

The load-bearing half is the rule -- a handover owes a reset step when the visible effect depends on
persisted client state. The rest is placement: a `###` subsection under *The shape of the handover*, and
the scoping clause on the control-URL bullet that is what a reader actually meets first.

#### Where the report was not followed verbatim

It calls the reset question a third *"beside the two the page already poses"*. Counted against the page,
there is **one** question the author answers -- *is the change visible in the frontend / storefront?*,
the last step under `### CREATE`. The subsection says SECOND rather than transcribing the report's two.

### CREATE

- [x] Scope the first consequence bullet under *What the control URL is* -- it settles the theme, not
      the feature's state -- with a link to the new subsection.
- [x] Add `### Pinning the control settles the THEME, not the feature's STATE` under *The shape of the
      handover*: the origin argument, the both-tabs-agree table, the reset step, the private window,
      the question, and the measurement behind it.
- [x] Name the reset in the *how to see the change* row of the handover table, beside the device and
      the viewport, so the rule is carried where a handover is actually assembled.
- [~] No script or seam change. `Get-MarketHandoverPairs` builds URLs; a reset step is prose in the
      handover's own block and nothing mechanical can assemble it.
- [~] No test. The repo's suites do not assert prose in a portable page, and the drift lint already
      holds the file's presence and shape.

### TEST

- [x] `check-plugin-integrity.ps1` + all suites green (the lint gate `open-pr` runs).
- [x] Anchor of the new subsection verified against the link that points at it.
- [x] File re-checked as ASCII, LF, no BOM after editing (a PowerShell write had introduced both).

### DEPLOY: docs/2238-handover-client-state-reset

`PREVIEW-portable.md` now states the second question a preview handover owes its reader: pinning the
control settles which THEME renders and settles nothing about what the browser REMEMBERS. Preview and
live share an origin, so they share `localStorage`, `sessionStorage`, IndexedDB and a feature's own
cookie -- and a reviewer carrying a stored value sees the change in both tabs, which reads as the change
being absent. Where the visible effect depends on persisted client state the handover now owes a reset
step, in the *how to see the change* block, and the reset is a private window. The first consequence
bullet under *What the control URL is* is scoped to say what it does and does not settle, because
following it as written is what produced the undiscriminating handover this came from.

**Score:** 3

#### What makes this deploy extra special

N/A -- a portable page this plugin ships to BWJ's stores. The reader is whoever builds a preview
handover there, which is this repo's own kind of reader one hop out, and no subscriber of a service
notices a rule about how a review link is assembled.

**Score:** N/A

#### Pull Request

A handover owes a client-state reset when the visible effect depends on persisted browser state
