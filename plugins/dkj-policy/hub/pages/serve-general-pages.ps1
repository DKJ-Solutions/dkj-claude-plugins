<#
.SYNOPSIS
    Serve the plugin's REPOSITORY (#3245) and the GENERAL pages (#3119) on http://localhost:<Port>/ -- the hub on
    '/', then /artifacts, /issues, /release-notes and /sessionstart, and /brandbook in a DKJ-Solutions repo --
    from the repo this server was started in.

.DESCRIPTION
    Started by hooks/dev-preview-sessionstart.ps1 in EVERY repo, beside the repo's own dev server where it
    states one, under a cmd.exe that changes into the repo root first, so the working directory IS the repo
    and that cmd.exe's command line is what lets the hook recognise this server as the checkout's own next
    time. A repo whose own server is not PowerShell (Vite, Next.js) gets the same pages this way. The pages
    and their rules are in hub/lib/general-pages-lib.ps1, the hub's page in hub/lib/repo-hub-page.ps1. In
    dkj-policy, which every repo runs, since #3198.

    WHAT EACH PAGE READS, from the repo, on every request unless it says otherwise:
      /artifacts      scripts/dashboard/artifacts.json -- absent, the page says the file is not there.
      /brandbook/     ONLY where the repo enables dkj-solutions (Test-DkjSolutionsEnabled, read at start), else
                      a plain 404: the brand book app's build in the dkj-solutions extension's assets/brandbook/
                      inside this plugin's payload, which the source repo's cut writes (#3210). Its own routes
                      are answered with its index.html; /brandbook is a 303 to the base. A payload without the
                      build gets a page saying so. The rules are that extension's own,
                      dkj-solutions/scripts/lib/dkj-solutions-pages-lib.ps1.
      /issues         `gh issue list`, three calls (the open issues; created and closed in the last 28 days),
                      for --repo <owner/name> parsed from the origin remote when that is on github.com, else
                      for the repo gh finds from the working directory. Kept for -IssuesCacheSeconds; a failed
                      read for 30 s only. A gh that fails or is missing is a warning on the page, never a blank.
      /release-notes  dkj-policy/releases/page/release-notes.html, dressed in the house style on the way out.
                      Built first, by build-release-notes-page.ps1 (found the way the always-on lib is), where it
                      is absent or older than a file under dkj-policy/releases (#3189): the page is a gitignored
                      snapshot nothing else builds. A 404 text naming why where it cannot be built.
      /sessionstart   (also: scripts/dashboard/session-start-snapshot.json, where the repo keeps one -- the last
                      full session-start measurement, shown below the live table; absent, nothing is added)
                      the always-on path, measured in a CHILD process by always-on-budget-lib.ps1, found in
                      the repo's own scripts/lib, else in this plugin's own. Kept for -CacheSeconds.
                      The child first dot-sources the repo's own scripts/repo-config.ps1, the trust the
                      dev-preview hook already gives it, and is bounded at 60 s.
      /hub, / and /index.html
                      the plugin's hub (Format-PluginRepoHubHtml), built per request from the state file
                      the hook wrote (%TEMP%\dkj-repo-hub-<leaf>-<hash>.json): the repo's own server as the
                      Product card (mode 'product'), the setup cards (mode 'none'). EXCEPT where the repo
                      opted out with OwnHub (mode 'ownhub', #3245): then a 303 to the repo's own hub, the url
                      the file names, and a plain 404 text where it names none.
      /repository     the hub's Repository page (Format-PluginRepoRepositoryHtml, #3383): the facts the home page
                      held until the house hub became a grid of card links, and the Issues page's card.
      /refresh        ?page=issues or ?page=sessionstart drops that page's cache (at most once per
                      -MinRefreshSeconds, and per 60 s for issues) and goes back to the page.
      /whoami         the hash of the repo root this server was started in (Get-DevPreviewRootHash): the
                      hubs ask it before they link here, because an open port does not say whose server it is.
      /house-style.css, /house-theme.js   the canonical copy under dkj-solutions/assets/house-style/ in this
                      plugin's payload (Get-HouseStyleDir), in every repo: the pages keep one look everywhere.
    The repo's name on the pages is owner/name from the origin remote, else the folder's name.

    A TcpListener ON 127.0.0.1, NOT AN HttpListener (#2976): under HttpListener the socket belongs to
    http.sys (PID 4), so the hook's ownership walk could never reach the cmd.exe that names the checkout, and
    every session would start another server on the next port. Loopback only, and a request whose Host is not
    localhost:<Port> or 127.0.0.1:<Port> is refused (DNS rebinding), as is one the browser marks as coming
    from another site -- except a same-site top-level GET navigation (the hub's link, the 303 hop, the
    crumb back), which is a user following a link and is served (Test-LoopbackCrossSite). GET and HEAD only.

    One request at a time, each answered with Connection: close. A connection whose request head is not
    complete within -ReadTimeoutMs, or is longer than 8 KB, is dropped, and one that never reads its answer
    is cut after 2 s. Every child process (git, gh, the measurement) is bounded, by a process helper of this
    file's own. It runs until the process is stopped.

    Pure ASCII (repo convention for .ps1). The pages and the request rules are in hub/lib/
    general-pages-lib.ps1 and repo-hub-page.ps1, tested by scripts/tests/dev-pages.tests.ps1 and
    dev-preview-sessionstart.tests.ps1 in the source repo.

.PARAMETER Port
    The loopback port to listen on (1024-65535).

.PARAMETER CacheSeconds
    How long one measurement of the always-on path is served before the next request measures again.

.PARAMETER IssuesCacheSeconds
    How long one read of the GitHub issues is served: three gh calls take about 12 s.

.PARAMETER ReadTimeoutMs
    How long a connection may take to send its whole request head (one deadline, not one per read).

.PARAMETER MinRefreshSeconds
    The shortest interval between two re-runs that /refresh can cause.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of the working directory.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateRange(1024, 65535)][int]$Port,
    [ValidateRange(0, 86400)][int]$CacheSeconds = 60,
    [ValidateRange(0, 86400)][int]$IssuesCacheSeconds = 300,
    [ValidateRange(100, 60000)][int]$ReadTimeoutMs = 1000,
    [ValidateRange(0, 3600)][int]$MinRefreshSeconds = 10,
    [string]$RepoRootOverride
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\general-pages-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\general-pages-state.ps1')
# The request reader, the response writer and the Host and Sec-Fetch-Site rules: one copy in the plugin,
# shared with the source repo's own hub server.
. (Join-Path $PSScriptRoot '..\lib\loopback-server-lib.ps1')
# The hub's page (#3245).
. (Join-Path $PSScriptRoot '..\lib\repo-hub-page.ps1')

$pluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/') }
$styleDir = Get-HouseStyleDir -PluginRoot $pluginRoot
# The Brandbook is a DKJ-Solutions page (#3198): read once at start, as the hook starts this server per session.
$dkjSolutions = (Test-DkjSolutionsEnabled -Root $root) -and (Test-Path -LiteralPath (Get-DkjSolutionsPagesLibPath -PluginRoot $pluginRoot) -PathType Leaf)
if ($dkjSolutions) { . (Get-DkjSolutionsPagesLibPath -PluginRoot $pluginRoot); $brandbookDir = Get-BrandbookBuildDir -PluginRoot $pluginRoot }
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}
$releaseNotesFile = Join-Path $root 'dkj-policy\releases\page\release-notes.html'

function ConvertTo-ProcessArgument {
    <# One argument as a Windows command line carries it (backslashes before a quote doubled, the whole quoted when it needs it). #>
    param([AllowEmptyString()][string]$Arg)
    if ($Arg -eq '') { return '""' }
    if ($Arg -notmatch '[\s"]') { return $Arg }
    $a = $Arg -replace '(\\+)$', '$1$1'
    $a = $a -replace '(\\*)"', '$1$1\"'
    return '"' + $a + '"'
}

function Invoke-BoundedProcess {
    <#
        Runs -FilePath and waits at most -TimeoutSeconds: @{ Output; ExitCode; TimedOut }. No shell, so no
        quoting layer of cmd.exe; stdout and stderr are both read (a full pipe would stall the child) and
        decoded as UTF-8, the encoding gh and git write, where Windows PowerShell 5.1 would decode through the
        console code page. A child that outlives the bound is killed.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 60,
        [string]$WorkingDirectory = ''
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = (@($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        $out = $p.StandardOutput.ReadToEndAsync()
        $err = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
            try { $p.Kill() } catch { }
            return @{ Output = ''; ExitCode = $null; TimedOut = $true }
        }
        $p.WaitForExit()
        return @{ Output = [string]$out.Result; Error = [string]$err.Result; ExitCode = $p.ExitCode; TimedOut = $false }
    } finally {
        $p.Dispose()
    }
}

function Get-ExecutablePath {
    param([string]$Name)
    $c = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return [string]$c.Source }
    return ''
}

$script:identity = $null
function Get-RepoIdentity {
    <# @{ Name; Slug }: Slug is owner/name from the origin remote when it is on github.com, else ''; Name is the Slug, else the folder's name. Kept for 60 s. #>
    if ($script:identity -and ((Get-Date) - $script:identity.At).TotalSeconds -lt 60) { return $script:identity }
    $slug = ''
    $git = Get-ExecutablePath 'git'
    if ($git) {
        try {
            $r = Invoke-BoundedProcess -FilePath $git -Arguments @('-C', $root, 'config', '--get', 'remote.origin.url') -TimeoutSeconds 10 -WorkingDirectory $root
            if (-not $r.TimedOut -and $r.ExitCode -eq 0) { $slug = ConvertFrom-GitRemoteUrl -Url ($r.Output.Trim()) }
        } catch { }
    }
    $script:identity = @{ Slug = $slug; Name = $(if ($slug) { $slug } else { Split-Path -Leaf $root }); At = Get-Date }
    return $script:identity
}

function Get-JsonFileModel {
    <# The parsed JSON file at -Path as @{ Json; Error }: Error is '' on success, 'the file is not there' or 'it is not valid JSON'. #>
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{ Json = $null; Error = 'the file is not there' } }
    try { return @{ Json = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json); Error = '' } }
    catch { return @{ Json = $null; Error = 'it is not valid JSON' } }
}

function Get-SessionStartSnapshot {
    <# The repo's scripts/dashboard/session-start-snapshot.json, read on every request: one small file. Only some repos keep one, so a missing file is no error and adds nothing to the page. #>
    $path = Join-Path $root 'scripts\dashboard\session-start-snapshot.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Data = $null; Error = '' } }
    try { return @{ Data = (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json); Error = '' } }
    catch { return @{ Data = $null; Error = 'it is not valid JSON' } }
}

function Get-IssuesModel {
    <#
        The repo's issues from GitHub: every open one, and those created or closed in the last 28 days --
        three gh calls, about 4 s each, so the result is cached for -IssuesCacheSeconds. A search returns at
        most 1,000 issues, which is what bounds the window. A gh failure is a ReadError, never a blank page.
    #>
    $started = Get-Date
    $since = $started.ToUniversalTime().AddDays(-28).ToString('yyyy-MM-dd')
    $fields = 'number,title,state,stateReason,labels,assignees,createdAt,closedAt,url'
    $slug = (Get-RepoIdentity).Slug
    $gh = Get-ExecutablePath 'gh'
    $read = {
        param([string[]]$Extra)
        $argv = @('issue', 'list') + $(if ($slug) { @('--repo', $slug) } else { @() }) + @('--limit', '1000', '--json', $fields) + $Extra
        $q = Invoke-BoundedProcess -FilePath $gh -Arguments $argv -TimeoutSeconds 60 -WorkingDirectory $root
        if ($q.TimedOut) { throw 'gh issue list did not answer within 60 s' }
        if ($q.ExitCode -ne 0) { throw "gh issue list exited $($q.ExitCode)" }
        # 5.1's ConvertFrom-Json emits a JSON array as ONE object, so it is enumerated before it is wrapped.
        $parsed = ConvertFrom-Json -InputObject $q.Output
        return , @($parsed | ForEach-Object { $_ })
    }
    try {
        if (-not $gh) { throw 'gh was not found on the PATH' }
        $open = & $read @('--state', 'open')
        $created = & $read @('--state', 'all', '--search', "created:>=$since")
        $closed = & $read @('--state', 'closed', '--search', "closed:>=$since")
        $model = ConvertFrom-IssueList -Open $open -Recent (@($created) + @($closed)) -Now $started -Days 28
        $err = ''
    } catch {
        $model = $null
        $err = ([string]$_.Exception.Message) -replace '\s+', ' '
    }
    return @{ Model = $model; Error = $err; GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); Seconds = ((Get-Date) - $started).TotalSeconds; At = Get-Date }
}

function Resolve-DkjPolicyScript {
    <# The dkj-policy script at -RelativePath this server runs, or '': the first of Get-DkjPolicyScriptCandidates that exists. #>
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    foreach ($c in @(Get-DkjPolicyScriptCandidates -RepoRoot $root -PluginRoot $pluginRoot -RelativePath $RelativePath)) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }
    return ''
}

function Resolve-AlwaysOnBudgetLib {
    <# The always-on-budget-lib.ps1 this server measures with, or ''. #>
    return Resolve-DkjPolicyScript -RelativePath 'scripts\lib\always-on-budget-lib.ps1'
}

$script:rnFailure = $null
function Update-ReleaseNotesPage {
    <#
        Builds the release-notes page where Get-ReleaseNotesPageNeed says it is absent or stale (#3189), with
        dkj-policy's own build-release-notes-page.ps1 in a CHILD process, bounded at 60 s: it dot-sources the
        repo's scripts/repo-config.ps1, whose functions must not land in this server's scope. Returns '' when
        the page on disk is current or was just built, else why it could not be built. A failed build is kept
        for 30 s, so a page that cannot build does not re-run it on every request; an older page stays served.
    #>
    $releasesDir = Split-Path -Parent (Split-Path -Parent $releaseNotesFile)
    $pageDir = Split-Path -Parent $releaseNotesFile
    $pageTime = if (Test-Path -LiteralPath $releaseNotesFile -PathType Leaf) { (Get-Item -LiteralPath $releaseNotesFile).LastWriteTimeUtc } else { $null }
    $newest = $null
    if (Test-Path -LiteralPath $releasesDir -PathType Container) {
        $prefix = $pageDir.TrimEnd('\') + '\'
        $newest = Get-ChildItem -LiteralPath $releasesDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { -not $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { $_.LastWriteTimeUtc } | Sort-Object -Descending | Select-Object -First 1
    }
    if (-not (Get-ReleaseNotesPageNeed -PageTime $pageTime -NewestInputTime $newest)) { return '' }
    if ($script:rnFailure -and ((Get-Date) - $script:rnFailure.At).TotalSeconds -lt 30) { return $script:rnFailure.Error }

    $err = ''
    $builder = Resolve-DkjPolicyScript -RelativePath 'scripts\release\build-release-notes-page.ps1'
    if (-not $builder) {
        $err = 'build-release-notes-page.ps1 was not found in the repo or in the dkj-policy plugin'
    } else {
        try {
            $run = Invoke-BoundedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -TimeoutSeconds 60 -WorkingDirectory $root -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $builder, '-RootOverride', $root, '-OutFile', $releaseNotesFile)
            if ($run.TimedOut) { $err = 'the build did not finish within 60 s' }
            elseif ($run.ExitCode -ne 0) {
                $last = @("$($run.Error)`n$($run.Output)" -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -First 1
                $err = "the build exited $($run.ExitCode)" + $(if ($last) { ': ' + ($last.Trim() -replace '\s+', ' ') } else { '' })
            }
        } catch { $err = (([string]$_.Exception.Message) -replace '\s+', ' ') }
    }
    $script:rnFailure = if ($err) { @{ Error = $err; At = Get-Date } } else { $null }
    return $err
}

function Get-SessionStartModel {
    <#
        The always-on path, measured the way always-on-sessioncheck measures it. In a CHILD process,
        because the measurement dot-sources repo-config.ps1 and the libs, and their functions must not land
        in this server's scope. The child hands back objects, deserialized; a failure is a ReadError.
    #>
    $started = Get-Date
    try {
        $lib = Resolve-AlwaysOnBudgetLib
        if (-not $lib) {
            return @{ Model = $null; Error = 'always-on-budget-lib.ps1 was not found in the repo or in the dkj-policy plugin'; At = Get-Date }
        }
        # The script is handed over encoded, so no quoting layer touches it; the root and the lib go in the
        # environment of the child. The child prints ONE json line with every non-ASCII character escaped, so the
        # console's code page cannot garble a document path. Bounded at 60 s like the gh and git calls.
        $script = @'
$ErrorActionPreference = 'Stop'
$Root = $env:DKJ_GP_ROOT
$Lib = $env:DKJ_GP_LIB
$cfg = Join-Path $Root 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $cfg) { try { . $cfg } catch { } }
. $Lib
$baseline = Read-AlwaysOnBaseline -RepoRoot $Root
$m = Get-AlwaysOnMeasurement -RepoRoot $Root -Baseline $baseline
$v = Get-AlwaysOnBudgetVerdict -Measurement $m -Budget (Resolve-AlwaysOnBudget) -Baseline $baseline
$docs = @()
foreach ($d in @($m.Measured)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]$d.Bytes; Source = 'measured' } }
foreach ($d in @($m.Carried)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]$d.Bytes; Source = 'carried' } }
foreach ($d in @($m.Unmeasured)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]0; Source = 'unmeasured' } }
$o = [pscustomobject]@{
    Total = [int64]$v.Total; Budget = [int64]$v.Budget; State = [string]$v.State; Ok = [bool]$v.Ok
    Tokens = [int64](ConvertTo-EstimatedTokens -Bytes $v.Total); Documents = @($docs)
}
$json = $o | ConvertTo-Json -Compress -Depth 4
[Console]::Out.WriteLine('DKJ-GP-RESULT ' + [regex]::Replace($json, '[^\x00-\x7F]', { param($x) '\u{0:x4}' -f [int][char]$x.Value }))
'@
        $env:DKJ_GP_ROOT = $root
        $env:DKJ_GP_LIB = $lib
        try {
            $run = Invoke-BoundedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -TimeoutSeconds 60 -WorkingDirectory $root -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script)))
        } finally {
            Remove-Item Env:\DKJ_GP_ROOT, Env:\DKJ_GP_LIB -ErrorAction SilentlyContinue
        }
        if ($run.TimedOut) { return @{ Model = $null; Error = 'the measurement did not finish within 60 s'; At = Get-Date } }
        $line = @($run.Output -split "`r?`n" | Where-Object { $_.StartsWith('DKJ-GP-RESULT ') }) | Select-Object -Last 1
        if (-not $line) { return @{ Model = $null; Error = 'the measurement returned nothing'; At = Get-Date } }
        $out = @(($line.Substring(14) | ConvertFrom-Json))
        $r = $out[-1]
        # An import through the marketplace clone resolves to an absolute path; the page names it from ~.
        $homeDir = ([string]$env:USERPROFILE).Replace('\', '/').TrimEnd('/')
        foreach ($d in @($r.Documents)) {
            if ($homeDir -and $d.Display.Replace('\', '/').StartsWith($homeDir + '/', [StringComparison]::OrdinalIgnoreCase)) {
                $d.Display = '~' + $d.Display.Replace('\', '/').Substring($homeDir.Length)
            }
        }
        $model = @{
            Total = $r.Total; Budget = $r.Budget; State = $r.State; Ok = $r.Ok; Tokens = $r.Tokens
            Documents = @($r.Documents | ForEach-Object { @{ Display = [string]$_.Display; Bytes = [int64]$_.Bytes; Source = [string]$_.Source } })
            GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); Seconds = ((Get-Date) - $started).TotalSeconds
        }
        return @{ Model = $model; Error = ''; At = Get-Date }
    } catch {
        return @{ Model = $null; Error = (([string]$_.Exception.Message) -replace '\s+', ' '); At = Get-Date }
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$rootHash = Get-DevPreviewRootHash -Root $root
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "general pages for $((Get-RepoIdentity).Name): http://localhost:$Port/"
$ssCache = $null
$isCache = $null

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        # A client that sends its head and then never reads must not hold the loop on Write either.
        $client.SendTimeout = 2000
        try {
            $request = Read-LoopbackRequest -Client $client -ReadTimeoutMs $ReadTimeoutMs
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $method, $target = ($request.RequestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-LoopbackHost -HostHeader $request.Host -Port $Port)) {
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
                # Whose server this is: the hash of the root it was started in. The hubs ask before they link here.
                Send-LoopbackResponse $stream 200 'OK' 'text/plain; charset=utf-8' ($utf8.GetBytes($rootHash)) -Method $method
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                $body = [System.IO.File]::ReadAllBytes($s.File)
                Send-LoopbackResponse $stream 200 'OK' $s.Type $body -Method $method
                continue
            }
            # The repo's DefaultTheme (#3390), read per request like the hub, so a session start that changes it
            # reaches the next page without a restart, and every page below opens in it.
            $state = Read-RepoHubState -Root $root
            Set-GeneralPagesThemeDefault $state.Theme
            if ($path -eq '/about') {
                # The hub is one page (#3289): an old link to About this repo goes on to the home page, which holds it.
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/' } -Method $method
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html' -or $path -eq '/hub') {
                # THE HUB IS THIS SERVER'S (#3245), built per request from the state file: unless the repo opted
                # out with OwnHub, in which case its own server is the hub and this one sends the visitor there.
                if ($state.Mode -eq 'ownhub') {
                    if ($state.Hub) {
                        Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = $state.Hub } -Method $method
                    } else {
                        Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('This repo''s hub is not known yet: the dev-preview hook records it at the next session start.')) -Method $method
                    }
                    continue
                }
                $hubMode = if ($state.Mode -eq 'product') { 'product' } else { 'none' }
                $hubHtml = Format-PluginRepoHubHtml -RepoName (Get-RepoIdentity).Name -Folder (Split-Path -Leaf $root) -Mode $hubMode -ProductUrl $state.Product -PagesUrl "http://localhost:$Port" -DkjSolutions:$dkjSolutions
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($hubHtml)) -Method $method
                continue
            }
            if ($path -eq '/repository') {
                # The hub's Repository page (#3383): the facts and the Issues page, which the home page no longer holds.
                $hubMode = if ($state.Mode -eq 'product') { 'product' } else { 'none' }
                $id = Get-RepoIdentity
                $repoHtml = Format-PluginRepoRepositoryHtml -RepoName $id.Name -Folder (Split-Path -Leaf $root) -Slug $id.Slug -Mode $hubMode -ProductUrl $state.Product -PagesUrl "http://localhost:$Port"
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($repoHtml)) -Method $method
                continue
            }
            if ($path -eq '/refresh') {
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for. ?page= names
                # where to go back to, from a fixed list, so the redirect never leaves this server.
                $page = if ([string]$target -match '[?&]page=(sessionstart|issues)(&|$)') { $Matches[1] } else { '' }
                if ($page -eq 'sessionstart') {
                    if ($ssCache -and ((Get-Date) - $ssCache.At).TotalSeconds -ge $MinRefreshSeconds) { $ssCache = $null }
                } elseif ($page -eq 'issues') {
                    # At least a minute: a re-read holds this single-threaded loop for about 12 s.
                    if ($isCache -and ((Get-Date) - $isCache.At).TotalSeconds -ge [Math]::Max($MinRefreshSeconds, 60)) { $isCache = $null }
                }
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" } -Method $method
                continue
            }
            if ($dkjSolutions -and $path -eq '/brandbook') {
                # The app is built for the base /brandbook/, so its own routes are read under the slash.
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/brandbook/' } -Method $method
                continue
            }
            if ($dkjSolutions -and $path.StartsWith('/brandbook/')) {
                # The brand book app's build, as the plugin ships it (#3210).
                $bb = Resolve-BrandbookFile -Path $path -BuildDir $brandbookDir
                if ($bb -and (Test-Path -LiteralPath $bb.File -PathType Leaf)) {
                    Send-LoopbackResponse $stream 200 'OK' (Get-BrandbookContentType -RelPath $bb.Rel) ([System.IO.File]::ReadAllBytes($bb.File)) -Method $method
                } elseif ($bb -and $bb.Rel -eq 'index.html') {
                    Send-LoopbackResponse $stream 503 'Service Unavailable' 'text/html; charset=utf-8' ($utf8.GetBytes((Format-BrandbookMissingHtml -RepoName (Get-RepoIdentity).Name))) -Method $method
                } else {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.')) -Method $method
                }
                continue
            }
            $html = $null
            if ($path -eq '/artifacts') {
                $ar = Get-JsonFileModel (Join-Path $root 'scripts\dashboard\artifacts.json')
                $html = Format-ArtifactsPageHtml -Model (ConvertFrom-ArtifactRegister -Register $ar.Json) -ReadError $ar.Error -RepoName (Get-RepoIdentity).Name
            } elseif ($path -eq '/issues') {
                # A failed read is kept for 30 s only, so a passing gh hiccup does not show for five minutes.
                $isAge = if ($isCache) { ((Get-Date) - $isCache.At).TotalSeconds } else { 0 }
                if ($null -eq $isCache -or $isAge -ge $IssuesCacheSeconds -or ($isCache.Error -and $isAge -ge 30)) { $isCache = Get-IssuesModel }
                $html = Format-IssuesPageHtml -Model $isCache.Model -ReadError $isCache.Error -GeneratedAt $isCache.GeneratedAt -Seconds $isCache.Seconds -RepoName (Get-RepoIdentity).Name
            } elseif ($path -eq '/sessionstart') {
                if ($null -eq $ssCache -or ((Get-Date) - $ssCache.At).TotalSeconds -ge $CacheSeconds) { $ssCache = Get-SessionStartModel }
                $snap = Get-SessionStartSnapshot
                $html = Format-SessionStartPageHtml -Model $ssCache.Model -ReadError $ssCache.Error -RepoName (Get-RepoIdentity).Name -Snapshot $snap.Data -SnapshotError $snap.Error
            } elseif ($path -eq '/release-notes') {
                $buildError = Update-ReleaseNotesPage
                if (-not (Test-Path -LiteralPath $releaseNotesFile -PathType Leaf)) {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes("Not built yet: this repo has no dkj-policy/releases/page/release-notes.html, and this server could not build it ($buildError).")) -Method $method
                    continue
                }
                $html = Format-ReleaseNotesDevPage -Html ([System.IO.File]::ReadAllText($releaseNotesFile, $utf8)) -RepoName (Get-RepoIdentity).Name
            }
            if ($null -ne $html) {
                $body = $utf8.GetBytes($html)
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' $body -Method $method
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
