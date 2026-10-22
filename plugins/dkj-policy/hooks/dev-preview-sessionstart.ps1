<#
.SYNOPSIS
    SessionStart hook: start (or reuse) the plugin's Repository and, where the repo states one, its own local
    dev server (the product), and hand the session both localhost links in one line.

.DESCRIPTION
    INBOUND #2967, reshaped by #3245 (the owner's decision of October 21, 2026). Replaces the three per-repo
    copies (dkj-brandbook, dkj-etf-tracker, life-hub); the seam and the ownership rule are in
    hub/lib/dev-preview-rules.ps1, which says what a repo states and why a listener counts as ours.

    THE PLUGIN SERVES THE REPOSITORY IN EVERY REPO, whether or not the repo states Get-DevPreview: the general
    pages server (hub/pages/serve-general-pages.ps1: the hub on '/', and Artifacts, Issues, Release notes,
    SessionStart, and the Brandbook in a DKJ-Solutions repo) is the hub, on the first free port of 4890-4899,
    under the ownership rule, with its log in %TEMP%\dev-preview-general-<repo>-<hash>.log. A server the repo
    states in Get-DevPreview is its PRODUCT, one link on that Repository. A repo that wants its own Repository states
    OwnHub = $true: its server is then the hub, as before, and the general server still starts beside it and
    sends '/hub' there.

    WHAT IT DOES, in order: reads Get-DevPreview (in a child scope with StrictMode off, the way the
    bwj-development hooks read their seams). It then takes one snapshot of the listening sockets and the
    process table, and STARTS OR REUSES THE GENERAL PAGES SERVER FIRST, before anything that can end the
    hook early: a product whose ports are all taken, a Requires path that is missing, a '%' or '^' in the
    repo root, a config that does not parse or cannot be read. The hub does not depend on any of them (#3244's
    second half, settled by #3245). The one thing that can keep the hub from starting is the hub's own
    problem: its ports 4890-4899 all taken, a '%' or '^' in the plugin or repo path, a plugin install that
    lacks the state library. The line then names that instead of a link.
    Then, where the repo states a server and has not opted out, it REUSES the first port whose listener is
    this checkout's product, or STARTS the repo's Command on the first free port, hidden and detached so it
    outlives the hook, under a cmd.exe that changes into the repo root first (that command line is what
    makes a server recognisable as ours next time). It waits until each server it started actually listens
    before it hands out its link -- a dead link is worse than none -- and both waits run in ONE loop, so the
    common case costs the longer of the two, never their sum. The hub has its own short deadline (12 s); the
    product has the repo's WaitSeconds.

    THE STATE FILE (%TEMP%\dkj-repository-<repo>-<hash>.json: root, hub, pages, product, mode) is written
    every session, from whatever the hook found, because it is the one contract by which the servers and
    hubs find each other. It is written before the wait and again after it where a wait failed, so it never
    names a server that did not come up. mode is what the repo states: 'none' (no Get-DevPreview, so the hub
    shows the setup cards), 'product' or 'ownhub'.

    SILENCE: a Get-DevPreview that answers nothing used to print nothing. Since #3245 it is a repo that
    states no server, so it gets the hub's line like one with no seam at all. Nothing is silent but a
    non-Windows host and a missing rules library.

    IN DKJ-POLICY SINCE #3198 (the owner's decision of October 20, 2026): the Repository and its General pages
    are what every repo has, so the hook ships with the plugin every repo runs, BWJ-Development's included.

    THE OUTPUT is SessionStart JSON with BOTH systemMessage (shown to the owner, so the links are clickable
    in the terminal) and additionalContext (the session knows the URLs too), ONE line, in one of these forms:
      no product      Hub: <hub> (started|already running) -- this repo states no Get-DevPreview yet[; route ...]
      with a product  Hub: <hub> -- product: <url> (started|already running[, LISTENING ON ALL INTERFACES ...])
      product failed  Hub: <hub> -- product not started: <why>
      OwnHub          Hub: <repo's own url> (started|already running[...])   -- as before #3245
      OwnHub+Product  Hub: <repo's own url> (...) -- product: <url> (started|already running) | product not started: <why>

    A PRODUCT BESIDE THE OWN HUB (#3283): a repo that states OwnHub = $true may also state Product = @{...},
    a second server with the same fields. It is started (or reused) and waited for exactly like the first,
    with its own log (dev-preview-product-<repo>-<hash>.log), and the state file's product names it.

    BIND TO 127.0.0.1 IN THE COMMAND. The hook cannot know what a server exposes, so where the repo serves
    something private (etf-tracker its ledger, life-hub its Brains/), its own Command says so -- e.g.
    `--bind 127.0.0.1` or `-H 127.0.0.1`. A server it REUSES did not necessarily come from that Command
    (one started by hand in the checkout counts as ours too), so where the Command names loopback and the
    reused listener is bound to every interface, the line says so (#3041).

    OpenInVsCode hands the HUB's URL to VS Code through `code --open-url` (the repo's own server's where it
    opted out with OwnHub), only when the session runs in VS Code's terminal (TERM_PROGRAM=vscode) --
    etf-tracker's route, where .vscode/settings.json routes the URL to the Simple Browser through
    workbench.externalUriOpeners. Off by default: without that setting VS Code passes the URL to the system
    browser. A repo that states no Get-DevPreview has no way to set it, so it is on where the repo routes the
    hub's port, and otherwise off, with the line naming the route to add.

    NEVER FAILS THE SESSION: every path exits 0, with at most one line. Windows only, like the three
    copies it replaces (the socket and process reads are Windows cmdlets); elsewhere it prints nothing.
    Stdin is not read: a SessionStart payload carries nothing this hook needs.

    The matcher in hooks.json is startup|resume|clear and not compact: a compaction is mid-work, and
    etf-tracker excluded it so VS Code would not reopen the page under the owner's hands.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of CLAUDE_PROJECT_DIR or the working directory.

.NOTES
    The general pages server's ports are 4890-4899. A test replaces them through the environment variable
    DKJ_GENERAL_PAGES_PORTS (see Get-GeneralPagesPortRange), which the servers the hook starts inherit, so
    the same range holds on the writing and the reading side of the state file.
#>
[CmdletBinding()]
param([string]$RepoRootOverride)

$ErrorActionPreference = 'Stop'

function Write-DevPreviewLine([string]$Text) {
    if (Get-Command ConvertTo-DevPreviewLine -ErrorAction SilentlyContinue) { $Text = ConvertTo-DevPreviewLine $Text }
    else { $Text = ($Text -replace '[\p{C}]', ' ') }
    $o = @{
        systemMessage      = $Text
        hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $Text }
    }
    Write-Output ($o | ConvertTo-Json -Compress)
    exit 0
}

trap {
    $reason = (((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-DevPreviewLine "dev-preview: skipped -- $reason"
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) { exit 0 }

$libPath = Join-Path $PSScriptRoot '..\hub\lib\dev-preview-rules.ps1'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
    [Console]::Error.WriteLine('dev-preview: dev-preview-rules.ps1 not found beside this hook -- reinstall or update the dkj-policy plugin.')
    exit 0
}
. $libPath
# The I/O half of the state-file contract (it dot-sources the rules lib again, which is harmless). A plugin
# install that lacks it still gets the repo's own server: the hub step checks before it calls.
$stateLibPath = Join-Path $PSScriptRoot '..\hub\lib\general-pages-state.ps1'
if (Test-Path -LiteralPath $stateLibPath -PathType Leaf) { . $stateLibPath }

$root = if ($RepoRootOverride) { $RepoRootOverride }
        elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
        else { (Get-Location).Path }
$root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')

# --- The repo's answer -------------------------------------------------------------------------------
$configPath = Join-Path $root 'scripts\repo-config.ps1'
$raw = $null
$hasSeam = $false
$unreadable = $false
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $read = & {
            Set-StrictMode -Off
            # 6>$null: a Write-Host in the repo's config would otherwise land on stdout under -File and break
            # the JSON this hook prints.
            $null = . $args[0] 6>$null
            if (@($ExecutionContext.InvokeCommand.GetCommands('Get-DevPreview', 'Function', $false)).Count) {
                @{ Seam = $true; Value = (Get-DevPreview 6>$null) }
            } else { @{ Seam = $false } }
        } $configPath
        $hasSeam = [bool]$read.Seam
        $raw = $read.Value
    } catch {
        $unreadable = $true
    }
}
if ($raw -is [array]) { $raw = @($raw | Where-Object { $_ -is [System.Collections.IDictionary] })[-1] }

# What the repo states, and so what the hub shows (#3245): 'none' (no Get-DevPreview, or one that answers
# nothing, or a config that could not be read), 'product' (a server of its own), 'ownhub' (that server is the hub).
# A seam that states something the hook cannot run is 'product' with no server, and its Problem is the line's reason.
$cfg = $null
$mode = 'none'
$productProblem = ''
$noteNone = 'this repo states no Get-DevPreview yet'
if ($unreadable) {
    $noteNone = 'scripts/repo-config.ps1 could not be read, so Get-DevPreview was not asked'
} elseif ($hasSeam -and $null -ne $raw) {
    $parsed = ConvertTo-DevPreviewConfig -Raw $raw
    $mode = 'product'
    if ($parsed.Ok) {
        $cfg = $parsed.Config
        if ($cfg.OwnHub) { $mode = 'ownhub' }
    } else {
        $productProblem = "$($parsed.Problem) (scripts/repo-config.ps1)"
    }
} elseif ($hasSeam) {
    $noteNone = 'this repo''s Get-DevPreview answers nothing'
}

# --- Who listens, and who started them ---------------------------------------------------------------
# THE CALLERS WRAP IN @(): a function returning a one-element array unrolls it, and .Count on a lone
# PSCustomObject is $null in Windows PowerShell 5.1 -- so one listener read as none (measured, #2967).
# Each read costs about 0.4s (measured in #2967's review), so the process table is read only when one of
# the ports has a listener at all: with none, every port is free and there is nobody to recognise.
function Get-DevPreviewListeners([int[]]$Ports) {
    return @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $Ports -contains [int]$_.LocalPort } | Select-Object LocalPort, LocalAddress, OwningProcess)
}
function Get-DevPreviewProcesses {
    $processes = @{}
    foreach ($p in @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, CommandLine -ErrorAction SilentlyContinue)) {
        $processes[[int]$p.ProcessId] = @{ CommandLine = [string]$p.CommandLine; ParentId = [int]$p.ParentProcessId }
    }
    return $processes
}

$script:openInVsCode = $false
function Open-DevPreviewInVsCode([string]$Url) {
    if (-not $script:openInVsCode -or $env:TERM_PROGRAM -ne 'vscode') { return '' }
    $code = Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $code) { return '' }
    Start-Process -FilePath $code.Source -ArgumentList @('--open-url', $Url) -WindowStyle Hidden | Out-Null
    return ', opened in VS Code'
}

# The hub: the plugin's general pages server (#3119, #3245), started or reused FIRST. Returns @{ Action =
# 'reuse'|'start'|'refused'|'none'; Port; Base; Proc; Reason; Restarted }: Base is its url without a slash, Reason
# says why there is no hub, Restarted that the start replaced this checkout's hub from another plugin version. Never waits and never throws: the caller waits, and whatever goes wrong here is a line.
function Start-DevPreviewHub($Listeners, $Processes) {
    $r = @{ Action = 'refused'; Port = 0; Base = ''; Proc = $null; Reason = ''; Restarted = $false }
    try {
        $ports = @(Get-GeneralPagesPortRange)
        $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        $server = Join-Path $pluginRoot 'hub\pages\serve-general-pages.ps1'
        if (-not (Get-Command Write-RepositoryState -ErrorAction SilentlyContinue) -or -not (Test-Path -LiteralPath $server -PathType Leaf)) {
            $r.Reason = 'the plugin lacks the hub server or its libraries -- reinstall or update the dkj-policy plugin'
            return $r
        }
        # A '%' or '^' in either path is rewritten by cmd.exe even inside quotes: refused, as for the repo's server.
        if ($pluginRoot -match '[%^]' -or $root -match '[%^]') {
            $r.Reason = 'the plugin path or the repo path holds a ''%'' or ''^'', which cmd.exe would rewrite'
            return $r
        }
        $pick = Select-DevPreviewPort -Ports $ports -Listeners $Listeners -Processes $Processes -Root $root
        if ($pick.Action -eq 'none') {
            $holders = Format-DevPreviewPortHolders -Ports $ports -Listeners $Listeners -Processes $Processes
            $r.Action = 'none'
            $r.Reason = (Format-DevPreviewPorts -Ports $ports) + ' taken by other processes' + $(if ($holders) { ": $holders" } else { '' })
            return $r
        }
        # OURS, BUT FROM ANOTHER PLUGIN VERSION (#3275): what the state file means changes between releases, so
        # that server is stopped and this version's started on the same port. One that will not stop is reused.
        if ($pick.Action -eq 'reuse') {
            $stale = @(Get-DevPreviewStaleHubOwners -Port $pick.Port -Listeners $Listeners -Processes $Processes -Server $server)
            if ($stale.Count) {
                foreach ($id in $stale) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
                $until = (Get-Date).AddSeconds(5)
                while ((Get-Date) -lt $until -and @(Get-DevPreviewListeners @([int]$pick.Port)).Count) { Start-Sleep -Milliseconds 200 }
                if (-not @(Get-DevPreviewListeners @([int]$pick.Port)).Count) {
                    $pick = @{ Action = 'start'; Port = $pick.Port }
                    $r.Restarted = $true
                }
            }
        }
        if ($pick.Action -eq 'start') {
            $command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$server`" -Port {port}"
            $log = Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general'
            $r.Proc = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden -PassThru `
                -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $command -Port ([int]$pick.Port) -LogPath $log)
        }
        $r.Action = $pick.Action
        $r.Port = [int]$pick.Port
        $r.Base = "http://localhost:$($pick.Port)"
    } catch {
        $r.Action = 'refused'
        $r.Reason = 'the hub could not be started: ' + ((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '')
    }
    return $r
}

# A server the repo states -- its own, or the Product beside its own hub (#3283) -- reused or started (the
# ownership and start rules are unchanged since #2967), each with a log of its own. Returns
# @{ Action = 'reuse'|'start'|'failed'; Port; Url; Detail; NotStarted; Exposed; Proc; Log }: Detail is the
# reason where it failed, and NotStarted says whether it reads "not started: <Detail>" or stands on its own.
function Start-DevPreviewProduct($Listeners, $Processes, $Cfg, [string]$LogName = 'dev-preview') {
    $r = @{ Action = 'failed'; Port = 0; Url = ''; Detail = ''; NotStarted = $true; Exposed = ''; Proc = $null; Log = '' }
    $pick = Select-DevPreviewPort -Ports $Cfg.Ports -Listeners $Listeners -Processes $Processes -Root $root
    if ($pick.Action -eq 'reuse') {
        $r.Action = 'reuse'
        $r.Port = [int]$pick.Port
        $r.Url = Get-DevPreviewUrl -Port $pick.Port -Path $Cfg.Path
        # A REUSED server may not be the one the Command starts (#3041): one started by hand binds wherever
        # its default says. Where the repo asked for loopback and got every interface, the line says so; the
        # restart stays the owner's call.
        if ((Test-DevPreviewCommandIsLoopback $Cfg.Command) -and (Test-DevPreviewListensOnAll -Port $pick.Port -Listeners $Listeners)) {
            $r.Exposed = ', LISTENING ON ALL INTERFACES -- not started by the loopback Command; restart it to bind 127.0.0.1'
        }
        return $r
    }
    if ($pick.Action -eq 'none') {
        # THE LINE NAMES THE HOLDER (#3244): with one pinned port, stopping it is the owner's only remedy, and
        # the process table is already read.
        $holders = Format-DevPreviewPortHolders -Ports $Cfg.Ports -Listeners $Listeners -Processes $Processes
        $r.Detail = (Format-DevPreviewPorts -Ports $Cfg.Ports) + ' taken by other processes' + $(if ($holders) { ": $holders" } else { '' })
        return $r
    }
    foreach ($rel in $Cfg.Requires) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) {
            $r.Detail = "'$rel' is missing (set it up, then start a new session)"
            return $r
        }
    }
    # A '%' or '^' in the root is expanded or eaten by cmd.exe even inside quotes, so the server would start
    # in the wrong directory and never be recognised as ours: refused rather than started wrong.
    if ($root -match '[%^]') {
        $r.Detail = 'the repo path holds a ''%'' or ''^'', which cmd.exe would rewrite'
        return $r
    }
    $r.Log = Get-DevPreviewLogPath -Root $root -Name $LogName
    $r.Port = [int]$pick.Port
    $r.Proc = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden -PassThru `
        -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $Cfg.Command -Port $r.Port -LogPath $r.Log)
    $r.Action = 'start'
    $r.Url = Get-DevPreviewUrl -Port $r.Port -Path $Cfg.Path
    return $r
}

$ports = @(Get-GeneralPagesPortRange)
if ($cfg) { $ports += @($cfg.Ports) }
# The product beside the repo's own hub (#3283): only under OwnHub, where ConvertTo-DevPreviewConfig allows one.
$extraCfg = if ($cfg -and $mode -eq 'ownhub') { $cfg.Product } else { $null }
if ($extraCfg) { $ports += @($extraCfg.Ports) }
$listeners = @(Get-DevPreviewListeners $ports)
$processes = if ($listeners.Count) { Get-DevPreviewProcesses } else { @{} }

# --- The hub first, then the product -----------------------------------------------------------------
$hub = Start-DevPreviewHub -Listeners $listeners -Processes $processes
# A throw while starting the product is the product's failure, never the hub's: the hub link and the state
# file must survive it.
$prod = $null
if ($cfg) {
    try { $prod = Start-DevPreviewProduct -Listeners $listeners -Processes $processes -Cfg $cfg }
    catch {
        $prod = @{ Action = 'failed'; Port = 0; Url = ''; Detail = ('could not be started: ' + ((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '')); NotStarted = $true; Exposed = ''; Proc = $null; Log = '' }
    }
}
# And the same for the product beside the own hub, whose failure costs neither the hub nor its line.
$extra = $null
if ($extraCfg) {
    try { $extra = Start-DevPreviewProduct -Listeners $listeners -Processes $processes -Cfg $extraCfg -LogName 'dev-preview-product' }
    catch {
        $extra = @{ Action = 'failed'; Port = 0; Url = ''; Detail = ('could not be started: ' + ((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '')); NotStarted = $true; Exposed = ''; Proc = $null; Log = '' }
    }
}

# --- Wait until what was started listens: one loop, one clock each -----------------------------------
$targets = @()
# The hub's own deadline, 12 s; DKJ_DEV_PREVIEW_HUB_WAIT (0-99) is the TEST override.
$hubWait = 12
if ([string]$env:DKJ_DEV_PREVIEW_HUB_WAIT -match '^[0-9]{1,2}$') { $hubWait = [int]$env:DKJ_DEV_PREVIEW_HUB_WAIT }
if ($hub.Action -eq 'start') { $targets += @{ Name = 'hub'; Port = $hub.Port; Proc = $hub.Proc; Deadline = (Get-Date).AddSeconds($hubWait); Done = $false; Ok = $false; Fail = '' } }
if ($prod -and $prod.Action -eq 'start') { $targets += @{ Name = 'product'; Port = $prod.Port; Proc = $prod.Proc; Deadline = (Get-Date).AddSeconds($cfg.WaitSeconds); Done = $false; Ok = $false; Fail = '' } }
if ($extra -and $extra.Action -eq 'start') { $targets += @{ Name = 'extra'; Port = $extra.Port; Proc = $extra.Proc; Deadline = (Get-Date).AddSeconds($extraCfg.WaitSeconds); Done = $false; Ok = $false; Fail = '' } }

# The state file goes in before the wait, so a hub that answers early already knows what the repo states, and
# again after it where a wait failed, so it never names a server that did not come up.
function Save-DevPreviewState {
    try {
        if (-not (Get-Command Write-RepositoryState -ErrorAction SilentlyContinue)) { return }
        $pagesUrl = if ($hub.Base -and -not (@($targets | Where-Object { $_.Name -eq 'hub' -and $_.Fail -eq 'exited' }).Count)) { $hub.Base } else { '' }
        $productUrl = if ($prod -and $prod.Url -and -not (@($targets | Where-Object { $_.Name -eq 'product' -and $_.Done -and -not $_.Ok }).Count)) { $prod.Url } else { '' }
        $hubUrl = if ($mode -eq 'ownhub') { $productUrl } elseif ($pagesUrl) { "$pagesUrl/" } else { '' }
        # Under OwnHub the own server is the hub, so 'product' names the product beside it, or nothing (#3283).
        if ($mode -eq 'ownhub') {
            $productUrl = if ($extra -and $extra.Url -and -not (@($targets | Where-Object { $_.Name -eq 'extra' -and $_.Done -and -not $_.Ok }).Count)) { $extra.Url } else { '' }
        }
        Write-RepositoryState -Root $root -Hub $hubUrl -Pages $pagesUrl -Product $productUrl -Mode $mode
    } catch { }
}
Save-DevPreviewState

$pending = @($targets)
while ($pending.Count) {
    foreach ($t in $pending) {
        if ((Get-Date) -ge $t.Deadline) { $t.Done = $true; $t.Fail = 'timeout' }
    }
    $pending = @($pending | Where-Object { -not $_.Done })
    if (-not $pending.Count) { break }
    Start-Sleep -Milliseconds 500
    $now = @(Get-DevPreviewListeners @($pending | ForEach-Object { $_.Port }))
    $table = $null
    foreach ($t in $pending) {
        $mine = @($now | Where-Object { [int]$_.LocalPort -eq [int]$t.Port })
        if ($mine.Count) {
            if ($null -eq $table) { $table = Get-DevPreviewProcesses }
            if ((Get-DevPreviewPortState -Port $t.Port -Listeners $mine -Processes $table -Root $root) -eq 'ours') { $t.Done = $true; $t.Ok = $true }
        } elseif ($t.Proc.HasExited) {
            # The shell that runs the Command ends with it, so a server that died at start ends the wait too.
            $t.Done = $true; $t.Fail = 'exited'
        }
    }
    $pending = @($pending | Where-Object { -not $_.Done })
}
if (@($targets | Where-Object { -not $_.Ok }).Count) { Save-DevPreviewState }

# --- The one line ------------------------------------------------------------------------------------
$hubT = @($targets | Where-Object { $_.Name -eq 'hub' }) | Select-Object -First 1
$prodT = @($targets | Where-Object { $_.Name -eq 'product' }) | Select-Object -First 1
$hubUrl = ''
$hubWord = ''
$hubReason = $hub.Reason
if ($hub.Action -eq 'reuse') { $hubUrl = "$($hub.Base)/"; $hubWord = 'already running' }
elseif ($hub.Action -eq 'start') {
    if ($hubT.Ok) { $hubUrl = "$($hub.Base)/"; $hubWord = $(if ($hub.Restarted) { 'restarted: it ran another plugin version' } else { 'started' }) }
    elseif ($hubT.Fail -eq 'exited') { $hubReason = "the hub on port $($hub.Port) exited at start -- see $(Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general')" }
    else { $hubReason = "the hub on port $($hub.Port) is not listening after ${hubWait}s -- see $(Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general')" }
}

# A server's part: what it is and how it stands, or why it is not. Returns @{ Url; Word; Fail }.
function Get-DevPreviewServerPart($P, $T, $Cfg) {
    $r = @{ Url = ''; Word = ''; Fail = '' }
    if (-not $P) { return $r }
    if ($P.Action -eq 'reuse') { $r.Url = $P.Url; $r.Word = 'already running' }
    elseif ($P.Action -eq 'start') {
        if ($T.Ok) { $r.Url = $P.Url; $r.Word = 'started' }
        elseif ($T.Fail -eq 'exited') { $r.Fail = "the server on port $($P.Port) exited at start -- see $($P.Log)" }
        else { $r.Fail = "starting on $($P.Url) but not listening after $($Cfg.WaitSeconds)s -- see $($P.Log)" }
    }
    elseif ($P.NotStarted) { $r.Fail = "not started: $($P.Detail)" }
    else { $r.Fail = $P.Detail }
    return $r
}

# The product's clause on the line, from its part: 'product: <url> (<word>)', or why there is none.
function Format-DevPreviewProductClause($Part, $P) {
    if ($Part.Url) { return "product: $($Part.Url) ($($Part.Word)$(if ($P.Action -eq 'reuse') { $P.Exposed }))" }
    if ($Part.Fail -like 'not started: *') { return "product $($Part.Fail)" }
    return "product: $($Part.Fail)"
}

$part = Get-DevPreviewServerPart $prod $prodT $cfg
$prodUrl = $part.Url
$prodWord = $part.Word
$prodFail = $part.Fail
$extraT = @($targets | Where-Object { $_.Name -eq 'extra' }) | Select-Object -First 1
$extraClause = if ($extra) { ' -- ' + (Format-DevPreviewProductClause (Get-DevPreviewServerPart $extra $extraT $extraCfg) $extra) }
               elseif ($cfg -and $mode -eq 'ownhub' -and $cfg.ProductProblem) { " -- product not started: $($cfg.ProductProblem) (scripts/repo-config.ps1)" }
               else { '' }

if ($mode -eq 'ownhub') {
    # The repo's own server IS the hub: the line it always had.
    if ($prodUrl) {
        $script:openInVsCode = $cfg.OpenInVsCode
        $opened = Open-DevPreviewInVsCode $prodUrl
        $exposed = if ($prod.Action -eq 'reuse') { $prod.Exposed } else { '' }
        Write-DevPreviewLine "$($cfg.Name): $prodUrl ($prodWord$opened$exposed)$extraClause"
    }
    Write-DevPreviewLine "$($cfg.Name): $(if ($prodFail -like 'not started: *') { 'not started -- ' + $prodFail.Substring(13) } else { $prodFail })$extraClause"
}

$head = if ($hubUrl) { "$script:DevPreviewLabel`: $hubUrl" } else { "$script:DevPreviewLabel`: not started -- $hubReason" }

if ($mode -eq 'product') {
    $clause = if ($productProblem) { "product not started: $productProblem" }
              else { Format-DevPreviewProductClause $part $prod }
    $opened = ''
    if ($hubUrl) {
        $script:openInVsCode = [bool]($cfg -and $cfg.OpenInVsCode)
        $opened = Open-DevPreviewInVsCode $hubUrl
    }
    Write-DevPreviewLine ($head + $(if ($opened) { " (opened in VS Code)" } else { '' }) + " -- $clause")
}

# No server stated: the hub alone, and -- where the repo has no Simple Browser route for its port -- the one
# line that adds it. With the route the hub opens in VS Code; without it, it does not, because VS Code would
# hand the URL to the system browser.
if (-not $hubUrl) { Write-DevPreviewLine $head }
$settings = Join-Path $root '.vscode\settings.json'
# An unreadable settings file must not cost the hub link: it reads as no route.
$text = ''
try { if (Test-Path -LiteralPath $settings -PathType Leaf) { $text = [System.IO.File]::ReadAllText($settings) } } catch { $text = '' }
$script:openInVsCode = Test-DevPreviewVsCodeRoute -SettingsText $text -Port $hub.Port
$note = ''
if (-not $script:openInVsCode) { $note = "; route localhost:$($hub.Port) to simpleBrowser.open in .vscode/settings.json to open it in VS Code" }
$opened = Open-DevPreviewInVsCode $hubUrl
Write-DevPreviewLine "$head ($hubWord$opened) -- $noteNone$note"
