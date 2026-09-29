// The issue dashboard's logic -- a PURE ES module: no I/O, no Workers globals, no dependencies.
//
// Issue #2643. It turns three plain-JSON reads of a repo (open issues, open PRs, branch names) into
// the rows the dashboard shows: a status per issue and a pick-up order derived from blocked-by
// dependencies. It is kept apart from the worker so it runs under plain `node` against fixtures.
//
// EXPECTED INPUT (the shape of the GraphQL nodes, flattened by the worker):
//   issue    { number, title, url, createdAt, labels:[name], assignees:[login],
//              blockedBy:[{ number, state:"OPEN"|"CLOSED", repo:"owner/name" }],
//              blockedByTruncated:bool }
//   pr       { number, url, isDraft, closes:[issue number] }      (closes: in-repo issues only)
//   branches [ "feat/12-some-name", "fix/7-x", ... ]              (short ref names)
//   options  { repo:"owner/name" }   the repo's own name, so a blocker in another repo is recognised
//
// OUTPUT { rows:[{ number, title, url, status, assignees, labels, blockers:[{number,repo,state}],
//                  blocking:[number], prs:[{number,url,isDraft}], rank, cycle, externalBlocker }],
//          warnings:[string] }
//
// ORDER IS BY BLOCKERS ONLY. Priority labels and age are deliberately not read: ties between issues
// that are equally ready fall back to the issue number, so the same input always gives the same page.

export const STATUSES = ["In review", "In progress", "Waiting", "Blocked", "Claimed", "Filed"];
export const PARKING_LABELS = ["needs-info", "needs-decision", "awaiting-recurrence"];

const BRANCH = /^(feat|fix|docs)\/(\d+)-/;

const sameRepo = (a, b) => !!a && !!b && a.toLowerCase() === b.toLowerCase();
const byNumber = (a, b) => a - b;

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
  if ((issue.labels || []).some((l) => PARKING_LABELS.includes(l))) return "Waiting";
  if ((issue.blockedBy || []).some((b) => b.state === "OPEN")) return "Blocked";
  if ((issue.assignees || []).length > 0) return "Claimed";
  return "Filed";
}

// Kahn's algorithm over `nodes` (issue numbers) with `blockersOf` (number -> Set of numbers that
// must come first). Lowest number goes first among the ready ones. A cycle never stalls it: the
// lowest-numbered member of the first cycle found is released, every member is flagged.
export function orderByBlockers(nodes, blockersOf, cycleSet = new Set(), warnings = []) {
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
    const ready = [...remaining].filter((n) => waitingOn.get(n).size === 0);
    if (ready.length) {
      release(Math.min(...ready));
      continue;
    }
    // Stalled: every remaining node waits on another remaining one. Find those on a cycle.
    const reaches = new Map([...remaining].map((n) => [n, reach(n)]));
    const cyclic = [...remaining].filter((n) => reaches.get(n).has(n)).sort(byNumber);
    const lowest = cyclic[0];
    const members = cyclic.filter((n) => n === lowest || (reaches.get(lowest).has(n) && reaches.get(n).has(lowest)));
    members.forEach((n) => cycleSet.add(n));
    warnings.push(`Circular blocked-by chain: ${members.map((n) => "#" + n).join(", ")}; ordered by issue number from #${lowest}.`);
    release(lowest);
  }
  return order;
}

export function deriveDashboard(issues, prs, branches, options = {}) {
  const repo = options.repo || "";
  const warnings = [];
  const open = new Map((issues || []).map((i) => [i.number, i]));
  const withBranch = branchIssueNumbers(branches);

  const prsByIssue = new Map();
  for (const pr of prs || []) {
    for (const n of pr.closes || []) {
      if (!prsByIssue.has(n)) prsByIssue.set(n, []);
      prsByIssue.get(n).push({ number: pr.number, url: pr.url, isDraft: !!pr.isDraft });
    }
  }

  // Edges: open in-repo blockers that are in the fetched set. An open blocker elsewhere, or in this
  // repo but not fetched, makes the issue "external" -- and so does anything waiting on such an issue.
  const blockersOf = new Map();
  const blocking = new Map([...open.keys()].map((n) => [n, []]));
  const external = new Set();
  for (const i of open.values()) {
    const edges = new Set();
    for (const b of i.blockedBy || []) {
      if (b.state !== "OPEN") continue;
      if (sameRepo(b.repo, repo) && open.has(b.number)) {
        edges.add(b.number);
        blocking.get(b.number).push(i.number);
      } else {
        external.add(i.number);
      }
    }
    blockersOf.set(i.number, edges);
    if (i.blockedByTruncated) warnings.push(`#${i.number} has more blockers than were fetched; its order may be too optimistic.`);
  }
  // Sinking is inherited: an issue behind a sunk issue cannot be picked up before it either.
  for (let grew = true; grew; ) {
    grew = false;
    for (const [n, edges] of blockersOf) {
      if (!external.has(n) && [...edges].some((b) => external.has(b))) { external.add(n); grew = true; }
    }
  }

  const cycleSet = new Set();
  const numbers = [...open.keys()].sort(byNumber);
  const free = numbers.filter((n) => !external.has(n));
  const sunk = numbers.filter((n) => external.has(n));
  const order = [
    ...orderByBlockers(free, blockersOf, cycleSet, warnings),
    ...orderByBlockers(sunk, blockersOf, cycleSet, warnings),
  ];

  const rows = order.map((n, idx) => {
    const i = open.get(n);
    const linked = prsByIssue.get(n) || [];
    return {
      number: n,
      title: i.title,
      url: i.url,
      status: deriveStatus(i, linked, withBranch.has(n)),
      assignees: i.assignees || [],
      labels: i.labels || [],
      blockers: (i.blockedBy || []).map((b) => ({ number: b.number, repo: b.repo, state: b.state })),
      blocking: blocking.get(n).sort(byNumber),
      prs: linked,
      rank: idx + 1,
      cycle: cycleSet.has(n),
      externalBlocker: external.has(n),
    };
  });
  return { rows, warnings };
}
