<#
.SYNOPSIS
    Regression tests for the background progress bar (issue #2101): scripts/lib/run-progress-lib.ps1
    and the statusline command scripts/task/show-progress.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/run-progress.tests.ps1

    EVERY CASE WRITES INTO ITS OWN FIXTURE ROOT, passed with -Root. The real root is a per-user
    directory holding whatever the machine is running right now, and a suite that read or reaped it
    would delete a live gate's record -- the mechanism under test is one whose whole job is to remove
    files, so pointing it at a shared directory is not a small mistake.

    THE LIVENESS CASES ARE WHERE THE VALUE IS. A bar that outlives its run is worse than no bar: it
    reports work that is not happening, on the one surface that is always on screen. So the two ways a
    record must be dropped -- the writer is gone, and the writer's pid belongs to somebody else now --
    are both walked with a real process rather than with a fabricated number, and the two ways it must
    NOT be dropped -- a healthy run that has published nothing for minutes, and an unparseable file
    somebody else put there -- are walked beside them.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Lib        = Join-Path $RepoRoot 'scripts\lib\run-progress-lib.ps1'
$StatusLine = Join-Path $RepoRoot 'scripts\task\show-progress.ps1'

. $Lib

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param([string]$Expected, [string]$Actual, [string]$Message)
    if ($Expected -ceq $Actual) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else {
        $script:fail++
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        Write-Host "         expected: '$Expected'" -ForegroundColor Red
        Write-Host "         actual:   '$Actual'" -ForegroundColor Red
    }
}

function New-Root {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("runprogress-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function Get-DeadProcessId {
    <#
        A pid that is provably gone: a process started here, waited out, and then read. A literal like
        999999 would usually work and would be a suite that fails on the machine where it does not.
    #>
    $p = Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile', '-Command', 'exit' -PassThru -WindowStyle Hidden
    $p.WaitForExit()
    return $p.Id
}

Write-Host '== run-progress ==' -ForegroundColor Cyan

# --- 1. the round trip, and the shape of the two lines -----------------------------------------
$root = New-Root 'roundtrip'
$started = (Get-Date).AddSeconds(-372).ToUniversalTime()
Assert-True (Write-RunProgress -Id 'gate' -Label 'test gate' -Current 37 -Total 84 -Note '7 running' -StartedUtc $started -Root $root) `
    'Write-RunProgress: publishing a counted record reports success'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'gate.json') -PathType Leaf) `
    'Write-RunProgress: the record lands at <id>.json'

$live = @(Get-LiveRunProgress -Root $root)
Assert-True ($live.Count -eq 1) 'Get-LiveRunProgress: one live record comes back'
Assert-Equal '[#####-------] 37/84  test gate (7 running)  +6m12s' (Format-RunProgressLine -Record $live[0]) `
    'Format-RunProgressLine: counts give a bar, the note rides in brackets, elapsed is derived'

# NO TEMPORARY FILE IS LEFT BEHIND by the write-aside-then-move. A '.tmp' surviving would be read by
# nothing -- the reader filters on *.json -- but it would accumulate one file per publish, and the gate
# publishes 168 times in a run.
Assert-True (@(Get-ChildItem -LiteralPath $root -Filter '*.tmp' -File).Count -eq 0) `
    'Write-RunProgress: the staging file is moved, not left beside the record'

# --- 2. no counts, no bar --------------------------------------------------------------------
$root = New-Root 'nocounts'
[void](Write-RunProgress -Id 'ship' -Label 'ship-pr: CI on PR #2103' -StartedUtc ((Get-Date).AddSeconds(-708).ToUniversalTime()) -Root $root)
$live = @(Get-LiveRunProgress -Root $root)
Assert-Equal '... ship-pr: CI on PR #2103  +11m48s' (Format-RunProgressLine -Record $live[0]) `
    'Format-RunProgressLine: a record with no counts gets elapsed and deliberately no bar'

# A TOTAL OF ZERO IS NOT A FRACTION EITHER, and it is the shape a gate with nothing to run publishes.
[void](Write-RunProgress -Id 'empty' -Label 'test gate' -Current 0 -Total 0 -Root $root)
$empty = @(Get-LiveRunProgress -Root $root | Where-Object { $_.Id -eq 'empty' })
Assert-True ((Format-RunProgressLine -Record $empty[0]) -like '... test gate*') `
    'Format-RunProgressLine: a total of 0 draws no bar rather than dividing by it'

# --- 3. the writer is gone: the record is dropped AND deleted ----------------------------------
$root = New-Root 'deadwriter'
[void](Write-RunProgress -Id 'gate' -Label 'test gate' -Current 1 -Total 2 -Root $root)
$deadPid = Get-DeadProcessId
$path = Join-Path $root 'gate.json'
$rec = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
$rec.writerPid = $deadPid
$rec.writerStartTicks = 0
[System.IO.File]::WriteAllText($path, ($rec | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))

Assert-True (@(Get-LiveRunProgress -Root $root).Count -eq 0) `
    'Get-LiveRunProgress: a record whose writer has exited is not reported'
Assert-True (-not (Test-Path -LiteralPath $path)) `
    'Get-LiveRunProgress: and it is reaped, so the directory does not grow one file per killed run'

# --- 4. pid reuse: same pid, different process -------------------------------------------------
$root = New-Root 'pidreuse'
[void](Write-RunProgress -Id 'gate' -Label 'test gate' -Current 1 -Total 2 -Root $root)
$path = Join-Path $root 'gate.json'
$rec = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
# This pid IS alive -- it is this suite. The recorded start time is not this process's, which is
# exactly the state a pid handed on to somebody else produces.
$rec.writerStartTicks = 1
[System.IO.File]::WriteAllText($path, ($rec | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
Assert-True (@(Get-LiveRunProgress -Root $root).Count -eq 0) `
    'Test-RunProgressWriterAlive: a live pid with the wrong start time is a different process, not the run'

# --- 5. a quiet but healthy run is NOT dropped -------------------------------------------------
# The case #1941 is the standing argument for: a gate can sit for 141 minutes printing nothing. The
# record is hours old, its writer is this suite, and it must still be reported.
$root = New-Root 'quiet'
[void](Write-RunProgress -Id 'ship' -Label 'ship-pr: CI on PR #2103' -StartedUtc ((Get-Date).AddHours(-2).ToUniversalTime()) -Root $root)
$live = @(Get-LiveRunProgress -Root $root)
Assert-True ($live.Count -eq 1) 'Get-LiveRunProgress: an old record with a live writer is still live -- staleness is not the test'
Assert-True ((Format-RunProgressLine -Record $live[0]) -like '*+2h00m*') `
    'Format-ElapsedShort: past an hour the readout switches to hours and minutes'

# --- 6. the hard age cap still fires -----------------------------------------------------------
$root = New-Root 'agecap'
[void](Write-RunProgress -Id 'ancient' -Label 'test gate' -StartedUtc ((Get-Date).AddHours(-13).ToUniversalTime()) -Root $root)
Assert-True (@(Get-LiveRunProgress -Root $root).Count -eq 0) `
    'Get-LiveRunProgress: past the 12-hour cap a record is dropped even though its pid is alive'

# --- 7. an unparseable file is skipped, not deleted --------------------------------------------
$root = New-Root 'corrupt'
[System.IO.File]::WriteAllText((Join-Path $root 'junk.json'), 'not json at all', (New-Object System.Text.UTF8Encoding($false)))
Assert-True (@(Get-LiveRunProgress -Root $root).Count -eq 0) 'Get-LiveRunProgress: a file it cannot parse contributes no line'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'junk.json')) `
    'Get-LiveRunProgress: and it is left alone -- a reader that deletes what it cannot read destroys evidence'

# --- 8. the bar itself: clamping and width -----------------------------------------------------
Assert-Equal '[------------]' (Format-ProgressBar -Fraction 0) 'Format-ProgressBar: zero is empty'
Assert-Equal '[############]' (Format-ProgressBar -Fraction 1) 'Format-ProgressBar: one is full'
Assert-Equal '[############]' (Format-ProgressBar -Fraction 1.4) 'Format-ProgressBar: over one is clamped, not overrun'
Assert-Equal '[------------]' (Format-ProgressBar -Fraction -3) 'Format-ProgressBar: under zero is clamped too'
Assert-Equal '[###-]' (Format-ProgressBar -Fraction 0.75 -Width 4) 'Format-ProgressBar: the width is honoured'

# A CURRENT ABOVE THE TOTAL DOES NOT OVERRUN THE LINE either -- the same clamp, reached through the
# formatter rather than directly, because that is the path a producer's off-by-one actually takes.
$root = New-Root 'overrun'
[void](Write-RunProgress -Id 'over' -Label 'g' -Current 85 -Total 84 -Root $root)
$over = @(Get-LiveRunProgress -Root $root)
Assert-True ((Format-RunProgressLine -Record $over[0]) -like '`[############`] 85/84*') `
    'Format-RunProgressLine: a count past the total fills the bar and still reports the honest numbers'

# --- 9. the elapsed readout, including the invariant culture -----------------------------------
Assert-Equal '0s'     (Format-ElapsedShort -Seconds 0)     'Format-ElapsedShort: zero'
Assert-Equal '59s'    (Format-ElapsedShort -Seconds 59.9)  'Format-ElapsedShort: under a minute floors to seconds'
Assert-Equal '1m00s'  (Format-ElapsedShort -Seconds 60)    'Format-ElapsedShort: the minute boundary pads the seconds'
Assert-Equal '59m59s' (Format-ElapsedShort -Seconds 3599)  'Format-ElapsedShort: the last second before an hour'
Assert-Equal '1h00m'  (Format-ElapsedShort -Seconds 3600)  'Format-ElapsedShort: the hour boundary'

$culture = [System.Threading.Thread]::CurrentThread.CurrentCulture
try {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')
    Assert-Equal '2h00m' (Format-ElapsedShort -Seconds 7200) `
        'Format-ElapsedShort: the figure does not depend on the machine that printed it (#1159 reasoning)'
} finally {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
}

# --- 10. the label ceiling ----------------------------------------------------------------------
$root = New-Root 'longlabel'
[void](Write-RunProgress -Id 'long' -Label ('x' * 200) -Current 1 -Total 2 -Root $root)
$long = @(Get-LiveRunProgress -Root $root)
$line = Format-RunProgressLine -Record $long[0]
Assert-True ($line.Length -lt 80) 'Format-RunProgressLine: a producer label that runs away is trimmed, so the status line cannot wrap'
Assert-True ($line -like '*...*') 'Format-RunProgressLine: and the trim is visible rather than silent'

# --- 11. newest first ---------------------------------------------------------------------------
$root = New-Root 'order'
[void](Write-RunProgress -Id 'older' -Label 'ship-pr: CI' -StartedUtc ((Get-Date).AddMinutes(-20).ToUniversalTime()) -Root $root)
[void](Write-RunProgress -Id 'newer' -Label 'test gate' -Current 1 -Total 4 -StartedUtc ((Get-Date).AddMinutes(-1).ToUniversalTime()) -Root $root)
$ordered = @(Get-LiveRunProgress -Root $root)
Assert-Equal 'newer' $ordered[0].Id 'Get-LiveRunProgress: newest first -- the gate inside the ship, not the ship'

# --- 12. Complete-RunProgress -------------------------------------------------------------------
Assert-True (Complete-RunProgress -Id 'newer' -Root $root) 'Complete-RunProgress: reports success'
Assert-True (@(Get-LiveRunProgress -Root $root | Where-Object { $_.Id -eq 'newer' }).Count -eq 0) `
    'Complete-RunProgress: and the record is gone'
Assert-True (Complete-RunProgress -Id 'never-existed' -Root $root) `
    'Complete-RunProgress: clearing a record that is not there is success, not an error in the producer'

# --- 13. the statusline command -----------------------------------------------------------------
Write-Host '== show-progress ==' -ForegroundColor Cyan

function Invoke-StatusLine {
    param([string]$Root, [string]$Payload = '{}')
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $StatusLine -Root $Root -Payload $Payload 2>&1
    return @{ Lines = @($out | ForEach-Object { "$_" }); ExitCode = $LASTEXITCODE }
}

$root = New-Root 'statusline'
$empty = Invoke-StatusLine -Root $root
Assert-True ($empty.ExitCode -eq 0) 'show-progress: exits 0 with nothing running'
Assert-True ($empty.Lines.Count -ge 1) 'show-progress: still prints the context line when no run is publishing'
Assert-True (-not ($empty.Lines -join "`n").Contains('[#')) 'show-progress: and draws no bar for a run that does not exist'

[void](Write-RunProgress -Id 'gate' -Label 'test gate' -Current 42 -Total 84 -StartedUtc ((Get-Date).AddSeconds(-60).ToUniversalTime()) -Root $root)
$withBar = Invoke-StatusLine -Root $root
Assert-True ($withBar.ExitCode -eq 0) 'show-progress: exits 0 with a run publishing'
Assert-True ($withBar.Lines[0] -like '`[######*') 'show-progress: the bar is the FIRST line -- it is what the reader is looking for'

# A GARBAGE PAYLOAD MUST NOT COST THE BAR. The payload comes from the harness, so this is defence
# against a version that changes its shape rather than against a hostile input -- and the failure mode
# it prevents is the expensive one: the surface that reports every other run going dark itself.
$garbage = Invoke-StatusLine -Root $root -Payload 'not json'
Assert-True ($garbage.ExitCode -eq 0) 'show-progress: a payload it cannot parse still exits 0'
Assert-True ($garbage.Lines[0] -like '`[######*') 'show-progress: and the bar is still drawn'

# --- 14. the gate publishes through native-capture-lib ------------------------------------------
Write-Host '== gate wiring ==' -ForegroundColor Cyan

$gateLib = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
$gateProbe = @"
`$ErrorActionPreference = 'Stop'
. '$gateLib'
if (-not `$script:RunProgressAvailable) { Write-Output 'LIB-MISSING'; exit 0 }
Publish-GateProgress -Started 9 -Done 5 -Total 84 -StartedUtc ((Get-Date).ToUniversalTime()) -Depth 1
`$id = Get-RunProgressId -Name 'test-gate-d1'
`$path = Join-Path (Get-RunProgressRoot) ("`$id.json")
if (Test-Path -LiteralPath `$path) { Write-Output 'PUBLISHED' } else { Write-Output 'NOT-PUBLISHED' }
Clear-GateProgress -Depth 1
if (Test-Path -LiteralPath `$path) { Write-Output 'NOT-CLEARED' } else { Write-Output 'CLEARED' }
"@
# RUN IN A CHILD, AND AGAINST THE REAL ROOT. Publish-GateProgress takes no -Root -- it is called from
# inside the gate's hot loop and a parameter nothing shipped would pass is a parameter that only exists
# to be tested. So the child publishes one record under its OWN pid and clears it in the same breath,
# which is why this is the one case that touches the real directory: the file it creates is named for a
# process that ends here, so nothing outlives the probe.
$probeFile = Join-Path (New-Root 'gateprobe') 'probe.ps1'
[System.IO.File]::WriteAllText($probeFile, $gateProbe, (New-Object System.Text.UTF8Encoding($false)))
$probeOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $probeFile 2>&1 | ForEach-Object { "$_" })
Assert-True ($probeOut -contains 'PUBLISHED') 'native-capture-lib: Publish-GateProgress writes the gate record'
Assert-True ($probeOut -contains 'CLEARED')   'native-capture-lib: Clear-GateProgress removes it again'

# THE MIRRORS MUST NOT CARRY A DOT-SOURCE THEY CANNOT RESOLVE -- and they do not, because the guard is
# a Test-Path. Asserted here rather than left to the drift lint, which proves the files are identical
# and says nothing about whether the shared line is SAFE in the place it was copied to.
foreach ($mirror in @(
        'plugins\dkj-policy\scripts\lib\native-capture-lib.ps1',
        'plugins\dkj-subagents\dkj-subagents-shopify\scripts\lib\native-capture-lib.ps1')) {
    $full = Join-Path $RepoRoot $mirror
    Assert-True (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $full) 'run-progress-lib.ps1'))) `
        "mirror: $mirror has no run-progress-lib beside it, so the guarded dot-source is the path that runs there"
    $probe = Join-Path (New-Root 'mirror') 'probe.ps1'
    [System.IO.File]::WriteAllText($probe, ". '$full'`nWrite-Output `"AVAILABLE=`$(`$script:RunProgressAvailable)`"", (New-Object System.Text.UTF8Encoding($false)))
    $mirrorOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $probe 2>&1 | ForEach-Object { "$_" })
    Assert-True ($mirrorOut -contains 'AVAILABLE=False') `
        "mirror: $mirror dot-sources cleanly and simply has no bar"
}

# --- -WriterPid: publishing on behalf of another process (issue #2104) ----------------------------
# THE PARAMETER EXISTS BECAUSE LIVENESS IS THE WRITER'S PROCESS. A PostToolUse hook that wants to draw a
# bar for a backgrounded shell lives about 400 ms, so a record under its own pid is reaped by the next
# read -- the hook has to name the process whose life IS the run.
Write-Host ''
Write-Host '-- 13. -WriterPid --' -ForegroundColor Cyan
$root = New-Root 'writerpid'

# The current process stands in for "some other process": it is real, it is alive, and it is not the
# default only because the default is also this process -- so the assert reads the RECORD rather than
# the behaviour, which is what makes it honest.
[void](Write-RunProgress -Id 'default' -Label 'gate' -Root $root)
$defaultRec = (Get-Content (Join-Path $root 'default.json') -Raw | ConvertFrom-Json)
Assert-Equal $PID $defaultRec.writerPid 'omitted, the writer is still this process -- every existing producer is unaffected'

# A pid that is NOT this process, and is certainly not alive: the record must carry what it was told.
[void](Write-RunProgress -Id 'other' -Label 'bg' -WriterPid 999999 -Root $root)
$otherRec = (Get-Content (Join-Path $root 'other.json') -Raw | ConvertFrom-Json)
Assert-Equal 999999 $otherRec.writerPid '-WriterPid is what lands in the record, not $PID'
Assert-Equal 0 $otherRec.writerStartTicks '...and the ticks are read FROM THAT PID -- unreadable here, so 0, which degrades the reuse guard rather than the record'

# AND THE REAPER THEN DOES THE WHOLE JOB, which is the entire design: no completion event is needed
# because a record whose writer is gone is dropped on the next read.
Assert-Equal 0 (@(Get-LiveRunProgress -Root $root | Where-Object { $_.Id -eq 'other' })).Count `
    'a record naming a dead process is reaped on the next read -- why the hook needs no Complete-RunProgress'
Assert-Equal 1 (@(Get-LiveRunProgress -Root $root | Where-Object { $_.Id -eq 'default' })).Count `
    '...while the live one beside it is untouched, so the reap is per-record and not a sweep'

# The pair must be read from ONE pid. A record carrying this process's ticks under another pid would
# survive a reuse it should not, which is the one thing the two fields exist to prevent together.
Assert-True ($defaultRec.writerStartTicks -gt 0) 'the default record does carry real ticks (otherwise the assert above proves nothing)'
Assert-True ($otherRec.writerStartTicks -ne $defaultRec.writerStartTicks) `
    'and the foreign record did NOT borrow this process ticks -- the pid and the ticks come from the same place'

# --- teardown ------------------------------------------------------------------------------------
foreach ($tree in $script:trees) {
    try { Remove-Item -LiteralPath $tree -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
