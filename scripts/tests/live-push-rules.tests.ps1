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
Write-Host 'Deletions -- their own command, never a push row (#2566, #2641)' -ForegroundColor Cyan

# THE CONSUMER'S SHAPE: theme files deleted in the range beside one that changed, a deleted script, and a
# deletion a sync mirrored in from live.
$delRows = @(Get-LivePushRows -ChangedPaths @('sections/hero.liquid', 'locales/es.json', 'templates/index.context.spanje.json', 'scripts/old.ps1', 'snippets/gone-on-live.liquid') `
                              -DeletedPaths @('locales/es.json', 'templates\index.context.spanje.json', 'scripts/old.ps1', 'snippets/gone-on-live.liquid') `
                              -SyncOwnedPaths @('snippets/gone-on-live.liquid'))
Assert-Equal 5 $delRows.Count 'a deleted path still gets a row'
Assert-Equal 1 @($delRows | Where-Object { $_.Push }).Count 'only the changed theme file is pushed -- no deleted one is'
$delEs = @($delRows | Where-Object { $_.Path -eq 'locales/es.json' })[0]
Assert-Equal 'deleted' $delEs.Kind 'a deleted theme file is reported as deleted'
Assert-True ($delEs.Reason.Contains('REMOVES it from live')) '...with the reason a reader can act on: an --only push of it deletes it (#2641)'
Assert-True (-not $delEs.Reason.Contains('cannot remove')) '...and never the retired claim that a push cannot remove it (#2641)'
Assert-Equal 'deleted' @($delRows | Where-Object { $_.Path -eq 'templates/index.context.spanje.json' })[0].Kind 'the deleted set matches across separator spellings'
Assert-Equal 'not-a-theme-path' @($delRows | Where-Object { $_.Path -eq 'scripts/old.ps1' })[0].Kind 'a deleted non-theme path is still reported as not a theme path'
Assert-Equal 'sync-owned' @($delRows | Where-Object { $_.Path -eq 'snippets/gone-on-live.liquid' })[0].Kind 'a deletion a sync mirrored from live is sync-owned -- it is already gone there'
Assert-True @(Get-LivePushRows -ChangedPaths @('sections/hero.liquid'))[0].Push 'with no deleted set, nothing changes for a caller that passes none'

# BOTH DRIVERS FEED THE SET, and read the range with renames split so a renamed file's old path is in it.
# The drivers read git and the Shopify CLI, so this is asserted on their source rather than by running them.
$pfSrc = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\task\live-preflight.ps1') -Raw
$prSrc = Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\scripts\task\prepare-release.ps1') -Raw
foreach ($drv in @(@{ Name = 'live-preflight'; Src = $pfSrc }, @{ Name = 'prepare-release'; Src = $prSrc })) {
    Assert-True ($drv.Src -match 'Get-LivePushRows\b[^\r\n]*-DeletedPaths') "$($drv.Name) passes the range's deletions to Get-LivePushRows"
    Assert-True ($drv.Src -match "'--no-renames',\s*'--name-only',\s*'--diff-filter=D'") "$($drv.Name) reads the deletions with renames split"
    Assert-True ($drv.Src -notmatch "'diff',\s*'--name-only'") "$($drv.Name) has no range read left with rename detection on"
    Assert-True ($drv.Src -notmatch 'push cannot (remove|carry)') "$($drv.Name) no longer claims a push cannot remove a file (#2641)"
}

# THE LIVE THEME'S ROLE HAS TWO SPELLINGS, and every reader of it accepts both (#2798). Shopify CLI 4.8.x
# reports 'live'; a 'main'-only compare in step 5 left the id/role refusal unable to fire. Asserted on the
# source because the preflight needs a store to run, and across every reader so none drifts back alone.
Assert-True ($pfSrc -match "\`$byRole = [^\r\n]*@\('live', 'main'\) -contains") "live-preflight's role check accepts both 'live' and 'main'"
foreach ($reader in @('scripts\task\live-preflight.ps1', 'scripts\lib\theme-lifecycle-rules.ps1', 'scripts\lib\theme-archive-rules.ps1')) {
    $mainOnly = @((Get-Content -LiteralPath (Join-Path $RepoRoot $reader)) | Where-Object { $_ -match "-eq 'main'" -and $_ -notmatch "'live'" })
    Assert-Equal 0 $mainOnly.Count "$reader has no role compare that accepts 'main' without 'live'"
}

# THE PREFLIGHT COMPOSES THE DELETION AS ITS OWN COMMAND, drift-checked on its own (#2641). Asserted on the
# source for the reason above: the driver needs git, the CLI and a store to run.
Assert-True ($pfSrc -match '\$deleteCommand = Format-LivePushCommand [^\r\n]*-Only \$deleteFiles') 'live-preflight composes the deletion command from the deleted paths'
Assert-True ($pfSrc -match 'Invoke-DriftCheck -Paths \$deleteFiles') 'live-preflight runs the drift check on the deleted paths'
Assert-True ($pfSrc -match 'if \(-not \$deleteWithheld\)') 'a drift refusal on the deletions withholds the deletion command'
Assert-True ($pfSrc -match '& \$driftFull -Only \$Paths \| Out-Host') "the drift check's own output goes to the host, never into the exit code Invoke-DriftCheck returns"
Assert-Equal 2 ([regex]::Matches($pfSrc, '\$deleteWithheld = \$true')).Count 'a deletion is withheld both on a drift refusal and when there is no drift check at all'
Assert-True ($pfSrc -match '-DeletionsCarried:\(\[bool\]\$deleteCommand\)') 'the record marks deletions live only when the command was composed'

# A DELETION COMMAND IS THE PUSH BUILDER'S OWN SPELLING: one --only per path, never an empty --only list.
$delCmd = Format-LivePushCommand -Store 's.myshopify.com' -ThemeId '123' -Only @('locales/es.json', 'templates/index.context.spanje.json')
Assert-Equal 'shopify theme push --store s.myshopify.com --theme 123 --only locales/es.json --only templates/index.context.spanje.json --allow-live' $delCmd 'the deletion command is one --only per deleted path, and carries no --nodelete'
Assert-Equal '' (Format-LivePushCommand -Store 's' -ThemeId '1' -Only @()) 'no deletions, no deletion command -- never a bare theme push'

# WHICH COMMITS CAME IN THROUGH A SYNC (#2509: out of live-preflight.ps1, so prepare-release reads the same
# rule). Both merge shapes, and the commit that merely mentions nothing sync-shaped is not a row.
$heads = @(Get-SyncMergeCommits -SyncPrefix 'sync/' -LogLines @(
    "m1`tp1 p2`tmerge: sync/2026-09-20 (#123)",
    "s1`tp3`tsync/2026-09-21: mirror live (#124)",
    "f1`tp4`tfeat: a filter",
    'not a log line'))
Assert-Equal 2 $heads.Count 'two sync-shaped commits, one of each merge shape, and nothing else'
Assert-True ($heads[0].IsMerge -and $heads[0].FirstParent -eq 'p1') 'a merge names its first parent, so the caller can list what it brought in'
Assert-True (-not $heads[1].IsMerge) 'a squash is the whole of its own sync'
Assert-Equal 0 @(Get-SyncMergeCommits -SyncPrefix '' -LogLines @("m1`tp1 p2`tmerge: sync/x")).Count 'no prefix, no sync commits -- the direction that excludes nothing'

# THE HEADS ARE READ ON THE TRUNK'S FIRST-PARENT LINE (#2912). A trunk-into-sync merge names the sync branch
# in its subject too, and read as a head it counted our own feature commits as the sync's.
foreach ($drv in @(@{ Name = 'live-preflight'; Src = $pfSrc }, @{ Name = 'prepare-release'; Src = $prSrc })) {
    Assert-True ($drv.Src -match "Get-SyncMergeCommits[^\r\n]*'log', '--first-parent',") "$($drv.Name) reads the sync heads with --first-parent"
}

# WHICH PATHS ONLY THOSE COMMITS TOUCHED. EVERY touching commit, not any: a file the sync mirrored and this
# repo then changed itself is this repo's to push.
$walk = @("COMMIT`tours", 'sections/header.liquid', "COMMIT`tsyncA", 'sections/header.liquid', 'sections/b.liquid', 'sections\c.liquid')
$owned = @(Get-SyncOwnedPaths -WalkLines $walk -SyncCommits @('syncA') | Sort-Object)
Assert-Equal 'sections/b.liquid|sections/c.liquid' ($owned -join '|') 'only the paths no non-sync commit touched, with separators normalised'
Assert-Equal 0 @(Get-SyncOwnedPaths -WalkLines $walk -SyncCommits @()).Count 'no sync commits, nothing sync-owned'

# UNDER A StrictMode CALLER, WITH NO DIRECTORIES PASSED (#2509). @() of a $null [string[]] stays $null in
# Windows PowerShell 5.1, and '.Count' on it threw the first time a strict script called this.
$strictRows = & { Set-StrictMode -Version Latest; @(Get-LivePushRows -ChangedPaths @('sections/a.liquid')) }
Assert-Equal 'theme-file' $strictRows[0].Kind 'a strict caller gets the default eight directories, not a throw'

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
Write-Host 'Paste safety -- a path that would run when pasted never reaches the command (#2514)' -ForegroundColor Cyan

# THE THREE MEASURED SHAPES, each of which the unchecked command printed as-is.
$subexpr = 'assets/$(calc.exe).css'
$semi    = 'assets/a;calc.css'
$newline = "assets/a`ncalc.css"
foreach ($bad in @($subexpr, $semi, $newline, 'assets/a b.css', 'assets/a|b.css', 'assets/a&b.css', 'assets/`a.css', "assets/a'b.css", '-x/a.css', ('assets/a' + [char]0x202E + 'b.css'), ('assets/e' + [char]0x0301 + '.css'), ('assets/x' + [char]0x01C0 + 'y.css'), ('assets/' + [char]0x00D7 + '.css'), ('assets/' + [char]0x212A + '.css'), ('asset' + [char]0x017F + '/foo.css'))) {
    $u = @(Get-LivePushUnsafePaths -Paths @('sections/header.liquid', $bad))
    Assert-Equal 1 $u.Count "refused: $($bad -replace '[^\x20-\x7E]', '?')"
}

# WHAT MUST STILL PASS. The ordinary theme path, and the accented one #821 measured in a consumer store:
# refusing that would block its live push for as long as the file is in the range.
$ok = @('sections/header.liquid', 'assets/theme.min.css', 'snippets/product_card-v2.liquid', 'locales/en.default.json', ('assets/caf' + [char]0x00E9 + '.css'), ('templates/' + [char]0x00C5 + 'rhus.json'))
Assert-Equal 0 @(Get-LivePushUnsafePaths -Paths $ok).Count 'ordinary and Latin-accented theme paths are all safe'
Assert-Equal 0 @(Get-LivePushUnsafePaths -Paths $null).Count 'a null list has nothing unsafe in it'
Assert-Equal 0 @(Get-LivePushUnsafePaths -Paths @('', '  ')).Count 'nor does a list of blanks, which the command drops anyway'
Assert-Equal 2 @(Get-LivePushUnsafePaths -Paths @($semi, 'assets/ok.css', $subexpr)).Count 'every unsafe path is returned, not only the first'
Assert-Equal $semi (@(Get-LivePushUnsafePaths -Paths @($semi, 'assets/ok.css', $subexpr)))[0] '...in input order'

# THE BACKSTOP. A caller that skipped the check gets a throw, never a command -- and the throw names a
# count, not the path, because the path is exactly the text that must not reach a console unguarded.
$thrown = $null
try { [void](Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only @('sections/header.liquid', $subexpr)) } catch { $thrown = $_.Exception.Message }
Assert-True ($null -ne $thrown) 'Format-LivePushCommand throws on a path unsafe to paste'
Assert-True ($null -ne $thrown -and -not $thrown.Contains('calc')) '...and the message does not carry the path'
$accented = Format-LivePushCommand -Store 'example.myshopify.com' -ThemeId '123456' -Only @('assets/caf' + [char]0x00E9 + '.css')
Assert-True ($accented.Contains('--only assets/caf' + [char]0x00E9 + '.css')) 'an accented path is composed like any other'

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

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The Git-connected live theme -- the promotion step and its command (#3008)' -ForegroundColor Cyan

$ok = Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live' -PromotionPaths @('sections/a.liquid', 'assets/b.css')
Assert-Equal 'pass' $ok.State 'paths to promote and no owed back-flow pass'
Assert-Equal 'promotion' $ok.Name '...under the step name the verdict fold reports'
Assert-True ($ok.Detail -match '2 path') '...and the detail counts what the promotion carries'

# OWED BACK-FLOW REFUSES, even with work to promote -- the cut after it would describe a theme that is not live.
$owed = Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live' -PromotionPaths @('sections/a.liquid') -BackflowPaths @('templates/index.json')
Assert-Equal 'refuse' $owed.State 'a live edit not yet on the trunk refuses the promotion'
Assert-True ($owed.Detail -match 'back-flow') '...and points at the back-flow PR'

# NOTHING TO PROMOTE REFUSES -- and the owed back-flow is reported first when both hold.
Assert-Equal 'refuse' (Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live').State 'identical trees refuse: nothing to promote'
Assert-True ((Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live' -BackflowPaths @('x.json')).Detail -match 'back-flow') 'owed back-flow is the refusal reported when both hold'
Assert-Equal 'refuse' (Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live' -PromotionPaths @('', ' ')).State 'blank paths are not paths to promote'

Assert-Equal 'refuse' (Get-LivePromotionStep -Trunk 'main' -DeployBranch 'MAIN' -PromotionPaths @('a')).State 'the deploy branch may not be the trunk'
Assert-Equal 'refuse' (Get-LivePromotionStep -Trunk 'main' -DeployBranch 'live"; x' -PromotionPaths @('a')).State 'an unprintable deploy branch refuses'
Assert-Equal 'refuse' (Get-LivePromotionStep -Trunk 'main' -DeployBranch 'a..b' -PromotionPaths @('a')).State 'a deploy branch holding .. refuses'

# THE STEP FOLDS LIKE ANY OTHER -- a refusal blocks the whole preflight.
Assert-True (-not (Get-LivePreflightVerdict -Steps @($ok, $owed)).Allowed) 'a refused promotion step makes the preflight refuse'

# THE COMMAND IS A PULL REQUEST INTO THE DEPLOY BRANCH, never a push.
$cmd = Format-LivePromotionCommand -Trunk 'main' -DeployBranch 'live' -Version 'v2.48.0'
Assert-Equal 'gh pr create --base live --head main --title "promote: main to live for v2.48.0" --body "Promotes main to the live theme''s deploy branch."' $cmd 'the promotion command, exactly'
Assert-True ($cmd -notmatch 'git push') '...and it is not a push'
Assert-True ((Format-LivePromotionCommand -Trunk 'main' -DeployBranch 'live') -match '--title "promote: main to live"') 'without a version the title names no version'
Assert-True $(try { Format-LivePromotionCommand -Trunk 'main' -DeployBranch 'li$(x)ve' | Out-Null; $false } catch { $true }) 'an unprintable branch name is a throw, not a command'
Assert-True $(try { Format-LivePromotionCommand -Trunk 'main' -DeployBranch 'live' -Version '2.48"' | Out-Null; $false } catch { $true }) 'a version that is not X.Y.Z is a throw'

# THREE INPUTS THE REVIEW MEASURED PASSING A '^...$' -match (#3008): a trailing newline ('$' matches
# before it), the Kelvin sign (case-insensitive [A-Za-z]) and an Arabic-Indic digit (\d is Unicode).
$kelvin = 'live' + [char]0x212A
Assert-True (-not (Test-LivePromotionRef "live`n")) 'a branch name with a trailing newline is not printable'
Assert-True (-not (Test-LivePromotionRef "live`r`n")) '...nor with a trailing CRLF'
Assert-True (-not (Test-LivePromotionRef $kelvin)) 'the Kelvin sign is not an ASCII letter'
Assert-True $(try { Format-LivePromotionCommand -Trunk 'main' -DeployBranch "live`n" | Out-Null; $false } catch { $true }) 'a trailing newline never reaches a printed command'
Assert-True $(try { Format-LivePromotionCommand -Trunk 'main' -DeployBranch 'live' -Version ('2.4' + [char]0x0663 + '.0') | Out-Null; $false } catch { $true }) 'a Unicode digit is not a version digit'

# THE TWO VALIDATORS HOLD ONE PATTERN IN TWO DEPENDENCY-FREE FILES, so they are held to the same answers.
. (Join-Path $RepoRoot 'scripts\lib\live-record-lib.ps1')
foreach ($name in @('live', 'main', 'release/v2', 'a.b_c-d', '-live', 'a..b', "live`n", 'li ve', 'li"ve', $kelvin, '')) {
    Assert-Equal (Test-LivePromotionRef $name) (Test-LiveRecordPromotionValue -Sha 'abcdef1' -Branch $name) "the push rules and the record agree on '$($name -replace "`n", '\n')'"
}

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The Git-connected live theme -- the write-back step (#3009)' -ForegroundColor Cyan

$clean = Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites @()
Assert-Equal 'pass' $clean.State 'an empty rule-suite log passes'
Assert-Equal 'write-back' $clean.Name '...under the step name the verdict fold reports'

$passOnly = @([pscustomobject]@{ result = 'pass'; actor_name = 'shopify[bot]'; pushed_at = '2026-10-14T10:00:00Z' })
Assert-Equal 'pass' (Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $passOnly).State 'a suite that passed is not a rejection'

# A REJECTION REFUSES, whoever the actor -- the bot's name is not measured, so no name is filtered out.
$rejected = @(
    [pscustomobject]@{ result = 'fail'; actor_name = 'shopify[bot]'; pushed_at = '2026-10-14T10:00:00Z' },
    [pscustomobject]@{ result = 'pass'; actor_name = 'someone'; pushed_at = '2026-10-14T11:00:00Z' }
)
$refused = Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $rejected
Assert-Equal 'refuse' $refused.State 'a rejected push to the deploy branch refuses'
Assert-True ($refused.Detail -match '^1 push') '...counting only the failed suites'
Assert-True ($refused.Detail -match 'shopify\[bot\] at 2026-10-14T10:00:00Z') '...and naming the actor and the time'
Assert-True ($refused.Detail -match '-AcceptRejectedWriteBacks') '...and the switch a person sets after reconciling'
Assert-True (-not (Get-LivePreflightVerdict -Steps @($clean, $refused)).Allowed) 'a refused write-back step makes the preflight refuse'

$accepted = Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $rejected -Accepted
Assert-Equal 'warn' $accepted.State 'an accepted rejection is a note, not a pass'
Assert-True (Get-LivePreflightVerdict -Steps @($accepted)).Allowed '...and it lets the preflight through'

# UNREADABLE IS A SKIP, never a pass: a skip is named in the summary.
$blind = Get-LiveWriteBackStep -DeployBranch 'live' -Unreadable
Assert-Equal 'skip' $blind.State 'an unreadable log is a skip'
Assert-True ((Get-LivePreflightVerdict -Steps @($blind)).Skipped.Count -eq 1) '...which the verdict names'

# API TEXT IS CUT TO A PLAIN SET before it is printed.
$hostile = @([pscustomobject]@{ result = 'FAIL'; actor_name = ("x" + [char]27 + "[2J;rm"); pushed_at = "2026`n10" })
$hd = (Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $hostile).Detail
Assert-True ($hd -notmatch "[\x00-\x1f;]") 'control characters and ; from the API never reach the detail'
Assert-True ($hd -match '^1 push') 'the result is compared case-insensitively'

Assert-Equal 'refuse' (Get-LiveWriteBackStep -DeployBranch "live`n" -RuleSuites @()).State 'an unprintable deploy branch refuses in the step itself'
$long = @([pscustomobject]@{ result = 'fail'; actor_name = ('a' * 200); pushed_at = 't' })
Assert-True ((Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $long).Detail -notmatch 'a{41}') 'an actor name is capped at 40 characters'

# -Since IS THE LAST PROMOTION: a rejection before it was the previous preflight's to refuse on.
$timed = @(
    [pscustomobject]@{ result = 'fail'; actor_name = 'old'; pushed_at = '2026-10-01T10:00:00Z' },
    [pscustomobject]@{ result = 'fail'; actor_name = 'new'; pushed_at = '2026-10-10T10:00:00Z' }
)
$cutAt = [datetime]::Parse('2026-10-05T00:00:00Z', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
$sinceStep = Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $timed -Since $cutAt
Assert-True (($sinceStep.Detail -match '^1 push') -and ($sinceStep.Detail -match 'new at') -and ($sinceStep.Detail -notmatch 'old at')) 'only rejections after the last promotion count'
Assert-Equal 'pass' (Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites @($timed[0]) -Since $cutAt).State 'a rejection before the last promotion alone passes'
$noTime = @([pscustomobject]@{ result = 'fail'; actor_name = 'x'; pushed_at = 'not a time' })
Assert-Equal 'refuse' (Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $noTime -Since $cutAt).State 'an unparseable time is kept, never read as old'
Assert-Equal 'refuse' (Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $timed[1]).State 'a single suite, not wrapped in an array, still counts'

$many = @(1..5 | ForEach-Object { [pscustomobject]@{ result = 'fail'; actor_name = "a$_"; pushed_at = 't' } })
Assert-True ((Get-LiveWriteBackStep -DeployBranch 'live' -RuleSuites $many).Detail -match 'and 2 more') 'more than three rejections are counted, not all listed'

if ($script:fail -eq 0) {
    Write-Host ''
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host ''
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
