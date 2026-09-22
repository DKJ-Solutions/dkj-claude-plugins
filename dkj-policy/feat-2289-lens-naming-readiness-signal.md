## feat/2289-lens-naming-readiness-signal

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

#### What #2289 reported, and which of its three options this branch takes

The issue reported two things and decided neither:

1. The #2130 dual-name layer has **no retirement tracker** — verified: 12 open issues, none of them
   this, and a search across all states returns only the round's own six steps.
2. The readiness signal #2128's plan names — *"the old names are retired once the connector register
   shows all six are over"* — **cannot ever report it**. Verified against the tree: every
   `connectors/*.json` stores bare ids and zero filenames, and `check-consumer-drift.ps1` resolves a
   lens through `Get-SpecialistFileNameCandidates` only in order to compare its **body**, never
   reporting which spelling it found.

The issue then listed three answers: build the signal, rekey the retirement on something else, or keep
the layer forever. **This branch takes the first, and the reason it needs no further decision is that
the other two reverse a decision that is Dave's.** Decision 1 of September 19, 2026 already fixed both
halves — *"Not a permanent dual-name state"* rules out the third, and the register sentence is the
second. Building the signal **implements** that decision; rekeying or abandoning it would overrule it,
and neither is a call this branch may make. The signal is also the thing option 2's own fallback (*"a
manual sweep of the six checkouts"*) would otherwise be done by hand.

#### One correction to the issue, carried into the work

#2289 describes the layer as a bridge *"carried until the six consumers are migrated"*. That is exact
for **Lens** and wrong for the other three kinds: `Get-SpecialistFileShapes`' own banner states that a
reader runs against a consumer's **plugin cache**, which holds whatever version that machine last
installed, so manual/persona/subagent are keyed on installed versions rather than on this register.
Dave's sentence is about the lens convention specifically. Every artefact this branch writes therefore
says **Lens only**, in the roll-up's own closing line as well as in the prose — a register signal read
as covering all four kinds would retire three rows on evidence about one.

### CREATE

- [x] `Get-SpecialistNamingState` in `scripts/lib/check-report-lib.ps1` — the classifier: hand it the
      filenames in a tree and it reports `Current` / `AlsoRead` / `Mixed` / `None`, counting names that
      match neither rather than dropping them. Named after the shapes table (`Current`/`AlsoRead`),
      never `new`/`legacy`, for the reason that table's banner gives.
- [x] Mirrored to the three plugin copies via `scripts/sync/build-shared-scripts.ps1`.
- [x] `check-connectors.ps1` check 7 — a non-counting `[LENS-NAMING]` line per connector, measured
      across every `Get-LensDirCandidates` directory for every published plugin.
- [x] `check-connectors.ps1` roll-up — the register-wide verdict, with its coverage stated first and
      **three** endings, so a partial sweep can never read as the window being open.
- [x] `connectors/README.md` — a section under *The check* stating the signal, and the four things
      about it that are deliberate.
- [x] `Get-SpecialistFileShapes`' banner — points at the tracker and restates the Lens-only bound at
      the one place a reader deciding to prune a row actually lands.
- [x] Filed the tracker the issue's first half asks for: **#2292**, on #1848's precedent, keyed on this
      signal and carrying the bounds.

### TEST

- [x] `scripts/tests/check-report-lib.tests.ps1` — 14 new assertions over the classifier: the four
      states, a null list, unrecognised names counted rather than dropped, kind independence
      (a lens name is not a subagent name), and the display names composed from the table rather than
      written as literals. 398 pass, 0 fail.
- [x] Ran `check-connectors.ps1 -SkipDrift -SkipVersions` on the real register. It answered, and the
      answer is a real measurement rather than a self-test: **3 of 6 reachable here, 1 over, 2 not
      over** — both BWJ stores still carry 25 lens files each on `<g>-<id>-extension.md`, and three
      connectors are not checked out on this machine, so the verdict printed is
      `NOT ANSWERABLE FROM THIS MACHINE`.
- [x] Lint gate + full suite via `open-pr.ps1`.

#### The test gap, named rather than papered over

There is **no suite over the roll-up itself** — the classifier is tested, the assembly around it is
not. `check-connectors.ps1` takes its input from the live register and six real checkouts, so covering
the three endings would mean a fixture register plus fabricated consumer trees, and that fixture would
then be the thing under test. The measurement above exercises two of the three endings on real data;
the third (`ALL N ARE OVER`) is unreachable until the migration actually completes, which is the
condition #2292 exists to wait for.

### DEPLOY: feat/2289-lens-naming-readiness-signal

`check-connectors.ps1` can now answer the question the #2130 dual-name layer's retirement is keyed on:
which spelling each registered consumer's repo lenses are actually written in. A non-counting
`[LENS-NAMING]` line per connector, and a roll-up across the register that states its coverage before
its verdict — `NOT ANSWERABLE FROM THIS MACHINE`, `NOT YET`, or `ALL N ARE OVER`, and only the third
opens the window. The classifier behind it, `Get-SpecialistNamingState`, reads the shapes table rather
than any literal, so a future rename step that flips a row cannot leave the report describing the wrong
file.

Dave's decision of September 19, 2026 retires the old lens names *"once the connector register shows all
six are over"*, and the register could not show it: manifests store bare ids and no filenames, and the
one check that does resolve a lens file resolves it to compare its **body**. A bridge whose expiry
cannot be established is a permanent one by default, which is what #2289 measured. The signal is
**measured, never declared** — no `lensNaming` manifest field, on the same ground the `plugins[].id`
rule already stands on: hand-maintained state about somebody else's tree turns the register into a false
alarm about a migration nobody ran.

Run on the real register it reports 3 of 6 connectors reachable on this machine, 1 over and 2 not —
so the honest answer today is that the window is not yet answerable, which is exactly the fact that was
previously unobtainable. #2292 is the retirement tracker the issue's other half asks for.

**Score:** 3

#### What makes this deploy extra special

Nothing a consumer runs changes. `check-connectors.ps1` and the `connectors/` register are
source-repo-only — a consumer's session check runs `plugin-versions` in `-Brief` mode instead — and the
new classifier travels in the plugin payload unused by any consumer-side caller. The `[LENS-NAMING]`
lines are deliberately neither `[ERROR]` nor `[INFO]`, so they do not count and no session hook surfaces
them: a consumer still on the old spelling is **not broken**, which is the entire purpose of the layer
being measured.

**Score:** N/A

#### Pull Request

The lens-naming readiness signal the #2130 dual-name retirement is keyed on
