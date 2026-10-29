# Changelog

## [Unreleased]

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3647-cut-release-notes-subject · 20261029-143052Z

The release cut's closing output now prints the release-notes commit to run, with the version filled in:
`git commit -m "release: vX.Y.Z release notes"`, beside the `git add` and `git push` around it
([#3647](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3647)). The Stopwatch ends a release run
only on that exact subject and stays silent on any other. At v5.37.0 the notes were committed under a
different subject and the run had to be closed by hand. A guardrail test holds the printed subject to the
Stopwatch's own regex, so the two cannot drift apart.

**Score:** 2

#### What makes this deploy extra special

A maintainer cutting a release copies one printed line instead of composing the subject. The Stopwatch then
times the cut to its end without a manual repair.

**Score:** 1

#### Pull Request

cut-release prints the release-notes commit line

Plugins: dkj-policy

[PR #3651](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3651)

---

### DEPLOY: fix/card-grid-padding · 20261029-141612Z

The release-notes, stopwatch and test-gate pages put their card grid in the house `.card-grid`, so the
group under the h1 gets the same padding and surface as every other toolbox page instead of cards that
touch its edge. On release-notes the version and its date now stand `--spacing-1` apart, as a title
over its sub line does everywhere else, and the LIVE chip takes the house tag's size, so it sits inside
the card's padding without making its row taller -- which had left an empty strip at the bottom of
every other card in it.

**Score:** 2

#### What makes this deploy extra special

A user of the toolbox sees three pages line up with the rest of the hub; nothing to act on.

**Score:** 2

#### Pull Request

Put the house card-grid on the three page grids that lacked it

Plugins: dkj-policy

[PR #3650](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3650)

---

