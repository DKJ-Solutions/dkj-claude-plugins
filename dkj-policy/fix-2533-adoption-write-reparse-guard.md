## fix/2533-adoption-write-reparse-guard

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

#2533, filed from the #2531 security review: the adoptions write into files a consumer already has
without checking for a reparse point, so a `CLAUDE.md` that is a symlink, or a `scripts/` directory
that is a junction, would have the write land outside the repo. Verified on pickup by reading the write
sites: `adopt-workflow-folder.ps1` (the `repo-config.ps1` seam append and, since #2532, the shared
`Add-ClaudeMdImportLine`), `adopt-extension-import.ps1` (the same writer), and `bootstrap.ps1`
(the orchestrator import into `CLAUDE.md`, which the issue inferred and a read confirmed).

The guard goes in its own leaf lib rather than in `check-report-lib.ps1` as the issue suggests.
`check-report-lib` loads a sibling `repo-root-lib.ps1` unguarded, and `dkj-policy-bwj` ships its own file
under that name, so the bwj writer could not load it. The guard judges every directory between the file
and the repo root, not only the file, because a junctioned `scripts/` holds a plain `repo-config.ps1`.
It reads each entry from its parent's listing, because `Test-Path` follows a link and reads a symlink to
a missing file as "no file here", and creating that file would create the link's target.

### CREATE

- [x] `scripts/lib/write-target-lib.ps1` (new): `Get-WriteTargetReparsePoint`. Mirrored into
  dkj-policy, dkj-policy-bwj and dkj-subagents-alpha; row added to `plugins/dkj-policy/scripts/README.md`.
- [x] `claude-md-import-lib.ps1`: `Add-ClaudeMdImportLine` takes a mandatory `-Root` and returns
  `refused` before reading or writing anything.
- [x] `adopt-workflow-folder.ps1`: the seam append gets a fourth condition, and the refused case is
  reported; the `CLAUDE.md` write reports a refusal with the line to add by hand.
- [x] `adopt-extension-import.ps1` and `bootstrap.ps1`: the same refusal for their `CLAUDE.md` write.

### TEST

- [x] `write-target-lib.tests.ps1` (new): a plain file, a missing path, a path outside the root, a `..`
  escape, a file under a junctioned directory, the junction itself, and a root that itself sits under a
  junction (not judged). 8 passed. The file-symlink cases (linked and dangling) skip on this machine,
  which cannot create file symlinks without Developer Mode or elevation, and say so rather than pass.
- [x] `adopt-workflow-folder.tests.ps1`: a junctioned `scripts/` leaves the seam unanswered and the file
  outside untouched. 143 passed.
- [x] `bwj-extension-import.tests.ps1` 27 passed; `bootstrap-drift.tests.ps1` 212 passed;
  `shared-scripts.tests.ps1` 1084 passed; `check-plugin-integrity.ps1` 0 errors.
- [~] A test of the `CLAUDE.md` refusal end to end: dropped. `CLAUDE.md` sits at the repo root, so only
  a file symlink can redirect it, and this machine cannot create one. The guard function is tested on
  the same shape where the machine allows it.

### DEPLOY: fix/2533-adoption-write-reparse-guard

The adoptions no longer write through a symlink or junction. Before each write into a file the consumer
already has, `adopt-dkj-policy`, `adopt-dkj-policy-bwj` and `specialists-init` check whether the file,
or any directory between it and the repo root, is a reparse point. When it is, nothing is written and
the run says what to add by hand. Before this, a `CLAUDE.md` that was a symlink, or a `scripts/`
directory that was a junction, would have had the write land outside the repo. The check is
`Get-WriteTargetReparsePoint` in `write-target-lib.ps1`, and it also catches a symlink whose target does
not exist. No consumer is known to link its governance files this way; this closes the path before one
does.

**Score:** 1

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

Adoption refuses to write into CLAUDE.md or repo-config.ps1 through a symlink or junction

