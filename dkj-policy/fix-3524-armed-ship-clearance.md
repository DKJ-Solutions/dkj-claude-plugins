## fix/3524-armed-ship-clearance

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

Issue #3524. The reason was verified against the tree: the persona's "Cleared" paragraph and the
manual's "And say what they MAY do" both still treat every backgrounded ship as dying with the harness,
which predates the arming (#2319, #2393) and `Get-ShipClearanceVerdict` (#3442).

### CREATE

- [x] Persona: an armed ship with the checkout on the trunk is a plain clearance, stated as a fact
- [x] Manual: the same case, its four facts, and "relay ship-pr's line", with the #3524 measurement
- [x] ship-pr skill: a backgrounded ship through `tail`/`head` prints nothing until it ends

### TEST

- [x] Docs only; the gates run inside ship-pr

### DEPLOY: fix/3524-armed-ship-clearance

A close-out after a backgrounded ship no longer tells the requester to keep the session open when the PR
is already armed `merge-when-green` and the checkout is back on `main`. Chris's persona and manual now
name that case as a plain clearance, matching the line `ship-pr` has printed since #3442. The second-session
advice stays for what really dies with the harness: an unarmed ship, a subagent, a local-only wait. The
`ship-pr` skill page adds why the run must not go through `tail`: the clearance line never reaches the
session until the run ends (#3524).

**Score:** 2

#### What makes this deploy extra special

In a consuming repo, the orchestrator stops warning that a session must stay open while an armed pull
request ships, and says plainly that it can be cleared.

**Score:** 2

#### Pull Request

Clear the session plainly when a backgrounded ship is armed merge-when-green

