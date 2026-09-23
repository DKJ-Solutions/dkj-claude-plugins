## fix/2347-release-asset-reupload-by-id

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

Replace the prescribed `gh release upload --clobber` with a helper that deletes the stale asset by id,
uploads, and verifies the size.

#### Triage (#2347)

- Symptom not reproducible now: `v5.7.0` carries both assets at the committed sizes. #2349, filed from
  `gh release view --json assets` returning [], was a false negative of that read and is closed -- which is
  why the helper reads `releases/{id}/assets`.
- Reason inferred by the report (gh's name lookup) is not verified here; the repair does not depend on
  it, because the helper never asks gh to resolve an asset by name.
- Repair: the report's second option, a helper, since the upload runs twice per cut (step 5 and the
  second pass) and the by-id route plus the byte check is too long to retype.

### CREATE

- [x] `scripts/release/upload-release-asset.ps1` + plugin mirror, registered in `shared-scripts-lib.ps1` under the `cut-release` skill
- [x] `cut-release` SKILL.md: step 5 and the second pass call the helper; the `--clobber` line replaced with the measurement
- [x] `RELEASES-portable.md` closing step names the helper; the plugin scripts README carries a row (the root `scripts/README.md` was removed on the trunk by #2356)
- [x] `scripts/tests/upload-release-asset.tests.ps1` against a fake gh that returns the 422 on a duplicate name
- [x] Read the asset list from `releases/{id}/assets`, not the release-level read: `gh release view --json assets` returned [] for v5.7.0 while that endpoint listed both (#2349, closed as a false negative)
- [~] Is the change visible in the frontend / storefront? No -- a release script and its docs.

### TEST

- [x] `upload-release-asset.tests.ps1`: 21 asserts green -- it caught a real bug on the way (an empty asset list unrolled to `$null` and read as an unreadable Release, which would have broken step 5's first upload)
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: fix/2347-release-asset-reupload-by-id

The `cut-release` skill told the second pass to re-upload an edited release document with `gh release
upload --clobber`. At `v5.7.0`, on gh 2.101.0, that returned `HTTP 422 ... ReleaseAsset.name already
exists` and left the stale asset in place, and `gh release delete-asset` reported it *not found*. A new
shared script, `upload-release-asset.ps1`, now does both uploads: it reads the Release's assets from the
`releases/{id}/assets` endpoint (not `gh release view`, which listed none for `v5.7.0`), deletes a same-named asset **by id**, uploads without `--clobber`, and exits 1 unless the
published asset has the file's exact byte count. The skill page and `RELEASES-portable.md` call it at
step 5 and in the second pass (#2347).

**Score:** 2 -- the old one-liner failed loudly but left the published note one revision behind, and
the fallback a reader reached for failed too; the byte check replaces a size somebody had to watch.

#### What makes this deploy extra special

N/A -- the reader is whoever cuts a release in a repo running this workflow, and for them it is a
different command at two steps of the same checklist, nothing to migrate.

**Score:** N/A

#### Pull Request

cut-release: re-upload a Release attachment by asset id and verify its byte count
