// The issue dashboard worker -- ONE Cloudflare Worker that renders the open GitHub issues of one repo,
// or of every repo of one owner, live, each with a status and a pick-up order derived from blocked-by
// dependencies.
//
// Issue #2643. THIS WORKER CARRIES NO TOKEN, NO REPO NAME AND NO CONTENT. Everything comes from env:
//   GITHUB_TOKEN     secret -- a fine-grained PAT, Issues / Pull requests / Contents / Metadata read
//   DASHBOARD_TOKEN  secret -- 32 lowercase hex, the path lock
//   GITHUB_REPO      var    -- "owner/name": repo mode, one repo
//   GITHUB_ORG       var    -- "login": org mode (#2649), every non-archived repo with issues enabled
//                             that the token can read. Set exactly one of GITHUB_REPO and GITHUB_ORG.
//
// THE ROUTE IS THE ONLY LOCK, as on the other dkj-policy workers: GET|HEAD /issues/<32 hex>, no login.
// The shape is checked with a regex BEFORE anything else is done with the path, and the token is then
// compared in constant time. EVERY MISS ANSWERS THE SAME 404 -- wrong method, wrong path, wrong token,
// missing DASHBOARD_TOKEN -- so nothing here can be used to probe which tokens are live.
//
// The GitHub reads are cached ~60 s: per isolate (a module-scoped memo), plus the edge cache where
// Cloudflare provides one (caches.default is not confirmed to act on *.workers.dev). Both are keyed on
// the repo, NEVER on the path token. The page the browser gets is no-store. Titles and labels are written by
// whoever can open an issue, so every GitHub-derived string is escaped before it reaches the page.
//
// Deployed by hand from dkj-policy/dashboard/, or dkj-policy/dashboard/org-<login>/ for an org
// dashboard (issue-dashboard.ps1 -EmitWorker writes it there).

import { deriveDashboard, parkingLabel } from "./issue-dashboard-logic.js";

const ROUTE = /^\/issues\/([0-9a-f]{32})\/?$/;
const CACHE_SECONDS = 60;
const MAX_PAGES = 10;          // repo mode: GitHub requests per refresh
const MAX_REQUESTS_ORG = 40;   // org mode: the same budget for a whole owner, under the 50-subrequest free plan
const MAX_LIST_PAGES = 5;      // org mode: at most 500 repositories are listed
const REPOS_PER_QUERY = 8;     // org mode: repositories read in one GraphQL request
const PAGE_SIZE = 100;
const LOGIN = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/;
const REF_PREFIXES = ["feat", "fix", "docs"];

const BASE_HEADERS = {
  "cache-control": "no-store",
  "x-robots-tag": "noindex, nofollow",
  // The path token is in the URL and the page links out to github.com: no referrer, no sniffing, no active content.
  "referrer-policy": "no-referrer",
  "x-content-type-options": "nosniff",
  "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
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
      nodes { number title url createdAt labels(first: 20) { totalCount nodes { name color } }
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

// `partialAliases` (org mode): GitHub answers a repository it cannot read with data.<alias> = null PLUS
// an error whose path starts at that alias. When every error is of that kind the data is returned and
// the caller warns per repo; any other error still throws.
async function graphql(env, query, variables, partialAliases = null) {
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
  if (res.ok && body && body.data && body.errors && partialAliases &&
      body.errors.every((e) => Array.isArray(e.path) && partialAliases.has(e.path[0]) && body.data[e.path[0]] === null)) {
    return body.data;
  }
  if (!res.ok || !body || body.errors) {
    const messages = body && body.errors ? body.errors.map((e) => e.message) : [`GitHub answered HTTP ${res.status}`];
    const err = new Error(messages.join("; "));
    err.messages = messages;
    throw err;
  }
  return body.data;
}

const notReadable = (what) => Object.assign(new Error(what), { messages: [what] });

// Every connection of every repo is paged until it is exhausted or the shared request budget runs out.
// One request carries up to REPOS_PER_QUERY repos, each an aliased repository() field asking only for
// the connections that repo still has pages for -- in repo mode that is one field, aliased to its own name.
async function loadRepos(env, slugs, budget, orgMode) {
  const warnings = [];
  const collected = { issues: [], prs: [], branches: [] };
  const keys = ["issues", "prs", ...REF_PREFIXES];
  const state = slugs.map((slug) => ({ slug, cursors: Object.fromEntries(keys.map((k) => [k, null])), active: [...keys] }));
  const alias = (idx) => (orgMode ? `r${idx}` : "repository");
  let requests = 0;

  for (;;) {
    const pending = state.filter((s) => s.active.length);
    if (!pending.length) break;
    if (requests >= budget) {
      const left = orgMode ? pending.map((s) => `${s.slug}: ${s.active.join(", ")}`).join("; ") : pending[0].active.join(", ");
      warnings.push(`Stopped after ${budget} GitHub requests; the list is incomplete (${left} had more pages).`);
      break;
    }
    requests++;
    const batch = pending.slice(0, REPOS_PER_QUERY);
    const fields = batch.map((s, idx) => {
      const [owner, name] = s.slug.split("/");
      return `${alias(idx)}: repository(owner: ${JSON.stringify(owner)}, name: ${JSON.stringify(name)}) {
      ${s.active.map((k) => connectionFragment(k, s.cursors[k])).join("\n")} }`;
    });
    const data = await graphql(env, `query { ${fields.join("\n")} }`, {}, orgMode ? new Set(batch.map((_, idx) => alias(idx))) : null);

    batch.forEach((s, idx) => {
      const repo = data[alias(idx)];
      if (!repo) {
        if (!orgMode) throw notReadable("repository not found or not readable with this token");
        warnings.push(`${s.slug} could not be read with this token; its issues are missing.`);
        s.active = [];
        return;
      }
      const next = [];
      for (const key of s.active) {
        const conn = repo[key === "prs" ? "pullRequests" : key];
        for (const node of conn.nodes) {
          if (key === "issues") collected.issues.push(flattenIssue(node, s.slug, orgMode, warnings));
          else if (key === "prs") collected.prs.push(flattenPr(node, s.slug, orgMode, warnings));
          else collected.branches.push(orgMode ? { repo: s.slug, name: `${key}/${node.name}` } : `${key}/${node.name}`);
        }
        if (conn.pageInfo.hasNextPage) { s.cursors[key] = conn.pageInfo.endCursor; next.push(key); }
      }
      s.active = next;
    });
  }
  return { ...collected, warnings, requests };
}

// Org mode: the owner's non-archived repositories with issues enabled, as far as the token can see them.
// repositoryOwner answers for an organization and for a user alike.
async function listOwnerRepos(env, login, warnings) {
  const slugs = [];
  let cursor = null;
  let requests = 0;
  for (;;) {
    if (requests >= MAX_LIST_PAGES) {
      warnings.push(`Stopped listing ${login}'s repositories after ${MAX_LIST_PAGES} requests; some repositories are missing.`);
      break;
    }
    requests++;
    const after = cursor ? `, after: ${JSON.stringify(cursor)}` : "";
    const data = await graphql(env, `query { repositoryOwner(login: ${JSON.stringify(login)}) {
      repositories(first: ${PAGE_SIZE}${after}, orderBy: {field: NAME, direction: ASC}) {
        pageInfo { hasNextPage endCursor } nodes { nameWithOwner isArchived hasIssuesEnabled } } } }`, {});
    const owner = data.repositoryOwner;
    if (!owner) throw notReadable("owner not found or not readable with this token");
    // For a user, GitHub's default affiliations also list repos they only collaborate on: owned ones only.
    const own = (r) => r.nameWithOwner.split("/")[0].toLowerCase() === login.toLowerCase();
    for (const r of owner.repositories.nodes) if (own(r) && !r.isArchived && r.hasIssuesEnabled) slugs.push(r.nameWithOwner);
    if (!owner.repositories.pageInfo.hasNextPage) break;
    cursor = owner.repositories.pageInfo.endCursor;
  }
  return { slugs, requests };
}

async function loadTarget(env) {
  if (!env.GITHUB_ORG) return loadRepos(env, [env.GITHUB_REPO], MAX_PAGES, false);
  const warnings = [];
  const listed = await listOwnerRepos(env, env.GITHUB_ORG, warnings);
  if (!listed.slugs.length) warnings.push(`No repository of ${env.GITHUB_ORG} with issues enabled is readable with this token.`);
  const raw = await loadRepos(env, listed.slugs, MAX_REQUESTS_ORG - listed.requests, true);
  raw.warnings.unshift(...warnings);
  return raw;
}

function flattenIssue(n, slug, orgMode, warnings) {
  const name = orgMode ? `${slug}#${n.number}` : `#${n.number}`;
  if (n.labels.totalCount > n.labels.nodes.length) warnings.push(`${name} has more labels than were fetched.`);
  return {
    number: n.number, title: n.title, url: n.url, createdAt: n.createdAt,
    ...(orgMode ? { repo: slug } : {}),
    labels: n.labels.nodes.map((l) => l.name),
    labelColors: Object.fromEntries(n.labels.nodes.map((l) => [l.name, l.color])),
    assignees: n.assignees.nodes.map((a) => a.login),
    blockedBy: n.blockedBy.nodes.map((b) => ({ number: b.number, state: b.state, repo: b.repository.nameWithOwner })),
    blockedByTruncated: n.blockedBy.totalCount > n.blockedBy.nodes.length,
  };
}

// A PR closes issues by repo and number; the logic keeps only the ones it has fetched.
function flattenPr(n, slug, orgMode, warnings) {
  const name = orgMode ? `${slug} PR #${n.number}` : `PR #${n.number}`;
  if (n.closingIssuesReferences.totalCount > n.closingIssuesReferences.nodes.length) warnings.push(`${name} closes more issues than were fetched.`);
  return {
    number: n.number, url: n.url, isDraft: n.isDraft,
    ...(orgMode ? { repo: slug } : {}),
    closes: n.closingIssuesReferences.nodes.map((c) => ({ number: c.number, repo: c.repository.nameWithOwner })),
  };
}

// What the dashboard is for: "owner/name" in repo mode, "org:<login>" in org mode.
const targetOf = (env) => (env.GITHUB_ORG ? `org:${env.GITHUB_ORG}` : env.GITHUB_REPO);

// The cache holds the DERIVED data, keyed on the target alone -- the path token never reaches the key.
// In front of it sits an in-isolate memo, because the edge cache is not confirmed to work everywhere.
let memo = null; // { target, data, expires }
export function resetMemo() { memo = null; }

async function getData(env, ctx) {
  const now = Date.now();
  const target = targetOf(env);
  if (memo && memo.target === target && memo.expires > now) return memo.data;
  const data = await getEdgeOrFresh(env, ctx, target);
  memo = { target, data, expires: now + CACHE_SECONDS * 1000 };
  return data;
}

async function getEdgeOrFresh(env, ctx, target) {
  const cache = caches.default;
  const key = new Request(`https://issue-dashboard.invalid/${encodeURIComponent(target)}`);
  const hit = await cache.match(key);
  if (hit) return hit.json();

  const raw = await loadTarget(env);
  const derived = deriveDashboard(raw.issues, raw.prs, raw.branches, env.GITHUB_ORG ? { org: env.GITHUB_ORG } : { repo: env.GITHUB_REPO });
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
--s-review:#1a7f37;--s-progress:#0969da;--s-waiting:#9a6700;--s-blocked:#cf222e;--s-claimed:#8250df;--s-filed:#656d76;--parked-bg:#ffebe9;--parked-line:#ffcecb}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#8d96a0;--line:#30363d;--card:#161b22;--link:#58a6ff;--warn-bg:#3a2f00;--warn-line:#9e6a03;
--s-review:#3fb950;--s-progress:#58a6ff;--s-waiting:#d29922;--s-blocked:#f85149;--s-claimed:#a371f7;--s-filed:#8d96a0;--parked-bg:#2d1517;--parked-line:#5a1e21}}
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
.row{display:grid;grid-template-columns:4rem 1fr;gap:.25rem .75rem;padding:.7rem .5rem;border-top:1px solid var(--line)}
.num{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
.repo{color:var(--muted)}
.title{font-weight:600}
.pill{display:inline-block;border:1px solid currentColor;border-radius:1rem;padding:0 .55rem;font-size:.78rem;font-weight:600;white-space:nowrap}
.row.parked{background:var(--parked-bg);border-top-color:var(--parked-line)}
.detail{color:var(--muted);font-size:.85rem;margin-top:.15rem}
.detail span{margin-right:1rem;display:inline-block}
.tag{display:inline-block;background:var(--card);border:1px solid var(--line);border-radius:2em;padding:0 .5rem;margin-right:.25rem;font-size:.75rem;font-weight:500;line-height:1.5}
.flag{color:var(--s-blocked)}
.empty{color:var(--muted);padding:1rem 0}
`;

// A label as GitHub draws it: its own colour as the fill, and dark or white text by perceived
// lightness. The colour comes from GitHub, so anything but six hex digits falls back to the neutral
// tag rather than reaching the style attribute.
const HEX6 = /^[0-9a-f]{6}$/i;
function labelTag(name, color) {
  if (!HEX6.test(color || "")) return `<span class="tag">${escapeHtml(name)}</span>`;
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(color.slice(i, i + 2), 16));
  const light = (r * 299 + g * 587 + b * 114) / 1000 > 150;
  return `<span class="tag" style="background:#${color};border-color:#${color};color:${light ? "#1f2328" : "#fff"}">${escapeHtml(name)}</span>`;
}

// ONE QUESTION PER ROW (Dave, September 30, 2026): may a sweep pick this issue up, or does it wait on
// something and get skipped? A skipped row is tinted red as a whole, and its tooltip names what it waits on.
// Only Filed is sweepable: every other status is somebody's already, or parked. A sweep's claim-tag
// comment is not read here, so an issue a sweep has just tagged still shows as sweepable until it is
// assigned or gets a branch.
const PARKED_BECAUSE = {
  "awaiting-more-info": "waiting on the submitter",
  "awaiting-decision": "waiting on the owner's decision",
  "awaiting-first-recurrence": "waiting on a first recurrence",
  "awaiting-more-recurrences": "record: waiting on the next instance or the root cause",
  // Former names (#2683, #2723, #2741), still read because a tracker keeps a name until renamed.
  "needs-info": "waiting on the submitter",
  "needs-decision": "waiting on the owner's decision",
  "awaiting-recurrence": "waiting on a first recurrence",
  record: "record: waiting on the next instance or the root cause",
  dossier: "record: waiting on the next instance or the root cause",
};
function sweepVerdict(r) {
  if (r.status === "Filed") return { sweepable: true, text: "Sweepable" };
  if (r.status === "In review") return { sweepable: false, text: "Skip: in review" };
  if (r.status === "In progress") return { sweepable: false, text: "Skip: in progress" };
  if (r.status === "Waiting") {
    return { sweepable: false, text: "Skip: " + (PARKED_BECAUSE[parkingLabel(r.labels)] || "parked") };
  }
  if (r.status === "Blocked") {
    const open = r.blockers.filter((b) => b.state === "OPEN").map((b) => "#" + Number(b.number));
    return { sweepable: false, text: "Skip: blocked" + (open.length ? " by " + open.join(", ") : "") };
  }
  return { sweepable: false, text: "Skip: claimed" + (r.assignees.length ? " by " + r.assignees.join(", ") : "") };
}

// NEWEST FIRST ON THE PAGE (Dave, September 30, 2026). The logic still derives the pick-up order and
// its warnings; the page lists by creation date, newest on top, ties by the higher number.
const newestFirst = (a, b) =>
  String(b.createdAt || "").localeCompare(String(a.createdAt || "")) || b.number - a.number || String(a.repo || "").localeCompare(String(b.repo || ""));

// `repoName` is the repo in repo mode; in org mode it is null and `org` names the owner.
function renderPage(data, repoName, org) {
  const repoUrl = (r) => `https://github.com/${r}`;
  const heading = org || repoName;
  // The text in front of "#<n>": nothing for this repo, the bare name for a repo of this org, else owner/name.
  const prefix = (r) => {
    if (!r) return "";
    if (repoName && r.toLowerCase() === repoName.toLowerCase()) return "";
    const [owner, name] = r.split("/");
    return org && owner.toLowerCase() === org.toLowerCase() ? name : r;
  };
  const issueLink = (n, r) =>
    `<a href="${escapeHtml(repoUrl(r || repoName))}/issues/${Number(n)}" rel="noopener noreferrer">${escapeHtml(prefix(r))}#${Number(n)}</a>`;
  const sweepable = data.rows.filter((r) => sweepVerdict(r).sweepable).length;
  const counts = `<li>Sweepable<b>${sweepable}</b></li><li>Skip<b>${data.rows.length - sweepable}</b></li>`;
  const warnings = data.warnings.length
    ? `<div class="warn"><strong>Read with care</strong><ul>${data.warnings.map((w) => `<li>${escapeHtml(w)}</li>`).join("")}</ul></div>`
    : "";

  const rows = [...data.rows].sort(newestFirst).map((r) => {
    const detail = [];
    if (r.assignees.length) detail.push(`<span>Assigned: ${r.assignees.map(escapeHtml).join(", ")}</span>`);
    const blockers = r.blockers.filter((b) => b.state === "OPEN");
    if (blockers.length) detail.push(`<span>Blocked by: ${blockers.map((b) => issueLink(b.number, b.repo)).join(", ")}</span>`);
    if (r.blocking.length) detail.push(`<span>Unblocks: ${r.blocking.map((b) => issueLink(b.number, b.repo)).join(", ")}</span>`);
    if (r.prs.length) detail.push(`<span>PR: ${r.prs.map((p) => `<a href="${escapeHtml(p.url)}" rel="noopener noreferrer">#${Number(p.number)}</a>${p.isDraft ? " (draft)" : ""}`).join(", ")}</span>`);
    if (r.cycle) detail.push(`<span class="flag">Circular blocker chain</span>`);
    if (r.externalBlocker) detail.push(`<span>Waits on something outside this list</span>`);
    const labels = r.labels.map((l) => labelTag(l, (r.labelColors || {})[l])).join("");
    // The first column is the issue number, not the pick-up position: the page's order IS the order.
    const repo = prefix(r.repo);
    const verdict = sweepVerdict(r);
    return `<div class="row${verdict.sweepable ? "" : " parked"}"${verdict.sweepable ? "" : ` title="${escapeHtml(verdict.text)}"`}><div class="num"><a href="${escapeHtml(r.url)}" rel="noopener noreferrer">#${Number(r.number)}</a></div><div>
      <div>${repo ? `<span class="repo">${escapeHtml(repo)}</span> ` : ""}<span class="title">${escapeHtml(r.title)}</span>
</div>
      ${labels ? `<div class="detail">${labels}</div>` : ""}
      ${detail.length ? `<div class="detail">${detail.join("")}</div>` : ""}</div></div>`;
  }).join("");

  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Issue dashboard — ${escapeHtml(heading)}</title>
<style>${CSS}</style></head><body><main>
<h1>Issue dashboard — <a href="${escapeHtml(repoUrl(heading))}" rel="noopener noreferrer">${escapeHtml(heading)}</a></h1>
<p class="meta">Generated ${escapeHtml(data.generatedAt)} · data up to ${CACHE_SECONDS} s old · ${data.rows.length} open, newest first</p>
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
    const missing = ["GITHUB_TOKEN"].filter((k) => !env[k]);
    if (!env.GITHUB_REPO && !env.GITHUB_ORG) missing.push("GITHUB_REPO (or GITHUB_ORG)");
    if (missing.length) return errorPage(503, "Dashboard not configured", [`Missing binding: ${missing.join(", ")}`]);
    if (env.GITHUB_REPO && env.GITHUB_ORG) return errorPage(503, "Dashboard not configured", ["Set GITHUB_REPO or GITHUB_ORG, not both"]);
    if (env.GITHUB_REPO && !/^[\w.-]+\/[\w.-]+$/.test(env.GITHUB_REPO)) return errorPage(503, "Dashboard not configured", ["GITHUB_REPO must look like owner/name"]);
    if (env.GITHUB_ORG && !LOGIN.test(env.GITHUB_ORG)) return errorPage(503, "Dashboard not configured", ["GITHUB_ORG must be a GitHub login"]);

    let data;
    try {
      data = await getData(env, ctx);
    } catch (err) {
      return errorPage(502, "GitHub could not be read", err.messages || [String(err.message || err)]);
    }
    const page = env.GITHUB_ORG ? renderPage(data, null, env.GITHUB_ORG) : renderPage(data, env.GITHUB_REPO, null);
    return new Response(request.method === "HEAD" ? null : page, { headers: HTML });
  },
};
