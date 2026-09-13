<#
.SYNOPSIS
    For a push to the trunk: find the pull requests that push carried, and run
    verify-resolved-issues.ps1 against each one.

.DESCRIPTION
    THE GAP THIS CLOSES (issue #1511). verify-resolved-issues.ps1 is ship-pr.ps1's step 6 -- it reads
    a merged PR's body back out, checks that every issue the body declared with a closing keyword is
    actually CLOSED, and closes the ones that are not. It has always run from exactly one place: the
    shipping session, immediately after its own `gh pr merge` call returned.

    The merge queue took that call away. Since #1506 ship-pr reads the trunk's rules before it merges
    and, where it finds a queue, ENQUEUES and exits 0 -- the merge lands minutes later in a process the
    session never observes, so step 6 never runs. Nothing is lost about the closing itself: GitHub
    honours the keywords on a queue merge exactly as on any other (measured on PR #1509, the first
    through that path). What is lost is the VERIFICATION that it happened, and the repair when a
    keyword missed -- which is the case the script was built for: eight issues repaired by PRs
    #341-#343 stayed open because those bodies carried plain mentions instead of keywords. Under a
    queue nothing checked, so that class returned silently.

    This script is that step running from the one place that always sees a queue merge: a push to the
    trunk. Same script underneath, same rules, same repair -- only the trigger is different.

    IT RESOLVES THE PRs FROM THE PUSH, NOT FROM THE TREE, and that is the whole reason it is its own
    file rather than a step inside fold-on-merge.yml. That workflow answers "which PR is this?" from
    the unfolded entry sitting on the trunk, which is exactly right for a fold and wrong here: an entry
    is a thing a branch happens to carry, and this check has to run for every merge -- including one
    with no entry at all, and including one whose entry a previous run already folded away. The push
    itself is the authority on what just landed, and it needs no tree state to read.

    TWO API CALLS, AND NEITHER NEEDS GIT HISTORY. The runner checks out at depth 1, so `git rev-list
    <before>..<sha>` has nothing to walk. Both questions go to GitHub instead:
      - repos/{repo}/compare/{before}...{sha}  -> the commits this push carried
      - repos/{repo}/commits/{sha}/pulls       -> the PR(s) each commit belongs to
    The range matters and is not decoration: a merge queue may land a BATCH, one merge commit per PR,
    and push them together -- so reading only the push's head commit would verify the last PR of the
    batch and silently skip the rest.

    A COMMIT MAPS TO A PR MORE THAN ONE WAY, deliberately kept. The queue's merge commit maps to its
    PR, and so do that PR's own branch-head commits once they reach the trunk (measured: 11e037d and
    6b0b458 both return #1509). The dedupe below makes the duplication free, and it buys redundancy --
    the check still finds the PR if one of the two associations is slow to appear.

    WHAT IT REFUSES TO VERIFY. A resolved PR is only passed on when it is MERGED and its base is the
    trunk. An open PR whose head commit reached the trunk some other way has closed nothing, and a PR
    merged into some other branch never had GitHub's keyword handling applied at all -- verifying
    either would report against a merge that did not happen.

    IT DOES NOT FAIL THE PUSH FOR A STILL-OPEN ISSUE. That is the case it REPAIRS, so a repair is not a
    finding. It exits non-zero only when the resolution itself broke -- the compare call failing, or a
    commit's PR lookup failing -- because then the check did not run and a green job would say it had.

    Repo-local, not plugin payload: it exists to be called by .github/workflows/verify-resolved.yml,
    which is this repo's own CI rather than anything a consumer receives. verify-resolved-issues.ps1
    underneath it IS mirrored, and is untouched by this file.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Sha
    The commit the push landed on (GitHub Actions: github.sha). Defaults to HEAD.

.PARAMETER Before
    The commit the trunk was on before the push (GitHub Actions: github.event.before). Where it is
    absent, all-zeros, or unknown to the compare API, only -Sha is examined -- see Get-PushedCommit.

.PARAMETER Trunk
    The branch a PR must have been merged into to count. Defaults to 'main'.

.PARAMETER Repo
    (Optional) 'owner/name'. Defaults to Get-RepoName from scripts/repo-config.ps1.

.PARAMETER MaxCommits
    Safety cap on how many commits of the range are looked up, newest first (default 60). A cap that
    bites is REPORTED by name rather than applied quietly -- a count taken inside a window is
    indistinguishable, in the output that quotes it, from a count taken over everything.

.PARAMETER ReportOnly
    Passed straight through to verify-resolved-issues.ps1: report each declared issue's state and
    close nothing.

.EXAMPLE
    ./scripts/release/verify-pushed-merges.ps1

.EXAMPLE
    ./scripts/release/verify-pushed-merges.ps1 -Before abc123 -Sha def456 -ReportOnly
#>
[CmdletBinding()]
param(
    [string]$Sha = '',
    [string]$Before = '',
    [string]$Trunk = 'main',
    [string]$Repo = '',
    [int]$MaxCommits = 60,
    [switch]$ReportOnly
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD, as every script here carries it. Guarded dot-source, so a tree without the
# lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'verify-pushed-merges.ps1'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# -Repo wins, so a test fixture does not need a repo-config at all -- the same seam
# verify-resolved-issues.ps1 uses, for the same reason.
if (-not $Repo) {
    . (Join-Path $repoRoot 'scripts\repo-config.ps1')
    $Repo = Get-RepoName
}

if (-not $Sha) {
    $head = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', 'HEAD') -DiscardStderr
    if ($head.ExitCode -ne 0) {
        Write-Error "no -Sha was given and HEAD could not be read (exit $($head.ExitCode)) -- nothing to resolve."
        exit 1
    }
    $Sha = ($head.Output -join '').Trim()
}

$script:ZeroSha = '0000000000000000000000000000000000000000'

function Get-ShortSha {
    <# Seven characters, or the whole string when it is shorter -- a fixture may hand in a stub. #>
    param([string]$Value)
    if (-not $Value) { return '(none)' }
    return $Value.Substring(0, [Math]::Min(7, $Value.Length))
}

function Get-PushedCommit {
    <#
        The commits this push carried, newest first.

        A range is asked of the compare API rather than of git, because the runner's checkout is
        shallow. Where there is no usable -Before -- a branch's first push sends all-zeros, and a
        force-push can name a commit the compare API no longer resolves -- the answer degrades to the
        head commit alone rather than failing: one commit is the ordinary push here, and verifying one
        PR beats verifying none.

        RETURNS THE ARRAY PLAINLY, WITHOUT THE `,@(...)` UNWRAP GUARD, and the call site keeps its
        `@()`. The guard exists to stop a ONE-element array collapsing to a scalar; combined with an
        `@()` around the call it does the opposite, wrapping the whole result in a second array that
        `@()` then reports as one element. Measured on the first smoke test of this script: a range of
        six commits printed `examining 1 commit`, and only that count said so. Every path here returns
        at least one element, so there is nothing for the guard to protect.
    #>
    param([string]$Repo, [string]$Before, [string]$Sha)

    if (-not $Before -or $Before -eq $script:ZeroSha -or $Before -eq $Sha) { return @($Sha) }

    # THE JQ EXPRESSION CARRIES NO DOUBLE QUOTES, DELIBERATELY. A quoted jq filter does not survive the
    # native-argument round trip on Windows: `.[] | "\(.number)\t..."` reaches gh as three arguments
    # and it answers `accepts 1 arg(s), received 3` -- exit 1, with nothing about quoting in it. The
    # bracket-plus-@tsv form says the same thing in characters that survive.
    $cmp = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
        'api', "repos/$Repo/compare/$Before...$Sha", '--jq', '[.commits[].sha] | reverse | .[]') -DiscardStderr
    if ($cmp.ExitCode -ne 0) {
        Write-Warning "the range $(Get-ShortSha $Before)..$(Get-ShortSha $Sha) could not be compared (exit $($cmp.ExitCode)) -- falling back to the pushed commit alone."
        return @($Sha)
    }

    $shas = @($cmp.Output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    # The compare API answers a two-dot range and excludes the base, so a push whose head is the only
    # new commit still has to be represented -- and a range that came back empty means the same thing.
    if ($shas.Count -eq 0) { return @($Sha) }
    if ($shas -notcontains $Sha) { $shas = @($Sha) + $shas }
    return $shas
}

$commits = @(Get-PushedCommit -Repo $Repo -Before $Before -Sha $Sha)

# A CAP THAT BITES IS SAID OUT LOUD. Silently truncating here would report "every declared issue was
# closed" over a window, in words that read as being over the push.
$capped = $false
if ($commits.Count -gt $MaxCommits) {
    $capped = $true
    Write-Warning "this push carries $($commits.Count) commits; only the newest $MaxCommits are examined for pull requests. Any PR older than that in this range is NOT verified -- re-run this script against the narrower range by hand if that matters."
    $commits = @($commits[0..($MaxCommits - 1)])
}

$plural = if ($commits.Count -ne 1) { 's' } else { '' }
Write-Host "merge check: examining $($commits.Count) commit$plural of this push for merged pull requests..." -ForegroundColor Cyan

$prs = [ordered]@{}
$lookupFailed = 0
foreach ($commit in $commits) {
    # number, merged_at and base.ref on one tab-separated line each, so a PR is judged on what the API
    # says rather than on the commit having been reachable from the trunk. @tsv renders a null
    # merged_at as an empty field, which is exactly the "never merged" test below. Quote-free for the
    # reason given in Get-PushedCommit.
    $assoc = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
        'api', "repos/$Repo/commits/$commit/pulls",
        '--jq', '.[] | [.number, .merged_at, .base.ref] | @tsv') -DiscardStderr
    if ($assoc.ExitCode -ne 0) {
        $lookupFailed++
        Write-Warning "  could not read the pull requests for $(Get-ShortSha $commit) (exit $($assoc.ExitCode))."
        continue
    }
    foreach ($line in $assoc.Output) {
        $fields = "$line".Trim() -split "`t"
        if ($fields.Count -lt 3) { continue }
        $number = 0
        if (-not [int]::TryParse($fields[0], [ref]$number) -or $number -le 0) { continue }
        if (-not $fields[1]) { continue }              # never merged
        if ($fields[2] -ne $Trunk) { continue }        # merged somewhere other than the trunk
        if (-not $prs.Contains("$number")) { $prs["$number"] = $number }
    }
}

if ($prs.Count -eq 0) {
    if ($lookupFailed -gt 0) {
        $failPlural = if ($lookupFailed -ne 1) { 's' } else { '' }
        Write-Error "no merged pull request was resolved from this push, and $lookupFailed commit lookup$failPlural failed -- the check did not run, so this is not the same as 'nothing to verify'."
        exit 1
    }
    Write-Host "merge check: this push carried no pull request merged into '$Trunk' -- nothing to verify." -ForegroundColor DarkGray
    exit 0
}

$numbers = @($prs.Values | Sort-Object)
Write-Host ("merge check: " + (($numbers | ForEach-Object { "PR #$_" }) -join ', ') + " landed on '$Trunk' -- verifying what each declared it closes.") -ForegroundColor Cyan

$verify = Join-Path $PSScriptRoot 'verify-resolved-issues.ps1'
foreach ($number in $numbers) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $verify, '-Pr', "$number", '-Repo', $Repo)
    if ($ReportOnly) { $arguments += '-ReportOnly' }
    & powershell @arguments
    # verify-resolved-issues.ps1 never fails on a still-open issue -- that is the case it repairs. A
    # non-zero here is the script itself having broken, which is worth a line and not worth abandoning
    # the remaining PRs of a batch for.
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  the issue check for PR #$number exited $LASTEXITCODE -- verify by hand with: gh pr view $number --repo $Repo"
    }
}

if ($lookupFailed -gt 0) {
    $failPlural = if ($lookupFailed -ne 1) { 's' } else { '' }
    Write-Error "$lookupFailed commit$failPlural in this push could not be looked up, so a pull request may have gone unverified even though the ones above were checked."
    exit 1
}
if ($capped) {
    Write-Warning "the commit cap bit on this run -- see the warning above for what was left out."
}
exit 0
