## docs/2203-seen-repair-remeasured

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

Answer #2203: re-run its three-way comparison on a quiet machine, produce the number its two earlier
attempts would not stand behind, and state the `try`/`catch` cost as a figure rather than an
order-of-magnitude claim. Record both in [Nolan #25's lens](../.claude/specialists/lenses/specialist-06-25-lens.md),
which is where this repo's wall-clock measurements live.

#### Nothing in `scripts/**` changes on this branch, deliberately

The subject of the measurement -- #2199's `-Seen` repair -- sits on `fix/2199-one-lens-assembler`,
which is parked with no pull request. What the measurement found is a design call on somebody else's
unmerged branch, so it left this session as
[#2210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2210) rather than as an edit here.

### CREATE

- [x] The measurement recorded in `.claude/specialists/lenses/specialist-06-25-lens.md`: the method,
      the four-variant table, the `try`/`catch` figure, and the one caveat that would otherwise be
      rediscovered (component isolation does not sum to the whole on this path).
- [x] The consequence filed as #2210 -- the +11% is the CALL, not the second pass, so the docstring on
      `fix/2199-one-lens-assembler` attributes its own measurement to the wrong cause.

### TEST

- [x] The measurement itself is the test, and it is reproducible rather than asserted: n=5 per variant,
      rotated batch order, every batch bracketed before and after by the contention pre-flight and
      discarded unless both brackets were in band (2,187-2,256 ms across the whole run).
- [x] Correctness proved rather than assumed: all four variants return an identical 33-row corpus, so
      the comparison is of the same work. A variant that had silently lost a row would have measured
      faster for the wrong reason.
- [x] The baseline is still the baseline: `main` gained 9 commits during this branch, one of them
      touching `entry-scaffold-lib.ps1` (`e9f6d796`), and the diff against `8fc89977` over that file is
      docstring prose only -- 0 executable lines. So the `main` row is executable-identical to today's
      trunk.
- [x] `check-plugin-integrity.ps1` and the full suite run, via `open-pr.ps1`'s own gate.

### DEPLOY: docs/2203-seen-repair-remeasured

#2199 promoted the lens assembly into one shared function and that made the always-on consumer-prose
path 11-12% slower; the repair that shipped with it -- handing the caller's own dedup set in through
`-Seen`, so one pass replaces two -- had never been shown to recover the cost. It does not. Measured on
a quiet machine, n=5 per variant, it is +0.05 ms against the shape it replaced, inside the noise.

What the bisect found instead is that the whole +11% is the *call*: restore only the call site to the
inline walk, on the repair's own file, and the cost is back on `main`'s band. Everything else on that
branch -- the new function, the fail-closed guard, both `try`/`catch` wraps, 185 lines of docstring --
is free. And the `try`/`catch` question is now a number rather than an estimate: 0.09 us median per
entry, which is 0.0005% of a call.

**Score:** 2

#### What makes this deploy extra special

The third attempt at this measurement is the one that worked, and what separates it from the two that
did not is written down rather than left as luck. Two changes: the batch order rotates every round, so
a drift cannot land on one variant; and the contention pre-flight brackets every *batch* instead of
every round -- which is not a refinement but a measured correction, because a round that opened at
2,279 ms still came back with a batch at 76 ms/call against its own 43 ms band.

That matters beyond this issue. This repo has no working OS-level CPU instrument (`Get-Counter` for
`% Processor Time` errors with `c0000bb9` on this box), so a self-timed band is the only thing standing
between a wall-clock figure and folklore -- and the session that produced the figure is exactly the
party who cannot tell the two apart without it.

**Score:** 1

#### Pull Request

The -Seen repair re-measured: the +11% is the call, not the second pass
