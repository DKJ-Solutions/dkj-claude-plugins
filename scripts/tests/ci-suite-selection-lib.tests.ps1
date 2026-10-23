<#
.SYNOPSIS
    Tests for scripts/lib/ci-suite-selection-lib.ps1 -- issue #3309's CI-side selection for a PR that
    changes only static assets -- and for the ci.yml wiring that reads its verdict.

.DESCRIPTION
    FAIL-CLOSED IS THE PROPERTY UNDER TEST. Getting this wrong in the SKIP direction merges an asset-only
    PR past a suite that should have caught it; getting it wrong in the RUN direction costs one CI run.
    So most cases below assert a refusal: a mixed change, a quoted path, an empty read, an unproven
    selection and an unreadable suite all have to answer "run".

    Get-AffectedSuiteSelection is stubbed: its own suite (affected-suites.tests.ps1) proves the map, and
    what is under test here is only what this lib does with the map's answer. Dependency-free (no
    Pester), same style as the rest of the suite. Pure ASCII.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath = Join-Path $RepoRoot 'scripts\lib\ci-suite-selection-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

. $LibPath

Write-Host ''
Write-Host 'Get-StaticAssetVerdict' -ForegroundColor Cyan

$v = Get-StaticAssetVerdict -ChangedPaths @('brandbook/src/index.css', 'assets/logo.SVG', 'fonts/a.woff2')
Assert-True $v.AssetOnly 'stylesheets, images and fonts are assets only, whatever the case of the extension'
Assert-Equal '.css,.svg,.woff2' ($v.Extensions -join ',') 'and the extensions come back distinct, lower case, sorted'

$v = Get-StaticAssetVerdict -ChangedPaths @('brandbook/src/index.css', 'scripts/lib/gate-lib.ps1')
Assert-True (-not $v.AssetOnly) 'one script among the stylesheets makes the change not asset-only'
Assert-True ($v.Reason -match 'gate-lib\.ps1') 'and the reason names the first path that is not an asset'

foreach ($p in @('index.html', 'src/App.tsx', 'main.js', 'data.json', 'README.md', '.github/workflows/ci.yml', 'Makefile')) {
    Assert-True (-not (Get-StaticAssetVerdict -ChangedPaths @($p)).AssetOnly) "'$p' is not a static asset"
}
Assert-True (-not (Get-StaticAssetVerdict -ChangedPaths @()).AssetOnly) 'an empty change set proves nothing, so it is not asset-only'
Assert-True (-not (Get-StaticAssetVerdict -ChangedPaths $null).AssetOnly) 'and neither is a null read'
$v = Get-StaticAssetVerdict -ChangedPaths @('"assets/caf\303\251.css"')
Assert-True (-not $v.AssetOnly) 'a quoted (non-ASCII) path is not judged, even when it ends in .css'
Assert-True ($v.Reason -match 'ASCII') 'and the reason says why'

Write-Host ''
Write-Host 'Get-StaticAssetSuiteSelection' -ForegroundColor Cyan

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("ci-suite-selection-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts\tests') -Force
try {
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-ps1.tests.ps1') -Value "Get-ChildItem -Filter '*.ps1'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-css.tests.ps1') -Value "Get-ChildItem -Filter '*.css'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\matched.tests.ps1') -Value 'x' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\declared-css.tests.ps1') -Value "# gate-selection: walks *.ps1`nGet-ChildItem -Filter '*.css'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\scoped.tests.ps1') -Value "# gate-selection: walks brandbook/*" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-open.tests.ps1') -Value "Get-ChildItem `$RepoRoot -Recurse" -Encoding ASCII

    $script:stub = $null
    function Get-AffectedSuiteSelection { param($RepoRoot, $ChangedPaths) return $script:stub }

    $script:stub = [pscustomobject]@{
        Proven = $true; PoolCount = 164
        Matched = @('scripts/tests/matched.tests.ps1')
        Always = @('scripts/tests/walks-ps1.tests.ps1', 'scripts/tests/walks-css.tests.ps1', 'scripts/tests/gone.tests.ps1')
        Scoped = @('scripts/tests/scoped.tests.ps1')
        Walkers = @('scripts/tests/walks-ps1.tests.ps1', 'scripts/tests/walks-css.tests.ps1', 'scripts/tests/gone.tests.ps1',
                    'scripts/tests/declared-css.tests.ps1', 'scripts/tests/scoped.tests.ps1', 'scripts/tests/walks-open.tests.ps1')
        Open = @('scripts/tests/walks-open.tests.ps1')
    }
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('brandbook/src/index.css')
    Assert-True $s.Proven 'an asset-only change over a proven map is a proven selection'
    Assert-True ($s.Suites -contains 'scripts/tests/matched.tests.ps1') 'a suite the map ties to the changed path runs'
    Assert-True ($s.Suites -contains 'scripts/tests/walks-css.tests.ps1') 'a tree walk that names the extension runs'
    Assert-True ($s.Suites -notcontains 'scripts/tests/walks-ps1.tests.ps1') 'a tree walk that only names *.ps1 is dropped -- the saving'
    Assert-True ($s.Suites -contains 'scripts/tests/gone.tests.ps1') 'an unreadable suite is kept, because the guard only drops a suite it has read'
    Assert-Equal 164 $s.PoolCount 'and the pool size is the map''s'
    # #3309: a walker whose declared scope leaves the change out is NOT in the local Always set, and CI
    # still judges it by its own text -- the declaration narrows the local gate, never this one.
    Assert-True ($s.Suites -contains 'scripts/tests/declared-css.tests.ps1') 'a declared walker outside Always that names the extension still runs on CI'
    Assert-True ($s.Suites -contains 'scripts/tests/scoped.tests.ps1') 'and a walker whose declared scope the change falls in runs, named extension or not'
    Assert-True ($s.Suites -contains 'scripts/tests/walks-open.tests.ps1' -and $s.KeptAlways -contains 'scripts/tests/walks-open.tests.ps1') 'an OPEN walker runs although its text never names css: its walk returns every type (#3316)'

    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('assets/logo.png')
    Assert-True ($s.Suites -notcontains 'scripts/tests/walks-css.tests.ps1') 'the extension guard is per change: a PNG does not keep the walk that names css'

    $script:stub = [pscustomobject]@{ Proven = $false; PoolCount = 164; Matched = @(); Always = @(); Scoped = @(); Walkers = @(); Reason = 'git could not list the tree' }
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('brandbook/src/index.css')
    Assert-True (-not $s.Proven) 'an unproven map is an unproven selection, so the caller runs the whole pool'
    Assert-Equal 'git could not list the tree' $s.Reason 'and the map''s reason is passed through'

    $script:stub = $null
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('brandbook/src/index.css', 'scripts/x.ps1')
    Assert-True (-not $s.Proven) 'a mixed change never reaches the map at all'
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'ci.yml reads the verdict' -ForegroundColor Cyan

$ci = [System.IO.File]::ReadAllText((Join-Path $RepoRoot '.github\workflows\ci.yml'))
Assert-True ($ci -match 'get-pr-suite-selection\.ps1 -Shard \$\{\{ matrix\.shard \}\}') 'each suites shard asks the selection with its own shard number'
Assert-True ($ci -match "-SuiteNames \`$selected") 'shard 1 runs the selected suites by name'
Assert-True ($ci -match "\`$mode -eq 'whole'") 'an unproven selection runs the whole pool in shard 1'
Assert-True ($ci -match '-Shard \$\{\{ matrix\.shard \}\} -ShardCount 5') 'and every other case keeps the sharded run'
Assert-True ($ci -match "get-pr-suite-selection\.ps1 -Shard 0") 'the Linux leg asks too, outside the matrix'
Assert-True ($ci -match "if: \`$\{\{ steps\.pr-suite-selection\.outputs\.mode != 'skip' \}\}") 'and it skips its suites only on skip'

$script = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\ci\get-pr-suite-selection.ps1'))
Assert-True ($script -match "if \(\`$Shard -eq 1\) \{ 'whole' \} else \{ 'full' \}") 'a failed path read makes shard 1 carry the whole pool, since the other shards may have skipped'

Write-Host ''
Write-Host ("ci-suite-selection-lib: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
