## fix/2907-closed-message-trust-by-permission

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

#2907 (inbound from smartwatchbanden, October 9, 2026): `asana-closed-message` never carried a go-live
block in CI, because `author_association` is computed for the viewer and the workflow token cannot see a
private org membership, so the shipping member's comment was dropped as untrusted and logged as "none was
on the issue". Maikel chose the trust model: the author of an untrusted marker comment is asked about by
repo permission (admin or write is trusted), and every drop is logged with its association.

### CREATE

- [x] `asana-closed-message.ps1`: the comment read keeps every comment with its login; `Select-TrustedCommentBodies` decides trust by association, then by repo permission for a marker comment (`Get-PermissionCheckLogins`, `Read-CollaboratorPermission`, `Test-TrustedRepoPermission`)
- [x] Each marker comment carried on permission or dropped is logged with its association and permission, never its body, and a drop is no longer reported as "none was on the issue" (`Get-ClosedMessageBlockPhrase -Dropped`)
- [x] `asana-closed-message.yml`: the permission comment names the extra read and the scope it relies on

### TEST

- [x] bwj-development suite green (390 asserts), with new cases for the permission path, the drop log line, the login guard and the permission read against a stubbed `gh`
- [x] Victor (no correctness findings; the shared `Invoke-GhCapture` helper and the stub test came from his review) and Sebastian (no blocking findings; the workflow comment no longer asserts an unmeasured scope)
- [x] check-plugin-integrity: 0 errors

### DEPLOY: fix/2907-closed-message-trust-by-permission

`asana-closed-message` now carries the go-live block when its author is an org member whose membership is
private. The workflow token reads such a member as `CONTRIBUTOR`, so until now the block was dropped and
the Asana task got the bare closed line, logged as "none was on the issue". The author of a block comment
with an untrusted association is now asked about by repo permission, and the block is carried when that
answers admin or write. Every block comment that is carried this way or dropped is logged with its
association and permission, and a dropped block is logged as dropped.

**Score:** 3

#### What makes this deploy extra special

A store repo picks this up only by copying the new `asana-closed-message.ps1` template into
`.github/scripts/`, since the copy there does not update itself. Whether the workflow token may read the
permission endpoint is not yet measured on a runner. The first close after the copy says which: the log
shows either `carried on repo permission` or `permission could not be read`.

**Score:** 3

#### Pull Request

asana-closed-message: trust a go-live block by its author's repo permission, so private org members' blocks are carried

