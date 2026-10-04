# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: feat/2784-awaiting-event-label · 20261003-143652Z

New parking label `awaiting-event`, purple like the rest of the awaiting-* family, for an issue that
waits on an external event or date, such as a launch or a third party's release
([#2784](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2784)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue states the event or date, and
the label comes off once it has happened.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-event`. A sweep no longer has to hold a date-bound issue out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A fifth parking label: awaiting-event

Plugins: dkj-policy

[PR #2787](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2787)

---

### DEPLOY: docs/2783-bwj-no-documentation-label · 20261003-141409Z

In a BWJ store repo every issue is now filed as either a `feature` (something new being added) or a
`bug` (something that exists and has to change), doc findings included. There is no third kind any
more, and the `documentation` label is no longer set or created. The adoption skill (step 4) shows how
to give the open issues still carrying `documentation` their kind and take it off, and a `docs/` pull
request goes out without a label
([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

BWJ: every issue is a bug or a feature, and the documentation label goes

Plugins: bwj-development

[PR #2785](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2785)

---

