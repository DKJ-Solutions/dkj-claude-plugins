<#
.SYNOPSIS
    Serve this repo's dev server on http://localhost:<Port>/ -- the Repo hub on '/', which links the
    pages below it (#3097): /connectors, every repo registered under connectors/ with its plugins, its
    local checkout and what check-connectors.ps1 reports for it on this machine (#2976); /specialists, every
    specialist the dkj-subagents plugins ship and the context each one costs, read from this tree; and /test-gate,
    the per-suite CI durations. The rules of the hub and the test-gate page are in scripts/lib/dev-pages-lib.ps1.

    THE GENERAL PAGES ARE NOT SERVED HERE (#3119): Artifacts, Issues, Release notes and SessionStart belong to
    every DKJ-Solutions repo, so the dkj-solutions plugin serves them from a server of its own
    (scripts/pages/serve-general-pages.ps1), which the dev-preview hook starts beside this one. This server
    only links it. The hook writes both servers' urls to a state file in %TEMP%; the hub reads it on every
    request and draws its General card from it, asking the server named there who it is (its /whoami, the
    hash of this root) for at most ~500 ms and showing the "not running" form when nothing answers, or the
    wrong checkout does. A request for /artifacts, /issues, /release-notes or /sessionstart is answered with
    a 303 to the same path on that server when it answers as this checkout's, and with a short 404 text
    naming the general pages server when it does not.

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
# The state file the hook writes, and the probe of the general pages server (#3119): the plugin's, read from
# this repo's own tree because this repo is the plugin's source.
. (Join-Path $root 'plugins\dkj-policy\dkj-solutions\scripts\lib\general-pages-state.ps1')

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
$styleDir = Join-Path $root 'scripts\dashboard\house-style'
$static = @{
    '/house-style.css' = @{ File = (Join-Path $styleDir 'house-style.css'); Type = 'text/css; charset=utf-8' }
    '/house-theme.js'  = @{ File = (Join-Path $styleDir 'house-theme.js');  Type = 'text/javascript; charset=utf-8' }
}
# The routes that moved to the general pages server (#3119): each is sent on, or answered with a 404 text.
$generalRoutes = @('/artifacts', '/issues', '/release-notes', '/sessionstart')

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
    $result = @{ RequestLine = $lines[0]; Host = ''; SecFetchSite = ''; SecFetchMode = '' }
    foreach ($h in @($lines | Select-Object -Skip 1)) {
        if ($h -match '^Host:\s*(.*)$') { $result.Host = $Matches[1] }
        elseif ($h -match '^Sec-Fetch-Site:\s*(.*)$') { $result.SecFetchSite = $Matches[1] }
        elseif ($h -match '^Sec-Fetch-Mode:\s*(.*)$') { $result.SecFetchMode = $Matches[1] }
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
            if (Test-DashboardCrossSite -SecFetchSite $request.SecFetchSite -SecFetchMode $request.SecFetchMode -Method $method) {
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
            if ($path -eq '/refresh') {
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for. ?page= names
                # where to go back to, from a fixed list, so the redirect never leaves this server.
                $page = if ([string]$target -match '[?&]page=(connectors)(&|$)') { $Matches[1] } else { '' }
                if ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                Send-DashboardResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" }
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                $html = Format-RepoHubHtml -Pages (Get-RepoHubPages) -SourceCommit $(if ($loadedSha) { $loadedSha.Substring(0, 8) } else { '' }) -GeneralPagesUrl (Get-GeneralPagesUrl -Root $root -TimeoutMs 500)
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
            if ($path -eq '/test-gate') {
                $tg = Get-TestGateModel
                $html = Format-TestGatePageHtml -Model $tg.Model -ReadError $tg.Error
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($path -eq '/specialists') {
                $sp = Get-SpecialistsModel
                $html = Format-SpecialistsPageHtml -Rows $sp.Rows -ReadError $sp.Error -CharsPerToken $sp.CharsPerToken
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-DashboardResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            if ($generalRoutes -contains $path) {
                # Moved to the plugin's general pages server (#3119): sent on when the state file names it.
                $pages = Get-GeneralPagesUrl -Root $root -TimeoutMs 500
                if ($pages) {
                    Send-DashboardResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = $pages + $path }
                } else {
                    Send-DashboardResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes("This page is served by the dkj-solutions general pages server, which is not running for this repo: the dev-preview hook starts it at the next session start."))
                }
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
