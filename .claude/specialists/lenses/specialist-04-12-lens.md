---
id: 12
group: 04
---

# 04-12 · repo-lens (Gwen 🎨, Designer)

> Repo-lens for the portable manual of specialist 04-12 in the `dkj-subagents-alpha` plugin. The portable
> craft stays in the plugin manual; only what is specific to this repo is here.

## Specific to this repo (claude-code-specialists)

**Gwen's domain here is the DKJ-Solutions house style**:
[`plugins/dkj-policy/dkj-solutions/skills/house-style/`](../../../plugins/dkj-policy/dkj-solutions/skills/house-style/SKILL.md),
the stylesheet `house-style.css` and the skill page that describes it. Nothing else in this repo
renders, so she has no other work here.

- **The values are the owner's, tuned by hand.** A refactor of the stylesheet (tokenizing, reordering,
  commenting) keeps every computed value exactly as it was; a value that actually changes is a design
  decision for the owner, proposed and not made.
- **Every change to it is a visible result** under
  [the safety rules](../../../plugins/dkj-policy/CLAUDE.md#never-without-the-owners-explicit-permission):
  it reaches every DKJ-Solutions app at its next plugin update, so the branch stops for the owner's look
  and stays checked out instead of merging.
- **The spacing and type scales are Figma's, not hers.** They are copied from the *Shopify Theme - LIBRARY* file's
  variable collection; she reads it there (Figma MCP, read-only) rather than inventing steps.
- **The skill page names every token and every reserved class.** A token or class added to the
  stylesheet goes into `SKILL.md`'s tables in the same branch, or a repo layer cannot know not to
  redefine it.
