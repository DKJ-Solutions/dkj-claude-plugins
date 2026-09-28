## fix/2569-publish-page-wrangler-oauth

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

Inbound #2569, verified on pickup. `publish-page.ps1` had one route, a Bearer token from
`CLOUDFLARE_API_TOKEN`, so a machine logged in through `wrangler login` could not publish. Measured on
this machine, wrangler 4.142.0: `whoami` exits 0 and prints the account table. It also exits 0 when
nobody is logged in, so the account id the seam names decides, not the exit code.

### CREATE

- [x] `page-publish-rules.ps1`: `Test-BwjWranglerSession` (exit 0 and the seam's account id in the
      output) and `Get-BwjPageWranglerArgs` (`kv key put/get ... --namespace-id <id> --remote`, the get
      without `--text` so the bytes are hashed undecoded).
- [x] `publish-page.ps1`: with no token, probe whoami. On a session for this account, put and read
      back through wrangler, with stdout copied to a file as bytes and `CLOUDFLARE_ACCOUNT_ID` set for
      the child. Otherwise refuse and name both routes.
- [x] `publish-page` SKILL.md: the second route, and the requirements line.

### TEST

- [x] `bwj-page-publish.tests.ps1`: unit asserts for both functions, plus three end-to-end runs
      against an `npx.cmd` shim (published and verified, another account refused before any upload,
      a tampered read-back failing). 110 pass, 0 fail standalone.

### DEPLOY: fix/2569-publish-page-wrangler-oauth

Inside this repo: `publish-page.ps1` gained a second publish route for when `CLOUDFLARE_API_TOKEN`
is absent, with two small functions in `page-publish-rules.ps1` and end-to-end tests against an
`npx.cmd` shim.

**Score:** 2

#### What makes this deploy extra special

For whoever publishes a BWJ page from a machine that is logged in with `npx wrangler login`: the
publish now works without an API token. It goes through `wrangler kv key put/get --remote` and is
proved with the same SHA-256 read-back. A login to a different account is refused, and the message
names both routes.

**Score:** 3

#### Pull Request

publish-page publishes through a wrangler OAuth session when CLOUDFLARE_API_TOKEN is absent

