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
- [x] The root README's two marked skill-enumeration spans, which the lint gate reads. Named rather
      than quoted on purpose: that span walker masks fenced blocks and not inline backticks, so a
      document mentioning the opening marker is read as opening a span of its own -- which is how
      this very bullet first turned the gate red.

### TEST

- [x] The pre-PR review chain -- Victor, Sebastian and Edith in parallel on the diff. What each found
      and what it changed is under *What the review changed* below; every finding was verified against
      the tree before it was repaired, and none was taken on the report's word.
- [x] `scripts/tests/bwj-page-publish.tests.ps1` -- 91 assertions, 0 failures. It holds the design
      property rather than an output: no page baked into the bundle, no 32-hex identifier in anything
      shipped from a public repository, the worker's own route regex lifted out of the bundle and run,
      and the cross-language seam where the list of kinds lives in a `.ps1` and in a `.js`.
- [x] The script cases run in a child process against a **fixture store repo**, never against this
      checkout -- they are about what a store's seam answers, and this repo is not a store. Nothing
      reaches the network: `-DryRun` and the three refusals are the whole testable surface of a script
      whose remaining half is HTTP against somebody's account.
- [x] `check-plugin-integrity.ps1`: 0 errors.
- [x] The full suite set, exactly as CI runs it -- 105 suites, run by `open-pr`'s own gate rather than
      pre-run beside it. It caught one thing three reviewers had not: `shared-scripts.tests.ps1`'s
      repo-wide guard over `2>$null` on a **native** command. Under `EAP=Stop` git's ordinary stderr
      becomes a terminating error, so the repo-root fallback it guards could never have been reached.
      Wrapped, which is the shape that guard exonerates.
- [~] **Not tested against a real Cloudflare account**, and this is stated rather than ticked: no BWJ
      account is reachable from this repo. The upload is one `PUT` to the documented KV value endpoint
      and the read-back compares SHA-256, so a shape Cloudflare refuses fails loudly on the first real
      run rather than silently -- but the first real run is the proof, and it belongs to whoever does
      the one-time setup.

#### What the review changed

- **The stray-token search was missing, and the docstring claimed it** (Victor). This script's own
  header says *"same doctrine as dkj-policy's page token"* -- and the one piece of that doctrine that
  actually prevents [#1444](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1444) had not
  been carried over. The page directory is derived from the same seam and gitignored the same way, so
  the same folder move strands the token, and `-InitToken` would have found *"nothing here"* and
  minted a second one. `Find-BwjStrayPageToken` now runs on both refusal paths, **scoped to one kind**
  -- a search across all of them would report a sibling's correct token as a stray on the very run
  minting the second kind.
- **`-UseBasicParsing` on the read-back** (Victor). Without it Windows PowerShell hands the body to
  the Internet Explorer engine to build a DOM, and the body is a whole HTML page. It breaks the
  script's own correctness proof, *after* the upload has landed.
- **A failed temp-file cleanup was silent** (Sebastian). That file is a copy of the page, and in a
  store repo the page is private content in a world-readable directory. `-ErrorAction
  SilentlyContinue` stays -- it must not fail the publish -- and a warning now names the leftover.
- **The 404 carried no `cache-control`** (Sebastian). A publish creates a key that did not exist a
  moment earlier, so a cached 404 can outlive the link becoming valid.
- **`$put.success` was read bare under StrictMode** (Victor). A response with no such field is not a
  success; it is a shape nobody has seen, and it now reports as an API answer rather than as a
  PowerShell fault.
- **`Get-Command` for the two seam probes** (Victor) -- the idiom
  [#1729](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1729) moved the source tree off,
  because it parses the name as a wildcard and pays a PATH scan on every miss, which is the normal
  case for an optional seam. Written out inline rather than dot-sourced, because this plugin's scripts
  deliberately pull in nothing outside their own folder.
- **A test label overclaimed** (Victor): *"one store URL is not the other"* was asserted by an exit
  code. It now reads the second kind's token and asserts it differs from the first's.
- **The token files had no `.gitignore` answer** (Edith). They live in the directory
  `release-notes-page` tells every consumer to ignore wholesale, so *"commit the token files"* was an
  instruction with no way to follow it. The skill now carries the working pattern and says why the
  obvious spelling fails **silently** -- git does not descend into an excluded directory, so the
  negation is never read.
- **The doctrine was quoted four ways** (Edith) while styled as a fixed citation, unlike the token
  doctrine, which is verbatim everywhere. Aligned on the source's wording.
- **And this document turned the gate red itself** (Edith, who reproduced it by running the gate
  rather than reading it). A CREATE bullet quoted the `skills:all` marker inside backticks; that span
  walker masks fenced blocks and not inline backticks, so the mention read as an unclosed span opener.

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
bytes the URL serves, never the deploy command's output*.

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
