<#
.SYNOPSIS
    Serve the placeholder preview (#3047) on http://localhost:<Port>/ -- the page the dev-preview hook
    opens in a repo that states no Get-DevPreview (every repo since #3198, when it moved into dkj-policy).

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
    /house-style.css and /house-theme.js from the canonical copy in this plugin's payload -- and runs until the process is
    stopped. The page is built per request, because its General card (#3119) links the general pages
    server the hook's state file names, when that server answers /whoami as this checkout's within 500 ms, and says it is
    not running otherwise. Its DKJ-Solutions card is there only where the repo enables dkj-solutions, read at start.

    Pure ASCII (repo convention for .ps1). The page and the request rules are in
    hub/lib/dev-preview-placeholder.ps1, tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
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
. (Join-Path $PSScriptRoot '..\lib\general-pages-state.ps1')

# The root the hook's state file is named for: the working directory, which its cmd.exe set to the root.
$repoRoot = [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/')
$repoName = Split-Path -Leaf $repoRoot
$styleDir = Get-HouseStyleDir -PluginRoot (Join-Path $PSScriptRoot '..\..')
$dkjSolutions = Test-DkjSolutionsEnabled -Root $repoRoot
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
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
            $request = Read-LoopbackRequest -Client $client -ReadTimeoutMs $ReadTimeoutMs
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $method, $target = ($request.RequestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-DevPreviewPlaceholderHost -HostHeader $request.Host -Port $Port)) {
                Send-LoopbackResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.')) -Method $method
                continue
            }
            if (Test-DevPreviewPlaceholderCrossSite -SecFetchSite $request.SecFetchSite -SecFetchMode $request.SecFetchMode -Method $method) {
                Send-LoopbackResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: another site may not drive this server.')) -Method $method
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-LoopbackResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' } -Method $method
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                $body = [System.IO.File]::ReadAllBytes($s.File)
                Send-LoopbackResponse $stream 200 'OK' $s.Type $body -Method $method
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                # Built per request: the General card follows the state file and whether that server answers.
                $body = $utf8.GetBytes((Format-DevPreviewPlaceholderHtml -RepoName $repoName -GeneralPagesUrl (Get-GeneralPagesUrl -Root $repoRoot) -DkjSolutions:$dkjSolutions))
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
