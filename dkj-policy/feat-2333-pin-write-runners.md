## feat/2333-pin-write-runners

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

Issue #2333: the consumer runners `adopt-ci-floor.ps1` scaffolds fetch this repo's scripts at `ref: main`
and execute them beside a write credential. Dave's decision (September 23, 2026): pin only the write
runners (fold, resolves, merge-on-green) to a release, with a check that reports a pin falling behind;
the read-only gates stay on `main` under the #1805 argument.

- The pin is the commit SHA of the tag `v<plugin.json version>`, resolved with `git ls-remote`, written
  as `ref: <sha> # v<version>`. A tag can be moved; a SHA cannot. Offline falls back to the tag, and an
  unreadable version to `main` -- both loudly.
- The freshness check is the re-run of `adopt-ci-floor.ps1` itself: every existing write runner is read
  for its shared ref, and one on a moving ref or behind this release is reported. That reaches every
  consumer, registered or not. A register-side report in `check-connectors.ps1` is filed as #2337.

### CREATE

- [x] `scripts/task/adopt-ci-floor.ps1` (+ mirror): resolve the pin, write it into the three write
  runners with a comment arguing it, `-SharedRefOverride` for the suite, the `[pin]` report on a
  created runner and the verdict on an existing one; the repo-settings template's stale "#1904, out of
  scope" claim corrected
- [x] `adopt-dkj-policy/SKILL.md`: a Part 3 subsection for the pin, and Part 1's `ref: main` argument
  bounded to the read-only gate
- [x] `CLAUDE.md`: the two-channel paragraph no longer says the fold and resolves scripts reach a
  consumer at `main` (byte-neutral or smaller, on the always-on budget)

### TEST

- [x] `adopt-ci-floor.tests.ps1` section 11: the three write runners carry the pin and the argument,
  repo-settings stays on `main`, and a re-run reports a runner on `main` and one behind while staying
  silent on a current one and leaving the file untouched. The native-call count asserts the new read
  is a `git ls-remote`. 219 passed, 0 failed.
- [x] Live probe against a scratch consumer, over the network: `v5.6.0` resolved to its peeled commit
  `92f1b73d`, written into fold, resolves and merge-on-green; repo-settings kept `main`.

### DEPLOY: feat/2333-pin-write-runners

The three consumer runners that hold a write credential no longer run this repo's scripts at `main`.
`adopt-ci-floor` now checks the shared scripts out for the fold, the resolves verification and
merge-on-green at the commit the adopting plugin's release was tagged at, written as
`ref: <sha> # v<version>`. Until now a change landing on this repo's trunk reached `FOLD_PUSH_TOKEN`'s
contents and pull-request write in every adopted consumer on its next run, with no release in between.
The read-only gates keep `ref: main`, where the stale-convention argument still holds. The pin has to
move, so re-running `adopt-ci-floor` now reads every existing write runner and reports one still on
`main` or pinned behind the version it came from, with the value to put there. It never rewrites the
file.

**Score:** 3

#### What makes this deploy extra special

A consumer that adopted the CI floor before this release keeps `ref: main` in its write runners until
somebody edits them, because the scaffolder never rewrites a file. Re-running `adopt-ci-floor` is what
tells them, one `ref:` line per runner. A floor adopted from now on is pinned from the start.

**Score:** 2

#### Pull Request

The write runners adopt-ci-floor places now pin the shared scripts to a release

Plugins: dkj-policy

