<#
.SYNOPSIS
    Which armed pull requests will the merge-on-green sweep decline FOREVER, because their diff touches
    a path the runner executes (issue #2338) -- and therefore sit stranded once the session that armed
    them is gone (issue #2438, split out of #2436's step 2).

.DESCRIPTION
    THE HOLE THIS CLOSES. ship-pr.ps1 labels a pull request `merge-when-green` before it starts waiting
    on CI, so a sweep can finish the merge if the shipping session dies. But when the diff reaches code
    the runner would execute from the branch, the picker (pick-merge-on-green.ps1) declines it on every
    sweep, forever -- and that decline is visible only in the sweep's own CI log. The pull request stays
    labelled and green, so it READS as owned. Measured on PR #2433, September 24, 2026.

    ONE PURE FUNCTION DOES THE JUDGING, REUSED RATHER THAN RESTATED: Get-MergeOnGreenStrandedVerdict in
    merge-on-green-lib.ps1 -- the same lib pick-merge-on-green.ps1 already dot-sources, holding the one
    spelling of the arming label, the executed-path rule and the settle window. The `gh` reads that
    function needs (which pull requests are armed, whether each one's required checks are green, and
    since when) are the identical reads pick-merge-on-green.ps1 already makes, so a repo running this
    check sees exactly what the next sweep would see -- and they are made by Invoke-BoundedPrScan
    (pr-scan-lib.ps1, issue #2526), shared with check-unshipped-pr.ps1, so this script keeps only its
    filter, its verdict and its prose.

    THREE WAYS THIS STAYS SILENT, DELIBERATELY, BECAUSE IT MUST NEVER BLOCK A SESSION START:
      - no .github/workflows/merge-on-green.yml in this repo -- the sweep this issue is about does not
        exist here, so there is nothing to strand;
      - gh is absent, or `gh auth status` names no active account -- the same "nothing to compare
        against" reading check-git-identity.ps1 gives, read here as "nothing to ASK";
      - the `gh pr list`/`gh pr checks` reads themselves fail to start, time out, or return a non-zero
        exit -- offline, a transient API outage, a rate limit. FAIL QUIET, not fail loud: the worst this
        check can be wrong about is a stranded pull request that goes unreported for one more session,
        which is exactly the state today, with nothing made worse.
    Every one of the three prints one line and exits 0; only a genuine finding, or an incomplete scan
    (see BOUNDED below), prints more.

    BOUNDED PER CALL, AND BOUNDED IN TOTAL (Victor, issue #2438). Every native call carries
    -TimeoutSeconds, so a hung `gh` cannot hold a session start hostage on its own -- but that bounds one
    call, not the loop: the armed set is normally 0 or 1 (ship-pr.ps1 is this workflow's only writer of
    the label), yet nothing stopped it from being larger, and at up to $TimeoutSeconds per armed pull
    request the loop alone could run past hooks.json's own 120s per-hook timeout, in which case the
    harness kills this check mid-scan and a stranded pull request among the untried ones is silently
    never reported -- the opposite of what this check exists for. -MaxElapsedSeconds is the second bound:
    once the scan's own wall clock (measured from just before the first `gh pr list` read) reaches it, no
    further armed pull request is judged, and the run says so explicitly with a `[INCOMPLETE]` marker
    naming how many were judged and how many were not, rather than reporting only on the ones it reached.
    The per-call timeout in hooks.json is still the backstop behind both.

    NO SEAM IS HARDCODED. The arming label (Get-MergeOnGreenArmLabel), the settle window
    (Get-MergeOnGreenSettleMinutes) and the required-check state (Get-MergeBlockVerdict, which reads
    whatever `gh pr checks --required` reports rather than naming a check) all come from the functions
    the picker itself calls -- a consumer that runs this workflow under a different required check name
    or a different settle window is read correctly without this script knowing either.

    UNTRUSTED DATA, PRINTED SAFELY. A pull request's branch name and title are chosen by whoever opened
    it, and this repository is public. Both are scrubbed to printable ASCII with the same `[^\x20-\x7E]`
    pattern Get-MergeOnGreenExecutedPathHit already uses on a pushed path, before either reaches a
    printed line. THAT SCRUB IS FOR DISPLAY ONLY, AND THE RESUME COMMAND NEEDS MORE (Sebastian, issue
    #2438): '$', '(', ')', '`', ';' and '|' are all printable ASCII, so a branch name carrying one sails
    through the `[^\x20-\x7E]` scrub unchanged and would otherwise reach the printed `git checkout`
    line -- a paste-ready remedy is exactly the command a reader is invited to run verbatim. So the
    checkout line is not built from the scrubbed name at all: it goes through Get-PasteableRef
    (ref-print-lib.ps1, issue #1594), ship-pr.ps1's own answer to this, reused rather than restated.
    A branch name outside its narrow allowlist prints as the placeholder '<branch>' plus a note naming
    the real branch as prose, where shell metacharacters are inert.

    READ-ONLY: every `gh` call here is a read (`pr list`, `pr checks`). Nothing is merged, labelled,
    commented on or pushed.

    RUN IT from the command line whenever you want the answer directly:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-stranded-sweep.ps1

    Its one automatic caller is the SessionStart hook stranded-sweep-sessioncheck.ps1 (workflow plugin).

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root to read the workflow file in, for the test suite and the SessionStart hook. A consumer
    never types this: the root is resolved dual-context like every other shared script.

.PARAMETER TimeoutSeconds
    (Optional) how long each `gh` call gets before this check gives up on it. Default 15 -- generous for
    a `pr list`/`pr checks` read, and far under hooks.json's own 120s per-hook backstop.

.PARAMETER MaxElapsedSeconds
    (Optional) the TOTAL wall-clock budget for judging armed pull requests, measured from just before the
    first `gh pr list` read. Default 90 -- comfortably under hooks.json's 120s per-hook timeout, leaving
    slack for the list read itself (up to -TimeoutSeconds), scrubbing and printing. Once the budget is
    spent, no further armed pull request is judged and the run says so via an `[INCOMPLETE]` marker
    rather than silently reporting on only the ones it reached (issue #2438).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-stranded-sweep.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [int]$TimeoutSeconds = 15,
    [int]$MaxElapsedSeconds = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE ROOT COMES FROM ONE DEFINITION (issue #1422), same as check-git-identity.ps1 and
# check-unfolded-entry.ps1. Dot-sourced guarded: a mirror built before this lib existed degrades to the
# CLAUDE_PROJECT_DIR/git fallback below rather than throwing.
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

# FEATURE-DETECTION, FIRST AND CHEAPEST: the sweep this issue is about only exists where this workflow
# file does. A consumer that has not adopted the CI floor -- or the source repo before it did -- has
# nothing this check can strand a pull request out of.
$flowPath = if ($repoRoot) { Join-Path $repoRoot '.github\workflows\merge-on-green.yml' } else { '' }
if (-not $flowPath -or -not (Test-Path -LiteralPath $flowPath -PathType Leaf)) {
    Write-Host '[SKIP] no .github/workflows/merge-on-green.yml in this repo -- there is no merge-on-green sweep for a pull request to be stranded out of.'
    exit 0
}

# gh ON PATH AT ALL -- asking about an EXECUTABLE, which is exactly the question command-probe-lib.ps1's
# own header says Get-Command is the right tool for, not the expensive one.
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host '[SKIP] gh is not installed -- nothing here can be read.'
    exit 0
}

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')

# gh AUTHENTICATED -- read from the KEYRING (Get-ActiveGhAccount), so this costs no network call and
# reads exactly the same "is there anything to ask" signal check-git-identity.ps1 already reads for a
# different question. Absent or logged out is the ordinary state of a machine that never touches the
# tracker.
if (-not (Get-ActiveGhAccount)) {
    Write-Host '[SKIP] gh names no active account (absent, or logged out) -- nothing here can be read.'
    exit 0
}

. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\merge-on-green-lib.ps1')
# FOR THE PRINTED RESUME COMMAND (issue #1594): Get-PasteableRef decides whether a pull request's own
# branch name may go into the `git checkout` line this check prints, and supplies the placeholder plus
# the explaining note when it may not -- ship-pr.ps1's own answer to a pushed branch name carrying a
# shell metacharacter, reused rather than restated. Same unguarded dot-source as its siblings above.
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-scan-lib.ps1')
$configPath = if ($repoRoot) { Join-Path $repoRoot 'scripts\repo-config.ps1' } else { '' }
if ($configPath -and (Test-Path -LiteralPath $configPath -PathType Leaf)) { . $configPath }

$label = Get-MergeOnGreenArmLabel

# THE SAME REPO NAME RESOLUTION pick-merge-on-green.ps1 uses (issue #2329's dual-context lesson): this
# repo's own seam first, GITHUB_REPOSITORY otherwise. A session hook has neither in the source repo's own
# checkout unless repo-config.ps1 declares it, so an unreadable name is its own quiet skip rather than a
# guess.
$repo = Get-SeamValue -Name 'Get-RepoName' -Default $env:GITHUB_REPOSITORY
if (-not $repo) {
    Write-Host '[SKIP] repo name unresolvable (Get-RepoName / GITHUB_REPOSITORY) -- nothing here can be read.'
    exit 0
}

# THE BOUNDED SCAN IS SHARED WITH check-unshipped-pr.ps1 (issue #2526): the list read, the per-PR
# required-check read, both budgets and the honest judged/unjudged split, the display scrub and the
# checkout token live in Invoke-BoundedPrScan. What is this check's own is the filter (the arming label),
# the verdict, and the prose. The --json fields are the picker's plus 'title', which only this check prints.
$scan = Invoke-BoundedPrScan -Repo $repo -ListFilter @('--label', $label) `
    -JsonFields 'number,headRefName,headRefOid,title,isDraft,mergeable,labels,isCrossRepository,files,changedFiles' `
    -TimeoutSeconds $TimeoutSeconds -MaxElapsedSeconds $MaxElapsedSeconds -Judge {
        param($Record, $MergeBlockVerdict, $GreenAgeMinutes)
        $verdict = Get-MergeOnGreenStrandedVerdict -Record $Record -MergeBlockVerdict $MergeBlockVerdict -GreenAgeMinutes $GreenAgeMinutes -Label $label
        if ($verdict.Stranded) { return @{} }
        return $null
    }

if ($scan.Status -eq 'ListFailed') {
    # FAIL QUIET, NOT FAIL LOUD (this file's own docstring): offline, a rate limit, a transient outage --
    # none of it is a finding, and the worst this check can be wrong about is one more session without an
    # answer, which is the state today.
    Write-Host '[SKIP] the list of armed pull requests could not be read -- offline, or a transient gh/API problem.'
    exit 0
}
if ($scan.Status -eq 'ParseFailed') {
    Write-Host '[SKIP] the list of armed pull requests could not be parsed.'
    exit 0
}
if ($scan.Total -eq 0) {
    Write-Host "[OK] no open pull request carries '$label' -- nothing can be stranded."
    exit 0
}

# HONEST, EVEN WHEN THERE IS NOTHING STRANDED TO REPORT (Victor, issue #2438): the armed count alone used
# to stand in for "none stranded", which folded a per-PR read failure or a budget cut-off silently into
# that claim. JudgedCount + UnjudgedCount always equals Total, so the two together say exactly what was
# actually checked.
$incompleteLine = Get-PrScanIncompleteLine -Scan $scan -Noun 'armed' -MaxElapsedSeconds $MaxElapsedSeconds
$stranded = @($scan.Findings)

if ($stranded.Count -eq 0) {
    if ($incompleteLine) { Write-Host $incompleteLine }
    else { Write-Host "[OK] $($scan.Total) armed pull request(s), none stranded on the executed-path reason." }
    exit 0
}

Write-Host "[STRANDED] $($stranded.Count) armed pull request(s) the sweep will never take -- their diff changes code the runner executes, so only a session can finish them:"
foreach ($s in ($stranded | Sort-Object { [int]$_.Number })) {
    $titlePart = if ($s.Title) { " -- $($s.Title)" } else { '' }
    Write-Host "  #$($s.Number) ($($s.Branch))$titlePart"
    Get-PrScanResumeLines -Finding $s | ForEach-Object { Write-Host $_ }
}
if ($incompleteLine) { Write-Host $incompleteLine }
exit 0
