## fix/1902-xoxowildhearts-live-repo

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

`connectors/xoxowildhearts.json` named `BWJ-ecommerce/xoxowildhearts`. The live consumer is
`BWJ-Development/xoxowildhearts` -- a fresh repo rather than a transfer, so there is no redirect
behind the old name.

#### Bounded to ONE field, on the precedent #1902 itself names

#1902 asks for "the same repair `connectors/smartwatchbanden.json` already carries for the same
situation". That repair -- its `CORRECTED 2026-09-07 (#1553)` note -- closes with *"Nothing else
here was re-checked ... this branch corrected one field"*. This branch holds to that: the `repo`
field and its dated note, nothing else. What the measurement turned up beyond it is filed rather
than folded in.

#### What the measurement found beyond the field, and where it went

- **#1905** -- the live repo was seeded at 2026-09-07T12:27Z while the abandoned one kept merging
  until 2026-09-11T07:55Z, so three merged PRs are stranded there: its #208 (`DECISIONS.md`), its
  #209 (**the #1769 marketplace rename**) and its #211 (**the `branch-entry` gate**, which the live
  `.github/workflows/` does not carry). Consumer-side work; filed here because an issue on another
  repository is outside this repo's normal PR flow.
- **#1906** -- this manifest's `MIGRATED 2026-09-11 (#1769)` paragraph measured the abandoned repo,
  so the registered `@dkj-claude-plugins` ids describe a repository the file no longer names. Which
  way to repair it depends on whether the consumer completes #1905, so it is not decided here.

### CREATE

- [x] `"repo"` -> `BWJ-Development/xoxowildhearts`
- [x] Append the dated note: what was measured on both repos, why the hazard differs from
      smartwatchbanden's (the old repo here is **not** archived, so both slugs resolve and the stale
      register reads healthy), that #1553's "read as a LABEL and nowhere else" answer has **expired**
      (`-RemoteRunners` resolves it since #1850, check 1b compares it since #1821), why the seven
      other mentions in the tree stay as written (#952 -- they print the name, they do not resolve
      it), the `localCheckout` verdict, and the two filings
- [~] `localCheckout` -- **left unchanged, deliberately.** Measured on this machine: `../../` holds
      only `dkj-solutions/` and `bwj-development/`, and `bwj-development/` holds only
      smartwatchbanden, so none of the three candidates resolves and neither would
      `../../bwj-development/xoxowildhearts`. That is a **true** absence, not a stale register, and
      #1807's own rule is that only measured paths are appended -- a guessed candidate does not fail
      loudly, it goes on printing `[SKIP] checkout ... not present on this machine` while the
      register looks repaired.

### TEST

- [x] The file is still valid JSON, read back through `ConvertFrom-Json`: `repo`, the three
      `localCheckout` candidates and all five plugin blocks survive the edit unchanged
- [x] `git diff --numstat` shows **2 insertions, 2 deletions** in one file -- the `repo` line and
      the notes line, and nothing else
- [x] `scripts/lint/check-plugin-integrity.ps1` green
- [x] every `scripts/tests/*.tests.ps1` green (run by `open-pr.ps1`, as CI does)

### DEPLOY: fix/1902-xoxowildhearts-live-repo

`connectors/xoxowildhearts.json` now names `BWJ-Development/xoxowildhearts`, the repository this
consumer actually works in. The old slug is **not archived** and still resolves, so nothing was
failing and nothing would have started failing -- which is the hazard: a register pointing at an
abandoned repo reads healthy indefinitely. Two checks have learned to *resolve* this field since the
last such correction was made (`-RemoteRunners` reads that repository's CI over the API, #1850; check
1b compares it against a checkout's own `origin`, #1821), so it is no longer the display-only
bookkeeping #1553 measured it as.

**Score:** 2 -- one data field in the consumer register, plus its note. Nobody outside this repo's
own maintenance runs into it, and it is latent even here: no machine currently resolves a
`localCheckout` for this consumer, so the connector block is a `[SKIP]` either way. It is noticed the
moment somebody registers a checkout path, or runs `-RemoteRunners`.

#### What makes this deploy extra special

N/A -- the consumer register is this repo's own bookkeeping about who consumes the plugins. Nothing
here ships, and nobody running an upgrade takes anything from it.

**Score:** N/A

#### Pull Request

connectors/xoxowildhearts.json points at the live repo
