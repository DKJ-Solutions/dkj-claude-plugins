## feat/1843-portable-repo-settings-runner

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

Step 1 of #1843's two remaining items. Move `scripts/lint/check-repo-settings.ps1` into the plugin,
register it in the shared-scripts drift lint, add a `Get-ExpectedRepoSettings` contract record so Part 2
reports the seam, and have Part 3 scaffold `.github/workflows/repo-settings.yml` over the second-checkout
mechanism. Checker-and-reporter only -- never an applied write -- per Dave's September 12, 2026 scope
decision on #1843: *identical scripts available, not identical rules enforced*. The CI skeleton (item 2)
is deliberately NOT in this branch: a different subject with a different repair, which is the lesson
#1805 stated and the reason the labels half was already split off to #1895.

### CREATE

- [x] `check-repo-settings.ps1` may travel: the comment declining the mirror is amended rather than
      flipped, so both readings stay legible. It was declined on the ground that "#1726 asked about this
      repo"; #1843 asked the wider question and the scope decision answered it.
- [x] The source-repo guard (`Assert-OwnCopy`) joins it. A repo-local script has no released copy to run
      stale; a mirrored one does, and `source-repo-guard.tests.ps1` exempts only hooks.
- [x] `-Trunk` resolves from the `Get-TrunkBranchName` seam when not passed explicitly, falling back to
      `main`. Without it a consumer on `master` aimed every branch-rules read at a branch they do not
      have, and `-RequireRead` then reported a red run whose real cause was never named.
- [x] Registered in `scripts/lib/shared-scripts-lib.ps1` and mirrored by `build-shared-scripts.ps1`.
- [x] A `Get-ExpectedRepoSettings` contract record, `adopt: decide` -- the shape of the declaration
      travels, the values do not. Blueprint regenerated: 40 records, 21 `decide`.
- [x] Part 3 scaffolds `.github/workflows/repo-settings.yml`: `contents: read`, `persist-credentials:
      false`, `-RequireRead`, the trunk baked in, the checkout deliberately unpinned because the job is
      read-only.
- [x] A pre-existing mis-attribution that adding a third target exposed: the `FOLD_PUSH_TOKEN` reminder
      and the queue-active live-defect count both keyed on a generic "anything missing" counter, so a
      missing `repo-settings.yml` would have counted as a live queue defect and the secret reminder would
      have fired for a run that created no fold runner. Fixed with a per-target `QueueRelated` flag and a
      `$foldRunnerCreated` flag keyed on the fold runner's own path.
- [x] Victor's finding: the new comment claimed the scaffolded fold/resolves pair is SHA-pinned. It is
      not -- and because that comment is written INTO the consumer's own file, every consumer would have
      read a reassuring untruth about their own two runners. Rewritten to contrast against the source
      repo's own in-tree workflows, which genuinely are pinned, and to name the real gap as #1904.
- [x] Edith's finding: `plugins/dkj-policy/scripts/README.md` still described Part 3 as placing "the two
      CI runners", one row above the new row naming the third. Repaired.
- [x] Docs that would otherwise have read as if Part 3 still places two files:
      `skills/adopt-dkj-policy/SKILL.md` (frontmatter, bullets, table note, a new section) and
      `CONTRIBUTING-portable.md`.

### TEST

- [x] `check-plugin-integrity.ps1` -- 0 errors. It caught one real omission on the way: the new script
      was missing its row in the mirror table in the plugin scripts README.
- [x] `build-shared-scripts.ps1 -Check` and `build-config-blueprint.ps1` -- mirror and blueprint
      byte-consistent with their generators.
- [x] All 100 suites under `scripts/tests/` -- green, individually and in a sequential sweep.
- [x] `repo-settings-gate.tests.ps1` extended for the trunk seam: honoured when present, `main` when
      absent, and an explicit `-Trunk` winning over both. Plus one case that runs the registered mirror.
- [x] `adopt-merge-queue.tests.ps1` 76 -> 103 asserts. The last ten close the gap Victor named: a fixture
      with fold and resolves already present and only `repo-settings.yml` missing, asserting the two are
      byte-for-byte untouched and that the `FOLD_PUSH_TOKEN` reminder stays silent -- the negative twin of
      the existing positive case.
- [x] `Test-NoLeakedCredential` replaces a plain substring match that fired on COMMENT text, which had
      already forced accurate prose to be reworded once. It strips comment lines, still catches a real
      `issues: write` line and a real `secrets.FOLD_PUSH_TOKEN` reference, and three asserts prove that
      against synthetic fixtures rather than by inspection.
- [x] `script-contract.tests.ps1` -- record count 39 -> 40, the new record pinned by name.

### DEPLOY: feat/1843-portable-repo-settings-runner

The repo-settings drift detector stops being this repo's private tool. `check-repo-settings.ps1` is now
a shared script in `dkj-policy`, `Get-ExpectedRepoSettings` is a contract record marked `decide` -- the
comparison travels, the values stay the consumer's own -- and Part 3 of the adoption scaffolds
`.github/workflows/repo-settings.yml` over the second-checkout mechanism the fold and resolves runners
already use. It reads `gh api` and reports; it never writes a setting, because repo settings are the
owner's surface. `-Trunk` now comes from `Get-TrunkBranchName`, which is what makes the check usable at
all in a repo whose trunk is not `main`: every read was previously aimed at a branch that does not exist
there, and `-RequireRead` turned that into a red run naming the wrong cause. Adding the third target also
exposed that the `FOLD_PUSH_TOKEN` reminder and the queue-defect count both hung on one generic
"something is missing" counter, so each now keys on the thing it is actually about.

**Score:** 3

#### What makes this deploy extra special

A consumer's ruleset, its bypass actors and its merge switches are GitHub-side state: nothing in their
tree changes when one moves, so a record and the live state can disagree indefinitely with nothing saying
so. This repo learned that the expensive way -- three drifts in eight days, two of them with mechanical
consequences: the org transfer emptied `bypass_actors` and every fold was dead for a day (#1244), and
`merge_queue` was added and removed with no trace at all (#1499, #1720). Until now the detector built from
that experience ran here and nowhere else. After the next release an adopting repo gets the same dated,
daily answer about its own settings, against its own declared values.

What it deliberately does not get is enforcement. Rulesets and required checks remain the repo owner's
surface, so the runner reports and stops -- the reachable goal being identical scripts available, not
identical rules enforced.

**Score:** 3

#### Pull Request

The repo-settings drift detector travels: check-repo-settings into the plugin, a Get-ExpectedRepoSettings seam, and a scaffolded repo-settings.yml
