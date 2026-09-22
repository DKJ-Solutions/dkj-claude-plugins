<#
.SYNOPSIS
    Every CI job -- this repo's own and every one it scaffolds into a consumer -- declares
    timeout-minutes, and the cap on the suites job stays under ship-pr's registration wait. Issue #2296.

.DESCRIPTION
    WHY THIS SUITE EXISTS. A job with no `timeout-minutes` runs to GitHub's default of SIX HOURS. That is
    not a slow job, it is a job nothing will ever reap -- and when the job carries, or is `needs:`-ed by,
    a required check, the branch does not go red. The check simply never registers, which reads as
    "still running" to every gate and to every person looking at the PR.

    THE INCIDENT. Run 35728958033's `suites (2)` wedged at 38 minutes and counting, on a commit whose
    other three shards were green in ~6 minutes each and whose shard 2 ran all 29 of its own suites
    locally in 344s. `lint-en-tests` needs: the shards, so it never registered; ship-pr spent its whole
    1800s registration wait and refused, correctly, with nothing to diagnose. Somebody had to cancel the
    job by hand, and the cancel itself took ~8 minutes to land.

    AND THE IN-PROCESS BOUND CANNOT COVER IT. $script:GateSuiteTimeoutSeconds is 1800s per suite and
    reaps a wedged child with an attribution (#1941 records it doing exactly that, three times). At 38
    minutes it should have fired and did not, so whatever wedged sat below the level a bound inside the
    process can reach. That is the class a runner-level cap exists for, and it is why this is a
    different layer from #1941/#2233/#2255/#2263 rather than a duplicate of them.

    THE FOUR PROPERTIES, and each fails silently without an assert:

      1. every job in .github/workflows/ declares timeout-minutes. A NEW workflow, or a new job in an
         existing one, is how the gap comes back -- and it comes back invisibly, because a job with no
         cap behaves exactly like a job with one until the day it wedges;
      2. every value is a positive integer inside a sane band. The tempting repair to a cap that once
         fired on a legitimately slow run is to raise it until it stops mattering, which restores the
         six-hour default under a number that looks deliberate;
      3. the cap on `suites` is STRICTLY BELOW ship-pr's registration wait, which is read out of
         ship-pr.ps1 rather than hard-coded here. This is the load-bearing one: at or above that wait the
         job times out at the same moment the shipping session gives up, so the session still learns
         nothing and the incident above repeats with a cap in place;
      4. every job the scaffolders compose for a CONSUMER declares one too. A wedge there blocks a
         consumer's required check with nobody watching at all, and none of this repo's own gates can
         see it.

    Dependency-free: no Pester, only PowerShell. Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

$repoRoot     = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$workflowDir  = Join-Path $repoRoot '.github\workflows'

# THE BAND. 60 is the loosest cap in the tree and it belongs to the two agent jobs, whose runtime is
# whatever task somebody wrote after `@claude` rather than a script this repo controls. Anything above
# that is the six-hour default wearing a number, which is the failure mode this suite exists to catch.
$maxAllowedMinutes = 60

# ------------------------------------------------------------------------------------------------
Write-Host "== .github/workflows: every job declares timeout-minutes ==" -ForegroundColor Cyan

function Get-WorkflowJobTimeouts {
    <#
        Returns one record per job key in a workflow file: its name, and the timeout-minutes declared in
        its block (or $null). PARSED ON INDENTATION, NOT ON A YAML LIBRARY -- a job key is the only thing
        at exactly two spaces under `jobs:`, and every key inside it is deeper. That is enough structure
        for this question and it keeps the suite dependency-free, which is the standing rule here.

        COMMENT LINES ARE DROPPED FIRST, and that is load-bearing rather than tidiness: every one of
        these files carries paragraphs of reasoning that quote the very keys being matched, so a
        comment saying `timeout-minutes` would satisfy this check for a job that declares none. Same
        trap ci-shard.tests.ps1's own header names for -ShardCount, one key over.
    #>
    param([string]$Path)

    $lines = @(Get-Content -LiteralPath $Path | ForEach-Object { if ($_ -match '^\s*#') { '' } else { $_ } })
    $inJobs = $false
    $jobs   = @()
    $current = $null

    foreach ($line in $lines) {
        if ($line -match '^jobs:\s*$') { $inJobs = $true; continue }
        if (-not $inJobs) { continue }
        # Anything back at column 0 ends the jobs block.
        if ($line -match '^\S') { break }

        if ($line -match '^  (?<key>[A-Za-z0-9_.-]+):\s*$') {
            if ($current) { $jobs += $current }
            $current = [pscustomobject]@{ Name = $Matches['key']; Timeout = $null }
            continue
        }
        if ($current -and $line -match '^\s{4,}timeout-minutes:\s*(?<v>\d+)\s*$') {
            $current.Timeout = [int]$Matches['v']
        }
    }
    if ($current) { $jobs += $current }
    return ,$jobs
}

$workflowFiles = @(Get-ChildItem -LiteralPath $workflowDir -File | Where-Object { $_.Extension -in @('.yml', '.yaml') } | Sort-Object Name)
Assert-True ($workflowFiles.Count -gt 0) "there are workflow files to check ($($workflowFiles.Count) found)"

$allJobs = @()
foreach ($wf in $workflowFiles) {
    $jobs = Get-WorkflowJobTimeouts -Path $wf.FullName
    Assert-True ($jobs.Count -gt 0) "$($wf.Name) declares at least one job"
    foreach ($job in $jobs) {
        $allJobs += [pscustomobject]@{ File = $wf.Name; Name = $job.Name; Timeout = $job.Timeout }
        Assert-True ($null -ne $job.Timeout) "$($wf.Name): job '$($job.Name)' declares timeout-minutes"
        if ($null -ne $job.Timeout) {
            Assert-True ($job.Timeout -ge 1 -and $job.Timeout -le $maxAllowedMinutes) `
                "$($wf.Name): job '$($job.Name)' caps at $($job.Timeout)m, inside 1..$maxAllowedMinutes"
        }
    }
}

# ------------------------------------------------------------------------------------------------
Write-Host "== the suites cap stays under ship-pr's registration wait ==" -ForegroundColor Cyan

# DERIVED FROM BOTH FILES, HARD-CODED IN NEITHER. Raising either number alone is exactly the change that
# would silently restore the incident: a cap at or above the wait times the job out at the same moment
# the shipping session stops waiting, so ship-pr still reads "never registered" rather than a red check
# with a job log behind it.
$shipPr = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\release\ship-pr.ps1') -Raw
$waitMatch = [regex]::Match($shipPr, '(?m)^\$maxRequiredWaitSec\s*=\s*(\d+)\s*$')
Assert-True ($waitMatch.Success) 'ship-pr.ps1 states its required-check registration wait as $maxRequiredWaitSec'

$suitesJob = @($allJobs | Where-Object { $_.File -eq 'ci.yml' -and $_.Name -eq 'suites' })
Assert-True ($suitesJob.Count -eq 1) 'ci.yml still has a job named suites'

if ($waitMatch.Success -and $suitesJob.Count -eq 1 -and $null -ne $suitesJob[0].Timeout) {
    $waitMinutes = [int]$waitMatch.Groups[1].Value / 60
    Assert-True ($suitesJob[0].Timeout -lt $waitMinutes) `
        "the suites cap ($($suitesJob[0].Timeout)m) is strictly under ship-pr's registration wait ($waitMinutes m), so a wedge goes red while the shipping session is still listening"
}

# ------------------------------------------------------------------------------------------------
Write-Host "== the scaffolders: every job composed for a consumer carries a cap ==" -ForegroundColor Cyan

# READ AS TEXT, DELIBERATELY. These runners are composed as PowerShell string arrays, so there is no YAML
# file to parse until a consumer has been scaffolded -- and running the scaffolders here would write into
# this repo's own .github/, which they refuse anyway. What is asserted is the property that survives that:
# every `runs-on:` line a scaffolder emits is followed, inside its own job block, by a `timeout-minutes:`
# line. A job gains its cap on the same line-run as its runner, so the two counts moving apart IS the
# regression.
$scaffolders = @(
    'scripts\task\adopt-ci-floor.ps1',
    'scripts\task\adopt-workflow-folder.ps1',
    'scripts\task\adopt-shopify-floor.ps1'
)

foreach ($rel in $scaffolders) {
    $path = Join-Path $repoRoot $rel
    Assert-True (Test-Path -LiteralPath $path) "$rel exists"
    if (-not (Test-Path -LiteralPath $path)) { continue }

    $text     = Get-Content -LiteralPath $path -Raw
    $runsOn   = @([regex]::Matches($text, '(?m)^\s*''?\s*runs-on:\s*\S+'))
    $timeouts = @([regex]::Matches($text, '(?m)^\s*''?\s*timeout-minutes:\s*(\d+)'))

    Assert-True ($runsOn.Count -gt 0) "$rel composes at least one job ($($runsOn.Count) runs-on lines)"
    Assert-True ($runsOn.Count -eq $timeouts.Count) `
        "$($rel): every composed job carries a cap -- $($runsOn.Count) runs-on against $($timeouts.Count) timeout-minutes"

    foreach ($m in $timeouts) {
        $v = [int]$m.Groups[1].Value
        Assert-True ($v -ge 1 -and $v -le $maxAllowedMinutes) "$($rel): a composed cap of $($v)m is inside 1..$maxAllowedMinutes"
    }
}

# THE BWJ MIRROR IS A REAL FILE RATHER THAN A COMPOSED ONE -- adopt-dkj-policy-bwj copies it into a
# consumer's .github/ verbatim -- so it is parsed the same way this repo's own workflows are. It is
# outside .github/workflows/ and would otherwise be reached by nothing above.
$asanaMirror = Join-Path $repoRoot 'plugins\dkj-policy\dkj-policy-bwj\templates\asana-mirror.yml'
Assert-True (Test-Path -LiteralPath $asanaMirror) 'the asana-mirror template exists'
if (Test-Path -LiteralPath $asanaMirror) {
    foreach ($job in (Get-WorkflowJobTimeouts -Path $asanaMirror)) {
        Assert-True ($null -ne $job.Timeout) "asana-mirror.yml: job '$($job.Name)' declares timeout-minutes"
        if ($null -ne $job.Timeout) {
            Assert-True ($job.Timeout -ge 1 -and $job.Timeout -le $maxAllowedMinutes) `
                "asana-mirror.yml: job '$($job.Name)' caps at $($job.Timeout)m, inside 1..$maxAllowedMinutes"
        }
    }
}

# ------------------------------------------------------------------------------------------------
Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
