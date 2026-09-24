<#
.SYNOPSIS
    new-branch.ps1, scenarios (s)-(u) and (x): whether the base it cuts from is behind origin or another
    branch's tip, and the -Resolves already-done check.

.DESCRIPTION
    The fixture, the assert helpers and the child runner live in new-branch-fixture.ps1, which also
    records why this suite is more than one file. Split under #2304.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/new-branch-base.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'new-branch-fixture.ps1')

try {
    # --- (s) THE BASE IS BEHIND ORIGIN: REFUSED, with the count and the way out (#1046, #1417) --------
    # THE CASE THE REPORT WAS FILED ON. In a consumer with two sessions on one board, new-branch cut from
    # a trunk 17 commits behind origin/main to fix an issue the other session had closed by a merged PR
    # four minutes earlier -- a complete duplicate, every gate green on both. #1046 answered that with a
    # warning as its own first step; #1417 read the reason it stopped there against the code and refused.
    #
    # THE ASSERTS SPLIT IN TWO, AND THE SECOND HALF IS THE POINT. Naming the count and the way out is what
    # the warning always had to do and is unchanged. What is new is that NOTHING HAPPENED: no branch, no
    # document, no commit. A refusal that leaves half a branch behind would be worse than the warning it
    # replaced, because the operator now has to unpick it -- so it is asserted rather than assumed.
    Write-Host "new-branch.ps1 -- a base behind origin is REFUSED, with the count (#1046, #1417)" -ForegroundColor Cyan
    # NAMED $fixStale AND NOT $fixtureS, WHICH IS NOT A STYLE CHOICE. PowerShell variable names are
    # case-INSENSITIVE, so `$fixtureS` and the teardown accumulator `$script:fixtures` are the SAME
    # variable at script scope -- and since the fixture path lands in it as a string first, every later
    # `$script:fixtures += ...` CONCATENATED onto it. The run failed with a Set-Location on three temp
    # paths glued together, and the teardown list was destroyed with it. Exactly the collision
    # new-branch.ps1 documents on $RepoRoot/$repoRoot; a single-letter suffix is what walks into it.
    $fixStale = New-Fixture -Label 's'
    $bareStale = New-BareOrigin -Dir $fixStale -Label 's'
    Publish-FixtureTrunk -Dir $fixStale
    Add-OriginCommits -Bare $bareStale -Label 's' -Count 3

    $rS = Invoke-NewBranch -Dir $fixStale -Name 'feat/cut-from-stale-v1' -Title 'Cut from stale'
    # A REFUSAL SINCE #1417, where this used to assert exit 0 and a created branch.
    Assert-ExitCode 1 $rS 'stale base: new-branch exit 1 -- this refuses, it no longer merely warns'
    # AND IT REFUSED BEFORE TOUCHING ANYTHING, which is the property that makes refusing cheaper than
    # warning here. Three separate reads, because a refusal that left any one of them behind would hand
    # the operator something to unpick: no branch, no document, and HEAD still where it started.
    $branchesS = ((& git -C $fixStale branch --list 'feat/cut-from-stale-v1') -join '').Trim()
    Assert-True (-not [bool]$branchesS) 'stale base: and NO branch was created -- the refusal is before the checkout'
    $docS = Join-Path $fixStale (Join-Path 'dkj-policy' 'feat-cut-from-stale-v1.md')
    Assert-True (-not (Test-Path -LiteralPath $docS)) 'stale base: and no branch document was scaffolded either'
    $headS = ((& git -C $fixStale rev-parse --abbrev-ref HEAD) -join '').Trim()
    Assert-Equal 'main' $headS 'stale base: and HEAD is left exactly where the operator was standing'
    # THE COUNT ITSELF, asserted as the literal number rather than on the word 'behind'. A check that
    # fires without a figure is the thing worktree-lane's message already beat.
    Assert-True (Test-Phrase -Text $rS.Out -Phrase '3 behind origin/main') 'stale base: names how far behind the base is, as a number'
    Assert-True (Test-Phrase -Text $rS.Out -Phrase 'feat/cut-from-stale-v1') 'stale base: and names the branch it applies to, version suffix included'
    # THE WAY OUT, now three halves -- the local fix, the route that never has this problem, and the valve.
    # The valve is asserted BY NAME: a refusal whose escape the operator has to find in the source is the
    # hand-typed `git checkout -b` that #1417 set out not to force on anybody.
    Assert-True (Test-Phrase -Text $rS.Out -Phrase 'git pull --ff-only') 'stale base: names the local remedy'
    Assert-True (Test-Phrase -Text $rS.Out -Phrase 'worktree-lane.ps1') 'stale base: and the lane route, which bases itself on origin by design'
    Assert-True (Test-Phrase -Text $rS.Out -Phrase '-SkipStaleBase') 'stale base: and names the valve, so the escape is not a source dive'
    # NOT REPEATED, and this is the assert that used to demand the opposite. The repeat existed because
    # the scaffold, the tier rubric, the commit and the push all printed between the warning and the end
    # of the run and buried it. A refusal ends the run there, so the count is the one it prints; a second
    # copy would now be noise two lines below the first.
    $flatStale = Get-FlatOutput $rS.Out
    $behindHits = @([regex]::Matches($flatStale, [regex]::Escape((Get-Squeezed '3 behind origin/main')))).Count
    Assert-Equal 1 $behindHits 'stale base: said ONCE -- a refusal ends the run, so nothing buries it'

    # --- (s2) THE VALVE: -SkipStaleBase cuts anyway, and the warning goes back to twice (#1417) -------
    # THE OTHER HALF OF THE DECISION. #1046's objection -- this file reaches consumers by plugin update
    # rather than by choice -- survives as the valve rather than as the answer, so the valve is asserted
    # to give back EXACTLY the old behaviour: the branch, the document, and the warning at both ends.
    # A fresh fixture rather than a re-run of $fixStale: that one refused before writing anything, but
    # asserting the old shape on a tree a previous run had already touched would prove less.
    Write-Host "new-branch.ps1 -- -SkipStaleBase cuts from a stale base anyway (#1417)" -ForegroundColor Cyan
    $fixValve = New-Fixture -Label 's2'
    $bareValve = New-BareOrigin -Dir $fixValve -Label 's2'
    Publish-FixtureTrunk -Dir $fixValve
    Add-OriginCommits -Bare $bareValve -Label 's2' -Count 3

    $rS2 = Invoke-NewBranch -Dir $fixValve -Name 'feat/cut-from-stale-v1' -Title 'Cut from stale' -SkipStaleBase
    Assert-ExitCode 0 $rS2 '-SkipStaleBase: exit 0 -- the valve really is an escape'
    $branchesS2 = ((& git -C $fixValve branch --list 'feat/cut-from-stale-v1') -join '').Trim()
    Assert-True ([bool]$branchesS2) '-SkipStaleBase: and the branch really is created'
    Assert-True (Test-Phrase -Text $rS2.Out -Phrase '3 behind origin/main') '-SkipStaleBase: the count is still named -- the valve silences the refusal, not the warning'
    Assert-True (Test-Phrase -Text $rS2.Out -Phrase 'cutting from that base anyway') '-SkipStaleBase: and the run says the valve was used'
    # THE REPEAT, which matters MORE under the valve than it ever did: this is the only run that still
    # reaches the end of the script carrying a stale base, and everything the scaffold prints buries the
    # first copy. Counted against Get-FlatOutput's own normalization, phrase squeezed the same way
    # Test-Phrase squeezes it -- a raw phrase would match zero times in whitespace-free text.
    $flatValve = Get-FlatOutput $rS2.Out
    $valveHits = @([regex]::Matches($flatValve, [regex]::Escape((Get-Squeezed '3 behind origin/main')))).Count
    Assert-Equal 2 $valveHits '-SkipStaleBase: said twice -- once before the checkout, once as the last line'

    # --- (t) THE BASE IS CURRENT: nothing to warn about -----------------------------------------------
    # The negative half, and it is what keeps the check from becoming noise on every run. Same fixture
    # shape as (s) minus the upstream commits, so the only difference is the gap itself.
    Write-Host "new-branch.ps1 -- a current base is not warned about (#1046)" -ForegroundColor Cyan
    $fixCurrent = New-Fixture -Label 't'
    $null = New-BareOrigin -Dir $fixCurrent -Label 't'
    Publish-FixtureTrunk -Dir $fixCurrent

    $rT = Invoke-NewBranch -Dir $fixCurrent -Name 'feat/cut-from-current-v1' -Title 'Cut from current'
    Assert-ExitCode 0 $rT 'current base: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rT.Out -Phrase 'Base is current with origin/main') 'current base: says so, so silence is never ambiguous'
    Assert-True (-not (Test-Phrase -Text $rT.Out -Phrase 'behind origin/main')) 'current base: and warns about nothing'
    Assert-True (-not (Test-Phrase -Text $rT.Out -Phrase 'but that base is')) 'current base: and claims no stack where HEAD is the trunk (#2074)'

    # --- (t2) THE BASE IS ANOTHER BRANCH'S TIP: named, counted, and said twice (#2074) ---------------
    # THE CASE (t) CANNOT TELL ITSELF APART FROM. Both read HEAD..origin/main == 0, so both used to end on
    # the same reassuring line. #2074's measurement is a second session that had merged origin/main into
    # its own branch minutes earlier and left the checkout standing there: the base was behind nothing,
    # the stale-base check was correct and silent, and five of that branch's commits -- 22 files -- rode
    # into a two-line repair's pull request. The fixture is that shape exactly: a branch off the published
    # trunk, carrying commits of its own, checked out, with nothing at all to be behind.
    Write-Host "new-branch.ps1 -- a base that is another branch's tip is named and counted (#2074)" -ForegroundColor Cyan
    $fixStack = New-Fixture -Label 't2'
    $null = New-BareOrigin -Dir $fixStack -Label 't2'
    Publish-FixtureTrunk -Dir $fixStack
    Invoke-FixtureGitIn $fixStack checkout -q -b 'fix/another-session-work'
    Set-Content -LiteralPath (Join-Path $fixStack 'their-first.txt')  -Value 'theirs' -Encoding utf8
    Invoke-FixtureGitIn $fixStack add -A
    Invoke-FixtureGitIn $fixStack commit -q -m 'fix: their first commit'
    Set-Content -LiteralPath (Join-Path $fixStack 'their-second.txt') -Value 'theirs' -Encoding utf8
    Invoke-FixtureGitIn $fixStack add -A
    Invoke-FixtureGitIn $fixStack commit -q -m 'fix: their second commit'

    $rT2 = Invoke-NewBranch -Dir $fixStack -Name 'feat/cut-from-a-branch-v1' -Title 'Cut from a branch'
    Assert-ExitCode 0 $rT2 'stacked base: exit 0 -- it warns and never refuses, because stacking on purpose is allowed'
    $branchesT2 = ((& git -C $fixStack branch --list 'feat/cut-from-a-branch-v1') -join '').Trim()
    Assert-True ([bool]$branchesT2) 'stacked base: and the branch really is created'
    Assert-True (Test-Phrase -Text $rT2.Out -Phrase "is being cut from 'fix/another-session-work'") 'stacked base: the base is named, which is the whole finding'
    Assert-True (Test-Phrase -Text $rT2.Out -Phrase '2 commits origin/main does not') 'stacked base: and counted -- that is the set which would ride into the PR'
    Assert-True (Test-Phrase -Text $rT2.Out -Phrase "but that base is 'fix/another-session-work', not main") 'stacked base: the currency line carries it too, so the reassuring sentence is not read alone'
    Assert-True (-not (Test-Phrase -Text $rT2.Out -Phrase 'behind origin/main')) 'stacked base: and this is NOT the stale-base check -- that base is behind nothing'
    # THE REPEAT, for the reason the three notes beside it are repeated: everything printed after the
    # measurement -- the checkout, the scaffold, the tier rubric, the commit, the push -- buries the first
    # copy, and this is the one case where nothing else in the run looks wrong.
    $flatT2 = Get-FlatOutput $rT2.Out
    $stackHits = @([regex]::Matches($flatT2, [regex]::Escape((Get-Squeezed "is being cut from 'fix/another-session-work'")))).Count
    Assert-Equal 2 $stackHits 'stacked base: said twice -- once before the checkout, once near the last line'

    # --- (t3) A BASE THAT IS A BRANCH BUT CARRIES NOTHING: silent (#2074) ----------------------------
    # THE NEGATIVE HALF, and it is what keeps this off the ordinary run. origin/main..HEAD is the number
    # that matters precisely because it is 0 for a branch freshly cut and not yet committed on -- nothing
    # would travel from such a base, so there is nothing to warn about. Without this the check would fire
    # on every second branch of a session and be trained away.
    Write-Host "new-branch.ps1 -- a branch base carrying nothing is not warned about (#2074)" -ForegroundColor Cyan
    $fixEmptyStack = New-Fixture -Label 't3'
    $null = New-BareOrigin -Dir $fixEmptyStack -Label 't3'
    Publish-FixtureTrunk -Dir $fixEmptyStack
    Invoke-FixtureGitIn $fixEmptyStack checkout -q -b 'feat/nothing-on-it-yet'

    $rT3 = Invoke-NewBranch -Dir $fixEmptyStack -Name 'feat/cut-from-empty-branch-v1' -Title 'Cut from an empty branch'
    Assert-ExitCode 0 $rT3 'empty branch base: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rT3.Out -Phrase 'Base is current with origin/main') 'empty branch base: the ordinary line, unchanged'
    Assert-True (-not (Test-Phrase -Text $rT3.Out -Phrase 'is being cut from')) 'empty branch base: and no stack is claimed -- that base carries nothing'
    Assert-True (-not (Test-Phrase -Text $rT3.Out -Phrase 'but that base is')) 'empty branch base: nor on the currency line'

    # --- (t4) BEHIND *AND* STACKED: both are said, and the refusal still fires (#2074) ---------------
    # THE ONE BEHAVIOUR THE SKILL PAGE CALLS OUT AS CROSS-CUTTING, and it had no assertion behind it until
    # a copy-edit pass on the same branch asked for one. The two checks are independent -- one reads how far
    # the base is BEHIND the trunk, the other what the base carries that the trunk does not -- so a base can
    # be both, and the stack note is deliberately placed ABOVE the gap chain so that a REFUSED run still
    # says what it was standing on. Refusing while withholding that is the worse half: the operator is told
    # to bring 'the base' up to date without being told the base is somebody else's branch.
    Write-Host "new-branch.ps1 -- a base both behind the trunk AND another branch's tip says both (#2074)" -ForegroundColor Cyan
    $fixBoth = New-Fixture -Label 't4'
    $bareBoth = New-BareOrigin -Dir $fixBoth -Label 't4'
    Publish-FixtureTrunk -Dir $fixBoth
    Invoke-FixtureGitIn $fixBoth checkout -q -b 'fix/stale-and-stacked'
    Set-Content -LiteralPath (Join-Path $fixBoth 'theirs.txt') -Value 'theirs' -Encoding utf8
    Invoke-FixtureGitIn $fixBoth add -A
    Invoke-FixtureGitIn $fixBoth commit -q -m 'fix: their only commit'
    Add-OriginCommits -Bare $bareBoth -Label 't4' -Count 3

    $rT4 = Invoke-NewBranch -Dir $fixBoth -Name 'feat/cut-from-stale-stack-v1' -Title 'Cut from a stale stack'
    Assert-ExitCode 1 $rT4 'behind and stacked: the stale-base refusal still fires -- the stack note does not soften it'
    Assert-True (Test-Phrase -Text $rT4.Out -Phrase '3 behind origin/main') 'behind and stacked: the gap is named'
    Assert-True (Test-Phrase -Text $rT4.Out -Phrase "is being cut from 'fix/stale-and-stacked'") 'behind and stacked: and so is the base -- a refused run still says what it was standing on'
    Assert-True (Test-Phrase -Text $rT4.Out -Phrase '1 commit origin/main does not') 'behind and stacked: counted, and in the singular at one'
    $branchesT4 = ((& git -C $fixBoth branch --list 'feat/cut-from-stale-stack-v1') -join '').Trim()
    Assert-True (-not [bool]$branchesT4) 'behind and stacked: and nothing was created -- the refusal is still before the checkout'

    # --- (u) NO REMOTE-TRACKING TRUNK: not asked, not claimed (#1046) -------------------------------
    # THE OFFLINE GUARANTEE, and the reason the local question gates the network one. A repo with an
    # origin it has never fetched from -- every other fixture in this file -- has nothing to compare
    # against, so the check must neither reach for the network nor imply an answer it does not have.
    Write-Host "new-branch.ps1 -- no remote-tracking trunk: the base is not compared (#1046)" -ForegroundColor Cyan
    $fixNoTrack = New-Fixture -Label 'u'
    $null = New-BareOrigin -Dir $fixNoTrack -Label 'u'

    $rU = Invoke-NewBranch -Dir $fixNoTrack -Name 'feat/never-fetched-v1' -Title 'Never fetched'
    Assert-ExitCode 0 $rU 'no tracking trunk: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rU.Out -Phrase 'Base not compared') 'no tracking trunk: says the question could not be asked'
    Assert-True (-not (Test-Phrase -Text $rU.Out -Phrase 'behind origin/main')) 'no tracking trunk: and claims no gap it cannot measure'
    Assert-True (-not (Test-Phrase -Text $rU.Out -Phrase 'Base is current')) 'no tracking trunk: nor a currency it cannot measure either'


    # --- (x) THE ALREADY-DONE CHECK: -RESOLVES WARNS BEFORE THE CHECKOUT, NEVER REFUSES (#1409) --------
    # SAME SHAPE AS (s)/(s2)/(t) ABOVE, ONE LAYER IN: a base gone stale and an issue already resolved are
    # both "work already happened somewhere this checkout cannot see", and #1409 is #1046's own report
    # filed against the OTHER half of that sentence. Positive cases assert the warning fires and is said
    # TWICE (the same repeat convention as (s2)); the negative cases (x1, x3, x7, x8) assert silence, so
    # the check cannot become noise on the overwhelming majority of runs that never pass -Resolves at all.
    #
    # A FAKE gh ON PATH, not the pr-issues-lib unit tests' fixture -- this suite exists to prove the
    # WIRING in new-branch.ps1 (which JSON it asks gh for, under which repo name, before which line),
    # not to re-derive Get-TargetIssueWarnings' own logic, which scripts/tests/pr-issues.tests.ps1 already
    # owns. Same fake-gh-on-PATH shape as verify-resolved-issues.tests.ps1, scoped to just this section
    # with its own try/finally so a PATH/env mutation here cannot leak into any fixture above or below it.
    Write-Host "new-branch.ps1 -- -Resolves warns before the checkout when the target issue is already done (#1409)" -ForegroundColor Cyan

    $xBin     = Join-Path ([System.IO.Path]::GetTempPath()) "new-branch-test-$PID-x-bin-$([guid]::NewGuid().ToString('n'))"
    $xCallLog = Join-Path ([System.IO.Path]::GetTempPath()) "new-branch-test-$PID-x-calls-$([guid]::NewGuid().ToString('n')).log"
    $prevPathX = $env:PATH
    try {
        New-Item -ItemType Directory -Path $xBin -Force | Out-Null
        # Records every call (one line per invocation) and answers:
        #   issue list -> a JSON array of {"number":N} for each id in GH_OPEN_ISSUES (or fails under
        #                 GH_FAIL_ISSUE_LIST)
        #   issue view -> the per-number resolve inbound #2056 added: a CLOSED issue for each id in
        #                 GH_CLOSED_ISSUES, and gh's own "Could not resolve" refusal for anything else.
        #                 THAT DEFAULT IS THE #2056 CASE ITSELF -- a number this repo does not have --
        #                 so a case that names no closed issue gets exactly the answer the old rule
        #                 misread as CLOSED.
        #   pr list    -> the raw JSON in GH_PR_LIST_JSON, '[]' by default (or fails under GH_FAIL_PR_LIST)
        $xGhImpl = @'
if ($env:GH_CALL_LOG) { Add-Content -Path $env:GH_CALL_LOG -Value ($args -join ' ') }
if ($args -contains 'issue' -and $args -contains 'list') {
    if ($env:GH_FAIL_ISSUE_LIST) { [Console]::Error.WriteLine('fake gh: issue list failed'); exit 1 }
    $nums = @()
    if ($env:GH_OPEN_ISSUES) { $nums = $env:GH_OPEN_ISSUES -split ',' }
    $items = @($nums | Where-Object { $_ } | ForEach-Object { "{`"number`":$_}" }) -join ','
    Write-Output "[$items]"
    exit 0
}
if ($args -contains 'issue' -and $args -contains 'view') {
    $asked = @($args | Where-Object { $_ -match '^\d+$' })[0]
    $closed = @()
    if ($env:GH_CLOSED_ISSUES) { $closed = $env:GH_CLOSED_ISSUES -split ',' }
    if ($closed -contains $asked) {
        Write-Output "{`"state`":`"CLOSED`",`"url`":`"https://github.com/o/r/issues/$asked`"}"
        exit 0
    }
    [Console]::Error.WriteLine("GraphQL: Could not resolve to an issue or pull request with the number of $asked. (repository.issue)")
    exit 1
}
if ($args -contains 'pr' -and $args -contains 'list') {
    if ($env:GH_FAIL_PR_LIST) { [Console]::Error.WriteLine('fake gh: pr list failed'); exit 1 }
    if ($env:GH_PR_LIST_JSON) { Write-Output $env:GH_PR_LIST_JSON } else { Write-Output '[]' }
    exit 0
}
exit 1
'@
        $xUtf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText((Join-Path $xBin 'gh-impl.ps1'), $xGhImpl, $xUtf8NoBom)
        $xGhCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
        [System.IO.File]::WriteAllText((Join-Path $xBin 'gh.cmd'), $xGhCmd, $xUtf8NoBom)
        $env:PATH = "$xBin;$env:PATH"

        function Invoke-NewBranchX {
            <# Invoke-NewBranch plus a fresh call log and the env vars the fake gh above reads, reset
               before every case so one case's gh answers cannot leak into the next. #>
            param(
                [Parameter(Mandatory = $true)][string]$Dir,
                [Parameter(Mandatory = $true)][string]$Name,
                [Parameter(Mandatory = $true)][string]$Resolves,
                [string]$OpenIssues = '',
                [string]$ClosedIssues = '',
                [string]$PrListJson = '',
                [switch]$FailIssueList,
                [switch]$FailPrList
            )
            Remove-Item -Path $xCallLog -Force -ErrorAction SilentlyContinue
            $env:GH_CALL_LOG = $xCallLog
            $env:GH_OPEN_ISSUES = $OpenIssues
            $env:GH_CLOSED_ISSUES = $ClosedIssues
            $env:GH_PR_LIST_JSON = $PrListJson
            if ($FailIssueList) { $env:GH_FAIL_ISSUE_LIST = '1' } else { Remove-Item Env:\GH_FAIL_ISSUE_LIST -ErrorAction SilentlyContinue }
            if ($FailPrList) { $env:GH_FAIL_PR_LIST = '1' } else { Remove-Item Env:\GH_FAIL_PR_LIST -ErrorAction SilentlyContinue }
            $r = Invoke-NewBranch -Dir $Dir -Name $Name -Title 'Fix something' -Resolves $Resolves
            $log = if (Test-Path -LiteralPath $xCallLog) { Get-Content -Path $xCallLog } else { @() }
            return [pscustomobject]@{ Code = $r.Code; Out = $r.Out; Log = @($log) }
        }

        # (x1) -Resolves OMITTED ENTIRELY: the ordinary run, which is the overwhelming majority of calls.
        # No repo-config.ps1 in this fixture either, so a stray call would hard-fail rather than pass
        # silently -- this asserts the check does not even try.
        $fixX1 = New-Fixture -Label 'x1'
        $rX1 = Invoke-NewBranch -Dir $fixX1 -Name 'feat/plain-cut'
        Assert-ExitCode 0 $rX1 '-Resolves omitted: exits 0'
        Assert-True (-not (Test-Phrase -Text $rX1.Out -Phrase 'already-done check')) '-Resolves omitted: the check never runs at all'

        # (x2) -Resolves GIVEN, NO Get-RepoName (no scripts\repo-config.ps1 in this fixture, same as
        # every fixture above it) -- the offline/no-seam skip path, gh never on PATH for it either.
        $fixX2 = New-Fixture -Label 'x2'
        $prevPathX2 = $env:PATH
        try {
            $env:PATH = $prevPathX  # no fake gh: a call here would be a real bug, not a stubbed answer
            $rX2 = Invoke-NewBranch -Dir $fixX2 -Name 'fix/1409-something' -Resolves '1409'
        } finally { $env:PATH = $prevPathX2 }
        Assert-ExitCode 0 $rX2 '-Resolves, no Get-RepoName: exits 0 -- the missing seam never blocks'
        Assert-True (Test-Phrase -Text $rX2.Out -Phrase 'Get-RepoName') '-Resolves, no Get-RepoName: names the missing seam'
        Assert-True (Test-Phrase -Text $rX2.Out -Phrase 'the check for #1409 is skipped') '-Resolves, no Get-RepoName: and says the check is skipped'
        $branchesX2 = ((& git -C $fixX2 branch --list 'fix/1409-something') -join '').Trim()
        Assert-True ([bool]$branchesX2) '-Resolves, no Get-RepoName: the branch is still created -- the missing seam is not a refusal'

        # (x3) THE NEGATIVE CONTROL: Get-RepoName answers, gh answers, the target issue is genuinely open
        # and unclaimed -- silence, exactly like (t)'s current-base case. Without this, (x4)-(x6) below
        # would only prove the check can say something, never that it stays quiet when there is nothing to say.
        $fixX3 = New-Fixture -Label 'x3'
        Add-FixtureRepoConfig -Dir $fixX3 -RepoName 'fake/repo'
        $rX3 = Invoke-NewBranchX -Dir $fixX3 -Name 'fix/1409-something' -Resolves '1409' -OpenIssues '1409'
        Assert-ExitCode 0 $rX3 'open and unclaimed: exits 0'
        Assert-True (-not (Test-Phrase -Text $rX3.Out -Phrase 'already-done check:')) 'open and unclaimed: nothing to warn about'
        Assert-True (($rX3.Log | Where-Object { $_ -match [regex]::Escape('issue list --repo fake/repo --state open --limit 1000') }).Count -eq 1) 'open and unclaimed: asked gh under the configured repo name, once'
        Assert-True (($rX3.Log | Where-Object { $_ -match [regex]::Escape('pr list --repo fake/repo') -and $_ -match [regex]::Escape('--search 1409 in:body') }).Count -eq 1) 'open and unclaimed: and searched PR bodies for the exact issue number'

        # (x4) THE ISSUE IS ALREADY CLOSED -- warned, twice, and NOT refused (#1282's own call: a shared
        # number or a reopened issue must not wedge a real branch).
        $fixX4 = New-Fixture -Label 'x4'
        Add-FixtureRepoConfig -Dir $fixX4 -RepoName 'fake/repo'
        $rX4 = Invoke-NewBranchX -Dir $fixX4 -Name 'fix/1409-something' -Resolves '1409' -OpenIssues '9999' -ClosedIssues '1409'
        Assert-ExitCode 0 $rX4 'issue already closed: exits 0 -- warned, never refused'
        Assert-True (Test-Phrase -Text $rX4.Out -Phrase 'already-done check: issue #1409 is already CLOSED') 'issue already closed: names the issue and the state'
        $flatX4 = Get-FlatOutput $rX4.Out
        $hitsX4 = @([regex]::Matches($flatX4, [regex]::Escape((Get-Squeezed 'issue #1409 is already CLOSED')))).Count
        Assert-Equal 2 $hitsX4 'issue already closed: said twice -- once before the checkout, once as the last line'
        $branchesX4 = ((& git -C $fixX4 branch --list 'fix/1409-something') -join '').Trim()
        Assert-True ([bool]$branchesX4) 'issue already closed: the branch is still created'

        # (x5) THE ISSUE IS STILL OPEN, BUT ANOTHER PR ALREADY CLOSES IT -- #1282's own scenario, caught
        # here instead of at open-pr time.
        $fixX5 = New-Fixture -Label 'x5'
        Add-FixtureRepoConfig -Dir $fixX5 -RepoName 'fake/repo'
        $prJsonX5 = '[{"number":1406,"state":"MERGED","headRefName":"fix/1402-something","body":"Closes #1409"}]'
        $rX5 = Invoke-NewBranchX -Dir $fixX5 -Name 'fix/1409-something-else' -Resolves '1409' -OpenIssues '1409' -PrListJson $prJsonX5
        Assert-ExitCode 0 $rX5 'issue claimed by a rival PR: exits 0'
        Assert-True (Test-Phrase -Text $rX5.Out -Phrase 'already-done check: issue #1409 is already resolved by PR #1406 (merged)') 'issue claimed by a rival PR: names the PR and its state'

        # (x6) TWO ISSUES, ONLY ONE OF THEM DONE -- ConvertTo-IssueNumberList's own parsing (comma list),
        # and proof the still-open one is not swept along into the same sentence.
        $fixX6 = New-Fixture -Label 'x6'
        Add-FixtureRepoConfig -Dir $fixX6 -RepoName 'fake/repo'
        $rX6 = Invoke-NewBranchX -Dir $fixX6 -Name 'fix/1409-and-1410' -Resolves '1409,1410' -OpenIssues '1410' -ClosedIssues '1409'
        Assert-True (Test-Phrase -Text $rX6.Out -Phrase 'issue #1409 is already CLOSED') 'two issues, one done: names the closed one'
        Assert-True (-not (Test-Phrase -Text $rX6.Out -Phrase '#1410 is already')) 'two issues, one done: and says nothing about the still-open one'
        Assert-True (($rX6.Log | Where-Object { $_ -match [regex]::Escape('--search 1409 OR 1410 in:body') }).Count -eq 1) 'two issues, one done: both numbers went into one PR search'

        # (x7) gh CANNOT SAY WHICH ISSUES ARE OPEN -- warns about the blind spot and does not block. The
        # PR search still runs and (with no claim in it) the run stays silent beyond that one warning.
        $fixX7 = New-Fixture -Label 'x7'
        Add-FixtureRepoConfig -Dir $fixX7 -RepoName 'fake/repo'
        $rX7 = Invoke-NewBranchX -Dir $fixX7 -Name 'fix/1409-blind' -Resolves '1409' -FailIssueList
        Assert-ExitCode 0 $rX7 'gh issue list unreadable: exits 0 -- a merged-elsewhere check must not read as failed'
        Assert-True (Test-Phrase -Text $rX7.Out -Phrase 'could not ask gh which issues are open') 'gh issue list unreadable: warns about the blind spot'
        Assert-True (-not (Test-Phrase -Text $rX7.Out -Phrase 'already-done check:')) 'gh issue list unreadable: and reports nothing it could not actually determine'

        # (x8) THE MIRROR CASE: the PR search itself is unreadable -- the check still runs on issue
        # state alone rather than failing outright.
        $fixX8 = New-Fixture -Label 'x8'
        Add-FixtureRepoConfig -Dir $fixX8 -RepoName 'fake/repo'
        $rX8 = Invoke-NewBranchX -Dir $fixX8 -Name 'fix/1409-blind-pr' -Resolves '1409' -OpenIssues '9999' -ClosedIssues '1409' -FailPrList
        Assert-ExitCode 0 $rX8 'gh pr list unreadable: exits 0'
        Assert-True (Test-Phrase -Text $rX8.Out -Phrase 'could not ask gh whether another PR already resolves') 'gh pr list unreadable: warns about the blind spot'
        Assert-True (Test-Phrase -Text $rX8.Out -Phrase 'issue #1409 is already CLOSED') 'gh pr list unreadable: and still reports what issue state alone could determine'

        # (x9) INBOUND #2056, THE WHOLE CASE, WIRED. The number is not in the open list AND is not an
        # issue of this repo at all -- the shape this workflow's own inbound route produces on every
        # branch citing a finding filed upstream. It used to be reported as 'already CLOSED', which is
        # why x4 above needs -ClosedIssues now: before the repair those two cases were indistinguishable
        # by construction, so x4 and this one were the SAME call with the same answer.
        #
        # THE ASSERT PAIR IS THE POINT. Silence alone would also be produced by the check never running,
        # so the call log is read too: gh WAS asked what #1409 is, and its answer was believed.
        $fixX9 = New-Fixture -Label 'x9'
        Add-FixtureRepoConfig -Dir $fixX9 -RepoName 'fake/repo'
        $rX9 = Invoke-NewBranchX -Dir $fixX9 -Name 'fix/1409-foreign-citation' -Resolves '1409' -OpenIssues '9999'
        Assert-ExitCode 0 $rX9 'a number that is not an issue here: exits 0'
        Assert-True (-not (Test-Phrase -Text $rX9.Out -Phrase 'already-done check:')) 'a number that is not an issue here: not reported as closed (inbound #2056)'
        # SILENT MEANS SILENT, AND THIS ASSERT IS THE ONE THAT SAYS SO. Testing only for the absence of
        # 'already-done check:' passed while the run printed "could not ask gh what every number ...
        # actually is" on every such branch -- the first cut discarded gh's stderr, which is where the
        # "Could not resolve" sentence lives, so the case landed on 'unreadable' instead of 'other'.
        # The label claimed silence and the assert never checked for it.
        Assert-True (-not (Test-Phrase -Text $rX9.Out -Phrase 'could not ask gh what every number')) 'a number that is not an issue here: and NOT reported as unreadable either -- genuinely silent'
        Assert-True (($rX9.Log | Where-Object { $_ -match [regex]::Escape('issue view 1409 --repo fake/repo') }).Count -eq 1) 'a number that is not an issue here: and the silence comes from having ASKED, not from skipping the check'
        $branchesX9 = ((& git -C $fixX9 branch --list 'fix/1409-foreign-citation') -join '').Trim()
        Assert-True ([bool]$branchesX9) 'a number that is not an issue here: the branch is created as normal'
    } finally {
        $env:PATH = $prevPathX
        'GH_CALL_LOG', 'GH_OPEN_ISSUES', 'GH_CLOSED_ISSUES', 'GH_PR_LIST_JSON', 'GH_FAIL_ISSUE_LIST', 'GH_FAIL_PR_LIST' | ForEach-Object {
            Remove-Item "Env:\$_" -ErrorAction SilentlyContinue
        }
        Remove-Item -Path $xBin -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $xCallLog -Force -ErrorAction SilentlyContinue
    }

} finally {
    Remove-NewBranchFixtures
}

Complete-NewBranchSuite
