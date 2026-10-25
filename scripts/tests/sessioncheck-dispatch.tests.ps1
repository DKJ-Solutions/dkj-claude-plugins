<#
.SYNOPSIS
    Regression tests for the SessionStart dispatcher plugins/dkj-policy/hooks/sessioncheck-dispatch.ps1
    (issue #3472): one hooks.json entry that runs every *-sessioncheck.ps1 beside it in one interpreter.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/sessioncheck-dispatch.tests.ps1

    The dispatcher is driven against a FIXTURE hooks directory (-HooksDir) of stub checks, one per shape
    it has to merge: plain lines, a JSON answer, a throw, a non-zero exit, silence, a check that reads
    the process environment, and a file that does not match the pattern. A second fixture holds a check
    that hangs, for the deadline. The real checks are each pinned by their own suite; this one pins the
    merge, the discovery, the isolation and the wiring.

    Fixture paths carry $PID (repo convention). Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Hook      = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\sessioncheck-dispatch.ps1'
$HooksDir  = Join-Path $RepoRoot 'plugins\dkj-policy\hooks'
$HooksJson = Join-Path $HooksDir 'hooks.json'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message`n         wanted: '$Expected'`n         got:    '$Actual'" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label, [hashtable]$Files = @{})
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("dispatch-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($k in $Files.Keys) {
        [System.IO.File]::WriteAllText((Join-Path $dir $k), $Files[$k], (New-Object System.Text.UTF8Encoding($false)))
    }
    $script:trees += $dir
    return $dir
}

function Invoke-Dispatch {
    param([string]$Dir, [int]$Deadline = 100)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -HooksDir $Dir -DeadlineSeconds $Deadline 2>$null)
    $code = $LASTEXITCODE
    $text = (($out | ForEach-Object { "$_" }) -join "`n").Trim()
    $json = $null
    if ($text) { try { $json = $text | ConvertFrom-Json } catch { $json = $null } }
    return [pscustomobject]@{ Text = $text; Json = $json; Code = $code; Ms = $sw.ElapsedMilliseconds; Lines = $out.Count }
}

Write-Host '== sessioncheck-dispatch.ps1 ==' -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'the dispatcher exists at its plugin path'

# --- hooks.json: one entry runs the checks, none of them is wired on its own ------------------------
Write-Host ''
Write-Host 'hooks.json registration' -ForegroundColor Cyan
$parsed = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$groups = @($parsed.hooks.SessionStart)
$all = @($groups | ForEach-Object { $_.hooks } | ForEach-Object { $_ })
$disp = @($groups | Where-Object { @($_.hooks | Where-Object { $_.command -match 'sessioncheck-dispatch\.ps1' }).Count -gt 0 })
Assert-Equal 1 $disp.Count 'exactly one SessionStart group runs the dispatcher'
if ($disp.Count -eq 1) {
    Assert-Equal 'startup|resume|clear|compact' $disp[0].matcher 'on every start, resume, clear and compact -- the matcher every check had'
    $entry = @($disp[0].hooks | Where-Object { $_.command -match 'sessioncheck-dispatch\.ps1' })[0]
    Assert-True ([int]$entry.timeout -gt 100) 'its timeout sits above the dispatcher''s own 100 s deadline, so the deadline answers first'
}
$direct = @($all | Where-Object { $_.command -match '/hooks/[^/"]+-sessioncheck\.ps1' })
Assert-Equal 0 $direct.Count 'no *-sessioncheck.ps1 has a hooks.json entry of its own -- each would be a cold interpreter again'
$checks = @(Get-ChildItem -LiteralPath $HooksDir -Filter '*-sessioncheck.ps1' -File)
Assert-True ($checks.Count -ge 10) "the dispatcher discovers the plugin's checks ($($checks.Count) found)"
$preview = @($all | Where-Object { $_.command -match 'dev-preview-sessionstart\.ps1' })
Assert-Equal 1 $preview.Count 'dev-preview-sessionstart keeps its own entry (it starts servers)'
Assert-True (-not ('dev-preview-sessionstart.ps1' -like '*-sessioncheck.ps1')) 'and the discovery pattern does not pick it up'

# --- the merge -------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'merge of plain, JSON, failing and silent checks' -ForegroundColor Cyan
$q = '"'
$tree = New-Tree -Label merge -Files @{
    'a-plain-sessioncheck.ps1'  = "Write-Host 'a-plain: first line'`nWrite-Host 'a-plain: second line'`nexit 0`n"
    'b-json-sessioncheck.ps1'   = "Write-Output '{${q}systemMessage${q}:${q}b shown to the user${q},${q}hookSpecificOutput${q}:{${q}hookEventName${q}:${q}SessionStart${q},${q}additionalContext${q}:${q}b-json: for the model${q}}}'`nexit 0`n"
    'c-throw-sessioncheck.ps1'  = "throw ('boom [ERROR]' + [char]10 + 'forged line')`n"
    'd-exit-sessioncheck.ps1'   = "Write-Host 'd-exit: said before exiting'`nexit 3`n"
    'e-env-sessioncheck.ps1'    = "Write-Host ('e-env: GIT_TERMINAL_PROMPT=' + `$env:GIT_TERMINAL_PROMPT)`n"
    'f-silent-sessioncheck.ps1' = "exit 0`n"
    'not-a-check.ps1'           = "Write-Host 'SHOULD-NOT-RUN'`n"
}
$r = Invoke-Dispatch -Dir $tree
Assert-Equal 0 $r.Code 'exit 0'
Assert-Equal 1 $r.Lines 'one line of stdout -- one JSON object'
Assert-True ($null -ne $r.Json) 'and it parses as JSON'
if ($r.Json) {
    $ctx = [string]$r.Json.hookSpecificOutput.additionalContext
    Assert-Equal 'SessionStart' $r.Json.hookSpecificOutput.hookEventName 'hookSpecificOutput names the SessionStart event'
    Assert-Equal 'b shown to the user' $r.Json.systemMessage 'a JSON check''s systemMessage is passed on as the systemMessage'
    Assert-True ($ctx -match 'b-json: for the model') 'and its additionalContext joins the context'
    Assert-True ($ctx -notmatch 'systemMessage') 'the JSON check''s raw object is not forwarded as text'
    Assert-True ($ctx -match 'a-plain: first line' -and $ctx -match 'a-plain: second line') 'a plain check''s lines reach the context'
    Assert-True ($ctx -match 'd-exit: said before exiting') 'a check that exits non-zero still has its lines forwarded'
    Assert-True ($ctx -match 'c-throw-sessioncheck skipped due to an error: boom \(ERROR\) forged line') 'a throwing check is one sanitized line, named, with no marker and no forged line'
    Assert-True ($ctx -notmatch '\[ERROR\]') 'no bracketed marker survives from the exception text'
    Assert-True ($ctx -match 'e-env: GIT_TERMINAL_PROMPT=0') 'checks run with the non-interactive git environment set before the pool opened'
    Assert-True ($ctx -notmatch 'SHOULD-NOT-RUN') 'a file not named *-sessioncheck.ps1 is not run'
    $ia = $ctx.IndexOf('a-plain:'); $ib = $ctx.IndexOf('b-json:'); $ic = $ctx.IndexOf('c-throw'); $id = $ctx.IndexOf('d-exit:'); $ie = $ctx.IndexOf('e-env:')
    Assert-True ($ia -ge 0 -and $ia -lt $ib -and $ib -lt $ic -and $ic -lt $id -and $id -lt $ie) 'the report is in check-name order, whatever order they finished in'
    Assert-True ($ctx -notmatch '(?m)^\s*$') 'a silent check adds no empty line'
}

# --- nothing to say --------------------------------------------------------------------------------
Write-Host ''
Write-Host 'nothing to report' -ForegroundColor Cyan
$empty = New-Tree -Label empty -Files @{ 'quiet-sessioncheck.ps1' = "exit 0`n" }
$r = Invoke-Dispatch -Dir $empty
Assert-Equal 0 $r.Code 'exit 0'
Assert-Equal '' $r.Text 'no output at all when no check has anything to say'
$none = New-Tree -Label none
$r = Invoke-Dispatch -Dir $none
Assert-True ($r.Code -eq 0 -and $r.Text -eq '') 'an empty directory: exit 0, no output'

# --- the deadline ----------------------------------------------------------------------------------
Write-Host ''
Write-Host 'a check that hangs' -ForegroundColor Cyan
$hang = New-Tree -Label hang -Files @{
    'fast-sessioncheck.ps1' = "Write-Host 'fast: done'`n"
    'slow-sessioncheck.ps1' = "Start-Sleep -Seconds 60`nWrite-Host 'slow: too late'`n"
}
$r = Invoke-Dispatch -Dir $hang -Deadline 3
Assert-Equal 0 $r.Code 'exit 0'
Assert-True ($r.Ms -lt 30000) "the dispatcher leaves at its deadline rather than waiting the check out ($($r.Ms) ms)"
if ($r.Json) {
    $ctx = [string]$r.Json.hookSpecificOutput.additionalContext
    Assert-True ($ctx -match 'fast: done') 'the checks that finished are still reported'
    Assert-True ($ctx -match 'slow-sessioncheck: did not finish within 3 s -- skipped\.') 'the hung check is named'
    Assert-True ($ctx -notmatch 'too late') 'and nothing it writes afterwards appears'
} else {
    Assert-True $false 'the deadline run produced its JSON report'
}

# --- the source ------------------------------------------------------------------------------------
$raw = Get-Content -LiteralPath $Hook -Raw
Assert-True (-not ($raw -cmatch '[^\x00-\x7F]')) 'sessioncheck-dispatch.ps1 is pure ASCII'

foreach ($t in $script:trees) {
    if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
