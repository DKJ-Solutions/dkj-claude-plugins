# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: feat/3084-brandbook-v0-1-0 · 20261017-092629Z

The `house-style` skill now fetches from the brand book's `v0.1.0` release, which brought the four
`house-style-v1`..`-v4` tags together ([#3084](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3084)).
The two files there are byte-identical to `house-style-v4`, so the checksums and both vendored copies stand.

**Score:** 1

#### What makes this deploy extra special

Nothing a DKJ-Solutions app takes changes: the bytes are the same. It prevents a failure that has not
happened yet: the brand book deleting its `house-style-v*` tags would otherwise leave every installed
copy of the skill fetching from a tag that no longer exists.

**Score:** 1

#### Pull Request

house-style skill: pin to dkj-brandbook v0.1.0

Plugins: dkj-solutions

[PR #3085](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3085)

---

