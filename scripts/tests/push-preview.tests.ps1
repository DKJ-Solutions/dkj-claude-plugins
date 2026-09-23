<#
.SYNOPSIS
    Contract tests for scripts/lib/preview-theme.ps1 -- the 'shopify theme push' argument lists
    push-preview.ps1 hands to the CLI, the 'shopify theme duplicate' call a new preview is created with
    (#2348), the two flag whitelists in front of them, the two readers of the CLI's own output, and the
    per-market settings notice.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/push-preview.tests.ps1

    WHAT THIS GUARDS, AND WHY IT EXISTS AT ALL. A consumer's create path spelled the flag '--theme-name',
    which the Shopify CLI does not have. It failed the FIRST time anybody needed a preview theme created --
    2026-08-21 -- because the path had been written the day before and no branch had wanted a preview theme
    in between. Nothing was wrong with the reasoning; the flag was simply never run. So what is pinned here
    is the shape of the call, which is the part that can be measured without a store:

      1. the NAME of a new theme travels on --theme, not --theme-name. --theme does double duty: a name
         when combined with --unpublished, an id otherwise. That double duty is what got mis-guessed.
      2. every '--*' token is a flag the CLI actually accepts. The whitelist was measured from
         'shopify theme push --help'; an invented flag throws before the CLI is reached.
      3. a theme name may not contain '/'. Shopify rejects it, so the branch name is flattened -- and a
         caller that passes the raw branch name gets a message saying so rather than a CLI error.
      4. the two calls do not get confused: an id goes to Get-ThemeUpdateArgs, a name to
         Get-ThemeCreateArgs, and each refuses the other's input.
      5. the two output readers, which are the halves that cannot be re-run: the id of a theme that was
         created-and-pushed in one call, and the theme-list lookup whose PowerShell 5.1 member-enumeration
         trap made a consumer's fallback always report 'not found'.
      6. the create-by-copy call and the per-market settings notice (inbound #2348): 'theme push' never
         uploads config/settings_data.context.*.json, so a new preview is a 'theme duplicate' of live,
         and what no push can deliver is said out loud rather than left for a reviewer to discover.

    WHAT IT CANNOT GUARD: that the CLI still accepts this set. Only the CLI can answer that, and the lib's
    header says to re-measure with --help rather than edit the list from memory. A test cannot tell a stale
    whitelist from a correct one.

    NOT COVERED, and deliberately: push-preview.ps1 itself. Every path in it either invokes the Shopify
    CLI against a real store or reads a consumer's own repo-config, and a suite must not be able to reach
    a store. What the script keeps for itself is the ORDER of the four resolution steps and the two
    refusals; the parts that can be judged without a network are in the lib, which is the whole reason the
    lib exists.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\preview-theme.ps1')
. (Join-Path $PSScriptRoot '..\lib\branch-info.ps1')

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Assert-False {
    param([bool]$Condition, [string]$Name)
    Assert-True (-not $Condition) $Name
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Name)
    Assert-True ($Text -match $Pattern) $Name
}

# These suites are dependency-free, so there is no Should -Throw to lean on.
function Get-ThrownMessage {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    try { $null = & $Action; return '' } catch { return $_.Exception.Message }
}

Write-Host "== push-preview.tests -- the preview-theme argument lists (inbound #805) ==" -ForegroundColor Cyan

Write-Host ""
Write-Host "The create call carries the name on --theme, and never on --theme-name" -ForegroundColor Cyan
$create = Get-ThemeCreateArgs -Store 'a-store.myshopify.com' -ThemeName 'fix-some-branch'
Assert-Equal 'theme' $create[0] 'it is a theme command'
Assert-Equal 'push'  $create[1] 'it is a push'
Assert-True  ($create -contains '--unpublished') 'the theme is created by --unpublished'
Assert-True  ($create -contains '--theme')       'the name travels on --theme'
Assert-False ($create -contains '--theme-name')  'THE BUG: --theme-name is not a Shopify CLI flag'
Assert-True  ($create -contains '--json')        'and --json, because the caller parses the new id out of the output'
# A value must sit immediately after its flag, or the CLI reads the next flag as the name.
$i = [array]::IndexOf($create, '--theme')
Assert-Equal 'fix-some-branch' $create[$i + 1] 'the name follows --theme directly'
$s = [array]::IndexOf($create, '--store')
Assert-Equal 'a-store.myshopify.com' $create[$s + 1] 'the store follows --store directly'

Write-Host ""
Write-Host "The update call pushes to an existing id, and asks for no JSON" -ForegroundColor Cyan
$upd = Get-ThemeUpdateArgs -Store 'a-store.myshopify.com' -ThemeId '202324083029'
Assert-True  ($upd -contains '--theme')      'the id travels on --theme too'
Assert-False ($upd -contains '--unpublished') 'an existing theme is not created again'
Assert-False ($upd -contains '--json')       'no --json: the caller reads the exit code and prints the URLs itself'
$j = [array]::IndexOf($upd, '--theme')
Assert-Equal '202324083029' $upd[$j + 1] 'the id follows --theme directly'

Write-Host ""
Write-Host "Neither call ever aims at live, publishes, or allows a live push" -ForegroundColor Cyan
# Those three flags belong to a deliberate, marker-carrying live command. This script is not it.
foreach ($a in @($create, $upd)) {
    Assert-False ($a -contains '--allow-live') 'no --allow-live'
    Assert-False ($a -contains '--live')       'no --live'
    Assert-False ($a -contains '--publish')    'no --publish'
}

Write-Host ""
Write-Host "An invented flag is refused before the CLI is reached" -ForegroundColor Cyan
$msg = Get-ThrownMessage { Test-ThemePushArgs -Arguments @('theme', 'push', '--theme-name', 'x') }
Assert-Match $msg '--theme-name'      'the message names the offending flag'
Assert-Match $msg 'theme push --help' 'and says how to re-measure the accepted set'
Assert-Equal '' (Get-ThrownMessage { Test-ThemePushArgs -Arguments $create }) 'the real create call passes'
Assert-Equal '' (Get-ThrownMessage { Test-ThemePushArgs -Arguments $upd })    'the real update call passes'
# A VALUE that happens to look like a flag is a value, not a flag: only '--*' tokens are judged.
Assert-Equal '' (Get-ThrownMessage { Test-ThemePushArgs -Arguments @('theme', 'push', '--theme', '-weird-name') }) 'a value is not judged as a flag'
Assert-Equal '' (Get-ThrownMessage { Test-ThemePushArgs -Arguments @() }) 'an empty list has nothing to refuse'

Write-Host ""
Write-Host "The whitelist is the CLI long-form set, not a hand-picked subset" -ForegroundColor Cyan
$flags = @(Get-ThemePushFlags)
Assert-Equal 19 $flags.Count 'nineteen long-form flags, measured 2026-08-21 against CLI 3.94.3'
Assert-True  ($flags -contains '--only')       '--only is in it: a live push per file needs it'
Assert-True  ($flags -contains '--unpublished') '--unpublished is in it -- its absence was the whitelist''s own first finding'
Assert-True  ($flags -contains '--allow-live') 'the whitelist ADMITS --allow-live...'
# ...and that is the point of the line above: the whitelist says what the CLI accepts, NOT what a repo
# permits. Refusing a live push is the guard hook's job. A validator that also enforced policy would give
# two different answers to 'is this a real flag'.
Assert-False ($flags -contains '--theme-name') 'and does not admit the flag that never existed'
Assert-Equal $flags.Count (@($flags | Sort-Object -Unique)).Count 'no duplicates'
Assert-Equal 0 (@($flags | Where-Object { $_ -notlike '--*' })).Count 'long forms only, no short forms'

Write-Host ""
Write-Host "A theme name with a slash is refused, because Shopify rejects it" -ForegroundColor Cyan
$slash = Get-ThrownMessage { Get-ThemeCreateArgs -Store 'x.myshopify.com' -ThemeName 'fix/some-branch' }
Assert-Match $slash 'may not contain' 'the slash is refused'
Assert-Match $slash 'SafeName'        'and the message points at the flattened form the seam produces'
# The real pairing, asserted against the seam rather than against a copy of its rule.
$safe = (Get-BranchInfo -Branch 'fix/some-branch').SafeName
Assert-Equal 'fix-some-branch' $safe 'SafeName flattens the slash'
Assert-Equal '' (Get-ThrownMessage { Get-ThemeCreateArgs -Store 'x.myshopify.com' -ThemeName $safe }) 'and is accepted'
Assert-Match (Get-ThrownMessage { Get-ThemeCreateArgs -Store 'x.myshopify.com' -ThemeName '   ' }) 'must not be blank' 'a blank name is refused'

Write-Host ""
Write-Host "The two builders refuse each other's input" -ForegroundColor Cyan
Assert-Match (Get-ThrownMessage { Get-ThemeUpdateArgs -Store 'x.myshopify.com' -ThemeId 'fix-some-branch' }) 'all digits' 'a name is refused where an id belongs'
Assert-Match (Get-ThrownMessage { Get-ThemeUpdateArgs -Store 'x.myshopify.com' -ThemeId '1907936a3653' }) 'all digits' 'a near-miss id is refused too'
Assert-Equal '' (Get-ThrownMessage { Get-ThemeUpdateArgs -Store 'x.myshopify.com' -ThemeId '190793613653' }) 'a real id is accepted'

Write-Host ""
Write-Host "Get-ThemeIdFromPushOutput -- the half that cannot be re-run" -ForegroundColor Cyan
# The create call pushes at the same time it creates, so a missed id is not recoverable by running it
# again -- only by the name-lookup fallback.
Assert-Equal '202324083029' (Get-ThemeIdFromPushOutput -Output '{"theme":{"id":202324083029,"name":"fix-x"}}') 'the id is read out of the --json output'
Assert-Equal '202324083029' (Get-ThemeIdFromPushOutput -Output "chatter on stderr`n{ `"id`" : 202324083029 }`nmore") 'whitespace and surrounding chatter do not hide it'
Assert-Equal '' (Get-ThemeIdFromPushOutput -Output 'Theme pushed successfully.') 'output with no id answers empty rather than guessing'
Assert-Equal '' (Get-ThemeIdFromPushOutput -Output '') 'and so does empty output'

Write-Host ""
Write-Host "Get-ThemeByName -- the PowerShell 5.1 member-enumeration trap" -ForegroundColor Cyan
# '$array.themes' does member enumeration in 5.1 and yields an array with a $null per element; that array
# is not empty and is therefore truthy, so a bare 'if ($parsed.themes)' throws away the right list. A
# consumer hit this on 2026-08-04 and its name lookup then always reported 'no preview theme found'.
$wrapped = ([pscustomobject]@{ themes = @(
    [pscustomobject]@{ id = 1; name = 'fix-a' },
    [pscustomobject]@{ id = 2; name = 'fix-b' }) })
Assert-Equal 2 (Get-ThemeByName -Parsed $wrapped -ThemeName 'fix-b').id 'a wrapped { themes: [...] } payload is unwrapped'
$bare = @([pscustomobject]@{ id = 3; name = 'fix-c' })
Assert-Equal 3 (Get-ThemeByName -Parsed $bare -ThemeName 'fix-c').id 'a bare array is read as-is'
Assert-Equal $null (Get-ThemeByName -Parsed $wrapped -ThemeName 'fix-missing') 'no match answers $null'
Assert-Equal $null (Get-ThemeByName -Parsed $null -ThemeName 'fix-a') 'and so does a null payload, rather than throwing'
# TWO THEMES OF ONE NAME IS AN ESTATE PROBLEM, not a coin flip: pushing to the wrong one of them is
# invisible until somebody opens the preview.
$dupes = ([pscustomobject]@{ themes = @(
    [pscustomobject]@{ id = 4; name = 'fix-dupe' },
    [pscustomobject]@{ id = 5; name = 'fix-dupe' }) })
Assert-Match (Get-ThrownMessage { Get-ThemeByName -Parsed $dupes -ThemeName 'fix-dupe' }) 'More than one theme' 'a duplicate name throws instead of picking one'

Write-Host ""
Write-Host "Get-ThemePreviewUrl -- a link that survives the first internal click" -ForegroundColor Cyan
# Without the three admin parameters the preview holds only through the cookie and is lost at the first
# internal link -- and then you are looking at live while believing you are looking at the preview. A
# consumer lost a whole review to that on 2026-08-05.
$url = Get-ThemePreviewUrl -Store 'a-store.myshopify.com' -ThemeId '123' -Path '/products/x'
Assert-Match $url 'preview_theme_id=123' 'the theme id is in the query'
Assert-Match $url '_ab=0'  'and the three admin parameters: _ab'
Assert-Match $url '_fd=0'  '_fd'
Assert-Match $url '_sc=1'  '_sc'
Assert-Match $url '^https://a-store\.myshopify\.com/products/x\?' 'the path sits before the query, not after it'
Assert-Match (Get-ThemePreviewUrl -Store 'a-store.myshopify.com' -ThemeId '123') '^https://a-store\.myshopify\.com/\?' 'no path given -> the home page'
Assert-Match (Get-ThemePreviewUrl -Store 'https://a-store.myshopify.com/' -ThemeId '123') '^https://a-store\.myshopify\.com/\?' 'a store answered with a scheme or a trailing slash still yields one well-formed URL'
Assert-Match (Get-ThemePreviewUrl -Store 'a-store.myshopify.com' -ThemeId '123' -Path 'products/x') '^https://a-store\.myshopify\.com/products/x\?' 'a path without its leading slash is still placed correctly'

Write-Host ""
Write-Host "Get-PreviewHandoverNote -- a list of URLs is not a handover (inbound #1873)" -ForegroundColor Cyan
# THE COUNT IS THE TRIGGER, and the boundary is the whole assert: one URL in a terminal genuinely is a
# usable handover, so a single-market repo must see nothing new at all. Two is where a reader has to
# choose a layout, and choosing a table is what #1873 measured.
Assert-Equal $null (Get-PreviewHandoverNote -Count 1) 'one URL prints no note'
Assert-Equal $null (Get-PreviewHandoverNote -Count 0) 'and neither does none'
# THE BOUNDARY ITSELF, because 1 and 5 leave it untested from both sides: 'more than one' and 'more
# than two' read alike in prose and the whole rule turns on which it is. A copy-edit pass on this
# branch caught exactly that drift in a skill page (one line said 'above two of them' while the code
# fires at two), so the number this suite pins is the one a document can be held to.
Assert-True (@(Get-PreviewHandoverNote -Count 2).Count -gt 0) 'and TWO is where it starts -- the boundary, not a round number'
$note = @(Get-PreviewHandoverNote -Count 5)
Assert-True ($note.Count -gt 0) 'five URLs do print a note'
Assert-Match ($note -join ' ') '\b5 preview URLs\b' 'it names the count it actually saw, rather than "several"'
# EACH OF THE THREE IS LOAD-BEARING and was measured: the terminal wraps them, the reviewer is on a
# phone, and the repo's own workflow -- not this script -- states what the handover IS.
Assert-Match ($note -join ' ') '(?i)\bONE link\b'  'it says what to hand over instead'
Assert-Match ($note -join ' ') '(?i)\bphone\b'     'it names the device the reviewer is actually on'
Assert-Match ($note -join ' ') '(?i)your workflow' 'it defers the carrier to the repo workflow'
# IT NAMES NO REPO AND NO PLUGIN. This lib ships to every Shopify consumer; the handover rule it points
# at is BWJ's house rule, and a generic script stating one repo's policy is the mechanism/policy split
# inverted. If this assert ever fails, the text belongs on the policy page instead.
Assert-True (($note -join ' ') -notmatch '(?i)bwj|smartwatchbanden|xoxowildhearts') `
    'and it names no specific repo or plugin -- the rule is generic, the carrier is the repo''s'

Write-Host ""
Write-Host "Get-ThemeDuplicateArgs -- a new preview is a copy of live (inbound #2348)" -ForegroundColor Cyan
# 'theme push' never uploads config/settings_data.context.*.json (CLI 4.8.0: no upload bucket matches it),
# so a preview is created by 'theme duplicate' of live, which copies every file server-side.
$dupA = Get-ThemeDuplicateArgs -Store 'a-store.myshopify.com' -SourceThemeId '170064871700' -ThemeName 'cc-fix-some-branch'
Assert-Equal 'theme'     $dupA[0] 'it is a theme command'
Assert-Equal 'duplicate' $dupA[1] 'it is a duplicate, not a push'
$t = [array]::IndexOf($dupA, '--theme')
Assert-Equal '170064871700' $dupA[$t + 1] 'the SOURCE id follows --theme'
$n = [array]::IndexOf($dupA, '--name')
Assert-Equal 'cc-fix-some-branch' $dupA[$n + 1] 'the new theme''s name follows --name'
Assert-True  ($dupA -contains '--force') '--force: "Required if non interactive", and a session has no TTY (#2031)'
Assert-True  ($dupA -contains '--json')  '--json, because the caller reads the new id out of it'
Assert-False ($dupA -contains '--unpublished') 'no --unpublished: that is the push that drops the context settings'
Assert-Match (Get-ThrownMessage { Get-ThemeDuplicateArgs -Store 'x' -SourceThemeId 'live' -ThemeName 'n' }) 'all digits' 'a NAME as the source is refused -- the source is the live id'
Assert-Match (Get-ThrownMessage { Get-ThemeDuplicateArgs -Store 'x' -SourceThemeId '1' -ThemeName 'fix/x' }) 'may not contain' 'a slash in the new name is refused'
Assert-Match (Get-ThrownMessage { Get-ThemeDuplicateArgs -Store 'x' -SourceThemeId '1' -ThemeName '  ' }) 'must not be blank' 'a blank name is refused'
# THE DUPLICATE'S --json SHAPE, read in CLI 4.8.0's source (dist/chunk-ZL5LU4U2.js): on success exactly
# {"theme":{"id","name","role","shop"}}, so the one id in it is the NEW theme's -- never the source's. Its
# failure shapes carry a message and no id, so the reader answers empty and push-preview falls back to
# the theme list.
Assert-Equal '999888777' (Get-ThemeIdFromPushOutput -Output '{"theme":{"id":999888777,"name":"cc-fix-x","role":"unpublished","shop":"a-store.myshopify.com"}}') 'the duplicate''s --json yields the NEW theme''s id'
Assert-Equal '' (Get-ThemeIdFromPushOutput -Output '{"message":"The theme ''Live'' could not be duplicated due to errors","errors":["x"],"requestId":"r"}') 'and a failed duplicate yields none'
$dupFlags = @(Get-ThemeDuplicateFlags)
Assert-Equal 10 $dupFlags.Count 'ten long-form flags, measured 2026-09-23 against CLI 4.8.0'
Assert-Equal 0 (@($dupA | Where-Object { $_ -like '--*' -and $dupFlags -notcontains $_ })).Count 'every flag the call uses is in the measured set'
Assert-Equal 0 (@($dupFlags | Where-Object { $_ -notlike '--*' })).Count 'long forms only, no short forms'

Write-Host ""
Write-Host "Test-ContextSettingsPath -- exactly the files no push delivers" -ForegroundColor Cyan
Assert-True  (Test-ContextSettingsPath -Path 'config/settings_data.context.nl.json') 'a per-market settings file matches'
Assert-True  (Test-ContextSettingsPath -Path 'config\settings_data.context.uk.json') 'a backslash path matches too'
Assert-False (Test-ContextSettingsPath -Path 'config/settings_data.json') 'the global settings file does not -- push delivers it'
Assert-False (Test-ContextSettingsPath -Path 'templates/index.context.nl.json') 'a template context file does not -- push delivers those'
Assert-False (Test-ContextSettingsPath -Path 'sections/header-group.context.nl.json') 'nor a section-group context file'
Assert-False (Test-ContextSettingsPath -Path '') 'an empty path answers false'

Write-Host ""
Write-Host "Get-ContextSettingsMarkets -- read off the working tree" -ForegroundColor Cyan
$fx = Join-Path ([System.IO.Path]::GetTempPath()) ('pp-ctx-' + [guid]::NewGuid().ToString('N'))
try {
    Assert-Equal 0 @(Get-ContextSettingsMarkets -RepoRoot $fx).Count 'no config folder -> no markets'
    New-Item -ItemType Directory -Path (Join-Path $fx 'config') -Force | Out-Null
    foreach ($f in 'settings_data.json', 'settings_data.context.uk.json', 'settings_data.context.nl.json', 'settings_schema.json') {
        Set-Content -LiteralPath (Join-Path $fx "config\$f") -Value '{}'
    }
    Assert-Equal 'nl,uk' (@(Get-ContextSettingsMarkets -RepoRoot $fx) -join ',') 'the two markets, sorted, and nothing else'
} finally {
    Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Get-PreviewSettingsNotice -- two facts, either true alone" -ForegroundColor Cyan
Assert-Equal 0 @(Get-PreviewSettingsNotice -FillState '' -Markets @()).Count 'a repo with no per-market settings sees nothing'
Assert-Equal 0 @(Get-PreviewSettingsNotice -FillState 'complete' -Markets @('nl', 'uk')).Count 'a verified copy of live sees nothing'
$noRec = (@(Get-PreviewSettingsNotice -FillState '' -Markets @('nl', 'uk')) -join ' ')
Assert-Match $noRec 'no record' 'a theme with no record says so, rather than claiming it is missing the settings'
Assert-Match $noRec 'nl, uk' 'and names the markets'
Assert-Match (@(Get-PreviewSettingsNotice -FillState 'short' -Markets @('nl')) -join ' ') 'not verified complete \(short\)' 'a copy that settled short says which state it is in'
$chg = (@(Get-PreviewSettingsNotice -FillState 'complete' -Markets @('nl') -ChangedContextFiles @('config/settings_data.context.nl.json')) -join ' ')
Assert-Match $chg 'config/settings_data\.context\.nl\.json' 'a branch changing a context file names the file, even on a verified copy'
Assert-Match $chg 'LIVE''s values' 'and says the preview shows live''s values for it'
Assert-True ($chg -notmatch 'no record') 'without the missing-settings note a verified copy does not need'
Assert-True (($noRec + ' ' + $chg) -notmatch '(?i)bwj|smartwatchbanden|xoxowildhearts|loyalty') 'it names no repo and no store''s own settings'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
