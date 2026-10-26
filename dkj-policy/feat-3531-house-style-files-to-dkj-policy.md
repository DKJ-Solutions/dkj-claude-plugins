## feat/3531-house-style-files-to-dkj-policy

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

#3531: the house style has two consumers. `dkj-policy`'s own hub and General pages render in it in every
repo, BWJ-Development's included, and `dkj-solutions` binds every DKJ-Solutions app to start from it. The
files sat under the second and were reached by the first through a path into the sibling plugin's folder
(`Get-HouseStyleDir`). The owner's decision (Maikel, October 26, 2026): split them. The files move to
`plugins/dkj-policy/assets/house-style/`, and the rule (the skill and its pin table, `check-house-style`,
the session check, the palette builder) stays in `dkj-solutions`.

The bytes do not change, so every sha256 in the pin table stands. The pin URL's path changes, and the
release cut repins only the tag, so the new path is written into the table now and becomes fetchable with
the next release. `Get-HouseStylePin` reads both path spellings, because the reusable gate reads the skill
page at the pinned tag, and every tag up to v5.32.0 carries the old path.

### CREATE

- [x] `git mv` of `assets/house-style/` from `dkj-solutions` to `dkj-policy`, unchanged
- [x] Every code path repointed: `Get-HouseStyleDir`, the connector dashboard, both `house-path.mjs`, the
  brandbook app's imports and vite config, both workflows' path filters, the palette builder's default
- [x] `Get-HouseStylePin` accepts the pre-#3531 path beside the new one
- [x] The skill, the `dkj-solutions` README, `CLAUDE.md` and manifest description, the house-style README
  and the hub README say where the files live and why; links out of `dkj-solutions` are absolute, since
  a relative one leaves that plugin's root in a consumer's cache
- [x] The two links in the archived 5.29.0 notes point at the old path at tag `v5.29.0`, where it exists

### TEST

- [x] `check-house-style` (82, with a new assert for a pre-#3531 pin), `house-palette`, `dev-pages` and
  `connector-dashboard` green; `check-plugin-integrity` 0 errors
- [x] `dev-preview-sessionstart` fails 8 here and 13 on an untouched `origin/main` on this machine (process
  starts exiting, an `OutOfMemoryException`), so the failures belong to this machine and not to this branch; CI is the judge

### DEPLOY: feat/3531-house-style-files-to-dkj-policy

The house style's files now live in `dkj-policy`, at `plugins/dkj-policy/assets/house-style/`, because
that plugin's hub renders in them in every repo, BWJ-Development's included; `dkj-solutions` keeps the
rule that a DKJ-Solutions app starts from them, with the skill, its pin and the `check-house-style` gate
([#3531](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3531)). The files are byte for byte
the same, so every checksum stands.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo that vendors the house style fetches it from a new path from this release on: the
skill's pin table names it, and the old path still serves every earlier tag. A copy already vendored
stays valid, since its checksum is unchanged.

**Score:** 1

#### Pull Request

Move the house style's files to dkj-policy; dkj-solutions keeps only the rule
