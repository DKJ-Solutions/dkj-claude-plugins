<#
.SYNOPSIS
    Tests for plugins/dkj-subagents/dkj-subagents-shopify/hooks/shopify-floor-sessioncheck.ps1 -- the session check that
    reports a half-armed live-theme guard and a second, hand-written guard registered beside the shipped
    one.

.DESCRIPTION
    WHY THIS SUITE EXISTS, and it is one message rather than the whole hook (inbound #994, August 27,
    2026). The duplicate-guard finding used to advise convergence unconditionally, calling the shipped
    guard "the superset". That is true of the MATCHER and not of the RULES: the guard's third rule
    recognises a push aimed at live BY ID only where the repo has answered Get-ShopifyLiveThemeId, so in
    a repo that has not, a hand-written guard that does know the id covers a case the shipped one does
    not. Following the advice there removes real cover, on a line calling removal "a safety improvement",
    and it fails SILENTLY -- the hook keeps running and only a push naming live by its number gets
    through.

    So what is pinned here is the CONDITION, not the wording: with the seam unanswered the message must
    not tell anybody to converge now, and with it answered it must. A regression in either direction
    re-opens a vector nobody would see.

    THE PLACEHOLDER CASE IS PART OF IT. adopt-shopify-floor writes the seam block with a 'VUL-IN'
    placeholder, so a non-numeric answer is a path a consumer really walks and must count as unanswered.

    THE NO-STORE DECLARATION (inbound #1570). A repo that enables this team without a Shopify store
    answers Get-ShopifyRepoHasNoStore with $true, and the half-armed finding then stays silent -- the
    third state the id question has no room for. Pinned here: a truthy answer suppresses that finding
    and nothing else (the duplicate-guard finding stays independent), a falsy one is not a declaration
    and changes nothing, and absence -- every store repo -- is unaffected.

    THE STORE FINDING (#2880). The check-shop-connector skill compares the claude.ai connector's store
    with the one this repo expects, so a repo naming no store is reported. Pinned here: the estate seam
    and its Get-ShopifyStoreDomain fallback both count, a VUL-IN placeholder does not, and a no-store
    repo and a repo with no config stay silent.

    Every case runs against a scratch fixture tree via CLAUDE_PROJECT_DIR. Nothing here touches the repo
    it runs in.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Hook     = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify\hooks\shopify-floor-sessioncheck.ps1'
# $PID in the fixture path: the test gate is a throttled PARALLEL scheduler, so two runs at one fixed
# temp path tear down each other's tree mid-assert. Same reasoning as adopt-shopify-floor.tests.ps1.
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "shopify-floor-sessioncheck-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function New-FixtureRepo {
    <# A consuming repo. $LiveId $null AND no other config flag means no repo-config.ps1 at all; a string
       is the seam's answer. -NoStore appends Get-ShopifyRepoHasNoStore returning $true; -ConfigExtra
       appends an arbitrary line (e.g. an explicit falsy no-store answer). -Store answers
       Get-ShopifyThemeEstateStore wherever a config is written at all; it has a default so the cases
       about the id and the duplicate guard stay about those, and '' leaves the store unanswered (#2880). #>
    param([string]$Label, $LiveId, [switch]$WithOwnGuard, [switch]$NoStore, [string]$ConfigExtra,
          [string]$Store = 'example-store.myshopify.com')
    $root = Join-Path $Fixture "repo-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Force -Path (Join-Path $root '.claude') | Out-Null
    $configLines = @()
    if ($null -ne $LiveId) { $configLines += "function Get-ShopifyLiveThemeId { '$LiveId' }" }
    if ($NoStore)          { $configLines += 'function Get-ShopifyRepoHasNoStore { $true }' }
    if ($ConfigExtra)      { $configLines += $ConfigExtra }
    if ($configLines.Count -gt 0 -and $Store) { $configLines += "function Get-ShopifyThemeEstateStore { '$Store' }" }
    if ($configLines.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path (Join-Path $root 'scripts') | Out-Null
        [IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'),
            (($configLines -join "`r`n") + "`r`n"), $Utf8NoBom)
    }
    if ($WithOwnGuard) {
        $settings = '{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ ' +
                    '{ "type": "command", "command": "pwsh -File .claude/hooks/guard-live-theme.ps1" } ] } ] } }'
        [IO.File]::WriteAllText((Join-Path $root '.claude\settings.json'), $settings, $Utf8NoBom)
    }
    return $root
}

function Invoke-Check {
    <# Run the hook against a fixture root in a child process, so its exit and its env stay contained. #>
    param([string]$Root)
    $prev = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $Root
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Hook 2>&1 |
               ForEach-Object { $_.ToString() }
        return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
    } finally { $env:CLAUDE_PROJECT_DIR = $prev }
}

Write-Host "== shopify-floor-sessioncheck.tests: the convergence advice is gated on the seam ==" -ForegroundColor Cyan

try {
    New-Item -ItemType Directory -Force -Path $Fixture | Out-Null

    # --- the seam is answered: converge now -------------------------------------------------------
    Write-Host "seam answered + a second guard -- the advice says converge" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'answered' -LiveId '190793613653' -WithOwnGuard)
    Assert-True ($r.Code -eq 0) 'answered: exit 0 -- a session check never blocks'
    Assert-True ($r.Out -match 'a second live-theme guard is registered') 'answered: the duplicate is reported'
    Assert-True ($r.Out -match 'the shipped guard is the superset') 'answered: and the superset claim is made'
    Assert-True ($r.Out -notmatch 'BEFORE YOU CONVERGE') 'answered: no wait-for-the-seam warning -- there is nothing to wait for'
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'answered: and the half-armed finding stays quiet'

    # --- the seam is unanswered: do NOT converge yet -----------------------------------------------
    # THE ONE THIS SUITE EXISTS FOR. Removing the local guard here opens the push-at-the-live-id vector.
    Write-Host "seam unanswered + a second guard -- the advice says answer the seam first" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'unanswered' -LiveId 'VUL-IN' -WithOwnGuard)
    Assert-True ($r.Code -eq 0) 'unanswered: exit 0 -- still never blocks'
    Assert-True ($r.Out -match 'has not said which theme is live') 'unanswered: the half-armed guard is reported'
    Assert-True ($r.Out -match 'a second live-theme guard is registered') 'unanswered: the duplicate is still reported'
    Assert-True ($r.Out -match 'BEFORE YOU CONVERGE') 'unanswered: the advice refuses to send them off the local guard yet'
    Assert-True ($r.Out -notmatch 'the shipped guard is the superset') 'unanswered: and the superset claim is NOT made -- it is false here'
    Assert-True ($r.Out -match 'covering a case the shipped one is not') 'unanswered: the reason is stated, not just the instruction'

    # --- a numeric answer is what counts ------------------------------------------------------------
    # adopt-shopify-floor writes 'VUL-IN' on purpose, so this is a path a consumer walks rather than a
    # contrived input. Asserted from the other side in the check itself.
    Write-Host "a non-numeric answer counts as no answer" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'placeholder' -LiveId 'VUL-IN')
    Assert-True ($r.Out -match 'has not said which theme is live') 'placeholder: read as unanswered, not as an answer'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'numeric' -LiveId '190793613653')
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'numeric: read as an answer'


    # --- a repo with no store declares it -- silent (inbound #1570) --------------------------------
    # The third state the id question has no room for: not "answered", not "left blank", but "there is
    # no store to answer for". The source repo enables this team without a store and walks exactly here.
    Write-Host "Get-ShopifyRepoHasNoStore = true -- the half-armed finding stays quiet" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'nostore' -LiveId $null -NoStore)
    Assert-True ($r.Code -eq 0) 'no-store: exit 0'
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'no-store: the half-armed [ERROR] is suppressed'
    Assert-True ([string]::IsNullOrWhiteSpace($r.Out)) 'no-store: silent, exactly like an answered id'

    # the declaration wins even over a VUL-IN placeholder sitting beside it
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'nostore-placeholder' -LiveId 'VUL-IN' -NoStore)
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'no-store + VUL-IN: the declaration suppresses the finding the placeholder alone would raise'

    # an explicit falsy answer is NOT a declaration -- a store repo that merely spells the seam out
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'nostore-false' -LiveId 'VUL-IN' -ConfigExtra 'function Get-ShopifyRepoHasNoStore { $false }')
    Assert-True ($r.Out -match 'has not said which theme is live') 'no-store = $false: still reported -- a falsy answer is not a declaration'

    # the declaration suppresses ONLY the half-armed finding; the duplicate-guard finding is independent
    Write-Host "no-store declared + a second guard -- half-armed quiet, duplicate still reported" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'nostore-dupe' -LiveId $null -NoStore -WithOwnGuard)
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'no-store + dupe: half-armed finding suppressed'
    Assert-True ($r.Out -match 'a second live-theme guard is registered') 'no-store + dupe: the duplicate-guard finding still fires -- independent of the id question'

    # --- no duplicate at all: the advice never appears ----------------------------------------------
    # The gate must not leak the convergence message into a repo with one guard, in EITHER seam state.
    Write-Host "one guard only -- neither branch of the advice fires" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'single-answered' -LiveId '190793613653')
    Assert-True ($r.Out -notmatch 'a second live-theme guard') 'single, answered: no convergence advice'
    Assert-True ([string]::IsNullOrWhiteSpace($r.Out)) 'single, answered: silent in the ordinary case'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'single-unanswered' -LiveId 'VUL-IN')
    Assert-True ($r.Out -notmatch 'a second live-theme guard') 'single, unanswered: no convergence advice either'

    # --- the store finding: nothing says which store this repo is (#2880) ---------------------------
    # The connector check needs an expected store to compare against. A hook cannot ask the connector,
    # so the one thing it can report is that the repo names no store at all.
    Write-Host "no store named -- reported, in the resolution order push-preview uses" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-none' -LiveId '190793613653' -Store '')
    Assert-True ($r.Code -eq 0) 'store unanswered: exit 0 -- a session check never blocks'
    Assert-True ($r.Out -match '\[ERROR\]') 'store unanswered: reported at the level the hook forwards'
    Assert-True ($r.Out -match 'Get-ShopifyThemeEstateStore') 'store unanswered: naming the seam to answer'
    Assert-True ($r.Out -match 'check-shop-connector') 'store unanswered: and the skill that reads it'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-domain-only' -LiveId '190793613653' -Store '' -ConfigExtra "function Get-ShopifyStoreDomain { 'example-store.myshopify.com' }")
    Assert-True ([string]::IsNullOrWhiteSpace($r.Out)) 'Get-ShopifyStoreDomain alone: an answer -- the fallback push-preview reads too'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-estate-empty' -LiveId '190793613653' -Store '' -ConfigExtra "function Get-ShopifyThemeEstateStore { '' }`r`nfunction Get-ShopifyStoreDomain { 'example-store.myshopify.com' }")
    Assert-True ($r.Out -notmatch 'which Shopify store') 'an empty estate answer falls through to Get-ShopifyStoreDomain'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-throws' -LiveId '190793613653' -Store '' -ConfigExtra "function Get-ShopifyThemeEstateStore { throw 'boom' }")
    Assert-True ($r.Code -eq 0) 'a store seam that throws: still exit 0 -- the check never blocks'
    Assert-True ($r.Out -match 'which Shopify store') 'a store seam that throws: read as unnamed and reported'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-placeholder' -LiveId '190793613653' -Store 'VUL-IN.myshopify.com')
    Assert-True ($r.Out -match 'which Shopify store') 'a VUL-IN store is a placeholder, not an answer'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-nostore' -LiveId $null -NoStore -Store '')
    Assert-True ([string]::IsNullOrWhiteSpace($r.Out)) 'no-store repo: the store finding stays silent too'
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'store-nobootstrap' -LiveId $null -Store '')
    Assert-True ($r.Out -notmatch 'which Shopify store') 'no config: silent -- the bootstrap owns that message'

    # --- no repo-config.ps1 at all: silent ----------------------------------------------------------
    # A repo that has never run the bootstrap is not a repo with a broken answer.
    Write-Host "no scripts/repo-config.ps1 -- silent, not accusatory" -ForegroundColor Cyan
    $r = Invoke-Check -Root (New-FixtureRepo -Label 'nobootstrap' -LiveId $null)
    Assert-True ($r.Code -eq 0) 'no config: exit 0'
    Assert-True ($r.Out -notmatch 'has not said which theme is live') 'no config: the half-armed finding stays quiet'

} finally {
    Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
