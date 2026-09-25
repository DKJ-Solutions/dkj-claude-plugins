## fix/2502-oem-encoding-helper

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

The OEM-codepage lookup that decodes the gate's capture files was written out three times in
`native-capture-lib.ps1`. All three readers must agree (#2295), so they now share one definition.

### CREATE

- [x] Add `Get-NativeCaptureOemEncoding` to `scripts/lib/native-capture-lib.ps1`, and point
  `Test-GateSuiteSilent`, `Write-GateCaptureBlock` and `Invoke-TestSuiteGate`'s retention block at it.
  Both plugin mirrors (dkj-policy, dkj-subagents-shopify) copied byte-identical. The issue's
  "not measured" question is answered: no other `.ps1` in the tree repeats the idiom, apart from the
  suite that asserted the decode.

### TEST

- [x] `native-capture.tests.ps1`: the existing decode-equivalence assert now resolves the encoding
  through the helper, and a new source pin holds the lib to exactly one `TextInfo.OEMCodePage`
  lookup. 353 pass, 0 fail.

### DEPLOY: fix/2502-oem-encoding-helper

The test gate's three readers of a suite's capture files (the print, the silent-suite check and the
retention decision) now take their decode from one helper, `Get-NativeCaptureOemEncoding`, instead of
three copies of the same OEM-codepage lookup
([#2502](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2502)). This changes no behaviour.
It prevents a later edit from changing one decode and not the other two, which would bring back the
print-versus-retention disagreement #2295 repaired. A suite assert refuses a second lookup.

**Score:** 1

#### What makes this deploy extra special

N/A -- an internal refactor of the test gate; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

native-capture-lib: one helper for the capture files' OEM decode
