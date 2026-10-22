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
  `plugins/dkj-policy/dkj-solutions/assets/house-style/`, and a change to a token, a theme or a house class is
  made there (Gwen's domain, [her lens](specialist-04-12-lens.md)), never in the app's `brand-layer.css`.
- **The app draws no hub.** The hub's form is laid down in that folder's `README.md`, "The hub", and
  its two stylesheet-only patterns; a second rendering here is the duplicate #3274 removed.
- **The gate is `npm run gate`** in `brandbook/` (eslint, CSS syntax, custom properties, colour tokens, build),
  and CI runs it as `brandbook-gate`. Run it before the hand-over: the PowerShell gate does not build the app.
- **Never hand-edit the shipped build.** `plugins/dkj-policy/dkj-solutions/assets/brandbook/` is written by
  the cut (`Get-ReleaseBuilds`, [#3210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3210)).
- **Every change here is a visible result**: the branch parks for the owner's look, served by this repo's hub
  under `/brandbook/`, which rebuilds the app from the tree on the next visit.
