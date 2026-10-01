# Changelog

## [Unreleased]

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2670-measure-skill-priced-copy · 20261001-094109Z

`measure-skill` no longer claims its figures are what a session in this checkout loads today when they
aren't. `claude plugin details` does not price the version recorded for this checkout in the plugin install
record (measured: it prices the newest version on the machine). So the report now reads that record and, where the two differ, says the figures are
what a session here pays after its next plugin update (#2670).

**Score:** 1

#### What makes this deploy extra special

If you run `measure-skill` in a checkout that has not yet taken the newest plugin update, it now says that
the costs shown belong to the newer version on your machine, not the version this checkout currently loads.

**Score:** 1

#### Pull Request

measure-skill names the gap between the version it priced and the version this checkout's install record pins

Plugins: dkj-policy

[PR #2675](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2675)

---

### DEPLOY: feat/sessioncheck-remote-staleness · 20261001-092720Z

A new `dkj-policy` SessionStart hook, `release-freshness-sessioncheck`, warns the user visibly when
GitHub carries a newer release of the dkj plugins than the one the session is running. It names both
versions and the `update-plugins` skill. Until now nothing did: `connector-sessioncheck` compares against
the local marketplace clone, which only moves on `claude plugin marketplace update`, and every
session-start hook printed plain text that reaches the model but never the user. The new hook compares
release tags rather than commits, so work merged between releases does not trigger it. It is silent
when the session is current, offline or unable to check. The network probe runs once per session and is
bounded at five seconds.

**Score:** 3

#### What makes this deploy extra special

A consumer who falls behind a release now sees a warning in the terminal at session start, telling them
to run `/dkj-policy:update-plugins`. Before this they had to guess. A current session costs about one
`git ls-remote` per session start and shows nothing.

**Score:** 3

#### Pull Request

release-freshness-sessioncheck: warn the user at session start when a newer dkj release is out

Plugins: dkj-policy

[PR #2674](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2674)

---

