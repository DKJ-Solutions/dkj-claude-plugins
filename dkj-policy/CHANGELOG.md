# Changelog

## [Unreleased]

**16 / 29 minor entries** <!-- pending-tally -->

### DEPLOY: fix/logbook-card-three-lines · 20261026-130009Z

A run card on the Logbook and the Stopwatch pages is three lines at most: its start, its prompt label on one line ending in an ellipsis, and its time with the Logbook's work time beside it. The run's own page still shows the label whole.

**Score:** 2

#### What makes this deploy extra special

A one-rule styling change to the hub's run cards; it reaches no reader who takes the next version.

**Score:** N/A

#### Pull Request

Logbook cards: three lines at most

Plugins: dkj-policy

[PR #3519](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3519)

---

### DEPLOY: feat/3515-awaiting-release-external · 20261026-114838Z

A new parking label, `awaiting-release-external`, for an issue whose remaining step runs only once
**another** repo cuts a release
([#3515](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3515)). `awaiting-release` names
this repo's own cut and surfaces at it, which said the wrong moment for such an issue. The issue names
that repo and release, and the label comes off once the release is out and the step has run. Both pickup
routes skip it, `claim-issue <n>` warns on it, the issue dashboard shows it as waiting, and
`adopt-triage-labels` prints the `gh label create` for a tracker that lacks it. Nothing lists it at the
other repo's cut.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Add the awaiting-release-external parking label

Plugins: dkj-policy

[PR #3517](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3517)

---

### DEPLOY: fix/3512-registration-grace-json-unroll · 20261026-113137Z

When the trunk moves while its gates run, `cut-release` waits for the trunk's CI run. Under Windows
PowerShell 5.1 it no longer reads a check that has already registered as "has not registered yet". A
registered red check now refuses at the first read. Before, the cut spent all four grace reads, one
poll interval apart, printing a line that was not true.

**Score:** 1

#### What makes this deploy extra special

A consumer cutting a release sees no change in what the cut decides. The verdict was already right; only
the wait before a red check's refusal is shorter.

**Score:** N/A

#### Pull Request

cut-release's registration grace reads a readable payload as absent under PowerShell 5.1

Plugins: dkj-policy

[PR #3516](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3516)

---

### DEPLOY: feat/3506-retire-page-token · 20261026-111725Z

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

Plugins: bwj-development

[PR #3514](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3514)

---

### DEPLOY: fix/3511-golive-coclaim-json-unroll · 20261026-110710Z

`build-golive-block` no longer stops under Windows PowerShell 5.1 when the task's GID turns up in two
or more open issues. It now reads gh's search result one element per issue, so the one-task-one-issue
check runs instead of throwing on its number cast before the block is printed.

**Score:** 3

#### What makes this deploy extra special

In a store repo, `-OutFile` and `-Post` could not produce a go-live block at all when the task's GID
also turned up in other issues' text. It was measured on one with three such issues. From this release
on, the block is built and the co-claim check judges those issues as intended.

**Score:** 3

#### Pull Request

build-golive-block: unroll the co-claim JSON array under PowerShell 5.1

Plugins: bwj-development

[PR #3513](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3513)

---

### DEPLOY: feat/3493-house-style-css-gate · 20261026-105439Z

The house style has a CSS gate of its own, `house-style-css`
([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)): every change to a stylesheet in
`assets/house-style/` is parsed, and fails on a `var()` that nothing defines or a colour code outside a
token declaration in `house-style.css`. Until now those checks ran only inside the brandbook app, which
#3493 retires.

**Score:** 1

#### What makes this deploy extra special

Nothing reaches a consumer: the gate runs in this repo's CI only, and the house-style files are unchanged.

**Score:** N/A

#### Pull Request

house style: a CSS gate of its own, so retiring the brandbook app leaves it gated

Plugins: dkj-solutions

[PR #3509](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3509)

---

### DEPLOY: fix/3500-notes-pages-publish-per-release · 20261026-104322Z

`publish-page -Kind notes` now publishes the release notes as the set the builder writes: the index of
cards and one page per release, each under a KV key of its own (`notes:<token>/v<x.y.z>`), and the
shared BWJ pages worker serves those pages at `/notes/<token>/v<x.y.z>`
([#3500](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3500)). The builder's
`/release-notes/...` links are mapped onto the worker's route in the published copy. A link the
published set would not serve stops the run before anything is uploaded.

**Score:** 3

#### What makes this deploy extra special

Both BWJ stores can publish their release notes again. Until now every card on a freshly built page led
to a 404, so neither store had published this week's release. **Redeploy the shared worker once**
(`publish-page.ps1 -EmitWorker`, then `wrangler deploy`) before the first publish: a worker deployed
before this release serves the index and 404s every release page.

**Score:** 4

#### Pull Request

publish-page and the shared worker serve the per-release notes pages

Plugins: bwj-development

[PR #3510](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3510)

---

### DEPLOY: feat/3502-house-style-font-longhands · 20261026-103340Z

The house style's stylesheet no longer uses the `font` shorthand with a size/line-height pair: the four
places that did (`body`, `.badge`, `.info-button`, `.moretoggle`) now spell out `font-family`,
`font-size`, `font-weight` and `line-height`, so each value can be read on its own. The `house-style`
skill's checksum follows the new file.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

House style: write the font longhands instead of the size/line-height shorthand

Plugins: dkj-solutions

[PR #3508](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3508)

---

### DEPLOY: fix/3498-notify-live-noresolves-issues · 20261026-102423Z

`notify-live` now finds the issues a release carried, not only the ones its PRs closed through a
closing keyword. It also reads the issue a PR's head branch is named after, and every `#<n>` in the
PR body that GitHub confirms is an issue. The verdict is unchanged, so a number a PR merely mentions
shows up as a `skipped` row in the dry run and never becomes a message.

**Score:** 3

#### What makes this deploy extra special

In a store repo that answers `Get-ResolvesExemptMatchers`, every Asana-linked issue ships with
`-NoResolves` and is closed by hand, so `notify-live` could never tell any of their tasks that the work
was live. From this release on, it does.

**Score:** 4

#### Pull Request

notify-live finds the issues a -NoResolves PR carried

Plugins: bwj-development

[PR #3507](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3507)

---

### DEPLOY: feat/3494-on-hold-for-every-awaiting-label · 20261026-101354Z

The `asana-closed-message` script now tells the Asana task when an issue is closed as not planned under any
`awaiting-*` label, not only `awaiting-info-client`
([#3494](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3494)). The task is told it is on
hold and will be reopened when the work can pick up again. The message under `awaiting-info-client` is
unchanged.

**Score:** 2

#### What makes this deploy extra special

A requester whose ticket is closed while parked, for example waiting on their own sign-off, is told it is on
hold instead of hearing nothing. A store picks it up by re-adopting the `asana-closed-message` script through
`adopt-bwj-development`'s stop-and-diff.

**Score:** 3

#### Pull Request

asana-closed-message: a close as not planned under any awaiting-* label posts an on-hold message

Plugins: bwj-development

[PR #3503](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3503)

---

### DEPLOY: feat/plugin-page-side-by-side · 20261026-100313Z

A plugin's page on the hub (`/plugins/<name>`) now sets its description and its state on this machine side by
side, as two cards in one row, with its state at the far right of the title's row and the description broken
into paragraphs at each chapter, so it reads on one screen without scrolling.

**Score:** 2

#### What makes this deploy extra special

In every repo's hub, a plugin's page now fits one screen: what the plugin is on the left, whether it is up to
date here (with the command that fixes it) on the right.

**Score:** 2

#### Pull Request

hub: plugin page side by side on one screen

Plugins: dkj-policy

[PR #3504](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3504)

---

### DEPLOY: fix/3488-repo-settings-admin-only-fields · 20261026-095402Z

`check-repo-settings.ps1` now reads the repo's merge switches (`allow_squash_merge`, `allow_auto_merge`,
`allow_update_branch` and their siblings) from GraphQL when the REST repo object leaves them out. REST
leaves them out for any token without admin, which includes every CI token. In this repo's own
scheduled run two of the seven declared settings read as not-read every day. They are now compared.

**Score:** 3

#### What makes this deploy extra special

A repo that declares only a merge switch in `Get-ExpectedRepoSettings` had a scheduled
`Repo settings` run that was red by construction under `-RequireRead`
(`BWJ-Development/smartwatchbanden`). With this release it reads the switch and goes green, or red
only on a real drift.

**Score:** 3

#### Pull Request

check-repo-settings reads admin-only merge switches through GraphQL

Plugins: dkj-policy

[PR #3501](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3501)

---

### DEPLOY: fix/3492-live-message-is-a-notice · 20261026-094312Z

The message `notify-live` posts on an Asana task after a release no longer says the review can start, and no
longer asks the go-live block's question a second time
([#3492](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3492)). It says the work is live as that
version, and that the review already took place on the preview.

**Score:** 2

#### What makes this deploy extra special

A requester told on release day that their work is live is no longer asked to review it again. The review
already happened on the preview, and the closed message said that was the last moment to change something.

**Score:** 3

#### Pull Request

notify-live: the live message is a notice, not a second review request

Plugins: bwj-development

[PR #3499](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3499)

---

### DEPLOY: fix/3491-merge-on-green-checks-scope · 20261026-092801Z

The merge-on-green runner that `adopt-ci-floor` places now grants its job token `checks: read` and
`statuses: read` ([#3491](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3491)). Without them a
private repo's picker could not read the required checks, so it never merged anything and every run still
concluded success. A re-run of `adopt-ci-floor` names a runner placed earlier with `[scope]` and the line(s) to
add.

**Score:** 2

#### What makes this deploy extra special

In a private repo, a pull request armed with merge-when-green now merges itself once its checks are green, where
before it waited forever with no error. A runner already placed has to be changed by hand: add the two lines
under `permissions:`, or delete the file and re-run `adopt-ci-floor -Apply`. A re-run says which.

**Score:** 4

#### Pull Request

merge-on-green: grant the pick step checks and statuses read

Plugins: dkj-policy

[PR #3496](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3496)

---

### DEPLOY: docs/house-style-density · 20261026-091734Z

The house style now states a density rule, and Gwen's manual a "nothing unasked" rule: pages are designed to one 1400 x 600 screen at the full width, without eyebrows, sub lines, intros or extra rows the brief did not ask for.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions page a session designs now starts from one screen without scrolling and the full width, instead of a tall column with decorative extra rows the owner then has to strip out.

**Score:** 3

#### Pull Request

House style: density first -- one screen, the full width, nothing unasked

Plugins: dkj-solutions, dkj-subagents-alpha

[PR #3495](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3495)

---

### DEPLOY: feat/3474-record-suite-durations-in-plugin · 20261026-082905Z

`record-suite-durations` now ships in `dkj-policy`, with a skill page of its own
([#3474](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3474)). It writes
`scripts/tests/suite-durations.json` from CI runs, and until now only this repo could run it. The skill page
states what a repo's CI must do for it to read the runs: keep its suites in `scripts/tests`, run them through
the plugin's gate, which prints the per-suite table, and let `gh run view --log` read the log. The runner's
description is no longer hard-coded to this repo's: `-Machine` names it, and a refresh keeps the value already
in the file. `suite-durations-lib.ps1` travels with it; `measure-suites` stays here.

**Score:** 3

#### What makes this deploy extra special

A repo using this workflow can fill the hub's Test gate page, which so far showed its empty state everywhere
but here: run the `record-suite-durations` skill on two or three pull-request runs and commit the file.

**Score:** 3

#### Pull Request

record-suite-durations ships in dkj-policy, with the CI contract it reads

Plugins: dkj-policy

[PR #3490](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3490)

---

### DEPLOY: feat/3476-hub-names-its-account · 20261026-080745Z

Every hub page's banner now ends on the Windows account the hub runs under, and `/api/airsquats` names it as
`account` ([#3476](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3476)). On a machine with several
accounts logged on, localhost ports are shared between them, so the hub a browser opens can be another account's,
with its state. Until now nothing on the page said so.

**Score:** 2

#### What makes this deploy extra special

A maintainer who shares a Windows machine with other accounts can see at a glance whose hub a `localhost` tab
shows.

**Score:** 2

#### Pull Request

Hub: the banner names the Windows account the hub runs under

Plugins: dkj-policy

[PR #3489](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3489)

---

### DEPLOY: fix/3485-house-style-selector-list-all-or-nothing · 20261025-224827Z

`check-house-style` no longer reports a house class named in prose inside a script's string, such as an assert
message reading `a .card, not a list` ([#3485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3485)).
It judged each member of a comma list on its own, and `a` is an element name, so that member looked like a
selector. Whether it was reported depended on lines elsewhere in the file. A selector list now counts only when
every member of it is a selector.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo running the house-style gate stops getting a finding on an unchanged line after an edit
somewhere else in the same script.

**Score:** 1

#### Pull Request

check-house-style: a selector list is read all or nothing, so prose in a script string is no finding

Plugins: dkj-solutions

[PR #3487](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3487)

---

### DEPLOY: fix/3478-drop-general-pages-card · 20261025-223236Z

`Format-GeneralPagesCardHtml`, the hub's grouped "General" card, is removed from the `dkj-policy` hub library
([#3478](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3478)). Every hub draws its home page as one
grid of card links since #3383, and its last caller went with #3475, so only its own tests still called it.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Remove Format-GeneralPagesCardHtml, which no hub calls any more

Plugins: dkj-policy

[PR #3486](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3486)

---

### DEPLOY: feat/3482-hub-plugins-page · 20261025-222319Z

Every repo's hub gains a **Plugins** card
([#3482](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3482)). Its page lists every plugin the
repo enables as a card of its own, which opens that plugin's page: the version installed for this checkout, the one
the marketplace clone holds, and what is wrong with the command that closes it. Problems come first: a plugin behind its clone or not installed here,
an install folder gone from disk, a stale clone, a retired name. The verdicts are the `plugin-versions` skill's
own, through its new `-Json` mode, so the page and the skill never disagree.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Hub: a Plugins page listing every enabled plugin and its problems

Plugins: dkj-policy

[PR #3484](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3484)

---

### DEPLOY: fix/3477-stop-shipping-brandbook-build · 20261025-215949Z

A release no longer builds the `brandbook/` app or copies it into the `dkj-solutions` plugin
([#3477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3477)). Since #3475 no consumer hub served
that copy, so the cut paid an `npm ci` and a build for a folder nothing read. `Get-ReleaseBuilds` now names no
build, and `assets/brandbook/` is gone from the plugin.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Stop building and shipping the brand book into dkj-solutions/assets/brandbook/

Plugins: dkj-policy, dkj-solutions

[PR #3483](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3483)

---

### DEPLOY: feat/3475-consumer-hub-no-brandbook · 20261025-213612Z

No hub shows or serves the Brandbook any more, whether or not the repo enables `dkj-solutions`
([#3475](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3475)). The brand book is a product of
`dkj-claude-plugins`, and only that repo shows it, on its own product port. A consumer hub's home page loses its
Brand book card, and `/brandbook` on its general pages server is now a plain 404. The extension's
`dkj-solutions-pages-lib.ps1`, which existed only to draw that card and serve the build, is removed.

**Score:** 2

#### What makes this deploy extra special

A maintainer of a DKJ-Solutions repo no longer finds the Brandbook card on that repo's hub after the update.
The brand book stays reachable from `dkj-claude-plugins`.

**Score:** 1

#### Pull Request

Consumer hubs no longer show or serve the Brandbook

Plugins: dkj-policy, dkj-solutions

[PR #3481](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3481)

---

### DEPLOY: feat/3470-hub-pages-into-plugin · 20261025-211844Z

The Test gate, the Stopwatch and the Logbook are now pages of every repo's hub, served by the `dkj-policy`
plugin, where until now only this source repo had them
([#3470](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3470)). The plugin's `UserPromptSubmit` and
`Stop` hooks record the runs in a store per repo on each machine, and this repo's existing runs are taken over as
its own. A repo shares its Stopwatch runs with its other machines only where it sets `DKJ_STOPWATCH_SHARE=1`,
which this repo does. Both hub servers answer the timing pages through one router in the plugin, and the
`stopwatch-hide` skill ships with the plugin too.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub gains three cards: Test gate, Stopwatch and Logbook. A prompt whose first line begins with
`stopwatch:` is timed until Claude is back on the trunk, and every session that starts on a clean trunk is logged
by itself, with each run's time split into its phases on its own page. The runs stay on the machine unless the
repo opts in with `DKJ_STOPWATCH_SHARE=1`. The Test gate shows an empty state until the repo has a
`scripts/tests/suite-durations.json`; the plugin ships no writer for it yet (#3474).

**Score:** 3

#### Pull Request

Stopwatch, Logbook and Test gate move into the dkj-policy hub

Plugins: dkj-policy

[PR #3479](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3479)

---

### DEPLOY: feat/3472-sessionstart-dispatcher · 20261025-202249Z

`dkj-policy`'s ten session checks now run from one SessionStart entry, `sessioncheck-dispatch.ps1`, in one
interpreter instead of ten ([#3472](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3472)). A
`/clear` in a consumer started thirteen cold `powershell.exe` processes at once, and under load some failed
before their script ran ("Unable to start thread"), each as a harness error. The checks still run in parallel,
on a runspace pool, so a session start takes about as long as before. A check that fails or
hangs now shows up as a named line in the report. A new `*-sessioncheck.ps1` in the plugin's `hooks/` runs
without a `hooks.json` edit.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

SessionStart checks run from one dispatcher instead of ten cold interpreters

Plugins: dkj-policy, dkj-subagents-alpha

[PR #3480](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3480)

---

### DEPLOY: feat/3468-own-hub-product-card · 20261025-191149Z

This repo's own hub now opens its grid with a Product card linking the brand book's dev server, as the plugin's
hub does in every consumer ([#3468](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3468)). The url
comes from the dev-preview hook's state file and is believed only as a plain loopback url, the plugin hub's own
rule. Where the file names none, the card says the server is not running.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

The source repo's own hub links its product, as the plugin's hub does

[PR #3469](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3469)

---

### DEPLOY: feat/3462-cut-stops-own-product · 20261025-184331Z

`cut-release.ps1` now stops this checkout's own dev-preview product when it holds a release build's folder, rather
than refusing the cut ([#3462](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3462)). The product is
the one `Get-DevPreview` states (its `Product` beside an own hub, or the server itself). Only a listener on its
ports that the hook's ownership rule reads as this checkout's is stopped, as the tree of the nearest process naming
the root, and the cut names the pid and says that the next session start restarts it. A holder it does not
recognise still refuses the cut before the gates, as it did under #3353. The cut refused at both v5.30.0 and v5.31.0
until the brandbook dev server was stopped by hand.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

cut-release stops this checkout's own product dev server instead of refusing

Plugins: dkj-policy

[PR #3466](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3466)

---

### DEPLOY: feat/3463-hub-config-drift · 20261025-183409Z

In a DKJ-Solutions repo, the dev-preview SessionStart line now names three things that keep a repo from
following a hub change ([#3463](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3463)). `OwnHub = $true`
is named as a plain fact (`own hub (OwnHub): hub releases do not reach it`), because it
stays a supported opt-out. `OpenInVsCode` with no hub port (4890-4899) routed in `.vscode/settings.json`, and a
`Name` still stated in `Get-DevPreview`, are named together as `config drift`. The source repo, which runs the
hub from its own tree, is not named for its `OwnHub`.

**Score:** 3

#### What makes this deploy extra special

A maintainer of a DKJ-Solutions repo sees on the next session's first line why a hub change did not reach
that repo, or why the hub opens in the system browser, and what to delete or route.

**Score:** 2

#### Pull Request

Hub: name the config drift that keeps a DKJ repo from following a hub change

Plugins: dkj-policy

[PR #3467](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3467)

---

### DEPLOY: docs/3461-release-title-lens · 20261025-182411Z

Rendall's lens no longer tells a cut to pass `-Title "Release version X.Y.Z"`: it says the Release name
comes from the tag and `-Title` is omitted unless the release has one theme, matching the `cut-release`
skill and the cuts since 5.26.0 (#3461).

**Score:** 1 -- prevents a cut from following the lens and writing `Release version X.Y.Z` into `history.md`'s description column again.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Rendall's lens: the release name comes from the tag; -Title is omitted unless a release has one theme

[PR #3465](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3465)

---

### DEPLOY: docs/h1-matches-breadcrumb · 20261025-145714Z

The house style now states that a page's `h1` reads exactly what its current breadcrumb reads, the same
words and the same case, so the bar and the page never name one page in two ways. The home page under a site
header carries no `h1` and is the one page the rule does not reach. The rule is in the house-style README
under "Every page: the breadcrumb bar", and the `house-style` skill names it beside the breadcrumb bar.

**Score:** 2

#### What makes this deploy extra special

A repo that builds pages on the house style gets one more rule to hold its pages to: the `h1` and the
current crumb are written from one name.

**Score:** 3

#### Pull Request

A page's h1 reads the same as its current breadcrumb

Plugins: dkj-solutions

[PR #3460](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3460)

---

