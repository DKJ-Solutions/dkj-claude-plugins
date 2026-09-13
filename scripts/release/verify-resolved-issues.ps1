<#
.SYNOPSIS
    Verify that the issues a merged PR declared it closes are actually CLOSED -- and close any that
    are not.

.DESCRIPTION
    The second half of the resolves gate. open-pr.ps1 writes `Closes #<n>` lines into the PR body and
    GitHub honours them on merge into the default branch; this script checks the OUTCOME and repairs
    it if the keyword did not fire (GitHub only auto-closes on a merge into the default branch, and an
    edited or cross-repo body can miss).

    It reads the numbers back OUT of the merged PR body rather than taking them as a parameter, so the
    verification is against what the PR actually declared -- there is no second tally to drift from
    the first (a second tally is how the #275 preview/apply drift started). Because it reads the body
    through the shared recogniser, a closing keyword written inside BACKTICKS is correctly ignored:
    GitHub does not link a reference inside a code span, so it closes nothing there either, and a
    document explaining this gate necessarily writes the pattern it explains.

    Called by ship-pr.ps1 as its last step. Also usable on its own to repair bookkeeping after the
    fact -- which is exactly what was needed on August 1, 2026, when eight issues repaired by PRs
    #341-#343 had stayed open because those bodies carried plain mentions instead of keywords.

    Ordering rule: COMMENT first, then close. `gh issue close --comment "<multiline>"` closes the
    issue and silently DROPS the comment (lesson of July 30, 2026), and `gh issue close` has no
    --body-file of its own.

    MIRRORED INTO THE PLUGIN, travelling with ship-pr.ps1 rather than on its own merit: it IS that
    script's step 6, and a consumer whose ship-pr called a file absent from the mirror would fail at the
    last step of a sequence that has already merged. Documented by the ship-pr skill, which carries a
    section for running this step alone.

    This header claimed the opposite until August 4, 2026 -- "deliberately workshop-local, NOT mirrored",
    citing ship-pr.ps1 and cut-release.ps1 as fellow cases while all three had by then been shared. Noted
    because no gate can catch that class: the drift lint compares the two copies against each other, and
    a wrong sentence present in both is not drift.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Pr
    The (merged) PR number to verify.

.PARAMETER Repo
    (Optional) 'owner/name'. Defaults to Get-RepoName from scripts/repo-config.ps1.

.PARAMETER ReportOnly
    Report the state of each declared issue without closing anything.

.EXAMPLE
    ./scripts/release/verify-resolved-issues.ps1 -Pr 343

.EXAMPLE
    ./scripts/release/verify-resolved-issues.ps1 -Pr 343 -ReportOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$Pr,
    [string]$Repo = '',
    [switch]$ReportOnly
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'verify-resolved-issues.ps1'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')

# -Repo wins, so a test fixture does not need a repo-config at all.
if (-not $Repo) {
    . (Join-Path $repoRoot 'scripts\repo-config.ps1')
    $Repo = Get-RepoName
}

# -Utf8 (issue #907): the body is scanned for 'Resolves #N'. The markers are ASCII, but a mis-decode
# shifts nothing about them -- what it does is corrupt the surrounding prose this same string is
# reported back in, and the class is the one the language rule says never to leave to the console.
$view = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @('pr', 'view', "$Pr", '--repo', $Repo, '--json', 'body', '-q', '.body') -DiscardStderr
if ($view.ExitCode -ne 0) {
    # A warning, not an error: the merge itself already succeeded, and failing here must not make a
    # completed ship look failed. The pointer names the manual check.
    Write-Warning "could not read the body of PR #$Pr (exit $($view.ExitCode)) -- the issue-closing check was skipped. Verify by hand with: gh issue list --repo $Repo --state open"
    exit 0
}

$declared = @(Get-ClosedIssueNumbers -Text ($view.Output -join "`n"))

# A SHORT READ MUST NOT BECOME "DECLARED NOTHING" (issue #1679). The -Utf8 arm can return an empty or
# truncated Output with ExitCode 0, and this was the quietest site in that class: an empty capture gave
# $declared.Count -eq 0, and the line below then reported the resolves verification as a clean pass over
# nothing -- the whole check skipped, in green, on a machine loaded enough to lose the read.
#
# AND THE EMPTY CAPTURE IS AMBIGUOUS HERE IN A WAY IT IS NOT ELSEWHERE, which is why the ShortRead field
# rather than a test on the text is what separates them. `--json body -q .body` prints NOTHING for a PR
# whose body is genuinely empty: measured September 9, 2026, 0 bytes at exit 0. So "empty means the read
# failed" would be false at this exact call, and a PR with no body would be reported as an error.
if ($view.ShortRead) {
    if ($declared.Count -eq 0) {
        # Nothing was read AND nothing can be concluded, so this says so instead of passing.
        Write-Warning "could not establish what PR #$Pr declares: gh exited 0 but its capture was still being written when it was read, so the body this run holds may be truncated -- the issue-closing check was skipped. Verify by hand with: gh issue list --repo $Repo --state open"
        exit 0
    }
    # SOMETHING was read, so verifying it beats verifying nothing -- but the list may be short a marker,
    # which is the half a reader cannot see. Verified below with the incompleteness stated, rather than
    # discarded: the issues that ARE named still get their state checked, and #1439's rule applies to the
    # sentence, not to the work -- a degraded answer is only wrong when it arrives undeclared.
    Write-Warning "PR #$Pr's body came back as a short read (gh exited 0 with its capture still being written), so the list below may be INCOMPLETE -- an issue whose 'Resolves' marker fell outside what was read is not verified. Re-run to check the rest."
}

if ($declared.Count -eq 0) {
    Write-Host "issue check: PR #$Pr declared no issue to close -- nothing to verify." -ForegroundColor DarkGray
    exit 0
}

Write-Host ("issue check: PR #$Pr declared " + (($declared | ForEach-Object { "#$_" }) -join ', ') + " -- verifying...") -ForegroundColor Cyan

$stillOpen = 0
foreach ($issue in $declared) {
    $state = Invoke-NativeCapture -FilePath 'gh' -Arguments @('issue', 'view', "$issue", '--repo', $Repo, '--json', 'state', '-q', '.state') -DiscardStderr
    if ($state.ExitCode -ne 0) {
        Write-Warning "  #$issue -- could not read its state; check by hand."
        continue
    }
    $stateText = ($state.Output -join '').Trim()
    if ($stateText -eq 'CLOSED') {
        Write-Host "  #$issue closed by the merge." -ForegroundColor Green
        continue
    }

    $stillOpen++
    if ($ReportOnly) {
        Write-Host "  #$issue is still $stateText (report-only: not closing)." -ForegroundColor Yellow
        continue
    }

    Write-Warning "  #$issue is still $stateText after the merge -- closing it explicitly."
    $commentFile = New-ScratchPath -Label "verify-resolved-$issue" -Extension '.md'
    $commentText = "Resolved by PR #$Pr, merged into main.`n`nClosed by verify-resolved-issues.ps1: the PR body declared this issue with a closing keyword, but it was still open after the merge."
    [System.IO.File]::WriteAllText($commentFile, $commentText, (New-Object System.Text.UTF8Encoding $false))
    try {
        # Comment BEFORE close -- see the ordering rule in the description.
        $cmt = Invoke-NativeCapture -FilePath 'gh' -Arguments @('issue', 'comment', "$issue", '--repo', $Repo, '--body-file', $commentFile) -DiscardStderr
        if ($cmt.ExitCode -ne 0) { Write-Warning "    commenting on #$issue failed -- closing it without a comment." }
        $cls = Invoke-NativeCapture -FilePath 'gh' -Arguments @('issue', 'close', "$issue", '--repo', $Repo) -DiscardStderr
        if ($cls.ExitCode -ne 0) { Write-Warning "    could not close #$issue -- close it by hand." } else { Write-Host "    #$issue closed." -ForegroundColor Green }
    } finally {
        Remove-Item -Path $commentFile -Force -ErrorAction SilentlyContinue
    }
}

if ($stillOpen -eq 0) {
    Write-Host "issue check: every declared issue was already closed by the merge." -ForegroundColor Green
}
exit 0
