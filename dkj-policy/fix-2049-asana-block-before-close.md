## fix/2049-asana-block-before-close

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

Inbound #2049, filed from `BWJ-Development/smartwatchbanden`. BWJ (Maikel, September 17, 2026) has
reversed the order for issues that carry a mirrored Asana task: the paste-ready block goes on the
issue **before** it closes, written by the session that shipped the work, and closing the issue is a
person's confirmation that the handover reached Asana.

#### What the verification found (six axes, read against the tree rather than the report)

All six stand. The symptom is verbatim -- step 4's heading is keyed on `closed` and the CRO section
says *"runs once, on the `closed` event, and carries no backstop"*. The reasoning holds:
`New-CroClosingComment` really does write `[ADD LINK]`, and the call site's own comment confirms the
missing backstop. The proposed repair names mechanisms that exist (`Resolve-AsanaTaskRef`'s three
matchers, `-NoResolves`); `-Refs` does not exist, and the report correctly names that as a larger
change rather than assuming it. The size figure (14/13/6) sits in the consumer and is not
re-verifiable here, and nothing in points 1-3 leans on it. Subject and repo are both right.

#### The one thing #2049 left open, and the answer

Point 5 -- keep `asana-mirror`'s own comment or retire it -- was explicitly not decided there.
Answered in session (Maikel, September 17, 2026): **keep it as a backstop, widened and
de-duplicated.** It loses nothing (an issue that closes without a block still gets a paragraph) and
it cannot produce the double-block the unchanged version would.

#### One finding scoped out, deliberately

The `CRO` gate turned out to be structurally redundant rather than merely narrow: `Invoke-EventMode`
already returns before the comment when no Asana task resolved, so *reaching that line* is the link.
Widening the gate was therefore a deletion, not a new matcher.

### CREATE

- [x] `asana-mirror.ps1`: retire `Test-IssueIsCro` and `New-CroClosingComment`; add
      `Get-AsanaPasteBlockMarker`, `Get-AsanaPasteBlockLead`, `Test-AsanaPasteBlockPosted` and
      `New-AsanaPasteBlockComment`. Named for the block rather than for a handover, because
      `Get-SubmitterHandoff` in the same file already owns that word.
- [x] `asana-mirror.ps1`: the close-event gate drops the label condition and gains the de-duplication;
      an unreadable issue answers "already posted", the same default `Test-MirrorUpdatePosted` takes.
- [x] `asana-mirror.ps1`: record why the sweep still does not carry it -- a first sweep would post a
      placeheld block on every Asana-linked issue closed in the last 30 days.
- [x] `WORKFLOW-portable.md`: step 4 is renamed and states the ordering, the block's exact shape, the
      three reasons the old order failed, the Asana-link gate, and the `-NoResolves` interaction; the
      backstop gets its own `#####` under it.
- [x] `WORKFLOW-portable.md`: the `CRO` label section loses its trigger paragraph -- it is a filing
      axis again; step 7 gains the person's act; the rationale list gains the ordering argument.
- [x] `open-pr/SKILL.md`: the resolves gate states the Asana-linked case, what `-NoResolves` costs
      there, and that a third flag is named in #2049 rather than assumed.
- [x] `dkj-policy-bwj.tests.ps1`: the CRO asserts are replaced.

### TEST

- [x] The marker is asserted to sit **outside** the pasted block -- the half that travels to Asana is
      split on its own `---` rules and checked for the marker's absence. That is the one property a
      reader cannot see and a colleague would pay for.
- [x] The marker and the lead sentence are asserted against `WORKFLOW-portable.md` itself, not only
      against the script's own output: two writers have to agree on them, and only one of them is code.
- [x] `dkj-policy-bwj.tests.ps1`: 323 asserts green.
- [x] `check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: fix/2049-asana-block-before-close

`dkj-policy-bwj` reverses the order of its Asana handover: the paste-ready block is written by the
session that shipped the work, while the issue is still **open**, and closing the issue is a person's
confirmation that the block reached Asana. It is gated on the issue having a linked Asana task rather
than on the `CRO` label, which was narrower than the need. `asana-mirror` still writes a block on the
`closed` event, but only where no block is already there -- it is the backstop now, not the route.

The old order could not be repaired in place. Its comment appeared underneath an item that had just
left every open-issue view; a missed event was never detected afterwards; and the link inside it was a
placeholder that CI cannot fill, because "where the result can be viewed" depends on what the ticket
was about. The session that built the thing is the one party that knows that link.

**Score:** 2

#### What makes this deploy extra special

A store repo running `dkj-policy-bwj` has to act, in two places. Re-copy `templates/asana-mirror.ps1`
into `.github/scripts/` -- an install writes nothing into a repo -- or the old CRO-gated comment keeps
running. And ship an Asana-linked issue with `-NoResolves` from now on: a `Closes #<n>` has GitHub
close the issue at the merge, before anybody has written a block and with nobody's confirmation, which
bypasses the whole rule silently.

In exchange the requester stops being told where to look by a comment nobody reads, on a ticket
nobody reopens, with the link still reading `[ADD LINK]`.

**Score:** 5

#### Pull Request

The paste-ready Asana block is written before the issue closes, by the session that shipped it

