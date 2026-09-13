<#
.SYNOPSIS
    Run ONE test suite repeatedly under the real parallel gate's contention, to reproduce a defect that
    is only visible when the pool is busy. Issue #1944.

.DESCRIPTION
    WHY IT EXISTS. This repo has a whole CLASS of defect that is invisible outside the gate's pool:

      - #1915 -- new-branch.tests.ps1, red at 16 lanes, green standalone (a git probe).
      - #1939 -- native-capture.tests.ps1, red at 16 lanes, green standalone (an unbounded
        powershell.exe bring-up measured against a fixed 2s bound).

    Different files, different causes, three days apart, and an IDENTICAL discovery path: the gate
    refused a push on a branch that touched neither suite, minutes after the same tree had passed the
    identical gate. The loop for anyone repairing one of these was:

      1. change the suite,
      2. run it standalone -- which is green BY DEFINITION OF THE BUG, and therefore proves nothing,
      3. run the whole gate, ~19 minutes, to learn whether the repair held.

    AND A SYNTHETIC LOAD IS NOT A SHORTCUT -- THAT WAS MEASURED. Sixteen concurrent PowerShell processes
    spawning short-lived PowerShell children reached 0.47-0.95s launch-to-print; the real gate, by
    native-capture.tests.ps1's own calibration, reaches 3.25s. The imitation falls ~3.4x short of the
    thing it imitates, and the suite under repair stayed green under it. So the load here is REAL
    sibling suites in the REAL pool -- same console, same spawn model, same scheduler.

    WHAT IT ACTUALLY DOES. Nothing of its own: it is a front door onto Invoke-TestSuiteGate's -FocusSuite
    mode. The composition (how many load suites, in what order, with what capture stems) is
    Get-TestSuiteFocusOrder's, and the verdict is the gate's. This script exists because that mode is
    otherwise reachable only by dot-sourcing a lib and splatting a hashtable, and a tool nobody can type
    is one nobody uses -- which is the complaint #1944 was actually filed about.

    WHAT IT IS NOT. It is NOT a gate and nothing may treat it as one: it runs one suite N times and every
    other process in the run is there to contend, not to be judged. A green result here is evidence about
    ONE suite under ONE draw count, which is why the gate prints that caveat under its own focus table
    rather than leaving it to be inferred.

    READ THE RESULT HONESTLY. A load-triggered defect is a probability, not a switch: #1939 was seen
    twice in three days across a pool of ~90 suites. Passing five repeats is weak evidence and passing
    thirty is better evidence; neither is proof. Raise -Repeat and -MaxParallel before concluding that a
    repair held, and say which numbers you ran when you write the result down.

.PARAMETER Suite
    The suite to put under contention. The file name, the base name, or the name without '.tests.ps1' --
    all three are accepted, because all three are what a person has in their hand at that moment.

.PARAMETER Repeat
    How many times it runs under the load. Default 5.

.PARAMETER MaxParallel
    Lanes, i.e. how much contention. Default 0 = the gate's own machine default (cores - 2). Pass the
    number the failure was SEEN at: the two instances above were both at 16, and #1941's wedge was at 30.

.PARAMETER RepoRoot
    Explicit repo root, for a run that starts outside the checkout.

.EXAMPLE
    ./scripts/maintenance/reproduce-suite-contention.ps1 -Suite native-capture -Repeat 10 -MaxParallel 16

.NOTES
    Pure ASCII, English -- repo convention for .ps1 (.claude/rules/language-layers.md).
#>
param(
    [Parameter(Mandatory)][string]$Suite,
    [int]$Repeat = 5,
    [int]$MaxParallel = 0,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# Invoke-NativeCapture rather than a bare `git ... 2>&1`: under 'Stop' a native command's redirected
# stderr arrives as an ErrorRecord and kills the script on a line git writes progress to. Same reason
# every other script in this tree dot-sources this lib first -- asserted by shared-scripts.tests.ps1.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

if (-not $RepoRoot) {
    $top = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', '--show-toplevel') -DiscardStderr
    if ($top.ExitCode -ne 0) { throw 'Not in a git repository - pass -RepoRoot.' }
    $RepoRoot = (@($top.Output) | Select-Object -First 1)
    if (-not $RepoRoot) { throw 'Not in a git repository - pass -RepoRoot.' }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$testsDir = Join-Path $RepoRoot 'scripts\tests'
if (-not (Test-Path -LiteralPath $testsDir)) { throw "No test directory at $testsDir." }

# FROM THE REPO ROOT, because the pool hands every child the CALLER's location as its working directory
# and several suites assert against the tree they are standing in (roster-sync.tests.ps1 is the named
# one in Invoke-TestSuiteGate's own docstring). A reproduction run that started somewhere else would
# produce reds that have nothing to do with contention.
Push-Location -LiteralPath $RepoRoot
try {
    Write-Host ''
    Write-Host "reproduce-suite-contention: $Suite x $Repeat under the real pool (issue #1944)" -ForegroundColor Cyan
    Write-Host "  This is a REPRODUCTION, not a gate. Only $Suite is being judged." -ForegroundColor DarkGray
    Write-Host ''

    $ok = Invoke-TestSuiteGate -TestsDir $testsDir -Context "a contention reproduction of $Suite" `
                               -MaxParallel $MaxParallel -FocusSuite $Suite -FocusRepeat $Repeat

    Write-Host ''
    if ($ok) {
        # THE GREEN MESSAGE IS DELIBERATELY NOT CONGRATULATORY. The failure mode this script is most
        # likely to cause is somebody reading one clean run as "fixed" and closing the issue.
        Write-Host "[OK] $Suite passed $Repeat repeat(s) under load. NOT PROOF: a load-triggered defect is a probability, so raise -Repeat and -MaxParallel before calling it closed." -ForegroundColor Green
    } else {
        Write-Host "[REPRODUCED] $Suite did not pass every repeat under load -- the focus table above says which draws failed, and the kept capture directory holds their output." -ForegroundColor Red
    }
} finally {
    Pop-Location
}

# The exit code mirrors the verdict, so this can be driven from a loop while bisecting a repair.
if ($ok) { exit 0 } else { exit 1 }
