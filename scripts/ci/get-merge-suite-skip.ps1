<#
.SYNOPSIS
    Prices issue #2303: whether THIS CI run's suites may be skipped because the push is a
    'merge:' commit whose PR was already independently re-certified fresh. Prints
    'merge-suite-skip: skip=true|false -- <reason>' and, inside GitHub Actions, writes 'skip' to
    $env:GITHUB_OUTPUT so a later step's `if:` can read it.

.DESCRIPTION
    #1300 gave the FOLD commit a static shortcut: its tree differs from the merge commit's by
    exactly two non-executable paths, provable from the subject alone. #2303 asks for the same
    saving on the MERGE COMMIT ITSELF, and that one cannot be decided from the subject: the
    argument in #2303 ("stated fairly") is that a ship-pr merge already carries the guarantee --
    'main' had not moved past the certified tree at merge time -- but a UI merge does not, and
    nothing in a push event says which one happened.

    So this script RE-DERIVES the fact instead of trusting the commit that claims it, using the
    identical reads and pure functions ship-pr.ps1's own step 3b already uses before merging
    (Get-RequiredCheckNames, Get-RequiredCheckRunIds, Get-CertifyingRunCreatedAt,
    Test-IsFoldOnlyCommit, Get-StaleCertificateVerdict, Get-CheckOutcome -- all in
    pr-issues-lib.ps1, combined here by Get-MergeCommitSuiteSkipVerdict in ci-merge-skip-lib.ps1)
    -- done AFTER the merge instead of before it, which is what makes the answer trustworthy
    regardless of how the merge landed. Unlike step 3b this never RETRIES: the merge has already
    happened, so there is nothing to bring forward -- one reading settles it.

    FAIL-CLOSED, THROUGHOUT: every read that cannot be made -- an unreadable check payload, an
    unresolvable run, a failed fetch -- prints skip=false and stops. The worst this script can do
    wrong is run suites that strictly were not needed; it can never skip suites it has not proved
    safe to skip.

    RUNS ONCE PER SHARD, not once for the job (ci.yml's own suites job is a 4-way matrix). A
    dedicated job gated on `needs:` was considered and declined: GitHub Actions treats a job
    whose `needs:` names a job that was itself skipped by its own `if:` as skipped too, which
    would put the ordinary PR-run and non-merge-push paths -- the overwhelming majority of runs --
    one missing `always()` away from silently skipping the suites job entirely. Staying a
    same-job, step-level answer avoids that trap outright, which is also where #1300's own
    shortcut lives. The cost is a few redundant 'gh api' calls on every shard but one when
    it fires at all (once per push to main whose subject starts with 'merge: '), immeasurable
    next to the suites run it might save.
#>

$ErrorActionPreference = 'Stop'

function Write-MergeSkipVerdict {
    param([bool]$Skip, [string]$Reason)
    $value = if ($Skip) { 'true' } else { 'false' }
    Write-Host "merge-suite-skip: skip=$value -- $Reason"
    if ($env:GITHUB_OUTPUT) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "skip=$value"
    }
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\ci-merge-skip-lib.ps1')
$configPath = Join-Path $RepoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath) { . $configPath }

# ONLY A 'merge: ' PUSH TO main IS IN SCOPE. A PR run, a merge_group entry, a 'fold:' push, or an
# ordinary push whose subject this repo never writes all leave the suites step's own `if:`
# untouched -- this prints skip=false and returns fast, no network call at all.
if ($env:GITHUB_EVENT_NAME -ne 'push') {
    Write-MergeSkipVerdict -Skip $false -Reason "event is '$($env:GITHUB_EVENT_NAME)', not 'push'"
    exit 0
}

$subjectRead = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('log', '-1', '--format=%s', 'HEAD')
$subject = (($subjectRead.Output -join '')).Trim()

$pr = Get-MergeCommitPrNumber -Message $subject
if (-not $pr) {
    Write-MergeSkipVerdict -Skip $false -Reason "commit subject '$subject' is not a 'merge: <branch> (#NN)' shape"
    exit 0
}

$checkName = Get-SeamValue -Name 'Get-CiTestCheckName' -Default ''
if (-not $checkName) {
    Write-MergeSkipVerdict -Skip $false -Reason 'this repo has not named its test check (Get-CiTestCheckName)'
    exit 0
}

$repo = Get-SeamValue -Name 'Get-RepoName' -Default $env:GITHUB_REPOSITORY
if (-not $repo) {
    Write-MergeSkipVerdict -Skip $false -Reason 'repo name unresolvable (Get-RepoName / GITHUB_REPOSITORY)'
    exit 0
}

# THE MERGED PR'S OWN CHECKS, READ BACK. 'gh pr checks' answers on a MERGED pr exactly as it does
# on an open one -- nothing about this read needs the PR to still be open.
$checksRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('pr', 'checks', "$pr", '--repo', $repo, '--json', 'name,bucket,state,link')
if ($checksRead.ExitCode -ne 0) {
    Write-MergeSkipVerdict -Skip $false -Reason "PR #$pr's checks could not be read"
    exit 0
}
$checksJson = ($checksRead.Output -join "`n")

$requiredRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('pr', 'checks', "$pr", '--repo', $repo, '--required', '--json', 'name,bucket,state,link')
$requiredJson = if ($requiredRead.ExitCode -eq 0) { ($requiredRead.Output -join "`n") } else { '' }
$requiredNames = @(Get-RequiredCheckNames -RequiredChecksJson $requiredJson)
if ($requiredNames -notcontains $checkName) {
    Write-MergeSkipVerdict -Skip $false -Reason "'$checkName' is not (or could not be read as) a required check on PR #$pr"
    exit 0
}

$checkRecord = $null
try {
    $checkRecord = @(($checksJson | ConvertFrom-Json) | Where-Object { $_ -and $_.name -eq $checkName }) | Select-Object -First 1
} catch {
    $checkRecord = $null
}
$outcome = Get-CheckOutcome -Record $checkRecord

$runIds = @(Get-RequiredCheckRunIds -ChecksJson $checksJson -Names @($checkName))
$certifyingRunFound = $false
$certifiedSince = $null
if ($runIds.Count -gt 0) {
    $createdAtValues = @()
    $readFailed = $false
    foreach ($runId in $runIds) {
        $runRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('api', "repos/$repo/actions/runs/$runId", '--jq', '.created_at')
        if ($runRead.ExitCode -eq 0) { $createdAtValues += (($runRead.Output -join '').Trim()) } else { $readFailed = $true }
    }
    if (-not $readFailed) {
        $certifiedSince = Get-CertifyingRunCreatedAt -CreatedAtValues $createdAtValues
        if ($null -ne $certifiedSince) { $certifyingRunFound = $true }
    }
}

if ($outcome -ne 'pass' -or -not $certifyingRunFound) {
    $verdict = Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome $outcome -CertifyingRunFound $certifyingRunFound -StaleVerdict $null
    Write-MergeSkipVerdict -Skip $verdict.Skip -Reason $verdict.Reason
    exit 0
}

# HEAD^1, NOT origin/main: HEAD is THIS merge commit, and its own first parent is provably what
# main's tip was the instant before it landed. This job's checkout carries full history on a
# 'merge: ' push (ci.yml's fetch-depth is conditional on exactly this case), so no fetch is
# needed to walk it.
$sinceStr = $certifiedSince.ToString('yyyy-MM-ddTHH:mm:ssZ')
$mainLog = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('log', 'HEAD^1', '--first-parent', '--since', $sinceStr, '--pretty=format:%H')
if ($mainLog.ExitCode -ne 0) {
    Write-MergeSkipVerdict -Skip $false -Reason "'git log HEAD^1' failed (not a two-parent merge commit, or history too shallow)"
    exit 0
}
$newMainCommits = @($mainLog.Output | Where-Object { $_ -and "$_".Trim() })

# THE FOLD IS DISCOUNTED, THE SAME EXEMPTION AND THE SAME REASONING AS SHIP-PR's OWN STEP 3B
# (issue #1592): a commit whose whole diff is the changelog plus the removal of a branch document
# carries no script, no test, no manifest and no agent def, so it cannot be the "test block on
# the trunk that this branch's CI never ran" this whole gate exists to catch.
$foldExemptCommits = @()
if ($newMainCommits.Count -gt 0) {
    $changelogForFold = Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $RepoRoot)
    $entryDirForFold = ''
    $reservedForFold = @()
    try {
        $branchPathsForFold = Get-BranchFilePaths
        $entryDirForFold = $branchPathsForFold.Directory
        $reservedForFold = @($branchPathsForFold.ReservedNames)
    } catch {
        $entryDirForFold = ''
    }
    if ($changelogForFold -and $entryDirForFold) {
        foreach ($gained in $newMainCommits) {
            $sha = "$gained".Trim()
            $diffRead = Invoke-NativeCapture -Utf8 -FilePath 'git' -DiscardStderr -Arguments @('show', '--name-status', '--format=', $sha)
            if ($diffRead.ExitCode -ne 0) { continue }
            if (Test-IsFoldOnlyCommit -NameStatusLines @($diffRead.Output) -ChangelogPath $changelogForFold `
                    -EntryDirectory $entryDirForFold -ReservedNames $reservedForFold) {
                $foldExemptCommits += $sha
            }
        }
    }
}

$staleVerdict = Get-StaleCertificateVerdict -NewMainCommits $newMainCommits -ExemptCommits $foldExemptCommits
$verdict = Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome $outcome -CertifyingRunFound $certifyingRunFound -StaleVerdict $staleVerdict
Write-MergeSkipVerdict -Skip $verdict.Skip -Reason $verdict.Reason
exit 0
