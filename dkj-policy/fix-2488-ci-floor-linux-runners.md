## fix/2488-ci-floor-linux-runners

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

Unblocked 2026-09-25: #2487 landed as PR #2498. Measure first, because #2488 itself says the size of the
script changes is inferred, and no session machine here has `pwsh` or WSL -- so the measurement runs on
`ubuntu-latest` itself, as a temporary push-triggered probe on this branch
(`.github/workflows/linux-runner-probe.yml` + `.github/probe-2488.ps1`).

#### Found statically, before the probe

- Beyond what the issue lists: the runner path launches CHILD processes by the literal name
  `powershell`, which does not exist on `ubuntu-latest` -- `ship-pr.ps1` L986 (open-pr), L3768 (fold),
  L3907 (verify-resolved-issues) and `verify-pushed-merges.ps1` L236. Either a host-resolving helper or a
  `powershell` -> `pwsh` shim in the runner; the probe's two passes separate that from real
  5.1-versus-7 differences.
- `merge-on-green` cannot be proved on its own PR (workflow_run runs the default branch's file), and it
  drives the largest code path (`ship-pr.ps1`, 4099 lines, plus open-pr, the fold and their libs).

#### What the probe measured (run 36152305956, 2026-09-25; re-run on the merged-up branch 2026-09-29)

- **Pass A** (no shim): all nine suites exit 1 on the first child launched as `powershell`. The name is
  the whole of that failure. It is also not confined to the four lines above: the tree launches children
  as `powershell` in many more places (`open-pr.ps1`, `cut-release.ps1`, `check-plugin-integrity.ps1`),
  so a per-site rename is far larger than a runner-level shim.
- **Pass B** (with a `powershell` -> `pwsh` shim): five suites green (`fold-changelog`,
  `repo-settings-gate`, `merge-on-green-lib`, `ship-pr-trusted-root`, `adopt-ci-floor`). The four red
  ones fail in the TEST HARNESS, not in runtime code: `verify-pushed-merges` (35) and
  `verify-resolved-issues` (11) plant their fake `gh` as `gh.cmd` on a `;`-joined PATH, which Linux
  neither executes nor splits, so the real `gh` answers instead; `native-capture` (4 + an abort) uses
  `cmd /c` as its test subject; `unfolded-entry-gate` aborts on a fixture `git rm dkj-policy\feat-alpha.md`.
- **Runner steps, read-only:** `pick-merge-on-green` and `check-repo-settings -RequireRead` behave as
  on Windows. `check-unfolded-entry -Branch main` flagged the branch's own document, because the probe
  checks out the branch, not main -- an artefact of the probe, not a defect.
- `.gitattributes` pins `* text=auto eol=lf`, so a fold committed from Linux writes the same bytes.

#### The shape: phased, decided here (a reversible default, per the constitution)

Three runners move now: `fold-on-merge`, `verify-resolved` and `repo-settings`. In #2487's consumer the
first two ran 265 times each in September, so they carry the bulk of the Windows minutes. Each moves to
`ubuntu-latest`, `shell: pwsh`, and a one-line `powershell` -> `pwsh` shim step, in the source's own
copies and in `adopt-ci-floor.ps1`'s templates alike. `merge-on-green` stays on `windows-latest` for now:
it drives `ship-pr.ps1`'s whole merge path, and a `workflow_run` runner cannot be proved on its own PR.
That move is its own issue. To keep the move proved, the four suites are made OS-portable, and a Linux
leg in CI runs the runner-path suites under `pwsh`.

### CREATE

- [x] Probe on ubuntu-latest: the nine suites of the runner path, twice (without and with a shim), plus
  the three read-only runner steps
- [x] Size the repair from the probe, and decide the shape (all four runners, or phased) -- phased, above
- [ ] Make the four red suites OS-portable (fake `gh`, PATH separator, `cmd` subject, fixture paths)
- [ ] Move `fold-on-merge`, `verify-resolved`, `repo-settings` to ubuntu-latest + pwsh + shim, source
  copies and `adopt-ci-floor.ps1` templates, with their `WINDOWS:` notes and the adopt-time cost line
- [ ] A Linux leg in `ci.yml` running the runner-path suites under pwsh
- [x] File the follow-up for `merge-on-green` (and the other Windows-only workflows) -- #2616
- [ ] Remove the probe files before the PR

### TEST

### DEPLOY: fix/2488-ci-floor-linux-runners

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

Move the CI-floor runners to ubuntu-latest + pwsh

