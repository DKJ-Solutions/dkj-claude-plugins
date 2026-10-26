<#
.SYNOPSIS
    Serve this repo's dev server on http://localhost:<Port>/ -- the hub on '/', which serves three pages that began
    here and are every repo's since #3470, the dkj-policy plugin's: /test-gate, the per-suite CI durations, grouped by
    the workflow step each suite guards (scripts/tests/suite-groups.json), with this checkout's suite selection,
    which only this hub shows (#3097, #3309); and /stopwatch and /logbook with their label, run and slug pages, how
    long each assignment took, from the runs the plugin's hooks record (#3315, #3323, #3364, #3405), answered by the
    plugin's own router (Resolve-HubTimingPage) as the plugin's server answers them; and /plugins, every plugin this
    repo enables and its state on this machine, from this tree's plugin-versions.ps1 -Json (#3482). The server takes
    no POST but the banner's.
    It also builds this repo's own pages, which the hub links: /connectors, every repo registered under connectors/ with its plugins, its local checkout and what
    check-connectors.ps1 reports for it on this machine (#2976), one card per owner group with each
    group a page of its own at /connectors/dkj, /bwj and /other; /specialists, every specialist the
    dkj-subagents plugins ship and the context each one costs, read from this tree; and /dkj-repos, every
    DKJ-Solutions repo on GitHub with its checkout here and a session to open there (#3231). The rules of
    the hub and of each page are in scripts/lib/dev-pages-lib.ps1; the Test gate's, the Stopwatch's and the
    Logbook's in plugins/dkj-policy/hub/lib/.

    NO PRODUCT BESIDE IT (#3493). From October 22, 2026 the brandbook/ app's Vite dev server was this repo's
    product, on a port of its own, and linked and relayed /connectors, /specialists and /dkj-repos from here.
    The owner retired the app (October 26, 2026) so that the house style is the one place DKJ styling lives:
    its check by eye is /plugins/dkj-solutions/house-style now, under the plugin that ships it, as on every
    hub that enables dkj-solutions, and the three pages are the hub's own again. /brandbook is a 404 here
    like any other path this server does not have.

    THE GENERAL PAGES ARE BUILT ELSEWHERE AND SERVED FROM HERE (#3119, #3168): Artifacts, Issues and
    SessionStart belong to every repo, so the dkj-policy plugin builds them in a server of its own
    (hub/pages/serve-general-pages.ps1; dkj-solutions' until #3198), which the dev-preview hook starts beside
    this one. The hook writes both servers' urls to a state file in %TEMP%; the hub reads it on every request,
    asking the server named there who it is (its /whoami, the hash of this root) for at most ~500 ms. When
    it answers as this checkout's, a request for /artifacts, /issues or /sessionstart and its section pages -- and
    /refresh?page=issues or =sessionstart -- is relayed to it and its answer sent back as it came
    (Copy-LoopbackUpstream), and the General card links those paths on this origin. A short 404 text naming
    the general pages server answers when it does not, and a 502 when it stops answering mid-request.
    WHY A RELAY AND NOT A 303 (#3168): the two servers are two origins, and house-theme.js keeps the theme
    and the width in localStorage, which is per origin, so a choice made on the hub did not exist on the
    general pages and back. Served from one origin, under one data-theme-key ('general-pages', the key the
    plugin's pages already carry in every repo), one choice holds on every page. The general pages' "Repo
    hub" crumb is '/hub', which this server answers with a 303 to '/'.

    /RELEASE-NOTES IS BUILT HERE, FROM THIS TREE (owner, October 25, 2026). The release notes are this repo's
    own, and relayed they came out of the installed plugin, so a fix to the page showed only after a cut. This
    server builds and dresses the page with this tree's scripts instead (Update-DashboardReleaseNotesPage).

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
    (For tests) The Stopwatch's store instead of this repo's own under LOCALAPPDATA (Get-StopwatchStorePath). The
    transcript phases are cached beside it, as stopwatch-phases.json.

.PARAMETER LogbookPath
    (For tests) The Logbook's store instead of the one beside the Stopwatch's (Get-LogbookStorePath). Its transcript
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
# The Stopwatch and the Logbook (#3315, #3364): the dkj-policy plugin's since #3470, read from this tree because
# this repo is the plugin's source, through the router the plugin's own server uses (Resolve-HubTimingPage).
. (Join-Path $root 'plugins\dkj-policy\hub\lib\timing-pages.ps1')
$timing = New-HubTimingContext -RepoRoot $root -RepoName 'dkj-claude-plugins' -HubHref '/' -StopwatchPath $StopwatchPath -LogbookPath $LogbookPath -TranscriptDir $TranscriptDir
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
# The banner's airsquats state, the same file and gist as every other hub's (#3438).
. (Join-Path $root 'plugins\dkj-policy\hub\lib\airsquats-lib.ps1')
# The Plugins page (#3482): the plugin's, served from this tree with this tree's plugin-versions.ps1, like /test-gate.
. (Join-Path $root 'plugins\dkj-policy\hub\lib\plugins-page-lib.ps1')

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
# The canonical copy lives in the plugin (#3130); the hub no longer vendors its own.
$styleDir = Join-Path $root 'plugins\dkj-policy\assets\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}# The routes that moved to the general pages server (#3119): each is sent on, or answered with a 404 text.
# /release-notes is not among them: it is built here, from this tree (below).
$generalRoutes = @('/artifacts', '/issues', '/sessionstart')
$releaseNotesFile = Join-Path $root 'dkj-policy\releases\page\release-notes.html'
$script:rnFailure = $null

function Update-DashboardReleaseNotesPage {
    <#
        THE RELEASE NOTES ARE THIS REPO'S OWN PAGE, BUILT FROM THIS TREE (owner, October 25, 2026). Relayed to
        the general pages server, they came out of the INSTALLED plugin's general-pages-lib.ps1, so a change to
        the page on main showed only after a cut. Here they are built by this tree's own
        build-release-notes-page.ps1 and dressed by this tree's Format-ReleaseNotesDevPage, as every other hub page
        here is. The rule for when to build is the general server's (Get-ReleaseNotesPageNeed): the page is absent,
        or a release document changed after it was built -- and here the builder and its template count as inputs
        too, so a change to how the page is built shows without a cut as well. The build runs in a CHILD process, bounded at 60 s,
        because it dot-sources scripts/repo-config.ps1, whose functions must not land in this server's scope.
        Returns '' when the page on disk is current or was just built, else why not; a failed build is kept for
        30 s, and an older page stays served.
    #>
    $releasesDir = Split-Path -Parent (Split-Path -Parent $releaseNotesFile)
    $pageDir = Split-Path -Parent $releaseNotesFile
    $pageTime = Get-ReleaseNotesBuiltTime -IndexFile $releaseNotesFile
    $newest = $null
    if (Test-Path -LiteralPath $releasesDir -PathType Container) {
        $prefix = $pageDir.TrimEnd('\') + '\'
        $newest = Get-ChildItem -LiteralPath $releasesDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { -not $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { $_.LastWriteTimeUtc } | Sort-Object -Descending | Select-Object -First 1
    }
    # The builder and its template are inputs too, so a change to how the page is BUILT rebuilds it as well.
    $builder = Join-Path $root 'scripts\release\build-release-notes-page.ps1'
    foreach ($source in @($builder, (Join-Path $root 'scripts\release\release-notes-page-template.html'))) {
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            $t = (Get-Item -LiteralPath $source).LastWriteTimeUtc
            if ($null -eq $newest -or $t -gt $newest) { $newest = $t }
        }
    }
    if (-not (Get-ReleaseNotesPageNeed -PageTime $pageTime -NewestInputTime $newest)) { return '' }
    if ($script:rnFailure -and ((Get-Date) - $script:rnFailure.At).TotalSeconds -lt 30) { return $script:rnFailure.Error }

    $err = ''
    if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { $err = 'scripts/release/build-release-notes-page.ps1 is not in this tree' }
    else { try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Join-Path $PSHOME 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $builder + '" -RootOverride "' + $root + '" -OutFile "' + $releaseNotesFile + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = $root
        $p = [System.Diagnostics.Process]::Start($psi)
        try {
            if (-not $p.WaitForExit(60000)) { try { $p.Kill() } catch { }; $err = 'the build did not finish within 60 s' }
            elseif ($p.ExitCode -ne 0) { $err = "the build exited $($p.ExitCode)" }
        } finally { $p.Dispose() }
    } catch { $err = (([string]$_.Exception.Message) -replace '\s+', ' ') } }
    $script:rnFailure = if ($err) { @{ Error = $err; At = Get-Date } } else { $null }
    return $err
}

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
    <# The plugin's reader of scripts/tests (Read-TestGateModel, #3470), and this checkout's selection, which only this repo's hub shows. #>
    $tg = Read-TestGateModel -RepoRoot $root
    $tg.Selection = Get-TestGateSelection
    return $tg
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
            if ($path -eq '/api/airsquats' -or $path.StartsWith('/api/airsquats/')) {
                # The banner's state (#3438): before the GET-only rule, since ticking the box is a POST.
                $as = Invoke-AirsquatsApi -Method $method -Path $path -SecFetchSite $request.SecFetchSite
                $asHeaders = if ($as.Allow) { @{ Allow = $as.Allow } } else { @{} }
                Send-LoopbackResponse $stream $as.Status $as.Reason 'application/json; charset=utf-8' ($utf8.GetBytes($as.Body)) $asHeaders -Method $method
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-LoopbackResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' } -Method $method
                continue
            }
            if ($path -eq '/whoami') {
                # Whose server this is, as the general server answers it: the hash of this root. Before the restart
                # check, so a probe never restarts the server.
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
                $page = if ([string]$target -cmatch '[?&]page=(connectors(?:/(?:dkj|bwj|other))?|dkj-repos)(&|$)') { $Matches[1] } else { '' }
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
            if ($path -cmatch '^/connectors(?:/(dkj|bwj|other))?\z') {
                # The overview with one card per owner group, or one group's own page (owner, October 26, 2026).
                $group = [string]$Matches[1]
                if ($null -eq $cache -or ((Get-Date) - $cache.At).TotalSeconds -ge $CacheSeconds) { $cache = Get-DashboardModel }
                $html = Format-ConnectorDashboardHtml -Connectors $cache.Connectors -Meta $cache.Meta -Group $group
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
                $html = Format-TestGatePageHtml -Model $tg.Model -ReadError $tg.Error -GroupsError $tg.GroupsError -Selection $tg.Selection -RepoName 'dkj-claude-plugins' -HubHref '/' -RepoSlug 'DKJ-Solutions/dkj-claude-plugins'
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            $plReq = Resolve-PluginsPageRequest -Path $path
            if ($plReq) {
                # The overview, or one plugin's page; a name no enabled plugin has is a 404.
                $pl = Read-PluginsPageModel -Script (Join-Path $root 'scripts\task\plugin-versions.ps1') -RepoRoot $root
                $plRow = if ($plReq.Name) { Find-PluginsPageRow -Model $pl.Model -Name $plReq.Name } else { $null }
                if ($plReq.Name -and -not $plRow) {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('No plugin of that name is enabled in this repo.')) -Method $method
                    continue
                }
                if ($plRow -and $plReq.Page -eq 'house-style') {
                    # The house style's specimens, under the plugin that ships them (#3493), read from this tree per request.
                    $specError = ''; $spec = ''
                    try { $spec = [System.IO.File]::ReadAllText((Join-Path $styleDir 'specimens.html'), $utf8) } catch { $specError = $_.Exception.Message }
                    $html = Format-HouseStyleSpecimensPageHtml -Body $spec -ReadError $specError -RepoName 'dkj-claude-plugins' -HubHref '/'
                } else {
                    $html = if ($plRow) { Format-PluginPageHtml -Row $plRow -Model $pl.Model -RepoName 'dkj-claude-plugins' -HubHref '/' }
                            else { Format-PluginsPageHtml -Model $pl.Model -ReadError $pl.Error -RepoName 'dkj-claude-plugins' -HubHref '/' }
                }
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            # The Stopwatch's and the Logbook's routes (#3470): a page, a moved run slug, or a slug no run has.
            $tp = Resolve-HubTimingPage -Path $path -Context $timing
            if ($null -ne $tp) {
                if ($tp.Status -eq 301) { Send-LoopbackResponse $stream 301 'Moved Permanently' 'text/plain; charset=utf-8' ($utf8.GetBytes('Moved.')) -Headers @{ Location = $tp.Location } -Method $method }
                elseif ($tp.Status -eq 404) { Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.')) -Method $method }
                else { Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($tp.Html)) -Method $method }
                continue
            }
            if ($path -eq '/specialists') {
                $sp = Get-SpecialistsModel
                $html = Format-SpecialistsPageHtml -Rows $sp.Rows -ReadError $sp.Error -CharsPerToken $sp.CharsPerToken
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
                continue
            }
            $rn = Resolve-ReleaseNotesRequest -Path $path -IndexFile $releaseNotesFile
            if ($rn) {
                # This repo's own pages, built from this tree (Update-DashboardReleaseNotesPage): the index, or
                # one release's own page beside it (owner, October 25, 2026).
                $buildError = Update-DashboardReleaseNotesPage
                if (-not (Test-Path -LiteralPath $releaseNotesFile -PathType Leaf)) {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes("Not built yet: this repo has no dkj-policy/releases/page/release-notes.html, and this server could not build it ($buildError).")) -Method $method
                    continue
                }
                if (-not (Test-Path -LiteralPath $rn.File -PathType Leaf)) {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes("No release v$($rn.Version) carries a note here.")) -Method $method
                    continue
                }
                $html = Format-ReleaseNotesDevPage -Html ([System.IO.File]::ReadAllText($rn.File, $utf8)) -HubHref '/' -RepoName 'dkj-claude-plugins' -Release:([bool]$rn.Version)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($generalRoutes -contains $path -or $path -match '^/sessionstart/[a-z-]{1,40}$') {
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
