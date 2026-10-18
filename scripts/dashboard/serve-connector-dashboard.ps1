<#
.SYNOPSIS
    Serve this repo's dev server on http://localhost:<Port>/ -- the Repo hub on '/', which links the
    pages below it (#3097): /connectors, every repo registered under connectors/ with its plugins, its
    local checkout and what check-connectors.ps1 reports for it on this machine (#2976); /release-notes;
    /sessionstart, the always-on path every session loads; /test-gate, the per-suite CI durations; and
    /artifacts, every claude.ai Artifact published from this repo, from scripts/dashboard/artifacts.json;
    and /issues, this repo's GitHub issues as gh reads them.
    The rules of the hub and the measurement pages are in scripts/lib/dev-pages-lib.ps1.

.DESCRIPTION
    Normally started by the dkj-solutions dev-preview SessionStart hook, through this repo's
    Get-DevPreview in scripts/repo-config.ps1; it can be started by hand the same way:

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

.PARAMETER IssuesCacheSeconds
    How long one read of the GitHub issues is served: three gh calls take about 12 s, so longer than
    -CacheSeconds. /refresh?page=issues reads them again sooner.

.PARAMETER ReadTimeoutMs
    How long a connection may take to send its whole request head (one deadline, not one per read).

.PARAMETER MinRefreshSeconds
    The shortest interval between two re-runs that /refresh can cause.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of the one this script sits in.
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

$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $root 'scripts\lib\connector-dashboard-lib.ps1')
. (Join-Path $root 'scripts\lib\dev-pages-lib.ps1')

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
$styleDir = Join-Path $root 'scripts\dashboard\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}
# The release-notes page build-release-notes-page.ps1 leaves here: this repo hosts it nowhere else (#3083).
# Served through Format-ReleaseNotesDevPage, which gives it the house style and the breadcrumb bar (#3108).
$releaseNotesFile = Join-Path $root 'dkj-policy\releases\page\release-notes.html'

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
        $resolved = $null
        foreach ($cand in $candidates) {
            # The manifest is data from a public repo and git runs in the folder it names, so the path is
            # held to check-connectors' own bound: relative, and resolving under the scope root.
            if ([System.IO.Path]::IsPathRooted($cand)) { continue }
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $cand))
            if (-not (Test-DashboardCheckoutInScope -Full $full -ScopeRoot $scopeRoot)) { continue }
            if (Test-Path -LiteralPath $full -PathType Container) { $resolved = $full; break }
        }
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

function Get-SessionStartModel {
    <#
        The always-on path, measured the way always-on-sessioncheck measures it. In a CHILD process,
        because the measurement dot-sources repo-config.ps1 and three libs, and their functions must not
        land in this server's scope. The child hands back objects, deserialized; a failure is a ReadError.
    #>
    $started = Get-Date
    $ErrorActionPreference = 'Continue'   # the same 5.1 stderr trap as in Invoke-DashboardGit
    try {
        $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command {
                param($Root)
                $ErrorActionPreference = 'Stop'
                $cfg = Join-Path $Root 'scripts\repo-config.ps1'
                if (Test-Path -LiteralPath $cfg) { try { . $cfg } catch { } }
                . (Join-Path $Root 'scripts\lib\always-on-budget-lib.ps1')
                $baseline = Read-AlwaysOnBaseline -RepoRoot $Root
                $m = Get-AlwaysOnMeasurement -RepoRoot $Root -Baseline $baseline
                $v = Get-AlwaysOnBudgetVerdict -Measurement $m -Budget (Resolve-AlwaysOnBudget) -Baseline $baseline
                $docs = @()
                foreach ($d in @($m.Measured)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]$d.Bytes; Source = 'measured' } }
                foreach ($d in @($m.Carried)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]$d.Bytes; Source = 'carried' } }
                foreach ($d in @($m.Unmeasured)) { $docs += [pscustomobject]@{ Display = [string]$d.Display; Bytes = [int64]0; Source = 'unmeasured' } }
                [pscustomobject]@{
                    Total = [int64]$v.Total; Budget = [int64]$v.Budget; State = [string]$v.State; Ok = [bool]$v.Ok
                    Tokens = [int64](ConvertTo-EstimatedTokens -Bytes $v.Total); Documents = $docs
                }
            } -args $root 2>$null | Where-Object { $_ -and $_.PSObject.Properties['Total'] })
        if (-not $out.Count) { return @{ Model = $null; Error = 'the measurement returned nothing'; At = Get-Date } }
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

function Get-TestGateModel {
    <# scripts/tests/suite-durations.json and the suite files beside it, read on every request: one small file. #>
    $testsDir = Join-Path $root 'scripts\tests'
    $files = @(Get-ChildItem -LiteralPath $testsDir -Filter '*.tests.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $json = $null; $err = ''
    $path = Join-Path $testsDir 'suite-durations.json'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $err = 'it is not valid JSON' }
    } else { $err = 'the file is not there' }
    return @{ Model = (ConvertFrom-SuiteDurations -Durations $json -SuiteFiles $files); Error = $err }
}

function Get-SessionStartSnapshot {
    <# scripts/dashboard/session-start-snapshot.json, read on every request: one small file. A missing file is no error. #>
    $path = Join-Path $root 'scripts\dashboard\session-start-snapshot.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Data = $null; Error = '' } }
    try { return @{ Data = (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json); Error = '' } }
    catch { return @{ Data = $null; Error = 'it is not valid JSON' } }
}

function Get-ArtifactsModel {
    <# scripts/dashboard/artifacts.json, read on every request: one small file. #>
    $json = $null; $err = ''
    $path = Join-Path $root 'scripts\dashboard\artifacts.json'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $err = 'it is not valid JSON' }
    } else { $err = 'the file is not there' }
    return @{ Model = (ConvertFrom-ArtifactRegister -Register $json); Error = $err }
}

function Get-IssuesModel {
    <#
        This repo's issues from GitHub: every open one, and those created or closed in the last 28 days --
        three gh calls, about 4 s each, so the result is cached for -IssuesCacheSeconds. A search returns at
        most 1,000 issues, which is what bounds the window. A gh failure is a ReadError, never a blank page.
    #>
    $started = Get-Date
    $since = $started.ToUniversalTime().AddDays(-28).ToString('yyyy-MM-dd')
    $fields = 'number,title,state,stateReason,labels,assignees,createdAt,closedAt'
    $ErrorActionPreference = 'Continue'   # the same 5.1 stderr trap as in Invoke-DashboardGit
    # Loaded here rather than at start: it pulls in libs of its own, and only this page needs it. Its
    # functions live in this call's scope; a lib that fails to load surfaces as the read error below.
    try { . (Join-Path $root 'scripts\lib\native-capture-lib.ps1') } catch { }
    $read = {
        param([string[]]$Extra)
        # -Utf8: gh writes UTF-8, and 5.1 would decode a title's non-ASCII through the console code page.
        $q = Invoke-NativeCapture -Utf8 -DiscardStderr -TimeoutSeconds 60 -FilePath 'gh' -Arguments (@(
                'issue', 'list', '--repo', 'DKJ-Solutions/dkj-claude-plugins', '--limit', '1000', '--json', $fields) + $Extra)
        if ($q.TimedOut) { throw 'gh issue list did not answer within 60 s' }
        if (-not (Test-NativeExitMeasured -Capture $q)) { throw 'gh issue list left no exit code' }
        if ($q.ExitCode -ne 0 -or $q.ShortRead) { throw "gh issue list exited $($q.ExitCode)" }
        # 5.1's ConvertFrom-Json emits a JSON array as ONE object, so it is enumerated before it is wrapped.
        $parsed = ConvertFrom-Json -InputObject (@($q.Output) -join "`n")
        return , @($parsed | ForEach-Object { $_ })
    }
    try {
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

function Read-DashboardRequest {
    <#
        The request line and the two headers the server reads, or $null. ONE deadline for the whole head
        (-ReadTimeoutMs), not one per read, and at most $MaxHeadBytes: a client that sends nothing, drips a
        byte at a time or never ends its line is dropped, so it cannot hold the single-threaded loop.
    #>
    param($Client)
    $stream = $Client.GetStream()
    $buffer = New-Object byte[] 1024
    $head = New-Object System.IO.MemoryStream
    $deadline = [DateTime]::UtcNow.AddMilliseconds($ReadTimeoutMs)
    while ($true) {
        $left = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($left -le 0) { return $null }
        $Client.ReceiveTimeout = $left
        $n = $stream.Read($buffer, 0, $buffer.Length)
        if ($n -le 0) { return $null }
        $head.Write($buffer, 0, $n)
        if ($head.Length -gt $MaxHeadBytes) { return $null }
        $text = [System.Text.Encoding]::ASCII.GetString($head.ToArray())
        $end = $text.IndexOf("`r`n`r`n")
        if ($end -ge 0) { break }
    }
    $lines = $text.Substring(0, $end) -split "`r`n"
    $result = @{ RequestLine = $lines[0]; Host = ''; SecFetchSite = '' }
    foreach ($h in @($lines | Select-Object -Skip 1)) {
        if ($h -match '^Host:\s*(.*)$') { $result.Host = $Matches[1] }
        elseif ($h -match '^Sec-Fetch-Site:\s*(.*)$') { $result.SecFetchSite = $Matches[1] }
    }
    return $result
}

function Send-DashboardResponse {
    param($Stream, [int]$Status, [string]$Reason, [string]$Type, [byte[]]$Body, [hashtable]$Headers = @{})
    $head = "HTTP/1.1 $Status $Reason`r`nContent-Type: $Type`r`nContent-Length: $($Body.Length)`r`n" +
        "Cache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n"
    foreach ($k in $Headers.Keys) { $head += "$k`: $($Headers[$k])`r`n" }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($head + "`r`n")
    $Stream.Write($bytes, 0, $bytes.Length)
    if ($Body.Length) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

$MaxHeadBytes = 8192
$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "connector dashboard: http://localhost:$Port/"
$cache = $null
$ssCache = $null
$isCache = $null
# The commit this process loaded its code from; $null outside a git checkout or on an unborn HEAD, and
# then it never restarts.
$loaded = Invoke-DashboardGit $root @('rev-parse', 'HEAD')
$loadedSha = if ($loaded) { [string]$loaded[0] } else { $null }
$restart = $false

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $request = Read-DashboardRequest -Client $client
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $requestLine = $request.RequestLine
            $hostHeader = $request.Host
            $method, $target = ($requestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-DashboardHost -HostHeader $hostHeader -Port $Port)) {
                Send-DashboardResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.'))
                continue
            }
            if (Test-DashboardCrossSite $request.SecFetchSite) {
                Send-DashboardResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: another site may not drive this server.'))
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-DashboardResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' }
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { [System.IO.File]::ReadAllBytes($s.File) }
                Send-DashboardResponse $stream 200 'OK' $s.Type $body
                continue
            }
            if ($loadedSha) {
                $live = Invoke-DashboardGit $root @('rev-parse', 'HEAD')
                if ($live -and [string]$live[0] -ne $loadedSha) {
                    $text = "This server was started on $($loadedSha.Substring(0, 8)); the checkout is now at $(([string]$live[0]).Substring(0, 8)). It is restarting on the new code -- this page reloads in a few seconds."
                    Send-DashboardResponse $stream 503 'Service Unavailable' 'text/plain; charset=utf-8' ($utf8.GetBytes($text)) @{ 'Retry-After' = '3'; Refresh = '3' }
                    $restart = $true
                    break
                }
            }
            if ($path -eq '/release-notes') {
                if (-not (Test-Path -LiteralPath $releaseNotesFile -PathType Leaf)) {
                    Send-DashboardResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not built yet: run scripts/release/build-release-notes-page.ps1.'))
                    continue
                }
                $html = Format-ReleaseNotesDevPage -Html ([System.IO.File]::ReadAllText($releaseNotesFile, $utf8))
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/refresh') {
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for. ?page= names
                # where to go back to, from a fixed list, so the redirect never leaves this server.
                $page = if ([string]$target -match '[?&]page=(connectors|sessionstart|issues)(&|$)') { $Matches[1] } else { '' }
                if ($page -eq 'sessionstart') {
                    if ($ssCache -and ((Get-Date) - $ssCache.At).TotalSeconds -ge $MinRefreshSeconds) { $ssCache = $null }
                } elseif ($page -eq 'issues') {
                    # At least a minute: a re-read holds this single-threaded loop for about 12 s.
                    if ($isCache -and ((Get-Date) - $isCache.At).TotalSeconds -ge [Math]::Max($MinRefreshSeconds, 60)) { $isCache = $null }
                } elseif ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                Send-DashboardResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" }
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                $html = Format-RepoHubHtml -Pages (Get-RepoHubPages) -SourceCommit $(if ($loadedSha) { $loadedSha.Substring(0, 8) } else { '' })
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/connectors') {
                if ($null -eq $cache -or ((Get-Date) - $cache.At).TotalSeconds -ge $CacheSeconds) { $cache = Get-DashboardModel }
                $html = Format-ConnectorDashboardHtml -Connectors $cache.Connectors -Meta $cache.Meta
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/sessionstart') {
                if ($null -eq $ssCache -or ((Get-Date) - $ssCache.At).TotalSeconds -ge $CacheSeconds) { $ssCache = Get-SessionStartModel }
                $snap = Get-SessionStartSnapshot
                $html = Format-SessionStartPageHtml -Model $ssCache.Model -ReadError $ssCache.Error -Snapshot $snap.Data -SnapshotError $snap.Error
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/issues') {
                # A failed read is kept for 30 s only, so a passing gh hiccup does not show for five minutes.
                $isAge = if ($isCache) { ((Get-Date) - $isCache.At).TotalSeconds } else { 0 }
                if ($null -eq $isCache -or $isAge -ge $IssuesCacheSeconds -or ($isCache.Error -and $isAge -ge 30)) { $isCache = Get-IssuesModel }
                $html = Format-IssuesPageHtml -Model $isCache.Model -ReadError $isCache.Error -GeneratedAt $isCache.GeneratedAt -Seconds $isCache.Seconds
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/test-gate') {
                $tg = Get-TestGateModel
                $html = Format-TestGatePageHtml -Model $tg.Model -ReadError $tg.Error
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/artifacts') {
                $ar = Get-ArtifactsModel
                $html = Format-ArtifactsPageHtml -Model $ar.Model -ReadError $ar.Error
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            Send-DashboardResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.'))
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
