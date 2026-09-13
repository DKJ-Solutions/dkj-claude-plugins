<#
.SYNOPSIS
    Regression tests for scripts/lib/sync-rules.ps1 -- the queries dkj-subagents-shopify's pre-task sync is built
    on (inbound #787, extended with the merged-sync-branch case from #801 and the content rule from #807).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell and git.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/sync-rules.tests.ps1

    WHY THESE FUNCTIONS HAVE A SUITE AND THE SYNC ITSELF HAS A SMALLER ONE. The policy is one sentence
    either way, and it is not where the risk is. The risk is in the QUERIES that decide when it fires, and
    every one of them fails SILENTLY and in the losing direction:

      * Test-LiveContentIsOurs answering $false for content that IS ours sends the file to take-live, which
        overwrites the trunk. This is the one that decides who wins a file since inbound #807.
      * Get-GitRawBlobId disagreeing with git by one byte reports a changed file as UNCHANGED -- the drift
        is then never seen at all, which is the worst shape here.
      * Get-CrStrippedBytes regressing makes every line-ending-only difference read as third-party drift,
        so the sync captures pure noise and overwrites the trunk with all of it.
      * Get-SyncReferencePoint answering with a commit that is too RECENT, or $null while the caller
        carries on, no longer loses files by itself -- it costs the both-sides-moved check, which is the
        only thing the floor still decides.
      * Test-MainTouchedSince answering $false where the trunk has moved turns a conflict into a
        take-live.

    THE DELETION CASE IS THE HEADLINE, and it is here because the first hand-written implementation of
    this rule got it wrong: a deletion is also a touch, so a file the trunk REMOVED must answer $true, or
    the sync puts back a file somebody deleted on purpose. It reads as an edge case and is the ordinary
    one -- removing a section from a theme is how a theme changes.

    THE UNION PATTERN IS TESTED FROM BOTH SIDES. The shipped default matches the two spellings actually
    in use ('sync:' and 'Sync '), and a repo that narrows it through the seam must still be able to
    exclude the other -- so there is a case for the default matching both and a case for a narrowed
    pattern matching only one.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary, and two runs sharing one fixed temp path tear down each other's tree
    mid-assert.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\sync-rules.ps1')
# Convert-GitQuotedPath MOVED TO git-porcelain-lib.ps1 (issue #1689) and its asserts stayed here, so this
# suite loads that lib too. They stayed because the comment above them explains why they are UNIT asserts
# IN THIS SUITE: the property they pin is one sync-main.tests.ps1 cannot pin without mutating the shared
# console state, and moving them would separate that reasoning from the sibling suite that produced the
# flakiness. git-porcelain-lib.tests.ps1 owns the decoder's other half -- that ConvertTo-GitPorcelainPath
# now returns the decoded path -- rather than a second copy of these ten.
#
# A SUITE MAY DOT-SOURCE WHAT sync-rules.ps1 ITSELF MUST NOT. That file is dependency-free because the
# live-theme guard loads it on every command; a test script is not in that path.
. (Join-Path $RepoRoot 'scripts\lib\git-porcelain-lib.ps1')
# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

$script:pass = 0
$script:fail = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message -- expected '$Expected', got '$Actual'" -ForegroundColor Red }
}

function New-GitTree {
    <# A fresh repo with a local identity, autocrlf off and commit signing off -- identity so a machine
       with no global user.email does not fail here for a reason unrelated to the code under test,
       autocrlf so git's own CRLF warning never reaches stderr and trips the EAP guard, and
       commit.gpgsign false so a machine with signing on but a locked signing agent does not fail the
       fixture commit for the same unrelated reason (#1287). Same reasoning as every other git fixture
       in this directory. #>
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("syncrules-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    # Each call is JUDGED rather than piped to Out-Null (issue #1635): the helper keeps the same lowered
    # EAP for the same reason as before, and now says so when a fixture command fails.
    Invoke-FixtureGitJudged @('-C', $dir, 'init', '--quiet')
    Invoke-FixtureGitJudged @('-C', $dir, 'config', 'user.name', 'sync-rules test')
    Invoke-FixtureGitJudged @('-C', $dir, 'config', 'user.email', 'sync@test.invalid')
    Invoke-FixtureGitJudged @('-C', $dir, 'config', 'core.autocrlf', 'false')
    Invoke-FixtureGitJudged @('-C', $dir, 'config', 'commit.gpgsign', 'false')
    return $dir
}

function Add-Commit {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Message,
        [hashtable]$Write = @{},
        [string[]]$Delete = @()
    )
    foreach ($rel in $Write.Keys) {
        $target = Join-Path $Dir $rel
        $parent = Split-Path -Parent $target
        if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -LiteralPath $target -Value $Write[$rel] -Encoding ascii -NoNewline
    }
    foreach ($rel in $Delete) {
        $target = Join-Path $Dir $rel
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    Invoke-FixtureGitJudged @('-C', $Dir, 'add', '-A')
    Invoke-FixtureGitJudged @('-C', $Dir, 'commit', '-q', '-m', $Message)
    return ([string](& git -C $Dir rev-parse HEAD)).Trim()
}

function New-ReconcileTree {
    <# The state inbound #1945 starts from: a sync took the path once, the trunk has moved on since, and
       a third party has edited the same path on live. That is the both-sides-moved conflict, and the
       four shapes below differ only in what the operator commits next. #>
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = New-GitTree -Label $Label
    Add-Commit -Dir $dir -Message 'initial' -Write @{ 'sections/x.liquid' = 'v1' } | Out-Null
    Add-Commit -Dir $dir -Message 'sync: mirror the section from live' -Write @{ 'sections/x.liquid' = 'L1' } | Out-Null
    Add-Commit -Dir $dir -Message 'fix: trunk work on the section, merged but not pushed to live' -Write @{ 'sections/x.liquid' = 'T2' } | Out-Null
    return $dir
}

function Get-ReconcileVerdict {
    <# The three queries sync-main.ps1 asks per differing path, in its own order, so these asserts walk
       the real decision rather than Get-SyncFileVerdict's parameters chosen by hand. #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Live,
        [string]$Path = 'sections/x.liquid'
    )
    Push-Location -LiteralPath $Dir
    try {
        $ours    = Test-LiveContentIsOurs -Path $Path -LiveBytes ([System.Text.Encoding]::ASCII.GetBytes($Live))
        $base    = $null
        $touched = $false
        if (-not $ours) {
            $base = Get-SyncPathReferencePoint -Path $Path
            if ($base) { $touched = Test-MainTouchedSince -Since $base -Path $Path }
        }
        return (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $ours `
            -MainTouchedSinceFloor $touched -PathAgreementKnown ([bool]$base)).Action
    } finally { Pop-Location }
}

try {
    # --- The default pattern ------------------------------------------------------------------------
    Write-Host 'the default reference pattern'
    Assert-Equal '^[Ss]ync' (Get-SyncDefaultReferencePattern) 'default/pattern: the union of the two spellings in use'

    # --- The reference point ------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-SyncReferencePoint'

    $lower = New-GitTree -Label 'lower'
    Add-Commit -Dir $lower -Message 'initial'          -Write @{ 'a.txt' = 'a1' } | Out-Null
    $lowerSync = Add-Commit -Dir $lower -Message 'sync: live theme drift 2026-08-01' -Write @{ 'b.txt' = 'b1' }
    Add-Commit -Dir $lower -Message 'feat: something else' -Write @{ 'c.txt' = 'c1' } | Out-Null

    Push-Location -LiteralPath $lower
    try {
        $ref = Get-SyncReferencePoint
        Assert-Equal $lowerSync $ref.Ref  "ref/lower: 'sync:' is found"
        Assert-Equal 'sync'     $ref.Kind 'ref/lower: and reported as a sync commit rather than a tag'
    } finally { Pop-Location }

    $upper = New-GitTree -Label 'upper'
    Add-Commit -Dir $upper -Message 'initial' -Write @{ 'a.txt' = 'a1' } | Out-Null
    $upperSync = Add-Commit -Dir $upper -Message 'Sync main with live theme (a-store)' -Write @{ 'b.txt' = 'b1' }
    Add-Commit -Dir $upper -Message 'fix: unrelated' -Write @{ 'c.txt' = 'c1' } | Out-Null

    Push-Location -LiteralPath $upper
    try {
        $ref = Get-SyncReferencePoint
        Assert-Equal $upperSync $ref.Ref "ref/upper: 'Sync ' with a capital is found by the SAME default"
        # The whole reason the default is not '^sync'. A pattern that misses this spelling finds nothing,
        # falls through to the tag lookup, finds nothing there in a repo with no tags, and aborts on the
        # first run -- before the rule has ever protected anything.
        $narrow = Get-SyncReferencePoint -Pattern '^sync:'
        Assert-True ($null -eq $narrow) 'ref/upper: a narrowed pattern excludes it, so the seam genuinely narrows'
    } finally { Pop-Location }

    # Two syncs: the floor is the most recent one. This is also why a LOOSER pattern is the dangerous
    # direction -- it can only move the floor forward, and a floor that is too recent protects less.
    $two = New-GitTree -Label 'two'
    Add-Commit -Dir $two -Message 'initial'        -Write @{ 'a.txt' = 'a1' } | Out-Null
    Add-Commit -Dir $two -Message 'sync: the first' -Write @{ 'b.txt' = 'b1' } | Out-Null
    $second = Add-Commit -Dir $two -Message 'sync: the second' -Write @{ 'c.txt' = 'c1' }
    Push-Location -LiteralPath $two
    try {
        Assert-Equal $second (Get-SyncReferencePoint).Ref 'ref/two: the MOST RECENT sync commit is the floor'
    } finally { Pop-Location }

    # A MERGED SYNC BRANCH, WHICH IS THE WORST CASE THIS SUITE HOLDS (inbound #801). '--grep' matches any
    # LINE of a message, and a merge commit carries the merged commit's subject in its body -- so the
    # merge matches the pattern, and right after a sync PR lands that merge is HEAD. A floor on HEAD makes
    # Test-MainTouchedSince answer $false for every path, so every both-sides-moved conflict is taken as
    # 'take-live' rather than reported, while printing a reference point as though all were well. Both
    # halves are asserted: that the shipped lookup skips the merge, AND that the old '--grep' lookup
    # genuinely picks it -- so that shape cannot come back later as a cheaper equivalent. What EXCLUDES
    # the merge changed with #819: the subject-anchored lookup does it, because a merge's own subject is
    # 'merge:'. See ref/chatty below for the case '--no-merges' never reached.
    $merged = New-GitTree -Label 'merged'
    Add-Commit -Dir $merged -Message 'initial' -Write @{ 'a.txt' = 'a1' } | Out-Null
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $trunkName = ([string](& git -C $merged rev-parse --abbrev-ref HEAD)).Trim()
    } finally { $ErrorActionPreference = $prevEap }
    Invoke-FixtureGitJudged @('-C', $merged, 'checkout', '-q', '-b', 'sync/live-2026-08-20')
    $syncOnBranch = Add-Commit -Dir $merged -Message 'sync: mirror in-flight third-party edits from live (2 file(s))' -Write @{ 'b.txt' = 'b1' }
    Invoke-FixtureGitJudged @('-C', $merged, 'checkout', '-q', $trunkName)
    # Two -m flags: the first is the subject, the second the body -- the shape gh writes for a merge.
    Invoke-FixtureGitJudged @('-C', $merged, 'merge', '--no-ff', '-q', 'sync/live-2026-08-20',
        '-m', 'merge: sync/live-2026-08-20 (#27)',
        '-m', 'sync: mirror in-flight third-party edits from live (2 file(s))')
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $mergeSha = ([string](& git -C $merged rev-parse HEAD)).Trim()
    } finally { $ErrorActionPreference = $prevEap }

    Push-Location -LiteralPath $merged
    try {
        Assert-True ($mergeSha -ne $syncOnBranch) 'ref/merged: the merge commit really is HEAD (fixture sanity)'
        Assert-Equal $syncOnBranch (Get-SyncReferencePoint).Ref 'ref/merged: the floor is the SYNC commit, not the merge that brought it in'

        # The regression half, and note WHAT it now protects (#819). It used to be labelled "so the
        # flag is load-bearing", which was true of the '--grep' lookup and is no longer the reason
        # this fixture passes: the subject-anchored lookup excludes the merge because its SUBJECT is
        # 'merge:', with or without the flag. Kept and relabelled rather than deleted, because the
        # thing it actually pins survives the change -- the '--grep' shape is measurably wrong here,
        # so nobody can restore it as a cheaper equivalent.
        $unrepaired = Invoke-SyncGitQuiet log -1 --format=%H "--grep=$(Get-SyncDefaultReferencePattern)" 'HEAD' |
            Where-Object { $_ } | Select-Object -First 1
        Assert-Equal $mergeSha ([string]$unrepaired).Trim() 'ref/merged: the OLD --grep shape picks the merge, so it cannot come back'
    } finally { Pop-Location }

    # AN ORDINARY COMMIT THAT MERELY TALKS ABOUT A SYNC (inbound #819). This is the case '--no-merges'
    # does not reach and had no coverage: one parent, subject 'fix:', and a BODY line opening with
    # 'sync'. '--grep' is line-oriented over the whole message, so the old lookup made it the floor --
    # newer than the real sync, which means fewer files protected and merged trunk work overwritten by
    # live, on a run that reports a reference point and looks green. Measured in the consumer that had
    # already taken the '--no-merges' repair: floor..HEAD went from 13 commits to 5.
    $chatty = New-GitTree -Label 'chatty'
    Add-Commit -Dir $chatty -Message 'initial' -Write @{ 'a.txt' = 'a1' } | Out-Null
    $realSync = Add-Commit -Dir $chatty -Message 'sync: live theme drift 2026-08-21' -Write @{ 'b.txt' = 'b1' }
    $chattyFix = Add-Commit -Dir $chatty -Write @{ 'c.txt' = 'c1' } -Message @'
fix: a sync PR states what a third party did, renames included

sync-main.tests.ps1 goes from 20 to 32 asserts. One earns its place twice: the
'@

    Push-Location -LiteralPath $chatty
    try {
        Assert-True ($chattyFix -ne $realSync) 'ref/chatty: the talkative commit is newer than the real sync (fixture sanity)'
        Assert-Equal $realSync (Get-SyncReferencePoint).Ref 'ref/chatty: the floor is the real sync, not the fix: commit that mentions one in its body'
        Assert-Equal 'sync'    (Get-SyncReferencePoint).Kind 'ref/chatty: and it is still reported as a sync floor'

        # The regression half, and the one that shows '--no-merges' was never enough: it is passed here
        # and changes nothing, because this commit has exactly one parent.
        $unrepaired = Invoke-SyncGitQuiet log -1 --no-merges --format=%H "--grep=$(Get-SyncDefaultReferencePattern)" 'HEAD' |
            Where-Object { $_ } | Select-Object -First 1
        Assert-Equal $chattyFix ([string]$unrepaired).Trim() 'ref/chatty: WITH --no-merges the --grep lookup still picks the body line, so the flag was necessary and not sufficient'
    } finally { Pop-Location }

    # The seam still narrows, on the SUBJECT now. The pattern reaches exactly as far as it always did;
    # only where it is applied changed, and a consumer that narrows it must still get $null rather than
    # a quietly wider match.
    Push-Location -LiteralPath $chatty
    try {
        Assert-True ($null -eq (Get-SyncReferencePoint -Pattern '^Sync ')) 'ref/chatty: a narrowed pattern that no SUBJECT matches answers $null, not the body line'
    } finally { Pop-Location }

    # No sync commit, but a tag: a wider window, and worth reporting as such.
    $tagged = New-GitTree -Label 'tagged'
    Add-Commit -Dir $tagged -Message 'initial' -Write @{ 'a.txt' = 'a1' } | Out-Null
    Invoke-FixtureGitJudged @('-C', $tagged, 'tag', 'v1.0.0')
    Add-Commit -Dir $tagged -Message 'feat: after the tag' -Write @{ 'b.txt' = 'b1' } | Out-Null
    Push-Location -LiteralPath $tagged
    try {
        $ref = Get-SyncReferencePoint
        Assert-Equal 'v1.0.0' $ref.Ref  'ref/tagged: the newest tag is the fallback floor'
        Assert-Equal 'tag'    $ref.Kind 'ref/tagged: and it says so, because a tag window is wider'
    } finally { Pop-Location }

    # Neither: $null, so the caller refuses. THE ONE THAT MATTERS MOST -- without a floor every file
    # looks untouched by the trunk, so the exclusion rule would pass everything through and the failure
    # would arrive as a green run.
    $bare = New-GitTree -Label 'bare'
    Add-Commit -Dir $bare -Message 'initial' -Write @{ 'a.txt' = 'a1' } | Out-Null
    Push-Location -LiteralPath $bare
    try {
        Assert-True ($null -eq (Get-SyncReferencePoint)) 'ref/bare: no sync commit and no tag answers $null, not a guess'
    } finally { Pop-Location }

    # --- The exclusion query ------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Test-MainTouchedSince'

    $rule = New-GitTree -Label 'rule'
    Add-Commit -Dir $rule -Message 'initial' -Write @{
        'changed.txt' = 'v1'; 'deleted.txt' = 'v1'; 'untouched.txt' = 'v1'; 'with space.txt' = 'v1'
    } | Out-Null
    $floor = Add-Commit -Dir $rule -Message 'sync: the floor' -Write @{ 'floor.txt' = 'v1' }
    Add-Commit -Dir $rule -Message 'trunk: change one file'  -Write  @{ 'changed.txt' = 'v2' } | Out-Null
    Add-Commit -Dir $rule -Message 'trunk: delete one file'  -Delete @('deleted.txt') | Out-Null
    Add-Commit -Dir $rule -Message 'trunk: add one file'     -Write  @{ 'added.txt' = 'v1' } | Out-Null
    Add-Commit -Dir $rule -Message 'trunk: touch a spaced path' -Write @{ 'with space.txt' = 'v2' } | Out-Null

    Push-Location -LiteralPath $rule
    try {
        Assert-True     (Test-MainTouchedSince -Since $floor -Path 'changed.txt')   'rule/changed: a modified file is touched'
        Assert-True     (Test-MainTouchedSince -Since $floor -Path 'added.txt')     'rule/added: a file the trunk added is touched, so live must not delete it'
        # THE CASE THE FIRST IMPLEMENTATION GOT WRONG.
        Assert-True     (Test-MainTouchedSince -Since $floor -Path 'deleted.txt')   'rule/deleted: A DELETION IS ALSO A TOUCH -- live must not resurrect it'
        Assert-True     (Test-MainTouchedSince -Since $floor -Path 'with space.txt') 'rule/spaced: a path with a space is measured, not mangled'
        Assert-True (-not (Test-MainTouchedSince -Since $floor -Path 'untouched.txt')) 'rule/untouched: an untouched file is live''s to overwrite'
        # A path that has never existed writes to stderr while being an ordinary "no". Under EAP=Stop that
        # is a terminating NativeCommandError unless the lib lowers it, which is what Invoke-SyncGitQuiet
        # is for -- so this case tests the wrapper as much as the answer.
        Assert-True (-not (Test-MainTouchedSince -Since $floor -Path 'never-existed.txt')) 'rule/absent: a path that never existed answers $false without throwing'
        # The floor itself is exclusive: the sync commit is not "since the sync commit".
        Assert-True (-not (Test-MainTouchedSince -Since $floor -Path 'floor.txt')) 'rule/floor: the reference commit''s own change is not counted as later work'
    } finally { Pop-Location }

    # --- The base is PER PATH (inbound #1535) -------------------------------------------------------
    # THE SHAPE THE CONSUMER MEASURED, rebuilt with the smallest history that carries it. A sync commit
    # establishes agreement with live only for the paths it actually TOOK; the defect was taking the most
    # recent sync GLOBALLY and asking "has the trunk moved since" against it for every path. For a path
    # that sync never touched, that base simply post-dates the trunk's own work -- so the trunk read as
    # stationary and live was taken over it, on a green run.
    #
    # The fixture is the report's own ordering: own work on a path, and then a sync that takes a
    # DIFFERENT path. In the consumer that sync took 167 files and none of the six was among them.
    Write-Host ''
    Write-Host 'Get-SyncPathReferencePoint'

    $perPath = New-GitTree -Label 'perpath'
    Add-Commit -Dir $perPath -Message 'initial' -Write @{
        'locales/nl.json'         = '{"a":1}'
        'sections/header.liquid'  = 'h1'
        'snippets/dropped.liquid' = 'd1'
    } | Out-Null
    $syncTookHeader = Add-Commit -Dir $perPath -Message 'sync: mirror the header from live' -Write @{ 'sections/header.liquid' = 'h2' }
    $syncTookDrop   = Add-Commit -Dir $perPath -Message 'sync: mirror the snippet from live' -Write @{ 'snippets/dropped.liquid' = 'd2' }
    # The own work: merged on the trunk, never pushed to live. This is what a take-live would revert.
    Add-Commit -Dir $perPath -Message 'fix: grammar in the Dutch locale' -Write @{ 'locales/nl.json' = '{"a":2}' } | Out-Null
    # And the newest sync, which takes the header again and NOT the locale -- so it becomes the global
    # floor while saying nothing about locales/nl.json.
    $syncNewest = Add-Commit -Dir $perPath -Message 'sync: mirror the header from live again' -Write @{ 'sections/header.liquid' = 'h3' }
    # A path the trunk later DELETED, to prove the '--' reaches git here (see Get-SyncCommitShas).
    Add-Commit -Dir $perPath -Message 'chore: drop the snippet' -Delete @('snippets/dropped.liquid') | Out-Null

    Push-Location -LiteralPath $perPath
    try {
        # The global answer is the newest sync, exactly as before -- unchanged behaviour.
        Assert-Equal $syncNewest (Get-SyncReferencePoint).Ref 'perpath/global: the repo-wide floor is still the most recent sync commit'

        # THIS PAIR IS THE DEFECT. The global floor says the trunk has not moved on the locale, which is
        # true of that base and false of the question -- the trunk's work on it is OLDER than that sync.
        Assert-True (-not (Test-MainTouchedSince -Since $syncNewest -Path 'locales/nl.json')) `
            'perpath/defect: measured from the GLOBAL floor the trunk looks stationary on a path that sync never took'
        Assert-True ($null -eq (Get-SyncPathReferencePoint -Path 'locales/nl.json')) `
            'perpath/none: no sync ever took the locale, so it has NO agreement point -- the answer is $null, not the newest sync'
        Assert-Equal 'conflict' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false `
            -PathAgreementKnown ([bool](Get-SyncPathReferencePoint -Path 'locales/nl.json'))).Action `
            'perpath/verdict: so the verdict is a conflict, where the global floor produced take-live'

        # A path a sync DID take answers with that sync, and with the RIGHT one of the two.
        Assert-Equal $syncNewest (Get-SyncPathReferencePoint -Path 'sections/header.liquid') `
            'perpath/taken: a path the syncs took answers with the most recent sync THAT TOUCHED IT'
        Assert-True ((Get-SyncPathReferencePoint -Path 'sections/header.liquid') -ne $syncTookHeader) `
            'perpath/taken: and not the earlier one'
        # Live moved alone on it, so it is still taken -- the repair must not turn every path into a conflict.
        Assert-Equal 'take-live' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false `
            -MainTouchedSinceFloor (Test-MainTouchedSince -Since (Get-SyncPathReferencePoint -Path 'sections/header.liquid') -Path 'sections/header.liquid') `
            -PathAgreementKnown $true).Action `
            'perpath/still-takes: a reconciled path the trunk has not touched since is still taken from live'

        # A path whose own sync is OLDER than the trunk's work on it: both moved, which is the arm that
        # could not fire from a global floor.
        Add-Commit -Dir $perPath -Message 'fix: tweak the header' -Write @{ 'sections/header.liquid' = 'h4' } | Out-Null
        $headerBase = Get-SyncPathReferencePoint -Path 'sections/header.liquid'
        Assert-Equal $syncNewest $headerBase 'perpath/both: the base is unchanged by the trunk''s own later commit'
        Assert-True (Test-MainTouchedSince -Since $headerBase -Path 'sections/header.liquid') `
            'perpath/both: and the trunk HAS moved since it'
        Assert-Equal 'conflict' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false `
            -MainTouchedSinceFloor $true -PathAgreementKnown $true).Action `
            'perpath/both: so both sides moved and neither is taken'

        # THE '--' CASE, the one that errors without a pathspec separator and would answer "no base"
        # for the wrong reason. A deleted path still has history, so its sync is still findable.
        Assert-Equal $syncTookDrop (Get-SyncPathReferencePoint -Path 'snippets/dropped.liquid') `
            'perpath/deleted: a path the trunk deleted still answers with the sync that took it (the ''--'' case)'

        # A path that never existed is an ordinary "no base" rather than a throw -- same wrapper property
        # Test-MainTouchedSince asserts above.
        Assert-True ($null -eq (Get-SyncPathReferencePoint -Path 'never/existed.liquid')) `
            'perpath/absent: a path that never existed answers $null without throwing'

        # NO TAG FALLBACK, and this is the assert that keeps it. A tag says nothing about agreement with
        # live, so reading one as a per-path base would reintroduce this defect by a second route.
        Invoke-FixtureGitJudged @('-C', $perPath, 'tag', 'v9.9.9')
        Assert-True ($null -eq (Get-SyncPathReferencePoint -Path 'locales/nl.json')) `
            'perpath/no-tag: a tag is not an agreement point -- it must not become one path''s base'
        Assert-Equal 'sync' (Get-SyncReferencePoint).Kind `
            'perpath/no-tag: while the repo-wide answer keeps its own tag fallback, untouched'

        # The pattern seam reaches the per-path answer too, or a repo that narrowed it would silently get
        # the default here.
        Assert-True ($null -eq (Get-SyncPathReferencePoint -Path 'sections/header.liquid' -Pattern '^mirror:')) `
            'perpath/pattern: the -Pattern seam applies per path as well'
    } finally { Pop-Location }

    # --- Inbound #1945: what an operator commits after a conflict, and what it is worth --------------
    # THE REFUSAL SENDS A PERSON AWAY TO MERGE BY HAND, AND THESE FOUR ASSERTS ARE WHAT THEY COME BACK
    # TO. Three of them are the reported table, reproduced against these functions; the fourth is the
    # shape that actually settles the path. Pinned together because the difference between them is one
    # commit subject and one extra commit, which is exactly the kind of distinction a later repair
    # flattens without noticing.
    Write-Host ''
    Write-Host 'the reconciliation shapes (inbound #1945)'

    $live = 'L2'   # what the third party has on live now: content this repo has never held

    $recStart = New-ReconcileTree -Label 'rec-start'
    Assert-Equal 'conflict' (Get-ReconcileVerdict -Dir $recStart -Live $live) `
        'rec/start: both sides moved, so the run refuses and sends the operator away to merge by hand'

    # ROW 1. A single reconciliation commit with an ordinary subject. The merged bytes are neither side,
    # so provenance never answers yes, and the base stays where it was with the trunk ahead of it.
    $recPlain = New-ReconcileTree -Label 'rec-plain'
    Add-Commit -Dir $recPlain -Message 'fix: reconcile the section by hand' -Write @{ 'sections/x.liquid' = 'MERGED' } | Out-Null
    Assert-Equal 'conflict' (Get-ReconcileVerdict -Dir $recPlain -Live $live) `
        'rec/plain: one commit, ordinary subject -- the same conflict comes back on every future run'

    # ROW 2. THE DAMAGING ONE, AND IT IS PINNED AS A DEFECT RATHER THAN AS A DESIGN. Spelling the commit
    # the way this repo spells its sync commits makes it the path's own agreement point; nothing has
    # touched the path since it, so the trunk reads as stationary and live is taken over the
    # reconciliation. This assert exists so the day somebody changes it, they change it on purpose --
    # Get-SyncPathReferencePoint carries why it is not repairable on that side.
    $recSync = New-ReconcileTree -Label 'rec-sync'
    Add-Commit -Dir $recSync -Message 'sync: reconcile the section by hand' -Write @{ 'sections/x.liquid' = 'MERGED' } | Out-Null
    Assert-Equal 'take-live' (Get-ReconcileVerdict -Dir $recSync -Live $live) `
        'rec/sync-subject: one commit spelled like a sync becomes the base, and the next run reverts it'

    # THE DURABLE SHAPE -- what -ReconcileBase writes. Live verbatim, then the trunk content back on top:
    # no file changes, and live's bytes are now in the path's history, which is the only thing the rule
    # reads. Live's content being ours is answered BEFORE the base is consulted, so the subject of
    # everything after this stops mattering.
    $recPair = New-ReconcileTree -Label 'rec-pair'
    Add-Commit -Dir $recPair -Message 'sync: live verbatim as the reconciliation base for 1 conflicted path(s)' -Write @{ 'sections/x.liquid' = $live } | Out-Null
    Add-Commit -Dir $recPair -Message 'fix: put the trunk content back over the reconciliation base (no file changes)' -Write @{ 'sections/x.liquid' = 'T2' } | Out-Null
    Assert-Equal 'keep-trunk' (Get-ReconcileVerdict -Dir $recPair -Live $live) `
        'rec/pair: live verbatim then the trunk back on top settles the path -- held back, the trunk wins'

    # AND THE OPERATOR'S OWN MERGE LANDS ON TOP OF IT IN ANY SPELLING, which is the promise the refusal
    # now prints. Both subjects are asserted because the whole defect above was a subject deciding a
    # verdict, and 'it no longer does' is only worth having if it is checked on the spelling that used to.
    Add-Commit -Dir $recPair -Message 'fix: merge the two sides of the section' -Write @{ 'sections/x.liquid' = 'MERGED' } | Out-Null
    Assert-Equal 'keep-trunk' (Get-ReconcileVerdict -Dir $recPair -Live $live) `
        'rec/pair: the reconciliation commit on top of it changes nothing -- provenance already decided'

    # THE REPAIR MUST NOT BLIND THE RULE, which is the half a fix like this gets wrong. A NEW third-party
    # edit after all of that is foreign again, the base is the reconciliation base, and the trunk has
    # moved since it -- so it is a conflict, correctly, and the operator is sent round the same loop.
    Assert-Equal 'conflict' (Get-ReconcileVerdict -Dir $recPair -Live 'L3') `
        'rec/pair: a later third-party edit on live is still caught as a fresh both-sides-moved conflict'

    # AND THE ROW-2 HOLE IS STILL OPEN ONE LOOP LATER, which is the whole reason the refusal warns rather
    # than the verdict refusing. Spell that next reconciliation like a sync and the same silent take
    # returns -- so the guard is the printed shape and -ReconcileBase, not anything this lib can decide.
    # Ordered last on purpose: this commit poisons the base for every assert after it.
    Add-Commit -Dir $recPair -Message 'sync: reconcile the later drift by hand' -Write @{ 'sections/x.liquid' = 'MERGED2' } | Out-Null
    Assert-Equal 'take-live' (Get-ReconcileVerdict -Dir $recPair -Live 'L3') `
        'rec/again: a sync-spelled reconciliation of the NEXT conflict is reverted exactly as the first was'

    # --- The quoted path, decoded off the wire ------------------------------------------------------
    # WHY THESE ARE UNIT ASSERTS AND NOT AN INTEGRATION CASE (inbound #821). The bug they pin is that a
    # git-reported path used to be decoded with whatever console code page the RUN inherited -- so the
    # answer depended on the environment, and sync-main.tests.ps1's own accented-path case was red
    # standalone and green under the gate on the same commit, because a sibling suite had flipped the
    # console to UTF-8 for the duration. An integration assert cannot pin the property without mutating
    # that same shared state, which is the thing being repaired. A pure function can: it never touches a
    # console, so if these hold, they hold everywhere.
    #
    # The escaped form below is exactly what git 2.54 prints for 'sections/cafe.liquid' with an accent,
    # captured rather than composed.
    Write-Host ''
    Write-Host 'Convert-GitQuotedPath'

    $accented = 'sections/caf' + [char]0x00E9 + '.liquid'
    Assert-Equal $accented (Convert-GitQuotedPath -Path '"sections/caf\303\251.liquid"') 'quoted/octal: the UTF-8 escape pair decodes back to the character'
    Assert-Equal 'sections/plain.liquid' (Convert-GitQuotedPath -Path 'sections/plain.liquid') 'unquoted: an ordinary ASCII path passes through untouched -- git quotes only when it must'
    Assert-Equal 'a b/c.liquid' (Convert-GitQuotedPath -Path 'a b/c.liquid') 'unquoted/space: a space is not a reason for git to quote, and not a reason to touch the string'
    Assert-Equal 'say "hi".liquid' (Convert-GitQuotedPath -Path '"say \"hi\".liquid"') 'quoted/quote: an escaped quote is one quote, not a terminator'
    Assert-Equal 'back\slash.liquid' (Convert-GitQuotedPath -Path '"back\\slash.liquid"') 'quoted/backslash: an escaped backslash is one backslash'
    Assert-Equal "tab`there.liquid" (Convert-GitQuotedPath -Path '"tab\there.liquid"') 'quoted/control: the C escapes git uses are decoded too'
    # A LONE BACKSLASH IS KEPT, NOT SWALLOWED. git escapes what it means, so a backslash before anything
    # it does not escape is a literal one -- and dropping it would silently shorten a Windows-shaped path,
    # which is the failure shape this whole area keeps producing: a wrong answer that still looks like one.
    Assert-Equal 'keep\me.liquid' (Convert-GitQuotedPath -Path '"keep\me.liquid"') 'quoted/unknown escape: the backslash is kept literally rather than guessed at'
    Assert-Equal '' (Convert-GitQuotedPath -Path '') 'empty: no path is not an error'
    Assert-Equal '"' (Convert-GitQuotedPath -Path '"') 'one quote: too short to be a quoted path, so it is not treated as one'
    # THE POINT OF THE WHOLE EXERCISE, stated as an assert: the escaped form is pure ASCII, which is what
    # makes the answer independent of the decoder. If a change ever put a high byte back on the wire, this
    # is the line that says so.
    Assert-True (@([int[]][char[]]'"sections/caf\303\251.liquid' | Where-Object { $_ -gt 0x7F }).Count -eq 0) 'wire: the quoted form carries no byte above 0x7F, which is why no code page can change the answer'

    # --- The blob id, against git itself ------------------------------------------------------------
    # The comparison's fast path trusts Get-GitRawBlobId against 'git ls-tree'. If it disagreed with git,
    # files would be reported as UNCHANGED that are not -- a silent skip, which is the worst failure shape
    # here: the drift is simply never seen. '--no-filters' is the comparison that holds, because a machine
    # with core.autocrlf on would have plain 'git hash-object' normalise line endings first.
    Write-Host ''
    Write-Host 'Get-GitRawBlobId'

    $blob = New-GitTree -Label 'blob'
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("hello`nworld`n")
    [System.IO.File]::WriteAllBytes((Join-Path $blob 'blob.txt'), $bytes)
    [System.IO.File]::WriteAllBytes((Join-Path $blob 'empty.txt'), (New-Object byte[] 0))
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $gitId    = ([string](& git -C $blob hash-object --no-filters 'blob.txt'  | Select-Object -First 1)).Trim()
        $gitEmpty = ([string](& git -C $blob hash-object --no-filters 'empty.txt' | Select-Object -First 1)).Trim()
    } finally { $ErrorActionPreference = $prevEap }
    Assert-Equal $gitId    (Get-GitRawBlobId -Bytes $bytes)               'blob/text: matches git hash-object --no-filters'
    Assert-Equal $gitEmpty (Get-GitRawBlobId -Bytes (New-Object byte[] 0)) 'blob/empty: and agrees on the empty blob'

    # --- CR stripping -------------------------------------------------------------------------------
    # Asserted through the SAME composition the script uses, Get-GitRawBlobId(Get-CrStrippedBytes(x)),
    # rather than through a helper that exists only to be tested. If this regresses, every file that comes
    # back from live differing only in CR bytes reads as "content the trunk has never held" -- which is the
    # definition of third-party drift under the content rule -- so the sync captures pure noise and
    # overwrites the trunk with all of it. Measured at 37 of 712 files in one consumer.
    Write-Host ''
    Write-Host 'Get-CrStrippedBytes'

    $lf   = [System.Text.Encoding]::ASCII.GetBytes("a`nb`nc")
    $crlf = [System.Text.Encoding]::ASCII.GetBytes("a`r`nb`r`nc")
    $diff = [System.Text.Encoding]::ASCII.GetBytes("a`nb`nd")
    $idLf   = Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes $lf)
    $idCrlf = Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes $crlf)
    $idDiff = Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes $diff)
    Assert-Equal $idLf $idCrlf 'cr/same: CRLF and LF of the same text give the same id'
    Assert-True ($idLf -ne $idDiff) 'cr/diff: genuinely different text still gives a different id'

    # A byte above 0x7F must survive: theme assets include binaries, and a text-mode read in Windows
    # PowerShell 5.1 mangles every one of them.
    $hi1 = Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes ([byte[]](0x41, 0xE9, 0x42)))
    $hi2 = Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes ([byte[]](0x41, 0xEA, 0x42)))
    Assert-True ($hi1 -ne $hi2) 'cr/high: bytes above 0x7F are not folded together'

    # A lone CR is STRIPPED rather than converted, so 'a<CR>b' and 'ab' collide. Asserted rather than left
    # implicit: it is the one place this normalisation is lossier than a real CRLF->LF conversion, and the
    # consequence is a file reading as OURS when it is not quite -- harmless for theme text, where the
    # alternative (a real conversion) would change binary bytes, which is worse.
    Assert-Equal (Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes ([System.Text.Encoding]::ASCII.GetBytes('ab')))) `
                 (Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes ([System.Text.Encoding]::ASCII.GetBytes("a`rb")))) `
                 'cr/lone: a lone CR is stripped, not converted (known and accepted)'

    # THE EMPTY CASE, ASSERTED AGAINST A KNOWN VALUE RATHER THAN AGAINST ITSELF. This is how the consumer's
    # suite hid a real bug: Get-CrStrippedBytes returned $null for an empty stream (PowerShell unwraps a
    # zero-length array), the hash threw on its Mandatory bind, and the assert then compared $null to $null
    # and printed a PASS -- a vacuous green, worse than the error it hid. e69de29... is git's empty blob, so
    # a wrong answer now fails instead of agreeing with itself.
    Assert-Equal 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391' `
        (Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes (New-Object byte[] 0))) `
        'cr/empty: an empty stream is git''s empty blob, not $null'
    Assert-Equal 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391' `
        (Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes ([byte[]](13, 13, 13)))) `
        'cr/all-cr: content that is nothing but CR bytes normalises to the empty blob'

    # --- Provenance: the query the rule turns on ----------------------------------------------------
    # The fixture is the production case in miniature: the trunk changed a file and never pushed it to
    # live, so live still holds the trunk's OLD content, and a later sync commit has buried the change
    # below the floor. The time rule loses it from that moment on, forever; content must not.
    Write-Host ''
    Write-Host 'Test-LiveContentIsOurs'

    $prov = New-GitTree -Label 'prov'
    Add-Commit -Dir $prov -Message 'sync: the first floor' -Write @{ 'sections/section.liquid' = 'live still has this'; 'sections/two-line.liquid' = "line one`nline two" } | Out-Null
    $oldBytes = [System.IO.File]::ReadAllBytes((Join-Path $prov 'sections\section.liquid'))
    Add-Commit -Dir $prov -Message 'fix: the trunk fixes it, not pushed to live' -Write @{ 'sections/section.liquid' = 'the trunk fixed this' } | Out-Null
    # ... and then a later sync, which is what puts the fix below any floor.
    Add-Commit -Dir $prov -Message 'sync: a later sync that buries the fix' -Write @{ 'sections/other.liquid' = 'o1' } | Out-Null

    Push-Location -LiteralPath $prov
    try {
        Assert-True (Test-LiveContentIsOurs -Path 'sections/section.liquid' -LiveBytes $oldBytes) `
            'prov/ours: live''s older copy of OUR file is recognised as ours'
        # THE POINT OF THE WHOLE CHANGE. The time rule has already lost this file, and the content rule
        # still protects it. If these two ever agree here, the floor has moved and the fixture is wrong.
        $floorNow = (Get-SyncReferencePoint).Ref
        Assert-True (-not (Test-MainTouchedSince -Since $floorNow -Path 'sections/section.liquid')) `
            'prov/buried: while the TIME rule has already lost it -- which is why content decides'

        $foreign = [System.Text.Encoding]::ASCII.GetBytes('a third party wrote this on live')
        Assert-True (-not (Test-LiveContentIsOurs -Path 'sections/section.liquid' -LiveBytes $foreign)) `
            'prov/foreign: content this repo has never held is foreign'
        # THE SAME TEXT WITH CRLF ENDINGS IS STILL OURS: the line-ending case reaching the real rule, and
        # it needs a file with an INTERNAL newline to be the case it claims to be. The first version of
        # this assert used the single-line file above and appended CRLF to it -- which CR-strips to that
        # line plus a trailing LF, content the repo has genuinely never held. It failed, correctly, and is
        # written down because a "fixed" version of it would have been the code loosening instead.
        Assert-True (Test-LiveContentIsOurs -Path 'sections/two-line.liquid' -LiveBytes ([System.Text.Encoding]::ASCII.GetBytes("line one`r`nline two"))) `
            'prov/crlf: our content with CRLF endings is still ours'
        # Provenance is per PATH: another file having held those bytes must not make this one ours.
        Assert-True (-not (Test-LiveContentIsOurs -Path 'sections/never-here.liquid' -LiveBytes $oldBytes)) `
            'prov/other-path: a path that never existed holds nothing of ours'
    } finally { Pop-Location }

    # THE 'A' CASE -- A PATH THE TRUNK DELETED, which is where this query failed for real in the consumer.
    # Written inline, the '--' before the pathspec never reaches git: for a path still in HEAD git
    # disambiguates and the bug is invisible, but for a DELETED path it reads the path as a revision, fails
    # to stderr, and the quiet wrapper swallows it -- so the answer came back "foreign" and live's copy
    # would have been written over a deliberate deletion. Measured there: 23 dropped locale files about to
    # be resurrected. This is that case in a fixture.
    Add-Commit -Dir $prov -Message 'feat: a locale the store does not publish' -Write @{ 'locales/dropped.json' = 'a locale nobody publishes' } | Out-Null
    $droppedBytes = [System.IO.File]::ReadAllBytes((Join-Path $prov 'locales\dropped.json'))
    Add-Commit -Dir $prov -Message 'feat: drop the locales the store does not publish' -Delete @('locales/dropped.json') | Out-Null

    Push-Location -LiteralPath $prov
    try {
        $stillOurs = Test-LiveContentIsOurs -Path 'locales/dropped.json' -LiveBytes $droppedBytes
        Assert-True $stillOurs 'prov/deleted: a path the trunk DELETED is still recognised as ours (the ''--'' case)'
        Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'A' -LiveContentIsOurs $stillOurs).Action `
            'prov/deleted: and the verdict for it is keep-trunk, not resurrection'
    } finally { Pop-Location }

    # THE SIMPLIFIED-HISTORY CASE, which is '--full-history' and nothing else (inbound #1945). A merged
    # branch whose NET effect on a path is zero is TREESAME to the first parent there, so default history
    # simplification prunes the whole side and every blob on it -- and this function's question is 'EVER
    # held', which is not a question a simplified walk can answer. The ordinary sync branch is never
    # TREESAME (it changes the path and nothing puts it back), which is why no take-live ever tripped on
    # it; -ReconcileBase writes a net-zero branch on purpose, so here it is load-bearing.
    $simp = New-GitTree -Label 'simplified'
    Add-Commit -Dir $simp -Message 'initial' -Write @{ 'sections/x.liquid' = 'v1' } | Out-Null
    Add-Commit -Dir $simp -Message 'fix: the trunk moves on' -Write @{ 'sections/x.liquid' = 'T2' } | Out-Null
    # Read rather than assumed: 'git init' names the initial branch from the machine's own config, so a
    # hard-coded 'main' here would fail on a machine that still defaults to 'master' and for a reason
    # that has nothing to do with the property under test.
    $simpTrunk = ([string](& git -C $simp rev-parse --abbrev-ref HEAD)).Trim()
    Invoke-FixtureGitJudged @('-C', $simp, 'checkout', '-q', '-b', 'reconcile')
    Add-Commit -Dir $simp -Message 'sync: live verbatim as the reconciliation base' -Write @{ 'sections/x.liquid' = 'LIVE' } | Out-Null
    Add-Commit -Dir $simp -Message 'fix: put the trunk content back' -Write @{ 'sections/x.liquid' = 'T2' } | Out-Null
    Invoke-FixtureGitJudged @('-C', $simp, 'checkout', '-q', $simpTrunk)
    Invoke-FixtureGitJudged @('-C', $simp, 'merge', '-q', '--no-ff', '-m', 'merge: reconcile', 'reconcile')

    Push-Location -LiteralPath $simp
    try {
        $liveBytes = [System.Text.Encoding]::ASCII.GetBytes('LIVE')
        # The assert is worth having only against the walk it repairs, so both are measured here: the
        # simplified walk cannot see the commit, the full one can, on the same repo in the same breath.
        Assert-True (@(& git log --format='%H' 'HEAD' '--' 'sections/x.liquid').Count -lt `
                     @(& git log --full-history --format='%H' 'HEAD' '--' 'sections/x.liquid').Count) `
            'prov/simplified: the default walk really does prune the merged side -- the premise of the flag'
        Assert-True (Test-LiveContentIsOurs -Path 'sections/x.liquid' -LiveBytes $liveBytes) `
            'prov/simplified: and live''s bytes are still recognised as ours through that merge'
        Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs `
            (Test-LiveContentIsOurs -Path 'sections/x.liquid' -LiveBytes $liveBytes)).Action `
            'prov/simplified: so the path is held back rather than reported as a conflict for ever'
        # The trunk's own content is still there too, so the widened walk has not blurred the two sides.
        Assert-True (Test-LiveContentIsOurs -Path 'sections/x.liquid' -LiveBytes ([System.Text.Encoding]::ASCII.GetBytes('T2'))) `
            'prov/simplified: the mainline content is unaffected by the flag'
        Assert-True (-not (Test-LiveContentIsOurs -Path 'sections/x.liquid' -LiveBytes ([System.Text.Encoding]::ASCII.GetBytes('L3')))) `
            'prov/simplified: and content nobody ever committed is still foreign -- the walk widened, the test did not'
    } finally { Pop-Location }

    # --- The verdict table, every cell --------------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-SyncFileVerdict'

    # EVERY M+foreign CELL NOW NAMES -PathAgreementKnown, and the omission is itself asserted further
    # down. Before inbound #1535 this cell took live whenever the (global) floor said the trunk had not
    # moved; the question is now per path, so "untouched" is only an answer where a base EXISTS to be
    # untouched since.
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $true).Action  'verdict/M+ours: the trunk has moved on, so it wins'
    Assert-Equal 'take-live'  (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -PathAgreementKnown $true).Action 'verdict/M+foreign: a third party''s edit to a path untouched since ITS OWN base is taken'
    Assert-Equal 'conflict'   (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -MainTouchedSinceFloor $true -PathAgreementKnown $true).Action 'verdict/M+both: both sides moved, so neither is taken'
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'A' -LiveContentIsOurs $true).Action  'verdict/A+ours: a deliberate deletion is not undone'
    Assert-Equal 'take-live'  (Get-SyncFileVerdict -Status 'A' -LiveContentIsOurs $false).Action 'verdict/A+foreign: a file only live has and we never held is taken'
    # 'A' has no conflict cell: the trunk does not have the file, so there is no trunk-side change to lose.
    Assert-Equal 'take-live'  (Get-SyncFileVerdict -Status 'A' -LiveContentIsOurs $false -MainTouchedSinceFloor $true).Action 'verdict/A+both: still take-live -- there is no trunk copy to lose'
    # 'D' is unconditional in every combination: a sync never deletes.
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'D' -LiveContentIsOurs $true).Action  'verdict/D+ours: a sync never deletes'
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'D' -LiveContentIsOurs $false).Action 'verdict/D+foreign: nor when live''s side is foreign'
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'D' -LiveContentIsOurs $false -MainTouchedSinceFloor $true).Action 'verdict/D+both: nor when the trunk moved too'

    # --- THE CELL INBOUND #1535 WAS ------------------------------------------------------------------
    # No sync has ever taken this path, so there is no moment at which the trunk and live are known to
    # have agreed. 'Live's content is foreign' then does not mean live moved alone -- it means nobody can
    # say -- and the answer is a report rather than a take. This is the assert that would have held back
    # all six paths the consumer measured.
    Assert-Equal 'conflict' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -PathAgreementKnown $false).Action `
        'verdict/M+foreign+no base: a path no sync ever took is reconciled by hand, never taken'
    Assert-Equal 'conflict' (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false).Action `
        'verdict/M+foreign+unanswered: the DEFAULT is the protective one -- an unanswered base is not "live moved alone"'

    # AND THE TWO CONFLICTS ARE TOLD APART, because they lead a person to different work: one side has
    # changes to merge, the other has never been reconciled at all.
    $rBoth = (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -MainTouchedSinceFloor $true -PathAgreementKnown $true).Reason
    $rNone = (Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -PathAgreementKnown $false).Reason
    Assert-True ($rBoth -ne $rNone) 'verdict/reason: both-sides-moved and no-agreement-point do not share one reason'
    Assert-True ($rNone -match 'no sync ever took this path') 'verdict/reason: and the no-base reason says why it cannot be decided'

    # 'A' IS DELIBERATELY UNAFFECTED BY THE NEW FACT: there is no trunk copy to lose, so an unknown
    # agreement point changes no answer there. Asserted so a later "make it consistent" pass has to
    # argue with a test rather than with a comment.
    Assert-Equal 'take-live' (Get-SyncFileVerdict -Status 'A' -LiveContentIsOurs $false -PathAgreementKnown $false).Action `
        'verdict/A+foreign+no base: still taken -- an unknown base cannot cost what the trunk does not have'
    Assert-Equal 'keep-trunk' (Get-SyncFileVerdict -Status 'D' -LiveContentIsOurs $false -PathAgreementKnown $false).Action `
        'verdict/D+no base: and a sync still never deletes'

    # A verdict always carries a reason: it is printed into the PR body, and a blank one there reads as
    # "nothing was held back" -- the one thing the exclusion list exists to contradict.
    Assert-True ([string](Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $true).Reason -ne '')  'verdict/reason: keep-trunk carries a reason'
    Assert-True ([string](Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -PathAgreementKnown $true).Reason -ne '') 'verdict/reason: take-live carries a reason'
    Assert-True ([string](Get-SyncFileVerdict -Status 'M' -LiveContentIsOurs $false -MainTouchedSinceFloor $true -PathAgreementKnown $true).Reason -ne '') 'verdict/reason: and so does a conflict'


    # --- The PR body ---------------------------------------------------------------------------------
    # THE ONE ASSERT THAT WOULD HAVE CAUGHT INBOUND #1000 is 'body/take: the taken paths are named at
    # all'. Before it, the body carried only the held-back half, and every other property here -- counts,
    # reasons, grouping -- was true of that body too. A suite can be entirely green over a report that
    # omits the half a reader came for, which is why the assert is worded as presence rather than shape.
    Write-Host ''
    Write-Host 'New-SyncPrBody'

    Assert-Equal 'changed on live' (Get-SyncFileKind -Status 'M') 'kind/M: both sides have it and it differs'
    Assert-Equal 'new on live'     (Get-SyncFileKind -Status 'A') 'kind/A: live has it and the trunk does not'
    # The #350 case: a flat list cannot say this, and it is the one that needs a second look.
    Assert-Equal 'gone from live'  (Get-SyncFileKind -Status 'D') 'kind/D: the trunk has it and live does not'

    $takeReason = 'content this repo has never held for this path: a third party wrote it on live'
    $rowsTake = @(
        [pscustomobject]@{ Status = 'M'; Path = 'sections/header.liquid'; Reason = $takeReason }
        [pscustomobject]@{ Status = 'A'; Path = 'snippets/promo.liquid';  Reason = $takeReason }
    )
    $rowsKeep = @(
        [pscustomobject]@{ Status = 'D'; Path = 'templates/page.back-to-school.json'; Reason = 'only the trunk has this file; a sync never deletes' }
        [pscustomobject]@{ Status = 'M'; Path = 'config/settings_data.json';          Reason = 'live holds a version this repo has had before; the trunk has moved on since' }
    )
    $body = New-SyncPrBody -Take $rowsTake -Keep $rowsKeep

    Assert-True ($body -match 'sections/header\.liquid' -and $body -match 'snippets/promo\.liquid') 'body/take: the taken paths are named at all'
    Assert-True ($body -match 'changed on live -- .sections/header\.liquid.') 'body/take: with the kind in front of the path, not a bare list'
    Assert-True ($body -match 'gone from live -- .templates/page\.back-to-school\.json.') 'body/keep: a path live no longer has is reported as gone, the #350 case'
    Assert-True ($body -match '\*\*Taken from live \(2\)\*\*' -and $body -match '\*\*Held back, the trunk wins \(2\)\*\*') 'body/counts: both halves carry their own count'
    Assert-True ($body -match [regex]::Escape($takeReason)) 'body/reason: the verdict''s reason travels into the body'
    # Grouped, not repeated: two files share one reason, so that sentence appears once.
    Assert-Equal 1 ([regex]::Matches($body, [regex]::Escape($takeReason)).Count) 'body/group: a shared reason is printed once, not once per file'
    # The caller's order is the console's order, so the body lines up with what the operator just read.
    Assert-True ($body.IndexOf('sections/header.liquid') -lt $body.IndexOf('snippets/promo.liquid')) 'body/order: files keep the caller''s order'
    Assert-True ($body.IndexOf('Taken from live') -lt $body.IndexOf('Held back')) 'body/order: and the taken half comes first'

    # Both empty halves keep a sentence rather than a silent gap: an absent section reads as an oversight,
    # and 'nothing was held back' is a finding.
    $emptyKeep = New-SyncPrBody -Take $rowsTake -Keep @()
    Assert-True ($emptyKeep -match 'Nothing was held back by the content rule\.') 'body/empty: an empty held-back half says so in words'
    $emptyTake = New-SyncPrBody -Take @() -Keep $rowsKeep
    Assert-True ($emptyTake -match 'Nothing was taken from live\.') 'body/empty: and so does an empty taken half'
    Assert-True ((New-SyncPrBody -Take @() -Keep @()) -match 'Nothing was taken from live\.') 'body/empty: neither half is required for a body at all'

    # A $null in a row array is what a caller's filter leaves behind; it must not become a blank bullet.
    $withNull = New-SyncPrBody -Take @($rowsTake[0], $null) -Keep @()
    Assert-Equal 1 ([regex]::Matches($withNull, '(?m)^- ').Count) 'body/null: an empty row is dropped rather than printed as a blank bullet'
    Assert-True ($withNull -match '\*\*Taken from live \(1\)\*\*') 'body/null: and it is not counted either'

    Assert-True ((New-SyncPrBody -Take $rowsTake -Keep $rowsKeep -Intro 'Custom intro.') -match '^Custom intro\.') 'body/intro: the opening line is the caller''s to set'

    # --- The sync-log entry (inbound #1382) ----------------------------------------------------------
    # THE HEADLINE ASSERT HERE IS 'log/shared', and it is not a shape check. The entry and the PR body
    # are two renderings of ONE set of rows, and the failure they are built to prevent is silent: the day
    # a verdict class is added, one composer learns about it and the other keeps producing a
    # complete-looking record with that class missing. Asserting that the same rows produce the same
    # bullets is the only assert that fails when the two drift apart -- every other property below is
    # true of a forked composer too.
    Write-Host ''
    Write-Host 'New-SyncLogEntry'

    $entry = New-SyncLogEntry -Branch 'sync/live-2026-09-04' -Date '2026-09-04' -Take $rowsTake -Keep $rowsKeep

    Assert-True ($entry -match '(?m)^## 2026-09-04 -- .sync/live-2026-09-04.') 'log/heading: the entry opens with its date and the branch it came from'
    Assert-True ($entry -match 'sections/header\.liquid' -and $entry -match 'snippets/promo\.liquid') 'log/take: the taken paths are named at all'
    Assert-True ($entry -match 'gone from live -- .templates/page\.back-to-school\.json.') 'log/keep: the held-back half is in the entry, and it is the half nothing else records'
    Assert-True ($entry -match '\*\*Taken from live \(2\)\*\*' -and $entry -match '\*\*Held back, the trunk wins \(2\)\*\*') 'log/counts: both halves carry their own count'

    # ONE DEFINITION, TWO OUTPUTS. Every bullet the body draws from these rows is in the entry, verbatim.
    $bodyBullets  = @([regex]::Matches($body,  '(?m)^- .+$')  | ForEach-Object { $_.Value })
    $entryBullets = @([regex]::Matches($entry, '(?m)^- .+$') | ForEach-Object { $_.Value })
    Assert-Equal ($bodyBullets -join '|') ($entryBullets -join '|') 'log/shared: the same rows render identically in the PR body and the log entry'

    # NO PR FIELD, and it is a decision rather than an omission: the entry is committed on the sync
    # branch before any PR exists, and the default seam answer never opens one at all.
    Assert-True ($entry -notmatch '(?i)pull request|/pull/') 'log/pr: the entry carries no PR field, because there is no PR yet when it is written'

    # The trailing blank line is what makes prepending two entries need no separator logic at the caller.
    Assert-True ($entry.EndsWith("`n`n")) 'log/tail: an entry ends with a blank line, so two of them concatenate cleanly'
    Assert-True ($entry -notmatch "`r") 'log/eol: LF only -- this runs on Windows and the file is read on GitHub'

    $logEmpty = New-SyncLogEntry -Branch 'sync/live-2026-09-04' -Date '2026-09-04' -Take @() -Keep @()
    Assert-True ($logEmpty -match 'Nothing was taken from live\.') 'log/empty: an empty half says so in words here too, rather than leaving a silent gap'

    # --- Where the entry goes in the file ------------------------------------------------------------
    # 'prepend/nomasthead' IS THE ONE THAT EARNS THIS BLOCK. '$lines[0..($anchor - 1)]' with an anchor of
    # 0 is '$lines[0..-1]', which PowerShell reads as "0 through the LAST index" -- so the arm that looks
    # like it yields an empty head yields the WHOLE FILE, and the log is duplicated rather than prepended
    # to. Well-formed markdown, no error, and only on a log whose first line is already an entry.
    Write-Host ''
    Write-Host 'Add-SyncLogEntry'

    $second = "## 2026-09-05 -- ``sync/live-2026-09-05``" + "`n`n- new on live -- ``a.liquid```n`n"

    Assert-Equal $second (Add-SyncLogEntry -Existing '' -Entry $second) 'prepend/fresh: an empty file becomes the entry and nothing else'

    $masthead = "# Sync log`n`nWhat third parties did on live. Newest first.`n`n"
    $withOne  = Add-SyncLogEntry -Existing ($masthead + $entry) -Entry $second
    Assert-True ($withOne.StartsWith($masthead)) 'prepend/masthead: whatever sits above the first entry is left exactly where it is'
    Assert-True ($withOne.IndexOf('2026-09-05') -lt $withOne.IndexOf('2026-09-04')) 'prepend/order: and the new entry lands above the old one, newest first'
    Assert-True ($withOne -match [regex]::Escape($entry)) 'prepend/intact: the entry already there survives byte for byte'
    Assert-Equal 2 ([regex]::Matches($withOne, '(?m)^## ').Count) 'prepend/count: two entries in, two entries out'

    # The trap: a log that is entries only, with no masthead at all.
    $bare = Add-SyncLogEntry -Existing $entry -Entry $second
    Assert-Equal 2 ([regex]::Matches($bare, '(?m)^## ').Count) 'prepend/nomasthead: a log whose first line IS an entry gets two entries, not its whole self back'
    Assert-True ($bare.StartsWith('## 2026-09-05')) 'prepend/nomasthead: and the new one is still on top'

    # A masthead and no entries yet: the file was hand-started, and the entry goes after it.
    $mastheadOnly = Add-SyncLogEntry -Existing $masthead -Entry $second
    Assert-True ($mastheadOnly.StartsWith('# Sync log')) 'prepend/mastheadonly: a file with a title and no entries keeps its title'
    Assert-True ($mastheadOnly -match [regex]::Escape($second)) 'prepend/mastheadonly: and gains the entry below it'

    # CRLF in, LF out: this runs on Windows, and a file that gains CRLF halfway diffs whole on GitHub.
    $crlf = Add-SyncLogEntry -Existing (($masthead + $entry) -replace "`n", "`r`n") -Entry $second
    Assert-True ($crlf -notmatch "`r") 'prepend/eol: an existing CRLF file is normalised to LF rather than mixed'
    Assert-Equal 2 ([regex]::Matches($crlf, '(?m)^## ').Count) 'prepend/eol: and the anchor is still found through the old line endings'

    # ===============================================================================================
    # THE STANDING-PREDECESSOR PAIR (inbound #1021)
    #
    # Both functions are pure, so these cases need no fixture at all -- which is the reason the parsing
    # and the verdict were split out of sync-main.ps1 rather than written inline there. What each group
    # protects is a failure that is SILENT in production: a predecessor the scan does not see, and a
    # supersession claimed on a path this run never wrote.
    # ===============================================================================================
    Write-Host ''
    Write-Host 'Get-SyncBranchNamesFromRefs -- which refs count as this sync' -ForegroundColor Cyan

    # EACH LINE IS ONE DOUBLE-QUOTED STRING WITH AN EMBEDDED `t, NEVER A '+' CONCATENATION. In PowerShell
    # the COMMA BINDS TIGHTER THAN '+', so 'a' + "`t" + 'b', 'c' + "`t" + 'd' inside @() does not build two
    # tab-separated lines -- it builds one flat array of the fragments, and every assert then measures a
    # fixture that looks right in the source and is not. Measured on this suite: the parser was correct
    # throughout and four asserts failed anyway.
    $refLines = @(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`trefs/heads/main",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`trefs/heads/sync/live-2026-08-21",
        "cccccccccccccccccccccccccccccccccccccccc`trefs/heads/sync/live-2026-08-27-2",
        "dddddddddddddddddddddddddddddddddddddddd`trefs/heads/tooling/sync/live-helper",
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee`trefs/heads/feat/sync/live-something",
        '',
        'warning: redirecting to https://github.com/x/y.git/',
        "ffffffffffffffffffffffffffffffffffffffff`trefs/heads/sync/live-2026-08-28^{}"
    )
    $names = @(Get-SyncBranchNamesFromRefs -Lines $refLines -Prefix 'sync/live-')
    Assert-Equal 2 $names.Count 'refs: only the two real sync branches are returned'
    Assert-True ($names -contains 'sync/live-2026-08-21') 'refs: a plain ls-remote line yields its branch name'
    Assert-True ($names -contains 'sync/live-2026-08-27-2') 'refs: the -2 suffix a stacked run produces is a branch like any other'

    # THE SELF-REPORT TRAP, and it is why the anchor is the whole ref rather than a substring of it. A
    # tooling branch whose NAME contains the prefix would otherwise report itself as its own predecessor,
    # and the guard would then refuse every run forever with no branch to merge.
    Assert-True (-not ($names -contains 'tooling/sync/live-helper')) 'refs: a prefix appearing mid-ref is not a match'
    Assert-True (-not ($names -contains 'feat/sync/live-something')) 'refs: and neither is one behind another prefix'
    Assert-True (-not ($names -contains 'main')) 'refs: the trunk is not a sync branch'
    Assert-True (-not ($names -contains 'sync/live-2026-08-28')) 'refs: a peeled ^{} ref is dropped rather than read as a branch'
    Assert-True (@($names | Where-Object { -not $_ }).Count -eq 0) 'refs: a blank line and a warning line produce no entry'

    # THE SEAM CASE, which is the one defect the inbound report's own proposal carried: it anchored on a
    # literal 'sync/'. Get-ShopifySyncBranchPrefix is a seam the README calls "yours to set", so a
    # hardcoded anchor gives a consumer a guard that finds nothing and never fires -- the same
    # always-silent failure, wearing the opposite face.
    $driftLines = @(
        "1111111111111111111111111111111111111111`trefs/heads/theme-drift/2026-08-28",
        "2222222222222222222222222222222222222222`trefs/heads/sync/live-2026-08-28"
    )
    $drift = @(Get-SyncBranchNamesFromRefs -Lines $driftLines -Prefix 'theme-drift/')
    Assert-Equal 1 $drift.Count 'refs/seam: a consumer''s own prefix is what decides, not a hardcoded ''sync/'''
    Assert-True ($drift -contains 'theme-drift/2026-08-28') 'refs/seam: and it finds that consumer''s branch'
    Assert-Equal 0 (@(Get-SyncBranchNamesFromRefs -Lines $driftLines -Prefix 'Sync/live-')).Count 'refs: matching is ordinal, so a prefix differing only in case names nothing'

    Assert-Equal 0 (@(Get-SyncBranchNamesFromRefs -Lines @() -Prefix 'sync/live-')).Count 'refs: no input is no predecessors, not an error'
    $dupes = @(Get-SyncBranchNamesFromRefs -Prefix 'sync/live-' -Lines @(
        "3333333333333333333333333333333333333333`trefs/heads/sync/live-2026-08-28",
        "3333333333333333333333333333333333333333`trefs/heads/sync/live-2026-08-28"))
    Assert-Equal 1 $dupes.Count 'refs: a name repeated in the output is reported once'

    # WHITESPACE-ONLY PREFIX THROWS RATHER THAN MATCHING EVERYTHING OR NOTHING. Both silent readings are
    # wrong in a way nobody would notice: match-everything reports the trunk as a predecessor, and
    # match-nothing leaves the guard permanently inert.
    $threw = $false
    try { Get-SyncBranchNamesFromRefs -Lines $refLines -Prefix '   ' | Out-Null } catch { $threw = $true }
    Assert-True $threw 'refs: a whitespace-only prefix is refused, because neither silent reading of it is safe'

    Write-Host ''
    Write-Host 'Get-SyncPredecessorReport -- does this run supersede the branch already standing?' -ForegroundColor Cyan

    $predA = [pscustomobject]@{ Branch = 'sync/live-2026-08-21'; Paths = @('sections/a.liquid', 'sections/b.liquid') }
    $predB = [pscustomobject]@{ Branch = 'sync/live-2026-08-27'; Paths = @('sections/a.liquid', 'templates/gone.json') }

    # THE MEASURED SHAPE: the newest run is a strict SUPERSET of the predecessor. That is the row where an
    # operator may close the older PR, so it is the row that must never be reported wrongly.
    $superset = @(Get-SyncPredecessorReport -Predecessors @($predA) -TakePaths @(
        'sections/a.liquid', 'sections/b.liquid', 'assets/new.js'))
    Assert-Equal 1 $superset.Count 'report: one row per standing branch'
    Assert-True $superset[0].Superseded 'report/superset: a take set covering every captured path supersedes it'
    Assert-Equal 0 @($superset[0].Uncovered).Count 'report/superset: with nothing uncovered'
    Assert-Equal 2 $superset[0].Captured 'report/superset: and the captured count is the branch''s own, not this run''s'

    $partial = @(Get-SyncPredecessorReport -Predecessors @($predB) -TakePaths @('sections/a.liquid'))
    Assert-True (-not $partial[0].Superseded) 'report/partial: one uncovered path is enough to deny supersession'
    Assert-Equal 1 @($partial[0].Uncovered).Count 'report/partial: and the uncovered path is counted'
    Assert-True (@($partial[0].Uncovered) -contains 'templates/gone.json') 'report/partial: named, because it is the whole decision'

    $none = @(Get-SyncPredecessorReport -Predecessors @($predA) -TakePaths @())
    Assert-Equal 2 @($none[0].Uncovered).Count 'report/nodrift: an empty take set leaves every path uncovered'
    Assert-True (-not $none[0].Superseded) 'report/nodrift: so "nothing to sync" never reads as "that branch is redundant"'

    # THE VACUOUS-TRUTH TRAP. A branch whose diff could not be read arrives with no paths, and
    # covers-everything is then trivially true -- which would present a branch this run knows nothing
    # about as safely replaceable by it.
    $unknown = @(Get-SyncPredecessorReport -Predecessors @(
        [pscustomobject]@{ Branch = 'sync/live-unreadable'; Paths = @() }) -TakePaths @('sections/a.liquid'))
    Assert-True (-not $unknown[0].Superseded) 'report/unknown: a branch with no readable file set is NOT superseded'
    Assert-Equal 0 $unknown[0].Captured 'report/unknown: and it says so with a zero count rather than silently'

    $mixed = @(Get-SyncPredecessorReport -Predecessors @($predA, $predB) -TakePaths @(
        'sections/a.liquid', 'sections/b.liquid'))
    Assert-Equal 2 $mixed.Count 'report/mixed: several standing branches are each answered separately'
    Assert-True $mixed[0].Superseded 'report/mixed: the covered one is superseded'
    Assert-True (-not $mixed[1].Superseded) 'report/mixed: and the other is not, in the same run'

    # CASE SENSITIVITY, ASSERTED FOR ITS DIRECTION rather than for correctness on a Windows checkout.
    # Ordinal comparison can call a covered path uncovered; the cost is a supersession this run declines
    # to claim. The inverse would call a path covered that this run never wrote, and closing the
    # predecessor on that verdict loses the only copy of the drift.
    $cased = @(Get-SyncPredecessorReport -Predecessors @(
        [pscustomobject]@{ Branch = 'sync/live-cased'; Paths = @('Sections/A.liquid') }) -TakePaths @('sections/a.liquid'))
    Assert-True (-not $cased[0].Superseded) 'report/case: a path differing only in case is not counted as covered'

    $blanks = @(Get-SyncPredecessorReport -Predecessors @(
        [pscustomobject]@{ Branch = 'sync/live-blanks'; Paths = @('sections/a.liquid', '', $null, '  ') }) -TakePaths @('sections/a.liquid'))
    Assert-Equal 1 $blanks[0].Captured 'report/blanks: an empty path is not a captured file'
    Assert-True $blanks[0].Superseded 'report/blanks: so it cannot deny a supersession that holds'
    Assert-Equal 0 (@(Get-SyncPredecessorReport -Predecessors @() -TakePaths @('x'))).Count 'report: no standing branches is an empty report'
    Assert-Equal 0 (@(Get-SyncPredecessorReport -Predecessors @($null) -TakePaths @('x'))).Count 'report: a $null row is dropped rather than reported as a branch'
}
finally {
    foreach ($d in $script:trees) {
        if ($d -and (Test-Path -LiteralPath $d)) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'sync-rules.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
