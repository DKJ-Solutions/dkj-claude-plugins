<#
.SYNOPSIS
    Tests for scripts/release/verify-pushed-merges.ps1 (the resolves gate's second half, resolved off
    a push to the trunk instead of off the shipping session -- issue #1511).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/verify-pushed-merges.tests.ps1

    WHY THIS SUITE EXISTS, beyond the sibling's reason. verify-pushed-merges.ps1 decides WHICH pull
    requests a state-mutating script is pointed at, and every one of its failure modes is silent by
    construction: a range read as one commit verifies the last PR of a batch and skips the rest; a
    missing merged_at filter verifies a PR that never landed; a missing base filter verifies one that
    landed somewhere else. None of those is visible in a green CI run -- the job says it checked, and
    it did check, just not the thing.

    Two of them were live defects on this script's first smoke test and are pinned below by name: the
    `,@(...)` return that collapsed a six-commit range to `examining 1 commit`, and the double-quoted
    jq filter that reached gh as three arguments. Both exited 0 in a way that read as working.

    DRIVEN END TO END against a FAKE gh on PATH, exactly like verify-resolved-issues.tests.ps1, and
    deliberately WITHOUT stubbing the child: the real verify-resolved-issues.ps1 runs underneath and
    talks to the same fake, so the call log proves the whole chain -- which PR was resolved, whose body
    was read, which issue was closed -- rather than only this script's half of it.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

# THE REPO ROOT, judged and ANCHORED (#1917). -From pins the git call to this file's own directory
# instead of the inherited working directory: this suite tree stands up throwaway git repos and
# changes into them, so a cwd-relative answer can name the wrong repo. Resolve-RepoRootOrFail
# refuses with git's exit code and stderr where the old (git rev-parse ...).Trim() died on
# $null.Trim() -- which here meant a suite testing the wrong file, or none.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'verify-pushed-merges.tests.ps1'
$ScriptPath = Join-Path $RepoRoot 'scripts\release\verify-pushed-merges.ps1'
# For Invoke-NativeCapture -- see the capture note in Invoke-Pushed below. Dot-sourced here rather
# than re-implemented, because a third private copy of "start a child and read its streams from
# files" is exactly the duplication that let this suite inherit its sibling's broken capture.
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

$script:pass = 0
$script:fail = 0

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

function Assert-Says {
    <#
        Asserts that the child's output contains a phrase, with ALL whitespace removed from both
        sides first -- and this is stronger than the whitespace NORMALIZATION the sibling suite does,
        for a reason that suite's own comment gets wrong.

        Normalizing runs of whitespace to one space survives a wrap between words. It does not survive
        a wrap INSIDE a word, and PowerShell's error formatter breaks at the column whatever is there:
        measured on this suite, `no merged pull request was resolved` came back as `... was resol` +
        `ved from this push`, which normalizes to `resol ved` and matches nothing. The wrap column is
        the child's console buffer width, so the same assert passes on one invocation and fails on the
        next -- this suite passed three runs and then failed three in a row with no edit in between.

        Removing whitespace entirely is immune to both -- AND NOT TO A THIRD THING, which is what
        #1530 measured and what this paragraph used to deny. A wrap only ever REMOVES separation, so
        stripping separation always repairs it; what stripping cannot repair is other text INSERTED
        into the middle of the phrase. A parent that captures a native child with '2>&1' renders the
        child's FIRST stderr line as a NativeCommandError record and stamps 'At <path>:<line>', the
        source echo, CategoryInfo and FullyQualifiedErrorId between it and the remainder -- so a
        phrase straddling the child's first wrap arrives with five lines of other text through it.
        That is a defect of the CAPTURE and not of this comparison, which is why the answer sits in
        Invoke-Pushed below rather than here.

        `.Contains` is a literal search, so a phrase carrying regex metacharacters needs no escaping
        either.
    #>
    param([string]$Output, [string]$Phrase, [string]$Name)
    Assert-True (($Output -replace '\s', '').Contains(($Phrase -replace '\s', ''))) $Name
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-pushed-bin-$PID-$([guid]::NewGuid().ToString('n'))")
$callLog = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-pushed-calls-$PID-$([guid]::NewGuid().ToString('n')).log")
$prevPath = $env:PATH
$prevEap = $ErrorActionPreference

# Shorthand shas. Forty hex characters each, because Get-ShortSha and the all-zeros test both read
# real lengths -- a stub like 'aaa' would pass here and say nothing about a real push.
$ShaHead = 'a' * 40   # the push's head: the queue's merge commit for PR 501
$ShaMid  = 'b' * 40   # a second merge commit in the same push: PR 502 (the BATCH case)
$ShaTail = 'c' * 40   # PR 501's own branch head, reaching the trunk in the same push (the DEDUPE case)
$ShaBase = 'd' * 40   # where the trunk stood before the push
$ShaNone = 'e' * 40   # a commit belonging to no pull request at all (a fold commit)
$ShaZero = '0' * 40

try {
    $ErrorActionPreference = 'Continue'  # native calls below -- the #107 stderr pitfall guard

    # --- Fake gh -----------------------------------------------------------------------------------
    # Records every invocation (one line per call) and answers four things:
    #   api .../compare/A...B  -> the shas in GH_COMPARE (comma-separated, newest first), or fails
    #                             when GH_FAIL_COMPARE is set
    #   api .../commits/S/pulls-> the rows in GH_PULLS_<first char of S>, one 'number|merged_at|base'
    #                             per entry, rendered tab-separated; fails when that sha is listed in
    #                             GH_FAIL_PULLS
    #   pr view                -> GH_PR_BODY_<pr number>, so each resolved PR has its own body
    #   issue view/comment/close -> as in verify-resolved-issues.tests.ps1
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    $ghImpl = @'
if ($env:GH_CALL_LOG) { Add-Content -Path $env:GH_CALL_LOG -Value ($args -join ' ') }

if ($args -contains 'api') {
    $path = $args[[array]::IndexOf($args, 'api') + 1]
    if ($path -match '/compare/') {
        if ($env:GH_FAIL_COMPARE) { [Console]::Error.WriteLine('fake gh: compare failed'); exit 1 }
        if ($env:GH_COMPARE) { ($env:GH_COMPARE -split ',') | ForEach-Object { Write-Output $_ } }
        exit 0
    }
    if ($path -match '/commits/([0-9a-f]+)/pulls') {
        $sha = $Matches[1]
        if ($env:GH_FAIL_PULLS -and (($env:GH_FAIL_PULLS -split ',') -contains $sha)) {
            [Console]::Error.WriteLine('fake gh: pulls lookup failed'); exit 1
        }
        $rows = [Environment]::GetEnvironmentVariable("GH_PULLS_$($sha.Substring(0,1))")
        if ($rows) {
            ($rows -split ';') | ForEach-Object {
                $f = $_ -split '\|'
                Write-Output ($f -join "`t")
            }
        }
        exit 0
    }
    exit 1
}

if ($args -contains 'pr' -and $args -contains 'view') {
    $num = $args[[array]::IndexOf($args, 'view') + 1]
    Write-Output ([Environment]::GetEnvironmentVariable("GH_PR_BODY_$num"))
    exit 0
}
if ($args -contains 'issue' -and $args -contains 'view') {
    $num = $args[[array]::IndexOf($args, 'view') + 1]
    $closed = @()
    if ($env:GH_CLOSED_ISSUES) { $closed = $env:GH_CLOSED_ISSUES -split ',' }
    if ($closed -contains $num) { Write-Output 'CLOSED' } else { Write-Output 'OPEN' }
    exit 0
}
if ($args -contains 'issue' -and $args -contains 'comment') { exit 0 }
if ($args -contains 'issue' -and $args -contains 'close') { exit 0 }
exit 1
'@
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh-impl.ps1'), $ghImpl, $Utf8NoBom)
    $ghCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh.cmd'), $ghCmd, $Utf8NoBom)
    $env:PATH = "$fakeBin;$env:PATH"
    $env:GH_CALL_LOG = $callLog

    function Invoke-Pushed {
        <# Runs the script under test with a clean call log and returns its output + the log. #>
        param(
            [string]$Before = '',
            [string]$Sha = '',
            [string]$Compare = '',
            [hashtable]$Pulls = @{},
            [hashtable]$Bodies = @{},
            [string]$ClosedIssues = '',
            [string]$FailPulls = '',
            [switch]$FailCompare,
            [switch]$ReportOnly,
            [int]$MaxCommits = 0
        )
        Remove-Item -Path $callLog -Force -ErrorAction SilentlyContinue
        Get-ChildItem Env: | Where-Object { $_.Name -like 'GH_PULLS_*' -or $_.Name -like 'GH_PR_BODY_*' } |
            ForEach-Object { Remove-Item "Env:\$($_.Name)" -ErrorAction SilentlyContinue }
        $env:GH_COMPARE = $Compare
        $env:GH_CLOSED_ISSUES = $ClosedIssues
        $env:GH_FAIL_PULLS = $FailPulls
        if ($FailCompare) { $env:GH_FAIL_COMPARE = '1' } else { Remove-Item Env:\GH_FAIL_COMPARE -ErrorAction SilentlyContinue }
        foreach ($key in $Pulls.Keys) { [Environment]::SetEnvironmentVariable("GH_PULLS_$key", $Pulls[$key]) }
        foreach ($key in $Bodies.Keys) { [Environment]::SetEnvironmentVariable("GH_PR_BODY_$key", $Bodies[$key]) }

        $runArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-Repo', 'fake/repo', '-Trunk', 'main', '-Sha', $Sha)
        if ($Before) { $runArgs += @('-Before', $Before) }
        if ($ReportOnly) { $runArgs += '-ReportOnly' }
        if ($MaxCommits -gt 0) { $runArgs += @('-MaxCommits', "$MaxCommits") }
        # CAPTURED VIA REDIRECT FILES, NOT '2>&1'. Invoke-NativeCapture -Utf8 starts the child with
        # Start-Process and redirected streams, so the parent's error formatter never sees the child's
        # stderr and cannot stamp anything into it. With '2>&1' it did, and the damage landed INSIDE an
        # asserted phrase: measured for #1530 at width 120, with the script under test at a path of 29
        # to 51 characters, the parent cut the rendered record inside `may have gone unverified` and
        # put 'At line:', the source echo, CategoryInfo and FullyQualifiedErrorId into the gap. No
        # amount of whitespace stripping rejoins a phrase across five lines of other text.
        #
        # WHICH IS WHY IT WAS GREEN ON CI AND RED ON A DEVELOPER'S MACHINE, on a byte-identical tree:
        # the cut column is decided by the path length and the console width together, and both are
        # properties of the machine rather than of the code. Outside that window every assert here
        # passes, so a green run was never evidence that the capture worked.
        #
        # Same finding, same fix and same reasoning as Invoke-CapturedScript in shared-scripts.tests.ps1
        # (measured August 14, 2026). This suite was written after that one and still copied the old
        # capture from its sibling -- which is the argument for calling the shared lib here instead of
        # keeping a third local variant.
        $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments $runArgs -Utf8
        $out = ($run.Output -join [Environment]::NewLine)
        $code = $run.ExitCode
        $log = if (Test-Path $callLog) { Get-Content -Path $callLog } else { @() }
        # Whitespace-normalized once for every scenario, for the sibling suite's reason: the child
        # renders at ITS own console width, so a phrase an assert matches can be split by a wrap whose
        # position depends on the machine's path length. Normalizing is NOT sufficient on its own --
        # see Assert-Says, which every prose assert here goes through. THAT IS STILL ONLY HALF OF WHAT
        # MAKES THIS FILE WIDTH-PROOF, and the missing half is the capture above: stripping repairs a
        # wrap, and nothing at the comparison can repair decoration inserted into the phrase (#1530).
        # This field stays normalized so a FAILED assert prints something a human can read.
        return [pscustomobject]@{ Output = ($out -replace '\s+', ' '); ExitCode = $code; Log = @($log) }
    }

    # --- The load-bearing scenario -----------------------------------------------------------------
    # A merge queue landing a BATCH: two PRs, one push, plus one PR's own branch head arriving in the
    # same range. Reading only the head commit would find PR 501 and miss 502; failing to dedupe would
    # verify 501 twice. This one scenario is what the `,@(...)` bug made invisible -- it reported
    # `examining 1 commit` and verified whichever PR the head belonged to.
    Write-Host "A push carrying a batch: every PR in the range is verified, each exactly once" -ForegroundColor Cyan
    $r = Invoke-Pushed -Before $ShaBase -Sha $ShaHead -Compare "$ShaHead,$ShaMid,$ShaTail" -Pulls @{
        'a' = "501|2026-09-06T11:59:47Z|main"
        'b' = "502|2026-09-06T11:58:00Z|main"
        'c' = "501|2026-09-06T11:59:47Z|main"     # the same PR again, via its branch head
    } -Bodies @{ '501' = 'Closes #601'; '502' = 'Closes #602' } -ClosedIssues '601,602'
    Assert-Equal 0 $r.ExitCode 'exits 0'
    Assert-Says $r.Output 'examining 3 commits' 'read the whole pushed RANGE, not just its head'
    Assert-Says $r.Output 'PR #501, PR #502' 'resolved both PRs of the batch, in order'
    Assert-True (($r.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'verified PR #501 exactly once (deduped across two commits)'
    Assert-True (($r.Log | Where-Object { $_ -match 'pr view 502' }).Count -eq 1) 'verified PR #502'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue view 601' }).Count -eq 1) 'reached the child script and checked #601'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue view 602' }).Count -eq 1) 'reached the child script and checked #602'

    # --- The repair, which is the whole reason issues: write is granted (issue #1511) --------------
    Write-Host "A declared issue the merge left open is CLOSED, not merely reported" -ForegroundColor Cyan
    $r2 = Invoke-Pushed -Sha $ShaHead -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } `
        -Bodies @{ '501' = "Closes #601`nCloses #602" } -ClosedIssues '601'
    Assert-Equal 0 $r2.ExitCode 'exits 0'
    Assert-True (($r2.Log | Where-Object { $_ -match 'issue close 602' }).Count -eq 1) 'closed the still-open #602'
    Assert-True (($r2.Log | Where-Object { $_ -match 'issue comment 602' }).Count -eq 1) 'commented on it first'
    Assert-True (($r2.Log | Where-Object { $_ -match 'issue close 601' }).Count -eq 0) 'did NOT re-close the one the merge already closed'

    Write-Host "-ReportOnly reaches the child and closes nothing" -ForegroundColor Cyan
    $r3 = Invoke-Pushed -Sha $ShaHead -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } `
        -Bodies @{ '501' = 'Closes #602' } -ReportOnly
    Assert-Equal 0 $r3.ExitCode 'exits 0'
    Assert-True (($r3.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closed nothing'
    Assert-Says $r3.Output 'report-only' 'says it is report-only'

    # --- What must NOT be verified ----------------------------------------------------------------
    Write-Host "A pull request that never merged is not verified" -ForegroundColor Cyan
    $r4 = Invoke-Pushed -Sha $ShaHead -Pulls @{ 'a' = "501||main" } -Bodies @{ '501' = 'Closes #601' }
    Assert-Equal 0 $r4.ExitCode 'exits 0'
    Assert-True (($r4.Log | Where-Object { $_ -match 'pr view' }).Count -eq 0) 'the PR body was never even read'
    Assert-Says $r4.Output 'no pull request merged' 'says there was nothing to verify'

    Write-Host "A pull request merged into some OTHER base is not verified" -ForegroundColor Cyan
    $r5 = Invoke-Pushed -Sha $ShaHead -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|release/4.x" } `
        -Bodies @{ '501' = 'Closes #601' }
    Assert-Equal 0 $r5.ExitCode 'exits 0'
    Assert-True (($r5.Log | Where-Object { $_ -match 'pr view' }).Count -eq 0) 'the PR body was never read'
    Assert-Says $r5.Output "merged into 'main'" 'names the trunk it was looking for'

    Write-Host "A push carrying no pull request at all (a fold commit) is quiet and green" -ForegroundColor Cyan
    $r6 = Invoke-Pushed -Sha $ShaNone -Pulls @{}
    Assert-Equal 0 $r6.ExitCode 'exits 0'
    Assert-Says $r6.Output 'nothing to verify' 'says so'
    Assert-True (($r6.Log | Where-Object { $_ -match 'issue' }).Count -eq 0) 'touched no issue'

    # --- Degrading rather than failing when the range cannot be read ------------------------------
    Write-Host "No -Before at all: the head commit alone, no compare call" -ForegroundColor Cyan
    $r7 = Invoke-Pushed -Sha $ShaHead -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } -Bodies @{ '501' = 'Closes #601' } -ClosedIssues '601'
    Assert-Equal 0 $r7.ExitCode 'exits 0'
    Assert-True (($r7.Log | Where-Object { $_ -match '/compare/' }).Count -eq 0) 'did not ask for a range it was not given'
    Assert-Says $r7.Output 'examining 1 commit' 'examined the head commit'
    Assert-True (($r7.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'still verified the PR'

    Write-Host "An all-zeros -Before (a branch's first push) is treated as no range" -ForegroundColor Cyan
    $r8 = Invoke-Pushed -Before $ShaZero -Sha $ShaHead -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } -Bodies @{ '501' = 'Closes #601' } -ClosedIssues '601'
    Assert-Equal 0 $r8.ExitCode 'exits 0'
    Assert-True (($r8.Log | Where-Object { $_ -match '/compare/' }).Count -eq 0) 'no compare was attempted'
    Assert-True (($r8.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'verified the PR anyway'

    Write-Host "A compare that fails (a force-pushed base) warns and falls back to the head" -ForegroundColor Cyan
    $r9 = Invoke-Pushed -Before $ShaBase -Sha $ShaHead -FailCompare -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } `
        -Bodies @{ '501' = 'Closes #601' } -ClosedIssues '601'
    Assert-Equal 0 $r9.ExitCode 'exits 0 -- verifying one PR beats verifying none'
    Assert-Says $r9.Output 'could not be compared' 'warns that the range was lost'
    Assert-True (($r9.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'still verified the head commit PR'

    Write-Host "A compare that returns a range NOT containing the head still verifies the head" -ForegroundColor Cyan
    $r10 = Invoke-Pushed -Before $ShaBase -Sha $ShaHead -Compare "$ShaMid" -Pulls @{
        'a' = "501|2026-09-06T11:59:47Z|main"; 'b' = "502|2026-09-06T11:58:00Z|main"
    } -Bodies @{ '501' = 'Closes #601'; '502' = 'Closes #602' } -ClosedIssues '601,602'
    Assert-Equal 0 $r10.ExitCode 'exits 0'
    Assert-True (($r10.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'the pushed commit is never dropped from the range'
    Assert-True (($r10.Log | Where-Object { $_ -match 'pr view 502' }).Count -eq 1) 'and the range it did return is still read'

    # --- The check not running is NOT the same as nothing to check --------------------------------
    Write-Host "Every commit lookup failing exits 1, so a broken check cannot report green" -ForegroundColor Cyan
    $r11 = Invoke-Pushed -Sha $ShaHead -FailPulls 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    Assert-Equal 1 $r11.ExitCode 'exits 1'
    Assert-Says $r11.Output "not the same as 'nothing to verify'" 'says why it is not a quiet green'

    Write-Host "A partial lookup failure verifies what it resolved AND still exits 1" -ForegroundColor Cyan
    $r12 = Invoke-Pushed -Before $ShaBase -Sha $ShaHead -Compare "$ShaHead,$ShaMid" -FailPulls 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' `
        -Pulls @{ 'a' = "501|2026-09-06T11:59:47Z|main" } -Bodies @{ '501' = 'Closes #601' } -ClosedIssues '601'
    Assert-Equal 1 $r12.ExitCode 'exits 1'
    Assert-True (($r12.Log | Where-Object { $_ -match 'pr view 501' }).Count -eq 1) 'verified the PR it COULD resolve rather than abandoning the run'
    Assert-Says $r12.Output 'may have gone unverified' 'names what the failure might have hidden'
    # THE GUARD FOR #1530, and deliberately about the CAPTURE rather than about the phrase above. An
    # assert that only looks for its own phrase is what was already here, and it fails only at the
    # widths and path lengths where the cut happens to land inside that phrase -- which is how a broken
    # capture stayed green on CI for as long as it did. 'NativeCommandError' can appear in this text
    # ONLY if a parent rendered the child's stderr as an error record; a redirect file receives what
    # the child wrote and nothing else. Its ABSENCE is therefore proof of which capture ran, at every
    # width and every path length. This scenario is the one to hang it on: it is the only one whose
    # child both writes to stderr and exits non-zero.
    Assert-True (-not (($r12.Output -replace '\s', '').Contains('NativeCommandError'))) 'no parent error-record decoration was stamped into the capture'

    # --- A cap is a measurement too ---------------------------------------------------------------
    Write-Host "A commit cap that bites is reported by name, never applied quietly" -ForegroundColor Cyan
    $r13 = Invoke-Pushed -Before $ShaBase -Sha $ShaHead -Compare "$ShaHead,$ShaMid,$ShaTail" -MaxCommits 2 -Pulls @{
        'a' = "501|2026-09-06T11:59:47Z|main"; 'b' = "502|2026-09-06T11:58:00Z|main"; 'c' = "503|2026-09-06T11:57:00Z|main"
    } -Bodies @{ '501' = 'Closes #601'; '502' = 'Closes #602'; '503' = 'Closes #603' } -ClosedIssues '601,602,603'
    Assert-Equal 0 $r13.ExitCode 'exits 0'
    Assert-Says $r13.Output 'only the newest 2 are examined' 'names the cap and the number'
    Assert-Says $r13.Output 'is NOT verified' 'says plainly that something was left out'
    Assert-True (($r13.Log | Where-Object { $_ -match 'pr view 503' }).Count -eq 0) 'and the capped-off commit really was skipped'

    # --- The quoting regression, pinned ------------------------------------------------------------
    # The jq filters must survive the native-argument round trip. A double-quoted filter reached gh as
    # three arguments (`accepts 1 arg(s), received 3`, exit 1) and the whole check degraded to "no PR
    # found" -- a green run that verified nothing. Asserting on the RECORDED ARGUMENTS is what catches
    # a future edit reintroducing quotes, since the fake gh would happily answer either form.
    Write-Host "Neither jq filter carries a double quote (they do not survive argument passing)" -ForegroundColor Cyan
    $apiCalls = @($r.Log | Where-Object { $_ -match '^api ' })
    Assert-True ($apiCalls.Count -ge 4) 'the batch scenario really did make the api calls being inspected'
    Assert-True (($apiCalls | Where-Object { $_ -match '"' }).Count -eq 0) 'no api call was passed a filter containing a double quote'
    Assert-True (($r.Log | Where-Object { $_ -match '@tsv' }).Count -ge 3) 'the pulls lookup uses the quote-free @tsv form'
} finally {
    $ErrorActionPreference = $prevEap
    $env:PATH = $prevPath
    'GH_CALL_LOG', 'GH_COMPARE', 'GH_CLOSED_ISSUES', 'GH_FAIL_COMPARE', 'GH_FAIL_PULLS' | ForEach-Object {
        Remove-Item "Env:\$_" -ErrorAction SilentlyContinue
    }
    Get-ChildItem Env: | Where-Object { $_.Name -like 'GH_PULLS_*' -or $_.Name -like 'GH_PR_BODY_*' } |
        ForEach-Object { Remove-Item "Env:\$($_.Name)" -ErrorAction SilentlyContinue }
    Remove-Item -Path $fakeBin -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $callLog -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
