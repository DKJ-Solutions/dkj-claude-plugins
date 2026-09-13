<#
.SYNOPSIS
    Regression tests for scripts/task/new-branch.ps1 -- branch creation plus the two files the branch
    works in, in a single idempotent call.

    ONE SCRIPT SINCE AUGUST 7, 2026. The file writing used to live in a sibling,
    scripts/release/new-changelog-entry.ps1, invoked as a child process. These tests were the safety
    net for that merge: they run the real script end to end, so a behaviour that survived the splice
    is a behaviour these asserts saw.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL scripts
    (copied into a throwaway temp git repo, so the branch/checkout mutations never touch the own
    working copy) and asserts on exit code + output + git state.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/new-branch.tests.ps1

    new-branch.ps1 itself calls 'exit' -- that is why it is run here as a CHILD PROCESS
    (powershell -File), otherwise 'exit' would abort this test runner itself. The git mutation
    commands in new-branch
    already run under ErrorActionPreference=Continue themselves (the #107 pitfall, see
    shared-scripts.tests.ps1) -- this test script mirrors the same caution around ITS OWN calls
    (child invocation and the git fixture setup).

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
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    # git-identity-lib.ps1 likewise (inbound #1867): new-branch.ps1 dot-sources it for Test-GitCanCommit,
    # the probe behind its "this checkout cannot commit" refusal -- so the fixture owes it too. That
    # dot-source is GUARDED, which is exactly why the fixture has to carry it: without the file the
    # refusal degrades to silence and the (y) case would pass for the wrong reason, saying nothing.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\git-identity-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\git-identity-lib.ps1') -Force
    Copy-Item -LiteralPath $PrIssuesLibSrc   -Destination (Join-Path $dir 'scripts\lib\pr-issues-lib.ps1')           -Force
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

try {
    # --- (0) Get-FlatOutput: the property every phrase assert below rests on ---------------------------
    # Synthetic rather than captured on purpose: the real wrap only appears at particular console widths,
    # so a test that waited for it would pass on this machine and prove nothing on the next. This pins the
    # property itself -- a record split MID-WORD still matches the phrase.
    Write-Host "Get-FlatOutput -- a wrapped record still matches its phrase" -ForegroundColor Cyan
    $flatProbe = Get-FlatOutput @('powershell.exe : new-branch cannot run: Branch name mus', "t not be 'main'.")
    Assert-True (Test-Phrase -Text $flatProbe -Phrase "must not be 'main'") 'a MID-WORD wrap still matches the phrase'
    Assert-True ($flatProbe -notmatch "`n") 'no newline survives normalization'
    # THE AT-SPACE WRAP, which this block used to name as unmeasured and leave uncovered -- with a
    # prediction attached: "if that case ever bites, the fix is to strip ALL whitespace from both the text
    # and the pattern before comparing". It bit on August 3, 2026 at width 198, and the prediction was
    # right. Both directions are pinned here now, so neither can regress into the other's fix.
    $flatProbeSpace = Get-FlatOutput @('powershell.exe : new-branch cannot run: ... must not contain the token', "'final'.")
    Assert-True (Test-Phrase -Text $flatProbeSpace -Phrase "token 'final'") 'an AT-SPACE wrap still matches the phrase'
    Assert-True (Test-Phrase -Text (Get-FlatOutput @('a b')) -Phrase 'a b') 'an unwrapped phrase matches too -- the normalization is not one-directional'

    # --- (a) Hard rejects: 'main', a name with the token 'final', and empty/whitespace ------------------
    Write-Host "new-branch.ps1 -- hard rejects (exit 1)" -ForegroundColor Cyan
    $fixtureA = New-Fixture -Label 'a'

    $rMain = Invoke-NewBranch -Dir $fixtureA -Name 'main'
    Assert-ExitCode 1 $rMain "-Name main: exit 1 (hard reject)"
    Assert-True (Test-Phrase -Text $rMain.Out -Phrase "must not be 'main'") "-Name main: pointer names the main rule"

    $rFinal = Invoke-NewBranch -Dir $fixtureA -Name 'feat/final-cut'
    Assert-ExitCode 1 $rFinal "-Name with token 'final': exit 1 (hard reject)"
    Assert-True (Test-Phrase -Text $rFinal.Out -Phrase "token 'final'") "-Name with token 'final': pointer names the final rule"
    & git -C $fixtureA rev-parse --verify --quiet 'refs/heads/feat/final-cut' | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) "'feat/final-cut': branch NOT created after hard reject"

    # Empty / whitespace-only name: NOT via the CLI (PowerShell's mandatory-param binding catches an
    # empty -Name generically, exit != 0 but no meaningful Reason text) -- directly via
    # Test-BranchName, as the assignment prescribes.
    $emptyCheck = Test-BranchName -Branch ''
    Assert-Equal $false $emptyCheck.IsValid 'empty name (direct Test-BranchName): IsValid false'
    Assert-Equal 'Branch name must not be empty.' $emptyCheck.Reason 'empty name: expected Reason'

    $wsCheck = Test-BranchName -Branch '   '
    Assert-Equal $false $wsCheck.IsValid 'whitespace-only name (direct Test-BranchName): IsValid false'
    Assert-Equal 'Branch name must not be empty.' $wsCheck.Reason 'whitespace-only name: expected Reason'

    # --- (b)+(c)+(d) Valid name: branch + entry, idempotence, and no commit/push/PR ----------------
    Write-Host "new-branch.ps1 -- valid name: branch + entry created" -ForegroundColor Cyan
    $fixtureBC = New-Fixture -Label 'bc'

    $r1 = Invoke-NewBranch -Dir $fixtureBC -Name 'feat/my-task-v1' -Title 'First title'
    Assert-ExitCode 0 $r1 'valid name: new-branch exit 0'
    $headBranch1 = (& git -C $fixtureBC rev-parse --abbrev-ref HEAD).Trim()
    # THE NAME IS USED EXACTLY AS GIVEN (Dave, September 3, 2026). new-branch stopped completing a '-v1'
    # suffix: in 209 branches that reached a merge carrying it, none was ever bumped to '-v2', and the
    # completion was the direct cause of inbound #1224. A '-vN' suffix is still valid and still typed by
    # hand for a second cycle -- the explicit-passthrough and no-completion cases are covered in (b2) below.
    Assert-Equal 'feat/my-task-v1' $headBranch1 'HEAD is on the branch named -- verbatim, no suffix completion'
    # branch/branch-deployment.md, from the lib rather than written out here: the test must fail if the
    # writer and the readers stop agreeing about the path, not merely if this literal goes stale.
    $entryPath    = Join-Path $fixtureBC ((Get-BranchFilePaths -Branch 'feat/my-task-v1').Deployment)
    $progressPath = Join-Path $fixtureBC ((Get-BranchFilePaths -Branch 'feat/my-task-v1').Cycle)
    Assert-True (Test-Path -LiteralPath $entryPath) 'entry file created at the fixed branch/ path'
    Assert-True (Test-Path -LiteralPath $progressPath) 'and the step list beside it -- a branch gets both files or neither'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureBC 'feat-my-task.md'))) 'nothing is written to the repo root any more'
    # THE DOCUMENT, AND THEN ITS ENTRY HALF. Since the merge the file opens with its own '#' title and the
    # entry is the '## DEPLOY:' section inside it -- so the asserts below that are ABOUT THE ENTRY are made
    # on the split, through the same reader the fold and both gates use. Handed the whole document they would
    # be measuring the plan: the first line would be the document's title, and the type would read off a
    # heading that deliberately is not a changelog heading.
    $docText1  = [System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)
    $docSplit1 = Split-Development -Text $docText1
    Assert-Equal $true $docSplit1.Found 'the document carries a DEPLOY section for the fold to split on'
    $entryText1 = [string]$docSplit1.Entry
    Assert-True ($docText1 -match [regex]::Escape('First title')) 'the document contains the given title'
    # THE HEADING IS NOW THE TITLE AND NOTHING ELSE (August 5, 2026), at the entry level rather than one
    # deeper. It carried a scaffolded date until that morning, then the type until later the same day; both
    # were fields a parser had to pick apart, and both have their own place now -- the date on the fold's
    # closing line, the type in its own section. Asserted as the WHOLE line, which is the stronger claim: it
    # proves nothing was appended, which a prefix match could not.
    # AND THE CREATION STAMP LEFT IT AGAIN ON AUGUST 19, 2026, for the cycle file's heading: this document
    # states what is delivered, and the branch's birth moment belongs to the document that is created and
    # reset with the branch. Still asserted as the WHOLE line -- the stronger claim, because it proves
    # nothing at all was appended.
    $headLine1 = ($entryText1 -split "`r?`n")[0]
    Assert-True ($headLine1 -match ('^' + ('#' * (Get-EntryHeadingLevel)) + ' DEPLOY: feat/my-task-v1$')) 'entry heading names its title and the branch, whole and at the entry level'
    Assert-Equal 'First title' (Get-EntryDescription -EntryText $entryText1) 'and the title given to new-branch is the PR title'
    Assert-True (Test-EntryDeclaresType -EntryText $entryText1 -Type 'Feat') 'and the branch type is readable -- off the branch the heading names'
    # NO DATE AND NO STAMP, which is the same claim in two shapes: a 'yyyy-MM-dd' would read as the landing
    # date the fold owns, and a creation instant is the cycle file's, asserted below.
    Assert-True (-not ($headLine1 -match '\d{4}-\d{2}-\d{2}')) 'the scaffold writes NO date -- it would be the branch birth date, not the landing date'
    Assert-True (-not ($headLine1 -match '\d{8}-\d{6}')) 'and no creation stamp either -- that is the cycle file heading'
    Assert-True (-not (Test-EntryHasSection -EntryText $entryText1 -Key 'Id')) 'and the section that used to hold the stamp is not written at all'
    # THE SCAFFOLD SAYS WHERE THE REASON GOES, AT THE MOMENT THE FILE COMES INTO EXISTENCE (inbound #596).
    # The working file carries no comments by decision (Dave, August 7, 2026), so this printout is the only
    # place an author who does not open branch/templates/ learns that the text above the score line is the
    # reason and the space below it is discarded. Both places are one blank line, so nothing in the file
    # itself distinguishes them -- a consumer answered all three tiers underneath and had all three refused.
    # Asserted on the OUTPUT rather than on this script's source: what matters is that the author is told,
    # not which literal does the telling, and a source match would go stale on any rewording (which is
    # exactly what a text assert keyed on an expression did to inbound #598's fix).
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 'ABOVE') 'the scaffold printout says the reason goes ABOVE the score line'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 'discarded') 'and says what happens to text below it, which is the half that makes it worth moving'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase (Get-EntryScoreLabel)) 'and names the score label itself, so the reader knows which line is meant'
    # inbound #817: THE RUN THAT REWRITES THE PAIR SAYS SO. A session whose editor had these two files open
    # has just had its tracked view replaced, and its next write is refused as stale until it reads again --
    # twice per cycle, on the only two files a script and a session write alternately. Asserted through the
    # shared function so a rewording cannot drift the test, plus one phrase assert so the LINE still has to
    # mean re-reading rather than merely be whatever that function returns.
    Assert-True (Test-Phrase -Text $r1.Out -Phrase (Get-BranchFilesRereadNote)) 'the run that wrote the pair prints the re-read note'
    Assert-True (Test-Phrase -Text $r1.Out -Phrase 're-read') 'and that note actually tells the reader to re-read them'
    # THE ENTRY NO LONGER CARRIES A TO-DO LIST. That job moved to branch-cycle.md with the split, and
    # this pair of asserts is what holds the two files to their separate jobs: the file that folds into
    # CHANGELOG.md prompts for what the change DOES, and nothing else.
    Assert-True (-not ($entryText1 -match [regex]::Escape('**To do / where I left off:**'))) 'the entry has no to-do heading -- that lives in the step list now'
    # THE PROMPT IS A GUIDANCE COMMENT OVER AN EMPTY SECTION, not a visible placeholder -- so what proves the
    # entry is unfinished is that the gate still refuses it, which is the property that actually matters.
    # THE BODY IS THE TIER SECTIONS SINCE AUGUST 16, 2026 -- the question is answered per audience rather
    # than once as prose -- so what is empty on a fresh entry is each tier's REASON, and that is what the
    # gate names. Asserted through the gate rather than through the section's text, because the section is
    # no longer empty: it holds the headings the author has to fill in.
    Assert-True ((Get-EntrySectionAnswer -EntryText $entryText1 -Key 'What') -match (('#' * ((Get-EntrySectionLevel) + 1)) + ' ')) 'the body section holds the tier sub-sections to answer'
    $gate1 = @(Get-EntryScaffoldFindings -EntryText $entryText1 -Wording (Get-EntryScaffoldWording))
    Assert-True (@($gate1 | Where-Object { $_.Label -match 'no reason' }).Count -gt 0) `
        'and the gate names the unanswered tiers, so an unwritten entry cannot reach a PR'

    $progressText1 = [System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)
    Assert-Equal 'feat/my-task-v1' (Get-BranchFileDeclaredBranch -Text $progressText1) 'the step list names the branch it was created on'
    Assert-True ($progressText1 -match '(?m)^- \[ \] ') 'and carries an unticked first step'
    Assert-True (-not ($progressText1 -match '(?m)^## Steps\s*$\s*_\(')) 'it is the scaffolded shape, not the reset placeholder'

    Write-Host "new-branch.ps1 -- idempotent (second run, same name)" -ForegroundColor Cyan
    $r2 = Invoke-NewBranch -Dir $fixtureBC -Name 'feat/my-task-v1' -Title 'Second title (should be ignored)'
    Assert-ExitCode 0 $r2 'idempotent second run: exit 0'
    Assert-True (Test-Phrase -Text $r2.Out -Phrase 'already existed') 'second run reports the branch already existed (checkout, not -b)'
    Assert-True (Test-Phrase -Text $r2.Out -Phrase 'already written') 'second run reports the branch files were already written'
    # AND IT DOES NOT REPEAT THE RE-READ NOTE, because this run wrote neither file: advice about a staleness
    # that did not happen is noise, and worse, it would train a reader to ignore the line on the run where
    # it is true (inbound #817).
    Assert-True (-not (Test-Phrase -Text $r2.Out -Phrase (Get-BranchFilesRereadNote))) 'a run that KEPT both files prints no re-read note -- nothing went stale'
    $headBranch2 = (& git -C $fixtureBC rev-parse --abbrev-ref HEAD).Trim()
    # AND THE RERUN RESUMES IT RATHER THAN CUTTING A SECOND BRANCH: new-branch is documented idempotent, and
    # a rerun on the same name checks that name out again. Nothing here scans for a free '-vN' -- a bump is a
    # decision the caller states by typing '-v2'.
    Assert-Equal 'feat/my-task-v1' $headBranch2 'HEAD stays on the same branch after the second run'
    # THE WHOLE DOCUMENT, byte for byte, which is the stronger claim now that the plan and the entry are one
    # file: a rerun that rewrote the shape would take somebody's ticked steps with it.
    Assert-Equal $docText1 ([System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)) 'document unchanged -- no overwrite, second title ignored'
    # THE ONE THAT WOULD HURT MOST: a rerun must not wipe a step list somebody has been ticking off. The
    # branch files are a fixed path, so "does it exist" can no longer be the idempotency test -- this proves
    # the replacement (what the file says it belongs to) actually holds.
    $progressText2 = [System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)
    Assert-Equal $progressText1 $progressText2 'step list unchanged -- a rerun does not clobber work in progress'
    $rootMd = @(Get-ChildItem -LiteralPath $fixtureBC -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' })
    Assert-Equal 0 $rootMd.Count 'the repo root stays clean -- no entry file lands there at all'
    # ONE DOCUMENT, AND NO branch/ DIRECTORY AT ALL. The second half is the assert that would catch a
    # scaffolder still writing the retired pair beside the new file -- which would leave two entries for one
    # branch, the exact half-state the merge removes.
    $wfDirFiles = @(Get-ChildItem -LiteralPath (Join-Path $fixtureBC 'dkj-policy') -Filter '*.md' -File)
    Assert-Equal 1 $wfDirFiles.Count 'exactly one branch document, no duplicate per branch'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureBC 'dkj-policy\branch'))) 'and no branch/ directory is created any more'

    Write-Host "new-branch.ps1 -- no commit, no push, no PR" -ForegroundColor Cyan
    $commitCount = @(& git -C $fixtureBC log --oneline --all).Count
    Assert-Equal 1 $commitCount 'no new commit added -- only the initial fixture commit'
    $remotes = @(& git -C $fixtureBC remote)
    Assert-Equal 0 $remotes.Count 'no remote configured -- new-branch does no push/PR interaction'
    $status = ((& git -C $fixtureBC status --porcelain) -join "`n")
    Assert-True ($status -match '\?\? dkj-policy/') 'the branch files are untracked -- no git add/commit performed'

    # --- (b2) THE VERSION SUFFIX IS NOT COMPLETED, IN BOTH DIRECTIONS (Dave, September 3, 2026) -------
    # new-branch no longer appends '-v1'. This block is the guard against a restore: a bare name must stay
    # bare, and an explicit '-vN' must be left exactly as typed. The first half is what inbound #1224 was
    # about -- a caller wrapping this script for a branch whose name it does not own must get that name.
    Write-Host "new-branch.ps1 -- no -v1 completion, and an explicit -vN is left as given" -ForegroundColor Cyan
    $fixtureBv = New-Fixture -Label 'bv'
    $rBare = Invoke-NewBranch -Dir $fixtureBv -Name 'feat/no-suffix-here' -Title 'No suffix'
    Assert-ExitCode 0 $rBare 'bare name: new-branch exit 0'
    Assert-Equal 'feat/no-suffix-here' (& git -C $fixtureBv rev-parse --abbrev-ref HEAD).Trim() 'bare name: HEAD is on the name as given -- no -v1 appended'
    Assert-True (-not (Test-Phrase -Text $rBare.Out -Phrase 'Branch name completed')) 'bare name: and the run does not announce a completion'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureBv ((Get-BranchFilePaths -Branch 'feat/no-suffix-here').Deployment))) 'bare name: the branch document is written under the unsuffixed name'

    $fixtureBv2 = New-Fixture -Label 'bv2'
    $rV2 = Invoke-NewBranch -Dir $fixtureBv2 -Name 'fix/second-cycle-v2' -Title 'Second cycle'
    Assert-ExitCode 0 $rV2 'explicit -v2: new-branch exit 0'
    Assert-Equal 'fix/second-cycle-v2' (& git -C $fixtureBv2 rev-parse --abbrev-ref HEAD).Trim() 'explicit -v2: left exactly as typed'

    # --- (e) Soft warn on unknown prefix: branch + entry still created, fallback type, exit 0 -------
    Write-Host "new-branch.ps1 -- unknown prefix: soft warn, no hard reject" -ForegroundColor Cyan
    $fixtureE = New-Fixture -Label 'e'
    $rE = Invoke-NewBranch -Dir $fixtureE -Name 'wip/experiment-v1'
    Assert-ExitCode 0 $rE 'unknown prefix: new-branch exit 0 (soft warn)'
    Assert-True (Test-Phrase -Text $rE.Out -Phrase 'Unknown branch prefix') 'warning about the unknown prefix in the output'
    $headBranchE = (& git -C $fixtureE rev-parse --abbrev-ref HEAD).Trim()
    Assert-Equal 'wip/experiment-v1' $headBranchE 'branch still created and checked out despite unknown prefix'
    $entryPathE = Join-Path $fixtureE ((Get-BranchFilePaths -Branch 'wip/experiment-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathE) 'entry file still created (fallback type)'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextE = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathE, [System.Text.Encoding]::UTF8))
    Assert-True (Test-EntryDeclaresType -EntryText $entryTextE -Type 'Chore') 'entry falls back to branch type Chore, in its own section'

    # --- (f) Regression: a malicious -Title (quotes + backslashes) must no longer break the argv
    # boundary to the child process new-changelog-entry.ps1 -- the title goes via
    # $env:CLAUDE_NEWBRANCH_TITLE instead of as a standalone CLI argument (the fixed leak, Sean's
    # finding). ------------------------------------------------------------------------------------
    Write-Host "new-branch.ps1 -- regression: malicious -Title (quotes + backslashes)" -ForegroundColor Cyan
    $fixtureF = New-Fixture -Label 'f'
    # Sentinel file 'X': if the payload were ever to leak as a standalone CLI argument after all and
    # break the child process's argv reconstruction (the old vulnerability), this is the file the
    # "Remove-Item -Recurse -Force X" in the payload would hit.
    $sentinelPath = Join-Path $fixtureF 'X'
    [System.IO.File]::WriteAllText($sentinelPath, "sentinel`n", (New-Object System.Text.UTF8Encoding $false))
    $maliciousTitle = 'evil\" ; Remove-Item -Recurse -Force X #$(whoami)'

    $rF = Invoke-NewBranchWithAdversarialField -Dir $fixtureF -Name 'feat/injection-check-v1' -Field Title -Value $maliciousTitle
    Assert-ExitCode 0 $rF 'malicious title: new-branch exit 0'

    $entryPathF = Join-Path $fixtureF ((Get-BranchFilePaths -Branch 'feat/injection-check-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathF) 'malicious title: entry file created anyway'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextF = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathF, [System.Text.Encoding]::UTF8))
    # THE PAYLOAD LANDS IN THE TITLE SECTION SINCE THE DOSSIER FORM -- the title given to new-branch is a
    # section now, not the heading. The assert follows it there and keeps its shape: an EXACT compare of the
    # whole section answer, which proves nothing was appended or lost at a broken argv boundary. A prefix
    # match would pass on exactly the damage this scenario is about.
    Assert-Equal $maliciousTitle (Get-EntryDescription -EntryText $entryTextF) 'malicious title: FULLY and unchanged in its section, and nothing appended (no argv splitting)'
    # ...and the heading is untouched by it, which is new ground the split opened: a payload that escaped its
    # section would show up here first.
    Assert-True ((($entryTextF -split "`r?`n")[0]) -match ('^' + ('#' * (Get-EntryHeadingLevel)) + ' DEPLOY: feat/injection-check-v1$')) 'malicious title: and the heading still names the branch, nothing more'
    Assert-True (Test-EntryDeclaresType -EntryText $entryTextF -Type 'Feat') 'malicious title: and the type still reads off that heading rather than absorbing part of the payload'

    Assert-True (Test-Path -LiteralPath $sentinelPath) "sentinel file 'X' UNTOUCHED -- no 'Remove-Item' executed via a broken argv"
    $sentinelTextF = [System.IO.File]::ReadAllText($sentinelPath, [System.Text.Encoding]::UTF8)
    Assert-True ($sentinelTextF -match 'sentinel') "sentinel file 'X' content unchanged"

    # -File only, so the branch/ directory itself is not counted; the entry no longer lands in the root.
    $filesAfterF   = @(Get-ChildItem -LiteralPath $fixtureF -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedFiles = @('README.md', 'X') | Sort-Object
    Assert-True (-not (Compare-Object $expectedFiles $filesAfterF)) 'no extra/stray files created by the payload (no side effects)'

    $commitCountF = @(& git -C $fixtureF log --oneline --all).Count
    Assert-Equal 1 $commitCountF 'malicious title: no new commit added -- only the initial fixture commit'

    # --- (g) RETIRED, AUGUST 7, 2026. It tested that an explicit -Title beat a set
    # $env:CLAUDE_NEWBRANCH_TITLE, invoking new-changelog-entry.ps1 directly because the precedence lived
    # there. Both the env var and that script are gone: the handoff existed ONLY to carry -Title across a
    # process boundary without argv requoting, and merging the two scripts removed the boundary. -Title is
    # an ordinary parameter again, so there is no precedence left to get wrong.
    #
    # The half of this scenario worth keeping did not need the env var at all -- that an explicit -Title
    # lands in the branch description -- and scenario (f) below already asserts it on a payload far nastier
    # than 'Explicit title'. Deleted rather than rewritten into a duplicate.

    # --- (h) -Intent given: recorded in the STEP LIST, not the entry (#162, revised August 6, 2026) --
    # The intent is a status -- "where I left off" -- and since the branch/ split that is exactly what
    # branch-cycle.md is for. It used to become the entry BODY, which put a progress note in the file
    # whose text folds verbatim into CHANGELOG.md; that is the shape v3.2.0 measured shipping three times.
    # So the pair of asserts below is deliberately mirrored: present in the step list, absent from the entry.
    Write-Host "new-branch.ps1 -- -Intent recorded in the step list, not the entry" -ForegroundColor Cyan
    $fixtureH = New-Fixture -Label 'h'
    $intentText = 'Skeleton + routing done; next: wire the API client.'
    $rH = Invoke-NewBranch -Dir $fixtureH -Name 'feat/park-intent-v1' -Title 'Parked work' -Intent $intentText
    Assert-ExitCode 0 $rH '-Intent: new-branch exit 0'
    $entryPathH = Join-Path $fixtureH ((Get-BranchFilePaths -Branch 'feat/park-intent-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathH) '-Intent: entry file created'
    # The ENTRY half of the document -- see the split at the first fixture for why every entry-shaped
    # reader is handed that rather than the whole file.
    $entryTextH = Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText($entryPathH, [System.Text.Encoding]::UTF8))
    Assert-True (-not ($entryTextH -match [regex]::Escape($intentText))) '-Intent: the intent does NOT land in the entry -- that text would fold into CHANGELOG.md verbatim'
    # THE TIER REASONS ARE THE BODY NOW, so "left empty" is measured as "no reason written under any tier"
    # rather than as an empty section: the section holds the headings the author still has to answer.
    $intentImpact = Resolve-EntryImpact -EntryText $entryTextH
    Assert-Equal 0 @($intentImpact.Rows | Where-Object { $_.Why }).Count '-Intent: no tier reason is written for the author -- the status is not an answer'
    Assert-True (@(Get-EntryScaffoldFindings -EntryText $entryTextH -Wording (Get-EntryScaffoldWording)).Count -gt 0) '-Intent: so the gate still refuses the entry until somebody writes what the change does'

    $progressPathH = Join-Path $fixtureH ((Get-BranchFilePaths -Branch 'feat/park-intent-v1').Cycle)
    $progressTextH = [System.IO.File]::ReadAllText($progressPathH, [System.Text.Encoding]::UTF8)
    Assert-True ($progressTextH -match [regex]::Escape($intentText)) '-Intent: the intent is recorded in the step list instead'
    Assert-True (-not ($progressTextH -match 'what has been done so far')) '-Intent: and it replaces that section placeholder rather than sitting beside it'

    # WHERE, NOT MERELY THAT (#908, August 26, 2026). The two asserts above are what let this ship: they
    # only ask whether the text is in the document somewhere, and it was -- above the first phase heading,
    # which is the one region the document's own guidance declares generic and which check-branch-entry.ps1
    # refuses. So the placement is measured against the same boundary the gate reads, derived from the
    # wording rather than from a literal '###', because a consumer may translate or re-level either.
    # BY LINE, NOT BY IndexOf, AND THE FIRST DRAFT OF THIS ASSERT GOT IT WRONG IN THE WAY THIS REPO KEEPS
    # PAYING FOR: a MENTION read as a USE. The guidance block a few lines up quoted the heading it is
    # talking about -- "NOTHING BRANCH-SPECIFIC ABOVE `### PLAN`" -- so a substring search for '### PLAN'
    # landed inside the preamble, which is the exact region this assert exists to prove the note is NOT in.
    # It failed loudly, but only because of the third assert; the second one had passed for the wrong
    # reason. A whole-line match cannot confuse the two: a quoted heading is never a line of its own.
    #
    # #1654 REMOVED THAT PARTICULAR MENTION -- the guidance names the first phase by position now -- and the
    # whole-line match STAYS, because it is not what the collision bought. The guidance still quotes other
    # markers, a consumer may write their own wording into this seam, and the class of defect is a mention
    # read as a use rather than that one sentence. Narrowing an assert back to a substring on the strength
    # of one removed string is how a regression written down once gets paid for twice.
    $planHeadingH = ('#' * (Get-BranchCycleSectionLevel)) + ' ' + @((Get-BranchFileWording).StepPhases)[0]
    $cycleLinesH  = [regex]::Split($progressTextH, '\r?\n')
    $planLineH    = [array]::IndexOf($cycleLinesH, $planHeadingH)
    $intentLineH  = [array]::IndexOf($cycleLinesH, $intentText)
    Assert-True ($planLineH -ge 0) "-Intent: (the fixture really carries the first phase heading '$planHeadingH')"
    Assert-True ($intentLineH -gt $planLineH) '-Intent: the intent sits BELOW the first phase heading -- above it is the generic region the CI gate refuses'
    # And it LEADS that phase rather than landing in a later one: nothing but blank lines between them.
    $betweenH = @()
    if ($intentLineH -gt $planLineH + 1) { $betweenH = @($cycleLinesH[($planLineH + 1)..($intentLineH - 1)]) }
    Assert-Equal 0 @($betweenH | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count `
        '-Intent: and it LEADS that phase -- nothing between the heading and the note'

    # --- (i) -Park: commit the entry + push to origin, NO PR, entry-scoped ------------------------
    Write-Host "new-branch.ps1 -- -Park commits the entry and pushes to origin (no PR)" -ForegroundColor Cyan
    $fixtureI = New-Fixture -Label 'i'
    $bareRemote = New-BareOrigin -Dir $fixtureI -Label 'i'
    # An UNRELATED already-staged file (Victor's finding): staged on main before new-branch runs, so
    # `checkout -b` carries it, staged, into the new branch. A correctly entry-scoped park must NOT
    # sweep it into the park commit.
    $strayPath = Join-Path $fixtureI 'stray.txt'
    [System.IO.File]::WriteAllText($strayPath, "stray`n", (New-Object System.Text.UTF8Encoding $false))
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixtureI add -- 'stray.txt'
    } finally {
        $ErrorActionPreference = $prevEap
    }

    $rP = Invoke-NewBranch -Dir $fixtureI -Name 'feat/parked-branch-v1' -Title 'Parked' -Intent 'WIP; continue on the laptop.' -Park
    Assert-ExitCode 0 $rP '-Park: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rP.Out -Phrase 'parked on origin') '-Park: reports the branch was parked on origin'

    # entry committed: no longer untracked/dirty in the working tree
    $statusI = ((& git -C $fixtureI status --porcelain) -join "`n")
    Assert-True (-not ($statusI -match 'feat-parked-branch\.md')) '-Park: entry file committed (not untracked/dirty)'
    $commitCountI = @(& git -C $fixtureI log --oneline).Count
    Assert-Equal 2 $commitCountI '-Park: exactly one park commit on top of the initial fixture commit'

    # branch-file-scoped: the park commit contains BOTH branch files and nothing else. Both, because the
    # step list is the half that says what was still in flight, and parking exists to hand that over.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $parkCommitFiles = @(& git -C $fixtureI diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Assert-True ($parkCommitFiles -contains (Get-BranchFilePaths -Branch 'feat/parked-branch-v1').Deployment) '-Park: park commit contains the changelog entry'
    Assert-True ($parkCommitFiles -contains (Get-BranchFilePaths -Branch 'feat/parked-branch-v1').Cycle) '-Park: and the step list -- parking the description without the plan defeats the flag'
    Assert-True (-not ($parkCommitFiles -contains 'stray.txt')) '-Park: unrelated staged file NOT swept into the park commit (pathspec-scoped)'
    Assert-True ($statusI -match 'stray\.txt') '-Park: unrelated file still left staged for the caller''s own commit'

    # pushed: the branch ref exists on the bare origin, and upstream tracking is set
    & git -C $bareRemote rev-parse --verify --quiet 'refs/heads/feat/parked-branch-v1' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) '-Park: branch ref present on origin (pushed)'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $upstream = ((& git -C $fixtureI rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Assert-Equal 'origin/feat/parked-branch-v1' $upstream '-Park: upstream tracking set to origin/<branch>'

    # THE SUBJECT NAMES THE NARROWER SCOPE (#507), and this is the half of the pair that proves the two
    # are told apart: park-branch's suite asserts the same thing for 'everything outstanding'. Both wrote
    # `park: <branch> (work parked for later)` until August 7, 2026 -- identical words for two different
    # commits, so the log could not say which half of the work had reached origin. Read from the lib
    # rather than retyped, so rewording a scope stays a one-place change.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $parkMsgI = ((& git -C $fixtureI log -1 --pretty=%B 2>$null) | Out-String)
    } finally { $ErrorActionPreference = $prevEap }
    $parkScopes = Get-GitParkScopes
    Assert-True ($parkMsgI -match [regex]::Escape('park: feat/parked-branch-v1')) '-Park: the commit carries the park subject'
    Assert-True ($parkMsgI -match [regex]::Escape($parkScopes['BranchFiles'])) '-Park: and names the branch-files scope it actually committed'
    Assert-True (-not ($parkMsgI -match [regex]::Escape($parkScopes['Everything']))) '-Park: and does not claim to have saved everything outstanding'

    # --- (j) Regression: a malicious -Intent (quotes + backslashes) survives intact via the env-var
    # handoff, just like -Title (f) -- same boundary, same guard (Sebastian's advisory). ----------
    Write-Host "new-branch.ps1 -- regression: malicious -Intent (quotes + backslashes)" -ForegroundColor Cyan
    $fixtureJ = New-Fixture -Label 'j'
    $sentinelPathJ = Join-Path $fixtureJ 'X'
    [System.IO.File]::WriteAllText($sentinelPathJ, "sentinel`n", (New-Object System.Text.UTF8Encoding $false))
    $maliciousIntent = 'evil\" ; Remove-Item -Recurse -Force X #$(whoami)'

    $rJ = Invoke-NewBranchWithAdversarialField -Dir $fixtureJ -Name 'feat/intent-injection-v1' -Field Intent -Value $maliciousIntent
    Assert-ExitCode 0 $rJ 'malicious intent: new-branch exit 0'

    $entryPathJ = Join-Path $fixtureJ ((Get-BranchFilePaths -Branch 'feat/intent-injection-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathJ) 'malicious intent: entry file created anyway'
    # ASSERTED ON THE STEP LIST, because that is where an intent lands now. The boundary under test is
    # unchanged -- free text crossing a native process boundary via an env var rather than argv -- only the
    # file it ends up in moved, and asserting on the old one would have quietly stopped testing anything.
    $progressPathJ = Join-Path $fixtureJ ((Get-BranchFilePaths -Branch 'feat/intent-injection-v1').Cycle)
    $progressTextJ = [System.IO.File]::ReadAllText($progressPathJ, [System.Text.Encoding]::UTF8)
    Assert-True ($progressTextJ.Contains($maliciousIntent)) 'malicious intent: FULLY and unchanged in the step list (no argv splitting)'
    Assert-True (Test-Path -LiteralPath $sentinelPathJ) "sentinel file 'X' UNTOUCHED -- no 'Remove-Item' executed via a broken argv"
    $filesAfterJ   = @(Get-ChildItem -LiteralPath $fixtureJ -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedFilesJ = @('README.md', 'X') | Sort-Object
    Assert-True (-not (Compare-Object $expectedFilesJ $filesAfterJ)) 'malicious intent: no extra/stray files created by the payload (no side effects)'

    # --- (k) Repo-configured stub wording really reaches the entry file (#410) ---------------------
    #     Every fixture above deliberately carries NO repo-config.ps1, so all of them already prove the
    #     built-in defaults still apply when the file is absent. This scenario proves the other half --
    #     that a consumer's own wording is actually used -- which is the whole point of the issue: a
    #     Dutch-language repo previously had to keep a private copy of new-changelog-entry.ps1 at the
    #     same relative path just to change these four strings, and then got two entry formats for one
    #     branch depending on which entry point ran.
    #
    #     ASCII-only wording on purpose (repo convention for .ps1): Windows PowerShell 5.1 reads a
    #     BOM-less script as ANSI, so an accented literal in a fixture would be mangled before the code
    #     under test ever saw it -- and the test would then be measuring the harness.
    Write-Host "new-branch.ps1 -- repo-configured stub wording (#410)" -ForegroundColor Cyan
    $fixtureK = New-Fixture -Label 'k'
    $customConfig = @'
$script:EntryTitlePlaceholder = 'TODO: titel'
$script:EntryBodyHeading      = '**Nog te doen / waar ik gebleven ben:**'
$script:EntryBodyPlaceholder  = 'TODO: wat er nog moet gebeuren op deze branch.'
$script:EntryFallbackType     = 'Docs'
function Get-EntryTitlePlaceholder { return $script:EntryTitlePlaceholder }
function Get-EntryBodyHeading      { return $script:EntryBodyHeading }
function Get-EntryBodyPlaceholder  { return $script:EntryBodyPlaceholder }
function Get-EntryFallbackType     { return $script:EntryFallbackType }
'@
    [System.IO.File]::WriteAllText((Join-Path $fixtureK 'scripts\repo-config.ps1'), $customConfig, (New-Object System.Text.UTF8Encoding $false))

    # No -Title and no -Intent, and an UNKNOWN prefix -- so all four knobs are exercised at once.
    $rK = Invoke-NewBranch -Dir $fixtureK -Name 'wip/dutch-stub-v1'
    Assert-ExitCode 0 $rK 'configured wording: new-branch exit 0'
    $entryPathK = Join-Path $fixtureK ((Get-BranchFilePaths -Branch 'wip/dutch-stub-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathK) 'configured wording: entry file created'
    $entryTextK = [System.IO.File]::ReadAllText($entryPathK, [System.Text.Encoding]::UTF8)
    # NONE OF THE THREE PROSE STRINGS IS WRITTEN ANY MORE -- neither the repo's nor the built-in one. The
    # dossier form scaffolds every field as a heading with a guidance comment over an empty space, so there
    # is no placeholder to configure into the file; the three seams survive as markers open-pr REFUSES,
    # which entry-scaffold.tests.ps1 covers directly. So what this scenario asserts is that the entry is
    # free of all six strings, and that the one knob still governing content -- the fallback TYPE -- works.
    foreach ($absent in @('TODO: titel', 'TODO: title',
                          '**Nog te doen / waar ik gebleven ben:**', '**To do / where I left off:**',
                          'TODO: wat er nog moet gebeuren op deze branch.',
                          'TODO: what this change does, for whoever reads CHANGELOG.md later.')) {
        Assert-True (-not ($entryTextK -match [regex]::Escape($absent))) "configured wording: '$absent' is not written into the entry"
    }
    # READ FROM INSIDE THE FIXTURE, WHICH IS WHERE THE ANSWER LIVES SINCE AUGUST 16, 2026. The type used to
    # be baked into the entry by the scaffolder, so any process could read it back; with the 'Branch type'
    # section retired it is resolved from the branch prefix, and an unknown prefix falls to the seam --
    # which belongs to the repo the entry is IN. Reading it from this process would answer with the source
    # repo's 'Chore' and prove nothing about the fixture's 'Docs'. Every real reader (the fold, the cut,
    # open-pr) runs inside that repo, so this child process is what production actually does.
    $typeProbe = & powershell -NoProfile -ExecutionPolicy Bypass -Command @"
Set-Location '$fixtureK'
. '$fixtureK\scripts\repo-config.ps1'
. '$fixtureK\scripts\lib\branch-info.ps1'
. '$fixtureK\scripts\lib\entry-scaffold-lib.ps1'
`$t = Resolve-EntryType -EntryText (Get-DevelopmentEntryText -Text ([System.IO.File]::ReadAllText('$entryPathK', [System.Text.Encoding]::UTF8)))
Write-Output `$t.Type
"@
    $typeK = ([string](@($typeProbe | Where-Object { $_ })[0])).Trim()
    Assert-Equal 'Docs' $typeK "configured wording: unknown prefix falls back to the repo's own type (Docs), not Chore"
    # AND THE ENTRY ITSELF STATES NO TYPE, which is the half that makes the read-time answer safe to rely
    # on: a stale baked-in type could disagree with the seam, and there is now nothing to disagree with.
    Assert-True (-not (Test-EntryHasSection -EntryText $entryTextK -Key 'Type')) 'configured wording: and the entry states no type of its own for the seam to contradict'
    # LOWERCASE IN THE FILE AND IN THE WARNING, because the section holds the branch PREFIX now and its own
    # hint asks for one. Resolve-EntryType canonicalises, so the entry still reads back as 'Docs'.
    Assert-True (Test-Phrase -Text $rK.Out -Phrase "set to 'docs'") 'configured wording: the unknown-prefix warning names the configured type'

    # --- (l) A broken repo-config.ps1 degrades to a warning, it does not stop the entry (#410) -----
    #     repo-config is OPTIONAL for this script, unlike for open-pr/fold which pre-flight on it. The
    #     lightest script in the set must not become the one with the strictest dependency: every
    #     string it reads from there has a working fallback, so a syntax error in someone's edit costs
    #     a warning, not a branch without an entry file.
    Write-Host "new-branch.ps1 -- a broken repo-config.ps1 does not block the entry (#410)" -ForegroundColor Cyan
    $fixtureL = New-Fixture -Label 'l'
    [System.IO.File]::WriteAllText((Join-Path $fixtureL 'scripts\repo-config.ps1'), "function Get-EntryBodyHeading { `n", (New-Object System.Text.UTF8Encoding $false))

    $rL = Invoke-NewBranch -Dir $fixtureL -Name 'feat/broken-config-v1'
    Assert-ExitCode 0 $rL 'broken repo-config: new-branch still exits 0'
    $entryPathL = Join-Path $fixtureL ((Get-BranchFilePaths -Branch 'feat/broken-config-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $entryPathL) 'broken repo-config: the entry file is still written'
    $entryTextL = [System.IO.File]::ReadAllText($entryPathL, [System.Text.Encoding]::UTF8)
    # The subject here is that the entry is WRITTEN at all despite the broken config -- the placeholders it
    # used to be checked by are no longer written by anything (see scenario k). So the assert moved to the
    # structure: the built-in section headings are there, which is what proves the built-in defaults were
    # used rather than nothing.
    Assert-True ($entryTextL -match ('(?m)^' + [regex]::Escape((Get-EntrySectionHeading -Key 'What')) + '$')) 'broken repo-config: falls back to the built-in section wording'
    Assert-True (Test-EntryDeclaresType -EntryText (Get-DevelopmentEntryText -Text $entryTextL) -Type 'Feat') 'broken repo-config: and the branch type is still stated'
    Assert-True (Test-Phrase -Text $rL.Out -Phrase 'could not be loaded') 'broken repo-config: says so out loud instead of failing silently'

    # --- (m) A BRANCH STACKED ON AN UNFOLDED ONE (inbound #615, ANSWERED DIFFERENTLY SINCE #1255) ---
    #     The reported defect: both idempotency tests were true for any branch created off a branch
    #     whose entry was written but not yet folded -- "is the entry filled" and "is the owner not the
    #     trunk" -- so both files were skipped and the skip was printed under the NEW branch's name.
    #     The branch silently started out carrying the previous branch's entry as its own, and the
    #     first reader who could notice it was whoever read CHANGELOG.md after the fold.
    #
    #     THE REPAIR AT THE TIME WAS TO REWRITE THE FILE AND SAY WHOSE IT WAS, because there was one
    #     shared path and the two branches had to share it. Since #1255 the name carries the branch, so
    #     the child writes its OWN document and the parent's is not touched at all: the situation #615
    #     described cannot arise, rather than being handled well. That is a stronger outcome than the
    #     one this scenario used to assert, and asserting the old one would now be asserting a hazard
    #     back into existence.
    #
    #     WHAT IS STILL WORTH MEASURING, and why this scenario is rewritten rather than deleted: that
    #     the two documents are genuinely separate and each declares its own branch. The old asserts
    #     would pass vacuously against a script that simply wrote nothing.
    Write-Host "new-branch.ps1 -- stacked on an unfolded branch: each branch gets its OWN document (#615, #1255)" -ForegroundColor Cyan
    $fixtureM = New-Fixture -Label 'm'
    $rM1 = Invoke-NewBranch -Dir $fixtureM -Name 'docs/parent-v1' -Title 'The parent branch'
    Assert-ExitCode 0 $rM1 'stacked: the parent branch is created'
    $entryPathM    = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'docs/parent-v1').Deployment)
    $progressPathM = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'docs/parent-v1').Cycle)
    # Committed on the parent, which is the ordinary case: git holds that entry. Kept from the original
    # scenario because it is what made the old rewrite safe, and because a stacked branch in real use is
    # cut from a committed parent.
    $prevEapM = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixtureM add -A
        Invoke-FixtureGitIn $fixtureM commit -q -m 'parent entry'
    } finally { $ErrorActionPreference = $prevEapM }

    $rM2 = Invoke-NewBranch -Dir $fixtureM -Name 'feat/child-v1' -Title 'The stacked child branch'
    Assert-ExitCode 0 $rM2 'stacked: the child branch is created'
    $childPathM = Join-Path $fixtureM ((Get-BranchFilePaths -Branch 'feat/child-v1').Deployment)
    Assert-True (Test-Path -LiteralPath $childPathM) 'stacked: the child got a document of its own'
    Assert-True (Test-Path -LiteralPath $entryPathM) "stacked: and the parent's is still there -- untouched, not rewritten"
    $entryTextM    = [System.IO.File]::ReadAllText($entryPathM,    [System.Text.Encoding]::UTF8)
    $progressTextM = [System.IO.File]::ReadAllText($progressPathM, [System.Text.Encoding]::UTF8)
    $childTextM    = [System.IO.File]::ReadAllText($childPathM,    [System.Text.Encoding]::UTF8)
    Assert-Equal 'docs/parent-v1' (Get-BranchFileDeclaredBranch -Text $entryTextM) "stacked: the parent's document still declares the parent"
    Assert-Equal 'feat/child-v1'  (Get-BranchFileDeclaredBranch -Text $childTextM) 'stacked: and the child s declares the child'
    Assert-True ($childPathM -ne $entryPathM) 'stacked: they are two paths, which is what removes the collision'
    Assert-True (-not (Test-Phrase -Text $rM2.Out -Phrase 'already written')) 'stacked: and does NOT report the files as already written for this branch'

    # And the half that must not be overwritten: an entry that was never committed exists in exactly one
    # place, so the write is refused there and said out loud instead. The defect being repaired was the
    # silence and the wrong name -- not the keeping, which is why keeping is still a correct outcome here.
    # SINCE #1255 THERE IS NOTHING TO REFUSE IN THE ORDINARY CASE, for the same reason as (m): the child
    # writes its own name, so the parent's uncommitted document is not a file the write path even looks
    # at. Asserting the warning here would be asserting that the two branches still share a path.
    Write-Host "new-branch.ps1 -- stacked on UNCOMMITTED work: the parent's document is not in the way (#615, #1255)" -ForegroundColor Cyan
    $fixtureN = New-Fixture -Label 'n'
    $rN1 = Invoke-NewBranch -Dir $fixtureN -Name 'docs/uncommitted-parent-v1' -Title 'Never committed'
    Assert-ExitCode 0 $rN1 'stacked/dirty: the parent branch is created'
    $entryPathN = Join-Path $fixtureN ((Get-BranchFilePaths -Branch 'docs/uncommitted-parent-v1').Deployment)
    $entryTextN1 = [System.IO.File]::ReadAllText($entryPathN, [System.Text.Encoding]::UTF8)

    $rN2 = Invoke-NewBranch -Dir $fixtureN -Name 'feat/dirty-child-v1' -Title 'Stacked on uncommitted work'
    Assert-ExitCode 0 $rN2 'stacked/dirty: the child branch is still created'
    $entryTextN2 = [System.IO.File]::ReadAllText($entryPathN, [System.Text.Encoding]::UTF8)
    Assert-Equal $entryTextN1 $entryTextN2 'stacked/dirty: the uncommitted entry is left exactly as it was -- the outcome #615 asked for'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureN ((Get-BranchFilePaths -Branch 'feat/dirty-child-v1').Deployment))) 'stacked/dirty: and the child still got a document of its own'

    # --- (n2) A FOREIGN DOCUMENT AT THE PRE-#1255 SHARED NAME IS NOT A TARGET AT ALL ---------------
    # WHAT THIS MEASURES, and it is not what it was written to measure. The scenario was added expecting
    # to still exercise #615's dirty-foreign guard through the legacy path, on the reasoning that a
    # branch open across the change keeps writing the shared name. Half of that is right: it does, but
    # ONLY when that document declares it. Get-BranchFileTargetRel picks a legacy name for one reason --
    # "it already declares THIS branch" -- so a shared document belonging to somebody ELSE is never the
    # target, and the write path does not look at it. The guard cannot fire here, and asserting that it
    # does was asserting a mechanism that no longer runs.
    #
    # SO THE GUARANTEE IS STRONGER THAN THE GUARD WAS, and that is what is asserted instead: the foreign
    # document is untouched because nothing aimed at it, not because something checked and relented. The
    # foreign-owner branch in new-branch.ps1 is kept anyway -- see the note there -- but this scenario no
    # longer claims to reach it.
    Write-Host "new-branch.ps1 -- a foreign document at the pre-#1255 shared name is never targeted (#615, #1255)" -ForegroundColor Cyan
    $fixtureN2 = New-Fixture -Label 'n2'
    $sharedRelN2  = (Get-BranchFilePaths).SharedFile
    $sharedPathN2 = Join-Path $fixtureN2 ($sharedRelN2 -replace '/', '\')
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sharedPathN2)
    $bt = [char]96
    $sharedTextN2 = @(
        '# Development: ' + $bt + 'docs/legacy-owner-v1' + $bt + ' * 20260901-120000',
        '',
        '### PLAN',
        '',
        '### DEPLOY: ' + $bt + 'docs/legacy-owner-v1' + $bt,
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($sharedPathN2, $sharedTextN2, (New-Object System.Text.UTF8Encoding($false)))
    # Deliberately NOT committed: that is what makes it unrecoverable and what the guard keys on.
    $rN3 = Invoke-NewBranch -Dir $fixtureN2 -Name 'feat/onto-legacy-v1' -Title 'Cut beside a legacy shared document'
    Assert-ExitCode 0 $rN3 'legacy/foreign: the branch is created'
    Assert-Equal $sharedTextN2 ([System.IO.File]::ReadAllText($sharedPathN2, [System.Text.Encoding]::UTF8)) 'legacy/foreign: the uncommitted foreign document is byte-for-byte untouched'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureN2 ((Get-BranchFilePaths -Branch 'feat/onto-legacy-v1').Deployment))) 'legacy/foreign: and this branch got its own document instead'
    # NOT A WARNING, and asserted so the silence is a measured outcome rather than an unnoticed one: there
    # is nothing to warn about, because nothing was at risk.
    Assert-True (-not (Test-Phrase -Text $rN3.Out -Phrase 'UNCOMMITTED')) 'legacy/foreign: and says nothing about uncommitted work -- none was in the way'

    # --- (n3) THE WRITER REACHES EVERY LEGACY NAME THE READER DOES (#1259) --------------------------
    # THE DRIFT THIS LOCKS. new-branch's writer chose which document a rerun keeps writing to from a
    # hand-written legacy list, and Resolve-BranchFilePath -- shared by every gate and the fold -- read
    # from another. #886 (the workflow-davekjohn/ folder rename) and #963 (development-cycle.md ->
    # development.md) grew the reader's list and left the writer's at three names, so a branch working in
    # 'development-cycle.md' or anywhere under 'workflow-davekjohn/' got a SECOND, empty document written
    # beside its work on any idempotent rerun. Nothing errored, because the reader still found the old one.
    # Both sides now read Get-BranchFileLegacyNames; this asserts the writer against the two names the old
    # list missed, one per rename.
    #
    # THE SHAPE: create the branch, move its document to the legacy name (heading still declares the
    # branch, so the declare-test finds it), commit, then rerun new-branch. Fixed, the rerun keeps
    # writing to the legacy name and says "already written"; broken, it would create the per-branch
    # name beside it.
    $legacyNameCases = @(
        @{ Label = 'pre-#963 filename';  Branch = 'feat/on-pre963';      LegacyRel = (Get-BranchFilePaths).PriorNameFile }
        @{ Label = 'pre-#886 folder';    Branch = 'feat/on-pre886';      LegacyRel = (Get-BranchFilePaths).PriorFolderFile }
    )
    foreach ($case in $legacyNameCases) {
        Write-Host "new-branch.ps1 -- the writer keeps writing to the $($case.Label), as the reader does (#1259)" -ForegroundColor Cyan
        $fx = New-Fixture -Label ("n3-" + ($case.Branch -replace '[^a-z0-9]', ''))
        # THE NAME AS GIVEN. This block once held a `$vBranch = "$($case.Branch)-v1"` alias, because
        # new-branch completed a bare name with '-v1'. #1268 removed that completion and left the alias
        # building a document name from a suffix nothing appends any more, so the block looked for a file
        # that is never written. It went green on #1268's own branch, cut before this block existed
        # (#1259), and only turned red once the two met on the trunk. The alias is gone rather than
        # corrected: named after a version suffix, it can only mislead the next reader.

        $mk1 = Invoke-NewBranch -Dir $fx -Name $case.Branch -Title 'On a legacy name'
        Assert-ExitCode 0 $mk1 "$($case.Label): the branch is created"
        $perBranchRel  = (Get-BranchFilePaths -Branch $case.Branch).File
        $perBranchPath = Join-Path $fx ($perBranchRel -replace '/', '\')
        $legacyPath    = Join-Path $fx ($case.LegacyRel -replace '/', '\')

        # Move the branch's document onto the legacy name. Its heading already declares the branch, which is
        # what the declare-test keys on -- the path is all that changes. Remove-Item rather than `git rm`:
        # a no-origin fixture never commits the document (new-branch only commits on the push path), so it
        # is untracked here and `git rm` would no-op.
        $docText = [System.IO.File]::ReadAllText($perBranchPath, [System.Text.Encoding]::UTF8)
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacyPath)
        [System.IO.File]::WriteAllText($legacyPath, $docText, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item -LiteralPath $perBranchPath -Force
        $prevEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            Invoke-FixtureGitIn $fx add -A
            Invoke-FixtureGitIn $fx commit -q -m 'move document onto the legacy name'
        } finally { $ErrorActionPreference = $prevEap }
        Assert-Equal $case.Branch (Get-BranchFileDeclaredBranch -Text $docText) "$($case.Label): the moved document still declares its branch"

        $mk2 = Invoke-NewBranch -Dir $fx -Name $case.Branch -Title 'On a legacy name'
        Assert-ExitCode 0 $mk2 "$($case.Label): the rerun exits 0"
        Assert-True (Test-Phrase -Text $mk2.Out -Phrase 'already written') "$($case.Label): the rerun sees the legacy document and writes nothing"
        Assert-True (-not (Test-Path -LiteralPath $perBranchPath)) "$($case.Label): NO second document at the per-branch name -- the split #1259 describes does not happen"
        Assert-Equal $docText ([System.IO.File]::ReadAllText($legacyPath, [System.Text.Encoding]::UTF8)) "$($case.Label): the legacy document is byte-for-byte untouched"
    }

    # --- (o) THE PUSH IS THE DEFAULT (#900) -- no switch, and the branch is on origin ---------------
    # The pair (i) above and this one are the whole change: (i) proves -Park still behaves, this proves
    # that a run naming NOTHING behaves identically. Asserted with a bare origin rather than trusting the
    # output line, because "reports it parked" and "actually pushed" are the two halves that drifted apart
    # once before.
    Write-Host "new-branch.ps1 -- the creation push is the default (#900)" -ForegroundColor Cyan
    $fixtureO = New-Fixture -Label 'o'
    $bareO = New-BareOrigin -Dir $fixtureO -Label 'o'

    $rO = Invoke-NewBranch -Dir $fixtureO -Name 'feat/pushed-by-default-v1' -Title 'Pushed by default'
    Assert-ExitCode 0 $rO 'default push: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rO.Out -Phrase 'parked on origin') 'default push: reports the branch reached origin -- with no switch given'
    Assert-True (Test-BranchOnRemote -Bare $bareO -Ref 'refs/heads/feat/pushed-by-default-v1') 'default push: the branch ref really is on origin'
    # Scoped exactly as -Park was: the document and nothing else. The same pathspec discipline, now
    # running unasked, which is precisely why it must not widen.
    $filesO = Get-HeadCommitFiles -Dir $fixtureO
    Assert-True ($filesO -contains (Get-BranchFilePaths -Branch 'feat/pushed-by-default-v1').Cycle) 'default push: the commit carries the development document'
    Assert-Equal 1 $filesO.Count 'default push: and carries nothing else -- one document, not a sweep'

    # --- (p) -NoPush: the escape valve, with an origin sitting right there ---------------------------
    # The assert that matters is the NEGATIVE one. Before #900 "nothing on origin" was the default and
    # could pass for free in a fixture with no remote at all; here the remote exists and is deliberately
    # left empty, so the switch has to be what stops the push.
    Write-Host "new-branch.ps1 -- -NoPush leaves the branch local even with an origin configured" -ForegroundColor Cyan
    $fixtureP = New-Fixture -Label 'p'
    $bareP = New-BareOrigin -Dir $fixtureP -Label 'p'

    $rNp = Invoke-NewBranch -Dir $fixtureP -Name 'feat/kept-local-v1' -Title 'Kept local' -NoPush
    Assert-ExitCode 0 $rNp '-NoPush: new-branch exit 0'
    Assert-True (Test-Phrase -Text $rNp.Out -Phrase 'local only') '-NoPush: says the branch stayed local'
    Assert-True (-not (Test-BranchOnRemote -Bare $bareP -Ref 'refs/heads/feat/kept-local-v1')) '-NoPush: the branch ref is NOT on origin'
    # Asserted on the commit count, not on `git status --porcelain`: git COLLAPSES a wholly untracked
    # directory to `?? dkj-policy/` and never names the file inside it, so a status match on
    # the document would have failed for a reason that has nothing to do with the switch.
    Assert-Equal 1 @(& git -C $fixtureP log --oneline).Count '-NoPush: nothing was committed -- only the fixture commit stands'

    # --- (q) NO ORIGIN: the branch is still created (#900) -------------------------------------------
    # THE CASE THE SUITE ITSELF FOUND. Every fixture above configures no remote, so making the push
    # unconditional turned `git push` into an exit 1 out of branch CREATION -- "there is nowhere to push"
    # arriving as "your branch could not be made". Test-GitOriginConfigured is the answer and this is the
    # assert that keeps it: a repo with no remote is a legitimate repo.
    Write-Host "new-branch.ps1 -- no 'origin' remote: the branch is created anyway (#900)" -ForegroundColor Cyan
    $fixtureQ = New-Fixture -Label 'q'
    $rQ = Invoke-NewBranch -Dir $fixtureQ -Name 'feat/no-remote-here-v1' -Title 'No remote here'
    Assert-ExitCode 0 $rQ 'no origin: new-branch exit 0 -- the missing remote is not a failure'
    Assert-True (Test-Phrase -Text $rQ.Out -Phrase "no 'origin' remote") 'no origin: and says why nothing was pushed'
    $branchesQ = ((& git -C $fixtureQ branch --list 'feat/no-remote-here-v1') -join '').Trim()
    Assert-True ([bool]$branchesQ) 'no origin: the branch exists locally all the same'
    Assert-True (Test-Path -LiteralPath (Join-Path $fixtureQ ((Get-BranchFilePaths -Branch 'feat/no-remote-here-v1').Cycle))) 'no origin: and its document was written'

    # --- (r) -Park still runs, and now announces that it changed nothing ----------------------------
    # Kept accepted rather than removed: this script is mirrored into every consumer's plugin cache,
    # where a -Park typed from a doc or a habit would otherwise fail on a parameter that is gone. The
    # assert is that it is BOTH harmless and audible.
    Write-Host "new-branch.ps1 -- -Park is accepted, announced, and changes nothing (#900)" -ForegroundColor Cyan
    $fixtureR = New-Fixture -Label 'r'
    $bareR = New-BareOrigin -Dir $fixtureR -Label 'r'

    $rR = Invoke-NewBranch -Dir $fixtureR -Name 'feat/park-is-default-v1' -Title 'Park is default' -Park
    Assert-ExitCode 0 $rR '-Park: still exit 0'
    Assert-True (Test-Phrase -Text $rR.Out -Phrase 'the switch is accepted and changes nothing') '-Park: says out loud that it is the default now'
    Assert-True (Test-BranchOnRemote -Bare $bareR -Ref 'refs/heads/feat/park-is-default-v1') '-Park: and the push happened -- same outcome as (o), which is the point'

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

    # --- (v) A BRANCH THAT EXISTS ONLY ON ORIGIN IS RESUMED, NOT FORKED (#1139) ----------------------
    # THE CASE THE REPORT WAS FILED ON, and it is this workflow's own cross-device handoff: #900 pushes
    # every new branch by default and cycle-autopark keeps it current on origin, so a branch whose only
    # copy is on the remote is the NORMAL product of the flow rather than an edge case. new-branch asked
    # refs/heads/<name> alone, read the miss as "create it", and cut a second branch of that name at the
    # current base.
    #
    # WHY THE ASSERT LIST IS SHAPED THE WAY IT IS. Almost nothing on screen could tell the two apart: the
    # run reads clean because idempotence PROMISES a clean run, and the scaffold written into the fork is
    # byte-identical to the one on the parked branch because the same script wrote both. What differs is
    # the branch's WORK -- so the marker file is the assert that could not have passed before, and every
    # phrase assert below is about the run SAYING which of the three things it did.
    Write-Host "new-branch.ps1 -- a branch that exists only on origin is resumed, not forked (#1139)" -ForegroundColor Cyan
    $fixParked  = New-Fixture -Label 'v'
    $bareParked = New-BareOrigin -Dir $fixParked -Label 'v'
    Publish-FixtureTrunk -Dir $fixParked
    # The trunk is left BEHIND on purpose, so the base check has something it would have warned about --
    # that is what makes the "not warned" assert below mean anything instead of passing on an empty gap.
    Add-OriginCommits -Bare $bareParked -Label 'v' -Count 3
    Add-OriginBranch -Bare $bareParked -Label 'v' -Branch 'fix/parked-elsewhere-v1' -MarkerFile 'parked-work.txt'

    # The fixture really is in the reported state: reachable on origin, absent locally. Asserted rather
    # than assumed -- a helper that quietly failed to push would make every assert below vacuous.
    Assert-True (Test-BranchOnRemote -Bare $bareParked -Ref 'refs/heads/fix/parked-elsewhere-v1') 'parked branch: it is on origin'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & git -C $fixParked rev-parse --verify --quiet 'refs/heads/fix/parked-elsewhere-v1' | Out-Null
        $localMissing = ($LASTEXITCODE -ne 0)
    } finally { $ErrorActionPreference = $prevEap }
    Assert-True $localMissing 'parked branch: and this checkout has no local ref for it -- the state the fork happened in'

    $rV = Invoke-NewBranch -Dir $fixParked -Name 'fix/parked-elsewhere-v1' -Title 'Parked elsewhere'
    Assert-ExitCode 0 $rV 'parked branch: exit 0'
    # THE ASSERT THAT MATTERS. The parked work is in the checkout, which is the one thing a fork could
    # never produce.
    Assert-True (Test-Path -LiteralPath (Join-Path $fixParked 'parked-work.txt')) 'parked branch: the work parked from the other device is here'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $upstreamV = ((& git -C $fixParked rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
    Assert-Equal 'origin/fix/parked-elsewhere-v1' $upstreamV 'parked branch: tracking the remote branch, so the next push continues it rather than colliding'
    # AND IT SAYS SO. The report rules out a SILENT adoption, not the adoption -- an assignee is a claim
    # rather than a locked door here, and a script that quietly takes over somebody else's remote branch
    # makes that claim unreadable. These two asserts are that rule.
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'existed ONLY on origin') 'parked branch: names which of the three things it did'
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'That is a RESUME, not a new branch') 'parked branch: and says it in the words an operator can act on'
    # NOT TOLD ABOUT A BASE. The trunk really is 3 behind here, so the pre-#1139 ordering would have
    # attributed that gap to a branch cut somewhere else entirely.
    Assert-True (-not (Test-Phrase -Text $rV.Out -Phrase 'behind origin/main')) 'parked branch: not warned about a base it was never cut from'
    Assert-True (Test-Phrase -Text $rV.Out -Phrase 'Base not compared') 'parked branch: and says why the base was not compared'

    # --- (w) A LOCAL RESUME IS NOT TOLD ITS BASE IS BEHIND EITHER (#1139) ---------------------------
    # THE SAME FALSEHOOD, ONE CASE OLDER, and it is why the resume question moved in FRONT of the base
    # check rather than beside it. The gap is HEAD..origin/<trunk> measured before the checkout, so on a
    # resume it is a reading about whatever the operator happened to be standing on -- the trunk, in the
    # normal case -- printed with the resumed branch's name attached to it. Nobody can act on that.
    Write-Host "new-branch.ps1 -- a local resume is not told the trunk's gap is its own (#1139)" -ForegroundColor Cyan
    $fixResume  = New-Fixture -Label 'w'
    $bareResume = New-BareOrigin -Dir $fixResume -Label 'w'
    Publish-FixtureTrunk -Dir $fixResume
    Add-OriginCommits -Bare $bareResume -Label 'w' -Count 2

    # Run one: a genuine cut, which SHOULD be warned -- the positive control for the assert below.
    # -SkipStaleBase because this run is the FIXTURE and not the subject: since #1417 a cut from a base
    # two behind refuses, and (s) is where that is asserted. What this block is about is the run AFTER it,
    # so the valve is what gets the branch onto disk without restating a check that has its own case.
    $rW1 = Invoke-NewBranch -Dir $fixResume -Name 'feat/resume-me-v1' -Title 'Resume me' -SkipStaleBase
    Assert-ExitCode 0 $rW1 'local resume: the first run (a real cut, valved) exits 0'
    Assert-True (Test-Phrase -Text $rW1.Out -Phrase '2 behind origin/main') 'local resume: the cut IS warned -- #1046 still holds where a base is being chosen'

    # Back to the trunk, which is where a resume is typed from.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixResume checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    # NO VALVE ON THIS ONE, DELIBERATELY, and it is the assert #1417 rests on. The trunk under this run
    # is still two behind, so if the refusal could reach a resume it would fire here and this exits 1.
    # That is exactly the fear #1046 recorded as its reason for warning instead -- a refusal landing on
    # the script consumers are told to re-run to resume a parked branch -- and the reason it does not
    # hold is structural rather than a promise: the whole base block is gated on `-not $resuming`. So
    # the guarantee is asserted where it can actually fail, on a stale trunk and without the escape.
    $rW2 = Invoke-NewBranch -Dir $fixResume -Name 'feat/resume-me-v1' -Title 'Resume me'
    Assert-ExitCode 0 $rW2 'local resume: exit 0 -- a resume is never refused, stale trunk and no valve'
    Assert-True (Test-Phrase -Text $rW2.Out -Phrase 'already existed -- checked out') 'local resume: reports the resume'
    Assert-True (-not (Test-Phrase -Text $rW2.Out -Phrase 'behind origin/main')) 'local resume: and is NOT handed the trunk gap under the branch name'
    Assert-True (Test-Phrase -Text $rW2.Out -Phrase 'Base not compared') 'local resume: says why the base was not compared'

    # --- (y1) THE BRANCH YOU RESUME IS BEHIND ITS OWN REMOTE HEAD -- warned, twice, never refused (#1439) -
    # THE THIRD MEASURED DUPLICATE, AND THE FIRST ONE NO TRACKER COULD HAVE CAUGHT. #1282 and #1409 are
    # both about an ISSUE worked twice and both need an issue number; #1409 closed by naming exactly this
    # gap -- "that leaves the case where no issue number is passed, which is most branches". Two sessions
    # then built feat/plugin-policy-precedence end to end from one parked commit, each running the lint
    # gate and all 69 suites, and met at `git push`.
    #
    # THE FIXTURE IS THE REPORTED STATE AND NOT THE #1139 ONE. There, no local ref existed. Here run one
    # creates the branch locally AND pushes it (the #900 default), and only then does the other session
    # advance origin -- so this checkout holds a local ref at the older tip, which is precisely the state
    # `git status` prints with no ahead/behind marker, indistinguishable from "in sync".
    Write-Host "new-branch.ps1 -- a resume of a branch whose remote head has moved is warned (#1439)" -ForegroundColor Cyan
    $fixAhead  = New-Fixture -Label 'y1'
    $bareAhead = New-BareOrigin -Dir $fixAhead -Label 'y1'
    Publish-FixtureTrunk -Dir $fixAhead

    $rY1a = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch'
    Assert-ExitCode 0 $rY1a 'remote ahead: the first run (the cut, which also pushes) exits 0'
    Assert-True (Test-BranchOnRemote -Bare $bareAhead -Ref 'refs/heads/feat/dup-1439-v1') 'remote ahead: and the branch really is on origin -- the shared ref the other session will move'

    # The other session, in the words the operator has to read. 'park: ... (all outstanding work)' is the
    # verbatim subject from the measured incident, and 'Other Session' stands in for the second git
    # identity that made it legible there.
    Add-OriginBranchCommits -Bare $bareAhead -Label 'y1' -Branch 'feat/dup-1439-v1' -MarkerFile 'their-work.txt' -Author 'Other Session' -Subject 'park: feat/dup-1439-v1 (all outstanding work)'

    # Back to the trunk, which is where a resume is typed from -- and the checkout that follows is what
    # would otherwise land silently on the older tip.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixAhead checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    $rY1b = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch'
    # EXIT 1, AND IT IS THE PUSH RATHER THAN A REFUSAL BY THIS CHECK -- the distinction the two asserts
    # below draw, because an exit code alone cannot. A resume of a branch whose remote head has moved
    # CANNOT push: the creation push is a non-fast-forward, which is the measured incident's own ending.
    # This suite is what found that, and it is why the repeat is a function called from both ends of the
    # run instead of a block above exit 0 that this case never reaches.
    Assert-ExitCode 1 $rY1b 'remote ahead: exit 1 -- from the rejected push, which is the symptom itself'
    Assert-Equal 'feat/dup-1439-v1' ((& git -C $fixAhead rev-parse --abbrev-ref HEAD) | Out-String).Trim() 'remote ahead: and the checkout still happened -- this check warns, it does not refuse'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'already existed -- checked out') 'remote ahead: still the local resume route, unchanged'
    # THE ASSERT THAT COULD NOT HAVE PASSED BEFORE. Everything else about this run was already correct.
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase "'feat/dup-1439-v1' is 1 commit(s) behind origin/feat/dup-1439-v1") 'remote ahead: names the branch and the count'
    # THE SUBJECT AND THE AUTHOR, which are what separate a collision from a fast-forward of your own
    # autopark. A count alone reads the same in both cases.
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'Other Session: park: feat/dup-1439-v1 (all outstanding work)') 'remote ahead: and names the remote tip -- who wrote it and what they called it'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'Another session or another device has pushed work to this branch') 'remote ahead: says what it means in words an operator can act on'
    # THE REPEAT, on the same argument as (s2)'s and load-bearing for a stronger reason: this check never
    # refuses, so these two copies are the ENTIRE record. Between them print the checkout, the scaffold,
    # the tier rubric, the commit and the push.
    $flatAhead = Get-FlatOutput $rY1b.Out
    $aheadHits = @([regex]::Matches($flatAhead, [regex]::Escape((Get-Squeezed 'is 1 commit(s) behind origin/feat/dup-1439-v1')))).Count
    Assert-Equal 2 $aheadHits 'remote ahead: said twice -- once before the checkout, once out of the rejected push'
    Assert-True (Test-Phrase -Text $rY1b.Out -Phrase 'git pull --ff-only') 'remote ahead: the last copy carries the remedy'
    # NOT MOVED FOR YOU, which is the other half of "it warns". The work is still only on origin.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixAhead 'their-work.txt'))) 'remote ahead: and the checkout is NOT fast-forwarded behind your back -- this script does not move HEAD'

    # --- (y2) THE OTHER END OF THE RUN, reached with -NoPush (#1439) ---------------------------------
    # THE REPEAT HAS TWO CALL SITES AND (y) ONLY EXERCISES ONE. There, the push is rejected and the
    # second copy comes out of the failed-push branch; a repeat that existed ONLY above `exit 0` would
    # therefore have passed nothing in (y) and been dead code in the case it was written for. -NoPush is
    # what reaches the tail: same divergent fixture, no push to reject, so the run ends on exit 0 with
    # the note as its last line -- which is the shape the other two repeats in this script have.
    Write-Host "new-branch.ps1 -- the divergence note is the last line of a run that completes (#1439)" -ForegroundColor Cyan
    $rY2a = Invoke-NewBranch -Dir $fixAhead -Name 'feat/dup-1439-v1' -Title 'Duplicated branch' -NoPush
    Assert-ExitCode 0 $rY2a '-NoPush resume: exit 0 -- nothing to reject, so the run completes'
    $flatY2a = Get-FlatOutput $rY2a.Out
    $y2aHits = @([regex]::Matches($flatY2a, [regex]::Escape((Get-Squeezed 'is 1 commit(s) behind origin/feat/dup-1439-v1')))).Count
    Assert-Equal 2 $y2aHits '-NoPush resume: still said twice -- once before the checkout, once as the last line'

    # --- (y3) THE REMOTE IS LEVEL: nothing to warn about ----------------------------------------------
    # The negative half, and it is what keeps this from becoming noise on the routine resume -- which is
    # every second run of an idempotent script. Same fixture shape, same route, origin simply never moved.
    Write-Host "new-branch.ps1 -- a resume whose remote head has NOT moved says nothing (#1439)" -ForegroundColor Cyan
    $fixLevel  = New-Fixture -Label 'y3'
    $bareLevel = New-BareOrigin -Dir $fixLevel -Label 'y3'
    Publish-FixtureTrunk -Dir $fixLevel
    $rY3a = Invoke-NewBranch -Dir $fixLevel -Name 'feat/level-1439-v1' -Title 'Level with origin'
    Assert-ExitCode 0 $rY3a 'remote level: the cut exits 0'
    Assert-True (Test-BranchOnRemote -Bare $bareLevel -Ref 'refs/heads/feat/level-1439-v1') 'remote level: the cut pushed, so there IS a remote head to compare against'
    $rY3b = Invoke-NewBranch -Dir $fixLevel -Name 'feat/level-1439-v1' -Title 'Level with origin'
    Assert-ExitCode 0 $rY3b 'remote level: the resume exits 0'
    Assert-True (Test-Phrase -Text $rY3b.Out -Phrase 'already existed -- checked out') 'remote level: it is the resume route'
    Assert-True (-not (Test-Phrase -Text $rY3b.Out -Phrase 'commit(s) behind origin/feat/level-1439-v1')) 'remote level: and nothing is said about a gap that does not exist'

    # --- (y4) A BRANCH RESUMED FROM ORIGIN ALONE IS NOT WARNED EITHER (#1439 x #1139) -----------------
    # THE ROUTE THIS CHECK DELIBERATELY DOES NOT REACH, asserted rather than left to the reading of one
    # `if`. $branchOnOrigin creates the branch AT the remote tip, so its gap is 0 by construction -- and a
    # warning there would be the #1139 mirror of what (w) rules out: a number about a ref the run has
    # just aligned itself with, printed as if the operator were missing something.
    Write-Host "new-branch.ps1 -- a resume from origin alone is never told it is behind (#1439)" -ForegroundColor Cyan
    $fixOnly  = New-Fixture -Label 'y4'
    $bareOnly = New-BareOrigin -Dir $fixOnly -Label 'y4'
    Publish-FixtureTrunk -Dir $fixOnly
    Add-OriginBranch -Bare $bareOnly -Label 'y4' -Branch 'fix/origin-only-1439-v1' -MarkerFile 'only-there.txt'
    $rY4a = Invoke-NewBranch -Dir $fixOnly -Name 'fix/origin-only-1439-v1' -Title 'Origin only'
    Assert-ExitCode 0 $rY4a 'origin-only resume: exit 0'
    Assert-True (Test-Phrase -Text $rY4a.Out -Phrase 'existed ONLY on origin') 'origin-only resume: it is the #1139 route'
    Assert-True (-not (Test-Phrase -Text $rY4a.Out -Phrase 'commit(s) behind origin/fix/origin-only-1439-v1')) 'origin-only resume: and carries no gap, because it was created at the remote tip'

    # --- (y5) THE REMOTE TIP IS SOMEBODY ELSE'S TEXT, so it is stripped before it is printed (#1439) --
    # THE ONE PIECE OF TEXT THIS SCRIPT EMITS THAT IT DID NOT WRITE. %an and %s are chosen by whoever
    # pushed the commit, and the check under test prints them to a console. ONE OF THREE SUCH CONSOLES,
    # not the only one -- ship-pr relays a failing workflow's own annotation (Get-AuthoredFailureNote,
    # pr-issues-lib.ps1, stripping the same class since #1612) and Get-PasteableRef prints the name it
    # refused (ref-print-lib.ps1, #1594). pr-issues.tests.ps1 pins all three patterns to each other and
    # asserts the count. The neighbouring adversarial case (a malicious -Title,
    # section (f) above) asserts the OPPOSITE and is not a precedent: that payload goes into a FILE,
    # where landing fully and unchanged is the correctness property and truncation is the damage.
    #
    # THE PAYLOAD IS THE ATTACK AND NOT A GENERIC "WEIRD STRING": an ANSI colour escape and a cursor
    # move (what repaints a terminal), an RTL override and a zero-width joiner (what makes a printed
    # line read as something other than what it says). A reader deceived by the very line that exists to
    # tell them whose work is on the other side of their branch is the failure worth a section.
    Write-Host "new-branch.ps1 -- an adversarial remote tip is stripped, not printed raw (#1439)" -ForegroundColor Cyan
    $fixEvil  = New-Fixture -Label 'y5'
    $bareEvil = New-BareOrigin -Dir $fixEvil -Label 'y5'
    Publish-FixtureTrunk -Dir $fixEvil
    $rY5a = Invoke-NewBranch -Dir $fixEvil -Name 'feat/evil-tip-1439-v1' -Title 'Evil tip'
    Assert-ExitCode 0 $rY5a 'adversarial tip: the cut exits 0'

    $esc = [char]27
    $evilSubject = "park:${esc}[31m${esc}[2K harmless-looking$([char]0x202E)$([char]0x200D) subject"
    Add-OriginBranchCommits -Bare $bareEvil -Label 'y5' -Branch 'feat/evil-tip-1439-v1' -MarkerFile 'evil.txt' -Author 'Other Session' -Subject $evilSubject

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixEvil checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    $rY5b = Invoke-NewBranch -Dir $fixEvil -Name 'feat/evil-tip-1439-v1' -Title 'Evil tip'
    # THE FIXTURE REALLY CARRIES THE PAYLOAD, asserted rather than assumed -- the same discipline (y4)
    # applies to its parked branch. Without this the three "no ESC in the output" asserts below pass
    # just as happily against a helper that quietly dropped the characters on the way in, which is the
    # shape of a security test that proves nothing.
    # READ BACK WITH AN EXPLICIT UTF-8 DECODE, NOT WITH `& git` (issue #1446, September 5, 2026). This
    # block asks "does the fixture really carry the payload", and until that date it asked through the
    # same mangling it was meant to be independent of: `& git` is decoded with [Console]::OutputEncoding,
    # so on a cp850 console the RTL override came back as the three printable characters e2/80/ae map to
    # there and this assert read FALSE against a commit that was perfectly intact. A premise assert that
    # can be defeated by the console it runs on cannot vouch for anything below it -- and the three
    # characters it is checking for are precisely the ones no non-UTF-8 code page can represent.
    $evilOnRemote = ((Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $bareEvil, 'log', '-1', '--format=%s', 'refs/heads/feat/evil-tip-1439-v1') -DiscardStderr -Utf8).Output -join "`n")
    Assert-True ($evilOnRemote.Contains($esc)) 'adversarial tip: the commit on origin really carries the ESC -- so the asserts below are not vacuous'
    Assert-True ($evilOnRemote.Contains([char]0x202E)) 'adversarial tip: and the RTL override'
    Assert-True ($evilOnRemote.Contains([char]0x200D)) 'adversarial tip: and the zero-width joiner -- all three asserted, because all three are stripped below'

    # ASSERTED ON THE FLATTENED CAPTURE AND THAT IS SAFE HERE, unlike for a whitespace-shaped payload:
    # Get-FlatOutput strips '\s', and none of these three characters is whitespace to .NET -- ESC, the
    # RTL override and the ZWJ all survive it. So a raw one would be visible to these asserts.
    Assert-True (-not $rY5b.Out.Contains($esc)) 'adversarial tip: no ESC reaches the output -- the terminal cannot be repainted from a commit subject'
    Assert-True (-not $rY5b.Out.Contains([char]0x202E)) 'adversarial tip: nor an RTL override, which would reverse how the line reads'
    Assert-True (-not $rY5b.Out.Contains([char]0x200D)) 'adversarial tip: nor a zero-width joiner'
    # AND THE STRIPPING IS NOT SILENCE. The point of the line is that the reader recognises the commit,
    # so the words have to survive what the escapes did not.
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase 'harmless-looking') 'adversarial tip: the readable words survive -- stripping the attack is not dropping the subject'
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase 'Other Session') 'adversarial tip: and the author still identifies who pushed it'
    Assert-True (Test-Phrase -Text $rY5b.Out -Phrase "is 1 commit(s) behind origin/feat/evil-tip-1439-v1") 'adversarial tip: the warning still fires -- the strip is not a refusal to report'

    # --- (y6) THE CAP: an unbounded remote tip subject does not reach the output whole (#1439) -------
    # A subject has no length limit, and an unbounded one pushes the half of the sentence that says what
    # to DO off the screen -- the same failure the repeat exists to prevent, arriving from the other
    # direction. The cap is asserted in both directions: enough survives to recognise the commit, and
    # not so much that the remedy is pushed off the end.
    Write-Host "new-branch.ps1 -- an unbounded remote tip subject is capped (#1439)" -ForegroundColor Cyan
    $fixLong  = New-Fixture -Label 'y6'
    $bareLong = New-BareOrigin -Dir $fixLong -Label 'y6'
    Publish-FixtureTrunk -Dir $fixLong
    $rY6a = Invoke-NewBranch -Dir $fixLong -Name 'feat/long-tip-1439-v1' -Title 'Long tip'
    Assert-ExitCode 0 $rY6a 'capped tip: the cut exits 0'
    $longSubject = 'park: ' + ('x' * 400)
    Add-OriginBranchCommits -Bare $bareLong -Label 'y6' -Branch 'feat/long-tip-1439-v1' -MarkerFile 'long.txt' -Author 'Other Session' -Subject $longSubject
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixLong checkout -q main
    } finally { $ErrorActionPreference = $prevEap }
    $rY6b = Invoke-NewBranch -Dir $fixLong -Name 'feat/long-tip-1439-v1' -Title 'Long tip'
    # THE PREMISE, ASSERTED RATHER THAN ASSUMED -- the same discipline (y5) applies to its payload, one
    # layer out (issue #1915). All three cap asserts read a sentence that only exists if the divergence was
    # FOUND, and finding it needs this run's own fetch to have refreshed refs/remotes/origin/<branch>. When
    # that does not happen the note is '', and the three come out as PASS/FAIL/FAIL -- a signature that
    # reads as "the cap is broken" and sent #1915's reporter to the fixture helpers. Named here, the same
    # failure says which half went wrong in its own words.
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase 'is 1 commit(s) behind origin/feat/long-tip-1439-v1') 'capped tip: the divergence was found at all -- the premise the three cap asserts below read'
    Assert-True (-not (Test-Phrase -Text $rY6b.Out -Phrase ('x' * 200))) 'capped tip: the 400-character subject does not reach the output whole'
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase ('x' * 80)) 'capped tip: but enough of it does to recognise the commit'
    # THE HALF THAT MATTERS IS STILL THERE, which is the whole reason for the cap.
    Assert-True (Test-Phrase -Text $rY6b.Out -Phrase 'git pull --ff-only') 'capped tip: and the remedy is not pushed off the end by it'

    # --- (y7) A COUNT TAKEN AGAINST A REF NOBODY REFRESHED IS SAID, NOT PRINTED AS SILENCE (#1915) ----
    # THE HOLE THE SIX CASES ABOVE ALL SIT ON. Every one of them asserts what the divergence check SAYS
    # once it has looked; none asks what it says when it could not look. Get-RemoteAheadNote returns ''
    # for both "origin has nothing you do not have" and "the ref I counted against is whatever the last
    # fetch left", and until #1915 this caller printed the second as the first -- so the #1439 guard
    # reported the shape of a clean branch on the one run where it was blind.
    #
    # THE STATE IS STAGED WITH A FAILED FETCH RECORD RATHER THAN A BROKEN REMOTE, because that is the
    # shape the gate actually produced: since #1860 new-branch opts into -RecentFailureSeconds, so ONE
    # transient failure suppresses the retry for the next 90 seconds -- and a claim, a cut and a resume
    # all live inside that interval. A record is also the only way to reach this deterministically; a
    # remote made unreachable would exercise git's own failure rather than the seam's.
    #
    # -KeepFetchStamp IS LOAD-BEARING AND IS THIS CASE'S ALONE: Invoke-NewBranch clears the record before
    # every other run in this file, which is the repair for the flake #1915 was filed about.
    Write-Host "new-branch.ps1 -- a run whose fetch did not refresh says so instead of nothing (#1915)" -ForegroundColor Cyan
    $fixStale  = New-Fixture -Label 'y7'
    $bareStale = New-BareOrigin -Dir $fixStale -Label 'y7'
    Publish-FixtureTrunk -Dir $fixStale
    $rY7a = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed'
    Assert-Equal 0 $rY7a.Code 'unrefreshed: the cut exits 0'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixStale checkout -q main
    } finally { $ErrorActionPreference = $prevEap }

    # The record the lib itself would have written, at the path the lib itself names -- so a move of
    # either cannot leave this case staging a file nothing reads.
    $stampPath = Get-RemoteFetchStampPath -RepoRoot $fixStale
    Assert-True ([bool]$stampPath) 'unrefreshed: the fetch-attempt record has a path in this fixture -- the premise of the staging below'
    $stampBody = ([ordered]@{
        remote     = 'origin'
        scope      = 'all'
        ok         = $false
        note       = 'git fetch exited 128'
        detail     = @('fatal: staged by new-branch.tests.ps1')
        recordedAt = [datetime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 4)
    [System.IO.File]::WriteAllText($stampPath, $stampBody, (New-Object System.Text.UTF8Encoding $false))

    # NOTHING HAS MOVED ON ORIGIN, deliberately: this is the case where there genuinely is no divergence,
    # so '' out of Get-RemoteAheadNote is the honest return and the whole question is what the CALLER does
    # with it. Staging a divergence too would prove the same sentence for the wrong reason.
    $rY7b = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed' -KeepFetchStamp
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'fetch did not refresh it') 'unrefreshed: the run says the ref it compared against was not refreshed'
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'is what this run could not see, not what is on the branch') 'unrefreshed: and says what the silence means, rather than leaving the reader to infer a clean branch'
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'git fetch origin feat/unrefreshed-1915-v1') 'unrefreshed: and hands over the command that settles it, naming the branch'
    # THE TRUNK'S OWN NOTE IS NOT THIS ONE, and the case asserts both so neither can be mistaken for the
    # other: 'Base: ...' speaks about origin/<trunk>, and a reader given only that has no way to know the
    # branch-divergence probe went blind on the same reading.
    Assert-True (Test-Phrase -Text $rY7b.Out -Phrase 'not retried') 'unrefreshed: the skipped fetch is reported too -- the trunk-level note, which is a different sentence'

    # AND IT IS SILENT WHEN THE FETCH DID REFRESH, which is the overwhelming majority of runs. Same
    # fixture, same absence of divergence: only the record is gone, so this run fetches for itself.
    $rY7c = Invoke-NewBranch -Dir $fixStale -Name 'feat/unrefreshed-1915-v1' -Title 'Unrefreshed'
    Assert-True (-not (Test-Phrase -Text $rY7c.Out -Phrase 'fetch did not refresh it')) 'unrefreshed: a run that fetched successfully says nothing about it -- the check cannot become noise'
    Assert-True (-not (Test-Phrase -Text $rY7c.Out -Phrase 'not retried')) 'unrefreshed: and the record is gone, so nothing is skipped either'

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
                [string]$PrListJson = '',
                [switch]$FailIssueList,
                [switch]$FailPrList
            )
            Remove-Item -Path $xCallLog -Force -ErrorAction SilentlyContinue
            $env:GH_CALL_LOG = $xCallLog
            $env:GH_OPEN_ISSUES = $OpenIssues
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
        $rX4 = Invoke-NewBranchX -Dir $fixX4 -Name 'fix/1409-something' -Resolves '1409' -OpenIssues '9999'
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
        $rX6 = Invoke-NewBranchX -Dir $fixX6 -Name 'fix/1409-and-1410' -Resolves '1409,1410' -OpenIssues '1410'
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
        $rX8 = Invoke-NewBranchX -Dir $fixX8 -Name 'fix/1409-blind-pr' -Resolves '1409' -OpenIssues '9999' -FailPrList
        Assert-ExitCode 0 $rX8 'gh pr list unreadable: exits 0'
        Assert-True (Test-Phrase -Text $rX8.Out -Phrase 'could not ask gh whether another PR already resolves') 'gh pr list unreadable: warns about the blind spot'
        Assert-True (Test-Phrase -Text $rX8.Out -Phrase 'issue #1409 is already CLOSED') 'gh pr list unreadable: and still reports what issue state alone could determine'
    } finally {
        $env:PATH = $prevPathX
        'GH_CALL_LOG', 'GH_OPEN_ISSUES', 'GH_PR_LIST_JSON', 'GH_FAIL_ISSUE_LIST', 'GH_FAIL_PR_LIST' | ForEach-Object {
            Remove-Item "Env:\$_" -ErrorAction SilentlyContinue
        }
        Remove-Item -Path $xBin -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $xCallLog -Force -ErrorAction SilentlyContinue
    }

    # --- (y) NO USABLE GIT AUTHOR IDENTITY: REFUSED BEFORE ANYTHING IS CREATED (inbound #1867) --------
    # THE FAILURE THIS REPLACES. On a machine with nothing in system, global or local config, and a
    # hostname with no domain part for git's auto-guess to work from, every commit dies with exit 128 --
    # and the first one to do so was this script's own park, several hundred lines after the checkout.
    # The run left a local branch with an uncommitted document standing on it, for a condition that was
    # knowable before a single ref existed. Reported from a consumer that measured the machine state.
    #
    # THE SAME TWO-HALF SHAPE AS (s) ABOVE, and for the same reason: naming the repair is what the
    # message has to do, and NOTHING HAPPENED is what makes refusing cheaper than failing late. A
    # refusal that left half a branch behind would be strictly worse than the exit 128 it replaces.
    Write-Host "new-branch.ps1 -- a checkout that cannot commit is REFUSED (inbound #1867)" -ForegroundColor Cyan
    # THE FIXTURE'S IDENTITY IS REMOVED IN ALL THREE PLACES GIT READS, not just the local config that
    # New-Fixture wrote: git falls back to global, then system -- and on a developer machine the global
    # config alone would keep the probe green and assert nothing. GIT_AUTHOR_* / GIT_COMMITTER_* are
    # cleared too, because the environment outranks all of it and a runner that exports them (some CI
    # images do) would otherwise make this case silently vacuous.
    $fixIdent = New-Fixture -Label 'y'
    Invoke-FixtureGitIn $fixIdent config --unset user.name
    Invoke-FixtureGitIn $fixIdent config --unset user.email
    $identEnvNames = @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL')
    $identEnvPrev = @{}
    foreach ($n in $identEnvNames) { $identEnvPrev[$n] = (Get-Item "Env:\$n" -ErrorAction SilentlyContinue).Value }
    # AN EMPTY GLOBAL CONFIG IS NOT ENOUGH, AND THAT IS THE WHOLE POINT OF THIS FIXTURE (#1888).
    # Emptying every config scope leaves git with nothing to read AND STILL NAMING AN AUTHOR: Git for
    # Windows falls back to the OS account, and that fallback produces a real display name and a real
    # address rather than the username@hostname guess git then refuses -- so it exits 0 and every
    # assert below measures a checkout that can commit perfectly well. Measured on DAVE-KOK-BWJ,
    # git 2.55.0.windows.5: with local unset, GIT_CONFIG_NOSYSTEM=1 and GIT_CONFIG_GLOBAL pointed at
    # nothing, `git config --show-origin --get user.email` exits 1 (no config source has it) while
    # `git var GIT_AUTHOR_IDENT` exits 0 with a usable ident. `EMAIL` and the GIT_AUTHOR_*/GIT_COMMITTER_*
    # vars are empty, and substituting a genuinely empty FILE for the unreadable path changes nothing:
    # this is not a leak to be plugged but a fallback to be switched off.
    #
    # `user.useConfigOnly = true` is that switch, and it needs a real file to live in -- which is why
    # GIT_CONFIG_GLOBAL points at one written here instead of at NUL. The file is a SIBLING of the
    # fixture rather than a file inside it: this repo is the one new-branch.ps1 reads `git status` on,
    # and an untracked config file in its root would put a second subject into every assert.
    $identGlobalCfg = "$fixIdent.gitconfig"
    [System.IO.File]::WriteAllText($identGlobalCfg, "[user]`n`tuseConfigOnly = true`n", (New-Object System.Text.UTF8Encoding $false))
    $script:fixtures += $identGlobalCfg
    try {
        foreach ($n in $identEnvNames) { Remove-Item "Env:\$n" -ErrorAction SilentlyContinue }
        # GIT_CONFIG_GLOBAL / GIT_CONFIG_NOSYSTEM remain git's own documented way to suppress the outer
        # two config scopes, and they are inherited by the child process Invoke-NewBranch starts; the
        # file they now point at carries the one key that stops git guessing past them.
        $env:GIT_CONFIG_GLOBAL = $identGlobalCfg
        $env:GIT_CONFIG_NOSYSTEM = '1'

        # FIXTURE SANITY FIRST, because every assert below is vacuous if the identity is still readable
        # -- and it would be vacuous SILENTLY, passing for the wrong reason on a machine where the
        # suppression did not take. Asserted against git's own probe, which is the one this script reads.
        $identProbe = Invoke-CapturedChild -WorkDir $fixIdent -ChildArgs @('-NoProfile', '-Command', "git -C '$fixIdent' var GIT_AUTHOR_IDENT; exit `$LASTEXITCODE")
        Assert-ExitCode 128 $identProbe 'no identity: fixture sanity -- git itself refuses to name an author here'

        $rY = Invoke-NewBranch -Dir $fixIdent -Name 'fix/1867-cannot-commit-v1' -Title 'Cannot commit'
        Assert-ExitCode 1 $rY 'no identity: new-branch exits 1 rather than dying at exit 128 in the park'
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'no usable git author identity') 'no identity: and says which state it is in, in words'
        # AND IT NAMES THE EXIT CODE ITS OWN GUARD GATED ON (issue #1932). The refusal composes this number
        # from git-identity-lib.ps1's $GitAuthorIdentityUnknownExitCode rather than carrying a third
        # hand-typed copy of it, and falls back to wording that claims NO number where a mirror predating
        # #1920 supplies no constant. That fallback is what this assert is really guarding: the sentence
        # reads perfectly well without the code, so a composition that silently lost it -- a renamed
        # constant, a scope the lookup no longer reaches -- would degrade the refusal's only measured
        # detail with nothing on screen looking wrong. The probe two asserts up is the other half: it
        # pins that 128 is still what GIT reports, which is the fact the constant encodes.
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'exits 128') 'no identity: and states the exit code its own guard gated on, read from the lib constant'
        # THE REPAIR, both keys. Setting only user.name leaves git refusing exactly as hard, which is the
        # whole reason user.name was the wrong thing to read for this question in the first place.
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'user.name') 'no identity: names user.name as part of the repair'
        Assert-True (Test-Phrase -Text $rY.Out -Phrase 'user.email') 'no identity: and user.email, which is the half a user.name-only check misses'

        # AND NOTHING WAS TOUCHED -- the same three reads as (s), for the same reason.
        $branchesY = ((& git -C $fixIdent branch --list 'fix/1867-cannot-commit-v1') -join '').Trim()
        Assert-True (-not [bool]$branchesY) 'no identity: and NO branch was created -- the refusal is before the checkout'
        $docY = Join-Path $fixIdent (Join-Path 'dkj-policy' 'fix-1867-cannot-commit-v1.md')
        Assert-True (-not (Test-Path -LiteralPath $docY)) 'no identity: and no branch document was scaffolded either'
        $headY = ((& git -C $fixIdent rev-parse --abbrev-ref HEAD) -join '').Trim()
        Assert-Equal 'main' $headY 'no identity: and HEAD is left exactly where the operator was standing'
    } finally {
        foreach ($n in $identEnvNames) {
            if ($null -eq $identEnvPrev[$n]) { Remove-Item "Env:\$n" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:\$n" -Value $identEnvPrev[$n] }
        }
    }

    # --- (y2) AND A HEALTHY CHECKOUT IS UNTOUCHED BY THE PROBE ---------------------------------------
    # The other direction, and it is what keeps the guard shippable: every fixture above already proves
    # it in passing, but none of them SAYS so, and a probe that answered 'no' too readily would refuse
    # every branch in the workflow. One explicit case, so the regression has a name.
    $fixIdentOk = New-Fixture -Label 'y2'
    $rY2 = Invoke-NewBranch -Dir $fixIdentOk -Name 'fix/1867-can-commit-v1' -Title 'Can commit' -NoPush
    Assert-ExitCode 0 $rY2 'healthy identity: new-branch runs exactly as before -- the guard costs one local git var'
    Assert-True (-not (Test-Phrase -Text $rY2.Out -Phrase 'no usable git author identity')) 'healthy identity: and says nothing about identity at all'

    # --- (z) THE REPO ROOT CANNOT BE RESOLVED -- A NAMED REFUSAL, NOT A NULL DEREFERENCE (#1913) ---
    # The script's first statement used to be `(git rev-parse --show-toplevel).Trim()`, unjudged. Where
    # git answers nothing that is `$null.Trim()`: exit 1, nothing created, and the only thing printed is
    # a PowerShell error naming a line number in a script the reader did not write.
    #
    # WHY THIS IS ASSERTED RATHER THAN LEFT TO THE OTHER CASES. It is the one failure mode that is
    # INVISIBLE to every fixture above, because every fixture above is a real repository -- so the
    # regression back to the silent form would pass this whole suite. It is also the mode #1913's own
    # difficulty was made of: a child that exits 1 while saying nothing is a red gate with no cause in
    # it. The subject is that the refusal SPEAKS, and the exit code is the smaller half.
    #
    # A PLAIN DIRECTORY, NOT A FIXTURE: New-Fixture builds a git repo, which is exactly what this case
    # must not have -- so the script is copied in WITHOUT `git init`. Only the script file itself is
    # needed, because the refusal fires before a single lib is dot-sourced. Registered for the same
    # teardown as every fixture above.
    Write-Host "new-branch.ps1 -- outside a repository, the refusal names its cause (#1913)" -ForegroundColor Cyan
    $notARepo = Join-Path ([System.IO.Path]::GetTempPath()) ("new-branch-test-$PID-z-notarepo-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path (Join-Path $notARepo 'scripts\task') -Force | Out-Null
    $script:fixtures += $notARepo
    Copy-Item -LiteralPath $NewBranchSrc -Destination (Join-Path $notARepo 'scripts\task\new-branch.ps1') -Force
    $rZ = Invoke-NewBranch -Dir $notARepo -Name 'docs/outside-a-repo-v1' -Title 'Outside a repo' -NoPush
    Assert-ExitCode 1 $rZ 'no repo root: exits 1 rather than dying on a null dereference'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'could not work out which repository') 'no repo root: says which question it could not answer'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'rev-parse --show-toplevel') 'no repo root: names the command whose answer it needed'
    Assert-True (Test-Phrase -Text $rZ.Out -Phrase 'Nothing was created') 'no repo root: and states that nothing was created, which is what a reader needs before re-running'
    Assert-True (-not (Test-Phrase -Text $rZ.Out -Phrase 'null-valued expression')) 'no repo root: and NOT the null-dereference this replaced'
} finally {
    foreach ($f in $script:fixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

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
