## fix/2272-guard-repo-field-two-more-sites

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

#2272: `check-consumer-siblings.ps1` reads `$label = [string]$m.repo` off a consumer's own
connector manifest and prints it raw at two sites just above the group loop's ONLY-IN/PARTIAL/
DRIFTED/SHIPPED block -- the block df25f9f6 (#2248) guarded with `Format-SafePathToken`. A `repo`
field carrying an embedded newline forges a second console line, exactly the harm #2248's own
reasoning names. Fix: guard `$label` at both remaining sites with the same function already used a
few lines below, so the whole loop is consistent.

### CREATE

- [x] Guard `$label` at both unguarded sites (the `$unreadable` line and the `read ... :` line)
      with `Format-SafePathToken -Value $label`, matching the guard already applied to the
      ONLY-IN/PARTIAL/DRIFTED/SHIPPED block a few lines below.

### TEST

- [x] Reproduced the issue's repro (`$label = "acme/repo`n[INJECTED]"`) against the unpatched line
      and confirmed the guarded line welds it to one line with no bracket, matching the ONLY-IN
      lines' existing behaviour.
- [x] `sibling-divergence.tests.ps1` (70 pass, 0 fail) and `check-report-lib.tests.ps1` (382 pass,
      0 fail) green -- the underlying lib and the divergence logic this script depends on are
      unaffected by a two-site console-formatting change.
- [~] A dedicated `check-consumer-siblings.tests.ps1` regression suite is not added here -- #2272
      itself was filed by a session already building that suite on a separate, unmerged branch
      (fix/2248-guard-raw-foreign-text-prints); duplicating that effort here would fork the same
      test file in two places. This branch instead verifies by direct repro (above) plus the
      existing suites for the guard function and the comparison logic.

### DEPLOY: fix/2272-guard-repo-field-two-more-sites

`check-consumer-siblings.ps1` printed a sibling's own manifest `repo` field raw at two console
sites -- the per-member "read" line and the "not compared" line built from it -- both sitting just
above the block df25f9f6 (#2248) already guarded with `Format-SafePathToken`. A `repo` field
carrying an embedded newline forged a second console line; both sites now go through the same
guard as their neighbours, so the whole loop treats this manifest field consistently.

**Score:** 1

#### What makes this deploy extra special

Same value class and same script as #2248: a sibling checkout's own manifest text, read back to
the person running the comparison. Nothing was exploited, and this closes the two sites #2248's
own widening did not reach.

**Score:** 1

#### Pull Request

Guard the manifest repo field at the two console sites df25f9f6 (#2248) missed

