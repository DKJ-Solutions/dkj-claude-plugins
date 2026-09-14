## feat/1977-portable-bwj-worker

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

#### The assignment

[#1977](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1977): BWJ's two store repos --
`smartwatchbanden` and `xoxowildhearts` -- must publish through **one** Cloudflare Worker, carrying the
release notes and the minor backlog for colleagues who do not read a private repository.

#### What was verified before anything was written

- A worker mechanism already exists, in `dkj-policy` rather than `dkj-policy-bwj`:
  `build-release-notes-page.ps1 -Worker` writes the page into `worker.js` **as a literal** and deploys
  one worker per repo (`Get-ReleasePageWorkerName`), serving `/notes/<32 hex>`.
- **That is exactly why it cannot be shared.** `wrangler deploy` replaces the whole script, so two repos
  pointed at one worker name means whichever deploys last erases the other's page -- silently, with both
  runs reporting success. The issue's premise stands.
- There is **no** minor-backlog page mechanism anywhere in the tree; `minor` exists only as the reach
  label on issues (`Get-ReachLabel`, default `minor`).
- The preview handover (chapter three) publishes through a Claude **Artifact**, not a worker -- a
  different channel, and nothing here touches it.

#### The two course-defining answers (Dave, September 14, 2026)

1. **One worker, pages in KV.** The worker ships in `dkj-policy-bwj` and holds no page content; each
   store publishes its own HTML under `<kind>:<token>`. A redeploy from either store re-uploads
   byte-identical code and cannot touch the other's page.
2. **The minor-backlog page BUILDER is a follow-up issue.** This branch delivers the worker and the
   publish mechanism, with `backlog` already routed as a kind, so the builder lands without touching
   the worker again.

#### What this branch deliberately does not do

- **It does not change `dkj-policy`.** Its single-repo worker is correct for a single repo and is left
  exactly as it is; a store that wants the shared one runs the builder **without** `-Worker`.
- **It does not deploy anything.** `-EmitWorker` writes the bundle and names `npx wrangler deploy`,
  because publishing is outward-facing and is a person's act.

### CREATE

- [x] `plugins/dkj-policy/dkj-policy-bwj/worker/bwj-pages-worker.js` -- the shared worker: KV-backed, no
      page content, one route `/<kind>/<32 hex>`, every miss the same 404.
- [x] `plugins/dkj-policy/dkj-policy-bwj/scripts/lib/page-publish-rules.ps1` -- the pure half: the kinds,
      the token shape, the KV key, the public URL, the API URL, the seam validation, the size ceiling.
- [x] `plugins/dkj-policy/dkj-policy-bwj/scripts/task/publish-page.ps1` -- the acting half: `-InitToken`,
      `-EmitWorker`, `-ShowUrl`, `-DryRun`, and the publish that verifies by reading the bytes back.
- [x] `plugins/dkj-policy/dkj-policy-bwj/skills/publish-page/SKILL.md` -- the skill page, not
      model-invocable, like `release-notes-page` beside it.
- [x] The plugin README: the `worker/` row, the shared-pages-worker section under
      *What this plugin owns*, the `Get-BwjPagesConfig` seam, and the skills table row.
- [x] The root README's two `<!-- skills:all -->` spans, which the lint gate reads.

### TEST

- [x] `scripts/tests/bwj-page-publish.tests.ps1` -- 83 assertions, 0 failures. It holds the design
      property rather than an output: no page baked into the bundle, no 32-hex identifier in anything
      shipped from a public repository, the worker's own route regex lifted out of the bundle and run,
      and the cross-language seam where the list of kinds lives in a `.ps1` and in a `.js`.
- [x] The script cases run in a child process against a **fixture store repo**, never against this
      checkout -- they are about what a store's seam answers, and this repo is not a store. Nothing
      reaches the network: `-DryRun` and the three refusals are the whole testable surface of a script
      whose remaining half is HTTP against somebody's account.
- [x] `check-plugin-integrity.ps1`: 0 errors.
- [x] The full suite set, exactly as CI runs it.
- [~] **Not tested against a real Cloudflare account**, and this is stated rather than ticked: no BWJ
      account is reachable from this repo. The upload is one `PUT` to the documented KV value endpoint
      and the read-back compares SHA-256, so a shape Cloudflare refuses fails loudly on the first real
      run rather than silently -- but the first real run is the proof, and it belongs to whoever does
      the one-time setup.

### DEPLOY: feat/1977-portable-bwj-worker

BWJ's two store repos can now publish a built page through **one** Cloudflare Worker, which is what
[#1977](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1977) asked for and what the worker
`dkj-policy` already ships cannot do. That one is correct for a single repo and is untouched here: it
writes the page into `worker.js` **as a literal**, and `wrangler deploy` replaces the whole script -- so
two repos pointed at one worker name means whichever deploys last erases the other's page, silently,
with both runs reporting success.

**The shared worker therefore carries no page content at all.** The pages live in Cloudflare KV, one key
per `<kind>:<token>`, and the worker's whole job is to look one up. A redeploy from either store
re-uploads byte-identical code and cannot disturb what the other published -- which is what makes *the
same worker* a true statement rather than a race. `-EmitWorker` copies the bundle out of the plugin
unchanged, so the suite can assert the emitted file is byte-identical to the shipped source: nothing
per-store is ever written into it.

**What differs per store is the path token and nothing else.** Both repos answer the same four seam
values -- `Get-BwjPagesConfig`, carrying `Worker`, `AccountId`, `NamespaceId` and `BaseUrl` -- and that
identity is what *one worker for both* means. It is a seam rather than four literals in the plugin for a
reason that is not configurability: this plugin ships from a **public** repository, so an account id, a
namespace id and a workers.dev origin written here would be published to everyone who can read the
marketplace. The Cloudflare **API token** is deliberately not part of it and is read from
`CLOUDFLARE_API_TOKEN` in the environment, because a seam answer is committed by construction and a
committed write token to an account is a different class of thing from an id that only identifies one.

**Three properties the suite exists to keep, each a way the design comes undone.** The worker holds no
content and no 32-hex identifier -- an edit that bakes a page back in would look like a simplification
and would restore exactly the defect this was filed about. The route is lifted out of the shipped bundle
and run, so *32 lowercase hex and nothing else* is asserted against the shipped characters: it is what
stops a request steering the KV lookup at a key of its own choosing, and it is why every miss -- wrong
kind, wrong token, unknown path, key never written -- answers the same 404. And the list of kinds is
written in a `.ps1` and in a `.js`, where a kind known to only one side publishes successfully to a key
nothing ever serves; nothing but the suite holds those two files together.

**The token doctrine is `dkj-policy`'s, read in a different repository.** It is an input and never
invented -- a token made up on the fly does not mean *a new path*, it means every link already sent now
404s while the publish reports success -- so `-InitToken` is separate and refuses to replace one, and a
missing token names three ways back in the order worth trying. The one answer that inverts is where it
lives: a store repo is **private**, so its tokens are committed, because a tracked token is what
survives a lost machine. And the publish **verifies by reading the value back and comparing SHA-256**,
which is the automatable half of the lesson the release-notes page states one layer up -- *verify the
bytes, never the command's own output*.

`backlog` is routed as a kind and has no builder yet; that is a follow-up issue by decision
([#1979](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1979)), so it lands later without
touching the worker again.

**Score:** 3

#### What makes this deploy extra special

BWJ colleagues who never open a repository get one link per store to the release notes, and the two
stores stop being one deploy away from erasing each other's page. The store side is a one-time setup --
answer one seam, create the namespace, deploy the worker once -- after which publishing is a single
command per page.

**Score:** 3

#### Pull Request

A portable, shared Cloudflare Worker for the two BWJ store repos

Plugins: dkj-policy-bwj
