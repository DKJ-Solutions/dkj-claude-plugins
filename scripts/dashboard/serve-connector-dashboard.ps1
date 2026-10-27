<#
.SYNOPSIS
    Serve this repo's PRODUCT on http://localhost:<Port>/ (#3540): the home page on '/', and this repo's own
    pages, which it links: /connectors, every repo registered under connectors/ with its plugins, its local
    checkout and what check-connectors.ps1 reports for it on this machine (#2976), one card per owner group
    with each group a page of its own at /connectors/dkj, /bwj and /other -- the DKJ one also holding every
    DKJ-Solutions repo on GitHub with its checkout here and a session to open there (#3231; its own page at
    /dkj-repos until #3549, which now redirects there); and /specialists, every specialist the dkj-subagents
    plugins ship and the context each one costs, read from this tree. The rules of
    each page are in scripts/lib/dev-pages-lib.ps1. The server takes no POST but the banner's.

    EVERY REPO HAS A PRODUCT PORT (Maikel, October 26, 2026, #3540). This server was this repo's own hub
    under OwnHub (#3245), with the brandbook/ app's Vite dev server as the product beside it (#3283).
    Retiring the app (#3493) took the product port with it, which was never the intent. So the hub is the
    dkj-policy plugin's now, as in every other repo, and this server is the product: the general pages --
    Repository, Artifacts, Issues, Release notes, SessionStart, Test gate, Stopwatch, Logbook, Plugins and
    the house style's specimens under it -- are the plugin hub's, on its own port, and no longer relayed or
    built here. The home page links the hub, read from the state file the dev-preview hook writes
    (Get-GeneralPagesUrl), and '/hub' sends there too.

.DESCRIPTION
    Normally started by the dkj-policy dev-preview SessionStart hook, through this repo's
    Get-DevPreview in scripts/repo-config.ps1, as the repo's product beside the plugin's hub (#3540); it can
    be started by hand the same way:

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
    The home page's footer names that loaded commit, not the live one. Static files skip the check.
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
# The state file the hook writes, and the probe of the plugin's hub server (#3119), whose url the home page links
# (#3540): the plugin's, read from this repo's own tree because this repo is the plugin's source.
. (Join-Path $root 'plugins\dkj-policy\hub\lib\general-pages-state.ps1')
# The request reader, the response writer and the two refusals: the same ones the plugin's servers use, so a
# fix to any of them lands in all three (#3163).
. (Join-Path $root 'plugins\dkj-policy\hub\lib\loopback-server-lib.ps1')
# The banner's airsquats state, the same file and gist as every other hub's (#3438).
. (Join-Path $root 'plugins\dkj-policy\hub\lib\airsquats-lib.ps1')

$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))
# The canonical copy lives in the plugin (#3130); the hub no longer vendors its own.
$styleDir = Join-Path $root 'plugins\dkj-policy\assets\house-style'
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
                # At most one re-run per -MinRefreshSeconds, however often /refresh is asked for. ?page= names
                # where to go back to, from a fixed list, so the redirect never leaves this server.
                $page = if ([string]$target -cmatch '[?&]page=(connectors(?:/(?:dkj|bwj|other))?)(&|$)') { $Matches[1] } else { '' }
                if ($cache -and ((Get-Date) - $cache.At).TotalSeconds -ge $MinRefreshSeconds) { $cache = $null }
                if ($dkjCache -and ((Get-Date) - $dkjCache.At).TotalSeconds -ge $MinRefreshSeconds) { $dkjCache = $null }
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = "/$page" } -Method $method
                continue
            }
            if ($path -eq '/' -or $path -eq '/index.html') {
                # The product's home page (#3540), with the plugin's hub as its first card where it answers.
                $html = Format-ProductHomeHtml -Pages (Get-ProductPages) -HubUrl (Get-GeneralPagesUrl -Root $root -TimeoutMs 500) -SourceCommit $(if ($loadedSha) { $loadedSha.Substring(0, 8) } else { '' })
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -cmatch '^/connectors(?:/(dkj|bwj|other))?\z') {
                # The overview with one card per owner group, or one group's own page (owner, October 26, 2026).
                $group = [string]$Matches[1]
                if ($null -eq $cache -or ((Get-Date) - $cache.At).TotalSeconds -ge $CacheSeconds) { $cache = Get-DashboardModel }
                # The DKJ group's page also holds every DKJ-Solutions repo on GitHub (#3549), read only for that page.
                $section = @{ Html = ''; Style = ''; FooterNote = '' }
                if ($group -eq 'dkj') {
                    if ($null -eq $dkjCache -or ((Get-Date) - $dkjCache.At).TotalSeconds -ge $CacheSeconds) { $dkjCache = Get-DkjReposModel }
                    $section = Format-DkjReposSectionHtml -Query $dkjCache.Query -Checkouts $dkjCache.Checkouts -Meta $dkjCache.Meta
                    # A failed read of GitHub is shown once and not kept, so the next request asks again (Victor, #3231).
                    if ($dkjCache.Query.Error) { $dkjCache = $null }
                }
                $html = Format-ConnectorDashboardHtml -Connectors $cache.Connectors -Meta $cache.Meta -Group $group `
                    -SectionHtml $section.Html -SectionStyle $section.Style -SectionFooterNote $section.FooterNote
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -eq '/dkj-repos') {
                # Its own page until #3549, now a section of the DKJ group's: an old link or bookmark lands there.
                Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = '/connectors/dkj' } -Method $method
                continue
            }
            if ($path -eq '/specialists') {
                $sp = Get-SpecialistsModel
                $html = Format-SpecialistsPageHtml -Rows $sp.Rows -ReadError $sp.Error -CharsPerToken $sp.CharsPerToken
                Send-LoopbackResponse $stream 200 'OK' 'text/html; charset=utf-8' ($utf8.GetBytes($html)) -Method $method
                continue
            }
            if ($path -eq '/hub') {
                # The way to the plugin's hub (#3540): a 303 to the url the state file names, once it answers as
                # this checkout's; else a short text, never a redirect to a port another checkout may hold.
                $hubUrl = Get-GeneralPagesUrl -Root $root -TimeoutMs 500
                if ($hubUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z') {
                    Send-LoopbackResponse $stream 303 'See Other' 'text/plain; charset=utf-8' ([byte[]]@()) @{ Location = $hubUrl } -Method $method
                } else {
                    Send-LoopbackResponse $stream 404 'Not Found' 'text/plain; charset=utf-8' ($utf8.GetBytes('The dkj-policy hub is not running for this repo: the dev-preview hook starts it at the next session start.')) -Method $method
                }
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
