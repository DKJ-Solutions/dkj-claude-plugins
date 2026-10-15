<#
.SYNOPSIS
    SessionStart hook: start (or reuse) this repo's local dev server and hand the session its localhost
    link -- for a repo whose scripts/repo-config.ps1 states Get-DevPreview, and silently nothing otherwise.

.DESCRIPTION
    INBOUND #2967. Replaces the three per-repo copies (dkj-brandbook, dkj-etf-tracker, life-hub); the seam
    and the ownership rule are in scripts/lib/dev-preview-rules.ps1, which says what a repo states and why
    a listener counts as ours.

    WHAT IT DOES, in order: reads Get-DevPreview (in a child scope with StrictMode off, the way the
    bwj-development hooks read their seams); with no answer it ends here, printing nothing. Otherwise it
    takes one snapshot of the listening sockets and the process table, REUSES the first port whose
    listener is this checkout's server -- so a /clear or a second session never starts a second one --
    or STARTS the repo's Command on the first free port, hidden and detached so it outlives the hook,
    under a cmd.exe that changes into the repo root first (that command line is what makes the server
    recognisable as ours next time). Then it waits until the server actually listens before it hands out
    the link: a dead link is worse than none.

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
    VS Code passes the URL to the system browser.

    NEVER FAILS THE SESSION: every path exits 0, with at most one line. Windows only, like the three
    copies it replaces (the socket and process reads are Windows cmdlets); elsewhere it prints nothing.
    Stdin is not read: a SessionStart payload carries nothing this hook needs.

    The matcher in hooks.json is startup|resume|clear and not compact: a compaction is mid-work, and
    etf-tracker excluded it so VS Code would not reopen the page under the owner's hands.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of CLAUDE_PROJECT_DIR or the working directory.
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

$libPath = Join-Path $PSScriptRoot '..\scripts\lib\dev-preview-rules.ps1'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
    [Console]::Error.WriteLine('dev-preview: dev-preview-rules.ps1 not found beside this hook -- reinstall or update the dkj-solutions plugin.')
    exit 0
}
. $libPath

$root = if ($RepoRootOverride) { $RepoRootOverride }
        elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
        else { (Get-Location).Path }
$root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')

# --- The repo's answer -------------------------------------------------------------------------------
$configPath = Join-Path $root 'scripts\repo-config.ps1'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { exit 0 }
$raw = $null
try {
    $raw = & {
        Set-StrictMode -Off
        # 6>$null: a Write-Host in the repo's config would otherwise land on stdout under -File and break
        # the JSON this hook prints.
        $null = . $args[0] 6>$null
        if (@($ExecutionContext.InvokeCommand.GetCommands('Get-DevPreview', 'Function', $false)).Count) { Get-DevPreview 6>$null }
    } $configPath
} catch {
    Write-DevPreviewLine 'dev-preview: scripts/repo-config.ps1 could not be read, so Get-DevPreview was not asked -- no server started.'
}
if ($raw -is [array]) { $raw = @($raw | Where-Object { $_ -is [System.Collections.IDictionary] })[-1] }

$parsed = ConvertTo-DevPreviewConfig -Raw $raw
if (-not $parsed.Ok) {
    if ($parsed.Problem) { Write-DevPreviewLine "dev-preview: not started -- $($parsed.Problem) (scripts/repo-config.ps1)." }
    exit 0
}
$cfg = $parsed.Config

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

$listeners = @(Get-DevPreviewListeners $cfg.Ports)
$processes = if ($listeners.Count) { Get-DevPreviewProcesses } else { @{} }
$pick = Select-DevPreviewPort -Ports $cfg.Ports -Listeners $listeners -Processes $processes -Root $root
$range = Format-DevPreviewPorts -Ports $cfg.Ports

if ($pick.Action -eq 'reuse') {
    $url = Get-DevPreviewUrl -Port $pick.Port -Path $cfg.Path
    $opened = Open-DevPreviewInVsCode $url
    # A REUSED server may not be the one the Command starts (#3041): one started by hand binds wherever
    # its default says. Where the repo asked for loopback and got every interface, the line says so; the
    # restart stays the owner's call.
    $exposed = if ((Test-DevPreviewCommandIsLoopback $cfg.Command) -and (Test-DevPreviewListensOnAll -Port $pick.Port -Listeners $listeners)) {
        ', LISTENING ON ALL INTERFACES -- not started by the loopback Command; restart it to bind 127.0.0.1'
    } else { '' }
    Write-DevPreviewLine "$($cfg.Name): $url (already running$opened$exposed)"
}
if ($pick.Action -eq 'none') {
    Write-DevPreviewLine "$($cfg.Name): not started -- $range taken by other processes."
}

foreach ($rel in $cfg.Requires) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $rel))) {
        Write-DevPreviewLine "$($cfg.Name): not started -- '$rel' is missing (set it up, then start a new session)."
    }
}

# --- Start it, and wait until it listens -------------------------------------------------------------
# A '%' or '^' in the root is expanded or eaten by cmd.exe even inside quotes, so the server would start
# in the wrong directory and never be recognised as ours: refused rather than started wrong.
if ($root -match '[%^]') {
    Write-DevPreviewLine "$($cfg.Name): not started -- the repo path holds a '%' or '^', which cmd.exe would rewrite."
}
$leaf = Split-Path -Leaf $root
$sha = [System.Security.Cryptography.SHA1]::Create()
$hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))[0..3] | ForEach-Object { $_.ToString('x2') })
$log = Join-Path ([System.IO.Path]::GetTempPath()) "dev-preview-$leaf-$hash.log"
$port = [int]$pick.Port

$shell = Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden -PassThru `
    -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $cfg.Command -Port $port -LogPath $log)

$url = Get-DevPreviewUrl -Port $port -Path $cfg.Path
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
        Write-DevPreviewLine "$($cfg.Name): $url (started$opened)"
    }
}
Write-DevPreviewLine "$($cfg.Name): starting on $url but not listening after $($cfg.WaitSeconds)s -- see $log"
