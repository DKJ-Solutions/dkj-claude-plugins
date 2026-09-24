<#
.SYNOPSIS
    Tests for scripts/lib/theme-lifecycle-rules.ps1 -- the estate rules behind the live-theme backup,
    its rotation, and the preview sweep (inbound #1965).

.DESCRIPTION
    WHAT THIS SUITE IS ACTUALLY GUARDING, because it is not the ordinary "does the function work"
    case. Two of the three mechanisms these rules serve are DESTRUCTIVE against a real Shopify store,
    and the store they were specified from carries 61 themes of which about 39 belong to other
    people -- a third-party agency, an experimentation tool, an installed app, colleagues' sandboxes.
    A rule that is merely almost right here deletes somebody else's working theme there, and a dry
    run that only counted themes would have looked correct.

    So the asserts below are weighted towards the NEGATIVE cases: the themes that must survive every
    sweep, the states in which rotation must refuse outright, and the copy that looks finished and is
    not. The happy paths are asserted once each; the ways to be wrong are asserted exhaustively.

    THE STORE IS UNREACHABLE FROM HERE AND THAT IS WHY THE RULES ARE PURE. This repo publishes
    plugins and has no theme estate, so nothing in this suite touches a network, a CLI or a
    repo-config -- the same split preview-theme.ps1 made, for the same reason. What CANNOT be
    asserted here is the CLI's own behaviour (that `theme duplicate` fills asynchronously, what
    `theme list --json` returns); those are the consumer's measurements, cited in the lib's header as
    theirs.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\theme-lifecycle-rules.ps1'

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
function Assert-Throws {
    param([scriptblock]$Action, [string]$Label, [string]$Contains = '')
    try {
        & $Action | Out-Null
        $script:fail++; Write-Host "  [FAIL] $Label (nothing was thrown)" -ForegroundColor Red
    } catch {
        if ($Contains -and -not ([string]$_.Exception.Message).Contains($Contains)) {
            $script:fail++; Write-Host "  [FAIL] $Label (thrown, but the message does not carry '$Contains')`n         got: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green
        }
    }
}

Assert-True (Test-Path -LiteralPath $LibPath) 'theme-lifecycle-rules.ps1 exists at its registered source path'
. $LibPath

$prefix = Get-RepoThemePrefix

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The reserved namespace -- what this repo owns, and what it must never claim' -ForegroundColor Cyan

Assert-True ([bool]$prefix)                    'the prefix is non-empty -- an empty one would make every theme repo-owned'
Assert-True (-not $prefix.Contains('/'))       'and carries no slash: Shopify refuses a theme name containing one'

Assert-True (Test-RepoOwnedThemeName -Name ($prefix + 'feat-1965-theme-lifecycle')) 'a theme this repo created is owned'
Assert-True (Test-RepoOwnedThemeName -Name ($prefix + 'backup-20260914-013000'))    'so is a backup'

# THE THEMES THAT MUST SURVIVE. Each of these is a real shape from the consumer's store, and each
# would have been destroyed by a role-based sweep.
foreach ($foreign in @(
    'Impact',                                   # the live theme, by name
    'feat-1965-theme-lifecycle',                # OUR OWN LEGACY SHAPE -- see the migration block below
    'theme-vendor/feat/upsell-options',         # a third-party agency's git integration
    'cro-test-branch-4471',                     # an experimentation tool's theme
    'Kopie live 9-7-2021 - DO NOT DELETE',      # a hand-made backup
    'sandbox-colleague',                        # somebody's sandbox: plain hyphenated, indistinguishable in SHAPE from ours
    'backup-20260914-013000',                   # the backup label WITHOUT our prefix -- not ours
    'DKJ-SOMETHING',                            # a near-miss in the other case
    '',
    '   '
)) {
    Assert-True (-not (Test-RepoOwnedThemeName -Name $foreign)) "not owned by this repo: '$foreign'"
}

# THE BARE PREFIX IS NOT A NAME THIS REPO'S COMPOSERS CAN PRODUCE, so it is not owned. A theme called
# exactly that is far more likely to be somebody experimenting than something to delete.
Assert-True (-not (Test-RepoOwnedThemeName -Name $prefix)) "the bare prefix alone is not owned: '$prefix'"

# CASE-SENSITIVE, DELIBERATELY AND UNLIKE Get-ExternalThemeWarning ONE FILE OVER. That function asks
# "might this be a third party's?" and a loose match costs a needless warning; this one asks "may I
# DELETE this?", where a loose match lets somebody else's theme into the delete set.
Assert-True (-not (Test-RepoOwnedThemeName -Name ($prefix.ToUpper() + 'feat-x'))) 'the ownership test is case-SENSITIVE: the destructive question takes the strict reading'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Composing the reserved names' -ForegroundColor Cyan

Assert-Equal ($prefix + 'feat-1965-theme-lifecycle') (Get-RepoPreviewThemeName -FlatBranchName 'feat-1965-theme-lifecycle') 'a preview name is the prefix plus the flattened branch name'
Assert-True  (Test-RepoOwnedThemeName -Name (Get-RepoPreviewThemeName -FlatBranchName 'feat-x'))                            '...and what it composes is recognised as ours, which is what makes the sweep able to find it'

# DOUBLE-PREFIXING IS THE FAILURE THAT LEAVES AN ORPHAN. A caller that hands back the name it found
# would otherwise create 'dkj-dkj-feat-x' -- a theme neither the lookup nor the sweep recognises, on a
# store with a finite ceiling.
Assert-Equal ($prefix + 'feat-x') (Get-RepoPreviewThemeName -FlatBranchName ($prefix + 'feat-x')) 'an already-prefixed name is returned unchanged rather than prefixed twice'

Assert-Throws { Get-RepoPreviewThemeName -FlatBranchName 'feat/1965-x' } 'a name still carrying a slash is refused here rather than by an opaque CLI error' -Contains "may not contain '/'"
Assert-Throws { Get-RepoPreviewThemeName -FlatBranchName '   ' }         'a blank branch name is refused'

# --- SHOPIFY'S 50-CHARACTER CEILING (inbound #2055) ------------------------------------------------
#
# THE LITERAL 50 IS ASSERTED ON PURPOSE rather than read back from the lib: it is the VENDOR's number,
# and a test that reads the same constant the function reads would agree with any value somebody put
# there. This is the one assert in the file whose subject is not this repo's own convention.
#
# THE MEASURED CASE, from the consumer that filed it: branch
# 'liquid/477-continue-browsing-below-model-picker' composes to 51 characters, one over, and the
# creating push was refused by the platform with 'Name is too long (maximum is 50 characters)'.
$overLongFlat = 'liquid-477-continue-browsing-below-model-picker'
$bounded      = Get-RepoPreviewThemeName -FlatBranchName $overLongFlat
Assert-True (($prefix + $overLongFlat).Length -gt 50)      'the measured branch name really does compose over the ceiling -- otherwise the asserts below prove nothing'
Assert-True ($bounded.Length -le 50)                       'an over-long preview name is shortened to the 50-character ceiling instead of being refused by the platform'
Assert-True ($bounded.StartsWith($prefix))                 '...keeping the reserved prefix, which is the only key the sweep has'
Assert-True (Test-RepoOwnedThemeName -Name $bounded)       '...so a shortened preview is still recognised as ours'

# A NAME THAT FITS IS UNTOUCHED. This is what keeps every preview created before the ceiling landed
# findable by the lookup and sparable by the sweep -- a rewrite here would orphan all of them at once.
Assert-Equal ($prefix + 'feat-x') (Get-RepoPreviewThemeName -FlatBranchName 'feat-x') 'a name that fits is returned unchanged, so existing previews keep their names'

# IDEMPOTENT ON ITS OWN OUTPUT, which the already-prefixed path depends on: the lookup hands back the
# name it found, and a second truncate-and-hash would compose a theme nobody created.
Assert-Equal $bounded (Get-RepoPreviewThemeName -FlatBranchName $bounded) 'a shortened name handed back is returned unchanged rather than shortened twice'

# THE DISCRIMINATOR IS THE WHOLE REASON THIS IS NOT PLAIN TRUNCATION. Two branches sharing a long
# enough head would otherwise map onto ONE theme and push over each other -- a wrong preview reviewed
# as if it were the right one, which is worse than the failed push this repairs.
$sharedHeadA = Get-RepoPreviewThemeName -FlatBranchName ($overLongFlat + '-variant-a')
$sharedHeadB = Get-RepoPreviewThemeName -FlatBranchName ($overLongFlat + '-variant-b')
Assert-True ($sharedHeadA -ne $sharedHeadB) 'two long branch names sharing a head compose to DIFFERENT theme names'
Assert-Equal $sharedHeadA (Get-RepoPreviewThemeName -FlatBranchName ($overLongFlat + '-variant-a')) '...and the shortened name is deterministic, which is what lets three call sites agree on it'

# THE CEILING IS A PARAMETER so a consumer can pin it if Shopify moves the number.
Assert-True ((Get-RepoPreviewThemeName -FlatBranchName $overLongFlat -MaxLength 30).Length -le 30) '-MaxLength pins the ceiling'

# AND A CEILING IT CANNOT HONOUR IS REFUSED rather than quietly exceeded: under the prefix plus the
# discriminator there is no room left for a label, and an unlabelled name is not one this repo's
# composers can ever produce.
Assert-Throws { Get-RepoPreviewThemeName -FlatBranchName $overLongFlat -MaxLength 8 } 'a ceiling too small for the prefix plus the discriminator is refused' -Contains 'smallest workable ceiling'

$stamp = [datetime]::new(2026, 9, 14, 1, 30, 0)
Assert-Equal ($prefix + 'backup-20260914-013000') (Get-BackupThemeName -Timestamp $stamp) 'a backup name carries a sortable timestamp'
Assert-True  (Test-BackupThemeName -Name (Get-BackupThemeName -Timestamp $stamp))         '...and is recognised as a backup'
Assert-True  (Test-RepoOwnedThemeName -Name (Get-BackupThemeName -Timestamp $stamp))      '...and as ours'

# SORTABLE IS THE POINT: rotation orders candidates without parsing a date out of a name.
$older = Get-BackupThemeName -Timestamp ([datetime]::new(2026, 9, 13, 23, 59, 59))
$newer = Get-BackupThemeName -Timestamp ([datetime]::new(2026, 9, 14, 0,  0,  1))
Assert-True ($older -lt $newer) 'backup names sort lexically in time order'

# A PREVIEW IS NOT A BACKUP. If it were, the sweep and rotation would both claim it.
Assert-True (-not (Test-BackupThemeName -Name (Get-RepoPreviewThemeName -FlatBranchName 'feat-x'))) 'a repo-owned PREVIEW is not a backup, so rotation can never take one'
Assert-True (-not (Test-BackupThemeName -Name 'backup-20260914-013000'))                            'and an unprefixed theme called backup-... is not ours to rotate'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Has the duplicate finished filling? (the silent half-empty backup, #1965 point 3)' -ForegroundColor Cyan

# THE MEASURED SHAPE, from the consumer: 38 -> 538 -> 738 -> 833 files over roughly eight minutes,
# with the CLI having returned long before.
Assert-Equal 'filling'  (Get-ThemeFillVerdict -Samples @(38)                     -SourceFileCount 833).Verdict 'one sample is never settled -- the count is also flat before the copy starts'
Assert-Equal 'filling'  (Get-ThemeFillVerdict -Samples @(38, 538)               -SourceFileCount 833).Verdict 'a moving count is still filling'
Assert-Equal 'filling'  (Get-ThemeFillVerdict -Samples @(538, 738, 833)         -SourceFileCount 833).Verdict 'reaching the source count once is not enough while the count is still moving'
Assert-Equal 'complete' (Get-ThemeFillVerdict -Samples @(538, 833, 833)         -SourceFileCount 833).Verdict 'settled AND matching the source is complete'

# THE REFUSAL THIS FUNCTION EXISTS FOR: stable and BELOW the source. The theme exists, is correctly
# named and has the right role -- nothing looks wrong until somebody needs it.
$short = Get-ThemeFillVerdict -Samples @(738, 738, 738) -SourceFileCount 833
Assert-Equal 'short' $short.Verdict                'a count that settles BELOW the source is short, not complete'
Assert-True  ($short.Reason.Contains('833'))       '...and the reason names what was expected'
Assert-True  ($short.Reason.Contains('738'))       '...and what was found'
Assert-Equal 738 $short.Count                      '...and the settled count is reported'

# AN UNKNOWN SOURCE COUNT IS ANSWERED HONESTLY. A caller that could not read the source has not
# measured anything, and 'complete' there would put this function's name on a guess.
Assert-Equal 'unknown' (Get-ThemeFillVerdict -Samples @(833, 833)).Verdict                      'no source count means the verdict is unknown, never complete'
Assert-Equal 'unknown' (Get-ThemeFillVerdict -Samples @()          -SourceFileCount 833).Verdict 'no samples at all is unknown'

# A COPY LARGER THAN THE SOURCE IS NOT SHORT. It can legitimately happen -- the source is read at a
# different moment than the copy -- and refusing there would block a backup that is demonstrably whole.
Assert-Equal 'complete' (Get-ThemeFillVerdict -Samples @(840, 840) -SourceFileCount 833).Verdict 'a copy at or above the source count is complete'

# THE STABILITY WINDOW IS A PARAMETER, because the measured growth came in BURSTS with pauses between
# them -- two equal samples across one pause is exactly the false 'complete' this guards.
Assert-Equal 'filling'  (Get-ThemeFillVerdict -Samples @(738, 738)      -SourceFileCount 738 -StableSamples 3).Verdict 'a wider stability window is not yet satisfied by two equal samples'
Assert-Equal 'complete' (Get-ThemeFillVerdict -Samples @(738, 738, 738) -SourceFileCount 738 -StableSamples 3).Verdict '...and is satisfied by three'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The sweep plan -- every theme gets a row, and only ours may go' -ForegroundColor Cyan

# A MINIATURE OF THE CONSUMER'S STORE. The proportions are what matter: a handful of ours among
# other people's, with live in the middle.
$store = @(
    [pscustomobject]@{ id = '100'; name = 'Impact';                              role = 'main' },
    [pscustomobject]@{ id = '101'; name = ($prefix + 'feat-1900-old');           role = 'unpublished' },
    [pscustomobject]@{ id = '102'; name = ($prefix + 'feat-1965-theme-lifecycle'); role = 'unpublished' },
    [pscustomobject]@{ id = '103'; name = ($prefix + 'backup-20260914-013000');  role = 'unpublished' },
    [pscustomobject]@{ id = '104'; name = 'theme-vendor/feat/upsell-options';    role = 'unpublished' },
    [pscustomobject]@{ id = '105'; name = 'cro-test-branch-4471';                role = 'unpublished' },
    [pscustomobject]@{ id = '106'; name = 'sandbox-colleague';                   role = 'unpublished' },
    [pscustomobject]@{ id = '107'; name = ($prefix + 'feat-1800-dev');           role = 'development' },
    [pscustomobject]@{ id = '108'; name = 'Kopie live 9-7-2021 - DO NOT DELETE'; role = 'unpublished' },
    [pscustomobject]@{ id = '109'; name = ($prefix + 'fix-2032-parked-branch');  role = 'unpublished' }
)

$plan = Get-ThemeSweepPlan -Themes $store -LiveThemeId '100' -KeepNames @($prefix + 'feat-1965-theme-lifecycle') `
    -LivingBranchNames @($prefix + 'fix-2032-parked-branch') -ExternalPrefixes @('theme-vendor/')

Assert-Equal $store.Count $plan.Count 'EVERY theme gets a row, including the ones that stay -- a summary listing only the delete set is unfalsifiable'

function Get-Row { param($Id) @($plan | Where-Object { $_.Id -eq $Id })[0] }

Assert-True ((Get-Row '101').Sweep)      'a spent preview created by this repo is swept'
Assert-True (-not (Get-Row '102').Sweep) 'the CURRENT branch''s own preview is kept'
Assert-True (-not (Get-Row '103').Sweep) 'the backup is kept -- only rotation may remove one'
Assert-True (-not (Get-Row '100').Sweep) 'the live theme is kept'
Assert-True (-not (Get-Row '104').Sweep) 'the agency''s theme is kept'
Assert-True (-not (Get-Row '105').Sweep) 'the experimentation tool''s theme is kept'
Assert-True (-not (Get-Row '106').Sweep) 'a colleague''s sandbox is kept, even though its SHAPE is indistinguishable from ours'
Assert-True (-not (Get-Row '107').Sweep) 'a repo-owned theme in role development is kept -- somebody is running `shopify theme dev` on it'
Assert-True (-not (Get-Row '108').Sweep) 'the hand-made backup is kept'
Assert-True (-not (Get-Row '109').Sweep) 'inbound #2032: a branch that is still alive ELSEWHERE -- not the branch this run stands on -- is kept too'

Assert-Equal 1 (@($plan | Where-Object { $_.Sweep }).Count) 'exactly one theme in this store is sweepable'

# EACH REFUSAL CARRIES ITS OWN REASON, so a dry run reads as "here is what I looked at and why each
# one lives" rather than as a list with one explanation stretched over it.
foreach ($row in @($plan | Where-Object { -not $_.Sweep })) {
    Assert-True ([bool]$row.Reason) "the kept row for '$($row.Name)' says WHY"
}
Assert-True ((Get-Row '104').Reason.Contains($prefix))       'the ownership refusal names the prefix that was missing, so the reader can see what makes a theme ours'
Assert-True ((Get-Row '107').Reason.Contains('development')) 'the role refusal names the role it found'
Assert-True ((Get-Row '103').Reason.Contains('rotate'))      'the backup refusal points at rotation rather than reading as a plain skip'
Assert-True ((Get-Row '102').Reason.Contains('current branch')) 'the kept-name refusal says it is the branch you are standing on'
Assert-True ((Get-Row '109').Reason.Contains('still exists')) 'the living-branch refusal has its OWN reason, distinct from "current branch" -- it is false for every row but one'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Inbound #2032 -- a preview is spared only when its branch is actually named as living' -ForegroundColor Cyan

# THE BUG ITSELF, REPRODUCED: sparing only the CURRENT branch's own preview swept a parked branch's
# preview exactly like a merged branch's -- the one round that is not recoverable. Without
# -LivingBranchNames the theme above is offered for the sweep like any other spent preview.
$parkedOnly = @([pscustomobject]@{ id = '110'; name = ($prefix + 'fix-2032-parked-branch'); role = 'unpublished' })
$parkedPlan = Get-ThemeSweepPlan -Themes $parkedOnly -LiveThemeId '100'
Assert-True $parkedPlan[0].Sweep 'without -LivingBranchNames, a parked branch''s preview is swept just like a merged one -- #2032 reproduced'

# ...AND NAMING THE BRANCH AS LIVING IS WHAT SPARES IT.
$parkedFixed = Get-ThemeSweepPlan -Themes $parkedOnly -LiveThemeId '100' -LivingBranchNames @($prefix + 'fix-2032-parked-branch')
Assert-True (-not $parkedFixed[0].Sweep)                     '...and naming it in -LivingBranchNames spares it'
Assert-True ($parkedFixed[0].Reason.Contains('still exists')) '...with its own reason'

# A NAME IN BOTH -KeepNames AND -LivingBranchNames IS KEPT UNDER THE CURRENT-BRANCH REASON, since
# that test runs FIRST -- the order is the thing worth pinning, not merely that both spare it.
$bothPlan = Get-ThemeSweepPlan -Themes @([pscustomobject]@{ id = '111'; name = ($prefix + 'feat-both'); role = 'unpublished' }) `
    -LiveThemeId '100' -KeepNames @($prefix + 'feat-both') -LivingBranchNames @($prefix + 'feat-both')
Assert-True (-not $bothPlan[0].Sweep)                          'a name in both -KeepNames and -LivingBranchNames is kept'
Assert-True ($bothPlan[0].Reason.Contains('current branch'))   '...under the CURRENT-BRANCH reason, since that test runs first'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The sweep refuses wholesale in the states where it cannot be sure' -ForegroundColor Cyan

# NO LIVE ID: the one thing standing between a sweep and the live theme is knowing which theme that
# is. Missing, nothing is swept -- not "everything except the one with role main".
$blind = Get-ThemeSweepPlan -Themes $store -LiveThemeId '' -ExternalPrefixes @()
Assert-Equal 0 (@($blind | Where-Object { $_.Sweep }).Count) 'with no live theme id known, NOTHING is swept'
Assert-True  (@($blind | Where-Object { $_.Id -eq '101' })[0].Reason.Contains('no live theme id')) '...and the reason says so rather than looking like an ownership miss'

# THE DOUBLED LIVE CHECK. The id says one theme is live and the STORE says another -- the day they
# disagree is the day one of them is the only guard left.
$moved = @(
    [pscustomobject]@{ id = '200'; name = ($prefix + 'feat-x'); role = 'main' },
    [pscustomobject]@{ id = '201'; name = ($prefix + 'feat-y'); role = 'unpublished' }
)
$movedPlan = Get-ThemeSweepPlan -Themes $moved -LiveThemeId '999'
Assert-True (-not (@($movedPlan | Where-Object { $_.Id -eq '200' })[0].Sweep)) 'a theme the STORE calls live is kept even when repo-config names a different id'
Assert-True  (@($movedPlan | Where-Object { $_.Id -eq '200' })[0].Reason.Contains('role')) '...on the role, which is the half that is current'

# A NAMESPACE COLLISION IS RESOLVED AWAY FROM DELETING.
$collision = @([pscustomobject]@{ id = '300'; name = ($prefix + 'vendorthing'); role = 'unpublished' })
$colPlan = Get-ThemeSweepPlan -Themes $collision -LiveThemeId '100' -ExternalPrefixes @($prefix + 'vendor')
Assert-True (-not $colPlan[0].Sweep)                       'a repo-prefixed name that ALSO matches a third-party prefix is refused'
Assert-True ($colPlan[0].Reason.Contains('collision'))     '...and says it is refusing rather than resolving the collision'

# AN UNNAMEABLE THEME IS NEVER DELETED.
$noId = Get-ThemeSweepPlan -Themes @([pscustomobject]@{ id = ''; name = ($prefix + 'feat-z'); role = 'unpublished' }) -LiveThemeId '100'
Assert-True (-not $noId[0].Sweep) 'a theme with no id is never swept -- nothing that cannot be named can be deleted'

Assert-Equal 0 (Get-ThemeSweepPlan -Themes @() -LiveThemeId '100').Count 'an empty store produces an empty plan rather than an error'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Rotation -- exactly one backup, and it refuses rather than emptying the store' -ForegroundColor Cyan

$withBackups = @(
    [pscustomobject]@{ id = '100'; name = 'Impact';                             role = 'main' },
    [pscustomobject]@{ id = '400'; name = ($prefix + 'backup-20260901-120000'); role = 'unpublished' },
    [pscustomobject]@{ id = '401'; name = ($prefix + 'backup-20260914-013000'); role = 'unpublished' },
    [pscustomobject]@{ id = '402'; name = ($prefix + 'feat-x');                 role = 'unpublished' },
    [pscustomobject]@{ id = '403'; name = 'Kopie live 9-7-2021 - DO NOT DELETE'; role = 'unpublished' }
)

$rot = Get-BackupRotationPlan -Themes $withBackups -KeepId '401'
Assert-Equal 2 $rot.Count                                             'rotation''s subject is the backup namespace and nothing else -- two rows, not five'
Assert-True  (-not (@($rot | Where-Object { $_.Id -eq '401' })[0].Delete)) 'the backup just created and verified is retained'
Assert-True  (@($rot | Where-Object { $_.Id -eq '400' })[0].Delete)        'the previous backup rotates out'
Assert-Equal 0 (@($rot | Where-Object { $_.Id -in @('402', '403', '100') }).Count) 'a preview, the hand-made backup and live are not in the plan at all'

# THE TWO REFUSALS. Both are states in which the tempting reading empties the store's only backup.
Assert-Throws { Get-BackupRotationPlan -Themes $withBackups -KeepId '' } `
    'rotation refuses with an empty keep-id -- the signature of a create or verify that did not reach a usable theme' -Contains 'no backup'
Assert-Throws { Get-BackupRotationPlan -Themes $withBackups -KeepId '999' } `
    'rotation refuses when the survivor is not in the list it was given -- caller and store disagree' -Contains 'delete every backup'

# A FIRST-EVER CUT HAS ONE BACKUP AND NOTHING TO ROTATE.
$first = Get-BackupRotationPlan -Themes @([pscustomobject]@{ id = '401'; name = ($prefix + 'backup-20260914-013000'); role = 'unpublished' }) -KeepId '401'
Assert-Equal 1 $first.Count            'the first cut plans one row'
Assert-True  (-not $first[0].Delete)   '...and deletes nothing'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'The cut/push order warning' -ForegroundColor Cyan

Assert-Equal '' (Get-CutOrderWarning -TrunkIsLive $true) 'the documented order (push, then cut) is silent'
$warn = Get-CutOrderWarning -TrunkIsLive $false
Assert-True ([bool]$warn)                             'a cut taken before the push warns'
Assert-True ($warn.Contains('push-then-cut'))         '...naming the order this workflow runs'
Assert-True ($warn.Contains('THEME-LIFECYCLE'))       '...and where the rule is written down'

# BOTH CALLERS READ 'short' THE SAME WAY (#2350, Dave, September 23, 2026): it ends a wait only once the
# deadline has passed. backup-live-theme used to break on the first 'short' while push-preview waited it
# out, and the loops themselves drive a live store, so no scenario here can run them. What CAN be held is
# the shape that made them disagree: a poll loop that breaks on 'short'.
foreach ($caller in @('scripts\task\backup-live-theme.ps1', 'scripts\task\push-preview.ps1')) {
    $callerText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $caller))
    Assert-True ($callerText -match "Verdict -eq 'complete'\)\s*\{\s*break\s*\}") "$caller ends its fill wait early on 'complete'"
    Assert-True (-not ($callerText -match "Verdict -eq 'short'\)\s*\{\s*break\s*\}")) "$caller does NOT end its fill wait on 'short' -- that is judged after the deadline"
}

if ($script:fail -eq 0) {
    Write-Host ''
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host ''
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
