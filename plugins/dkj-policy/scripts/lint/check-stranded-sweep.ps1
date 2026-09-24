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

# THE TOTAL BUDGET STARTS HERE, not at the top of the script -- everything before this point is local
# feature-detection (file existence, Get-Command, the keyring read), none of it network-bound, so
# counting it would only make the budget less generous for no reason (issue #2438).
$scanStart = Get-Date

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
$judgedCount = 0
$unjudgedCount = 0
$budgetExceeded = $false
foreach ($record in $armed) {
    # THE TOTAL BUDGET, CHECKED ONCE PER ARMED PULL REQUEST, BEFORE ITS OWN gh CALL (issue #2438): once
    # spent, every remaining record is counted as unjudged rather than attempted -- this is what keeps
    # the loop's own worst case bounded, on top of -TimeoutSeconds bounding each individual call.
    if (-not $budgetExceeded -and ((Get-Date) - $scanStart).TotalSeconds -ge $MaxElapsedSeconds) {
        $budgetExceeded = $true
    }
    if ($budgetExceeded) { $unjudgedCount++; continue }

    if ($null -eq $record -or -not $record.PSObject.Properties['number']) { $unjudgedCount++; continue }
    $number = [string]$record.number

    $requiredRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -TimeoutSeconds $TimeoutSeconds -Arguments @(
        'pr', 'checks', $number, '--repo', $repo, '--required', '--json', 'name,bucket,state,link,completedAt')
    if (-not (Test-NativeCommandStarted -Capture $requiredRead) -or -not (Test-NativeExitMeasured -Capture $requiredRead) `
            -or $requiredRead.TimedOut -or $requiredRead.ExitCode -ne 0) {
        # THIS ONE PULL REQUEST'S REQUIRED-CHECK READ FAILED -- fail closed for IT alone (read as
        # not-green, exactly as Get-MergeOnGreenPrVerdict itself reads an unreadable payload), rather
        # than abandoning every other armed pull request in the list over one bad read. Counted as
        # unjudged (issue #2438, Victor): this pull request was never actually checked for stranding,
        # so a summary that folded it silently into "none stranded" would be reporting more than it knows.
        $unjudgedCount++
        continue
    }
    $requiredJson = ($requiredRead.Output -join "`n")

    $blockVerdict = $null
    try { $blockVerdict = Get-MergeBlockVerdict -RequiredChecksJson $requiredJson } catch { $blockVerdict = $null }
    $greenAge = $null
    try { $greenAge = Get-RequiredGreenAgeMinutes -RequiredChecksJson $requiredJson -Now (Get-Date) } catch { $greenAge = $null }

    $verdict = Get-MergeOnGreenStrandedVerdict -Record $record -MergeBlockVerdict $blockVerdict -GreenAgeMinutes $greenAge -Label $label
    $judgedCount++
    if (-not $verdict.Stranded) { continue }

    $branch = ''
    if ($record.PSObject.Properties['headRefName']) { $branch = [string]$record.headRefName }
    $title = ''
    if ($record.PSObject.Properties['title']) { $title = [string]$record.title }

    # UNTRUSTED DATA, SCRUBBED BEFORE IT REACHES A PRINTED LINE -- the same [^\x20-\x7E] pattern
    # Get-MergeOnGreenExecutedPathHit already applies to a pushed path, applied here uniformly to every
    # value a pull request's own author chose (branch name, title), on a repository anybody may open one
    # against. THIS SCRUB IS FOR PROSE, NOT FOR A COMMAND LINE (Sebastian, issue #2438) -- see
    # Get-PasteableRef below for the separate judgement the printed `git checkout` needs.
    $branchSafe = $branch -replace '[^\x20-\x7E]', '?'
    $titleSafe  = $title -replace '[^\x20-\x7E]', '?'

    # THE CHECKOUT LINE JUDGES THE RAW BRANCH NAME, NOT $branchSafe (issue #1594). Scrubbing control
    # characters to '?' leaves every printable ASCII shell metacharacter -- '$', '(', ')', '`', ';', '|'
    # -- untouched, so a branch carrying one would still reach a command line a reader is invited to
    # paste. Get-PasteableRef is the allowlist that actually answers "is this safe to paste": the branch
    # name itself when it is, else a placeholder plus a note naming the real branch as prose.
    $branchPaste = Get-PasteableRef -Ref $branch

    $stranded += [pscustomobject]@{
        Number = $number; Branch = $branchSafe; Title = $titleSafe
        CheckoutToken = $branchPaste.Token; CheckoutNote = $branchPaste.Note
    }
}

# HONEST, EVEN WHEN THERE IS NOTHING STRANDED TO REPORT (Victor, issue #2438): $armed.Count alone used to
# stand in for "none stranded", which folded a per-PR read failure or a budget cut-off silently into that
# claim. $judgedCount + $unjudgedCount always equals $armed.Count, so the two together say exactly what
# was actually checked.
$total = $armed.Count
$incompleteLine = ''
if ($unjudgedCount -gt 0) {
    $incompleteLine = "[INCOMPLETE] judged $judgedCount of $total armed pull request(s); $unjudgedCount not checked (a per-PR required-check read failed, or the ${MaxElapsedSeconds}s scan budget ran out) -- the rest were not checked, so run this again to cover them."
}

if ($stranded.Count -eq 0) {
    if ($unjudgedCount -eq 0) {
        Write-Host "[OK] $total armed pull request(s), none stranded on the executed-path reason."
    } else {
        Write-Host $incompleteLine
    }
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
    Write-Host "    git checkout $($s.CheckoutToken)"
    if ($s.CheckoutNote) { Write-Host $s.CheckoutNote }
    Write-Host '    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/ship-pr.ps1'
}
if ($incompleteLine) { Write-Host $incompleteLine }
exit 0
