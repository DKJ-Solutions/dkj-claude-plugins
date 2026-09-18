<#
.SYNOPSIS
    The statusLine command: draw a progress bar for every run currently publishing one -- issue #2101.

.DESCRIPTION
    Wired up in .claude/settings.json as the statusLine command. Claude Code runs it, hands it the
    session payload as JSON on stdin, and renders its stdout persistently under the prompt.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/show-progress.ps1

    WHY THE STATUSLINE AND NOT A PRINTED LINE. A run this session backgrounds prints to nobody: a
    Bash call made with run_in_background streams no stdout anywhere visible, in the terminal CLI and
    in the VS Code extension alike. The statusline is the one surface that keeps rendering while that
    is true, which is why the bar is drawn here and published there -- run-progress-lib.ps1's header
    has the whole argument.

    IT ALWAYS EXITS 0 AND NEVER THROWS. This runs every couple of seconds for as long as a session is
    open, so a failure here is not an error report, it is a broken status line -- repeated forever. A
    record it cannot read, a directory that is not there, a payload that is not JSON: each means "draw
    what is left", never a red line and never a stack trace where the branch name goes.

    THE CONTEXT LINE COSTS NO SUBPROCESS. The branch is read out of .git/HEAD as a file, not from a
    git invocation: at this cadence the process spawn IS the cost, and this script's job is to be the
    cheap half of a mechanism whose expensive half is already unavoidable. Nothing here shells out.

    Pure ASCII (repo convention for .ps1) -- and here it is also what the line is made of; see the lib.
#>
[CmdletBinding()]
param(
    # The record directory, for the suite. Nothing in settings.json passes it.
    [string]$Root = '',
    # The session payload, for the suite -- normally read from stdin the way Claude Code sends it.
    [string]$Payload = '',
    # How many live runs may draw a bar at once. Two is the real ceiling of this workflow: a ship
    # whose own gate is running inside it. A third would be noise, and a status line that grows
    # without bound is one nobody can read at a glance.
    [int]$MaxBars = 2
)

# NOT 'Stop'. The whole contract of this file is that it degrades instead of failing, and an
# ErrorActionPreference that turns a missing directory into a terminating error would defeat the
# try/catch blocks below rather than help them.
$ErrorActionPreference = 'SilentlyContinue'

$lines = @()

try {
    . (Join-Path $PSScriptRoot '..\lib\run-progress-lib.ps1')

    foreach ($record in @(Get-LiveRunProgress -Root $Root | Select-Object -First ([math]::Max(1, $MaxBars)))) {
        $line = Format-RunProgressLine -Record $record
        if ($line) { $lines += $line }
    }
} catch { }

# --- the context line ------------------------------------------------------------------------
# Second, not first: the bar is what this file exists for, and the thing a reader is looking for
# belongs where their eye lands first. With nothing running this is the whole status line.
try {
    # ONLY WHEN STDIN IS ACTUALLY REDIRECTED. Claude Code always pipes the session payload in, so the
    # read always has an end -- but a person debugging this file by running it in a console has no pipe,
    # and ReadToEnd on a live console waits for a Ctrl+Z that is never coming. A status line that hangs
    # the first time somebody looks at it by hand is a status line nobody will look at twice.
    if (-not $Payload -and [Console]::IsInputRedirected) {
        $stdin = [Console]::In.ReadToEnd()
        if ($stdin) { $Payload = $stdin }
    }

    $model = ''
    $dir = ''
    if ($Payload) {
        $session = $Payload | ConvertFrom-Json
        if ($session) {
            if ($session.model -and $session.model.display_name) { $model = "$($session.model.display_name)" }
            if ($session.workspace -and $session.workspace.current_dir) { $dir = "$($session.workspace.current_dir)" }
        }
    }
    if (-not $dir) { $dir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }

    $branch = ''
    try {
        # .git IS A FILE IN A WORKTREE, holding 'gitdir: <path>' -- which this workflow's lanes make
        # ordinary rather than exotic, so it is followed rather than treated as "no branch".
        $gitPath = Join-Path $dir '.git'
        if (Test-Path -LiteralPath $gitPath -PathType Leaf) {
            $pointer = (Get-Content -LiteralPath $gitPath -First 1)
            if ("$pointer" -match '^gitdir:\s*(.+)$') { $gitPath = $Matches[1].Trim() }
        }
        $headFile = Join-Path $gitPath 'HEAD'
        if (Test-Path -LiteralPath $headFile -PathType Leaf) {
            $head = "$(Get-Content -LiteralPath $headFile -First 1)".Trim()
            if ($head -match '^ref:\s*refs/heads/(.+)$') { $branch = $Matches[1] }
            elseif ($head) { $branch = 'detached' }
        }
    } catch { }

    $parts = @()
    $leaf = ''
    try { $leaf = Split-Path -Leaf $dir } catch { }
    if ($leaf) { $parts += $leaf }
    if ($branch) { $parts += $branch }
    if ($model) { $parts += $model }
    if ($parts.Count -gt 0) { $lines += ($parts -join '  ') }
} catch { }

foreach ($line in $lines) { Write-Output $line }
exit 0
