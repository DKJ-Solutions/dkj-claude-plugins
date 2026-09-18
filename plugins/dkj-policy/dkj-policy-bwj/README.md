# dkj-policy-bwj -- BWJ's shared extra layer, packaged so two repos cannot drift on it

**This is the shared law layer for BWJ's two Shopify stores -- `smartwatchbanden` and
`xoxowildhearts`.** The two repos are named by **store, not by org**, deliberately: they sat side by
side in `BWJ-ecommerce` until September 7, 2026, when `smartwatchbanden` moved to `BWJ-Development` as
a fresh repo and the old one was archived. There is no redirect behind the old name, and the move may
not be finished -- so an org in a scope statement is a fact with a shelf life, while the store names
are what this plugin is actually about. The two repos are identical in behaviour and differ only in brand,
and the connector register already flags them as the pair most at risk of quietly diverging. This
plugin is the thing that holds them together on the points that belong to exactly these two repos
and to none of the others Dave runs.

**And one of the four chapters below now reaches a third repo -- the other three do not.**
`dkj-claude-plugins`, this plugin's own source repo, was admitted to ticket handling alone on
September 14, 2026 (commit `b9b2a65a`): it is the one chapter whose subject -- a discovered issue --
exists here too, where the other three are Shopify-store policy and this repo runs no store. Each
chapter page states its own reach and, where it widened, cites that decision; this overview does not
repeat the detail.

**It has four chapters, and each has its own page:**

| chapter | the page | what it answers |
|---|---|---|
| **ticket handling** | [`WORKFLOW-portable.md`](WORKFLOW-portable.md) | what happens between spotting a problem and it being tracked where every BWJ colleague can see it |
| **the sync log** | [`SYNC-LOG-portable.md`](SYNC-LOG-portable.md) | what a `sync/` branch owes -- a durable record of what a third party did on the live theme, in the tree rather than only in a merged PR body |
| **the preview handover** | [`PREVIEW-portable.md`](PREVIEW-portable.md) | what a preview handover owes and how it reaches the reviewer -- the control variant beside the preview, on one link to a published page rather than a table of URLs |
| **the theme lifecycle** | [`THEME-LIFECYCLE-portable.md`](THEME-LIFECYCLE-portable.md) | what the estate owes at the two moments it grows -- a verified backup of live rotated at the release cut, and a sweep of this repo's spent previews after the live push |

They are separate chapters rather than sections of one page because they answer different
questions for different readers, and each of the last three was added later -- the sync log on inbound
[#1382](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1382), the preview handover on inbound
[#1874](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1874), the theme lifecycle on inbound
[#1965](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1965). Shipping several portable
pages is the established form here -- `dkj-policy` carries three.

**The chapters are policy, never mechanism.** The Asana CI and the sync machinery both live
elsewhere (`.github/` in each repo, and `dkj-subagents-shopify` respectively); what this plugin states is what
the two repos *owe*, which is Dave's house rule for them rather than a fact about Asana or Shopify.

**Beside the chapters, it now also ships mechanism the two stores share** -- see
[What this plugin owns](#what-this-plugin-owns) below. That is a deliberate widening
of the line above rather than a contradiction of it: a chapter is policy, and what sits in
[`scripts/`](scripts/) is the code both repos were writing twice.

## It is an add-on, not a replacement

`dkj-policy-bwj` **layers on top of `dkj-policy`** -- it does not stand in for it. It
extends exactly four seams of that workflow: *ticket-work, the layer before the branch*, *what a
`sync/` branch owes*, which that workflow deliberately exempts and leaves to the repo, *what a
preview handover contains* once the consumer's own rule says one is owed, and *what the theme estate
owes at a push and a cut*. It says
**nothing** about how a branch is named, which changes owe a preview, what a change owes before it can
open a PR, or what a release is -- those are still `dkj-policy`'s answers, unchanged. So the two do not hand
the specialists two contradicting answers to the same question; they answer different questions.

**One clause of that sentence was overtaken on September 18, 2026 and is corrected rather than
deleted.** *"Which changes owe a preview"* is no longer something this plugin says nothing about: it
now states that the **question** is asked on every branch, as the last step under `### CREATE` (see
below). What it still enumerates nowhere is which changes count as visible -- that judgement, and the
consumer's own reach rule, are untouched.

That is the deliberate reading of the "second workflow" note left in
[the `dkj-policy` README](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/README.md)
and the root README after
[#886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/886): a second workflow plugin is
safe here **because it is additive and non-overlapping**, not because the old guard was wrong.

**It carries no specialists.** A workflow changes how the existing ones work, not who they are.
Enabling this without `dkj-subagents-alpha` gives you a skill with nobody to invoke it; it also expects
`dkj-policy` to be enabled, because its rule begins where that workflow's ticket-work
step begins.

## What the cycle gains here

**Install this beside `dkj-policy` and that workflow's cycle gains exactly two steps.** Everything
before the step list is unchanged -- the issue, the branch, its `dkj-policy/<branch>.md`, the writing of
`### PLAN` / `### CREATE` / `### TEST` -- and nothing already in that document is rewritten
(Dave, September 18, 2026,
[#2100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2100)).

| the step | where it sits in the cycle | the rule |
|---|---|---|
| **Is the change visible in the frontend / storefront?** | the **last** step under `### CREATE` | a `- [~]` with its reason where nothing renders; otherwise a preview theme, a comment on the GitHub issue carrying the steps and the URLs, and `- [x]` only once a **person** confirms they looked -- [`PREVIEW-portable.md`](PREVIEW-portable.md) |
| **The go-live half of the paste-ready block** | just before the GitHub issue is closed | the block gains the next release date, the version it will carry and the live URLs per market, written by `build-golive-block.ps1` -- [`WORKFLOW-portable.md`](WORKFLOW-portable.md) |

**They are not a fifth chapter, deliberately.** Each belongs to the subject a chapter already owns --
previews, and ticket handling -- so it is written there, and this table is an index rather than a
third copy. What the index buys is the one question neither chapter answers on its own: *what does my
cycle gain by installing this?*

**Their reach is each chapter's own reach, not a new one.** The storefront step is chapter three's, so
it applies in the two store repos and nowhere else -- a repo with no theme has nothing to preview. The
go-live block is chapter one's, so it reaches the source repo too; there the live-URL list is simply
empty, because that repo declares no markets.

## Chapter one -- ticket handling, in one paragraph

A discovered issue is **created on GitHub first** -- GitHub is the source of truth, full technical
detail, the normal `dkj-subagents-alpha` filing bar unchanged. It is **classified in the same breath**: an issue
type (Bug / Feature / Task), plus the reach label where management and the commissioner would notice
it, both set at creation so nobody has to classify a tracker by hand a second time. It is then
**mirrored to Asana** as a colleague-friendly variant: plain language, outcome-framed, no code or
repo jargon, so any BWJ colleague can read it. The two are **cross-linked both ways**. When the
**GitHub issue is closed, the Asana task gets an update** saying the work is built and ready to test,
naming the pull request that closed it
-- by a small GitHub Actions workflow this plugin ships as a template for each repo to copy into its
own `.github/`. Reopening the issue posts a comment pointing to the issue for why -- it does not guess
whether the work is picked up again or going back to the requester; a daily reconciliation sweep
carries over anything a missed event left behind, without ever saying the same thing twice.

And that same daily run carries exactly one thing the other way: the Asana task's **`Prio-Score`**
becomes one of four prio labels on the GitHub issue (`prio-4` / `prio-3` / `prio-2` / `prio-1`), so
the priority the business sets on the board is readable where the work actually happens. It is the
only step that moves Asana -> GitHub, and the only thing this plugin writes outside Asana.

**It never ticks the task off, and it has no code path that could** (Dave, September 1, 2026): closing
the issue says the work is *built*, and only the colleague who asked for it can say it is *good*.
**A ticket that came the other way -- filed in Asana and copied into an issue for analysis -- is
covered too:** the workflow reads the Asana link in such an issue's header row when it carries no
machine marker of its own.

**And the card moves with it.** The board's sections **are** the cycle, in order, from *a colleague put
this on your name* to *tested and good*. Two questions, deliberately kept apart: a section is
recognised by the **number its name starts with**, so the words after it belong to the team and can be
rewritten any day; what each number **means** is stated once by the repo, in `Get-AsanaStageMap`. A
board whose sections are not numbered is never written to, and a column the map does not name is left
alone rather than guessed at.

**The three middle stages are the GitHub Project's three statuses, and always in sync with them** --
`Todo` / `In Progress` / `Done` are *filed* / *being built* / *closed*, read off the project board
rather than re-derived from the issue, because GitHub's own project workflows already write that field
and deriving it twice made two writers of one fact. `Get-GithubStatusMap` is where a repo states it.

**A board is not required, and a repo without one says so** -- an empty `FieldName` in that same map,
and the three stages come off the issue instead (closed / a pull request linked / neither). That is the
declaration the seam could not express until inbound #1536, which is what made its absence silent: the
missing floor also switched off *ready to test* below, so closing an issue told the submitter the work
was ready and left their card where it stood.

**The stage past those is reached by FEEDBACK, not by a column:** a card moves to *ready to test* once
the submitter has actually been told, which is the workflow's own close update -- and where a ticket
has no submitter that stage is skipped entirely, because there is nobody to hand it to.

The two ends stay the submitter's -- their untriaged inbox at one end and `Completed` at the other --
and the code permits the middle and nothing else, which is the same guarantee as *"it never ticks the
task off"* in the board's own currency. **And the last two sections are terminal**: once a card is in
*ready to test* or `Completed`, nothing here takes it back out, not even a reopen. Moves are otherwise
forward, with exactly two exceptions that are both a person saying something: the `needs-info` label,
which blocks a card whatever the board is doing, and an issue being reopened. Dave, September 2, 2026, closing
[#1222](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1222); **there is exactly one such
board**, which is what makes the *"which board?"* question inbound
[#1217](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1217) ran into moot.

The whole rule, with the field-by-field shape of the Asana variant and the cross-link markers, is in
[`WORKFLOW-portable.md`](WORKFLOW-portable.md) -- that is the page to read, and the page to point BWJ
colleagues at.

## Chapter two -- the sync log, in one paragraph

A `sync/` branch mirrors what a **third party** changed on the live Shopify theme. It is deliberately
exempt from the changelog -- that is somebody else's change, not this repo's -- which until inbound
[#1382](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1382) left it the only branch in
the workflow owing **nothing durable at all**: the sole account of what was taken and what was held
back was the PR body on GitHub, in two repos whose standing rule is that a sync PR does *not* wait
for review. So a sync now owes a **sync-log entry** where an ordinary branch owes a changelog entry:
`dkj-policy-bwj/SYNC-LOG.md` in the repo's own root, newest at the top, one entry per sync branch, written
and committed by `sync-main.ps1` in the same breath as the branch itself. It is never folded, never
cut, and never reaches a release note.

The mechanism is `dkj-subagents-shopify`'s and reaches every Shopify consumer; the **policy** is this
plugin's, and it is silent until a repo answers one seam -- `Get-ShopifySyncLogPath`. The whole rule,
the entry's shape, and why there is no gate are in
[`SYNC-LOG-portable.md`](SYNC-LOG-portable.md).

## Chapter three -- the preview handover, in one paragraph

Where a change owes a preview, the handover is a **pair per market**: the preview URL, and the
**control** -- the same page on the live theme, so the reader sees the difference instead of recalling
it. A preview alone shows what a page will look like, never what changed, and the half it leaves out is
exactly the judgement it was pushed for. It costs nothing to add: the changed page has already been
resolved per market to build the preview list. The one thing that has to be written down is **what the
control URL is** -- it names the **live theme id** (`Get-ShopifyLiveThemeId`, which the repo already
answers for the live-theme guard), and not the bare URL with the parameter dropped. `preview_theme_id`
sets a cookie, so after a preview has been opened the bare URL keeps serving the preview theme: the
control tab silently agrees with the preview, and the reviewer concludes nothing changed. Measured, with
the two neighbouring wrong answers, in [`PREVIEW-portable.md`](PREVIEW-portable.md).

**And the pair is handed over as ONE LINK to a published page, never as a table of URLs** (inbound
[#1873](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1873), the same day and the same
handover as the rule above). Pairing the URLs doubles them, and five markets by two variants is ten
URLs of 70 to 100 characters -- which a terminal wraps until the columns saying *which market, preview
or control* are gone, which cannot even be selected to copy, and which a phone cannot scan at all,
though a phone is where storefront work is judged. So the page carries one card per market: a QR code
to the preview, the pair as text beneath it, and above and below them what a URL cannot say -- how to
see the change, what the gates already proved, and the one question being asked. The rule is carried at
the print site too, generically, so it does not lose to `push-preview`'s own printed list. The page is
also where this chapter states what it deliberately does **not** decide: which changes owe a preview at
all, and when the PR may open, both still the consumer's and `dkj-policy`'s.

## What is in this folder

| what | what it holds |
|---|---|
| [`WORKFLOW-portable.md`](WORKFLOW-portable.md) | chapter one in prose -- ticket handling, read alongside your repo's own Asana config |
| [`SYNC-LOG-portable.md`](SYNC-LOG-portable.md) | chapter two in prose -- what a `sync/` branch owes, where the record lands, and what it stays out of |
| [`PREVIEW-portable.md`](PREVIEW-portable.md) | chapter three in prose -- what a preview handover contains, why the control URL names the live theme id, and why the whole pair travels as one link rather than a table |
| [`THEME-LIFECYCLE-portable.md`](THEME-LIFECYCLE-portable.md) | chapter four in prose -- the push-then-cut order and what it makes the backup MEAN, the three standing approvals for deleting a theme and their bounds, and why the delete set is a prefix this repo wrote |
| [`scripts/`](scripts/) | the mechanism both stores share, to **dot-source** from the plugin cache rather than copy -- see [What this plugin owns](#what-this-plugin-owns) |
| [`worker/`](worker/) | the one Cloudflare Worker both stores publish through, as source -- deployed once, never copied into a repo, and carrying no page content of its own |
| [`skills/`](skills/) | the skills a specialist invokes |
| [`templates/`](templates/) | the CI mechanism to **copy** into each repo's `.github/` -- GitHub only runs workflows from a repo's own `.github/`, so what ships here is the reference to copy and diff against, the same pattern as `dkj-policy/templates/pull_request_template.md` |

**No `subagents/`, no `manuals/`, no `hooks/`, no `blueprint/`.** Agents and manuals belong to a team.
The hooks and blueprint a workflow carries "only where it needs them" -- this one needs neither.

## What this plugin owns

**Anything the two stores share goes to `dkj-policy-bwj`, unless it is obviously universal**
(Dave, September 11, 2026, on
[#1881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1881)). That is the whole ruling, and
it decides where a mechanism lives the moment a second store turns out to need it.

**What it is answering.** The sibling check
([#1869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1869)) compared the two stores for
the first time and found 69 mechanisms only one of them has, 19 shared files that have grown apart, and
5 pairs that are one capability under two filenames. The load-bearing instance is
`prune-merged.ps1`: asked for centrally through the inbound route, shipped in `dkj-policy` 4.21.0,
adopted by one store and still hand-carried in the other three weeks later. **The inbound route worked
and nothing propagated the result to the second consumer.** Making that a rule needed one decision --
*which plugin* -- and the answer above is it.

**Why here and not in `dkj-policy`.** `dkj-policy` is enabled by every consumer of this marketplace,
and a mechanism that reaches all of them for the benefit of two stores is the larger blast radius. The
price is accepted and stated: `dkj-policy` stays thinner than it could be, and the two stores get a
BWJ-only copy of things that are arguably universal -- a test harness is the standing example. *Obviously
universal* is the exception rather than the default, and it means the mechanism has a demonstrated
reader outside these two repos, not that one can be imagined.

**Two homes this ruling does not touch:**

- **`dkj-subagents-shopify`** already owns the theme mechanisms -- `push-preview.ps1`, `sync-main.ps1`,
  `preview-theme.ps1`, `sync-rules.ps1`. A store still carrying its own copy of one of those is an
  **adoption gap**, not an ownership question; the answer is to forward to the plugin, not to move
  anything.
- **Your own `scripts/repo-config.ps1`** keeps the *data*. Only the mechanism travels: the domain
  table, the theme ids, the board gid and the workspace stay a seam answer in each store, which is what
  lets one mechanism serve two brands.

### The second question, before you build anything

A store repo's own rule asks **"does the plugin provide this?"** -- and that is a one-repo question. With
a structural N of two it answers *"no duplication"* right up until somebody opens the other repo, which
is exactly how the divergence above accumulated. So it is joined by a second:

> **"Is there a second store that needs this too?"**

If the answer is yes, it belongs here, and the branch that builds it files the inbound issue that brings
it here rather than landing a second local copy. The sibling check is the backstop, not the rule: it
reports after the fact and refuses nothing.

### What ships under it today

| what | where | notes |
|---|---|---|
| the test harness | [`scripts/tests/test-lib.ps1`](scripts/tests/test-lib.ps1) | the assert helpers, `ConvertTo-CapturedText`, `Add-SuiteFault` and `Assert-PluginLoadedForProject` -- the superset of what the two stores each had, in English |
| the market URL builder | [`scripts/lib/market-urls.ps1`](scripts/lib/market-urls.ps1) | the storefront and preview URLs per market -- the superset of what the two stores each had, in English. The market table itself stays a `Get-StorefrontMarkets` seam answer per store |
| the shared pages worker | [`worker/bwj-pages-worker.js`](worker/bwj-pages-worker.js) + [`scripts/task/publish-page.ps1`](scripts/task/publish-page.ps1) + [`scripts/lib/page-publish-rules.ps1`](scripts/lib/page-publish-rules.ps1) | **one** Cloudflare Worker for both stores, serving a built page at an unguessable path -- see [The shared pages worker](#the-shared-pages-worker) below |
| the backlog page builder | [`scripts/task/build-backlog-page.ps1`](scripts/task/build-backlog-page.ps1) + [`scripts/lib/backlog-page-rules.ps1`](scripts/lib/backlog-page-rules.ps1) | writes `minor-backlog.html` from the open, reach-labelled issues, showing each one's mirrored Asana task text -- see [`build-backlog-page`](skills/build-backlog-page/SKILL.md) |

#### The shared pages worker

**Issue [#1977](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1977): both stores publish
through ONE worker.** It carries the pages a colleague outside the development work has to read --
the release notes, and the minor backlog
[`build-backlog-page`](skills/build-backlog-page/SKILL.md) builds (issue
[#1979](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1979)) -- because those documents
live as markdown, or as issues and Asana tasks, in a **private** repository, which is the right home
for them and the wrong place to read them.

**`dkj-policy`'s own worker could not be that one, and the reason is mechanical.**
`build-release-notes-page.ps1 -Worker` writes the page into `worker.js` **as a literal**, and
`wrangler deploy` replaces the whole script -- so pointing both stores at one worker name means
whichever deploys last erases the other store's page. Silently: both runs report success, and the
loss is found by whoever opens a link that used to work.

**So this worker carries no content at all.** The pages sit in Cloudflare KV, one key per
`<kind>:<token>`, and a redeploy from either store re-uploads byte-identical code. That is what makes
*the same worker* a true statement rather than a race, and it is the property
`scripts/tests/bwj-page-publish.tests.ps1` in the source repo exists to keep -- including the seam
between two languages, where the list of kinds is written in a `.ps1` and in a `.js` and nothing else
can hold the two together.

**What differs per store is the path token and nothing else.** Both repos answer the same four seam
values -- one account, one namespace, one worker, one origin -- so the token is the only thing that
makes one store's URL not the other's, and it is why two stores can share a namespace without being
able to reach each other's pages by accident. The whole procedure, the token doctrine and what the
path does and does not lock are in [`publish-page`](skills/publish-page/SKILL.md).

**Adopting the test harness** in a store repo: replace the local `scripts/tests/test-lib.ps1` with a
forwarder that dot-sources this one out of the plugin cache, resolved through that repo's
`scripts/lib/plugin-scripts.ps1` -- the shape `prune-merged.ps1` already uses there. Keep the file name,
because every suite already dot-sources `test-lib.ps1` from its own folder: the forwarder costs one file
and no suite changes.

**Adopting the market URL builder** is the same forwarder shape, and it keeps whichever file name that
store's callers already use -- `market-domains.ps1` in one repo, `market-urls.ps1` in the other. Two
things beside the forwarder are real work rather than a rename, and both are named in the lib's own
header: `Get-StorefrontMarkets` has to be answered in `scripts/repo-config.ps1` first, and
`Get-PreviewPrimeUrl` (singular) is replaced by `Get-PreviewPrimeUrls` (plural), which a caller has to
loop over. That plural is the one place where converging two stores **changed** an answer rather than
merging one: a preview cookie is set per domain, so a single prime URL is right for a one-domain store
and silently primes one of five for the other -- inside the very check that exists to prove the reader
is not looking at live.

**Why the market table is the one thing that did not travel.** It is the *data*, and the split between
mechanism here and data in each store's seam is what lets one builder serve two brands that share no
domain at all. One store runs its markets on five separate domains; the other runs them on a single
domain with locale path prefixes. Copying either table onto the other store produces URLs that do not
exist -- which is also why neither repo ever found the other's copy: only the exported function names
matched, so the sibling check could see the pair only as `ALIASED`
([#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886), candidate 1).

## The skills

<!-- skills:plugin -->

| skill | when |
|---|---|
| [`report-issue`](skills/report-issue/SKILL.md) | a real issue has been found in a BWJ store repo -- files it on GitHub with its type and reach label, mirrors it to Asana as the colleague-facing variant, and writes the cross-links |
| [`adopt-dkj-policy-bwj`](skills/adopt-dkj-policy-bwj/SKILL.md) | one-time setup in a store repo -- copies the CI mechanism into `.github/`, proposes the Asana config seam, and prints the secret/variable setup |
| [`build-backlog-page`](skills/build-backlog-page/SKILL.md) | the minor-backlog page needs refreshing -- reads the open, reach-labelled issues and shows each one's mirrored Asana task text, never the issue's own |
| [`publish-page`](skills/publish-page/SKILL.md) | a built page has to reach somebody outside the development work -- publishes it to the one worker both stores share, at an unguessable path, and verifies by reading the bytes back |
| [`golive-block`](skills/golive-block/SKILL.md) | the work is shipped and the issue is about to close -- writes the paste-ready block with its go-live half: where the result can be seen, the next release day, the version it is on course for, and the live URL per market |

<!-- /skills:plugin -->

## What it expects from your repo -- the seam

Both chapters answer themselves out of your repo-owned `scripts/repo-config.ps1` -- the same file
`dkj-policy` already dot-sources.

**Chapter two needs exactly one function**, and it is the switch that turns the whole chapter on:

- `Get-ShopifySyncLogPath` -- where the log lives, repo-root-relative. Answer it `'dkj-policy-bwj/SYNC-LOG.md'`
  in **both** repos. Leave it out and no log is written at all, which is the default every other
  Shopify consumer gets. The machinery is `dkj-subagents-shopify`'s, so it is already present; this answer is
  what asks it to run. `adopt-shopify-floor` lists it among the optional Shopify seams it writes into
  that file as commented guidance.

**Chapter one needs the Asana answers**, a set of functions in that same file. The `report-issue`
skill needs to know which workspace and project a mirrored task lands in, and the CI mechanism needs
the project:

- `Get-AsanaWorkspaceGid` -- the Asana workspace GID.
- `Get-AsanaStageMap` -- which numbered section of the board each stage of the cycle is, plus the
  label that drives the blocked column. **Optional**: leave it out and the built-in map is used, which
  is right only if your board happens to be numbered the same way, and the run says which map it read.
  Semantic keys rather than GIDs, so a rebuilt column costs nothing.
- `Get-GithubStatusMap` -- which **GitHub Project status** each of the three middle stages is, keyed on
  the project board's own column names, plus `SubmitterPattern`: the regex over an Asana task's notes
  that names who asked for it. It is also where a repo with **no board** says so, by naming no field at
  all; the stages then come off the issue and no `GH_PROJECT_TOKEN` is needed. **Also optional**, with
  one consequence worth knowing: leave the pattern
  out and *ready to test* is never entered automatically, so every closed ticket waits a column short
  for a person. That is the fail-safe default rather than a fault -- a card pushed into the submitter's
  column claims a handover that never happened -- but it is silent, so it is worth stating deliberately.
- `Get-AsanaProjectGid` -- the project a mirrored task is created in, and it has exactly one correct
  value: **the board the team reads**. Two independent constraints land on the same answer. `Prio-Score`
  only reaches a task once it has been added to that task's project via the project's own
  `custom_field_settings` -- sitting in the board's workspace is not enough to guarantee that -- so a
  project that does not carry the field makes the prio labels of
  [step 5](WORKFLOW-portable.md#5-the-asana-prio-score-comes-back-as-a-github-label) reach only the
  tickets imported from the board; and the stages of
  [step 6](WORKFLOW-portable.md#6-the-boards-sections-are-the-cycle----one-card-one-column-per-stage)
  live on
  that board's sections, so a task filed anywhere else is on no pipeline and never moves a column.
  Neither failure says anything in a log.
- `Get-AsanaIssueFieldGid` and `Get-AsanaTypeFieldGid` -- the GIDs of the board's `Github Issue` and
  `Github Type` custom fields, so a mirrored task carries the issue URL and the issue type from the
  moment it is created rather than waiting for somebody to type them in. **Both optional**, and
  `$null` -- the default -- is the common answer: most boards carry neither, and `report-issue`
  skips whichever is unset without saying anything. Where a board does carry one, leaving it unset is
  the state that costs something, because the field is then filled by hand or not at all.
- `Get-ReachLabel` -- **the name GitHub stores for the reach label**, and the one function in this list
  that says nothing about Asana. The axis it carries is fixed and portable, defined for every repo running this workflow in
  [`RELEASES-portable.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/RELEASES-portable.md#the-same-scale-on-an-issue--the-reach-label)
  and applied to these two stores in [`WORKFLOW-portable.md`](WORKFLOW-portable.md#the-reach-label----the-reach-axis-carried-onto-issues);
  the string is yours, because a repo renames a label for its own colleagues without consulting a
  plugin. **Optional, default `minor`** -- so answer it only where your label is called something
  else, which since [#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870) means a
  store still carrying `tier-1` rather than one that has renamed. A consumer renaming that label on
  September 11, 2026 is what made this a seam rather than a literal
  ([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)): `gh issue create` fails
  outright on a label the repo does not have, so the filing half broke loudly -- while
  `adopt-dkj-policy-bwj`, being strictly additive, would have quietly re-created `tier-1` beside it.

`adopt-dkj-policy-bwj` **proposes** these, it never places them: they state what your repo *is*, and the
project may differ per brand. The CI half reads the project from the repo variable
`ASANA_PROJECT_GID` and its token from the secret `ASANA_PAT` -- it addresses every task by GID, so
it needs no workspace of its own.

**And the mechanism under [What this plugin owns](#what-this-plugin-owns) needs one answer of its own**,
in that same file. It belongs to no chapter, because a chapter is policy and this is the data half of a
shared lib:

- `Get-StorefrontMarkets` -- the markets this store serves, one row per market, each carrying `Market`
  (the label), `Domain` (the host, no scheme and no trailing slash) and `PathPrefix` (`''` for a market
  at the domain root, otherwise `'/de'`-shaped). Order is display order and the first row is the
  primary market. **Required** by
  [`scripts/lib/market-urls.ps1`](scripts/lib/market-urls.ps1) and by nothing else, so a repo that
  does not build storefront URLs leaves it out; where it is needed and missing, every function in that
  lib refuses by name rather than inventing a table. Read it off the live storefront's public hreflang
  set rather than from memory when a market is added or removed -- both stores' original copies
  recorded that instruction, and it is the reason neither table had silently rotted.

- `Get-BwjPagesConfig` -- the shared pages worker: `Worker`, `AccountId`, `NamespaceId` and
  `BaseUrl`. **Required** by [`publish-page`](skills/publish-page/SKILL.md) and by nothing else, and
  it is the one seam in this list whose answer is **identical in both stores** -- that identity is
  what *one worker for both* means. It is a seam rather than four literals in the plugin because this
  plugin ships from a **public** repository and a store repo does not: the boundary it draws is
  confidentiality, not configurability, which is the opposite of `Get-StorefrontMarkets` above.
  **The Cloudflare API token is deliberately NOT part of it** -- it is read from
  `CLOUDFLARE_API_TOKEN` in the environment, because a seam answer is committed by construction and a
  committed write token to an account is a different class of thing from an id that only identifies
  one.

## Enabling it

An ordinary plugin change: enable `dkj-policy-bwj` in `.claude/settings.json` alongside `dkj-subagents-alpha`
and `dkj-policy`, then run [`adopt-dkj-policy-bwj`](skills/adopt-dkj-policy-bwj/SKILL.md) once for
chapter one, and answer `Get-ShopifySyncLogPath` for chapter two.

**Chapter two needs no skill of its own** -- its one adopt step, scaffolding `dkj-policy-bwj/SYNC-LOG.md`
with its masthead, rides along inside `adopt-dkj-policy-bwj`'s run rather than getting a second skill for a
single file. There is still no CI to wire: the folder and the file exist from that run on, and every
sync after it prepends. See [`SYNC-LOG-portable.md`](SYNC-LOG-portable.md#where-the-record-lives) for
why scaffolding it unconditionally at adopt time is what removes the old ambiguity rather than
reintroducing it.

Disabling the plugin removes nothing it already wrote to your repo -- the CI workflow, the config and
the sync log stay; the skills and the pages that explain them stop.
