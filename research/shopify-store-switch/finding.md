# Switching the claude.ai Shopify connector between stores â€” finding

> Research for [#2879](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2879), October 7,
> 2026. Researched by Rebecca #07, red-teamed by Marlowe #29, written up by Tessa #16. The inbound
> report came from the `xoxowildhearts` consumer, which works beside `smartwatchbanden`, a second store
> repo.

## The problem

The claude.ai Shopify connector is bound to **one store per account**. A session in one store repo
therefore answers for whichever store the last session switched to. `switch-shop` revokes the current
store's token, and the next call fails with *"run /mcp to re-authenticate"*. Only a person can finish
that. Nothing tells a session which store its checkout expects.

*Measured by the consumer, not re-verified here:* the one-store binding and the revocation on
`switch-shop`.

## What was found

### Two connectors, or a per-project MCP server: not available

- **Documented** ([Claude Code MCP docs](https://code.claude.com/docs/en/mcp)): claude.ai connectors
  load from the signed-in account. A local, project or user server with the same endpoint URL hides
  the connector. `/mcp` can disable a connector per project, but that is stored in `~/.claude.json`,
  so it is per machine and never in the repo.
- **Inferred:** nothing documents a per-store instance of the claude.ai connector, because the binding
  lives in the account-wide server session.
- **Shopify's own MCP servers do not fill the gap.**
  - [Dev MCP](https://shopify.dev/docs/apps/build/devmcp) is local and serves docs and schema only.
  - [Storefront MCP](https://shopify.dev/apps/build/storefront-mcp/servers/storefront) is per store,
    but it is unauthenticated and storefront-only.
  - No official per-store Admin MCP with its own auth was found. A third-party server holding a store
    token would put a standing write credential in front of every session, through unvetted code.

### Admin API without the connector: Shopify CLI `store auth` / `store execute`

- **Verified** ([`shopify store`](https://shopify.dev/docs/api/shopify-cli/store)):
  - `shopify store auth --store <x>.myshopify.com --scopes <list>` stores an online access token per
    store. It is re-run when that token is missing or expires, or lacks a scope.
  - `shopify store execute --store <x> --query â€¦` runs Admin GraphQL with that auth. Mutations stay off
    unless `--allow-mutations` is passed.
  - Auth is keyed by `--store`, so two stores can, in principle, hold tokens side by side.
- **Verified** ([Shopify announcement](https://community.shopify.dev/t/starting-january-1-2026-you-will-not-be-able-to-create-new-legacy-custom-apps-this-will-not-impact-any-existing-apps/26798)):
  new legacy custom apps cannot be created since January 1, 2026. A static store token in the style of
  an `ASANA_PAT` is therefore closed for new stores. Its replacement, Dev Dashboard client
  credentials, needs a secret plus code that mints tokens.
- **Unverified, and gating:**
  - the token lifetime. Online tokens are usually short-lived, and if it is about 24 hours, the owner
    re-auths in a browser every day, which is arguably worse than today;
  - whether two stores authenticated side by side really survive each other;
  - which app backs `store auth`, and who approves it;
  - which staff permissions it needs, and the minimum CLI version.

### Seams already in this tree

- `Get-ShopifyThemeEstateStore`, then `Get-ShopifyStoreDomain`, is the resolution order `archive-theme`
  and `push-preview` already use. A new check must not require `Get-ShopifyStoreDomain`, because
  answering it also unlocks `sync-main`'s PR path, and some consumers leave it unanswered on purpose
  (see the `theme-lifecycle` skill).
- `Get-ShopifyRepoHasNoStore` declares a repo with no store, and such a repo stays silent.
- A SessionStart hook is a process, not a model turn, so it **cannot** ask the connector which store it
  is bound to. It can only say which store the repo expects. The comparison with `get-shop-info` has to
  be a step the model runs.

### Safety: a confirmed gap in the live-theme guard

`guard-live-theme.ps1` matches only `shopify theme publish`, `shopify theme delete` and
`shopify theme push`. Nothing matches `shopify store execute --allow-mutations`, so an Admin GraphQL
theme mutation (`themeFilesUpsert`, `themePublish`) passes it. Connector writes are out of the guard's
scope by its own header. That gap exists today, whether or not the CLI route is adopted.

## Recommendation

1. **Primary: a store-mismatch check for the connector** ([#2880](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2880)).
   - The expected store comes from the seams above.
   - The session check names it, and says when the seam is unanswered, as an `[ERROR]`-only line that
     exits 0 and stays silent in a no-store repo.
   - A skill step calls `get-shop-info`, compares the answer with the expected store, and on a mismatch
     says *"run `/mcp`, then `switch-shop <store>`"*.
   - It never calls `switch-shop` itself, because that revokes the other store's token.

   This does not remove the switch. It moves the failure from mid-task to the first call, with the
   exact remedy, and that is the cheapest change that addresses the complaint itself.
2. **Optional, after one measurement: the CLI route, read-only.** Scripted Admin reads can go through
   `shopify store execute` and need no connector switch. Before any skill depends on it, measure the
   token lifetime and the side-by-side survival on one store. Keep it read-only: no `--allow-mutations`
   and read scopes only.
3. **Separately: close the guard gap** ([#2881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2881)), by refusing `shopify store execute --allow-mutations` against
   theme data.

**What this does not solve:** while the connector stays one store per account, chat sessions in two
store repos still need a manual `/mcp` re-auth whenever they alternate. Only Shopify or Anthropic can
change that.
