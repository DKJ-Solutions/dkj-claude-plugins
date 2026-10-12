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

    AND SINCE #2928 IT SAYS TWO MORE THINGS. An issue that neither links nor mentions Asana gets one
    question -- did it start from an Asana task? -- because the evidence can sit on the task, where this
    hook cannot look. And a linked issue whose task is also linked from another OPEN issue is named, with
    that issue's number: section 8 is one GitHub issue per Asana ticket.

    WHAT IT PRINTS is fixed text plus issue numbers and the task GID -- never an issue's title or body.

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
# TWO CALLS AT MOST, 18s + 8s: the issue itself, and -- only when it is linked -- the open issues that name
# the same task (#2928). The second is the cheaper question and the one that may be dropped: a timeout
# there skips the duplicate check and says so, and the issue's own verdict still stands.
$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
function Invoke-GhJson {
    param([string]$Arguments, [int]$TimeoutMs)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'gh'
        $psi.Arguments = $Arguments
        $psi.WorkingDirectory = $projectDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $null = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch { }
        } elseif ($p.ExitCode -eq 0) {
            # WRAPPED, because a bare return unrolls an empty JSON array into $null -- and "no other issue
            # names this task" must not read as "the search failed".
            return [pscustomobject]@{ Ok = $true; Data = ($outTask.Result | ConvertFrom-Json) }
        }
    } catch { }
    return [pscustomobject]@{ Ok = $false; Data = $null }
}

$issueRead = Invoke-GhJson -Arguments "issue view $number --json title,body" -TimeoutMs 18000
$issue = $issueRead.Data
if (-not $issueRead.Ok -or $null -eq $issue) {
    [Console]::Error.WriteLine("asana-link-pickupcheck: could not read issue #$number -- its Asana link was not checked.")
    exit 0
}

$verdict = Get-AsanaPickupVerdict -Title ([string]$issue.title) -IssueBody ([string]$issue.body)
$parts = @(Format-AsanaPickupWarning -Number $number -Verdict $verdict)

if ($verdict -eq 'linked') {
    $gid = (Resolve-AsanaTaskRef -IssueBody ([string]$issue.body)).Gid
    # The GID is digits only (Resolve-AsanaTaskRef matches nothing else), so it is safe on a command line.
    $peers = Invoke-GhJson -Arguments "issue list --state open --search `"$gid in:body`" --json number,body --limit 20" -TimeoutMs 8000
    if (-not $peers.Ok) {
        [Console]::Error.WriteLine("asana-link-pickupcheck: could not search the open issues -- whether task $gid is linked from another issue was not checked.")
    } else {
        $parts += Format-AsanaCoClaimWarning -Number $number -Gid $gid -Others (Get-AsanaTaskCoClaimants -Gid $gid -Number $number -Issues @($peers.Data))
    }
}

$text = (@($parts | Where-Object { $_ }) -join "`n`n")
if (-not $text) { exit 0 }

@{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $text } } | ConvertTo-Json -Compress
exit 0
