<#
.SYNOPSIS
    Tests for scripts/lib/fetch-attempt-lib.ps1 -- the record of which remote was fetched, at which
    scope, and how it went.

.DESCRIPTION
    This lib decides whether a script may SKIP a network call, so every way it can be wrong is
    asymmetric in the same direction as gate-lib's: a false negative costs one `git fetch`, a false
    positive makes a check read refs nobody refreshed. Most of what is asserted here is therefore that
    a skip is REFUSED.

    THE PROPERTY THAT WOULD BREAK SILENTLY IS THAT A SUCCESS NEVER EXCUSES A FETCH. #1860 reports two
    things -- a duplicated ~700ms and a doubled worst-case stall -- and the symmetric seam that fixes
    both was built first. new-branch.tests.ps1 refused it: cases (v) and (y1) reproduce two runs
    seconds apart with another session's push in between, which is precisely the interval a freshness
    window covers and precisely the event #1139 and #1439 exist to see. So the skip is failure-only,
    and case 3 is the assert that keeps it that way -- it is the one a later "optimisation" would
    delete first.

    THE SECOND PROPERTY IS THE FAILURE CARRY, which is the half that is not about milliseconds. A
    fetch that TIMES OUT never writes FETCH_HEAD, so the obvious implementation -- read FETCH_HEAD's
    age -- leaves the doubled stall ceiling exactly where it was while taking on the correctness cost
    above. What halves it is remembering the failed ATTEMPT. Case 7 is that.

    THE THIRD IS THE SCOPE MODEL. `git fetch origin main` can fail for a reason that is about that ref
    -- "couldn't find remote ref main" -- and says nothing about whether the remote would answer a
    wide fetch. Letting the narrow failure suppress the wide one invents an outage rather than
    reporting one. Case 5 is both directions of that, against a real remote.

    A REAL GIT REPOSITORY PER CASE, NOT A STUB, and a real LOCAL bare remote to fetch from. The lib's
    whole job is to be right about what git does, so a fake would prove only that the parser agrees
    with the fake -- and a local bare remote makes a genuine `git fetch` offline and fast. Each
    fixture is a genuine `git init` under the temp directory, keyed on $PID so concurrent suites
    cannot collide (the gate runs these in parallel).

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$LibPath     = Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1'
$CapturePath = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'

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
function Assert-Has {
    param([string]$Haystack, [string]$Needle, [string]$Label)
    Assert-True ($Haystack -like "*$Needle*") $Label
}

Assert-True (Test-Path -LiteralPath $LibPath) 'fetch-attempt-lib.ps1 exists at its registered source path'
. $CapturePath
. $LibPath

$FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "fetch-attempt-tests-$PID-$([guid]::NewGuid().ToString('n'))"
$script:seq  = 0
$script:trees = @()

function Invoke-FixtureGit {
    <#
        Git MUTATIONS inside a fixture, run under EAP=Continue -- the repo's standing pitfall: `git add`
        writes its autocrlf notice to stderr, which under EAP=Stop becomes a terminating
        NativeCommandError even though git exits 0.
    #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # A push whose transport breaks under the parallel gate is retried once (issue #2481).
        Invoke-FixtureGitNative -Arguments @($GitArgs)
    } finally { $ErrorActionPreference = $prev }
}

function New-RemoteFixture {
    <#
        A checkout with a LOCAL bare origin it can really fetch from, plus a second clone that can push
        new refs into that origin -- which is what makes "a branch somebody else pushed" reproducible
        without a network.
    #>
    $script:seq++
    $dir  = Join-Path $FixtureRoot "repo-$($script:seq)"
    $bare = Join-Path $FixtureRoot "origin-$($script:seq).git"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Invoke-FixtureGit 'init' '--quiet' $dir
    Invoke-FixtureGit '-C' $dir 'config' 'user.email' 'fixture@example.com'
    Invoke-FixtureGit '-C' $dir 'config' 'user.name'  'Fixture'
    Invoke-FixtureGit '-C' $dir 'config' 'core.autocrlf' 'false'
    Invoke-FixtureGit '-C' $dir 'config' 'commit.gpgsign' 'false'
    Set-Content -LiteralPath (Join-Path $dir 'README.md') -Value 'baseline' -Encoding ascii
    Invoke-FixtureGit '-C' $dir 'add' '-A'
    Invoke-FixtureGit '-C' $dir 'commit' '-m' 'baseline' '--quiet'
    Invoke-FixtureGit '-C' $dir 'branch' '-M' 'main'
    Invoke-FixtureGit 'init' '--bare' '--quiet' $bare
    Invoke-FixtureGit '-C' $bare 'symbolic-ref' 'HEAD' 'refs/heads/main'
    Invoke-FixtureGit '-C' $dir 'remote' 'add' 'origin' $bare
    Invoke-FixtureGit '-C' $dir 'push' '--quiet' '-u' 'origin' 'main'

    $script:trees += @($dir, $bare)
    return [pscustomobject]@{ Dir = $dir; Bare = $bare }
}

function Push-SideBranch {
    <# A branch pushed into origin by somebody who is not this checkout -- the #1139 shape. #>
    param([Parameter(Mandatory)]$Fixture, [Parameter(Mandatory)][string]$Name)
    $script:seq++
    $side = Join-Path $FixtureRoot "side-$($script:seq)"
    Invoke-FixtureGit 'clone' '--quiet' $Fixture.Bare $side
    Invoke-FixtureGit '-C' $side 'config' 'user.email' 'other@example.com'
    Invoke-FixtureGit '-C' $side 'config' 'user.name'  'Other'
    Invoke-FixtureGit '-C' $side 'config' 'commit.gpgsign' 'false'
    Invoke-FixtureGit '-C' $side 'checkout' '--quiet' '-b' $Name
    Set-Content -LiteralPath (Join-Path $side 'side.txt') -Value 'from elsewhere' -Encoding ascii
    Invoke-FixtureGit '-C' $side 'add' '-A'
    Invoke-FixtureGit '-C' $side 'commit' '-m' 'side work' '--quiet'
    Invoke-FixtureGit '-C' $side 'push' '--quiet' 'origin' $Name
    $script:trees += $side
}

function Test-RefExists {
    param([string]$Dir, [string]$Ref)
    $probe = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $Dir, 'rev-parse', '--verify', '--quiet', $Ref) -DiscardStderr
    return ($probe -and $probe.ExitCode -eq 0)
}

try {

Write-Host "`n-- 1. the scope strings, and which covers which --" -ForegroundColor Cyan

Assert-Equal 'all'      (Get-RemoteFetchScope)               '1a: no refspec is the remote''s configured refspec -- "all"'
Assert-Equal 'ref:main' (Get-RemoteFetchScope -Refspec 'main') '1b: a refspec narrows the scope and names the ref'

Assert-True  (Test-RemoteFetchScopeCovers -Recorded 'all' -Requested 'all')           '1c: all covers all'
Assert-True  (Test-RemoteFetchScopeCovers -Recorded 'all' -Requested 'ref:main')      '1d: all covers a narrow request'
Assert-True  (Test-RemoteFetchScopeCovers -Recorded 'ref:main' -Requested 'ref:main') '1e: a narrow scope covers itself'
Assert-True  (-not (Test-RemoteFetchScopeCovers -Recorded 'ref:main' -Requested 'all')) '1f: a narrow scope does NOT cover an all-refs request -- a per-ref failure is not an outage'
Assert-True  (-not (Test-RemoteFetchScopeCovers -Recorded 'ref:main' -Requested 'ref:other')) '1g: one narrow scope does not cover another'
Assert-True  (-not (Test-RemoteFetchScopeCovers -Recorded '' -Requested 'all'))       '1h: an absent record covers nothing'

Write-Host "`n-- 2. a cold fetch runs, records, and reports fresh --" -ForegroundColor Cyan

$fx = New-RemoteFixture
$r = Invoke-RecordedRemoteFetch -RepoRoot $fx.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $r.Ran           '2a: with no record at all, the fetch runs'
Assert-True (-not $r.Skipped) '2b: ...and nothing is skipped'
Assert-True $r.Fresh         '2c: a fetch that exits 0 reports Fresh'
Assert-Equal ''  $r.Note     '2d: nothing to say on the happy path'

$stamp = Read-RemoteFetchStamp -RepoRoot $fx.Dir
Assert-True   ($null -ne $stamp) '2e: the attempt is recorded'
Assert-Equal  'origin' $stamp.remote '2f: ...under the remote it named'
Assert-Equal  'all'    $stamp.scope  '2g: ...at the scope it fetched'
Assert-Equal  'True'   $stamp.ok     '2h: ...with the outcome'

Write-Host "`n-- 3. A SUCCESS NEVER EXCUSES A FETCH -- the assert that holds the whole design --" -ForegroundColor Cyan

# THE ONE A LATER "OPTIMISATION" WOULD DELETE FIRST, so it carries its reason. Skipping here would
# remove the duplicated ~700ms #1860 reports -- and blind new-branch's resume probe (#1139) and its
# remote-ahead note (#1439), both of which read refs refreshed by exactly this fetch and both of which
# exist to see a push made seconds ago by another session. new-branch.tests.ps1 (v) and (y1) are the
# behavioural half of this assert; this is the unit half.
$r2 = Invoke-RecordedRemoteFetch -RepoRoot $fx.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $r2.Ran           '3a: a SUCCESSFUL attempt seconds ago does not excuse this fetch'
Assert-True (-not $r2.Skipped) '3b: ...and nothing is reported as skipped'
Assert-True $r2.Fresh          '3c: ...so the refs really were refreshed, by this call'

Write-Host "`n-- 4. RecentFailureSeconds 0 -- the default -- never skips --" -ForegroundColor Cyan

$fx0 = New-RemoteFixture
Save-RemoteFetchStamp -RepoRoot $fx0.Dir -Remote 'origin' -Scope 'all' -Ok $false -Note 'git fetch exited 128' | Out-Null
$r3 = Invoke-RecordedRemoteFetch -RepoRoot $fx0.Dir -Remote 'origin'
Assert-True $r3.Ran            '4a: a caller that did not opt in fetches even against a fresh FAILURE'
Assert-True (-not $r3.Skipped) '4b: ...and is never told it was skipped'

Write-Host "`n-- 5. scope, against a real remote: a per-ref failure is not an outage --" -ForegroundColor Cyan

$fx2 = New-RemoteFixture
# A narrow failure first, so the record says 'ref:main' and ok=false.
Save-RemoteFetchStamp -RepoRoot $fx2.Dir -Remote 'origin' -Scope 'ref:main' -Ok $false `
                      -Note 'git fetch exited 128' -Detail @("fatal: couldn't find remote ref main") | Out-Null

# Somebody else pushes a branch. An all-refs request must NOT be suppressed by that narrow failure, or
# refs/remotes/origin/parked never comes into existence and #1139 reopens in silence.
Push-SideBranch -Fixture $fx2 -Name 'parked'
$n2 = Invoke-RecordedRemoteFetch -RepoRoot $fx2.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $n2.Ran '5a: a narrow failure does NOT suppress an all-refs fetch'
Assert-True (Test-RefExists -Dir $fx2.Dir -Ref 'refs/remotes/origin/parked') '5b: ...so the branch pushed elsewhere is visible afterwards'

# The reverse direction is the one that DOES carry: a wide failure is about reachability.
Save-RemoteFetchStamp -RepoRoot $fx2.Dir -Remote 'origin' -Scope 'all' -Ok $false -Note 'git fetch exited 128' | Out-Null
$n3 = Invoke-RecordedRemoteFetch -RepoRoot $fx2.Dir -Remote 'origin' -Refspec 'main' -RecentFailureSeconds 90
Assert-True $n3.Skipped      '5c: a wide failure DOES suppress a narrow retry -- the remote did not answer at all'
Assert-True (-not $n3.Fresh) '5d: ...and it is not fresh, because nothing was refreshed'

Write-Host "`n-- 6. the record is keyed on the remote, not on "a fetch failed" --" -ForegroundColor Cyan

$fx3 = New-RemoteFixture
Save-RemoteFetchStamp -RepoRoot $fx3.Dir -Remote 'upstream' -Scope 'all' -Ok $false -Note 'git fetch exited 128' | Out-Null
$o = Invoke-RecordedRemoteFetch -RepoRoot $fx3.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $o.Ran '6a: a failure recorded for ANOTHER remote does not suppress this one'

Write-Host "`n-- 7. the failure carry -- the half that halves the stall --" -ForegroundColor Cyan

$fx4 = New-RemoteFixture
Save-RemoteFetchStamp -RepoRoot $fx4.Dir -Remote 'origin' -Scope 'all' -Ok $false `
                      -Note 'git fetch did not answer within 120 seconds' `
                      -Detail @('fatal: could not read from remote repository') | Out-Null
$f = Invoke-RecordedRemoteFetch -RepoRoot $fx4.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True  $f.Skipped        '7a: a FAILED attempt seconds ago is reported rather than repeated'
Assert-True  (-not $f.Ran)     '7b: ...which is the whole point -- no second two-minute bound is paid'
Assert-True  (-not $f.Fresh)   '7c: ...and it is NOT fresh, because nothing was refreshed'
Assert-Has   $f.Note 'did not answer within 120 seconds' '7d: the recorded reason is carried, not re-derived'
Assert-Has   $f.Note 'not retried' '7e: ...and says it was not retried, so the reader knows whose attempt this was'
Assert-Has   ($f.Output -join '|') 'could not read from remote repository' '7f: git''s own lines travel with it -- the credential-versus-network distinction (#1313)'

Write-Host "`n-- 8. a stale record is no record --" -ForegroundColor Cyan

$fx5 = New-RemoteFixture
$path = Get-RemoteFetchStampPath -RepoRoot $fx5.Dir

# A record from the future is a clock that moved backwards, not a fresh one -- and it is the one value
# that would suppress every retry for ever.
$future = [ordered]@{ remote='origin'; scope='all'; ok=$false; note='git fetch exited 128'; detail=@(); recordedAt=([datetime]::UtcNow.AddHours(1).ToString('o')) }
[System.IO.File]::WriteAllText($path, ($future | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
$fut = Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $fut.Ran '8a: a record dated in the future is refused rather than trusted for ever'

# An old failure is simply old: the operator has had time to fix their network, so the retry is worth
# making. That is what bounds the window rather than what argues against it.
$old = [ordered]@{ remote='origin'; scope='all'; ok=$false; note='git fetch exited 128'; detail=@(); recordedAt=([datetime]::UtcNow.AddMinutes(-10).ToString('o')) }
[System.IO.File]::WriteAllText($path, ($old | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
$stale = Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $stale.Ran '8b: a failure older than the window is not consulted'

# AND A SUCCESS CLEARS A FAILURE INSIDE ITS OWN WINDOW. This is the only reason a success is recorded
# at all: without it a remote that came back would go on suppressing retries until the window expired.
$recent = [ordered]@{ remote='origin'; scope='all'; ok=$false; note='git fetch exited 128'; detail=@(); recordedAt=([datetime]::UtcNow.AddSeconds(-5).ToString('o')) }
[System.IO.File]::WriteAllText($path, ($recent | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
Assert-True (Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' -RecentFailureSeconds 90).Skipped '8c: the recent failure does suppress a retry'
Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' | Out-Null
Assert-True (Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' -RecentFailureSeconds 90).Ran '8d: ...and one successful fetch clears it, rather than the window having to expire'

# Garbage is "no record", which fails toward fetching.
[System.IO.File]::WriteAllText($path, 'not json at all', (New-Object System.Text.UTF8Encoding($false)))
Assert-True ($null -eq (Read-RemoteFetchStamp -RepoRoot $fx5.Dir)) '8e: a malformed record reads as no record'
$junk = Invoke-RecordedRemoteFetch -RepoRoot $fx5.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $junk.Ran '8f: ...and a run with no record fetches'

Write-Host "`n-- 9. the stamp is shared by the clone, not private to a worktree --" -ForegroundColor Cyan

$fx6 = New-RemoteFixture
$lane = Join-Path $FixtureRoot "lane-$($script:seq)"
Invoke-FixtureGit '-C' $fx6.Dir 'worktree' 'add' '--quiet' '-b' 'lane-branch' $lane
$script:trees += $lane
$primary = Get-RemoteFetchStampPath -RepoRoot $fx6.Dir
$inLane  = Get-RemoteFetchStampPath -RepoRoot $lane
Assert-Equal ([System.IO.Path]::GetFullPath($primary)) ([System.IO.Path]::GetFullPath($inLane)) '9a: a linked worktree resolves the SAME record -- whether a remote answered is a property of the clone'

Save-RemoteFetchStamp -RepoRoot $lane -Remote 'origin' -Scope 'all' -Ok $false -Note 'git fetch exited 128' | Out-Null
$afterLane = Invoke-RecordedRemoteFetch -RepoRoot $fx6.Dir -Remote 'origin' -RecentFailureSeconds 90
Assert-True $afterLane.Skipped '9b: ...so a failure the lane recorded reaches the primary checkout -- a remote that did not answer did not answer for either of them'

Write-Host "`n-- 10. the default remote is resolved, never guessed --" -ForegroundColor Cyan

$fx7 = New-RemoteFixture
Assert-Equal 'origin' (Get-DefaultFetchRemoteName -RepoRoot $fx7.Dir) '10a: a branch tracking origin resolves to origin'

# A checkout with no remote at all must resolve to nothing -- so nothing is recorded under a name
# that does not exist, and two unrelated failures cannot match each other.
$script:seq++
$bare2 = Join-Path $FixtureRoot "lonely-$($script:seq)"
New-Item -ItemType Directory -Force -Path $bare2 | Out-Null
Invoke-FixtureGit 'init' '--quiet' $bare2
Invoke-FixtureGit '-C' $bare2 'config' 'user.email' 'fixture@example.com'
Invoke-FixtureGit '-C' $bare2 'config' 'user.name'  'Fixture'
Invoke-FixtureGit '-C' $bare2 'config' 'commit.gpgsign' 'false'
Set-Content -LiteralPath (Join-Path $bare2 'a.txt') -Value 'x' -Encoding ascii
Invoke-FixtureGit '-C' $bare2 'add' '-A'
Invoke-FixtureGit '-C' $bare2 'commit' '-m' 'only' '--quiet'
$script:trees += $bare2
Assert-True ($null -eq (Get-DefaultFetchRemoteName -RepoRoot $bare2)) '10b: a checkout with no remote resolves to nothing rather than to "origin"'

Write-Host "`n-- 11. Get-TrunkGap is wired to the seam, and only new-branch opts in --" -ForegroundColor Cyan

$scaffold = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1') -Raw
Assert-Has $scaffold 'Invoke-RecordedRemoteFetch -RepoRoot $RepoRoot -Remote ''origin''' '11a: Get-TrunkGap fetches through the seam rather than calling git itself'
# -like, not -match: the literal here carries '[int]', whose brackets are a -like character class.
# Asserted on the half without them rather than by escaping, so the pattern reads as what it checks.
Assert-Has $scaffold '$RecentFailureSeconds = 0' '11b: ...and its window DEFAULTS to zero, so every existing caller is untouched'

$newBranch = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\task\new-branch.ps1') -Raw
Assert-Has $newBranch '-FetchAllRefs -RecentFailureSeconds $RemoteFetchRecentFailureSeconds' '11c: new-branch opts in, with the lib''s constant rather than a number typed here'

$fold = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\release\fold-changelog-entry.ps1') -Raw
Assert-True (-not ($fold -like '*RecentFailureSeconds*')) '11d: the fold does NOT opt in -- a refusal that commits to the trunk looks for itself'

# THE STDERR DECISION FOLLOWED THE CALL DOWN HERE (#1313, via #1860). A git call to a remote writes
# everything to stderr, git redacts the credential out of it itself, and nothing in this lib parses the
# capture -- so -DiscardStderr would buy nothing and cost the reader git's own reason on the one failure
# path an exit code cannot diagnose. claim-issue.tests.ps1 held this while the call was inline there.
$lib = Get-Content -LiteralPath $LibPath -Raw
$theFetch = if ($lib -match "(?s)(\`$fetch = if \(\`$TimeoutSeconds -gt 0\).*?\n\s*\})") { $Matches[1] } else { '' }
Assert-True ($theFetch -ne '') '11e: the lib''s own git fetch statement is findable'
Assert-True ($theFetch -notmatch '-DiscardStderr') '11f: ...and it keeps git''s own diagnosis (#1313)'

$claim = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\task\claim-issue.ps1') -Raw
Assert-Has $claim 'Invoke-RecordedRemoteFetch -RepoRoot $repoRoot -RecentFailureSeconds $RemoteFetchRecentFailureSeconds' '11g: claim-issue''s parked-fix fetch goes through the same seam'
Assert-True (-not ($claim -like "*'fetch', '--quiet'*")) '11h: ...and its hand-rolled fetch is gone, so there is one definition and not two'

} finally {
    if (Test-Path -LiteralPath $FixtureRoot) {
        # `git worktree add` marks its administrative files read-only on Windows; -Force is what lets
        # the tree go away rather than leaving a fixture per run under the temp directory.
        Remove-Item -LiteralPath $FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-FixtureGitSummary | Out-Null
Write-Host ""
$fixtureFailures = Get-FixtureGitFailureCount
if ($script:fail -gt 0 -or $fixtureFailures -gt 0) {
    Write-Host "FAILED: $($script:pass) passed, $($script:fail) failed, $fixtureFailures fixture command(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($script:pass) passed." -ForegroundColor Green
exit 0
