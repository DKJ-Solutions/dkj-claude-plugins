# Changelog

## [Unreleased]

**0 / 3 patch entries** <!-- pending-tally -->

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

