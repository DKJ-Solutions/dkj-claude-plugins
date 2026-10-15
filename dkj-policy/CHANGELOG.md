# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

### DEPLOY: fix/3028-thumbnail-connector-repo · 20261015-104628Z

The connector register names thumbnail-generator's renamed repo, `DKJ-Solutions/dkj-thumbnail-generator`, and its
renamed checkout folder ([#3028](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3028)). Until now
the connector check could not find that checkout and skipped its whole block.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: thumbnail-generator names its renamed repo and checkout folder

[PR #3030](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3030)

---

