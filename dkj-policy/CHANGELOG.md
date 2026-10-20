# Changelog

## [Unreleased]

**16 / 19 minor entries** <!-- pending-tally -->

### DEPLOY: feat/hub-width-full · 20261020-073112Z

Every page the repo hub serves now opens in full page width when nobody has picked a width yet, where it
used to fall back to the house script's fluid column. A width picked in the settings panel still wins.

**Score:** 2

#### What makes this deploy extra special

A developer opening the repo hub for the first time gets the whole screen for its tables and cards.

**Score:** 2

#### Pull Request

The repo hub opens in full page width by default

Plugins: dkj-solutions

[PR #3197](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3197)

---

### DEPLOY: feat/heading-colours-h2-h3 · 20261019-195835Z

Inside this repo the brandbook, the repo hub and the dev pages render with the twelve-step scale. The hub's theme
table shows twelve columns.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release has to renumber its own `--primary-*` uses. The names stay valid,
so a missed one fails silently and just shows the wrong colour. The README's migration table gives the order. The
headings change by themselves: h2 moves off the h1's colour to `-10`, and h3-h6 take the new dark step `-11`.
The colours themselves change too: `-1` and `-12` are almost white and black, the theme's colour (`-9`) is the most
saturated version of its hue that still reads on the page, and the cards and lines take a subtle tint of it.

**Score:** 5

#### Pull Request

The primary scale grows to twelve steps (4 light, 4 grey, 4 dark), anchored at the edges and the colour; h2 takes -10 and h3-h6 -11

Plugins: dkj-solutions

[PR #3196](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3196)

---

### DEPLOY: fix/3189-build-release-notes-on-demand · 20261019-191555Z

The Repo hub's Release notes link here works on a fresh clone. The general pages server builds the gitignored
page itself when it is missing or older than a release document, so nobody has to run
`build-release-notes-page.ps1` by hand any more (#3189).

**Score:** 2

#### What makes this deploy extra special

In a DKJ-Solutions repo with `dkj-solutions` enabled, the hub's Release notes card opens the notes instead
of a 404, and shows the latest release without a manual rebuild. Where the page cannot be built, the 404
now says why.

**Score:** 2

#### Pull Request

Repo hub's Release notes link 404s: the general pages server builds the page on demand

Plugins: dkj-solutions

[PR #3192](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3192)

---

### DEPLOY: fix/3190-live-record-whole-pr-diff · 20261019-190616Z

The change here is only in the bwj-development plugin's script and its tests.

**Score:** 1

#### What makes this deploy extra special

In a BWJ store repo, `notify-live -LivePushRecord` now sees a held file that an earlier commit of a
rebase-merged PR touched, and does not tell that issue's requester their work is live. A PR whose file
list gh truncates is reported as UNREAD instead of guessed. This prevents a failure that has not happened
yet: a "Rebase and merge" through the GitHub UI telling a requester "live" while their file was held back.

**Score:** 1

#### Pull Request

notify-live -LivePushRecord: read a PR's whole diff, so a rebase-merged PR's earlier commits count

Plugins: bwj-development

[PR #3195](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3195)

---

### DEPLOY: feat/3176-app-deploy-in-live-record · 20261019-185315Z

live-preflight writes one `live <path>` line per file under `Get-ShopifyAppRoot` into the live-push
record, and writes the record for an app-only release too. A deploy that is not run is marked `hold` by
hand, like a held theme file. `notify-live -LivePushRecord <path>` reads the same record through a
mirrored `live-record-lib`. It holds an issue whose PR changed a `hold` path, and it refuses a record it
cannot parse. prepare-release's step 7 tells you to pass the record (#3176).

**Score:** 2

#### What makes this deploy extra special

A store that ships a Shopify app no longer has an app-only change announced as live to its requester,
or listed as landed by the cut, before `shopify app deploy` has run. Pass the record to notify-live.

**Score:** 3

#### Pull Request

notify-live treats an app-only change as live before the shopify app deploy has run

Plugins: bwj-development, dkj-policy, dkj-subagents-shopify

[PR #3191](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3191)

---

### DEPLOY: feat/3183-golive-block-by-hand · 20261019-182305Z

`build-golive-block.ps1 -ByHand [-Story <gid>]` records on the issue that its closed message was posted on
the Asana task by hand. The close guard accepts that record as this round's block, and the
`asana-closed-message` workflow posts nothing beside the hand-written message. A record from before the
last reopen, or from an untrusted author, silences nothing. `-ByHand` skips the pull-request and
shared-task checks, and the guard's refusal names it among its fixes (#3183).

**Score:** 2

#### What makes this deploy extra special

A hand-approved closed message no longer needs the issue body edited around the close to keep the
workflow from posting a second message beside it.

**Score:** 2

#### Pull Request

build-golive-block -ByHand: a sanctioned opt-out for a closed message posted by hand

Plugins: bwj-development

[PR #3188](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3188)

---

### DEPLOY: docs/3177-requester-verifies-live-result · 20261019-181059Z

Inside this repo the rule is text in the bwj-development page. Nothing reads it.

**Score:** 1

#### What makes this deploy extra special

In a BWJ store repo, a dev session stops taking the post-live acceptance measurement of a fix whose
result is a number (PageSpeed, conversion, ranking). It closes the issue instead, with a closed message
telling the requester how to measure and against which targets. In smartwatchbanden that measurement
was picked up four times, and three of those stalled on PageSpeed quota and missing browser tooling.

**Score:** 3

#### Pull Request

BWJ ticket handling: the requester re-measures a live result, not a dev session

Plugins: bwj-development

[PR #3184](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3184)

---

### DEPLOY: feat/3182-golive-refuses-shared-task · 20261019-174252Z

`build-golive-block.ps1 -Post` now refuses while another open issue links the same Asana task, and names
that issue: the closed message says "this Asana task is now in review", and posted from a follow-up or
sub-issue it would say so while the umbrella is still open. `-OutFile` warns, `-Force` posts regardless,
and `WORKFLOW-portable.md` states that a follow-up or sub-issue does not take its umbrella's task link
(#3182).

**Score:** 2

#### What makes this deploy extra special

A BWJ requester no longer hears that their task is in review because a follow-up closed while the issue
that actually answers their request is still open.

**Score:** 2

#### Pull Request

build-golive-block refuses a post while another open issue links the same Asana task

Plugins: bwj-development

[PR #3187](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3187)

---

### DEPLOY: feat/3181-research-warns-on-merged-pr · 20261019-165907Z

`build-golive-block.ps1 -Research -Post` now warns when a merged pull request closes or references the
issue: the research form tells the requester "Nothing has changed", which is then likely false, and the
warning names the go-live form with `-LiveSince` and `-Measure` instead. It is a warning, not a refusal
(#3181).

**Score:** 2

#### What makes this deploy extra special

A session about to close a BWJ ticket with a research message after a change already went live is told
so before the requester reads "Nothing has changed".

**Score:** 2

#### Pull Request

build-golive-block -Research warns when a merged pull request closes or references the issue

Plugins: bwj-development

[PR #3186](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3186)

---

### DEPLOY: feat/3179-golive-measure-form · 20261019-163434Z

`build-golive-block.ps1` gains a third completed form, `-Measure`, for a ticket whose result is a number
the requester measures again -- a page-speed target, a conversion rate, a ranking. From a prose file's
`[measure]` and `[targets]` (and optional `[baseline]` and `[when]`) it writes how to measure and the
targets, and the closed message opens with "Nothing changes visibly on the storefront. You can take a new
measurement yourself, as described below." and ends by asking whether the target is met (#3179).

**Score:** 3

#### What makes this deploy extra special

A BWJ store can close a measurement follow-up with a message that tells the requester how to measure it
and against which targets, instead of a research message that says nothing changed or a go-live message
that points at nothing. The colleague gets a clear "is the target met?" in the Asana task.

**Score:** 3

#### Pull Request

golive-block gains a measurement form for a ticket whose result is a number the requester re-measures

Plugins: bwj-development

[PR #3185](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3185)

---

### DEPLOY: feat/3175-h2-above-cards · 20261019-161745Z

An `h2` never stands inside a card any more: it stands above the card or cards it heads, in a `.grid-2`
with a `.grid__head`, and a card's own title is an `h3` (`.card__title` now renders at `--text-h3`). A
headed group takes extra room above it in the page column, so the `h2`s visibly group the cards. The
`check-house-style` gate gains a fourth check, `heading`, that reports an `h2` inside a card (#3175).

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app whose cards carry an `h2` title fails the house-style CI gate from the merge on,
because the reusable gate runs its checks from `main`: move each `h2` and its sub line into a `.grid__head`
above the card and add `.grid__full` to the card, as the house-style README's "An h2 never stands inside a
card" lays out. That form already works with the current release. Once the release is taken, a
`.card__title` renders at the `h3` size in the sans instead of the `h2` size in the serif.

**Score:** 3

#### Pull Request

House style: an h2 never stands inside a card

Plugins: dkj-solutions

[PR #3180](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3180)

---

### DEPLOY: feat/3174-release-day-app-deploy · 20261019-152957Z

A store repo that also ships a Shopify app can name its folder with a new optional seam,
`Get-ShopifyAppRoot` (e.g. `extensions`). `live-preflight` then lists the release's files under it,
reports them as their own step, treats an app-only release as a note instead of "nothing to push", and
ends a green run with `shopify app deploy --path <folder>`; `prepare-release` puts the same command in
the runbook as step 2b. The command is printed for a person to run and never run (#3174).

**Score:** 3

#### What makes this deploy extra special

A BWJ store with a Shopify app beside its theme gets its app changes onto release day: answer
`Get-ShopifyAppRoot` in `scripts/repo-config.ps1`, and the preflight and the runbook print the
`shopify app deploy` the owner runs, so a merged `extensions/` change no longer waits with no route live.
Unanswered, nothing changes.

**Score:** 3

#### Pull Request

The release-day skills list a store's app changes and print the shopify app deploy for the owner

Plugins: bwj-development, dkj-subagents-shopify

[PR #3178](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3178)

---

### DEPLOY: feat/3168-hub-proxies-general-pages · 20261019-150948Z

The repo hub now serves Artifacts, Issues, Release notes and SessionStart from its own origin: it relays
each from the dkj-solutions general pages server instead of redirecting to that server's port (#3168). The
hub's pages also take the general pages' theme key, `general-pages`. A theme or width picked on any page
now holds on all of them; before, the hub and the general pages were two origins with two keys, so a choice
made on one did not exist on the other, and moving between them read as two different hubs. The General
card links the pages on the hub's own origin, and the pages' "Repo hub" crumb (`/hub`) is answered by the
hub. A theme picked on the hub before this change is not carried over once.

**Score:** 3 -- the maintainer sees one theme hold across the hub and every general page, the moment they click between them.

#### What makes this deploy extra special

The plugin's `loopback-server-lib.ps1` gains `Copy-LoopbackUpstream`, and `Format-GeneralPagesCardHtml`
gains `-SameOrigin`: a repo whose own hub is a PowerShell loopback server can relay the general pages the
same way. Nothing changes for a repo that does not.

**Score:** 1 -- nothing changes for a consumer until its own hub relays; the failure it prevents is the split theme the owner saw here.

#### Pull Request

Repo hub serves the general pages from its own origin, with one shared theme key

Plugins: dkj-solutions

[PR #3172](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3172)

---

### DEPLOY: feat/3170-asana-type-option-map · 20261019-150059Z

`report-issue` reads a new optional seam, `Get-AsanaTypeOptionMap`, that maps each kind label to the
option name a board's `Type` field actually uses -- e.g.
`@{ bug = 'Dev (Feature / Bug)'; feature = 'Dev (Feature / Bug)' }` -- before the default `Bug`,
`Feature` and `Task`. A kind the map leaves out keeps its default, and the value shape follows the
field's `resource_subtype` (#3170).

**Score:** 2

#### What makes this deploy extra special

A BWJ store whose Asana board names its `Type` options its own way gets every mirrored card typed
again, by answering `Get-AsanaTypeOptionMap` in its `scripts/repo-config.ps1`, instead of a "option
missing" note and a hand edit. Unanswered, nothing changes.

**Score:** 3

#### Pull Request

report-issue lets a consumer map the kind labels to its own Asana Type option names

Plugins: bwj-development

[PR #3173](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3173)

---

### DEPLOY: fix/3166-placeholder-lilac-default · 20261019-144946Z

With no theme chosen yet, the dev-preview placeholder page (the Repo hub a repo without a dev page of
its own gets) now opens in Lila, the same default as every other dev and general page, instead of
Petrol or Hemelsblauw depending on the OS mode (#3166).

**Score:** 2

#### What makes this deploy extra special

A consumer running the dkj-solutions dev-preview hook sees its placeholder page open in the same
default theme as its other pages. Cosmetic.

**Score:** 1

#### Pull Request

The dev-preview placeholder page falls back to lilac like every other dev page

Plugins: dkj-solutions

[PR #3171](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3171)

---

### DEPLOY: fix/3162-release-notes-lilac-default · 20261019-143532Z

With no theme chosen yet, the Release notes page served by the general pages server now opens in
Lila, the same default as the Repo hub and every other dev and general page, instead of Petrol or
Hemelsblauw depending on the OS mode (#3162).

**Score:** 2

#### What makes this deploy extra special

A consumer running the dkj-solutions general pages server sees the release-notes page open in the same
default theme as its other pages. Cosmetic.

**Score:** 1

#### Pull Request

Release notes dev page falls back to lilac like every other dev page

Plugins: dkj-solutions

[PR #3169](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3169)

---

### DEPLOY: fix/3163-hub-uses-loopback-lib · 20261019-142111Z

The repo hub server now loads the plugin's `loopback-server-lib.ps1` for reading a request, writing a
response and the Host and cross-site refusals, instead of keeping its own copy of each (#3163). #3161
had to repair the same `HEAD` defect in both copies. A fix to any of those rules now reaches the hub and
the plugin's two servers at once. The static-file 404 added after #3161 also stops sending a body to a
`HEAD`.

**Score:** 1 -- prevents a fix to a loopback rule landing in one server and not the other; #3161 nearly did.

#### What makes this deploy extra special

N/A -- the hub is this repo's own server; the plugin's lib only gains a line in its synopsis.

**Score:** N/A

#### Pull Request

Repo hub server loads the plugin's loopback-server-lib instead of its own copy

Plugins: dkj-solutions

[PR #3167](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3167)

---

### DEPLOY: fix/3161-hub-head-no-body · 20261019-140239Z

The repo hub and the plugin's general pages and placeholder servers now answer a `HEAD` the way RFC 9110
asks on every route: the same headers a `GET` would get, with the real `Content-Length`, and no body
(#3161). Before, the 403, 405, 404 and restart-503 routes sent their body to a `HEAD`, and the 200 routes
sent `Content-Length: 0`. The body is now dropped once, in the response function, instead of by each route.
Nothing visible changes: browsers do not send `HEAD` for a page load.

**Score:** 1 -- prevents a client that probes with `HEAD` from reading a body it did not ask for or a wrong size; that has not happened.

#### What makes this deploy extra special

N/A -- nothing a user of the plugin notices: the servers are local dev pages, and browsers load them with `GET`.

**Score:** N/A

#### Pull Request

Local dev servers answer HEAD with the real Content-Length and no body on every route

Plugins: dkj-solutions

[PR #3165](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3165)

---

### DEPLOY: fix/hub-static-after-restart-check · 20261019-134700Z

A hub server whose stylesheet or theme script has moved out from under it no longer drops the
connection. A missing static file now falls through to the moved-HEAD check, so a server on older code
restarts itself onto the checkout's, and where the checkout has not moved it answers a plain 404 naming
the file. A file that is there is still served without the check, so a page is never left unstyled by a
503.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Repo hub server is this repo's own development tool and ships to no consumer.

**Score:** N/A

#### Pull Request

a hub server restarts when a static file it serves has moved, instead of dropping the connection

[PR #3164](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3164)

---

