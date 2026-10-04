<#
.SYNOPSIS
    Regression tests for the shared BWJ test harness that bwj-development ships --
    plugins/dkj-policy/bwj-development/scripts/tests/test-lib.ps1 (issue #1881).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bwj-test-lib.tests.ps1

    WHY A SUITE HERE FOR A FILE NOBODY IN THIS REPO USES. It is exactly the state #1881 was filed
    about. The two BWJ stores each carried their own copy, each ahead of the other, and nothing
    compared them until the sibling check did -- so the converged copy is a merge of two trees whose
    reasoning lives in comments and whose behaviour lived only in the suites that used it. Shipping it
    without a suite in the repo that ships it would put it back in exactly that position: a mechanism
    with no owner watching it, one edit away from drifting again, this time inside the plugin.

    IT RUNS THE LIB IN A CHILD PROCESS, ALWAYS, and that is not a style choice. The lib sets
    $script:Pass / $script:Fail and defines Assert-True in the scope of whoever dot-sources it, and
    PowerShell variable and function names are case-insensitive -- so dot-sourcing it HERE would silently
    replace this suite's own counters and its own Assert-True with the ones under test. The suite would
    then be asserting with the code it is trying to assert about, and a broken lib could report itself
    green.

    WHAT IT HOLDS, and each of the three is a way the convergence can be undone:

      1. THE SUPERSET. Both stores' contributions are present. A later edit that drops one side is the
         divergence coming back inside the plugin, which no consumer-to-consumer check would ever see.
      2. THE BEHAVIOUR of the two mechanisms that were born from a false GREEN in the very gate these
         suites are read by -- an ErrorRecord with an empty message, and the counted terminating error.
      3. THE LANGUAGE. The file is English; one of the two source copies was not, and a merge that
         reaches for the other copy's line is how half of it would come back.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Lib      = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\scripts\tests\test-lib.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-test-lib-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

# Run a probe against the lib in a child process and hand back its output and exit code. The probe
# dot-sources the lib the way a store suite does, so the contract under test is the real one.
function Invoke-Probe {
    param([Parameter(Mandatory = $true)][string]$Body)
    if (-not (Test-Path -LiteralPath $Fixture)) { New-Item -ItemType Directory -Path $Fixture -Force | Out-Null }
    $path = Join-Path $Fixture "probe-$([guid]::NewGuid().ToString('n')).ps1"
    $script = ". `"$Lib`"" + [Environment]::NewLine + $Body
    [System.IO.File]::WriteAllText($path, $script, (New-Object System.Text.UTF8Encoding($false)))
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    $code = $LASTEXITCODE
    $text = (@($out | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { [string]$_.Exception.Message } else { [string]$_ }
    }) -join "`n")
    return [pscustomobject]@{ Text = $text; ExitCode = $code }
}

Write-Host ''
Write-Host 'The shared BWJ test harness -- it is where the plugin ships it (#1881)' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $Lib) 'bwj-development ships scripts/tests/test-lib.ps1'
$body = [System.IO.File]::ReadAllText($Lib)

$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Lib, [ref]$null, [ref]$errors)
Assert-True (@($errors).Count -eq 0) 'it parses without error'

# NOT named *.tests.ps1, because the shared test gate runs everything matching that pattern and a lib
# is not a suite: it would report zero asserts and pass vacuously.
Assert-True ((Split-Path -Leaf $Lib) -eq 'test-lib.ps1') 'and it is not named like a suite, so no gate runs it as one'

Write-Host ''
Write-Host 'The superset -- both stores contributions survive the merge (#1881)' -ForegroundColor Cyan

# FROM ONE STORE: the two mechanisms born from a false GREEN in the gate these suites are read by.
Assert-True ($body -match '(?m)^function ConvertTo-CapturedText') 'ConvertTo-CapturedText is here -- the console-width and ErrorRecord half'
Assert-True ($body -match '(?m)^function Add-SuiteFault') 'Add-SuiteFault is here -- the counted terminating error'
# FROM THE OTHER: the three legs of a plugin that is loaded rather than merely present.
Assert-True ($body -match '(?m)^function Assert-PluginLoadedForProject') 'Assert-PluginLoadedForProject is here -- the three legs'
Assert-True ($body -match 'LEG 1' -and $body -match 'LEG 2' -and $body -match 'LEG 3') 'with all three legs, which fail independently and are therefore three asserts'
# THE COMMON BASE both copies already agreed on.
foreach ($fn in @('Write-SuiteHeader', 'Write-Case', 'Assert-Equal', 'Assert-True', 'Assert-False', 'Assert-Match', 'Assert-NoMatch', 'Complete-Suite')) {
    Assert-True ($body -match "(?m)^function $fn") "$fn survived the merge"
}

# THE REASONING IS THE PAYLOAD. Each of these measurements cost a real failure in a store repo, and a
# tidying pass that keeps the code and drops the comment is how the next merge loses the argument.
Assert-True ($body -match 'RemoteException') 'the empty-stderr-line measurement is written down beside the code it explains'
Assert-True ($body -match '79-column') 'and so is the console-width one'
Assert-True ($body -match 'scope project') 'the plugin-registration repair still names the flag that is the whole point of it'

Write-Host ''
Write-Host 'The language -- English, which one of the two copies was not (#1881)' -ForegroundColor Cyan

# The lint gate holds the whole script layer to ASCII; it has no opinion about which language the words
# are in. One source copy was Dutch, so a merge reaching for its line is the live way this comes back.
foreach ($dutch in @('verwacht', 'gekregen', 'geslaagd', 'gefaald', 'bestand', 'draai dit')) {
    Assert-True ($body -notmatch $dutch) "no '$dutch' -- the converged copy is English throughout"
}

Write-Host ''
Write-Host 'The behaviour, run in a child process (#1881)' -ForegroundColor Cyan

# A PASSING AND A FAILING ASSERT, and the exit-code contract the shared test gate reads.
$green = Invoke-Probe -Body 'Assert-True $true "a true thing" ; Complete-Suite'
Assert-True ($green.ExitCode -eq 0) 'a suite with only passing asserts exits 0'
Assert-True ($green.Text -match 'OK: all 1 asserts passed') 'and says so with its own count'

$red = Invoke-Probe -Body 'Assert-True $false "a false thing" ; Complete-Suite'
Assert-True ($red.ExitCode -eq 1) 'a suite with a failing assert exits 1 -- the contract the gate reads'
Assert-True ($red.Text -match 'FAILS: 1 failed') 'and names the count'
Assert-True ($red.Text -match 'expected true, got false') 'a failing Assert-True says what it expected'

$eq = Invoke-Probe -Body 'Assert-Equal "a" "b" -Name "two strings" ; Complete-Suite'
Assert-True ($eq.Text -match "expected: 'a'" -and $eq.Text -match "got:      'b'") 'a failing Assert-Equal prints both values'

$false_ = Invoke-Probe -Body 'Assert-False $false "not true" ; Complete-Suite'
Assert-True ($false_.ExitCode -eq 0) 'Assert-False passes on a false condition'

# Assert-Match is a SUBSTRING assert, not a regex -- so a needle full of regex metacharacters (a path,
# a quoted flag) is compared literally rather than blowing up or matching the wrong thing.
$match = Invoke-Probe -Body 'Assert-Match -Text "refused: scripts/task/sync-main.ps1 (live)" -Needle "scripts/task/sync-main.ps1 (live)" -Name "a path with brackets" ; Complete-Suite'
Assert-True ($match.ExitCode -eq 0) 'Assert-Match compares as a substring, so regex metacharacters in the needle are literal'

$noMatch = Invoke-Probe -Body 'Assert-NoMatch -Text "all clear" -Needle "refused" -Name "absent" ; Complete-Suite'
Assert-True ($noMatch.ExitCode -eq 0) 'Assert-NoMatch passes when the needle is absent'

Write-Host ''
Write-Host 'ConvertTo-CapturedText -- the console and the test source stay out of it (#1881)' -ForegroundColor Cyan

# THE MEASURED CASE: a blank stderr line arrives as an ErrorRecord whose message is empty, and
# ToString() on that falls through to the exception TYPE NAME. Every empty line in a child's message
# came back as 'System.Management.Automation.RemoteException'.
$blank = Invoke-Probe -Body @'
$rec = New-Object System.Management.Automation.ErrorRecord (New-Object System.Management.Automation.RemoteException ''), 'x', 'NotSpecified', $null
$text = ConvertTo-CapturedText @('first', $rec, 'last')
Write-Host "RESULT[$text]"
'@
Assert-True ($blank.Text -notmatch 'RemoteException') 'an ErrorRecord with an empty message does not come back as its exception type name'
Assert-True ($blank.Text -match 'RESULT\[first') 'the plain lines are kept'

$empty = Invoke-Probe -Body 'Write-Host "RESULT[$(ConvertTo-CapturedText $null)]"'
Assert-True ($empty.Text -match 'RESULT\[\]') 'a null capture is the empty string, not a crash'

Write-Host ''
Write-Host 'Add-SuiteFault -- a terminating error is COUNTED, not scrolled past (#1881)' -ForegroundColor Cyan

# The whole point: without the trap line the suite resumes at the next statement, Complete-Suite sees
# no failures, and a case that stopped part-way reports OK. This is the false green the gate reads.
$trapped = Invoke-Probe -Body @'
trap { Add-SuiteFault $_ ; continue }
Assert-True $true "a passing case"
throw "a case that stops part-way"
Complete-Suite
'@
Assert-True ($trapped.ExitCode -eq 1) 'a suite whose case throws goes RED rather than printing a false green'
Assert-True ($trapped.Text -match 'unhandled terminating error') 'and says what happened'
Assert-True ($trapped.Text -match 'a case that stops part-way') 'naming the error it caught'

if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "bwj-test-lib.tests: $($script:pass) passed, $($script:fail) FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "bwj-test-lib.tests: $($script:pass) passed, 0 failed" -ForegroundColor Green
exit 0
