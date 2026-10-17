# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: fix/3095-house-style-property-access · 20261017-221912Z

`check-house-style` no longer reads a property access inside a call's closing parens, followed by an
object literal, as a selector styling a house class: a "selector" with an unbalanced paren is skipped,
and nested functional pseudo-classes now fold fully
([#3095](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3095)).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo whose script reads a property named like a house class (`.sort`, `.card`) and
passes an object literal on the same statement no longer gets a red house-style gate it cannot act on.

**Score:** 2

#### Pull Request

check-house-style: a property access followed by an object literal is no selector

Plugins: dkj-solutions

[PR #3098](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3098)

---

