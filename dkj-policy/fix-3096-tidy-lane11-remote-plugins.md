## fix/3096-tidy-lane11-remote-plugins

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

Verified the reason in #3096: lane 11 calls `Get-RepoPluginRoots -RepoRoot $cloneDir` without
`-IncludeRemote`, and `Get-PluginRoots` skips every non-string source unless that switch is passed.

### CREATE

- [x] Pass `-IncludeRemote` in lane 11, in `scripts/` and its `plugins/dkj-policy/scripts/` mirror
- [x] Name lane 11 beside plugin-versions in `Get-PluginRoots`'s comment on the switch, in both copies
- [x] A behavioural case in `tidy-lib.tests.ps1`: a clone mixing a local and a url-sourced entry

### TEST

- [x] `tidy-lib.tests.ps1`: 94 passed, 0 failed; with the fix reverted, the url-sourced case fails

### DEPLOY: fix/3096-tidy-lane11-remote-plugins

`tidy-machine`'s lane 11 no longer reports a url-sourced plugin, such as `figma` from the official
marketplace, as retired, and no longer hands over an uninstall of it: it reads the marketplace clone with
`-IncludeRemote`, so a plugin the manifest still names counts as listed whether or not the clone holds a
copy ([#3096](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3096)).

**Score:** 3

#### What makes this deploy extra special

Anyone running `tidy-machine` with a url-sourced plugin installed was told to uninstall a live plugin;
pasting that command removed it.

**Score:** 3

#### Pull Request

tidy-machine lane 11: a url-sourced plugin is no longer reported as retired

