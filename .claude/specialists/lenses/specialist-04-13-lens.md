---
id: 13
group: 04
---

# 04-13 · repo-lens (Cody 💻, App Developer)

> Repo-lens for the portable manual of specialist 04-13 in the `dkj-subagents-alpha` plugin. The portable
> craft stays in the plugin manual; only what is specific to this repo is here.

## Specific to this repo (claude-code-specialists)

**Cody's domain here is the brand book app, [`brandbook/`](../../../brandbook/README.md)**: the React +
TypeScript + Vite showcase of the house style. It was first work for him on October 21, 2026, when its hub
specimen and hub previews were removed ([#3274](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3274)):
the hub's form lives in the house-style README and its stylesheet-only patterns alone.

- **The app takes no house style of its own.** It reads the one copy in
  `plugins/dkj-policy/assets/house-style/`, and a change to a token, a theme or a house class is
  made there (Gwen's domain, [her lens](specialist-04-12-lens.md)), never in the app's `brand-layer.css`.
- **The app draws no hub.** The hub's form is laid down in that folder's `README.md`, "The hub", and
  its two stylesheet-only patterns; a second rendering here is the duplicate #3274 removed.
- **The gate is `npm run gate`** in `brandbook/` (eslint, CSS syntax, custom properties, colour tokens, build),
  and CI runs it as `brandbook-gate`. Run it before the hand-over: the PowerShell gate does not build the app.
- **No build of it ships.** The cut copied one into `dkj-solutions/assets/brandbook/` from #3210 until
  [#3477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3477), once no consumer hub served it, so
  this repo's product port is the only place the app is seen.
- **Every change here is a visible result**: the branch parks for the owner's look, served on this repo's product
  port under `/brandbook/`, whose dev server shows the tree as it is edited.
