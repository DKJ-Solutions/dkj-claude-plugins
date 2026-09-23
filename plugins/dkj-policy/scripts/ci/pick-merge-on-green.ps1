<#
.SYNOPSIS
    Issue #2319's sweep: which ARMED pull request, if any, this merge-on-green run should hand to
    ship-pr.ps1. Prints one line per armed pull request and, inside GitHub Actions, writes
    'picked', 'pr' and 'branch' to $env:GITHUB_OUTPUT so the runner's later steps can key on them.

.DESCRIPTION
    WHAT #2319 MEASURED. ship-pr refused on a red required check, `gh run rerun --failed` turned
    every check green, and nothing merged the pull request -- the merge was owed to a session that
    had already exited, to a person noticing, and to a checkout standing on the right branch. This
    script is the first half of removing the first two: it answers "is there a merge owed right
    now", from the tracker, with no session involved.

    IT DECIDES NOTHING ABOUT THE MERGE ITSELF, and that restraint is the design rather than a gap.
    Whether the certificate is stale (ship-pr's step 3b), whether the branch document still matches
    what the pull request published (the DEPLOY lock), and whether a step is still unresolved (the
    step-list gate) are all ship-pr.ps1's questions, and the runner answers them by RUNNING that
    script. See merge-on-green-lib.ps1's header for why re-deriving them here would be the one
    mistake this family of files is shaped to avoid.

    THE SWEEP READS THE TRACKER, NOT THE EVENT. The runner is woken by three triggers -- a CI
    workflow_run completing, a half-hourly schedule, and workflow_dispatch -- and none of them is
    trusted to say WHICH pull request is owed a merge. #2319's own incident was repaired with
    `gh run rerun --failed`, and whether a partial re-run re-emits workflow_run is not a contract
    worth resting the mechanism on. A sweep is indifferent to which of the three woke it.

    FAIL-CLOSED, THROUGHOUT: every read that cannot be made prints picked=false and stops. The worst
    this script can do wrong is leave an owed merge for the next sweep, half an hour later at the
    outside, with the pull request untouched.
#>

$ErrorActionPreference = 'Stop'

function Write-PickVerdict {
    param([bool]$Picked, [string]$Reason, [string]$Pr = '', [string]$Branch = '', [string]$Sha = '')

    $value = if ($Picked) { 'true' } else { 'false' }
    Write-Host "merge-on-green: picked=$value -- $Reason"
    if ($env:GITHUB_OUTPUT) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "picked=$value"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "pr=$Pr"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "branch=$Branch"
        # The head commit the verdict was formed on (#2338): the runner refuses to run anything from a
        # checkout that is not this commit, so a push after the pick cannot bring new code with it.
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "sha=$Sha"
    }
}

# THE SOURCE-REPO GUARD, as every mirrored script carries it. Guarded dot-source, so a tree without the
# lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# DUAL-CONTEXT ROOT, AND IN A CONSUMER IT IS THE WHOLE DIFFERENCE BETWEEN RIGHT AND WRONG (#2329). This
# read '$PSScriptRoot\..\..' until then, which is the source repo's root only because the source runs its
# own copy. A consumer's merge-on-green.yml runs the plugin mirror out of a checkout of the SOURCE tree,
# so that expression resolved to the checkout -- and the Get-RepoName read below would then have come off
# the source repo's own repo-config.ps1, sweeping the source repo's pull requests from a consumer's
# runner. CLAUDE_PROJECT_DIR first, the git root otherwise: the resolution every other mirrored script
# already uses.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -ScriptName 'pick-merge-on-green.ps1'
Set-Location $RepoRoot

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
# ref-print-lib IS NOT REACHED THROUGH pr-issues-lib, which is easy to assume because so many of that
# file's own callers load both. Get-DisplayRef is defined here and here only, and the one line below
# that prints a branch name into a log needs it: a head ref is chosen by whoever opened the pull
# request, and this is the file that strips the format characters git itself accepts.
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\merge-on-green-lib.ps1')
$configPath = Join-Path $RepoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath) { . $configPath }

$label = Get-MergeOnGreenArmLabel

$repo = Get-SeamValue -Name 'Get-RepoName' -Default $env:GITHUB_REPOSITORY
if (-not $repo) {
    Write-PickVerdict -Picked $false -Reason 'repo name unresolvable (Get-RepoName / GITHUB_REPOSITORY)'
    exit 0
}

# THE SERVER-SIDE FILTER IS THE CHEAP HALF; the lib re-asks it locally, which is why this asks gh for
# `labels` as well as passing --label. See Test-MergeOnGreenArmed for what that second read closes.
# --limit is generous rather than tight: an armed pull request that fell off the end of the page would
# be an owed merge no sweep can ever see, and the page costs one call whatever its size.
$listRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
    'pr', 'list', '--state', 'open', '--label', $label, '--limit', '100', '--repo', $repo,
    '--json', 'number,headRefName,headRefOid,isDraft,mergeable,labels,isCrossRepository,files,changedFiles')
if ($listRead.ExitCode -ne 0) {
    Write-PickVerdict -Picked $false -Reason "the list of '$label' pull requests could not be read"
    exit 0
}

$armed = @()
try {
    # THROUGH THE LIB, NOT A PIPE INTO ConvertFrom-Json: under 5.1 that wraps the whole array as ONE
    # record, and the sweep then evaluated nothing (#2381).
    $armed = @(ConvertFrom-MergeOnGreenListJson -Json ($listRead.Output -join "`n"))
} catch {
    Write-PickVerdict -Picked $false -Reason "the list of '$label' pull requests could not be parsed"
    exit 0
}

if ($armed.Count -eq 0) {
    Write-PickVerdict -Picked $false -Reason "no open pull request carries '$label' -- nothing is owed a merge"
    exit 0
}

$verdicts = @()
foreach ($record in $armed) {
    # FAIL-CLOSED, BUT NEVER SILENTLY (#2381). A skip that printed nothing read exactly like "not
    # eligible yet", which is how a parse that dropped every record went unnoticed for six sweeps.
    if ($null -eq $record -or -not $record.PSObject.Properties['number']) {
        Write-Host '  (skipped) a record in the list carries no pull request number -- it was not evaluated'
        continue
    }
    $number = [string]$record.number

    # ONE gh CALL PER ARMED PULL REQUEST, and the armed set is normally empty or one. The required
    # payload is fetched even for a pull request the cheap tests below will refuse anyway, because
    # Get-MergeOnGreenPrVerdict wants every fact in hand -- which is what keeps the verdict pure and
    # its Reason exact. A sweep that armed ten pull requests would cost ten reads; the merge it
    # performs costs a CI run.
    $requiredRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
        'pr', 'checks', $number, '--repo', $repo, '--required', '--json', 'name,bucket,state,link')
    $requiredJson = if ($requiredRead.ExitCode -eq 0) { ($requiredRead.Output -join "`n") } else { '' }

    # ChecksJson is left out deliberately: Get-MergeBlockVerdict uses it only to NAME the
    # not-required checks that failed, which no decision here reads, and skipping it halves the calls.
    $blockVerdict = $null
    try { $blockVerdict = Get-MergeBlockVerdict -RequiredChecksJson $requiredJson } catch { $blockVerdict = $null }

    $verdict = Get-MergeOnGreenPrVerdict -Record $record -MergeBlockVerdict $blockVerdict -Label $label
    $branch = ''
    if ($record.PSObject.Properties['headRefName']) { $branch = [string]$record.headRefName }
    $sha = ''
    if ($record.PSObject.Properties['headRefOid']) { $sha = [string]$record.headRefOid }

    Write-Host ("  #{0} ({1}): {2} -- {3}" -f $number, (Get-DisplayRef -Ref $branch), $(if ($verdict.Eligible) { 'ELIGIBLE' } else { 'waiting' }), $verdict.Reason)

    $verdicts += [pscustomobject]@{
        Number   = $number
        Branch   = $branch
        Sha      = $sha
        Eligible = $verdict.Eligible
        Reason   = $verdict.Reason
    }
}

# N ARMED AND NO VERDICT IS A CONTRADICTION, NOT A WAIT: every armed pull request the list held was
# skipped before it could be judged. Still fail-closed -- the reason just says what actually happened.
if ($verdicts.Count -eq 0) {
    Write-PickVerdict -Picked $false -Reason "$($armed.Count) record(s) in the '$label' list, but none could be evaluated -- the list was not read as pull requests"
    exit 0
}

$pick = Select-MergeOnGreenCandidate -Verdicts $verdicts
if ($null -eq $pick) {
    Write-PickVerdict -Picked $false -Reason "$($verdicts.Count) armed pull request(s), none eligible yet -- the lines above say why"
    exit 0
}

# THE BRANCH NAME IS THE ONE ATTACKER-INFLUENCED VALUE THIS SCRIPT EMITS, and it is emitted into a
# GITHUB_OUTPUT that a later step puts on a `git checkout` command line. Anyone who can open a pull
# request chooses it. git itself rejects the control characters that would make a NAME deceptive, but
# nothing stops a leading '-', which turns the argument into a flag -- so the charset is asserted here
# and a name outside it refuses the whole pick rather than being sanitised into something else. The
# set is deliberately narrower than git's: every branch this workflow creates is <prefix>/<name>.
if ($pick.Sha -notmatch '^[0-9a-f]{40}$') {
    Write-PickVerdict -Picked $false -Reason "PR #$($pick.Number)'s head commit could not be read, so there is no commit to pin the ship to -- the next sweep asks again"
    exit 0
}
if ($pick.Branch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$') {
    Write-PickVerdict -Picked $false -Reason "PR #$($pick.Number)'s head branch is not a plain name this runner will put on a command line -- merge it by hand"
    exit 0
}

Write-PickVerdict -Picked $true -Reason "PR #$($pick.Number) on '$($pick.Branch)' is owed a merge -- handing it to ship-pr" -Pr $pick.Number -Branch $pick.Branch -Sha $pick.Sha
exit 0
