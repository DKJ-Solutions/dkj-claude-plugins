<#
.SYNOPSIS
    Tests for scripts/lib/hook-check-lib.ps1 -- Invoke-CheckScript, the one place a hook RUNS its
    script in its OWN interpreter instead of spawning a second one, and Select-CheckMarkerLine, the
    one place a hook READS that script's output for verdict markers.

.DESCRIPTION
    WHY THIS SUITE EXISTS (issue #1641). The lib arrived with #1644 carrying no coverage of its own,
    and its header names THREE traps that "fail SILENTLY -- a wrong answer, not a crash". A silent
    wrong answer is precisely what a suite is for: every one of them leaves a hook reporting a clean
    check, so nothing downstream goes red to announce the drift.

    THE CALLERS MAKE IT WORTH MORE THAN ITS SIZE. Seven SessionStart hooks take the default path
    (a count that grows as this family does -- stranded-sweep-sessioncheck.ps1 joined it at #2438,
    after this count was last corrected) and cycle-autopark takes -MergeAllStreams, so one regression
    here is every one of them at once -- and hook output is the one class of defect that shows up as
    SILENCE in a session rather than as a failure anybody chases.

    WHAT #1641 ADDED, and why the pre-existing behaviour is pinned here too rather than only the new
    switches: that change restructured the capture pipeline for EVERY caller (an assignment became an
    append inside the pipeline, so -OutputTo could work), so a hook that never passes a new parameter
    still runs through rewritten code.

    THE FIXTURES ARE STUBS, deliberately -- no check script, no git, no repo. What is pinned is the
    lib's own contract; each real check has its own suite.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Lib      = Join-Path $RepoRoot 'scripts\lib\hook-check-lib.ps1'
# $PID in the fixture path: the gate is a throttled PARALLEL scheduler, so two runs at one fixed temp
# path tear down each other's tree mid-assert. Same reasoning as the hook suites.
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "hook-check-lib-tests-$PID-$([guid]::NewGuid().ToString('n'))"

$Ascii = New-Object System.Text.ASCIIEncoding
$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ("$Expected" -eq "$Actual") {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted: '$Expected'`n         got:    '$Actual'" -ForegroundColor Red
    }
}

function New-Check {
    <# A stand-in check script. $Body is written verbatim, so a case says exactly what it is about. #>
    param([Parameter(Mandatory = $true)][string]$Label, [Parameter(Mandatory = $true)][string]$Body)
    $path = Join-Path $Fixture "check-$Label.ps1"
    [System.IO.File]::WriteAllText($path, $Body, $Ascii)
    return $path
}

Write-Host "== hook-check-lib.ps1 ==" -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Lib -PathType Leaf) 'the lib exists at its registered path'
if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
New-Item -ItemType Directory -Force -Path $Fixture | Out-Null

. $Lib

try {
    # --- (a) TRAP 2: Write-Host IS CAPTURED -------------------------------------------------------
    # In a child process Write-Host lands on stdout and the caller captures it. In-process it goes to
    # the information stream, so a plain capture gets NOTHING and every line leaks unfiltered into the
    # session -- which for these hooks means forwarding everything they exist to hold back.
    Write-Host "hook-check-lib -- Write-Host is captured, not leaked (trap 2)" -ForegroundColor Cyan
    $a = Invoke-CheckScript -Path (New-Check -Label 'a' -Body "Write-Host 'captured line'`nexit 0`n")
    Assert-Equal 1 @($a.Output).Count 'write-host: exactly one line captured'
    Assert-Equal 'captured line' @($a.Output)[0] 'write-host: and it is the line the check wrote'

    # --- (b) TRAP 3: ONE Write-Host CAN CARRY SEVERAL LINES ---------------------------------------
    # A child's stdout arrives already split. An InformationRecord stringifies to ONE element holding
    # the newlines, and the hooks then indent the block once and line-match it as a unit.
    Write-Host "hook-check-lib -- a multi-line Write-Host arrives as several lines (trap 3)" -ForegroundColor Cyan
    $b = Invoke-CheckScript -Path (New-Check -Label 'b' -Body "Write-Host `"one``ntwo``nthree`"`nexit 0`n")
    Assert-Equal 3 @($b.Output).Count 'split: three lines, not one record holding two newlines'
    Assert-Equal 'three' @($b.Output)[2] 'split: and the last of them is intact'

    # --- (c) TRAP 1: A HASHTABLE SPLATS BY NAME ---------------------------------------------------
    # An ARRAY splats positionally in-process, so '-Skip' binds to the first positional parameter and
    # the switch stays false. Nothing errors; the check simply answers a different question.
    Write-Host "hook-check-lib -- arguments bind by name, not by position (trap 1)" -ForegroundColor Cyan
    $c = Invoke-CheckScript -Path (New-Check -Label 'c' -Body @"
param([switch]`$Skip, [string]`$Path = '')
Write-Host "Skip=`$(`$Skip.IsPresent) Path=[`$Path]"
exit 0
"@) -Arguments @{ Skip = $true; Path = 'C:\x' }
    Assert-Equal 'Skip=True Path=[C:\x]' @($c.Output)[0] 'splat: both parameters bound to themselves'

    # --- (d) exit IN THE CHECK DOES NOT TAKE THE CALLER WITH IT -----------------------------------
    # The premise #1625 reasoned from, and the one this whole lib depends on being false for a .ps1
    # FILE invoked with '&'. True for dot-sourcing and for a script BLOCK; not for this.
    Write-Host "hook-check-lib -- the check's exit ends the check, and its code comes back" -ForegroundColor Cyan
    $d = Invoke-CheckScript -Path (New-Check -Label 'd' -Body "Write-Host 'before'`nexit 4`nWrite-Host 'AFTER-EXIT'`n")
    Assert-Equal 4 $d.ExitCode 'exit: the code reaches the caller'
    Assert-Equal 'before' @($d.Output)[0] 'exit: what came before it was captured'
    Assert-True (-not (@($d.Output) -contains 'AFTER-EXIT')) 'exit: and the line after it never ran'

    # --- (e) $LASTEXITCODE IS RESET, NOT INHERITED ------------------------------------------------
    # A check that returns without reaching an 'exit' would otherwise report whatever the previous
    # native call left behind -- a clean check announcing its predecessor's failure.
    Write-Host "hook-check-lib -- a check with no exit statement reads as 0, not as the last code" -ForegroundColor Cyan
    & cmd /c 'exit 9' | Out-Null
    $e = Invoke-CheckScript -Path (New-Check -Label 'e' -Body "Write-Host 'no exit here'`n")
    Assert-Equal 0 $e.ExitCode 'reset: 0, not the 9 left by the previous native call'

    # --- (f) THE DEFAULT DOES NOT MERGE stderr ----------------------------------------------------
    # Deliberate for the six session checks: a merged error line would sit in front of their [ERROR]
    # filter as if the check had reported it.
    Write-Host "hook-check-lib -- by default an error line is NOT captured" -ForegroundColor Cyan
    $f = Invoke-CheckScript -Path (New-Check -Label 'f' -Body @"
Write-Host 'a host line'
Write-Error 'an error line' -ErrorAction Continue
exit 0
"@) 2>$null
    Assert-True (-not (@($f.Output) -match 'an error line')) 'default: the error line is not in Output'
    Assert-True (@($f.Output) -contains 'a host line')       'default: and the host line still is'

    # --- (g) -MergeAllStreams CAPTURES EVERYTHING, IN ORDER (#1641) -------------------------------
    # For a caller that RELAYS its callee rather than filtering it -- cycle-autopark, whose child was
    # already captured with 2>&1 on purpose (#1600).
    Write-Host "hook-check-lib -- -MergeAllStreams captures every stream, in order (#1641)" -ForegroundColor Cyan
    $g = Invoke-CheckScript -Path (New-Check -Label 'g' -Body @"
Write-Host '1 host'
Write-Output '2 output'
Write-Error '3 error' -ErrorAction Continue
Write-Warning '4 warning'
Write-Host '5 host again'
exit 0
"@) -MergeAllStreams
    $flat = (@($g.Output) -join '|')
    Assert-True ($flat -match '1 host.*2 output.*3 error.*4 warning.*5 host again') "merge: all five, in the order written -- got '$flat'"

    # --- (h) -OutputTo KEEPS WHAT A THROWING CHECK MANAGED TO SAY (#1641) -------------------------
    # A child process had already PRINTED its early lines before it died. In-process a throw leaves no
    # return value at all, so an ASSIGNMENT loses them -- measured at 0 lines recovered. Appending
    # inside the pipeline keeps them, and -OutputTo is how a relaying caller reads them from its catch.
    # The exception must still PROPAGATE: the six session hooks report a crashed check as skipped.
    Write-Host "hook-check-lib -- a throwing check still hands back what it wrote first (#1641)" -ForegroundColor Cyan
    $partial = New-Object System.Collections.Generic.List[string]
    $threw = $false
    try {
        $null = Invoke-CheckScript -Path (New-Check -Label 'h' -Body "Write-Host 'said first'`nWrite-Host 'said second'`nthrow 'fell over'`n") `
                                   -MergeAllStreams -OutputTo $partial
    } catch { $threw = $true }
    Assert-True $threw 'outputto: the terminating error still propagates to the caller'
    Assert-True ($partial.Count -ge 2) "outputto: the lines written before the throw survived -- got $($partial.Count)"
    Assert-Equal 'said first' $partial[0] 'outputto: and the first of them is intact'

    # --- (i) OMITTING -OutputTo CHANGES NOTHING ---------------------------------------------------
    # The parameter is additive: Output holds the same lines whether or not a list was handed in. Pinned
    # because six callers omit it, and a list that only filled when supplied would be a silent halving
    # of every one of their reports.
    Write-Host "hook-check-lib -- omitting -OutputTo leaves Output exactly as it was" -ForegroundColor Cyan
    $chk = New-Check -Label 'i' -Body "Write-Host 'same either way'`nexit 0`n"
    $without = Invoke-CheckScript -Path $chk
    $sink    = New-Object System.Collections.Generic.List[string]
    $with    = Invoke-CheckScript -Path $chk -OutputTo $sink
    Assert-Equal (@($without.Output) -join '|') (@($with.Output) -join '|') 'outputto: Output is identical with and without the sink'
    Assert-Equal (@($without.Output) -join '|') ($sink -join '|')           'outputto: and the sink holds the same lines'

    # --- (j) Select-CheckMarkerLine: A MARKER COUNTS WHERE THE CHECK WROTE IT (issue #2142) --------
    # Eight hooks across two plugins decide what reaches a session start with this one function, and
    # every failure of it is silent in the same two directions: a forged marker that gets counted, or
    # a real finding that stops being. Neither goes red anywhere else.
    Write-Host "hook-check-lib -- Select-CheckMarkerLine counts a marker only where the check wrote it" -ForegroundColor Cyan

    $sample = @(
        '[ERROR] the check said so, at column 0',
        '  [WARN]  and this one behind its indentation',
        "  [WARN]  not measured: 'a[ERROR]b.md'",
        '        a continuation line with no marker at all',
        '[OK]    inside the budget'
    )

    Assert-Equal 1 @(Select-CheckMarkerLine -Output $sample -Marker '[ERROR]').Count 'only the line that OPENS with [ERROR] counts'
    Assert-Equal '[ERROR] the check said so, at column 0' (@(Select-CheckMarkerLine -Output $sample -Marker '[ERROR]')[0]) 'and it is the one the check wrote, not the one reporting a value'
    Assert-Equal 2 @(Select-CheckMarkerLine -Output $sample -Marker '[WARN]').Count 'indentation is the check''s own layout, so an indented marker still counts'
    Assert-Equal 3 @(Select-CheckMarkerLine -Output $sample -Marker '[WARN]', '[OK]').Count 'several markers: a line matches when it carries ANY of them'
    Assert-Equal 0 @(Select-CheckMarkerLine -Output $sample -Marker '[error]').Count 'the match is case-exact, so the word "error" in prose never counts'
    Assert-Equal 0 @(Select-CheckMarkerLine -Output $sample -Marker '[MISSING]').Count 'a marker no line carries selects nothing'

    # THE ESCAPE, pinned because getting it wrong fails in the loudest possible direction and still
    # LOOKS right: '[ERROR]' read as a regex is a character class matching ONE of E/R/O, so an
    # unescaped marker would select every line beginning with any of those letters.
    Assert-Equal 0 @(Select-CheckMarkerLine -Output @('Everything is fine.', 'Ran clean.') -Marker '[ERROR]').Count `
        'the marker is a LITERAL -- it is not read as a regex character class'

    # The empty cases, because a hook hands this whatever Invoke-CheckScript returned and a check that
    # printed nothing is an ordinary state rather than an error.
    Assert-Equal 0 @(Select-CheckMarkerLine -Output @() -Marker '[ERROR]').Count 'no output selects nothing'
    Assert-Equal 0 @(Select-CheckMarkerLine -Output $null -Marker '[ERROR]').Count 'null output selects nothing rather than throwing'

    # It returns an ARRAY even for one hit: every caller does '@(...).Count' on the result, and a bare
    # string would report its LENGTH instead.
    $one = @(Select-CheckMarkerLine -Output @('[ERROR] just the one') -Marker '[ERROR]')
    Assert-Equal 1 $one.Count 'a single hit comes back as a one-element array, not as a string'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
