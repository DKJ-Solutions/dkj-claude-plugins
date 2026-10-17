## feat/3084-brandbook-v0-1-0

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

Inbound #3084: the brand book released its four `house-style-v*` tags as one `v0.1.0`, and the skill
must stop pointing at `house-style-v4` before that tag can be deleted. Verified first: both files served
at `v0.1.0` hash to the pinned sha256 values, and the README and `patterns/repo-dashboard.html` exist at
the tag, so the vendored copies and the retired-name list stand unchanged.

### CREATE

- [x] Repoint every brand-book link in the `house-style` skill to `v0.1.0`, and its commit to `ed2cadd5`
- [x] Name the brand book's releases `vX.Y.Z`, cut with `cut-release`, in "Changing the house style"
- [x] The retired-names docstring and the test's tag asserts follow the new pin

### TEST

- [x] `check-house-style.tests.ps1`: 58 passed, 0 failed

### DEPLOY: feat/3084-brandbook-v0-1-0

The `house-style` skill now fetches from the brand book's `v0.1.0` release, which brought the four
`house-style-v1`..`-v4` tags together ([#3084](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3084)).
The two files there are byte-identical to `house-style-v4`, so the checksums and both vendored copies stand.

**Score:** 1

#### What makes this deploy extra special

Nothing a DKJ-Solutions app takes changes: the bytes are the same. It prevents a failure that has not
happened yet: the brand book deleting its `house-style-v*` tags would otherwise leave every installed
copy of the skill fetching from a tag that no longer exists.

**Score:** 1

#### Pull Request

house-style skill: pin to dkj-brandbook v0.1.0

