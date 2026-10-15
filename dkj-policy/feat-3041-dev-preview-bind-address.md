## feat/3041-dev-preview-bind-address

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

Issue [#3041](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3041), confirmed in
`dev-preview-sessionstart.ps1`: the listener read selects `LocalPort` and `OwningProcess` only. Its
proposal is followed: say it, and leave the restart to the owner.

### CREATE

- [x] `dev-preview-rules.ps1`: `Test-DevPreviewCommandIsLoopback` and `Test-DevPreviewListensOnAll`, both pure.
- [x] The hook reads `LocalAddress` too, and a reuse line gains `LISTENING ON ALL INTERFACES` when the Command names loopback and the reused listener is on `0.0.0.0` or `::`.
- [x] The plugin README's bind bullet says so.

### TEST

- [x] Nine new asserts in group 1c of `dev-preview-sessionstart.tests.ps1`; 72 passed. No end-to-end case: binding a test listener to every interface can raise the Windows firewall prompt.

### DEPLOY: feat/3041-dev-preview-bind-address

The `dev-preview` session-start hook now reads which address a reused server listens on
([#3041](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3041)). When the repo's `Command`
binds to a loopback host and the server it reuses listens on every interface, as one started by hand
without `-H` does, the line says `LISTENING ON ALL INTERFACES`.

**Score:** 2

#### What makes this deploy extra special

In a DKJ-Solutions repo whose `Get-DevPreview` binds the server to `127.0.0.1`, a session start now
warns when the server it hands you is one you started by hand that is reachable from the network,
instead of handing out its link as if it were private.

**Score:** 2

#### Pull Request

dev-preview: say when a reused server listens on all interfaces
