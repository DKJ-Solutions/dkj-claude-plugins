<#
.SYNOPSIS
    Tests for scripts/lib/closeout-gate-lib.ps1 and plugins/dkj-policy/hooks/closeout-gate.ps1 -- the
    close-out gate (issue #2050): the band, the marker, the verdict, and the hook that acts on them.

.DESCRIPTION
    THE SUITE IS WEIGHTED TOWARDS THE WAYS THE GATE MUST NOT FIRE, and that is deliberate. This is the
    first hook in this workflow that BLOCKS a turn, against cycle-autopark.ps1's stated contract that a
    Stop hook never does. What makes that reversal safe is not the blocking path -- it is that every
    other path exits 0: a missing lib, an unreadable payload, a repo that never opted in, a turn with
    no chain behind it, a malformed seam. Each of those is asserted below, because a regression in any
    one of them does not produce a wrong refusal message, it produces a session that cannot end.

    THE LOOP GUARD IS ASSERTED AS A PROPERTY, not as a code path. Pop-CloseOutMarker consumes the
    marker as it reads it, so the second call in a row must answer $false whatever the first answered.
    That is what makes a block-then-refire impossible by construction rather than by trusting
    stop_hook_active -- a field this repo could not confirm across harness versions, and therefore does
    not rest on. Both halves are checked: the property here, and that the hook still reads the field.

    THE HOOK IS DRIVEN END TO END, through a real child process with a real payload on stdin and a
    real marker on disk, because the three overrides exist for exactly that. A unit test of
    Get-CloseOutGateVerdict alone would pass on a hook that never reaches it -- which is the same trap
    closeout-lib.tests.ps1 answers with its structural half, one layer down.

    EVERY MARKER IN THIS SUITE IS WRITTEN UNDER AN OVERRIDDEN CACHE ROOT in the session scratch
    directory, so a run never touches the per-user cache a live session's gate reads from. A suite that
    dropped a real marker would arm the gate on the very turn that ran it.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\closeout-gate-lib.ps1'
$HookPath = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\closeout-gate.ps1'

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

Assert-True (Test-Path -LiteralPath $LibPath)  'closeout-gate-lib.ps1 exists at its registered source path'
Assert-True (Test-Path -LiteralPath $HookPath) 'closeout-gate.ps1 exists beside the other plugin hooks'
. $LibPath

# An isolated cache root and an isolated fake repo, both under the session scratch directory. See the
# header: nothing here may reach the per-user cache the live gate reads.
$sandbox   = Join-Path ([System.IO.Path]::GetTempPath()) ("closeout-gate-tests-" + [guid]::NewGuid().ToString('N'))
$cacheRoot = Join-Path $sandbox 'cache'
$fakeRepo  = Join-Path $sandbox 'repo'
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fakeRepo 'scripts') -Force | Out-Null

function New-FakeRepoConfig {
    <# A consumer's scripts/repo-config.ps1 holding one answer -- or none, for the opted-out case. #>
    param([string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $fakeRepo 'scripts\repo-config.ps1'), $Body, (New-Object System.Text.UTF8Encoding $false))
}

function Invoke-Hook {
    <#
        Run the hook as the harness would: a JSON payload on stdin, in its own process, with the three
        overrides pointed at this suite's sandbox. Returns @{ ExitCode; Stderr }.
    #>
    param([string]$Payload)

    $payloadFile = Join-Path $sandbox 'payload.json'
    $errFile     = Join-Path $sandbox 'stderr.txt'
    [System.IO.File]::WriteAllText($payloadFile, $Payload, (New-Object System.Text.UTF8Encoding $false))

    # cmd's redirection rather than the call operator's: stdin must be a REDIRECTED handle, which is
    # what the hook tests before reading it at all.
    $args = @(
        '/c', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$HookPath`"",
        '-LibOverride', "`"$LibPath`"", '-RepoRootOverride', "`"$fakeRepo`"", '-CacheRootOverride', "`"$cacheRoot`"",
        '<', "`"$payloadFile`"", '2>', "`"$errFile`""
    )
    $p = Start-Process -FilePath $env:ComSpec -ArgumentList $args -NoNewWindow -Wait -PassThru
    # -Raw on an EMPTY file returns $null, and '[string]$null' is $null rather than '' -- so the cast
    # that looks like it normalises this does not. Normalised explicitly, because the allowed path is
    # asserted to say nothing at all and that assert would otherwise crash on its own success.
    $stderr = if (Test-Path -LiteralPath $errFile) { Get-Content -LiteralPath $errFile -Raw } else { '' }
    if ($null -eq $stderr) { $stderr = '' }
    return @{ ExitCode = $p.ExitCode; Stderr = $stderr }
}

function New-Payload {
    param([string]$Message, [bool]$StopHookActive = $false)
    return (@{
        session_id             = 'closeout-gate-suite-0001'
        cwd                    = $fakeRepo
        last_assistant_message = $Message
        stop_hook_active       = $StopHookActive
    } | ConvertTo-Json -Compress)
}

# A close-out of a known height, built from the count the band is stated in rather than from prose, so
# the assert cannot drift with the wording.
function New-Message { param([int]$Lines) return (( 1..$Lines | ForEach-Object { "line $_" } ) -join "`n") }

try {

Write-Host ''
Write-Host 'The line count -- what the band is stated in' -ForegroundColor Cyan

Assert-Equal 0 (Get-CloseOutLineCount -Text '')                  'an empty message is zero lines'
Assert-Equal 0 (Get-CloseOutLineCount -Text "   `n`n  ")         'whitespace only is zero lines'
Assert-Equal 3 (Get-CloseOutLineCount -Text "a`nb`nc")           'three lines count as three'
# THE ONE THAT MATTERS: blanks are excluded, so a receipt cannot pass or fail on its formatting.
Assert-Equal 3 (Get-CloseOutLineCount -Text "a`n`nb`n`n`nc`n")   'blank separators do not count'
Assert-Equal 3 (Get-CloseOutLineCount -Text "a`r`n`r`nb`r`nc")   'CRLF counts the same as LF'

Write-Host ''
Write-Host 'The verdict -- inclusive upper bound, and off when there is no band' -ForegroundColor Cyan

Assert-Equal $false (Get-CloseOutGateVerdict -Message (New-Message 6) -Band 6).Blocked  'exactly the band passes -- the bound is inclusive'
Assert-Equal $true  (Get-CloseOutGateVerdict -Message (New-Message 7) -Band 6).Blocked  'one over the band is refused'
Assert-Equal 7      (Get-CloseOutGateVerdict -Message (New-Message 7) -Band 6).Lines    'the verdict reports the measured height'
Assert-Equal $false (Get-CloseOutGateVerdict -Message (New-Message 99) -Band 0).Blocked 'band 0 means no gate, however long the message'
Assert-Equal $false (Get-CloseOutGateVerdict -Message '' -Band 6).Blocked               'an empty message is never a violation'

# The refusal obeys its own band, which is not decoration: it is the first thing in context when the
# replacement close-out is composed.
$refusal = Get-CloseOutGateRefusal -Verdict (Get-CloseOutGateVerdict -Message (New-Message 40) -Band 6)
Assert-True (@($refusal).Count -le 6) 'the refusal itself fits inside the default band'
Assert-True (($refusal -join ' ') -match 'REHOUSED') 'the refusal names rehousing rather than only cutting'

Write-Host ''
Write-Host 'The band seam -- absent and malformed both mean OFF' -ForegroundColor Cyan

# Resolve-CloseOutGateBand reads whatever Get-CloseOutGateBand is defined in this session, which is
# exactly how a hook that has just dot-sourced a repo-config sees it.
Assert-Equal 0 (Resolve-CloseOutGateBand) 'no seam defined at all means no gate'
function Get-CloseOutGateBand { return 6 }
Assert-Equal 6 (Resolve-CloseOutGateBand) 'a repo that opted in gets its own band'
function Get-CloseOutGateBand { return 0 }
Assert-Equal 0 (Resolve-CloseOutGateBand) '0 is a real answer -- the gate off without deleting the function'
function Get-CloseOutGateBand { return -4 }
Assert-Equal 0 (Resolve-CloseOutGateBand) 'a negative band is off, not a fallback to the default'
function Get-CloseOutGateBand { return 'six' }
Assert-Equal 0 (Resolve-CloseOutGateBand) 'a non-numeric answer is off, not a fallback to the default'
Remove-Item Function:\Get-CloseOutGateBand -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'The marker -- consuming it IS the loop guard' -ForegroundColor Cyan

Assert-Equal $false (Pop-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot) 'no chain ended: nothing to claim'
Assert-True  (Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot)      'a chain end drops a marker'
Assert-Equal $true  (Pop-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot) 'the next Stop claims it'
# THE PROPERTY THE WHOLE DESIGN RESTS ON. The block this run may issue fires Stop again; that firing
# must find nothing, or the gate can refuse the same turn forever.
Assert-Equal $false (Pop-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot) '...and the firing after that finds nothing -- the block cannot repeat'

# Two repos on one machine do not claim each other's chains.
$otherRepo = Join-Path $sandbox 'other-repo'
$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
Assert-Equal $false (Pop-CloseOutMarker -Cwd $otherRepo -Root $cacheRoot) 'a marker is scoped to the repo that wrote it'
Assert-Equal $true  (Pop-CloseOutMarker -Cwd $fakeRepo  -Root $cacheRoot) '...and is still there for the repo that did'

# The scope key is normalised, because the writer and the reader can spell one directory differently.
# A mismatch would not be a wrong block -- it would be a gate that silently never fires.
Assert-Equal (Get-CloseOutGateScopeKey -Cwd 'C:\Repos\Thing') (Get-CloseOutGateScopeKey -Cwd 'c:/repos/thing/') 'the scope key survives case, slashes and a trailing separator'

Write-Host ''
Write-Host 'The hook end to end -- the ways it must NOT fire' -ForegroundColor Cyan

New-FakeRepoConfig -Body 'function Get-CloseOutGateBand { return 6 }'

# No marker: an ordinary turn, which is the overwhelming majority of them.
Assert-Equal 0 (Invoke-Hook -Payload (New-Payload -Message (New-Message 40))).ExitCode 'a turn with no chain behind it is never gated, however long'

# stop_hook_active, asserted separately from the marker so a regression in either is visible.
$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
Assert-Equal 0 (Invoke-Hook -Payload (New-Payload -Message (New-Message 40) -StopHookActive $true)).ExitCode 'stop_hook_active is honoured'
$null = Pop-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot

# An unparseable payload fails towards ALLOWING -- the opposite of the working-copy guard, and right
# for the opposite reason: this one decides whether to block a person's turn over a writing rule.
$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
Assert-Equal 0 (Invoke-Hook -Payload 'not json at all').ExitCode 'an unreadable payload lets the turn end'

# A repo that never opted in. The marker is still claimed, so this also proves the claim happens
# before the seam is read.
New-FakeRepoConfig -Body '# this repo answers nothing'
$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
Assert-Equal 0 (Invoke-Hook -Payload (New-Payload -Message (New-Message 40))).ExitCode 'a repo that never opted in is never gated'

# A missing lib is a half-installed plugin, not a reason to strand a session.
$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
$missing = Start-Process -FilePath $env:ComSpec -NoNewWindow -Wait -PassThru -ArgumentList @(
    '/c', 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$HookPath`"",
    '-LibOverride', "`"$(Join-Path $sandbox 'no-such-lib.ps1')`"", '<', 'NUL'
)
Assert-Equal 0 $missing.ExitCode 'a missing lib leaves the gate off rather than stranding the turn'

Write-Host ''
Write-Host 'The hook end to end -- the one way it does' -ForegroundColor Cyan

New-FakeRepoConfig -Body 'function Get-CloseOutGateBand { return 6 }'

$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
$ok = Invoke-Hook -Payload (New-Payload -Message (New-Message 6))
Assert-Equal 0 $ok.ExitCode 'a close-out inside the band ends the turn'
Assert-Equal '' $ok.Stderr.Trim() '...and says nothing at all while doing it'

$null = Write-CloseOutMarker -Cwd $fakeRepo -Root $cacheRoot
$blocked = Invoke-Hook -Payload (New-Payload -Message (New-Message 12))
Assert-Equal 2 $blocked.ExitCode 'a close-out over the band is refused with exit 2'
Assert-True ($blocked.Stderr -match 'BLOCKED \(closeout-gate\)') '...naming itself, so the reader knows which gate spoke'
Assert-True ($blocked.Stderr -match '12 non-empty lines against a band of 6') '...and reporting the measurement it refused on'

# THE REFIRE, WHICH IS WHAT A REAL BLOCK LOOKS LIKE ONE TURN LATER. Same payload, same repo, and the
# marker is gone -- so the model's replacement close-out is not judged again.
$refire = Invoke-Hook -Payload (New-Payload -Message (New-Message 12))
Assert-Equal 0 $refire.ExitCode 'the firing after a block finds no chain and lets the turn end'

Write-Host ''
Write-Host 'Registration, mirroring and the ASCII rule' -ForegroundColor Cyan

$raw = Get-Content -LiteralPath $LibPath -Raw
Assert-True (-not ($raw -cmatch '[^\x00-\x7F]')) 'closeout-gate-lib.ps1 is pure ASCII'
$hookRaw = Get-Content -LiteralPath $HookPath -Raw
Assert-True (-not ($hookRaw -cmatch '[^\x00-\x7F]')) 'closeout-gate.ps1 is pure ASCII'

# The hook is only a hook once hooks.json says so -- the same "defined but never called" trap
# closeout-lib.tests.ps1 answers one layer down.
$hooksJson = Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\hooks\hooks.json') -Raw
Assert-True ($hooksJson -match 'closeout-gate\.ps1') 'the hook is registered in hooks.json'
# -match over a COLLECTION filters rather than tests, so it hands back the matching commands and not a
# bool. Counted instead, which also says how many Stop hooks name it -- one.
$stopCommands = @(($hooksJson | ConvertFrom-Json).hooks.Stop.hooks.command)
Assert-Equal 1 @($stopCommands | Where-Object { $_ -match 'closeout-gate' }).Count '...on the Stop event, which is the only one that carries the close-out'

# And the marker is only dropped if the printer still drops it.
$closeoutLib = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\closeout-lib.ps1') -Raw
Assert-True ($closeoutLib -match 'Write-CloseOutMarker') 'Write-CloseOutReceipt still arms the gate'
Assert-True ($closeoutLib -match 'closeout-gate-lib\.ps1') '...through a dot-source of this lib'
Assert-True ($closeoutLib -match 'Test-Path -LiteralPath \$closeoutGateLib') '...and that dot-source is guarded, so an older mirror does not crash on load'

Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1') -Raw) -match 'closeout-gate-lib') 'closeout-gate-lib is registered as a shared script'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lib\closeout-gate-lib.ps1')) '...and its plugin mirror is present'
Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\script-contract-lib.ps1') -Raw) -match 'Get-CloseOutGateBand') 'the seam is declared in the script contract'

} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
