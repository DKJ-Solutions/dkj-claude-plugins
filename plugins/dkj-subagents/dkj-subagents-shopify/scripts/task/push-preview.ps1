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
    previews, 6 belonged to branches that never needed one. And a Shopify store has a hard ceiling of 20
    themes, so an estate filling up with unused previews is not merely untidy -- it eventually refuses the
    next push.

    A preview theme is a consequence of "I want to show this", not of "I am starting work". So it comes
    into existence at the moment something is actually pushed.

    WHY NOT A FLAG ON BRANCH CREATION: a flag has to be remembered, and the mistake this replaces was
    precisely somebody reaching for the familiar route while the documentation already named the right
    one. Lazy creation cannot be forgotten -- there is no moment at which somebody has to get it right.

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

.PARAMETER RootOverride
    Fixture root, so a suite can drive this against a scratch tree instead of a real store.

.EXAMPLE
    powershell -NoProfile -File scripts/task/push-preview.ps1

.EXAMPLE
    powershell -NoProfile -File scripts/task/push-preview.ps1 -Path '/products/some-handle'

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE. scripts/tests/push-preview.tests.ps1 pins the lib
    beside this file: both argument lists, the flag whitelist, the two builders refusing each other's
    input, the id reader, the theme-list lookup, and the preview URL.

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
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'push-preview.ps1'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store: there is no theme estate
# here to push to. Same one-file test sync-main and adopt-shopify-floor use for the same distinction.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no theme estate here to push to. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

$branch = ([string](git rev-parse --abbrev-ref HEAD)).Trim()

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
$themeName = ([string]$seam.ThemeName).Trim()
if (-not $themeName) { $themeName = $branch -replace '/', '-' }

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
if (-not $id) { $id = ([string](git config --get "branch.$branch.previewTheme")).Trim() }

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
    if ($theme) { $id = [string]$theme.id }
}

# 4. Still nothing: the theme is created HERE, and not when the branch was created. See the rule above.
if (-not $id) {
    Write-Host "No preview theme for '$branch' yet; creating '$themeName' (unpublished)." -ForegroundColor Yellow
    # --unpublished CREATES the theme and pushes the current working tree in the SAME call, so no second
    # push follows on purpose.
    $createArgs = Get-ThemeCreateArgs -Store $store -ThemeName $themeName
    # -Quiet AND -DiscardStderr for the same two reasons as the list call: Get-ThemeIdFromPushOutput
    # parses this output, and --json means there is no progress on stdout to show anyway.
    $create = Invoke-ShopifyCli -Arguments $createArgs -Quiet -DiscardStderr
    if ($create.ExitCode -ne 0) {
        Write-Error ("Creating the preview theme failed. If the CLI says 'A shop may only have 20 " +
            "themes', the estate is full: archive and remove a spent preview theme first.")
        exit 1
    }
    $id = Get-ThemeIdFromPushOutput -Output ($create.Output | Out-String)
    if ($id) {
        # '$null = ' and NOT '| Out-Null': piping a native exe into a cmdlet wraps every stderr line in a
        # terminating ErrorRecord under $ErrorActionPreference = 'Stop'.
        $null = git config "branch.$branch.previewTheme" $id
        Write-Host "Preview theme '$themeName' (id $id) created and pushed; id remembered." -ForegroundColor Green
        Write-PreviewUrls -Id $id
    } else {
        Write-Host "Preview theme '$themeName' created and pushed. The id was not in the output, so the next run falls back to the name lookup." -ForegroundColor Yellow
    }
    exit 0
}

if ($liveId -and "$id" -eq "$liveId") {
    Write-Host "Target is the LIVE theme ($liveId). Refused." -ForegroundColor Red
    exit 1
}

$pushArgs = Get-ThemeUpdateArgs -Store $store -ThemeId "$id"
# STREAMED: Get-ThemeUpdateArgs deliberately passes no --json precisely so the CLI's progress is
# visible, so this is the one call whose output is the point. Nothing parses it.
$push = Invoke-ShopifyCli -Arguments $pushArgs
if ($push.ExitCode -ne 0) { Write-Error "Push failed."; exit 1 }
Write-Host "Pushed to the preview theme of '$branch' (id $id)." -ForegroundColor Green
Write-PreviewUrls -Id $id
