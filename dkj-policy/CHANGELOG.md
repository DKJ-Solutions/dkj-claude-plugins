# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

### DEPLOY: docs/2879-shopify-store-switch-research · 20261007-123507Z

A research dossier, [`research/shopify-store-switch/finding.md`](../research/shopify-store-switch/finding.md), answers [#2879](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2879): why the claude.ai Shopify connector has to be switched by hand between the two store repos, and what can make that easier. A second connector or a per-project Admin MCP is not available. Shopify CLI `store auth`/`store execute` gives a per-store channel for scripted reads, but the token lifetime has to be measured before any skill depends on it. The recommendation is a store-mismatch check that catches the wrong store at the first call ([#2880](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2880)). The research also confirmed that `guard-live-theme` does not see `shopify store execute --allow-mutations` ([#2881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2881)).

**Score:** 2

#### What makes this deploy extra special

N/A -- a research document in the source repo; no plugin ships anything new from it.

**Score:** N/A

#### Pull Request

Research: switching the claude.ai Shopify connector between store repos

[PR #2882](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2882)

---

