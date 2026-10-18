<#
.SYNOPSIS
    Serve this repo's dev server on http://localhost:<Port>/ -- the Repo hub on '/', which links the
    pages below it (#3097): /connectors, every repo registered under connectors/ with its plugins, its
    local checkout and what check-connectors.ps1 reports for it on this machine (#2976); /release-notes;
    /sessionstart, the always-on path every session loads; /test-gate, the per-suite CI durations; and
    /artifacts, every claude.ai Artifact published from this repo, from scripts/dashboard/artifacts.json.
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
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateRange(1024, 65535)][int]$Port,
    [ValidateRange(0, 86400)][int]$CacheSeconds = 60,
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

function Get-ArtifactsModel {
    <# scripts/dashboard/artifacts.json, read on every request: one small file. #>
    $json = $null; $err = ''
    $path = Join-Path $root 'scripts\dashboard\artifacts.json'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $err = 'it is not valid JSON' }
    } else { $err = 'the file is not there' }
    return @{ Model = (ConvertFrom-ArtifactRegister -Register $json); Error = $err }
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
                $page = if ([string]$target -match '[?&]page=(connectors|sessionstart)(&|$)') { $Matches[1] } else { '' }
                if ($page -eq 'sessionstart') {
                    if ($ssCache -and ((Get-Date) - $ssCache.At).TotalSeconds -ge $MinRefreshSeconds) { $ssCache = $null }
                } elseif ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                Send-DashboardResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" }
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                $sha = Invoke-DashboardGit $root @('rev-parse', '--short', 'HEAD')
                $html = Format-RepoHubHtml -Pages (Get-RepoHubPages) -SourceCommit $(if ($sha) { [string]$sha[0] } else { '' })
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
                $html = Format-SessionStartPageHtml -Model $ssCache.Model -ReadError $ssCache.Error
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
