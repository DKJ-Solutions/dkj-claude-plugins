<#
.SYNOPSIS
    SessionStart hook: start (or reuse) this repo's local dev server and hand the session its localhost
    link -- the server scripts/repo-config.ps1 states in Get-DevPreview, or the plugin's placeholder page
    where the repo states none.

.DESCRIPTION
    INBOUND #2967. Replaces the three per-repo copies (dkj-brandbook, dkj-etf-tracker, life-hub); the seam
    and the ownership rule are in hub/lib/dev-preview-rules.ps1, which says what a repo states and why
    a listener counts as ours.

    WHAT IT DOES, in order: reads Get-DevPreview (in a child scope with StrictMode off, the way the
    bwj-development hooks read their seams). Where the repo has no such function -- or no config file at
    all -- it takes Get-DevPreviewPlaceholder's answer instead (#3047: every repo opens a preview, and
    hub/preview/serve-placeholder.ps1 is the floor); a function that answers nothing ends
    it here, printing nothing. Otherwise it
    takes one snapshot of the listening sockets and the process table, REUSES the first port whose
    listener is this checkout's server -- so a /clear or a second session never starts a second one --
    or STARTS the repo's Command on the first free port, hidden and detached so it outlives the hook,
    under a cmd.exe that changes into the repo root first (that command line is what makes the server
    recognisable as ours next time). Then it waits until the server actually listens before it hands out
    the link: a dead link is worse than none.

    THE GENERAL PAGES (#3119). Once it knows the repo hub's url -- reused or about to be started -- it starts
    or reuses the plugin's general pages server (hub/pages/serve-general-pages.ps1: Artifacts, Issues,
    Release notes, SessionStart, and the Brandbook in a DKJ-Solutions repo) on the first free port of 4890-4899, under the same ownership rule and its
    own log (%TEMP%\dev-preview-general-<repo>-<hash>.log), and does NOT wait for it to listen: the repo's
    own link is the one this hook promises, and the hub shows the general card's "not running" form until
    the server answers. It then writes the state file (%TEMP%\dkj-repo-hub-<repo>-<hash>.json: the hub url
    and the pages url), the one contract by which the two servers find each other. Placeholder repos get it
    too. This step never fails the session and never changes the line printed below. Where the hook ends
    before any hub exists (its ports all taken, a Requires path missing, a root cmd.exe would rewrite, a
    seam that answers nothing) it REMOVES last session's state file instead: with no hub to link there is
    nothing for the general server to send a visitor back to, and a stale file would name a hub that is
    not this session's. The listener snapshot is ONE read over the hub's ports and the general pages' ports
    together, and the process table is read at most once, shared by both steps.

    IN DKJ-POLICY SINCE #3198 (the owner's decision of October 20, 2026): the Repo hub and its General pages
    are what every repo has, so the hook ships with the plugin every repo runs, BWJ-Development's included.
    It was dkj-solutions', which BWJ never enables.

    THE OUTPUT is SessionStart JSON with BOTH systemMessage (shown to the owner, so the link is clickable
    in the terminal) and additionalContext (the session knows the URL too). life-hub sent only the first.

    BIND TO 127.0.0.1 IN THE COMMAND. The hook cannot know what a server exposes, so where the repo serves
    something private (etf-tracker its ledger, life-hub its Brains/), its own Command says so -- e.g.
    `--bind 127.0.0.1` or `-H 127.0.0.1`. A server it REUSES did not necessarily come from that Command
    (one started by hand in the checkout counts as ours too), so where the Command names loopback and the
    reused listener is bound to every interface, the line says so (#3041).

    OpenInVsCode hands the URL to VS Code through `code --open-url`, only when the session runs in VS
    Code's terminal (TERM_PROGRAM=vscode) -- etf-tracker's route, where .vscode/settings.json routes the
    URL to the Simple Browser through workbench.externalUriOpeners. Off by default: without that setting
    VS Code passes the URL to the system browser. The placeholder sets it itself, from that very setting:
    on where the repo routes the port it got, and otherwise off, with the line naming the route to add.

    NEVER FAILS THE SESSION: every path exits 0, with at most one line. Windows only, like the three
    copies it replaces (the socket and process reads are Windows cmdlets); elsewhere it prints nothing.
    Stdin is not read: a SessionStart payload carries nothing this hook needs.

    The matcher in hooks.json is startup|resume|clear and not compact: a compaction is mid-work, and
    etf-tracker excluded it so VS Code would not reopen the page under the owner's hands.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of CLAUDE_PROJECT_DIR or the working directory.

.PARAMETER PlaceholderPortsOverride
    (For tests) The placeholder's ports instead of 4880-4889, so a test run never meets a real one.

.NOTES
    The general pages server's ports are 4890-4899. A test replaces them through the environment variable
    DKJ_GENERAL_PAGES_PORTS (see Get-GeneralPagesPortRange), which the servers and hubs the hook starts
    inherit, so the same range holds on the writing and the reading side of the state file.
#>
[CmdletBinding()]
param([string]$RepoRootOverride, [int[]]$PlaceholderPortsOverride)

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
# install that lacks it still gets the repo's own server: the general pages step checks before it calls.
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
        Write-DevPreviewLine 'dev-preview: scripts/repo-config.ps1 could not be read, so Get-DevPreview was not asked -- no server started.'
    }
}
if ($raw -is [array]) { $raw = @($raw | Where-Object { $_ -is [System.Collections.IDictionary] })[-1] }

# No seam at all -- no config file, or one without Get-DevPreview -- is the placeholder (#3047): every
# repo opens a preview, and this is the floor. A seam that answers nothing stays silent.
$placeholder = -not $hasSeam
if ($placeholder) {
    $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($pluginRoot -match '[%^]') {
        Write-DevPreviewLine "dev-preview: placeholder not started -- the plugin path holds a '%' or '^', which cmd.exe would rewrite."
    }
    $raw = if ($PlaceholderPortsOverride) { Get-DevPreviewPlaceholder -PluginRoot $pluginRoot -Ports $PlaceholderPortsOverride }
           else { Get-DevPreviewPlaceholder -PluginRoot $pluginRoot }
}

# Last session's state file is only true while a hub is up: a hook that ends before there is one removes it.
function Clear-DevPreviewState {
    try {
        if (Get-Command Get-RepoHubStatePath -ErrorAction SilentlyContinue) {
            Remove-Item -LiteralPath (Get-RepoHubStatePath -Root $root) -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

$parsed = ConvertTo-DevPreviewConfig -Raw $raw
if (-not $parsed.Ok) {
    Clear-DevPreviewState
    if ($parsed.Problem) { Write-DevPreviewLine "dev-preview: not started -- $($parsed.Problem) (scripts/repo-config.ps1)." }
    exit 0
}
$cfg = $parsed.Config

# The placeholder's own words after the link: why it is a placeholder, and -- where the repo has no
# Simple Browser route for the port it got -- the one line that adds it. With the route it opens in VS
# Code; without it, it does not, because VS Code would hand the URL to the system browser.
function Get-DevPreviewPlaceholderNote([int]$Port) {
    if (-not $placeholder) { return '' }
    $settings = Join-Path $root '.vscode\settings.json'
    $text = if (Test-Path -LiteralPath $settings -PathType Leaf) { [System.IO.File]::ReadAllText($settings) } else { '' }
    $cfg.OpenInVsCode = Test-DevPreviewVsCodeRoute -SettingsText $text -Port $Port
    $note = ' -- this repo states no Get-DevPreview yet'
    if (-not $cfg.OpenInVsCode) { $note += "; route localhost:$Port to simpleBrowser.open in .vscode/settings.json to open it in VS Code" }
    return $note
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

function Open-DevPreviewInVsCode([string]$Url) {
    if (-not $cfg.OpenInVsCode -or $env:TERM_PROGRAM -ne 'vscode') { return '' }
    $code = Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $code) { return '' }
    Start-Process -FilePath $code.Source -ArgumentList @('--open-url', $Url) -WindowStyle Hidden | Out-Null
    return ', opened in VS Code'
}

# The general pages server (#3119), started or reused beside the repo's own, and the state file that tells
# each of the two where the other is. NEVER WAITS for the server to listen, and never throws: whatever goes
# wrong here leaves the hub's General card in its "not running" form and the session's line untouched.
function Start-DevPreviewGeneralPages([string]$HubUrl, $Listeners, $Processes) {
    try {
        if (-not (Get-Command Write-RepoHubState -ErrorAction SilentlyContinue)) { return }
        $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
        $server = Join-Path $pluginRoot 'hub\pages\serve-general-pages.ps1'
        $ports = @(Get-GeneralPagesPortRange)
        $pagesUrl = ''
        # A '%' or '^' in either path is rewritten by cmd.exe even inside quotes: refused, as for the repo's server.
        if ((Test-Path -LiteralPath $server -PathType Leaf) -and $pluginRoot -notmatch '[%^]' -and $root -notmatch '[%^]') {
            $gpick = Select-DevPreviewPort -Ports $ports -Listeners $Listeners -Processes $Processes -Root $root
            if ($gpick.Action -eq 'start') {
                $gcommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$server`" -Port {port}"
                $glog = Get-DevPreviewLogPath -Root $root -Name 'dev-preview-general'
                $null = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden `
                    -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $gcommand -Port ([int]$gpick.Port) -LogPath $glog)
            }
            if ($gpick.Action -ne 'none') { $pagesUrl = "http://localhost:$($gpick.Port)" }
        }
        Write-RepoHubState -Root $root -Hub $HubUrl -Pages $pagesUrl
    } catch { }
}

$listeners = @(Get-DevPreviewListeners (@($cfg.Ports) + @(Get-GeneralPagesPortRange)))
$processes = if ($listeners.Count) { Get-DevPreviewProcesses } else { @{} }
$pick = Select-DevPreviewPort -Ports $cfg.Ports -Listeners $listeners -Processes $processes -Root $root
$range = Format-DevPreviewPorts -Ports $cfg.Ports

if ($pick.Action -eq 'reuse') {
    $url = Get-DevPreviewUrl -Port $pick.Port -Path $cfg.Path
    $note = Get-DevPreviewPlaceholderNote $pick.Port
    $opened = Open-DevPreviewInVsCode $url
    # A REUSED server may not be the one the Command starts (#3041): one started by hand binds wherever
    # its default says. Where the repo asked for loopback and got every interface, the line says so; the
    # restart stays the owner's call.
    $exposed = if ((Test-DevPreviewCommandIsLoopback $cfg.Command) -and (Test-DevPreviewListensOnAll -Port $pick.Port -Listeners $listeners)) {
        ', LISTENING ON ALL INTERFACES -- not started by the loopback Command; restart it to bind 127.0.0.1'
    } else { '' }
    Start-DevPreviewGeneralPages -HubUrl $url -Listeners $listeners -Processes $processes
    Write-DevPreviewLine "$($cfg.Name): $url (already running$opened$exposed$note)"
}
if ($pick.Action -eq 'none') {
    Clear-DevPreviewState
    Write-DevPreviewLine "$($cfg.Name): not started -- $range taken by other processes."
}

foreach ($rel in $cfg.Requires) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) {
        Clear-DevPreviewState
        Write-DevPreviewLine "$($cfg.Name): not started -- '$rel' is missing (set it up, then start a new session)."
    }
}

# --- Start it, and wait until it listens -------------------------------------------------------------
# A '%' or '^' in the root is expanded or eaten by cmd.exe even inside quotes, so the server would start
# in the wrong directory and never be recognised as ours: refused rather than started wrong.
if ($root -match '[%^]') {
    Clear-DevPreviewState
    Write-DevPreviewLine "$($cfg.Name): not started -- the repo path holds a '%' or '^', which cmd.exe would rewrite."
}
$log = Get-DevPreviewLogPath -Root $root
$port = [int]$pick.Port

$shell = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden -PassThru `
    -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $cfg.Command -Port $port -LogPath $log)

$url = Get-DevPreviewUrl -Port $port -Path $cfg.Path
$note = Get-DevPreviewPlaceholderNote $port
Start-DevPreviewGeneralPages -HubUrl $url -Listeners $listeners -Processes $processes
$deadline = (Get-Date).AddSeconds($cfg.WaitSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $listeners = @(Get-DevPreviewListeners @($port))
    if (-not $listeners.Count) {
        # The shell that runs the Command ends with it, so a server that died at start ends the wait too.
        if ($shell.HasExited) { Write-DevPreviewLine "$($cfg.Name): the server on port $port exited at start -- see $log" }
        continue
    }
    if ((Get-DevPreviewPortState -Port $port -Listeners $listeners -Processes (Get-DevPreviewProcesses) -Root $root) -eq 'ours') {
        $opened = Open-DevPreviewInVsCode $url
        Write-DevPreviewLine "$($cfg.Name): $url (started$opened$note)"
    }
}
Write-DevPreviewLine "$($cfg.Name): starting on $url but not listening after $($cfg.WaitSeconds)s -- see $log"
