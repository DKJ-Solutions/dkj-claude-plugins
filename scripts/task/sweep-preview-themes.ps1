<#
.SYNOPSIS
    Remove the spent preview themes THIS REPO created, after a live push. Every other theme on the
    store is reported and left alone.

.DESCRIPTION
    This is the closing step of a live push in a store repo: the previews the push made spent leave
    the estate, so it does not fill up with themes for branches that merged weeks ago. Inbound #1965,
    whose practical motivation was exactly that -- about 21 repo-created previews still standing,
    including some for branches merged weeks earlier.

    ------------------------------------------------------------------------------------------------
    THE ONE THING THIS SCRIPT MUST NEVER DO IS TREAT 'unpublished' AS 'MINE'.

    The store this was specified from carries 61 themes -- 1 live and 60 unpublished -- and only about
    21 of those were created by the repo. The other ~39 belong to other people: a third-party agency's
    working themes, an experimentation tool's CRO test branches, an installed app's generated themes,
    colleagues' sandboxes, and a hand-made duplicate of live. A sweep keyed on the role would destroy
    every one of them, AND IT WOULD LOOK CORRECT in a dry run that only counted themes.

    So the delete set is defined by something this repo WROTE -- the reserved prefix every theme
    push-preview creates now carries -- and never by something it recognises. The previous key, "the
    name looks like a flattened branch name", cannot serve: several third-party themes on that store
    are plain hyphenated words, indistinguishable in shape from a branch-derived name.

    THAT MAKES THE MIGRATION EXPLICIT RATHER THAN SILENT, and it is the safe direction. A preview
    created BEFORE the reserved prefix landed does not carry it, so this sweep will not touch it --
    it is reported as "not created by this repo", which is literally true of the name. Those are a
    one-time manual cleanup; the alternative, guessing, is what this script exists not to do.
    ------------------------------------------------------------------------------------------------

    WHAT IS NEVER SWEPT, and each is its own refusal rather than one rule stretched over four cases:
    the live theme (by configured id AND by the role the STORE reports), this repo's backup (only the
    release cut rotates that, and only after its replacement is verified), any theme whose role is not
    'unpublished', the current branch's own preview, ANY OTHER BRANCH STILL ALIVE (see below), and any
    name that also matches a third-party prefix.

    ------------------------------------------------------------------------------------------------
    INBOUND #2032: A PARKED BRANCH'S PREVIEW USED TO BE SWEPT LIKE A MERGED ONE'S.

    Sparing only the CURRENT branch's own preview is legal by every rule above and is almost never
    what was meant: a branch parked on the remote with no pull request -- carrying work that exists
    nowhere else -- had its preview swept on the very round that made it unrecoverable. So this run
    also reads which OTHER branches are still alive -- `git ls-remote --heads origin` and a plain
    `git branch` -- and spares every one of their previews too, with its own reason ('the branch
    still exists'). "Still exists" is read deliberately WIDE: a local ref or a remote one, without
    asking whether a PR merged, because `deleteBranchOnMerge` already removes a merged branch's ref,
    so a branch still standing is parked work or a cleanup that has not run yet.

    THE FAILURE DIRECTION MATTERS MORE THAN USUAL HERE: a branch list that is missing a branch is a
    branch whose preview looks spent when it is not. So a `ls-remote`/`branch` call that did not
    answer cleanly REFUSES THE RUN under -Execute rather than silently narrowing the spare list --
    the same asymmetry the live-theme-id check above already applies. Under a dry run it prints a
    loud warning and reports anyway, since nothing is removed by looking.
    ------------------------------------------------------------------------------------------------

    DRY RUN IS THE DEFAULT. A destructive step whose safe mode has to be remembered is one that gets
    run without it; -Execute is the opt-in.

    THE DELETE IS GUARDED AND HAS TO CARRY THE MARKER. dkj-subagents-shopify's PreToolUse guard refuses
    every 'shopify theme delete' from a session unless the repo has answered
    Get-ShopifyThemeDeleteMarker and the command carries it. That default is an absolute refusal and
    this script does not work around it: unanswered, the removals are PRINTED for a person to run.
    What the standing approval covers, and its bounds, is stated in
    dkj-policy-bwj/THEME-LIFECYCLE-portable.md rather than assumed here.

    WHICH STORE IT TALKS TO: Get-ShopifyThemeEstateStore, a seam of its own rather than
    Get-ShopifyStoreDomain. The reasoning is in backup-live-theme.ps1's header -- answering that other
    seam also unlocks sync-main's bare PR route, which opens a PR without the lint and test gates.

.PARAMETER Store
    Store domain, overriding Get-ShopifyThemeEstateStore for this run.

.PARAMETER Execute
    Actually remove the swept themes. Without it this run reports and changes nothing.

.PARAMETER Keep
    Extra theme names to spare, beyond the current branch's own preview and every other branch this
    run finds still alive. Exact names, never patterns.

.PARAMETER RootOverride
    Fixture root, so a suite can drive this against a scratch tree instead of a real store.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/sweep-preview-themes.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/sweep-preview-themes.ps1 -Execute

.NOTES
    COVERAGE. scripts/tests/theme-lifecycle-rules.tests.ps1 pins the plan this script prints and acts
    on -- including a miniature of the consumer's store in which exactly one of nine themes is
    sweepable, the two blind states (no live id known, a namespace collision) in which nothing is, and
    the sixth refusal added for inbound #2032 (a preview whose branch still exists). THIS SCRIPT ITSELF
    IS NOT DRIVEN, for the reason push-preview.ps1 gives: every path reaches a real store, a consumer's
    repo-config, or -- since #2032 -- the remote's own branch list.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$Store = '',
    [switch]$Execute,
    [string[]]$Keep = @(),
    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
# INBOUND #2032's git reads (ls-remote, branch) go through the same guarded, bounded, non-interactive
# capture every other git/gh call in this plugin uses -- NOT fetch-attempt-lib.ps1, which is dkj-policy
# payload only and would be a cross-plugin dependency a Shopify-only consumer does not have.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\theme-lifecycle-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\theme-archive-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'sweep-preview-themes.ps1' -OverrideName '-RootOverride'

if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme estate here to sweep. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

$branch = ([string](git rev-parse --abbrev-ref HEAD)).Trim()

$seam = & {
    Set-StrictMode -Off
    $answers = @{ LiveThemeId = ''; StoreDomain = ''; DeleteMarker = ''; External = @() }
    $cfg = Join-Path $repoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . $cfg } catch { Write-Warning "scripts/repo-config.ps1 could not be read: $(Format-SafeProseToken -Value $_.Exception.Message)" }
    }
    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId')        { $answers.LiveThemeId  = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyThemeEstateStore')   { $answers.StoreDomain  = [string](Get-ShopifyThemeEstateStore) }
    if (Test-FunctionDefined 'Get-ShopifyThemeDeleteMarker')  { $answers.DeleteMarker = [string](Get-ShopifyThemeDeleteMarker) }
    if (Test-FunctionDefined 'Get-ShopifyExternalThemePrefixes') { $answers.External  = @(Get-ShopifyExternalThemePrefixes) }
    [pscustomobject]$answers
}

$store = ([string]$Store).Trim()
if (-not $store) { $store = ([string]$seam.StoreDomain).Trim() }
if (-not $store) {
    Write-Host 'REFUSED: no store domain.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyThemeEstateStore in scripts/repo-config.ps1, or pass -Store for this run.'
    exit 1
}

# THE LIVE ID IS REQUIRED AND ITS ABSENCE STOPS THE RUN RATHER THAN NARROWING IT. Get-ThemeSweepPlan
# already refuses every theme when it is unknown, so this exit only makes the reason loud instead of
# printing nine rows that all say the same thing.
$liveId = ([string]$seam.LiveThemeId).Trim()
if (-not $liveId) {
    Write-Host 'REFUSED: no live theme id known.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyLiveThemeId in scripts/repo-config.ps1. Knowing which theme is live is the'
    Write-Host 'one thing standing between a sweep and the live theme, so this refuses rather than guessing.'
    exit 1
}

# THE FLATTENED PREVIEW NAME FOR A BRANCH -- one answer, read for the current branch below and for
# every OTHER branch still alive. Get-BranchInfo's SafeName where the repo has it, a plain '/'->'-'
# replace where it does not -- the same fallback push-preview has always used.
$biPath = Join-Path $repoRoot 'scripts\lib\branch-info.ps1'
$hasGetBranchInfo = $false
if (Test-Path -LiteralPath $biPath -PathType Leaf) {
    try { . $biPath; $hasGetBranchInfo = Test-FunctionDefined 'Get-BranchInfo' } catch { }
}

# The current branch's own preview, spared by name.
$ownPreview = ''
if ($branch -and $branch -ne 'HEAD') {
    $flat = if ($hasGetBranchInfo) { [string]((Get-BranchInfo -Branch $branch).SafeName) } else { $branch -replace '/', '-' }
    if ($flat) { $ownPreview = Get-RepoPreviewThemeName -FlatBranchName $flat }
}

# EVERY OTHER BRANCH THAT IS STILL ALIVE (inbound #2032) -- see the header banner for why this
# exists and why "still exists" is read wide. A branch list this run cannot fully read is a branch
# list that is MISSING branches, and a missing branch is a swept preview -- so an unreliable read
# refuses the run under -Execute rather than narrowing the spare set silently.
$refListReliable = $true

$lsRemote = Invoke-NativeCapture -FilePath 'git' -Arguments @('ls-remote', '--heads', 'origin') `
                                 -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
# AUDITED UNDER #2081 AND LEFT AS IT IS, here and at the local `git branch` below. Both are written as a
# POSITIVE test, so an unmeasurable exit code (#1931) is not `-eq 0` and clears $refListReliable -- which
# is what makes a real run REFUSE and a dry run say the list was incomplete. That is the fail-closed
# direction for a sweep whose whole hazard is deleting a theme whose branch it could not see, and the
# refusal's own sentence already names the two commands rather than a number, so nothing here printed an
# empty "(exit )". Recorded as deliberate.
$remoteBranchNames = @()
if ($lsRemote.ExitCode -eq 0) {
    $remoteBranchNames = @(@($lsRemote.Output) | ForEach-Object {
        if ("$_" -match 'refs/heads/(.+)$') { $Matches[1] }
    } | Where-Object { $_ })
} else {
    $refListReliable = $false
}

$localBranchList = Invoke-NativeCapture -FilePath 'git' -Arguments @('branch', '--format', '%(refname:short)') -DiscardStderr
$localBranchNames = @()
if ($localBranchList.ExitCode -eq 0) {
    $localBranchNames = @(@($localBranchList.Output) | Where-Object { $_ })
} else {
    $refListReliable = $false
}

if (-not $refListReliable) {
    $refListWarning = "the branch list could not be fully read -- 'git ls-remote --heads origin' or 'git branch' did not answer cleanly, and a branch this run cannot see is a branch it cannot spare"
    if ($Execute) {
        Write-Host "REFUSED: $refListWarning." -ForegroundColor Red
        Write-Host 'Nothing was changed. Fix the remote or the credential and run again.' -ForegroundColor Red
        exit 1
    }
    Write-Host "WARNING: $refListWarning." -ForegroundColor Yellow
    Write-Host '   This dry run may be UNDER-reporting which previews still belong to a living branch.' -ForegroundColor Yellow
}

$livingBranchNames = @(@($remoteBranchNames) + @($localBranchNames) | Where-Object { $_ } | Sort-Object -Unique)
$livingPreviewNames = @($livingBranchNames | ForEach-Object {
    $flat = if ($hasGetBranchInfo) { [string]((Get-BranchInfo -Branch $_).SafeName) } else { $_ -replace '/', '-' }
    if ($flat) { Get-RepoPreviewThemeName -FlatBranchName $flat }
} | Where-Object { $_ })

$keepNames = @(@($Keep) | Where-Object { $_ } | ForEach-Object { ([string]$_).Trim() })
if ($ownPreview) { $keepNames += $ownPreview }

Write-Host "== sweep-preview-themes -- $store ==" -ForegroundColor Cyan
if (-not $Execute) { Write-Host '   DRY RUN (the default): every verdict is reported and nothing is removed. -Execute acts.' -ForegroundColor Yellow }
if ($ownPreview)   { Write-Host "   sparing this branch's own preview: '$ownPreview'" }
Write-Host "   sparing $($livingPreviewNames.Count) preview(s) of branch(es) still alive (local or on origin)"

$list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $store, '--json') -Quiet -DiscardStderr
if ($list.ExitCode -ne 0) { Write-Error 'shopify theme list failed.'; exit 1 }
$parsed = $null
try { $parsed = ($list.Output | Out-String) | ConvertFrom-Json } catch {
    Write-Error "Could not read 'shopify theme list --json' output as JSON."
    exit 1
}
$themes = if ($parsed -isnot [System.Array] -and $parsed.PSObject.Properties.Name -contains 'themes') { @($parsed.themes) } else { @($parsed) }

$plan = Get-ThemeSweepPlan -Themes $themes -LiveThemeId $liveId -KeepNames $keepNames `
    -LivingBranchNames $livingPreviewNames -ExternalPrefixes @($seam.External)

$going = @($plan | Where-Object { $_.Sweep })
$staying = @($plan | Where-Object { -not $_.Sweep })

Write-Host ''
Write-Host "Kept -- $($staying.Count) theme(s):" -ForegroundColor Cyan
# EVERY KEPT THEME IS PRINTED, and that is the design rather than verbosity. A summary that lists only
# the delete set is unfalsifiable: the ~39 themes it must never touch are exactly the rows it would
# not print, so a reader has no way to see that they were considered and spared.
foreach ($row in $staying) {
    Write-Host ("  [keep] {0,-44} {1}" -f $row.Name, $row.Reason) -ForegroundColor DarkGray
}

Write-Host ''
if ($going.Count -eq 0) {
    Write-Host 'Nothing to sweep: no spent preview theme of this repo is standing.' -ForegroundColor Green
    exit 0
}

Write-Host "To sweep -- $($going.Count) theme(s):" -ForegroundColor Yellow
foreach ($row in $going) { Write-Host ("  [sweep] {0,-43} id {1}" -f $row.Name, $row.Id) -ForegroundColor Yellow }

if (-not $Execute) {
    Write-Host ''
    Write-Host 'DRY RUN: nothing was removed. Re-run with -Execute to sweep the themes listed above.' -ForegroundColor Yellow
    exit 0
}

$marker = ([string]$seam.DeleteMarker).Trim()
if (-not $marker) {
    Write-Host ''
    Write-Host 'Not authorised to delete from a session: Get-ShopifyThemeDeleteMarker is unanswered.' -ForegroundColor Yellow
    Write-Host 'That default is an absolute refusal and this script does not work around it. Run these yourself:' -ForegroundColor Yellow
    foreach ($row in $going) {
        $warning = Get-ExternalThemeWarning -Name $row.Name -ExternalPrefixes @($seam.External)
        if ($warning) { Write-Host "  $warning" -ForegroundColor Red }
        Write-Host ('  ' + (Format-ThemeDeleteCommand -Store $store -ThemeId $row.Id -ThemeName $row.Name -DeleteMarker $marker)) -ForegroundColor Cyan
    }
    exit 0
}

Write-Host ''
$removed = 0
$failed = 0
foreach ($row in $going) {
    Write-Host "  removing '$($row.Name)' (id $($row.Id))..." -ForegroundColor Yellow
    $del = Invoke-ShopifyCli -Arguments @('theme', 'delete', '--store', $store, '--theme', $row.Id, '--force')
    if ($del.ExitCode -ne 0) {
        # ONE FAILURE DOES NOT END THE RUN. Each theme is independent, and a sweep that stopped at the
        # first refusal would leave the rest standing for no reason -- the count below is what the
        # reader needs, and the next run offers the same ones again.
        Write-Warning "Could not remove '$($row.Name)' (id $($row.Id)). It is still standing and will be offered again next time."
        $failed++
    } else {
        $removed++
    }
}

Write-Host ''
Write-Host "Swept $removed theme(s); $($staying.Count) left alone." -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "$failed theme(s) could not be removed -- see the warnings above." -ForegroundColor Yellow
    exit 1
}
