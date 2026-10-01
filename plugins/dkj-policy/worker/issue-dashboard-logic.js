// The issue dashboard's logic -- a PURE ES module: no I/O, no Workers globals, no dependencies.
//
// Issue #2643. It turns three plain-JSON reads (open issues, open PRs, branch names) into the rows
// the dashboard shows: a status per issue and a pick-up order derived from blocked-by dependencies.
// It is kept apart from the worker so it runs under plain `node` against fixtures.
//
// ONE REPO OR A WHOLE OWNER (issue #2649). In repo mode every item belongs to options.repo. In org mode
// (options.org set) every item carries its own `repo`, and an issue is identified by repo AND number,
// so a blocker in another repo of the same org is an ordinary edge rather than an external sink.
//
// EXPECTED INPUT (the shape of the GraphQL nodes, flattened by the worker):
//   issue    { number, title, url, createdAt, labels:[name], labelColors?:{name:"rrggbb"}, assignees:[login],
//              blockedBy:[{ number, state:"OPEN"|"CLOSED", repo:"owner/name" }],
//              blockedByTruncated:bool, repo?:"owner/name" }         (repo defaults to options.repo)
//   pr       { number, url, isDraft, closes:[number | {number, repo}], repo? }
//   branches [ "feat/12-some-name" | { repo, name:"feat/12-some-name" }, ... ]   (short ref names)
//   options  { repo:"owner/name" }  or  { org:"login" }
//
// OUTPUT { rows:[{ number, repo, title, createdAt, url, status, assignees, labels, labelColors, blockers:[{number,repo,state}],
//                  blocking:[{number,repo}], prs:[{number,url,isDraft}], rank, cycle, externalBlocker }],
//          warnings:[string] }
//
// ORDER IS BY BLOCKERS ONLY. Priority labels and age are deliberately not read: ties between issues
// that are equally ready fall back to the issue number (then the repo name, in org mode), so the same
// input always gives the same page.

export const STATUSES = ["In review", "In progress", "Waiting", "Blocked", "Claimed", "Filed"];
// "dossier" is the legacy name of "record" (#2683), still read because a tracker keeps it until renamed.
export const PARKING_LABELS = ["needs-info", "needs-decision", "awaiting-recurrence", "record", "dossier"];

// The first parking label on an issue, as PARKING_LABELS spells it, or undefined. Compared
// case-insensitively, because GitHub label names are and claim-issue/open-pr match them that way (#2688).
export function parkingLabel(labels) {
  const names = new Set((labels || []).map((l) => String(l).toLowerCase()));
  return PARKING_LABELS.find((l) => names.has(l));
}

const BRANCH = /^(feat|fix|docs)\/(\d+)-/;

const byNumber = (a, b) => a - b;
const keyOf = (repo, number) => `${String(repo || "").toLowerCase()}#${Number(number)}`;

// Issue numbers that have a <prefix>/<n>- branch.
export function branchIssueNumbers(branches) {
  const found = new Set();
  for (const name of branches || []) {
    const m = BRANCH.exec(name);
    if (m) found.add(Number(m[2]));
  }
  return found;
}

// First match wins, in the order STATUSES lists. `prsFor` is the issue's linked open PRs.
export function deriveStatus(issue, prsFor, hasBranch) {
  if (prsFor.some((p) => !p.isDraft)) return "In review";
  if (prsFor.length > 0 || hasBranch) return "In progress";
  if (parkingLabel(issue.labels)) return "Waiting";
  if ((issue.blockedBy || []).some((b) => b.state === "OPEN")) return "Blocked";
  if ((issue.assignees || []).length > 0) return "Claimed";
  return "Filed";
}

// Kahn's algorithm over `nodes` with `blockersOf` (node -> Set of nodes that must come first). The
// node `compare` puts first goes first among the ready ones. A cycle never stalls it: the first
// member of the first cycle found is released, every member is flagged. `label` names a node in a warning.
export function orderByBlockers(nodes, blockersOf, cycleSet = new Set(), warnings = [], compare = byNumber, label = (n) => "#" + n) {
  const remaining = new Set(nodes);
  const waitingOn = new Map(nodes.map((n) => [n, new Set([...(blockersOf.get(n) || [])].filter((b) => remaining.has(b)))]));
  const dependents = new Map(nodes.map((n) => [n, []]));
  for (const [n, set] of waitingOn) for (const b of set) dependents.get(b).push(n);
  const order = [];

  const release = (n) => {
    remaining.delete(n);
    order.push(n);
    for (const d of dependents.get(n)) waitingOn.get(d).delete(n);
  };
  // Everything a node can reach through its dependents while staying in `remaining`.
  const reach = (from) => {
    const seen = new Set();
    const stack = [...dependents.get(from)].filter((d) => remaining.has(d));
    while (stack.length) {
      const n = stack.pop();
      if (seen.has(n)) continue;
      seen.add(n);
      for (const d of dependents.get(n)) if (remaining.has(d)) stack.push(d);
    }
    return seen;
  };

  while (remaining.size) {
    const ready = [...remaining].filter((n) => waitingOn.get(n).size === 0).sort(compare);
    if (ready.length) {
      release(ready[0]);
      continue;
    }
    // Stalled: every remaining node waits on another remaining one. Find those on a cycle.
    const reaches = new Map([...remaining].map((n) => [n, reach(n)]));
    const cyclic = [...remaining].filter((n) => reaches.get(n).has(n)).sort(compare);
    const lowest = cyclic[0];
    const members = cyclic.filter((n) => n === lowest || (reaches.get(lowest).has(n) && reaches.get(n).has(lowest)));
    members.forEach((n) => cycleSet.add(n));
    warnings.push(`Circular blocked-by chain: ${members.map(label).join(", ")}; ordered by issue number from ${label(lowest)}.`);
    release(lowest);
  }
  return order;
}

export function deriveDashboard(issues, prs, branches, options = {}) {
  const home = options.repo || "";
  const orgMode = !!options.org;
  const warnings = [];

  // Every issue is keyed on repo AND number; `ref` keeps the display form of each key.
  const open = new Map();
  const ref = new Map();
  for (const i of issues || []) {
    const repo = i.repo || home;
    const k = keyOf(repo, i.number);
    open.set(k, i);
    ref.set(k, { number: i.number, repo });
  }
  const label = (k) => (orgMode ? `${ref.get(k).repo}#${ref.get(k).number}` : `#${ref.get(k).number}`);
  const compare = (a, b) => ref.get(a).number - ref.get(b).number || (a < b ? -1 : a > b ? 1 : 0);

  const withBranch = new Set();
  for (const b of branches || []) {
    const repo = typeof b === "string" ? home : b.repo;
    const name = typeof b === "string" ? b : b.name;
    for (const n of branchIssueNumbers([name])) withBranch.add(keyOf(repo, n));
  }

  const prsByIssue = new Map();
  for (const pr of prs || []) {
    for (const c of pr.closes || []) {
      const k = typeof c === "number" ? keyOf(pr.repo || home, c) : keyOf(c.repo, c.number);
      if (!prsByIssue.has(k)) prsByIssue.set(k, []);
      prsByIssue.get(k).push({ number: pr.number, url: pr.url, isDraft: !!pr.isDraft });
    }
  }

  // Edges: open blockers that are in the fetched set. An open blocker anywhere else -- another owner,
  // or a repo in scope whose issue was not fetched -- makes the issue "external", and so does anything
  // waiting on such an issue.
  const blockersOf = new Map();
  const blocking = new Map([...open.keys()].map((k) => [k, []]));
  const external = new Set();
  for (const [k, i] of open) {
    const edges = new Set();
    for (const b of i.blockedBy || []) {
      if (b.state !== "OPEN") continue;
      const bk = keyOf(b.repo, b.number);
      if (open.has(bk)) {
        edges.add(bk);
        blocking.get(bk).push(k);
      } else {
        external.add(k);
      }
    }
    blockersOf.set(k, edges);
    if (i.blockedByTruncated) warnings.push(`${label(k)} has more blockers than were fetched; its order may be too optimistic.`);
  }
  // Sinking is inherited: an issue behind a sunk issue cannot be picked up before it either.
  for (let grew = true; grew; ) {
    grew = false;
    for (const [k, edges] of blockersOf) {
      if (!external.has(k) && [...edges].some((b) => external.has(b))) { external.add(k); grew = true; }
    }
  }

  const cycleSet = new Set();
  const keys = [...open.keys()].sort(compare);
  const free = keys.filter((k) => !external.has(k));
  const sunk = keys.filter((k) => external.has(k));
  const order = [
    ...orderByBlockers(free, blockersOf, cycleSet, warnings, compare, label),
    ...orderByBlockers(sunk, blockersOf, cycleSet, warnings, compare, label),
  ];

  const rows = order.map((k, idx) => {
    const i = open.get(k);
    const linked = prsByIssue.get(k) || [];
    return {
      number: i.number,
      repo: ref.get(k).repo,
      title: i.title,
      createdAt: i.createdAt,
      url: i.url,
      status: deriveStatus(i, linked, withBranch.has(k)),
      assignees: i.assignees || [],
      labels: i.labels || [],
      labelColors: i.labelColors || {},
      blockers: (i.blockedBy || []).map((b) => ({ number: b.number, repo: b.repo, state: b.state })),
      blocking: blocking.get(k).sort(compare).map((d) => ({ ...ref.get(d) })),
      prs: linked,
      rank: idx + 1,
      cycle: cycleSet.has(k),
      externalBlocker: external.has(k),
    };
  });
  return { rows, warnings };
}
