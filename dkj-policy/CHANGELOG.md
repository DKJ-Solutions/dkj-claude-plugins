# Changelog

## [Unreleased]

**3 / 14 minor entries** <!-- pending-tally -->

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

