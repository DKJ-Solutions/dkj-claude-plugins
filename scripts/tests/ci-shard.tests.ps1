<#
.SYNOPSIS
    The CI shard: Invoke-TestSuiteGate's partition, and the fail-closed summary job that makes four
    green shards mean something. Issue #1351.

.DESCRIPTION
    WHY THIS SUITE EXISTS. Sharding replaced one required check with five jobs, and every way it can go
    wrong is SILENT IN THE GREEN DIRECTION -- the family this repo has now measured three times (#1294's
    dropped runs, #1300's fold shortcut, #1325's exit-code inference). Specifically:

      * -ShardCount disagreeing with the matrix length runs a FRACTION of the pool and reports every
        shard green. A matrix of [1,2,3,4] against -ShardCount 5 runs 4/5 of the suites, for ever, with
        nothing in any log saying which fifth never ran.
      * The summary job losing `if: !cancelled()` turns a red shard into NO verdict: a job that needs a
        failed job is skipped, and a skipped check is not a reported failure. Regaining a bare
        `if: always()` in its place is the #1356 regression -- `always()` also fires on a CANCELLED run,
        so a PR run superseded by `cancel-in-progress` reports the required check as failure, not
        cancelled.
      * The summary job losing its result comparison turns that `if:` into a permanent GREEN.
      * The summary job being RENAMED un-gates `main` outright -- `main-ci-gate` requires the context
        `lint-en-tests`, so the ruleset would wait for a check nobody reports.

    None of those changes any observable behaviour of the repo TODAY, which is what makes them worth
    asserts rather than a comment: nothing else in the tree would notice.

    THE PARTITION IS TESTED AS A PROPERTY, NOT AS A SPELLING. The asserts below run the real
    Invoke-TestSuiteGate over a temporary directory of trivial suites and check what it actually RAN --
    a clean cover (every suite exactly once across the shards), balance, and the refusals -- rather than
    grepping the lib for a modulo. A stride written backwards, off by one, or over an unsorted list
    passes every text match and fails the cover.

    WHY IT RUNS REAL CHILD PROCESSES. The gate's whole shape is Start-Process children, and the property
    under test is which files it hands to them. Its own per-suite output is the only honest evidence of
    that, so each fixture suite prints a line naming itself and the assert reads the transcript. The
    fixture suites do nothing else, so the whole suite costs a few seconds.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ciPath   = Join-Path $repoRoot '.github\workflows\ci.yml'
$libPath  = Join-Path $repoRoot 'scripts\lib\native-capture-lib.ps1'

$ci = Get-Content -LiteralPath $ciPath -Raw
. $libPath

# ------------------------------------------------------------------------------------------------
Write-Host "== the partition: a clean cover, over a real gate run ==" -ForegroundColor Cyan

# Twelve suites, named so that alphabetical order is unambiguous and a stride is distinguishable from a
# contiguous block. Each one prints its own name and exits 0.
$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ci-shard-fixture-$PID-$([guid]::NewGuid().ToString('n'))")
if (Test-Path -LiteralPath $fixtureDir) { Remove-Item -Recurse -Force -LiteralPath $fixtureDir }
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

$fixtureNames = @()
foreach ($n in 1..12) {
    $name = ('s{0:d2}' -f $n)
    $fixtureNames += $name
    $body = "Write-Host 'RAN:$name'" + "`r`n" + 'exit 0'
    Set-Content -LiteralPath (Join-Path $fixtureDir "$name.tests.ps1") -Value $body -Encoding Ascii
}

function Get-ShardRun {
    <# Runs the real gate for one shard and returns the suite names it actually executed. #>
    param([int]$Shard, [int]$ShardCount)
    $out = Invoke-TestSuiteGate -TestsDir $fixtureDir -Context 'gate probe' -MaxParallel 4 `
        -Shard $Shard -ShardCount $ShardCount 6>&1 | Out-String -Width 4000
    $ran = @([regex]::Matches($out, 'RAN:(s\d\d)') | ForEach-Object { $_.Groups[1].Value })
    [pscustomobject]@{ Ran = $ran; Text = $out }
}

$shardRuns = @(1..4 | ForEach-Object { Get-ShardRun -Shard $_ -ShardCount 4 })
$allRan = @($shardRuns | ForEach-Object { $_.Ran })

Assert-True ($allRan.Count -eq 12) "four shards of four run 12 suites in total, not more and not fewer (ran $($allRan.Count))"
Assert-True (@($allRan | Sort-Object -Unique).Count -eq 12) 'every suite ran exactly once -- no suite is in two shards'
Assert-True ((Compare-Object $fixtureNames ($allRan | Sort-Object) | Measure-Object).Count -eq 0) `
    'and the union is the whole pool -- no suite is in no shard'

# BALANCE IS THE POINT OF THE STRIDE, so it is asserted rather than assumed. 12 over 4 is exact; the
# general claim is that no two shards differ by more than one, which is what a stride guarantees and a
# contiguous block over an uneven division does not.
$sizes = @($shardRuns | ForEach-Object { $_.Ran.Count })
Assert-True (($sizes | Measure-Object -Maximum).Maximum - ($sizes | Measure-Object -Minimum).Minimum -le 1) `
    "no two shards differ in size by more than one (sizes $($sizes -join ','))"

# A STRIDE, NOT A BLOCK -- the assert that actually distinguishes the two implementations. Shard 1 of a
# stride holds s01, s05, s09; shard 1 of a contiguous split holds s01, s02, s03.
Assert-True (($shardRuns[0].Ran | Sort-Object) -join ',' -eq 's01,s05,s09') `
    'shard 1 holds every fourth suite (s01,s05,s09) -- a stride, not the first contiguous block'
Assert-True (($shardRuns[1].Ran | Sort-Object) -join ',' -eq 's02,s06,s10') 'and shard 2 is offset by one'

# DETERMINISM: the same two integers select the same files, which is what makes a red shard re-runnable
# by hand. Asserted by running one shard twice rather than by reading the sort call.
$again = Get-ShardRun -Shard 3 -ShardCount 4
Assert-True ((($again.Ran | Sort-Object) -join ',') -eq (($shardRuns[2].Ran | Sort-Object) -join ',')) `
    'the same (Shard, ShardCount) selects the same suites on a second run'

# THE UNSHARDED CALL IS UNCHANGED -- every existing caller passes neither parameter.
$whole = Invoke-TestSuiteGate -TestsDir $fixtureDir -Context 'gate probe' -MaxParallel 4 6>&1 | Out-String -Width 4000
$wholeRan = @([regex]::Matches($whole, 'RAN:(s\d\d)') | ForEach-Object { $_.Groups[1].Value })
Assert-True ($wholeRan.Count -eq 12) 'a call with neither parameter still runs the whole pool'
Assert-True ($whole -match 'all 12 suites passed') 'and its summary line still says "all 12", unchanged'
Assert-True ($whole -notmatch 'shard') 'and mentions no shard at all'

Write-Host "== the summary line names its scope (#1318's rule, applied to shards) ==" -ForegroundColor Cyan
Assert-True ($shardRuns[0].Text -match 'shard 1/4') 'a sharded run names the shard on the line that gets quoted'
Assert-True ($shardRuns[0].Text -match '3 of 12 suites passed') 'and states the slice against the pool, so the seconds are readable later'
Assert-True ($shardRuns[0].Text -notmatch 'all 3 suites passed') 'and never claims "all" of a slice'

Write-Host "== the refusals: a nonsensical shard is not interpreted ==" -ForegroundColor Cyan

# EACH OF THESE HAS A PLAUSIBLE SILENT READING, which is why the gate throws instead of picking one.
$threw = $false
try { Invoke-TestSuiteGate -TestsDir $fixtureDir -Shard 3 6>&1 | Out-Null } catch { $threw = $true }
Assert-True $threw '-Shard without -ShardCount throws rather than quietly running the whole pool'

$threw = $false
try { Invoke-TestSuiteGate -TestsDir $fixtureDir -ShardCount 4 6>&1 | Out-Null } catch { $threw = $true }
Assert-True $threw '-ShardCount without -Shard throws rather than quietly running the whole pool'

$threw = $false
try { Invoke-TestSuiteGate -TestsDir $fixtureDir -Shard 5 -ShardCount 4 6>&1 | Out-Null } catch { $threw = $true }
Assert-True $threw 'a shard past the count throws rather than selecting nothing and reporting green'

$threw = $false
try { Invoke-TestSuiteGate -TestsDir $fixtureDir -Shard 0 -ShardCount 4 6>&1 | Out-Null } catch { $threw = $true }
Assert-True $threw 'and so does shard 0 -- the parameter is 1-based, and off-by-one is the likeliest typo'

# MORE SHARDS THAN SUITES is the one empty slice that is legitimate, and it must not read as "this repo
# has no tests" -- the directory plainly does.
$thin = Invoke-TestSuiteGate -TestsDir $fixtureDir -Shard 20 -ShardCount 20 -MaxParallel 2 3>&1 6>&1 | Out-String -Width 4000
Assert-True ($thin -match 'more shards than suites') 'an empty slice says more shards than suites'
Assert-True ($thin -notmatch 'no \*\.tests\.ps1 suites found') 'and does not claim the directory is empty when it holds twelve'

Write-Host "== the cost-aware partition: hints change the packing, never the cover (#1358) ==" -ForegroundColor Cyan

# WHY THESE ARE MOSTLY DIRECT-FUNCTION ASSERTS while the stride above is tested through a real gate run.
# The stride's claim is about which files got HANDED to child processes, and only a real run proves that.
# The claims here are about ORDER as well as membership, and a completed-suite transcript cannot show
# dequeue order -- twelve trivial fixtures all finish in milliseconds, so their completion order is a
# race, not a reading. Get-TestSuiteShardOrder is pure and returns the queue itself, so it is asserted
# directly and the cover is re-checked through the gate underneath.

function New-FakeSuite { param([string]$Name) [pscustomobject]@{ Name = $Name } }

# Eleven suites whose alphabetical order is the REVERSE of their cost order, so any assert below that
# passes cannot be passing on the name sort by accident.
$costPool = @(
    (New-FakeSuite 'a.tests.ps1'), (New-FakeSuite 'b.tests.ps1'), (New-FakeSuite 'c.tests.ps1'),
    (New-FakeSuite 'd.tests.ps1'), (New-FakeSuite 'e.tests.ps1'), (New-FakeSuite 'f.tests.ps1'),
    (New-FakeSuite 'g.tests.ps1'), (New-FakeSuite 'h.tests.ps1'), (New-FakeSuite 'i.tests.ps1'),
    (New-FakeSuite 'j.tests.ps1'), (New-FakeSuite 'k.tests.ps1')
)
$costs = @{
    'a.tests.ps1' = 1.0;  'b.tests.ps1' = 2.0;  'c.tests.ps1' = 3.0;  'd.tests.ps1' = 4.0
    'e.tests.ps1' = 5.0;  'f.tests.ps1' = 6.0;  'g.tests.ps1' = 7.0;  'h.tests.ps1' = 8.0
    'i.tests.ps1' = 9.0;  'j.tests.ps1' = 10.0; 'k.tests.ps1' = 100.0
}

# THE ORDER IS THE HALF THAT PAYS, and it is the reverse of the name sort here by construction.
$wholeOrder = @(Get-TestSuiteShardOrder -Suites $costPool -Costs $costs | ForEach-Object { $_.Name })
Assert-True ($wholeOrder[0] -eq 'k.tests.ps1') 'the whole pool is dequeued longest-first, not alphabetically'
Assert-True ($wholeOrder[-1] -eq 'a.tests.ps1') 'and the cheapest suite is last, where an idle lane costs nothing'
Assert-True ($wholeOrder.Count -eq $costPool.Count) 'and ordering drops nothing'

# THE COVER SURVIVES THE PACK. This is the one property that must hold no matter how wrong the numbers
# are -- stale hints may cost wall clock, never coverage.
$packed = @(1..4 | ForEach-Object { ,@(Get-TestSuiteShardOrder -Suites $costPool -Costs $costs -Shard $_ -ShardCount 4 | ForEach-Object { $_.Name }) })
$packedAll = @($packed | ForEach-Object { $_ })
Assert-True ($packedAll.Count -eq 11) "four cost-packed shards run all 11 suites (ran $($packedAll.Count))"
Assert-True (@($packedAll | Sort-Object -Unique).Count -eq 11) 'every suite is in exactly one shard under the pack'

# THE PACK IS BY COST, NOT BY COUNT -- the assert that distinguishes it from the stride. k costs 100 of
# the pool's 155, so a cost-aware pack gives its shard almost nothing else, while a stride would hand
# that shard two more suites regardless.
$kShard = @($packed | Where-Object { $_ -contains 'k.tests.ps1' })[0]
Assert-True ($kShard.Count -lt 3) "the shard holding the 100s suite draws fewer than three suites (drew $($kShard.Count)) -- cost, not count"
$loads = @($packed | ForEach-Object { $s = 0.0; foreach ($n in $_) { $s += $costs[$n] }; $s })
$strideLoads = @(1..4 | ForEach-Object { $i = $_ - 1; $s = 0.0; for ($j = $i; $j -lt $costPool.Count; $j += 4) { $s += $costs[$costPool[$j].Name] }; $s })
Assert-True (($loads | Measure-Object -Maximum).Maximum -le ($strideLoads | Measure-Object -Maximum).Maximum) `
    "the heaviest packed shard is no heavier than the heaviest strided one ($(($loads | Measure-Object -Maximum).Maximum)s vs $(($strideLoads | Measure-Object -Maximum).Maximum)s)"

# WITHIN A SHARD THE ORDER IS STILL DESCENDING. A balanced shard whose heaviest file is dequeued last
# ends on that file's tail, which is why packing without ordering measured WORSE than doing neither.
foreach ($shardNames in $packed) {
    if ($shardNames.Count -lt 2) { continue }
    $vals = @($shardNames | ForEach-Object { $costs[$_] })
    $sorted = @($vals | Sort-Object -Descending)
    Assert-True (($vals -join ',') -eq ($sorted -join ',')) "shard order is longest-first within the shard ($($shardNames -join ','))"
}

# AN UNTIMED SUITE IS CHARGED THE MAXIMUM, so it opens in the first lanes rather than trailing sixteen
# others. This is the one default that decides whether a new heavy suite costs its runtime or a tail.
$withNew = @($costPool + (New-FakeSuite 'zz-brand-new.tests.ps1'))
$newOrder = @(Get-TestSuiteShardOrder -Suites $withNew -Costs $costs | ForEach-Object { $_.Name })
Assert-True ($newOrder[0] -eq 'k.tests.ps1' -and $newOrder[1] -eq 'zz-brand-new.tests.ps1') `
    'a suite with no recorded duration is charged the maximum and dequeued in the opening lanes'

# DETERMINISM AND THE TIE-BREAK. Equal costs must not leave the order to hashtable enumeration, or a
# red shard stops being re-runnable by hand from two integers.
$tied = @((New-FakeSuite 'y.tests.ps1'), (New-FakeSuite 'x.tests.ps1'), (New-FakeSuite 'w.tests.ps1'))
$tiedCosts = @{ 'y.tests.ps1' = 5.0; 'x.tests.ps1' = 5.0; 'w.tests.ps1' = 5.0 }
$tiedOrder = @(Get-TestSuiteShardOrder -Suites $tied -Costs $tiedCosts | ForEach-Object { $_.Name })
Assert-True (($tiedOrder -join ',') -eq 'w.tests.ps1,x.tests.ps1,y.tests.ps1') 'equal costs fall back to the name sort, so the order is total'
$repeat = @(Get-TestSuiteShardOrder -Suites $costPool -Costs $costs -Shard 2 -ShardCount 4 | ForEach-Object { $_.Name })
Assert-True (($repeat -join ',') -eq ($packed[1] -join ',')) 'the same (Shard, ShardCount) packs the same suites in the same order on a second call'

# NO HINTS IS THE STRIDE, byte for byte -- the path every consuming repo without a durations file takes.
$noHints = @(1..4 | ForEach-Object { ,@(Get-TestSuiteShardOrder -Suites $costPool -Costs $null -Shard $_ -ShardCount 4 | ForEach-Object { $_.Name }) })
Assert-True (($noHints[0] -join ',') -eq 'a.tests.ps1,e.tests.ps1,i.tests.ps1') 'with no hints shard 1 is still every fourth suite in name order'
Assert-True (@(@($noHints | ForEach-Object { $_ }) | Sort-Object -Unique).Count -eq 11) 'and the strided cover is still clean'
$emptyHints = @(Get-TestSuiteShardOrder -Suites $costPool -Costs @{} -Shard 1 -ShardCount 4 | ForEach-Object { $_.Name })
Assert-True (($emptyHints -join ',') -eq ($noHints[0] -join ',')) 'an EMPTY hints table is the stride too, not a pack that puts everything in shard 1'

Write-Host "== the hints file: a bad one degrades to the stride rather than failing the gate ==" -ForegroundColor Cyan

$hintDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ci-shard-hints-$PID-$([guid]::NewGuid().ToString('n'))")
if (Test-Path -LiteralPath $hintDir) { Remove-Item -Recurse -Force -LiteralPath $hintDir }
New-Item -ItemType Directory -Path $hintDir -Force | Out-Null
$hintFile = Join-Path $hintDir 'suite-durations.json'

Assert-True ($null -eq (Get-TestSuiteCostHints -TestsDir $hintDir)) 'no file at all returns null -- the untouched path for a consumer'

Set-Content -LiteralPath $hintFile -Value '{ this is not json' -Encoding Ascii
Assert-True ($null -eq (Get-TestSuiteCostHints -TestsDir $hintDir -WarningAction SilentlyContinue)) 'unparseable JSON returns null rather than throwing'

Set-Content -LiteralPath $hintFile -Value '{ "note": "no seconds map here" }' -Encoding Ascii
Assert-True ($null -eq (Get-TestSuiteCostHints -TestsDir $hintDir -WarningAction SilentlyContinue)) 'a file with no seconds map returns null'

Set-Content -LiteralPath $hintFile -Value '{ "seconds": { "a.tests.ps1": "slow", "b.tests.ps1": 0, "c.tests.ps1": -4 } }' -Encoding Ascii
Assert-True ($null -eq (Get-TestSuiteCostHints -TestsDir $hintDir -WarningAction SilentlyContinue)) `
    'non-numeric, zero and negative entries are all dropped -- zero would sort a suite to the very back'

Set-Content -LiteralPath $hintFile -Value '{ "seconds": { "a.tests.ps1": 12.5, "b.tests.ps1": "slow" } }' -Encoding Ascii
$mixed = Get-TestSuiteCostHints -TestsDir $hintDir -WarningAction SilentlyContinue
Assert-True ($null -ne $mixed -and $mixed.Count -eq 1 -and $mixed['a.tests.ps1'] -eq 12.5) `
    'one bad entry does not discard the good ones beside it'
Remove-Item -Recurse -Force -LiteralPath $hintDir -ErrorAction SilentlyContinue

# THE GATE READS IT, AND THE COVER STILL HOLDS THROUGH A REAL RUN. Everything above is the pure function;
# this is the only assert that proves the gate actually calls it and still hands every file to a child.
$fixtureHints = Join-Path $fixtureDir 'suite-durations.json'
$fixtureCosts = [ordered]@{}
foreach ($n in $fixtureNames) { $fixtureCosts["$n.tests.ps1"] = 13 - [int]$n.Substring(1) }
@{ seconds = $fixtureCosts } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fixtureHints -Encoding Ascii
try {
    $hintedRuns = @(1..4 | ForEach-Object { Get-ShardRun -Shard $_ -ShardCount 4 })
    $hintedAll  = @($hintedRuns | ForEach-Object { $_.Ran })
    Assert-True ($hintedAll.Count -eq 12) "with a hints file present the four shards still run 12 suites (ran $($hintedAll.Count))"
    Assert-True (@($hintedAll | Sort-Object -Unique).Count -eq 12) 'and still exactly once each -- hints move suites between shards, never out of the pool'
    Assert-True ((($hintedRuns[0].Ran | Sort-Object) -join ',') -ne 's01,s05,s09') `
        'and the assignment is no longer the stride, which is the proof the gate read the file at all'
} finally {
    Remove-Item -LiteralPath $fixtureHints -Force -ErrorAction SilentlyContinue
}

Write-Host "== this repo's own durations file ==" -ForegroundColor Cyan

# FORMAT ONLY, AND DELIBERATELY NOT FRESHNESS. A stale entry is ignored and a missing one is charged the
# maximum, so neither can cost coverage -- gating on either would break the trunk the moment somebody
# adds or deletes a suite, to protect against a cost this design already absorbs. What IS worth an
# assert is that the file the gate reads on every CI run is still readable at all.
$realHints = Get-TestSuiteCostHints -TestsDir (Join-Path $repoRoot 'scripts\tests')
Assert-True ($null -ne $realHints) 'scripts/tests/suite-durations.json parses and holds usable durations'
if ($realHints) {
    Assert-True (@($realHints.Keys | Where-Object { $_ -notlike '*.tests.ps1' }).Count -eq 0) 'and every key names a suite file'
    Assert-True (@($realHints.Values | Where-Object { $_ -le 0 }).Count -eq 0) 'and every value is a positive number of seconds'
}
$realDoc = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\tests\suite-durations.json') -Raw | ConvertFrom-Json
Assert-True (@($realDoc.recordedFrom.runs).Count -gt 0) 'and it names the CI runs it was recorded from, so a reader can re-derive or age it'

if (Test-Path -LiteralPath $fixtureDir) { Remove-Item -Recurse -Force -LiteralPath $fixtureDir }

# ------------------------------------------------------------------------------------------------
Write-Host "== ci.yml: the matrix and -ShardCount agree ==" -ForegroundColor Cyan

# THE ONE MISMATCH NOTHING ELSE WOULD CATCH. Both numbers are read out of the workflow and compared, so
# changing the matrix without changing the flag fails here instead of running a fraction of the pool for
# ever. Derived, not hard-coded to 4: raising both together is a legitimate change and must stay green.
$matrixMatch = [regex]::Match($ci, '(?m)^\s*shard:\s*\[([0-9,\s]+)\]\s*$')
Assert-True ($matrixMatch.Success) 'ci.yml declares a shard matrix as a literal list'
$matrixEntries = @()
if ($matrixMatch.Success) {
    $matrixEntries = @($matrixMatch.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
# ANCHORED ON THE CALL, NOT ON THE FILE. The first version of this assert searched the whole workflow
# for '-ShardCount\s+(\d+)' and read the 5 out of the COMMENT that explains what a mismatch would do --
# so it reported a mismatch against a file that had none. Same trap the merge-queue suite's header names
# for `merge_group`: on a page where every rule is also explained in prose, a substring match reads the
# prose. The number that matters is the one on the line that invokes the gate.
$countMatch = [regex]::Match($ci, 'Invoke-TestSuiteGate[^\r\n]*-ShardCount\s+(\d+)')
Assert-True ($countMatch.Success) 'and passes -ShardCount on the line that calls the gate'
Assert-True ($matrixMatch.Success -and $countMatch.Success -and [int]$countMatch.Groups[1].Value -eq $matrixEntries.Count) `
    "-ShardCount ($(if ($countMatch.Success) { $countMatch.Groups[1].Value } else { '?' })) equals the matrix length ($($matrixEntries.Count))"
Assert-True (($matrixEntries | Sort-Object { [int]$_ }) -join ',' -eq (1..$matrixEntries.Count -join ',')) `
    'and the matrix is 1..N with no gaps -- the gate refuses anything else, but it would refuse it in CI'
Assert-True ($ci -match '-Shard \$\{\{ matrix\.shard \}\}') 'each entry passes its own shard number through'

Write-Host "== ci.yml: the required check is the summary job, and it fails closed ==" -ForegroundColor Cyan

# THE NAME. `main-ci-gate` requires the context 'lint-en-tests'; GitHub names a check after its job.
Assert-True ($ci -match '(?m)^  lint-en-tests:\s*$') 'a job named lint-en-tests still exists -- the required context is reported'
Assert-True ($ci -match '(?m)^  suites:\s*$') 'the suites job carries the pool'
Assert-True ($ci -match '(?m)^  lint:\s*$') 'and the lint keeps a job of its own, run once rather than once per shard'

# Extract the summary job by its own key, so the asserts below cannot be satisfied by text elsewhere in
# the file -- the mistake the merge-queue suite's own header warns about.
$summaryJob = [regex]::Match($ci, '(?ms)^  lint-en-tests:\s*$(?<body>.*)\z')
Assert-True ($summaryJob.Success) 'the summary job block is readable'
$summary = if ($summaryJob.Success) { $summaryJob.Groups['body'].Value } else { '' }

Assert-True ($summary -match '(?m)^\s*needs:\s*\[\s*lint\s*,\s*suites\s*\]') 'it needs both legs'
Assert-True (($summary -match '(?m)^\s*if:\s*\$\{\{\s*!cancelled\(\)\s*\}\}') -and ($summary -notmatch '(?m)^\s*if:\s*always\(\)')) `
    'runs with if: !cancelled(), not always() -- true on a failed/skipped leg so a red shard still reports red, false only on a cancelled run where always() would report a superseded PR run as failure (#1356)'
Assert-True ($summary -match 'needs\.lint\.result') 'it reads the lint result'
Assert-True ($summary -match 'needs\.suites\.result') 'and the suites result'
Assert-True ($summary -match 'exit 1') 'and exits non-zero on a leg that did not succeed'

# STRICT SUCCESS, both legs. A comparison against 'failure' would pass a skipped or cancelled leg, which
# is the same silence in a different coat.
Assert-True ($summary -match '"\$\{\{ needs\.lint\.result \}\}"\s*!=\s*"success"') 'the lint leg is required to be success, not merely not-failure'
Assert-True ($summary -match '"\$\{\{ needs\.suites\.result \}\}"\s*!=\s*"success"') 'and so is the suites leg'
Assert-True ($summary -notmatch '!=\s*["'']failure') 'no leg is judged by "not failure", which would accept skipped and cancelled'

# It must not become a job that does work -- if it ever needs a checkout or a script, the reasoning for
# putting it on ubuntu (and for it being cheap) has changed and should be re-read rather than patched.
Assert-True ($summary -notmatch 'actions/checkout') 'the summary job checks nothing out -- it compares two strings'
Assert-True ($summary -match 'runs-on: ubuntu-latest') 'and runs on ubuntu, which the file header explains'

Write-Host "== ci.yml: what sharding must NOT have changed ==" -ForegroundColor Cyan

# #1300's fold shortcut stays on the STEP. On the job it would make needs.suites.result legitimately
# 'skipped' on a fold commit, and the summary would then have to accept a non-success from that leg.
$suitesJob = [regex]::Match($ci, '(?ms)^  suites:\s*$(?<body>.*?)(?=^  lint-en-tests:\s*$)')
Assert-True ($suitesJob.Success) 'the suites job block is readable'
$suitesBody = if ($suitesJob.Success) { $suitesJob.Groups['body'].Value } else { '' }
Assert-True ($suitesBody -notmatch "(?m)^    if:") `
    'the fold-commit skip is NOT a job-level if: -- that would make a skipped leg legitimate'
Assert-True ($suitesBody -match "(?m)^        if:[^\r\n]*startsWith\(github\.event\.head_commit\.message,\s*'fold:'\)") `
    'it is still the step-level skip #1300 measured'
Assert-True ($suitesBody -match 'fail-fast: false') `
    'fail-fast is false -- a red shard must not cancel the other three, which is where the re-run evidence lives'

Write-Host "== ci.yml: the merge-commit certificate (#2303) ==" -ForegroundColor Cyan

# THE SAME STEP-LEVEL CONSTRAINT AS THE FOLD SHORTCUT, for the same reason: a job-level if: sourced from
# another job's output would make needs.suites.result legitimately 'skipped' on the overwhelming majority
# of runs (any PR, any non-merge push). The blanket job-level-if assert a few lines up already covers this
# (no '^    if:' anywhere in the suites job body); this reasserts it against the SPECIFIC line so a future
# refactor that moves only this condition is still caught.
Assert-True ($suitesBody -match "(?m)^        if:[^\r\n]*steps\.merge-suite-skip\.outputs\.skip\s*!=\s*'true'") `
    'the Test suites step also refuses on the merge-commit certificate output, at step level'

# THE STEP THAT COMPUTES IT: an id (so the Test suites step above can read its output), and it calls the
# dedicated script rather than growing an inline block the way the fold check never needed to.
Assert-True ($suitesBody -match "(?m)^      - name: Merge-commit certificate[^\r\n]*$") `
    'the certificate step exists'
Assert-True ($suitesBody -match "(?m)^        id: merge-suite-skip\s*$") `
    'and carries the id the Test suites step reads'
Assert-True ($suitesBody -match 'scripts[\\/]ci[\\/]get-merge-suite-skip\.ps1') `
    'and calls the dedicated script rather than an inline block'
Assert-True ($suitesBody -match 'GH_TOKEN:\s*\$\{\{\s*github\.token\s*\}\}') `
    'with a token so its gh calls can authenticate'

# THE CHECKOUT IS DEEPENED ONLY ON THE ONE PUSH THAT NEEDS IT. A bare 'fetch-depth: 0' on every run would
# pay a full clone on every PR and every ordinary push -- the overwhelming majority -- for a read only a
# 'merge: ' push ever makes.
Assert-True ($suitesBody -match 'fetch-depth:\s*"\$\{\{[^\r\n]*startsWith\(github\.event\.head_commit\.message,\s*''merge: ''\)[^\r\n]*&&\s*''0''\s*\|\|\s*''1''[^\r\n]*\}\}"') `
    'the checkout deepens to full history only when the subject is a merge: commit, and stays shallow otherwise'

# THE FALSY-ZERO TRAP, GUARDED -- issue #2312, measured on the merge commit for #2303 itself: GitHub
# Actions expressions treat the NUMBER 0 as falsy, so 'cond && 0 || 1' evaluates the true branch to 0,
# which is itself falsy, and the || silently falls through to 1 regardless of cond. fetch-depth then
# never receives 0, so the certificate step's own history walk fails closed on EVERY merge commit --
# fail-closed, so never unsafe, but the whole saving #2303 exists for never fires. The fix is quoting
# both arms as strings, and this assert pins that a bare, unquoted 0 or 1 never returns to this line.
Assert-True ($suitesBody -notmatch 'fetch-depth:\s*"\$\{\{[^\r\n]*&&\s*0\b') `
    'fetch-depth''s true branch is never a bare number 0 -- that is the falsy-zero trap that made this line a no-op on the one push it exists for'

# READ-ONLY PERMISSIONS WIDER THAN THE WORKFLOW LEVEL, SCOPED TO THIS JOB ALONE -- the certificate step
# reads a merged PR's checks and the Actions runs behind them, which contents: read cannot reach.
Assert-True ($suitesBody -match '(?m)^    permissions:\s*$') 'the suites job states its own permissions block'
foreach ($scope in @('contents: read', 'checks: read', 'pull-requests: read', 'actions: read')) {
    Assert-True ($suitesBody -match [regex]::Escape($scope)) "and grants '$scope'"
}
Assert-True ($suitesBody -notmatch '(?m)^\s+\w[\w-]*:\s*write\s*$') `
    'no permission in the suites job is write -- the certificate step only reads'

# The gate is still the shared one (#512), and CI still does not walk scripts/tests itself.
Assert-True ($ci -match 'Invoke-TestSuiteGate') 'CI still calls the shared gate rather than a copy of its loop'
Assert-True ($ci -notmatch 'Get-ChildItem[^\r\n]*tests') 'and still does not glob the suites itself'
Assert-True ($ci -match '(?m)^\s{2}merge_group:') 'the merge_group trigger survived the restructure (#1325 prerequisite 1)'
Assert-True ($ci -like '*#1351*') 'and the file cites the issue whose measurement explains the shape'

Write-Host "== ci.yml: the banner above jobs: stays an orphan nobody appends to (#2314) ==" -ForegroundColor Cyan

# THE ONLY COMMENT RUN IN ci.yml THAT BELONGS TO NO KEY, which is exactly why it grew. Every other run
# sits above a key and is bounded by that key's subject; this one had no owner, so a paragraph about any
# job landed here -- and two branches appending to one anchor conflict pairwise, by construction. Three
# CI branches in one afternoon did (#2296, #2303, #2304), and the cost was never the resolution but the
# forty minutes of CI laps it took to discover. Same shape as #1255 one file over.
#
# A CEILING, NOT A BAN. What legitimately belongs here is what is true of the FILE -- why there are three
# jobs, and that every job declares a timeout at all -- and that is two subjects, so a ceiling is the
# check that admits them and refuses a third. 40 is derived, not chosen for roundness: this run measured
# 87 lines before #2314 and 32 after, so the ceiling is the post-change reading plus one paragraph of
# headroom, and still under half of what it had reached. Re-measure it here if a genuinely file-wide
# decision ever needs the room; do NOT raise it to admit a paragraph that has a key of its own.
$ciLines = @($ci -split '\r?\n')
$jobsIdx = -1
for ($i = 0; $i -lt $ciLines.Count; $i++) { if ($ciLines[$i] -match '^jobs:\s*$') { $jobsIdx = $i; break } }
Assert-True ($jobsIdx -ge 0) 'ci.yml declares a top-level jobs: key'

# GUARDED ON THE KEY BEING THERE, so the degrade path is SILENT rather than green. Without it a file
# with no `jobs:` leaves $jobsIdx at -1, the walk starts below the array and never runs, and the ceiling
# assert reports a measured 0 -- a PASS from a check that measured nothing, which is the exact class
# ci.yml's own `!cancelled()` paragraph is about. The assert above is what fails in that case.
if ($jobsIdx -ge 0) {
    $bannerLines = 0
    for ($i = $jobsIdx - 1; $i -ge 0 -and $ciLines[$i] -match '^#'; $i--) { $bannerLines++ }
    Assert-True ($bannerLines -le 40) `
        "the comment run directly above jobs: is $bannerLines lines, at or under the 40-line ceiling -- a paragraph that argues ONE key belongs above that key, not here (#2314)"
}

# AND THE CONVENTION IS WRITTEN DOWN IN THE FILE ITSELF, not only here. A ceiling that fires without
# saying what to do instead sends the next author to raise the ceiling -- which is the one repair that
# reopens the class. The file's own head states where a decision is argued; this pins that it still does.
Assert-True ($ci -match '(?m)^# WHERE A DECISION IS ARGUED: DIRECTLY ABOVE THE KEY IT DECIDES') `
    'ci.yml states the per-anchor convention in its own head, so the ceiling above has somewhere to point'
Assert-True ($ci -like '*#2314*') 'and cites the issue that measured the collision'

# ------------------------------------------------------------------------------------------------
Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
