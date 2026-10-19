# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

### DEPLOY: fix/hub-static-after-restart-check · 20261019-134700Z

A hub server whose stylesheet or theme script has moved out from under it no longer drops the
connection. A missing static file now falls through to the moved-HEAD check, so a server on older code
restarts itself onto the checkout's, and where the checkout has not moved it answers a plain 404 naming
the file. A file that is there is still served without the check, so a page is never left unstyled by a
503.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Repo hub server is this repo's own development tool and ships to no consumer.

**Score:** N/A

#### Pull Request

a hub server restarts when a static file it serves has moved, instead of dropping the connection

[PR #3164](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3164)

---

