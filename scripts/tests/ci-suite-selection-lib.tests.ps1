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

$v = Get-StaticAssetVerdict -ChangedPaths @('web/src/index.css', 'assets/logo.SVG', 'fonts/a.woff2')
Assert-True $v.AssetOnly 'stylesheets, images and fonts are assets only, whatever the case of the extension'
Assert-Equal '.css,.svg,.woff2' ($v.Extensions -join ',') 'and the extensions come back distinct, lower case, sorted'

$v = Get-StaticAssetVerdict -ChangedPaths @('web/src/index.css', 'scripts/lib/gate-lib.ps1')
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
Write-Host 'Remove-BranchDocumentPath (#3370)' -ForegroundColor Cyan

$doc = 'dkj-policy/docs-stopwatch-css-comment-v4.md'
$left = @(Remove-BranchDocumentPath -ChangedPaths @('web/src/app/app.css', $doc) -BranchDocument $doc)
Assert-Equal 'web/src/app/app.css' ($left -join ',') 'the branch document is taken out of the judged change'
Assert-True (Get-StaticAssetVerdict -ChangedPaths $left).AssetOnly 'so a CSS change with its branch document is asset-only (the #3369 case)'
$left = @(Remove-BranchDocumentPath -ChangedPaths @('a.css', $doc, 'dkj-policy/other-branch.md', 'README.md') -BranchDocument $doc)
Assert-Equal 'a.css,dkj-policy/other-branch.md,README.md' ($left -join ',') 'only that one path goes: another branch document and any other .md stay'
Assert-True (-not (Get-StaticAssetVerdict -ChangedPaths $left).AssetOnly) 'and they still make the change not asset-only'
$left = @(Remove-BranchDocumentPath -ChangedPaths @('a.css', $doc) -BranchDocument '')
Assert-Equal "a.css,$doc" ($left -join ',') 'an unresolved document removes nothing (fail-closed)'
$left = @(Remove-BranchDocumentPath -ChangedPaths @($doc) -BranchDocument $doc)
Assert-True (-not (Get-StaticAssetVerdict -ChangedPaths $left).AssetOnly) 'a PR that changes only its branch document proves nothing, so it runs the pool'
$left = @(Remove-BranchDocumentPath -ChangedPaths @('a.css', 'DKJ-POLICY/docs-stopwatch-css-comment-v4.md') -BranchDocument $doc)
Assert-Equal 2 $left.Count 'the match is exact, case included -- git paths are case-sensitive'

Write-Host ''
Write-Host 'Get-StaticAssetSuiteSelection' -ForegroundColor Cyan

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("ci-suite-selection-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts\tests') -Force
try {
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-ps1.tests.ps1') -Value "Get-ChildItem -Filter '*.ps1'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-css.tests.ps1') -Value "Get-ChildItem -Filter '*.css'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\matched.tests.ps1') -Value 'x' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\declared-css.tests.ps1') -Value "# gate-selection: walks *.ps1`nGet-ChildItem -Filter '*.css'" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\scoped.tests.ps1') -Value "# gate-selection: walks web/*" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\walks-open.tests.ps1') -Value "Get-ChildItem `$RepoRoot -Recurse" -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'scripts\tests\declared-open.tests.ps1') -Value "# gate-selection: walks plugins/*`nCopy-Item `$RepoRoot\plugins\x `$tmp -Recurse" -Encoding ASCII

    $script:stub = $null
    function Get-AffectedSuiteSelection { param($RepoRoot, $ChangedPaths) return $script:stub }

    $script:stub = [pscustomobject]@{
        Proven = $true; PoolCount = 164
        Matched = @('scripts/tests/matched.tests.ps1')
        Always = @('scripts/tests/walks-ps1.tests.ps1', 'scripts/tests/walks-css.tests.ps1', 'scripts/tests/gone.tests.ps1', 'scripts/tests/walks-open.tests.ps1')
        Scoped = @('scripts/tests/scoped.tests.ps1')
        Walkers = @('scripts/tests/walks-ps1.tests.ps1', 'scripts/tests/walks-css.tests.ps1', 'scripts/tests/gone.tests.ps1',
                    'scripts/tests/declared-css.tests.ps1', 'scripts/tests/scoped.tests.ps1', 'scripts/tests/walks-open.tests.ps1',
                    'scripts/tests/declared-open.tests.ps1')
        Open = @('scripts/tests/walks-open.tests.ps1', 'scripts/tests/declared-open.tests.ps1')
    }
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('web/src/index.css')
    Assert-True $s.Proven 'an asset-only change over a proven map is a proven selection'
    Assert-True ($s.Suites -contains 'scripts/tests/matched.tests.ps1') 'a suite the map ties to the changed path runs'
    Assert-True ($s.Suites -contains 'scripts/tests/walks-css.tests.ps1') 'a tree walk that names the extension runs'
    Assert-True ($s.Suites -notcontains 'scripts/tests/walks-ps1.tests.ps1') 'a tree walk that only names *.ps1 is dropped -- the saving'
    Assert-True ($s.Suites -contains 'scripts/tests/gone.tests.ps1') 'an unreadable suite is kept, because the guard only drops a suite it has read'
    Assert-Equal 164 $s.PoolCount 'and the pool size is the map''s'
    # #3392: a walker that declares its scope (outside the Always set) is judged by the declaration alone --
    # the owner's decision, made safe by the scope guard in affected-suites.tests.ps1.
    Assert-True ($s.Suites -notcontains 'scripts/tests/declared-css.tests.ps1') 'a declared walker whose scope leaves the change out is dropped, though its text names the extension'
    Assert-True ($s.Suites -notcontains 'scripts/tests/declared-open.tests.ps1') 'and so is a declared OPEN walker: the declaration bounds the walk, not its type'
    Assert-True ($s.Suites -contains 'scripts/tests/scoped.tests.ps1') 'and a walker whose declared scope the change falls in runs, named extension or not'
    Assert-True ($s.Suites -contains 'scripts/tests/walks-open.tests.ps1' -and $s.KeptAlways -contains 'scripts/tests/walks-open.tests.ps1') 'an OPEN walker runs although its text never names css: its walk returns every type (#3316)'

    Assert-True ($s.Suites -contains 'scripts/tests/walks-css.tests.ps1' -and $s.Suites -contains 'scripts/tests/walks-open.tests.ps1') 'while an UNDECLARED walker is still judged by its text and its openness (#3316)'

    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('assets/logo.png')
    Assert-True ($s.Suites -notcontains 'scripts/tests/walks-css.tests.ps1') 'the extension guard is per change: a PNG does not keep the walk that names css'

    $script:stub = [pscustomobject]@{ Proven = $false; PoolCount = 164; Matched = @(); Always = @(); Scoped = @(); Walkers = @(); Reason = 'git could not list the tree' }
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('web/src/index.css')
    Assert-True (-not $s.Proven) 'an unproven map is an unproven selection, so the caller runs the whole pool'
    Assert-Equal 'git could not list the tree' $s.Reason 'and the map''s reason is passed through'

    $script:stub = $null
    $s = Get-StaticAssetSuiteSelection -RepoRoot $fixture -ChangedPaths @('web/src/index.css', 'scripts/x.ps1')
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
Write-Host 'the parse cache travels between runs (#3393)' -ForegroundColor Cyan
# The path ci.yml carries must be the one the selection reads: the cache file's leaf, in the git directory.
. (Join-Path $RepoRoot 'scripts\lib\gate-lib.ps1')
$leaf = Split-Path -Leaf (Get-SuiteReferenceCachePath -RepoRoot $RepoRoot)
Assert-Equal 2 ([regex]::Matches($ci, "path: \.git/$([regex]::Escape($leaf))")).Count "the restore and the save both carry .git/$leaf, the file the selection reads"
Assert-True ($ci -match "(?s)- name: Restore the suite selection's parse cache\s+if: \`$\{\{ matrix\.shard == 1 \}\}") 'only shard 1 restores it: the one job that parses'
Assert-True ($ci -match "(?s)Restore the suite selection's parse cache.*?- name: PR suite selection.*?- name: Save the suite selection's parse cache") 'the restore comes before the selection, and the save after it'
Assert-True ($ci -match "if: \`$\{\{ matrix\.shard == 1 && github\.event_name == 'push' && github\.ref == 'refs/heads/main' && steps\.suite-refs-cache\.outputs\.cache-hit != 'true' \}\}") 'only the trunk saves, since a PR''s cache is visible to that PR alone'
Assert-True ($script -match "\`$Shard -eq 1 -and \`$env:GITHUB_EVENT_NAME -eq 'push' -and \`$env:GITHUB_REF -eq 'refs/heads/main'") 'and the script warms it on that same push, in that same shard'

Write-Host ''
Write-Host ("ci-suite-selection-lib: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
