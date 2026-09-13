<#
.SYNOPSIS
    Tests for scripts/release/verify-resolved-issues.ps1 (the post-merge half of the resolves gate).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/verify-resolved-issues.tests.ps1

    Why this suite exists: this is the one part of the ship chain that MUTATES state outside the repo
    -- it posts comments and CLOSES issues. Reviewing it was not enough; the failure mode (closing an
    issue that a PR never really declared) is invisible until it has already happened on a live
    tracker. So the script is driven end to end against a FAKE gh on PATH that records every call.

    The load-bearing scenario is the backtick one: a document explaining this gate necessarily writes
    `Closes #<n>` as prose, and the changelog entry for the gate does exactly that. GitHub does not
    link a reference inside a code span, so it closes nothing there -- and neither may this script,
    or it would force-close an unrelated issue while crediting the wrong PR.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

# THE REPO ROOT, judged and ANCHORED (#1917). -From pins the git call to this file's own directory
# instead of the inherited working directory: this suite tree stands up throwaway git repos and
# changes into them, so a cwd-relative answer can name the wrong repo. Resolve-RepoRootOrFail
# refuses with git's exit code and stderr where the old (git rev-parse ...).Trim() died on
# $null.Trim() -- which here meant a suite testing the wrong file, or none.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'verify-resolved-issues.tests.ps1'
$ScriptPath = Join-Path $RepoRoot 'scripts\release\verify-resolved-issues.ps1'
# For Invoke-NativeCapture -- see the capture note in Invoke-Verify below.
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

function Test-Says {
    <# Does the child's captured output contain this phrase, whatever the console did to it?

       Strips ALL whitespace from both sides rather than normalizing runs of it. Collapsing '\s+' to
       one space survives a wrap BETWEEN words and NOT a wrap INSIDE one, and the child's formatter
       breaks at whatever column the buffer width lands on -- see the comment on Invoke-Verify.
       Comparison is literal (IndexOf, not -match), so a phrase carrying '(', ')', '.', '[' or ']'
       needs no escaping; OrdinalIgnoreCase keeps the case-insensitivity that -match had here. #>
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

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-resolved-bin-$PID-$([guid]::NewGuid().ToString('n'))")
$callLog = Join-Path ([System.IO.Path]::GetTempPath()) ("verify-resolved-calls-$PID-$([guid]::NewGuid().ToString('n')).log")
$prevPath = $env:PATH
$prevEap = $ErrorActionPreference

try {
    $ErrorActionPreference = 'Continue'  # native calls below -- the #107 stderr pitfall guard

    # --- Fake gh -----------------------------------------------------------------------------------
    # Records every invocation (one line per call) so ordering can be asserted, and answers:
    #   pr view    -> GH_PR_BODY (or fails when GH_FAIL_PR_VIEW is set)
    #   issue view -> 'CLOSED' when the number is listed in GH_CLOSED_ISSUES, else 'OPEN'
    #   issue comment / issue close -> recorded, exit 0
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    $ghImpl = @'
if ($env:GH_CALL_LOG) { Add-Content -Path $env:GH_CALL_LOG -Value ($args -join ' ') }
if ($args -contains 'pr' -and $args -contains 'view') {
    if ($env:GH_FAIL_PR_VIEW) { [Console]::Error.WriteLine('fake gh: pr view failed'); exit 1 }
    Write-Output $env:GH_PR_BODY
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

    function Invoke-Verify {
        <# Runs the script under test with a clean call log and returns its output + the log. #>
        param([string]$Body, [string]$ClosedIssues = '', [switch]$ReportOnly, [switch]$FailPrView)
        Remove-Item -Path $callLog -Force -ErrorAction SilentlyContinue
        $env:GH_PR_BODY = $Body
        $env:GH_CLOSED_ISSUES = $ClosedIssues
        if ($FailPrView) { $env:GH_FAIL_PR_VIEW = '1' } else { Remove-Item Env:\GH_FAIL_PR_VIEW -ErrorAction SilentlyContinue }
        $shipArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-Pr', '999', '-Repo', 'fake/repo')
        if ($ReportOnly) { $shipArgs += '-ReportOnly' }
        # CAPTURED VIA REDIRECT FILES, NOT '2>&1' -- see the paragraph below, and #1530 for the
        # measurement. Changed here WITHOUT a failing assert to point at, deliberately: this suite is
        # where verify-pushed-merges.tests.ps1 copied its capture from, and that copy was the defect.
        # Whether a given suite currently survives '2>&1' is decided by its own phrase offsets against
        # the machine's path length and console width -- so "it passes here today" is a fact about this
        # checkout, not a property of the file, and leaving the old capture in the file others copy
        # from is what makes the next instance.
        $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments $shipArgs -Utf8
        $out = ($run.Output -join [Environment]::NewLine)
        $code = $run.ExitCode
        $log = if (Test-Path $callLog) { Get-Content -Path $callLog } else { @() }
        # Output is whitespace-NORMALIZED here so that a FAILING assert prints one readable line. The
        # child renders Write-Host/Write-Warning at ITS OWN console buffer width, so any phrase an
        # assert matches can be split by a line wrap -- and the wrap point depends on the width and on
        # the repo's path length, which differ between a dev machine and CI. This suite learned that
        # the expensive way: a 'gh issue list' assert passed locally and failed on CI.
        #
        # NORMALIZING IS NOT THE FIX, AND THIS COMMENT USED TO CLAIM IT WAS ("no assert in this file
        # CAN be width-fragile"). Collapsing '\s+' to a single space repairs a wrap BETWEEN words. It
        # does nothing for a wrap INSIDE one, and the formatter breaks at whatever character sits at
        # the column -- measured verbatim on this repo's own path, where a child's message arrived as
        # '...so this is n' / 'ot the same as...'. Normalized, that reads 'is n ot the same as', and an
        # assert on 'not the same as' matches nothing. Which asserts straddle a break is decided by the
        # width, so a green run is not evidence that any of them are safe (issue #1512).
        #
        # THE FIX IS AT THE COMPARISON *AND* AT THE CAPTURE, and this paragraph used to name only the
        # first. Every assert reading prose out of this Output goes through Assert-Says / Test-Says
        # above, which strip ALL whitespace from both sides -- and that repairs a WRAP, because a wrap
        # only ever REMOVES separation. It cannot repair text INSERTED into the middle of a phrase,
        # which is exactly what a '2>&1' capture does: the parent renders the child's first stderr line
        # as a NativeCommandError record and stamps 'At <path>:<line>', the source echo, CategoryInfo
        # and FullyQualifiedErrorId between it and the remainder. Nothing at the comparison rejoins a
        # phrase across five lines of other text, which is why the capture above changed too (#1530).
        # Asserts on .Log are exempt and stay plain -- the fake gh writes that file with Add-Content,
        # so nothing ever wrapped it.
        return [pscustomobject]@{ Output = ($out -replace '\s+', ' '); ExitCode = $code; Log = @($log) }
    }

    Write-Host "Test-Says survives a wrap INSIDE a word; normalizing does not" -ForegroundColor Cyan
    # THE GUARD FOR #1512, and deliberately SYNTHETIC. The real wrap column is the child's console
    # buffer width, so a scenario that waits for a real wrap only fails on the machines where one
    # happens to land inside the asserted phrase -- which is exactly how the false claim this suite
    # used to make stayed green long enough to be believed. This asserts the PROPERTY, so it holds at
    # every width and every path length. Both directions, or a helper that returned $true always
    # would pass the half that matters.
    $wrapped = "issue check: PR #999 declared no i" + [Environment]::NewLine + "ssue to close."
    Assert-True (-not (($wrapped -replace '\s+', ' ') -match 'declared no issue')) 'normalizing does NOT repair a mid-word wrap -- the immunity this file used to claim'
    Assert-True (Test-Says $wrapped 'declared no issue') 'Test-Says does repair it'
    Assert-True (Test-Says ($wrapped -replace "`r?`n", ' ') 'declared no issue') 'and it still matches when the wrap fell on a space instead'
    Assert-True (Test-Says 'could not read the body of PR #999 (exit 1) -- skipped.' '(exit 1)') 'the comparison is literal, so ( ) . [ ] need no escaping'
    Assert-True (-not (Test-Says 'the body was read fine' 'could not read the body')) 'and it still says no when the phrase is genuinely absent'

    Write-Host "A declared issue that GitHub left open is closed, comment first" -ForegroundColor Cyan
    # #331 already closed by the merge, #332 still open -> only #332 is acted on.
    $r = Invoke-Verify -Body "Fixes the thing.`n`nCloses #331`nCloses #332" -ClosedIssues '331'
    Assert-Equal 0 $r.ExitCode 'exits 0'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue view 331' }).Count -eq 1) 'checked the state of #331'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue view 332' }).Count -eq 1) 'checked the state of #332'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue close 331' }).Count -eq 0) 'did NOT re-close the already-closed #331'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue close 332' }).Count -eq 1) 'closed the still-open #332'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue comment 332' }).Count -eq 1) 'commented on #332'
    Assert-True (($r.Log | Where-Object { $_ -match 'issue comment 332' -and $_ -match '--body-file' }).Count -eq 1) 'the comment went via --body-file (never a multiline inline body)'
    # Ordering matters: `gh issue close --comment` drops a multiline comment, so the comment must
    # land BEFORE the close, not after.
    $cmtIdx = [array]::IndexOf(@($r.Log | ForEach-Object { $_ }), (@($r.Log | Where-Object { $_ -match 'issue comment 332' }))[0])
    $clsIdx = [array]::IndexOf(@($r.Log | ForEach-Object { $_ }), (@($r.Log | Where-Object { $_ -match 'issue close 332' }))[0])
    Assert-True ($cmtIdx -lt $clsIdx) 'commented BEFORE closing'

    Write-Host "Everything already closed by the merge -> nothing is touched" -ForegroundColor Cyan
    $r2 = Invoke-Verify -Body "Closes #331`nCloses #332" -ClosedIssues '331,332'
    Assert-Equal 0 $r2.ExitCode 'exits 0'
    Assert-True (($r2.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closed nothing'
    Assert-True (($r2.Log | Where-Object { $_ -match 'issue comment' }).Count -eq 0) 'commented nothing'
    Assert-Says $r2.Output 'already closed by the merge' 'says so'

    Write-Host "A body that declares nothing" -ForegroundColor Cyan
    $r3 = Invoke-Verify -Body 'This PR mentions #332 but closes nothing.'
    Assert-Equal 0 $r3.ExitCode 'exits 0'
    Assert-True (($r3.Log | Where-Object { $_ -match 'issue view' }).Count -eq 0) 'no issue was even inspected'
    Assert-True (($r3.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'a PLAIN MENTION closes nothing'
    Assert-Says $r3.Output 'declared no issue' 'reports that nothing was declared'

    Write-Host "A closing keyword inside BACKTICKS is not a declaration" -ForegroundColor Cyan
    # The critical case: prose explaining the gate. This body is the shape of the gate's own changelog
    # entry. GitHub does not link a reference in a code span, so nothing may be closed here -- without
    # this, the script force-closed #331 with a comment crediting an unrelated PR.
    $r4 = Invoke-Verify -Body 'GitHub does not distribute a keyword: `Closes #331, #332` closes only the first.'
    Assert-Equal 0 $r4.ExitCode 'exits 0'
    Assert-True (($r4.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closed NOTHING from a backticked example'
    Assert-True (($r4.Log | Where-Object { $_ -match 'issue view' }).Count -eq 0) 'did not even inspect it'
    # And the same body with the keyword OUTSIDE the backticks must still work, so the stripping is
    # not just silently swallowing everything.
    $r5 = Invoke-Verify -Body 'Closes #331 -- and see `#332` for context.'
    Assert-True (($r5.Log | Where-Object { $_ -match 'issue view 331' }).Count -eq 1) 'a real keyword outside backticks still counts'
    Assert-True (($r5.Log | Where-Object { $_ -match 'issue view 332' }).Count -eq 0) 'the backticked #332 does not'

    Write-Host "A fenced code block is stripped too" -ForegroundColor Cyan
    $fenced = "See the example:`n`n" + '```' + "`npowershell -Resolves 331`nCloses #331`n" + '```' + "`n`nNothing is declared here."
    $r6 = Invoke-Verify -Body $fenced
    Assert-True (($r6.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closed nothing from inside a fence'

    Write-Host "-ReportOnly does not mutate anything" -ForegroundColor Cyan
    $r7 = Invoke-Verify -Body 'Closes #332' -ReportOnly
    Assert-Equal 0 $r7.ExitCode 'exits 0'
    Assert-True (($r7.Log | Where-Object { $_ -match 'issue view 332' }).Count -eq 1) 'still inspects the issue'
    Assert-True (($r7.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closes nothing'
    Assert-True (($r7.Log | Where-Object { $_ -match 'issue comment' }).Count -eq 0) 'comments nothing'
    Assert-Says $r7.Output 'report-only' 'says it is report-only'

    Write-Host "An unreadable PR body warns and exits 0 (a merged ship must not read as failed)" -ForegroundColor Cyan
    $r8 = Invoke-Verify -Body 'Closes #332' -FailPrView
    Assert-Equal 0 $r8.ExitCode 'exits 0 even though gh failed'
    Assert-Says $r8.Output 'could not read the body' 'warns about it'
    Assert-Says $r8.Output 'gh issue list' 'points at the manual check'
    Assert-True (($r8.Log | Where-Object { $_ -match 'issue close' }).Count -eq 0) 'closed nothing while blind'
    # Proof of WHICH capture ran, at every width and path length: 'NativeCommandError' can only appear
    # in this text if a parent rendered the child's stderr as an error record. This is the suite's only
    # scenario whose child writes to stderr at all, so it is the one to hang it on (#1530).
    Assert-True (-not (Test-Says $r8.Output 'NativeCommandError')) 'no parent error-record decoration was stamped into the capture'
} finally {
    $ErrorActionPreference = $prevEap
    $env:PATH = $prevPath
    'GH_CALL_LOG', 'GH_PR_BODY', 'GH_CLOSED_ISSUES', 'GH_FAIL_PR_VIEW' | ForEach-Object {
        Remove-Item "Env:\$_" -ErrorAction SilentlyContinue
    }
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
