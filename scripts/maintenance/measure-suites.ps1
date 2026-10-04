<#
.SYNOPSIS
    Measures what the test suites cost on CI, for one set of runs or as a before/after comparison of
    two -- pool total, per-family totals, the slowest shard, and the per-suite changes. Read-only.

.DESCRIPTION
    WHY IT EXISTS (issue #2775). measure-session-start, measure-skill and measure-closeouts each measure
    their own cost; the suites' CI cost had only record-suite-durations.ps1, which is built to REWRITE
    scripts/tests/suite-durations.json and whose -DryRun prints the twelve slowest suites and the pool
    total. The before/after check of a change to the suites was therefore done by hand twice in two
    days (October 2 and 3, 2026): that script pointed at two scratch copies of scripts/tests to get full
    tables without touching the committed file, an ad-hoc sum per family, and `gh run view --json jobs`
    for each shard's wall-clock. That is this house's trigger for a script in a skill.

    IT REUSES THE PARSER, IT DOES NOT COPY IT. The log parsing, and above all its row validation against
    the suites that exist in this tree, lives in suite-durations-lib.ps1, which record-suite-durations
    uses too. A consequence worth knowing before reading a delta: a suite that a change renamed or
    deleted is not in the tree, so its baseline rows are dropped -- the "rows dropped" line says how
    many, and a comparison across a rename should be read with that in mind.

    WHAT IT REFUSES TO DO. It writes nothing -- not suite-durations.json, not a baseline -- and it
    reaches no verdict. It always exits 0 once it has read the runs; an unreadable run, or a run with no
    suite table, throws before anything is printed, because a partial set reads as data.

    NOISE. These suites are measurably noisy under the gate (#1033), so one run is one draw. The report
    names how many runs each set holds; a delta between n=1 sets is a hint, not a measurement.

.PARAMETER BaselineRunId
    One or more GitHub Actions run ids of the CI workflow -- the "before" set, or the only set. Take PR
    runs: both trunk pushes a ship leaves behind normally skip the suites (see the lib's throw). Several
    ids under `-File` go in ONE comma-separated string, e.g. `-BaselineRunId 111,222`.

.PARAMETER RunId
    The "after" set, in the same form. Omit it to report the baseline set on its own.

.PARAMETER Family
    Named groups of suites to total, as 'name=glob' with several globs joined by ';', several families
    comma-separated in one string under `-File`, e.g.
    `-Family 'integrity=check-plugin-integrity-*,bwj=bwj-*;bwj-development.tests.ps1'`. A suite may count
    in more than one family.

.PARAMETER Top
    How many per-suite rows to print: the largest changes in a comparison, the slowest suites otherwise.
    Default 10; 0 prints every suite.

.PARAMETER Json
    Emit the figures as JSON on stdout instead of the human report.

.PARAMETER RepoRoot
    The repo whose scripts/tests decides which suite names count. Defaults to the git root of the
    working directory.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$BaselineRunId,
    [string[]]$RunId,
    [string[]]$Family,
    [int]$Top = 10,
    [switch]$Json,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\suite-durations-lib.ps1')

if (-not $RepoRoot) {
    $RepoRoot = (Get-GitTopLevelPath).Path
    if (-not $RepoRoot) { throw 'Not in a git repository - pass -RepoRoot.' }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$testsDir = Join-Path $RepoRoot 'scripts\tests'
if (-not (Test-Path -LiteralPath $testsDir)) { throw "No test directory at $testsDir." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'The gh CLI is required to read a run log.' }

$known    = Get-KnownSuiteNames -TestsDir $testsDir
$families = @(@($Family) | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$slug     = Get-RepoSlugFromGh

function Read-RunSet {
    param([string[]]$Ids, [string]$Label)
    $samples = @{}; $dropped = 0; $shards = @()
    foreach ($id in $Ids) {
        if (-not $Json) { Write-Host "reading $Label run $id ..." -ForegroundColor DarkGray }
        $read = Read-RunSuiteSamples -Id $id -Slug $slug -KnownNames $known -Samples $samples
        $dropped += $read.Dropped
        $runShards = @(Read-RunShardSeconds -Id $id -Slug $slug)
        $slowest = $runShards | Sort-Object Seconds -Descending | Select-Object -First 1
        $shards += [pscustomobject]@{
            RunId          = $id
            SlowestShard   = if ($slowest) { $slowest.Name } else { '' }
            SlowestSeconds = if ($slowest) { [double]$slowest.Seconds } else { $null }
            Shards         = $runShards
        }
    }
    $means = Get-SuiteMeans -Samples $samples
    $slowestValues = @($shards | Where-Object { $null -ne $_.SlowestSeconds } | ForEach-Object { $_.SlowestSeconds })
    return [pscustomobject]@{
        Runs              = @($Ids)
        Means             = $means
        Suites            = $means.Count
        PoolSeconds       = [Math]::Round((@($means.Values) | Measure-Object -Sum).Sum, 1)
        SlowestShardMean  = if ($slowestValues.Count) { [Math]::Round(($slowestValues | Measure-Object -Average).Average) } else { $null }
        PerRun            = $shards
        Families          = Get-FamilyTotals -Means $means -Family $families
        RowsDropped       = $dropped
    }
}

$baseIds = Split-RunIdList -RunId $BaselineRunId
if ($baseIds.Count -eq 0) { throw 'No baseline run ids given.' }
$cmpIds = Split-RunIdList -RunId $RunId

$base = Read-RunSet -Ids $baseIds -Label 'baseline'
$cmp  = if ($cmpIds.Count) { Read-RunSet -Ids $cmpIds -Label 'comparison' } else { $null }

# Per-suite rows: the change in a comparison, the slowest otherwise.
$suiteRows = if ($cmp) {
    $names = @(@($base.Means.Keys) + @($cmp.Means.Keys) | Sort-Object -Unique)
    @($names | ForEach-Object {
        $b = if ($base.Means.Contains($_)) { [double]$base.Means[$_] } else { $null }
        $a = if ($cmp.Means.Contains($_))  { [double]$cmp.Means[$_] }  else { $null }
        $d = if ($null -ne $b -and $null -ne $a) { [Math]::Round($a - $b, 1) } elseif ($null -ne $a) { $a } else { -$b }
        [pscustomobject]@{ Suite = $_; Baseline = $b; Comparison = $a; Delta = $d }
    } | Sort-Object { [Math]::Abs($_.Delta) } -Descending)
} else {
    @($base.Means.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        [pscustomobject]@{ Suite = $_.Key; Baseline = [double]$_.Value; Comparison = $null; Delta = $null }
    })
}
if ($Top -gt 0) { $suiteRows = @($suiteRows | Select-Object -First $Top) }

if ($Json) {
    [pscustomobject]@{ Repo = $slug; Baseline = $base; Comparison = $cmp; Suites = $suiteRows } |
        ConvertTo-Json -Depth 6
    exit 0
}

# INVARIANT CULTURE, because these figures get pasted into issues and changelog entries: on a nl-NL
# console -f would print 236,8s.
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function Format-Sec { param($v) if ($null -eq $v) { return '--' } [string]::Format($inv, '{0:0}s', [double]$v) }
function Format-Delta {
    param($before, $after)
    if ($null -eq $before -or $null -eq $after) { return '' }
    $d = [double]$after - [double]$before
    $pct = if ([double]$before -ne 0) { [string]::Format($inv, ' ({0:+0;-0;0}%)', 100 * $d / [double]$before) } else { '' }
    return [string]::Format($inv, '{0:+0;-0;0}s', $d) + $pct
}
function Write-Line {
    param([string]$Label, $Before, $After)
    if ($cmp) {
        Write-Host ([string]::Format($inv, '  {0,-26} {1,10} {2,12}   {3}', $Label, (Format-Sec $Before), (Format-Sec $After), (Format-Delta $Before $After)))
    } else {
        Write-Host ([string]::Format($inv, '  {0,-26} {1,10}', $Label, (Format-Sec $Before)))
    }
}

Write-Host ''
Write-Host "== measure-suites -- $slug ==" -ForegroundColor Cyan
Write-Host ("  baseline:   {0} run(s): {1}" -f $base.Runs.Count, ($base.Runs -join ', '))
if ($cmp) { Write-Host ("  comparison: {0} run(s): {1}" -f $cmp.Runs.Count, ($cmp.Runs -join ', ')) }
Write-Host ''
if ($cmp) { Write-Host ([string]::Format('  {0,-26} {1,10} {2,12}   {3}', '', 'baseline', 'comparison', 'delta')) -ForegroundColor DarkGray }
Write-Line ("pool total ({0}{1} suites)" -f $base.Suites, $(if ($cmp) { "/$($cmp.Suites)" } else { '' })) $base.PoolSeconds $(if ($cmp) { $cmp.PoolSeconds })
Write-Line 'slowest shard (mean)' $base.SlowestShardMean $(if ($cmp) { $cmp.SlowestShardMean })
foreach ($name in $base.Families.Keys) {
    $bf = $base.Families[$name]
    $af = if ($cmp) { $cmp.Families[$name] } else { $null }
    Write-Line ("family {0} ({1})" -f $name, $bf.Suites) $bf.Seconds $(if ($af) { $af.Seconds })
}
Write-Host ''
Write-Host '  slowest shard per run:' -ForegroundColor DarkGray
foreach ($set in @(@($base) + @($cmp | Where-Object { $_ }))) {
    foreach ($r in $set.PerRun) { Write-Host ("    {0}  {1}  {2}" -f $r.RunId, (Format-Sec $r.SlowestSeconds), $r.SlowestShard) }
}

Write-Host ''
$heading = if ($cmp) { 'per suite, largest change first' } else { 'per suite, slowest first' }
Write-Host ("  {0}{1}:" -f $heading, $(if ($Top -gt 0) { " (top $Top)" } else { '' })) -ForegroundColor DarkGray
foreach ($row in $suiteRows) {
    if ($cmp) {
        Write-Host ([string]::Format($inv, '    {0,8} {1,8}  {2,-12} {3}', (Format-Sec $row.Baseline), (Format-Sec $row.Comparison),
            $(if ($null -eq $row.Baseline) { 'new' } elseif ($null -eq $row.Comparison) { 'gone' } else { (Format-Delta $row.Baseline $row.Comparison) -replace ' \(.*$', '' }),
            $row.Suite))
    } else {
        Write-Host ([string]::Format($inv, '    {0,8}  {1}', (Format-Sec $row.Baseline), $row.Suite))
    }
}

$dropped = $base.RowsDropped + $(if ($cmp) { $cmp.RowsDropped } else { 0 })
Write-Host ''
Write-Host ("  rows dropped: {0} (a fixture table, or a suite no longer in this tree)" -f $dropped) -ForegroundColor DarkGray
if ($base.Runs.Count -lt 2 -or ($cmp -and $cmp.Runs.Count -lt 2)) {
    Write-Host '  a set of one run is one draw (#1033) -- read its delta as a hint.' -ForegroundColor DarkGray
}
Write-Host '  nothing was written.' -ForegroundColor DarkGray
exit 0
