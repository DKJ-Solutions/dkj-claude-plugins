<#
.SYNOPSIS
    Shared fixture, assert helpers and child runner for the three new-branch suites -- the regression
    tests for scripts/task/new-branch.ps1: branch creation plus the two files the branch works in, in a
    single idempotent call.

    ONE SCRIPT SINCE AUGUST 7, 2026. The file writing used to live in a sibling,
    scripts/release/new-changelog-entry.ps1, invoked as a child process. These tests were the safety
    net for that merge: they run the real script end to end, so a behaviour that survived the splice
    is a behaviour these asserts saw.

.DESCRIPTION
    NOT NAMED *.tests.ps1 ON PURPOSE: the test gate globs that pattern, and this file asserts
    nothing. It is dot-sourced by the three suites that do:

      new-branch.tests.ps1           (0) and (v)-(z) -- resuming, the remote head, and the refusals
                                     made before anything is created
      new-branch-document.tests.ps1  (a)-(r) -- the name, the branch document, -Park and the push
      new-branch-base.tests.ps1      (s)-(u) and (x) -- the base's freshness and the already-done check

    WHY IT IS MORE THAN ONE FILE (#2304, September 23, 2026). The gate parallelises per FILE, and once
    the check-plugin-integrity family had been split and CI moved to five shards, this was the file
    that set the floor: 392.5s on CI (runs 35902838420, 35900890044, 35899919410) against a work bound
    of about 330s over 20 lanes, with the next-heaviest suite at 229.4s. Cut at scenario boundaries and
    balanced on measured time -- standalone on one workstation the single file took 149s, and the three
    parts take about 49s, 54s and 46s of it. Every scenario already built its OWN fixture, so unlike the
    integrity family nothing had to be rebuilt per part: the split costs three process starts and the
    lib loads above, not a fixture each.

    NOTHING WAS REMOVED TO BUY THE TIME. The three suites carry the same scenarios, the asserts still
    sum to the 302 the single file reported, verified by running them, and no scenario reads state
    another one created -- checked for every variable before the cut, which is the property a
    cost-based partition may not depend on.

    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL scripts
    (copied into a throwaway temp git repo, so the branch/checkout mutations never touch the own
    working copy) and asserts on exit code + output + git state.

    new-branch.ps1 itself calls 'exit' -- that is why it is run here as a CHILD PROCESS
    (powershell -File), otherwise 'exit' would abort the test runner itself. The git mutation
    commands in new-branch
    already run under ErrorActionPreference=Continue themselves (the #107 pitfall, see
    shared-scripts.tests.ps1) -- these suites mirror the same caution around THEIR OWN calls
    (child invocation and the git fixture setup).

    EACH SUITE BUILDS ITS OWN FIXTURES, under per-process directory names ($PID in New-Fixture). They
    run CONCURRENTLY under the gate, so a shared path would have them tearing down each other's trees.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot         = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
# AND ITS RUNTIME SIBLING -- issue #1934. fixture-git-lib judges the calls that BUILD the fixture; this
# one judges the child that RUNS in it. A child that dies during load never reaches its first statement,
# so what the asserts below report is the absence of a document nothing wrote -- naming the missing lib
# not at all, while the child's own output named it all along.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')
$NewBranchSrc     = Join-Path $RepoRoot 'scripts\task\new-branch.ps1'
$BranchInfoSrc    = Join-Path $RepoRoot 'scripts\lib\branch-info.ps1'
# new-branch -Park dot-sources this sibling shared lib for its git push (the #107 stderr guard),
# so the fixture must carry it too.
$NativeCaptureSrc = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
$RunProgressSrc = Join-Path $RepoRoot 'scripts\lib\run-progress-lib.ps1'
# And since #507 the -Park path dot-sources the shared park implementation as well: Invoke-GitPark does
# the stage/commit/push that used to be written out here AND in park-branch.ps1, in two copies that had
# drifted into writing the same commit message for different scopes.
$ParkLibSrc       = Join-Path $RepoRoot 'scripts\lib\park-lib.ps1'
# park-lib dot-sources this one (#1682), guarded -- so a fixture that omits it loses Get-GitParkBacking
# silently rather than crashing. park-cycle.tests.ps1 is where that cost ten asserts.
$PorcelainSrc     = Join-Path $RepoRoot 'scripts\lib\git-porcelain-lib.ps1'
# new-branch.ps1 dot-sources this for the entry format -- the single source it shares with open-pr.ps1's
# scaffold gate. Without it in the fixture, every entry-writing case here dies on a raw path-not-found
# instead of testing anything.
$EntryScaffoldSrc = Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1'
# The changelog seam, which new-branch reads since inbound #967 to state the right link base in the guidance
# it writes. It arrives with the plugin in a real consumer; a hand-built fixture has to be handed it.
$SeamLibSrc       = Join-Path $RepoRoot 'scripts\lib\seam-lib.ps1'
# The already-done check's pure half (#1409) -- ConvertTo-IssueNumberList and Get-TargetIssueWarnings,
# which -Resolves below runs against. Without it in the fixture, every -Resolves case here dies on a
# raw path-not-found instead of testing anything, exactly like the entry-scaffold lib above.
$PrIssuesLibSrc   = Join-Path $RepoRoot 'scripts\lib\pr-issues-lib.ps1'
# And the IMPURE half (inbound #2056) -- Get-ClosedIssueSet, which asks gh what each cited number
# actually IS so the pure half can be told rather than infer it. Its own file precisely because the lib
# above is pure; same fixture consequence as every lib here, and the (x) cases below drive it through
# their fake gh.
$IssueStateLibSrc = Join-Path $RepoRoot 'scripts\lib\issue-state-lib.ps1'
# The remote-ahead note composer (issue #1450), extracted out of new-branch.ps1 into its own shared
# lib once open-pr.ps1 became a second reader. Without it in the fixture, every resume case below dies
# on a raw path-not-found instead of testing anything, exactly like the two libs above.
$RemoteAheadLibSrc = Join-Path $RepoRoot 'scripts\lib\remote-ahead-lib.ps1'
# remote-ahead-lib.ps1 dot-sources this for Get-DisplayRef (issue #1623), so a fixture that copies the one
# without the other builds a repo whose scripts die on a missing function.
$RefPrintLibSrc = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'
# Direct Test-BranchName calls (separate from the CLI) for the empty/whitespace-only case --
# PowerShell's mandatory-param binding catches an empty -Name via the CLI with a generic error, so
# the exact Reason text can only be tested directly.
. $BranchInfoSrc
# The asserts read the branch files' paths and their branch line from the lib rather than from literals,
# so a path change breaks the writer and the test together instead of leaving the test asserting a stale
# location that still passes.
. $EntryScaffoldSrc
# Same reasoning for the park scopes: the -Park asserts read the commit-subject phrases from Get-GitParkScopes
# rather than repeating them, so rewording a scope cannot leave a test matching text nobody writes any more.
. $ParkLibSrc
# And Invoke-NativeCapture for THIS suite's own use, not only for the fixtures it copies the lib into
# (issue #1446): the adversarial-tip case has to read a commit subject back from git as DATA, and `& git`
# decodes it with the console code page. Dot-sourced here so the read is the same mechanism the script
# under test uses -- a fixture copy would not be in this process's scope.
. $NativeCaptureSrc
# Get-RemoteFetchStampPath, for THIS suite's own use (issue #1915): Invoke-NewBranch below clears the
# fetch-attempt record before every run, and the path that record lives at is the lib's to name rather
# than a literal here that would go stale the first time it moves. Dot-sourced after native-capture,
# which it needs.
. (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1')

$script:pass = 0
$script:fail = 0

function Get-FlatOutput {
    <#
        Captured child output with ALL whitespace removed, so a phrase assert cannot fail on line breaks
        that the behaviour under test does not decide. Pair it with Test-Phrase, which strips the expected
        phrase the same way.

        A native child's stderr captured with 2>&1 does not arrive as plain text: PowerShell wraps each
        line in a NativeCommandError, renders it with a 'powershell.exe : ' prefix, and WRAPS the whole
        record at the HOST WIDTH. The wrap point therefore moves with the width of the window the suite
        happens to run in and with the length of the fixture's temp path (the user name and $PID are both
        in it) -- none of which is a property of new-branch.ps1.

        Measured August 3, 2026 at width 176: the record broke MID-WORD into '... Branch name mus' plus
        't not be 'main'.', so the assert on "must not be 'main'" failed while the script was behaving
        exactly as specified, and CI -- whose narrower, piped width put the whole phrase on the next line
        -- stayed green on the same commit. That is a test failing on its own formatting.

        Mid-word is why the newlines are REMOVED rather than collapsed to a space: '\s+' -> ' ' turns that
        record into 'name mus t not be', which still does not match.

        THAT WAS STILL NOT ENOUGH, and the rest was measured on August 3, 2026 at width 198. Two separate
        things were happening, and only the first was understood:

          1. The CHILD wraps its own Write-Error output at its own width, so its stderr genuinely arrives
             as two lines, split anywhere -- including ON A SPACE. Removing the newline then GLUES the
             words ("token" + "'final'" -> "token'final'"), so an assert on "token 'final'" fails for the
             mirror-image reason the mid-word case failed. No single substitution fixes both, because the
             wrap point is not recoverable from the wrapped text. Hence: strip ALL whitespace here, and
             strip it from the expected phrase too -- that is Test-Phrase below.

          2. The PARENT then wrapped each of those stderr lines in its own NativeCommandError and rendered
             the SECOND record's header, category and FullyQualifiedErrorId BETWEEN the two halves. The
             captured text read '...the token 'fina' + ~300 characters of error-record decoration + 'l'.'.
             No whitespace normalization can survive that -- the phrase is not merely reformatted, it has
             other content inserted into the middle of it. That is why Invoke-CapturedChild below stops
             using '2>&1' and captures the child's stderr as PLAIN TEXT via a redirect file.

        The two fixes are independent and both are needed: (2) removes the interleaving, (1) survives the
        child's own wrap that remains afterwards.
    #>
    param($Captured)
    return (($Captured | Out-String) -replace '\s', '')
}

function Test-Phrase {
    <# True when $Text contains $Phrase, comparing both with all whitespace removed -- the matching half of
       Get-FlatOutput's normalization (see the wrap reasoning there). Use this instead of -match for any
       assert on captured CHILD output; a regex against flattened text would have to encode the same
       stripping in every pattern, and the one that forgets is the one that fails at some window width
       nobody is looking at. #>
    param([string]$Text, [string]$Phrase)
    return $Text.Contains((Get-Squeezed $Phrase))
}

function Get-Squeezed {
    <# The stripping itself, named once (#1417). Test-Phrase answers "is it in there"; an assert that
       COUNTS occurrences cannot use it and has to flatten the needle by hand, against the same rule
       Get-FlatOutput used on the haystack. Two hand-written copies of one rule is how a counting assert
       ends up silently matching zero times and reading as "the line is missing" -- so the rule is a
       function and both readers call it. #>
    param([string]$Text)
    return ($Text -replace '\s', '')
}

function Invoke-CapturedChild {
    <#
        Runs a powershell child and returns its exit code plus its combined output as PLAIN TEXT.

        Deliberately Start-Process with redirect FILES rather than '& powershell ... 2>&1'. Under 2>&1 the
        parent turns every stderr line into a NativeCommandError and renders that record -- header,
        CategoryInfo, FullyQualifiedErrorId -- so with two stderr lines the decoration of the second lands
        in the MIDDLE of the first's sentence. Measured: an assert on "token 'final'" saw
        "...the token 'fina<300 characters of error-record>l'." A redirect file receives what the child
        actually wrote, and nothing else.

        Each argument is quoted individually: Start-Process joins -ArgumentList with plain spaces, so a
        fixture path containing a space (a user name with one is ordinary) would otherwise arrive as two
        arguments -- a failure that would look like a bug in the script under test.
    #>
    param([string[]]$ChildArgs, [string]$WorkDir)
    $tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $outFile = Join-Path ([System.IO.Path]::GetTempPath()) "nb-test-out-$tag.txt"
    $errFile = Join-Path ([System.IO.Path]::GetTempPath()) "nb-test-err-$tag.txt"
    try {
        $quoted = @($ChildArgs | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        })
        $proc = Start-Process -FilePath 'powershell' -ArgumentList $quoted -WorkingDirectory $WorkDir `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $text = ''
        foreach ($f in @($outFile, $errFile)) {
            if (Test-Path -LiteralPath $f) { $text += [System.IO.File]::ReadAllText($f) }
        }
        # #1934: name a load failure before the caller reads a document the child never wrote. This
        # helper serves the refusal cases too, and a refusal carries no CommandNotFoundException, so it
        # stays silent there. The script is picked out of the argument vector because this helper takes
        # the whole vector rather than a script path of its own.
        $childPs1 = @($ChildArgs | Where-Object { "$_" -like '*.ps1' })
        Assert-FixtureScriptLoaded -Code $proc.ExitCode -Output $text `
            -Script $(if ($childPs1.Count -gt 0) { $childPs1[0] } else { '' })
        return [pscustomobject]@{ Code = $proc.ExitCode; Out = (Get-FlatOutput $text) }
    } finally {
        foreach ($f in @($outFile, $errFile)) {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}


function Assert-ExitCode {
    <#
        An exit-code assert that PRINTS THE CHILD'S OUTPUT WHEN IT FAILS -- issue #1913.

        Assert-Equal was doing this job, and it was the wrong tool for it: it reports the two numbers
        and discards the result object, so a red lane said `expected: '0' / got: '1'` and nothing else.
        What that costs is not tidiness. This suite runs new-branch.ps1 as a CHILD PROCESS, so the only
        account of what went wrong is that child's stdout and stderr -- already captured, already in
        $Result.Out, and thrown away at the one moment it is the entire evidence.

        MEASURED TWICE, AND THE SECOND TIME IS WHY THIS EXISTS. #1913 was filed after a 632s gate run
        reported this suite red on the 'stacked/dirty' fixture; its author could say only that
        new-branch had exited 1 and written no document, and had to infer even that from the
        ReadAllText two lines further down. On September 13, 2026 the same suite went red under the
        same gate in a DIFFERENT place -- the 'local resume' and 'remote level' cases -- and reported
        exactly as little. A gate whose red says nothing is a gate that gets re-run, and a gate that is
        re-run on a red is a gate that is off.

        The output is printed INDENTED and whole. Trimming it to a line would reinstate the problem in
        a smaller size: which line of a child's output carries the cause is not knowable in advance,
        which is the reason there is nothing better to print than all of it.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$Expected,
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $actual = if ($null -eq $Result) { '<no result object>' } else { "$($Result.Code)" }
    if ("$Expected" -eq $actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
        return
    }
    $script:fail++
    Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$actual'" -ForegroundColor Red
    $out = if ($null -eq $Result) { '' } else { "$($Result.Out)" }
    if ([string]::IsNullOrWhiteSpace($out)) {
        Write-Host "         the child printed nothing at all -- neither stdout nor stderr" -ForegroundColor Red
    } else {
        Write-Host "         what the child said:" -ForegroundColor Red
        foreach ($line in ($out -split "`r?`n")) { Write-Host "           $line" -ForegroundColor DarkRed }
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

$script:fixtures = @()

function New-Fixture {
    <#
        A fresh throwaway git repo with the touched scripts copied into it (new-branch.ps1 and the libs
        it dot-sources -- the real ones from the repo, so the prefix table is correct), plus an initial
        commit on a base branch 'main'. The scripts under test will run
        FROM THIS FIXTURE (not from the real repo), so git mutations (checkout/checkout -b) never
        touch the own working copy.
    #>
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\task')    -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\release') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib')    -Force | Out-Null
    Copy-Item -LiteralPath $NewBranchSrc     -Destination (Join-Path $dir 'scripts\task\new-branch.ps1')             -Force
    Copy-Item -LiteralPath $BranchInfoSrc    -Destination (Join-Path $dir 'scripts\lib\branch-info.ps1')             -Force
    Copy-Item -LiteralPath $NativeCaptureSrc -Destination (Join-Path $dir 'scripts\lib\native-capture-lib.ps1')      -Force
    Copy-Item -LiteralPath $RunProgressSrc -Destination (Join-Path $dir 'scripts\lib\run-progress-lib.ps1')      -Force
    Copy-Item -LiteralPath $ParkLibSrc       -Destination (Join-Path $dir 'scripts\lib\park-lib.ps1')               -Force
    Copy-Item -LiteralPath $PorcelainSrc     -Destination (Join-Path $dir 'scripts\lib\git-porcelain-lib.ps1')      -Force
    Copy-Item -LiteralPath $EntryScaffoldSrc -Destination (Join-Path $dir 'scripts\lib\entry-scaffold-lib.ps1')      -Force
    Copy-Item -LiteralPath $SeamLibSrc       -Destination (Join-Path $dir 'scripts\lib\seam-lib.ps1')                -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    # check-report-lib.ps1 likewise (#1917): the script under test resolves its repo root through
    # Resolve-RepoRootOrFail, which lives there -- so the fixture owes it too. UNGUARDED in the script,
    # deliberately: it is the first statement that runs, and a guarded load would have to fall back to
    # the very unjudged .Trim() this repair removes.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\check-report-lib.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    # repo-root-lib.ps1 likewise (#2115): check-report-lib.ps1 resolves the repo root through
    # Get-GitTopLevelPath, which lives there. UNGUARDED in that lib, deliberately -- it is mirrored
    # beside it into every plugin that carries it, so a payload missing it is broken rather than old.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\repo-root-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\repo-root-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    # fence-lib.ps1 likewise (#2536): entry-scaffold-lib.ps1, pr-body-lib.ps1 and pr-issues-lib.ps1 dot-source it.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fence-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fence-lib.ps1') -Force
    # git-identity-lib.ps1 likewise (inbound #1867): new-branch.ps1 dot-sources it for Test-GitCanCommit,
    # the probe behind its "this checkout cannot commit" refusal -- so the fixture owes it too. That
    # dot-source is GUARDED, which is exactly why the fixture has to carry it: without the file the
    # refusal degrades to silence and the (y) case would pass for the wrong reason, saying nothing.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\git-identity-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\git-identity-lib.ps1') -Force
    Copy-Item -LiteralPath $PrIssuesLibSrc   -Destination (Join-Path $dir 'scripts\lib\pr-issues-lib.ps1')           -Force
    Copy-Item -LiteralPath $IssueStateLibSrc -Destination (Join-Path $dir 'scripts\lib\issue-state-lib.ps1')         -Force
    Copy-Item -LiteralPath $RemoteAheadLibSrc -Destination (Join-Path $dir 'scripts\lib\remote-ahead-lib.ps1')       -Force
    Copy-Item -LiteralPath $RefPrintLibSrc    -Destination (Join-Path $dir 'scripts\lib\ref-print-lib.ps1')          -Force

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $dir init -q
        Invoke-FixtureGitIn $dir config user.email 'tycho-tests@local.invalid'
        Invoke-FixtureGitIn $dir config user.name 'Tycho Tests'
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $dir config commit.gpgsign false
        # symbolic-ref instead of checkout -b: works on a still-unborn HEAD regardless of git's own
        # init.defaultBranch setting, and gives no error if HEAD happens to already be named 'main'.
        Invoke-FixtureGitIn $dir symbolic-ref HEAD refs/heads/main
        [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $dir add -A
        Invoke-FixtureGitIn $dir commit -q -m 'init'
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $script:fixtures += $dir
    return $dir
}

function New-BareOrigin {
    <#
        A bare repo added to $Dir as 'origin', so a push has somewhere to land -- no auth, no network.
        Registered as a fixture so the teardown removes it. Extracted for #900: section (i) did this
        inline when it was the only test that needed a remote, and four now do.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $bare = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-$Label-origin-$([guid]::NewGuid().ToString('n')).git")
    if (Test-Path -LiteralPath $bare) { Remove-Item -Recurse -Force -LiteralPath $bare }
    $script:fixtures += $bare
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitJudged @('init', '--bare', '-q', $bare)
        Invoke-FixtureGitIn $Dir remote add origin $bare
    } finally { $ErrorActionPreference = $prevEap }
    return $bare
}

function Add-FixtureRepoConfig {
    <#
        Writes scripts\repo-config.ps1 into $Dir with a fixed Get-RepoName -- the seam the already-done
        check (#1409) reads before it asks gh anything. Every other fixture in this file has no such
        file, which is deliberate: it is what exercises the SKIP path (no Get-RepoName, so the check
        never calls gh at all). Only the cases that need the check to actually run call this first.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$RepoName
    )
    New-Item -ItemType Directory -Path (Join-Path $Dir 'scripts') -Force | Out-Null
    $body = "function Get-RepoName { '$RepoName' }`n"
    [System.IO.File]::WriteAllText((Join-Path $Dir 'scripts\repo-config.ps1'), $body, (New-Object System.Text.UTF8Encoding $false))
}

function Publish-FixtureTrunk {
    <#
        Push the fixture's 'main' to its bare origin with -u, which is what brings
        refs/remotes/origin/main into existence. THAT REF IS THE GATE the stale-base check reads first
        (inbound #1046), so without this call every fixture in this file answers "not compared" -- which
        is exactly why the check landed green against the whole existing suite and needs sections of its
        own.
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $Dir push -u -q origin main
    } finally { $ErrorActionPreference = $prevEap }
}

function Add-OriginCommits {
    <#
        Advance the bare origin's 'main' by $Count commits WITHOUT touching $Dir -- the second session on
        the same board, reproduced. Done through a throwaway clone rather than by committing in the
        fixture and resetting it back, so the fixture's own HEAD and reflog stay exactly as new-branch
        will find them.

        Deliberately leaves the fixture's remote-tracking ref STALE: the point of the check under test is
        that its own fetch is what discovers the gap.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Bare,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][int]$Count
    )
    $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-$Label-other-$([guid]::NewGuid().ToString('n')).git")
    if (Test-Path -LiteralPath $clone) { Remove-Item -Recurse -Force -LiteralPath $clone }
    $script:fixtures += $clone
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # --branch main IS LOAD-BEARING, not tidiness. `git init --bare` leaves the bare repo's HEAD
        # pointing at refs/heads/master while New-Fixture only ever pushes 'main', so a plain clone lands
        # on an UNBORN 'master': the three commits below go there, `push origin main` fails with
        # "src refspec main does not match any", and the fixture reads 0 behind -- a green-looking helper
        # that proves nothing. Same literal trunk name as New-Fixture, for the same reason.
        Invoke-FixtureGitJudged @('clone', '-q', '--branch', 'main', $Bare, $clone)
        Invoke-FixtureGitIn $clone config user.email 'other-session@local.invalid'
        Invoke-FixtureGitIn $clone config user.name 'Other Session'
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $clone config commit.gpgsign false
        for ($i = 1; $i -le $Count; $i++) {
            [System.IO.File]::WriteAllText((Join-Path $clone "upstream-$i.txt"), "$i`n", (New-Object System.Text.UTF8Encoding $false))
            Invoke-FixtureGitIn $clone add -A
            Invoke-FixtureGitIn $clone commit -q -m "upstream $i"
        }
        Invoke-FixtureGitIn $clone push -q origin main
    } finally { $ErrorActionPreference = $prevEap }
}

function Add-OriginBranch {
    <#
        A branch that exists ONLY on the bare origin, carrying a file nothing else has -- the other
        device's parked branch, reproduced (#1139). Built through a throwaway clone for the same reason
        Add-OriginCommits is: $Dir is never touched, so refs/heads/<branch> stays absent there and the
        fixture is in exactly the state the report describes.

        $MarkerFile is what makes the assert possible at all. Everything else about a resume and a fork
        looks identical on screen -- same clean run, byte-identical scaffold -- so the only readable
        difference is whether the branch's WORK arrived.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Bare,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$MarkerFile
    )
    $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-$Label-parked-$([guid]::NewGuid().ToString('n')).git")
    if (Test-Path -LiteralPath $clone) { Remove-Item -Recurse -Force -LiteralPath $clone }
    $script:fixtures += $clone
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # --branch main for the reason spelled out in Add-OriginCommits: a bare repo's HEAD points at
        # refs/heads/master and only 'main' was ever pushed, so a plain clone lands on an unborn branch.
        Invoke-FixtureGitJudged @('clone', '-q', '--branch', 'main', $Bare, $clone)
        Invoke-FixtureGitIn $clone config user.email 'other-device@local.invalid'
        Invoke-FixtureGitIn $clone config user.name 'Other Device'
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $clone config commit.gpgsign false
        Invoke-FixtureGitIn $clone checkout -q -b $Branch
        [System.IO.File]::WriteAllText((Join-Path $clone $MarkerFile), "parked elsewhere`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $clone add -A
        Invoke-FixtureGitIn $clone commit -q -m "work parked on the other device"
        Invoke-FixtureGitIn $clone push -q origin $Branch
    } finally { $ErrorActionPreference = $prevEap }
}
function Add-OriginBranchCommits {
    <#
        Advance a branch that ALREADY exists on the bare origin, from a throwaway clone -- the other
        session finishing its work and parking it, reproduced (#1439). The distinction from
        Add-OriginBranch matters and is the whole of this suite's new case: that helper builds a branch
        with no local ref at all (#1139), while here $Dir holds a local ref pointing at the OLDER tip.
        That is the state `git status` cannot tell from "in sync".

        $Author and $Subject are parameters rather than constants because they are what the check under
        test PRINTS. The count alone cannot separate a collision from a fast-forward of your own
        autopark; 'park: ... (all outstanding work)' under an identity that is not yours can.

        $Dir is never touched, so its remote-tracking ref is left STALE on purpose -- the check's own
        fetch is what has to discover this.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Bare,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$MarkerFile,
        [Parameter(Mandatory = $true)][string]$Author,
        [Parameter(Mandatory = $true)][string]$Subject
    )
    $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-$Label-ahead-$([guid]::NewGuid().ToString('n')).git")
    if (Test-Path -LiteralPath $clone) { Remove-Item -Recurse -Force -LiteralPath $clone }
    $script:fixtures += $clone
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # --branch $Branch, not 'main': this clone exists to extend THAT branch, and the reasoning in
        # Add-OriginCommits about a bare repo's HEAD applies just as much -- a plain clone would land on
        # an unborn 'master' and the push below would fail into a green-looking helper that proves nothing.
        Invoke-FixtureGitJudged @('clone', '-q', '--branch', $Branch, $Bare, $clone)
        Invoke-FixtureGitIn $clone config user.email 'other-session@local.invalid'
        Invoke-FixtureGitIn $clone config user.name $Author
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $clone config commit.gpgsign false
        [System.IO.File]::WriteAllText((Join-Path $clone $MarkerFile), "built by the other session`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $clone add -A
        Invoke-FixtureGitIn $clone commit -q -m $Subject
        Invoke-FixtureGitIn $clone push -q origin $Branch
    } finally { $ErrorActionPreference = $prevEap }
}
function Test-BranchOnRemote {
    <# Is $Ref present in the bare repo $Bare? The push assert, read from the remote rather than from
       the pusher's own output -- "reports it parked" and "actually pushed" are two claims. #>
    param(
        [Parameter(Mandatory = $true)][string]$Bare,
        [Parameter(Mandatory = $true)][string]$Ref
    )
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

function Get-HeadCommitFiles {
    <# The paths in $Dir's HEAD commit -- what a park commit actually swept in. #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return @(& git -C $Dir diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    } finally { $ErrorActionPreference = $prevEap }
}

function Clear-FixtureFetchStamp {
    <#
        Delete the fixture's fetch-attempt record, so the NEXT new-branch run in it fetches for itself
        (issue #1915).

        WHY A SUITE ABOUT THE DIVERGENCE WARNING OWNS THIS. Every "another session pushed" case below is
        two new-branch runs on one fixture, seconds apart, with the remote advanced in between -- and the
        script under test discovers that only by fetching. Since #1860 it opts into -RecentFailureSeconds,
        so a fetch that failed in the FIRST run suppresses the retry in the second for 90 seconds: the
        second run then counts against a ref nobody refreshed, reads 0, and says nothing. Every assert on
        the warning fails, and it fails pointing at whatever the case was really about.

        MEASURED AS EXACTLY THAT, in the parallel test gate on September 13, 2026 (issue #1915): case (y6)
        went red on its two positive cap asserts while the negative one passed -- the signature of a
        warning that never fired -- and the same tree was green standalone. Reproduced by writing a failed
        record between the two runs by hand: three asserts, same three verdicts.

        IT REMOVES NO COVERAGE. The freshness seam has its own suite (scripts/tests/fetch-attempt.tests.ps1,
        cases 7 and 8), which is where a skip belongs; nothing in this file asserts on one. And it cannot
        mask a regression either: clearing the record only ever makes the second run FETCH, so a
        new-branch whose fetch genuinely fails still leaves the ref stale and still fails these asserts.

        Best-effort, like the writer it undoes: a record that cannot be located or removed costs a
        possible skip, never the run.
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $stamp = Get-RemoteFetchStampPath -RepoRoot $Dir
        if ($stamp) { Remove-Item -LiteralPath $stamp -Force -ErrorAction SilentlyContinue }
    } catch {
    } finally { $ErrorActionPreference = $prevEap }
}

function Invoke-NewBranch {
    <#
        Runs the fixture copy of new-branch.ps1 as a child process, with the fixture folder as cwd
        (so the dual-context fallback `git rev-parse --show-toplevel` lands there) and without
        CLAUDE_PROJECT_DIR from an earlier test run. EAP=Continue around the call -- the same
        caution as the #86 preflight block in shared-scripts.tests.ps1 (native stderr under
        EAP=Stop would otherwise become terminating here).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Title,
        [string]$Intent,
        [switch]$Park,
        [switch]$NoPush,
        # The valve on the stale-base refusal (#1417). Only the fixtures that DELIBERATELY cut from a
        # base behind origin pass it -- every other fixture here has no origin/main to be behind, so the
        # question is never asked and the switch would assert nothing.
        [switch]$SkipStaleBase,
        # The already-done check's own input (#1409). Only the (x) fixtures below pass it -- every
        # other fixture here is exercising something else and would have nothing to assert about it.
        [string]$Resolves,
        # Leave the fetch-attempt record alone (issue #1915). Only (y7) passes it -- the one case whose
        # SUBJECT is a run that could not refresh its refs, which is exactly the state Clear-FixtureFetchStamp
        # exists to keep out of every other case.
        [switch]$KeepFetchStamp
    )
    $scriptPath = Join-Path $Dir 'scripts\task\new-branch.ps1'
    $callArgs = @('-Name', $Name)
    if ($PSBoundParameters.ContainsKey('Title'))  { $callArgs += @('-Title', $Title) }
    if ($PSBoundParameters.ContainsKey('Intent')) { $callArgs += @('-Intent', $Intent) }
    if ($Park)   { $callArgs += '-Park' }
    if ($NoPush) { $callArgs += '-NoPush' }
    if ($SkipStaleBase) { $callArgs += '-SkipStaleBase' }
    if ($PSBoundParameters.ContainsKey('Resolves')) { $callArgs += @('-Resolves', $Resolves) }

    $prevPd  = $env:CLAUDE_PROJECT_DIR
    $prevEap = $ErrorActionPreference
    $prevLoc = (Get-Location).Path
    try {
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        if (-not $KeepFetchStamp) { Clear-FixtureFetchStamp -Dir $Dir }
        Set-Location -LiteralPath $Dir
        $ErrorActionPreference = 'Continue'
        return (Invoke-CapturedChild -WorkDir $Dir -ChildArgs (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $callArgs))
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

function Invoke-NewBranchWithAdversarialField {
    <#
        Variant of Invoke-NewBranch for a MALICIOUS free-text field value (quotes + backslashes),
        for -Title OR -Intent (both cross the same env-var handoff boundary into the child
        new-changelog-entry.ps1). Passing such a payload directly as a standalone CLI argument to a
        NEW powershell.exe child process (as Invoke-NewBranch above does via `& powershell
        -File ... -Title $Title`) already runs into PowerShell's own, UNRELATED argv
        re-serialization vulnerability when spawning a native process (confirmed with a standalone
        diagnostic script: the same payload already arrived split at the child process with `\"`
        followed by a space, independent of new-branch.ps1's own code) -- that would make this
        scenario fail at the WRONG boundary (test harness -> new-branch.ps1) instead of the boundary
        the fix actually touches (new-branch.ps1 -> new-changelog-entry.ps1).

        Workaround: the value goes to the child process here via an environment variable
        (environment variable values do not survive argv requoting), and the child process reads it
        back itself within its OWN -Command script block (so within the same PowerShell runtime,
        without yet another process-boundary re-serialization of the malicious value). This way the
        value arrives intact and unchanged as new-branch.ps1's own -$Field parameter -- exactly as
        with a normal, safe call (e.g. typed directly in an interactive session) -- and this
        scenario purely tests the internal fix (the env-var handoff to new-changelog-entry.ps1), not
        an unrelated PowerShell argv defect at a different boundary.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Title', 'Intent')][string]$Field,
        [Parameter(Mandatory = $true)][string]$Value
    )
    $scriptPath   = Join-Path $Dir 'scripts\task\new-branch.ps1'
    $envVarName   = 'TYCHO_NEWBRANCH_TEST_FIELD'
    $prevEnvValue = [Environment]::GetEnvironmentVariable($envVarName)
    $prevEap      = $ErrorActionPreference
    $prevLoc      = (Get-Location).Path
    $prevPd       = $env:CLAUDE_PROJECT_DIR
    try {
        [Environment]::SetEnvironmentVariable($envVarName, $Value)
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        Set-Location -LiteralPath $Dir
        $ErrorActionPreference = 'Continue'
        # The -Command string itself contains no malicious content -- only the fixed field name and
        # a reference to the env var name (harmless ASCII) -- so that string needs no special escaping.
        $cmd = "& '$scriptPath' -Name '$Name' -$Field `$env:$envVarName"
        return (Invoke-CapturedChild -WorkDir $Dir -ChildArgs @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd))
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
        [Environment]::SetEnvironmentVariable($envVarName, $prevEnvValue)
    }
}

function Test-EntryDeclaresType {
    <#
        Does the entry state $Type under its own '### Type of change' section?

        THE TYPE LEFT THE HEADING ON AUGUST 5, 2026, and this helper exists because four asserts in this file
        were reading it out of the heading as a trailing middot field. It was the second-to-last such field,
        then (once the scaffolded date moved to the fold) a field matched by content against the known branch
        types -- both of them parses of a heading doing three jobs. As its own section it is STATED rather
        than inferred, and the heading is reduced to what a reader scans: the title.

        THE SECTION IS 'Branch type' AND HOLDS THE PREFIX SINCE THE DOSSIER FORM (August 6, 2026), so this
        asks Get-EntrySectionAnswer rather than matching the raw text: the section now opens with a guidance
        comment, and a heading+blank+value pattern would be looking at the hint. The comparison is
        case-insensitive because the FILE carries 'feat' while the callers name the canonical 'Feat' -- which
        is exactly the pair Resolve-EntryType reconciles.

        AND SINCE AUGUST 16, 2026 THE SECTION IS GONE AND THE HEADING HAS IT AGAIN -- the branch prefix,
        in the branch the heading has to name anyway, which is where 'Branch type' was copying it from.
        So this asks Resolve-EntryType, the reader the release documents use: it takes the section where an
        older entry still has one and the heading otherwise, which is exactly the pair of shapes the
        callers below span. Still not a bare '-match': one of them is the injection test, whose whole
        subject is that nothing extra ended up in the file.
    #>
    param([Parameter(Mandatory = $true)][string]$EntryText, [Parameter(Mandatory = $true)][string]$Type)
    $resolved = Resolve-EntryType -EntryText $EntryText
    return ($resolved.Declared -and ([string]$resolved.Type).ToLowerInvariant() -eq $Type.ToLowerInvariant())
}

function Get-EntryDescription {
    <# The PR title -- the first line of 'Pull Request' since August 16, 2026, and the 'Branch title'
       section before that. Get-EntryPrTitle knows both, which is what open-pr composes the PR title from. #>
    param([Parameter(Mandatory = $true)][string]$EntryText)
    return (Get-EntryPrTitle -EntryText $EntryText)
}

# The teardown every suite runs in its finally block: one place, so a suite cannot leave a tree behind
# that the others would have removed.
function Remove-NewBranchFixtures {
    foreach ($f in $script:fixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

# The closing verdict, identical in every suite: one place, so the files cannot drift on how they
# report a failure.
function Complete-NewBranchSuite {
    Write-Host ""
    # A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
    # assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
    $fixtureBroken = Write-FixtureGitSummary -Subject 'new-branch.ps1'
    # AND THE SAME VERDICT FOR A CHILD THAT DIED ON LOAD (#1934). Separate counter, separate line: a
    # fixture git call that failed and a child that never started are different breakages with different
    # repairs, and folding them into one number would name neither.
    $loadBroken = Write-FixtureScriptSummary -Subject 'new-branch.ps1'
    if ($script:fail -gt 0) {
        Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
        exit 1
    }
    if ($loadBroken) {
        Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child script(s) died on load -- this run measured a fixture, not the script." -ForegroundColor Red
        exit 1
    }
    if ($fixtureBroken) {
        Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
    exit 0
}
