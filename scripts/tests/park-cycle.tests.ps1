<#
.SYNOPSIS
    Regression tests for scripts/task/park-cycle.ps1 -- the automatic push of the branch's development
    cycle to origin, and every bound that stops it (#900).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL script in a
    throwaway temp git repo with a bare 'origin', so the commit/push mutations never touch the own
    working copy or a real remote.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/park-cycle.tests.ps1

    THE gh SHIM IS THE POINT OF THIS SUITE, not a workaround. park-cycle's most important bound is that
    it becomes a no-op once a PR exists -- without that, it would break the DEPLOY lock (#884) on every
    branch in the repo. A bare repo is not a GitHub remote, so a real `gh pr list` against a fixture
    fails, and a suite that accepted that would only ever exercise the fail-safe path and would report
    "no PR" and "gh is broken" as the same green. So each fixture gets a `gh` of its own, first on PATH,
    answering the one shape this script parses. All three answers are then reachable: no PR, a PR, and
    gh failing.

    park-cycle.ps1 itself calls 'exit', so it is run here as a CHILD PROCESS (powershell -File). Its own
    git calls run under ErrorActionPreference=Continue via the shared Invoke-NativeCapture (the #107
    pitfall) -- this suite mirrors the same caution around its own fixture git calls.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

# Every lib park-cycle.ps1 dot-sources $PSScriptRoot-relative. A fixture missing one has no script at
# all, so they are named here rather than globbed: a lib that is added to the script and forgotten here
# must fail loudly in this suite, not be silently supplied by a wildcard.
$ParkCycleSrc     = Join-Path $RepoRoot 'scripts\task\park-cycle.ps1'
$NativeCaptureSrc = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
$EntryScaffoldSrc = Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1'
$ParkLibSrc       = Join-Path $RepoRoot 'scripts\lib\park-lib.ps1'
# park-lib dot-sources this one (#1682) and its Get-GitParkBacking cannot answer without it. The
# dot-source is guarded, so a fixture that omits it does not crash -- it silently loses the backing
# note, which is what ten asserts in this file measure.
$PorcelainSrc     = Join-Path $RepoRoot 'scripts\lib\git-porcelain-lib.ps1'
$PrIssuesSrc      = Join-Path $RepoRoot 'scripts\lib\pr-issues-lib.ps1'
# Added by #1600: the failure arm composes its divergence sentence with Get-RemoteAheadNote rather than
# a fourth hand-typed copy, so the fixture needs the lib new-branch and open-pr already share.
$RemoteAheadSrc   = Join-Path $RepoRoot 'scripts\lib\remote-ahead-lib.ps1'
# remote-ahead-lib.ps1 dot-sources this for Get-DisplayRef (issue #1623), so a fixture that copies the one
# without the other builds a repo whose scripts die on a missing function.
$RefPrintSrc      = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'

# The cycle path and the scope phrases are read from the shared libs rather than retyped, so a rename
# stays a one-place change -- the same discipline new-branch.tests.ps1 and park-branch.tests.ps1 follow.
. $EntryScaffoldSrc
. $NativeCaptureSrc
. $ParkLibSrc

$script:pass = 0
$script:fail = 0
$script:fixtures = @()

function Get-FlatOutput {
    <# Captured child output with the line breaks removed, so a phrase assert cannot fail on a wrap
       point that park-cycle.ps1 does not decide. Same reasoning as park-branch.tests.ps1's copy.

       THIS IS HALF THE REPAIR, AND THE OPPOSITE HALF FROM THE SIBLING SUITES. Deleting the newline
       joins a word the formatter split ('resol' + 'ved' -> 'resolved'), which normalizing '\s+' to a
       space would not. It breaks the other case for the same reason: where the wrap consumed the
       space between two words, deleting the newline yields 'ghissue list'. No single substitution
       survives both (#1512), so the prose asserts below go through Assert-Says, which strips ALL
       whitespace from both sides and is immune either way. This field stays because a FAILING assert
       still has to print one readable line. #>
    param($Captured)
    return (($Captured | Out-String) -replace "`r?`n", '')
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it?

       Strips ALL whitespace from both sides. Normalizing '\s+' to a single space -- which this file
       does to the captured text -- repairs a wrap BETWEEN words and does nothing for a wrap INSIDE
       one, and the child's formatter breaks at whatever character sits at the buffer column. Which
       asserts straddle a break is decided by the width, so a green run is not evidence (issue #1512;
       the worked measurement is in verify-resolved-issues.tests.ps1).

       Literal (IndexOf), so a phrase carrying '(', ')', '.', '[' or ']' needs no escaping;
       OrdinalIgnoreCase keeps the case-insensitivity that -match had at these call sites. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (Test-Says -Text $Text -Phrase $Phrase) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted to find: '$Phrase'`n         in:             '$Text'" -ForegroundColor Red
    }
}

function New-Fixture {
    <#
        A throwaway git repo with park-cycle.ps1 and its four libs copied in, an initial commit on
        'main', and (unless -NoOrigin) a bare repo wired up as 'origin'. Also writes a `gh` shim whose
        answer is chosen by -GhAnswer: 'none' (an empty list), 'pr' (one open PR, number 42),
        'merged'/'closed' (a PR in that state, visible only to '--state all'), 'pr-nostate' (an open PR
        whose payload carries no `state` field at all) or 'fail' (exit 1, which is how gh missing,
        logged out or offline all arrive).

        THE 'merged' AND 'closed' SHIMS ARE ARGUMENT-AWARE, AND THAT IS THE REGRESSION GUARD FOR #1035.
        They answer `[]` unless the command line carries `--state all`, exactly as the real gh does -- so
        a park-cycle that narrows the query back to `--state open` sees no PR, pushes, and turns these
        cases red. An unconditional shim would pass either way and prove nothing about the query.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [ValidateSet('none', 'pr', 'merged', 'closed', 'pr-nostate', 'fail')][string]$GhAnswer = 'none',
        [switch]$NoOrigin,
        # Writes a scripts/repo-config.ps1 answering the OPTIONAL trunk seam with this name. Omitted:
        # no repo-config at all, which is the unadopted repo every other fixture here models.
        [string]$TrunkName = ''
    )
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("park-cycle-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\task') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib')  -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir '_bin')         -Force | Out-Null
    Copy-Item -LiteralPath $ParkCycleSrc     -Destination (Join-Path $dir 'scripts\task\park-cycle.ps1')        -Force
    Copy-Item -LiteralPath $NativeCaptureSrc -Destination (Join-Path $dir 'scripts\lib\native-capture-lib.ps1') -Force
    Copy-Item -LiteralPath $EntryScaffoldSrc -Destination (Join-Path $dir 'scripts\lib\entry-scaffold-lib.ps1') -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    Copy-Item -LiteralPath $ParkLibSrc       -Destination (Join-Path $dir 'scripts\lib\park-lib.ps1')           -Force
    Copy-Item -LiteralPath $PorcelainSrc     -Destination (Join-Path $dir 'scripts\lib\git-porcelain-lib.ps1')  -Force
    Copy-Item -LiteralPath $PrIssuesSrc      -Destination (Join-Path $dir 'scripts\lib\pr-issues-lib.ps1')      -Force
    Copy-Item -LiteralPath $RemoteAheadSrc   -Destination (Join-Path $dir 'scripts\lib\remote-ahead-lib.ps1')   -Force
    Copy-Item -LiteralPath $RefPrintSrc      -Destination (Join-Path $dir 'scripts\lib\ref-print-lib.ps1')      -Force

    # A .cmd rather than a .ps1: Invoke-NativeCapture resolves 'gh' as a native command, and only an
    # executable extension on PATHEXT is found that way.
    #
    # `findstr` on %* is how a .cmd reads its own arguments here. /C: makes the needle a literal, so the
    # leading dashes are not read as findstr's own switches; errorlevel 1 means "not found", which for
    # these two shims is the `--state open` call that must come back empty.
    $stateAware = {
        param([string]$Record)
        "@echo off`r`necho %* | findstr /C:`"--state all`" >nul`r`nif errorlevel 1 (echo []) else (echo $Record)`r`n"
    }
    $ghBody = switch ($GhAnswer) {
        'none'       { "@echo off`r`necho []`r`n" }
        'pr'         { "@echo off`r`necho [{`"number`":42,`"state`":`"OPEN`"}]`r`n" }
        # An open PR is returned by `--state open` and `--state all` alike, so this one is unconditional
        # on purpose -- it models the shape gh really produces rather than the query being asked.
        'pr-nostate' { "@echo off`r`necho [{`"number`":42}]`r`n" }
        'merged'     { & $stateAware "[{`"number`":1027,`"state`":`"MERGED`"}]" }
        'closed'     { & $stateAware "[{`"number`":969,`"state`":`"CLOSED`"}]" }
        'fail'       { "@echo off`r`nexit /b 1`r`n" }
    }
    [System.IO.File]::WriteAllText((Join-Path $dir '_bin\gh.cmd'), $ghBody, (New-Object System.Text.ASCIIEncoding))

    if ($TrunkName) {
        $cfg = "function Get-TrunkBranchName { '$TrunkName' }`r`n"
        [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\repo-config.ps1'), $cfg, (New-Object System.Text.ASCIIEncoding))
    }

    $bareRemote = "$dir.git"
    if (Test-Path -LiteralPath $bareRemote) { Remove-Item -Recurse -Force -LiteralPath $bareRemote }

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $dir init -q
        Invoke-FixtureGitIn $dir config user.email 'tycho-tests@local.invalid'
        Invoke-FixtureGitIn $dir config user.name 'Tycho Tests'
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $dir config commit.gpgsign false
        # symbolic-ref rather than checkout -b: works on a still-unborn HEAD whatever git's own
        # init.defaultBranch says. Same reasoning as park-branch.tests.ps1.
        Invoke-FixtureGitIn $dir symbolic-ref HEAD refs/heads/main
        [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $dir add -A
        Invoke-FixtureGitIn $dir commit -q -m 'init'
        if (-not $NoOrigin) {
            Invoke-FixtureGitJudged @('init', '--bare', '-q', $bareRemote)
            Invoke-FixtureGitIn $dir remote add origin $bareRemote
        }
    } finally { $ErrorActionPreference = $prevEap }

    $script:fixtures += $dir
    $script:fixtures += $bareRemote
    return $dir
}

function New-CycleDocument {
    <#
        Writes a development document at the path the shared resolver expects, declaring $Branch in its
        heading -- the shape Get-BranchFileDeclaredBranch reads. -Branch '' writes a reset document
        (no name at all), which is the state the trunk carries.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [string]$Body = 'work in progress'
    )
    $rel = (Get-BranchFilePaths).Cycle
    $full = Join-Path $Dir ($rel -replace '/', '\')
    New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
    $heading = if ($Branch) { "## Development: ``$Branch``" } else { '# Development' }
    [System.IO.File]::WriteAllText($full, "$heading`n`n$Body`n", (New-Object System.Text.UTF8Encoding $false))
    return $rel
}

function Invoke-ParkCycle {
    <#
        Runs the fixture copy as a child process, with the fixture as cwd (so the dual-context fallback
        `git rev-parse --show-toplevel` lands there), without a CLAUDE_PROJECT_DIR left over from an
        earlier run, and with the fixture's own _bin first on PATH so its `gh` shim is the one found.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [switch]$Quiet
    )
    $scriptPath = Join-Path $Dir 'scripts\task\park-cycle.ps1'
    $callArgs = @()
    if ($Quiet) { $callArgs += '-Quiet' }

    $prevPd   = $env:CLAUDE_PROJECT_DIR
    $prevPath = $env:PATH
    $prevEap  = $ErrorActionPreference
    $prevLoc  = (Get-Location).Path
    try {
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        $env:PATH = (Join-Path $Dir '_bin') + ';' + $prevPath
        Set-Location -LiteralPath $Dir
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @callArgs 2>&1
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Code = $code; Out = (Get-FlatOutput $out) }
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        $env:PATH = $prevPath
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

function Get-CommitMessage {
    <#
        The last commit's full message with every run of whitespace collapsed to one space.

        THE COLLAPSE IS NOT COSMETIC. The backing note is WRAPPED for commit-body width, so where the
        line break falls is park-lib's decision about rendering rather than a fact about the note -- and
        a phrase assert pinned across it goes red the moment a clause is reworded by a word. Same
        reasoning as Get-FlatOutput above, one layer along.
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return ((((& git -C $Dir log -1 --pretty=%B) | Out-String) -replace '\s+', ' ').Trim())
    } finally { $ErrorActionPreference = $prevEap }
}

function Get-CommitCount {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; return @(& git -C $Dir log --oneline).Count }
    finally { $ErrorActionPreference = $prevEap }
}

function Get-HeadFiles {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; return @(& git -C $Dir diff-tree --no-commit-id --name-only -r HEAD 2>$null) }
    finally { $ErrorActionPreference = $prevEap }
}

function Test-RefOnRemote {
    param([Parameter(Mandatory = $true)][string]$Bare, [Parameter(Mandatory = $true)][string]$Ref)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # NOT judged, and deliberately not Invoke-FixtureGitIn (issue #1635): this is a QUESTION rather
        # than a fixture mutation. A missing ref is the answer the caller asked for and exit 1 is how git
        # gives it, so counting it as a broken fixture would report every negative case as a defect.
        & git -C $Bare rev-parse --verify --quiet $Ref | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $prevEap }
}

function Switch-ToBranch {
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Name)
    $prevEap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; Invoke-FixtureGitIn $Dir checkout -q -b $Name }
    finally { $ErrorActionPreference = $prevEap }
}

function New-PeerDivergence {
    <#
        THE INCIDENT, AS A FIXTURE (#1953). Puts a branch on origin, then has a SECOND CLONE under its own
        identity commit and push to it -- so this checkout is one commit behind a tip that is somebody
        else's. That second identity is the whole point: an amend or a reset produces the same rejection
        under the SAME author, which cannot tell a collision from a fast-forward of your own work from
        another machine, and telling those apart is what the report exists for.

        Written once because three cases below need it (#1953); case (p) predates it and is left as it
        stands -- it is a long-standing assert about a different arm, and rewriting it would put risk on
        the one test that already guards the refused-push path.

        Leaves this session's own copy of the document dirty, which is the state the Stop hook fires in,
        and returns the peer tip so a caller can assert origin was not written over.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$Rel,
        [Parameter(Mandatory = $true)][string]$PeerSubject
    )
    $peer = "$Dir-peer"
    $script:fixtures += $peer
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $Dir add -- $Rel
        Invoke-FixtureGitIn $Dir commit -q -m 'the plan'
        Invoke-FixtureGitIn $Dir push -q -u origin $Branch

        Invoke-FixtureGitJudged @('clone', '-q', "$Dir.git", $peer)
        Invoke-FixtureGitIn $peer config user.email 'other@local.invalid'
        Invoke-FixtureGitIn $peer config user.name 'Other Session'
        Invoke-FixtureGitIn $peer config commit.gpgsign false
        Invoke-FixtureGitIn $peer checkout -q $Branch
        Add-Content -LiteralPath (Join-Path $peer ($Rel -replace '/', '\')) -Value 'their repair'
        Invoke-FixtureGitIn $peer add -A
        Invoke-FixtureGitIn $peer commit -q -m $PeerSubject
        Invoke-FixtureGitIn $peer push -q origin $Branch

        # This session edits its own copy and the turn ends -- the state the Stop hook fires in.
        Add-Content -LiteralPath (Join-Path $Dir ($Rel -replace '/', '\')) -Value 'our repair'

        # NOT judged, and deliberately not Invoke-FixtureGitIn (#1635): a question, not a mutation.
        return ((& git -C "$Dir.git" rev-parse "refs/heads/$Branch") | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
}

try {
    # --- (a) THE HAPPY PATH: a dirty document, no PR -> committed and pushed, one file only ---------
    Write-Host "park-cycle.ps1 -- pushes the development document when no PR exists" -ForegroundColor Cyan
    $fixA = New-Fixture -Label 'a' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixA -Name 'feat/visible-v1'
    $relA = New-CycleDocument -Dir $fixA -Branch 'feat/visible-v1'
    # An unrelated dirty file, the bound that matters most: an AUTOMATIC park that swept this in would
    # publish work in progress nobody asked to publish. park-branch does sweep it, deliberately; this
    # must not.
    [System.IO.File]::WriteAllText((Join-Path $fixA 'stray.txt'), "stray`n", (New-Object System.Text.UTF8Encoding $false))

    $rA = Invoke-ParkCycle -Dir $fixA
    Assert-Equal 0 $rA.Code 'happy path: exit 0'
    Assert-Says $rA.Out 'parked on origin' 'happy path: reports the document reached origin'
    Assert-Equal 2 (Get-CommitCount -Dir $fixA) 'happy path: exactly one park commit on top of the fixture commit'
    $filesA = Get-HeadFiles -Dir $fixA
    Assert-True ($filesA -contains $relA) 'happy path: the commit carries the development document'
    Assert-Equal 1 $filesA.Count 'happy path: and NOTHING else -- the unrelated dirty file stayed out'
    Assert-True (Test-RefOnRemote -Bare "$fixA.git" -Ref 'refs/heads/feat/visible-v1') 'happy path: the branch ref is on origin'
    $msgA = Get-CommitMessage -Dir $fixA
    Assert-True ($msgA -match [regex]::Escape((Get-GitParkScopes)['BranchFiles'])) 'happy path: the commit names the branch-files scope it committed'
    # THE BACKING NOTE (#960), on the ordinary park: it is always stamped, so its ABSENCE cannot be read
    # as "this park was fine". fixA's document carries no steps and one unrelated dirty file.
    Assert-True ($msgA -match [regex]::Escape((Get-GitParkBackingMarker))) 'happy path: the commit body carries the backing note'
    Assert-True ($msgA -match 'no steps written yet') 'happy path: and says the plan has no steps yet rather than reporting zero of zero done'
    Assert-True ($msgA -match '1 file\(s\) uncommitted') 'happy path: it counts the unrelated dirty file as unpublished work'
    Assert-True (-not ($msgA -match 'stray')) 'happy path: COUNTS, NEVER FILENAMES -- the unrelated path is not named in a public commit'
    Assert-True (-not ($msgA -match 'reads as FINISHED')) 'happy path: and no alarm on a plan that never claimed to be finished'
    # The note is BODY, not subject: a `git log --oneline` of a branch stays readable.
    $subjA = ((& git -C $fixA log -1 --pretty=%s) | Out-String).Trim()
    Assert-True (-not ($subjA -match [regex]::Escape((Get-GitParkBackingMarker)))) 'happy path: the note stays out of the subject line'

    # --- (b) IDEMPOTENT: a second run has nothing to do, and says so ------------------------------
    Write-Host "park-cycle.ps1 -- a second run does nothing" -ForegroundColor Cyan
    $rB = Invoke-ParkCycle -Dir $fixA
    Assert-Equal 0 $rB.Code 'second run: exit 0'
    Assert-Says $rB.Out 'already on origin' 'second run: says the document is already on origin'
    Assert-Equal 2 (Get-CommitCount -Dir $fixA) 'second run: no second commit'

    # --- (c) -Quiet: the hook path prints NOTHING when there is nothing to do ---------------------
    # The assert that keeps the hook usable. Without it this would add a line to every turn of every
    # session, which is the difference between a hook nobody notices and one everybody turns off.
    Write-Host "park-cycle.ps1 -- -Quiet is silent when there is nothing to do" -ForegroundColor Cyan
    $rC = Invoke-ParkCycle -Dir $fixA -Quiet
    Assert-Equal 0 $rC.Code '-Quiet: exit 0'
    Assert-Equal '' $rC.Out.Trim() '-Quiet: no output at all'

    # --- (d) THE DEPLOY LOCK (#884): a PR exists -> no commit, no push ----------------------------
    # THE MOST IMPORTANT BOUND IN THE SCRIPT. ship-pr refuses the merge once this document has diverged
    # from what the PR published, so a pusher that kept running after open-pr would block every merge in
    # the repo -- and the failure would read as the lock misbehaving rather than as this.
    Write-Host "park-cycle.ps1 -- a PR exists: the document is the PR's from there on" -ForegroundColor Cyan
    $fixD = New-Fixture -Label 'd' -GhAnswer 'pr'
    Switch-ToBranch -Dir $fixD -Name 'feat/has-a-pr-v1'
    $null = New-CycleDocument -Dir $fixD -Branch 'feat/has-a-pr-v1'

    $rD = Invoke-ParkCycle -Dir $fixD
    Assert-Equal 0 $rD.Code 'PR open: exit 0 -- this is a normal outcome, not an error'
    Assert-Says $rD.Out 'PR #42 for' 'PR open: names the PR it found'
    Assert-Says $rD.Out 'is open' 'PR open: and says which of the three refusals this is'
    Assert-Equal 1 (Get-CommitCount -Dir $fixD) 'PR open: nothing committed'
    Assert-True (-not (Test-RefOnRemote -Bare "$fixD.git" -Ref 'refs/heads/feat/has-a-pr-v1')) 'PR open: nothing pushed'

    # --- (d2) THE PR ALREADY MERGED (#1035): the branch shipped -> no commit, no push --------------
    # THE DEFECT THIS CLOSES. Scoped to `--state open`, this bound lifted at the merge -- and the Stop
    # hook then pushed the branch back onto origin seconds after deleteBranchOnMerge had removed it,
    # where `git ls-remote --heads origin` reports the resurrected head as parked work carrying a
    # `Backing:` line reading '2 of 2 steps resolved'. Measured on PR #1027, whose number this shim uses.
    #
    # THE DOCUMENT IS LEFT DIRTY HERE, deliberately: a clean one would be refused by the gate above for
    # having nothing to do, and would prove nothing about this bound. Dirty is also the real shape --
    # a session standing on the shipped branch after the fold.
    Write-Host "park-cycle.ps1 -- the PR already merged: the branch shipped, so it is not resurrected" -ForegroundColor Cyan
    $fixD2 = New-Fixture -Label 'd2' -GhAnswer 'merged'
    Switch-ToBranch -Dir $fixD2 -Name 'fix/already-shipped-v1'
    $null = New-CycleDocument -Dir $fixD2 -Branch 'fix/already-shipped-v1'

    $rD2 = Invoke-ParkCycle -Dir $fixD2
    Assert-Equal 0 $rD2.Code 'PR merged: exit 0'
    Assert-Says $rD2.Out 'PR #1027 for' 'PR merged: names the PR it found -- which only --state all can return'
    Assert-Says $rD2.Out 'already MERGED' 'PR merged: says the branch shipped, not that a PR is open'
    Assert-Says $rD2.Out 'resurrect' 'PR merged: and names what the push would have done'
    Assert-Equal 1 (Get-CommitCount -Dir $fixD2) 'PR merged: nothing committed'
    Assert-True (-not (Test-RefOnRemote -Bare "$fixD2.git" -Ref 'refs/heads/fix/already-shipped-v1')) 'PR merged: the head is NOT put back on origin'

    # --- (d3) THE PR CLOSED UNMERGED (#992): published all the same -> no commit, no push ----------
    # The head #992 left behind sat 96 files divergent from main, so the other candidate repair -- refuse
    # when HEAD is an ancestor of the trunk -- would have pushed it back happily. Asking about the PR
    # rather than about the trunk is what covers both this and (d2), and this case is what pins that.
    Write-Host "park-cycle.ps1 -- the PR closed unmerged: published, so still not resurrected" -ForegroundColor Cyan
    $fixD3 = New-Fixture -Label 'd3' -GhAnswer 'closed'
    Switch-ToBranch -Dir $fixD3 -Name 'docs/closed-unmerged-v1'
    $null = New-CycleDocument -Dir $fixD3 -Branch 'docs/closed-unmerged-v1'

    $rD3 = Invoke-ParkCycle -Dir $fixD3
    Assert-Equal 0 $rD3.Code 'PR closed: exit 0'
    Assert-Says $rD3.Out 'PR #969 for' 'PR closed: names the PR it found'
    Assert-Says $rD3.Out 'is CLOSED' 'PR closed: says which refusal this is'
    Assert-Says $rD3.Out 'park-branch' 'PR closed: names the escape valve for work that genuinely resumed'
    Assert-Equal 1 (Get-CommitCount -Dir $fixD3) 'PR closed: nothing committed'
    Assert-True (-not (Test-RefOnRemote -Bare "$fixD3.git" -Ref 'refs/heads/docs/closed-unmerged-v1')) 'PR closed: nothing pushed'

    # --- (d4) NO `state` IN THE PAYLOAD: the wording degrades, the REFUSAL does not ----------------
    # Set-StrictMode -Version Latest THROWS on a property gh did not return, so an older gh or a changed
    # --json field would take the whole script down mid-bound -- and this script always exits 0 because a
    # hook that fails interrupts the work it was added to protect. The guarded read must cost the
    # sentence and nothing else.
    Write-Host "park-cycle.ps1 -- a payload without 'state': the refusal survives the missing field" -ForegroundColor Cyan
    $fixD4 = New-Fixture -Label 'd4' -GhAnswer 'pr-nostate'
    Switch-ToBranch -Dir $fixD4 -Name 'feat/no-state-field-v1'
    $null = New-CycleDocument -Dir $fixD4 -Branch 'feat/no-state-field-v1'

    $rD4 = Invoke-ParkCycle -Dir $fixD4
    Assert-Equal 0 $rD4.Code 'no state field: exit 0, not a mid-bound crash'
    Assert-Says $rD4.Out 'PR #42 for' 'no state field: still names the PR'
    Assert-True ($rD4.Out -notmatch 'cannot be found on this object') 'no state field: StrictMode did not throw'
    Assert-Equal 1 (Get-CommitCount -Dir $fixD4) 'no state field: nothing committed'
    Assert-True (-not (Test-RefOnRemote -Bare "$fixD4.git" -Ref 'refs/heads/feat/no-state-field-v1')) 'no state field: nothing pushed'

    # --- (e) gh CANNOT ANSWER -> fail-safe: do not push -------------------------------------------
    # gh missing, logged out, offline, or an unparseable payload all arrive here. Being one turn stale is
    # a nuisance; an unmergeable branch is a defect, so unknown does not push.
    Write-Host "park-cycle.ps1 -- gh cannot answer: fail-safe, no push" -ForegroundColor Cyan
    $fixE = New-Fixture -Label 'e' -GhAnswer 'fail'
    Switch-ToBranch -Dir $fixE -Name 'feat/gh-broken-v1'
    $null = New-CycleDocument -Dir $fixE -Branch 'feat/gh-broken-v1'

    $rE = Invoke-ParkCycle -Dir $fixE
    Assert-Equal 0 $rE.Code 'gh failing: exit 0'
    Assert-Says $rE.Out 'not pushing' 'gh failing: says it is not pushing'
    Assert-Says $rE.Out 'DEPLOY lock' 'gh failing: and names the reason, so the direction is not read as a bug'
    Assert-Equal 1 (Get-CommitCount -Dir $fixE) 'gh failing: nothing committed'
    Assert-True (-not (Test-RefOnRemote -Bare "$fixE.git" -Ref 'refs/heads/feat/gh-broken-v1')) 'gh failing: nothing pushed'

    # --- (f) ON THE TRUNK: nothing to do, and it says why ----------------------------------------
    Write-Host "park-cycle.ps1 -- on the trunk, where the fold removes this document" -ForegroundColor Cyan
    $fixF = New-Fixture -Label 'f' -GhAnswer 'none'
    $null = New-CycleDocument -Dir $fixF -Branch 'feat/not-checked-out-v1'

    $rF = Invoke-ParkCycle -Dir $fixF
    Assert-Equal 0 $rF.Code 'trunk: exit 0'
    Assert-Says $rF.Out 'on the trunk' 'trunk: names the trunk rule'
    Assert-Equal 1 (Get-CommitCount -Dir $fixF) 'trunk: nothing committed'

    # --- (g) A RESET DOCUMENT declares no branch -> left alone -----------------------------------
    # Resolve-BranchFilePath falls back to a path that merely EXISTS when nothing claims the branch, so
    # without this check a branch created outside new-branch would push the trunk's own empty document
    # under a `park:` subject.
    Write-Host "park-cycle.ps1 -- a reset document belongs to no branch" -ForegroundColor Cyan
    $fixG = New-Fixture -Label 'g' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixG -Name 'feat/reset-doc-v1'
    $null = New-CycleDocument -Dir $fixG -Branch ''

    $rG = Invoke-ParkCycle -Dir $fixG
    Assert-Equal 0 $rG.Code 'reset document: exit 0'
    Assert-Says $rG.Out 'reset state' 'reset document: says the document belongs to no branch'
    Assert-Equal 1 (Get-CommitCount -Dir $fixG) 'reset document: nothing committed'

    # --- (h) SOMEBODY ELSE'S DOCUMENT -> left alone, owner named ---------------------------------
    Write-Host "park-cycle.ps1 -- a document belonging to another branch is left alone" -ForegroundColor Cyan
    $fixH = New-Fixture -Label 'h' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixH -Name 'feat/current-branch-v1'
    $null = New-CycleDocument -Dir $fixH -Branch 'docs/somebody-else-v1'

    $rH = Invoke-ParkCycle -Dir $fixH
    Assert-Equal 0 $rH.Code "other branch's document: exit 0"
    Assert-Says $rH.Out 'docs/somebody-else-v1' "other branch's document: names the owner"
    Assert-Says $rH.Out 'left alone' "other branch's document: says it kept its hands off"
    Assert-Equal 1 (Get-CommitCount -Dir $fixH) "other branch's document: nothing committed"

    # --- (i) NO ORIGIN: nowhere to park to, and that is not a failure ----------------------------
    Write-Host "park-cycle.ps1 -- no 'origin' remote" -ForegroundColor Cyan
    $fixI = New-Fixture -Label 'i' -GhAnswer 'none' -NoOrigin
    Switch-ToBranch -Dir $fixI -Name 'feat/no-remote-v1'
    $null = New-CycleDocument -Dir $fixI -Branch 'feat/no-remote-v1'

    $rI = Invoke-ParkCycle -Dir $fixI
    Assert-Equal 0 $rI.Code 'no origin: exit 0'
    Assert-Says $rI.Out "no 'origin' remote" 'no origin: says why nothing happened'
    Assert-Equal 1 (Get-CommitCount -Dir $fixI) 'no origin: nothing committed'

    # --- (j) NO DOCUMENT AT ALL: nothing to park ------------------------------------------------
    Write-Host "park-cycle.ps1 -- no development document on disk" -ForegroundColor Cyan
    $fixJ = New-Fixture -Label 'j' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixJ -Name 'feat/no-document-v1'

    $rJ = Invoke-ParkCycle -Dir $fixJ
    Assert-Equal 0 $rJ.Code 'no document: exit 0'
    Assert-Says $rJ.Out 'does not exist yet' 'no document: says there is nothing to park'
    Assert-Equal 1 (Get-CommitCount -Dir $fixJ) 'no document: nothing committed'

    # --- (k) AN UNPUSHED LOCAL COMMIT is invisibility too --------------------------------------
    # A committed-but-unpushed document is the real-world case park was written for (#175): the gate is
    # "is it on origin", not "is the file dirty".
    Write-Host "park-cycle.ps1 -- a committed but unpushed document is still pushed" -ForegroundColor Cyan
    $fixK = New-Fixture -Label 'k' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixK -Name 'feat/committed-not-pushed-v1'
    $relK = New-CycleDocument -Dir $fixK -Branch 'feat/committed-not-pushed-v1'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixK add -- $relK
        Invoke-FixtureGitIn $fixK commit -q -m 'cycle by hand'
    } finally { $ErrorActionPreference = $prevEap }

    $rK = Invoke-ParkCycle -Dir $fixK
    Assert-Equal 0 $rK.Code 'unpushed commit: exit 0'
    Assert-Says $rK.Out 'parked on origin' 'unpushed commit: pushed anyway'
    Assert-Equal 2 (Get-CommitCount -Dir $fixK) 'unpushed commit: no empty extra commit was made'
    Assert-True (Test-RefOnRemote -Bare "$fixK.git" -Ref 'refs/heads/feat/committed-not-pushed-v1') 'unpushed commit: the branch ref is on origin'

    # --- (l) THE TRUNK SEAM: a consumer whose trunk is not 'main' -------------------------------
    # THE ASSERT IS INVERTED ON PURPOSE, which is what makes it prove anything. This repo's trunk is
    # 'master' here, and the branch checked out is called 'main' -- so a script that assumed 'main' is
    # the trunk would refuse with "on the trunk" and look perfectly well-behaved doing it. Only a script
    # that actually reads Get-TrunkBranchName parks this branch.
    #
    # It also pins the layer this script deliberately does NOT have: it asks Get-BranchTrunkName, which
    # probes that seam itself, rather than probing the seam a second time on its own.
    Write-Host "park-cycle.ps1 -- reads the consumer's trunk name, so 'main' can be an ordinary branch" -ForegroundColor Cyan
    $fixL = New-Fixture -Label 'l' -GhAnswer 'none' -TrunkName 'master'
    # The fixture's initial commit already sits on 'main'; here that is a FEATURE branch, not the trunk.
    $relL = New-CycleDocument -Dir $fixL -Branch 'main'

    $rL = Invoke-ParkCycle -Dir $fixL
    Assert-Equal 0 $rL.Code 'trunk seam: exit 0'
    Assert-True (-not (Test-Says $rL.Out 'on the trunk')) "trunk seam: 'main' is NOT treated as the trunk -- the seam was read"
    Assert-Says $rL.Out 'parked on origin' 'trunk seam: and the branch was parked'
    Assert-True ((Get-HeadFiles -Dir $fixL) -contains $relL) 'trunk seam: the commit carries the development document'

    # --- (m) THE SHAPE #960 WAS MEASURED ON: a plan that reads as FINISHED with nothing behind it -----
    # THE ASSERT THIS WHOLE MECHANISM EXISTS FOR. The measured branch had eight resolved CREATE steps, a
    # diff against the trunk consisting of the cycle document alone, and the work uncommitted in another
    # device's working copy. From origin that is indistinguishable from a finished branch, and the more
    # complete the ticks the more convincing the wrong reading -- a session picking it up either rebuilds
    # work that already exists or opens a PR that merges the document alone.
    Write-Host "park-cycle.ps1 -- a plan that reads as finished with nothing behind it says so" -ForegroundColor Cyan
    $fixM = New-Fixture -Label 'm' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixM -Name 'feat/ticked-but-empty-v1'
    $null = New-CycleDocument -Dir $fixM -Branch 'feat/ticked-but-empty-v1' `
        -Body "### CREATE`n`n- [x] wrote the reader`n- [x] wrote the writer`n"
    # The work, uncommitted -- which is what the other device's checkout looked like.
    [System.IO.File]::WriteAllText((Join-Path $fixM 'reader.ps1'), "# work`n", (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText((Join-Path $fixM 'writer.ps1'), "# work`n", (New-Object System.Text.UTF8Encoding $false))

    $rM = Invoke-ParkCycle -Dir $fixM
    Assert-Equal 0 $rM.Code 'finished plan: exit 0 -- the note is a note, never a gate'
    Assert-Says $rM.Out 'parked on origin' 'finished plan: and the park still happened, which is the point of it not being a gate'
    $msgM = Get-CommitMessage -Dir $fixM
    Assert-True ($msgM -match '2 of 2 step\(s\) resolved') 'finished plan: the note counts the resolved steps'
    Assert-True ($msgM -match 'nothing else committed on this branch') 'finished plan: and says nothing else is committed'
    Assert-True ($msgM -match 'reads as FINISHED') 'finished plan: the alarm fires -- this is the state that misleads a reader'
    Assert-True ($msgM -match 'not missing') 'finished plan: and it says the work is uncommitted elsewhere rather than gone'
    Assert-True ($msgM -match 'Do NOT rebuild it') 'finished plan: naming the wrong move a good-faith pickup would make'
    Assert-True (-not ($msgM -match 'reader\.ps1')) 'finished plan: still counts only -- the uncommitted paths are not published'
    Assert-Equal 1 (Get-HeadFiles -Dir $fixM).Count 'finished plan: and bound 1 holds -- the commit is the document alone'

    # --- (n) A HALF-DONE PLAN GETS THE NUMBERS AND NO ALARM ------------------------------------------
    # THE ASSERT THAT KEEPS THE ALARM WORTH READING. 'Any resolved step with nothing committed' would fire
    # on nearly every early park -- a planning step ticked before a line of code exists is the ordinary
    # case -- and an alarm that fires on almost every park is one nobody reads by the time it matters.
    Write-Host "park-cycle.ps1 -- a half-done plan gets the numbers, not the alarm" -ForegroundColor Cyan
    $fixN = New-Fixture -Label 'n' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixN -Name 'feat/half-done-v1'
    $null = New-CycleDocument -Dir $fixN -Branch 'feat/half-done-v1' `
        -Body "### CREATE`n`n- [x] read the code`n- [ ] change it`n"

    $rN = Invoke-ParkCycle -Dir $fixN
    Assert-Equal 0 $rN.Code 'half-done plan: exit 0'
    $msgN = Get-CommitMessage -Dir $fixN
    Assert-True ($msgN -match '1 of 2 step\(s\) resolved') 'half-done plan: the numbers are still there'
    Assert-True (-not ($msgN -match 'reads as FINISHED')) 'half-done plan: and the alarm stays silent, because one step is still open'
    Assert-True ($msgN -match 'nothing uncommitted') 'half-done plan: a clean working copy is stated rather than left blank'

    # --- (o) A REJECTED PUSH STILL EXITS 0 -- the Stop-hook contract (#1275) ------------------------
    # THE DEFECT: Invoke-GitPark wrote its push-failure summary with a bare Write-Error, and every caller
    # -- this one included -- runs under $ErrorActionPreference = 'Stop', where Write-Error TERMINATES. So
    # `return $false` was dead code, the `if (-not $ok)` arm below the call never ran, and a rejected push
    # (the ordinary divergence case this script's own note names) took park-cycle out non-zero -- on a hook
    # whose header promises "ALWAYS EXITS 0". Nothing here could see it: every other case reaches a push
    # that SUCCEEDS or no push at all.
    #
    # The fixture diverges with `git commit --amend` rather than a reset -- it rewrites the local tip so it
    # is no longer a descendant of what origin holds, the same rejection with none of the destructive
    # shape. Same technique as park-branch.tests.ps1 (d3).
    Write-Host "park-cycle.ps1 -- a rejected push is reported, not thrown, and the hook still exits 0" -ForegroundColor Cyan
    $fixO = New-Fixture -Label 'o' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixO -Name 'fix/diverged-v1'
    $relO = New-CycleDocument -Dir $fixO -Branch 'fix/diverged-v1'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixO add -- $relO
        Invoke-FixtureGitIn $fixO commit -q -m 'cycle by hand'
        Invoke-FixtureGitIn $fixO push -q -u origin 'fix/diverged-v1'
        # Rewrite the tip origin already has: local and origin now share no descendant line.
        Invoke-FixtureGitIn $fixO commit -q --amend -m 'cycle by hand (rewritten)'
    } finally { $ErrorActionPreference = $prevEap }

    $rO = Invoke-ParkCycle -Dir $fixO
    Assert-Equal 0 $rO.Code 'rejected push: exit 0 -- the Stop-hook contract holds'
    Assert-Says $rO.Out 'could NOT be pushed' 'rejected push: the caller-owned line is reached, not a raw terminating error'

    # --- (p) THE COLLISION IS NAMED, NOT HINTED AT (#1600) -----------------------------------------
    # WHAT (o) ABOVE CANNOT SEE. It proves the failure arm is REACHED; it says nothing about whether what
    # that arm prints is usable. Until #1600 it printed "run park-cycle by hand for the reason (diverged
    # from origin?)" -- a question mark over an answer the run already held, sending the reader for a
    # second run to learn what the first one could have said.
    #
    # WHY THAT MATTERED ENOUGH TO TEST. This script is the EARLIEST detector of two sessions on one
    # branch: it runs every turn, so from the moment the other side pushes, every turn of this one ends
    # in a refused push. Measured on feat/plugin-version-overview, September 8, 2026: two sessions ran
    # the same pre-PR review in full from one handoff note, each finding real defects the other missed,
    # and the collision was not learned until open-pr refused the push roughly half an hour later.
    #
    # THE FIXTURE IS THE INCIDENT, not an amend: a SECOND CLONE commits under a DIFFERENT IDENTITY and
    # pushes, which is what makes the author line the assert below is really about. An amend (as in (o))
    # produces the same rejection with the same author, so it could not tell a collision from a
    # fast-forward of your own autopark -- which is exactly the distinction this report exists to draw.
    Write-Host "park-cycle.ps1 -- a rejected push names the other session, not '(diverged from origin?)'" -ForegroundColor Cyan
    $fixP = New-Fixture -Label 'p' -GhAnswer 'none'
    Switch-ToBranch -Dir $fixP -Name 'feat/two-sessions-v1'
    $relP = New-CycleDocument -Dir $fixP -Branch 'feat/two-sessions-v1'
    $peerP = "$fixP-peer"
    $script:fixtures += $peerP
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixP add -- $relP
        Invoke-FixtureGitIn $fixP commit -q -m 'the handoff note'
        Invoke-FixtureGitIn $fixP push -q -u origin 'feat/two-sessions-v1'

        # The other session: its own clone, its own identity, its own park on the shared branch.
        Invoke-FixtureGitJudged @('clone', '-q', "$fixP.git", $peerP)
        Invoke-FixtureGitIn $peerP config user.email 'other@local.invalid'
        Invoke-FixtureGitIn $peerP config user.name 'Other Session'
        Invoke-FixtureGitIn $peerP config commit.gpgsign false
        Invoke-FixtureGitIn $peerP checkout -q 'feat/two-sessions-v1'
        Add-Content -LiteralPath (Join-Path $peerP ($relP -replace '/', '\')) -Value 'their round'
        Invoke-FixtureGitIn $peerP add -A
        Invoke-FixtureGitIn $peerP commit -q -m 'park: feat/two-sessions-v1 (all outstanding work)'
        Invoke-FixtureGitIn $peerP push -q origin 'feat/two-sessions-v1'

        # This session edits its own copy and the turn ends -- the state the Stop hook fires in.
        Add-Content -LiteralPath (Join-Path $fixP ($relP -replace '/', '\')) -Value 'our round'
    } finally { $ErrorActionPreference = $prevEap }

    $rP = Invoke-ParkCycle -Dir $fixP
    Assert-Equal 0 $rP.Code 'collision: exit 0 -- the Stop-hook contract still holds'
    Assert-Says $rP.Out 'Other Session' 'collision: the report names WHO is on the other side'
    Assert-Says $rP.Out 'all outstanding work' 'collision: and their commit subject, which is what separates it from your own autopark'
    Assert-Says $rP.Out 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH' 'collision: the reader is told what it means, not only what happened'
    Assert-Says $rP.Out 'git pull --ff-only' 'collision: and what to do about it'
    if (Test-Says -Text $rP.Out -Phrase 'diverged from origin?') {
        $script:fail++; Write-Host "  [FAIL] collision: the hedged wording is gone`n         still found: '(diverged from origin?)'" -ForegroundColor Red
    } else {
        $script:pass++; Write-Host '  [PASS] collision: the hedged wording is gone' -ForegroundColor Green
    }
    # -NoFailureMessage (#1600): Invoke-GitPark's own sentence is suppressed for THIS caller, because the
    # hook merges the child's stderr into what it prints and a PowerShell error banner directly above the
    # report reads as the hook having broken. The verdict is unchanged -- the arm above still ran.
    if (Test-Says -Text $rP.Out -Phrase 'Invoke-GitPark :') {
        $script:fail++; Write-Host "  [FAIL] collision: no PowerShell error banner above the report`n         still found: 'Invoke-GitPark :'" -ForegroundColor Red
    } else {
        $script:pass++; Write-Host '  [PASS] collision: no PowerShell error banner above the report' -ForegroundColor Green
    }
    # --- (q) THE OPEN-PR ARM LOOKS, THOUGH IT STILL DOES NOT PUSH (#1953) --------------------------
    # WHAT (p) ABOVE CANNOT SEE, AND WHY THAT MATTERED. (p) proves the collision report is right; it can
    # only prove it on a branch with NO PR, because the report was a side effect of a refused push and
    # bound (d) refuses the push the moment a PR exists. So for every branch with an open PR -- which is
    # every branch from open-pr until the merge -- this script ran to that bound and stopped, and under
    # -Quiet it stopped in silence. The "earliest detector" claim was true only where the push happened.
    #
    # THE BRANCH IT WAS BLIND ON IS THE WORST ONE. Measured September 13, 2026 (#1953): two sessions on
    # one account repaired the same red required check on one open PR about 90 seconds apart, wrote the
    # same three-file change, and learned of each other from git's non-fast-forward refusal at the push
    # -- after the diagnosis, the repair, the suite run and the lint gate had been paid for twice.
    #
    # THE FIXTURE IS (p)'s, WITH A PR. Same peer clone under its own identity, because the author line is
    # what separates a collision from a fast-forward of your own work from another machine -- and this
    # time the gh shim answers with an open PR, so the run reaches the bound rather than the push.
    Write-Host "park-cycle.ps1 -- an open PR stops the push, not the looking" -ForegroundColor Cyan
    $fixQ = New-Fixture -Label 'q' -GhAnswer 'pr'
    Switch-ToBranch -Dir $fixQ -Name 'fix/red-check-v1'
    $relQ = New-CycleDocument -Dir $fixQ -Branch 'fix/red-check-v1'
    $peerTipQ = New-PeerDivergence -Dir $fixQ -Branch 'fix/red-check-v1' -Rel $relQ `
                                   -PeerSubject 'fix: the same red check, repaired'

    $rQ = Invoke-ParkCycle -Dir $fixQ
    Assert-Equal 0 $rQ.Code 'open-PR collision: exit 0 -- the Stop-hook contract still holds'
    Assert-Says $rQ.Out 'PR #42' 'open-PR collision: the report names the PR that is holding the push back'
    Assert-Says $rQ.Out 'pushes nothing' 'open-PR collision: and says outright that this run pushed nothing'
    Assert-Says $rQ.Out 'Other Session' 'open-PR collision: the report names WHO is on the other side'
    Assert-Says $rQ.Out 'the same red check, repaired' 'open-PR collision: and their commit subject, which is what makes it a collision rather than your own push'
    Assert-Says $rQ.Out 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH' 'open-PR collision: the reader is told what it means, not only what happened'
    Assert-Says $rQ.Out 'git pull --ff-only' 'open-PR collision: and what to do about it'
    # THE BOUND IS UNTOUCHED, which is the half that must not regress: the DEPLOY lock refuses the merge
    # once this document has diverged from what the PR published, so a run that LOOKED and then also
    # wrote would block every merge in the repo.
    Assert-Equal 2 (Get-CommitCount -Dir $fixQ) 'open-PR collision: nothing committed -- the bound still refuses the write'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Assert-Equal $peerTipQ ((((& git -C "$fixQ.git" rev-parse 'refs/heads/fix/red-check-v1') | Out-String).Trim())) 'open-PR collision: origin still carries the other session tip -- nothing was pushed over it'
    } finally { $ErrorActionPreference = $prevEap }

    # AND IT SURVIVES -Quiet, which is the only assert that matters for the hook: -Quiet is what
    # cycle-autopark passes, so a report suppressed by it is a report nobody ever reads. The bound's own
    # "PR #42 ... is open" note stays suppressed -- that one IS "nothing to do".
    $rQ2 = Invoke-ParkCycle -Dir $fixQ -Quiet
    Assert-Equal 0 $rQ2.Code 'open-PR collision under -Quiet: exit 0'
    Assert-Says $rQ2.Out 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH' 'open-PR collision under -Quiet: the collision still reports itself -- this is the path the Stop hook runs'
    Assert-Says $rQ2.Out 'Other Session' 'open-PR collision under -Quiet: with the other side named'

    # --- (r) AND ONLY AN OPEN PR BUYS THE ROUND TRIP -----------------------------------------------
    # The bound above covers merged and closed PRs too, and there the answer stays silence: the branch
    # has shipped or its PR ended, so a divergence is not two sessions building the same repair. This
    # path runs on every turn that has anything to push, so the network call is bought rather than
    # assumed -- and this is the assert that keeps it bought.
    Write-Host "park-cycle.ps1 -- a merged PR buys no fetch: the branch shipped, so a divergence is not a collision" -ForegroundColor Cyan
    $fixR = New-Fixture -Label 'r' -GhAnswer 'merged'
    Switch-ToBranch -Dir $fixR -Name 'fix/already-shipped-v1'
    $relR = New-CycleDocument -Dir $fixR -Branch 'fix/already-shipped-v1'
    $null = New-PeerDivergence -Dir $fixR -Branch 'fix/already-shipped-v1' -Rel $relR `
                               -PeerSubject 'park: fix/already-shipped-v1 (all outstanding work)'

    $rR = Invoke-ParkCycle -Dir $fixR
    Assert-Equal 0 $rR.Code 'merged PR, diverged origin: exit 0'
    Assert-Says $rR.Out 'already MERGED' 'merged PR, diverged origin: the bound still says which refusal this is'
    Assert-True (-not (Test-Says -Text $rR.Out -Phrase 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH')) 'merged PR, diverged origin: and no collision report -- a shipped branch buys no round trip'

    # --- (s) AN UNKNOWN PR STATE IS TREATED AS OPEN, AND IT REPORTS ---------------------------------
    # The gh payload may carry no `state` field at all -- an older gh, a changed --json field, a
    # hand-rolled shim -- and the bound above degrades that to the wording an open PR gets. Case (d4)
    # already proves the degraded WORDING survives StrictMode; it sets up no divergence, so it says
    # nothing about whether the arm added here runs. This is the half that decides the direction: an
    # unknown state must buy the look, because the alternative is the collision going unreported on a
    # branch this run could not classify -- which is the exact silence #1953 was filed for.
    Write-Host "park-cycle.ps1 -- a PR whose state gh did not return still buys the look" -ForegroundColor Cyan
    $fixS = New-Fixture -Label 's' -GhAnswer 'pr-nostate'
    Switch-ToBranch -Dir $fixS -Name 'fix/state-unknown-v1'
    $relS = New-CycleDocument -Dir $fixS -Branch 'fix/state-unknown-v1'
    $peerTipS = New-PeerDivergence -Dir $fixS -Branch 'fix/state-unknown-v1' -Rel $relS `
                                   -PeerSubject 'fix: their round on the same branch'

    $rS = Invoke-ParkCycle -Dir $fixS
    Assert-Equal 0 $rS.Code 'unknown PR state: exit 0, not a mid-arm crash'
    Assert-True ($rS.Out -notmatch 'cannot be found on this object') 'unknown PR state: StrictMode did not throw on the way into the new arm'
    Assert-Says $rS.Out 'Other Session' 'unknown PR state: the collision is reported -- an unclassifiable PR buys the look rather than losing it'
    Assert-Says $rS.Out 'their round on the same branch' 'unknown PR state: with their commit subject'
    Assert-Equal 2 (Get-CommitCount -Dir $fixS) 'unknown PR state: and still nothing committed -- the bound holds whatever the state was'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Assert-Equal $peerTipS ((((& git -C "$fixS.git" rev-parse 'refs/heads/fix/state-unknown-v1') | Out-String).Trim())) 'unknown PR state: origin still carries the other session tip'
    } finally { $ErrorActionPreference = $prevEap }
} finally {
    foreach ($f in $script:fixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'park-cycle.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
