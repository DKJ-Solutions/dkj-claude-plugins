# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: fix/2899-cut-release-origin-check · 20261008-071817Z

`cut-release.ps1` now fetches `origin/main` and refuses unless local `main` is exactly that, naming
the commits it is behind or ahead. It checks twice: before the gates, and again after them, before the
first write, because the gate minutes are when merges land. A refusal there leaves the tree untouched,
where before a merge during the gates left a local release commit and tag that only an owner-gated
`reset --hard` could unpick. `-SkipOriginCheck` is the escape valve, and a repo with no `origin` remote
skips the check on its own and says so.

**Score:** 3

#### What makes this deploy extra special

If you cut releases with `cut-release`, a release can no longer be built on a `main` that is behind
GitHub: the cut stops before it writes anything and tells you to `git merge --ff-only origin/main`. With
`-NoPush` the command it prints is now a single atomic push, so a rejected `main` can no longer publish
the tag on its own.

**Score:** 2

#### Pull Request

cut-release refuses a main that is not origin/main

Plugins: dkj-policy

[PR #2901](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2901)

---

