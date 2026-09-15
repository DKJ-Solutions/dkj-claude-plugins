<#
.SYNOPSIS
    Duplicate the live Shopify theme into a reserved backup theme, WAIT until the copy is actually
    complete, and only then rotate the previous backup out. Exactly one backup is retained.

.DESCRIPTION
    This is the closing step of a release cut in a store repo: it records the baseline of WHAT
    SHIPPED, so the third-party drift that accumulates on live between releases has a fixed point to
    be measured from. Inbound #1965.

    THE ORDER IS CREATE -> VERIFY -> ROTATE, AND IT IS THE WHOLE DESIGN.

      1. CREATE. 'shopify theme duplicate' from the live theme into '<prefix>backup-<timestamp>'.
      2. VERIFY. Poll the copy's file count until it settles AND matches the source's. The CLI
         returns long before the copy is complete -- measured in the consumer on September 13, 2026:
         a duplicate of live grew 38 -> 538 -> 738 -> 833 files over roughly eight minutes. A step
         that reported success on step 1 would be reporting on a theme that may hold a fraction of
         what it is meant to protect, and the failure is SILENT: the theme exists, is correctly
         named, and has the right role. A backup nobody verified is worse than no backup, because it
         is relied on.

         THE COUNT IS TAKEN OFF A REAL 'theme pull', NOT OFF 'theme info --json' (#2033). On
         @shopify/cli 4.8.0 -- measured in the consumer on September 15, 2026, the current release,
         not a stale install -- 'theme info --json' carries no 'files' field at any level, so every
         count read that way was -1 and the verify step could never pass; #2031's '--force' repair
         got step 1 past its non-interactive refusal only to fail here instead, reading like a
         permissions problem rather than a JSON shape that moved. Nothing else the CLI's --json
         output exposes carries a count either -- 'theme list --json' answers only id/name/role/
         processing, and 'processing''s semantics are undocumented, so this function does not guess
         at what it means. So each sample now pulls the theme into a scratch directory and counts
         what actually arrived on disk -- heavier than a JSON read, and strictly stronger, because it
         verifies identity rather than trusting a number the CLI reports about itself. This is the
         same verification the #2033 consumer did by hand (pull both themes, compare) to confirm
         their hand-taken baseline.
      3. ROTATE. Only now is the PREVIOUS backup deleted. There is never a window in which the store
         holds no backup at all; that costs one theme slot transiently, which is the price of the
         guarantee.

    A SHORT OR UNVERIFIED COPY FAILS LOUDLY AND ROTATES NOTHING. Both halves matter: the run exits
    non-zero so a cut checklist cannot walk past it, and the OLD backup is still standing, which is
    the state a reader would want if they had been asked.

    WHICH STORE IT TALKS TO, AND WHY NOT Get-ShopifyStoreDomain (#1965 point 4). This script reads
    Get-ShopifyThemeEstateStore, a seam of its own. That looks like duplication of one fact and is
    deliberate: at least one consumer leaves Get-ShopifyStoreDomain UNANSWERED as a brake, because
    answering it makes sync-main's bare route usable -- and that route opens its PR with plain 'gh'
    rather than through the lint and test gates, which sync-main's own header names as the accepted
    cost of not coupling to a workflow plugin. If this script read that seam, the first consumer to
    adopt a backup would lift an unrelated brake as a side effect, and the gate-bypassing route would
    open silently while looking like configuration tidy-up. A seam whose answer authorises something
    else is not a shared fact.

    NEVER PUBLISHES, NEVER TOUCHES LIVE EXCEPT TO READ IT. The duplicate is unpublished by definition,
    the rotation deletes only themes in this repo's own backup namespace, and dkj-subagents-shopify's
    PreToolUse guard blocks a publish independently of anything here.

    THE DELETE IS GUARDED AND IT HAS TO CARRY THE MARKER. That guard refuses every 'shopify theme
    delete' from a session unless the repo has answered Get-ShopifyThemeDeleteMarker and the command
    carries it. That is the right default and this script does not work around it: with the seam
    unanswered the rotation is PRINTED for a person to run rather than performed. What the standing
    approval covers, and its bounds, is stated in dkj-policy-bwj/THEME-LIFECYCLE-portable.md rather
    than assumed here.

.PARAMETER Store
    Store domain, overriding Get-ShopifyThemeEstateStore for this run.

.PARAMETER DryRun
    Report every verdict and change nothing. The default is $false, but a first run in a new store is
    worth doing with it.

.PARAMETER PollSeconds
    Seconds between file-count samples while waiting for the copy to fill. Default 20. Each sample is
    now a real 'theme pull' (#2033), not a JSON read, so the actual gap between samples is this plus
    however long that store's pull takes -- raise it for a large theme rather than let short pulls
    stack up on top of each other.

.PARAMETER TimeoutMinutes
    Give up waiting after this long and fail loudly. Default 20 -- the measured fill took about
    eight, and the bound is there so a stalled copy ends the run rather than the cut. Since each
    sample now pulls the theme (#2033) rather than reading a JSON field, a large theme may need more
    headroom than a small one did under the old, cheaper count.

.PARAMETER RootOverride
    Fixture root, so a suite can drive this against a scratch tree instead of a real store.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/backup-live-theme.ps1 -DryRun

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/backup-live-theme.ps1

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE. scripts/tests/theme-lifecycle-rules.tests.ps1
    pins the rules this script invokes: the reserved namespace, the backup name, the fill verdict in
    all four of its states, and the two states in which rotation refuses outright. THIS SCRIPT ITSELF
    IS NOT DRIVEN, for the same reason push-preview.ps1 is not: every path in it either invokes the
    Shopify CLI against a real store or reads a consumer's repo-config, and a suite must not be able
    to reach a store.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$Store = '',
    [switch]$DryRun,
    [int]$PollSeconds = 20,
    [int]$TimeoutMinutes = 20,
    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\theme-lifecycle-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\theme-archive-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'backup-live-theme.ps1' -OverrideName '-RootOverride'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store. Same one-file test
# push-preview, sync-main and adopt-shopify-floor use for the same distinction.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme estate here to back up. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

# --- The seam answers ------------------------------------------------------------------------------
# Read in a child scope with StrictMode OFF and inside a try, exactly as the live-theme guard and
# sync-main read the same file: repo-config.ps1 belongs to the consumer, so a fault in it must degrade
# to defaults rather than take this script down.
$seam = & {
    Set-StrictMode -Off
    $answers = @{ LiveThemeId = ''; StoreDomain = ''; DeleteMarker = ''; TrunkIsLive = $true }
    $cfg = Join-Path $repoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . $cfg } catch { Write-Warning "scripts/repo-config.ps1 could not be read: $($_.Exception.Message)" }
    }
    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId')       { $answers.LiveThemeId  = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyThemeEstateStore')  { $answers.StoreDomain  = [string](Get-ShopifyThemeEstateStore) }
    if (Test-FunctionDefined 'Get-ShopifyThemeDeleteMarker') { $answers.DeleteMarker = [string](Get-ShopifyThemeDeleteMarker) }
    # OPTIONAL, AND ITS ABSENCE IS NOT A GAP. Answered, it says whether the trunk has reached live, and
    # a 'no' produces the order warning. Unanswered, the documented order is assumed and nothing is
    # said -- a warning printed on every run because a seam is unanswered is a warning nobody reads.
    if (Test-FunctionDefined 'Get-ShopifyTrunkIsLive')       { $answers.TrunkIsLive  = [bool](Get-ShopifyTrunkIsLive) }
    [pscustomobject]$answers
}

$store = ([string]$Store).Trim()
if (-not $store) { $store = ([string]$seam.StoreDomain).Trim() }
if (-not $store) {
    Write-Host 'REFUSED: no store domain.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyThemeEstateStore in scripts/repo-config.ps1, or pass -Store for this run.'
    Write-Host 'It is deliberately NOT Get-ShopifyStoreDomain: answering that one also unlocks sync-main''s'
    Write-Host 'bare PR route, which opens a PR without this repo''s lint and test gates (#1965).'
    exit 1
}

$liveId = ([string]$seam.LiveThemeId).Trim()
if (-not $liveId) {
    Write-Host 'REFUSED: no live theme id known.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyLiveThemeId in scripts/repo-config.ps1. This script duplicates the LIVE theme,'
    Write-Host 'so it refuses to guess which one that is rather than backing up an arbitrary theme.'
    exit 1
}

Write-Host "== backup-live-theme -- $store ==" -ForegroundColor Cyan
if ($DryRun) { Write-Host '   DRY RUN: every verdict is reported and nothing is created, deleted or pushed.' -ForegroundColor Yellow }

$orderWarning = Get-CutOrderWarning -TrunkIsLive ([bool]$seam.TrunkIsLive)
if ($orderWarning) { Write-Warning $orderWarning }

# --- Read the estate -------------------------------------------------------------------------------
function Get-ThemeList {
    # -Quiet AND -DiscardStderr, and both are required rather than tidy: the CLI writes a hint line to
    # stderr WHILE SUCCEEDING under Claude Code, which ConvertFrom-Json then refuses as a JSON
    # primitive. This is the exact call a consumer's break was measured on.
    $list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $store, '--json') -Quiet -DiscardStderr
    if ($list.ExitCode -ne 0) { Write-Error 'shopify theme list failed.'; exit 1 }
    $parsed = $null
    try { $parsed = ($list.Output | Out-String) | ConvertFrom-Json } catch {
        Write-Error "Could not read 'shopify theme list --json' output as JSON."
        exit 1
    }
    # THE WRAPPER TEST IS ON THE PROPERTY, NOT ON TRUTHINESS. '$array.themes' does member enumeration
    # in PowerShell 5.1 and yields an array of $null that is not empty and is therefore truthy -- the
    # trap that made a consumer's name lookup always report 'not found'.
    if ($parsed -isnot [System.Array] -and $parsed.PSObject.Properties.Name -contains 'themes') { return @($parsed.themes) }
    return @($parsed)
}

$themes = Get-ThemeList
Write-Host "  the store holds $($themes.Count) theme(s)."

$sourceCount = -1
$liveTheme = @($themes | Where-Object { $_ -and ([string]$_.id).Trim() -eq $liveId })
if ($liveTheme.Count -eq 1) {
    Write-Host "  live theme: $($liveTheme[0].name) (id $liveId, role $($liveTheme[0].role))."
} else {
    Write-Host "REFUSED: the configured live theme id ($liveId) is not in the store's theme list." -ForegroundColor Red
    Write-Host 'Get-ShopifyLiveThemeId has gone stale, or this is the wrong store. Nothing was changed.'
    exit 1
}

# --- Step 1: create --------------------------------------------------------------------------------
$backupName = Get-BackupThemeName -Timestamp ([datetime]::Now)
Write-Host ''
Write-Host "[1/3] create -- duplicating live into '$backupName'" -ForegroundColor Cyan

# ONE ARGUMENT LIST, READ BY BOTH BRANCHES (inbound #2031). It was two spellings -- a literal string in
# the dry run and an array in the call -- and they drifted in the direction that costs most: the dry run
# printed a command that could not succeed, so the one mode a session can safely run reported the defect
# as the intended behaviour. Same lesson as Format-ThemeDeleteCommand's property 2 in
# lib/theme-archive-rules.ps1, one call over: a documented command and the command that runs are the same
# bytes or they are not the same command.
#
# --force IS WHY THIS STEP EXISTED AND NEVER RAN. The CLI declares it "Required if non interactive
# outside CI" (measured against Shopify CLI 4.8.0: shopify theme duplicate --help), and an agent session
# has no TTY -- so the duplicate failed at 1/3 every time, while CLAUDE.md in both BWJ consumer repos
# names this script as the closing step of a release cut. The failure was clean, which is why it went
# unnoticed: nothing was created, nothing was rotated, and the message correctly said the previous backup
# still stood. A store following the documented procedure simply never got a baseline.
#
# --theme IS THE SECOND HALF OF THE SAME SENTENCE and was already right. The same help calls it "Required
# if non interactive", because --force suppresses the theme-selection prompt as well as the confirmation;
# a duplicate forced without a theme id has nothing to duplicate. Named here so a later reader does not
# read the flag as decoration and take it out.
$dupArgs = @('theme', 'duplicate', '--store', $store, '--theme', $liveId, '--name', $backupName, '--force')

if ($DryRun) {
    Write-Host "  DRY RUN: would run 'shopify $($dupArgs -join ' ')'."
} else {
    $dup = Invoke-ShopifyCli -Arguments $dupArgs
    if ($dup.ExitCode -ne 0) {
        Write-Error "Duplicating the live theme failed. Nothing was rotated; the previous backup is still standing."
        exit 1
    }
}

# THE ID IS READ BACK OFF A FRESH LIST RATHER THAN PARSED OUT OF THE DUPLICATE'S OUTPUT. The name is
# ours and unique by its timestamp, so the list is the authoritative answer -- and it is the same read
# rotation needs anyway, so this costs nothing and removes one thing that can be parsed wrong.
$backupId = ''
if (-not $DryRun) {
    $after = Get-ThemeList
    $hit = @($after | Where-Object { $_ -and ([string]$_.name).Trim() -eq $backupName })
    if ($hit.Count -eq 1) { $backupId = ([string]$hit[0].id).Trim() }
    if (-not $backupId) {
        Write-Error ("The duplicate was created but no theme called '$backupName' is in the theme list. " +
            'Nothing was rotated; the previous backup is still standing.')
        exit 1
    }
    Write-Host "  created: '$backupName' (id $backupId)." -ForegroundColor Green
}

# --- Step 2: verify --------------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/3] verify -- waiting for the copy to finish filling' -ForegroundColor Cyan
Write-Host '  the CLI returns long before the copy is complete: a duplicate measured in a consumer grew'
Write-Host '  38 -> 538 -> 738 -> 833 files over roughly eight minutes (#1965).'
Write-Host '  each sample pulls the theme and counts files on disk (#2033) -- heavier than a JSON read.'

if ($DryRun) {
    Write-Host '  DRY RUN: would pull the copy into a scratch directory, count its files, and repeat until'
    Write-Host '  the count settles and matches the source.'
} else {
    function Get-ThemeFileCount {
        param([string]$Id)
        # 'theme info --json' carries no file count on current CLI releases (#2033 -- @shopify/cli
        # 4.8.0's schema is fixed to id/name/role/shop/preview_url/editor_url), and 'theme list --json'
        # carries none either (only id/name/role/processing, and 'processing''s meaning is undocumented
        # -- not something this function will guess at). So the count is taken off a real pull: a full
        # 'theme pull' into a scratch directory, counted off what actually landed on disk. A count this
        # cannot take -- the pull fails, or the scratch directory cannot be read back -- is reported as
        # -1 and handled as unknown, exactly as before.
        $pullPath = Join-Path ([System.IO.Path]::GetTempPath()) ('shopify-fill-check-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $pullPath -Force | Out-Null
        try {
            # Not -Quiet: 'theme pull' is one of the two calls in this plugin that can run for minutes
            # and stop mid-way to ask for authentication -- captured, that prompt is invisible and the
            # run reads as still in progress (shopify-cli-lib.ps1's own header). Same call shape
            # sync-main already uses to mirror the live theme into a scratch path.
            $r = Invoke-ShopifyCli -Arguments @('theme', 'pull', '--store', $store, '--theme', $Id, '--path', $pullPath)
            if ($r.ExitCode -ne 0) { return -1 }
            return @(Get-ChildItem -LiteralPath $pullPath -Recurse -File -ErrorAction SilentlyContinue).Count
        } catch {
            return -1
        } finally {
            Remove-Item -LiteralPath $pullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $sourceCount = Get-ThemeFileCount -Id $liveId
    if ($sourceCount -lt 0) {
        Write-Error ("Could not read the LIVE theme's file count, so the copy cannot be judged complete. " +
            "The backup '$backupName' (id $backupId) exists and may be incomplete; nothing was rotated, " +
            'and the previous backup is still standing.')
        exit 1
    }
    Write-Host "  the source holds $sourceCount file(s); polling the copy every $PollSeconds s (giving up after $TimeoutMinutes min)."

    $samples = @()
    $deadline = [datetime]::Now.AddMinutes($TimeoutMinutes)
    $verdict = $null
    while ([datetime]::Now -lt $deadline) {
        $n = Get-ThemeFileCount -Id $backupId
        if ($n -ge 0) { $samples += $n }
        $verdict = Get-ThemeFillVerdict -Samples $samples -SourceFileCount $sourceCount
        Write-Host "    $($verdict.Count) file(s) -- $($verdict.Verdict)"
        if ($verdict.Verdict -eq 'complete') { break }
        if ($verdict.Verdict -eq 'short') { break }
        Start-Sleep -Seconds $PollSeconds
    }

    if ($null -eq $verdict -or $verdict.Verdict -ne 'complete') {
        $why = if ($null -eq $verdict) { 'no samples were taken' } else { $verdict.Reason }
        Write-Error ("The backup is NOT verified complete: $why. '$backupName' (id $backupId) is left " +
            'standing so it can be inspected, nothing was rotated, and the previous backup is still ' +
            'there. A backup nobody verified is worse than no backup, so this run fails rather than ' +
            'reporting success.')
        exit 1
    }
    Write-Host "  verified: $($verdict.Reason)." -ForegroundColor Green
}

# --- Step 3: rotate --------------------------------------------------------------------------------
Write-Host ''
Write-Host '[3/3] rotate -- exactly one backup is retained' -ForegroundColor Cyan

if ($DryRun) {
    $existing = @($themes | Where-Object { $_ -and (Test-BackupThemeName -Name ([string]$_.name)) })
    if ($existing.Count -eq 0) {
        Write-Host '  DRY RUN: the store holds no backup of ours yet, so the first run would rotate nothing.'
    } else {
        foreach ($b in $existing) { Write-Host "  DRY RUN: would rotate out '$($b.name)' (id $($b.id))." }
    }
    Write-Host ''
    Write-Host 'DRY RUN complete. Nothing was created, deleted or pushed.' -ForegroundColor Yellow
    exit 0
}

$rotation = Get-BackupRotationPlan -Themes $after -KeepId $backupId
$going = @($rotation | Where-Object { $_.Delete })

if ($going.Count -eq 0) {
    Write-Host "  nothing to rotate: '$backupName' is the only backup." -ForegroundColor Green
} else {
    $marker = ([string]$seam.DeleteMarker).Trim()
    foreach ($row in $going) {
        $cmd = Format-ThemeDeleteCommand -Store $store -ThemeId $row.Id -ThemeName $row.Name -DeleteMarker $marker
        if (-not $marker) {
            # THE GUARD'S DEFAULT IS AN ABSOLUTE REFUSAL AND THIS SCRIPT DOES NOT WORK AROUND IT. With
            # no marker answered, the removal is printed for a person to run. That is the repo saying
            # it has not authorised an automatic theme delete, which is a decision rather than a gap.
            Write-Host "  not authorised to delete from a session (Get-ShopifyThemeDeleteMarker is unanswered)." -ForegroundColor Yellow
            Write-Host "  run this yourself to rotate '$($row.Name)' out:" -ForegroundColor Yellow
            Write-Host "    $cmd" -ForegroundColor Cyan
            continue
        }
        Write-Host "  rotating out '$($row.Name)' (id $($row.Id))..." -ForegroundColor Yellow
        $del = Invoke-ShopifyCli -Arguments @('theme', 'delete', '--store', $store, '--theme', $row.Id, '--force')
        if ($del.ExitCode -ne 0) {
            # NOT FATAL, AND THAT IS THE RIGHT DIRECTION. The new backup exists and is verified, which
            # is what the cut needed; a stale extra backup costs one theme slot and is visible on the
            # next run. Failing here would report the whole step as failed when its subject succeeded.
            Write-Warning "Could not delete '$($row.Name)' (id $($row.Id)). The new backup is in place; this one is still standing and will be offered again next time."
        } else {
            Write-Host "  rotated out '$($row.Name)'." -ForegroundColor Green
        }
    }
}

Write-Host ''
Write-Host "Backup complete: '$backupName' (id $backupId) is the baseline of what shipped." -ForegroundColor Green
