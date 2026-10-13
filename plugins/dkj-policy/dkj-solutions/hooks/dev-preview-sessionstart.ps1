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
    `--bind 127.0.0.1` or `-H 127.0.0.1`.

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
param([string]$RepoRootOverride)

$ErrorActionPreference = 'Stop'

function Write-DevPreviewLine([string]$Text) {
    $o = @{
        systemMessage      = $Text
        hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $Text }
    }
    Write-Output ($o | ConvertTo-Json -Compress)
    exit 0
}

trap {
    $reason = ([string]$_.Exception.Message) -replace '[\p{C}]', ' '
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
        $null = . $args[0]
        if (@($ExecutionContext.InvokeCommand.GetCommands('Get-DevPreview', 'Function', $false)).Count) { Get-DevPreview }
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

# --- One snapshot of who listens, and who started them -----------------------------------------------
function Get-DevPreviewSnapshot {
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalPort, OwningProcess)
    $processes = @{}
    foreach ($p in @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, CommandLine -ErrorAction SilentlyContinue)) {
        $processes[[int]$p.ProcessId] = @{ CommandLine = [string]$p.CommandLine; ParentId = [int]$p.ParentProcessId }
    }
    return @{ Listeners = $listeners; Processes = $processes }
}

function Open-DevPreviewInVsCode([string]$Url) {
    if (-not $cfg.OpenInVsCode -or $env:TERM_PROGRAM -ne 'vscode') { return '' }
    $code = Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $code) { return '' }
    Start-Process -FilePath $code.Source -ArgumentList @('--open-url', $Url) -WindowStyle Hidden | Out-Null
    return ', opened in VS Code'
}

$snap = Get-DevPreviewSnapshot
$pick = Select-DevPreviewPort -Ports $cfg.Ports -Listeners $snap.Listeners -Processes $snap.Processes -Root $root
$range = if ($cfg.Ports.Count -eq 1) { "port $($cfg.Ports[0])" } else { "ports $($cfg.Ports[0])-$($cfg.Ports[-1])" }

if ($pick.Action -eq 'reuse') {
    $url = Get-DevPreviewUrl -Port $pick.Port -Path $cfg.Path
    $opened = Open-DevPreviewInVsCode $url
    Write-DevPreviewLine "$($cfg.Name): $url (already running$opened)"
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
$leaf = Split-Path -Leaf $root
$sha = [System.Security.Cryptography.SHA1]::Create()
$hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($root.ToLowerInvariant()))[0..3] | ForEach-Object { $_.ToString('x2') })
$log = Join-Path ([System.IO.Path]::GetTempPath()) "dev-preview-$leaf-$hash.log"
$port = [int]$pick.Port

Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -WindowStyle Hidden `
    -ArgumentList (Get-DevPreviewStartLine -Root $root -Command $cfg.Command -Port $port -LogPath $log) | Out-Null

$url = Get-DevPreviewUrl -Port $port -Path $cfg.Path
$deadline = (Get-Date).AddSeconds($cfg.WaitSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $snap = Get-DevPreviewSnapshot
    if ((Get-DevPreviewPortState -Port $port -Listeners $snap.Listeners -Processes $snap.Processes -Root $root) -eq 'ours') {
        $opened = Open-DevPreviewInVsCode $url
        Write-DevPreviewLine "$($cfg.Name): $url (started$opened)"
    }
}
Write-DevPreviewLine "$($cfg.Name): starting on $url but not listening after $($cfg.WaitSeconds)s -- see $log"
