## fix/2641-only-push-deletes-missing-path

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

Inbound #2641 (consumer BWJ-Development/xoxowildhearts#307). Verified on pickup:

- **Symptom:** the four statements stand (`live-push-rules.ps1:189`, `live-record-lib.ps1:69,84`,
  `live-preflight.ps1:466`, the live-preflight skill), plus two more the report did not name:
  `prepare-release.ps1:358,363` in dkj-policy-bwj and the sync-main skill.
- **Reason:** read in the installed `@shopify/cli` 4.8.2 here. `chunk-F4HKZVXJ.js`: the delete step
  returns early only on `o.nodelete`; its set is `e.applyIgnoreFilters(remote).filter(k => !e.files.has(k))`.
  `chunk-ZKWJX5GE.js` `Ho` builds that filter from `{ ignore, only }`. So `--only <path>`, absent
  locally, deletes it on the theme. Not executed against a store: no store is reachable from this repo,
  and pushing a dummy to a real store is outward-facing.
- **#2566** was built on the opposite premise, stated as its "why" and never verified.

#### The design

- A `deleted` row stays out of the ordinary push list. live-preflight composes a **second, separately
  named command** with the same builder (`Format-LivePushCommand -Only $deleteFiles`), so authorising a
  deletion on live stays its own visible act.
- The deleted paths go through the drift check **in a call of their own**. A deletion destroys live's
  content like an overwrite does, so a third party's content at that path stops it. A refusal there
  withholds only the deletion command (a warning), unless deletions are the range's only theme change
  (a refusal). A consumer drift check that cannot read a locally missing path fails the same, safe way.
- The live-push record writes a deleted row as `live` when the deletion command was composed
  (`Format-LivePushRecord -DeletionsCarried`), `hold` otherwise.
- The report's "`[A] ... live holds our old copy`" is sync-main's verdict and is not available to the
  preflight, which reads no live bytes itself; the drift check is the preflight's own reading of live,
  so it is the gate used.

### CREATE

- [x] live-push-rules: the `deleted` verdict's docstring and reason corrected; `Format-LivePushCommand` notes it composes the deletion too.
- [x] live-record-lib: `-DeletionsCarried`, the header and the format docstring.
- [x] live-preflight: the delete group, the separate drift call, the deletion command, the record switch.
- [x] prepare-release (bwj): the deletions and push-list details.
- [x] live-preflight and sync-main skills.
- [x] Mirrors rebuilt with `build-shared-scripts.ps1`.
- [x] Review round (Victor, Edith, Sebastian). A drift check's success-stream output leaked into `Invoke-DriftCheck`'s return value and read a pass as a refusal; it now goes to `Out-Host`. With no drift check at all, the deletion command is withheld. Skill description, verdict count and wording fixed.

### TEST

- [x] `live-push-rules.tests.ps1` (112 pass): the reason, the retired claim absent from both drivers, the preflight wiring asserted on source, the deletion command's spelling, the output routed to the host, and both withholding paths.
- [x] `live-record-lib.tests.ps1` (82 pass): the new header, `-DeletionsCarried`, and an entry whose only change is a carried deletion reading as live.
- [x] `dkj-policy-bwj.tests.ps1` (498 pass).

### DEPLOY: fix/2641-only-push-deletes-missing-path

live-preflight now prints a separate deletion command for theme files the trunk deleted. It no longer
leaves them on live with no route off it. An `--only` push of a path missing from the checkout
removes it from the theme, which the plugin had stated as impossible in six places (#2641). This\nsupersedes the #2566 entry above on one point. A deleted file is no longer listed under `held` as a\nseparate store decision: it goes under `delete` and gets that command.

**Score:** 2

#### What makes this deploy extra special

A store running `live-preflight` gets a second, separately named command beside the push. That command
removes the files the release deleted, after the drift check has passed on them. Before, those files
stayed on live, and the plugin said no push could remove them.

**Score:** 3

#### Pull Request

live-preflight: a trunk-deleted theme file gets its own --only deletion command