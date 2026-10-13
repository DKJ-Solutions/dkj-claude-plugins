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
    check-connectors.ps1 -SkipDrift again (about three seconds), reads every connectors/*.json, and asks
    git for each checkout's branch, uncommitted count and ahead/behind against its upstream -- local refs
    only, no fetch. /refresh drops the cache and redirects to the page.

    One request at a time, each answered with Connection: close; a connection that sends nothing within
    -ReadTimeoutMs is dropped, so a browser's speculative connection cannot stall the loop. It runs until
    the process is stopped.

    Pure ASCII (repo convention for .ps1). The page's rules are in scripts/lib/connector-dashboard-lib.ps1,
    tested by scripts/tests/connector-dashboard.tests.ps1.

.PARAMETER Port
    The loopback port to listen on (1024-65535).

.PARAMETER CacheSeconds
    How long one read of the register is served before the next request reads it again.

.PARAMETER ReadTimeoutMs
    How long a connection may take to send its request line.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of the one this script sits in.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateRange(1024, 65535)][int]$Port,
    [ValidateRange(0, 86400)][int]$CacheSeconds = 60,
    [ValidateRange(100, 60000)][int]$ReadTimeoutMs = 3000,
    [string]$RepoRootOverride
)

$ErrorActionPreference = 'Stop'

$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $root 'scripts\lib\connector-dashboard-lib.ps1')

$styleDir = Join-Path $root 'scripts\dashboard\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}

function Invoke-DashboardGit {
    param([string]$Path, [string[]]$GitArgs)
    $out = & git -C $Path @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    # The comma keeps a one-line answer an array: unrolled, '[0]' would index the string's first letter.
    return , @($out)
}

function Get-DashboardGitInfo {
    <# Branch, uncommitted count and ahead/behind of one checkout, from local refs only. #>
    param([string]$Path)
    $branch = Invoke-DashboardGit $Path @('rev-parse', '--abbrev-ref', 'HEAD')
    if ($null -eq $branch) { return @{ Branch = $null } }
    $dirty = Invoke-DashboardGit $Path @('status', '--porcelain')
    $info = @{ Branch = [string]$branch[0]; Dirty = @($dirty | Where-Object { $_ }).Count; Ahead = $null; Behind = $null; Subject = ''; When = '' }
    $counts = Invoke-DashboardGit $Path @('rev-list', '--left-right', '--count', 'HEAD...@{u}')
    if ($counts -and ([string]$counts[0]) -match '^(\d+)\s+(\d+)$') { $info.Ahead = [int]$Matches[1]; $info.Behind = [int]$Matches[2] }
    $last = Invoke-DashboardGit $Path @('log', '-1', '--format=%cr%x09%s')
    if ($last -and ([string]$last[0]) -match '^([^\t]*)\t(.*)$') { $info.When = $Matches[1]; $info.Subject = $Matches[2] }
    return $info
}

function Get-DashboardModel {
    $started = Get-Date
    $meta = @{ GeneratedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); SourceCommit = ''; Seconds = $null; CheckFailed = $null }
    $sha = Invoke-DashboardGit $root @('rev-parse', '--short', 'HEAD')
    if ($sha) { $meta.SourceCommit = [string]$sha[0] }

    $parsed = @{}
    try {
        $check = Join-Path $root 'scripts\sync\check-connectors.ps1'
        $lines = & powershell -NoProfile -ExecutionPolicy Bypass -File $check -SkipDrift 2>&1 | ForEach-Object { [string]$_ }
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
            # The manifest is data from a public repo: only a relative path stays inside the scope root.
            if ([System.IO.Path]::IsPathRooted($cand)) { continue }
            $full = [System.IO.Path]::GetFullPath((Join-Path $root $cand))
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
            Status     = Get-ConnectorStatus $signals
            Git        = if ($resolved) { Get-DashboardGitInfo $resolved } else { $null }
            Notes      = [string]$m.notes
        }
    }
    $meta.Seconds = ((Get-Date) - $started).TotalSeconds
    return @{ Connectors = $connectors; Meta = $meta; At = Get-Date }
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

$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "connector dashboard: http://localhost:$Port/"
$cache = $null

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = $ReadTimeoutMs
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
            $requestLine = $reader.ReadLine()
            if (-not $requestLine) { continue }
            $hostHeader = ''
            for ($i = 0; $i -lt 100; $i++) {
                $h = $reader.ReadLine()
                if (-not $h) { break }
                if ($h -match '^Host:\s*(.*)$') { $hostHeader = $Matches[1] }
            }
            $method, $target = ($requestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-DashboardHost -HostHeader $hostHeader -Port $Port)) {
                Send-DashboardResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.'))
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-DashboardResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' }
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                Send-DashboardResponse $stream 200 'OK' $s.Type ([System.IO.File]::ReadAllBytes($s.File))
                continue
            }
            if ($path -eq '/refresh') {
                $cache = $null
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
