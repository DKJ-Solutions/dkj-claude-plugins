# Changelog

## [Unreleased]

**0 / 2 patch entries** <!-- pending-tally -->

### DEPLOY: feat/3231-hub-repo-sessions · 20261020-193428Z

The Repo hub has a **DKJ repos** page in its DKJ-Solutions card: every DKJ-Solutions repo on GitHub with its
open issues and pull requests, its checkout on this machine, and the command that opens Claude Code there
([#3231](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3231)). The new repo-local
`repo-session` skill does the same from a session: it shows a repo's checkout, branch and open issues, and
opens a session in that checkout in a window of its own, optionally with a first prompt. The work then runs under that repo's own rules, and an issue for it is filed
there.

**Score:** 1

#### What makes this deploy extra special

N/A: the hub and the skill are this repo's own, and no consumer takes them.

**Score:** N/A

#### Pull Request

Hub: look into every registered repo and open a Claude session in its checkout

Plugins: dkj-policy, dkj-solutions

[PR #3233](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3233)

---

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

