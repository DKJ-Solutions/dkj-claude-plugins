<#
.SYNOPSIS
    Measures what a SKILL costs and how fast it is: token cost per skill (pass 1) and the wall-clock
    of the script it drives, in a DECLARED read-only mode only (pass 2).

.DESCRIPTION
    A skill's description is paid by every session in every consumer whether it fires or not; its
    body is paid per firing. Nothing in this repo measured either until this script existed, and the
    growth was real: 7 skill descriptions cost ~1.245 tok at v2.10.0, while 18 across the two enabled
    plugins cost ~3.650 at v4.17.0 -- nearly 3x, never re-measured. See the performance lens.

    IT OWNS NO MEASUREMENT OF ITS OWN, DELIBERATELY. Pass 1 drives `claude plugin details`, whose
    figures come from the count_tokens API for the active model. A second, file-size-based estimate
    would produce a number that disagrees with the authoritative one, which is exactly what the
    performance lens forbids ("do not estimate from file sizes"). This script parses, ranks, compares
    against a stored baseline, and states its own provenance. It computes no token count.

    WHAT IT IS NOT. It does not check a skill's correctness -- frontmatter, dead links, parameter
    coverage and the printed install commands all belong to check-plugin-integrity.ps1, which has its own
    numbered checks for each. Duplicating one here would produce two verdicts on one subject.
    (The count is deliberately not stated: it said 26 while that gate ran 35, and a wrong number reads as
    authority -- the same reason CLAUDE.md stopped stating its gate counts. Read it off the gate.)

    IT IS NOT A GATE AND MUST NOT BECOME ONE. open-pr already spends ~10s of lint plus ~170s of
    suites, and CI's lint-en-tests has a median of 7m 23s and blocks every merge. A skill's cost
    changes on the scale of releases, not commits, so this runs on demand.

    PASS 1 -- COST. Free, seconds, no model call. Per skill: always-on, on-invoke, share of its
    plugin's always-on total, and the delta against the baseline. Two rules from the performance lens
    are enforced rather than remembered:
      - It NAMES THE COPY IT MEASURED. `claude plugin details` prices the INSTALLED PAYLOAD -- the
        extracted copy under ~/.claude/plugins/cache/ that a session actually loads -- and not this
        tree. It is not the marketplace clone either, which is what this line said until #1812:
        measured September 10, 2026 (CLI 2.1.267), the command reported Skills (17) for dkj-policy
        while the clone's copy of that same version carried 18. When payload and tree differ the
        difference is queued cost arriving at the next release, not error to smooth away, and the
        report says so.
      - It LEAVES THE FREQUENCY COLUMN EMPTY. An on-invoke figure without a firing frequency is not a
        cost, and a guessed frequency is worse than a blank one.

    THE PARSE IS THE WEAK POINT, AND IT FAILS LOUDLY. The per-component table is human-formatted
    output whose shape the CLI owns. Two cross-checks run before any figure is reported: the parsed
    rows must sum to the printed Always-on total within tolerance, and every skill named in the
    component inventory must have produced a row. Either one failing is an [ERROR] and no table is
    printed for that plugin -- a plausible wrong number is worse than a refusal, the same reasoning
    behind round-tally.measure.ps1's UNCLASSIFIED rule.

    FAILING LOUDLY IS ONLY A VIRTUE WHERE THE FAILURE IS REAL, and this refused two of six enabled
    plugins over output that was perfectly intact (#1771). The CLI prints no per-component table at all
    for a plugin whose inventory declares no skills and no agents, so an empty table is now judged
    against that inventory instead of on its own: no rows AND something owed is still the [ERROR], no
    rows and nothing owed is an [INFO] naming why, and an inventory that could not be read is the
    [ERROR] this check was written for.

    IT ALSO SAYS WHAT THE FIGURES DO NOT COVER. The inventory's 'Agents (N)' counts only defs found by
    convention in a plugin's default agents\ directory; a def named by the manifest's 'agents' key loads
    in a session and is counted as 0 -- measured with a two-plugin control against Claude Code 2.1.267.
    Every always-on figure here is therefore SKILLS ONLY for such a plugin, and the report says so
    rather than letting a 100% share imply the skills are the whole cost.

    Two notations appear in one table and both are handled: '~3.031' is 3031 (the dot is a thousands
    separator) while '~1.3k' is 1300 (a k suffix on a decimal). A parser that read the first as 3.031
    would under-report by a factor of a thousand and still look plausible, which is why the sum check
    exists rather than being a nicety.

    PASS 2 -- SPEED. Opt-in via -IncludeSpeed. It times the script behind a skill n times and reports
    min/median/max with the machine state, following the .measure.ps1 convention already in
    scripts/tests/.

    IT WILL NOT RUN A SCRIPT THAT HAS NO DECLARED READ-ONLY MODE, and that is the whole safety model.
    Timing the script behind `cut-release` by invoking it would cut a release. So a script is timed
    only where its registration in scripts/lib/shared-scripts-lib.ps1 carries a MeasureArgs key
    naming a read-only invocation; everything else is reported as not measured, with the reason. The
    declaration lives beside the registration rather than in a table here, because this repo has
    already paid for the other shape: a second hand-written list is one a new entry falls out of
    silently (the accumulation shape of #275/#331, recorded in that registry's own comments).

    Pass 2 needs that registry and so runs only where it exists. In a consumer it reports [SKIP] with
    the reason; pass 1 works everywhere, since it needs nothing but the `claude` CLI.

    Read-only with respect to this repo unless -UpdateBaseline is passed, which rewrites the baseline
    file and nothing else.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Plugin
    Which plugin(s) to measure, as '<name>@<marketplace>' or just '<name>'. Defaults to the plugins
    enabled for this repo, read from the settings chain -- i.e. what a session here actually pays.

.PARAMETER Skill
    Limit the report to these skill names. Default: every skill the plugin's inventory names.

.PARAMETER IncludeSpeed
    Also run pass 2 (wall-clock). Off by default because it executes scripts, and it executes only
    the ones whose registration declares a read-only invocation.

.PARAMETER Runs
    Timed runs per script in pass 2. Default 3, the smallest n that yields a median.

.PARAMETER BaselinePath
    The cost baseline to compare against. Default: scripts/maintenance/baselines/skill-cost.json.

.PARAMETER UpdateBaseline
    Write the measured cost figures to the baseline instead of only comparing against it. Token
    counts come from an API and not from this machine, so the file is machine-independent and
    committable; pass-2 timings are machine-dependent and are deliberately NOT stored.

.PARAMETER OutFile
    Also write the markdown report to this path, for pasting into a lens or a dossier.

.EXAMPLE
    ./scripts/maintenance/measure-skill.ps1

.EXAMPLE
    ./scripts/maintenance/measure-skill.ps1 -Plugin dkj-policy -Skill cut-release

.EXAMPLE
    ./scripts/maintenance/measure-skill.ps1 -IncludeSpeed -Runs 5 -OutFile report.md
#>
param(
    [string[]]$Plugin,
    [string[]]$Skill,
    [switch]$IncludeSpeed,
    [int]$Runs = 3,
    [string]$BaselinePath,
    [switch]$UpdateBaseline,
    [string]$OutFile,
    [string]$RootOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
# The parsing and formatting half: the two token notations, the details parser and its two
# cross-checks. It lives in a lib so a suite can pin it against captured output without shelling out
# to `claude` -- the parse is the one fragile thing here, and an unpinnable parser is an unpinned one.
. (Join-Path $PSScriptRoot '..\lib\measure-skill-lib.ps1')

$script:errors = 0
$script:infos  = 0

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same three-source precedence, but it names git's exit code and stderr instead of dying on
# $null.Trim() where git answers nothing.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'measure-skill.ps1' -OverrideName '-RootOverride'

if (-not $BaselinePath) {
    $BaselinePath = Join-Path $repoRoot 'scripts\maintenance\baselines\skill-cost.json'
}

# A comma-separated value is split (see the lib): `-File <script> -Skill a,b,c` hands the whole of
# 'a,b,c' over as ONE element, because -File does not parse PowerShell syntax for what follows it.
$Plugin = Expand-ListArgument -Value $Plugin
$Skill  = Expand-ListArgument -Value $Skill

# ConvertTo-TokenCount, Format-Tok/Pct/Sec and the parser itself all come from measure-skill-lib.ps1.

# BOM-LESS, LF -- the repo convention for generated files, and not cosmetic here. In PowerShell 5.1
# `Set-Content -Encoding utf8` writes a BOM, and the first baseline this script produced carried one:
# a JSON file the lint gate scans for exactly that, and a byte some parsers hand back as part of the
# first key. Same writer the shared-scripts generator uses, for the same reason.
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $normalized = ($Content -replace "`r`n", "`n")
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

# --- run `claude plugin details`; the parsing itself lives in the lib ----------------------------
function Get-PluginDetails {
    param([Parameter(Mandatory = $true)][string]$PluginId)

    $res = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'details', $PluginId)
    $lines = @($res.Output | ForEach-Object { [string]$_ })
    if ($res.ExitCode -ne 0) {
        return [pscustomobject]@{
            Ok     = $false
            Reason = "claude plugin details exited $($res.ExitCode)"
            Raw    = $lines
        }
    }

    $parsed = Read-PluginDetailsOutput -Lines $lines
    return [pscustomobject]@{
        Ok                = $true
        Version           = $parsed.Version
        AlwaysOnTotal     = $parsed.AlwaysOnTotal
        InventoryCounts   = $parsed.InventoryCounts
        RowProducingCount = $parsed.RowProducingCount
        InventorySkills   = $parsed.InventorySkills
        Rows              = $parsed.Rows
        Raw               = $lines
    }
}

# Get-DeclaredAgentCount lives in measure-skill-lib.ps1, dot-sourced above -- it reads a file and returns
# an object, with no I/O of its own, which is that lib's whole remit. It sat here first and had no test at
# all: the suite dot-sources the lib and never this script, so reverting the function and both its call
# sites would have failed nothing.

# The two cross-checks, reported. The judging itself is in the lib (Get-PluginDetailsParseProblems), so
# the suite can pin it without a `claude` on the machine; refusing on it is this function's half.
function Test-DetailsParse {
    param(
        [Parameter(Mandatory = $true)]$Details,
        [Parameter(Mandatory = $true)][string]$PluginId
    )

    $problems = @(Get-PluginDetailsParseProblems -Details $Details)
    if ($problems.Count -gt 0) {
        # The line count is here so the reader can tell the two failure shapes apart without running
        # anything: a handful of lines means the command said something else entirely (not installed,
        # marketplace unreachable), while a full page of them means the format moved under the parser.
        Write-Failure "$PluginId -- the output of 'claude plugin details' did not parse as expected ($(@($Details.Raw).Count) line(s) came back), so no figures are reported for it. The CLI owns this format and may have changed it; re-run the command yourself and repair the parser against what it prints. Detail: $($problems -join '; ')."
        return $false
    }
    return $true
}

# --- which plugins ------------------------------------------------------------------------------
function Resolve-PluginIds {
    param([string[]]$Requested, [string]$MeasureRoot)

    if ($Requested -and @($Requested).Count -gt 0) { return @($Requested) }

    $enabled = Get-EnabledPlugins -RepoRoot $MeasureRoot
    if (@($enabled.Ids).Count -eq 0) {
        Write-Failure "no plugin was named and none is enabled for this repo ($($enabled.Summary)), so there is nothing to measure. Pass -Plugin '<name>@<marketplace>'."
        return @()
    }
    Write-Info "no -Plugin given, so measuring what a session HERE actually pays: the $(@($enabled.Ids).Count) plugin(s) enabled for this repo, per $($enabled.Summary)."
    return @($enabled.Ids)
}

# --- baseline -----------------------------------------------------------------------------------
function Read-Baseline {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    } catch {
        Write-Info "the baseline at $Path did not parse ($($_.Exception.Message)) -- reporting without a delta."
        return $null
    }
}

function Get-BaselineEntry {
    param($Baseline, [string]$Key)
    if ($null -eq $Baseline) { return $null }
    if (-not ($Baseline.PSObject.Properties.Name -contains $Key)) { return $null }
    return $Baseline.$Key
}

function Format-Delta {
    param($Now, $Then)
    if ($null -eq $Then -or $null -eq $Now) { return 'no baseline' }
    $d = $Now - $Then
    if ($d -eq 0) { return 'unchanged' }
    if ($d -gt 0) { return "+$(Format-Tok $d)" }
    return "-$(Format-Tok ([math]::Abs($d)))"
}

# ================================================================================================
Write-Host ''
Write-Host 'measure-skill -- what a skill costs, and how fast the script behind it runs' -ForegroundColor Cyan
Write-Host ''

$pluginIds = Resolve-PluginIds -Requested $Plugin -MeasureRoot $repoRoot
$report    = New-Object System.Collections.Generic.List[string]
$measured  = [ordered]@{}
$baseline  = Read-Baseline -Path $BaselinePath

$report.Add('## measure-skill report')
$report.Add('')
$report.Add('Measured with `claude plugin details` (the count_tokens API for the active model), not estimated from file sizes.')
$report.Add('')

foreach ($id in $pluginIds) {
    $pluginId = $id
    if ($pluginId -notmatch '@') { $pluginId = "$pluginId@dkj-claude-plugins" }
    $shortName = ($pluginId -split '@')[0]

    Write-Host "Plugin: $pluginId" -ForegroundColor White

    $details = Get-PluginDetails -PluginId $pluginId
    if (-not $details.Ok) {
        Write-Failure "$pluginId -- $($details.Reason). Is the plugin installed, and is its marketplace reachable?"
        continue
    }
    if (-not (Test-DetailsParse -Details $details -PluginId $pluginId)) { continue }

    # WHICH COPY WAS MEASURED. The command prices the INSTALLED PAYLOAD -- the extracted copy a session
    # loads -- and not this tree, and not the marketplace clone either (#1812).
    $declared   = Get-DeclaredAgentCount -RepoRoot $repoRoot -ShortName $shortName
    $treeVersion = $declared.Version
    if ($treeVersion -and $details.Version -and $treeVersion -ne $details.Version) {
        Write-Info "$pluginId -- measured the INSTALLED PAYLOAD at v$($details.Version) while this tree is at v$treeVersion. The difference is queued cost that arrives at the next plugin update, not error: every figure below is what a session loads today."
    }

    # WHAT THE FIGURES DO NOT COVER, said before any of them is printed. A def named by the manifest's
    # 'agents' key loads in a session -- measured with a two-plugin control, Claude Code 2.1.267 -- and
    # the inventory counts it as 0, so its description is always-on cost that no figure below contains.
    # Left unsaid, the share reads as 'the skills are effectively ALL of this plugin's always-on cost'
    # over a plugin whose agents are unpriced, and 'Agents (0)' reads as 'this plugin ships none' (#1771).
    #
    # AND THE NUMBER IS THE TREE'S, so it is only stated where the tree is the copy that was measured.
    # $declared.AgentCount comes from the manifest on disk while every figure here comes from the
    # installed payload, and those are different versions often enough to have their own [INFO] one line
    # up -- which says 'every figure below is what a session loads today'. Asserting a count off the other
    # copy underneath that sentence contradicts it. So where the two versions differ, the caveat keeps the
    # part that is version-independent (the inventory counts no key-declared agent) and drops the count.
    $inventoryAgents = $null
    if ($details.InventoryCounts -and $details.InventoryCounts.Contains('Agents')) {
        $inventoryAgents = [int]$details.InventoryCounts['Agents']
    }
    $agentsUncounted = ($declared.AgentCount -gt 0 -and $inventoryAgents -eq 0)
    $countIsMeasured = ($treeVersion -and $details.Version -and $treeVersion -eq $details.Version)
    $uncountedAgents = if ($agentsUncounted -and $countIsMeasured) { $declared.AgentCount } else { 0 }
    $agentPhrase = if ($uncountedAgents -gt 0) { "$uncountedAgents agent def(s)" } else { 'agent def(s)' }

    # A plugin the inventory declares nothing tabulatable for. Not a parse failure -- the cross-check
    # above has already cleared it -- and not something the skills report can say anything about, so it
    # is named and skipped rather than run through a table of zeroes. It carries the uncounted-agent
    # reason itself, rather than letting the caveat below print first and promise figures that never come.
    if (@($details.Rows).Count -eq 0) {
        $why = if ($agentsUncounted) {
            "it ships no skills, and its $agentPhrase are declared by path, which this inventory counts as 0 though they load in a session"
        } else {
            'it declares no skills and no agents'
        }
        Write-Info "$pluginId v$($details.Version) -- no per-component table, because $why. Nothing to measure here; the CLI's format is intact."
        continue
    }

    if ($agentsUncounted) {
        Write-Info "$pluginId -- the inventory reports 'Agents (0)' while the manifest declares $agentPhrase by path. Those load in a session and this inventory does not count them, so every always-on figure below -- the plugin's own printed total included -- is SKILLS ONLY and understates what the plugin costs. Read the 0 as 'not counted here', never as 'ships none'."
    }

    $skillRows = @($details.Rows | Where-Object { $details.InventorySkills -contains $_.Component })
    if ($Skill -and @($Skill).Count -gt 0) {
        $skillRows = @($skillRows | Where-Object { $Skill -contains $_.Component })
    }
    $skillRows = @($skillRows | Sort-Object -Property AlwaysOn -Descending)

    $skillAlwaysOn = 0
    if ($skillRows.Count -gt 0) {
        $skillAlwaysOn = ($skillRows | Measure-Object -Property AlwaysOn -Sum).Sum
    }
    $sharePct = 0
    if ($details.AlwaysOnTotal -gt 0) {
        $sharePct = [math]::Round(100.0 * $skillAlwaysOn / $details.AlwaysOnTotal, 1)
    }

    # A share AT OR ABOVE 100% is arithmetic, not a defect, and saying so is the point. Each row is
    # rounded to two significant figures, so a plugin whose always-on cost IS its skills sums to just
    # over the printed total. Printing '101%' bare would read as a bug in the very tool that exists to
    # be trusted about figures, so the reading travels with the number.
    #
    # AND 'ALL OF IT' IS A CLAIM ABOUT THE PRINTED TOTAL, not about the plugin, wherever agents go
    # uncounted (#1771). Asserting the skills are effectively the whole cost one line under a caveat
    # saying the total excludes 15 agent descriptions is a contradiction the reader has to resolve --
    # so the share is stated against what the total actually covers.
    $shareNote = ''
    if ($sharePct -ge 100) {
        $shareNote = ' -- rounding puts the rows at or just above the printed total, i.e. the skill descriptions account for effectively ALL of this plugin''s always-on cost'
        if ($agentsUncounted) {
            $descPhrase = if ($uncountedAgents -gt 0) { "$uncountedAgents agent description(s)" } else { 'agent description(s)' }
            $shareNote = ' -- rounding puts the rows at or just above the printed total, i.e. the skill descriptions account for effectively all of the total PRINTED here; the plugin also pays for ' +
                "$descPhrase that this inventory does not count"
        }
    }

    Write-Coverage -Category 'skills' -Checked $skillRows.Count -Of @($details.Rows).Count `
        -Note "$pluginId v$($details.Version): the skills carry $(Format-Tok $skillAlwaysOn) of the plugin's $(Format-Tok $details.AlwaysOnTotal) always-on tokens ($(Format-Pct $sharePct)%)$shareNote"
    Write-Ok 'parse cross-checks passed (rows sum to the printed total within tolerance; every inventory skill produced a row).'

    if ($skillRows.Count -eq 0) {
        Write-Info "$pluginId -- no skill matched, so there is nothing to report for it."
        continue
    }

    $report.Add("### ``$pluginId`` v$($details.Version)")
    $report.Add('')
    $report.Add("The skills carry **$(Format-Tok $skillAlwaysOn)** of this plugin's **$(Format-Tok $details.AlwaysOnTotal)** always-on tokens (**$(Format-Pct $sharePct)%**)$shareNote. Always-on is paid by every session whether the skill fires or not; on-invoke is paid per firing.")
    $report.Add('')
    $report.Add('| skill | always-on | vs. baseline | on-invoke | share of plugin always-on | fires how often |')
    $report.Add('|---|---:|---:|---:|---:|---|')

    foreach ($row in $skillRows) {
        $key  = "$shortName/$($row.Component)"
        $prev = Get-BaselineEntry -Baseline $baseline -Key $key
        $prevAlwaysOn = $null
        if ($null -ne $prev) { $prevAlwaysOn = $prev.AlwaysOn }
        $delta = Format-Delta -Now $row.AlwaysOn -Then $prevAlwaysOn

        $rowShare = 0
        if ($details.AlwaysOnTotal -gt 0) {
            $rowShare = [math]::Round(100.0 * $row.AlwaysOn / $details.AlwaysOnTotal, 1)
        }

        Write-Host ("    {0,-24} always-on {1,7}  {2,-12} on-invoke {3,8}  {4,5}%" -f `
            $row.Component, (Format-Tok $row.AlwaysOn), $delta, (Format-Tok $row.OnInvoke), (Format-Pct $rowShare))

        # The frequency column is left EMPTY on purpose: an on-invoke figure without a firing
        # frequency is not a cost, and a guessed frequency is worse than a blank one.
        $report.Add("| ``$($row.Component)`` | $(Format-Tok $row.AlwaysOn) | $delta | $(Format-Tok $row.OnInvoke) | $(Format-Pct $rowShare)% | |")

        $measured[$key] = [ordered]@{
            AlwaysOn = $row.AlwaysOn
            OnInvoke = $row.OnInvoke
            Version  = $details.Version
        }
    }
    $report.Add('')
    Write-Host ''
}

# --- pass 2: speed ------------------------------------------------------------------------------
if ($IncludeSpeed) {
    Write-Host 'Pass 2 -- wall-clock of the script behind a skill' -ForegroundColor White

    $registryLib = Join-Path $repoRoot 'scripts\lib\shared-scripts-lib.ps1'
    if (-not (Test-Path -LiteralPath $registryLib -PathType Leaf)) {
        Write-Skip 'pass 2 needs the shared-scripts registry (scripts\lib\shared-scripts-lib.ps1), which exists only in the repo that maintains these scripts. Pass 1 above needs nothing but the claude CLI and is complete.'
    } else {
        . $registryLib
        $pairs = @(Get-SharedScriptPairs -RepoRoot $repoRoot)

        # A LibOnly entry carries Skill = $null (nothing invokes it), and an entry point that declares
        # it has no page carries ''. Neither is a skill-backed script, so both fall out here.
        $inScope = @($pairs | Where-Object {
            $null -ne $_.Skill -and $_.Skill -ne '' -and
            ((-not $Skill) -or (@($Skill).Count -eq 0) -or ($Skill -contains $_.Skill))
        })
        # MeasureDeclared, not the args themselves: a script declared safe with NO arguments carries an
        # empty MeasureArgs, and testing the args would read that as undeclared and skip it.
        $timeable = @($inScope | Where-Object { $_.MeasureDeclared })
        $declined = @($inScope | Where-Object { -not $_.MeasureDeclared })

        Write-Coverage -Category 'timed scripts' -Checked $timeable.Count -Of $inScope.Count `
            -Note "$($declined.Count) skill-backed script(s) were NOT RUN because no read-only invocation is declared for them. A script is never invoked to time it unless its own registration says how to invoke it harmlessly -- timing cut-release by running it would cut a release"

        if ($declined.Count -gt 0) {
            $names = @($declined | ForEach-Object { $_.Skill }) | Sort-Object -Unique
            Write-Info "not measured, no declared read-only mode: $($names -join ', ')."
        }

        if ($timeable.Count -gt 0) {
            $report.Add('### Pass 2 -- wall-clock')
            $report.Add('')
            $report.Add("Each script run **$Runs** times in its declared read-only mode, on this machine, PowerShell $($PSVersionTable.PSVersion). A timing is a count too: the machine state belongs beside it.")
            $report.Add('')
            $report.Add('| skill | script | read-only invocation | n | min | median | max |')
            $report.Add('|---|---|---|---:|---:|---:|---:|')
        }

        foreach ($pair in $timeable) {
            $scriptPath = $pair.SourcePath
            if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                Write-Failure "$($pair.Skill) -- its registered source $($pair.SourceRel) is not on disk, so it cannot be timed."
                continue
            }
            $measureArgs = @()
            if ($null -ne $pair.MeasureArgs) { $measureArgs = @($pair.MeasureArgs) }
            $shown = 'no arguments'
            if ($measureArgs.Count -gt 0) { $shown = $measureArgs -join ' ' }

            $samples = @()
            for ($i = 1; $i -le $Runs; $i++) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $null = Invoke-NativeCapture -FilePath 'powershell' -Arguments (@('-NoProfile', '-File', $scriptPath) + $measureArgs)
                $sw.Stop()
                $samples += [math]::Round($sw.Elapsed.TotalSeconds, 2)
            }
            $sorted = @($samples | Sort-Object)
            $median = $sorted[[int][math]::Floor($sorted.Count / 2)]
            if ($sorted.Count % 2 -eq 0) {
                $median = [math]::Round((($sorted[$sorted.Count / 2 - 1] + $sorted[$sorted.Count / 2]) / 2), 2)
            }

            Write-Host ("    {0,-24} n={1}  min {2,6}s  median {3,6}s  max {4,6}s   ({5})" -f `
                $pair.Skill, $Runs, (Format-Sec $sorted[0]), (Format-Sec $median), (Format-Sec $sorted[-1]), $shown)
            $report.Add("| ``$($pair.Skill)`` | ``$($pair.SourceRel)`` | ``$shown`` | $Runs | $(Format-Sec $sorted[0])s | **$(Format-Sec $median)s** | $(Format-Sec $sorted[-1])s |")
        }
        if ($timeable.Count -gt 0) { $report.Add('') }
    }
    Write-Host ''
} else {
    Write-Skip 'pass 2 (wall-clock) not run -- pass -IncludeSpeed for it. It executes scripts, and only those whose registration declares a read-only invocation.'
}

# --- baseline write -----------------------------------------------------------------------------
if ($UpdateBaseline) {
    if ($script:errors -gt 0) {
        Write-Failure "the baseline was NOT written, because $($script:errors) error(s) above mean the figures are not trustworthy. Repair those first."
    } elseif ($measured.Count -eq 0) {
        Write-Info 'the baseline was not written: nothing was measured.'
    } else {
        $dir = Split-Path -Parent $BaselinePath
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }

        # IT MERGES, IT DOES NOT REPLACE, and that is a repair rather than a nicety. -UpdateBaseline
        # used to write exactly what this run measured, so a scoped run -- one -Plugin, or one -Skill --
        # silently deleted every baseline entry outside its own scope. Measured while building this:
        # `-Plugin dkj-subagents-alpha -UpdateBaseline` reduced an 18-skill baseline to 4 and reported success.
        # A run narrower than the file must update its own rows and leave the rest standing.
        $merged = [ordered]@{}
        $carried = 0
        if ($null -ne $baseline) {
            foreach ($prop in $baseline.PSObject.Properties) {
                if (-not $measured.Contains($prop.Name)) {
                    $merged[$prop.Name] = $prop.Value
                    $carried++
                }
            }
        }
        foreach ($k in $measured.Keys) { $merged[$k] = $measured[$k] }

        # Sorted, so a diff of this file shows what CHANGED rather than what moved. Measurement order
        # follows the always-on ranking, which reorders the whole file the moment two skills swap places.
        $sorted = [ordered]@{}
        foreach ($k in @($merged.Keys | Sort-Object)) { $sorted[$k] = $merged[$k] }

        Write-TextFile -Path $BaselinePath -Content ($sorted | ConvertTo-Json -Depth 4)
        Write-Ok "baseline written: $($measured.Count) skill(s) updated, $carried left untouched (outside this run's scope), $($sorted.Count) in the file -> $BaselinePath. Token counts come from an API rather than from this machine, so this file is machine-independent and committable."
    }
} elseif ($null -eq $baseline) {
    Write-Info "no baseline at $BaselinePath, so no deltas are shown. Re-run with -UpdateBaseline to record one; the NEXT run then reports the growth."
}

if ($OutFile) {
    Write-TextFile -Path $OutFile -Content ($report -join "`n")
    Write-Ok "markdown report written to $OutFile."
}

Write-CheckSummary
