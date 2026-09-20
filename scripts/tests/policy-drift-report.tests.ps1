<#
.SYNOPSIS
    Regression tests for the policy-drift report: scripts/task/check-policy-drift.ps1, its registration
    in the shared-scripts registry, and the skill page that documents it for a consumer.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/policy-drift-report.tests.ps1

    WHAT IS WORTH ASSERTING HERE, given that this script deliberately makes no judgement. Its output is
    prose for a session to act on, and pinning prose would make the suite a spell-checker. So the asserts
    below hold the three things that are actually DECISIONS:

      1. IT NEVER REFUSES. Report-only is the whole design -- an exit code would be a verdict it has not
         earned, and a gate here would be #1380's declined check wearing a different hat. Every fixture
         asserts the code as well as the text, including the empty tree and the tree with findings.
      2. THE RANK-1 ORDER. dkj-policy before a companion plugin is the top rung's own internal
         order out of "A third rank sits above both". A sort that lost it would still print every page
         and read as correct.
      3. THE SOURCE-REPO SKIP IS THE HOOK'S SKIP. The two detector FUNCTIONS carry no skip -- it lives in
         check-consumer-prose.ps1, the entry script #1421 merged both detectors into -- so a report that
         called them straight would print findings under a heading claiming the consumer-prose-sessioncheck
         hook covers it, two lines from where that hook prints [OK]. Both directions are pinned: skipped
         where the marketplace publishes this workflow, reported where it does not.

    THE USER LAYER IS REDIRECTED FOR EVERY RUN. Get-EnabledPlugins reads the whole settings chain, so
    this machine's own ~/.claude/settings.json would otherwise add plugins to a fixture's rank 1 and the
    plugin cache would answer probes the fixture did not set up. $env:USERPROFILE is pointed at a
    throwaway home for the CHILD process, which is the technique Resolve-PluginDir's docstring names.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\check-policy-drift.ps1'
$Skill    = Join-Path $RepoRoot 'plugins\dkj-policy\skills\check-policy-drift\SKILL.md'
$Mirror   = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\task\check-policy-drift.ps1'
. (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')
# For Get-LensFamily: the pre-seam lens path is composed from the constant rather than typed, so a
# suite cannot pin a family name the family has moved past (the #179 lesson, one layer out).
. (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("policydrift-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function Set-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Rel,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $target = Join-Path $Dir ($Rel -replace '/', '\')
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($target, $Text + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Add-FixturePlugin {
    # A plugin the way the report has to recognise one: a directory carrying .claude-plugin/plugin.json,
    # declared by the tree's own marketplace, with a portable page beside it.
    #
    # -Root IS THE PATH THE FIXTURE'S OWN marketplace.json DECLARES, and it is a parameter rather than a
    # literal here because the two silently drifted apart once. This helper wrote 'plugins/workflows/<name>/'
    # while the manifest above it was repointed to the new layout by #1467, so the manifest named a source
    # that did not exist in the tree -- the report then found no plugin, and the failure surfaced three
    # asserts later as "each plugin's own portable page is named", which is not what broke. Passing the
    # same string to both is what keeps a layout change from having to be made twice.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Page
    )
    $rel = $Root.TrimStart('.', '/')
    Set-Text -Dir $Dir -Rel "$rel/.claude-plugin/plugin.json" -Text "{ `"name`": `"$Name`", `"version`": `"1.0.0`" }"
    Set-Text -Dir $Dir -Rel "$rel/$Page" -Text "# $Name portable page"
}

function Invoke-Report {
    # The user layer is redirected for the child process, so the fixture's own settings.json is the only
    # thing that enables anything and the cache probe finds nothing to answer with.
    # -ScriptPath so the same scenario can be driven through the plugin mirror as well as the root
    # copy (#1857). It defaults to the root copy, so every existing call is unchanged.
    param([Parameter(Mandatory = $true)][string]$Dir, [string]$ScriptPath = $Script)
    $fakeHome = New-Tree -Label 'home'
    $prevProfile = $env:USERPROFILE
    $prevProject = $env:CLAUDE_PROJECT_DIR
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $env:USERPROFILE = $fakeHome
        $env:CLAUDE_PROJECT_DIR = ''
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -RootOverride $Dir 2>&1
    } finally {
        $ErrorActionPreference = $prevEap
        $env:USERPROFILE = $prevProfile
        $env:CLAUDE_PROJECT_DIR = $prevProject
    }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

$paths = Get-BranchFilePaths

# The retired name the report echoes. Taken from the plugin's own table rather than typed here, so this
# suite cannot pin a name the rename history has moved past.
$retiredName = @(Get-RetiredBranchDocNames)[0].Name

try {
    # --- The registration -------------------------------------------------------------------------
    # Asserted first because everything else is invisible to a consumer without it: the mirror is what
    # they run and the skill page is the only place its command is written down for them.
    Write-Host 'Registration'

    $pair = @(Get-SharedScriptPairs -RepoRoot $RepoRoot | Where-Object { $_.Name -eq 'check-policy-drift' })
    Assert-True ($pair.Count -eq 1) 'the script is registered exactly once in the shared-scripts registry'
    Assert-True ($pair.Count -eq 1 -and $pair[0].Skill -eq 'check-policy-drift') `
        "the registration names its documenting skill -- '' would declare that no page documents it"
    Assert-True (Test-Path -LiteralPath $Skill -PathType Leaf) 'the skill page exists'
    Assert-True (Test-Path -LiteralPath $Mirror -PathType Leaf) 'the plugin mirror exists'
    Assert-True ((Get-NormalizedScriptContent -Path $Script) -eq (Get-NormalizedScriptContent -Path $Mirror)) `
        'the mirror is byte-identical to the root copy after LF normalization'

    # --- It never refuses -------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Report-only'

    $empty = New-Tree -Label 'empty'
    $r = Invoke-Report -Dir $empty
    Assert-True ($r.Code -eq 0) 'a tree with no documents at all -- exit 0, because there is nothing to refuse over'
    Assert-True ($r.Out -match 'RANK 1' -and $r.Out -match 'RANK 2' -and $r.Out -match 'RANK 3') `
        'all three ranks are printed even when every one of them is empty'
    Assert-True ($r.Out -match 'REPORT ONLY') 'the hand-over states that nothing was edited'

    # --- The rank-1 order -------------------------------------------------------------------------
    # A companion plugin sorts before dkj-policy alphabetically, which is the whole point of
    # pinning this: a plain Sort-Object would print the order upside down and still look right.
    Write-Host ''
    Write-Host 'Rank 1 -- the top rung has an internal order'

    $source = New-Tree -Label 'source'
    Set-Text -Dir $source -Rel '.claude-plugin/marketplace.json' -Text @'
{
  "name": "fixture",
  "plugins": [
    { "name": "dkj-policy", "source": "./plugins/dkj-policy" },
    { "name": "dkj-policy-bwj", "source": "./plugins/dkj-policy/dkj-policy-bwj" }
  ]
}
'@
    Add-FixturePlugin -Dir $source -Root './plugins/dkj-policy' -Name 'dkj-policy' -Page 'CONTRIBUTING-portable.md'
    Add-FixturePlugin -Dir $source -Root './plugins/dkj-policy/dkj-policy-bwj' -Name 'dkj-policy-bwj' -Page 'WORKFLOW-portable.md'
    Set-Text -Dir $source -Rel '.claude/settings.json' -Text @'
{
  "enabledPlugins": {
    "dkj-policy-bwj@fixture": true,
    "dkj-policy@fixture": true
  }
}
'@
    $r = Invoke-Report -Dir $source
    $atPrime = $r.Out.IndexOf('dkj-policy', [System.StringComparison]::Ordinal)
    $atCompanion = $r.Out.IndexOf('dkj-policy-bwj', [System.StringComparison]::Ordinal)
    Assert-True ($r.Code -eq 0) 'a tree publishing both plugins -- exit 0'
    Assert-True ($atPrime -ge 0 -and $atCompanion -ge 0) 'both plugins are located and printed'
    Assert-True ($atPrime -ge 0 -and $atCompanion -gt $atPrime) `
        'dkj-policy is printed BEFORE the companion, against the alphabetical order'
    Assert-True ($r.Out -match 'CONTRIBUTING-portable\.md' -and $r.Out -match 'WORKFLOW-portable\.md') `
        "each plugin's own portable page is named, discovered rather than listed"

    # --- The source-repo skip, both directions ----------------------------------------------------
    Write-Host ''
    Write-Host 'The echoed slices skip the repo that publishes the workflow'

    Set-Text -Dir $source -Rel 'CLAUDE.md' -Text "# Source`n`nThe branch document used to be called ``$retiredName``, which is history."
    $r = Invoke-Report -Dir $source
    Assert-True ($r.Out -match '\[skipped\]') 'the marketplace publishes this workflow -- both slices are skipped, as their own checks skip it'
    Assert-True ($r.Out -notmatch '\[retired-name\]') 'and no retired-name finding is printed there, which is what the hook would say too'

    $consumer = New-Tree -Label 'consumer'
    Set-Text -Dir $consumer -Rel 'CLAUDE.md' -Text "# Consumer`n`nOur plan lives in ``$retiredName`` and we keep it current."
    $r = Invoke-Report -Dir $consumer
    Assert-True ($r.Code -eq 0) 'a consumer with a finding -- still exit 0, because the verdict is not the script''s'
    Assert-True ($r.Out -match '\[retired-name\]') 'the retired name IS reported in a consumer'
    Assert-True ($r.Out -match [regex]::Escape($retiredName)) 'and the finding names the retired name it matched'
    Assert-True ($r.Out -match 'CLAUDE\.md') 'rank 3 lists the always-on document the finding sits in'

    # --- Rank 2 is the workflow folder, rank 3 the always-on closure ------------------------------
    Write-Host ''
    Write-Host 'The consumer side is split at the workflow folder'

    $split = New-Tree -Label 'split'
    Set-Text -Dir $split -Rel 'CLAUDE.md' -Text "# Consumer`n`n@docs/imported.md"
    Set-Text -Dir $split -Rel 'docs/imported.md' -Text '# Imported'
    Set-Text -Dir $split -Rel "$($paths.Directory)/CONTRIBUTING.md" -Text '# Our answers'
    $r = Invoke-Report -Dir $split
    $rank2 = $r.Out.IndexOf('RANK 2', [System.StringComparison]::Ordinal)
    $rank3 = $r.Out.IndexOf('RANK 3', [System.StringComparison]::Ordinal)
    $atFolderPage = $r.Out.IndexOf("$($paths.Directory)/CONTRIBUTING.md", [System.StringComparison]::Ordinal)
    $atImport = $r.Out.IndexOf('docs/imported.md', [System.StringComparison]::Ordinal)
    Assert-True ($atFolderPage -gt $rank2 -and $atFolderPage -lt $rank3) `
        'the workflow folder page is listed under RANK 2, not with the floor'
    Assert-True ($atImport -gt $rank3) `
        "an '@'-imported document is part of the always-on closure and lands in RANK 3"

    # --- Rank 2 also holds the repo lenses (issue #2184) ------------------------------------------
    # THE DEFECT THIS PINS was invisible from the output, which is why it is worth a block of its own:
    # RANK 2 was built from the workflow-folder prefix and RANK 3 from the always-on closure, so a lens
    # was in NEITHER -- and a repo that had moved its seam answers into its lenses got a report that
    # examined none of them while printing as though it were complete.
    Write-Host ''
    Write-Host 'Rank 2 -- the repo lenses'

    $lensTree = New-Tree -Label 'lenses'
    $seamLens = '.claude/specialists/lenses/specialist-05-15-lens.md'
    $importedLens = '.claude/specialists/lenses/specialist-01-01-lens.md'
    Set-Text -Dir $lensTree -Rel 'CLAUDE.md' -Text "# Consumer`n`n@$importedLens"
    Set-Text -Dir $lensTree -Rel $importedLens -Text '# The orchestrator lens'
    Set-Text -Dir $lensTree -Rel $seamLens -Text "# Our system-administration lens`n`nThis repo's answer to a seam."
    $r = Invoke-Report -Dir $lensTree
    $rank2 = $r.Out.IndexOf('RANK 2', [System.StringComparison]::Ordinal)
    $rank3 = $r.Out.IndexOf('RANK 3', [System.StringComparison]::Ordinal)
    $atSeamLens = $r.Out.IndexOf($seamLens, [System.StringComparison]::Ordinal)
    $atImported = $r.Out.IndexOf($importedLens, [System.StringComparison]::Ordinal)
    Assert-True ($r.Code -eq 0) 'a tree carrying lenses -- still exit 0, because the verdict is not the script''s'
    Assert-True ($atSeamLens -gt $rank2 -and $atSeamLens -lt $rank3) `
        'a lens that no document imports is listed under RANK 2, where it used to be listed nowhere'
    Assert-True ($atImported -gt $rank3) `
        "a lens the root document '@'-imports is part of the always-on closure and stays in RANK 3"
    # ONE RANK PER DOCUMENT. Listing the imported lens in both would be a "which rank wins" question in
    # the one report whose whole job is to settle those.
    $importedHits = @([regex]::Matches($r.Out, [regex]::Escape($importedLens))).Count
    Assert-True ($importedHits -eq 1) 'and it is listed exactly once, not under both ranks at the same time'

    # THE PRE-SEAM LAYOUT IS FOUND TOO, and it needs its own assert because it is reached by a different
    # route: the seam directory is plugin-independent, while '.claude/plugins/<family>/<plugin>/' is a
    # candidate Get-LensDirCandidates can only compose once it has been given a plugin NAME. A consumer
    # bootstrapped before #221 keeps its lenses there and is never relocated, so a rank that read only
    # the seam would be blind in exactly the repos that have been running this longest.
    $legacyLens = ".claude/plugins/$(Get-LensFamily)/dkj-policy/05-15-extension.md"
    Set-Text -Dir $source -Rel $legacyLens -Text '# A pre-seam lens'
    $r = Invoke-Report -Dir $source
    $rank2 = $r.Out.IndexOf('RANK 2', [System.StringComparison]::Ordinal)
    $rank3 = $r.Out.IndexOf('RANK 3', [System.StringComparison]::Ordinal)
    $atLegacy = $r.Out.IndexOf($legacyLens, [System.StringComparison]::Ordinal)
    Assert-True ($atLegacy -gt $rank2 -and $atLegacy -lt $rank3) `
        'a lens in the pre-seam per-plugin tree is listed under RANK 2 as well, under either spelling'

    # A TREE WITH NO LENSES IS UNCHANGED, which is the promise made to every consumer that has none:
    # the probe returns nothing and the rank reads exactly as it did before.
    $r = Invoke-Report -Dir $split
    Assert-True ($r.Out -notmatch 'repo lens states') `
        'a tree with no lenses gets no lens note -- the addition is silent where there is nothing to add'

    # --- The skill page's command matches the script ----------------------------------------------
    # The lint gate holds a skill's PARAMETERS against the script; nothing held the file NAME, and a
    # skill pointing at a script that is not there is a consumer's only route failing silently.
    Write-Host ''
    Write-Host 'The skill page'

    $skillText = [System.IO.File]::ReadAllText($Skill)
    Assert-True ($skillText -match 'scripts/task/check-policy-drift\.ps1') 'the skill page runs the script this suite tests'
    Assert-True ($skillText -match 'CLAUDE_PLUGIN_ROOT') 'and reaches it through ${CLAUDE_PLUGIN_ROOT}, which is what a consumer has'

    # --- The mirror RUNS, not just matches (issue #1857) -------------------------------------------
    # The registration block above proves the two copies are byte-identical, which is precisely what
    # makes the remaining difference invisible: step 4a resolves the sibling plugin folders with
    # Split-Path (Split-Path $PSScriptRoot -Parent) -Parent, two levels up -- the repo root from the
    # root copy and the PLUGIN root from the mirror. Identical text, different folder, nothing to
    # diff, and the mirror is the copy a consumer actually runs.
    #
    # THE SCENARIO IS RE-USED RATHER THAN REBUILT, on purpose: the question is not whether the mirror
    # can report, it is whether it reports THE SAME THING from a different depth. So it is handed the
    # fixture the root copy was just measured on, and its answer is held to that answer.
    Write-Host ''
    Write-Host 'The plugin mirror'

    $rSource = Invoke-Report -Dir $source
    $rMirror = Invoke-Report -Dir $source -ScriptPath $Mirror
    Assert-True ($rMirror.Code -eq $rSource.Code) `
        'the mirror exits the same as the root copy on the same tree'
    Assert-True ($rMirror.Out -match 'RANK 1' -and $rMirror.Out -match 'RANK 2' -and $rMirror.Out -match 'RANK 3') `
        'the mirror prints all three ranks, so its own $PSScriptRoot-relative dot-sources resolved from the plugin tree'
    $mPrime = $rMirror.Out.IndexOf('dkj-policy', [System.StringComparison]::Ordinal)
    $mCompanion = $rMirror.Out.IndexOf('dkj-policy-bwj', [System.StringComparison]::Ordinal)
    Assert-True ($mPrime -ge 0 -and $mCompanion -gt $mPrime) `
        'the mirror locates both plugins and keeps the rank-1 order -- step 4a resolved from its own depth'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host "policy-drift-report: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
