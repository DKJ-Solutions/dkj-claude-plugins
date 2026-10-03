<#
.SYNOPSIS
    Regenerates scripts/tests/suite-durations.json from the per-suite tables real CI runs printed.

.DESCRIPTION
    WHY IT EXISTS. Invoke-TestSuiteGate packs its shards and orders its queue from that file (issue
    #1358), and the file is committed rather than written by the gate itself for one reason: the only
    durations worth packing a hosted runner from are a hosted runner's. A local reading does not convert
    into a CI one -- THERE IS NO RATIO TO DIVIDE OUT, and the sign is not even fixed -- so a gate that
    refreshed the file from whatever machine last ran it would pack CI off workstation figures and land
    worse than no data at all. That is not a hypothetical: reading a local figure as a CI one is exactly
    how #1358 came to name a five-file plateau that has four.

    THIS DOCSTRING STATED THAT BACKWARDS UNTIL SEPTEMBER 9, 2026 (issue #1713). It said the same suites
    run "3.6-4.0x faster on a developer machine", which was measured the other way round on the machine
    that checked it: check-plugin-integrity-links.tests.ps1 took 759.1s SOLO on an 18-thread workstation
    against a 290.9s mean over three 4-lane CI runs. A third configuration disagrees with both -- the
    whole 85-suite pool runs in about 255s of wall clock on a 32-thread machine at 30 lanes. The
    conclusion above is unaffected and in fact stronger for it: CI is a different machine, not a scaled
    one. No replacement constant is published here on purpose, because three readings on three
    configurations is what "not a constant" looks like.

    AND WHY IT IS A SCRIPT RATHER THAN A PROCEDURE. This was done by hand twice on September 4, 2026 --
    `gh run view --log`, a grep, and an average across two runs -- which is this house's own trigger for
    automating a thing rather than writing it down. The hand method also has a failure the script does
    not: the gate's log carries OTHER tables that look identical, because test-suite-gate.tests.ps1
    prints one over its own fixture, so a naive grep silently mixes 1.4s fixtures into a table of real
    suites. Every row here is checked against the suites that actually exist before it is kept.

    WHAT IT REFUSES TO DO. It reaches no verdict and gates nothing. A suite it finds no row for is left
    out of the file entirely rather than written with a guess -- the gate charges an unlisted suite the
    maximum recorded value, which is the safe direction, and a fabricated middling number would take that
    protection away while looking like data.

    AVERAGED ACROSS RUNS, AND THE RUNS ARE NAMED IN THE FILE. These suites are measurably noisy under the
    gate (#1033), so one run is one draw; two or three is enough to pack from. The `recordedFrom` block
    records which runs produced the numbers, so a later reader can re-derive them or notice they are old.

.PARAMETER RunId
    One or more GitHub Actions run ids of the CI workflow. Each must have run the sharded suites job --
    so take a PR run. Neither trunk push a ship leaves behind normally qualifies: the `fold:` push skips
    the suites by subject (#1300), and the `merge:` push skips them whenever the merge-commit certificate
    proves its tree was already certified (#2303), which is the ordinary case after ship-pr. See the throw
    that names both.

    SEVERAL IDS UNDER `-File`: pass them as ONE comma-separated string, e.g.
    `-RunId 34583187104,34583740147`. Both `$RunId` and `$RepoRoot` are positional, so under
    `powershell -NoProfile -ExecutionPolicy Bypass -File` -- the form every doc in this repo uses --
    a space-separated list binds only the first id to `-RunId` and the second to `-RepoRoot`, which
    then fails as a missing path. The
    comma form reaches this script as one string and is split on `[,\s]+` below.

.PARAMETER RepoRoot
    The repo to write into. Defaults to the git root of the working directory.

.PARAMETER DryRun
    Print the table that would be written and touch nothing. It prints the 12 slowest suites and the
    pool total only: for the full table, a per-family total or a before/after comparison of two sets of
    runs, use measure-suites.ps1 beside this script, which writes nothing at all (issue #2775).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$RunId,
    [string]$RepoRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# A run id passed as a second space-separated -RunId argument binds here instead (both parameters are
# positional under `-File`) and would otherwise fail several lines down as a missing path, with no
# mention of -RunId anywhere in the message. Caught at the point of the mistake, with the caller's own
# value in the text -- see the .PARAMETER RunId note above.
if ($RepoRoot -match '^\d{6,}$') {
    throw "-RepoRoot '$RepoRoot' looks like a GitHub Actions run id, not a path. Pass several run ids " +
        "to -RunId as one comma-separated string, e.g. -RunId '$($RunId[0]),$RepoRoot', not as " +
        'separate space-separated arguments.'
}

# Invoke-NativeCapture rather than a bare `gh ... 2>&1`: under 'Stop' a native command's redirected
# stderr arrives as an ErrorRecord and kills the script on a line gh writes progress to. The lib runs
# the call under 'Continue' and hands back the exit code separately, which is what shared-scripts.tests
# asserts for every script in this tree.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# WHERE THE REPO ROOT COMES FROM (issue #2115). --show-toplevel returns a raw path and -Utf8 was never
# passed here, so Windows PowerShell 5.1 decoded it with [Console]::OutputEncoding: under an accented
# checkout the Resolve-Path below failed on a root that was really there.
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')

if (-not $RepoRoot) {
    $RepoRoot = (Get-GitTopLevelPath).Path
    if (-not $RepoRoot) { throw 'Not in a git repository - pass -RepoRoot.' }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$testsDir = Join-Path $RepoRoot 'scripts\tests'
if (-not (Test-Path -LiteralPath $testsDir)) { throw "No test directory at $testsDir." }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'The gh CLI is required to read a run log - install it, or pass logs another way.'
}

# THE PARSING LIVES IN suite-durations-lib.ps1 (issue #2775), shared with measure-suites.ps1. Its row
# validation is what drops the fixture tables the gate's own suite prints (see the docstring) and, for
# free, any suite that has since been deleted or renamed -- both of which would otherwise be carried
# forward for ever by an averaging pass that never looks at the directory.
. (Join-Path $PSScriptRoot '..\lib\suite-durations-lib.ps1')
$known = Get-KnownSuiteNames -TestsDir $testsDir

$runIds = Split-RunIdList -RunId $RunId
if ($runIds.Count -eq 0) { throw 'No run ids given.' }

$slug = Get-RepoSlugFromGh

$samples = @{}
foreach ($id in $runIds) {
    Write-Host "reading run $id ..." -ForegroundColor Cyan
    # A run with no table throws, naming the fold and merge pushes: their CI runs skip the suites and
    # complete green having measured nothing, which is the run a caller reaches for first (#1833, #2388).
    $read = Read-RunSuiteSamples -Id $id -Slug $slug -KnownNames $known -Samples $samples
    Write-Host "  $($read.Found) suite rows" -ForegroundColor DarkGray
}

$missing = @($known.Keys | Where-Object { -not $samples.ContainsKey($_) } | Sort-Object)
if ($missing.Count -gt 0) {
    # Loud, and not fatal: the gate charges an unlisted suite the maximum, so the file is still correct --
    # it is just missing a suite the runs predate, which is exactly what a reader needs told.
    Write-Warning ("no rows for {0} suite(s) -- left out of the file, and the gate will charge each the maximum: {1}" -f $missing.Count, ($missing -join ', '))
}

$seconds = Get-SuiteMeans -Samples $samples

Write-Host ''
# INVARIANT CULTURE, because these lines are MEASUREMENTS somebody copies into an issue or a changelog
# entry. PowerShell's -f uses the current culture, so on a nl-NL console the pool's heaviest suite prints
# as '236,8s' -- a figure that reads as wrong everywhere it is pasted, from a script whose whole job is
# producing figures. The JSON below is unaffected: ConvertTo-Json serialises a double invariantly.
$inv = [System.Globalization.CultureInfo]::InvariantCulture
Write-Host ("{0} suites, slowest first:" -f $seconds.Count) -ForegroundColor Cyan
$seconds.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 12 | ForEach-Object {
    Write-Host ([string]::Format($inv, '  {0,7:0.0}s  {1}', $_.Value, $_.Key))
}
Write-Host ([string]::Format($inv, '  ... pool total {0:0}s', (($seconds.Values | Measure-Object -Sum).Sum)))

if ($DryRun) {
    Write-Host 'dry run - nothing written.' -ForegroundColor Yellow
    exit 0
}

$doc = [ordered]@{
    note = @(
        'Per-suite CI durations, in seconds -- a HINT for Invoke-TestSuiteGate, never a contract.',
        'The gate packs shards and dequeues longest-first from these. A suite missing here is charged',
        'the largest recorded value, so a new suite starts early and can never be the one left last.',
        'Every suite in the directory runs exactly once whether or not it appears below; delete this',
        'file and the gate falls back to the stride, unchanged.',
        'MEASURED ON CI, NOT ON A WORKSTATION, and a local reading does NOT convert into a CI one: there',
        'is no ratio to divide out and the sign is not even fixed. One suite ran 2.6x SLOWER solo on an',
        '18-thread workstation than on a 4-lane runner, where this note claimed 3.6-4.0x faster until',
        'issue #1713. So a local reading would pack worse than no reading at all. Refresh with',
        'scripts/maintenance/record-suite-durations.ps1.'
    )
    recordedFrom = [ordered]@{
        runs    = @($runIds)
        date    = (Get-Date -Format 'yyyy-MM-dd')
        machine = 'windows-latest (4 cores), 4 lanes per shard'
        method  = 'mean of the per-suite durations the gate printed in each shard log'
    }
    seconds = $seconds
}

$target = Join-Path $testsDir 'suite-durations.json'
$json = ($doc | ConvertTo-Json -Depth 5) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($target, $json + "`n")
Write-Host "wrote $target" -ForegroundColor Green
exit 0
