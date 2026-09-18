## fix/2115-repo-root-decoding

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

`core.quotePath` does not reach `rev-parse --show-toplevel` (measured). The repair is to change the
QUESTION rather than the decode -- `--is-inside-work-tree --show-cdup` -- through one shared helper
rather than ~20 hand-repeated call sites.

#### Why this is not the repair the issue proposed

#2115 proposed `Invoke-NativeCapture ... -Utf8`. Correct in mechanism and unavailable where it matters:
a script resolves the repo root in order to FIND `scripts\lib\`, so the dot-source that would supply
that function runs after the line that needs it. `--show-cdup` needs no lib, no capture file and no
second child process, which is what lets the bootstrap sites use it. The reason is written into the
lib's own synopsis so the next reader does not re-propose `-Utf8`.

### CREATE

- [x] `scripts/lib/repo-root-lib.ps1` -- `Get-GitTopLevelPath`, one definition, returning
      `Path`/`ExitCode`/`Error` so a refusing caller can say why (#1917's judgement kept verbatim).
- [x] The three canonical resolvers routed through it: `Resolve-CheckRoot` (check-report-lib),
      `Resolve-CheckRepoRoot` (consumer-check-lib), `Resolve-GuardRepoRoot` (source-repo-guard-lib).
- [x] The remaining direct readers converted -- the five lint checks' lib-free degraded branch, the
      two maintenance measurers, the two suite-timing scripts, `new-internal-note`,
      `publish-to-business`, `check-connectors`, `find-specialist-mentions`, `park-cycle`,
      `worktree-lane`. 18 invocation sites in `scripts/`.
- [x] The two sites that may NOT reach a lib write the same question out by hand, each saying why:
      `new-branch.ps1`'s no-lib refusal branch, and `dkj-policy-bwj`'s self-contained
      `repo-root-lib.ps1`.
- [x] `Resolve-RepoRootOrFail`'s refusal repointed at the command it now actually runs -- a refusal
      quoting a command the script no longer issues sends the reader to reproduce the wrong thing.
- [x] Mirrored into the three plugins that carry a reader (`dkj-subagents-alpha`, `dkj-policy`,
      `dkj-subagents-shopify`) and registered in `Get-SharedScriptPairs`.
- [x] `.claude/rules/language-layers.md`: the reading rule now states which half of the class
      `core.quotePath` reaches, and the general lesson about a sweep whose predicate names a repair.

### TEST

- [x] `scripts/tests/repo-root-lib.tests.ps1` -- 17 asserts. The accented-checkout case is asserted on
      RAW BYTES from a child writing to a file, never by setting `[Console]::OutputEncoding`: that
      setter is console-wide and the gate runs every suite on one console, which is how inbound #821
      stayed invisible.
- [x] The `.git`-directory case is pinned (case 6): `--show-cdup` alone exits 0 there, so a straight
      flag swap would have resolved `.git` itself as the root and reported success.
- [x] A repo-wide guard in `shared-scripts.tests.ps1` refuses any new executable
      `rev-parse --show-toplevel` in the tree, with a four-file fixture proving it still fires and
      still exonerates the prose that quotes the old form.
- [x] Two suites went red on the conversion and both were real: `new-branch.tests.ps1` pinned the old
      command in the refusal text, and `find-specialist-mentions.tests.ps1` read
      `git status --porcelain` without `-uall`, which collapsed the newly untracked `scripts\sync\`
      into one directory entry its filename filter could not match.
- [x] Full gate green: `check-plugin-integrity.ps1` 0 errors, 117 suites.

### DEPLOY: fix/2115-repo-root-decoding

Every repo-root read in this workflow now asks a question a console code page cannot corrupt. `git
rev-parse --show-toplevel` returns a RAW path, and Windows PowerShell 5.1 decodes a native child's
stdout with `[Console]::OutputEncoding` -- so in a checkout under an accented directory name it
returned a well-formed string that matched nothing, and what followed was a `Test-Path` miss reported
as *"cannot determine the repo root"*, or a silent skip in the branch of a session hook with no
`CLAUDE_PROJECT_DIR` to fall back on. The read is now `--is-inside-work-tree --show-cdup`, whose output
is a run of `../` segments and no filename at all, joined onto a base PowerShell already holds
correctly; the second flag is not decoration, because `--show-cdup` alone exits 0 inside `.git` where
`--show-toplevel` exits 128. One definition in `scripts/lib/repo-root-lib.ps1`, mirrored into the three
plugins that carry a reader, 18 call sites converted plus the two that may not reach a lib, and a
repo-wide guard that refuses the flag anywhere in the tree.

**Score:** 3

#### What makes this deploy extra special

It is **latent here and live for a consumer**, which is the shape that accumulates. This checkout's
path is ASCII, so nothing here has ever failed on it; a consumer whose checkout sits under an accented
directory name is the ordinary case on a non-English Windows box -- `C:\Users\<name>\Bureaublad\...`,
a company folder with a diacritic -- and the shared libs and lint checks this workflow mirrors into
their plugin cache are exactly the files that would fail there.

The lesson worth keeping is about the **sweep**, not the flag. #2110's sweep concluded *"every other
reader is already correct"* while about twenty call sites were reading it, because its predicate --
*"neither forces `core.quotePath=true` nor passes `-Utf8`"* -- silently assumed its own repair was
available. `core.quotePath` governs the path output of the porcelain that consults it, and `rev-parse`
is not such a porcelain: under the forced flag `ls-files` returns `"café.md"` ASCII-quoted while
`rev-parse --show-toplevel` returns raw UTF-8. A predicate that names a repair reads as *"these sites
are fine"* where it means *"these sites do not use a mechanism that could not have helped them"*.

**Score:** 4

#### Pull Request

Repo-root reads ask a question no code page can corrupt
