---
id: 12
group: 04
---

# 04-12 · repo-lens (Gwen 🎨, Designer)

> Repo-lens for the portable manual of specialist 04-12 in the `dkj-subagents-alpha` plugin. The portable
> craft stays in the plugin manual; only what is specific to this repo is here.

## Specific to this repo (claude-code-specialists)

**Gwen's domain here is the `house-style` skill page**:
[`plugins/dkj-policy/dkj-solutions/skills/house-style/SKILL.md`](../../../plugins/dkj-policy/dkj-solutions/skills/house-style/SKILL.md).
Since October 13, 2026 it is a pointer: the stylesheet, the theme script and the full rules live in
[DKJ-Solutions/dkj-brandbook](https://github.com/DKJ-Solutions/dkj-brandbook) (`house-style/`), and a
change to the house style is made there, not here. Nothing in this repo renders, so the page is all she
has here.

- **Keep the page a pointer.** It carries where the files are and the three rules a session needs before
  it fetches them (copy unchanged, a repo layer on top, never redefine). Token tables, themes and
  reserved class names belong in the brand book's `house-style/README.md`; a second copy here is the
  drift the move removed.
