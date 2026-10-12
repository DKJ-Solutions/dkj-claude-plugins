<#
.SYNOPSIS
    PostToolUse hook on the shell tools: after claim-issue or new-branch picks up an issue, warns the
    session when that issue names Asana but links no Asana task.

.DESCRIPTION
    INBOUND #2919. An issue copied from a colleague's Asana task without its link runs the whole chain
    unnoticed, and the requester hears nothing when it ships. The judgement is in
    scripts/lib/asana-pickup-rules.ps1; this file reads the payload, asks the tracker, and answers. Why
    it warns rather than refuses is in that lib's header.

    IT ONLY EVER ADDS CONTEXT. PostToolUse runs after the command, so it cannot stop the claim or the
    branch -- and it should not: the repair (writing the link) is a step of the same pickup. Its output
    is the PostToolUse JSON with hookSpecificOutput.additionalContext, which the harness hands the
    session; on every other path it prints nothing.

    IT FAILS OPEN, SILENTLY ON THE COMMON PATH. Nearly every shell call is neither command, so
    hooks.json greps the payload first and starts PowerShell only when one of the two scripts is named
    -- the shell pre-gate guard-working-copy and guard-live-theme already carry, here for wall-clock
    rather than safety: a PowerShell start on every shell call is the cost this hook must not add. The
    same test is repeated below for a run that reaches this file another way. Where gh cannot answer, a one-line note on stderr
    says the link was not checked, and the call's own result stands.

    WHAT IT PRINTS is fixed text plus the issue number -- never the issue's title or body.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/asana-link-pickupcheck.tests.ps1 in
    the source repo -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE, the guard every hook in this tree carries (#2264).
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE: neither script named, nothing to judge, and no lib load or gh call is spent.
if ($raw -notmatch '(claim-issue|new-branch)\.ps1') { exit 0 }

$libPath = Join-Path $PSScriptRoot '..\scripts\lib\asana-pickup-rules.ps1'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
    [Console]::Error.WriteLine('asana-link-pickupcheck: asana-pickup-rules.ps1 not found beside this hook -- the Asana link was not checked. Reinstall or update the bwj-development plugin.')
    exit 0
}
. $libPath

trap {
    [Console]::Error.WriteLine('asana-link-pickupcheck: an unexpected error stopped the check -- the Asana link of this issue was NOT checked.')
    exit 0
}

$command = ''
try { $command = [string](($raw | ConvertFrom-Json).tool_input.command) } catch { exit 0 }
$number = Get-PickupIssueNumber -Command $command
if ($null -eq $number) { exit 0 }

# --- Ask the tracker, bounded under hooks.json's 30s ceiling ----------------------------------------
$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$issue = $null
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'gh'
    $psi.Arguments = "issue view $number --json title,body"
    $psi.WorkingDirectory = $projectDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $null = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(20000)) {
        try { $p.Kill() } catch { }
    } elseif ($p.ExitCode -eq 0) {
        $issue = $outTask.Result | ConvertFrom-Json
    }
} catch {
    $issue = $null
}
if ($null -eq $issue) {
    [Console]::Error.WriteLine("asana-link-pickupcheck: could not read issue #$number -- its Asana link was not checked.")
    exit 0
}

$text = Format-AsanaPickupWarning -Number $number -Verdict (Get-AsanaPickupVerdict -Title ([string]$issue.title) -IssueBody ([string]$issue.body))
if (-not $text) { exit 0 }

@{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $text } } | ConvertTo-Json -Compress
exit 0
