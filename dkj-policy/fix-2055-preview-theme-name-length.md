## fix/2055-preview-theme-name-length

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

Inbound #2055: the shared preview-theme name builder does not bound its result, so a long branch name makes the creating push fail on Shopify's 50-char ceiling. Bound it in the shared builder (prefix kept, branch part truncated, deterministic hash appended), so all three call sites keep agreeing on one string.

### CREATE

- [x] `Get-RepoPreviewThemeName` bounds its result: a name that fits is returned unchanged, an
      over-long one keeps the prefix, truncates the branch part, and takes a 6-hex SHA256 tail of the
      FULL name as a discriminator.
- [x] The ceiling and the discriminator length sit beside `$script:RepoThemePrefix` as named
      constants, with `-MaxLength` exposed so a consumer can pin the number if Shopify moves it.
- [x] A ceiling too small to hold the prefix plus the discriminator plus one character of label is
      refused rather than quietly exceeded.
- [x] Mirrored to the plugin payload with `scripts/sync/build-shared-scripts.ps1`.

### TEST

- [x] `scripts/tests/theme-lifecycle-rules.tests.ps1` -- 102 pass, 0 fail, including nine new
      asserts: the measured 51-character case, the untouched short name, idempotency on the
      function's own output, two long branches sharing a head composing to DIFFERENT names,
      determinism, `-MaxLength`, and the refused floor.
- [x] The full gate (`check-plugin-integrity.ps1` plus every suite) via `open-pr.ps1`.

#### What could NOT be asserted here

The platform's own refusal. This repo publishes plugins and reaches no Shopify store, so the 50 is
the consumer's measurement cited as theirs -- which is exactly why the suite asserts the literal `50`
rather than reading the constant back out of the lib it is testing.

### DEPLOY: fix/2055-preview-theme-name-length

`Get-RepoPreviewThemeName` now bounds a branch's preview theme name to Shopify's 50-character
ceiling (inbound #2055). A branch name long enough to compose past it used to reach the platform and
come back as `Name is too long (maximum is 50 characters)` -- after the run had already announced
which theme it was creating, so the push read as half-done. A name that FITS is returned unchanged,
so every preview theme that exists today keeps its name and stays findable; only an over-long one is
rewritten, as `<prefix><truncated branch part>-<6 hex of SHA256(the full name)>`.

The bound belongs in the shared builder rather than at the caller because three call sites compose
this name and all three have to agree on one string: `push-preview.ps1` creates the theme, and
`sweep-preview-themes.ps1` composes it again -- once for the current branch and once for every branch
still alive -- in order to SPARE it. A ceiling applied outside the builder would leave the sweep
composing a name it no longer recognises as spared, which is silent and destructive.

The discriminator is not decoration: plain truncation maps every branch sharing a long enough head
onto one theme name, so two branches would push over each other onto a preview that looks correct
from both.

A consumer whose branch names run long cannot create a preview theme at all today; everyone else sees
no change, because a name that fits is untouched. Noticed the moment that consumer pushes.

**Score:** 3

#### What makes this deploy extra special

It closes the class rather than the instance. `Get-RepoPreviewThemeName` already refused a name
illegal at the CLI -- a `/` in it -- and its own docstring named that as its job; the length ceiling
is the same kind of rule from the same vendor, and it was the one case the function did not cover.

**Score:** 2

#### Pull Request

Get-RepoPreviewThemeName bounds the theme name to Shopify's 50-character limit
