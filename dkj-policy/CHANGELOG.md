# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

### DEPLOY: fix/3695-killed-product-not-reused · 20261030-165759Z

When a session starts after the trunk has moved, the dev-preview hook restarts the repo's product
server, and it now really restarts it
([#3695](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3695)). Before, a stopped server that
took more than 5 seconds to free its port was reported `already running`, and a moment later nothing
listened at all. The replacement now starts on the same port once it is free, or on the next free port
in the range. Where there is none, the line says so instead of naming a server that is gone. The hub's
restart after a plugin update follows the same rule.

**Score:** 2 -- the product link from the session start line pointed at nothing, which the owner
notices the first time they open it.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

dev-preview: a killed outdated product server is never reported as reused

Plugins: dkj-policy

[PR #3696](https://github.com/DKJ-Solutions/dkj-marketplace/pull/3696)

---

