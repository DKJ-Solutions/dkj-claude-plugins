<#
.SYNOPSIS
    Serve this repo's dev server on http://localhost:<Port>/ -- the hub on '/', which links the hub's own
    pages (#3097): /test-gate, the per-suite CI durations, grouped by the workflow step each suite guards
    (scripts/tests/suite-groups.json); and /stopwatch, how long each assignment took: a read-only overview of cards, one per
    prompt label, and /stopwatch/<slug>, each label's page with a card per run, or each run's page, from the runs the hooks of scripts/dashboard/stopwatch-hook.ps1 record (#3315, #3323); and /logbook
    and /logbook/<slug>, the same pages for every session that began on a clean trunk, from the runs of scripts/dashboard/logbook-hook.ps1 (#3364), a /sweep-issues run cut into one run per issue at its folds (#3405). The server takes no POST at all. It also builds three pages the product relays, which the hub does not link (below):
    /connectors, every repo registered under connectors/ with its plugins, its local checkout and what
    check-connectors.ps1 reports for it on this machine (#2976); /specialists, every specialist the
    dkj-subagents plugins ship and the context each one costs, read from this tree; and /dkj-repos, every
    DKJ-Solutions repo on GitHub with its checkout here and a session to open there (#3231). The rules of
    the hub and of each page are in scripts/lib/dev-pages-lib.ps1, the Stopwatch's in
    scripts/lib/stopwatch-lib.ps1.

    NO /brandbook HERE. The brand book is this repo's product: the brandbook/ app's Vite dev server, which the
    dev-preview hook starts on a port of its own (#3283). This server built and served the same app at
    /brandbook too, so one brand book was visible on two ports; the owner put it on the product port alone
    (October 22, 2026), and /brandbook is a 404 here like any other path this server does not have.

    /connectors, /specialists AND /dkj-repos ARE THE PRODUCT'S PAGES, BUILT HERE. The owner moved them to the
    product port too (October 22, 2026): its dev server (productRoot in brandbook/vite.config.ts) links them on
    its root page and relays each request here, finding this server by /whoami. So this server still answers
    all three, for that relay, and the hub links none of them.

    THE GENERAL PAGES ARE BUILT ELSEWHERE AND SERVED FROM HERE (#3119, #3168): Artifacts, Issues, Release
    notes and SessionStart belong to every repo, so the dkj-policy plugin builds them in a server of its own
    (hub/pages/serve-general-pages.ps1; dkj-solutions' until #3198), which the dev-preview hook starts beside
    this one. The hook writes both servers' urls to a state file in %TEMP%; the hub reads it on every request,
    asking the server named there who it is (its /whoami, the hash of this root) for at most ~500 ms. When
    it answers as this checkout's, a request for /artifacts, /issues, /release-notes or /sessionstart -- and
    /refresh?page=issues or =sessionstart -- is relayed to it and its answer sent back as it came
    (Copy-LoopbackUpstream), and the General card links those paths on this origin. A short 404 text naming
    the general pages server answers when it does not, and a 502 when it stops answering mid-request.
    WHY A RELAY AND NOT A 303 (#3168): the two servers are two origins, and house-theme.js keeps the theme
    and the width in localStorage, which is per origin, so a choice made on the hub did not exist on the
    general pages and back. Served from one origin, under one data-theme-key ('general-pages', the key the
    plugin's pages already carry in every repo), one choice holds on every page. The general pages' "Repo
    hub" crumb is '/hub', which this server answers with a 303 to '/'.

.DESCRIPTION
    Normally started by the dkj-policy dev-preview SessionStart hook, through this repo's
    Get-DevPreview in scripts/repo-config.ps1, which states OwnHub = $true (#3245): the plugin serves its hub
    of its own in every other repo, and this repo's connector dashboard is its hub instead; it can be started by hand the same way:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dashboard\serve-connector-dashboard.ps1 -Port 4870

    A TcpListener ON 127.0.0.1, NOT AN HttpListener. Under HttpListener the listening socket belongs to
    http.sys (the System process, PID 4), so the hook's ownership check -- which walks from the socket's
    owning process up to the cmd.exe that names this checkout -- could never recognise the server as
    ours, and every session would start another one on the next port. A TcpListener's socket is owned by
    this powershell.exe. Loopback only, so nothing on the network reaches it, and a request whose Host is
    not localhost:<Port> or 127.0.0.1:<Port> is refused (DNS rebinding).

    THE DATA IS READ ON DEMAND AND KEPT FOR -CacheSeconds. The first request after that runs
    check-connectors.ps1 again, drift check included (#2997, about 1.4 s more), reads every connectors/*.json, and asks
    git for the last commit on each checkout's trunk -- local refs only, no fetch.
    /refresh drops the cache and redirects to the page.

    One request at a time, each answered with Connection: close. A connection whose request head is not
    complete within -ReadTimeoutMs, or is longer than 8 KB, is dropped, so a browser's speculative
    connection or a dripping client cannot stall the loop. A request the browser marks as coming from
    another site (Sec-Fetch-Site) is refused, and /refresh re-runs the check at most once per
    -MinRefreshSeconds. It runs until the process is stopped.

    IT RESTARTS ITSELF WHEN THE CHECKOUT MOVES (#3122). The libs are dot-sourced once, so a server keeps
    the code it started on; and the hook reuses any server of this checkout, so a pull after the start
    left every later session on the old pages. So the server notes the HEAD it loaded, and a request that
    finds HEAD somewhere else is answered with a 503 that reloads in three seconds, after which the server
    stops listening and starts its successor on the same port -- under a cmd.exe that changes into the
    root first, as the hook's own start line does, so the hook still recognises it as this checkout's.
    The hub's "Source at" names that loaded commit, not the live one. Static files skip the check.
    A successor that dies at start (a broken commit) leaves the port empty, with the reason in
    %TEMP%\serve-connector-dashboard-<Port>-<guid>.log; the next session's hook starts a server again. A root
    holding '%' or '"', which cmd.exe would rewrite, gets the notice but no restart.

    Pure ASCII (repo convention for .ps1). The page's rules are in scripts/lib/connector-dashboard-lib.ps1,
    tested by scripts/tests/connector-dashboard.tests.ps1.

.PARAMETER Port
    The loopback port to listen on (1024-65535).

.PARAMETER CacheSeconds
    How long one read of the register is served before the next request reads it again.

.PARAMETER ReadTimeoutMs
    How long a connection may take to send its whole request head (one deadline, not one per read).

.PARAMETER MinRefreshSeconds
    The shortest interval between two re-runs that /refresh can cause.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of the one this script sits in.

.PARAMETER StopwatchPath
    (For tests) The Stopwatch's store instead of the one under LOCALAPPDATA (Get-StopwatchStorePath). The
    transcript phases are cached beside it, as stopwatch-phases.json.

.PARAMETER LogbookPath
    (For tests) The Logbook's store instead of the one under LOCALAPPDATA (Get-LogbookStorePath). Its transcript
    phases are cached beside it, as logbook-phases.json.

.PARAMETER TranscriptDir
    (For tests) The session transcripts the Stopwatch reads its phases from, instead of this checkout's own
    under ~/.claude/projects (Get-StopwatchTranscriptDir).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateRange(1024, 65535)][int]$Port,
    [ValidateRange(0, 86400)][int]$CacheSeconds = 60,
    [ValidateRange(100, 60000)][int]$ReadTimeoutMs = 1000,
    [ValidateRange(0, 3600)][int]$MinRefreshSeconds = 10,
    [string]$RepoRootOverride,
    [string]$StopwatchPath,
    [string]$LogbookPath,
    [string]$TranscriptDir
)

$ErrorActionPreference = 'Stop'

$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $root 'scripts\lib\connector-dashboard-lib.ps1')
. (Join-Path $root 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $root 'scripts\lib\stopwatch-lib.ps1')
if (-not $StopwatchPath) { $StopwatchPath = Get-StopwatchStorePath }
if (-not $TranscriptDir) { $TranscriptDir = Get-StopwatchTranscriptDir -RepoRoot $root }
$StopwatchPhasesPath = Join-Path (Split-Path -Parent $StopwatchPath) 'stopwatch-phases.json'
# The Logbook (#3364), guarded: a tree that copies the Stopwatch's lib alone serves no /logbook.
$logbookLib = Join-Path $root 'scripts\lib\logbook-lib.ps1'
$LogbookAvailable = Test-Path -LiteralPath $logbookLib -PathType Leaf
if ($LogbookAvailable) {
    . $logbookLib
    if (-not $LogbookPath) { $LogbookPath = Get-LogbookStorePath }
    $LogbookPhasesPath = Join-Path (Split-Path -Parent $LogbookPath) 'logbook-phases.json'
}
# ship-pr's step marks (#3338): the writer's own path, from the lib stopwatch-lib.ps1 loads beside itself.
$StopwatchStepLogPath = if ($script:StopwatchStepLogAvailable) { Get-RunStepLogPath } else { '' }
# The other machines' runs (#3349), read from refs/stopwatch-origin/* and refreshed in the background at most every
# few minutes. Only for the real store: a test that passes a store of its own must neither read this checkout's
# refs nor reach the network. GUARDED like the test gate's libs below, so a tree without it serves this machine's runs.
$swSyncLib = Join-Path $root 'scripts\lib\stopwatch-sync-lib.ps1'
$StopwatchShared = (-not $PSBoundParameters.ContainsKey('StopwatchPath')) -and (Test-Path -LiteralPath $swSyncLib -PathType Leaf)
if ($StopwatchShared) { . $swSyncLib }
$StopwatchMachineId = if ($StopwatchShared) { Get-StopwatchMachineId -StoreDir (Split-Path -Parent $StopwatchPath) } else { '' }
function Get-StopwatchPageRuns {
    <# This machine's store, and when shared, the other machines' runs merged in (Merge-StopwatchRuns) with their phases; starts a background sync when one is due. #>
    $store = Read-StopwatchStore -Path $StopwatchPath
    $shared = @{ Runs = @(); Phases = @{}; Machines = 0 }
    if (-not $StopwatchShared) { return @{ Store = $store; Runs = $store.Runs; Shared = $shared } }
    $stamp = Join-Path (Split-Path -Parent $StopwatchPath) 'stopwatch-sync.stamp'
    if (Test-StopwatchSyncDue -StampPath $stamp) {
        # Stamped here as well as by the sync itself, so the loads before it starts do not start more.
        try { [System.IO.File]::WriteAllText($stamp, (Format-StopwatchStamp ([datetime]::UtcNow))) } catch { }
        [void](Start-StopwatchSync -RepoRoot $root)
    }
    $shared = Read-StopwatchShared -RepoRoot $root -MachineId $StopwatchMachineId
    # No other machine read yet while a sync runs: on a first visit that is the fetch still under way, not an empty origin (#3377).
    $shared.Fetching = ($shared.Machines -eq 0) -and (Test-StopwatchSyncRunning -StampPath $stamp -LogPath (Join-Path (Split-Path -Parent $StopwatchPath) 'stopwatch-sync.log'))
    return @{ Store = $store; Runs = (Merge-StopwatchRuns -Local $store.Runs -Shared $shared.Runs); Shared = $shared }
}
# The test gate's own selection and CI's, so /test-gate shows what they decide for this checkout (#3309).
# GUARDED, unlike the libs above: they serve one section of one page, and gate-lib.ps1 loads a chain of its
# own, so a tree without them (this script's own test fixtures) still serves every page, and the section
# says why it is empty.
$gateLibError = ''
try {
    . (Join-Path $root 'scripts\lib\gate-lib.ps1')
    . (Join-Path $root 'scripts\lib\ci-suite-selection-lib.ps1')
} catch { $gateLibError = $_.Exception.Message }
# For Resolve-BranchFilePath: the branch document falls in no walk scope, as in open-pr (#3379). Its own try,
# because without it Get-GateBranchDocument answers '' and the selection only grows.
try { . (Join-Path $root 'scripts\lib\entry-scaffold-lib.ps1') } catch { }
# The state file the hook writes, and the probe of the general pages server (#3119): the plugin's, read from
# this repo's own tree because this repo is the plugin's source.
. (Join-Path $root 'plugins\dkj-policy\hub\lib\general-pages-state.ps1')
# The request reader, the response writer and the two refusals: the same ones the plugin's servers use, so a
# fix to any of them lands in all three (#3163).
. (Join-Path $root 'plugins\dkj-policy\hub\lib\loopback-server-lib.ps1')

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
# The canonical copy lives in the plugin (#3130); the hub no longer vendors its own.
$styleDir = Join-Path $root 'plugins\dkj-policy\dkj-solutions\assets\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}
# The routes that moved to the general pages server (#3119): each is sent on, or answered with a 404 text.
$generalRoutes = @('/artifacts', '/issues', '/release-notes', '/sessionstart')

function Get-GeneralPagesPort {
    <# The general pages server's port when the state file names one that answers as this checkout's, else 0. #>
    $pages = Get-GeneralPagesUrl -Root $root -TimeoutMs 500
    if ($pages -cmatch '^http://localhost:([0-9]{4,5})/?\z') { return [int]$Matches[1] }
    return 0
}

function Invoke-DashboardGit {
    param([string]$Path, [string[]]$GitArgs)
    # 'Continue' here, and the catch: under the script's 'Stop', Windows PowerShell 5.1 turns a native
    # command's stderr into a terminating error even with 2>$null -- so one branch without an upstream
    # ('fatal: no upstream configured') blanked the whole page (Victor's review, #2976).
    $ErrorActionPreference = 'Continue'
    try { $out = & git -C $Path @GitArgs 2>$null } catch { return $null }
    if ($LASTEXITCODE -ne 0) { return $null }
    # The comma keeps a one-line answer an array: unrolled, '[0]' would index the string's first letter.
    return , @($out)
}

function Get-DashboardGitInfo {
    <#
        The last commit on one checkout's TRUNK -- origin/HEAD's target, else 'main', or 'master' where only
        that exists -- from local refs only. The branch the checkout stands on is read only to tell a git
        checkout from a folder that is not one.
    #>
    param([string]$Path)
    $branch = Invoke-DashboardGit $Path @('rev-parse', '--abbrev-ref', 'HEAD')
    if ($null -eq $branch) { return @{ Branch = $null } }
    $info = @{ Branch = [string]$branch[0]; Subject = ''; When = ''; Trunk = $null }
    $originHead = Invoke-DashboardGit $Path @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
    $trunk = if ($originHead -and ([string]$originHead[0]) -match '^origin/(.+)$') { $Matches[1] }
             elseif (-not (Invoke-DashboardGit $Path @('rev-parse', '--verify', '--quiet', 'refs/heads/main')) -and (Invoke-DashboardGit $Path @('rev-parse', '--verify', '--quiet', 'refs/heads/master'))) { 'master' }
             else { 'main' }
    # The name goes on a git command line, so it must read as a ref and never as an option.
    if ($trunk -match '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -and (Invoke-DashboardGit $Path @('rev-parse', '--verify', '--quiet', "refs/heads/$trunk"))) {
        $info.Trunk = $trunk
    }
    if (-not $info.Trunk) { return $info }
    $last = Invoke-DashboardGit $Path @('log', '-1', '--format=%cr%x09%s', "refs/heads/$($info.Trunk)")
    if ($last -and ([string]$last[0]) -match '^([^\t]*)\t(.*)$') { $info.When = $Matches[1]; $info.Subject = $Matches[2] }
    return $info
}

function Get-DashboardModel {
    $started = Get-Date
    $meta = @{ GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); Seconds = $null; CheckFailed = $null }

    $parsed = @{}
    $ErrorActionPreference = 'Continue'   # the same 5.1 stderr trap as in Invoke-DashboardGit
    try {
        $check = Join-Path $root 'scripts\sync\check-connectors.ps1'
        $lines = & powershell -NoProfile -ExecutionPolicy Bypass -File $check 2>&1 | ForEach-Object { [string]$_ }
        $parsed = ConvertFrom-ConnectorCheckOutput -Lines $lines
        if (-not $parsed.Count) { $meta.CheckFailed = 'it printed no connector block' }
    } catch {
        $meta.CheckFailed = ([string]$_.Exception.Message) -replace '\s+', ' '
    }

    $connectors = @()
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'connectors') -Filter '*.json' -File | Sort-Object Name)) {
        try { $m = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
        $repo = [string]$m.repo
        if (-not $repo) { continue }
        $candidates = @(Get-ConnectorCheckoutCandidates $m.localCheckout)
        # The manifest is data from a public repo and git runs in the folder it names, so the path is held to
        # check-connectors' own bound -- the one resolver repo-session.ps1 uses too (#3231).
        $resolved = Resolve-ConnectorCheckout -Root $root -LocalCheckout $m.localCheckout -ScopeRoot $scopeRoot
        $signals = if ($parsed.Contains($repo)) { @($parsed[$repo].Signals) } else { @() }
        $plugins = @(@($m.plugins) | Where-Object { $_ } | ForEach-Object { @{ Id = [string]$_.id; Extensions = @($_.extensions) } })
        $connectors += @{
            Repo       = $repo
            Visibility = [string]$m.visibility
            File       = $f.Name
            Checkout   = $candidates
            Present    = [bool]$resolved
            Plugins    = $plugins
            Signals    = $signals
            Drift      = if ($parsed.Contains($repo)) { $parsed[$repo].Drift } else { $null }
            Status     = Get-ConnectorStatus $signals
            Git        = if ($resolved) { Get-DashboardGitInfo $resolved } else { $null }
            Notes      = [string]$m.notes
        }
    }
    $meta.Seconds = ((Get-Date) - $started).TotalSeconds
    return @{ Connectors = $connectors; Meta = $meta; At = Get-Date }
}

function Get-DkjReposModel {
    <#
        The DKJ repos page's data (#3231): one GraphQL call for every DKJ-Solutions repo with its open issue and
        pull request counts, and the checkouts beside this repo. Cached like the Connectors page, because the
        call goes over the network.
    #>
    $started = Get-Date
    $ErrorActionPreference = 'Continue'   # the same 5.1 stderr trap as in Invoke-DashboardGit
    $raw = $null
    try { $raw = & gh api graphql -f ('query=' + (Get-DkjRepoQuery)) -f 'owner=DKJ-Solutions' 2>$null } catch { $raw = $null }
    $query = ConvertFrom-DkjRepoQuery -Json $(if ($LASTEXITCODE -eq 0 -and $raw) { ($raw -join "`n") } else { '' })
    $checkouts = @(Find-DkjCheckouts -ParentDir (Split-Path -Parent $root) -Owner 'DKJ-Solutions')
    return @{ Query = $query; Checkouts = $checkouts; At = Get-Date
              Meta = @{ GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); Seconds = ((Get-Date) - $started).TotalSeconds } }
}

function Get-TestGateModel {
    <# scripts/tests/suite-durations.json, suite-groups.json and the suite files beside them, read on every request: two small files. #>
    $testsDir = Join-Path $root 'scripts\tests'
    $files = @(Get-ChildItem -LiteralPath $testsDir -Filter '*.tests.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $read = {
        param($Name)
        $p = Join-Path $testsDir $Name
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @{ Json = $null; Error = 'the file is not there' } }
        try { return @{ Json = (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json); Error = '' } } catch { return @{ Json = $null; Error = 'it is not valid JSON' } }
    }
    $d = & $read 'suite-durations.json'
    $g = & $read 'suite-groups.json'
    $groups = if ($g.Json) { $g.Json.groups } else { $null }
    if (-not $g.Error -and -not @($groups | Where-Object { $_ }).Count) { $g.Error = 'it holds no groups' }
    # What each suite protects, off its own header (#3309, lever 3): ~165 small reads.
    $synopses = @{}
    foreach ($f in $files) {
        try { $synopses[$f] = Get-SuiteSynopsis -Text ([System.IO.File]::ReadAllText((Join-Path $testsDir $f))) } catch { }
    }
    return @{ Model = (ConvertFrom-SuiteDurations -Durations $d.Json -SuiteFiles $files -Groups $groups -Synopses $synopses); Error = $d.Error; GroupsError = $g.Error
              Selection = (Get-TestGateSelection) }
}

function Get-TestGateSelection {
    <#
        What this checkout's change selects, locally and on CI (#3309, lever 3), from the functions open-pr
        and the CI check run themselves -- Get-GateChangedPaths and Get-AffectedSuiteSelection in
        gate-lib.ps1, Get-StaticAssetVerdict in ci-suite-selection-lib.ps1 -- so the page shows the
        selection's own answer. It is the SELECTION, not the whole gate: open-pr may skip the suites
        before selecting (tests already proved for the tree, a CI certificate, a note-tree-only change), and
        the page does not repeat those checks (Victor, #3309). A warm run takes about 2 s (the gate's own
        per-blob cache in the git directory), a cold one about 25 s, which holds the single-threaded server
        for that long. So the answer is kept for -CacheSeconds while HEAD and the list of changed files stay
        the same; a further edit to a file already modified is seen once that time is up. A failure is a
        sentence on the page, never a failed page, and is not kept.
    #>
    # 'Continue', as Invoke-DashboardGit does: the gate's git reads must not turn stderr into a terminating error.
    $ErrorActionPreference = 'Continue'
    $head = Invoke-DashboardGit $root @('rev-parse', 'HEAD')
    $status = Invoke-DashboardGit $root @('status', '--porcelain')
    # No key when git could not answer: a constant key would keep whatever came first.
    $key = if ($null -ne $head -and $null -ne $status) { (@($head) + @($status)) -join '|' } else { $null }
    if ($key -and $script:selectionCache -and $script:selectionCache.Key -eq $key -and ((Get-Date) - $script:selectionCache.At).TotalSeconds -lt $CacheSeconds) {
        return $script:selectionCache.Value
    }
    $value = @{ Base = ''; Changed = @(); Proven = $false; Reason = ''; Selected = @(); Why = @{}; PoolCount = 0; CiText = '' }
    if ($gateLibError) { $value.Reason = "The test gate's selection could not be loaded: $gateLibError"; return $value }
    try {
        $changes = Get-GateChangedPaths -RepoRoot $root
        $value.Base = $changes.Base
        if (-not $changes.Known) { $value.Reason = $changes.Reason }
        elseif (-not @($changes.Paths).Count) { $value.Reason = "Nothing differs from $($changes.Base), so nothing is selected" }
        else {
            $value.Changed = @($changes.Paths)
            $branchDoc = Get-GateBranchDocument -RepoRoot $root
            $sel = Get-AffectedSuiteSelection -RepoRoot $root -ChangedPaths $value.Changed -BranchDocument $branchDoc
            $value.Proven = [bool]$sel.Proven; $value.Reason = $sel.Reason; $value.PoolCount = $sel.PoolCount
            $value.Selected = @($sel.Suites); $value.Why = $(if ($sel.Why) { $sel.Why } else { @{} })
            # CI judges the change without the branch document too (#3370, get-pr-suite-selection.ps1).
            $ciPaths = @(Remove-BranchDocumentPath -ChangedPaths $value.Changed -BranchDocument $branchDoc)
            $assets = Get-StaticAssetVerdict -ChangedPaths $ciPaths
            $value.CiText = if ($assets.AssetOnly) {
                $ci = Get-StaticAssetSuiteSelection -RepoRoot $root -ChangedPaths $ciPaths
                if ($ci.Proven) { "only stylesheets, images or fonts change, so the required check runs $(@($ci.Suites).Count) of $($ci.PoolCount) suites" }
                else { "every suite -- $($ci.Reason)" }
            } else { "every suite, because $($assets.Reason)" }
        }
    } catch { $value.Reason = "the selection failed: $($_.Exception.Message)"; return $value }
    if ($key) { $script:selectionCache = @{ Key = $key; At = Get-Date; Value = $value } }
    return $value
}

function Get-SpecialistsModel {
    <#
        Every specialist under plugins/dkj-subagents/, read on every request: about sixty small files. A
        definition's manual is the plugin's manuals/specialist-<id>-manual.md, its lens this repo's
        .claude/specialists/lenses/specialist-<id>-lens.md; whether its plugin is enabled here is read from
        .claude/settings.json. A file that cannot be read is named in the ReadError, never a blank page.
    #>
    $rows = @(); $errs = @(); $enabled = @{}
    # The token factor's one home; loaded in this call's scope, as the Issues read loads its lib. Should
    # it fail to load, the page still renders at the last calibrated value and says so in its warning.
    $factor = 3.12
    try { . (Join-Path $root 'scripts\lib\measure-context-lib.ps1'); $factor = (Get-CalibratedCharsPerToken).Value } catch { $errs += 'measure-context-lib.ps1 did not load, so the tokens use the fallback factor 3.12' }
    try {
        $settings = Get-Content -LiteralPath (Join-Path $root '.claude\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in @($settings.enabledPlugins.PSObject.Properties)) { if ($p.Value -eq $true) { $enabled[($p.Name -split '@')[0]] = $true } }
    } catch { $errs += '.claude/settings.json is not readable' }
    $lensDir = Join-Path $root '.claude\specialists\lenses'
    $size = { param($f) if (Test-Path -LiteralPath $f -PathType Leaf) { [int64](Get-Item -LiteralPath $f).Length } else { $null } }
    foreach ($plugin in @(Get-ChildItem -LiteralPath (Join-Path $root 'plugins\dkj-subagents') -Directory -Filter 'dkj-subagents-*' -ErrorAction SilentlyContinue)) {
        foreach ($form in 'subagent', 'persona') {
            $dir = Join-Path $plugin.FullName ($form + 's')
            foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -Filter "specialist-*-$form.md" -ErrorAction SilentlyContinue)) {
                if ($file.Name -notmatch '^specialist-(\d\d-\d\d)-') { continue }
                $id = $Matches[1]
                try {
                    $rows += ConvertTo-SpecialistRow -Id $id -Plugin $plugin.Name -Form $form -Enabled ([bool]$enabled[$plugin.Name]) `
                        -Text ([System.IO.File]::ReadAllText($file.FullName, $utf8)) `
                        -ManualBytes (& $size (Join-Path $plugin.FullName "manuals\specialist-$id-manual.md")) `
                        -LensBytes (& $size (Join-Path $lensDir "specialist-$id-lens.md"))
                } catch { $errs += "$($plugin.Name)/$($file.Name)" }
            }
        }
    }
    return @{ Rows = $rows; Error = ($errs -join ', '); CharsPerToken = $factor }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "connector dashboard: http://localhost:$Port/"
$cache = $null
$dkjCache = $null
# The commit this process loaded its code from; $null outside a git checkout or on an unborn HEAD, and
# then it never restarts.
$loaded = Invoke-DashboardGit $root @('rev-parse', 'HEAD')
$loadedSha = if ($loaded) { [string]$loaded[0] } else { $null }
$restart = $false

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $request = Read-LoopbackRequest -Client $client -ReadTimeoutMs $ReadTimeoutMs
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $requestLine = $request.RequestLine
            $hostHeader = $request.Host
            $method, $target = ($requestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-LoopbackHost -HostHeader $hostHeader -Port $Port)) {
                Send-LoopbackResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.')) -Method $method
                continue
            }
            if (Test-LoopbackCrossSite -SecFetchSite $request.SecFetchSite -SecFetchMode $request.SecFetchMode -Method $method) {
                Send-LoopbackResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: another site may not drive this server.')) -Method $method
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-LoopbackResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' } -Method $method
                continue
            }
            if ($path -eq '/whoami') {
                # Whose server this is, as the general server answers it: the hash of this root. The product's dev
                # server asks before it relays /connectors and /specialists here, so it never relays another
                # checkout's hub. Before the restart check, so a probe never restarts the server.
                Send-LoopbackResponse $stream 200 'OK' 'text/plain; charset=utf-8' ($utf8.GetBytes((Get-DevPreviewRootHash -Root $root))) -Method $method
                continue
            }
            # A static file skips the restart check while it is there: a 503 handed to a <link> would leave the
            # page it styles unstyled. A MISSING one falls through to the check -- a server on older code than
            # the checkout looks for it where that older code kept it (the house style moved under #3130) --
            # and is a 404 below when the checkout has not moved, never a dropped connection.
            if ($static.ContainsKey($path) -and (Test-Path -LiteralPath $static[$path].File -PathType Leaf)) {
                $s = $static[$path]
                $body = [System.IO.File]::ReadAllBytes($s.File)
                Send-LoopbackResponse $stream 200 'OK' $s.Type $body -Method $method
                continue
            }
            if ($loadedSha) {
                $live = Invoke-DashboardGit $root @('rev-parse', 'HEAD')
                if ($live -and [string]$live[0] -ne $loadedSha) {
                    $text = "This server was started on $($loadedSha.Substring(0, 8)); the checkout is now at $(([string]$live[0]).Substring(0, 8)). It is restarting on the new code -- this page reloads in a few seconds."
                    Send-LoopbackResponse $stream 503 'Service Unavailable' 'text/plain; charset=utf-8' ($utf8.GetBytes($text)) @{ 'Retry-After' = '3'; Refresh = '3' } -Method $method
                    $restart = $true
                    break
                }
            }
            if ($static.ContainsKey($path)) {
                $text = "Not found: $([System.IO.Path]::GetFileName($static[$path].File)) is not where this server looks for it."
                Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes($text)) -Method $method
                continue
            }
            if ($path -eq '/refresh') {
                # A general page's own refresh is the general pages server's, relayed (#3168): its 303 names a
                # path, which the browser then asks of this origin.
                $generalPage = if ([string]$target -match '[?&]page=(sessionstart|issues)(&|$)') { $Matches[1] } else { '' }
                if ($generalPage) {
                    $gp = Get-GeneralPagesPort
                    if ($gp -and (Copy-LoopbackUpstream -Stream $stream -Port $gp -Method $method -Target "/refresh?page=$generalPage")) { continue }
                }
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for. ?page= names
                # where to go back to, from a fixed list, so the redirect never leaves this server.
                $page = if ([string]$target -match '[?&]page=(connectors|dkj-repos)(&|$)') { $Matches[1] } else { '' }
                if ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                if ($dkjCache -and ((Get-Date) - $dkjCache.At).TotalSeconds -ge $MinRefreshSeconds) { $dkjCache = $null }
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" } -Method $method
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                $html = Format-RepoHubHtml -Pages (Get-RepoHubPages) -SourceCommit $(if ($loadedSha) { $loadedSha.Substring(0, 8) } else { '' }) -GeneralPagesUrl (Get-GeneralPagesUrl -Root $root -TimeoutMs 500)
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            if ($path -eq '/repository') {
                # The GitHub repo: its facts, Issues and its pages on GitHub (owner, October 22, 2026).
                $html = Format-RepoGitHubPageHtml -SourceCommit $(if ($loadedSha) { $loadedSha.Substring(0, 8) } else { '' }) -GeneralPagesUrl (Get-GeneralPagesUrl -Root $root -TimeoutMs 500)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -eq '/about') {
                # About this repo is the home page's since October 22, 2026: an old link lands there.
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/' } -Method $method
                continue
            }
            if ($path -eq '/connectors') {
                if ($null -eq $cache -or ((Get-Date) - $cache.At).TotalSeconds -ge $CacheSeconds) { $cache = Get-DashboardModel }
                $html = Format-ConnectorDashboardHtml -Connectors $cache.Connectors -Meta $cache.Meta
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            if ($path -eq '/dkj-repos') {
                if ($null -eq $dkjCache -or ((Get-Date) - $dkjCache.At).TotalSeconds -ge $CacheSeconds) { $dkjCache = Get-DkjReposModel }
                $html = Format-DkjReposPageHtml -Query $dkjCache.Query -Checkouts $dkjCache.Checkouts -Meta $dkjCache.Meta
                # A failed read of GitHub is shown once and not kept, so the next request asks again (Victor, #3231).
                if ($dkjCache.Query.Error) { $dkjCache = $null }
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -eq '/test-gate') {
                $tg = Get-TestGateModel
                $html = Format-TestGatePageHtml -Model $tg.Model -ReadError $tg.Error -GroupsError $tg.GroupsError -Selection $tg.Selection
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            if ($path -eq '/stopwatch') {
                $sw = Get-StopwatchPageRuns; $store = $sw.Store
                $html = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs $sw.Runs) -ReadError $store.Error -Skipped $store.Skipped -StorePath $StopwatchPath -SharedMachines $sw.Shared.Machines -Fetching:([bool]$sw.Shared.Fetching)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -match '^/stopwatch/([a-z0-9-]{1,60})$') {
                # One run's page (#3323), else one label's page. A slug neither has is a 404, like any other path.
                $sw = Get-StopwatchPageRuns; $store = $sw.Store
                if ($store.Error) {
                    # The same read error the overview shows, not a bare 404 for a page that may well exist.
                    $html = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -ReadError $store.Error -StorePath $StopwatchPath
                    Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                    continue
                }
                $swModel = ConvertTo-StopwatchModel -Runs $sw.Runs
                $group = Find-StopwatchGroup -Model $swModel -Slug $Matches[1]
                if (-not $group) {
                    $labelSet = Find-StopwatchLabel -Model $swModel -Slug $Matches[1]
                    if ($labelSet) {
                        $html = Format-StopwatchLabelPageHtml -Set $labelSet -StorePath $StopwatchPath
                        Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                    } else {
                        Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.')) -Method $method
                    }
                    continue
                }
                # Only this machine's runs are read from its transcripts; another machine's carry the phases it read from its own.
                $phases = Get-StopwatchTranscriptCache -Runs @($group.Rows | ForEach-Object { $_.Run } | Where-Object { -not $_.Machine }) -CachePath $StopwatchPhasesPath -TranscriptDir $TranscriptDir -StepLogPath $StopwatchStepLogPath -RepoRoot $root
                foreach ($k in $sw.Shared.Phases.Keys) { if (-not $phases.ContainsKey($k)) { $phases[$k] = $sw.Shared.Phases[$k] } }
                $html = Format-StopwatchRunPageHtml -Group $group -StorePath $StopwatchPath -Transcript $phases -LabelCrumb
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($LogbookAvailable -and $path -eq '/logbook') {
                $lb = Read-StopwatchStore -Path $LogbookPath
                # A sweep is shown per issue, cut at its folds (#3405).
                $lbRuns = Get-LogbookRuns -Runs $lb.Runs -StepLogPath $StopwatchStepLogPath -RepoRoot $root
                # Every finished run's phases, for its work time on its card: read from the transcripts once, then cached.
                $phases = Get-StopwatchTranscriptCache -Runs @($lbRuns | Where-Object { $_.End }) -CachePath $LogbookPhasesPath -TranscriptDir $TranscriptDir -StepLogPath $StopwatchStepLogPath -RepoRoot $root
                $html = Format-LogbookPageHtml -Runs $lbRuns -ReadError $lb.Error -Skipped $lb.Skipped -StorePath $LogbookPath -Transcript $phases
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($LogbookAvailable -and $path -match '^/logbook/([a-z0-9-]{1,60})$') {
                # One run's page. A store that does not read shows the overview's warning; a slug no run has is a 404.
                $lb = Read-StopwatchStore -Path $LogbookPath
                if ($lb.Error) {
                    $html = Format-LogbookPageHtml -Runs @() -ReadError $lb.Error -StorePath $LogbookPath
                    Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                    continue
                }
                $group = Find-StopwatchGroup -Model (ConvertTo-LogbookModel -Runs (Get-LogbookRuns -Runs $lb.Runs -StepLogPath $StopwatchStepLogPath -RepoRoot $root)) -Slug $Matches[1]
                if (-not $group) {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.')) -Method $method
                    continue
                }
                $phases = Get-StopwatchTranscriptCache -Runs @($group.Rows | ForEach-Object { $_.Run }) -CachePath $LogbookPhasesPath -TranscriptDir $TranscriptDir -StepLogPath $StopwatchStepLogPath -RepoRoot $root
                $html = Format-LogbookRunPageHtml -Group $group -StorePath $LogbookPath -Transcript $phases
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -eq '/specialists') {
                $sp = Get-SpecialistsModel
                $html = Format-SpecialistsPageHtml -Rows $sp.Rows -ReadError $sp.Error -CharsPerToken $sp.CharsPerToken
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            if ($generalRoutes -contains $path) {
                # Built by the plugin's general pages server (#3119) and relayed from it, so the page is on this
                # origin and shares its theme choice (#3168).
                $gp = Get-GeneralPagesPort
                if ($gp) {
                    if (-not (Copy-LoopbackUpstream -Stream $stream -Port $gp -Method $method -Target $path)) {
                        Send-LoopbackResponse $stream 502 'Bad Gateway' 'text/plain; charset=utf-8' ($utf8.GetBytes('The dkj-policy general pages server did not answer this request. Reload the page in a moment.')) -Method $method
                    }
                } else {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes("This page is served by the dkj-policy general pages server, which is not running for this repo: the dev-preview hook starts it at the next session start.")) -Method $method
                }
                continue
            }
            if ($path -eq '/hub') {
                # The general pages' "Home" crumb, now that they are served from this origin (#3168).
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/' } -Method $method
                continue
            }
            Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.')) -Method $method
        } catch {
            # A dropped or silent connection ends that request, never the server.
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}

if ($restart -and ($root + $PSCommandPath) -notmatch '[%"]') {
    # The listener is closed above, so the successor can bind the port. Every parameter goes along -- the
    # root as resolved here, never the raw override -- and the root is on the cmd.exe line first: that
    # ancestor is what the dev-preview hook recognises.
    $argLine = (@($PSBoundParameters.GetEnumerator() | Where-Object { $_.Key -ne 'RepoRootOverride' } |
        ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join ' ')
    if ($RepoRootOverride) { $argLine += " -RepoRootOverride `"$root`"" }
    $log = Join-Path ([System.IO.Path]::GetTempPath()) "serve-connector-dashboard-$Port-$([guid]::NewGuid().ToString('n')).log"
    try {
        Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden -ArgumentList (
            '/d /s /c "cd /d "{0}" && powershell -NoProfile -ExecutionPolicy Bypass -File "{1}" {2} > "{3}" 2>&1"' -f $root, $PSCommandPath, $argLine, $log) | Out-Null
    } catch {
        # The port is free either way, so the next session's hook starts a server again.
        [Console]::Error.WriteLine("serve-connector-dashboard: the successor did not start -- $($_.Exception.Message)")
    }
}
