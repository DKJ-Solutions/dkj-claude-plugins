<#
.SYNOPSIS
    Regression tests for the shared BWJ market URL builder that dkj-policy-bwj ships --
    plugins/dkj-policy/dkj-policy-bwj/scripts/lib/market-urls.ps1 (issue #1886, candidate 1).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bwj-market-urls.tests.ps1

    WHY A SUITE HERE FOR A FILE NOBODY IN THIS REPO USES -- the same answer bwj-test-lib.tests.ps1
    gives for the same reason. The two BWJ stores each built this and neither could see the other's,
    so the converged copy is a merge of two unequal trees. Shipping it without a suite in the repo
    that ships it would put it straight back in that position: a mechanism with no owner watching it,
    one edit away from drifting again, this time inside the plugin.

    IT IS DRIVEN BY BOTH STORES' REAL TABLES, and that is the whole point of the design. The two
    storefront topologies are what kept these copies apart:

      SWB    five markets on five SEPARATE DOMAINS, no path prefix anywhere
      XOXO   eight markets on ONE domain, a locale path prefix on all but the primary

    Every behavioural case runs against both fixtures wherever the answer should be the same, and
    against the one it distinguishes wherever it should not -- Get-PreviewPrimeUrls above all, which
    is the single place where converging CHANGED an answer rather than merging one.

    WHAT IT HOLDS, and each is a way the convergence can be undone:

      1. THE SUPERSET. Everything the richer copy carried is present -- the comma split, the
         mangled-path refusal, the preview query parameters, the applied-theme-id reader -- and so are
         the two accessors the thinner copy's callers use. An edit that drops one side is the
         divergence coming back inside the plugin, where no consumer-to-consumer check would see it.
      2. THE SEAM. The table is the store's and the mechanism is the plugin's. A refusal that names
         Get-StorefrontMarkets is what keeps a default table from ever being invented here, which
         would hand one store the other store's domains.
      3. THE LANGUAGE. The file is English and pure ASCII; one of the two source copies was neither,
         and a merge that reaches for that copy's line is how half of it would come back.

    THE SEAM CASES RUN IN A CHILD PROCESS, the rest do not. Only the seam cases care whether
    Get-StorefrontMarkets exists in the session, and defining or removing a function in this process
    to fake that would be asserting about this suite's scope rather than about a store's. Nothing else
    the lib defines can collide with this file's own names, so the remaining cases dot-source it
    directly and stay fast.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-policy-bwj\scripts\lib\market-urls.ps1'

# Test-FunctionDefined, for the export cases at the foot of this file. This repo routes every function
# probe through it rather than through Get-Command (issue #1729), and its own gate refuses the old
# idiom under scripts/ -- which is how the first version of this suite went red.
. (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1')
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-market-urls-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Label, [string]$MessageLike = '')
    try {
        & $Action | Out-Null
        $script:fail++; Write-Host "  [FAIL] $Label -- nothing was thrown" -ForegroundColor Red
    } catch {
        if ($MessageLike -and ($_.Exception.Message -notlike $MessageLike)) {
            $script:fail++
            Write-Host "  [FAIL] $Label -- thrown, but the message does not match '$MessageLike'`n         got: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green
        }
    }
}

# Run a probe against the lib in a child process, so a case about whether a seam function EXISTS is
# asked in a session that genuinely does or does not have one.
function Invoke-Probe {
    param([Parameter(Mandatory = $true)][string]$Body)
    if (-not (Test-Path -LiteralPath $Fixture)) { New-Item -ItemType Directory -Path $Fixture -Force | Out-Null }
    $path   = Join-Path $Fixture "probe-$([guid]::NewGuid().ToString('n')).ps1"
    $script = ". `"$LibPath`"" + [Environment]::NewLine + $Body
    [System.IO.File]::WriteAllText($path, $script, (New-Object System.Text.UTF8Encoding($false)))
    $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    $code = $LASTEXITCODE
    $text = (@($out | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { [string]$_.Exception.Message } else { [string]$_ }
    }) -join "`n")
    return [pscustomobject]@{ Text = $text; ExitCode = $code }
}

Write-Host ''
Write-Host 'The shared BWJ market URL builder -- where the plugin ships it (#1886)' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LibPath) 'dkj-policy-bwj ships scripts/lib/market-urls.ps1'
. $LibPath

# The two real storefront topologies, as each store's seam would answer them. Trimmed to the markets
# that carry a distinct case -- the count is asserted per store where the count is the finding.
$SWB = @(
    @{ Market = 'NL'; Domain = 'smartwatchbanden.nl' }
    @{ Market = 'DE'; Domain = 'smartwatcharmbaender.de' }
    @{ Market = 'FR'; Domain = 'braceletsmartwatch.fr' }
    @{ Market = 'ES'; Domain = 'correasmartwatch.es' }
    @{ Market = 'UK'; Domain = 'smartwatch-straps.co.uk' }
)
$XOXO = @(
    @{ Market = 'NL';    Domain = 'www.xoxowildhearts.com'; PathPrefix = '' }
    @{ Market = 'EN';    Domain = 'www.xoxowildhearts.com'; PathPrefix = '/en' }
    @{ Market = 'DE';    Domain = 'www.xoxowildhearts.com'; PathPrefix = '/de' }
    @{ Market = 'NL-GB'; Domain = 'www.xoxowildhearts.com'; PathPrefix = '/nl-gb' }
)

Write-Host ''
Write-Host 'The two topologies -- one mechanism, both shapes' -ForegroundColor Cyan

$swbHome = @(Get-MarketUrls -Markets $SWB)
Assert-Equal 5 $swbHome.Count 'separate domains: one row per market for the home page'
Assert-Equal 'https://smartwatchbanden.nl/' $swbHome[0].Url 'separate domains: the primary home page'
Assert-Equal 'https://smartwatcharmbaender.de/' $swbHome[1].Url 'separate domains: a second market is a second DOMAIN, not a path'
Assert-Equal 'NL' $swbHome[0].Market 'separate domains: the store''s order is preserved'
Assert-Equal 'UK' $swbHome[4].Market 'separate domains: ...right down to the last row'

$xoxoHome = @(Get-MarketUrls -Markets $XOXO)
Assert-Equal 'https://www.xoxowildhearts.com/' $xoxoHome[0].Url 'locale paths: a market at the ROOT keeps its trailing slash'
Assert-Equal 'https://www.xoxowildhearts.com/en' $xoxoHome[1].Url 'locale paths: a PREFIXED home page is /en and never /en/'
Assert-Equal 'https://www.xoxowildhearts.com/nl-gb' $xoxoHome[3].Url 'locale paths: a two-part locale prefix survives intact'

$xoxoPage = @(Get-MarketUrls -Path '/products/foo' -Markets $XOXO)
Assert-Equal 'https://www.xoxowildhearts.com/products/foo' $xoxoPage[0].Url 'locale paths: the primary market takes the path unprefixed'
Assert-Equal 'https://www.xoxowildhearts.com/de/products/foo' $xoxoPage[2].Url 'locale paths: every other market prefixes it'

Write-Host ''
Write-Host 'The preview parameters -- the repair, not the move' -ForegroundColor Cyan

# Without these a preview holds only through the cookie and is lost at the first internal link. The
# store with five domains had none of them, which is what makes this a repair rather than a relocation.
foreach ($row in @(Get-MarketPreviewUrls -ThemeId 123 -Markets $SWB)) {
    Assert-True ($row.Url -like '*preview_theme_id=123*') "separate domains: $($row.Market) carries the theme id"
    Assert-True ($row.Url -like '*_ab=0&_fd=0&_sc=1*') "separate domains: $($row.Market) carries the three preview parameters"
}
Assert-Equal 'https://smartwatchbanden.nl/?preview_theme_id=9&_ab=0&_fd=0&_sc=1' `
    (@(Get-MarketPreviewUrls -ThemeId 9 -Markets $SWB))[0].Url `
    'a URL with no query yet opens the preview parameters with ''?'''

# The '?' versus '&' case, which one source copy got wrong by testing with -like: in -like a '?' is a
# single-character WILDCARD, so '*?*' is true for every non-empty string and the separator came out '&'.
Assert-Equal 'https://a.example/x?utm=1&preview_theme_id=9&_ab=0&_fd=0&_sc=1' `
    (Add-PreviewQuery -Url 'https://a.example/x?utm=1' -ThemeId 9) `
    'a URL that ALREADY has a query appends with ''&'''

Write-Host ''
Write-Host 'More than one page per run -- the comma split' -ForegroundColor Cyan

$two = @(Get-MarketPreviewUrls -ThemeId 1 -Path '/products/foo,/collections/bar' -Markets $XOXO)
Assert-Equal 8 $two.Count 'two paths over four markets is eight rows, not four'
Assert-Equal '/products/foo' $two[0].Path 'the caller''s order is kept: first page first'
Assert-Equal '/collections/bar' $two[1].Path '...then the second, under the same market'
Assert-True ($two[0].Url -notlike '*bar*') 'neither page is joined into the other''s URL'

Assert-Equal '/products/foo' (@(Get-NormalizedPaths -Path 'products/foo'))[0] 'a path with no leading slash is accepted and prefixed'
Assert-Equal 1 (@(Get-NormalizedPaths -Path '/a,/a')).Count 'a page named twice is printed once'
Assert-Equal '/' (@(Get-NormalizedPaths -Path ' , '))[0] 'an all-blank -Path means the home page, not no page'
Assert-Equal 2 (@(Get-NormalizedPaths -Path @('/a', '/b'))).Count 'a real array still works beside the split'

Write-Host ''
Write-Host 'The git-bash mangled path -- a refusal, because a note had been tried' -ForegroundColor Cyan

Assert-True (Test-MangledStorefrontPath -Path 'C:/Program Files/Git/products/foo') 'a drive letter is the mangling''s fingerprint'
Assert-True (Test-MangledStorefrontPath -Path 'C:\Program Files\Git\x') '...in either slash direction'
Assert-True (-not (Test-MangledStorefrontPath -Path '/products/foo')) 'a real storefront path is not flagged'
Assert-True (-not (Test-MangledStorefrontPath -Path 'products/foo')) '...nor is a relative one, which is a documented convenience'
Assert-Throws { Get-NormalizedPaths -Path 'C:/Program Files/Git/products/foo' } `
    'the single funnel refuses it, so every caller refuses it' '*MSYS_NO_PATHCONV*'
Assert-Throws { Get-MarketPreviewUrls -ThemeId 1 -Path 'C:/Program Files/Git/x' -Markets $XOXO } `
    '...including the preview builder'

# The refusal has to happen before anything is printed, or it reads as URLs that failed to appear
# rather than as a run that never started.
$mangled = Invoke-Probe -Body @'
try { Write-MarketPreviewUrls -ThemeId 1 -Path 'C:/Program Files/Git/x' -Markets @(@{Market='NL';Domain='a.nl'}) }
catch { Write-Host "CAUGHT" }
'@
Assert-True ($mangled.Text -notlike '*Preview URLs per market*') 'no header is printed above the refusal'
Assert-True ($mangled.Text -like '*CAUGHT*') '...and the refusal really did reach the caller'

Write-Host ''
Write-Host 'Priming a cookie jar -- the one answer converging CHANGED' -ForegroundColor Cyan

# A preview cookie is set per DOMAIN. The single-URL version this replaces was right for one store and
# silently wrong for the other: it would prime one domain and leave the other four reading live, inside
# the very check that exists to prove the reader is not looking at live.
$swbPrime = @(Get-PreviewPrimeUrls -ThemeId 7 -Markets $SWB)
Assert-Equal 5 $swbPrime.Count 'five domains need five prime URLs'
Assert-Equal 5 (@($swbPrime | ForEach-Object { $_.Domain } | Sort-Object -Unique)).Count '...one per DISTINCT domain'
Assert-True ($swbPrime[0].Url -like '*preview_theme_id=7*') 'a prime URL carries the preview parameters'
$xoxoPrime = @(Get-PreviewPrimeUrls -ThemeId 7 -Markets $XOXO)
Assert-Equal 1 $xoxoPrime.Count 'one domain needs exactly one, however many locales hang off it'
Assert-Equal 'https://www.xoxowildhearts.com/?preview_theme_id=7&_ab=0&_fd=0&_sc=1' $xoxoPrime[0].Url `
    '...and it is the primary market''s home page'

Write-Host ''
Write-Host 'Reading the theme back off the storefront' -ForegroundColor Cyan

Assert-Equal '190793613653' (Get-AppliedThemeId -Html 'x Shopify.theme = {"name":"a","id":190793613653,"theme_store_id":null,"role":"main"}; y') `
    'the applied theme id is read out of the Shopify.theme marker'
Assert-Equal '190793613653' (Get-AppliedThemeId -Html 'Shopify.theme={"theme_store_id":null,"id":190793613653}') `
    '...at any property order, and theme_store_id is not mistaken for it'
Assert-True ($null -eq (Get-AppliedThemeId -Html '<html>nothing here</html>')) 'a page without the marker answers $null rather than guessing'
Assert-True ($null -eq (Get-AppliedThemeId -Html '')) 'so does an empty body'

Write-Host ''
Write-Host 'The handover pair -- what chapter three asks for' -ForegroundColor Cyan

$pair = @(Get-MarketHandoverPairs -ThemeId 5 -Path '/products/foo' -Markets $SWB -LiveThemeId 9)
Assert-Equal 5 $pair.Count 'a pair per market'
Assert-True ($pair[0].PreviewUrl -like '*preview_theme_id=5*') 'the preview half carries the theme id'

# THESE TWO ASSERTS USED TO PIN THE DEFECT (#2052). They read 'the control half carries none' and
# 'the control is the bare URL' -- which is the one control form PREVIEW-portable.md spends a measured
# table ruling out, because the preview cookie survives on the bare URL. A suite can hold a bug in
# place as firmly as code does, and this is what that looks like.
Assert-True ($pair[0].LiveUrl -like '*preview_theme_id=9*') 'the control half names the LIVE theme id explicitly'
Assert-Equal 'https://smartwatchbanden.nl/products/foo?preview_theme_id=9&_ab=0&_fd=0&_sc=1' $pair[0].LiveUrl `
    '...on the same page and the same market, with the preview parameters'
Assert-True ($pair[0].LiveUrl -ne $pair[0].PreviewUrl) 'the two halves of a pair are never the same URL'

# The control resolver, in isolation.
Assert-Equal '7' (Get-ControlThemeId -LiveThemeId 7) 'an explicit -LiveThemeId wins'

# IT FAILS RATHER THAN FALLING BACK -- a bare-URL fallback would be exactly the silent defect above.
$noLiveSeam = Invoke-Probe -Body @'
function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }
try { Get-MarketHandoverPairs -ThemeId 4 } catch { Write-Host $_.Exception.Message }
'@
Assert-True ($noLiveSeam.Text -like '*Get-ShopifyLiveThemeId*') `
    'with no live-theme seam, the pair builder refuses and names the function to add'
Assert-True ($noLiveSeam.Text -like '*repo-config.ps1*') '...and the file it belongs in'
Assert-True ($noLiveSeam.Text -notlike '*preview_theme_id*') `
    '...and it does NOT hand back a URL -- no fallback control is built'

$emptyLiveSeam = Invoke-Probe -Body @'
function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }
function Get-ShopifyLiveThemeId { '' }
try { Get-MarketHandoverPairs -ThemeId 4 } catch { Write-Host $_.Exception.Message }
'@
Assert-True ($emptyLiveSeam.Text -like '*answered nothing*') `
    'a seam that answers nothing is refused too -- there is no safe default for a control'

$withLiveSeam = Invoke-Probe -Body @'
function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }
function Get-ShopifyLiveThemeId { '170064871700' }
(Get-MarketHandoverPairs -ThemeId 4)[0].LiveUrl
'@
Assert-Equal 'https://seam.example/?preview_theme_id=170064871700&_ab=0&_fd=0&_sc=1' $withLiveSeam.Text.Trim() `
    'with the seam declared, the control is pinned to the live theme without the caller passing anything'

Write-Host ''
Write-Host 'The table is validated, because a wrong one produces a URL that looks right' -ForegroundColor Cyan

Assert-Throws { Get-MarketTable -Markets @(@{ Market = 'NL'; Domain = 'https://smartwatchbanden.nl' }) } `
    'a Domain carrying a scheme is refused' '*scheme*'
Assert-Throws { Get-MarketTable -Markets @(@{ Market = 'NL'; Domain = 'smartwatchbanden.nl/nl' }) } `
    'a Domain carrying a path is refused' '*path*'
Assert-Throws { Get-MarketTable -Markets @(@{ Market = 'NL'; Domain = 'a.nl' }, @{ Market = 'NL'; Domain = 'b.nl' }) } `
    'the same market label twice is refused' '*twice*'
Assert-Throws { Get-MarketTable -Markets @(@{ Market = 'NL' }) } 'a row with no Domain is refused' '*no Domain*'
Assert-Throws { Get-MarketTable -Markets @(@{ Domain = 'a.nl' }) } 'a row with no Market label is refused' '*no Market*'
Assert-Throws { Get-MarketTable -Markets @() } 'an empty table is refused -- a store serves at least one market' '*at least one*'

Assert-Equal '/de' (@(Get-MarketTable -Markets @(@{ Market = 'DE'; Domain = 'a.nl'; PathPrefix = 'de/' })))[0].PathPrefix `
    'a PathPrefix is normalised: leading slash added, trailing slash removed'
Assert-Equal '' (@(Get-MarketTable -Markets @(@{ Market = 'NL'; Domain = 'a.nl' })))[0].PathPrefix `
    'a row that leaves PathPrefix off means the domain root'

# A seam answer is hand-written, so both of the two shapes a person reaches for have to work.
$asObject = @([pscustomobject]@{ Market = 'NL'; Domain = 'a.nl'; PathPrefix = '/nl' })
Assert-Equal '/nl' (@(Get-MarketTable -Markets $asObject))[0].PathPrefix 'a pscustomobject row works as well as a hashtable'
Assert-Equal '' (Get-MarketRowField -Row ([pscustomobject]@{ Market = 'NL' }) -Name 'PathPrefix') `
    'an absent field on an object row reads as empty rather than throwing'
Assert-Equal '' (Get-MarketRowField -Row @{ Market = 'NL' } -Name 'PathPrefix') '...and the same on a hashtable row'

Write-Host ''
Write-Host 'The seam -- the table is the store''s, the mechanism is the plugin''s' -ForegroundColor Cyan

$noSeam = Invoke-Probe -Body 'try { Get-MarketTable } catch { Write-Host $_.Exception.Message }'
Assert-True ($noSeam.Text -like '*Get-StorefrontMarkets*') 'with no seam declared, the refusal names the function to add'
Assert-True ($noSeam.Text -like '*repo-config.ps1*') '...and the file it belongs in'
Assert-True ($noSeam.Text -notlike '*smartwatchbanden*' -and $noSeam.Text -notlike '*xoxowildhearts*') `
    'no default table is invented here -- neither store''s domains appear in the lib at all'

$withSeam = Invoke-Probe -Body @'
function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }
(Get-MarketPreviewUrls -ThemeId 4)[0].Url
'@
Assert-Equal 'https://seam.example/?preview_theme_id=4&_ab=0&_fd=0&_sc=1' $withSeam.Text.Trim() `
    'with the seam declared, every function answers out of it without being passed anything'

Write-Host ''
Write-Host 'The superset, and the language' -ForegroundColor Cyan

# Both stores' accessors survive, so a store adopting this needs a forwarder and no caller changes.
Assert-Equal 'smartwatcharmbaender.de' (Get-MarketDomains -Markets $SWB)['DE'] 'Get-MarketDomains is kept for the callers that build their own URLs'
Assert-Equal '/de' (Get-MarketPaths -Markets $XOXO)['DE'] 'Get-MarketPaths is kept for the callers on the other side'
Assert-Equal 5 (Get-MarketDomains -Markets $SWB).Count '...and both are derived from the one table, so they cannot disagree with it'

foreach ($fn in @('Get-MarketTable', 'Get-MarketUrls', 'Get-MarketPreviewUrls', 'Write-MarketPreviewUrls',
                  'Get-MarketDomains', 'Get-MarketPaths', 'Get-NormalizedPaths', 'Test-MangledStorefrontPath',
                  'Get-AppliedThemeId', 'Get-PreviewPrimeUrls', 'Get-MarketHandoverPairs', 'Get-ControlThemeId')) {
    Assert-True (Test-FunctionDefined -Name $fn) "the superset still exports $fn"
}

$bytes = [System.IO.File]::ReadAllBytes($LibPath)
Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) 'the lib is pure ASCII (repo convention for .ps1)'
$text = [System.IO.File]::ReadAllText($LibPath)
foreach ($dutch in @('Geef ', 'bestand', 'gedeelde', 'markt', 'Dot-source dit')) {
    Assert-True ($text -notlike "*$dutch*") "the lib is English -- no '$dutch' came across in the merge"
}

if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
