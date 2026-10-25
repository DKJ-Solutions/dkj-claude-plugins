# brandbook

The DKJ-Solutions brand book app: the showcase of every house token, theme, class and component with its
variants and states, a theme and mode switcher and a 360px phone width. Moved here from
`DKJ-Solutions/dkj-brandbook` ([#3131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3131),
step 2 of [#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130)).

**It sits at the repo root, outside `plugins/`, so no consumer installs it.** It holds no house style
of its own: it reads the one copy in
[`plugins/dkj-policy/dkj-solutions/assets/house-style/`](../plugins/dkj-policy/dkj-solutions/assets/house-style/README.md)
where it lives (`src/main.tsx` imports the stylesheet, `vite.config.ts` inlines the theme script, and
`scripts/lint/house-path.mjs` names it for the checks). A change to the house style is made there, not here.

## Where to see it: the product port, at `/brandbook/`

**This is the one brand book, and this repo shows it on the product port alone.** The dev-preview hook starts
this app's Vite dev server at session start, beside the hub (`Get-DevPreview`'s `Product` in
`scripts/repo-config.ps1`, [#3283](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3283)), and hands
out its url: `http://localhost:<product port>/`. **The product starts at the root**: in dev, `/` is
[`root.html`](root.html), a page linking the brand book at `/brandbook/` and the Connectors, Specialists and DKJ repos pages
(`productRoot` in `vite.config.ts`; the build is the app alone). Those three are live pages the hub builds:
the dev server finds this checkout's hub by its `/whoami` (ports 4870-4879) and relays each request there, so they
show on this port and the hub no longer links them. It shows the tree as it is edited, with no build. The
hub's own PowerShell Brandbook page it replaced is gone, and its themes table and class list live here now.
**The hub neither links nor serves it** (October 22, 2026): it used to serve a build of this app at
`/brandbook/` too, so one brand book was visible on two ports.

**No other repo sees it, and the release does not ship it** ([#3477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3477)).
From [#3210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3210) the cut built this app and copied
`dist/` into the `dkj-solutions` plugin's `assets/brandbook/`, for every DKJ-Solutions repo's hub to serve at
`/brandbook/`. Once no consumer hub served it ([#3475](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3475)),
nothing read that folder, so the build left `Get-ReleaseBuilds` and the folder left the plugin.

The app is built for the base `/brandbook/` (`vite.config.ts`): the showcase is its one page, and the "Home" crumb
goes to the origin's own `/`, the product port's root page. It drew a hub specimen and previews of other repos'
hubs until #3274; the hub's form is the house-style README's, with its two stylesheet-only patterns.

## Work on it

```bash
npm ci
npm run dev       # hot reload while you work, at http://localhost:5173/brandbook/
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
