// The issue dashboard worker -- ONE Cloudflare Worker that renders a repo's open GitHub issues live,
// each with a status and a pick-up order derived from blocked-by dependencies.
//
// Issue #2643. THIS WORKER CARRIES NO TOKEN, NO REPO NAME AND NO CONTENT. Everything comes from env:
//   GITHUB_TOKEN     secret -- a fine-grained PAT, one repo, Issues / Pull requests / Contents read
//   DASHBOARD_TOKEN  secret -- 32 lowercase hex, the path lock
//   GITHUB_REPO      var    -- "owner/name"
//
// THE ROUTE IS THE ONLY LOCK, as on the other dkj-policy workers: GET|HEAD /issues/<32 hex>, no login.
// The shape is checked with a regex BEFORE anything else is done with the path, and the token is then
// compared in constant time. EVERY MISS ANSWERS THE SAME 404 -- wrong method, wrong path, wrong token,
// missing DASHBOARD_TOKEN -- so nothing here can be used to probe which tokens are live.
//
// The GitHub reads are cached ~60 s at the edge under a synthetic key derived from the repo, NEVER
// from the path token. The page the browser gets is no-store. Titles and labels are written by
// whoever can open an issue, so every GitHub-derived string is escaped before it reaches the page.
//
// Deployed by hand from dkj-policy/dashboard/ (issue-dashboard.ps1 -EmitWorker writes it there).

import { deriveDashboard, STATUSES } from "./issue-dashboard-logic.js";

const ROUTE = /^\/issues\/([0-9a-f]{32})\/?$/;
const CACHE_SECONDS = 60;
const MAX_PAGES = 10;
const PAGE_SIZE = 100;
const REF_PREFIXES = ["feat", "fix", "docs"];

const BASE_HEADERS = {
  "cache-control": "no-store",
  "x-robots-tag": "noindex, nofollow",
};
const TEXT = { ...BASE_HEADERS, "content-type": "text/plain; charset=utf-8" };
const HTML = { ...BASE_HEADERS, "content-type": "text/html; charset=utf-8" };

const notFound = () => new Response("Not found", { status: 404, headers: TEXT });

// Compares over the full length of `given` whatever `expected` is, so a mismatch takes as long as a match.
function tokenMatches(given, expected) {
  if (typeof expected !== "string") return false;
  let diff = given.length ^ expected.length;
  for (let i = 0; i < given.length; i++) diff |= given.charCodeAt(i) ^ (expected.charCodeAt(i) || 0);
  return diff === 0;
}

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

// ---- GitHub reads -------------------------------------------------------------------------------

// Each connection is paged until it is exhausted or the shared page budget runs out. Every
// connection still active goes into the same request, so the first page of all five is one round trip.
function connectionFragment(key, cursor) {
  const after = cursor ? `, after: ${JSON.stringify(cursor)}` : "";
  const page = "pageInfo { hasNextPage endCursor }";
  if (key === "issues") {
    return `issues(states: OPEN, first: ${PAGE_SIZE}${after}, orderBy: {field: CREATED_AT, direction: ASC}) {
      totalCount ${page}
      nodes { number title url createdAt labels(first: 20) { totalCount nodes { name } }
        assignees(first: 10) { nodes { login } }
        blockedBy(first: 50) { totalCount nodes { number state repository { nameWithOwner } } } } }`;
  }
  if (key === "prs") {
    return `pullRequests(states: OPEN, first: ${PAGE_SIZE}${after}) {
      ${page}
      nodes { number url isDraft closingIssuesReferences(first: 20) { totalCount nodes { number repository { nameWithOwner } } } } }`;
  }
  return `${key}: refs(refPrefix: "refs/heads/${key}/", first: ${PAGE_SIZE}${after}) { ${page} nodes { name } }`;
}

async function graphql(env, query, variables) {
  const res = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.GITHUB_TOKEN}`,
      "user-agent": "dkj-policy-issue-dashboard",
      "content-type": "application/json",
    },
    body: JSON.stringify({ query, variables }),
  });
  let body = null;
  try { body = await res.json(); } catch { /* handled below */ }
  if (!res.ok || !body || body.errors) {
    const messages = body && body.errors ? body.errors.map((e) => e.message) : [`GitHub answered HTTP ${res.status}`];
    const err = new Error(messages.join("; "));
    err.messages = messages;
    throw err;
  }
  return body.data;
}

async function loadRepo(env) {
  const [owner, name] = env.GITHUB_REPO.split("/");
  const warnings = [];
  const collected = { issues: [], prs: [], branches: [] };
  const cursors = { issues: null, prs: null };
  REF_PREFIXES.forEach((p) => (cursors[p] = null));
  let active = Object.keys(cursors);
  let pages = 0;

  while (active.length) {
    if (pages >= MAX_PAGES) {
      warnings.push(`Stopped after ${MAX_PAGES} GitHub requests; the list is incomplete (${active.join(", ")} had more pages).`);
      break;
    }
    pages++;
    const query = `query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) {
      ${active.map((k) => connectionFragment(k, cursors[k])).join("\n")} } }`;
    const repo = (await graphql(env, query, { owner, name })).repository;
    if (!repo) throw Object.assign(new Error("repository not found or not readable with this token"), { messages: ["repository not found or not readable with this token"] });

    const next = [];
    for (const key of active) {
      const conn = repo[key === "prs" ? "pullRequests" : key];
      for (const node of conn.nodes) {
        if (key === "issues") collected.issues.push(flattenIssue(node, warnings));
        else if (key === "prs") collected.prs.push(flattenPr(node, env.GITHUB_REPO, warnings));
        else collected.branches.push(`${key}/${node.name}`);
      }
      if (conn.pageInfo.hasNextPage) { cursors[key] = conn.pageInfo.endCursor; next.push(key); }
    }
    active = next;
  }
  return { ...collected, warnings };
}

function flattenIssue(n, warnings) {
  if (n.labels.totalCount > n.labels.nodes.length) warnings.push(`#${n.number} has more labels than were fetched.`);
  return {
    number: n.number, title: n.title, url: n.url, createdAt: n.createdAt,
    labels: n.labels.nodes.map((l) => l.name),
    assignees: n.assignees.nodes.map((a) => a.login),
    blockedBy: n.blockedBy.nodes.map((b) => ({ number: b.number, state: b.state, repo: b.repository.nameWithOwner })),
    blockedByTruncated: n.blockedBy.totalCount > n.blockedBy.nodes.length,
  };
}

function flattenPr(n, repoName, warnings) {
  if (n.closingIssuesReferences.totalCount > n.closingIssuesReferences.nodes.length) warnings.push(`PR #${n.number} closes more issues than were fetched.`);
  return {
    number: n.number, url: n.url, isDraft: n.isDraft,
    closes: n.closingIssuesReferences.nodes
      .filter((c) => c.repository.nameWithOwner.toLowerCase() === repoName.toLowerCase())
      .map((c) => c.number),
  };
}

// The cache holds the DERIVED data, keyed on the repo alone -- the path token never reaches the key.
async function getData(env, ctx) {
  const cache = caches.default;
  const key = new Request(`https://issue-dashboard.invalid/${encodeURIComponent(env.GITHUB_REPO)}`);
  const hit = await cache.match(key);
  if (hit) return hit.json();

  const raw = await loadRepo(env);
  const derived = deriveDashboard(raw.issues, raw.prs, raw.branches, { repo: env.GITHUB_REPO });
  derived.warnings.push(...raw.warnings);
  const data = { ...derived, generatedAt: new Date().toISOString() };
  const stored = new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json", "cache-control": `max-age=${CACHE_SECONDS}` },
  });
  ctx.waitUntil(cache.put(key, stored));
  return data;
}

// ---- Rendering ----------------------------------------------------------------------------------

const CSS = `
:root{--bg:#fff;--fg:#1f2328;--muted:#656d76;--line:#d8dee4;--card:#f6f8fa;--link:#0969da;--warn-bg:#fff8c5;--warn-line:#d4a72c;
--s-review:#1a7f37;--s-progress:#0969da;--s-waiting:#9a6700;--s-blocked:#cf222e;--s-claimed:#8250df;--s-filed:#656d76}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#8d96a0;--line:#30363d;--card:#161b22;--link:#58a6ff;--warn-bg:#3a2f00;--warn-line:#9e6a03;
--s-review:#3fb950;--s-progress:#58a6ff;--s-waiting:#d29922;--s-blocked:#f85149;--s-claimed:#a371f7;--s-filed:#8d96a0}}
*{box-sizing:border-box}
body{margin:0;padding:1rem;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:64rem;margin:0 auto}
h1{font-size:1.4rem;margin:0 0 .25rem}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
.meta{color:var(--muted);font-size:.85rem;margin:0 0 1rem}
.counts{display:flex;flex-wrap:wrap;gap:.5rem;margin:0 0 1rem;padding:0;list-style:none}
.counts li{background:var(--card);border:1px solid var(--line);border-radius:.5rem;padding:.25rem .7rem}
.counts b{margin-left:.35rem}
.warn{background:var(--warn-bg);border:1px solid var(--warn-line);border-radius:.5rem;padding:.6rem 1rem;margin:0 0 1rem}
.warn ul{margin:.25rem 0 0;padding-left:1.2rem}
.row{display:grid;grid-template-columns:2.5rem 1fr;gap:.25rem .75rem;padding:.7rem 0;border-top:1px solid var(--line)}
.rank{color:var(--muted);text-align:right;font-variant-numeric:tabular-nums}
.title{font-weight:600}
.pill{display:inline-block;border:1px solid currentColor;border-radius:1rem;padding:0 .55rem;font-size:.78rem;font-weight:600;white-space:nowrap}
.detail{color:var(--muted);font-size:.85rem;margin-top:.15rem}
.detail span{margin-right:1rem;display:inline-block}
.tag{background:var(--card);border:1px solid var(--line);border-radius:.3rem;padding:0 .35rem;margin-right:.25rem;font-size:.78rem}
.flag{color:var(--s-blocked)}
.empty{color:var(--muted);padding:1rem 0}
`;

const STATUS_COLOUR = {
  "In review": "review", "In progress": "progress", Waiting: "waiting",
  Blocked: "blocked", Claimed: "claimed", Filed: "filed",
};

function renderPage(data, repoName) {
  const repoUrl = (r) => `https://github.com/${r}`;
  const issueLink = (n, r) => {
    const own = !r || r.toLowerCase() === repoName.toLowerCase();
    return `<a href="${escapeHtml(repoUrl(own ? repoName : r))}/issues/${Number(n)}">${own ? "" : escapeHtml(r)}#${Number(n)}</a>`;
  };
  const counts = STATUSES.map((s) => `<li>${s}<b>${data.rows.filter((r) => r.status === s).length}</b></li>`).join("");
  const warnings = data.warnings.length
    ? `<div class="warn"><strong>Read with care</strong><ul>${data.warnings.map((w) => `<li>${escapeHtml(w)}</li>`).join("")}</ul></div>`
    : "";

  const rows = data.rows.map((r) => {
    const detail = [];
    if (r.assignees.length) detail.push(`<span>Assigned: ${r.assignees.map(escapeHtml).join(", ")}</span>`);
    const blockers = r.blockers.filter((b) => b.state === "OPEN");
    if (blockers.length) detail.push(`<span>Blocked by: ${blockers.map((b) => issueLink(b.number, b.repo)).join(", ")}</span>`);
    if (r.blocking.length) detail.push(`<span>Unblocks: ${r.blocking.map((n) => issueLink(n, repoName)).join(", ")}</span>`);
    if (r.prs.length) detail.push(`<span>PR: ${r.prs.map((p) => `<a href="${escapeHtml(p.url)}">#${Number(p.number)}</a>${p.isDraft ? " (draft)" : ""}`).join(", ")}</span>`);
    if (r.cycle) detail.push(`<span class="flag">Circular blocker chain</span>`);
    if (r.externalBlocker) detail.push(`<span>Waits on something outside this list</span>`);
    const labels = r.labels.map((l) => `<span class="tag">${escapeHtml(l)}</span>`).join("");
    return `<div class="row"><div class="rank">${r.rank}</div><div>
      <div><a href="${escapeHtml(r.url)}">#${Number(r.number)}</a> <span class="title">${escapeHtml(r.title)}</span>
      <span class="pill" style="color:var(--s-${STATUS_COLOUR[r.status]})">${escapeHtml(r.status)}</span></div>
      ${labels ? `<div class="detail">${labels}</div>` : ""}
      ${detail.length ? `<div class="detail">${detail.join("")}</div>` : ""}</div></div>`;
  }).join("");

  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Issue dashboard — ${escapeHtml(repoName)}</title>
<style>${CSS}</style></head><body><main>
<h1>Issue dashboard — <a href="${escapeHtml(repoUrl(repoName))}">${escapeHtml(repoName)}</a></h1>
<p class="meta">Generated ${escapeHtml(data.generatedAt)} · data up to ${CACHE_SECONDS} s old · ${data.rows.length} open, in pick-up order</p>
<ul class="counts">${counts}</ul>
${warnings}
${rows || '<p class="empty">No open issues.</p>'}
</main></body></html>`;
}

function errorPage(status, title, lines) {
  const body = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="robots" content="noindex,nofollow">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title><style>${CSS}</style></head>
<body><main><h1>${escapeHtml(title)}</h1><div class="warn"><ul>${lines.map((l) => `<li>${escapeHtml(l)}</li>`).join("")}</ul></div></main></body></html>`;
  return new Response(body, { status, headers: HTML });
}

// ---- Entry --------------------------------------------------------------------------------------

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") return notFound();

    const match = ROUTE.exec(new URL(request.url).pathname);
    if (!match) return notFound();
    if (!env || !tokenMatches(match[1], env.DASHBOARD_TOKEN)) return notFound();

    // Past the lock, so saying which binding is missing leaks nothing to a stranger.
    const missing = ["GITHUB_TOKEN", "GITHUB_REPO"].filter((k) => !env[k]);
    if (missing.length) return errorPage(503, "Dashboard not configured", [`Missing binding: ${missing.join(", ")}`]);
    if (!/^[\w.-]+\/[\w.-]+$/.test(env.GITHUB_REPO)) return errorPage(503, "Dashboard not configured", ["GITHUB_REPO must look like owner/name"]);

    let data;
    try {
      data = await getData(env, ctx);
    } catch (err) {
      return errorPage(502, "GitHub could not be read", err.messages || [String(err.message || err)]);
    }
    const page = renderPage(data, env.GITHUB_REPO);
    return new Response(request.method === "HEAD" ? null : page, { headers: HTML });
  },
};
