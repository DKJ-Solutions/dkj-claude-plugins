<#
.SYNOPSIS
    Gate: is the ALWAYS-ON DOCUMENT PATH -- CLAUDE.md plus everything it '@'-imports -- inside this
    repo's budget, and did this branch grow it? (issue #2037)

.DESCRIPTION
    THE HOLE THIS CLOSES. measure-always-on.ps1 has reported the size of this path since August 2026
    and reaches no verdict about it, deliberately (issue #861). Every measurable consumer went over
    100,000 B anyway -- the source repo included, and it is the smallest of the four. That is the
    finding Dave's request of September 16, 2026 comes off: MEASUREMENT WITHOUT A BOUND DOES NOT HOLD A
    LINE. This is the bound. It still judges no block of prose; it judges one total.

    IT ADDS NO RULE OF ITS OWN. Every decision is in always-on-budget-lib.ps1 -- the ceiling, the
    ratchet, the baseline file and the verdict -- so the three carriers (this script run locally from
    open-pr, this script run in CI, and the SessionStart hook) cannot drift into describing the same
    path differently. This file is the printing and the exit code.

    A RATCHET, NOT A CLIFF. Over the ceiling, the limit is the recorded baseline and the gate refuses
    GROWTH; at or under it, the limit is the ceiling and the gate refuses CROSSING. The baseline falls
    on its own whenever a run measures less, and rises only under -Raise with a reason. So a repo that
    is over today converges on the ceiling instead of meeting a red gate on day one -- which is the gate
    that gets -Skip'ped once and never obeyed again.

    THE TERM A CI RUNNER CANNOT SEE IS CARRIED, NOT DROPPED. A consumer's path reaches its orchestrator
    persona through an absolute '~/.claude/plugins/marketplaces/...' import: 30,267 B, 27.7% of the
    source repo's own path. A CI runner has no marketplace clone, so that import does not resolve there
    and a naive total would read 30,267 B lower in CI than locally for the very same commit. The
    baseline therefore records every document's size by its import target, and a run that cannot resolve
    one takes the recorded figure and SAYS SO. A term that is neither measurable nor recorded is
    reported as unmeasured and never counted as zero.

    RUN IT whenever you want the answer early -- it writes nothing without -Record or -Raise:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-always-on-budget.ps1

    Exit 0 when the path is inside its limit, 1 when this branch pushed it past one.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite and the SessionStart hook. A consumer never types this:
    the root is resolved dual-context like every other shared script.

.PARAMETER RootDocument
    The root of the always-on path. Defaults to CLAUDE.md in the repo root; the suite points it at a
    fixture tree.

.PARAMETER Record
    Write the measurement back as the new baseline where the verdict says it should be lowered (or where
    there is no baseline yet). The LOCAL carrier passes this -- open-pr.ps1, which then commits the file
    alongside the branch's own document. CI and the session hook never do: a read-only carrier that
    rewrote the ratchet's own memory would be the one thing able to raise it without anybody saying so.

.PARAMETER Raise
    Deliberately raise the baseline to what this run measured. Requires -Reason, and the reason is
    written into the file: a raise is the one move that loosens the ratchet, so it has to leave a
    sentence behind that a reviewer can argue with.

.PARAMETER Reason
    Why the baseline is being raised. Refused as empty, because "" in that field is indistinguishable
    from a raise nobody thought about.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-always-on-budget.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-always-on-budget.ps1 -Raise -Reason "the new routing table is on the path by design; #2101 moves its evidence to the lens"
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [string]$RootDocument = '',
    [switch]$Record,
    [switch]$Raise,
    [string]$Reason = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NO SOURCE-REPO GUARD, deliberately, and for the reason source-repo-guard-lib.ps1's own header gives
# for check-unfolded-entry and check-script-contract: a SessionStart hook invokes this from
# '${CLAUDE_PLUGIN_ROOT}/scripts/lint/' against the current repo, so Assert-OwnCopy would refuse it --
# and thereby the hook -- at every session start in the source repo.

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# THE ROOT COMES FROM ONE DEFINITION (#1422). Dot-sourced guarded, so a mirror built before this lib
# existed degrades rather than throwing.
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

$repoRoot = ''
if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    $repoRoot = Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) {
    $repoRoot = $RootOverride
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $repoRoot = $env:CLAUDE_PROJECT_DIR
}
if (-not $repoRoot) {
    Write-Host '[SKIP]  no repo root could be resolved -- the always-on budget was not measured.'
    exit 0
}
$repoRoot = [System.IO.Path]::GetFullPath($repoRoot)

# repo-config.ps1 FIRST and optional, exactly as check-unfolded-entry and check-branch-entry load it:
# the Get-AlwaysOnBudget seam lives there, and a repo that states none runs on the built-in ceiling.
# Loaded BEFORE the lib so the seam is in the function table by the time Resolve-AlwaysOnBudget probes
# for it -- and note that the lib's resolver is deliberately NOT called Get-AlwaysOnBudget, or the probe
# would find itself. See its header.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in ceiling is used." }
}

. (Join-Path $PSScriptRoot '..\lib\always-on-budget-lib.ps1')

if (-not $RootDocument) { $RootDocument = Join-Path $repoRoot 'CLAUDE.md' }
if (-not (Test-Path -LiteralPath $RootDocument -PathType Leaf)) {
    # NOT A REFUSAL. A repo with no CLAUDE.md has no always-on path to bound, and every consumer of this
    # workflow that has one arrived at it through specialists-init rather than being born with it.
    Write-Host "[SKIP]  no root document at $($RootDocument -replace '\\', '/') -- there is no always-on path to bound."
    exit 0
}

if ($Raise -and -not $Reason.Trim()) {
    Write-Host '[ERROR] -Raise needs -Reason: a raise is the one move that loosens the ratchet, so it has to' -ForegroundColor Red
    Write-Host '        leave a sentence behind that a reviewer can argue with. Nothing was written.' -ForegroundColor Red
    exit 1
}

$budget   = Resolve-AlwaysOnBudget
$baseline = Read-AlwaysOnBaseline -RepoRoot $repoRoot

if ($baseline -and $baseline.Unreadable) {
    # A file from a NEWER schema. Reported and NOT overwritten: re-recording over a file this copy did
    # not understand would destroy the only record of where the repo has been.
    Write-Host "[ERROR] the baseline at $((Get-AlwaysOnBaselinePath -RepoRoot $repoRoot) -replace '\\', '/') cannot be read: $($baseline.Unreadable)." -ForegroundColor Red
    Write-Host '        Nothing was measured and nothing was written.' -ForegroundColor Red
    exit 1
}

$measurement = Get-AlwaysOnMeasurement -RepoRoot $repoRoot -RootDocument $RootDocument -Baseline $baseline
$verdict     = Get-AlwaysOnBudgetVerdict -Measurement $measurement -Budget $budget -Baseline $baseline

# ----------------------------------------------------------------- the figure

$totalStr    = Format-MeasuredBytes $verdict.Total
$budgetStr   = Format-MeasuredBytes $verdict.Budget
$tokens      = Format-MeasuredBytes (ConvertTo-EstimatedTokens -Bytes $verdict.Total)

Write-Host ''
Write-Host "  always-on path: $totalStr B (~$tokens tokens, an ESTIMATE) against a budget of $budgetStr B" -ForegroundColor Cyan
Write-Host "    root: $(($RootDocument.Replace($repoRoot, '.')) -replace '\\', '/'), $(@($measurement.Measured).Count) document(s) measured" -ForegroundColor DarkGray

# THE UNIT, STATED WHEREVER IT COULD BE MISTAKEN. The ratchet compares LF bytes so a CRLF checkout and a
# CI runner reach the same number (inbound #1162); the figure a session actually LOADS is the on-disk
# one, and it is named here rather than left for somebody to rediscover against `wc -c`.
if ($measurement.DiskBytes -ne $measurement.MeasuredBytes) {
    Write-Host ("    measured in LF bytes, which is what the repository stores -- on disk here it is " +
                "$(Format-MeasuredBytes $measurement.DiskBytes) B (CRLF).") -ForegroundColor DarkGray
}

foreach ($c in @($verdict.Carried)) {
    Write-Host "    carried from the baseline, not measurable here: $(Format-MeasuredBytes $c.Bytes) B  $($c.Key)" -ForegroundColor DarkGray
}
if (@($verdict.Carried).Count -gt 0) {
    Write-Host '      (plugin payload -- no marketplace clone on this machine. It is not this branch to change,' -ForegroundColor DarkGray
    Write-Host '       and a local run re-measures and re-records it.)' -ForegroundColor DarkGray
}

# UNMEASURED IS NEVER ZERO, AND IT IS SAID LOUDLY. A document on the path that this run could not read
# and the baseline has no figure for is cost the total below does not contain -- so the total is a floor
# rather than the answer, and a reader who does not know that is reading a healthier path than exists.
foreach ($u in @($verdict.Unmeasured)) {
    Write-Host "  [WARN]  not measured and not recorded: '$($u.Target)'" -ForegroundColor Yellow
    Write-Host "            imported by $((($u.ImportedBy) -replace '\\', '/'))" -ForegroundColor Yellow
}
if (@($verdict.Unmeasured).Count -gt 0) {
    Write-Host '          Its cost is NOT in the total above, so that total is a floor. Run this once on a' -ForegroundColor Yellow
    Write-Host '          machine where the import resolves, so the baseline records a figure CI can carry.' -ForegroundColor Yellow
}

# ----------------------------------------------------------------- the verdict

$baselinePath = (Get-AlwaysOnBaselinePath -RepoRoot $repoRoot)
$baselineRel  = ($baselinePath.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/')

if ($Raise) {
    # A RAISE IS NOT A VERDICT, IT IS A WRITE. It is honoured whatever the state -- including a state
    # this gate would have passed -- because the caller has said in words why the path is bigger now.
    $null = Write-AlwaysOnBaseline -RepoRoot $repoRoot -Measurement $measurement -Reason $Reason.Trim()
    Write-Host "[OK]    baseline RAISED to $totalStr B in $baselineRel -- reason recorded:" -ForegroundColor Yellow
    Write-Host "          $($Reason.Trim())" -ForegroundColor Yellow
    Write-Host '        Commit that file with this branch, so the raise is reviewed with the change that needed it.' -ForegroundColor Yellow
    exit 0
}

switch ($verdict.State) {

    'first-run' {
        Write-Host "[OK]    no baseline yet -- this run establishes one at $totalStr B." -ForegroundColor Green
        if ($verdict.Total -gt $verdict.Budget) {
            Write-Host "        That is $(Format-MeasuredBytes ($verdict.Total - $verdict.Budget)) B over the budget, and it is NOT a refusal." -ForegroundColor Yellow
            Write-Host '        The ratchet holds the path where it is and lets it fall: from here a branch may shrink' -ForegroundColor Yellow
            Write-Host '        this path or hold it, and growing it is what gets refused.' -ForegroundColor Yellow
        }
        if (-not $Record) {
            Write-Host "        Nothing was written -- pass -Record (open-pr does) to create $baselineRel." -ForegroundColor DarkGray
        }
    }

    'inside' {
        Write-Host "[OK]    inside the budget -- $(Format-MeasuredBytes $verdict.Headroom) B of headroom." -ForegroundColor Green
    }

    'over-holding' {
        Write-Host "[OK]    over the budget by $(Format-MeasuredBytes ($verdict.Total - $verdict.Budget)) B, and NOT growing." -ForegroundColor Green
        Write-Host "        The ratchet holds this path at its recorded $(Format-MeasuredBytes $verdict.Baseline) B until it falls." -ForegroundColor DarkGray
    }

    'over-shrink' {
        Write-Host "[OK]    over the budget, and this branch SHRANK the path by $(Format-MeasuredBytes ([math]::Abs($verdict.Delta))) B." -ForegroundColor Green
        Write-Host "        New low-water mark: $totalStr B (was $(Format-MeasuredBytes $verdict.Baseline) B)." -ForegroundColor Green
    }

    'crossing' {
        Write-Host "[ERROR] this branch takes the always-on path OVER its budget: $totalStr B against $budgetStr B." -ForegroundColor Red
        Write-Host "        That is $(Format-MeasuredBytes ($verdict.Total - $verdict.Budget)) B too far, and every session pays it before a single" -ForegroundColor Red
        Write-Host '        assignment is given.' -ForegroundColor Red
    }

    'over-growing' {
        Write-Host "[ERROR] this branch GROWS an already-over-budget always-on path by $(Format-MeasuredBytes $verdict.Delta) B:" -ForegroundColor Red
        Write-Host "          $(Format-MeasuredBytes $verdict.Baseline) B recorded -> $totalStr B now, against a budget of $budgetStr B." -ForegroundColor Red
        Write-Host '        While a repo is over the ceiling the rule is that the path may not grow. It falls or it holds.' -ForegroundColor Red
    }
}

if (-not $verdict.Ok) {
    # THE REFUSAL NAMES THE DESTINATION, because a ceiling with no destination is a red check nobody can
    # clear -- and this repo has already proved each of these four moves on its own always-on path.
    Write-Host ''
    Write-Host '        Four places this weight goes, in the order they pay:' -ForegroundColor Yellow
    Write-Host '          1. Procedure a plugin already ships ON DEMAND -- delete it and leave a pointer.' -ForegroundColor Yellow
    Write-Host '          2. Layer-specific detail -> .claude/rules/*.md with paths:. Only for detail that is' -ForegroundColor Yellow
    Write-Host '             inert until such a file is open: a paths:-scoped rule is LOST after a /compact' -ForegroundColor Yellow
    Write-Host '             until a matching file is read again.' -ForegroundColor Yellow
    Write-Host '          3. Evidence, measurement and declined-option history -> the owning specialist''s lens,' -ForegroundColor Yellow
    Write-Host '             or a skill page. The decision belongs on the always-on path; the evidence for it' -ForegroundColor Yellow
    Write-Host '             does not.' -ForegroundColor Yellow
    Write-Host '          4. Repo-specific craft detail for one specialist -> that specialist''s lens.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '        Where the growth is deliberate and the path is genuinely bigger now, raise the baseline' -ForegroundColor Yellow
    Write-Host '        on the record instead of working around the gate:' -ForegroundColor Yellow
    Write-Host '          check-always-on-budget.ps1 -Raise -Reason "<why this path is bigger now>"' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "        Where the mass sits: measure-always-on.ps1 -Depth 3" -ForegroundColor DarkGray
    exit 1
}

if ($Record -and $verdict.ShouldRecord) {
    $null = Write-AlwaysOnBaseline -RepoRoot $repoRoot -Measurement $measurement -Reason ''
    Write-Host "        Recorded in $baselineRel." -ForegroundColor DarkGray
}

Write-Host ''
exit 0
