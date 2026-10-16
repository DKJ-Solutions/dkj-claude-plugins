<#
.SYNOPSIS
    Serve the connector dashboard (#2976) on http://localhost:<Port>/ -- one page with every repo
    registered under connectors/, its plugins, its local checkout and what check-connectors.ps1 reports
    for it on this machine.

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

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
$styleDir = Join-Path $root 'scripts\dashboard\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
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
    $meta = @{ GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); SourceCommit = ''; Seconds = $null; CheckFailed = $null }
    $sha = Invoke-DashboardGit $root @('rev-parse', '--short', 'HEAD')
    if ($sha) { $meta.SourceCommit = [string]$sha[0] }

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
        $resolvedCandidate = $null
        foreach ($cand in $candidates) {
            # The manifest is data from a public repo and git runs in the folder it names, so the path is
            # held to check-connectors' own bound: relative, and resolving under the scope root.
            if ([System.IO.Path]::IsPathRooted($cand)) { continue }
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $cand))
            if (-not (Test-DashboardCheckoutInScope -Full $full -ScopeRoot $scopeRoot)) { continue }
            if (Test-Path -LiteralPath $full -PathType Container) { $resolved = $full; $resolvedCandidate = $cand; break }
        }
        $signals = if ($parsed.Contains($repo)) { @($parsed[$repo].Signals) } else { @() }
        $plugins = @(@($m.plugins) | Where-Object { $_ } | ForEach-Object { @{ Id = [string]$_.id; Extensions = @($_.extensions) } })
        $connectors += @{
            Repo       = $repo
            Visibility = [string]$m.visibility
            File       = $f.Name
            Checkout   = $candidates
            CheckoutHere = $resolvedCandidate
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
            if ($path -eq '/refresh') {
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for.
                if ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                Send-DashboardResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/' }
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                if ($null -eq $cache -or ((Get-Date) - $cache.At).TotalSeconds -ge $CacheSeconds) { $cache = Get-DashboardModel }
                $html = Format-ConnectorDashboardHtml -Connectors $cache.Connectors -Meta $cache.Meta
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
