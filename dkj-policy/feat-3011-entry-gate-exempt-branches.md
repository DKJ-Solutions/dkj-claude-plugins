## feat/3011-entry-gate-exempt-branches

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

Issue #3011, part of #2998. The back-flow PR of a Git-connected live theme comes from the deploy branch
itself (`live`). `Get-EntryGateExemptPrefixes` replaces its `sync` default, and a slash-less branch's
prefix is the part before its first `-`, so answering `live` there would exempt every `live-*` branch.
Add an additive exact-name seam instead, read through the one function both readers already share.

### CREATE

- [x] `Get-BranchEntryExemptPrefix` (entry-scaffold-lib) also reads `Get-EntryGateExemptBranches` (default
      none) and hands back the branch's own name for an exact match
- [x] check-branch-entry and open-pr say "an exempt branch name" for that match, instead of a prefix
- [x] contract record in script-contract-lib, expected-contract row, record count 48 -> 49, blueprint
      regenerated, plugin mirrors rebuilt
- [x] the seam documented on the check-branch-entry, adopt-dkj-policy and open-pr skill pages

### TEST

- [x] entry-scaffold: the default is none, an exact name matches, `live-*` and `live/x` do not, `sync`
      still stands beside it
- [x] branch-entry-gate: the gate passes `live`, refuses `live-banner`, still passes `sync/...`
- [x] script-contract and config-blueprint: the counted `[INFO]` and undeclared-record asserts each rise
      by one, since this repo deploys no theme and leaves the new seam at its default

### DEPLOY: feat/3011-entry-gate-exempt-branches

The branch-entry gate and `open-pr` gain a second, additive exemption: `Get-EntryGateExemptBranches` in `scripts/repo-config.ps1` lists exact branch names that owe no changelog entry, beside `Get-EntryGateExemptPrefixes` rather than in place of it. It is built for the back-flow PR of a Git-connected live theme, which comes from the deploy branch itself (`live`). Listed as a prefix, that name would have exempted every `live-*` branch too, and would have dropped the `sync` default. A name matches the whole branch and nothing else, case-insensitively, and open-pr names such a PR from its own commit subject exactly as it names a `sync/` branch's. Unanswered, nothing changes ([#3011](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3011), part of [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998)).

**Score:** 2

#### What makes this deploy extra special

A repo whose live theme deploys from a branch can let that branch's back-flow PR through the entry gate without exempting anything else. A repo that does not answer the seam sees no difference.

**Score:** 2

#### Pull Request

The entry gate exempts exact branch names, beside its prefixes

