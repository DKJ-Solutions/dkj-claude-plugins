// The shared BWJ pages worker -- ONE Cloudflare Worker serving BOTH store repos.
//
// Issue #1977. It exists because the worker dkj-policy already ships cannot be shared:
// build-release-notes-page.ps1 -Worker writes the page into the bundle as a LITERAL, and
// `wrangler deploy` replaces the whole script -- so the second store's deploy erases the first
// store's page, silently, and both deploys report success.
//
// THIS WORKER CARRIES NO PAGE CONTENT AT ALL, and that is the whole of the fix. The pages live in
// KV, one key per (store, kind), written by each store's own publish step. A redeploy from either
// store re-uploads byte-identical code and cannot touch what the other store published -- which is
// what makes "both repos, the same worker" a true statement rather than a race.
//
// THE ROUTE IS THE ONLY LOCK, exactly as it is on dkj-policy's single-repo worker: /<kind>/<32 hex>,
// no login, anyone with the link can read. That is defensible here for a narrower reason than it is
// there. dkj-policy's notes are public in a public repository, so the path guards the route and not
// the content; a BWJ store repo is PRIVATE, so here the path is guarding content that is not public
// anywhere else. Publish only what is safe in the hands of whoever receives the link.
//
// EVERY MISS ANSWERS THE SAME 404. A wrong kind, a wrong token, an unknown path and a key that was
// never written are indistinguishable from outside, so nothing here can be used to enumerate which
// stores publish, which kinds exist, or which tokens are live.
//
// THE TOKEN SHAPE IS ENFORCED IN THE ROUTE, NOT IN THE LOOKUP. The path has to match 32 lowercase
// hex characters before a KV key is built from it, so no request can steer the lookup at a key of
// its own choosing -- a namespace listing, a key belonging to some other binding, a prefix sweep.
// Building the key first and validating afterwards would be the same code with that property gone.
//
// Deployed once, by hand, from either store's checkout:  npx wrangler deploy
// The bundle is emitted by publish-page.ps1 -EmitWorker, which also writes the wrangler.toml that
// binds BWJ_PAGES to the KV namespace this account holds.

const KINDS = new Set(["notes", "backlog"]);
const ROUTE = /^\/([a-z]+)\/([0-9a-f]{32})\/?$/;

const HEADERS = {
  "content-type": "text/html; charset=utf-8",
  // The page is a SNAPSHOT of documents that move, and a colleague who reloads it is asking for
  // the current one. Caching it would answer a question they did not ask.
  "cache-control": "no-store",
  // A link nobody can guess is worth nothing once a crawler has published it -- so the header and
  // the page's own meta tag both say noindex, for the same reason dkj-policy's worker does.
  "x-robots-tag": "noindex, nofollow",
};

function notFound() {
  return new Response("Not found", {
    status: 404,
    headers: { "content-type": "text/plain; charset=utf-8", "x-robots-tag": "noindex, nofollow" },
  });
}

export default {
  async fetch(request, env) {
    if (request.method !== "GET" && request.method !== "HEAD") return notFound();

    const match = ROUTE.exec(new URL(request.url).pathname);
    if (!match) return notFound();

    const [, kind, token] = match;
    if (!KINDS.has(kind)) return notFound();

    // The binding is optional at the type level and required in practice: a worker deployed with a
    // wrangler.toml that lost its kv_namespaces block would otherwise throw on every request, and a
    // 500 says something a 404 does not.
    if (!env || !env.BWJ_PAGES) return notFound();

    const html = await env.BWJ_PAGES.get(`${kind}:${token}`, { type: "text" });
    if (html === null) return notFound();

    return new Response(request.method === "HEAD" ? null : html, { headers: HEADERS });
  },
};
