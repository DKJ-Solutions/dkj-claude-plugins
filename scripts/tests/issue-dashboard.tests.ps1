<#
.SYNOPSIS
    Regression tests for the optional live issue dashboard: its Cloudflare Worker (route, escaping,
    ordering and status logic) and the script that prepares it (issue #2643).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. The behavioural half additionally needs `node`
    and is SKIPPED, with a visible line, when it is not on PATH.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/issue-dashboard.tests.ps1

    WHAT IT HOLDS, and each is a way the design comes undone:

      1. THE WORKER CARRIES NOTHING. No 32-hex literal, no token, no repository name -- this plugin
         ships from a PUBLIC repository, and the worker is deployed by people who own other repos.
      2. THE ROUTE. The worker's own regex is lifted out of the shipped source and run against the
         cases that matter, then the whole handler is run under node: every miss answers the SAME 404.
      3. THE ESCAPING. Issue titles, labels and logins are written by anybody who can open an issue.
         The handler is run end to end against a stubbed GitHub and the page is read back.
      4. THE CROSS-FILE SEAMS. The status vocabulary in the JS equals the one the skill documents; the
         parking labels equal claim-issue.ps1's default parking set.
      5. THE ORDERING AND STATUS RULES, run against fixtures under node: blockers first, ties by
         number, closed blockers impose nothing, external blockers sink (transitively -- the accepted
         deviation from the contract's wording), cycles are flagged and broken, priority labels and
         age never order anything, and the status precedence for every pair that can collide.
      6. THE SCRIPT, in a temp repo through -RepoRoot: -InitToken once, -EmitWorker copies and writes a
         wrangler.toml exactly once, prints the commands, never a secret. Nothing reaches the network.
      7. THE .gitignore ANCHOR on /dkj-policy/dashboard/.
      8. ORG MODE (#2649): issues keyed on repo AND number, a blocker in another repo of the owner is
         an edge rather than a sink, the handler lists the owner's repos and reads them in aliased
         batches, and -Org prepares a dashboard of its own beside this repo's without either token
         reading as the other's stray.

    The live half -- the real GitHub GraphQL read and a real wrangler deploy -- stays untested: it
    runs against somebody's account.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

$RepoRoot    = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$WorkerDir   = Join-Path $RepoRoot 'plugins\dkj-policy\worker'
$LogicPath   = Join-Path $WorkerDir 'issue-dashboard-logic.js'
$WorkerPath  = Join-Path $WorkerDir 'issue-dashboard-worker.js'
$ScriptPath  = Join-Path $RepoRoot 'scripts\task\issue-dashboard.ps1'
$SkillPath   = Join-Path $RepoRoot 'plugins\dkj-policy\skills\issue-dashboard\SKILL.md'
$ClaimPath   = Join-Path $RepoRoot 'scripts\task\claim-issue.ps1'
$Fixture     = Join-Path ([System.IO.Path]::GetTempPath()) "issue-dashboard-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -ceq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Join-N { param($Items) return (@($Items) -join ',') }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$HexA = 'a' * 32
$HexB = 'b' * 32

Write-Host ''
Write-Host 'The issue dashboard -- what the plugin ships (#2643)' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LogicPath)  'the plugin ships worker/issue-dashboard-logic.js'
Assert-True (Test-Path -LiteralPath $WorkerPath) 'the plugin ships worker/issue-dashboard-worker.js'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'the source repo ships scripts/task/issue-dashboard.ps1'
Assert-True (Test-Path -LiteralPath $SkillPath)  'the plugin ships the issue-dashboard skill'

$logicJs  = [System.IO.File]::ReadAllText($LogicPath, [System.Text.Encoding]::UTF8)
$workerJs = [System.IO.File]::ReadAllText($WorkerPath, [System.Text.Encoding]::UTF8)
$scriptText = [System.IO.File]::ReadAllText($ScriptPath)
$skillText  = [System.IO.File]::ReadAllText($SkillPath, [System.Text.Encoding]::UTF8)
$claimText  = [System.IO.File]::ReadAllText($ClaimPath)

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The worker carries no token, no repository name and no content' -ForegroundColor Cyan

foreach ($pair in @(@('issue-dashboard-worker.js', $workerJs), @('issue-dashboard-logic.js', $logicJs), @('issue-dashboard.ps1', $scriptText))) {
    Assert-True ($pair[1] -notmatch '(?<![0-9a-z])[0-9a-f]{32}(?![0-9a-z])') "$($pair[0]) holds no 32-hex identifier -- no path token, no account id"
}
foreach ($pair in @(@('issue-dashboard-worker.js', $workerJs), @('issue-dashboard-logic.js', $logicJs))) {
    $t = $pair[1]
    Assert-True ($t -notmatch 'ghp_|github_pat_|ghs_|gho_') "$($pair[0]) holds no GitHub token literal"
    Assert-True ($t -notmatch '(?i)DKJ-Solutions|dkj-claude-plugins|claude-code-specialists|DaveKJohn|smartwatchbanden|xoxowildhearts') "$($pair[0]) names no repository or owner -- GITHUB_REPO comes from env"
}
Assert-True ($workerJs -match 'env\.GITHUB_REPO')     'the repository is read from env.GITHUB_REPO'
Assert-True ($workerJs -match 'env\.GITHUB_TOKEN')    '...the GitHub token from env.GITHUB_TOKEN'
Assert-True ($workerJs -match 'env\.DASHBOARD_TOKEN') '...and the path lock from env.DASHBOARD_TOKEN'
Assert-True ($workerJs -match 'noindex')              'the response carries noindex'
Assert-True ($workerJs -match 'x-robots-tag')         '...as an X-Robots-Tag header'
Assert-True ($workerJs -match 'no-store')             'and no-store, because the page is derived from a tracker that moves'
Assert-True ($workerJs -match 'charset=utf-8')        'and declares UTF-8, because the source carries non-ASCII punctuation'

# The lock: constant-time compare, and never a plain comparison against the secret.
Assert-True ($workerJs -match 'diff\s*\|=')           'the token is compared by accumulating XOR differences -- constant time'
Assert-True ($workerJs -match 'charCodeAt')           '...character by character'
Assert-True ($workerJs -notmatch 'DASHBOARD_TOKEN\s*[!=]==?\s') 'DASHBOARD_TOKEN is never compared with == or ==='
Assert-True ($workerJs -notmatch '[!=]==?\s*env\.DASHBOARD_TOKEN') '...on either side'
Assert-True ($workerJs -match '\.pathname')           'the route is matched on the URL pathname, so a query string never reaches it'

# GitHub text is escaped before it reaches the page.
Assert-True ($workerJs -match 'const\s+escapeHtml\s*=') 'an escape function exists'
Assert-True ($workerJs -match 'escapeHtml\(r\.title\)') 'issue titles are escaped'
Assert-True ($workerJs -match 'escapeHtml\(l\)')        'labels are escaped'
Assert-True ($workerJs -match 'assignees\.map\(escapeHtml\)') 'assignee logins are escaped'
Assert-True ($workerJs -match 'escapeHtml\(r\.url\)')   'issue urls are escaped'
Assert-True ($workerJs -match 'escapeHtml\(w\)')        'warnings are escaped'
Assert-True ($workerJs -notmatch '\$\{r\.title\}|\$\{r\.status\}|\$\{l\}|\$\{w\}') 'no GitHub-derived field is interpolated raw'
$escBody = [regex]::Match($workerJs, 'const\s+escapeHtml[\s\S]*?;\r?\n').Value
foreach ($ch in @('&amp;', '&lt;', '&gt;', '&quot;', '&#39;')) {
    Assert-True ($escBody.Contains($ch)) "the escape function maps to $ch"
}

# The cache key is derived from the target (the repo, or the owner in org mode), never from the path token.
Assert-True ($workerJs -match 'encodeURIComponent\(target\)') 'the edge cache key is derived from the target'
Assert-True ($workerJs -match 'const targetOf = \(env\) => \(env\.GITHUB_ORG \? `org:\$\{env\.GITHUB_ORG\}` : env\.GITHUB_REPO\)') '...which is the repo, or org:<login> in org mode'
Assert-True ($workerJs -notmatch 'match\[1\][^;\n]*(cache|Request)') '...and the path token never reaches it'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The route -- lifted out of the shipped worker and run' -ForegroundColor Cyan

$routeMatch = [regex]::Match($workerJs, '(?m)^const\s+ROUTE\s*=\s*/(.+)/;\s*$')
Assert-True $routeMatch.Success 'the worker declares its route as one regex literal this suite can read'
$route = [regex]::new($routeMatch.Groups[1].Value)

Assert-True ($route.IsMatch("/issues/$HexA"))          'the route matches /issues/<32 hex>'
Assert-True ($route.IsMatch("/issues/$HexA/"))         '...and tolerates one trailing slash'
Assert-True (-not $route.IsMatch("/issues/$HexA//"))   '...but not two'
Assert-True (-not $route.IsMatch("/issues/$($HexA.ToUpperInvariant())")) 'UPPERCASE hex is not a token'
Assert-True (-not $route.IsMatch("/issues/$($HexA.Substring(1))"))       '31 characters is not a token'
Assert-True (-not $route.IsMatch("/issues/${HexA}a"))                    '33 characters is not a token'
Assert-True (-not $route.IsMatch('/issues/'))                            'a bare /issues/ is not a route'
Assert-True (-not $route.IsMatch('/issues'))                             '...nor is /issues'
Assert-True (-not $route.IsMatch("/notes/$HexA"))                        'another prefix is not this route'
Assert-True (-not $route.IsMatch("/$HexA"))                              'a token without a prefix is not a route'
Assert-True (-not $route.IsMatch("/x/issues/$HexA"))                     'the route is anchored at the start'
Assert-True (-not $route.IsMatch("/issues/$HexA/extra"))                 'and at the end'
Assert-True (-not $route.IsMatch("/issues/../$HexA"))                    'nothing traversal-shaped survives'
Assert-True (-not $route.IsMatch("/issues/$HexA?x=1"))                   'a raw query string is not part of the path the route sees'
$asUri = [uri]"https://d.example/issues/${HexA}?x=1"
Assert-True ($route.IsMatch($asUri.AbsolutePath))                        '...because the worker matches the URL pathname, where a query string is already gone'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The cross-file seams -- vocabulary the JS, the skill and claim-issue must share' -ForegroundColor Cyan

$jsStatuses = @([regex]::Matches(([regex]::Match($logicJs, 'export const STATUSES\s*=\s*\[([^\]]*)\]')).Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$jsParking  = @([regex]::Matches(([regex]::Match($logicJs, 'export const PARKING_LABELS\s*=\s*\[([^\]]*)\]')).Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Equal 6 $jsStatuses.Count 'the logic module declares six statuses'

$descMatch = [regex]::Match($skillText, 'with a status \(([^)]+)\)')
Assert-True $descMatch.Success 'the skill description lists the status vocabulary'
$skillStatuses = @($descMatch.Groups[1].Value -split ',\s*')
Assert-Equal (Join-N $jsStatuses) (Join-N $skillStatuses) 'STATUSES in the JS equals the skill description, in the same order'
foreach ($s in $jsStatuses) {
    Assert-True ($skillText.Contains("**$s**")) "the skill body documents the status '$s'"
}
# Every status but Claimed is named in sweepVerdict, and Claimed is its fallback, so a status added to
# the logic without a verdict of its own reads as claimed rather than as sweepable.
$verdictFn = [regex]::Match($workerJs, 'function sweepVerdict\(r\) \{([\s\S]*?)\n\}').Groups[1].Value
foreach ($s in @($jsStatuses | Where-Object { $_ -ne 'Claimed' })) {
    Assert-True ($verdictFn.Contains('r.status === "' + $s + '"')) "the sweep verdict names the status '$s'"
}
Assert-True ($verdictFn.Contains('if (r.status === "Filed") return { sweepable: true')) 'only Filed is sweepable'
$parkedBecause = [regex]::Match($workerJs, 'const PARKED_BECAUSE = \{([\s\S]*?)\};').Groups[1].Value
foreach ($l in $jsParking) {
    Assert-True ($parkedBecause -match ('(?:^|[\s,{])"?' + [regex]::Escape($l) + '"?\s*:')) "the page says what the parking label '$l' waits on"
}

$claimMatch = [regex]::Match($claimText, '(?m)^\s+\$SkipLabel\s*=\s*@\(([^)]*)\)')
Assert-True $claimMatch.Success 'claim-issue.ps1 declares its default parking set in one readable array'
$claimParking = @([regex]::Matches($claimMatch.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
Assert-Equal (Join-N ($claimParking | Sort-Object)) (Join-N ($jsParking | Sort-Object)) 'PARKING_LABELS equals claim-issue.ps1 default parking set'
foreach ($l in $jsParking) {
    Assert-True ($skillText.Contains("``$l``")) "the skill names the parking label '$l'"
}

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The logic and the handler, run under node' -ForegroundColor Cyan

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Host '  [SKIP] node is not on PATH -- the ordering, status, branch-regex, route and escaping behaviour checks were NOT run' -ForegroundColor Yellow
} else {
    $nodeDir = Join-Path $Fixture 'node'
    New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null
    Copy-Item -LiteralPath $LogicPath  -Destination (Join-Path $nodeDir 'issue-dashboard-logic.js')
    Copy-Item -LiteralPath $WorkerPath -Destination (Join-Path $nodeDir 'issue-dashboard-worker.js')
    # ES-module detection for a typeless package differs across node versions; declaring it removes the question.
    [System.IO.File]::WriteAllText((Join-Path $nodeDir 'package.json'), '{"type":"module"}', $Utf8NoBom)

    $runnerJs = @'
import { pathToFileURL } from "node:url";
const dir = process.argv[2];
const logic = await import(pathToFileURL(dir + "/issue-dashboard-logic.js").href);
const workerMod = await import(pathToFileURL(dir + "/issue-dashboard-worker.js").href);
const worker = workerMod.default;
const resetMemo = workerMod.resetMemo;
const { deriveDashboard, deriveStatus, branchIssueNumbers, STATUSES, PARKING_LABELS } = logic;

const R = "acme/widgets";
const iss = (number, o = {}) => ({
  number, title: "T" + number, url: "https://github.com/acme/widgets/issues/" + number,
  createdAt: "2026-01-01T00:00:00Z", labels: [], assignees: [], blockedBy: [], blockedByTruncated: false, ...o,
});
const blk = (number, state = "OPEN", repo = R) => ({ number, state, repo });
const run = (issues, prs = [], branches = []) => deriveDashboard(issues, prs, branches, { repo: R });
const order = (d) => d.rows.map((r) => r.number);
const flag = (d, key) => d.rows.filter((r) => r[key]).map((r) => r.number);
const statusOf = (issue, prs = [], hasBranch = false) => deriveStatus(issue, prs, hasBranch);
const pr = (number, isDraft, closes) => ({ number, url: "https://github.com/acme/widgets/pull/" + number, isDraft, closes });
const out = {};

out.exports = { statuses: STATUSES, parking: PARKING_LABELS };

// --- ordering
const chain = run([iss(1, { blockedBy: [blk(2)] }), iss(2, { blockedBy: [blk(3)] }), iss(3), iss(4)]);
out.chain = order(chain);
out.chainReversed = order(run([iss(4), iss(3), iss(2, { blockedBy: [blk(3)] }), iss(1, { blockedBy: [blk(2)] })]));
out.chainRanks = chain.rows.map((r) => r.rank);
out.chainBlocking3 = chain.rows.find((r) => r.number === 3).blocking.map((b) => b.number);
out.chainRepo = chain.rows.map((r) => r.repo);
out.ties = order(run([iss(9), iss(3), iss(5)]));
const closed = run([iss(1, { blockedBy: [blk(2, "CLOSED")], assignees: ["u"] }), iss(2)]);
out.closed = { order: order(closed), external: flag(closed, "externalBlocker"), status1: closed.rows.find((r) => r.number === 1).status };
const cross = run([iss(1, { blockedBy: [blk(7, "OPEN", "other/repo")] }), iss(2), iss(3, { blockedBy: [blk(1)] }), iss(4)]);
out.cross = { order: order(cross), external: flag(cross, "externalBlocker") };
const crossClosed = run([iss(1, { blockedBy: [blk(7, "CLOSED", "other/repo")] }), iss(2)]);
out.crossClosed = { order: order(crossClosed), external: flag(crossClosed, "externalBlocker") };
const deep = run([iss(1, { blockedBy: [blk(7, "OPEN", "other/repo")] }), iss(2, { blockedBy: [blk(1)] }), iss(3, { blockedBy: [blk(2)] }), iss(4), iss(5)]);
out.crossDeep = { order: order(deep), external: flag(deep, "externalBlocker") };
const casing = run([iss(1, { blockedBy: [blk(2, "OPEN", "ACME/Widgets")] }), iss(2)]);
out.casing = { order: order(casing), external: flag(casing, "externalBlocker") };
const cyc = run([
  iss(1, { blockedBy: [blk(2)] }), iss(2, { blockedBy: [blk(3)] }), iss(3, { blockedBy: [blk(1)] }),
  iss(4, { blockedBy: [blk(1)] }), iss(5),
]);
out.cycle = { order: order(cyc), cycle: flag(cyc, "cycle"), warnings: cyc.warnings };
const cyc2 = run([iss(8, { blockedBy: [blk(6)] }), iss(6, { blockedBy: [blk(8)] })]);
out.cycle2 = { order: order(cyc2), cycle: flag(cyc2, "cycle"), warnings: cyc2.warnings };
out.noCycleWarnings = chain.warnings;
const trunc = run([iss(1, { blockedByTruncated: true })]);
out.truncated = trunc.warnings;

// prio labels and createdAt must not order anything
const base = [iss(1), iss(2), iss(3), iss(4, { blockedBy: [blk(2)] })];
const perm = [
  iss(4, { blockedBy: [blk(2)], labels: ["prio-4"], createdAt: "2020-01-01T00:00:00Z" }),
  iss(3, { labels: ["prio-3"], createdAt: "2021-01-01T00:00:00Z" }),
  iss(2, { labels: ["prio-1"], createdAt: "2030-01-01T00:00:00Z" }),
  iss(1, { labels: ["prio-2", "minor"], createdAt: "2029-06-01T00:00:00Z" }),
];
out.prioBase = order(run(base));
out.prioPermuted = order(run(perm));
out.prioAlt = order(run([...perm].reverse().map((i) => ({ ...i, labels: i.labels.map(() => "prio-4"), createdAt: "1999-01-01T00:00:00Z" }))));

// --- status precedence
const pk = { labels: ["needs-info"] }, bl = { blockedBy: [blk(9)] }, asg = { assignees: ["u"] };
const all = { ...pk, ...bl, ...asg };
const live = [pr(1, false, [1])], draft = [pr(2, true, [1])];
out.status = {
  reviewOverAll:        statusOf(iss(1, all), live, true),
  reviewOverDraft:      statusOf(iss(1), [...draft, ...live], false),
  reviewOverBranch:     statusOf(iss(1), live, true),
  draftOverParking:     statusOf(iss(1, all), draft, false),
  branchOverParking:    statusOf(iss(1, all), [], true),
  draftVsBranch:        statusOf(iss(1), draft, true),
  parkingOverBlocked:   statusOf(iss(1, { ...bl, labels: ["awaiting-decision"] }), [], false),
  parkingOverAssignee:  statusOf(iss(1, { ...asg, labels: ["awaiting-recurrence"] }), [], false),
  parkingFormerDecision: statusOf(iss(1, { ...bl, labels: ["needs-decision"] }), [], false),
  parkingOverAll:       statusOf(iss(1, all), [], false),
  blockedOverAssignee:  statusOf(iss(1, { ...bl, ...asg }), [], false),
  closedBlockerClaimed: statusOf(iss(1, { blockedBy: [blk(9, "CLOSED")], ...asg }), [], false),
  claimed:              statusOf(iss(1, asg), [], false),
  filed:                statusOf(iss(1), [], false),
  prioLabelIsNotParking: statusOf(iss(1, { labels: ["prio-4", "bug"] }), [], false),
  parkingEach:          PARKING_LABELS.map((l) => statusOf(iss(1, { labels: [l] }), [], false)),
  parkingMixedCase:     ["Record", "Needs-Decision", "AWAITING-RECURRENCE"].map((l) => statusOf(iss(1, { labels: [l] }), [], false)),
  externalOpenBlocker:  statusOf(iss(1, { blockedBy: [blk(7, "OPEN", "other/repo")] }), [], false),
};
// End to end through deriveDashboard: PR link, draft, branch, foreign-issue PR.
const e2e = run(
  [iss(1), iss(2), iss(3), iss(4), iss(5)],
  [pr(10, false, [1]), pr(11, true, [2]), pr(12, false, [99])],
  ["feat/3-work", "chore/4-nope"],
);
out.e2e = Object.fromEntries(e2e.rows.map((r) => [r.number, r.status]));
out.e2ePrs = e2e.rows.find((r) => r.number === 2).prs;

// --- branch regex
const names = ["feat/12-a", "fix/7-x", "docs/3-y", "chore/9-z", "feat/12", "feat/x-1", "feature/5-a",
  "feat/5a-b", "xfeat/8-a", "feat/-5-a", "fix/007-dup", "refs/heads/feat/20-a", "docs/3"];
out.branches = [...branchIssueNumbers(names)].sort((a, b) => a - b);
out.branchesEmpty = [...branchIssueNumbers(undefined)];

// --- the handler
const HEX = "a".repeat(32);
const NEAR = "a".repeat(31) + "b";
const req = (path, method = "GET") => new Request("https://d.example" + path, { method });
const snap = async (res, withBody = true) => ({
  status: res.status, body: withBody ? await res.text() : "", cc: res.headers.get("cache-control"),
  robots: res.headers.get("x-robots-tag"), ct: res.headers.get("content-type"),
  ref: res.headers.get("referrer-policy"), nosniff: res.headers.get("x-content-type-options"),
  csp: res.headers.get("content-security-policy"),
});
const ctx = { waitUntil() {} };
const good = { DASHBOARD_TOKEN: HEX };
const misses = {
  wrongToken:      [req("/issues/" + NEAR), good],
  uppercaseToken:  [req("/issues/" + HEX.toUpperCase()), good],
  wrongPath:       [req("/"), good],
  otherPrefix:     [req("/notes/" + HEX), good],
  shortToken:      [req("/issues/" + HEX.slice(1)), good],
  post:            [req("/issues/" + HEX, "POST"), good],
  put:             [req("/issues/" + HEX, "PUT"), good],
  noSecret:        [req("/issues/" + HEX), {}],
  nonStringSecret: [req("/issues/" + HEX), { DASHBOARD_TOKEN: 12345 }],
  emptySecret:     [req("/issues/" + HEX), { DASHBOARD_TOKEN: "" }],
  noEnv:           [req("/issues/" + HEX), undefined],
};
out.misses = {};
for (const [k, [r, env]] of Object.entries(misses)) out.misses[k] = await snap(await worker.fetch(r, env, ctx));

// past the lock, before any GitHub call: 503 tells the operator which binding is missing
out.passLock = {
  plain:    await snap(await worker.fetch(req("/issues/" + HEX), good, ctx)),
  slash:    await snap(await worker.fetch(req("/issues/" + HEX + "/"), good, ctx)),
  query:    await snap(await worker.fetch(req("/issues/" + HEX + "?x=1"), good, ctx)),
  head:     await snap(await worker.fetch(req("/issues/" + HEX, "HEAD"), good, ctx), false),
  badRepo:  await snap(await worker.fetch(req("/issues/" + HEX), { ...good, GITHUB_TOKEN: "t", GITHUB_REPO: 'a/b"><x' }, ctx)),
};

// the whole handler against a stubbed GitHub
const cacheKeys = [];
globalThis.caches = { default: {
  match: async (k) => { cacheKeys.push(k.url); return undefined; },
  put: async (k) => { cacheKeys.push(k.url); },
} };
const conn = (nodes) => ({ nodes, pageInfo: { hasNextPage: false, endCursor: null } });
const calls = [];
const evilTitle = '<script>alert(1)</script> & "q" \'s\'';
let reply = null;
let respond = null; // when set, builds the reply from the GraphQL query text (the paging stubs)
globalThis.fetch = async (url, init) => {
  calls.push({ url: String(url), auth: init.headers.authorization, body: init.body });
  const answer = respond ? respond(JSON.parse(init.body).query) : reply;
  return new Response(JSON.stringify(answer), { status: 200, headers: { "content-type": "application/json" } });
};
reply = { data: { repository: {
  issues: { ...conn([
    { number: 1, title: evilTitle, url: "https://github.com/acme/widgets/issues/1", createdAt: "2026-01-01T00:00:00Z",
      labels: { totalCount: 1, nodes: [{ name: "<b>x</b>", color: "d73a4a" }] }, assignees: { nodes: [{ login: "<i>u</i>" }] },
      blockedBy: { totalCount: 0, nodes: [] } },
    { number: 2, title: "second", url: "https://github.com/acme/widgets/issues/2", createdAt: "2026-01-02T00:00:00Z",
      labels: { totalCount: 2, nodes: [{ name: "light", color: "fbca04" }, { name: "odd", color: "red;x:y" }] }, assignees: { nodes: [] },
      blockedBy: { totalCount: 1, nodes: [{ number: 1, state: "OPEN", repository: { nameWithOwner: "acme/widgets" } }] } },
    { number: 12, title: "branch", url: "https://github.com/acme/widgets/issues/12", createdAt: "2026-01-03T00:00:00Z",
      labels: { totalCount: 0, nodes: [] }, assignees: { nodes: [] }, blockedBy: { totalCount: 0, nodes: [] } },
    { number: 13, title: "parked", url: "https://github.com/acme/widgets/issues/13", createdAt: "2025-12-31T00:00:00Z",
      labels: { totalCount: 1, nodes: [{ name: "Needs-Decision", color: "" }] }, assignees: { nodes: [] }, blockedBy: { totalCount: 0, nodes: [] } },
  ]), totalCount: 4 },
  pullRequests: conn([{ number: 40, url: "https://github.com/acme/widgets/pull/40", isDraft: false,
    closingIssuesReferences: { totalCount: 1, nodes: [{ number: 1, repository: { nameWithOwner: "acme/widgets" } }] } }]),
  feat: conn([{ name: "12-x" }]), fix: conn([]), docs: conn([]),
} } };
const env = { DASHBOARD_TOKEN: HEX, GITHUB_TOKEN: "ghs_FAKE", GITHUB_REPO: R };
resetMemo();
const page = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
out.render = {
  status: page.status, cc: page.cc, robots: page.robots, ct: page.ct,
  ref: page.ref, nosniff: page.nosniff, csp: page.csp,
  anchors: (page.body.match(/<a\s[^>]*>/g) || []).length,
  anchorsWithRel: (page.body.match(/<a\s[^>]*>/g) || []).filter((a) => a.includes('rel="noopener noreferrer"')).length,
  scriptRaw: page.body.includes("<script"),
  titleEscaped: page.body.includes("&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;q&quot; &#39;s&#39;"),
  labelEscaped: page.body.includes("&lt;b&gt;x&lt;/b&gt;") && !page.body.includes("<b>x</b>"),
  labelColoured: page.body.includes('style="background:#d73a4a;border-color:#d73a4a;color:#fff">&lt;b&gt;x&lt;/b&gt;<'),
  labelLightText: page.body.includes('style="background:#fbca04;border-color:#fbca04;color:#1f2328">light<'),
  labelBadColour: page.body.includes('<span class="tag">odd<') && !page.body.includes("red;x:y"),
  numberColumn: page.body.includes('<div class="num"><a href="https://github.com/acme/widgets/issues/12" rel="noopener noreferrer">#12</a></div>'),
  noRank: !page.body.includes('class="rank"'),
  loginEscaped: page.body.includes("&lt;i&gt;u&lt;/i&gt;") && !page.body.includes("<i>u</i>"),
  metaNoindex: /<meta name="robots" content="noindex/.test(page.body),
  inReview: page.body.includes('class="row parked" title="Skip: in review"'),
  inProgress: page.body.includes('class="row parked" title="Skip: in progress"'),
  blockedBy: page.body.includes('class="row parked" title="Skip: blocked by #1"'),
  parkedMixedCase: page.body.includes('class="row parked" title="Skip: waiting on the owner&#39;s decision"'),
  sweepCounts: page.body.includes("<li>Sweepable<b>0</b></li><li>Skip<b>4</b></li>"),
  noQuietPills: !page.body.includes(">In progress<") && !page.body.includes(">Filed<") && !page.body.includes(">Waiting<"),
  order: [...page.body.matchAll(/class="num"><a href="[^"]*?issues\/(\d+)"/g)].map((m, i) => (i + 1) + ":" + m[1]),
  githubCalls: calls.length,
  githubUrl: calls[0] && calls[0].url,
  githubAuth: calls[0] && calls[0].auth,
  pathTokenSentToGithub: calls.some((c) => c.body.includes(HEX) || c.url.includes(HEX)),
  dashboardTokenSentToGithub: calls.some((c) => (c.auth || "").includes(HEX)),
  cacheKeyHasToken: cacheKeys.some((k) => k.includes(HEX)),
  cacheKeyCount: cacheKeys.length,
};
// the memo: a second request inside the window makes no GitHub call and no edge-cache call; after resetMemo() it does
const goodReply = reply;
const memoBefore = { calls: calls.length, keys: cacheKeys.length };
const memo2 = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
const memoAfter2 = { calls: calls.length, keys: cacheKeys.length };
resetMemo();
const memo3 = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
out.memo = { before: memoBefore.calls, after2: memoAfter2.calls, after3: calls.length, keysBefore: memoBefore.keys, keysAfter2: memoAfter2.keys,
  status2: memo2.status, status3: memo3.status, sameBody: memo2.body === page.body };
// a failing read: 502 with the GitHub message escaped
resetMemo();
reply = { errors: [{ message: "<img src=x onerror=alert(1)>" }] };
const bad = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
out.githubError = { status: bad.status, raw: bad.body.includes("<img"), escaped: bad.body.includes("&lt;img"), cc: bad.cc, robots: bad.robots };
reply = goodReply;

// --- paging. Stubs answer per connection named in the query, so a connection that is not asked again gets nothing.
const gq = (num) => ({ number: num, title: "paged " + num, url: "https://github.com/acme/widgets/issues/" + num, createdAt: "2026-02-01T00:00:00Z",
  labels: { totalCount: 0, nodes: [] }, assignees: { nodes: [] }, blockedBy: { totalCount: 0, nodes: [] } });
const pageInfo = (more, cur) => ({ hasNextPage: more, endCursor: more ? cur : null });
const asked = (q, key) => q.includes(key === "issues" ? "issues(" : key === "prs" ? "pullRequests(" : key + ": refs(");
const numbersOnPage = (body) => [...body.matchAll(/class="num"><a href="[^"]*?issues\/(\d+)"/g)].map((m) => Number(m[1]));

// (a) issues need a second page, prs and refs finish on the first
resetMemo();
calls.length = 0;
respond = (q) => {
  const repo = {};
  if (asked(q, "issues")) {
    const second = q.includes('after: "C1"');
    repo.issues = second
      ? { nodes: [gq(3), gq(4)], totalCount: 4, pageInfo: pageInfo(false) }
      : { nodes: [gq(1), gq(2)], totalCount: 4, pageInfo: pageInfo(true, "C1") };
  }
  if (asked(q, "prs")) repo.pullRequests = { nodes: [], pageInfo: pageInfo(false) };
  for (const k of ["feat", "fix", "docs"]) if (asked(q, k)) repo[k] = { nodes: [], pageInfo: pageInfo(false) };
  return { data: { repository: repo } };
};
const paged = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
const q1 = calls[0] ? JSON.parse(calls[0].body).query : "";
const q2 = calls[1] ? JSON.parse(calls[1].body).query : "";
const nums = numbersOnPage(paged.body);
out.paging = {
  status: paged.status, requests: calls.length,
  firstHasAfter: q1.includes("after:"), firstAskedAll: ["issues", "prs", "feat", "fix", "docs"].every((k) => asked(q1, k)),
  secondAfterCount: (q2.match(/after:/g) || []).length, secondIssuesOnly: asked(q2, "issues") && !asked(q2, "prs") && !asked(q2, "feat") && !asked(q2, "fix") && !asked(q2, "docs"),
  secondCursor: q2.includes('after: "C1"'),
  numbers: nums, unique: new Set(nums).size === nums.length,
  noWarning: !paged.body.includes("Stopped after"),
};

// (b) a connection that never ends: the budget stops it at MAX_PAGES requests and the page says so
resetMemo();
calls.length = 0;
let serial = 100;
respond = (q) => {
  const repo = {};
  if (asked(q, "issues")) { serial++; repo.issues = { nodes: [gq(serial)], totalCount: 9999, pageInfo: pageInfo(true, "N" + serial) }; }
  if (asked(q, "prs")) repo.pullRequests = { nodes: [], pageInfo: pageInfo(true, "P") };
  for (const k of ["feat", "fix", "docs"]) if (asked(q, k)) repo[k] = { nodes: [], pageInfo: pageInfo(true, "R") };
  return { data: { repository: repo } };
};
const endless = await snap(await worker.fetch(req("/issues/" + HEX), env, ctx));
out.endless = { status: endless.status, requests: calls.length, stopped: endless.body.includes("Stopped after 10 GitHub requests"), rendered: numbersOnPage(endless.body).length };
respond = null;

// --- org mode (#2649): the logic
const A = "acme/a", B = "acme/b";
const oiss = (repo, number, o = {}) => ({ ...iss(number, o), repo, url: "https://github.com/" + repo + "/issues/" + number });
const orun = (issues, prs = [], branches = []) => deriveDashboard(issues, prs, branches, { org: "acme" });
const okey = (d) => d.rows.map((r) => r.repo + "#" + r.number);
const oCross = orun([oiss(A, 1, { blockedBy: [blk(1, "OPEN", B)] }), oiss(B, 1), oiss(A, 2)]);
out.org = {
  cross: okey(oCross),
  crossExternal: oCross.rows.filter((r) => r.externalBlocker).length,
  crossBlocking: oCross.rows.find((r) => r.repo === B).blocking.map((b) => b.repo + "#" + b.number),
  ties: okey(orun([oiss(B, 3), oiss(A, 3), oiss(B, 1)])),
  outside: okey(orun([oiss(A, 1, { blockedBy: [blk(4, "OPEN", "other/x")] }), oiss(B, 2)])),
  unfetched: okey(orun([oiss(A, 1, { blockedBy: [blk(9, "OPEN", B)] }), oiss(B, 2)])),
  branch: Object.fromEntries(orun([oiss(A, 5), oiss(B, 5)], [], [{ repo: B, name: "feat/5-x" }]).rows.map((r) => [r.repo, r.status])),
  pr: Object.fromEntries(orun([oiss(A, 6), oiss(B, 6)], [{ number: 30, url: "u", isDraft: false, repo: A, closes: [{ number: 6, repo: B }] }]).rows.map((r) => [r.repo, r.status])),
  cycleWarnings: orun([oiss(A, 1, { blockedBy: [blk(1, "OPEN", B)] }), oiss(B, 1, { blockedBy: [blk(1, "OPEN", A)] })]).warnings,
};

// --- org mode: the handler against a stubbed GitHub
const orgNode = (repo, num, blockedBy = []) => ({ number: num, title: repo + " " + num, url: "https://github.com/" + repo + "/issues/" + num,
  createdAt: "2026-03-01T00:00:00Z", labels: { totalCount: 0, nodes: [] }, assignees: { nodes: [] },
  blockedBy: { totalCount: blockedBy.length, nodes: blockedBy } });
const emptyRepo = (issues) => ({ issues: { nodes: issues, totalCount: issues.length, pageInfo: pageInfo(false) },
  pullRequests: { nodes: [], pageInfo: pageInfo(false) }, feat: conn([]), fix: conn([]), docs: conn([]) });
resetMemo();
calls.length = 0;
cacheKeys.length = 0;
respond = (q) => {
  if (q.includes("repositoryOwner(")) return { data: { repositoryOwner: { repositories: { pageInfo: pageInfo(false), nodes: [
    { nameWithOwner: "acme/a", isArchived: false, hasIssuesEnabled: true },
    { nameWithOwner: "acme/b", isArchived: false, hasIssuesEnabled: true },
    { nameWithOwner: "acme/old", isArchived: true, hasIssuesEnabled: true },
    { nameWithOwner: "acme/site", isArchived: false, hasIssuesEnabled: false },
    { nameWithOwner: "acme/sso", isArchived: false, hasIssuesEnabled: true },
    { nameWithOwner: "friend/lib", isArchived: false, hasIssuesEnabled: true },
  ] } } } };
  const data = {};
  if (q.includes('r0: repository(owner: "acme", name: "a")')) data.r0 = emptyRepo([orgNode("acme/a", 1, [{ number: 1, state: "OPEN", repository: { nameWithOwner: "acme/b" } }])]);
  if (q.includes('r1: repository(owner: "acme", name: "b")')) data.r1 = emptyRepo([orgNode("acme/b", 1)]);
  // The real shape of an unreadable repository: null data for its alias AND an error pathed at it.
  if (q.includes('r2: repository(owner: "acme", name: "sso")')) {
    data.r2 = null;
    return { data, errors: [{ type: "FORBIDDEN", path: ["r2"], message: "Resource protected by organization SAML enforcement." }] };
  }
  return { data };
};
const orgEnv = { DASHBOARD_TOKEN: HEX, GITHUB_TOKEN: "ghs_FAKE", GITHUB_ORG: "acme" };
const orgPage = await snap(await worker.fetch(req("/issues/" + HEX), orgEnv, ctx));
const orgQueries = calls.map((c) => JSON.parse(c.body).query);
out.orgHandler = {
  status: orgPage.status, requests: calls.length,
  listedFirst: !!orgQueries[0] && orgQueries[0].includes('repositoryOwner(login: "acme")'),
  archivedAsked: orgQueries.some((q) => q.includes('name: "old"')),
  noIssuesAsked: orgQueries.some((q) => q.includes('name: "site"')),
  bothInOne: !!orgQueries[1] && orgQueries[1].includes("r0: repository(") && orgQueries[1].includes("r1: repository("),
  order: [...orgPage.body.matchAll(/class="num"><a href="https:\/\/github\.com\/([^"]+?)\/issues\/(\d+)"/g)].map((m) => m[1] + "#" + m[2]),
  shortLinks: orgPage.body.includes('<span class="repo">b</span>') && orgPage.body.includes('<span class="repo">a</span>'),
  heading: orgPage.body.includes("<title>Issue dashboard " + String.fromCharCode(0x2014) + " acme</title>"),
  noSink: !orgPage.body.includes("Waits on something outside this list"),
  cacheKeyOrg: cacheKeys.some((k) => k.includes("org%3Aacme")),
  cacheKeyHasToken: cacheKeys.some((k) => k.includes(HEX)),
  partialWarned: orgPage.body.includes("acme/sso could not be read with this token"),
  collaboratorAsked: orgQueries.some((q) => q.includes('owner: "friend"')),
};
// An error that is NOT an unreadable repository still fails the page.
resetMemo();
respond = (q) => q.includes("repositoryOwner(")
  ? { data: { repositoryOwner: { repositories: { pageInfo: pageInfo(false), nodes: [{ nameWithOwner: "acme/a", isArchived: false, hasIssuesEnabled: true }] } } } }
  : { data: { r0: emptyRepo([]) }, errors: [{ type: "MAX_NODE_LIMIT_EXCEEDED", message: "too many nodes" }] };
out.orgHardError = (await snap(await worker.fetch(req("/issues/" + HEX), orgEnv, ctx))).status;
respond = null;
out.orgConfig = {
  both:   await snap(await worker.fetch(req("/issues/" + HEX), { ...orgEnv, GITHUB_REPO: R }, ctx)),
  badOrg: await snap(await worker.fetch(req("/issues/" + HEX), { ...orgEnv, GITHUB_ORG: 'a"><x' }, ctx)),
};
console.log(JSON.stringify(out));
'@
    $runnerPath = Join-Path $nodeDir 'runner.mjs'
    [System.IO.File]::WriteAllText($runnerPath, $runnerJs, $Utf8NoBom)

    $errFile = Join-Path $nodeDir "stderr-$([guid]::NewGuid().ToString('n')).txt"
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $rawOut = & node $runnerPath $nodeDir 2>$errFile
        $nodeCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $nodeErr = if (Test-Path -LiteralPath $errFile) { [System.IO.File]::ReadAllText($errFile) } else { '' }
    Assert-Equal 0 $nodeCode 'node imports both modules and runs every fixture'
    if ($nodeCode -ne 0) { Write-Host "         node said: $nodeErr" -ForegroundColor Red }

    $r = $null
    try { $r = ((@($rawOut) -join "`n") | ConvertFrom-Json) } catch { }
    Assert-True ($null -ne $r) 'the runner answered with JSON'

    if ($null -ne $r) {
        Write-Host ''
        Write-Host '  -- exports' -ForegroundColor DarkCyan
        Assert-Equal (Join-N $jsStatuses) (Join-N $r.exports.statuses) 'STATUSES as node sees it equals the text this suite parsed'
        Assert-Equal (Join-N $jsParking) (Join-N $r.exports.parking)  'PARKING_LABELS as node sees it equals the text this suite parsed'

        Write-Host '  -- order' -ForegroundColor DarkCyan
        Assert-Equal '3,2,1,4' (Join-N $r.chain) 'a chain orders blockers first (1<-2<-3 gives 3,2,1), the free issue last by number'
        Assert-Equal (Join-N $r.chain) (Join-N $r.chainReversed) '...and the input order does not matter'
        Assert-Equal '1,2,3,4' (Join-N $r.chainRanks) 'rank is the 1-based position'
        Assert-Equal '2' (Join-N $r.chainBlocking3) '...and blocking lists who a row unblocks'
        Assert-Equal 'acme/widgets,acme/widgets,acme/widgets,acme/widgets' (Join-N $r.chainRepo) '...and in repo mode every row carries the repo'
        Assert-Equal '3,5,9' (Join-N $r.ties) 'issues that are equally ready are ordered by issue number'
        Assert-Equal '1,2' (Join-N $r.closed.order) 'a CLOSED blocker imposes no order (1 stays before 2)'
        Assert-Equal '' (Join-N $r.closed.external) '...and does not sink the issue'
        Assert-Equal 'Claimed' $r.closed.status1 '...nor does it make it Blocked'
        Assert-Equal '2,4,1,3' (Join-N $r.cross.order) 'an open blocker in another repo sinks the issue below every issue without one'
        Assert-Equal '1,3' (Join-N ($r.cross.external | Sort-Object {[int]$_})) '...and, transitively, an issue waiting on the sunk issue (accepted deviation from the contract)'
        Assert-Equal '1,2' (Join-N $r.crossClosed.order) 'a CLOSED cross-repo blocker sinks nothing'
        Assert-Equal '' (Join-N $r.crossClosed.external) '...and sets no external flag'
        Assert-Equal '4,5,1,2,3' (Join-N $r.crossDeep.order) 'sinking is inherited down a whole chain (1 external, 2 and 3 behind it)'
        Assert-Equal '1,2,3' (Join-N ($r.crossDeep.external | Sort-Object {[int]$_})) '...and every one of them is flagged'
        Assert-Equal '2,1' (Join-N $r.casing.order) 'a blocker repo written in another case is still this repo'
        Assert-Equal '' (Join-N $r.casing.external) '...so it does not sink'

        Write-Host '  -- cycles' -ForegroundColor DarkCyan
        Assert-Equal '1,2,3' (Join-N ($r.cycle.cycle | Sort-Object {[int]$_})) 'a 3-cycle flags every member and nothing else (the dependant 4 and the free 5 are not flagged)'
        Assert-Equal 1 @($r.cycle.warnings).Count 'it warns exactly once'
        Assert-True ((@($r.cycle.warnings)[0]) -like '*#1, #2, #3*') '...naming all members'
        Assert-True ((@($r.cycle.warnings)[0]) -like '*from #1.') '...and the lowest number it broke at'
        Assert-Equal '5,1,3,2,4' (Join-N $r.cycle.order) 'the cycle is broken at the lowest number and the rest still ordered; the dependant 4 comes after the cycle'
        Assert-Equal '6,8' (Join-N ($r.cycle2.cycle | Sort-Object {[int]$_})) 'a 2-cycle flags both'
        Assert-Equal '6,8' (Join-N $r.cycle2.order) '...broken at the lower number even though the input listed 8 first'
        Assert-Equal 0 @($r.noCycleWarnings).Count 'an acyclic input warns about nothing'
        Assert-Equal 1 @($r.truncated).Count 'a truncated blockedBy connection is reported'
        Assert-True ((@($r.truncated)[0]) -like '*#1*') '...naming the issue'

        Write-Host '  -- priority and age do not order' -ForegroundColor DarkCyan
        Assert-Equal '1,2,3,4' (Join-N $r.prioBase) 'baseline order'
        Assert-Equal (Join-N $r.prioBase) (Join-N $r.prioPermuted) 'prio-* labels, other labels and createdAt, shuffled, leave the order unchanged'
        Assert-Equal (Join-N $r.prioBase) (Join-N $r.prioAlt) '...whichever way they are permuted'

        Write-Host '  -- status precedence' -ForegroundColor DarkCyan
        $s = $r.status
        Assert-Equal 'In review'   $s.reviewOverAll        'an open non-draft PR beats a branch, a parking label, an open blocker and an assignee'
        Assert-Equal 'In review'   $s.reviewOverDraft      '...a non-draft PR beats a draft PR on the same issue'
        Assert-Equal 'In review'   $s.reviewOverBranch     '...and a branch'
        Assert-Equal 'In progress' $s.draftOverParking     'a draft PR beats a parking label, an open blocker and an assignee'
        Assert-Equal 'In progress' $s.branchOverParking    'a branch beats a parking label, an open blocker and an assignee'
        Assert-Equal 'In progress' $s.draftVsBranch        'a draft PR and a branch agree'
        Assert-Equal 'Waiting'     $s.parkingOverBlocked   'a parking label beats an open blocker'
        Assert-Equal 'Waiting'     $s.parkingOverAssignee  '...and an assignee'
        Assert-Equal 'Waiting'     $s.parkingFormerDecision 'the former name needs-decision still parks (#2741)'
        Assert-Equal 'Waiting'     $s.parkingOverAll       '...and both'
        Assert-Equal 'Blocked'     $s.blockedOverAssignee  'an open blocker beats an assignee'
        Assert-Equal 'Claimed'     $s.closedBlockerClaimed 'a CLOSED blocker does not block'
        Assert-Equal 'Blocked'     $s.externalOpenBlocker  'an open blocker in another repo blocks too'
        Assert-Equal 'Claimed'     $s.claimed              'an assignee alone is Claimed'
        Assert-Equal 'Filed'       $s.filed                'nothing at all is Filed'
        Assert-Equal 'Filed'       $s.prioLabelIsNotParking 'a prio or bug label is not a parking label'
        Assert-Equal (Join-N @($jsParking | ForEach-Object { 'Waiting' })) (Join-N $s.parkingEach) 'each parking label parks on its own -- every former name as well as the current ones (#2683, #2723)'
        Assert-Equal 'Waiting,Waiting,Waiting' (Join-N $s.parkingMixedCase) '...in any letter case, as GitHub and claim-issue match labels (#2688)'
        Assert-Equal 'In review' $r.e2e.'1' 'end to end: an open non-draft PR closing #1 puts it In review'
        Assert-Equal 'In progress' $r.e2e.'2' '...a draft PR closing #2 puts it In progress'
        Assert-Equal 'In progress' $r.e2e.'3' '...a feat/3- branch puts #3 In progress'
        Assert-Equal 'Filed' $r.e2e.'4' '...a chore/4- branch does not'
        Assert-Equal 'Filed' $r.e2e.'5' '...and a PR closing an issue outside the fetched set touches nobody'
        Assert-Equal 1 @($r.e2ePrs).Count 'a row carries its linked PRs'
        Assert-Equal 'True' "$($r.e2ePrs[0].isDraft)" '...with the draft flag'

        Write-Host '  -- branch regex' -ForegroundColor DarkCyan
        Assert-Equal '3,7,12' (Join-N $r.branches) 'only feat/, fix/ and docs/ branches with <n>- count (chore/, feature/, no dash, non-digit, prefixed refs are ignored)'
        Assert-Equal '' (Join-N $r.branchesEmpty) 'no branch list is an empty set'

        Write-Host '  -- the handler: every miss is the same 404' -ForegroundColor DarkCyan
        $ref = $r.misses.wrongToken
        Assert-Equal 404 $ref.status 'a wrong token answers 404'
        Assert-Equal 'Not found' $ref.body '...with a body that says nothing about why'
        foreach ($p in $r.misses.PSObject.Properties) {
            $m = $p.Value
            $same = ($m.status -eq $ref.status) -and ($m.body -ceq $ref.body) -and ($m.cc -ceq $ref.cc) -and ($m.robots -ceq $ref.robots) -and ($m.ct -ceq $ref.ct) -and ($m.ref -ceq $ref.ref) -and ($m.nosniff -ceq $ref.nosniff) -and ($m.csp -ceq $ref.csp)
            Assert-True $same "miss '$($p.Name)' is byte-for-byte the same 404 (status, body, headers)"
        }
        Assert-Equal 'no-store' $ref.cc '...carrying no-store'
        Assert-True ($ref.robots -like 'noindex*') '...and noindex'
        Assert-Equal 'no-referrer' $ref.ref '...and referrer-policy no-referrer'
        Assert-Equal 'nosniff' $ref.nosniff '...and x-content-type-options nosniff'
        Assert-True (($ref.csp -like "default-src 'none'*") -and ($ref.csp -like "*frame-ancestors 'none'*")) "...and a CSP that starts from default-src 'none' and forbids framing"

        Write-Host '  -- the handler: past the lock' -ForegroundColor DarkCyan
        foreach ($n in 'plain', 'slash', 'query', 'head') {
            $p = $r.passLock.$n
            Assert-Equal 503 $p.status "the valid route ($n) passes the lock and reaches the configuration check"
            Assert-Equal 'no-store' $p.cc "...and its answer is no-store ($n)"
            Assert-True ($p.robots -like 'noindex*') "...and noindex ($n)"
            Assert-Equal 'no-referrer' $p.ref "...and no-referrer ($n)"
            Assert-Equal 'nosniff' $p.nosniff "...and nosniff ($n)"
            Assert-Equal $ref.csp $p.csp "...and the same CSP as the 404 ($n)"
        }
        Assert-True ($r.passLock.plain.body -like '*Missing binding: GITHUB_TOKEN, GITHUB_REPO*') 'a missing binding is named, but only after the lock'
        Assert-Equal 503 $r.passLock.badRepo.status 'a GITHUB_REPO that is not owner/name is refused'
        Assert-True ($r.passLock.badRepo.body -notlike '*<x*') '...and the value is not echoed raw'

        Write-Host '  -- the handler: the page' -ForegroundColor DarkCyan
        $g = $r.render
        Assert-Equal 200 $g.status 'a good request against the stubbed GitHub renders'
        Assert-Equal 'no-store' $g.cc '...no-store'
        Assert-True ($g.robots -like 'noindex*') '...noindex'
        Assert-True ($g.ct -like 'text/html*utf-8*') '...as UTF-8 HTML'
        Assert-True $g.metaNoindex '...with a robots meta as well'
        Assert-Equal 'no-referrer' $g.ref 'the 200 page carries referrer-policy no-referrer'
        Assert-Equal 'nosniff' $g.nosniff '...x-content-type-options nosniff'
        Assert-Equal $ref.csp $g.csp '...and the same CSP as the 404'
        Assert-True (($g.csp -like "default-src 'none'*") -and ($g.csp -notlike '*script-src*') -and ($g.csp -like "*frame-ancestors 'none'*")) "...which starts from default-src 'none', allows no script and forbids framing"
        Assert-True ($g.anchors -gt 0) 'the rendered page has links'
        Assert-Equal $g.anchors $g.anchorsWithRel 'every <a> in the rendered page carries rel="noopener noreferrer"'
        Assert-Equal 'False' "$($g.scriptRaw)" 'no raw <script appears anywhere on the page'
        Assert-Equal 'True' "$($g.titleEscaped)" 'a hostile issue title is escaped (& < > " and the apostrophe)'
        Assert-Equal 'True' "$($g.labelEscaped)" 'a hostile label is escaped'
        Assert-Equal 'True' "$($g.labelColoured)" 'a label is filled with its GitHub colour, white text on a dark one'
        Assert-Equal 'True' "$($g.labelLightText)" '...and dark text on a light one'
        Assert-Equal 'True' "$($g.labelBadColour)" 'a colour that is not six hex digits never reaches the style attribute'
        Assert-Equal 'True' "$($g.numberColumn)" 'the first column is the issue number, linked to the issue'
        Assert-Equal 'True' "$($g.noRank)" 'no pick-up position is printed'
        Assert-Equal 'True' "$($g.loginEscaped)" 'a hostile assignee login is escaped'
        Assert-Equal 'True' "$($g.inReview)" 'the PR-linked row is tinted as skipped, its tooltip saying in review'
        Assert-Equal 'True' "$($g.inProgress)" 'the branch-linked issue is skipped as in progress'
        Assert-Equal 'True' "$($g.blockedBy)" 'the blocked issue is skipped and names its blocker'
        Assert-Equal 'True' "$($g.parkedMixedCase)" 'a parking label spelled Needs-Decision parks the row, its tooltip naming the owner''s decision (#2688)'
        Assert-Equal 'True' "$($g.sweepCounts)" 'the counts are Sweepable and Skip'
        Assert-Equal 'True' "$($g.noQuietPills)" 'In progress, Filed and Waiting carry no pill and no count'
        Assert-Equal '1:12,2:2,3:1,4:13' (Join-N $g.order) 'rows appear newest first, each led by its issue number (#2 waits on #1, and still comes above it)'
        Assert-Equal 1 $g.githubCalls 'one GraphQL round trip when nothing needs a second page'
        Assert-Equal 'https://api.github.com/graphql' $g.githubUrl 'it reads GitHub GraphQL and nothing else'
        Assert-Equal 'Bearer ghs_FAKE' $g.githubAuth '...with the GITHUB_TOKEN from env'
        Assert-Equal 'False' "$($g.pathTokenSentToGithub)" 'the path token is never sent to GitHub'
        Assert-Equal 'False' "$($g.dashboardTokenSentToGithub)" '...not even in a header'
        Assert-True ($g.cacheKeyCount -gt 0) 'the edge cache is consulted'
        Assert-Equal 'False' "$($g.cacheKeyHasToken)" 'the cache key never contains the path token'
        Write-Host '  -- the handler: the memo' -ForegroundColor DarkCyan
        $mm = $r.memo
        Assert-Equal 200 $mm.status2 'a second request inside the window is served'
        Assert-Equal $mm.before $mm.after2 '...with no further GitHub call'
        Assert-Equal $mm.keysBefore $mm.keysAfter2 '...and no edge-cache call either -- the memo sits in front of it'
        Assert-Equal 'True' "$($mm.sameBody)" '...and it is the same page'
        Assert-Equal ($mm.before * 2) $mm.after3 'after resetMemo() a request makes a new set of GitHub calls'
        Assert-Equal 200 $mm.status3 '...and is served'

        Assert-Equal 502 $r.githubError.status 'a GitHub error answers 502'
        Assert-Equal 'False' "$($r.githubError.raw)" '...and the GitHub message is not written raw'
        Assert-Equal 'True' "$($r.githubError.escaped)" '...it is escaped'
        Assert-Equal 'no-store' $r.githubError.cc '...and no-store'
        Assert-True ($r.githubError.robots -like 'noindex*') '...and noindex'

        Write-Host '  -- the handler: paging' -ForegroundColor DarkCyan
        $pg = $r.paging
        Assert-Equal 200 $pg.status 'a connection with a second page renders'
        Assert-Equal 2 $pg.requests 'only issues has a next page, so two GitHub requests'
        Assert-Equal 'False' "$($pg.firstHasAfter)" 'the first request carries no cursor'
        Assert-Equal 'True' "$($pg.firstAskedAll)" '...and asks for all five connections'
        Assert-Equal 1 $pg.secondAfterCount 'the second request carries exactly one after:'
        Assert-Equal 'True' "$($pg.secondCursor)" '...the cursor the first page returned'
        Assert-Equal 'True' "$($pg.secondIssuesOnly)" '...and asks only for issues -- prs and refs finished on page 1'
        Assert-Equal '4,3,2,1' (Join-N $pg.numbers) 'all four issues are rendered, from both pages, the higher number first on a tied date'
        Assert-Equal 'True' "$($pg.unique)" '...none twice'
        Assert-Equal 'True' "$($pg.noWarning)" '...and no incomplete-list warning is shown'
        $en = $r.endless
        Assert-Equal 200 $en.status 'a connection that never ends still renders'
        Assert-Equal 10 $en.requests 'it is stopped at exactly MAX_PAGES (10) GitHub requests'
        Assert-Equal 'True' "$($en.stopped)" '...and the page carries the "Stopped after 10 GitHub requests" warning'
        Assert-Equal 10 $en.rendered '...with what was fetched (one issue per request) rendered'

        Write-Host '  -- org mode: the logic (#2649)' -ForegroundColor DarkCyan
        $o = $r.org
        Assert-Equal 'acme/b#1,acme/a#1,acme/a#2' (Join-N $o.cross) 'a blocker in another repo of the owner is an edge: acme/b#1 comes before acme/a#1'
        Assert-Equal 0 $o.crossExternal '...and sinks nothing'
        Assert-Equal 'acme/a#1' (Join-N $o.crossBlocking) '...and the blocker lists whom it unblocks, with the repo'
        Assert-Equal 'acme/b#1,acme/a#3,acme/b#3' (Join-N $o.ties) 'ties go by issue number, then by repo name'
        Assert-Equal 'acme/b#2,acme/a#1' (Join-N $o.outside) 'a blocker outside the owner still sinks'
        Assert-Equal 'acme/b#2,acme/a#1' (Join-N $o.unfetched) '...and so does one in a repo of the owner that was not fetched'
        Assert-Equal 'Filed' $o.branch.'acme/a' 'a feat/5- branch in acme/b does not move acme/a#5'
        Assert-Equal 'In progress' $o.branch.'acme/b' '...it moves acme/b#5'
        Assert-Equal 'Filed' $o.pr.'acme/a' 'a PR closing acme/b#6 does not touch acme/a#6'
        Assert-Equal 'In review' $o.pr.'acme/b' '...even when the PR itself lives in acme/a'
        Assert-Equal 1 @($o.cycleWarnings).Count 'a cycle across two repos warns once'
        Assert-True ((@($o.cycleWarnings)[0]) -like '*acme/a#1, acme/b#1*') '...naming each member with its repo'

        Write-Host '  -- org mode: the handler' -ForegroundColor DarkCyan
        $oh = $r.orgHandler
        Assert-Equal 200 $oh.status 'an org dashboard renders against the stubbed GitHub'
        Assert-Equal 2 $oh.requests '...in two requests: one repository listing, one batch'
        Assert-Equal 'True' "$($oh.listedFirst)" '...listing the owner through repositoryOwner first'
        Assert-Equal 'False' "$($oh.archivedAsked)" 'an archived repository is not read'
        Assert-Equal 'False' "$($oh.noIssuesAsked)" '...nor one with issues disabled'
        Assert-Equal 'True' "$($oh.bothInOne)" 'the readable repositories are read as aliased fields of one request'
        Assert-Equal 'acme/a#1,acme/b#1' (Join-N $oh.order) 'the rows are newest first, a tied date and number going by repo name'
        Assert-Equal 'True' "$($oh.shortLinks)" '...each shows its repo name without the owner'
        Assert-Equal 'True' "$($oh.heading)" 'the page is titled after the owner'
        Assert-Equal 'True' "$($oh.noSink)" 'the cross-repo blocker is not shown as outside the list'
        Assert-Equal 'True' "$($oh.cacheKeyOrg)" 'the cache key is org:<login>'
        Assert-Equal 'False' "$($oh.cacheKeyHasToken)" '...and never holds the path token'
        Assert-Equal 'True' "$($oh.partialWarned)" 'a repository GitHub answers with null data plus an error pathed at it becomes a warning, not a 502'
        Assert-Equal 'False' "$($oh.collaboratorAsked)" 'a listed repository of another owner is not read'
        Assert-Equal 502 $r.orgHardError 'any other GitHub error still answers 502'
        Assert-Equal 503 $r.orgConfig.both.status 'GITHUB_REPO and GITHUB_ORG together are refused'
        Assert-True ($r.orgConfig.both.body -like '*not both*') '...saying so'
        Assert-Equal 503 $r.orgConfig.badOrg.status 'a GITHUB_ORG that is not a login is refused'
        Assert-True ($r.orgConfig.badOrg.body -notlike '*<x*') '...and the value is not echoed raw'
    }
}

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The script, against a temp repo (-RepoRoot)' -ForegroundColor Cyan

New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

function New-DashRepo {
    param([string]$Name, [string]$Config = '', [switch]$NoIgnore, [switch]$NoGit)
    $p = Join-Path $Fixture $Name
    New-Item -ItemType Directory -Path (Join-Path $p 'scripts') -Force | Out-Null
    if ($Config) { [System.IO.File]::WriteAllText((Join-Path $p 'scripts\repo-config.ps1'), $Config, $Utf8NoBom) }
    if (-not $NoGit) { Invoke-FixtureGitJudged -Arguments @('init', '-q', $p) }
    # The script refuses to prepare a token git would commit, so the happy paths carry the ignore line.
    if (-not $NoIgnore) { [System.IO.File]::WriteAllText((Join-Path $p '.gitignore'), "/dkj-policy/dashboard/`n", $Utf8NoBom) }
    return $p
}

# stderr goes to a file (never 2>&1): see the sibling suites for why. Lines keeps the stdout line
# structure, Text is the whole run flattened so one sentence can be quoted across a wrap.
function Invoke-Dash {
    param([string]$Root, [string[]]$ScriptArgs = @())
    $errFile = Join-Path $Fixture "stderr-$([guid]::NewGuid().ToString('n')).txt"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-RepoRoot', $Root) + $ScriptArgs
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell @all 2>$errFile
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $err = ''
    if (Test-Path -LiteralPath $errFile) {
        $err = [System.IO.File]::ReadAllText($errFile)
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    $lines = @($out | ForEach-Object { "$_" })
    $text  = (($lines -join "`n") + "`n" + $err) -replace '\s+', ' '
    return [pscustomobject]@{ Text = $text; Lines = $lines; ExitCode = $code }
}

$cfg = "function Get-RepoName { return 'acme/widgets' }"
$repo = New-DashRepo 'repo1' $cfg
$dash = Join-Path $repo 'dkj-policy\dashboard'
$tokenFile = Join-Path $dash 'dashboard-path-token.txt'

$none = Invoke-Dash $repo
Assert-True ($none.ExitCode -ne 0) 'no switch at all is refused'
Assert-True ($none.Text -like '*Nothing to do*') '...saying so'

$noTok = Invoke-Dash $repo @('-EmitWorker')
Assert-True ($noTok.ExitCode -ne 0) '-EmitWorker without a token is refused'
Assert-True ($noTok.Text -like '*does NOT invent one*') '...and says a token is never invented on this path'
Assert-True (-not (Test-Path -LiteralPath $tokenFile)) '...and it wrote no token'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dash 'issue-dashboard-worker.js'))) '...and copied no worker'

$init = Invoke-Dash $repo @('-InitToken')
Assert-Equal 0 $init.ExitCode '-InitToken creates the token'
Assert-True (Test-Path -LiteralPath $tokenFile) '...at dkj-policy/dashboard/dashboard-path-token.txt'
$token = [System.IO.File]::ReadAllText($tokenFile)
Assert-True ($token -cmatch '^[0-9a-f]{32}$') '...32 lowercase hex characters, and nothing else in the file'
Assert-True ($init.Text -notlike "*$token*") '...and the run does not print it'
Assert-True ($init.Text -notmatch '(?i)warning') '...and a gitignored token file raises no warning'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dash 'wrangler.toml'))) '-InitToken alone writes no wrangler.toml'

$again = Invoke-Dash $repo @('-InitToken')
Assert-True ($again.ExitCode -ne 0) 'a second -InitToken is refused -- it would 404 every link already sent'
Assert-True ($again.Text -like '*already exists*') '...naming the file'
Assert-Equal $token ([System.IO.File]::ReadAllText($tokenFile)) '...and the token is untouched'

$emit = Invoke-Dash $repo @('-EmitWorker')
Assert-Equal 0 $emit.ExitCode '-EmitWorker succeeds with a token'
foreach ($f in 'issue-dashboard-worker.js', 'issue-dashboard-logic.js') {
    $dst = Join-Path $dash $f
    Assert-True (Test-Path -LiteralPath $dst) "$f is copied into the dashboard directory"
    Assert-Equal (Get-FileHash -LiteralPath (Join-Path $WorkerDir $f) -Algorithm SHA256).Hash (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash "...byte-identical to the shipped source ($f)"
}
$tomlPath = Join-Path $dash 'wrangler.toml'
Assert-True (Test-Path -LiteralPath $tomlPath) 'wrangler.toml is written'
$toml = [System.IO.File]::ReadAllText($tomlPath)
Assert-True ($toml -match '(?m)^main = "issue-dashboard-worker\.js"$') '...deploying the worker file (main = issue-dashboard-worker.js)'
Assert-True ($toml -match '(?m)^\[vars\]\s*$') '...with a [vars] table'
Assert-True ($toml -match '(?m)^GITHUB_REPO = "acme/widgets"$') '...carrying GITHUB_REPO from Get-RepoName'
Assert-True ($toml -match '(?m)^name = "widgets-issue-dashboard"$') '...named <repo>-issue-dashboard by default'
Assert-True ($toml -notmatch '(?m)^\s*(GITHUB_TOKEN|DASHBOARD_TOKEN)\s*=') '...and never a secret as a var'
Assert-True ($toml -notmatch $token) '...and never the path token'
Assert-True ($toml -notmatch '(?m)^\s*account_id') '...and no account id'
Assert-True ($toml -match '(?m)^\[observability\]\s*\r?\nenabled = false\s*$') '...and [observability] enabled = false, because request URLs carry the token and Workers Logs would record them'
# Every line is blank, a comment, a table header or a key = value: a backtick-n in the expandable
# here-string once broke a comment and left a bare 'px wrangler ...' line that wrangler refuses (#2647).
$strayTomlLines = @(($toml -split '\r?\n') | Where-Object { $_ -notmatch '^\s*($|#|\[[A-Za-z0-9_.-]+\]\s*$|[A-Za-z0-9_-]+\s*=\s*\S)' })
Assert-Equal 0 $strayTomlLines.Count "...and every line is valid TOML shape (blank, comment, [table] or key = value); stray: $($strayTomlLines -join ' | ')"

# npx.cmd on Windows, where 'npx' resolves to npx.ps1 and the default execution policy blocks it (#2651).
$npx = if ($env:OS -eq 'Windows_NT') { 'npx.cmd' } else { 'npx' }
Assert-True ($emit.Text -like "*$npx wrangler secret put GITHUB_TOKEN*")    "it prints the GITHUB_TOKEN secret command, as $npx"
Assert-True ($emit.Text -like "*$npx wrangler secret put DASHBOARD_TOKEN*") '...the DASHBOARD_TOKEN secret command'
Assert-True ($emit.Text -like "*$npx wrangler deploy*")                     '...and the deploy command'
if ($env:OS -eq 'Windows_NT') {
    Assert-Equal 0 @($emit.Lines | Where-Object { $_ -match '(^|[\s''])npx wrangler' }).Count '...and on Windows no line names the bare npx the execution policy blocks'
}
$cdLine = @($emit.Lines | Where-Object { $_ -match '^\s*cd\s' })
Assert-Equal 1 $cdLine.Count 'it prints one cd line, so wrangler runs from the dashboard directory (#2581)'
Assert-True ($cdLine[0] -like "*$dash*") '...to that directory, not the repo root'
$cmdLines = @($emit.Lines | Where-Object { $_ -match '^\s*(cd |npx(\.cmd)? )' })
Assert-Equal 4 $cmdLines.Count 'the printed commands are cd + two secret puts + deploy'
Assert-Equal 0 @($cmdLines | Where-Object { $_.Contains($token) }).Count 'no command line contains the token'
Assert-Equal 0 @($emit.Lines | Where-Object { $_ -match 'wrangler' -and $_.Contains($token) }).Count '...and no line mentioning wrangler does'
Assert-True ($emit.Text -notlike "*$token*") 'the token value appears nowhere in the -EmitWorker output, not even as part of a URL'
Assert-Equal 0 @($emit.Lines | Where-Object { $_.Contains($token) }).Count '...on no output line'
Assert-True ($emit.Text -like '*/issues/<contents of *dashboard-path-token.txt>*') 'the URL is printed as a shape, with a placeholder naming the token file'
Assert-True ($emit.Text -like '*<your-subdomain>.workers.dev*') '...and the subdomain as a placeholder'
Assert-True ($emit.Text -notmatch '(?i)warning') '...and a gitignored token file raises no warning'
Assert-True ($emit.Text -like '*deploys nothing*') 'it states that it deploys nothing'

# wrangler.toml is written once, and drift is reported, not corrected.
[System.IO.File]::AppendAllText($tomlPath, "`n# my account id lives here`n", $Utf8NoBom)
$tomlBefore = [System.IO.File]::ReadAllText($tomlPath)
[System.IO.File]::WriteAllText((Join-Path $dash 'issue-dashboard-logic.js'), '// tampered', $Utf8NoBom)
$re = Invoke-Dash $repo @('-EmitWorker')
Assert-Equal 0 $re.ExitCode 'a second -EmitWorker succeeds'
Assert-Equal $tomlBefore ([System.IO.File]::ReadAllText($tomlPath)) 'an existing wrangler.toml is never overwritten'
Assert-True ($re.Text -like '*left as it is*') '...and the run says so'
Assert-True ($re.Text -notmatch 'does not set \[observability\]') '...with no observability warning while it is off'
Assert-True (($re.Text -notmatch "deploys '") -and ($re.Text -notmatch 'serves issues of')) '...and no drift warning while name and GITHUB_REPO match'
Assert-True ($re.Text -notlike "*$token*") '...and the token is not printed'
Assert-Equal (Get-FileHash -LiteralPath $LogicPath -Algorithm SHA256).Hash (Get-FileHash -LiteralPath (Join-Path $dash 'issue-dashboard-logic.js') -Algorithm SHA256).Hash 'the worker files, being derivatives, ARE refreshed'
Assert-Equal $token ([System.IO.File]::ReadAllText($tokenFile)) 'and the token is untouched'

[System.IO.File]::WriteAllText($tomlPath, ($tomlBefore -replace 'name = "widgets-issue-dashboard"', 'name = "other-name"' -replace 'GITHUB_REPO = "acme/widgets"', 'GITHUB_REPO = "elsewhere/repo"'), $Utf8NoBom)
$drift = Invoke-Dash $repo @('-EmitWorker')
Assert-Equal 0 $drift.ExitCode 'a drifted wrangler.toml does not fail the run'
Assert-True ($drift.Text -like "*deploys 'other-name'*") '...it warns about the drifted worker name'
Assert-True ($drift.Text -like "*serves issues of 'elsewhere/repo'*") '...and the drifted GITHUB_REPO'
Assert-True ([System.IO.File]::ReadAllText($tomlPath) -match 'other-name') '...without correcting either'
Assert-True ($drift.Text -notlike "*$token*") '...and the token is not printed'

# Each drift warning on its own, so neither can be produced by the other's condition.
[System.IO.File]::WriteAllText($tomlPath, ($tomlBefore -replace 'name = "widgets-issue-dashboard"', 'name = "only-name"'), $Utf8NoBom)
$dName = Invoke-Dash $repo @('-EmitWorker')
Assert-True ($dName.Text -like "*deploys 'only-name'*") 'a drifted worker name alone is warned about'
Assert-True ($dName.Text -notlike '*serves issues of*') '...without a GITHUB_REPO warning'
[System.IO.File]::WriteAllText($tomlPath, ($tomlBefore -replace 'GITHUB_REPO = "acme/widgets"', 'GITHUB_REPO = "elsewhere/repo"'), $Utf8NoBom)
$dRepo = Invoke-Dash $repo @('-EmitWorker')
Assert-True ($dRepo.Text -like "*serves issues of 'elsewhere/repo'*") 'a drifted GITHUB_REPO alone is warned about'
Assert-True ($dRepo.Text -notmatch "deploys '") '...without a name warning'

# An existing wrangler.toml without observability off is warned about, not edited.
$noObs = $tomlBefore -replace '(?m)^\[observability\]\r?\nenabled = false\r?\n', ''
Assert-True ($noObs -ne $tomlBefore) '(fixture: the observability block was stripped from the copy)'
[System.IO.File]::WriteAllText($tomlPath, $noObs, $Utf8NoBom)
$obs = Invoke-Dash $repo @('-EmitWorker')
Assert-Equal 0 $obs.ExitCode 'a wrangler.toml without [observability] does not fail the run'
Assert-True ($obs.Text -match 'does not set \[observability\] enabled = false') '...it warns that Workers Logs would record the token URLs'
Assert-Equal $noObs ([System.IO.File]::ReadAllText($tomlPath)) '...and does not edit the file'
[System.IO.File]::WriteAllText($tomlPath, ($tomlBefore -replace '(?m)^enabled = false', 'enabled = true'), $Utf8NoBom)
$obsOn = Invoke-Dash $repo @('-EmitWorker')
Assert-True ($obsOn.Text -match 'does not set \[observability\] enabled = false') '...and so does [observability] enabled = true'
[System.IO.File]::WriteAllText($tomlPath, $tomlBefore, $Utf8NoBom)

# A wrangler.toml at the root is a hazard the run names.
[System.IO.File]::WriteAllText((Join-Path $repo 'wrangler.toml'), 'name = "root-project"', $Utf8NoBom)
$rootToml = Invoke-Dash $repo @('-EmitWorker')
Assert-True ($rootToml.Text -like '*wrangler.toml stands at the repository root*') 'a wrangler.toml at the repo root is warned about (#2581)'

# The optional seam names the worker; an invalid name is refused; no Get-RepoName and no gh answer is refused.
$repo2 = New-DashRepo 'repo2' "function Get-RepoName { return 'acme/widgets' }`nfunction Get-IssueDashboardWorkerName { return 'my-board' }"
$both = Invoke-Dash $repo2 @('-InitToken', '-EmitWorker')
Assert-Equal 0 $both.ExitCode '-InitToken -EmitWorker together work on a fresh repo'
$token2 = [System.IO.File]::ReadAllText((Join-Path $repo2 'dkj-policy\dashboard\dashboard-path-token.txt'))
Assert-True (($token2 -cmatch '^[0-9a-f]{32}$') -and ($both.Text -notlike "*$token2*")) '...and the freshly minted token appears nowhere in the combined output'
Assert-True ([System.IO.File]::ReadAllText((Join-Path $repo2 'dkj-policy\dashboard\wrangler.toml')) -match '(?m)^name = "my-board"$') 'Get-IssueDashboardWorkerName names the worker'

$repo3 = New-DashRepo 'repo3' "function Get-RepoName { return 'acme/widgets' }`nfunction Get-IssueDashboardWorkerName { return 'Bad Name' }"
$bad = Invoke-Dash $repo3 @('-InitToken', '-EmitWorker')
Assert-True ($bad.ExitCode -ne 0) 'a worker name Cloudflare would refuse is refused first'
Assert-True ($bad.Text -like '*not a valid Cloudflare Worker name*') '...saying why'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo3 'dkj-policy\dashboard\wrangler.toml'))) '...before any wrangler.toml is written'

# ORG MODE (#2649): a dashboard of its own beside this repo's, in repo1, which already holds a token.
Remove-Item -LiteralPath (Join-Path $repo 'wrangler.toml') -Force   # the root-toml case above is done
$orgDash = Join-Path $repo 'dkj-policy\dashboard\org-acme'
$org = Invoke-Dash $repo @('-Org', 'Acme', '-InitToken', '-EmitWorker')
Assert-Equal 0 $org.ExitCode '-Org -InitToken -EmitWorker works beside an existing repo dashboard'
Assert-True ($org.Text -notlike '*already holds one*') '...the repo dashboard token is a sibling, not a stray'
$orgToken = [System.IO.File]::ReadAllText((Join-Path $orgDash 'dashboard-path-token.txt'))
Assert-True ($orgToken -cmatch '^[0-9a-f]{32}$') '...its token lives in dkj-policy/dashboard/org-acme/'
Assert-True ($orgToken -ne $token) '...and is not the repo dashboard token'
Assert-Equal $token ([System.IO.File]::ReadAllText($tokenFile)) '...which is untouched'
$orgToml = [System.IO.File]::ReadAllText((Join-Path $orgDash 'wrangler.toml'))
Assert-True ($orgToml -match '(?m)^GITHUB_ORG = "Acme"$') 'its wrangler.toml carries GITHUB_ORG'
Assert-True ($orgToml -notmatch '(?m)^\s*GITHUB_REPO') '...and no GITHUB_REPO'
Assert-True ($orgToml -match '(?m)^name = "acme-issue-dashboard"$') '...and is named <login>-issue-dashboard'
Assert-True ($orgToml -match '(?m)^\[observability\]\s*\r?\nenabled = false\s*$') '...with observability off'
Assert-True (Test-Path -LiteralPath (Join-Path $orgDash 'issue-dashboard-worker.js')) '...and the worker files copied in'
Assert-True ($org.Text -like '*resource owner Acme*') 'it names the PAT the org worker needs'
Assert-True ($org.Text -like '*wrangler whoami*') '...and says to check which Cloudflare account wrangler is logged in to'
Assert-True ($org.Text -notlike "*$orgToken*") '...and never prints the token'
$orgCd = @($org.Lines | Where-Object { $_ -match '^\s*cd\s' })
Assert-True ($orgCd.Count -eq 1 -and $orgCd[0] -like "*org-acme*") 'the printed cd goes to the org dashboard directory'
$orgAgain = Invoke-Dash $repo @('-Org', 'Acme', '-InitToken')
Assert-True ($orgAgain.ExitCode -ne 0) 'a second -Org -InitToken refuses to replace its token'
$repoAgain = Invoke-Dash $repo @('-EmitWorker')
Assert-Equal 0 $repoAgain.ExitCode 'the repo dashboard still emits with an org dashboard beside it'
Assert-True ($repoAgain.Text -notmatch '(?i)warning') '...without a warning'
[System.IO.File]::AppendAllText((Join-Path $orgDash 'wrangler.toml'), "`nGITHUB_REPO = `"acme/widgets`"`n", $Utf8NoBom)
$orgBoth = Invoke-Dash $repo @('-Org', 'Acme', '-EmitWorker')
Assert-True ($orgBoth.Text -like '*sets GITHUB_REPO as well as GITHUB_ORG*') 'an org wrangler.toml that also sets GITHUB_REPO is warned about'
$badOrg = Invoke-Dash $repo @('-Org', 'not/a-login', '-InitToken')
Assert-True ($badOrg.ExitCode -ne 0) 'an -Org that is not a GitHub login is refused'
Assert-True ($badOrg.Text -like '*not a GitHub login*') '...saying why'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo 'dkj-policy\dashboard\org-not'))) '...before anything is written'

# The stray-token search: a renamed dkj-policy folder leaves the gitignored token behind.
$repo4 = New-DashRepo 'repo4' $cfg
$strayDir = Join-Path $repo4 'old-policy\dashboard'
New-Item -ItemType Directory -Path $strayDir -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $strayDir 'dashboard-path-token.txt'), $HexA, $Utf8NoBom)
$stray = Invoke-Dash $repo4 @('-InitToken')
Assert-True ($stray.ExitCode -ne 0) '-InitToken refuses while a token sits elsewhere in the tree'
Assert-True ($stray.Text -like '*old-policy*') '...naming where it found it'
Assert-True ($stray.Text -like '*MOVE that folder here*') '...and saying to move it rather than mint a second one'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo4 'dkj-policy\dashboard\dashboard-path-token.txt'))) '...and minted nothing'
$strayEmit = Invoke-Dash $repo4 @('-EmitWorker')
Assert-True ($strayEmit.ExitCode -ne 0) '-EmitWorker without the token refuses the same way'
Assert-True ($strayEmit.Text -like '*already holds one*') '...leading with what it found'

# The token file must be gitignored: refused before anything is written, in both entry points.
$repo6 = New-DashRepo 'repo6' $cfg -NoIgnore
$noIgnInit = Invoke-Dash $repo6 @('-InitToken')
Assert-True ($noIgnInit.ExitCode -ne 0) '-InitToken is refused when git does not ignore the token path'
Assert-True ($noIgnInit.Text -like '*NOT gitignored*') '...saying so'
Assert-True ($noIgnInit.Text -like '*/dkj-policy/dashboard/*') '...and naming the .gitignore line to add'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo6 'dkj-policy\dashboard\dashboard-path-token.txt'))) '...and no token file was written'
$dash6 = Join-Path $repo6 'dkj-policy\dashboard'
New-Item -ItemType Directory -Path $dash6 -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dash6 'dashboard-path-token.txt'), $HexB, $Utf8NoBom)
$noIgnEmit = Invoke-Dash $repo6 @('-EmitWorker')
Assert-True ($noIgnEmit.ExitCode -ne 0) '-EmitWorker is refused when git does not ignore the token path'
Assert-True ($noIgnEmit.Text -like '*NOT gitignored*') '...saying so'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dash6 'wrangler.toml'))) '...and wrote no wrangler.toml'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $dash6 'issue-dashboard-worker.js'))) '...and copied no worker'
Assert-True ($noIgnEmit.Text -notlike "*$HexB*") '...and never prints the token'
[System.IO.File]::WriteAllText((Join-Path $repo6 '.gitignore'), "/dkj-policy/dashboard/`n", $Utf8NoBom)
Assert-Equal 0 (Invoke-Dash $repo6 @('-EmitWorker')).ExitCode '...and the same repo passes once the line is added'

# Where git cannot answer (not a repository) the run warns and carries on.
$repo7 = New-DashRepo 'repo7' $cfg -NoIgnore -NoGit
$noGit = Invoke-Dash $repo7 @('-InitToken')
Assert-Equal 0 $noGit.ExitCode '-InitToken outside a git repository still runs'
Assert-True ($noGit.Text -like '*Could not ask git*') '...with a warning that it could not ask git'
Assert-True (Test-Path -LiteralPath (Join-Path $repo7 'dkj-policy\dashboard\dashboard-path-token.txt')) '...and creates the token'

# A hand-damaged token is refused, not shipped.
$repo5 = New-DashRepo 'repo5' $cfg
Assert-Equal 0 (Invoke-Dash $repo5 @('-InitToken')).ExitCode 'a fifth repo gets a token'
[System.IO.File]::WriteAllText((Join-Path $repo5 'dkj-policy\dashboard\dashboard-path-token.txt'), $HexA.ToUpperInvariant(), $Utf8NoBom)
$upper = Invoke-Dash $repo5 @('-EmitWorker')
Assert-True ($upper.ExitCode -ne 0) 'an UPPERCASE token file is refused -- the worker route only matches lowercase'
Assert-True ($upper.Text -like '*not 32 lowercase hex*') '...saying why'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The .gitignore anchors the dashboard directory' -ForegroundColor Cyan

$gi = [System.IO.File]::ReadAllLines((Join-Path $RepoRoot '.gitignore'))
Assert-True ($gi -contains '/dkj-policy/dashboard/') '.gitignore carries the anchored line /dkj-policy/dashboard/'
Assert-True (-not ($gi -contains 'dkj-policy/dashboard/') -and -not ($gi -contains 'dashboard/')) '...and no unanchored form that would swallow an unrelated dashboard/ folder'

function Test-GitIgnored {
    param([string]$RelPath)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git -C $RepoRoot check-ignore -q -- $RelPath 2>$null; return ($LASTEXITCODE -eq 0) } finally { $ErrorActionPreference = $prev }
}
Assert-True (Test-GitIgnored 'dkj-policy/dashboard/dashboard-path-token.txt') 'git ignores the path token file'
Assert-True (Test-GitIgnored 'dkj-policy/dashboard/wrangler.toml')            '...and the wrangler.toml'
Assert-True (-not (Test-GitIgnored 'sub/dkj-policy/dashboard/x.txt'))         'but not a dkj-policy/dashboard/ nested elsewhere'
Assert-True (-not (Test-GitIgnored 'dashboard/x.txt'))                        '...nor a bare dashboard/ folder'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The language' -ForegroundColor Cyan

$bytes = [System.IO.File]::ReadAllBytes($ScriptPath)
Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) 'issue-dashboard.ps1 is pure ASCII (repo convention)'
$thisBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
Assert-True (-not ($thisBytes | Where-Object { $_ -gt 127 })) 'this suite is pure ASCII'

if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
# A BROKEN FIXTURE FAILS THE RUN (issue #1635): the script cases read a repo git init had to build.
$fixtureBroken = Write-FixtureGitSummary -Subject 'issue-dashboard.ps1'
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0 -and -not $fixtureBroken) { 'Green' } else { 'Red' })
if ($script:fail -gt 0 -or $fixtureBroken) { exit 1 }
exit 0
