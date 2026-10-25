# Changelog

## [Unreleased]

**14 / 30 minor entries** <!-- pending-tally -->

### DEPLOY: feat/3446-stopwatch-tombstones · 20261025-124423Z

A Stopwatch run, or every run of a label, can now be hidden from every machine's `/stopwatch` pages,
whichever machine recorded it, and shown again from any machine:
`scripts/dashboard/stopwatch-hide.ps1 -RunId <id>` or `-Label "<label>"`, `-Show` to undo, `-List` to
see what is hidden (the `stopwatch-hide` skill). The entry goes into the hiding machine's own
`refs/stopwatch/<machine id>`, so one writer per ref still holds, and nothing is erased from any store.

**Score:** 3

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev server and ships to no consumer.

**Score:** N/A

#### Pull Request

Stopwatch: delete a run or a label from any machine

[PR #3451](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3451)

---

### DEPLOY: fix/release-notes-match-stopwatch · 20261025-121115Z

The release-notes page on a dev hub now reads like the Stopwatch page: the same column width and
spacing, the same heading, the list in a card with the house border and corners, and the closing note
in the same muted small print. The page the Worker publishes is unchanged.

**Score:** 2

#### What makes this deploy extra special

A repo running the dkj-policy hub sees its release-notes page in the same layout as the rest of its
hub pages, instead of the narrower serif column it had.

**Score:** 2

#### Pull Request

Release notes page styled like the Stopwatch page

Plugins: dkj-policy

[PR #3447](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3447)

---

### DEPLOY: fix/3442-ship-pr-clearance-line · 20261025-114705Z

`ship-pr` now says, seconds after it starts waiting on CI, whether the session can be cleared:
`Session can be cleared: PR #N is armed and this checkout is back on the trunk` where the merge-on-green
sweep would finish the ship if the run died, or `Session can NOT be cleared yet:` naming what holds it.
A session that backgrounds the ship waits for that line and closes out on it, rather than on a progress
note.

**Score:** 3

#### What makes this deploy extra special

Whoever ships with `ship-pr` is told plainly when they can clear the session and start the next thing,
instead of being left to guess while CI runs.

**Score:** 3

#### Pull Request

ship-pr says when the session can be cleared during the CI wait

Plugins: dkj-policy

[PR #3445](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3445)

---

### DEPLOY: fix/3271-fixture-git-wrapper-dispatch · 20261025-113358Z

A test-suite fixture git call that Git for Windows' launcher refuses with its own path as the subcommand
(`git: '...\cmd\git.exe' is not a git command`) is now retried once, for any verb, instead of turning a
suite red under the parallel gate. That refusal comes from git's dispatcher before any subcommand runs,
so repeating it is safe where repeating a failed commit otherwise is not. The retry line names the cause
and prints the argument vector element by element, so the next occurrence carries the evidence
[#3271](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3271) asked for. A genuinely mistyped
subcommand is still a failure.

**Score:** 2

#### What makes this deploy extra special

N/A -- `scripts/tests/` ships to no consumer; this changes only this repo's own gate runs.

**Score:** N/A

#### Pull Request

Retry a fixture git call once when Git's own launcher hands it its own path as the subcommand

[PR #3444](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3444)

---

### DEPLOY: fix/stopwatch-cards-slowest-first · 20261025-113356Z

The Stopwatch overview's label cards now stand from slowest to fastest, by the fastest time each card
shows, instead of by their newest run. A label with no finished run yet (one going now, or the pinned Ship
PR before its first run) follows the timed cards.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev hub page; no plugin user sees it.

**Score:** N/A

#### Pull Request

Stopwatch: the overview's cards stand slowest first

[PR #3443](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3443)

---

### DEPLOY: feat/3438-hub-banner-sync · 20261025-112350Z

The hub banner's airsquats count is now kept by the hub servers instead of each browser: every repo hub on
a machine shares one file, and a private GitHub gist (`dkj-hub-airsquats`) carries it to every other
machine, so ticking the box anywhere clears it everywhere within about half a minute. The page asks
`GET /api/airsquats` and ticks off with `POST /api/airsquats/clear`, the one POST the hub serves, and only
same-origin. The state merges without conflict, and an hour still counts only where a hub saw it begin.

**Score:** 3

#### What makes this deploy extra special

Whoever runs the hub on more than one machine, or with several repo hubs open, now sees one airsquats
count everywhere: tick it off on the laptop and the desktop's box clears too. Machines on the same `gh`
account find the shared gist with nothing configured; machines on different accounts pin it with
`DKJ_HUB_AIRSQUATS_GIST`.

**Score:** 3

#### Pull Request

Hub airsquats banner in sync across machines

Plugins: dkj-policy, dkj-solutions

[PR #3441](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3441)

---

### DEPLOY: feat/hub-card-icons · 20261025-111020Z

Every card on a hub's home page now carries an icon before its label -- Test gate, Stopwatch, Logbook, Repository and the general pages here, and the Product, Repository, general and Brandbook cards on the plugin's hub in every other repo -- as do the cards on the Repository page. The product port's root page gives its Brandbook, Connectors, Specialists and DKJ repos cards one too. The house style moves with it: a `.menu-item` row has no padding of its own and a wider gap (`--spacing-4`) between icon, label and chevron, and a `.card` is padded at `--spacing-6` instead of `--spacing-5` -- in every app that renders the house style. The icons are line drawings stroked in the text colour, like the chevron, set in the house style's existing `.menu-item__icon` slot, so the house stylesheet is unchanged.

**Score:** 2

#### What makes this deploy extra special

A consumer's hub home page gains an icon on every card once the plugin is updated; nothing else changes.

**Score:** 2

#### Pull Request

An icon on every hub card, and roomier menu items and cards in the house style

Plugins: dkj-policy, dkj-solutions

[PR #3440](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3440)

---

### DEPLOY: fix/stopwatch-label-short-title · 20261025-104944Z

On the Stopwatch's label and run pages, a label such as `hub lib comment, start to end` is named by its short
title, `hub lib comment`, as its card on the overview already was; the prompt to type still shows the whole
label. A label's URL is made of that short title too (`/stopwatch/hub-lib-comment`; two labels sharing one keep
the hash suffix that already kept clashing slugs apart). A run's page now lives under its label's,
`/stopwatch/<label>/<run>`, matching its crumbs, and an old `/stopwatch/<run>` link redirects there.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev hub page; no plugin user sees it.

**Score:** N/A

#### Pull Request

Stopwatch: a label page and its runs are titled with the short title

[PR #3437](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3437)

---

### DEPLOY: fix/3423-hub-release-notes-eyebrow · 20261025-103104Z

The hub's release-notes page now opens its masthead with the `Release notes` heading, with no product
name in small capitals above it: the site header above the page already names the repo, as on every other
hub page. The page a Cloudflare Worker serves keeps that line, because it has no header to name the
product.

**Score:** 2

#### What makes this deploy extra special

Nothing to do: the page is dressed on the way out, so the next hub session shows it.

**Score:** N/A

#### Pull Request

The hub's release-notes page drops the eyebrow under its site header

Plugins: dkj-policy

[PR #3436](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3436)

---

### DEPLOY: feat/stopwatch-ship-pr-prompt · 20261025-102005Z

The Ship PR page on the Stopwatch now carries the prompt that starts a timed ship, in a block with a copy button:
`stopwatch: Ship PR`, then one line asking to ship the branch that is checked out, so it pastes unchanged. And
every Stopwatch page now begins with an `h1` (a label's page, a run's page, and an empty overview), where several
opened with an `h2`.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev-server page; no plugin ships it.

**Score:** N/A

#### Pull Request

The Ship PR page carries the prompt to copy, with a copy button

[PR #3435](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3435)

---

### DEPLOY: fix/3431-release-notes-page-ignored · 20261025-100806Z

The release-notes page directory (`dkj-policy/releases/page/`) now ignores itself: the build writes a
`.gitignore` holding `*` into it when there is none. A repo whose hub built the page no longer finds it as
an untracked folder after every session, and a `git add -A` can no longer commit it, whether or not that
repo ever added the line to its own `.gitignore`.

**Score:** 3

#### What makes this deploy extra special

Nothing to do: a repo that already ignores the directory keeps working, and the new file is ignored by
itself. An existing `page/.gitignore` is never overwritten.

**Score:** N/A

#### Pull Request

The release-notes page directory ignores itself

Plugins: dkj-policy

[PR #3434](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3434)

---

### DEPLOY: fix/3430-card-h2-comment · 20261025-095642Z

The comment above `.card__head` in `house-style.css` no longer says an `h2` never stands inside a card, a
rule the house style retired on October 24, 2026; it now agrees with the `house-style` skill. A comment
only, so nothing renders differently, but the file's checksum in the skill moves with it.

**Score:** 1

#### What makes this deploy extra special

Nothing for an app to do: no rule or value changed.

**Score:** N/A

#### Pull Request

house-style.css comment still states the retired no-h2-in-a-card rule

Plugins: dkj-solutions

[PR #3433](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3433)

---

### DEPLOY: feat/stopwatch-ship-pr-card · 20261025-094821Z

The Stopwatch overview now carries a Ship PR card before its first run, linking a page of its own that holds the
five steps that time a ship the same way every time: a branch made ready outside the clock, a prompt whose first
line is exactly `stopwatch: Ship PR`, and the run page's split of the ship into its checks, local gates, CI wait,
merge and fold.
Runs of one label are compared with each other on that page, so it is where a slow step and a speed-up attempt
show.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev-server page; no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch overview carries a Ship PR card that says how to time a ship again and again

[PR #3432](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3432)

---

### DEPLOY: docs/hub-banner-stopwatch-comment · 20261025-093839Z

A `stopwatch test run` timestamp line at the top of `Format-RepoHubBanner`'s docstring, a marker for
timing the branch-to-fold chain end to end. Comment only; nothing the hub renders changes.

**Score:** 1

#### What makes this deploy extra special

N/A -- a code comment reaches no user of the plugins.

**Score:** N/A

#### Pull Request

Stopwatch test-run line in the hub banner docstring

Plugins: dkj-policy

[PR #3429](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3429)

---

### DEPLOY: feat/heading-h2-18px · 20261025-092551Z

`h2` in the house style is now 18px instead of 24px, so a section heading sits closer to the body text
under it. Nothing else in the scale moves.

**Score:** 2

#### What makes this deploy extra special

Nothing for an app to do: the token keeps its name, so every `h2` takes the new size with the next copy.

**Score:** N/A

#### Pull Request

House style: h2 at 18px

Plugins: dkj-solutions

[PR #3427](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3427)

---

### DEPLOY: feat/3422-close-parked-recurrences · 20261025-091440Z

An issue filed with, or given, `awaiting-recurrences` or `awaiting-recurrences-first` is now closed as not
planned automatically, with its `[RECORD]` title prefix added where missing and the label kept
([#3422](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3422)). The rule in
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md) was prose only, and #3410 stayed
open after it was filed parked. The new `close-parked-recurrences.yml` runner does it on `opened` and
`labeled`, never on `reopened`, so a recurrence can reopen and unlabel in either order. Every other label
event is skipped at the job level. `adopt-ci-floor` places the same file in a consumer as its fifth runner;
it checks nothing out and needs no secret.

**Score:** 3

#### What makes this deploy extra special

A consumer who re-runs `adopt-ci-floor -Apply` gets parked recurrence issues closed for them, instead of
the open list filling with issues that wait on their next instance.

**Score:** 2

#### Pull Request

Close parked recurrence issues as not planned automatically

Plugins: dkj-policy

[PR #3426](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3426)

---

### DEPLOY: feat/heading-scale-h3-14px · 20261025-090538Z

The house style keeps three heading levels. `h3` is now 14px, the body size, and stands apart only by its weight
and colour. `h4` and `h5` are gone along with `--text-h4` and `--text-h5`, which the gate now reports as retired.
The brand book and the connector dashboard follow suit. Large figures that borrowed `--text-h3` for their size
move to `--text-lg`. The README's new section "The heading cut of October 25, 2026" tells an app how to move over.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes the next house-style copy has to turn its `h4` and `h5` into `h3` and move off
the two retired tokens. The gate names each use that is left behind.

**Score:** 4

#### Pull Request

House style headings: h3 at 14px, h4 and h5 retired

Plugins: dkj-solutions

[PR #3425](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3425)

---

### DEPLOY: fix/product-root-card-link · 20261025-090535Z

The product port's home page (`brandbook/root.html`) wrote its four page cards as a plain `.card`, so
only the link row tinted on hover and took a click, while the hub's cards, `.card--link` since #3298,
tint and click over their whole area. That hand-written file was missed by #3298; it now carries the
same class, and `dev-pages.tests.ps1` pins it so the two ports cannot drift apart again.

**Score:** 2

#### What makes this deploy extra special

N/A: the product port is this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

the product root's cards are clickable and tint over their whole area, like the hub's

[PR #3424](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3424)

---

### DEPLOY: fix/3419-stale-install-by-content · 20261024-222029Z

dev-preview's `run npm install` note now fires only where the install really differs from the lock
([#3419](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3419)). The note added in #3404 compared
file times, and git rewrites `package-lock.json` on any commit or checkout that touches it. In this repo it fired
on an install that `npm ls` called clean. A lock newer than npm's own install record is now compared by content:
every package version it pins against `node_modules/.package-lock.json`. The note appears only where a package is
installed at another version, or not at all. Optional packages for other platforms never count.

**Score:** 2

#### What makes this deploy extra special

A consumer no longer gets a `run npm install` note on every session after a pull or checkout that rewrote the
lock without changing what it pins.

**Score:** 2

#### Pull Request

dev-preview's stale-install note compares the lock's content with the install, not its time

Plugins: dkj-policy

[PR #3421](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3421)

---

### DEPLOY: fix/3403-stopwatch-fetch-state · 20261024-220200Z

The Stopwatch overview now says when its copy of the other machines' runs was last fetched, and says so
whenever a fetch is running, not only on the first visit
([#3403](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3403)). The page renders the runs last
fetched into `refs/stopwatch-origin/*` and starts a fetch in the background, so a run another machine had just
published was missing with no sign of why. Measured: a group showed one card short of another machine's
overview. The footer now ends with `as last fetched <time>`. While a fetch runs, the page says it is checking
origin for newer runs and reloads until the fetch ends.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev-server page; no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch says when the other machines' runs were last fetched, and when a fetch is running

[PR #3420](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3420)

---

### DEPLOY: fix/3408-unfolded-entry-stacked-branch · 20261024-211441Z

The unfolded-entry check no longer reports a stacked branch's unmerged parents as changelog entries
stranded on the trunk ([#3408](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3408)). On a branch
stacked three deep with the trunk clean, `unfolded-entry-sessioncheck` printed `[ERROR]` for both parents.
Its remedy, `fold-changelog-entry.ps1 -Commit -Push`, would have put unmerged work's entries onto `main`. Off
the trunk, a document now counts only where it is also on the trunk's tree at HEAD's merge-base with it. A
leftover that came in from the trunk is still reported; a stacked parent's document is not. On the trunk,
nothing changes.

**Score:** 2

#### What makes this deploy extra special

A consumer who stacks branches no longer gets an `[ERROR]` at session start whose remedy folds unmerged
work onto their trunk.

**Score:** 2

#### Pull Request

The unfolded-entry check no longer reports a stacked branch's parent documents as trunk leftovers

Plugins: dkj-policy

[PR #3418](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3418)

---

### DEPLOY: fix/3406-refresh-clone-already-current · 20261024-205709Z

`update-plugins` no longer exits 1 when a marketplace refresh fails while the clone is already at its
origin's HEAD ([#3406](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3406)). On Windows the refresh
can fail with `EBUSY` while a session holds the clone. Measured: the run exited 1 while its own receipt read
all plugins current. A failed refresh now asks the clone's origin for its HEAD. Where that matches the clone,
the refresh prints as a `WARNING` and the run can still exit 0. A refresh that really left the clone behind
stays `FAILED`, and an `EBUSY` one says to close the other sessions and rerun.

**Score:** 2

#### What makes this deploy extra special

A consumer running `update-plugins` from inside a session on Windows gets an exit code that agrees with its
receipt, instead of a red run after an update that went through.

**Score:** 2

#### Pull Request

update-plugins counts a failed refresh as a warning when the clone is already at its remote's HEAD

Plugins: dkj-policy

[PR #3417](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3417)

---

### DEPLOY: fix/3404-product-exits-after-bind · 20261024-203430Z

The dev-preview line no longer reports a product as `(started)` when it quits right after it starts listening
([#3404](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3404)). A started product counts as started
only once it is still listening two seconds after its first answer, and otherwise reads
`the server on port N stopped right after it started listening -- see <log>`. Measured: Next.js 16.4.0 under an
agent printed `Ready`, then exited to show an upgrade nudge, while the line said `(started)`. A `Requires`
entry that is a `node_modules` folder older than the `package-lock.json` beside it now adds
`'node_modules' is older than its package-lock.json -- run npm install` to the product's clause. That was the
cause here: a pull had moved the lock to 16.4.3 while this machine's install stayed on 16.4.0.

**Score:** 3

#### What makes this deploy extra special

A consumer whose dev server dies right after it starts, or whose install fell behind a pull, is told so on
the session's first line instead of getting a `(started)` link to nothing.

**Score:** 3

#### Pull Request

dev-preview catches a product that exits right after binding, and an install older than its lock

Plugins: dkj-policy

[PR #3416](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3416)

---

### DEPLOY: feat/house-style-h2-in-card · 20261024-202517Z

The house rule that an `h2` never stands inside a card (#3175) is retired, and with it `check-house-style`'s
fourth check, `heading`. An `h2` may now title a card; the grouping form with an `h2` in a `.grid__head` above
`h3`-titled cards stays where a page groups cards.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app whose CI runs the house-style gate no longer fails on an `h2` inside a card.

**Score:** 3

#### Pull Request

Retire the house rule that an h2 never stands inside a card

Plugins: dkj-solutions

[PR #3414](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3414)

---

### DEPLOY: feat/hub-banner-above-site-header · 20261024-201638Z

The airsquats banner is now the first thing on every hub page, above the site header rather than under the breadcrumb bar (owner, October 24, 2026). It stands with no margin, border or radius, a bare strip edge to edge, flush against the header.

**Score:** 2

#### What makes this deploy extra special

Every hub page a consumer opens shows the countdown at the very top, above its own site header.

**Score:** 2

#### Pull Request

The hub banner stands above the site header

Plugins: dkj-policy, dkj-solutions

[PR #3411](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3411)

---

### DEPLOY: fix/3401-holder-other-logon-session · 20261024-200215Z

The dev-preview line now says why it can only name a port's holder by pid
([#3401](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3401)). Where the holder's command line
reads back empty, the entry reads `3000 by pid 22588 (its command line cannot be read)`, and
`(another logon session -- its command line cannot be read)` where the holder runs in another Windows logon
session of the account. Measured: the bare pid was this checkout's own product, started from another session,
and nothing in the line said where to look.

**Score:** 2

#### What makes this deploy extra special

A consumer whose dev server was started from another Windows logon session now learns that from the session
line, instead of hunting for a foreign app holding the port.

**Score:** 2

#### Pull Request

dev-preview names a holder whose command line cannot be read, and another logon session

Plugins: dkj-policy

[PR #3412](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3412)

---

### DEPLOY: feat/house-style-h1-sans · 20261024-195118Z

The house `h1` is set in the body sans at weight 700 and in its own case: the serif face and the capitals are
gone. The template masthead of the general pages follows it. `--font-serif` stays as a token for a title that
keeps that face.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes the next house-style copy shows its page titles in the sans, in ordinary case.

**Score:** 3

#### Pull Request

The house h1 in the body sans, in its own case

Plugins: dkj-policy, dkj-solutions

[PR #3413](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3413)

---

### DEPLOY: feat/stopwatch-label-pages · 20261024-194102Z

The Stopwatch overview on the dev server now opens on a Stopwatch h1 and shows one card per prompt label, three to
a row: an h2 with the label's short title, a line saying from which prompt a run starts and when it stops, and the
label's fastest time (or the live clock of its only run). Each card opens the
label's own page, `/stopwatch/<label slug>`, which holds a card per run of that label, newest first, each opening
the run's page as before. A run's page now leads back through its label in the breadcrumb. A label's slug used to
redirect to its newest run; it addresses the label page instead.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is a page of this repo's own dev server and ships to no consumer.

**Score:** N/A

#### Pull Request

A page per label on the Stopwatch, holding that label's run cards

[PR #3409](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3409)

---

### DEPLOY: feat/3405-logbook-sweep-per-issue · 20261024-185230Z

The Logbook now times a `/sweep-issues` session per issue
([#3405](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3405)). A sweep used to be one run of the
whole sweep, whose length only said how many issues the backlog held. Its pages now cut it at every `ship-pr` fold
of this checkout, the moment the trunk is clean again: each issue gets a card and a page of its own, from the
previous clean trunk to its fold, named after the issue its fold commit names (`/sweep-issues #3397`), with its own
transcript phases and work time. The time after the last fold belongs to no issue and is not shown; in a sweep
still going, the issue in progress shows as going. The store and the hooks are unchanged.

**Score:** 3

#### What makes this deploy extra special

N/A: the Logbook is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

The Logbook times a /sweep-issues run per issue, clean trunk to clean trunk

[PR #3407](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3407)

---

### DEPLOY: feat/3400-stopwatch-release-run · 20261024-182244Z

A Stopwatch run now stops only on a commit made during it, so a fast-forward that brought in others' older
commits no longer ends it. A run whose label begins with `release` (`stopwatch: Release cut`) stops only on the
`release: vX.Y.Z release notes` commit that `cut-release` step 4 prescribes. A release cut had moved HEAD at the
fast-forward and again at the release commit, minutes before it was done
([#3400](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3400)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev-server page and its hooks; no plugin ships it.

**Score:** N/A

#### Pull Request

A Stopwatch release-cut run stops when the release is done

[PR #3402](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3402)

---

