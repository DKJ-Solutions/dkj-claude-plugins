# Changelog

## [Unreleased]

**5 / 8 minor entries** <!-- pending-tally -->

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

