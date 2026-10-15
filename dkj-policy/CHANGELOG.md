# Changelog

## [Unreleased]

**0 / 3 patch entries** <!-- pending-tally -->

### DEPLOY: fix/3031-djcylow-register-no-lenses · 20261015-123321Z

The djcylow-react connector record no longer registers the 19 team-alpha lenses that the consumer
removed on 2026-09-28 ([#3031](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3031)), so
the extension check stops reporting them as missing.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: djcylow-react registers no team-alpha lenses, as the consumer carries none

[PR #3034](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3034)

---

### DEPLOY: fix/3029-thumbnail-register-dkj-solutions · 20261015-121700Z

The thumbnail-generator connector record registers the `dkj-solutions` plugin the consumer enables
([#3029](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3029)), so it now falls under the
extension and version checks.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: thumbnail-generator registers the dkj-solutions plugin

[PR #3032](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3032)

---

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

