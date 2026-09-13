<#
.SYNOPSIS
    Tests for scripts/lib/fixture-script-lib.ps1 -- the fixture load-failure verdict (issue #1934).

.DESCRIPTION
    Run:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fixture-script-lib.tests.ps1

    THE CENTRAL CLAIM UNDER TEST is the one that makes the helper safe to wire into a shared invocation
    helper: it speaks on a LOAD FAILURE and stays silent on an ordinary refusal, even though both exit
    non-zero. Get that wrong in either direction and the repair is worse than the defect -- silent, it
    restores #1934; loud on a refusal, it shouts on the dozens of cases in this directory that assert a
    non-zero exit on purpose.

    THE END-TO-END CASE IS A REAL CHILD, NOT A CANNED STRING. The signature this lib keys on is produced
    by PowerShell, not by this repo, so a test that feeds it a hand-written error message proves only
    that the regex matches the test's own fixture. So the load-failure case builds a script that
    dot-sources a lib that is not there, runs it, and hands the REAL captured output over.

    Dependency-free (no Pester), same style as the rest of the suite.
    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\fixture-script-lib.ps1')

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

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) "fixture-script-lib-test-$PID-$([guid]::NewGuid().ToString('n'))"

try {
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    Write-Host "== fixture-script-lib.tests: a real child that dies on load ==" -ForegroundColor Cyan

    # A SCRIPT THAT DOT-SOURCES A LIB THAT IS NOT THERE -- the #1917 shape exactly: unguarded, resolved
    # off $PSScriptRoot, and reached before the script writes anything.
    $actingDir = Join-Path $Fixture 'scripts\task'
    New-Item -ItemType Directory -Path $actingDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\lib') -Force | Out-Null
    $acting = Join-Path $actingDir 'pretend-acting.ps1'
    Set-Content -LiteralPath $acting -Encoding ascii -Value @'
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\absent-helper-lib.ps1')
Write-Host 'REACHED-THE-BODY'
'@
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $loadOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $acting 2>&1
        $loadCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }

    Assert-True ($loadCode -ne 0) 'the child really died (non-zero exit), so the case is the one under test'
    Assert-True ((($loadOut | Out-String)) -notmatch 'REACHED-THE-BODY') 'the child really died during LOAD, before its body ran'

    $found = Get-FixtureScriptLoadFailure -Output $loadOut -Script $acting
    Assert-True ($null -ne $found) 'a real load failure is recognised'
    Assert-True ($found.MissingLeaves -contains 'absent-helper-lib.ps1') 'the absent lib is named, which is the whole of #1934'
    Assert-True ($found.MissingLeaves -notcontains 'pretend-acting.ps1') 'the script that CONTAINS the dot-source is not reported as the missing dependency'

    # AND IT NAMES NOTHING THAT IS NOT A FILE. Two artefacts of how PowerShell renders an ErrorRecord
    # used to reach this list: a console WRAP splitting the path ('preten' / 'd-acting.ps1') and the
    # CategoryInfo ELLIPSIS. Both matched the leaf pattern and neither exists. This is #1936's lesson
    # one layer over -- a headline naming a file nobody can find costs the reader what the missing
    # headline did.
    #
    # THESE ARE INVARIANTS, NOT AN EXACT COUNT, because every artefact above is a property of the HOST:
    # how wide its console is, and how long the temp path under its home directory happens to be. An
    # exact-count assert here passed on the machine that wrote it and failed on the CI runner, whose
    # longer user name moved PowerShell's truncation point. What must hold everywhere is that nothing
    # reported is a fragment; the exact counts are asserted below against CANNED text this suite owns.
    Assert-True ($found.MissingLeaves -contains 'absent-helper-lib.ps1') 'the real capture names the absent lib on any host'
    Assert-True (-not (@($found.MissingLeaves) | Where-Object { $_ -like '*...*' })) 'no reported leaf carries an ellipsis -- a real filename never does'
    Assert-True (-not (@($found.MissingLeaves) | Where-Object { $_ -eq 'pretend-acting.ps1' })) 'the containing script is never reported as the missing dependency'

    # THE COUNTER AND THE PRINTED VERDICT.
    Assert-Equal 0 (Get-FixtureScriptLoadFailureCount) 'nothing counted before the verdict is asked for'
    Assert-FixtureScriptLoaded -Code $loadCode -Script $acting -Output $loadOut
    Assert-Equal 1 (Get-FixtureScriptLoadFailureCount) 'a load failure is counted'

    Write-Host "fixture-script-lib.tests: SILENT on everything that is not a load failure" -ForegroundColor Cyan

    # AN ORDINARY REFUSAL -- non-zero, deliberate, and the behaviour under test in dozens of cases here.
    # This is the assertion that makes the helper safe to wire into a shared invocation helper.
    $refuser = Join-Path $actingDir 'pretend-refuser.ps1'
    Set-Content -LiteralPath $refuser -Encoding ascii -Value @'
Write-Host 'REFUSED: this script declines, on purpose.'
exit 1
'@
    try {
        $ErrorActionPreference = 'Continue'
        $refOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $refuser 2>&1
        $refCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEap }

    Assert-Equal 1 $refCode 'the refusal really exits non-zero -- otherwise this case proves nothing'
    Assert-True ($null -eq (Get-FixtureScriptLoadFailure -Output $refOut -Script $refuser)) 'a deliberate refusal is NOT a load failure'
    Assert-FixtureScriptLoaded -Code $refCode -Script $refuser -Output $refOut
    Assert-Equal 1 (Get-FixtureScriptLoadFailureCount) 'a refusal does not move the counter'

    # A CLEAN RUN.
    Assert-FixtureScriptLoaded -Code 0 -Script $acting -Output $loadOut
    Assert-Equal 1 (Get-FixtureScriptLoadFailureCount) 'exit 0 is never judged, even carrying the signature'

    # NO OUTPUT TO READ -- a caller that discarded it. Nothing to say, and nothing to invent.
    Assert-FixtureScriptLoaded -Code 1 -Script $acting -Output $null
    Assert-Equal 1 (Get-FixtureScriptLoadFailureCount) 'a caller with no captured output is not guessed at'

    # AN ABSENT EXIT CODE STILL GETS READ (#1920's Start-Process shape). Typed [int] this would arrive as
    # 0 and fall out of the function silently -- which is why -Code is untyped.
    Assert-FixtureScriptLoaded -Code $null -Script $acting -Output $loadOut
    Assert-Equal 2 (Get-FixtureScriptLoadFailureCount) 'a null exit code does not silence the signature'

    Write-Host "fixture-script-lib.tests: the summary" -ForegroundColor Cyan
    Assert-True (Write-FixtureScriptSummary -Subject 'pretend-acting.ps1') 'the summary reports true once something died on load'

    # THE LOCALE POINT, stated as an assert rather than only in the docstring: the matcher must key on the
    # error ID and not on the English sentence, because #1934's own measured symptom is Dutch.
    $dutchish = @"
. : De term '..\lib\absent-helper-lib.ps1' wordt niet herkend as de naam van een cmdlet.
    + CategoryInfo          : ObjectNotFound: (..\lib\absent-helper-lib.ps1:String) []
    + FullyQualifiedErrorId : CommandNotFoundException
"@
    $dutchFound = Get-FixtureScriptLoadFailure -Output $dutchish -Script 'pretend-acting.ps1'
    Assert-True ($null -ne $dutchFound) 'a localized message is still recognised -- the id is what is matched'
    Assert-True ($dutchFound.MissingLeaves -contains 'absent-helper-lib.ps1') 'and the absent lib is still named from a localized message'

    # The control: the same text WITHOUT the id is not a load failure, so the match is really the id and
    # not the '.ps1' leaf happening to appear.
    $noId = "something went wrong near ..\lib\absent-helper-lib.ps1 and that is all"
    Assert-True ($null -eq (Get-FixtureScriptLoadFailure -Output $noId -Script 'pretend-acting.ps1')) 'a .ps1 name alone is not a load failure -- the id is the signature'

    Write-Host "fixture-script-lib.tests: the wrap guard, on a CONTROLLED input" -ForegroundColor Cyan

    # THE WRAP IS ASSERTED AGAINST A CANNED STRING, not left to whether a real host happens to wrap.
    # The real child DOES wrap on a long temp path, which is how the artefact was found -- but a host
    # whose console is wide enough would not, and then the guard would be proven by nothing while still
    # looking green. Same reasoning as the canned localized message above.
    $wrapped = @"
. : The term 'C:\Users\x\AppData\Local\Temp\fixture-test\scripts\task\preten
d-acting.ps1' is not recognized as the name of a cmdlet, function, script file, or operable program.
    + FullyQualifiedErrorId : CommandNotFoundException
"@
    $wrapFound = Get-FixtureScriptLoadFailure -Output $wrapped -Script 'pretend-acting.ps1'
    Assert-True ($null -ne $wrapFound) 'a wrapped message is still recognised as the class'
    Assert-True ($wrapFound.MissingLeaves -notcontains 'd-acting.ps1') 'the wrap orphan is NOT reported as a file -- it sits at a line start, behind no separator'
    Assert-Equal 0 $wrapFound.MissingLeaves.Count 'a capture whose only .ps1 token is a wrap orphan names nothing at all'

    Write-Host "fixture-script-lib.tests: BOTH ellipsis shapes, on controlled input" -ForegroundColor Cyan

    # WHERE PowerShell CUTS A LONG CategoryInfo TARGET DEPENDS ON THE PATH, so the artefact has two
    # shapes. The first was the only one the real child produced on the machine this was written on; the
    # second is what the CI runner produced, and it slipped through a leading-dot test and turned the
    # suite red on the only other host that has run it. Both are canned here so neither depends on whose
    # home directory the run happens to sit under.
    $ellipsisShapes = @(
        @{ Label = 'cut right after a separator'; Text = "(C:\Users\maike\...-helper-lib.ps1:String)" },
        @{ Label = 'cut mid-segment';             Text = "(C:\Users\runner...-helper-lib.ps1:String)" }
    )
    foreach ($shape in $ellipsisShapes) {
        $canned = ". : The term 'x' is not recognized.`n    + CategoryInfo : ObjectNotFound: $($shape.Text) []`n    + FullyQualifiedErrorId : CommandNotFoundException"
        $ef = Get-FixtureScriptLoadFailure -Output $canned -Script 'pretend-acting.ps1'
        Assert-True ($null -ne $ef) "the class is still recognised when the target is truncated ($($shape.Label))"
        Assert-Equal 0 $ef.MissingLeaves.Count "a truncated target names no file at all ($($shape.Label))"
    }

    # AND THAT EMPTY CASE TAKES THE OTHER HEADLINE. CommandNotFoundException with no .ps1 behind it is
    # most likely a mistyped cmdlet INSIDE the acting script -- a bug in that script, not a gap in the
    # copy list -- so the verdict must not claim the script 'never ran' nor point at the copy list.
    $beforeUnresolved = Get-FixtureScriptLoadFailureCount
    $unresolvedOut = & {
        Assert-FixtureScriptLoaded -Code 1 -Script 'pretend-acting.ps1' -Output $wrapped 6>&1
    } | Out-String
    Assert-Equal ($beforeUnresolved + 1) (Get-FixtureScriptLoadFailureCount) 'the unresolved-command case is still counted'
    Assert-True ($unresolvedOut -match 'UNRESOLVED COMMAND') 'with no .ps1 named, the headline does not claim a load failure'
    Assert-True ($unresolvedOut -notmatch 'never ran') 'with no .ps1 named, the verdict does not claim the script never ran'
    Assert-True ($unresolvedOut -notmatch "add it to this suite's copy list") 'with no .ps1 named, the reader is not sent to the copy list'

    Write-Host "fixture-script-lib.tests: the summary is SILENT on a clean scope" -ForegroundColor Cyan

    # A FRESH PROCESS, because the counter lives in this suite's own script scope and is already
    # non-zero by now. The $false path is the one every wired suite takes on a normal green run, so
    # leaving it unproven means a guard that always printed would pass every test here.
    $libPath = Join-Path $RepoRoot 'scripts\lib\fixture-script-lib.ps1'
    $freshChild = Join-Path $Fixture 'summary-fresh.ps1'
    Set-Content -LiteralPath $freshChild -Encoding ascii -Value @"
. '$libPath'
if (Write-FixtureScriptSummary -Subject 'nothing-broke.ps1') { Write-Host 'SUMMARY-SAID-TRUE' } else { Write-Host 'SUMMARY-SAID-FALSE' }
Write-Host ('COUNT=' + (Get-FixtureScriptLoadFailureCount))
"@
    $freshOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $freshChild 2>&1) | Out-String
    Assert-True ($freshOut -match 'SUMMARY-SAID-FALSE') 'on a clean scope the summary reports false'
    Assert-True ($freshOut -match 'COUNT=0') 'and the counter starts at zero in a fresh scope'
    Assert-True ($freshOut -notmatch 'FIXTURE:') 'a clean scope prints no broken-fixture block at all'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
