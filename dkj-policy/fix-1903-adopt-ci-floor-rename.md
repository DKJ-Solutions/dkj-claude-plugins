## fix/1903-adopt-ci-floor-rename

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

#### What #1903 asked and what the tree actually said

#1903 offered three options and reserved the decision for Dave, who took the specialist's
recommendation. Sylvester's verdict: **rename, clean break, no shim.**

Two things were checked before writing anything, because the report is a snapshot:

- **The third runner is not in the tree.** #1903 was filed from
  `feat/1843-portable-repo-settings-runner`, which sits on origin as a park commit carrying only its
  branch document -- `repo-settings.yml` is that branch's *plan*, not a state. So the "three runners
  under a two-runner name" half of the report does not stand yet.
- **The rest of it stands without that half.** `.SYNOPSIS` already opened with *"The CI floor"*, and
  the queue stopped being the policy on September 7 (#1546) and came off the source's own ruleset on
  September 9 (#1720). The name was the last part still saying "queue", independently of #1843.

#### Why no shim at the old path

Every reference was read first: the one **executable** caller is the run line on `adopt-dkj-policy`'s
Part 3 page, which ships in the same plugin release as the script, so the two cannot disagree in a
consumer's tree. No workflow, hook or lib invokes it. A shim would need its own registry entry and its
own suite -- two maintained names for one script, which is the ambiguity the rename removes -- and a
consumer who had wrapped the old path gets a loud file-not-found instead of a second silent name.

### CREATE

- [x] `scripts/task/adopt-merge-queue.ps1` -> `scripts/task/adopt-ci-floor.ps1`, with the rename and
      its reasoning written into the head of `.DESCRIPTION` (the shared source, not the lens)
- [x] `scripts/lib/shared-scripts-lib.ps1`: registry `Name`/`Source` repointed, and the entry's comment
      block rewritten -- it still described the queue as live policy and counted "three CI files"
- [x] `scripts/tests/adopt-merge-queue.tests.ps1` -> `adopt-ci-floor.tests.ps1`, internals and the
      `scripts/tests/suite-durations.json` key with it
- [x] `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md`: run line, plus a note recording the rename
      and that the old path is gone rather than forwarded
- [x] `plugins/dkj-policy/scripts/README.md`: the Part 3 row rewritten -- it led with "would survive a
      GitHub merge queue", which is the framing #1903 is about
- [x] the remaining 16 source-side files of prose and comment swept (`CONTRIBUTING-portable.md`, Sylvester's
      lens, both CI workflows, `repo-config.ps1`, seven scripts and libs, and four suites)
- [x] `dkj-policy/releases/**` deliberately untouched -- the archived release history is historical by
      the carve-out in `CLAUDE.md`
- [x] mirrors regenerated with `scripts/sync/build-shared-scripts.ps1` (6 updated)

### TEST

- [x] `check-plugin-integrity.ps1` -- 0 errors, including the shared-script mirror, skill-param,
      skill-command and shared-script-list checks that all read the registry name
- [x] `adopt-ci-floor.tests.ps1` -- 76 passed, 0 failed
- [x] `merge-queue-prereq.tests.ps1` -- 36 asserts, including the one pinning the registered pair name
- [x] `check-script-contract.ps1` -- 0 errors
- [x] full suite run via `open-pr.ps1`'s own gate

### DEPLOY: fix/1903-adopt-ci-floor-rename

`adopt-merge-queue.ps1` is now `adopt-ci-floor.ps1`, in both copies, with the test suite, the
shared-scripts registry entry, the durations key and 16 source-side files of prose following it -- closes #1903.
The queue stopped being this workflow's policy on September 7 (#1546) and came off the source's own
ruleset on September 9 (#1720); most repos running this workflow cannot have one at all (#1540). The
name was the last part that still promised it. No shim: the old path is gone rather than forwarded,
and the reasoning for that is in the script's own header rather than here.

For this repo's maintainers the change is a name that finally matches the file plus a registry comment
that no longer states retired policy as current -- noticed the moment somebody reaches for the Part 3
adopter, and invisible otherwise.
**Score:** 2

#### What makes this deploy extra special

A subscriber running this workflow types this command about once per repo, and they type it off the
skill page -- which travels in the same release as the script, so following the page they notice
nothing at all. The one who must act is the consumer who wrote the old path into a note or a wrapper:
for them this is a breaking rename with a loud failure and no silent fallback, which is the trade the
branch deliberately took. Named on the page and in the release note so it is not met first as an
error.
**Score:** 3

#### Pull Request

The CI-floor adopter is named for the floor, not for the merge queue

Plugins: dkj-policy
