<#
.SYNOPSIS
    Serve the GENERAL pages of a DKJ-Solutions repo's Repo hub (#3119) on http://localhost:<Port>/ --
    /artifacts, /issues, /release-notes and /sessionstart -- from the repo this server was started in.

.DESCRIPTION
    Started by hooks/dev-preview-sessionstart.ps1 beside the repo's own dev server, under a cmd.exe that
    changes into the repo root first, so the working directory IS the repo and that cmd.exe's command line
    is what lets the hook recognise this server as the checkout's own next time, exactly as for the
    placeholder. A repo whose own server is not PowerShell (Vite, Next.js) gets the same four pages this way,
    and its hub links here. The pages and their rules are in scripts/lib/general-pages-lib.ps1.

    WHAT EACH PAGE READS, from the repo, on every request unless it says otherwise:
      /artifacts      scripts/dashboard/artifacts.json -- absent, the page says the file is not there.
      /issues         `gh issue list`, three calls (the open issues; created and closed in the last 28 days),
                      for --repo <owner/name> parsed from the origin remote when that is on github.com, else
                      for the repo gh finds from the working directory. Kept for -IssuesCacheSeconds; a failed
                      read for 30 s only. A gh that fails or is missing is a warning on the page, never a blank.
      /release-notes  dkj-policy/releases/page/release-notes.html, dressed in the house style on the way out;
                      a 404 text where the page is not built.
      /sessionstart   the always-on path, measured in a CHILD process by always-on-budget-lib.ps1, found in
                      the repo's own scripts/lib, else in the plugin's source tree, else in the highest
                      dkj-policy version in the plugin cache. Kept for -CacheSeconds.
      /hub and /      a 303 to the repo's own hub, whose url the hook wrote to the state file
                      (%TEMP%\dkj-repo-hub-<leaf>-<hash>.json); a plain 404 text where it names none.
      /refresh        ?page=issues or ?page=sessionstart drops that page's cache (at most once per
                      -MinRefreshSeconds, and per 60 s for issues) and goes back to the page.
      /house-style.css, /house-theme.js   the plugin's vendored copy under assets/house-style/.
    The repo's name on the pages is owner/name from the origin remote, else the folder's name.

    A TcpListener ON 127.0.0.1, NOT AN HttpListener (#2976): under HttpListener the socket belongs to
    http.sys (PID 4), so the hook's ownership walk could never reach the cmd.exe that names the checkout, and
    every session would start another server on the next port. Loopback only, and a request whose Host is not
    localhost:<Port> or 127.0.0.1:<Port> is refused (DNS rebinding), as is one the browser marks as coming
    from another site. GET and HEAD only.

    One request at a time, each answered with Connection: close. A connection whose request head is not
    complete within -ReadTimeoutMs, or is longer than 8 KB, is dropped, and one that never reads its answer
    is cut after 2 s. Every child process (git, gh, the measurement) is bounded, by a process helper of this
    file's own: the plugin depends on no lib of dkj-policy. It runs until the process is stopped.

    Pure ASCII (repo convention for .ps1). The pages and the request rules are in scripts/lib/
    general-pages-lib.ps1 and dev-preview-placeholder.ps1, tested by scripts/tests/dev-pages.tests.ps1 and
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
# The request rules the placeholder already has (the Host and Sec-Fetch-Site checks): one copy in the plugin.
. (Join-Path $PSScriptRoot '..\lib\dev-preview-placeholder.ps1')

$pluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/') }
$styleDir = Join-Path $pluginRoot 'assets\house-style'
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
        return @{ Output = [string]$out.Result; ExitCode = $p.ExitCode; TimedOut = $false }
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

function Resolve-AlwaysOnBudgetLib {
    <# The always-on-budget-lib.ps1 this server measures with, or '': the first of Get-AlwaysOnBudgetLibCandidates that exists. #>
    $cacheDir = Join-Path (Split-Path -Parent (Split-Path -Parent $pluginRoot)) 'dkj-policy'
    $versions = @(if (Test-Path -LiteralPath $cacheDir -PathType Container) { Get-ChildItem -LiteralPath $cacheDir -Directory | ForEach-Object { $_.Name } })
    foreach ($c in @(Get-AlwaysOnBudgetLibCandidates -RepoRoot $root -PluginRoot $pluginRoot -PolicyVersions $versions)) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }
    return ''
}

function Get-SessionStartModel {
    <#
        The always-on path, measured the way always-on-sessioncheck measures it. In a CHILD process,
        because the measurement dot-sources repo-config.ps1 and the libs, and their functions must not land
        in this server's scope. The child hands back objects, deserialized; a failure is a ReadError.
    #>
    $started = Get-Date
    $ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1 turns a native command's stderr into a terminating error under 'Stop'
    try {
        $lib = Resolve-AlwaysOnBudgetLib
        if (-not $lib) {
            return @{ Model = $null; Error = 'always-on-budget-lib.ps1 was not found in the repo, the plugin''s source tree or the plugin cache'; At = Get-Date }
        }
        $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command {
                param($Root, $Lib)
                $ErrorActionPreference = 'Stop'
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
                [pscustomobject]@{
                    Total = [int64]$v.Total; Budget = [int64]$v.Budget; State = [string]$v.State; Ok = [bool]$v.Ok
                    Tokens = [int64](ConvertTo-EstimatedTokens -Bytes $v.Total); Documents = $docs
                }
            } -args $root, $lib 2>$null | Where-Object { $_ -and $_.PSObject.Properties['Total'] })
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

function Read-GeneralPagesRequest {
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

function Send-GeneralPagesResponse {
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
Write-Host "general pages for $((Get-RepoIdentity).Name): http://localhost:$Port/"
$ssCache = $null
$isCache = $null

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        # A client that sends its head and then never reads must not hold the loop on Write either.
        $client.SendTimeout = 2000
        try {
            $request = Read-GeneralPagesRequest -Client $client
            if ($null -eq $request) { continue }
            $stream = $client.GetStream()
            $method, $target = ($request.RequestLine -split ' ')[0, 1]
            $path = ([string]$target -split '\?')[0]

            if (-not (Test-DevPreviewPlaceholderHost -HostHeader $request.Host -Port $Port)) {
                Send-GeneralPagesResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: this server answers only to localhost.'))
                continue
            }
            if (Test-DevPreviewPlaceholderCrossSite $request.SecFetchSite) {
                Send-GeneralPagesResponse $stream 403 'Forbidden' 'text/plain; charset=utf-8' ($utf8.GetBytes('Forbidden: another site may not drive this server.'))
                continue
            }
            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                Send-GeneralPagesResponse $stream 405 'Method Not Allowed' 'text/plain; charset=utf-8' ($utf8.GetBytes('GET only.')) @{ Allow = 'GET, HEAD' }
                continue
            }
            if ($static.ContainsKey($path)) {
                $s = $static[$path]
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { [System.IO.File]::ReadAllBytes($s.File) }
                Send-GeneralPagesResponse $stream 200 'OK' $s.Type $body
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html' -or $path -eq '/hub') {
                $hub = (Read-RepoHubState -Root $root).Hub
                if ($hub) {
                    Send-GeneralPagesResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = $hub }
                } else {
                    Send-GeneralPagesResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('This repo''s hub is not known yet: the dev-preview hook records it at the next session start.'))
                }
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
                Send-GeneralPagesResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" }
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
                $html = Format-SessionStartPageHtml -Model $ssCache.Model -ReadError $ssCache.Error -RepoName (Get-RepoIdentity).Name
            } elseif ($path -eq '/release-notes') {
                if (-not (Test-Path -LiteralPath $releaseNotesFile -PathType Leaf)) {
                    Send-GeneralPagesResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not built yet: this repo has no dkj-policy/releases/page/release-notes.html. The dkj-policy plugin builds it with scripts/release/build-release-notes-page.ps1.'))
                    continue
                }
                $html = Format-ReleaseNotesDevPage -Html ([System.IO.File]::ReadAllText($releaseNotesFile, $utf8))
            }
            if ($null -ne $html) {
                $body = if ($method -eq 'HEAD') { [byte[]]@() } else { $utf8.GetBytes($html) }
                Send-GeneralPagesResponse $stream 200 'OK' 'text/html; charset=utf-8' $body
                continue
            }
            Send-GeneralPagesResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found.'))
        } catch {
            # A dropped or silent connection ends that request, never the server.
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
