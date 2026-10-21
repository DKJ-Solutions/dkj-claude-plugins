## fix/3275-hub-stale-plugin-version

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

Inbound #3275, its reason verified against the tree: `Select-DevPreviewPort` recognises a hub by the
checkout its command line names, never by the plugin payload it runs, so `Start-DevPreviewHub` reused a
v5.26.0 server after the update. That server's `/` sends a 303 to the state file's `hub`, which since
#3245 is the server itself.

### CREATE

- [x] `Get-DevPreviewStaleHubOwners` in `hub/lib/dev-preview-rules.ps1`: the listeners whose own command line runs
  a `serve-general-pages.ps1` from an absolute path other than the hook's.
- [x] `Start-DevPreviewHub` stops such a server and starts this version's on the same port; one that will not stop
  is reused as before. The line reads `(restarted: it ran another plugin version)`.

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: unit cases (another version, the own payload in another case and
  slash, a relative path, no hub) and an end-to-end case with a fake older hub on the port: 285 passed, 0 failed.

### DEPLOY: fix/3275-hub-stale-plugin-version

The dev-preview hook no longer reuses a hub that this checkout started under another plugin version (#3275).
After an update it stops that server and starts the new version's on the same port, and the session's line
reads `(restarted: it ran another plugin version)`. Before this, a server from v5.26.0 kept running after the
move to v5.27.0, and its `/` redirected to itself (`ERR_TOO_MANY_REDIRECTS`). A server started by hand from a
relative path is still reused.

**Score:** 3

#### What makes this deploy extra special

After an update the Repo hub link opens the hub again, without anyone stopping the old server by hand.

**Score:** 2

#### Pull Request

dev-preview hook restarts a hub server that runs from another plugin version
