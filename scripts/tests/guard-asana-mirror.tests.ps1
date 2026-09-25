<#
.SYNOPSIS
    Tests for plugins/dkj-policy/dkj-policy-bwj/hooks/guard-asana-mirror.ps1 and its lib,
    scripts/lib/asana-mirror-gate.ps1 -- the PreToolUse hook that refuses an Asana task mirroring a
    GitHub issue without the reach label (inbound #2482).

.DESCRIPTION
    THREE GROUPS.
      1. THE LIB, in-process: which URLs count as a mirror, and the three verdicts. 'unknown' is held
         apart from 'refuse' on purpose -- a failed read is not evidence the label is absent.
      2. THE HOOK, as a process, on every path that makes no network call: the cheap pre-gate, a URL on
         a repo report-issue does not admit, and an unparseable payload. Each must exit 0.
      3. THE REGISTRATION: hooks.json names the file and matches the Asana create-task tools, and only
         those -- a matcher that missed a tool would leave the gate a sentence again.

    THE TEST GAP, NAMED. The admit/refuse paths of the hook PROCESS need `gh` to answer about a real
    issue, so they are not run here -- this suite runs in CI without tracker credentials. The decision
    those paths take is group 1's Get-AsanaMirrorVerdict, and the branch that shipped this hook ran
    both live (smartwatchbanden#770 refused, #764 admitted).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'
$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-policy-bwj'
$Hook       = Join-Path $PluginRoot 'hooks\guard-asana-mirror.ps1'
$HooksJson  = Join-Path $PluginRoot 'hooks\hooks.json'

. (Join-Path $PluginRoot 'scripts\lib\asana-mirror-gate.ps1')

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
    <# Runs the hook with $Payload on stdin; returns @{ Code; Err }. #>
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
    $null = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return @{ Code = $p.ExitCode; Err = $errTask.Result }
}

# --- 1. The lib -------------------------------------------------------------------------------------
Write-Host 'the lib' -ForegroundColor Cyan

$refs = @(Get-MirroredIssueRefs -Text 'Tracked on GitHub: https://github.com/BWJ-Development/smartwatchbanden/issues/770')
Assert-Equal 1 $refs.Count 'a Tracked-on-GitHub line on an admitted repo is one mirrored issue'
Assert-Equal 'BWJ-Development/smartwatchbanden#770' $refs[0].Ref 'and its ref is owner/repo#n'
Assert-Equal 770 $refs[0].Number 'and its number is an int'

$both = 'notes: https://github.com/BWJ-Development/smartwatchbanden/issues/770 field: https://github.com/BWJ-Development/smartwatchbanden/issues/770'
Assert-Equal 1 @(Get-MirroredIssueRefs -Text $both).Count 'the same issue in the notes and the custom field counts once'

Assert-Equal 0 @(Get-MirroredIssueRefs -Text 'https://github.com/someone/other-repo/issues/5').Count 'an issue on a repo report-issue does not admit is not a mirror'
Assert-Equal 0 @(Get-MirroredIssueRefs -Text 'https://github.com/BWJ-Development/smartwatchbanden/pull/771').Count 'a pull request URL is not an issue'
Assert-Equal 1 @(Get-MirroredIssueRefs -Text 'https://github.com/DKJ-Solutions/DKJ-Claude-Plugins/issues/1').Count 'the repo name is matched case-insensitively'
Assert-Equal 2 @(Get-MirroredIssueRefs -Text 'https://github.com/a/xoxowildhearts/issues/1 https://github.com/b/smartwatchbanden/issues/2').Count 'two admitted repos in one task are two mirrored issues'
Assert-Equal 0 @(Get-MirroredIssueRefs -Text '').Count 'empty text is no mirror'

Assert-Equal 'admit'   (Get-AsanaMirrorVerdict -Labels @('documentation', 'minor') -ReachLabel 'minor') 'the reach label on the issue admits it'
Assert-Equal 'admit'   (Get-AsanaMirrorVerdict -Labels @('Minor') -ReachLabel 'minor') 'case-insensitively, as GitHub matches labels'
Assert-Equal 'admit'   (Get-AsanaMirrorVerdict -Labels @('tier-1') -ReachLabel 'tier-1') 'a repo that renamed its reach label is judged by its own name'
Assert-Equal 'refuse'  (Get-AsanaMirrorVerdict -Labels @('documentation') -ReachLabel 'minor') 'smartwatchbanden#770 -- documentation only -- is refused'
Assert-Equal 'refuse'  (Get-AsanaMirrorVerdict -Labels ([string[]]@()) -ReachLabel 'minor') 'an issue with no labels at all is refused'
Assert-Equal 'unknown' (Get-AsanaMirrorVerdict -Labels $null -ReachLabel 'minor') 'labels that could not be read are unknown, never refused'

$parsed = ConvertFrom-GhIssueLabels -Json '{"labels":[{"name":"documentation"},{"name":"minor"}]}'
Assert-Equal 'documentation,minor' ($parsed -join ',') 'gh --json labels output parses to label names'
$empty = ConvertFrom-GhIssueLabels -Json '{"labels":[]}'
Assert-True ($null -ne $empty -and @($empty).Count -eq 0) 'an issue with no labels parses to an EMPTY list, not to unknown'
Assert-True ($null -eq (ConvertFrom-GhIssueLabels -Json 'not json')) 'an unparseable reply is unknown'
Assert-True ($null -eq (ConvertFrom-GhIssueLabels -Json '{"state":"OPEN"}')) 'a reply without a labels field is unknown'

$ti = Get-AsanaMirrorToolInputText -Raw '{"tool_name":"x","tool_input":{"tasks":[{"notes":"https:\/\/github.com\/a\/smartwatchbanden\/issues\/9"}]}}'
Assert-Equal 1 @(Get-MirroredIssueRefs -Text $ti).Count 'an escaped URL in the payload is matched in its decoded form'
Assert-Equal '' (Get-AsanaMirrorToolInputText -Raw '{broken') 'an unparseable payload yields no text to search'

# --- 2. The hook, on the paths that make no network call --------------------------------------------
Write-Host 'the hook, network-free paths' -ForegroundColor Cyan

$r = Invoke-Hook '{"tool_name":"mcp__claude_ai_Asana__create_tasks","tool_input":{"tasks":[{"name":"Plan the offsite","notes":"no link here"}]}}'
Assert-Equal 0 $r.Code 'a task citing no GitHub issue passes'
Assert-Equal '' $r.Err.Trim() 'and passes silently'

$r = Invoke-Hook '{"tool_name":"mcp__claude_ai_Asana__create_tasks","tool_input":{"tasks":[{"name":"x","notes":"https://github.com/someone/other-repo/issues/5"}]}}'
Assert-Equal 0 $r.Code 'a task citing an issue on a repo report-issue does not admit passes'

$r = Invoke-Hook 'github.com/a/smartwatchbanden/issues/1 but not json'
Assert-Equal 0 $r.Code 'an unparseable payload passes rather than blocking every Asana write'

# --- 3. The registration ----------------------------------------------------------------------------
Write-Host 'hooks.json registration' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $HooksJson -PathType Leaf) 'dkj-policy-bwj ships a hooks.json'
$manifest = Get-Content -Raw -LiteralPath $HooksJson | ConvertFrom-Json
$entry = @($manifest.hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-asana-mirror\.ps1' }).Count -gt 0 })
Assert-Equal 1 $entry.Count 'guard-asana-mirror.ps1 is registered as a PreToolUse hook exactly once'
$matcher = '^(?:' + $entry[0].matcher + ')$'
foreach ($tool in @('mcp__claude_ai_Asana__create_tasks', 'mcp__claude_ai_Asana__create_task_preview_v4',
                    'mcp__claude_ai_Asana_2__create_tasks', 'mcp__asana__create_task')) {
    Assert-True ($tool -match $matcher) "the matcher covers $tool"
}
foreach ($tool in @('mcp__claude_ai_Asana__update_tasks', 'mcp__claude_ai_Asana__add_comment',
                    'mcp__claude_ai_Asana__create_project', 'Bash')) {
    Assert-True (-not ($tool -match $matcher)) "the matcher leaves $tool alone"
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
