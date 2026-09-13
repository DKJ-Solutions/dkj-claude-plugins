<#
.SYNOPSIS
    Regression tests for scripts/lib/consumer-check-lib.ps1 -- Resolve-CheckRepoRoot and
    Get-CheckProseCorpus, the preamble that five consumer-facing lint checks used to carry near-copies
    of (issue #1422).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Both functions are pure enough to dot-source and
    call in-process; neither exits, by design -- Resolve-CheckRepoRoot returns '' where four of its five
    former copies threw, and what to DO about '' is the caller's verdict rather than the lib's.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/consumer-check-lib.tests.ps1

    What is asserted:
      1. the three sources of the root, IN ORDER -- -RootOverride beats CLAUDE_PROJECT_DIR beats the git
         root. The precedence is the part worth pinning: CLAUDE_PROJECT_DIR winning over the git root is
         what stops a SessionStart hook running from the plugin cache judging THIS repo instead of the
         consumer whose session it is, and nothing else in the tree states that;
      2. '' -- not a throw -- when none of the three answers. This is the drift the extraction settled:
         four checks resolved on one line and died on `.Trim()` against $null outside a checkout, while
         check-git-identity had wrapped it. A test that only covered the happy path is exactly what let
         two readings of the same line coexist for as long as they did;
      3. Get-CheckProseCorpus returns @() rather than throwing for the two absences it tolerates on
         purpose -- no root document, and (proven by calling it from a directory with no
         measure-context-lib.ps1 sibling) no walker lib;
      4. and it really walks: a fixture CLAUDE.md with an '@'-import yields BOTH documents, so the assert
         is that the closure is followed rather than that a file was opened.

    THE ENV VAR IS SAVED AND RESTORED around every case that touches it. This suite runs under the same
    shared console as every other one in this folder -- the shared-state hazard the language rules
    already record for [Console]::OutputEncoding -- and CLAUDE_PROJECT_DIR is set for real in a Claude
    Code session, so leaking a fixture path out of here would hand the next suite a repo root that does
    not exist.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

# JUDGING THIS SUITE'S OWN FIXTURE CHILD -- issues #1934 and #1954. The probe below runs a COPY of the
# lib in a child process, so a load this copy cannot resolve kills it before it writes anything.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\consumer-check-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function New-Fixture {
    param([Parameter(Mandatory)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("cclib-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return (Resolve-Path -LiteralPath $dir).Path
}

function Set-Text {
    param([string]$Dir, [string]$Rel, [string]$Text)
    $path = Join-Path $Dir ($Rel -replace '/', '\')
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $Text, $Utf8NoBom)
}

$savedProjectDir = $env:CLAUDE_PROJECT_DIR

try {

# --- 1. Resolve-CheckRepoRoot: the three sources, in order -----------------------------------------
Write-Host ''
Write-Host 'Resolve-CheckRepoRoot -- precedence'

$override = New-Fixture -Label 'override'
$fromEnv  = New-Fixture -Label 'fromenv'

$env:CLAUDE_PROJECT_DIR = $fromEnv
Assert-True ((Resolve-CheckRepoRoot -RootOverride $override) -eq $override) `
    '-RootOverride wins over CLAUDE_PROJECT_DIR -- the test suite and worktree-lane pass a tree explicitly'

Assert-True ((Resolve-CheckRepoRoot) -eq $fromEnv) `
    'CLAUDE_PROJECT_DIR wins over the git root -- a hook run from the plugin cache judges the SESSION repo, not this one'

$env:CLAUDE_PROJECT_DIR = ''
Push-Location $RepoRoot
try {
    $viaGit = Resolve-CheckRepoRoot
} finally { Pop-Location }
Assert-True ($viaGit -and ((Resolve-Path -LiteralPath $viaGit).Path -eq $RepoRoot)) `
    'with neither set, the git root answers -- the source-repo command-line case'

# --- 2. '' rather than a throw, outside a checkout --------------------------------------------------
Write-Host ''
Write-Host 'Resolve-CheckRepoRoot -- outside a checkout'

# A temp directory is not a git repo, so `git rev-parse` exits non-zero and prints nothing. The one-line
# form four of the five checks carried called .Trim() on that $null under Set-StrictMode; this is the
# assert that would have caught it.
$notARepo = New-Fixture -Label 'notarepo'
$env:CLAUDE_PROJECT_DIR = ''
Push-Location $notARepo
try {
    $outside = $null
    $threw = $false
    try { $outside = Resolve-CheckRepoRoot } catch { $threw = $true }
} finally { Pop-Location }

Assert-True (-not $threw) 'a tree that is not a checkout does not throw -- a SessionStart hook must not fail over an advisory check'
Assert-True ($outside -eq '') 'and it answers the empty string, so the caller supplies its own verdict'

# --- 3. Get-CheckProseCorpus: the two tolerated absences --------------------------------------------
Write-Host ''
Write-Host 'Get-CheckProseCorpus -- tolerated absences'

$noDoc = New-Fixture -Label 'nodoc'
Assert-True ((@(Get-CheckProseCorpus -RepoRoot $noDoc)).Count -eq 0) `
    'a repo with no CLAUDE.md has no always-on prose -- @(), not an error'

Assert-True ((@(Get-CheckProseCorpus -RepoRoot $noDoc -RootDocument (Join-Path $noDoc 'nope.md'))).Count -eq 0) `
    'a -RootDocument that does not exist is the same answer'

# THE MISSING-WALKER CASE, and it needs a COPY of the lib in a directory with no measure-context-lib
# sibling -- the guarded load resolves $PSScriptRoot-relative, so it can only be proven from a tree
# shaped like a mirror built before that lib travelled. Asserted through a child process because the
# copy defines the same two function names as the ones already dot-sourced here.
$loneDir = New-Fixture -Label 'lonelib'
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\consumer-check-lib.ps1') -Destination (Join-Path $loneDir 'consumer-check-lib.ps1')
$docDir = New-Fixture -Label 'lonedoc'
Set-Text -Dir $docDir -Rel 'CLAUDE.md' -Text "# Root`n"
$probe = Join-Path $loneDir 'probe.ps1'
Set-Text -Dir $loneDir -Rel 'probe.ps1' -Text @"
`$ErrorActionPreference = 'Stop'
. (Join-Path `$PSScriptRoot 'consumer-check-lib.ps1')
Write-Output ("COUNT=" + (@(Get-CheckProseCorpus -RepoRoot '$docDir')).Count)
"@
# EAP LOWERED FOR THE CALL AND THE VERDICT READ AFTER IT (issues #1934 and #1954). The probe dot-sources
# a COPY of the lib, so an unguarded load this copy cannot resolve kills the child before it writes
# COUNT= at all -- and the assert below would then report a missing measure-context-lib sibling, which is
# the one thing that is working as designed here. At 'Stop' the child's stderr is terminating, so the
# verdict has to be reachable before it can say so.
$prevEap = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $probeOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $probe 2>&1 | Out-String
    Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Script $probe -Output $probeOut
} finally {
    $ErrorActionPreference = $prevEap
}
Assert-True ($probeOut -match 'COUNT=0') `
    'no measure-context-lib sibling -- @() and no throw, so a pre-#1422 mirror degrades instead of failing'

# --- 4. and it really walks the '@'-import closure ---------------------------------------------------
Write-Host ''
Write-Host 'Get-CheckProseCorpus -- the walk'

$walkDir = New-Fixture -Label 'walk'
Set-Text -Dir $walkDir -Rel 'imported.md' -Text "# Imported`nsome prose`n"
Set-Text -Dir $walkDir -Rel 'CLAUDE.md'   -Text "# Root`n`n@imported.md`n"
$walked = @(Get-CheckProseCorpus -RepoRoot $walkDir)
# ASSERTED ON IDENTITY, NOT ON A COUNT. `-ge 2` was the first form and it does not prove what this case
# claims: two unrelated or duplicate rows satisfy it just as well as a followed import. The subject is
# the CLOSURE, so the assert names the file that only appears if the '@' line was resolved. The rows may
# be paths or objects carrying one, so the match is over their string forms.
$walkedText = ($walked | ForEach-Object { [string]$_ }) -join "`n"
if (-not ($walkedText -match 'imported')) {
    $walkedText = ($walked | ForEach-Object { ($_.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ' ' }) -join "`n"
}
Assert-True ($walked.Count -ge 2 -and $walkedText -match 'imported\.md') `
    'the root AND its @-import come back, and the IMPORTED file is named -- the closure is followed, not just the one file opened'

Remove-Item -Recurse -Force -LiteralPath $override, $fromEnv, $notARepo, $noDoc, $loneDir, $docDir, $walkDir -ErrorAction SilentlyContinue

} finally {
    $env:CLAUDE_PROJECT_DIR = $savedProjectDir
}

Write-Host ''
# ABOVE THE VERDICT AND EVEN ON A GREEN RUN (issues #1934 and #1954): a child that died on load made
# this run a measurement of the fixture rather than of the lib.
$loadBroken = Write-FixtureScriptSummary -Subject 'consumer-check-lib.ps1'
if ($loadBroken) {
    Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child script(s) died on load -- this run measured a fixture, not the lib." -ForegroundColor Red
    exit 1
}
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
