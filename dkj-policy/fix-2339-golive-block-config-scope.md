## fix/2339-golive-block-config-scope

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

Inbound #2339, checked against the tree before repairing: the reported cause holds. The config was
dot-sourced inside a `& { }` scriptblock, so `Get-StorefrontMarkets` died with that scope, and
`market-urls.ps1` then refused. One more thing the report did not mention: with `-Version` given, that
scriptblock never ran at all, so the config was not loaded in any form.

### CREATE

- [x] `build-golive-block.ps1` dot-sources `scripts/repo-config.ps1` once, at script scope. Every
      parameter is captured before the load, and `$repoRoot` is restored after it.
- [x] The version half reads `Get-ChangelogPath` from that load; the scriptblock is gone.
- [x] `dkj-policy-bwj.tests.ps1`: the driver run with `-File` and `-Path` against a fixture
      repo-config that declares markets.

### TEST

- [x] Unrepaired copy on `main`, same fixture: `this store has not declared its markets`, exit 1.
- [x] `dkj-policy-bwj.tests.ps1` in the lane: 365 pass, 0 fail.

### DEPLOY: fix/2339-golive-block-config-scope

`build-golive-block.ps1` read `scripts/repo-config.ps1` inside a scriptblock, so the functions it
defined were gone before the live-URL half ran. The config is now read once at script scope, and a suite
case runs the driver via `-File` (#2339).

**Score:** 2 -- one script in one plugin, with a suite case that holds the invocation shape.

#### What makes this deploy extra special

In a store running dkj-policy-bwj, the `golive-block` skill's own `-File` invocation with `-Path` failed
with *"this store has not declared its markets"*, even though the store had declared them, so the error
pointed at the wrong fix. It now prints one live URL per market, without the caller having to dot-source
the config first.

**Score:** 3 -- the documented invocation works for the first time with `-Path`; noticed the moment
somebody builds a go-live block for a storefront page.

#### Pull Request

build-golive-block: read repo-config at script scope, so -Path finds the store's markets

