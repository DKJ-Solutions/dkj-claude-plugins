# CLAUDE.md — the dkj-solutions extension

**This file extends the `dkj-policy` constitution (that plugin's own `CLAUDE.md`) for the repos of
DKJ-Solutions, and it never overrides it** (Dave, issue
[#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1, 2026). A repo
with `dkj-solutions` installed imports it on the line directly below the `dkj-policy` import. Where
the two ever speak to the same question, `dkj-policy` wins.

It adds one chapter:

- **The house style** — the [`house-style`](skills/house-style/SKILL.md) skill. Every page, report,
  dashboard or Artifact a DKJ-Solutions app renders starts from that skill's stylesheet, and a repo
  adds its own domain layer on top without redefining a house token. Load the skill before any visual
  work. Where a repo's own lens names a style guide, that guide extends the house style and does not
  replace it.

**This plugin reaches DKJ-Solutions only.** BWJ-Development has its own styling, so this extension is
never enabled there.
