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
Since October 18, 2026 ([#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130)) the
stylesheet, the theme script, the full rules and the page patterns live in this plugin's
[`assets/house-style/`](../../../plugins/dkj-policy/dkj-solutions/assets/house-style/), and the change to
the house style is made there. The page stays a pointer to them (they were in `dkj-brandbook` from
October 13). The source repo's own Repository renders them, so a change to them is a visible result that
stops for the owner's look.

- **Keep the page a pointer.** It carries where the files are and the three rules a session needs before
  it fetches them (copy unchanged, a repo layer on top, never redefine). Token tables, themes and
  reserved class names belong in `assets/house-style/README.md`; a second copy on the page is the
  drift the move removed.
