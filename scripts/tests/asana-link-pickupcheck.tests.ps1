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
    -- this suite runs in CI without tracker credentials. The decisions that path takes are group 1's
    Get-AsanaPickupVerdict, Format-AsanaPickupWarning, Format-AsanaReachLabelWarning,
    Get-AsanaTaskCoClaimants and Format-AsanaCoClaimWarning.

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
# A GITHUB-ONLY ISSUE IS ASKED ABOUT (#2928): xoxowildhearts #401/#402 came from one Asana task and never
# said so, so the word test reads them as ordinary -- the question is the one thing the hook can add.
$q = Format-AsanaPickupWarning -Number 402 -Verdict 'github-only'
Assert-True ($q -like 'ASANA ORIGIN?*#402 links no Asana task and does not mention*') 'a GitHub-only issue gets the origin question, by number'
Assert-True (@($q -split "`n").Count -eq 2 -and $q -notmatch 'LINK MISSING') 'in two lines, and not dressed as the missing-link warning'

Write-Host ''
Write-Host 'The lib -- a linked issue carries the reach label (#2940)' -ForegroundColor Cyan

$rw = Format-AsanaReachLabelWarning -Number 402 -ReachLabel 'minor' -Labels @('feature')
Assert-True ($rw -like "REACH LABEL MISSING*#402 links an Asana task but does not carry 'minor'.*") 'the measured #402: linked, labelled, and no reach label'
Assert-True ($rw.Contains('gh issue edit 402 --add-label "minor"')) 'and the warning carries the line that repairs it'
Assert-True ((Format-AsanaReachLabelWarning -Number 402 -ReachLabel 'minor' -Labels @()) -like 'REACH LABEL MISSING*') 'an issue with no labels at all is missing it too'
Assert-Equal '' (Format-AsanaReachLabelWarning -Number 402 -ReachLabel 'minor' -Labels @('feature', 'Minor')) 'carrying it, in any case, says nothing'
Assert-Equal '' (Format-AsanaReachLabelWarning -Number 402 -ReachLabel 'minor' -Labels $null) 'labels that could not be read are no evidence, so nothing'
Assert-True ((Format-AsanaReachLabelWarning -Number 7 -ReachLabel 'tier-1' -Labels @('minor')) -like "*does not carry 'tier-1'*") 'the name judged is the project''s own answer'

$cfgRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("reach-label-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path (Join-Path $cfgRoot 'scripts') -Force | Out-Null
    $rl = Get-ProjectReachLabel -ProjectDir $cfgRoot
    Assert-True ($rl.Label -eq 'minor' -and -not $rl.ReadFailed) 'no repo-config: the prescribed default, and no read failure'
    Set-Content -LiteralPath (Join-Path $cfgRoot 'scripts\repo-config.ps1') -Value "function Get-ReachLabel { 'tier-1' }" -Encoding ASCII
    Assert-Equal 'tier-1' (Get-ProjectReachLabel -ProjectDir $cfgRoot).Label 'repo-config answering Get-ReachLabel names the label'
    Set-Content -LiteralPath (Join-Path $cfgRoot 'scripts\repo-config.ps1') -Value "throw 'broken'" -Encoding ASCII
    $rl = Get-ProjectReachLabel -ProjectDir $cfgRoot
    Assert-True ($rl.Label -eq 'minor' -and $rl.ReadFailed) 'a repo-config that throws: the default, and the failure reported'
} finally {
    Remove-Item -LiteralPath $cfgRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'The lib -- one task, one issue (#2928)' -ForegroundColor Cyan

$gid = '1217711673556434'
$peers = @(
    [pscustomobject]@{ number = 402; body = "<!-- asana-task: $gid -->" },
    [pscustomobject]@{ number = 401; body = "| **Asana** | https://app.asana.com/1/1/project/2/task/$gid |" },
    [pscustomobject]@{ number = 399; body = "mentions $gid only as a number" },
    [pscustomobject]@{ number = 398; body = '<!-- asana-task: 999 -->' }
)
$co = @(Get-AsanaTaskCoClaimants -Gid $gid -Number 402 -Issues $peers)
Assert-Equal '401' ($co -join ',') 'the other issue resolving to the same task is found, the issue itself and a bare number are not'
Assert-Equal 0 @(Get-AsanaTaskCoClaimants -Gid $gid -Number 402 -Issues @()).Count 'an empty search names nobody'
$cw = Format-AsanaCoClaimWarning -Number 402 -Gid $gid -Others @(401)
Assert-True ($cw -like "ONE TASK, TWO ISSUES*task $gid is linked from issue #402 and also from #401.*") 'the warning names the task and both issues'
Assert-Equal '' (Format-AsanaCoClaimWarning -Number 402 -Gid $gid -Others @()) 'and with no other issue there is nothing to say'

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
