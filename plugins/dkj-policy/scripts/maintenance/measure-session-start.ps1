<#
.SYNOPSIS
    Measures what a CLEAN SESSION loads before the first question (the MEASURED half of a session-start
    report), and renders the report page from a data file. Two modes: collect and -Render.

.DESCRIPTION
    WHY IT EXISTS. The session-start report was hand-built: figures typed into JavaScript arrays, a delta
    against a number remembered from the last time, and no way to repeat it. A measurement in a document
    that nothing regenerates goes stale silently, which is the failure measure-always-on.ps1 was written
    against, and this is the same lesson applied to the whole session start instead of one half of it.

    WHAT IT MEASURES, AND WHAT IT LEAVES TO THE MODEL. Only what a script can measure honestly:
      - the always-on DOCUMENT path -- every document CLAUDE.md and the unscoped rules pull in, bytes
        measured and tokens estimated at the calibrated factor (measure-context-lib.ps1), against the
        budget the always-on gate uses (Resolve-AlwaysOnBudget);
      - the plugin listings -- every enabled plugin's skill descriptions, priced by `claude plugin details`
        (the count_tokens API), MINUS the skills whose frontmatter says disable-model-invocation: true,
        because those are not in a session (issue #2664; measure-skill still reports the raw total);
    and it says plainly that it did NOT measure the rest: tool definitions, harness instructions, deferred
    tool names, MCP server instructions, built-in skills and agents, account skills, the session context,
    and the SessionStart hooks' output. Those exist only inside the running session, so the model that
    invokes the skill estimates them from its own context and labels them as estimates.

    IT REACHES NO VERDICT, AND IT IS NOT A GATE. It always exits 0. Ranking the actions and writing the
    advice is the invoking model's job, not this script's: that boundary is the recorded outcome of issue
    #861 (a portable skill that judged an instruction document was argued down) and it holds here. A script
    that advised would also be advising from numbers it knows are only half the session.

    MODE 1, COLLECT: -OutFile <json>. Writes the measured half as JSON. Every item carries measured: true and
    its source. Fields: schema, asOf, factor, alwaysOn { budgetBytes, budgetSource, totalBytes, totalTokens,
    documents[] }, plugins[] { id, version, installedVersion, payloadVersion, enabledBy, skills { loadedTokens, excludedTokens,
    loaded[], excluded[], unverified[] }, agents }, pluginTotals, hooks { measured: false }, problems[].

    MODE 2, -Render: -Data <json> -Template <html> -Out <html> [-Previous <html>]. Injects the data JSON into
    the template between the two data markers (see session-start-lib.ps1), with '<' escaped so the data
    cannot close the script element. With -Previous -- the currently published page, downloaded by the
    caller -- the previous data block is read back out of it and the delta fields are added (previousBytes per
    document, previousTokens per item, a previous total), so the published page is its own history and no
    state file exists anywhere. A previous page with no data block (the hand-built first version) renders
    without deltas, and the script says so.

    MODE 3, -ExtractPrevious: -Previous <html> -OutFile <json>. Writes only the NUMERIC history of a
    previously published page (asOf, item ids with tokens, document ids with bytes, action ids with the done
    flag). A published page is data from outside the session; this is the way to read its history without
    reading its prose.

    COLLECT RUNS THE MEASURED REPO'S CODE. It dot-sources that repo's scripts/repo-config.ps1 to read the
    Get-AlwaysOnBudget seam, exactly as the always-on gate does. Run it only on a repo you trust.

    NO DATA LEAVES THE MACHINE FROM HERE. Nothing is published by this script; the skill's last step
    republishes the page, and that step is the invoking session's.

    Pure ASCII (repo convention for .ps1).

.PARAMETER OutFile
    Collect mode: where to write the measured JSON.

.PARAMETER ExtractPrevious
    Print the numeric history of -Previous into -OutFile as JSON, instead of collecting.

.PARAMETER Render
    Render mode, instead of collecting. Needs -Data, -Template and -Out.

.PARAMETER Data
    Render mode: the full data JSON (the collect output extended with the estimated half, the actions and
    the advice).

.PARAMETER Template
    Render mode: the page template, with the two data markers.

.PARAMETER Out
    Render mode: where to write the finished page.

.PARAMETER Previous
    Render mode: the previously published page, to read the history out of. Optional.

.PARAMETER RepoRoot
    The repo to measure. Defaults to CLAUDE_PROJECT_DIR in a consumer, otherwise the git root.

.PARAMETER Plugin
    Collect mode: limit the plugin listing to these plugins ('<name>@<marketplace>' or just '<name>').
    Default: every plugin enabled for this repo -- what a session here actually loads.

.PARAMETER Root
    Collect mode: the root document of the always-on path. Defaults to CLAUDE.md in the repo root.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-session-start.ps1 -OutFile collect.json

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-session-start.ps1 -Render -Data data.json -Template session-start-template.html -Out index.html -Previous previous.html
#>
[CmdletBinding()]
param(
    [string]$OutFile,
    [switch]$Render,
    [switch]$ExtractPrevious,
    [string]$Data,
    [string]$Template,
    [string]$Out,
    [string]$Previous,
    [string]$RepoRoot,
    [string[]]$Plugin,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. A stale copy of a
# MEASUREMENT tool does not fail -- it reports -- which is the reason it is wired in here at all.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\session-start-lib.ps1')

function Write-Line { param([string]$Tag, [string]$Text) Write-Host ("[{0}] {1}" -f $Tag, $Text) }

# BOM-LESS, LF -- the repo convention for generated files (see measure-skill.ps1's writer, same reason).
function Write-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $normalized = ($Content -replace "`r`n", "`n")
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}
function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

# ================================================================================ extract previous
if ($ExtractPrevious) {
    try {
        if (-not $Previous) { throw '-ExtractPrevious needs -Previous <html>.' }
        if (-not $OutFile) { throw '-ExtractPrevious needs -OutFile <json>.' }
        if (-not (Test-Path -LiteralPath $Previous -PathType Leaf)) { throw "-Previous file not found: $Previous" }
        if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }
        $prev = Read-SessionStartDataBlock -Html (Read-TextFile -Path $Previous)
        if (-not $prev.Found) {
            Write-Line 'INFO' "no history to extract: $($prev.Reason). The page's own prose is not read by this mode."
        } else {
            $history = Get-SessionStartHistory -Previous $prev.Data
            Write-TextFile -Path $OutFile -Content (ConvertTo-Json -InputObject $history -Depth 10)
            Write-Line 'OK' ("numeric history written to {0}: {1} item(s), {2} document(s), {3} action(s), as of '{4}'." -f $OutFile, @($history.items).Count, @($history.documents).Count, @($history.actions).Count, $history.asOf)
        }
    } catch {
        Write-Line 'ERROR' "extract failed: $($_.Exception.Message)"
    }
    exit 0
}

# ================================================================================ render
if ($Render) {
    try {
        foreach ($pair in @(@('-Data', $Data), @('-Template', $Template), @('-Out', $Out))) {
            if (-not $pair[1]) { throw "-Render needs $($pair[0])." }
        }
        foreach ($pair in @(@('-Data', $Data), @('-Template', $Template))) {
            if (-not (Test-Path -LiteralPath $pair[1] -PathType Leaf)) { throw "$($pair[0]) file not found: $($pair[1])" }
        }

        # EVERY INPUT IS READ INTO MEMORY BEFORE -Out IS TOUCHED, and a pre-existing -Out is then deleted:
        # a render that fails half way must not leave last run's page standing where the caller is about to
        # publish from. The catch below removes it too, for a failure after this point.
        $dataObj = ConvertFrom-Json -InputObject (Read-TextFile -Path $Data)
        $tpl = Read-TextFile -Path $Template
        $prevHtml = $null
        if ($Previous -and (Test-Path -LiteralPath $Previous -PathType Leaf)) { $prevHtml = Read-TextFile -Path $Previous }
        if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Force }

        if ($Previous) {
            if ($null -eq $prevHtml) {
                Write-Line 'INFO' "-Previous file not found ($Previous), so the page is rendered without deltas."
            } else {
                $prev = Read-SessionStartDataBlock -Html $prevHtml
                if ($prev.Found) {
                    $dataObj = Merge-SessionStartPrevious -Data $dataObj -Previous $prev.Data
                    Write-Line 'OK' 'read the previous measurement out of the published page and added the deltas.'
                    foreach ($note in @(Get-SessionStartMergeNotes)) { Write-Line 'INFO' $note }
                } else {
                    Write-Line 'INFO' "no deltas: $($prev.Reason). This render becomes the history the next one reads."
                }
            }
        } else {
            Write-Line 'INFO' 'no -Previous given, so the page is rendered without deltas.'
        }

        $title = ''
        $props = @($dataObj.PSObject.Properties.Name)
        if ($props -contains 'pageTitle') { $title = [string]$dataObj.pageTitle }

        $json = ConvertTo-SafeScriptJson -Object $dataObj
        $page = Merge-SessionStartTemplate -Template $tpl -Json $json -PageTitle $title
        Write-TextFile -Path $Out -Content $page
        Write-Line 'OK' ("page written to {0} ({1} bytes)." -f $Out, $utf8.GetByteCount($page))
    } catch {
        Write-Line 'ERROR' "render failed: $($_.Exception.Message)"
        # Never leave a stale page behind, but never delete an input either.
        try {
            if ($Out -and (Test-Path -LiteralPath $Out -PathType Leaf)) {
                $outFull = [System.IO.Path]::GetFullPath($Out)
                $isInput = $false
                foreach ($p in @($Data, $Template, $Previous)) {
                    if ($p -and ([System.IO.Path]::GetFullPath($p) -ieq $outFull)) { $isInput = $true }
                }
                if (-not $isInput) { Remove-Item -LiteralPath $Out -Force }
            }
        } catch { }
    }
    exit 0
}

# ================================================================================ collect
$problems = New-Object System.Collections.Generic.List[string]
try {
    if (-not $OutFile) { throw 'collect mode needs -OutFile <json> (or use -Render).' }

    if (-not $RepoRoot) {
        # DUAL-CONTEXT, like measure-always-on: a consumer's harness sets CLAUDE_PROJECT_DIR and the mirror
        # runs from the plugin cache, where a git root would be absent or the wrong repository.
        if ($env:CLAUDE_PROJECT_DIR) { $RepoRoot = $env:CLAUDE_PROJECT_DIR }
        else { $RepoRoot = (Get-GitTopLevelPath).Path }
    }
    if (-not $RepoRoot) { throw 'Not inside a git repository, and -RepoRoot was not given.' }
    $RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot.Trim())

    # repo-config.ps1 first and optional: the Get-AlwaysOnBudget seam lives there, and a repo that states
    # none runs on the built-in ceiling. Loaded BEFORE always-on-budget-lib, which probes for the seam.
    $repoConfig = Join-Path $RepoRoot 'scripts\repo-config.ps1'
    $seamStated = $false
    if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
        try { . $repoConfig } catch { $problems.Add("scripts/repo-config.ps1 failed to load ($($_.Exception.Message)), so the built-in budget is used.") }
    }
    . (Join-Path $PSScriptRoot '..\lib\always-on-budget-lib.ps1')
    $seamStated = [bool](Test-FunctionDefined 'Get-AlwaysOnBudget')
    $budget = Resolve-AlwaysOnBudget
    $budgetSource = 'built-in default (Get-AlwaysOnBudgetDefault), the ceiling the always-on gate falls back to'
    if ($seamStated) { $budgetSource = 'this repo''s Get-AlwaysOnBudget seam in scripts/repo-config.ps1, the ceiling the always-on gate and the session check use' }

    # ---- (a) the always-on document path
    if (-not $Root) { $Root = Join-Path $RepoRoot 'CLAUDE.md' }
    if (-not (Test-Path -LiteralPath $Root -PathType Leaf)) { throw "Root document not found: $Root" }
    $factor = Get-CalibratedCharsPerToken
    $docs = @(Get-AlwaysOnDocuments -RootDocument $Root -RepoRoot $RepoRoot)
    $userHome = Get-UserClaudeHome
    $docEntries = @()
    $missing = @()
    foreach ($d in $docs) {
        if (-not $d.Exists) { $missing += [string]$d.Target; continue }
        $docEntries += [pscustomobject](ConvertTo-SessionStartDocumentEntry -Doc $d -CharsPerToken $factor.Value -RepoRoot $RepoRoot -UserHome $userHome)
    }
    foreach ($m in $missing) { $problems.Add("an @-import on the always-on path does not resolve: $m (the session loses that whole document and nothing errors).") }
    $totalBytes = [int64]0
    if ($docEntries.Count -gt 0) { $totalBytes = [int64](($docEntries | Measure-Object -Property bytes -Sum).Sum) }

    # ---- (b) the plugin listings
    $Plugin = Expand-ListArgument -Value $Plugin
    $enabled = Get-EnabledPlugins -RepoRoot $RepoRoot
    $ids = @($enabled.Ids)
    if ($Plugin -and @($Plugin).Count -gt 0) {
        # A bare name takes the marketplace it is ENABLED under here (Resolve-PluginRequest).
        $ids = @(Resolve-PluginRequest -Requested $Plugin -EnabledIds @($enabled.Ids))
    }
    if ($ids.Count -eq 0) { $problems.Add("no plugin is enabled for this repo ($($enabled.Summary)), so no listing was measured.") }

    $pluginEntries = @()
    foreach ($id in $ids) {
        $details = Get-PluginDetails -PluginId $id
        if (-not $details.Ok) { $problems.Add("$id : $($details.Reason). Is the plugin installed and its marketplace reachable? Not measured."); continue }
        $parseProblems = @(Get-PluginDetailsParseProblems -Details $details)
        if ($parseProblems.Count -gt 0) {
            $problems.Add("$id : the output of 'claude plugin details' did not parse as expected ($($parseProblems -join '; ')). Not measured.")
            continue
        }

        $payload = Get-PayloadDirForPlugin -RepoRoot $RepoRoot -PluginId $id -Version ([string]$details.Version)
        $skillsDir = ''
        if ($null -ne $payload) {
            $skillsDir = Join-Path $payload.Dir 'skills'
            if (-not $payload.Exact) { $problems.Add("$id : no installed copy at v$($details.Version) was found; the disable-model-invocation flags were read from v$($payload.Version) instead.") }
        } else {
            $problems.Add("$id : the installed copy was not found on disk, so no skill could be checked for disable-model-invocation and every skill is counted as loaded.")
        }

        $skillRows = @($details.Rows | Where-Object { @($details.InventorySkills) -contains $_.Component })
        $split = Split-SkillRowsByInvocation -Rows $skillRows -SkillsDir $skillsDir
        if (@($split.Unverified).Count -gt 0) { $problems.Add("$id : no SKILL.md found for $(@($split.Unverified) -join ', '), so they are counted as loaded.") }

        $shortName = ($id -split '@')[0]
        $declared = Get-DeclaredAgentCount -RepoRoot $RepoRoot -ShortName $shortName
        $declaredCount = $null
        if ($declared.Found) { $declaredCount = $declared.AgentCount }

        $enabledBy = 'machine'
        if (@($enabled.RepoEnabledIds) -contains $id) { $enabledBy = 'repo' }
        $pluginEntries += [pscustomobject](ConvertTo-SessionStartPluginEntry -PluginId $id -Details $details -Split $split -Payload $payload -EnabledBy $enabledBy -InstalledVersion ([string](Get-InstalledVersionForRepo -RepoRoot $RepoRoot -PluginId $id)) -DeclaredAgents $declaredCount)
    }

    $loadedTotal = 0
    $excludedTotal = 0
    foreach ($p in $pluginEntries) { $loadedTotal += [int]$p.skills.loadedTokens; $excludedTotal += [int]$p.skills.excludedTokens }

    $result = [ordered]@{
        schema   = 'session-start-collect/1'
        asOf     = (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
        measured = $true
        factor   = [ordered]@{
            charsPerToken = $factor.Value
            calibrated    = $factor.Calibrated
            basis         = $factor.Basis
            caveat        = $factor.Caveat
        }
        alwaysOn = [ordered]@{
            measured     = $true
            budgetBytes  = $budget
            budgetSource = $budgetSource
            totalBytes   = $totalBytes
            totalTokens  = (ConvertTo-EstimatedTokens -Bytes $totalBytes -CharsPerToken $factor.Value)
            documents    = @($docEntries)
        }
        plugins  = @($pluginEntries)
        pluginTotals = [ordered]@{
            measured                    = $true
            skillTokensLoaded           = $loadedTotal
            skillTokensExcludedNotInSession = $excludedTotal
            note                        = 'skills with disable-model-invocation: true are listed per plugin under skills.excluded and are NOT in the loaded figure (issue #2664); agent descriptions are separate and may be uncounted, see each plugin''s agents.note'
        }
        hooks    = [ordered]@{
            measured = $false
            note     = 'the SessionStart hooks'' output is not measured by this script; estimate it from the session context'
        }
        notMeasured = @('tool definitions', 'harness instructions', 'deferred tool names', 'MCP server instructions', 'built-in skills', 'built-in agents', 'claude.ai account skills', 'session context', 'SessionStart hook output')
        problems = @($problems)
    }

    Write-TextFile -Path $OutFile -Content (ConvertTo-Json -InputObject $result -Depth 20)
    Write-Line 'OK' ("measured half written to {0}: {1} always-on document(s), {2} B (budget {3} B); {4} plugin(s), {5} skill token(s) loaded, {6} excluded (not in a session)." -f `
        $OutFile, $docEntries.Count, $totalBytes, $budget, $pluginEntries.Count, $loadedTotal, $excludedTotal)
    foreach ($p in $problems) { Write-Line 'INFO' $p }
} catch {
    Write-Line 'ERROR' "collect failed: $($_.Exception.Message)"
}
exit 0
