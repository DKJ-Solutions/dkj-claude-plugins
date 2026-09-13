## fix/1904-pin-checkout-in-scaffolded-runners

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

#### The inconsistency, as re-measured on this branch

`adopt-merge-queue.ps1` composes two **write-capable** runners into an adopting consumer's
`.github/workflows/`, and both read `actions/checkout@v5` -- a mutable tag:

- `fold-on-merge.yml`, whose first checkout is handed `secrets.FOLD_PUSH_TOKEN`: a fine-grained PAT
  belonging to somebody who bypasses the trunk ruleset, valid up to 366 days.
- `verify-resolved.yml`, whose job holds `issues: write`.

This repo's **own committed copies of the same two jobs** are SHA-pinned -- `.github/workflows/fold-on-merge.yml:174`
and `.github/workflows/verify-resolved.yml:102`, both `actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5` --
and the comment on the first states the reason in as many words: *a mutable tag on this line could
otherwise retag its way into exfiltrating a 366-day standing write token instead of an hour-lived one.*

So the rule is stated, implemented and enforced by this repo **on itself**, and the generator that hands
the identical job to every adopting consumer shipped them the weaker template. The consumer's copy is the
one that matters more, not less: they are told to create a `FOLD_PUSH_TOKEN` for it, and then receive a
runner that spends it behind a floating tag they never chose.

#### Verified before it was repaired, and one thing the report got wrong

The symptom stands exactly as filed; the **line numbers do not**. #1904 named 409/415 and 549/554, and the
file has moved since -- they were 397/403 and 537/542 when this branch opened. The report also weighs a
third template (`repo-settings.yml`, correctly unpinned) from the in-flight `feat/1843-portable-repo-settings-runner`
branch; that branch has **not** merged, so `main` carries two templates, not three. Neither correction
changes the repair -- recorded because a repair built on an unverified reason carries a citation.

#### Both checkout steps per job, not only the one holding the credential

`actions/checkout` defaults to `persist-credentials: true`, so the fold runner's first step writes the PAT
into the workspace git config and **every later step of that job holds it**; `verify-resolved`'s job
likewise carries `issues: write` for its whole length. An action is pinned because of the **job** it runs
in, not because of the line it sits on. All four lines are therefore pinned.

A read-only runner is deliberately left unpinned -- `contents: read`, no secret, nothing to exfiltrate --
which is why this repo's own `repo-settings.yml:91` is unpinned and why #1843's new template is right to be.

#### And the half a pinned generated template does not get for free

#1904 asks it directly: *a pin nobody refreshes is its own slow problem.* This repo's workflows are
hand-maintained and a scaffolder's are not, so a bump here and not there leaves every consumer's floor
silently behind the floor the source runs on, with both files individually valid and nothing reporting it.
Answered with a mechanism rather than a hope: **one** `$checkoutPin` variable as the refresh point, and a
new suite that fails the moment it stops equalling this repo's own.

### CREATE

- [x] Hoist the pin into a single `$checkoutPin` seam in `scripts/task/adopt-merge-queue.ps1`, beside the
      `$sharedRepo`/`$sharedRef` block, with the reasoning above written at it -- why these two runners are
      pinned, why both steps of each, why a read-only runner is not, and where the refresh gate lives.
- [x] Point all four composed `uses:` lines at that seam (fold-on-merge x2, verify-resolved x2).
- [x] Mirror the file to `plugins/dkj-policy/scripts/task/adopt-merge-queue.ps1` -- byte-identical, as the
      shared-scripts drift lint requires.

### TEST

- [x] New suite `scripts/tests/pin-parity.tests.ps1` -- nine asserts over three properties: the generator
      names a 40-character SHA and no `@vN` tag survives in it; the pin is assigned exactly **once**, so it
      has a single refresh point; it **equals** the SHA in this repo's own `fold-on-merge.yml`; and this
      repo's two write-capable runners agree with each other, so "this repo's own pin" is one answer rather
      than two that happen to match today.
- [x] Deliberately **not** asserted: that every `actions/checkout` under `.github/` is pinned. Several are
      not, correctly. Pinning is a property of the job, so a blanket assert would be wrong in exactly the
      cases the reasoning already covers.
- [x] `adopt-merge-queue.tests.ps1` had hardcoded `actions/checkout@v5` inside its #1543 ordering assert, so
      it went red on the right change. Re-pointed at `@[0-9a-f]{40}`: that suite reads the **ordering** it
      was written for, and `pin-parity` owns which SHA. 76/76.
- [x] Pin verified against the registry rather than copied: `refs/tags/v5` on `actions/checkout` resolves to
      `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09` today, so the pin is v5 and not a downgrade.
- [x] Full gate: `check-plugin-integrity.ps1` + every suite, via `open-pr.ps1`.

### DEPLOY: fix/1904-pin-checkout-in-scaffolded-runners

The two write-capable runners this workflow scaffolds into a consumer -- `fold-on-merge.yml`, which spends a
366-day `FOLD_PUSH_TOKEN`, and `verify-resolved.yml`, which holds `issues: write` -- were composed with a
mutable `actions/checkout@v5`, while this repo's own committed copies of the same two jobs have always been
SHA-pinned against exactly that risk. The repo that wrote the warning was protected; the repos that took its
advice were not. All four composed checkout lines are now pinned to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`
(`v5`) through a single `$checkoutPin` seam, and `pin-parity.tests.ps1` asserts that seam still equals the SHA
in this repo's own fold runner -- so a bump here that forgets the generator fails a gate instead of quietly
leaving every consumer's floor behind. Both steps of each job are pinned, not only the one carrying the
credential, because `persist-credentials` puts the token in the workspace for the whole job; a read-only
runner stays unpinned for the same reason this repo's own does.

**Score:** 3

#### What makes this deploy extra special

It closes a gap that pointed the wrong way round: the hardening was written down, implemented and enforced
here, and the generator handed every adopting consumer the weaker template of the same job. And it answers
the follow-up #1904 raised rather than leaving it -- a pin in a *generated* file has no maintainer, so the
refresh point was made singular and put under a parity gate in the same change.

**Score:** 2

#### Pull Request

Pin actions/checkout by SHA in the fold and resolves runners the scaffolder writes
