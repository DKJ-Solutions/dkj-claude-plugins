# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

### DEPLOY: fix/3230-lifehub-checkout-path · 20261020-185630Z

The connector register finds the lifehub checkout under its renamed folder, `../dkj-lifehub`
([#3230](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3230)). Until now the connector check could
not find it and skipped its whole block.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

life-hub connector names the renamed checkout folder

[PR #3232](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3232)

---

