## feat/3675-consumers-folder

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

Full rename, as decided on the issue (maikel-bwj, October 30, 2026): folder, script, hook and tests.
History keeps its words (#952): the release documents, the pending `CHANGELOG.md` entries, the dated
manifest `notes`, quoted words and branch-name citations. "Connector" in the Shopify and MCP sense is
a different thing and stays.

### CREATE

- [x] `connectors/` -> `consumers/`, and every reference to the register in scripts, hooks, tests, skills, lenses and docs
- [x] `check-connectors.ps1` -> `check-consumers.ps1`, `connector-sessioncheck.ps1` -> `consumer-sessioncheck.ps1`, the dashboard server and lib, and the three suites
- [x] `Resolve-ConnectorCheckout` -> `Resolve-RegisteredCheckout`, because `check-consumer-siblings.ps1` already defines a `Resolve-ConsumerCheckout`
- [x] `scripts/sync/check-connectors.ps1` kept as a forwarder for hooks installed before this release

### TEST

- [x] `main` merged in after #3666, which git carried onto the renamed `consumer-sessioncheck.ps1`; no new `connectors/` reference outside history, the forwarder, the redirect test and the dated session-start snapshot
- [x] The four gates: roster sync, plugin integrity, script contract, unfolded entry -- 0 errors
- [x] `check-consumers.ps1`, the `check-connectors.ps1` forwarder and the `consumer-sessioncheck` hook run clean on this checkout

### DEPLOY: feat/3675-consumers-folder

The register of repos that install this marketplace's plugins is now `consumers/`, the name the rest
of the tree already used for those repos, and no longer one that collides with MCP connectors
([#3675](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3675)). Its check is
`scripts/sync/check-consumers.ps1`, the dashboard server is `serve-consumer-dashboard.ps1`, and the
suites are `consumers.tests.ps1`, `consumer-sessioncheck.tests.ps1` and `consumer-dashboard.tests.ps1`.
`check-connectors.ps1` stays as a forwarder, because a hook installed before this release finds the
source checkout by that file and runs it. It can go once every install has this release.

**Score:** 1 -- the forwarder prevents a failure that has not happened: without it, every session
start beside a source checkout on `main` would read that checkout as absent until its plugins were
updated.

#### What makes this deploy extra special

**The SessionStart hook is renamed: `connector-sessioncheck` is now `consumer-sessioncheck`.** That is
a public interface change. Every session start in a repo with `dkj-policy` installed prints its lines
under the new name, and the dispatcher's timing line reads `consumer` where it read `connector`.
Nothing has to be done to take it, but anything that matches the old name (a filter, a note, a
script that reads the session-start output) has to follow.

**Score:** 2

#### Pull Request

Rename connectors/ to consumers/

