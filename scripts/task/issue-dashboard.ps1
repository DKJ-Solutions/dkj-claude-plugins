<#
.SYNOPSIS
    Prepares the OPTIONAL live issue dashboard: the path token and the Cloudflare Worker bundle that
    serves this repo's open GitHub issues, with a status and a pick-up order. Deploys nothing.

.DESCRIPTION
    WHAT THE DASHBOARD IS (issue #2643). A Cloudflare Worker that reads the repo's open issues, open
    pull requests and feat/fix/docs branches through the GitHub API on every (cached) view, derives a
    status per issue and orders them by their blocked-by dependencies. It is LIVE, not a snapshot --
    the opposite of build-release-notes-page.ps1, which builds a page once. The worker itself is two
    static files shipped with the plugin (worker/issue-dashboard-worker.js and
    worker/issue-dashboard-logic.js). They carry NO content, no token and no repository name:
    everything comes from the worker's environment. So this script has almost nothing to generate,
    and what it does write is only the local scaffolding around them.

    WHAT IT WRITES, all into the gitignored dkj-policy/dashboard/ directory:

      - dashboard-path-token.txt   with -InitToken. 32 lowercase hex, written ONCE, never replaced.
      - issue-dashboard-worker.js and issue-dashboard-logic.js   with -EmitWorker, copied verbatim
        from the plugin (overwritten each run -- they are derivatives, not yours to edit).
      - wrangler.toml   with -EmitWorker, written ONLY WHEN ABSENT and yours from then on.

    THE PATH TOKEN IS THE ONLY LOCK. The worker answers GET|HEAD /issues/<token> and every other request
    with the same 404; there is no login. So, exactly as with the release-notes page, a token invented
    on the fly would not mean "a new path", it would mean every link already sent now 404s. Missing
    token is therefore an error with a recovery instruction, and -InitToken is the separate, explicit
    way to create the first one. The token also has to be set as the DASHBOARD_TOKEN worker secret, so
    a deployed worker's secret is NOT readable back from Cloudflare the way the release-notes route
    literal is -- keep the token file, and record the finished URL somewhere you will find it again.

    IT DEPLOYS NOTHING AND NEVER READS A SECRET. It PRINTS the commands and you run them, because
    publishing is outward-facing and because a secret must not pass through a script's output:

      cd <dashboard dir>
      npx wrangler secret put GITHUB_TOKEN      (a fine-grained PAT, see below)
      npx wrangler secret put DASHBOARD_TOKEN   (paste the contents of dashboard-path-token.txt)
      npx wrangler deploy

    The only secret-adjacent file it touches is the path token file. It never puts that value into a
    command line (wrangler prompts for the secret value, which is where you paste it) and it never
    prints the full URL either: it prints the URL SHAPE and names the file, because terminal output
    lands in agent transcripts and logs. The token file is the only lock; keep it out of chats and issues.

    THE TOKEN FILE MUST BE GITIGNORED, and both -InitToken and -EmitWorker check it with
    `git check-ignore -q`. Not ignored: -InitToken refuses before writing (in a public repo a committed
    token is a published lock) and names the .gitignore line to add, /dkj-policy/dashboard/; -EmitWorker
    refuses likewise. Where git itself is unavailable or the root is not a repo, it only warns.

    wrangler.toml IS WRITTEN WITH [observability] enabled = false: request URLs carry the token, and
    Workers Logs would record them.

    RUN WRANGLER FROM THE DASHBOARD DIRECTORY, NEVER FROM THE REPOSITORY ROOT (issue #2581). Run from
    the root, wrangler finds no wrangler.toml, guesses a project from package.json or the working
    directory and deploys the wrong thing, or asks for an entry point; the printed commands therefore
    start with a cd. This script also refuses to write its output into the root itself, and warns when
    a wrangler.toml already stands at the root, because that is the file a root-run wrangler would
    pick up instead.

    GITHUB_TOKEN NEEDS EXACTLY THESE PERMISSIONS on a FINE-GRAINED personal access token scoped to
    this ONE repository: Issues (read), Pull requests (read), Contents (read), Metadata (read). Nothing
    that writes. The worker cannot change an issue, so a leaked worker secret can read what the token
    can read and no more.

    THE WORKER NAME is Get-IssueDashboardWorkerName from the repo's own scripts/repo-config.ps1 when it
    is answered -- optional, and unlike the release-notes seam an empty answer does not refuse, because
    the dashboard is opt-in by running this script at all. The default is '<repo>-issue-dashboard'.
    GITHUB_REPO in wrangler.toml comes from Get-RepoName, else from `gh repo view`.

    A wrangler.toml THAT ALREADY EXISTS IS NEVER REWRITTEN, and a name, GITHUB_REPO or observability
    setting that has drifted from what this script would write is reported rather than corrected: which of the two is wrong is
    not this script's to decide. Same reasoning as build-release-notes-page.ps1 (#1479): an absent one
    is also reported, since it is as likely to mean the gitignored directory was rebuilt from nothing
    as a first run, and whatever you had added (an account id, a route) is not in the fresh one.

    Dual-context: run the root copy in this repo, the plugin mirror in a consumer. The worker files
    live only under the plugin's worker/ folder; both copies find them there.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER InitToken
    Create the path token when there is none. Deliberately explicit: see the token note above.
    Refuses when the token file is not gitignored.
    Refuses to overwrite an existing token, and refuses when a token stands anywhere else in the tree.

.PARAMETER EmitWorker
    Copy the two worker files into the dashboard directory and write wrangler.toml if it is absent,
    then print the secret and deploy commands. Requires a path token (-InitToken first), gitignored.

.PARAMETER Org
    ORG MODE (issue #2649): prepare a dashboard for EVERY repository of this GitHub owner (an
    organization or a user) instead of for this repo. Its files go into their own directory,
    dkj-policy/dashboard/org-<login>/, with its own path token and its own wrangler.toml carrying
    [vars] GITHUB_ORG, so one checkout can prepare several dashboards side by side. The worker is named
    '<login>-issue-dashboard'; Get-IssueDashboardWorkerName names only this repo's own dashboard. The
    GITHUB_TOKEN of an org worker is a fine-grained PAT whose resource owner is that org, with access
    to all of its repositories -- one PAT per owner, because a fine-grained PAT has exactly one.

.PARAMETER RepoRoot
    The repository root to read and write in, instead of the one git (or CLAUDE_PROJECT_DIR) names.
    A test seam; a consumer never types it.

.EXAMPLE
    ./scripts/task/issue-dashboard.ps1 -InitToken -EmitWorker
    First-time setup: creates the token, emits the worker, and prints the commands to run.

.EXAMPLE
    ./scripts/task/issue-dashboard.ps1 -Org DKJ-Solutions -InitToken -EmitWorker
    First-time setup of a dashboard over every repository of the DKJ-Solutions organization.

.EXAMPLE
    ./scripts/task/issue-dashboard.ps1 -EmitWorker
    Refreshes the two worker files after a plugin update and prints the deploy commands again.
#>
[CmdletBinding()]
param(
    [switch]$InitToken,
    [switch]$EmitWorker,
    [string]$Org,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined: the seam probe reads the function table directly (issue #1729) rather than
# through Get-Command, which treats the name as a wildcard and scans PATH on every miss.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
# Find-StrayToken: a token left behind by a renamed dkj-policy folder (issues #1444, #2644).
. (Join-Path $PSScriptRoot '..\lib\stray-token-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RepoRoot -ScriptName 'issue-dashboard.ps1' -OverrideName '-RepoRoot'

if (-not $InitToken -and -not $EmitWorker) {
    throw ("Nothing to do: pass -InitToken (create the path token, once) and/or -EmitWorker (copy the " +
           "worker and write wrangler.toml, then print the deploy commands). See the issue-dashboard skill.")
}

# --- 1. The repo's own answers ----------------------------------------------------------------------
# Probed in a CHILD scope with StrictMode off: repo-config.ps1 is written on the assumption that its
# runtime callers do not run under Latest. Every value has a fallback.
$config = & {
    Set-StrictMode -Off
    $answers = @{ WorkerName = ''; Repo = '' }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $answers }
    try { . $configPath } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded ($(Format-SafeProseToken -Value $_.Exception.Message)) -- using the built-in defaults."
        return $answers
    }
    if (Test-FunctionDefined 'Get-IssueDashboardWorkerName') { $answers.WorkerName = [string](Get-IssueDashboardWorkerName) }
    if (Test-FunctionDefined 'Get-RepoName') { $answers.Repo = [string](Get-RepoName) }
    return $answers
} $repoRoot

# ORG MODE gets a directory of its own under the dashboard root (#2649), so this repo's dashboard and
# any number of owner dashboards stand side by side, each with its own token and wrangler.toml.
if ($Org -and $Org -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$') {
    throw "-Org '$Org' is not a GitHub login (letters, digits and hyphens, at most 39 characters)."
}
$dashRoot  = Join-Path $repoRoot 'dkj-policy\dashboard'
$dashRel   = if ($Org) { "dkj-policy/dashboard/org-$($Org.ToLowerInvariant())" } else { 'dkj-policy/dashboard' }
$dashDir   = if ($Org) { Join-Path $dashRoot "org-$($Org.ToLowerInvariant())" } else { $dashRoot }
$tokenPath = Join-Path $dashDir 'dashboard-path-token.txt'
$tokenRel  = "$dashRel/dashboard-path-token.txt"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# NEVER THE ROOT (issue #2581). The directory is a fixed child of the root, so this cannot fire
# through the parameters; it is here for whoever changes the constant above.
if ((Split-Path -Parent (Split-Path -Parent $dashRoot)).TrimEnd('\', '/') -ne $repoRoot.TrimEnd('\', '/')) {
    throw "The dashboard directory must be a child of the repository root, never the root itself: $dashRoot"
}

function Find-DashboardStrayToken {
    <# Find-StrayToken, minus the tokens of the OTHER dashboards under the dashboard root: those are
       siblings with their own directory (#2649), not debris of a moved folder. #>
    $prefix = $dashRoot.TrimEnd('\') + '\'
    return @(Find-StrayToken -Root $repoRoot -ExpectedPath $tokenPath -FileName 'dashboard-path-token.txt' |
             Where-Object { -not $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
}

function Get-DashboardRepoSlug {
    <# The owner/name GITHUB_REPO is set to: the repo's own Get-RepoName, else what gh says. '' if neither answers. #>
    param([string]$FromConfig)
    if ($FromConfig -match '^[\w.-]+/[\w.-]+$') { return $FromConfig }
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'   # native stderr must not become a terminating error under Stop
        try { $slug = (& gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null) } catch { $slug = $null } finally { $ErrorActionPreference = $prev }
        if ($LASTEXITCODE -eq 0 -and $slug) {
            $slug = ([string]($slug | Select-Object -First 1)).Trim()
            if ($slug -match '^[\w.-]+/[\w.-]+$') { return $slug }
        }
    }
    return ''
}

function Get-TokenIgnoreState {
    <# 'ignored' (git check-ignore exit 0), 'not-ignored' (exit 1), or 'unknown' (git missing, not a repo, other error). #>
    param([Parameter(Mandatory = $true)][string]$Root)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return 'unknown' }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # native stderr must not become a terminating error under Stop
    try {
        & git -C $Root check-ignore -q -- $tokenRel 2>$null | Out-Null
        $code = $LASTEXITCODE
    } catch { return 'unknown' } finally { $ErrorActionPreference = $prev }
    if ($code -eq 0) { return 'ignored' }
    if ($code -eq 1) { return 'not-ignored' }
    return 'unknown'
}

function Assert-TokenIgnored {
    <# Refuses when the token file would be committable; warns when git cannot say. #>
    param([Parameter(Mandatory = $true)][string]$Root)
    switch (Get-TokenIgnoreState -Root $Root) {
        'not-ignored' {
            throw ("The path token file ($tokenRel) is NOT gitignored, so it " +
                   "could be committed -- and the token is the only lock on the dashboard. Add this line to " +
                   ".gitignore and run again: /dkj-policy/dashboard/")
        }
        'unknown' {
            Write-Warning "Could not ask git whether dkj-policy/dashboard/ is gitignored (git missing or not a repository). Make sure /dkj-policy/dashboard/ is in .gitignore: the token file must never be committed."
        }
    }
}

if (-not (Test-Path -LiteralPath $dashDir)) { New-Item -ItemType Directory -Force -Path $dashDir | Out-Null }

# --- 2. -InitToken ----------------------------------------------------------------------------------
if ($InitToken) {
    if (Test-Path -LiteralPath $tokenPath -PathType Leaf) {
        throw ("A path token already exists at $tokenPath. This script does not replace one: the URL " +
               "carrying it has been sent, so a new token means every existing link 404s. Delete the " +
               "file deliberately if that is genuinely what you want.")
    }
    # @( ) at the call site: PowerShell unrolls a returned empty array to $null, and StrictMode Latest
    # then refuses .Count on it.
    $strays = @(Find-DashboardStrayToken)
    if ($strays.Count -gt 0) {
        throw ("There is no token at $tokenPath, but this tree already holds one: $($strays -join ', '). " +
               "That is what a renamed or repointed dkj-policy folder leaves behind -- the directory is " +
               "gitignored, so it stayed where it was while everything tracked moved. MOVE that folder " +
               "here instead of creating a second token, which 404s every link already sent. Delete the " +
               "copy deliberately if it is genuinely dead.")
    }
    Assert-TokenIgnored -Root $repoRoot
    $newToken = [guid]::NewGuid().ToString('N')
    [System.IO.File]::WriteAllText($tokenPath, $newToken, $Utf8NoBom)
    Write-Host "== issue-dashboard ==" -ForegroundColor Cyan
    Write-Host "  token    : $tokenPath (created)" -ForegroundColor Yellow
    Write-Host "  IT IS THE ONLY LOCK ON THE DASHBOARD. Keep the file: it is gitignored, so nothing else remembers" -ForegroundColor Yellow
    Write-Host "  it. Do not paste its content into chats or issues." -ForegroundColor Yellow
}

if (-not $EmitWorker) { exit 0 }

# --- 3. -EmitWorker ---------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    $strays = @(Find-DashboardStrayToken)
    $lead = if ($strays.Count -gt 0) {
        "This tree already holds one, at $($strays -join ', '). The directory is gitignored, so it did " +
        "not travel with a renamed or repointed dkj-policy folder: MOVE that folder here rather than " +
        "creating a second token. "
    } else { '' }
    throw ("The path token is missing: $tokenPath. " + $lead + "This script does NOT invent one on an " +
           "-EmitWorker run -- the path is the only lock on the dashboard, so a fresh token means the " +
           "link already sent 404s while the deploy reports success. Restore the 32 hex characters " +
           "from the URL you have, or run -InitToken if this is the first setup.")
}
Assert-TokenIgnored -Root $repoRoot
$token = ([System.IO.File]::ReadAllText($tokenPath, [System.Text.Encoding]::UTF8)).Trim()
if ($token -cnotmatch '^[0-9a-f]{32}$') {
    throw "The path token is not 32 lowercase hex characters: $tokenPath"
}

# The worker files live only under the plugin's worker/ folder. In the plugin mirror that is two levels
# up from scripts/task; in the source repo it is under plugins/dkj-policy. Both are tried.
$workerDir = $null
foreach ($candidate in @((Join-Path $PSScriptRoot '..\..\worker'), (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\worker'))) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'issue-dashboard-worker.js') -PathType Leaf) { $workerDir = (Resolve-Path -LiteralPath $candidate).Path; break }
}
$workerFiles = @('issue-dashboard-worker.js', 'issue-dashboard-logic.js')
if (-not $workerDir) {
    throw ("The worker source is missing from this plugin: looked for worker\$($workerFiles[0]) beside the " +
           "scripts folder and under plugins\dkj-policy. Update the plugin (update-plugins) and retry.")
}
foreach ($f in $workerFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $workerDir $f) -PathType Leaf)) {
        throw "The worker source is incomplete: $(Join-Path $workerDir $f) is missing."
    }
}

# The target is this repo, or in org mode the owner; the worker name follows it.
$workerName = if ($config.WorkerName -and -not $Org) { $config.WorkerName } else { '' }
$repoSlug   = if ($Org) { '' } else { Get-DashboardRepoSlug -FromConfig $config.Repo }
if (-not $Org -and -not $repoSlug) {
    throw ("Could not tell which repository the dashboard is for: Get-RepoName is not answered in " +
           "scripts\repo-config.ps1 and `gh repo view` returned nothing. Answer Get-RepoName ('owner/name') " +
           "or authenticate gh, then retry.")
}
if (-not $workerName) {
    $base = if ($Org) { $Org } else { ($repoSlug -split '/')[-1] }
    $workerName = ($base + '-issue-dashboard').ToLowerInvariant()
}
# The one [vars] line, and the one it must never carry beside it.
$varName  = if ($Org) { 'GITHUB_ORG' } else { 'GITHUB_REPO' }
$varValue = if ($Org) { $Org } else { $repoSlug }
$otherVar = if ($Org) { 'GITHUB_REPO' } else { 'GITHUB_ORG' }
if ($workerName -notmatch '^[a-z0-9][a-z0-9-]*$') {
    throw "The worker name '$workerName' is not a valid Cloudflare Worker name (lowercase letters, digits, hyphens)."
}

foreach ($f in $workerFiles) {
    Copy-Item -LiteralPath (Join-Path $workerDir $f) -Destination (Join-Path $dashDir $f) -Force
}

# WRITTEN ONLY WHEN ABSENT, and an absent one is reported (see the header, #1479).
$wranglerPath = Join-Path $dashDir 'wrangler.toml'
if (-not (Test-Path -LiteralPath $wranglerPath -PathType Leaf)) {
    $wrangler = @"
name = "$workerName"
main = "issue-dashboard-worker.js"
compatibility_date = "2025-04-01"
workers_dev = true

# Request URLs carry the path token, and Workers Logs would record them: keep observability off.
[observability]
enabled = false

# GITHUB_TOKEN and DASHBOARD_TOKEN are SECRETS: set them with 'npx wrangler secret put', never here.
[vars]
$varName = "$varValue"

# No account_id on purpose: it is one more identifier to keep out of a public repo, and wrangler
# resolves the account from CLOUDFLARE_ACCOUNT_ID or from the token when it has only one. Add it
# here if you work across several accounts -- this file is written once and never overwritten.

"@
    [System.IO.File]::WriteAllText($wranglerPath, $wrangler, $Utf8NoBom)
    Write-Host "  wrangler : $wranglerPath (written -- it is yours from now on, never overwritten)" -ForegroundColor Yellow
    Write-Host "  NOTE: it was ABSENT. If this repo hosted a dashboard before, whatever the old file carried" -ForegroundColor Yellow
    Write-Host "  beyond the lines above (an account id, a route) is NOT in this one. A first-ever deploy is" -ForegroundColor Yellow
    Write-Host "  the legitimate case and looks identical from here, so this is a note and not a refusal." -ForegroundColor Yellow
} else {
    $existing = [System.IO.File]::ReadAllText($wranglerPath, [System.Text.Encoding]::UTF8)
    $declared = [regex]::Match($existing, '(?m)^\s*name\s*=\s*"([^"]+)"')
    if ($declared.Success -and $declared.Groups[1].Value -ne $workerName) {
        Write-Warning ("wrangler.toml deploys '$($declared.Groups[1].Value)' while this run would name it " +
                       "'$workerName' (Get-IssueDashboardWorkerName, else '<repo>-issue-dashboard'). One of the two " +
                       "is wrong -- this script does not pick.")
    }
    $declaredRepo = [regex]::Match($existing, "(?m)^\s*$varName\s*=\s*`"([^`"]+)`"")
    if ($declaredRepo.Success -and $declaredRepo.Groups[1].Value -ne $varValue) {
        Write-Warning ("wrangler.toml serves issues of '$($declaredRepo.Groups[1].Value)' while this run is for " +
                       "'$varValue'. One of the two is wrong -- this script does not pick.")
    }
    if ($existing -match "(?m)^\s*$otherVar\s*=") {
        Write-Warning ("wrangler.toml sets $otherVar as well as $varName, and the worker refuses both at once. " +
                       "Remove the one that is wrong -- this script does not edit the file.")
    }
    if ($existing -notmatch '(?ms)^\s*\[observability\][^\[]*?^\s*enabled\s*=\s*false') {
        Write-Warning ("wrangler.toml does not set [observability] enabled = false. Request URLs carry the path " +
                       "token and Workers Logs would record them. Add it if that is not deliberate -- this script does not edit the file.")
    }
    Write-Host "  wrangler : $wranglerPath (exists -- left as it is)" -ForegroundColor Green
}

# A wrangler.toml at the ROOT is the file a root-run wrangler would pick up instead (issue #2581).
if (Test-Path -LiteralPath (Join-Path $repoRoot 'wrangler.toml') -PathType Leaf) {
    Write-Warning ("A wrangler.toml stands at the repository root. Never run wrangler from the root: it would " +
                   "deploy THAT project. Run every command below from $dashDir.")
}

Write-Host "== issue-dashboard ==" -ForegroundColor Cyan
Write-Host "  worker   : $dashDir  ($($workerFiles -join ', '), copied from the plugin -- no content, no token)" -ForegroundColor Green
if ($Org) { Write-Host "  owner    : $Org (every repository the token can read)   worker name: $workerName" }
else      { Write-Host "  repo     : $repoSlug   worker name: $workerName" }
Write-Host ""
Write-Host "  Run these yourself, in order -- this script deploys nothing and never sees a secret:" -ForegroundColor Cyan
Write-Host "    cd `"$dashDir`""
Write-Host "        wrangler deploys to the Cloudflare account it is logged in to: check it with"
Write-Host "        'npx wrangler whoami' first, and log out and in again if that is not this worker's account."
Write-Host "    npx wrangler secret put GITHUB_TOKEN"
if ($Org) {
Write-Host "        fine-grained PAT with resource owner $Org and ALL its repositories: Issues read,"
Write-Host "        Pull requests read, Contents read, Metadata read. Nothing that writes. Paste it at wrangler's prompt."
} else {
Write-Host "        fine-grained PAT, THIS ONE repository only: Issues read, Pull requests read,"
Write-Host "        Contents read, Metadata read. Nothing that writes. Paste it at wrangler's prompt."
}
Write-Host "    npx wrangler secret put DASHBOARD_TOKEN"
Write-Host "        paste the 32 characters in $tokenPath at the prompt (not on the command line)."
Write-Host "    npx wrangler deploy"
Write-Host ""
Write-Host "  Then open (the subdomain is your Cloudflare account's workers.dev subdomain, which wrangler prints):" -ForegroundColor Cyan
Write-Host "    https://$workerName.<your-subdomain>.workers.dev/issues/<contents of $tokenPath>"
Write-Host "  The URL is not printed in full on purpose (terminal output lands in transcripts and logs). The file"
Write-Host "  content is the ONLY lock: anyone holding it reads your open issues. Never paste it into a chat or issue."
Write-Host "  The worker answers 404 to everything else, sends noindex and no-store, and caches GitHub reads"
Write-Host "  per worker isolate (and at the edge where Cloudflare provides a cache): roughly once a minute per isolate."
Write-Host "  Never run wrangler from the repository root; run it from the directory above."
exit 0
