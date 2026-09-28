<#
.SYNOPSIS
    Push the current branch to its preview theme, creating the theme if the branch has none yet.

.DESCRIPTION
    Four steps decide the target theme, in this order: an explicit -ThemeId, else the id remembered in
    the branch's own git config (branch.<name>.previewTheme), else a name lookup through the theme list,
    and else THIS SCRIPT CREATES THE THEME. Guardrails: it refuses on the trunk and it refuses the live
    theme outright.

    THE LAZY CREATION IS THE POINT, and it is a measured rule rather than a convenience (Dave,
    2026-08-19). A preview theme used to be created for EVERY branch at the moment the branch was made --
    including a docs or tooling branch that could never touch a theme file, which then left an unused
    theme on the store. Measured on the day the rule was made: 49 themes on the store, 47 unpublished, 16
    names carrying a branch prefix, of which 4 were artefacts from another project; of the 12 real branch
    previews, 6 belonged to branches that never needed one. And a Shopify store's theme ceiling is
    FINITE, so an estate filling up with unused previews is not merely untidy -- it eventually refuses
    the next push.

    THE CEILING IS PLAN-DEPENDENT AND IS NOT 20 EVERYWHERE (inbound #1965). This header said "a hard
    ceiling of 20 themes" until September 14, 2026, and the store that filed that issue holds 61. The
    number was never the argument -- the argument is that the ceiling exists and is reached -- so what
    is stated now is the property rather than a figure that is wrong on the very store this feature was
    specified from. The CLI names the real limit when you hit it ("A shop may only have N themes").

    A preview theme is a consequence of "I want to show this", not of "I am starting work". So it comes
    into existence at the moment something is actually pushed.

    WHY NOT A FLAG ON BRANCH CREATION: a flag has to be remembered, and the mistake this replaces was
    precisely somebody reaching for the familiar route while the documentation already named the right
    one. Lazy creation cannot be forgotten -- there is no moment at which somebody has to get it right.

    A NEW PREVIEW IS A COPY OF LIVE, NOT A PUSH (inbound #2348, measured in a consumer on 2026-09-23,
    CLI 4.8.0). 'theme push' silently skips config/settings_data.context.<market>.json -- listed as "to be
    uploaded", never sent, reported as success -- so a preview born from 'push --unpublished' rendered
    every market of a Markets store with the global settings only. So step 4 runs 'theme duplicate' of
    live, which copies every file server-side, WAITS until that copy has filled (pushing into a copy that
    is still filling is a race the copy can win, putting live's version of a branch file back), and only
    then pushes the working tree over it. Where no live id is answered there is nothing to copy from, and
    it falls back to the old create with a notice rather than refusing the preview. The detail is in
    Get-ThemeDuplicateArgs in the preview-theme lib.

    NEVER TOUCHES LIVE. A newly created theme is unpublished by definition, the live id is refused
    outright here, and dkj-subagents-shopify's PreToolUse guard blocks a push aimed at live independently of this
    script.

    IT DEPENDS ON NO WORKFLOW PLUGIN. Every seam it reads is fetched through Get-Command, exactly as
    sync-main does, so a repo that enables no workflow at all gets identical behaviour -- including the
    branch name flattening, which falls back to replacing '/' with '-' where Get-BranchInfo is absent.

    Inbound #805. The argument lists and the two output readers live in the preview-theme lib beside this
    file, which is what makes them testable without a store; this script is the part that invokes them.

.PARAMETER ThemeId
    Force a specific preview theme id instead of the remembered or looked-up one.

.PARAMETER Store
    Store domain, overriding Get-ShopifyStoreDomain for this run.

.PARAMETER Path
    The storefront path to print preview URLs for, e.g. '/products/some-handle'. Default the home page --
    but a home-page link alone is not enough when the change sits on a product page.

.PARAMETER PollSeconds
    How often to count a freshly duplicated preview while it fills (default 30).

.PARAMETER TimeoutMinutes
    How long to wait for that copy to fill before giving up WITHOUT pushing (default 20). A re-run resumes
    the wait on the same theme.

.PARAMETER RootOverride
    Fixture root, so a suite can drive this against a scratch tree instead of a real store.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/push-preview.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/push-preview.ps1 -Path '/products/some-handle'

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE. scripts/tests/push-preview.tests.ps1 pins the lib
    beside this file: the three argument lists and both flag whitelists, the builders refusing each
    other's input, the id reader, the theme-list lookup, the preview URL, and the per-market settings
    notice (#2348). The fill wait is Get-ThemeFillVerdict's, pinned in theme-lifecycle-rules.tests.ps1.

    THIS SCRIPT ITSELF IS NOT DRIVEN, and deliberately: every path in it either invokes the Shopify CLI
    against a real store or reads a consumer's own repo-config, and a suite must not be able to reach a
    store. What is therefore unpinned is the ORDER of the four resolution steps and the two refusals --
    which is exactly why the parts that CAN be judged without a network were moved into the lib.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$ThemeId = '',
    [string]$Store = '',
    [string]$Path = '/',
    [int]$PollSeconds = 30,
    [int]$TimeoutMinutes = 20,
    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

. (Join-Path $PSScriptRoot '..\lib\preview-theme.ps1')

# THE RESERVED NAMESPACE (inbound #1965). Unguarded, like the CLI wrapper below and unlike the
# source-repo guard above: a copy of this script without the lib must fail at load rather than create a
# theme under a name the sweep cannot recognise, which would leave an orphan on a finite estate.
. (Join-Path $PSScriptRoot '..\lib\theme-lifecycle-rules.ps1')

# THE SHOPIFY CLI WRAPPER (inbound #1183, September 1, 2026). All three Shopify calls below were bare,
# under this script's 'Stop' -- and the CONFIRMED instance of the class is one of them: a captured
# 'theme list --json' in a consumer, killed by a hint line the CLI writes to stderr while succeeding.
# On Windows the CLI is a PowerShell shim that inherits this script's preference, which is why lowering
# it around the call is the repair and a try/catch at the call site is not. Its header has the detail.
#
# UNGUARDED, unlike the source-repo guard above: a copy of this script without the lib must fail at
# load rather than push a theme whose failure path cannot be reached. Registered for dkj-subagents-shopify in
# scripts/lib/shared-scripts-lib.ps1, so it travels beside this script in the mirror.
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source root copy falls back to the git root. Same resolution as every other mirrored script, which is
# what lets both copies stay byte-identical.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'push-preview.ps1' -OverrideName '-RootOverride'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store: there is no theme estate
# here to push to. Same one-file test sync-main and adopt-shopify-floor use for the same distinction.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme estate here to push to. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

$branch = "$(git rev-parse --abbrev-ref HEAD)".Trim()

# --- The seam answers ------------------------------------------------------------------------------
# Read in a child scope with StrictMode OFF and inside a try, exactly as dkj-subagents-shopify's live-theme guard
# and sync-main read the same file. The reason is the same: repo-config.ps1 belongs to the consumer, so a
# fault in it must degrade to defaults rather than take this script down with it.
#
# branch-info.ps1 IS DOT-SOURCED IN THE SAME SCOPE, guarded, because Get-BranchInfo lives there rather
# than in repo-config -- and a repo running no workflow plugin has no such file at all. Its absence is
# not an error here: the only thing wanted from it is the flattened branch name, and that has a one-line
# fallback. The name is resolved INSIDE this scope rather than by dot-sourcing the file a second time
# further down, so there is one read of each of the consumer's files per run.
$seam = & {
    Set-StrictMode -Off
    $answers = @{ LiveThemeId = ''; StoreDomain = ''; Trunk = ''; ThemeName = ''; HasPreviewUrls = $false }
    $root = $args[0]
    $branchName = $args[1]
    $configPath = Join-Path $root 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try { . $configPath } catch { }
    }
    $branchInfoPath = Join-Path $root 'scripts\lib\branch-info.ps1'
    if (Test-Path -LiteralPath $branchInfoPath -PathType Leaf) {
        try { . $branchInfoPath } catch { }
    }
    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId') { $answers.LiveThemeId = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyStoreDomain') { $answers.StoreDomain = [string](Get-ShopifyStoreDomain) }
    if (Test-FunctionDefined 'Get-TrunkBranchName') { $answers.Trunk       = [string](Get-TrunkBranchName) }
    if (Test-FunctionDefined 'Get-BranchInfo') {
        try { $answers.ThemeName = [string]((Get-BranchInfo -Branch $branchName).SafeName) } catch { }
    }
    $answers.HasPreviewUrls = [bool](Test-FunctionDefined 'Get-ShopifyPreviewUrls')
    return $answers
} $repoRoot $branch

$store = if ($Store) { $Store } else { ([string]$seam.StoreDomain).Trim() }
if (-not $store -or $store -match 'VUL-IN') {
    Write-Host 'No store domain: Get-ShopifyStoreDomain is unanswered and -Store was not given.' -ForegroundColor Red
    Write-Host '  Answering the seam is the durable fix; -Store gets you through this run.'
    exit 1
}
$trunk = if (([string]$seam.Trunk).Trim()) { ([string]$seam.Trunk).Trim() } else { 'main' }

# A NON-NUMERIC LIVE ID COUNTS AS NO ANSWER -- the same rule the guard applies, and for the same reason: a
# 'VUL-IN' left behind in the seam block reads as answered to anything testing for emptiness.
#
# UNLIKE sync-main THIS DOES NOT REFUSE OVER IT, and the difference is which direction the risk runs.
# sync-main READS FROM live, so not knowing which theme is live means it cannot do its job at all. This
# script pushes to an unpublished theme; the live id is only wanted for a belt-and-braces refusal, and the
# guard hook blocks a live-aimed push whether or not this script recognised the target. So an unanswered
# seam costs one of two independent refusals, and that is said out loud rather than blocking a preview.
$liveId = ([string]$seam.LiveThemeId).Trim()
if ($liveId -notmatch '^\d+$') {
    $liveId = ''
    Write-Warning ("Get-ShopifyLiveThemeId does not answer with a theme id, so this script cannot " +
        "recognise the live theme by id. dkj-subagents-shopify's guard hook still blocks a live-aimed push; answer " +
        "the seam to get the second refusal back (see the adopt-shopify-floor skill).")
}

if ($branch -eq $trunk) {
    Write-Host "You are on $trunk. A preview theme belongs to a branch -- create one first." -ForegroundColor Red
    exit 1
}

# THE FLATTENED NAME, from the repo's own seam where it has one. Shopify rejects a theme name containing
# '/', so this is not cosmetic: Get-ThemeCreateArgs refuses the raw branch name by design.
$flatName = ([string]$seam.ThemeName).Trim()
if (-not $flatName) { $flatName = $branch -replace '/', '-' }

# AND THEN THE RESERVED NAMESPACE ON TOP OF IT (inbound #1965). A theme this script creates now carries
# the prefix Get-RepoThemePrefix owns, because that is the ONLY thing that can define the sweep's delete
# set later: the flattened branch name cannot. Measured in the consumer that filed it -- on a store of
# 61 themes, several third-party themes are plain hyphenated words indistinguishable in shape from a
# branch-derived name, and others are branch-shaped but keep the slash, so they look like ours and are
# not. Identifying a delete set by resemblance is guesswork on a destructive operation, so the sweep
# matches on something this repo WROTE.
$themeName = Get-RepoPreviewThemeName -FlatBranchName $flatName

# THE LEGACY NAME IS STILL LOOKED UP, AND THAT IS A MIGRATION RATHER THAN A COURTESY. Every preview
# created before this landed carries the bare flattened name. Without this fallback the name lookup
# below would miss it and step 4 would create a SECOND theme for the same branch -- the exact failure
# Get-ThemeUpdateArgs' digits-only check exists to prevent, arriving through a different door, on a
# store with a finite ceiling. A legacy theme found this way keeps its own name: renaming it is a
# separate act, and the sweep leaves it alone either way (it does not carry the prefix), which is the
# safe direction for a one-time manual cleanup.
$legacyThemeName = $flatName

function Write-PreviewUrls {
    <# The seam where the repo has one, the built-in single URL otherwise. A function so that the two exit
       paths below print the same way rather than each spelling it out. #>
    param([Parameter(Mandatory = $true)][string]$Id)
    if ($seam.HasPreviewUrls) {
        # THE SEAM IS CALLED IN A CHILD SCOPE, like every other read of a consumer's own file: a fault in
        # their function must not take down a push that has already happened.
        $urls = & {
            Set-StrictMode -Off
            . (Join-Path $args[0] 'scripts\repo-config.ps1')
            try { @(Get-ShopifyPreviewUrls -ThemeId $args[1] -Path $args[2]) } catch { @() }
        } $repoRoot $Id $Path
        $named = @($urls | Where-Object { $_ })
        if ($named.Count -gt 0) {
            $named | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
            Write-HandoverNote -Count $named.Count
            return
        }
        Write-Warning 'Get-ShopifyPreviewUrls answered nothing -- falling back to the single store URL.'
    }
    Write-Host ("  " + (Get-ThemePreviewUrl -Store $store -ThemeId $Id -Path $Path)) -ForegroundColor Cyan
}

function Write-HandoverNote {
    <# A LIST OF URLS IS NOT A HANDOVER (inbound #1873). The note itself is composed in the lib, where it
       can be tested without a store; this is only where it reaches the console. Silent below two URLs,
       so a single-market repo sees nothing new. #>
    param([Parameter(Mandatory = $true)][int]$Count)
    $note = Get-PreviewHandoverNote -Count $Count
    if (-not $note) { return }
    Write-Host ""
    $note | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
}

# --- Which theme? ----------------------------------------------------------------------------------
# 1. An explicitly passed id wins.
$id = $ThemeId

# 2. Otherwise: the id remembered in the branch's own git config, written by an earlier run of this
#    script. Per branch rather than in a file, so nothing has to be committed or cleaned up.
#    "$(...)", NEVER ([string](...)): under Windows PowerShell 5.1 the cast of a native command that
#    prints nothing is $null, so .Trim() threw here on every branch's FIRST push (inbound #2483).
if (-not $id) { $id = "$(git config --get "branch.$branch.previewTheme")".Trim() }

# 3. Otherwise: a name lookup through the theme list. The theme carries the flattened branch name.
if (-not $id) {
    Write-Host "No remembered theme id; looking up '$themeName' in the theme list..." -ForegroundColor Yellow
    # -Quiet AND -DiscardStderr, and both are required rather than tidy. THIS IS THE CONFIRMED CALL --
    # the consumer's break was here (BWJ-ecommerce/smartwatchbanden#433). -DiscardStderr keeps the CLI's
    # hint line out of Output, which ConvertFrom-Json would otherwise refuse as a JSON primitive; -Quiet
    # keeps a theme list off the console, where it is noise rather than progress.
    $list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $store, '--json') -Quiet -DiscardStderr
    if ($list.ExitCode -ne 0) { Write-Error "shopify theme list failed."; exit 1 }
    $parsed = $null
    try { $parsed = ($list.Output | Out-String) | ConvertFrom-Json } catch {
        Write-Error "Could not read 'shopify theme list --json' output as JSON."
        exit 1
    }
    # Get-ThemeByName carries the PowerShell 5.1 member-enumeration trap that made this fallback always
    # report 'not found' in a consumer, and it THROWS on a duplicate name rather than picking one.
    $theme = Get-ThemeByName -Parsed $parsed -ThemeName $themeName
    # THE RESERVED NAME FIRST, THE LEGACY NAME SECOND, and never the other way round: a branch that has
    # both must resolve to the one this repo now owns, because that is the one the sweep can retire.
    if (-not $theme -and $legacyThemeName -ne $themeName) {
        $theme = Get-ThemeByName -Parsed $parsed -ThemeName $legacyThemeName
        if ($theme) {
            Write-Host ("Found this branch's preview under its pre-#1965 name '$legacyThemeName'. Pushing to " +
                "it as it stands -- it keeps that name, so the sweep will not retire it; renaming or " +
                "removing it is a separate, deliberate act.") -ForegroundColor Yellow
        }
    }
    if ($theme) { $id = [string]$theme.id }
}

function Write-SettingsNotice {
    <# THE PER-MARKET SETTINGS, SAID OUT LOUD (#2348): a preview that may lack them, and a branch that
       changes one no push can deliver. Composed in the lib; silent in a repo with no such files.
       The branch's changes are read against its merge-base with the trunk, WORKING TREE INCLUDED, since
       an uncommitted edit to one of these files is just as undeliverable as a committed one. #>
    param([AllowEmptyString()][string]$FillState)
    $markets = @(Get-ContextSettingsMarkets -RepoRoot $repoRoot)
    # 'rev-parse --verify --quiet' FIRST, so a missing ref answers with silence instead of a stderr line --
    # which under this script's 'Stop' would be terminating in Windows PowerShell 5.1, redirected or not.
    $base = ''
    foreach ($ref in @("origin/$trunk", $trunk)) {
        $sha = "$(git rev-parse --verify --quiet "$ref^{commit}")".Trim()
        if (-not $sha) { continue }
        $mb = "$(git merge-base HEAD $sha)".Trim()
        if ($mb) { $base = $mb; break }
    }
    $changed = @()
    if ($base) { $changed = @(git diff --name-only $base | Where-Object { Test-ContextSettingsPath -Path $_ }) }
    elseif ($markets.Count -gt 0) {
        # "I found no change" and "I could not look" are different sentences.
        Write-Warning "Neither origin/$trunk nor $trunk resolves here, so this branch's own per-market settings changes were not checked."
    }
    $notice = @(Get-PreviewSettingsNotice -FillState $FillState -Markets $markets -ChangedContextFiles $changed)
    if ($notice.Count -eq 0) { return }
    Write-Host ""
    $notice | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
}

# What this checkout knows about how the target theme was made. Read for the theme it remembers -- and
# for a theme found by NAME while a copy is recorded 'pending' with no id beside it: that is a duplicate
# an earlier run started and could not read the id of, so it may still be filling, and pushing into it
# is the race step 5 exists for. Any other theme found by name or passed as -ThemeId has no record.
$remembered = "$(git config --get "branch.$branch.previewTheme")".Trim()
$recordedFill = "$(git config --get "branch.$branch.previewFill")".Trim()
$fillState = ''
if ($id -and "$id" -eq $remembered) { $fillState = $recordedFill }
elseif ($id -and -not $remembered -and $recordedFill -eq 'pending') {
    $fillState = 'pending'
    $null = git config "branch.$branch.previewTheme" $id
    Write-Host "Found '$themeName' (id $id) by name, recorded as a copy of live still to be verified filled." -ForegroundColor Yellow
}

# 4. Still nothing: the theme is created HERE, and not when the branch was created. See the rule above.
if (-not $id) {
    if (-not $liveId) {
        # NOTHING TO COPY FROM, so the old create -- which pushes the working tree in the same call -- and
        # the notice below says what that theme will lack. Refusing a preview over an unanswered seam
        # would cost more than the settings do.
        Write-Host "No preview theme for '$branch' yet, and no live id to copy from; creating '$themeName' by a plain push." -ForegroundColor Yellow
        $createArgs = Get-ThemeCreateArgs -Store $store -ThemeName $themeName
        # -Quiet AND -DiscardStderr for the same two reasons as the list call: Get-ThemeIdFromPushOutput
        # parses this output, and --json means there is no progress on stdout to show anyway.
        $create = Invoke-ShopifyCli -Arguments $createArgs -Quiet -DiscardStderr
        if ($create.ExitCode -ne 0) {
            Write-Error ("Creating the preview theme failed. If the CLI says 'A shop may only have N " +
                "themes', the estate is full: archive and remove a spent preview theme first.")
            exit 1
        }
        $id = Get-ThemeIdFromPushOutput -Output ($create.Output | Out-String)
        if ($id) {
            # '$null = ' and NOT '| Out-Null': piping a native exe into a cmdlet wraps every stderr line in
            # a terminating ErrorRecord under $ErrorActionPreference = 'Stop'.
            $null = git config "branch.$branch.previewTheme" $id
            Write-Host "Preview theme '$themeName' (id $id) created and pushed; id remembered." -ForegroundColor Green
            Write-PreviewUrls -Id $id
        } else {
            Write-Host "Preview theme '$themeName' created and pushed. The id was not in the output, so the next run falls back to the name lookup." -ForegroundColor Yellow
        }
        # A stale 'pending' from an earlier duplicate attempt would otherwise stop the next push at step 5
        # for want of a live id. '--unset' of an absent key exits 5 and writes nothing.
        $null = git config --unset "branch.$branch.previewFill"
        Write-SettingsNotice -FillState ''
        exit 0
    }

    Write-Host "No preview theme for '$branch' yet; creating '$themeName' as a copy of live ($liveId)." -ForegroundColor Yellow
    # LIVE IS ONLY READ HERE: a duplicate copies it into a new theme, which is unpublished by definition.
    $dupArgs = Get-ThemeDuplicateArgs -Store $store -SourceThemeId $liveId -ThemeName $themeName
    # 'pending' IS RECORDED BEFORE THE CALL, not after it: where the new id cannot be read back, the next
    # run finds the theme by name, and this record is the only thing that tells it the copy may still be
    # filling (see the fill-state read above step 4).
    $null = git config "branch.$branch.previewFill" pending
    $dup = Invoke-ShopifyCli -Arguments $dupArgs -Quiet -DiscardStderr
    if ($dup.ExitCode -ne 0) {
        Write-Error ("Creating the preview theme (a copy of live) failed. If the CLI says 'A shop may only " +
            "have N themes', the estate is full: archive and remove a spent preview theme first.")
        exit 1
    }
    $id = Get-ThemeIdFromPushOutput -Output ($dup.Output | Out-String)
    if (-not $id) {
        # The name is ours and unique, so the theme list is the authoritative answer where --json was not.
        $list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $store, '--json') -Quiet -DiscardStderr
        if ($list.ExitCode -eq 0) {
            try {
                $theme = Get-ThemeByName -Parsed (($list.Output | Out-String) | ConvertFrom-Json) -ThemeName $themeName
                if ($theme) { $id = [string]$theme.id }
            } catch { }
        }
    }
    if (-not $id) {
        Write-Error ("The copy '$themeName' WAS created, but its id cannot be read back yet. Nothing was " +
            "pushed. Re-run this script: it finds the theme by name and, because the copy is recorded as " +
            "pending, waits for it to fill before pushing.")
        exit 1
    }
    # 'complete' only once verified. A run that dies during the wait leaves the next run knowing it must
    # wait rather than push into a half-filled copy.
    $null = git config "branch.$branch.previewTheme" $id
    $fillState = 'pending'
    Write-Host "Preview theme '$themeName' (id $id) created as a copy of live; id remembered." -ForegroundColor Green
}

if ($liveId -and "$id" -eq "$liveId") {
    Write-Host "Target is the LIVE theme ($liveId). Refused." -ForegroundColor Red
    exit 1
}

# 5. A COPY THAT IS STILL FILLING GETS NO PUSH YET. 'theme duplicate' returns long before the copy is
#    complete (measured in #1965: 38 -> 538 -> 738 -> 833 files over about eight minutes), and pushing
#    into it is a race: the copy can afterwards put live's version of a branch file back, and the preview
#    then silently shows live instead of the branch. The verdict is Get-ThemeFillVerdict's.
if ($fillState -eq 'pending') {
    if (-not $liveId) {
        Write-Error ("This preview is recorded as a copy of live that has not finished filling, and no live " +
            "id is answered to count it against. Nothing was pushed; answer Get-ShopifyLiveThemeId and re-run.")
        exit 1
    }
    Write-Host "Waiting for the copy of live to fill (every $PollSeconds s, at most $TimeoutMinutes min)..." -ForegroundColor Cyan
    Write-Host '  each sample pulls the theme and counts files on disk -- heavier than a JSON read.'
    $sourceCount = Get-ThemeFileCount -Store $store -ThemeId $liveId
    if ($sourceCount -lt 0) {
        Write-Error ("Could not count live's files, so the copy cannot be judged filled. Nothing was pushed; " +
            "re-run this script -- it resumes the wait on the same theme (id $id).")
        exit 1
    }
    Write-Host "  live holds $sourceCount file(s)."
    $samples = @()
    $verdict = $null
    $deadline = [datetime]::Now.AddMinutes($TimeoutMinutes)
    while ([datetime]::Now -lt $deadline) {
        $n = Get-ThemeFileCount -Store $store -ThemeId $id
        if ($n -ge 0) { $samples += $n }
        $verdict = Get-ThemeFillVerdict -Samples $samples -SourceFileCount $sourceCount
        Write-Host "    $($verdict.Count) file(s) -- $($verdict.Verdict)"
        # ONLY 'complete' ENDS THE WAIT EARLY. A copy also stands still in its first seconds and between
        # bursts, where it reads as 'short' -- stopping there is exactly the race this step prevents.
        if ($verdict.Verdict -eq 'complete') { break }
        Start-Sleep -Seconds $PollSeconds
    }
    if ($null -eq $verdict -or ($verdict.Verdict -ne 'complete' -and $verdict.Verdict -ne 'short')) {
        $why = if ($null -eq $verdict) { 'no samples were taken' } else { $verdict.Reason }
        Write-Error ("The copy has not filled after $TimeoutMinutes min ($why). Nothing was pushed; re-run " +
            "this script -- it resumes the wait on the same theme (id $id).")
        exit 1
    }
    # 'short' AFTER THE WHOLE WAIT: the copy has stood below live's count all that time. Push anyway -- the
    # branch arrives in full -- and let the notice say the per-market settings are unverified.
    $fillState = $verdict.Verdict
    $null = git config "branch.$branch.previewFill" $fillState
    Write-Host "  $($verdict.Reason)." -ForegroundColor $(if ($fillState -eq 'complete') { 'Green' } else { 'Yellow' })
}

$pushArgs = Get-ThemeUpdateArgs -Store $store -ThemeId "$id"
# STREAMED: Get-ThemeUpdateArgs deliberately passes no --json precisely so the CLI's progress is
# visible, so this is the one call whose output is the point. Nothing parses it. And NO --nodelete: what
# live has and the working tree does not, does not belong on this branch's preview. The context-settings
# files survive it because they exist locally -- the push neither uploads nor deletes them.
$push = Invoke-ShopifyCli -Arguments $pushArgs
if ($push.ExitCode -ne 0) { Write-Error "Push failed."; exit 1 }
Write-Host "Pushed to the preview theme of '$branch' (id $id)." -ForegroundColor Green
Write-PreviewUrls -Id $id
Write-SettingsNotice -FillState $fillState
