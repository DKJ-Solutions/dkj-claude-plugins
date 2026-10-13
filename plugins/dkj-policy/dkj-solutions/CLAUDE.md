# CLAUDE.md — the dkj-solutions extension

**This file extends the `dkj-policy` constitution (that plugin's own `CLAUDE.md`) for the repos of
DKJ-Solutions, and it never overrides it** (Dave, issue
[#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1, 2026). A repo
with `dkj-solutions` installed imports it on the line directly below the `dkj-policy` import. Where
the two ever speak to the same question, `dkj-policy` wins.

It adds one chapter, in two rules:

- **The house style** — the [`house-style`](skills/house-style/SKILL.md) skill, which points at the
  stylesheet, the theme script and the rules in [`dkj-brandbook`](https://github.com/DKJ-Solutions/dkj-brandbook).
  Every page, report, dashboard or Artifact a DKJ-Solutions app renders starts from that stylesheet, and
  a repo adds its own domain layer on top without redefining a house token. Load the skill before any
  visual work. Where a repo's own lens names a style guide, that guide extends the house style and does
  not replace it.

- **The house style is changed upstream, in `dkj-brandbook`, never in the repo that uses it** (Maikel,
  October 13, 2026). A repo's copy of `house-style.css` or `house-theme.js` is never edited, and a house
  token or class is never redefined in its own layer. When a turn needs the house style itself to change
  (a token value, a theme, a shared component's look), file an issue on `DKJ-Solutions/dkj-brandbook`
  naming what and why, keep working on the repo's own layer, and take the new copy once it has landed
  there. That is the inbound route applied to the brand: it needs nobody's permission, and the same filing
  bar holds. Only the repo's **own** domain layer (its own tokens, components and theme pair) is edited
  locally. **In `dkj-brandbook` itself this rule does not apply**: that repo is where the change is made.

**This plugin reaches DKJ-Solutions only.** BWJ-Development has its own styling, so this extension is
never enabled there.
