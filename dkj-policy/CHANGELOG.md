# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

