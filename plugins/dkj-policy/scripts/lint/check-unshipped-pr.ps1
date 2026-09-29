<#
.SYNOPSIS
    Which of THIS account's open pull requests are green, settled and owed a merge that nothing will
    make -- because no arming label handed them to a sweep (issue #2525).

.DESCRIPTION
    THE HOLE THIS CLOSES. check-stranded-sweep.ps1 reads only ARMED pull requests. A ship that dies
    before ship-pr.ps1 writes the `merge-when-green` label -- or runs in a repo with no merge-on-green
    sweep, where the label buys nothing -- leaves an open, green, unmerged pull request with its branch
    document stranded off the trunk, and no session start reports it. Measured on PR #2515,
    September 26, 2026: every required check green by 08:36 UTC, never armed, unmerged and unfolded
    until the owner noticed it around 11:10 UTC, while three later pull requests shipped past it.

    ONE PURE FUNCTION DOES THE JUDGING: Get-UnshippedPrVerdict in merge-on-green-lib.ps1, which reads
    the required-check state and the settle window through the same block the picker and the stranded
    verdict share. The reads it needs -- the open pull requests this account authored, and each one's
    required checks -- are made by Invoke-BoundedPrScan (pr-scan-lib.ps1, issue #2526), shared with
    check-stranded-sweep.ps1, so this script keeps only its filter, its verdict and its prose.

    WHOSE PULL REQUESTS: the active gh account's (`gh pr list --author <login>`), because that is the
    account ship-pr.ps1 opens them under. A colleague's green pull request is theirs to ship, and a
    report naming it at every one of your session starts would be noise you cannot act on.

    NOT PROOF THAT A SHIP DIED. A pull request held back for the owner's own word (a visible result,
    `ship-pr.ps1 -NoMerge`) is green, settled and unarmed too, and nothing on the tracker tells the two
    apart. So the report offers the resume and names the other reading, rather than claiming a history
    it cannot read.

    THREE WAYS THIS STAYS SILENT, DELIBERATELY, BECAUSE IT MUST NEVER BLOCK A SESSION START -- the same
    three as check-stranded-sweep.ps1, minus its workflow-file gate, because this hole exists with or
    without a sweep: gh absent or logged out; the repo name unresolvable; the tracker read failing.
    Each prints one [SKIP] line and exits 0.

    BOUNDED PER CALL AND IN TOTAL, on check-stranded-sweep.ps1's reasoning (#2438): every `gh` call
    carries -TimeoutSeconds, and -MaxElapsedSeconds caps the loop, reporting [INCOMPLETE] with the
    judged/unjudged split instead of silently covering only the pull requests it reached.

    UNTRUSTED DATA, PRINTED SAFELY. Branch names and titles are scrubbed to printable ASCII for display,
    and the printed `git checkout` goes through Get-PasteableRef (ref-print-lib.ps1, #1594), exactly as
    check-stranded-sweep.ps1 prints its own resume line.

    READ-ONLY: `gh pr list` and `gh pr checks`. Nothing is merged, labelled, commented on or pushed.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-unshipped-pr.ps1

    Its one automatic caller is the SessionStart hook unshipped-pr-sessioncheck.ps1 (workflow plugin).

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root, for the test suite and the SessionStart hook. Resolved dual-context otherwise.

.PARAMETER TimeoutSeconds
    (Optional) how long each `gh` call gets. Default 15.

.PARAMETER MaxElapsedSeconds
    (Optional) the TOTAL wall-clock budget for judging pull requests, measured from just before the list
    read. Default 90 -- under hooks.json's 120s per-hook timeout.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-unshipped-pr.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [int]$TimeoutSeconds = 15,
    [int]$MaxElapsedSeconds = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE ROOT COMES FROM ONE DEFINITION (issue #1422), the same resolution check-stranded-sweep.ps1 uses.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

$repoRoot = ''
if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    $repoRoot = Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) {
    $repoRoot = $RootOverride
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $repoRoot = $env:CLAUDE_PROJECT_DIR
} else {
    $repoRoot = (Get-GitTopLevelPath).Path
    if (-not $repoRoot) { $repoRoot = '' }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host '[SKIP] gh is not installed -- nothing here can be read.'
    exit 0
}

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')

# THE ACCOUNT IS BOTH THE "IS THERE ANYTHING TO ASK" SIGNAL AND THE AUTHOR FILTER -- read from the
# keyring, so it costs no network call.
$account = Get-ActiveGhAccount
if (-not $account) {
    Write-Host '[SKIP] gh names no active account (absent, or logged out) -- nothing here can be read.'
    exit 0
}

. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\merge-on-green-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-scan-lib.ps1')
$configPath = if ($repoRoot) { Join-Path $repoRoot 'scripts\repo-config.ps1' } else { '' }
if ($configPath -and (Test-Path -LiteralPath $configPath -PathType Leaf)) { . $configPath }

$repo = Get-SeamValue -Name 'Get-RepoName' -Default $env:GITHUB_REPOSITORY
if (-not $repo) {
    Write-Host '[SKIP] repo name unresolvable (Get-RepoName / GITHUB_REPOSITORY) -- nothing here can be read.'
    exit 0
}

# WHETHER A SWEEP EXISTS DECIDES WHETHER AN ARMED PULL REQUEST IS ANOTHER CHECK'S QUESTION -- see
# Get-UnshippedPrVerdict's header.
$flowPath = if ($repoRoot) { Join-Path $repoRoot '.github\workflows\merge-on-green.yml' } else { '' }
$sweepExists = [bool]($flowPath -and (Test-Path -LiteralPath $flowPath -PathType Leaf))

# THE BOUNDED SCAN IS SHARED WITH check-stranded-sweep.ps1 (issue #2526): the list read, the per-PR
# required-check read, both budgets and the honest judged/unjudged split, the display scrub and the
# checkout token live in Invoke-BoundedPrScan. What is this check's own is the filter (this account's
# pull requests), the precheck, the verdict, and the prose.
$scan = Invoke-BoundedPrScan -Repo $repo -ListFilter @('--author', $account) `
    -JsonFields 'number,headRefName,title,isDraft,labels,isCrossRepository' `
    -TimeoutSeconds $TimeoutSeconds -MaxElapsedSeconds $MaxElapsedSeconds -Precheck {
        param($Record)
        # THE CHEAP DISQUALIFIERS FIRST, WITHOUT A NETWORK CALL: a draft, a fork, or an armed pull request
        # a sweep owns is declined by the verdict whatever the checks say, so its `gh pr checks` is not
        # spent. The synthetic "maximally green" inputs are safe because they can only err one way: a
        # decline here is always one of the record's own disqualifiers, and anything
        # Test-MergeOnGreenRequiredChecksSettled might add later only makes the precheck pass MORE often,
        # which spends the real read.
        $precheck = Get-UnshippedPrVerdict -Record $Record -MergeBlockVerdict ([pscustomobject]@{ Blocked = $false; Reason = ''; UnfinishedRequired = @() }) `
            -GreenAgeMinutes ([double]::MaxValue) -SweepExists $sweepExists
        return [bool]$precheck.Unshipped
    } -Judge {
        param($Record, $MergeBlockVerdict, $GreenAgeMinutes)
        # A repo with NO required check never reaches a report: with no certificate there is no green to
        # date, so Get-RequiredGreenAgeMinutes returns $null and this check cannot tell a settled pull
        # request from a live one there.
        $verdict = Get-UnshippedPrVerdict -Record $Record -MergeBlockVerdict $MergeBlockVerdict -GreenAgeMinutes $GreenAgeMinutes -SweepExists $sweepExists
        if ($verdict.Unshipped) { return @{ GreenMinutes = [math]::Floor([double]$GreenAgeMinutes) } }
        return $null
    }

if ($scan.Status -eq 'ListFailed') {
    Write-Host '[SKIP] the list of open pull requests could not be read -- offline, or a transient gh/API problem.'
    exit 0
}
if ($scan.Status -eq 'ParseFailed') {
    Write-Host '[SKIP] the list of open pull requests could not be parsed.'
    exit 0
}
if ($scan.Total -eq 0) {
    Write-Host "[OK] no open pull request authored by this account -- nothing can be left unshipped."
    exit 0
}

$incompleteLine = Get-PrScanIncompleteLine -Scan $scan -Noun 'open' -MaxElapsedSeconds $MaxElapsedSeconds
$unshipped = @($scan.Findings)

if ($unshipped.Count -eq 0) {
    if ($incompleteLine) { Write-Host $incompleteLine }
    else { Write-Host "[OK] $($scan.Total) open pull request(s) by this account, none green and unshipped." }
    exit 0
}

Write-Host "[UNSHIPPED] $($unshipped.Count) open pull request(s) by this account are green and settled, and nothing is going to merge them -- no merge-on-green sweep holds them:"
foreach ($u in ($unshipped | Sort-Object { [int]$_.Number })) {
    $titlePart = if ($u.Title) { " -- $($u.Title)" } else { '' }
    Write-Host "  #$($u.Number) ($($u.Branch)), green for $($u.GreenMinutes) minute(s)$titlePart"
    Get-PrScanResumeLines -Finding $u | ForEach-Object { Write-Host $_ }
}
Write-Host '  Either a ship died before it armed the pull request, or it is held back on purpose for the owner''s word (ship-pr -NoMerge) -- the tracker cannot tell which. Resume the first; leave the second.'
if ($incompleteLine) { Write-Host $incompleteLine }
exit 0
