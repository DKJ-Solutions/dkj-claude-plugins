## fix/3637-canonical-house-style-not-a-copy

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

#3637. In this source repo the house-style gate held the canonical stylesheet in
`plugins/dkj-policy/assets/house-style/` to the installed plugin's pin, which lags `main` between cuts (seven
house-style commits since v5.36.0), so every session here opened with an advice to revert merged work. The
fallback to the page at the tag returns the same hashes, so nothing cleared it before the next cut. The fix
makes the lib recognise the source repo (its marketplace manifest publishes `dkj-solutions`) and exempt
exactly those two files from check 1, while still reading them as the verified stylesheet for check 2.
Independent of #3636, which moves the checksum write to the cut and touches neither the lib nor the hook.

### CREATE

- [x] `house-style-rules.ps1`: `Test-HouseStyleSourceRepo`, `Get-HouseStyleCanonicalDir`, and the exemption in
  `Invoke-HouseStyleCheck` (exact paths, a `Canonical` flag per copy, a note when it differs from the tag)
- [x] `check-house-style.ps1` prints a canonical copy as `[source]`; the session hook counts it apart
- [x] `house-style` skill page: check 1 names the exemption

### TEST

- [x] `check-house-style.tests.ps1`: a fixture source repo (canonical copy ahead of the pin passes with the
  note, check 2 still runs, the hook says so), a vendored and a nested demo copy there still fail the pin, a
  manifest publishing other plugins or an unreadable one is a consumer; this repo reads as the source. 102 passed
- [x] The gate on this repo against the installed v5.36.0 page: `[FAIL]` before, `[OK]` after
- [x] Review (Victor, Sebastian, Edith) taken in: exact paths instead of the folder prefix, "differs from"
  instead of "ahead of", a positive hook assert, the wording of the outputs and the skill sentence
- [x] `check-plugin-integrity.ps1` 0 errors

### DEPLOY: fix/3637-canonical-house-style-not-a-copy

A session in `dkj-claude-plugins` no longer opens with a warning to replace the canonical house stylesheet
with the last release's file, a step that would revert work merged since that cut
([#3637](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3637)). The two files in
`plugins/dkj-policy/assets/house-style/` are now named as the source and still read for the redefine check.
Every other copy, in every repo, is held to the pin as before.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

the source repo's canonical house style is not held to the installed pin

