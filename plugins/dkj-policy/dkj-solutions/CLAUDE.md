# CLAUDE.md — the dkj-solutions extension

**This file extends the `dkj-policy` constitution (that plugin's own `CLAUDE.md`) for the repos of
DKJ-Solutions, and it never overrides it** (Dave, issue
[#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1, 2026). A repo
with `dkj-solutions` installed imports it on the line directly below the `dkj-policy` import. Where
the two ever speak to the same question, `dkj-policy` wins.

It adds two chapters. The first is the tracker labels: **a `feat/` pull request and a new feature issue
carry `feature`, a fix carries `bug`, and never `enhancement`**, in every DKJ-Solutions repo (#2961).
How a repo still on `enhancement` moves over is in this plugin's README.

The second is the house style, with two rules:

- **Start from it** — the [`house-style`](skills/house-style/SKILL.md) skill, which points at the
  stylesheet and theme script in this plugin's [`assets/house-style/`](assets/house-style/) and the rules
  in its [`README.md`](assets/house-style/README.md). Every page, report, dashboard or Artifact a DKJ-Solutions app renders starts from that stylesheet, and
  a repo adds its own domain layer on top without redefining a house token. Load the skill before any
  visual work. Where a repo's own lens names a style guide, that guide extends the house style and does
  not replace it.

- **Change it in this plugin, never in the repo that uses it** (Maikel, October 13, 2026, as reshaped
  by Dave in [#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130), October 18,
  2026: the house style now lives in this plugin, no longer in `dkj-brandbook`). A repo's copy of
  `house-style.css` or `house-theme.js` is never edited, and the repo's own domain layer never redefines
  a house token or class. When a turn needs the house style itself to change (a token value, a theme, a
  shared component's look), file an inbound issue (`feature-inbound` or `bug-inbound`) on
  `DKJ-Solutions/dkj-claude-plugins` naming what and why, keep working on the repo's own domain layer,
  and take the new copy once it has been released and the `house-style` skill points at it. Only the
  repo's own domain layer (its own tokens, components and theme pair) is edited locally. **In
  `dkj-claude-plugins` itself this rule does not apply**: the change is made in `assets/house-style/`.

**This plugin reaches DKJ-Solutions only.** BWJ-Development has its own styling, so this extension is
never enabled there.
