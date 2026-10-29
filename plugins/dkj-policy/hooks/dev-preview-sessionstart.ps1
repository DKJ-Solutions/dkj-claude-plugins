<#
.SYNOPSIS
    SessionStart hook: start (or reuse) the plugin's hub and, where the repo states one, its own local
    dev server (the product), and hand the session both localhost links in one line.

.DESCRIPTION
    INBOUND #2967, reshaped by #3245 (the owner's decision of October 21, 2026). Replaces the three per-repo
    copies (dkj-brandbook, dkj-etf-tracker, life-hub); the seam and the ownership rule are in
    hub/lib/dev-preview-rules.ps1, which says what a repo states and why a listener counts as ours.

    THE PLUGIN SERVES THE REPOSITORY IN EVERY REPO, whether or not the repo states Get-DevPreview: the general
    pages server (hub/pages/serve-general-pages.ps1: the hub on '/', and Artifacts, Issues, Release notes,
    SessionStart) is the hub, on the first free port of 4890-4899,
    under the ownership rule, with its log in %TEMP%\dev-preview-general-<repo>-<hash>.log. A server the repo
    states in Get-DevPreview is its PRODUCT, one link on that hub. There is no opt-out (#3643, the owner's
    decision of October 29, 2026): every repo gets this hub, in the house style. The OwnHub key that let a
    repo serve its own hub from #3245 to #3643, and the Product it allowed beside it (#3283), are ignored
    where a repo still states them, and named as config drift in a DKJ-Solutions repo.

    WHAT IT DOES, in order: reads Get-DevPreview (in a child scope with StrictMode off, the way the
    bwj-development hooks read their seams). It then takes one snapshot of the listening sockets and the
    process table, and STARTS OR REUSES THE GENERAL PAGES SERVER FIRST, before anything that can end the
    hook early: a product whose ports are all taken, a Requires path that is missing, a '%' or '^' in the
    repo root, a config that does not parse or cannot be read. The hub does not depend on any of them (#3244's
    second half, settled by #3245). The one thing that can keep the hub from starting is the hub's own
    problem: its ports 4890-4899 all taken, a '%' or '^' in the plugin or repo path, a plugin install that
    lacks the state library. The line then names that instead of a link.
    Then, where the repo states a server, it REUSES the first port whose listener is
    this checkout's product, or STARTS the repo's Command on the first free port, hidden and detached so it
    outlives the hook, under a cmd.exe that changes into the repo root first (that command line is what
    makes a server recognisable as ours next time). It waits until each server it started actually listens
    before it hands out its link -- a dead link is worse than none -- and both waits run in ONE loop, so the
    common case costs the longer of the two, never their sum. The hub has its own short deadline (12 s); the
    product has the repo's WaitSeconds.

    THE STATE FILE (%TEMP%\dkj-repo-hub-<repo>-<hash>.json: root, hub, pages, product, mode) is written
    every session, from whatever the hook found, because it is the one contract by which the servers and
    hubs find each other. It is written before the wait and again after it where a wait failed, so it never
    names a server that did not come up. mode is what the repo states: 'none' (no Get-DevPreview, so the hub
    shows the setup cards) or 'product'.

    SILENCE: a Get-DevPreview that answers nothing used to print nothing. Since #3245 it is a repo that
    states no server, so it gets the hub's line like one with no seam at all. Nothing is silent but a
    non-Windows host and a missing rules library.

    IN DKJ-POLICY SINCE #3198 (the owner's decision of October 20, 2026): the hub and its General pages
    are what every repo has, so the hook ships with the plugin every repo runs, BWJ-Development's included.

    THE OUTPUT is SessionStart JSON with BOTH systemMessage (shown to the owner, so the links are clickable
    in the terminal) and additionalContext (the session knows the URLs too), ONE line, in one of these forms:
      no product      Toolbox: <hub> (started|already running) -- this repo states no Get-DevPreview yet[; route ...]
      with a product  Toolbox: <hub> -- product: <url> (started|already running[, LISTENING ON ALL INTERFACES ...])
      product failed  Toolbox: <hub> -- product not started: <why>

    WHAT KEEPS A DKJ-SOLUTIONS REPO FROM FOLLOWING A HUB CHANGE (#3463) is appended to the product form, from
    Get-DevPreviewDriftClauses: '-- config drift: ...' for OpenInVsCode with no hub port routed, or a Name, an
    OwnHub or a Product still stated.

    BIND TO 127.0.0.1 IN THE COMMAND. The hook cannot know what a server exposes, so where the repo serves
    something private (etf-tracker its ledger, life-hub its Brains/), its own Command says so -- e.g.
    `--bind 127.0.0.1` or `-H 127.0.0.1`. A server it REUSES did not necessarily come from that Command
    (one started by hand in the checkout counts as ours too), so where the Command names loopback and the
    reused listener is bound to every interface, the line says so (#3041).

    OpenInVsCode hands the HUB's URL to VS Code through `code --open-url`, only when the session runs in VS Code's terminal (TERM_PROGRAM=vscode) --
    etf-tracker's route, where .vscode/settings.json routes the URL to the Simple Browser through
    workbench.externalUriOpeners. Off by default: without that setting VS Code passes the URL to the system
    browser. A repo that states no Get-DevPreview has no way to set it, so it is on where the repo routes the
    hub's port, and otherwise off, with the line naming the route to add.

    NEVER FAILS THE SESSION: every path exits 0, with at most one line. Windows only, like the three
    copies it replaces (the socket and process reads are Windows cmdlets); elsewhere it prints nothing.
    Stdin is read only for the session id, and only where the repo states a product (#3657, below).

    THE PRODUCT WAITS FOR THE TRUNK SYNC, AND OUTLIVES NO HEAD MOVE (#3657). sessioncheck-dispatch.ps1
    fast-forwards the trunk in a SEPARATE SessionStart entry that runs beside this one, and a server loads its
    code once at start: measured October 29, 2026, the product started at 19:30:23, the trunk moved at
    19:30:24, and the product served the old code. So the hub starts first, then the product waits (up to
    20 s) for the dispatcher's prep-done mark in the session cache. And a product this hook started that is
    older than HEAD's last move -- a sync, a checkout, a /clear after either -- is stopped and started again
    on its port, which the line names; a server somebody started by hand is reused as before.

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
# The session cache, for the prep steps' done mark (#3657). A plugin install that lacks it starts the product
# without waiting, as before.
$cacheLibPath = Join-Path $PSScriptRoot '..\scripts\lib\session-cache-lib.ps1'
if (Test-Path -LiteralPath $cacheLibPath -PathType Leaf) { try { . $cacheLibPath } catch { } }

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
# nothing, or a config that could not be read) or 'product' (a server of its own).
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
    foreach ($p in @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, CommandLine, SessionId, CreationDate -ErrorAction SilentlyContinue)) {
        $created = $null
        if ($p.CreationDate) { $created = ([datetime]$p.CreationDate).ToUniversalTime() }
        $processes[[int]$p.ProcessId] = @{ CommandLine = [string]$p.CommandLine; ParentId = [int]$p.ParentProcessId; SessionId = $p.SessionId; Created = $created }
    }
    return $processes
}

# WHEN HEAD LAST CHANGED THE TREE, in UTC, or $null (issue #3657): a product server loads its code once at
# start, so one created before this moment serves the tree from before a trunk sync or a checkout.
function Get-DevPreviewHeadMovedUtc {
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& git -C $root reflog -50 '--format=%gd%x09%gs' '--date=unix' 2>$null)
        return (ConvertFrom-DevPreviewReflogTime ([string[]]$lines))
    } catch { return $null }
}

# THE PREP STEPS FIRST (issue #3657): sessioncheck-dispatch.ps1 fast-forwards the trunk in a SEPARATE
# SessionStart entry that runs beside this one, and marks its prep done in the session cache. The product
# is started or reused only after that mark, or after -Seconds without it. Returns 'done', 'timeout' or
# 'skipped' (no session id, no cache library, or a wait of 0).
function Wait-DevPreviewSessionPrep([string]$SessionId, [int]$Seconds) {
    if ($Seconds -le 0 -or -not $SessionId -or -not (Get-Command Test-SessionPrepDone -ErrorAction SilentlyContinue)) { return 'skipped' }
    $until = (Get-Date).AddSeconds($Seconds)
    while ($true) {
        if (Test-SessionPrepDone -SessionId $SessionId) { return 'done' }
        if ((Get-Date) -ge $until) { return 'timeout' }
        Start-Sleep -Milliseconds 250
    }
}

# A STARTED SERVER DOES NOT OUTLIVE ITS SESSION (INBOUND #3569): a disconnected session keeps its processes, so a
# server started there held its port for every later session -- measured cross-account, where the later session
# cannot stop it. A watcher in this same session stops the server's tree once the session stays disconnected.
# Never in session 0, which always reads as disconnected. Whatever goes wrong here costs the watcher, never the start.
function Start-DevPreviewWatch($Proc) {
    try {
        if (-not $Proc -or $Proc.HasExited -or -not (Test-DevPreviewSessionWatchable -SessionId $Proc.SessionId)) { return }
        $watcher = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\hub\pages\dev-preview-watch.ps1'))
        if (-not (Test-Path -LiteralPath $watcher -PathType Leaf)) { return }
        # A TEST TIES THE SERVER TO ITSELF (#3620) through DKJ_DEV_PREVIEW_OWNER_PID; a real session leaves it unset.
        $owner = Get-DevPreviewOwner
        $ownerId = 0; $ownerTicks = 0
        if ($owner) { $ownerId = $owner.Id; $ownerTicks = $owner.StartTicks }
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden `
            -ArgumentList (Get-DevPreviewWatchArgs -Watcher $watcher -ProcessId $Proc.Id -StartTicks $Proc.StartTime.ToFileTimeUtc() -OwnerId $ownerId -OwnerStartTicks $ownerTicks) | Out-Null
    } catch { }
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
        if (-not (Get-Command Write-RepoHubState -ErrorAction SilentlyContinue) -or -not (Test-Path -LiteralPath $server -PathType Leaf)) {
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
            Start-DevPreviewWatch $r.Proc
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

# The server the repo states, reused or started (the ownership and start rules are unchanged since #2967),
# with a log of its own. Returns
# @{ Action = 'reuse'|'start'|'failed'; Port; Url; Detail; NotStarted; Exposed; Proc; Log; Restarted }: Detail is
# the reason where it failed, NotStarted says whether it reads "not started: <Detail>" or stands on its own, and
# Restarted that the start replaced this hook's own server from before HEAD last moved (-HeadMovedUtc).
function Start-DevPreviewProduct($Listeners, $Processes, $Cfg, [string]$LogName = 'dev-preview', $HeadMovedUtc = $null) {
    $r = @{ Action = 'failed'; Port = 0; Url = ''; Detail = ''; NotStarted = $true; Exposed = ''; Proc = $null; Log = ''; Stale = ''; Restarted = $false }
    # AN INSTALL OLDER THAN ITS LOCK IS NAMED, NOT REFUSED (#3404): the server may still run, and when it does
    # not, this is the line's only clue.
    $staleRel = Get-DevPreviewStaleInstall -Root $root -Requires $Cfg.Requires
    if ($staleRel) { $r.Stale = "; '$staleRel' is older than its package-lock.json -- run npm install" }
    $pick = Select-DevPreviewPort -Ports $Cfg.Ports -Listeners $Listeners -Processes $Processes -Root $root
    # OURS, BUT OLDER THAN THE TREE IT SERVES (#3657): a server that loaded its code before HEAD last moved --
    # a trunk sync, a checkout -- keeps serving the old code, so this hook's own tree is stopped and started
    # again on the same port. One that will not let go of its port is reused, as before.
    if ($pick.Action -eq 'reuse') {
        $outdated = @(Get-DevPreviewOutdatedProductRoots -Port $pick.Port -Listeners $Listeners -Processes $Processes -Root $root `
            -LogPath (Get-DevPreviewLogPath -Root $root -Name $LogName) -HeadMovedUtc $HeadMovedUtc)
        if ($outdated.Count) {
            foreach ($id in $outdated) {
                Start-Process -FilePath 'taskkill.exe' -ArgumentList "/PID $id /T /F" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
            }
            $until = (Get-Date).AddSeconds(5)
            while ((Get-Date) -lt $until -and @(Get-DevPreviewListeners @([int]$pick.Port)).Count) { Start-Sleep -Milliseconds 200 }
            if (-not @(Get-DevPreviewListeners @([int]$pick.Port)).Count) {
                $pick = @{ Action = 'start'; Port = $pick.Port }
                $r.Restarted = $true
            }
        }
    }
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
    Start-DevPreviewWatch $r.Proc
    $r.Action = 'start'
    $r.Url = Get-DevPreviewUrl -Port $r.Port -Path $Cfg.Path
    return $r
}

$ports = @(Get-GeneralPagesPortRange)
if ($cfg) { $ports += @($cfg.Ports) }
$listeners = @(Get-DevPreviewListeners $ports)
$processes = if ($listeners.Count) { Get-DevPreviewProcesses } else { @{} }

# --- The hub first, then the product -----------------------------------------------------------------
$hub = Start-DevPreviewHub -Listeners $listeners -Processes $processes
# A throw while starting the product is the product's failure, never the hub's: the hub link and the state
# file must survive it.
$prod = $null
if ($cfg) {
    # The hub is already starting; the product waits for the trunk sync (#3657), at most 20 s and never more
    # than the hook's 60 s leave after the product's own wait, its settle and about 10 s for the rest (the
    # stdin read, a restart's port release). DKJ_DEV_PREVIEW_PREP_WAIT (0-99) is the TEST override, and 0
    # also skips the stdin read that finds the session id.
    $prepWait = [Math]::Max(0, [Math]::Min(20, 50 - [int]$cfg.WaitSeconds - [int]$script:DevPreviewSettleSeconds))
    if ([string]$env:DKJ_DEV_PREVIEW_PREP_WAIT -match '^[0-9]{1,2}$') { $prepWait = [int]$env:DKJ_DEV_PREVIEW_PREP_WAIT }
    $sessionId = ''
    if ($prepWait -gt 0 -and (Get-Command Get-HookSessionId -ErrorAction SilentlyContinue)) { try { $sessionId = Get-HookSessionId } catch { $sessionId = '' } }
    if ((Wait-DevPreviewSessionPrep -SessionId $sessionId -Seconds $prepWait) -ne 'skipped') {
        # A FRESH SNAPSHOT AFTER THE WAIT (review of #3657): the restart force-stops a process tree, so it acts
        # on who listens NOW, not on who listened before the wait -- a pid can be reused, and a second
        # session's hook may have restarted the product meanwhile.
        $listeners = @(Get-DevPreviewListeners $ports)
        $processes = if ($listeners.Count) { Get-DevPreviewProcesses } else { @{} }
    }
    try { $prod = Start-DevPreviewProduct -Listeners $listeners -Processes $processes -Cfg $cfg -HeadMovedUtc (Get-DevPreviewHeadMovedUtc) }
    catch {
        $prod = @{ Action = 'failed'; Port = 0; Url = ''; Detail = ('could not be started: ' + ((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '')); NotStarted = $true; Exposed = ''; Proc = $null; Log = '' }
    }
}

# --- Wait until what was started listens: one loop, one clock each -----------------------------------
$targets = @()
# The hub's own deadline, 12 s; DKJ_DEV_PREVIEW_HUB_WAIT (0-99) is the TEST override.
$hubWait = 12
if ([string]$env:DKJ_DEV_PREVIEW_HUB_WAIT -match '^[0-9]{1,2}$') { $hubWait = [int]$env:DKJ_DEV_PREVIEW_HUB_WAIT }
# The settle after a started product's first answer (#3404); DKJ_DEV_PREVIEW_SETTLE (0-99) is the TEST override.
if ([string]$env:DKJ_DEV_PREVIEW_SETTLE -match '^[0-9]{1,2}$') { $script:DevPreviewSettleSeconds = [int]$env:DKJ_DEV_PREVIEW_SETTLE }
if ($hub.Action -eq 'start') { $targets += @{ Name = 'hub'; Port = $hub.Port; Proc = $hub.Proc; Deadline = (Get-Date).AddSeconds($hubWait); Done = $false; Ok = $false; Fail = '' } }
if ($prod -and $prod.Action -eq 'start') { $targets += @{ Name = 'product'; Port = $prod.Port; Proc = $prod.Proc; Deadline = (Get-Date).AddSeconds($cfg.WaitSeconds); Done = $false; Ok = $false; Fail = '' } }
# The state file goes in before the wait, so a hub that answers early already knows what the repo states, and
# again after it where a wait failed, so it never names a server that did not come up.
function Save-DevPreviewState {
    try {
        if (-not (Get-Command Write-RepoHubState -ErrorAction SilentlyContinue)) { return }
        $pagesUrl = if ($hub.Base -and -not (@($targets | Where-Object { $_.Name -eq 'hub' -and $_.Fail -eq 'exited' }).Count)) { $hub.Base } else { '' }
        $productUrl = if ($prod -and $prod.Url -and -not (@($targets | Where-Object { $_.Name -eq 'product' -and $_.Done -and -not $_.Ok }).Count)) { $prod.Url } else { '' }
        $hubUrl = if ($pagesUrl) { "$pagesUrl/" } else { '' }
        $theme = if ($cfg) { [string]$cfg.DefaultTheme } else { '' }
        Write-RepoHubState -Root $root -Hub $hubUrl -Pages $pagesUrl -Product $productUrl -Mode $mode -Theme $theme
    } catch { }
}
Save-DevPreviewState

$pending = @($targets)
while ($pending.Count) {
    foreach ($t in $pending) {
        if ((Get-Date) -ge $t.Deadline -and -not $t.SettleUntil) { $t.Done = $true; $t.Fail = 'timeout' }
    }
    $pending = @($pending | Where-Object { -not $_.Done })
    if (-not $pending.Count) { break }
    Start-Sleep -Milliseconds 500
    $now = @(Get-DevPreviewListeners @($pending | ForEach-Object { $_.Port }))
    $table = $null
    foreach ($t in $pending) {
        $mine = @($now | Where-Object { [int]$_.LocalPort -eq [int]$t.Port })
        $state = 'free'
        if ($mine.Count) {
            if ($null -eq $table) { $table = Get-DevPreviewProcesses }
            $state = Get-DevPreviewPortState -Port $t.Port -Listeners $mine -Processes $table -Root $root
        }
        # A started product that answered is held for a short settle before it reads as started (#3404): a
        # server that binds and then exits at once leaves its port free, and would otherwise be 'started'.
        if ($t.SettleUntil) {
            $gone = $mine.Count -and -not @($mine | Where-Object { $table.ContainsKey([int]$_.OwningProcess) }).Count
            switch (Get-DevPreviewSettleOutcome -State $state -Due ((Get-Date) -ge $t.SettleUntil) -HolderGone $gone) {
                'ok'      { $t.Done = $true; $t.Ok = $true }
                'stopped' { $t.Done = $true; $t.Fail = 'stopped' }
                'lost'    { $t.Done = $true; $t.Fail = 'lost'; $t.Holder = Format-DevPreviewPortHolders -Ports @([int]$t.Port) -Listeners $mine -Processes $table }
            }
            continue
        }
        # The shell that runs the Command ends with it, so a server that died at start ends the wait too --
        # also where another process holds the port: that is a lost bind, not a slow start (#3378).
        switch (Get-DevPreviewWaitOutcome -State $state -Exited ([bool]$t.Proc.HasExited)) {
            'ok'     {
                if ($t.Name -eq 'hub') { $t.Done = $true; $t.Ok = $true }
                else { $t.SettleUntil = (Get-Date).AddSeconds($script:DevPreviewSettleSeconds) }
            }
            'exited' { $t.Done = $true; $t.Fail = 'exited' }
            'lost'   { $t.Done = $true; $t.Fail = 'lost'; $t.Holder = Format-DevPreviewPortHolders -Ports @([int]$t.Port) -Listeners $mine -Processes $table }
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
    elseif ($hubT.Fail -eq 'lost') { $hubReason = "the hub lost port $($hub.Port) to a process this hook cannot identify ($($hubT.Holder)) -- it may be a hub started beside this one; see $(Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general')" }
    else { $hubReason = "the hub on port $($hub.Port) is not listening after ${hubWait}s -- see $(Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general')" }
}

# A server's part: what it is and how it stands, or why it is not. Returns @{ Url; Word; Fail }.
function Get-DevPreviewServerPart($P, $T, $Cfg) {
    $r = @{ Url = ''; Word = ''; Fail = '' }
    if (-not $P) { return $r }
    if ($P.Action -eq 'reuse') { $r.Url = $P.Url; $r.Word = 'already running' }
    elseif ($P.Action -eq 'start') {
        if ($T.Ok) { $r.Url = $P.Url; $r.Word = $(if ($P.Restarted) { 'restarted: the checkout moved after it started' } else { 'started' }) }
        elseif ($T.Fail -eq 'exited') { $r.Fail = "the server on port $($P.Port) exited at start -- see $($P.Log)" }
        elseif ($T.Fail -eq 'stopped') { $r.Fail = "the server on port $($P.Port) stopped right after it started listening -- see $($P.Log)" }
        elseif ($T.Fail -eq 'lost') { $r.Fail = "the server lost port $($P.Port) to a process this hook cannot identify ($($T.Holder)) -- it may be one started beside it; see $($P.Log)" }
        else { $r.Fail = "starting on $($P.Url) but not listening after $($Cfg.WaitSeconds)s -- see $($P.Log)" }
    }
    elseif ($P.NotStarted) { $r.Fail = "not started: $($P.Detail)" }
    else { $r.Fail = $P.Detail }
    return $r
}

# The product's clause on the line, from its part: 'product: <url> (<word>)', or why there is none.
function Format-DevPreviewProductClause($Part, $P) {
    if ($Part.Url) { return "product: $($Part.Url) ($($Part.Word)$(if ($P.Action -eq 'reuse') { $P.Exposed })$($P.Stale))" }
    if ($Part.Fail -like 'not started: *') { return "product $($Part.Fail)$($P.Stale)" }
    return "product: $($Part.Fail)$($P.Stale)"
}

$part = Get-DevPreviewServerPart $prod $prodT $cfg

$settings = Join-Path $root '.vscode\settings.json'
# An unreadable settings file must not cost the hub link: it reads as no route.
$text = ''
try { if (Test-Path -LiteralPath $settings -PathType Leaf) { $text = [System.IO.File]::ReadAllText($settings) } } catch { $text = '' }

# What keeps this repo from following a hub change, in a DKJ-Solutions repo (#3463). A failure here costs the
# drift clauses, never the line.
$drift = ''
try {
    $dkjSolutions = [bool]((Get-Command Test-DkjSolutionsEnabled -ErrorAction SilentlyContinue) -and (Test-DkjSolutionsEnabled -Root $root))
    $drift = -join @(Get-DevPreviewDriftClauses -DkjSolutions $dkjSolutions -Mode $mode -Config $cfg -SettingsText $text | ForEach-Object { " -- $_" })
} catch { $drift = '' }

$head = if ($hubUrl) { "$script:DevPreviewLabel`: $hubUrl" } else { "$script:DevPreviewLabel`: not started -- $hubReason" }

if ($mode -eq 'product') {
    $clause = if ($productProblem) { "product not started: $productProblem" }
              else { Format-DevPreviewProductClause $part $prod }
    $opened = ''
    if ($hubUrl) {
        $script:openInVsCode = [bool]($cfg -and $cfg.OpenInVsCode)
        $opened = Open-DevPreviewInVsCode $hubUrl
    }
    Write-DevPreviewLine ($head + $(if ($opened) { " (opened in VS Code)" } else { '' }) + " -- $clause$drift")
}

# No server stated: the hub alone, and -- where the repo has no Simple Browser route for its port -- the one
# line that adds it. With the route the hub opens in VS Code; without it, it does not, because VS Code would
# hand the URL to the system browser.
if (-not $hubUrl) { Write-DevPreviewLine $head }
$script:openInVsCode = Test-DevPreviewVsCodeRoute -SettingsText $text -Port $hub.Port
$note = ''
if (-not $script:openInVsCode) { $note = "; route localhost:$($hub.Port) to simpleBrowser.open in .vscode/settings.json to open it in VS Code" }
$opened = Open-DevPreviewInVsCode $hubUrl
Write-DevPreviewLine "$head ($hubWord$opened) -- $noteNone$note"
