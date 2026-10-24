# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

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

