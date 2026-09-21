<#
.SYNOPSIS
    Tests for scripts/lib/live-push-rules.ps1 -- the rules behind the live-push preflight: the eight
    theme directories, the derived push list, the release-tag pick, the push command, and the verdict
    fold (inbound #2228).

.DESCRIPTION
    WHAT THIS SUITE IS ACTUALLY GUARDING. These rules decide what reaches a LIVE Shopify theme -- the
    one moment in the release cycle where a mistake is visible to paying customers -- and both ways of
    being wrong cost something different:

      A PUSH LIST THAT IS TOO SHORT ships half a release. The consumer's own measurement is the shape:
      61 changed files, 11 of them on a theme. Drop a directory from the eight and that directory's
      files silently never leave the repo, and nothing says so until somebody sees a half-updated page.

      A PUSH LIST THAT IS TOO LONG overwrites live files nobody changed. That is what a lexically
      sorted tag pick produces -- 'v2.9.0' sorts above 'v2.44.0', so the range starts far too early --
      and it is what pushing a sync-mirrored file does to the third party who wrote it.

    So the asserts below are weighted towards the negative cases: the paths that must NOT be pushed,
    the tag that must NOT win, the empty list that must NOT become a command, and the step state that
    must NOT read as a pass. The happy paths are asserted once each.

    THE STORE IS UNREACHABLE FROM HERE AND THAT IS WHY THE RULES ARE PURE. This repo publishes plugins
    and has no theme estate, so nothing in this suite touches a network, a CLI, git or a repo-config --
    the same split theme-lifecycle-rules.ps1 and preview-theme.ps1 made, for the same reason. What
    CANNOT be asserted here is live-preflight.ps1's own ordering and its git derivation of sync
    provenance; those reach git and a store, which is exactly why everything else was moved into the
    lib this suite drives.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\live-push-rules.ps1'

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

Assert-True (Test-Path -LiteralPath $LibPath) 'live-push-rules.ps1 exists at its registered source path'
. $LibPath

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The eight theme directories -- one definition, and sync-main reads this one' -ForegroundColor Cyan

$dirs = Get-ShopifyThemeDirectoryNames
Assert-Equal 8 $dirs.Count 'there are eight of them'
foreach ($d in @('assets', 'blocks', 'config', 'layout', 'locales', 'sections', 'snippets', 'templates')) {
    Assert-True ($dirs -contains $d) "'$d' is one of them"
}

# THE COPY IS GONE FROM sync-main, and this asserts that rather than trusting it. The whole argument
# for moving the set into a lib was that two copies are free to drift; a suite that did not check the
# second site would leave exactly the drift it was meant to prevent.
$syncMain = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\task\sync-main.ps1') -Raw
Assert-True ($syncMain -match '\$ThemeDirs\s*=\s*Get-ShopifyThemeDirectoryNames') 'sync-main.ps1 reads the shared set'
Assert-True (-not ($syncMain -match "\`$ThemeDirs\s*=\s*@\('assets'")) '...and no longer carries its own literal copy'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The push list -- what leaves the repo, and everything that must not' -ForegroundColor Cyan

# A MINIATURE OF THE CONSUMER'S OWN RANGE (#2228): theme files beside the scripts, tests and docs that
# outnumbered them five to one.
$changed = @(
    'sections/header.liquid',
    'snippets/price.liquid',
    'assets/theme.css',
    'templates/product.json',
    'locales/nl.json',
    'config/settings_schema.json',
    'layout/theme.liquid',
    'blocks/reviews.liquid',
    'scripts/task/live-preflight.ps1',
    'scripts/tests/live-push-rules.tests.ps1',
    'CLAUDE.md',
    'dkj-policy/CHANGELOG.md',
    '.github/workflows/ci.yml',
    'README.md'
)
$rows = Get-LivePushRows -ChangedPaths $changed
Assert-Equal 14 $rows.Count 'every changed path gets a row, including the ones held back'
Assert-Equal 8 @($rows | Where-Object { $_.Push }).Count 'the eight theme files are pushed'
Assert-Equal 6 @($rows | Where-Object { $_.Kind -eq 'not-a-theme-path' }).Count 'the six that do not exist on a theme are held'

foreach ($held in @('scripts/task/live-preflight.ps1', 'CLAUDE.md', 'dkj-policy/CHANGELOG.md', '.github/workflows/ci.yml', 'README.md')) {
    $row = @($rows | Where-Object { $_.Path -eq $held })
    Assert-True ($row.Count -eq 1 -and -not $row[0].Push) "'$held' is never pushed"
}

# A PATH WHOSE NAME MERELY RESEMBLES A THEME DIRECTORY IS NOT ONE. 'scripts/assets/x.css' contains the
# word and is not under assets/, and 'assets' with no file after it is a directory rather than a file.
$edge = Get-LivePushRows -ChangedPaths @('scripts/assets/build.css', 'my-sections/header.liquid', 'assets', 'assets/')
Assert-Equal 0 @($edge | Where-Object { $_.Push }).Count 'a near-miss path is not a theme file'

# SEPARATORS AND CASE, both accepted on the way in, neither rewritten on the way out.
$winRow = @(Get-LivePushRows -ChangedPaths @('sections\hero.liquid'))
Assert-True $winRow[0].Push 'a backslash path is recognised'
Assert-Equal 'sections\hero.liquid' $winRow[0].Path '...and reported back exactly as it arrived'
$caseRow = @(Get-LivePushRows -ChangedPaths @('Sections/Hero.liquid'))
Assert-True $caseRow[0].Push 'the directory test is case-insensitive'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Sync provenance -- a one-way mirror is not pushed back' -ForegroundColor Cyan

$syncRows = Get-LivePushRows -ChangedPaths @('sections/header.liquid', 'sections/media-with-text.liquid', 'scripts/x.ps1') `
                             -SyncOwnedPaths @('sections/media-with-text.liquid')
Assert-Equal 1 @($syncRows | Where-Object { $_.Push }).Count 'a sync-mirrored theme file is held back'
$mirrored = @($syncRows | Where-Object { $_.Path -eq 'sections/media-with-text.liquid' })[0]
Assert-Equal 'sync-owned' $mirrored.Kind '...and is reported as sync-owned rather than as an ordinary skip'
Assert-True ($mirrored.Reason.Contains('already there')) '...with the reason a reader can act on'

# THE ORDER OF THE TWO REFUSALS. A sync-owned path OUTSIDE the theme directories is reported as what it
# primarily is -- not a theme path -- so a reader is not told to look for a sync that is beside the point.
$outside = @(Get-LivePushRows -ChangedPaths @('scripts/x.ps1') -SyncOwnedPaths @('scripts/x.ps1'))
Assert-Equal 'not-a-theme-path' $outside[0].Kind 'the theme-path test runs before the provenance test'

# THE SET IS COMPARED ON THE NORMALISED SPELLING, because the two sides may come from different git
# commands on a Windows checkout.
$mixed = @(Get-LivePushRows -ChangedPaths @('sections/header.liquid') -SyncOwnedPaths @('sections\header.liquid'))
Assert-Equal 'sync-owned' $mixed[0].Kind 'provenance matches across separator spellings'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The release tag -- compared as a version, which is the whole reason it is a function' -ForegroundColor Cyan

# THE MEASURED PAIR. The consumer was preparing v2.44.0 with v2.43.0 behind it, on a repo that also
# holds v2.9.0 -- and 'v2.9.0' sorts ABOVE 'v2.44.0' lexically, which is the trap.
Assert-Equal 'v2.43.0' (Get-HighestReleaseTag -Tags @('v2.9.0', 'v2.43.0', 'v2.10.0', 'v1.99.99')) 'the highest tag is picked numerically, not lexically'
Assert-Equal 'v10.0.0' (Get-HighestReleaseTag -Tags @('v9.9.9', 'v10.0.0')) 'a two-digit major beats a one-digit one'
Assert-Equal 'v2.0.1'  (Get-HighestReleaseTag -Tags @('v2.0.1', 'v2.0.0'))  'the patch component is compared too'
Assert-Equal ''        (Get-HighestReleaseTag -Tags @())                    'no tags means no answer, not a guess'
Assert-Equal ''        (Get-HighestReleaseTag -Tags $null)                  'and a null list is the same answer'

# WHAT IS DELIBERATELY IGNORED, so a repo tagging other things does not have one of them picked.
Assert-Equal 'v1.0.0' (Get-HighestReleaseTag -Tags @('v1.0.0', 'v2.44.0-rc1', '2026-09-21', 'v2', 'release-3')) 'only three-component vX.Y.Z tags are considered'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The push command -- one --only per file, and never the marker' -ForegroundColor Cyan

$cmd = Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only @('sections/header.liquid', 'assets/theme.css')
Assert-Equal 'shopify theme push --store example.myshopify.com --theme 123456 --only sections/header.liquid --only assets/theme.css --allow-live' $cmd 'the command carries one --only per file'
Assert-True (-not $cmd.Contains('LIVE-PUSH-AUTHORIZED')) 'it never carries the authorisation marker'
Assert-True (-not $cmd.Contains('#'))                    '...and no comment at all, which is where a marker would sit'

# THE EMPTY LIST IS THE ONE THAT MATTERS. A 'theme push' with no --only pushes the WHOLE theme, so the
# only safe answer for an empty list is no command at all.
Assert-Equal '' (Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only @())   'an empty list produces no command'
Assert-Equal '' (Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only $null) 'and neither does a null one'
Assert-Equal '' (Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only @('', '   ')) 'nor a list of blanks'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The verdict -- a skip is not a pass, and an unreadable state is a refusal' -ForegroundColor Cyan

$allPass = Get-LivePreflightVerdict -Steps @(
    [pscustomobject]@{ Name = 'trunk'; State = 'pass'; Detail = 'clean' },
    [pscustomobject]@{ Name = 'gates'; State = 'pass'; Detail = 'green' }
)
Assert-True  $allPass.Allowed          'every step passing allows the push to be made'
Assert-Equal 2 $allPass.Passed         '...and counts them'
Assert-True  ($allPass.Summary.Contains('human act')) '...while still saying the marker is a human act'

$oneRefusal = Get-LivePreflightVerdict -Steps @(
    [pscustomobject]@{ Name = 'trunk'; State = 'pass';   Detail = 'clean' },
    [pscustomobject]@{ Name = 'drift'; State = 'refuse'; Detail = 'somebody edited sections/header.liquid on live' },
    [pscustomobject]@{ Name = 'backup'; State = 'pass';  Detail = 'verified' }
)
Assert-True  (-not $oneRefusal.Allowed)   'one refusal refuses the whole run'
Assert-Equal 1 $oneRefusal.Refusals.Count '...and is reported by name'
Assert-Equal 'drift' $oneRefusal.Refusals[0].Name '...naming which step said no'

# A SKIP DOES NOT REFUSE AND DOES NOT DISAPPEAR. Both halves, because the failure this models is a
# checklist reading green while a step sat inert.
$skipped = Get-LivePreflightVerdict -Steps @(
    [pscustomobject]@{ Name = 'gates'; State = 'pass'; Detail = 'green' },
    [pscustomobject]@{ Name = 'drift'; State = 'skip'; Detail = 'no drift check in this repo' }
)
Assert-True  $skipped.Allowed              'an unanswered seam does not refuse the run'
Assert-Equal 1 $skipped.Skipped.Count      '...and is carried out of the fold rather than dropped'
Assert-True  ($skipped.Summary.Contains('could not be measured')) '...and named in the summary'
Assert-Equal 1 $skipped.Passed             'a skip is never counted as a pass'

$warned = Get-LivePreflightVerdict -Steps @([pscustomobject]@{ Name = 'version'; State = 'warn'; Detail = 'nothing pending' })
Assert-True  $warned.Allowed          'a warning does not refuse'
Assert-Equal 1 $warned.Warnings.Count '...and is reported'

# AN UNREADABLE STATE IS A REFUSAL. A caller that mistyped a state has measured nothing, and the safe
# direction on a live push is to stop.
$bogus = Get-LivePreflightVerdict -Steps @([pscustomobject]@{ Name = 'gates'; State = 'ok'; Detail = '' })
Assert-True (-not $bogus.Allowed) "a state the fold does not recognise refuses rather than passing"

# A STEP MISSING ITS FIELDS MUST NOT THROW, and must not read as a pass either -- the same guard
# Test-ReleaseBumpEarned puts on its own caller-built input.
$bare = Get-LivePreflightVerdict -Steps @([pscustomobject]@{ Detail = 'no name, no state' })
Assert-True (-not $bare.Allowed) 'a step with no state at all refuses'
Assert-Equal '(unnamed step)' $bare.Refusals[0].Name '...and is still nameable in the report'

Assert-True (Get-LivePreflightVerdict -Steps @()).Allowed 'an empty run has nothing that says do not push'

if ($script:fail -eq 0) {
    Write-Host ''
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host ''
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
