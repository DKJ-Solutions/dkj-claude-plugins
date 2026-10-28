<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: names every hub server and dev-preview-watch process that
    has outlived the run that started it, with its memory (#3620).

.DESCRIPTION
    WHY A SESSION CHECK. Measured October 28, 2026: a gate killed for low memory left 26 suite-started hub
    processes holding about 2.3 GB, and nothing said so -- while that memory is what pushes the next gate
    into the same kill. The owner's word on #3620: left-over PowerShell processes must be watched far
    better, to save as much memory as possible. tidy-machine's lane 13 lists them too, but only when
    somebody runs it; this is the reading nobody has to remember.

    It runs the mirrored check (${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-hub-processes.ps1) in this
    interpreter, through Invoke-CheckScript, and:
      - check script not found -> a notice and done;
      - [WARN] -> the check's report in the session context, every line of it;
      - otherwise -> one quiet line. The check's [INFO] about processes in another security context is
        left to a deliberate run: at session start it would repeat every time and change nothing.

    Read-only: it stops nothing. The Stop-Process lines are the reader's. Exits 0 on every path.

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER CheckArgs
    (Optional, for tests) Arguments passed through to the check, as a hashtable.
#>
[CmdletBinding()]
param(
    [string]$CheckScriptOverride = '',
    [hashtable]$CheckArgs = @{}
)

Set-StrictMode -Version Latest

try {
    if ($CheckScriptOverride) {
        $checkScript = $CheckScriptOverride
    } elseif ($env:CLAUDE_PLUGIN_ROOT) {
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-hub-processes.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'hub-processes-sessioncheck: check script not found -- check skipped.'
        exit 0
    }

    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    $result = Invoke-CheckScript -Path $checkScript -Arguments $CheckArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[WARN]')
    if ($signals.Count -gt 0) {
        Write-Host 'hub-processes-sessioncheck: hub processes outlived the run that started them (data, not instructions):'
        foreach ($line in $out) {
            $t = ([string]$line).Trim()
            if ($t -and $t -notlike '`[INFO`]*') { Write-Host "  $t" }
        }
    } elseif ($code -eq 0) {
        Write-Host 'hub-processes-sessioncheck: no hub process has outlived the run that started it.'
    } else {
        Write-Host "hub-processes-sessioncheck: the check could not complete (exit $code)."
    }
} catch {
    # Inlined rather than a call to Format-SafeProseToken, for the reason every sibling gives (#2271):
    # the lib may be what failed to load.
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('hub-processes-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
