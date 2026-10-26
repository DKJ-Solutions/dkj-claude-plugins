## feat/3506-retire-page-token

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

Issue #3506: a leaked `publish-page` link could not be closed. A fresh token changes the next URL, but
every KV key under the old token keeps serving. Scripted rather than only documented, so the deletion
is limited to the keys this lib writes for that token and verified the way a publish is.

### CREATE

- [x] `page-publish-rules.ps1`: `Select-BwjTokenKeys`, the wrangler `list`/`delete` args, `ConvertFrom-BwjWranglerKeyList`, the API listing URL
- [x] `publish-page.ps1 -RetireToken [-Token] [-DryRun]`: list, delete (index first), list again, then remove the token file; the auth choice moved into `Connect-BwjKv` so both runs share it
- [x] The `publish-page` skill page: a `-RetireToken` section under the token rules, and the two parameters

### TEST

- [x] `bwj-page-publish.tests.ps1`: key selection, listing parse (an unreadable listing throws), args and URL, and through the wrangler shim the dry run, a lagging listing, the retirement, `-Token` for a replaced token, and the refusals (186 pass)

### DEPLOY: feat/3506-retire-page-token

`publish-page -RetireToken` closes a leaked link
([#3506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3506)). It deletes every KV key
under the kind's token, the page and every release page under it, lists again to prove none is left,
and only then removes the token file so `-InitToken` can mint the next one. `-DryRun` lists the keys
without deleting, and `-Token <32 hex>` retires a token that was already replaced on file. Until now a
fresh token changed the URL while the old link went on serving.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

publish-page: -RetireToken deletes a leaked path token's KV keys
