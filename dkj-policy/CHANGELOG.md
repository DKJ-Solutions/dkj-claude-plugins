# Changelog

Everything merged since the last release sits under **`## [Unreleased]`**, **newest first**: **one `###` per
change**, and under it two named `####` sections. The `###` heading is the change's own —
`` DEPLOY: `<branch>` `` and the moment it
landed — and the text directly beneath it answers what a reader arrives with: what the change deploys to
`main`. Then `#### What makes this deploy extra special` for the second audience, and `#### Pull Request`.
Every level here moved one deeper on August 26, 2026, when the pending section above them was introduced and
the development cycle beside them shifted to match; entries written before that day carry the whole set one
level shallower and are read exactly as they always were.
The tier numbers live in the parser rather than in any heading. That second heading said `PR` rather than
`deploy` for one day, August 24 to 25, 2026, and `change` for the four days before that; every wording it
has ever carried is still read, so an entry below written under any of them is parsed exactly as it always
was — including the four written under `PR`, which are in the list below right now. Entries written
before August 23, 2026 carry that first answer under a `###` question of its own with the second nested
at `####` beneath it; entries before August 16 carry the longer set of headings that shape replaced, and
every earlier shape is read exactly as it always was. Every release ever cut is listed in
[`releases/history.md`](releases/history.md) — each with its date, type and title, and a link to what that
release was worth. How the mechanism works (entry files, the Significance sections, folding) is described in
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

Each change declares its own **reach**, and per audience how much it **weighs** there — one `##### Tier N`
sub-section per tier where a repo writes them numbered, each closing with its score; here the audience tier
carries a named heading beside the others instead. This list does not order on it: it is a record of what
landed, so it reads in the order things landed. What the declaration decides is what the **release
documents** lead with — they rank themselves on it — and what may be released at all, because **the bump
follows the highest tier pending**: **tier 0 only earns a patch**, **tier 1 or higher earns a minor**, and
a **major** recaps ten minors. So a changelog holding nothing but tier 0 is a patch waiting to be cut, not
a release with nobody to announce it to.

**The line directly under `## [Unreleased]` is a tally, and nobody types it.** It reads
`**4 / 9 minor entries**`: how many of the pending entries reach the audience this repo publishes to, out of
how many are waiting for the next release, and which bump that work has earned. The two numbers answer
different questions and may differ — the fraction counts tier 2 and above, the bump follows tier 1 and
above — so `**0 / 8 minor entries**` says nothing reaches a subscriber while the version still owes a minor
for what reaches management. It is
**derived from the entries below it every time it is written**, by the fold that adds one and the cut that
removes them all, so it holds no state of its own and a hand-edited count is simply corrected on the next
fold. It ends with an HTML comment that marks it as machine-written; that marker is what the next run
replaces, so anything else written in this space is left alone.

---

## [Unreleased]

**4 / 6 minor entries** <!-- pending-tally -->

### DEPLOY: feat/1977-portable-bwj-worker · 20260914-132829

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

Plugins: dkj-policy-bwj

[PR #1984](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1984)

---

### DEPLOY: feat/bwj-adopt-third-repo · 20260914-125826

`dkj-policy-bwj`'s two skills refused to run anywhere but BWJ's two Shopify stores. They now admit a
third repo by name -- `dkj-claude-plugins`, the plugin's own source -- which until today step 0 named
as the *most likely wrong* target, precisely because the templates it copies live there. The check
itself is unchanged and so is the measurement behind it (#1522): what changed is the verdict for that
one name, and step 0 now carries what the admission costs in a public repo whose tracker receives
every consumer's inbound reports.

**Score:** 2

#### What makes this deploy extra special

N/A -- a consumer of this marketplace gains nothing. The three-name list is this source repo letting
itself run a procedure it ships; the two BWJ stores it was written for are unaffected, and every
other repo is refused exactly as before.

**Score:** N/A

#### Pull Request

The BWJ adoption gate admits the plugin's own source repo as a third target

Plugins: dkj-policy-bwj

[PR #1983](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1983)

---

### DEPLOY: docs/1980-artifact-source-url-record · 20260914-123205

`dkj-policy`'s contribution cycle now states where a durable, published Artifact's own URL belongs when
its source is committed: beside the source, read and passed to the publish call before any
republication, and written into the same commit as the first publication rather than as later
housekeeping. Closes inbound
[#1980](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1980): without this, a session that
edits and republishes a committed Artifact source creates a second, unmaintained artifact while the
original link goes on serving stale content, and a page with its own state (a backlog/snapshot document
feeding a scheduled workflow) starts the second copy empty on its committed fallback data -- rendering
correctly and looking exactly like a current page, with nothing erroring and no gate able to catch it.
Scope is deliberately narrow: a durable surface whose source is committed, not the short-lived preview
handover `dkj-policy-bwj`'s own `PREVIEW-portable.md` chapter already covers for its own kind of link.
No mechanism is built here; the closing note a publishing session could print (the shape
`push-preview.ps1` already uses) is named as later, optional work.

**Score:** 3 -- a preventive rule closing a gap that has already caused a real, measured failure (a
second artifact silently orphaning the first, with a page's own persisted state left behind on the
stranded copy) rather than one hypothesised in the abstract; every consumer running this workflow that
publishes a durable Artifact is exposed to it, but nothing forces a reader to act today -- the rule
changes what a *future* session does the next time it republishes such a source.

#### What makes this deploy extra special

Every consumer of this workflow (this repo's audience, tier 2) that commits the source of a durable,
published Artifact was exposed to the failure this closes: silently duplicating a published page on
republish, with no error and no gate to catch it, and losing whatever state the original page had
accumulated. The rule tells a session what to do the next time it republishes such a source, so it
belongs in the record any subscriber of this service reads.

**Score:** 3 -- same reasoning as tier 0: a real, previously-unrecorded failure mode closed by a rule a
session needs to already know before its next republish, not a change anyone has to react to today.

#### Pull Request

record the published URL of a committed Artifact source

Plugins: dkj-policy

[PR #1981](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1981)

---

### DEPLOY: docs/1976-theme-lifecycle-delete-marker-claim · 20260914-114210

`THEME-LIFECYCLE-portable.md` claimed both BWJ stores answer `Get-ShopifyThemeDeleteMarker`; one of
them deliberately does not, pinned by its own test. Reworded the sentence to a store-agnostic
conditional so a reader no longer reads an unanswered seam as a gap to close against a `CLAUDE.md`
safety rule.

**Score:** 2

#### What makes this deploy extra special

N/A -- a portable-doc wording correction with no bearing on this repo's own audience tiers.

**Score:** N/A

#### Pull Request

correct THEME-LIFECYCLE-portable.md's claim that both BWJ stores answer Get-ShopifyThemeDeleteMarker

Plugins: dkj-policy-bwj

[PR #1978](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1978)

---

### DEPLOY: fix/1972-compose-ruleset-call · 20260914-085815

`adopt-ci-floor.ps1` said in five places that it composes the exact `gh api` call for the ruleset it
refuses to apply, and composed none -- the only `gh api` line it ever printed was a read. The sentence
was load-bearing rather than decorative: `IT NEVER FLIPS THE SETTING, AND THAT IS A RULE RATHER THAN A
LIMITATION` rests on it, so refusing to write was proportionate *because* the reader was handed the call.
Without it the command refused to write and refused to say what to write, which is a weaker bargain than
the one its own docstring defends. Measured while working #1971: three sentences read, no call found, and
the payload reconstructed by reading another repo's live `main-ci-gate` through `gh api` and diffing it --
precisely the "went looking through the ruleset UI" failure that section exists to prevent.

The claim is now true where it carries the argument. The `[gap]` arm -- the one that fires when the trunk
has no required status check, which is #1971's own situation -- prints a paste-ready PowerShell block: a
here-string holding the ruleset JSON, piped into `gh api --method POST repos/<slug>/rulesets --input -`.
It targets `refs/heads/<trunk>` rather than `~DEFAULT_BRANCH`, because the trunk this run was told about
is the authority and need not be the default branch. Where exactly one job id exists across the workflows
that trigger on `pull_request`, that check is filled in; otherwise the placeholder stands and every
candidate is printed with the workflow it came from, so choosing is a copy from a list rather than a hunt.
It still never runs the call, and the strictly-additive, dry-run-by-default contract is untouched --
printing a command is not applying one.

**The merge-queue instruction deliberately stays a UI pointer, and the prose now says so.** That is not
the same rule said twice for two targets: the required-check payload has exactly one free choice, which
the tree can usually answer itself, while a `merge_queue` rule asserts seven scheduling parameters --
merge method, grouping strategy, three limits, two timeouts -- that are policy nobody here has chosen, on
a control GitHub does not even render outside the plans that may have one. All five citations were
reworded to name which instruction composes and why the other does not, including the one scaffolded into
every adopting consumer's `repo-settings.yml` header. **Two of the five were not in the report**: the lens
at `.claude/specialists/lenses/05-15-extension.md` carried the same claim, and separately the
`.SYNOPSIS` line carried a worse version of it -- it attributed the printed command to "a repo that has
CHOSEN a merge queue," which matched neither the old behaviour nor the new. Three from the issue plus
these two is five.

One thing the repair had to move out of the way: `$repoSlug` lived inside the `else` branch of the
rules-read block, so under `Set-StrictMode -Version Latest` it was undefined on the `-RulesJsonOverride`
path -- the path the suite takes and the one the printed call needs the slug on. It is hoisted; the `gh`
fallback stays inside the network-reading branch, because a run with an override file and no network has
no way to answer it and is owed a placeholder instead.

**The copy edit that followed found the claim had spread further than those five.** Four consumer-facing
pages attributed the composed call to the queue arm specifically -- the one arm that, after this branch,
composes nothing at all: the `adopt-dkj-policy` skill page, `CONTRIBUTING-portable.md`, the scripts
README's own table row, and this repo's own scaffolded `.github/workflows/repo-settings.yml`, which still
carried the sentence the `$repoSettingsRunner` template wrote before it was reworded here. Each is now
corrected to name the required-check arm as the one that composes and the queue as the one that stays a
UI pointer. **The real total this branch corrects is nine** -- the five citations above plus these four.

**Score:** 3

#### What makes this deploy extra special

A consumer adopting this workflow with no ruleset on their trunk is handed the call that creates one,
instead of a paragraph telling them a required check is what turns the staleness guard on. The same run
also stops telling them, in a comment it writes into their own repo, that a call it never composed is
waiting further down the file.

**Score:** 3

#### Pull Request

adopt-ci-floor composes the ruleset call its docstring promises

Plugins: dkj-policy

[PR #1975](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1975)

---

### DEPLOY: docs/1973-native-worktree-note · 20260914-082022

Adds an explicit "why not native worktrees" section to the `worktree-lane` skill, answering the
question issue #1973 asked directly from the skill a reader would already be looking at, instead of
only from a comment buried in the issue thread.

**Score:** 2 -- noticed only by a session or a person who goes looking for the reasoning; nothing
about how the skill runs changes.

#### What makes this deploy extra special

Consuming repos running `dkj-policy` get the same explanation inside their own copy of the skill
after the next release, so "why doesn't this use native worktrees" doesn't have to be re-asked (or
re-researched) per consumer.

**Score:** 1 -- cosmetic; no behavior changes for a consumer, only the explanation reaches them.

#### Pull Request

Document why worktree-lane skips native worktree placement

Plugins: dkj-policy

[PR #1974](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1974)

---

