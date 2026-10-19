# Changelog

## [Unreleased]

**2 / 5 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3166-placeholder-lilac-default · 20261019-144946Z

With no theme chosen yet, the dev-preview placeholder page (the Repo hub a repo without a dev page of
its own gets) now opens in Lila, the same default as every other dev and general page, instead of
Petrol or Hemelsblauw depending on the OS mode (#3166).

**Score:** 2

#### What makes this deploy extra special

A consumer running the dkj-solutions dev-preview hook sees its placeholder page open in the same
default theme as its other pages. Cosmetic.

**Score:** 1

#### Pull Request

The dev-preview placeholder page falls back to lilac like every other dev page

Plugins: dkj-solutions

[PR #3171](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3171)

---

### DEPLOY: fix/3162-release-notes-lilac-default · 20261019-143532Z

With no theme chosen yet, the Release notes page served by the general pages server now opens in
Lila, the same default as the Repo hub and every other dev and general page, instead of Petrol or
Hemelsblauw depending on the OS mode (#3162).

**Score:** 2

#### What makes this deploy extra special

A consumer running the dkj-solutions general pages server sees the release-notes page open in the same
default theme as its other pages. Cosmetic.

**Score:** 1

#### Pull Request

Release notes dev page falls back to lilac like every other dev page

Plugins: dkj-solutions

[PR #3169](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3169)

---

### DEPLOY: fix/3163-hub-uses-loopback-lib · 20261019-142111Z

The repo hub server now loads the plugin's `loopback-server-lib.ps1` for reading a request, writing a
response and the Host and cross-site refusals, instead of keeping its own copy of each (#3163). #3161
had to repair the same `HEAD` defect in both copies. A fix to any of those rules now reaches the hub and
the plugin's two servers at once. The static-file 404 added after #3161 also stops sending a body to a
`HEAD`.

**Score:** 1 -- prevents a fix to a loopback rule landing in one server and not the other; #3161 nearly did.

#### What makes this deploy extra special

N/A -- the hub is this repo's own server; the plugin's lib only gains a line in its synopsis.

**Score:** N/A

#### Pull Request

Repo hub server loads the plugin's loopback-server-lib instead of its own copy

Plugins: dkj-solutions

[PR #3167](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3167)

---

### DEPLOY: fix/3161-hub-head-no-body · 20261019-140239Z

The repo hub and the plugin's general pages and placeholder servers now answer a `HEAD` the way RFC 9110
asks on every route: the same headers a `GET` would get, with the real `Content-Length`, and no body
(#3161). Before, the 403, 405, 404 and restart-503 routes sent their body to a `HEAD`, and the 200 routes
sent `Content-Length: 0`. The body is now dropped once, in the response function, instead of by each route.
Nothing visible changes: browsers do not send `HEAD` for a page load.

**Score:** 1 -- prevents a client that probes with `HEAD` from reading a body it did not ask for or a wrong size; that has not happened.

#### What makes this deploy extra special

N/A -- nothing a user of the plugin notices: the servers are local dev pages, and browsers load them with `GET`.

**Score:** N/A

#### Pull Request

Local dev servers answer HEAD with the real Content-Length and no body on every route

Plugins: dkj-solutions

[PR #3165](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3165)

---

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

