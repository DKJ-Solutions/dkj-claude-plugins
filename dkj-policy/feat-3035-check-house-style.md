## feat/3035-check-house-style

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

Issue [#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035), with the owner's three
design decisions from its comments: a discovery glob for the copies, a pattern grep rather than a CSS
parse for checks 2 and 3, and CSS embedded in non-CSS files in scope.

### CREATE

- [x] `scripts/lib/house-style-rules.ps1` in the dkj-solutions plugin: the three checks, the pin read from the skill page, the retired names (v1/v2 tokens plus v3's `Was` column, minus what v3 defines), the allowlist seam.
- [x] `scripts/lint/check-house-style.ps1`: the gate (exit 0 / 1 / 2).
- [x] `hooks/house-style-sessioncheck.ps1`, registered in the plugin's `hooks.json`: read-only, quiet in a repo without a house style.
- [x] `.github/workflows/reusable-house-style.yml`: the CI gate a consumer calls.
- [x] This repo's `Get-HouseStyleAllowlist`: the dkj-policy pages are outside the house style by design (BWJ-Development runs them too).
- [x] The skill page, the plugin README and both plugin descriptions.

### TEST

- [x] `scripts/tests/check-house-style.tests.ps1`: 47 asserts on the rules, the retired list held to the vendored v3 copy, and the gate and session check against scratch repos and this repo itself.
- [x] Run on this repo: the first version took 281s (a selector regex rescanning every run), the lookbehind version 21s; 101 findings, all in dkj-policy pages, answered by the allowlist.

### DEPLOY: feat/3035-check-house-style

A new `check-house-style` gate in the `dkj-solutions` plugin
([#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035)) checks three things. Every
vendored `house-style.css` and `house-theme.js` must be the copy the `house-style` skill pins. The repo's
own layer must not redefine a house token or restyle a house class app-wide. And it must not use a token
name the brand book retired. The gate runs in CI through a reusable workflow and, read-only, at session
start. This repo's connector dashboard passes it.

**Score:** 3

#### What makes this deploy extra special

In a DKJ-Solutions repo with this plugin, a new session-start line now reports a drifted copy of the
house style, a redefined house token or class, or a retired token name such as `--muted` or `--good`, with
file and line. To block a pull request on the same findings, a repo adds the few-line caller from the
`house-style` skill page, which calls `reusable-house-style.yml`. A false positive is answered with a
reason in `Get-HouseStyleAllowlist` in `scripts/repo-config.ps1`.

**Score:** 3

#### Pull Request

house-style: a check-house-style gate
