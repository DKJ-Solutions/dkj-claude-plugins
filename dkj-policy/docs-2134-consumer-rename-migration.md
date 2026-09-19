## docs/2134-consumer-rename-migration

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

Write the third INSTALL.md migration section. Measured against both real consumer checkouts on this machine (smartwatchbanden, xoxowildhearts) before writing. The PR WAITS until steps A-D (#2130-#2133) have landed -- Dave, September 19, 2026.

#### The PR is held until steps A-D have landed

Dave, September 19, 2026: *"begin alvast met issue 2134, maar wacht met de PR tot step a tot en met d
klaar zijn"*. So the work is finished and parked on `origin`, and `open-pr` is not run until
[#2130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2130),
[#2131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2131),
[#2132](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2132) and
[#2133](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2133) are merged. Step F
([#2135](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2135)) depends on this one having
landed first, which is the ordering this branch exists to protect.

#### Where the section's advice differs from what #2134 proposed

#2134 states the safe order as *"edit `SPECIALISTS.md` first, refresh second"*. Read against the
mechanism, that order still opens a window in which the import names a file the clone does not hold,
and it cannot be verified before it is written -- if the rename has not reached `main` at that moment
the refresh does not repair it. The section therefore gives a **zero-window** recipe instead: carry
both import lines during the overlap, which is sound precisely because of what #2135 measured -- a
dead `@`-import is silent, inert and non-fatal. The half of #2134's reasoning that does survive is the
urgency, and the section keeps it: the clone tracks `main`, so the break arrives with no version
behind it and no gate in front of it.

#### Filed while measuring, and deliberately not repaired here

[#2138](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2138) -- reading the two real
consumer checkouts turned up one that has been running on a dead orchestrator import since the
September 9/10 renames, with nothing reporting it. The detector already exists (the always-on budget
gate names it exactly); what is missing is anything running it where it would be read, and lint check
28 excludes this class of import by design. That is the **detection** half of the same hazard this
branch documents, it is a design call rather than a doc edit, and it is not in #2134's scope.

### CREATE

- [x] Read both real consumer checkouts on this machine -- `smartwatchbanden` and `xoxowildhearts` --
      rather than writing the steps from the source tree alone. 25 lenses each; the two import lines
      in `SPECIALISTS.md`; the baseline keyed on `lenses/01-01-extension.md` and on the persona target
      at 30,267 B, which is the figure #2135 quotes.
- [x] Confirm the four consumer-side things that move, which is one more than #2134 listed: the lens
      files, the two import lines, the markdown links in the consumer's own prose (16 occurrences in
      one checkout's lens bodies, 4 in the other's `CLAUDE.md`), and `always-on-baseline.json`.
- [x] Confirm nothing consumer-side refuses a second `@`-import, which is what makes the zero-window
      recipe available: `bootstrap.ps1` never rewrites an existing `SPECIALISTS.md`, and no shipped
      check reads the import line's shape.
- [x] Write the third `INSTALL.md` migration section, at the top of the migration stack, in the shape
      of the two already there.
- [x] Give the two fenced blocks the `unbound-sample` opt-out with a named reason -- they are file
      content to paste rather than captured output, which is the one thing check 15 cannot tell by
      itself.

### TEST

- [x] `check-plugin-integrity.ps1` green, including the dead-link scan and the two consumer-doc
      checks the new section is subject to (15 expected-output, 16 measured-figure).
- [x] All suites green -- 118 of 118, via `open-pr.ps1 -GatesOnly`, which is the tooling's own gate
      rather than a hand-rolled copy of it. **The pass is not banked as gate evidence**: the commit
      landed while the run was in flight, so the gate correctly refused to credit a tree that moved
      under it. `open-pr` will re-run the suites whenever this branch is finally pushed for review,
      which is the right outcome for a branch that is deliberately going to sit.
- [x] The verification recipe the section hands a consumer was run, read-only, against both real
      consumer checkouts -- and it reported the live dead import in one of them, which is the
      evidence the section cites.

### DEPLOY: docs/2134-consumer-rename-migration

`INSTALL.md` gains a third migration section, for the `specialist-` filename rename. It is written
**before** the rename lands, because the persona half of it breaks outside every version gate: that
import resolves against the marketplace clone, which tracks `main` and advances on a refresh, so
instructions arriving afterwards are instructions nobody had when they needed them.

**Score:** 3

#### What makes this deploy extra special

A consumer whose `SPECIALISTS.md` still names the old orchestrator path loses Chris's entire body --
30,267 B of it -- and **nothing reports it**: not stdout, not stderr, not `--debug`. This section is
the only thing standing between that and the six registered consumers, and it hands them a recipe
with no broken window at all: carry both import lines through the overlap, which is sound exactly
because a dead `@`-import is inert. It also names the one verification that answers "does my import
resolve?" without opening a session to find out, and three consumer-side things the issue did not
list -- the markdown links in their own prose, the `always-on-baseline.json` key, and the fact that
their lenses need not move at all.

That last one is the part a consumer will feel most: the two halves of this rename are not equally
urgent, and only one of them is theirs to run today.

**Score:** 4

#### Pull Request

The consumer migration section for the specialist filename rename

