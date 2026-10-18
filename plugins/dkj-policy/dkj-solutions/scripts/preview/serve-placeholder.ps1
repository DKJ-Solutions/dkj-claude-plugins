<#
.SYNOPSIS
    Serve the placeholder preview (#3047) on http://localhost:<Port>/ -- the page the dev-preview hook
    opens in a DKJ-Solutions repo that states no Get-DevPreview.

.DESCRIPTION
    Started by hooks/dev-preview-sessionstart.ps1 under a cmd.exe that changes into the repo root first,
    so the working directory IS the repo, and the page takes the repo's name from it. That cmd.exe's
    command line is also what lets the hook recognise this server as the checkout's own next time, exactly
    as for a repo's own server.

    A TcpListener ON 127.0.0.1, NOT AN HttpListener (#2976): under HttpListener the socket belongs to
    http.sys (PID 4), so the hook's ownership walk could never reach the cmd.exe that names the checkout,
    and every session would start another placeholder on the next port. Loopback only, and a request whose
    Host is not localhost:<Port> or 127.0.0.1:<Port> is refused (DNS rebinding), as is one the browser
    marks as coming from another site.

    One request at a time, each answered with Connection: close. A connection whose request head is not
    complete within -ReadTimeoutMs, or is longer than 8 KB, is dropped. It serves three paths -- the page,
    /house-style.css and /house-theme.js from the plugin's canonical copy -- and runs until the process is
    stopped.

    Pure ASCII (repo convention for .ps1). The page and the request rules are in
    scripts/lib/dev-preview-placeholder.ps1, tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo.

.PARAMETER Port
    The loopback port to listen on (1024-65535).

.PARAMETER ReadTimeoutMs
    How long a connection may take to send its whole request head (one deadline, not one per read).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateRange(1024, 65535)][int]$Port,
    [ValidateRange(100, 60000)][int]$ReadTimeoutMs = 1000
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\dev-preview-placeholder.ps1')

$repoName = Split-Path -Leaf ((Get-Location).Path.TrimEnd('\', '/'))
$styleDir = Join-Path $PSScriptRoot '..\..\assets\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}

function Read-PlaceholderRequest {
    <# The request line and the two headers the server reads, or $null -- one deadline, at most 8 KB. #>
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
        if ($head.Length -gt 8192) { return $null }
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

function Send-PlaceholderResponse {
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
$page = $utf8.GetBytes((Format-DevPreviewPlaceholderHtml -RepoName $repoName))
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "placeholder preview for ${repoName}: http://localhost:$Port/"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        # A client that sends its head and then never reads must not hold the loop on Write either
        # (Sebastian's review, #3047).
        $client.SendTimeout = 2000
        try {
            $request = Read-PlaceholderRequest -Client $client
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $method, $target = ($request.RequestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-DevPreviewPlaceholderHost -HostHeader $request.Host -Port $Port)) {
                Send-PlaceholderResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.'))
                continue
            }
            if (Test-DevPreviewPlaceholderCrossSite $request.SecFetchSite) {
                Send-PlaceholderResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: another site may not drive this server.'))
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-PlaceholderResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' }
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { [System.IO.File]::ReadAllBytes($s.File) }
                Send-PlaceholderResponse $stream 200 'OK' $s.Type $body
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $page }
                Send-PlaceholderResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            Send-PlaceholderResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.'))
        } catch {
            # A dropped or silent connection ends that request, never the server.
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
