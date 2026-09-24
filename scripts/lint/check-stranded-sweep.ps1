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
    spelling of the arming label, the executed-path rule and the settle window. This script's own job is
    only the three `gh` reads that function needs (which pull requests are armed, whether each one's
    required checks are green, and since when) -- the identical reads pick-merge-on-green.ps1 already
    makes, so a repo running this check sees exactly what the next sweep would see.

    THREE WAYS THIS STAYS SILENT, DELIBERATELY, BECAUSE IT MUST NEVER BLOCK A SESSION START:
      - no .github/workflows/merge-on-green.yml in this repo -- the sweep this issue is about does not
        exist here, so there is nothing to strand;
      - gh is absent, or `gh auth status` names no active account -- the same "nothing to compare
        against" reading check-git-identity.ps1 gives, read here as "nothing to ASK";
      - the `gh pr list`/`gh pr checks` reads themselves fail to start, time out, or return a non-zero
        exit -- offline, a transient API outage, a rate limit. FAIL QUIET, not fail loud: the worst this
        check can be wrong about is a stranded pull request that goes unreported for one more session,
        which is exactly the state today, with nothing made worse.
    Every one of the three prints one line and exits 0; only a genuine finding prints more.

    BOUNDED RUNTIME. Every native call carries -TimeoutSeconds, so a hung `gh` cannot hold a session
    start hostage -- the harness's own per-hook timeout in hooks.json is the backstop, this is the first
    line of defence. The armed set is normally 0 or 1 (ship-pr.ps1 is this workflow's only writer of the
    label), so the ordinary run costs at most a small, fixed number of calls -- the same shape
    pick-merge-on-green.ps1's own docstring already argues for its per-sweep cost.

    NO SEAM IS HARDCODED. The arming label (Get-MergeOnGreenArmLabel), the settle window
    (Get-MergeOnGreenSettleMinutes) and the required-check state (Get-MergeBlockVerdict, which reads
    whatever `gh pr checks --required` reports rather than naming a check) all come from the functions
    the picker itself calls -- a consumer that runs this workflow under a different required check name
    or a different settle window is read correctly without this script knowing either.

    UNTRUSTED DATA, PRINTED SAFELY. A pull request's branch name and title are chosen by whoever opened
    it, and this repository is public. Both are scrubbed to printable ASCII with the same `[^\x20-\x7E]`
    pattern Get-MergeOnGreenExecutedPathHit already uses on a pushed path, before either reaches a
    printed line.

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

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-stranded-sweep.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [int]$TimeoutSeconds = 15
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

# ONE READ, BOUNDED. The same --json fields the picker asks for, plus 'title' -- this check prints one,
# the picker never needs to.
$listRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -TimeoutSeconds $TimeoutSeconds -Arguments @(
    'pr', 'list', '--state', 'open', '--label', $label, '--limit', '100', '--repo', $repo,
    '--json', 'number,headRefName,headRefOid,title,isDraft,mergeable,labels,isCrossRepository,files,changedFiles')
if (-not (Test-NativeCommandStarted -Capture $listRead) -or -not (Test-NativeExitMeasured -Capture $listRead) `
        -or $listRead.TimedOut -or $listRead.ExitCode -ne 0) {
    # FAIL QUIET, NOT FAIL LOUD (this file's own docstring): offline, a rate limit, a transient outage --
    # none of it is a finding, and the worst this check can be wrong about is one more session without an
    # answer, which is the state today.
    Write-Host '[SKIP] the list of armed pull requests could not be read -- offline, or a transient gh/API problem.'
    exit 0
}

$armed = @()
try {
    $armed = @(ConvertFrom-MergeOnGreenListJson -Json ($listRead.Output -join "`n"))
} catch {
    Write-Host '[SKIP] the list of armed pull requests could not be parsed.'
    exit 0
}

if ($armed.Count -eq 0) {
    Write-Host "[OK] no open pull request carries '$label' -- nothing can be stranded."
    exit 0
}

$stranded = @()
foreach ($record in $armed) {
    if ($null -eq $record -or -not $record.PSObject.Properties['number']) { continue }
    $number = [string]$record.number

    $requiredRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -TimeoutSeconds $TimeoutSeconds -Arguments @(
        'pr', 'checks', $number, '--repo', $repo, '--required', '--json', 'name,bucket,state,link,completedAt')
    if (-not (Test-NativeCommandStarted -Capture $requiredRead) -or -not (Test-NativeExitMeasured -Capture $requiredRead) `
            -or $requiredRead.TimedOut -or $requiredRead.ExitCode -ne 0) {
        # THIS ONE PULL REQUEST'S REQUIRED-CHECK READ FAILED -- fail closed for IT alone (read as
        # not-green, exactly as Get-MergeOnGreenPrVerdict itself reads an unreadable payload), rather
        # than abandoning every other armed pull request in the list over one bad read.
        continue
    }
    $requiredJson = ($requiredRead.Output -join "`n")

    $blockVerdict = $null
    try { $blockVerdict = Get-MergeBlockVerdict -RequiredChecksJson $requiredJson } catch { $blockVerdict = $null }
    $greenAge = $null
    try { $greenAge = Get-RequiredGreenAgeMinutes -RequiredChecksJson $requiredJson -Now (Get-Date) } catch { $greenAge = $null }

    $verdict = Get-MergeOnGreenStrandedVerdict -Record $record -MergeBlockVerdict $blockVerdict -GreenAgeMinutes $greenAge -Label $label
    if (-not $verdict.Stranded) { continue }

    $branch = ''
    if ($record.PSObject.Properties['headRefName']) { $branch = [string]$record.headRefName }
    $title = ''
    if ($record.PSObject.Properties['title']) { $title = [string]$record.title }

    # UNTRUSTED DATA, SCRUBBED BEFORE IT REACHES A PRINTED LINE -- the same [^\x20-\x7E] pattern
    # Get-MergeOnGreenExecutedPathHit already applies to a pushed path, applied here uniformly to every
    # value a pull request's own author chose (branch name, title), on a repository anybody may open one
    # against.
    $branchSafe = $branch -replace '[^\x20-\x7E]', '?'
    $titleSafe  = $title -replace '[^\x20-\x7E]', '?'

    $stranded += [pscustomobject]@{ Number = $number; Branch = $branchSafe; Title = $titleSafe }
}

if ($stranded.Count -eq 0) {
    Write-Host "[OK] $($armed.Count) armed pull request(s), none stranded on the executed-path reason."
    exit 0
}

Write-Host "[STRANDED] $($stranded.Count) armed pull request(s) the sweep will never take -- their diff changes code the runner executes, so only a session can finish them:"
foreach ($s in ($stranded | Sort-Object { [int]$_.Number })) {
    $titlePart = if ($s.Title) { " -- $($s.Title)" } else { '' }
    Write-Host "  #$($s.Number) ($($s.Branch))$titlePart"
    # SHIP-PR.PS1 TAKES NO -Pr OR -Branch PARAMETER (verified against its own param block, issue #2438):
    # it looks up the open pull request for the CURRENT branch (gh pr list --head <branch>), so the
    # resume form is a checkout followed by a bare run -- two commands, not one chained with '&&', which
    # Windows PowerShell 5.1 does not have.
    Write-Host "    git checkout $($s.Branch)"
    Write-Host '    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/ship-pr.ps1'
}
exit 0
