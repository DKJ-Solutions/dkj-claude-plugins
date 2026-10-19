# brandbook

The DKJ-Solutions brand book app: the Repo hub pattern, the showcase of every house component with its
variants and states, a theme and mode switcher, and a 360px phone width. Moved here from
`DKJ-Solutions/dkj-brandbook` ([#3131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3131),
step 2 of [#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130)).

**It sits at the repo root, outside `plugins/`, so no consumer installs it.** It holds no house style
of its own: it reads the one copy in
[`plugins/dkj-policy/dkj-solutions/assets/house-style/`](../plugins/dkj-policy/dkj-solutions/assets/house-style/README.md)
where it lives (`src/main.tsx` imports the stylesheet, `vite.config.ts` inlines the theme script, and
`scripts/lint/house-path.mjs` names it for the checks). A change to the house style is made there, not here.

## Run it

```bash
npm ci
npm run dev       # the Repo hub at http://localhost:5173/, the showcase at /showcase
npm run gate      # the PR gate: eslint, CSS syntax, custom properties, colour tokens, build
```

Node version: see `.nvmrc`.

## What is where

| Path | Holds |
| --- | --- |
| [`src/brand-layer.css`](src/brand-layer.css) | The brand book's own layer on top of the house style: radius, weights, control sizes, focus ring, motion and layout, and no colour. Every name starts with `--dkj-`. |
| `src/components/` | Presentational React components, styled only on house-style tokens and `src/brand-layer.css`. |
| [`src/components/sources.ts`](src/components/sources.ts) | Where each component comes from: the source repo, its components there, and the CSS it was lifted from. |
| `src/showcase/` | The overview app. |
| `scripts/lint/` | The gate's three Node checks; `npm run gate` runs them between eslint and the build. |

**Mirroring components from another repo.** Only the UI/UX design is copied: structure, layout,
spacing, type, colour, radius, states, responsive behaviour and interaction. Content, data and logic
stay behind, and placeholder text takes their place. Every component gets an entry in `sources.ts`. A
house token or class is never redefined here (extend, never override), bar the dialog tint in `dialog.css`.

## The gate

`npm run gate` is the whole gate, and the `brandbook` workflow runs the same line on every pull request
that touches `brandbook/**` or the house-style assets. It is an npm script rather than a PowerShell
wrapper on purpose: the app's tooling is Node, so it needs no `.ps1` in this repo's script layer and no
skill to invoke it.
