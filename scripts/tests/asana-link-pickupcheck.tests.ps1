<#
.SYNOPSIS
    Tests for plugins/dkj-policy/bwj-development/hooks/asana-link-pickupcheck.ps1 and its lib,
    scripts/lib/asana-pickup-rules.ps1 -- the PostToolUse hook that warns at pickup when an issue names
    Asana but links no task (inbound #2919).

.DESCRIPTION
    THREE GROUPS.
      1. THE LIB, in-process: which commands pick up which issue, the four verdicts, and the warning text
         -- which must never echo the issue's own words.
      2. THE HOOK, as a process, on every path that makes no network call: the pre-gate, a command that
         picks up nothing, and an unparseable payload. Each exits 0 and prints nothing.
      3. THE REGISTRATION: hooks.json runs the file after the shell tools, behind a shell pre-gate on the
         two script names, so PowerShell does not start on every shell call.

    THE TEST GAP, NAMED. The path that reads a real issue needs `gh` and a tracker, so it is not run here
    -- this suite runs in CI without tracker credentials. The decision that path takes is group 1's
    Get-AsanaPickupVerdict and Format-AsanaPickupWarning.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'
$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development'
$Hook       = Join-Path $PluginRoot 'hooks\asana-link-pickupcheck.ps1'
$HooksJson  = Join-Path $PluginRoot 'hooks\hooks.json'

. (Join-Path $PluginRoot 'scripts\lib\asana-pickup-rules.ps1')

$script:pass = 0
$script:fail = 0
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Invoke-Hook {
    <# Runs the hook with $Payload on stdin; returns @{ Code; Out; Err }. #>
    param([string]$Payload)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Hook`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($Payload)
    $p.StandardInput.Close()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return @{ Code = $p.ExitCode; Out = $out; Err = $errTask.Result }
}

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The lib -- which command picks up which issue' -ForegroundColor Cyan

$cache = 'C:/Users/x/.claude/plugins/cache/dkj-claude-plugins/dkj-policy/5.17.0/scripts/task'
Assert-Equal 404 (Get-PickupIssueNumber -Command "powershell -File `"$cache/claim-issue.ps1`" 404 -Tag") 'a sweep claim through the plugin cache, the path quoted'
Assert-Equal 404 (Get-PickupIssueNumber -Command 'pwsh scripts/task/claim-issue.ps1 #404') 'a plain claim with a hash'
Assert-Equal 404 (Get-PickupIssueNumber -Command 'claim-issue.ps1 404 -Tag -TakeOver') 'a take-over picks the work up too'
Assert-Equal 404 (Get-PickupIssueNumber -Command "new-branch.ps1 -Name fix/404-model-dropdown -Title `"x`"") 'new-branch reads the number out of the branch name'
Assert-Equal 404 (Get-PickupIssueNumber -Command "new-branch.ps1 -Name 'feat/404-x'") '...quoted too'
Assert-True ($null -eq (Get-PickupIssueNumber -Command 'claim-issue.ps1 -Candidates -SkipLabel a,b')) '-Candidates picks nothing up'
Assert-True ($null -eq (Get-PickupIssueNumber -Command 'claim-issue.ps1 404 -Tag -Release')) 'a release lets go of the work, so it is no pickup'
Assert-True ($null -eq (Get-PickupIssueNumber -Command 'claim-issue.ps1 -Tag -ReleaseAll -Apply')) '-ReleaseAll neither'
Assert-True ($null -eq (Get-PickupIssueNumber -Command 'new-branch.ps1 -Name docs/tidy-readme')) 'a branch with no number names no issue'
Assert-True ($null -eq (Get-PickupIssueNumber -Command 'git status')) 'any other command names none'
Assert-True ($null -eq (Get-PickupIssueNumber -Command $null)) 'and an absent command is no pickup'

Write-Host ''
Write-Host 'The lib -- what the issue says about its Asana task' -ForegroundColor Cyan

$task = 'https://app.asana.com/1/111/project/222/task/1219216227959314'
Assert-Equal 'unlinked' (Get-AsanaPickupVerdict -Title 'WH Model dropdown' -IssueBody 'Reported by Jordy via Asana (Dev - Bug)') 'the measured #404: Asana in prose, no link'
Assert-Equal 'unlinked' (Get-AsanaPickupVerdict -Title 'From ASANA: dropdown' -IssueBody '') 'a mention in the title counts, in any case'
Assert-Equal 'linked' (Get-AsanaPickupVerdict -Title 't' -IssueBody "via Asana`n<!-- asana-task: 1219216227959314 -->") 'the marker links it'
Assert-Equal 'linked' (Get-AsanaPickupVerdict -Title 't' -IssueBody "| **Asana** | $task |") 'so does the header row'
Assert-Equal 'linked' (Get-AsanaPickupVerdict -Title 't' -IssueBody "See $task") 'and a sole task URL, which Resolve-AsanaTaskRef resolves for every reader'
Assert-Equal 'ambiguous' (Get-AsanaPickupVerdict -Title 't' -IssueBody "$task and https://app.asana.com/0/222/333") 'two task URLs and nothing to choose between them'
Assert-Equal 'github-only' (Get-AsanaPickupVerdict -Title 'Cart bug' -IssueBody 'Found while testing.') 'no mention of Asana is the ordinary issue'
Assert-Equal 'github-only' (Get-AsanaPickupVerdict -Title 'Asanas yoga page' -IssueBody '') 'a word that merely contains it does not count'

Write-Host ''
Write-Host 'The lib -- the warning' -ForegroundColor Cyan

$w = Format-AsanaPickupWarning -Number 404 -Verdict 'unlinked'
Assert-True ($w -like 'ASANA LINK MISSING*#404 names Asana but links no Asana task.*') 'an unlinked issue is named by number'
Assert-True ($w.Contains('<!-- asana-task: <gid> -->') -and $w.Contains('Tracked on GitHub:')) 'and the warning names both writes report-issue prescribes'
Assert-True ((Format-AsanaPickupWarning -Number 404 -Verdict 'ambiguous') -like '*several Asana task URLs*') 'an ambiguous issue gets its own reason'
Assert-Equal '' (Format-AsanaPickupWarning -Number 404 -Verdict 'linked') 'a linked issue gets nothing'
Assert-Equal '' (Format-AsanaPickupWarning -Number 404 -Verdict 'github-only') 'and neither does a GitHub-only one'

Write-Host ''
Write-Host 'The hook -- every path that needs no tracker' -ForegroundColor Cyan

$r = Invoke-Hook -Payload '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
Assert-True ($r.Code -eq 0 -and -not $r.Out.Trim() -and -not $r.Err.Trim()) 'a command naming neither script exits 0 and prints nothing'
$r = Invoke-Hook -Payload '{"tool_name":"PowerShell","tool_input":{"command":"claim-issue.ps1 -Candidates"}}'
Assert-True ($r.Code -eq 0 -and -not $r.Out.Trim()) 'a claim command that picks nothing up prints nothing'
$r = Invoke-Hook -Payload 'not json, but it says claim-issue.ps1 404'
Assert-True ($r.Code -eq 0 -and -not $r.Out.Trim()) 'an unparseable payload fails open, silently'

Write-Host ''
Write-Host 'The registration' -ForegroundColor Cyan

$hj = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$entry = @($hj.hooks.PostToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -like '*asana-link-pickupcheck.ps1*' }).Count -gt 0 })
Assert-Equal 1 $entry.Count 'hooks.json registers the hook once, as PostToolUse'
Assert-Equal 'Bash|PowerShell' $entry[0].matcher 'after both shell tools'
$cmd = @($entry[0].hooks)[0].command
Assert-True ($cmd.StartsWith('p=$(cat); printf ''%s'' "$p" | grep -Eq ''(claim-issue|new-branch)\.ps1'' || exit 0;')) 'behind a shell pre-gate, so PowerShell starts only when one of the two scripts is named'

$src = Get-Content -LiteralPath $Hook -Raw
Assert-True ($src -notmatch '\$issue\.(title|body)[^)]*\|\s*Write|Write-Host') 'the hook writes nothing of the issue''s own text'
foreach ($f in @($Hook, (Join-Path $PluginRoot 'scripts\lib\asana-pickup-rules.ps1'), $PSCommandPath)) {
    Assert-True (-not ([System.IO.File]::ReadAllText($f) -match '[^\x00-\x7F]')) "$(Split-Path $f -Leaf) is pure ASCII"
}

Write-Host ''
Write-Host "Result: $($script:pass) pass, $($script:fail) fail."
if ($script:fail -gt 0) { exit 1 }
exit 0
