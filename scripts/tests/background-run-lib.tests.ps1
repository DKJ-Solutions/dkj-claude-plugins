<#
.SYNOPSIS
    Tests for scripts/lib/background-run-lib.ps1 -- the judgement behind the PostToolUse hook that
    publishes a backgrounded call's progress record (issue #2104).

.DESCRIPTION
    THE WHOLE POINT OF THE SPLIT IS DRIVEN HERE. Get-BackgroundRunPublishPlan is a pure function of the
    payload text, so every decision below is a string in and a verdict out -- no process, no stdin, no
    CIM query, no clock. That is why the lib exists separately from the hook, and this file is what
    would be impossible otherwise.

    THE PAYLOADS ARE REAL. The shapes asserted here were captured from Claude Code 2.1.276 by a probe
    hook on 18 September 2026, not invented: tool_response really does carry backgroundTaskId beside
    stdout/stderr/interrupted/isImage/noOutputExpected, and the payload really does carry cwd and
    duration_ms at the top level. A fixture that guesses the shape would assert nothing about the
    surface this hook actually reads.

    Get-BackgroundShellProcessId IS DELIBERATELY NOT DRIVEN over a fixture machine: it asks the live OS
    which shell is running a command, and a fake for that would be asserting that a mock returns what
    the mock was told to. Its contract -- 0 on anything it cannot answer -- is asserted on the two
    inputs that need no machine at all.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\background-run-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Assert-True (Test-Path -LiteralPath $LibPath) 'background-run-lib.ps1 exists at its registered source path'
. $LibPath

function New-Payload {
    <#
        A PostToolUse payload in the shape Claude Code actually sends -- see the header. Every field the
        lib reads is a parameter, so a case states exactly the one thing it varies.
    #>
    param(
        [object]$Background = $true,
        [string]$TaskId = 'b972u1th4',
        [string]$Command = 'echo hi; sleep 25',
        [string]$Description = 'A backgrounded probe run',
        [string]$Cwd = 'C:\repo',
        [switch]$NoTaskIdField,
        [switch]$NoToolResponse,
        [switch]$NoCwd,
        [switch]$NoDescription
    )
    $toolInput = [ordered]@{ command = $Command }
    if (-not $NoDescription) { $toolInput.description = $Description }
    if ($null -ne $Background) { $toolInput.run_in_background = $Background }

    $o = [ordered]@{
        session_id      = 'abc'
        hook_event_name = 'PostToolUse'
        tool_name       = 'Bash'
        tool_input      = $toolInput
        tool_use_id     = 'toolu_x'
        duration_ms     = 13
    }
    if (-not $NoCwd) { $o.cwd = $Cwd }
    if (-not $NoToolResponse) {
        $resp = [ordered]@{ stdout = ''; stderr = ''; interrupted = $false; isImage = $false; noOutputExpected = $false }
        if (-not $NoTaskIdField) { $resp.backgroundTaskId = $TaskId }
        $o.tool_response = $resp
    }
    return ($o | ConvertTo-Json -Depth 6 -Compress)
}

# --- 1. the ordinary case -------------------------------------------------------------------------
Write-Host ''
Write-Host 'A backgrounded call with everything present' -ForegroundColor Cyan

$p = Get-BackgroundRunPublishPlan -Payload (New-Payload)
Assert-True $p.ShouldPublish 'it publishes'
Assert-Equal 'bg-b972u1th4' $p.Name 'the id is keyed on backgroundTaskId, so two concurrent runs cannot share a record'
Assert-Equal 'A backgrounded probe run' $p.Label 'the label prefers the description -- a person wrote it about this call'
Assert-Equal 'C:\repo' $p.RepoRoot 'the repo root is read from the payload cwd'
Assert-Equal 'echo hi; sleep 25' $p.Command 'the command is carried, because the shell lookup matches on it'
# THE NOTE IS EMPTY ON PURPOSE, asserted so a later edit that "helpfully" fills it has to argue with
# this line. Format-RunProgressLine spends the note from the label's own ceiling: measured end-to-end,
# a note of 'backgrounded' rendered as "... Second end-to-end backgrounded run (bac...  +9s".
Assert-Equal '' $p.Note 'the note is empty -- it would be spent from the label budget and says nothing the label does not'

# --- 2. every reason to publish NOTHING -----------------------------------------------------------
# EACH IS A $false RATHER THAN A THROW. The hook's contract is that a bar it cannot draw costs the tool
# call nothing, so there is no failure path here that a caller has to catch.
Write-Host ''
Write-Host 'The cases that publish nothing' -ForegroundColor Cyan

Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -Background $false)).ShouldPublish) `
    'a FOREGROUND call publishes nothing -- the gate is read properly here, not just as the raw pre-gate string'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -Background $null)).ShouldPublish) `
    'run_in_background absent entirely is a foreground call, not a missing-field error'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -NoTaskIdField)).ShouldPublish) `
    'no backgroundTaskId: without it two runs cannot be told apart, so nothing is published'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -NoToolResponse)).ShouldPublish) `
    'no tool_response at all is the same answer, and does not throw on the missing property'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -TaskId '   ')).ShouldPublish) `
    'a whitespace-only task id is not an id'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload 'not json at all {').ShouldPublish) `
    'a payload that is not JSON publishes nothing rather than inventing a label'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload '').ShouldPublish) `
    'an empty payload publishes nothing'
Assert-True (-not (Get-BackgroundRunPublishPlan -Payload $null).ShouldPublish) `
    'a null payload publishes nothing -- the parameter is AllowNull, so this is a verdict and not an error'

# EVERY FIELD IS PRESENT ON A REFUSAL, so a caller never null-checks before reading.
$none = Get-BackgroundRunPublishPlan -Payload (New-Payload -Background $false)
foreach ($prop in @('ShouldPublish', 'RepoRoot', 'Name', 'Label', 'Note', 'Command')) {
    Assert-True ([bool]$none.PSObject.Properties[$prop]) "a refused plan still carries '$prop', so the caller reads one shape"
}

# --- 3. the repo root, and why it decides whether anything happens at all --------------------------
Write-Host ''
Write-Host 'The repo root: payload first, environment second' -ForegroundColor Cyan

$savedProjectDir = $env:CLAUDE_PROJECT_DIR
try {
    $env:CLAUDE_PROJECT_DIR = 'C:\from-env'
    $fromEnv = Get-BackgroundRunPublishPlan -Payload (New-Payload -NoCwd)
    Assert-True $fromEnv.ShouldPublish 'with no cwd in the payload it falls back to CLAUDE_PROJECT_DIR'
    Assert-Equal 'C:\from-env' $fromEnv.RepoRoot '...and reports that as the root'

    # THE PAYLOAD WINS. cwd is where the session is actually standing, which is the tree whose
    # scripts/lib the hook then looks in; the env var is a fallback for a shape that lacks it.
    Assert-Equal 'C:\repo' (Get-BackgroundRunPublishPlan -Payload (New-Payload)).RepoRoot `
        'where both exist the payload cwd wins over the environment'

    $env:CLAUDE_PROJECT_DIR = ''
    Assert-True (-not (Get-BackgroundRunPublishPlan -Payload (New-Payload -NoCwd)).ShouldPublish) `
        'with neither, nothing is published -- there is no tree to find the progress lib in'
} finally {
    $env:CLAUDE_PROJECT_DIR = $savedProjectDir
}

# --- 4. the label falls back, and never to nothing ------------------------------------------------
Write-Host ''
Write-Host 'The label' -ForegroundColor Cyan

Assert-Equal 'echo hi; sleep 25' (Get-BackgroundRunPublishPlan -Payload (New-Payload -NoDescription)).Label `
    'no description: the command is the fallback'
Assert-Equal 'echo hi; sleep 25' (Get-BackgroundRunPublishPlan -Payload (New-Payload -Description '   ')).Label `
    'a whitespace-only description is not a label either'
Assert-Equal 'background run' (Get-BackgroundRunPublishPlan -Payload (New-Payload -NoDescription -Command '')).Label `
    'and with neither, a bar still has a name rather than an empty one'

# --- 5. the quoting the shell applies, which a fixture pair cannot show by itself -----------------
# THE ONE DEFECT THE UNIT TESTS COULD NOT HAVE CAUGHT, so the measurement is pinned here instead. Both
# strings below are real: the first is tool_input.command as the payload carried it, the second is the
# command line of the bash.exe Claude Code actually launched for it. A plain Contains() between them is
# $false, which is why the first end-to-end run of this hook published nothing at all.
Write-Host ''
Write-Host 'The shell re-quotes the command, and the match survives it' -ForegroundColor Cyan

$payloadCommand = 'echo "E2E-2104 start"; sleep 40; echo "E2E-2104 end"'
$shellCommandLine = 'source /c/Users/x/.claude/shell-snapshots/snap.sh >/dev/null 2>&1 || true && eval ''echo \"E2E-2104 start\"; sleep 40; echo \"E2E-2104 end\"'' < /dev/null && pwd -P >| /tmp/x'

Assert-True (-not $shellCommandLine.Contains($payloadCommand)) `
    'the premise: a RAW Contains() does not match, because the shell escaped every quote'
Assert-True ((Get-CommandMatchKey -Text $shellCommandLine).Contains((Get-CommandMatchKey -Text $payloadCommand))) `
    '...and through the reduction it does -- the same reduction applied to both sides'
Assert-Equal 'echo E2E-2104 start; sleep 40; echo E2E-2104 end' (Get-CommandMatchKey -Text $payloadCommand) `
    'the reduction drops quotes and backslashes and nothing else'
Assert-Equal '' (Get-CommandMatchKey -Text '') 'an empty string reduces to an empty string rather than throwing'
Assert-Equal '' (Get-CommandMatchKey -Text $null) 'and so does a null one'
# A command that is ONLY quoting reduces to nothing, and must not then match every process on the box.
Assert-Equal 0 (Get-BackgroundShellProcessId -CommandText '"\"') `
    'a command that reduces to nothing is 0 -- an empty needle would otherwise match every command line'

# --- 6. Get-BackgroundShellProcessId: the contract that needs no machine ---------------------------
Write-Host ''
Write-Host 'The shell lookup, on the inputs that need no live process' -ForegroundColor Cyan

Assert-Equal 0 (Get-BackgroundShellProcessId -CommandText '') `
    'an empty command is 0 -- and 0 means the caller publishes nothing'
Assert-Equal 0 (Get-BackgroundShellProcessId -CommandText '   ') `
    'a whitespace-only command is 0'
Assert-Equal 0 (Get-BackgroundShellProcessId -CommandText $null) `
    'a null command is 0 rather than an error'
# A STRING NO COMMAND LINE ON THIS MACHINE CAN CONTAIN. This one does touch the OS, which is the point:
# it proves the query runs and that finding nothing is 0 rather than a throw.
Assert-Equal 0 (Get-BackgroundShellProcessId -CommandText 'zzz-no-process-has-this-in-its-command-line-2104-zzz') `
    'a command nothing is running is 0 -- the query ran and found nothing, which is not an error'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
