# Changelog

## [Unreleased]

**11 / 27 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3383-house-hub-card-grid · 20261024-161943Z

The house hub's form is now the one the source repo's own hub already had, in the README, the patterns and the
dkj-policy plugin's hub alike (#3383): the home page is one `.grid-3` of card links with no heading, and the
facts and Issues sit on a separate Repository page on `/repository`. The two hubs draw their cards through one
helper, `Format-HubCardLinkHtml`, and `patterns/repo-repository.html` is the new reference for that page.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub the dkj-policy plugin serves changes shape at the next update: the products and pages become
cards in one grid, and the facts move to a Repository page. A repo that built its own hub from the README
now has a reference that matches the plugin's hub it sees beside it.

**Score:** 3

#### Pull Request

The house hub is a grid of card links with a separate Repository page

Plugins: dkj-policy, dkj-solutions

[PR #3395](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3395)

---

### DEPLOY: feat/3393-ci-selection-parse-cache · 20261024-160911Z

CI now keeps the suite selection's parse cache between runs, so an asset-only pull request no longer
pays a cold parse of every script before its suites start
([#3393](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3393)). Every push to `main` warms
the cache and saves it, and shard 1 of a pull request restores it. Measured locally: 27.3s cold
against 3.3s warm, with the same selection. On CI the step took 59s.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own CI, which ships in no plugin.

**Score:** N/A

#### Pull Request

CI: keep the suite selection's parse cache between runs

[PR #3396](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3396)

---

### DEPLOY: feat/3390-hub-default-theme · 20261024-155325Z

A repo can now state the theme the plugin's hub and its general pages (Artifacts, Issues, Release notes,
SessionStart) open in, with an optional `DefaultTheme` in its `Get-DevPreview`, for example `'teal'`.
Until now they always opened in lilac, so a repo whose own product opens in another theme showed two
defaults depending on the port. A repo that states nothing keeps lilac, and a visitor's own theme choice
still wins ([#3390](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3390)). The key is
documented in [the hub's README](../plugins/dkj-policy/hub/README.md).

**Score:** 2

#### What makes this deploy extra special

A consumer repo's maintainer who runs its own themed product beside the plugin's hub can now make the
hub and its pages open in the same theme, with one line in `scripts/repo-config.ps1`.

**Score:** 2

#### Pull Request

Let a repo state the default theme of the plugin's hub and general pages

Plugins: dkj-policy

[PR #3394](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3394)

---

### DEPLOY: docs/stopwatch-css-comment-v6 · 20261024-150222Z

The first line of the brand book's showcase stylesheet now carries a fresh stopwatch test comment, timing a branch from start to fold. A CSS comment only; nothing renders differently.

**Score:** 1

#### What makes this deploy extra special

N/A -- a comment in a stylesheet reaches no user of what this repo ships.

**Score:** N/A

#### Pull Request

Stopwatch test comment on the showcase stylesheet

[PR #3391](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3391)

---

### DEPLOY: fix/3377-stopwatch-first-sync-fetching · 20261024-145203Z

The Stopwatch overview on a machine's first visit no longer says that no other machine has shared a run
while its first sync is still fetching them. Until that sync has ended it says the other machines' runs
are being fetched, and reloads every few seconds to show them
([#3377](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3377)).

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own hub page and ships in no plugin.

**Score:** N/A

#### Pull Request

Stopwatch: say the other machines' runs are being fetched while the first sync runs

[PR #3388](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3388)

---

### DEPLOY: fix/3386-claim-unmarked-branch · 20261024-144309Z

A `-Tag` claim now asks origin for a `<prefix>/<n>-*` branch before it writes its marker, and refuses
when it finds one carrying no claim marker, whoever wrote it. Until now the claim printed `[OK]` over
such a branch when its author was this account, although `-Candidates` calls that state `branch` and not
free. Measured: a sweep claimed #3379 an hour after its candidate list, the other session's branch
merged first, and the sweep's pull request was a duplicate. `-TakeOver` stays the way to resume your own
unmarked branch ([#3386](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3386)).

**Score:** 3

#### What makes this deploy extra special

A team that sweeps the same tracker from several checkouts no longer builds an issue twice when one
session pushed its branch without a claim.

**Score:** 2

#### Pull Request

claim-issue -Tag refuses a free issue with an unmarked branch on origin, whoever wrote it

Plugins: dkj-policy

[PR #3389](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3389)

---

### DEPLOY: feat/stopwatch-cards-readable · 20261024-143319Z

The `/stopwatch` overview is a bare page, with no `h1` or lead (the breadcrumb names it), and groups its cards under one `h2` per prompt label (compared case-insensitively, the label with the newest run first, with no sub line under it); the Logbook, which draws its overview with the same function, keeps its bare page and its one Measurements heading (`-Flat`). The cards on both read in three lines, with no header above them: the run's start; its prompt label as the link to the run's page, with the run's version behind it (`v3`) once the label has run more than once; and its total time with its change against the previous run of the same label beside it, as a signed percent only (`+31%` in green when faster, `-25%` in red when slower: the sign is the result's). A card sets its text in the house sizes (`--text-lg`, `-base`, `-sm`, `-xs`), the text colour or `--muted`, and the weights 300 to 800 only, with no heading: the start is the heaviest line (base, 800), the prompt label with its version the least visible (sm, regular, muted), and the time light (base, 300) with its change beside it (xs, regular). The cards stand five to a row, then two and one on a narrow screen, in grids of the page's own (`.sw-grid`) with no top margin; the groups stand in one wrapper (`.sw-groups`) whose 28px gap (`--spacing-7`) spaces them apart.

The hub's airsquats banner is now always the first block of a hub page, above the `h1` where there is one (the general page shell, the home page and the Connectors page; the release notes already had it there).

The house style's `h2` is now 24px (`--text-h2`, was 32px) at weight 700 (was 600), set in the sans (it was the serif `h1` keeps) and in the theme colour (`--primary`, was `--fg-2`), while the `h1` stands apart by its 32px serif capitals. The `.lead` under an `h1` is now body size (`--text-base`, was `--text-lg`). The site header's initials mark used `--text-h2` and now takes `--text-h1`, so it keeps its size. The breadcrumb trail is set at `--text-base` (was `--text-sm`), and under a site header its current page is in the theme colour (`--primary`, was `--fg-1`). The house style README, the brand book's type specimen and the checksum in the `house-style` skill follow the new file.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes the next house-style copy gets smaller sans `h2`s in its theme colour, a body-size lead under its `h1` and a larger breadcrumb trail with its current page in the theme colour, and every repo's hub shows its banner above the page title, without changing anything of its own.

**Score:** 3

#### Pull Request

Stopwatch cards grouped per prompt, the hub banner on top, and a smaller house h2

Plugins: dkj-policy, dkj-solutions

[PR #3387](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3387)

---

### DEPLOY: fix/3379-gate-branch-document-walk-scope · 20261024-140923Z

open-pr's local test gate no longer counts the branch's own development document as a change to any
suite's walk scope, so a branch that changes only a stylesheet runs 2 suites instead of 7 (89s down
to about 23s on the measured case). A suite that names the document itself is still selected. The dev
server's /test-gate page shows the same selection, and its CI line now drops the document as CI does.

**Score:** 2

#### What makes this deploy extra special

A consumer whose suites declare a `'*.md'` walk scope gets the same saving on every branch.

**Score:** 1

#### Pull Request

Local test gate leaves the branch document out of walk scopes

Plugins: dkj-policy

[PR #3384](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3384)

---

### DEPLOY: fix/3378-hub-lost-bind · 20261024-135858Z

The dev-preview SessionStart line no longer says a server is "not listening after 15s" when its port is
listening. Where the started server lost its bind to another process (one whose command line cannot be
read), the wait ends at once and the line names the port's holder, for the hub and for a repo's own
server alike ([#3378](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3378)).

**Score:** 2

#### What makes this deploy extra special

A user of the plugin who opens two sessions at once is told which process holds the port, instead of a
false "not listening" after a 15-second wait.

**Score:** 1

#### Pull Request

The dev-preview hook names a hub port lost to another process instead of 'not listening'

Plugins: dkj-policy

[PR #3382](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3382)

---

### DEPLOY: fix/3376-new-branch-merged-name · 20261024-134302Z

`new-branch` now refuses a branch name whose pull request has already merged, before it checks anything
out, and names the first free follow-up name (`<name>-v<N>`). Until now that branch was cut, committed and
pushed, and only `open-pr` noticed, after the work, with a hint that always said `-v2` even where `-v2`
was taken. `open-pr`'s hint now names the first free name too
([#3376](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3376)).

**Score:** 3

#### What makes this deploy extra special

A consumer re-using a branch name after its merge is stopped at `new-branch` instead of after a commit and
a push, and is told the exact name to use. The check only asks `gh` where the repo names itself and has a
hosted origin, so an offline run is unchanged.

**Score:** 2

#### Pull Request

new-branch refuses a branch name a merged PR has used up, and names the first free -vN

Plugins: dkj-policy

[PR #3381](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3381)

---

### DEPLOY: fix/hub-banner-one-row · 20261024-133354Z

The hub's airsquats banner never takes more than one row: once airsquats are due, the checkbox (`☐ 30 due`) now sits on the same line as the countdown instead of on a second line below it, and a test holds the banner to one paragraph.

**Score:** 2

#### What makes this deploy extra special

Every repo hub that runs `dkj-policy` carries this banner, so after the update its airsquats line stays one row high instead of pushing the page down a line every hour.

**Score:** 2

#### Pull Request

Hub banner always fits on one row

Plugins: dkj-policy

[PR #3380](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3380)

---

### DEPLOY: docs/stopwatch-css-comment-v5 · 20261024-125533Z

A timing run of the full workflow, branch to fold: the brand book's showcase stylesheet carries a
one-line comment stamped with the run's date and time, and nothing renders differently.

**Score:** 1

#### What makes this deploy extra special

Nothing reaches a user of the plugins: the comment sits in the brand book's source and changes no output.

**Score:** N/A

#### Pull Request

A stopwatch test-run comment at the top of showcase.css

[PR #3375](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3375)

---

### DEPLOY: fix/3371-stopwatch-run-pages-entry · 20261024-112308Z

The pending changelog entry for the hub banner (#3357) named the Stopwatch's label pages, which had
been replaced by run pages before it merged; it now says run pages. Without the fix, the next release
notes would have described pages that no longer exist.

**Score:** 1

#### What makes this deploy extra special

A wording fix in this repo's own pending changelog entry; nothing a consumer runs changes.

**Score:** N/A

#### Pull Request

Correct #3357's changelog entry: the Stopwatch's run pages, not label pages

[PR #3374](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3374)

---

### DEPLOY: fix/3370-asset-only-branch-document · 20261024-111349Z

A pull request that changes only stylesheets, images or fonts now really runs only the suites that read them on CI. The asset-only lane from #3309 had never fired, because every pull request also carries its own branch document, a Markdown file, and that one file sent every run to the whole pool. CI now leaves that one document out of the judgement, and only that one: any other changed file still runs everything. On a one-line CSS change like #3369 the suites leg drops from about seven and a half minutes over five shards to the handful of suites that touch the stylesheet.

**Score:** 2

#### What makes this deploy extra special

N/A -- this repo's own CI; nothing a plugin user takes changes.

**Score:** N/A

#### Pull Request

Let CI's asset-only suite selection see past the branch document

[PR #3373](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3373)

---

### DEPLOY: feat/3356-hub-banner-everywhere · 20261024-110301Z

The hub's airsquats banner is now on every hub page: the Stopwatch overview and its run pages keep their bare
layout (no h1 or lead) but open on the banner, and the Connectors page carries it under its intro. `-Bare` on
`Format-GeneralPageHtml` now leaves out the intro only.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server; a consumer's hub pages that pass `-Bare` (none do today) would gain the
banner too.

**Score:** N/A

#### Pull Request

The hub banner shows on every hub page, the Stopwatch and Connectors included

Plugins: dkj-policy

[PR #3357](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3357)

---

### DEPLOY: fix/3368-untimed-suite-count · 20261024-104843Z

The test gate now says how many suites `suite-durations.json` has not timed, and names them, on its opening lines. Each one is charged the largest recorded duration when the CI shards are packed, so twelve untimed suites had quietly added about 3,000 seconds of load nobody saw until a stopwatch found it weeks later (#3367). The skew now shows on the run that introduces it.

**Score:** 2

#### What makes this deploy extra special

A repo that keeps its own `suite-durations.json` sees one new yellow line in its test gate when a suite is missing from it; without that file nothing changes.

**Score:** 1

#### Pull Request

Report how many suites suite-durations.json has not timed

Plugins: dkj-policy, dkj-subagents-shopify

[PR #3372](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3372)

---

### DEPLOY: docs/stopwatch-css-comment-v4 · 20261024-102537Z

The first line of the brand book's showcase stylesheet now carries a fresh stopwatch test comment, timing a branch from start to fold. A CSS comment only; nothing renders differently.

**Score:** 1

#### What makes this deploy extra special

N/A -- a comment in a stylesheet reaches no user of what this repo ships.

**Score:** N/A

#### Pull Request

Stopwatch test comment on the showcase stylesheet

[PR #3369](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3369)

---

### DEPLOY: fix/refresh-suite-durations · 20261024-100707Z

The CI suite shards pack evenly again. Twelve suites added since October 7 had no recorded duration, so the packer charged each of them the largest one (267.7s) while most take 2 to 40 seconds -- about 3,000 seconds of phantom load that left shards 1 and 5 heavy. In the three latest PR runs shard 5 was the slowest every time, at 488 to 521 seconds. Refreshed from those runs, a simulation of the pack puts every shard at about 378 seconds against 454 for the slowest before: roughly 76 seconds off the required check, about a tenth of a small branch's run from prompt to fold.

**Score:** 3

#### What makes this deploy extra special

N/A -- CI wall-clock in this repo; nothing that ships to a plugin user changes.

**Score:** N/A

#### Pull Request

Refresh suite-durations.json so the CI shards pack evenly again

[PR #3367](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3367)

---

### DEPLOY: docs/stopwatch-css-comment-v3 · 20261024-094528Z

The first line of the brand book's showcase stylesheet now carries a fresh stopwatch test comment, timing a branch from start to fold. A CSS comment only; nothing renders differently.

**Score:** 1

#### What makes this deploy extra special

N/A -- a comment in a stylesheet reaches no user of what this repo ships.

**Score:** N/A

#### Pull Request

Stopwatch test comment on the showcase stylesheet

[PR #3366](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3366)

---

### DEPLOY: feat/3364-logbook · 20261024-092754Z

The hub has a new card, **Logbook** ([#3364](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3364)).
It times every assignment given in a clean session, with no marker. The first prompt of a new Claude Code session
starts a run when the checkout is on a clean trunk. The run stops when a turn ends with Claude back on the clean
trunk, including when nothing was merged, and never while a `ship-pr` is still waiting on CI. Each session keeps
its own run. A branch parked for a look keeps its run going. Every run gets a card and a page with its transcript
phases, built from the Stopwatch's own pages. Beside each run's time stands its work time: the time less the
minutes in which no session was busy, so waiting on the owner's look does not hide the work. The runs stay on
this machine and are not shared.

**Score:** 3

#### What makes this deploy extra special

N/A: the Logbook is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

A Logbook card on the hub that times every assignment of a clean session, first prompt to back on the trunk

[PR #3365](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3365)

---

### DEPLOY: fix/3350-stopwatch-uncovered-run-cache · 20261023-170553Z

The Stopwatch no longer files a run as 100% "Waiting on you" when the transcripts that covered it are gone
([#3350](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3350)). It used to cache a finished
run's phases as soon as any transcript was read, so an old run whose transcripts had been pruned was
computed from nothing and kept that way. Now a run is read and cached only when a transcript spans its
start. A run with no such transcript shows "No phases read for this run yet", and an entry already cached
with no session is checked again and dropped when nothing covers it.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev page, and no consumer runs it.

**Score:** N/A

#### Pull Request

Stopwatch: a run no transcript covers is no longer cached as all waiting

[PR #3352](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3352)

---

### DEPLOY: fix/stopwatch-one-card-per-run · 20261023-165610Z

The Stopwatch overview now gives every run its own card, also when runs share a label. Each card is named by the
run's start and leads to that run's page. Before this, runs with the same label were merged into one card.

**Score:** 3

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch gives every run a card and a page of its own, also when two runs share a label

Plugins: dkj-policy

[PR #3363](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3363)

---

### DEPLOY: fix/3353-release-build-held-files · 20261023-155717Z

`cut-release.ps1` now refuses a cut **before its gates** when a running process has loaded an executable or
native module inside a release build's folder, which is what a dev server running from `brandbook/` does.
The build's `npm ci` cannot replace such a file, and until now the cut only found that out after the whole
~11-minute gate ([#3353](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3353)). The refusal names
the file and the folder. The probe is a write-open on `*.exe`, `*.dll` and `*.node` rather than a process
scan, because a process's image path can come back in 8.3 form and a `.node` module is loaded into
`node.exe`, which lives elsewhere.

**Score:** 3

#### What makes this deploy extra special

N/A: a consumer names no release build by default, so its cut is unchanged.

**Score:** N/A

#### Pull Request

cut-release: refuse before the gates when a running process holds a release build's files

Plugins: dkj-policy

[PR #3360](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3360)

---

### DEPLOY: fix/3324-general-pages-probe · 20261023-154805Z

The ownhub routing assert in `dev-preview-sessionstart.tests.ps1` now probes the general pages with
`/artifacts` rather than `/issues`, so it no longer runs git and gh inside the fixture server's
single-threaded loop. That probe went unanswered for 30 s on loaded CI shards seven times in one day, which
blocked every PR, while answering locally in 0 s
([#3324](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3324)). The cause is not established.
On a miss the assert now also reports what `/whoami` answers, which tells a held loop from a dead server.

**Score:** 3

#### What makes this deploy extra special

N/A: a test of this repo's own suite, which no consumer runs.

**Score:** N/A

#### Pull Request

dev-preview-sessionstart: probe the general pages with /artifacts, which spawns nothing

[PR #3362](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3362)

---

### DEPLOY: docs/stopwatch-css-comment-v2 · 20261023-153701Z

A timing run of the full workflow, branch to fold: the stopwatch test-run comment at the top of the brand
book's showcase stylesheet carries this run's date and time, and nothing renders differently.

**Score:** 1

#### What makes this deploy extra special

N/A: a comment in this repo's own brand book source reaches no user of what the plugins ship.

**Score:** N/A

#### Pull Request

A stopwatch test-run comment at the top of showcase.css

[PR #3361](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3361)

---

### DEPLOY: fix/3355-push-preview-mangled-path · 20261023-151437Z

`push-preview` now refuses a `-Path` that Git Bash (MSYS) rewrote into a Windows path, such as
`C:/Program Files/Git/products/x`, before anything is pushed, and names `MSYS_NO_PATHCONV=1` as the
remedy. Before this, the push succeeded and the printed preview URL silently 404'd.

**Score:** 2

#### What makes this deploy extra special

A Shopify consumer who runs `push-preview -Path ...` from Git Bash gets a clear refusal instead of
a broken link in the handover. Nothing to configure.

**Score:** 2

#### Pull Request

push-preview refuses a Git-Bash-mangled -Path

Plugins: dkj-subagents-shopify

[PR #3358](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3358)

---

### DEPLOY: feat/ship-pr-early-forward-lap · 20261023-145306Z

When the trunk gains a commit while a PR's CI is still running, `ship-pr` now brings the branch up to
date at once and waits for the fresh run, instead of first sitting out a run whose certificate step 3b
was always going to refuse. The gate is unchanged: the same staleness predicate, the same fold discount
and the same `-MaxForwardLaps` budget, which the early forward shares. Anything the early phase cannot
read hands over to the existing wait, so its worst case is the old behaviour. On PR #3348 this would
have saved about 8 of 19 minutes.

**Score:** 3

#### What makes this deploy extra special

A consumer running `ship-pr` on a busy trunk gets its pull request merged one CI run sooner whenever
another merge lands during its CI wait. Nothing to configure, and `-MaxForwardLaps 0` still switches
every lap off.

**Score:** 3

#### Pull Request

ship-pr laps forward as soon as the trunk moves during the CI wait, instead of after the stale run finishes

Plugins: dkj-policy

[PR #3354](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3354)

---

