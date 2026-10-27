<#
.SYNOPSIS
    Tests for scripts/lib/dev-pages-lib.ps1 -- the hub and the test-gate page of the dev server
    (#3097) -- and for the plugin libs it reuses: plugins/dkj-policy/hub/lib/general-pages-lib.ps1 -- the page
    shell, the number formats and the four general pages (SessionStart, Artifacts, Issues, Release notes) that
    moved there in #3119, and to dkj-policy in #3198. Pure: the servers that serve them are
    exercised by connector-dashboard.tests.ps1 and dev-preview-sessionstart.tests.ps1.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')
# The Test gate page's lib, which this suite also covers: the plugin's since #3470, and no longer loaded by
# dev-pages-lib now that the Test gate is the plugin hub's alone (#3540).
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\test-gate-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
# A statement that throws -- a malformed -match pattern inside an assert, #3257 -- is skipped under
# 'Continue', so the suite would end green without ever evaluating it. Count it instead (as #1881 does).
trap { $script:fail++; Write-Host "  [FAIL] unhandled terminating error: $_" -ForegroundColor Red; continue }
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

Write-Host '-- the number formats' -ForegroundColor Cyan
Assert-Equal '58,895' (Format-DevNumber 58895) 'thousands separators, whatever the culture'
Assert-Equal '--' (Format-DevNumber $null) 'a value not read is --'
Assert-Equal '7.6s' (Format-DevSeconds 7.6) 'under a minute: seconds with one decimal'
Assert-Equal '23:22' (Format-DevSeconds 1402) 'from a minute: m:ss'
Assert-Equal '59.6s' (Format-DevSeconds 59.6) 'just under a minute stays in seconds'
Assert-Equal '1:38:47' (Format-DevSeconds 5927) 'from an hour: h:mm:ss, so a long sum does not read as minutes'
Assert-Equal '59:59' (Format-DevSeconds 3599) 'and just under an hour stays m:ss'

Write-Host '-- the page shell' -ForegroundColor Cyan
$shell = Format-DevPageHtml -Title 'A <b>page' -Lead 'lead' -Body '<p>body</p>' -FooterNote 'note'
Assert-True ($shell.IndexOf('<div class="breadcrumbs-bar">') -lt $shell.IndexOf('<main')) 'the breadcrumb bar comes before <main>'
Assert-True ($shell -match '<li><a href="/">Home</a></li>') 'the trail starts at Home, linked'
Assert-True ($shell -match 'breadcrumbs__sep" aria-hidden="true"><svg\ viewBox="0\ 0\ 24\ 24"><path\ fill="currentColor"\ fill-rule="evenodd"\ d="M9\.793\ 16\.707a1\ 1\ 0\ 0\ 1\ 0-1\.414L13\.086\ 12\ 9\.793\ 8\.707a1\ 1\ 0\ 0\ 1\ 1\.414-1\.414l4\ 4a1\ 1\ 0\ 0\ 1\ 0\ 1\.414l-4\ 4a1\ 1\ 0\ 0\ 1-1\.414\ 0"\ clip-rule="evenodd"/></svg></span><span aria-current="page">A &lt;b&gt;page</span>') 'and ends at the page, unlinked and escaped'
Assert-True ($shell -match '<h1>A &lt;b&gt;page</h1>') 'the h1 is the page name, escaped'
Assert-True ($shell -match 'data-theme-key="general-pages"') 'the theme key is the general pages'' own, so a theme picked on any page the hub serves holds on all of them (#3168)'
Assert-True ($shell -match '<p class="footer-note">note</p>') 'the footer note closes the column'

Write-Host '-- the general page shell (the plugin''s)' -ForegroundColor Cyan
$gshell = Format-GeneralPageHtml -Title 'An <i>issue' -Lead 'lead' -Body '<p>body</p>' -Eyebrow 'Org/some<repo>' -SiteName 'Org/some<repo>'
Assert-True ($gshell -match '<li><a href="/hub">Home</a></li>') 'the first crumb goes to /hub on the general server'
Assert-True ($gshell -match '<title>Org/some&lt;repo&gt; -- An &lt;i&gt;issue</title>' -and $gshell -match 'site-header__name">Org/some&lt;repo&gt; <span class="site-header__tag">hub</span>' -and $gshell -notmatch 'class="eyebrow"') 'the title and the site header carry the repo''s name, escaped, and a named page needs no eyebrow'
Assert-True ($gshell -match 'data-theme-key="general-pages"') 'the theme key is the general server''s own'
Assert-True ($gshell -notmatch 'dkj-claude-plugins') 'and nothing of this repo is built into it'
$gIntro = $gshell.IndexOf('<h1>')
Assert-True ($gshell.Contains((Format-RepoHubBanner)) -and $gshell.IndexOf('id="hub-banner"') -lt $gshell.IndexOf('class="site-header"') -and $gshell.IndexOf('id="hub-banner"') -lt $gIntro -and $gIntro -lt $gshell.IndexOf('<p>body</p>') -and ([regex]::Matches($gshell, 'id="hub-banner"')).Count -eq 1) 'every page carries the general banner once, as the first thing in <body>, above the site header, its h1 and its own blocks (#3297; owner, October 24, 2026)'
# THE SITE HEADER (October 22, 2026): only where a caller asks for it with -Brand, so every other repo's pages stay as they were.
$anon = Format-GeneralPageHtml -Title 'T' -Lead 'L' -Body ''
Assert-True ($anon -notmatch 'site-header' -and $anon -match 'theme-settings--floating') 'a page that names no site draws no site header, and its settings button floats as before'
Assert-True ((ConvertTo-SiteHeaderName -RepoName 'DKJ-Solutions/dkj-x') -eq 'dkj-x' -and (ConvertTo-SiteHeaderName -RepoName 'a/b<c>') -eq 'a/b<c>') 'a GitHub slug loses its owner in the header; any other name stays whole'
$bshell = Format-GeneralPageHtml -Title 'T' -Lead 'L' -Body '' -Eyebrow 'Org/r' -Brand 'r<x>' -HubHref '/home'
Assert-True ($bshell -match '<header class="site-header"><div class="container"><a class="site-header__brand" href="/home" aria-label="r&lt;x&gt;, home"><span class="site-header__mark" aria-hidden="true">DKJ</span><span class="site-header__name">r&lt;x&gt;</span></a><div id="settings"></div></div></header>') 'with -Brand the header carries the escaped name, links home, and holds the settings button'
Assert-True ((Format-SiteHeaderHtml -Name 'n' -Tag 'p<q>') -match 'aria-label="n p&lt;q&gt;, home">.*site-header__name">n <span class="site-header__tag">p&lt;q&gt;</span></span>' -and $bshell -notmatch 'site-header__tag') 'a -Tag follows the name, escaped, and is left out when empty'
Assert-True ((Format-ProductHomeHtml) -match 'site-header__name">dkj-claude-plugins <span class="site-header__tag">product</span>' -and (Format-SpecialistsPageHtml -Rows @() -CharsPerToken 3) -match '>product</span>') 'every page this server builds says product: it is this repo''s product port again (#3540)'
Assert-True ((Format-RepoHomeHeadHtml -RepoName 'r' -Lead 'l') -match '<h1>r</h1>\s*<p class="lead">l</p>') 'without a site header the home page keeps its intro, as in every other repo'
Assert-True ($bshell -notmatch 'class="eyebrow"' -and $bshell -notmatch 'theme-settings--floating' -and $bshell.IndexOf('class="site-header"') -lt $bshell.IndexOf('class="breadcrumbs-bar"')) 'and it stands above the bar, with no eyebrow and no floating button'

Write-Host '-- the product: the home page on / (#3540)' -ForegroundColor Cyan
$pages = @(Get-ProductPages)
Assert-Equal '/connectors,/specialists' (($pages | ForEach-Object { $_.Href }) -join ',') 'the product links its two pages: Connectors and Specialists, the DKJ repos on GitHub a section of /connectors/dkj since #3549; the general pages are the plugin hub''s (#3540)'
Assert-Equal '/artifacts,/issues,/release-notes,/sessionstart,/test-gate,/stopwatch,/logbook,/plugins' ((Get-GeneralPages | ForEach-Object { $_.Href }) -join ',') 'the plugin lists the eight general pages, in order: Test gate, Stopwatch and Logbook every repo''s since #3470, Plugins since #3482'
$ph = Format-ProductHomeHtml -HubUrl 'http://localhost:4890' -SourceCommit 'abc1234'
Assert-True ($ph -match '<title>dkj-claude-plugins -- Home</title>' -and $ph -notmatch '<h1' -and $ph -notmatch 'class="lead"') 'under the site header the home page has no intro at all, and its title says Home'
Assert-True ($ph -match '(?s)<body>\s*<div class="notice" id="hub-banner".*?</script>\s*<header class="site-header">.*?</header>\s*<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>\s*<li><span aria-current="page">Home</span></li>\s*</ol>') 'the banner opens <body>, the site header under it and the bar right under that, its trail the one crumb Home'
Assert-True ($ph -match 'site-header__name">dkj-claude-plugins <span class="site-header__tag">product</span>' -and $ph -match '<header class="site-header"><div class="container"><a class="site-header__brand" href="/"') 'the site header names the repo with product after it, and goes home'
Assert-True ($ph -notmatch 'class="eyebrow"' -and ([regex]::Matches($ph, '<header')).Count -eq 1 -and $ph -notmatch 'theme-settings--floating' -and $ph -match '<div id="settings"></div></div></header>') 'no eyebrow, no <header> but the site header, which holds the settings button'
Assert-True ($ph -match '<div class="grid-3">\r?\n<section class="card card--link"><nav class="menu-list" aria-label="Hub"><a class="menu-item" href="http://localhost:4890">') 'the grid opens on the Hub card, linking the plugin hub'
Assert-True ($ph.IndexOf('aria-label="Hub"') -lt $ph.IndexOf('href="/connectors"') -and $ph.IndexOf('href="/connectors"') -lt $ph.IndexOf('href="/specialists"') -and $ph -notmatch 'href="/dkj-repos"') 'then Connectors and Specialists, in that order, and no DKJ repos card of its own (#3549)'
Assert-Equal 3 ([regex]::Matches($ph, '<section class="card card--link"><nav class="menu-list" aria-label="[^"]+"><a class="menu-item" href="[^"]+"><svg class="menu-item__icon"')).Count 'three cards, each a .card--link with its icon first'
Assert-True ($ph -notmatch 'href="/(repository|test-gate|stopwatch|logbook|plugins|artifacts|issues|release-notes|sessionstart|brandbook)"') 'and no general page of its own: those are the plugin hub''s (#3540)'
Assert-True ($ph -match 'class="footer-note">[^\n]*serve-connector-dashboard\.ps1</code>, from <code>abc1234</code>') 'the footer names the server and the commit it loaded'
Assert-True ((Format-ProductHomeHtml) -notmatch ', from <code>') 'and leaves the commit out when it could not be read'
$down = Format-ProductHomeHtml
Assert-True ($down -match '<section class="card"><p class="msg" role="status">The hub is not running' -and $down -notmatch 'aria-label="Hub"' -and $down -match 'href="/connectors"') 'with no hub known one card says it is not running, and the product''s own pages stay linked'
Assert-True ((Format-ProductHomeHtml -HubUrl 'http://evil.example:4890') -match 'hub is not running' -and (Format-ProductHomeHtml -HubUrl 'javascript:alert(1)') -notmatch 'javascript:') 'a hub url that is not plain loopback is no hub at all'
Assert-True (@(@($pages) + @(Get-GeneralPages) | Where-Object { -not (Get-HubIconSvg -Name $_.Icon) }).Count -eq 0) 'every page a hub or the product links names an icon the hub has'
Assert-True (@(Get-HubGroups | Where-Object { -not (Get-HubIconSvg -Name $_.Icon) }).Count -eq 0) 'and every group page a hub card links names one too'

Write-Host '-- the Clock group page (the owner, October 27, 2026)' -ForegroundColor Cyan
Assert-Equal '/test-gate,/stopwatch,/logbook' ((Get-GeneralPages | Where-Object { $_.Group -eq '/clock' } | ForEach-Object { $_.Href }) -join ',') 'Test gate, Stopwatch and Logbook belong to the Clock group, in that order'
$clockCards = @(Format-HubPageCardsHtml -Pages @(Get-GeneralPages))
Assert-True ($clockCards.Count -eq 6 -and @($clockCards | Where-Object { $_ -notmatch '^<section class="card card--link">' }).Count -eq 0 -and @($clockCards | Where-Object { ([regex]::Matches($_, '<a ')).Count -ne 1 }).Count -eq 0) 'the hub draws six cards for the eight pages, each a .card--link holding exactly one link'
Assert-True ($clockCards[4] -match 'href="/clock"' -and $clockCards[4] -match 'menu-item__label">Clock<' -and -not ($clockCards -match 'href="/(test-gate|stopwatch|logbook)"')) 'the Clock card takes the Test gate''s place and links /clock; no member has a hub card of its own'
$clockPage = Format-HubGroupPageHtml -Href '/clock' -RepoName 'dkj-claude-plugins'
Assert-True ($clockPage -match '<div class="grid__head"><h1>Clock</h1></div>' -and ([regex]::Matches($clockPage, '<section class="card card--link">')).Count -eq 3 -and $clockPage.IndexOf('href="/test-gate"') -lt $clockPage.IndexOf('href="/stopwatch"') -and $clockPage.IndexOf('href="/stopwatch"') -lt $clockPage.IndexOf('href="/logbook"')) 'the /clock page is an h1 and one card link each for Test gate, Stopwatch and Logbook, in that order'
Assert-True ($clockPage -match 'aria-current="page">Clock</span>' -and $clockPage -match '<li><a href="/hub">Home</a></li>') 'its trail reads Home > Clock'
Assert-True ($null -eq (Format-HubGroupPageHtml -Href '/nope') -and $null -eq (Format-HubGroupPageHtml -Href '/Clock')) 'a path no group has is no group page'
Assert-True ((Get-HubIconSvg -Name '') -eq '' -and (Get-HubIconSvg -Name 'nope') -eq '' -and (Format-HubCardLinkHtml -Href '/x' -Label 'X') -notmatch 'menu-item__icon') 'a card that names no icon, or one the hub lacks, draws none'
$houseCss = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'plugins\dkj-policy\assets\house-style\house-style.css'))
Assert-True ($houseCss -match '\.card--link \{ position: relative; \}' -and $houseCss -match '\.card--link a::after \{ content: ""; position: absolute; inset: 0; \}') 'the house style stretches a .card--link''s one link over the card'
Assert-True ($ph -notmatch '<style>' -and $ph -notmatch 'grid__head') 'the home page restyles nothing and has no group heading (#3133)'
$homeBanner = $ph.IndexOf('<div class="notice" id="hub-banner"')
Assert-True ($homeBanner -ge 0 -and $homeBanner -lt $ph.IndexOf('class="site-header"') -and $homeBanner -lt $ph.IndexOf('class="grid-3"')) 'the airsquats banner sits above the site header, and so above the cards'
Assert-True ($ph.Contains('data-hub-timer') -and $ph.Contains('<input type="checkbox" data-hub-done> <span data-hub-count>10</span> due') -and $ph.Contains('data-hub-due hidden')) 'it counts down to the hour, and its "10 due" box stays hidden until an hour has passed, on the same one-row line as the timer'
Assert-True (([regex]::Matches((Format-RepoHubBanner), '<p[ >]')).Count -eq 1) 'the banner is one row: the timer and the box owed share a single paragraph, never a second line (Dave, October 24, 2026)'
$bannerJs = Format-RepoHubBanner
Assert-True ($bannerJs -notmatch 'localStorage' -and $bannerJs -match 'fetch\(path' -and ([regex]::Matches($bannerJs, '"/api/airsquats')).Count -eq 1 -and $bannerJs -notmatch 'XMLHttpRequest|WebSocket|sendBeacon|eval\(|new Function|document\.cookie') 'its state is the server''s, shared by every hub and machine: it asks /api/airsquats on its own origin and nothing else (#3438)'
Assert-True ($bannerJs -match 'ask\("POST", API \+ "/clear"\)' -and $bannerJs -match '\(s\.per \|\| 10\) \* s\.owed' -and $bannerJs -match 'if \(s\.announce\) \{ tone\(\); \}') 'ticking the box is a POST to /clear, the box shows 10 per hour owed, and the server says when to play the tone'
Assert-True ($bannerJs -match '<span data-hub-owner hidden[^>]*> &middot; <span data-hub-account></span></span></p>' -and $bannerJs -match 'account\.textContent = s\.account; owner\.hidden = false;' -and $bannerJs -notmatch 'innerHTML') 'the row ends on the Windows account the hub runs under, written as text and shown only once the server names one (#3476)'
$ix = @('id="hub-banner"', 'class="site-header"', 'id="settings"', 'class="breadcrumbs-bar"', 'class="grid-3"', 'class="footer-note"') | ForEach-Object { $ph.IndexOf($_) }
Assert-True ((@($ix | Where-Object { $_ -lt 0 }).Count -eq 0) -and ((($ix | Sort-Object) -join ',') -eq ($ix -join ','))) 'the blocks stand in the form''s order'
$evil = Format-ProductHomeHtml -Pages @(@{ Href = '/x"><script>'; Label = '<b>'; Sub = '' })
Assert-True ($evil -notmatch 'x"><script>' -and $evil -match 'href="/x&quot;&gt;&lt;script&gt;"' -and $evil -notmatch '<b>') 'every value is escaped'

Write-Host '-- the test-gate model' -ForegroundColor Cyan
$json = '{ "seconds": { "a.tests.ps1": 10, "b.tests.ps1": 30, "gone.tests.ps1": 5 }, "recordedFrom": { "runs": ["111", "222"], "date": "2026-10-07", "machine": "m", "method": "mean" } }' | ConvertFrom-Json
$m = ConvertFrom-SuiteDurations -Durations $json -SuiteFiles @('a.tests.ps1', 'b.tests.ps1', 'new.tests.ps1')
Assert-Equal 'b.tests.ps1,a.tests.ps1,gone.tests.ps1' (($m.Suites | ForEach-Object { $_.Name }) -join ',') 'suites slowest first'
Assert-Equal 45 $m.Total 'the sum of every recorded suite'
Assert-Equal 'new.tests.ps1' ($m.Missing -join ',') 'a suite on disk the file does not record is missing'
Assert-Equal 'gone.tests.ps1' ($m.Stale -join ',') 'a recorded suite no longer on disk is stale'
Assert-Equal '111,222' ($m.Runs -join ',') 'the runs it was recorded from'
$empty = ConvertFrom-SuiteDurations -Durations $null -SuiteFiles @('a.tests.ps1')
Assert-Equal 0 @($empty.Suites).Count 'no file: no suites'
Assert-Equal 'a.tests.ps1' ($empty.Missing -join ',') 'and every suite on disk is missing'

Write-Host '-- the test-gate page' -ForegroundColor Cyan
$tg = Format-TestGatePageHtml -Model $m
Assert-True ($tg -match '<h1>Test gate</h1>') 'the page is named Test gate'
Assert-True ($tg.IndexOf('b.tests.ps1') -lt $tg.IndexOf('>a.tests.ps1<')) 'the table lists the slowest first'
Assert-True ($tg -match 'width: 100%"></span></span></td><td>66.7%</td>') 'the slowest suite''s bar is full, and its share is of the sum'
Assert-True ($tg -match 'width: 33.33%"></span></span></td><td>22.2%</td>') 'another suite''s bar is drawn against the slowest'
Assert-True ($tg -match 'gone.tests.ps1</code> <span class="badge badge--sm badge--neutral">no longer on disk') 'a stale suite is marked'
Assert-True ($tg -match 'class="msg" role="status">Not recorded yet.*new.tests.ps1') 'the missing suites are named'
Assert-True ((Format-TestGatePageHtml -Model $m -RepoSlug 'DKJ-Solutions/dkj-claude-plugins') -match 'href="https://github.com/DKJ-Solutions/dkj-claude-plugins/actions/runs/111"') 'each run links to its CI run, in the repo the origin remote names'
Assert-True ($tg -notmatch 'actions/runs/' -and $tg -match '<dt>CI runs</dt><dd>111, 222</dd>' -and (Format-TestGatePageHtml -Model $m -RepoSlug 'x" onclick="y') -notmatch 'actions/runs/') 'without an owner/name it names each run by its number and links nowhere (#3470)'
$none = Format-TestGatePageHtml -Model (ConvertFrom-SuiteDurations -Durations $null -SuiteFiles @('a.tests.ps1')) -ReadError 'the file is not there'
Assert-True ($none -match 'No test gate has been measured in this repo yet' -and $none -notmatch 'could not be read' -and $none -notmatch 'Not recorded yet, so the gate charges') 'a repo with no suite-durations.json gets the empty state, not a warning (#3470)'
Assert-True ($tg -match '<li><a href="/hub">Home</a></li>' -and (Format-TestGatePageHtml -Model $m -HubHref '/') -match '<li><a href="/">Home</a></li>') 'its Home crumb is the general server''s /hub, or the hub the caller names'
Assert-True ($tg -match '<li><a href="/hub">Home</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/clock">Clock</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">Test gate</span></li>') 'and its trail reads Home > Clock > Test gate (the owner, October 27, 2026)'
$bad = Format-TestGatePageHtml -Model $empty -ReadError 'it is not valid JSON'
Assert-True ($bad -match 'msg msg--warn" role="alert">scripts/tests/suite-durations.json could not be read: it is not valid JSON') 'an unreadable file is a warning'
Assert-True ($bad -match 'No suite durations are recorded') 'and the table says it is empty rather than vanishing'
$hostile = ConvertFrom-SuiteDurations -Durations ('{ "seconds": { "<x>.tests.ps1": 1 }, "recordedFrom": { "runs": ["1\" onclick=\"x"] } }' | ConvertFrom-Json)
$hp = Format-TestGatePageHtml -Model $hostile
Assert-True ($hp -match '&lt;x&gt;.tests.ps1' -and $hp -notmatch '<x>') 'a suite name is escaped'
Assert-True ($hp -notmatch 'onclick') 'a run id that is not a number is not linked'

Write-Host '-- the test-gate groups' -ForegroundColor Cyan
$groupsJson = '[ { "key": "one", "title": "Step <one>", "guards": "the first step", "tips": ["Mind <this>", "And that"], "split": "this <and> that.", "suites": ["a.tests.ps1", "new.tests.ps1", "away.tests.ps1"] }, { "key": "two", "title": "Step two", "guards": "the second", "suites": ["b.tests.ps1"] } ]' | ConvertFrom-Json
$gm = ConvertFrom-SuiteDurations -Durations $json -SuiteFiles @('a.tests.ps1', 'b.tests.ps1', 'new.tests.ps1') -Groups $groupsJson
Assert-Equal 'one,two' (($gm.Groups | ForEach-Object { $_.Key }) -join ',') 'the groups keep the file''s order, not their cost'
Assert-Equal 'a.tests.ps1' (($gm.Groups[0].Suites | ForEach-Object { $_.Name }) -join ',') 'a group holds its recorded suites only'
Assert-Equal 10 $gm.Groups[0].Total 'and its total is theirs'
Assert-Equal 'new.tests.ps1' ($gm.Groups[0].Unmeasured -join ',') 'a grouped suite on disk with no recorded duration is unmeasured, not dropped'
Assert-Equal 'gone.tests.ps1' ($gm.Ungrouped -join ',') 'a suite no group holds is ungrouped'
Assert-Equal 'away.tests.ps1' ($gm.Unknown -join ',') 'a grouped name not on disk is unknown'
Assert-Equal 0 (@($m.Groups).Count + @($m.Ungrouped).Count) 'with no groups there are no groups, and nothing is called ungrouped'
$gp = Format-TestGatePageHtml -Model $gm
Assert-True ($gp -match '<h2>Groups</h2>' -and $gp -match 'What each group of suites guards') 'the page opens with the groups, and says what each guards'
Assert-True ($gp -match 'href="#group-one">Step &lt;one&gt;</a>' -and $gp -notmatch 'Step <one>') 'each group links to its own section, its title escaped'
Assert-True ($gp.IndexOf('id="group-one"') -lt $gp.IndexOf('id="group-two"') -and $gp -match '<h2>Step two</h2><p class="card__sub">Guards the second</p>') 'each group has its own section, in order, with what it guards'
Assert-True ($gp.IndexOf('>a.tests.ps1<') -gt $gp.IndexOf('id="group-one"') -and $gp.IndexOf('>a.tests.ps1<') -lt $gp.IndexOf('id="group-two"')) 'a suite is listed in its own group'
Assert-True ($gp -match 'href="#group-one">.*?</span></td><td class="num">2</td>' -and $gp -match 'new.tests.ps1</code> <span class="badge badge--sm badge--neutral">not recorded yet</span></td><td class="num">--</td>') 'a group counts and lists its unmeasured suites too, marked as not recorded yet'
Assert-True ($gp -match 'role="alert">In no group of scripts/tests/suite-groups.json: <code>gone.tests.ps1</code>' -and $gp -match '<h2>Not grouped</h2>') 'an ungrouped suite is a warning, and still listed'
Assert-True ($gp -match 'Grouped but no longer on disk: <code>away.tests.ps1</code>') 'a grouped name not on disk is named'
Assert-True ($gp -notmatch 'id="suites"') 'and the ungrouped single table is gone'
Assert-True ($gp -match '<tfoot><tr class="row-total dp-total"><td class="dp-left">Total <span class="note">all groups, run one after another; CI runs them in parallel</span></td><td class="num">3</td><td class="num">40.0s</td><td class="dp-left"></td><td>88.9%</td></tr></tfoot>') 'the groups table closes on the sum of every group, its count, and its share of the whole'
Assert-True ($gp -match '>Total <span class="note">2 suites, run one after another; CI runs them in parallel</span></td><td class="num">10.0s</td><td class="dp-left"></td><td>22.2%</td></tr></tfoot>') 'each group''s table closes on its own sum, counting its unmeasured suites'
Assert-True ($gp -match '\.dp-total td \{ border-top: 2px solid var\(--paper-4\); \}') 'the total row stands under a heavier rule than the rows above it'
Assert-Equal ([regex]::Matches($gp, '<table').Count) ([regex]::Matches($gp, '<tfoot>').Count) 'every table on the page has a total'
# A section's notes close it, below its card: what sits between a section's id and the next section's.
$sectionOf = { param($Id) $i = $gp.IndexOf('id="' + $Id + '"'); $n = $gp.IndexOf('<div class="grid-2"', $i + 1); if ($n -lt 0) { $n = $gp.Length }; $gp.Substring($i, $n - $i) }
$one = & $sectionOf 'group-one'
Assert-True ($one -match '</section>\r?\n<div class="grid__full dp-tips"><h3>Points to note</h3><ul><li>Mind &lt;this&gt;</li><li>And that</li><li>Could be split into this &lt;and&gt; that.</li></ul></div>\r?\n</div>') 'a group''s notes close its section, below the card and outside the table, escaped, its split advice last'
Assert-True ((& $sectionOf 'groups') -match '<li>Candidates to split, largest first: Step &lt;one&gt; \(2 suites, 22%\)\. Each one&#39;s own notes say how\.') 'the overview names the split candidates with their measured size, and only those the file gives a split for'
Assert-True ($one.IndexOf('</table>') -lt $one.IndexOf('Points to note')) 'so they come after its table'
Assert-True ((& $sectionOf 'group-two') -notmatch '<h3>') 'a group with no tips has no notes'
Assert-True (@('groups', 'ungrouped', 'recorded' | Where-Object { (& $sectionOf $_) -notmatch '</section>\r?\n<div class="grid__full dp-tips"><h3>Points to note</h3>' }).Count -eq 0) 'the groups, not-grouped and measured sections close on their own notes'
$gf = Format-TestGatePageHtml -Model $m -GroupsError 'the file is not there'
Assert-True ($gf -match 'suite-groups.json could not be read: the file is not there, so the suites are listed ungrouped' -and $gf -match 'id="suites"') 'without the groups file the page falls back to one table, and says why'

Write-Host '-- what a suite protects, and why this change selects it (#3309, lever 3)' -ForegroundColor Cyan
$header = "<#`r`n.SYNOPSIS`r`n    Tests for x-lib.ps1 -- the thing`r`n    it pins.`r`n`r`n.DESCRIPTION`r`n    Long.`r`n#>`r`nexit 0"
Assert-Equal 'Tests for x-lib.ps1 -- the thing it pins.' (Get-SuiteSynopsis -Text $header) 'the synopsis is the paragraph under .SYNOPSIS, on one line'
Assert-Equal 'Short.' (Get-SuiteSynopsis -Text "<#`n.SYNOPSIS`n    Short.`n#>") 'a synopsis that runs into the closing of the header ends there'
Assert-Equal '' (Get-SuiteSynopsis -Text "exit 0") 'a file with no synopsis has none'
Assert-Equal 20 (Get-SuiteSynopsis -Text ("<#`n.SYNOPSIS`n" + ('w ' * 40) + "`n`n#>") -Max 20).Length 'and a long one is capped'
$sm = ConvertFrom-SuiteDurations -Durations $json -SuiteFiles @('a.tests.ps1', 'b.tests.ps1') -Synopses @{ 'a.tests.ps1' = 'Pins <the> fold' }
$sp = Format-TestGatePageHtml -Model $sm
Assert-True ($sp -match '<code>a.tests.ps1</code><br><span class="note">Pins &lt;the&gt; fold</span>') 'each suite says what it protects under its name, escaped'
Assert-True ($sp -notmatch 'id="selection"') 'without a selection the page has no change section'
$selection = @{ Base = 'origin/main'; Changed = @('brandbook/src/<x>.css'); Proven = $true; Reason = ''; PoolCount = 165
                Selected = @('scripts/tests/a.tests.ps1', 'scripts/tests/b.tests.ps1'); Why = @{ 'scripts/tests/a.tests.ps1' = 'it reaches <lib>'; 'scripts/tests/b.tests.ps1' = 'its walk scope covers it' }
                CiText = 'only stylesheets change' }
$sel = Format-TestGatePageHtml -Model $sm -Selection $selection
Assert-True ($sel.IndexOf('id="selection"') -ge 0 -and $sel.IndexOf('id="selection"') -lt $sel.IndexOf('id="suites"')) 'the change section comes before the suite tables'
Assert-True ($sel -match '<dt>Locally</dt><dd>2 of 165 suites</dd>' -and $sel -match '<dt>On CI</dt><dd>only stylesheets change</dd>') 'it says what runs locally and on CI'
Assert-True ($sel -match 'brandbook/src/&lt;x&gt;.css' -and $sel -match 'it reaches &lt;lib&gt;' -and $sel -notmatch '<lib>') 'the changed paths and the reasons are escaped'
Assert-True ($sel.IndexOf('>b.tests.ps1<') -lt $sel.IndexOf('>a.tests.ps1<', $sel.IndexOf('id="selection"'))) 'the selected suites are listed slowest first'
$none = Format-TestGatePageHtml -Model $sm -Selection @{ Base = 'origin/main'; Changed = @(); Proven = $false; Reason = 'Nothing differs from origin/main, so nothing is selected'; Selected = @(); Why = @{}; PoolCount = 0; CiText = '' }
Assert-True ($none -match 'id="selection"' -and $none -match 'Nothing differs from origin/main, so nothing is selected\.') 'a clean checkout says there is nothing to select'
$whole = Format-TestGatePageHtml -Model $sm -Selection @{ Base = 'origin/main'; Changed = @('scripts/lib/gate-lib.ps1'); Proven = $false; Reason = 'the change touches the selection'; Selected = @(); Why = @{}; PoolCount = 165; CiText = '' }
Assert-True ($whole -match '<dt>Locally</dt><dd>every suite -- the change touches the selection</dd>' -and $whole -notmatch 'Why it runs') 'an unproven selection says every suite runs, and why, with no table'
$all = Format-TestGatePageHtml -Model $sm -Selection @{ Base = 'origin/main'; Changed = @('x.ps1'); Proven = $true; Reason = ''; Selected = @('scripts/tests/a.tests.ps1', 'scripts/tests/b.tests.ps1'); Why = @{}; PoolCount = 2; CiText = '' }
Assert-True ($all -match '<dt>Locally</dt><dd>every suite -- the change can affect all 2</dd>') 'a selection of the whole pool says every suite, not "2 of 2" (Victor)'
Assert-True ($sel -match 'The suites the affected-suite selection picks for it, against origin/main') 'and the section claims the selection, not the whole gate, which may skip the suites first (Victor)'

Write-Host '-- suite-groups.json against the tree' -ForegroundColor Cyan
# The file is a reading aid and nothing selects suites by it, so the only way it goes wrong is by going
# stale: a suite added without a group, or a group still naming a suite that was removed or renamed.
$realGroups = @((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\tests\suite-groups.json') -Raw -Encoding UTF8 | ConvertFrom-Json).groups)
$grouped = @($realGroups | ForEach-Object { @($_.suites) })
$onDisk = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scripts\tests') -Filter '*.tests.ps1' -File | ForEach-Object { $_.Name })
$noGroup = @($onDisk | Where-Object { $grouped -notcontains $_ })
Assert-True ($noGroup.Count -eq 0) ('every suite is in a group of scripts/tests/suite-groups.json -- add it to the group whose workflow step it guards' + $(if ($noGroup.Count) { ': ' + ($noGroup -join ', ') } else { '' }))
$twice = @($grouped | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
Assert-True ($twice.Count -eq 0) ('and in one group only' + $(if ($twice.Count) { ': ' + ($twice -join ', ') } else { '' }))
$gone = @($grouped | Where-Object { $onDisk -notcontains $_ })
Assert-True ($gone.Count -eq 0) ('and no group names a suite that is not on disk' + $(if ($gone.Count) { ': ' + ($gone -join ', ') } else { '' }))
Assert-True (@($realGroups | Where-Object { -not ($_.key -match '^[a-z-]+$' -and $_.title -and $_.guards) }).Count -eq 0) 'every group has a key, a title and what it guards'
Assert-True (@($realGroups | Where-Object { -not @(@($_.tips) | Where-Object { $_ }).Count }).Count -eq 0) 'and at least one point to note'

Write-Host '-- the SessionStart page' -ForegroundColor Cyan
$ssModel = @{
    Total = 1000; Budget = 4000; State = 'inside'; Ok = $true; Tokens = 320; GeneratedAt = '2026-10-18 00:00:00'; Seconds = 1.2
    Documents = @(
        @{ Display = 'CLAUDE.md'; Bytes = 100; Source = 'measured' },
        @{ Display = '~/persona.md'; Bytes = 900; Source = 'carried' },
        @{ Display = 'lost.md'; Bytes = 0; Source = 'unmeasured' })
}
$ss = Format-SessionStartPageHtml -Model $ssModel
$ssDocs = Format-SessionStartPageHtml -Model $ssModel -Section 'documents'
Assert-True ($ss -match '<h1>SessionStart</h1>') 'the overview is named SessionStart'
Assert-True ($ss -match '<section class="card card--link ss-card" id="documents"><h2><a href="/sessionstart/documents">Always-on documents</a></h2>') 'each section is a card on the overview, linking its own page (the Stopwatch''s shape)'
Assert-True ($ss -match 'class="ss-value num">1,000 B of 4,000 B</p>') 'and the documents'' card carries the path against the budget'
Assert-True ($ss -notmatch '<table') 'the overview holds cards, not the tables'
Assert-True ($ssDocs -match '<h1>Always-on documents</h1>' -and $ssDocs -match '<a href="/sessionstart">SessionStart</a>') 'a section''s page is named after it, with a crumb back to the overview'
Assert-True ($ssDocs -match 'Headroom \(B\)</div><div class="v num">3,000') 'inside the budget: the headroom'
Assert-True ($ssDocs.IndexOf('~/persona.md') -lt $ssDocs.IndexOf('<code>CLAUDE.md</code></td>')) 'the documents are listed largest first'
Assert-True ($ssDocs -match '~/persona.md</code></td><td class="num">900</td>.*?<td>90.0%</td><td class="dp-left">from the baseline') 'a carried document says so'
Assert-True ($ssDocs -match 'role="status">Not counted.*lost.md') 'an unmeasured document is named, not counted as zero'
Assert-True ($ss.Replace((Format-RepoHubBanner), '') -notmatch 'msg--warn' -and $ssDocs.Replace((Format-RepoHubBanner), '') -notmatch 'msg--warn') 'no warning inside the budget (the general banner''s own hidden line aside, #3297)'
Assert-True ($null -eq (Format-SessionStartPageHtml -Model $ssModel -Section 'nope')) 'a slug no section has is no page, which the server answers with a 404'
$ssModel.Total = 5000; $ssModel.Ok = $false; $ssModel.State = 'over-growing'
$over = Format-SessionStartPageHtml -Model $ssModel -Section 'documents'
Assert-True ($over -match 'Over the budget \(B\)</div><div class="v num">1,000') 'over the budget: by how much'
Assert-True ($over -match 'msg msg--warn" role="alert">The always-on path is over its limit \(over-growing\)') 'and a warning naming the state'
Assert-True ((Format-SessionStartPageHtml -Model $ssModel) -match 'role="alert">The always-on path is over its limit') 'which the overview carries too'
$failed = Format-SessionStartPageHtml -Model $null -ReadError 'boom <x>'
Assert-True ($failed -match 'could not be measured: boom &lt;x&gt;') 'a failed measurement is a warning, escaped'
Assert-True ($failed -match 'class="ss-value num">Not measured</p>') 'and its card says it was not measured'
Assert-True ((Format-SessionStartPageHtml -Model $null -ReadError 'boom' -Section 'documents') -match 'No always-on document was measured') 'and its page says the table is empty'

Write-Host '-- the SessionStart snapshot' -ForegroundColor Cyan
Assert-True ($ss -notmatch 'id="last-measurement"') 'without a snapshot the overview shows only the live card'
Assert-True ($null -eq (Format-SessionStartPageHtml -Model $ssModel -Section 'layers')) 'and a snapshot section has no page'
$snap = @'
{ "asOf": "2026-10-02", "header": { "eyebrow": "the fourth", "lede": "About **47k** in `CLAUDE.md` <b>" },
  "items": [
    { "id": "a", "name": "Docs", "influence": "direct", "tokens": 600, "measured": true, "source": "s", "previousTokens": 700 },
    { "id": "b", "name": "Stubs", "influence": "setting", "tokens": 100, "measured": false, "source": "s" },
    { "id": "c", "name": "Tools", "influence": "none", "tokens": 300, "measured": false, "source": "s" } ],
  "actions": { "lede": "ranked", "items": [
    { "id": "x", "influence": "direct", "done": true, "tokens": 50, "title": "Old one", "text": "t" },
    { "id": "y", "influence": "setting", "done": false, "tokens": 900, "title": "Open one", "text": "t", "caveat": "careful" } ] },
  "none": { "items": [ { "title": "Harness", "text": "fixed" } ] },
  "advice": { "heading": "Do this", "steps": [ { "title": "1", "text": "first" } ], "dont": { "label": "Do not", "text": "that" } },
  "footer": "method", "previous": { "noneTokens": 200, "totalTokens": 1000 },
  "source": { "artifact": "https://claude.ai/artifact/abc", "title": "Session-start context", "copied": "2026-10-18" } }
'@ | ConvertFrom-Json
$sp = Format-SessionStartPageHtml -Model $ssModel -Snapshot $snap
$ids = @([regex]::Matches($sp, 'ss-card" id="([a-z-]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Equal 'documents,last-measurement,layers,actions,no-influence,advice,method' ($ids -join ',') 'the snapshot''s sections follow the live card, one card each'
Assert-True ($sp -match 'Efficiency score 30 / 100 \(was 20\)</p>') 'the score card is the no-influence share, against the previous one'
Assert-True ($sp -match '1 open, 1 done</p>' -and $sp -match '>Do this</a></h2>') 'the actions'' card counts them, and the advice card takes its heading'
$page = { param($slug) Format-SessionStartPageHtml -Model $ssModel -Snapshot $snap -Section $slug }
$lm = & $page 'last-measurement'
Assert-True ($lm -match 'About <strong>47k</strong> in <code>CLAUDE.md</code> &lt;b&gt;') 'the lede renders bold and code, and escapes the rest'
Assert-True ($lm -match 'Direct \(tokens\)</div><div class="v num">~600 \(60%\)') 'the influence tiles sum the layers'
$ly = & $page 'layers'
Assert-True ($ly.IndexOf('>Docs') -lt $ly.IndexOf('>Stubs') -and $ly.IndexOf('>Stubs') -lt $ly.IndexOf('>Tools')) 'the layers are grouped direct, setting, none'
Assert-True ($ly -match '<td class="num">-100</td>') 'a layer that shrank shows by how much'
Assert-True ($ly -match '<td class="num">~100</td>') 'an estimated layer is marked as one'
$ac = & $page 'actions'
Assert-True ($ac.IndexOf('Open one') -lt $ac.IndexOf('Old one')) 'open actions come before done ones'
Assert-True ($ac -match 'Old one.*?&#10003;</span>Done') 'a done action says so'
Assert-True ($ac -match '<em>Caveat:</em> careful') 'an action carries its caveat'
Assert-True ((& $page 'no-influence') -match '<dt>Harness</dt><dd>fixed</dd>' -and (& $page 'advice') -match '<strong>Do not:</strong> that') 'what cannot change, and the advice, are shown'
Assert-True ((& $page 'method') -match 'href="https://claude.ai/artifact/abc"') 'the source Artifact is linked'
$snap.source.artifact = 'javascript:alert(1)'
Assert-True ((& $page 'method') -notmatch 'javascript:') 'a source that is not an Artifact link is not linked'
$badSnap = Format-SessionStartPageHtml -Model $ssModel -SnapshotError 'it is not valid JSON'
Assert-True ($badSnap -match 'session-start-snapshot.json could not be read: it is not valid JSON') 'an unreadable snapshot is a warning'

Write-Host '-- the Artifacts link check' -ForegroundColor Cyan
Assert-True (Test-ArtifactUrl 'https://claude.ai/artifact/TzrnhFefotMqYp6oWXYp5y') 'a claude.ai/artifact link is one'
Assert-True (Test-ArtifactUrl 'https://claude.ai/code/artifact/7d2fa536-ace6-412a-8977-60a4ddc4b6be') 'and so is a claude.ai/code/artifact link'
Assert-True (-not (Test-ArtifactUrl 'javascript:alert(1)')) 'a script url is not'
Assert-True (-not (Test-ArtifactUrl 'http://claude.ai/artifact/abc')) 'nor plain http'
Assert-True (-not (Test-ArtifactUrl 'https://claude.ai.evil.example/artifact/abc')) 'nor another host'
Assert-True (-not (Test-ArtifactUrl 'https://claude.ai/artifact/abc"><script>')) 'nor a link that breaks out of its attribute'
Assert-True (-not (Test-ArtifactUrl '')) 'nor an empty one'
Assert-True (-not (Test-ArtifactUrl "https://claude.ai/artifact/abc`n")) 'nor one with a trailing newline'

Write-Host '-- the Artifacts model' -ForegroundColor Cyan
$reg = '{ "recordedFrom": { "date": "2026-10-18", "method": "transcripts" }, "artifacts": [ { "title": "Old", "url": "https://claude.ai/artifact/aaa", "kind": "page", "created": "2026-09-01", "updated": "2026-09-02", "about": "first" }, { "title": "New <b>", "url": "https://claude.ai/code/artifact/0f1e-2a", "kind": "document", "created": "2026-10-07", "updated": "2026-10-07" }, { "title": "Bad", "url": "javascript:alert(1)", "kind": "page", "created": "2026-09-15" } ] }' | ConvertFrom-Json
$am = ConvertFrom-ArtifactRegister -Register $reg
Assert-Equal 'New <b>,Bad,Old' ((@($am.Artifacts) | ForEach-Object { $_.Title }) -join ',') 'newest first'
Assert-Equal 'False' (@($am.Artifacts | Where-Object { $_.Title -eq 'Bad' })[0].Linked) 'a url that is not an Artifact link is kept, unlinked'
Assert-Equal '2026-10-18' $am.Date 'the recording date is read'
$empty = ConvertFrom-ArtifactRegister -Register $null
Assert-Equal 0 @($empty.Artifacts).Count 'a missing register is an empty list'

Write-Host '-- the Artifacts page' -ForegroundColor Cyan
$ap = Format-ArtifactsPageHtml -Model $am
Assert-True ($ap -match '<h1>Artifacts</h1>' -and $ap -match '<span aria-current="page">Artifacts</span>') 'the page is named Artifacts, in the h1 and the trail'
Assert-True ($ap -match 'Artifacts</div><div class="v num">3<') 'the tile counts every recorded Artifact'
Assert-True ($ap -match '<a class="dp-link" href="https://claude.ai/artifact/aaa" target="_blank" rel="noopener noreferrer">Old</a>') 'a recorded Artifact links to claude.ai, in a new tab'
Assert-True ($ap -match 'New &lt;b&gt;</a>' -and $ap -notmatch 'New <b>') 'the title is escaped'
Assert-True ($ap -notmatch 'href="javascript' -and $ap -match '<td class="dp-left">Bad</td>') 'an unlinked row shows its title without an href'
Assert-True ($ap -match 'msg msg--warn" role="status">Not a claude.ai Artifact link.*<code>Bad</code>') 'and is named in a warning'
Assert-True ($ap -match '<p class="note">first</p>') 'the one-line description sits under the title'
Assert-True ($ap -match '<dt>Recorded</dt><dd>2026-10-18</dd>') 'where the list comes from is stated'
$apFailed = Format-ArtifactsPageHtml -Model $empty -ReadError 'it is not valid JSON'
Assert-True ($apFailed -match 'could not be read: it is not valid JSON' -and $apFailed -match 'No Artifact is recorded') 'an unreadable register is a warning and an empty table'

Write-Host '-- the register in the tree' -ForegroundColor Cyan
$treeReg = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\dashboard\artifacts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$treeModel = ConvertFrom-ArtifactRegister -Register $treeReg
Assert-True (@($treeModel.Artifacts).Count -gt 0) 'the register parses and records at least one Artifact'
Assert-Equal 0 @($treeModel.Artifacts | Where-Object { -not $_.Linked }).Count 'every recorded url is a claude.ai Artifact link'
Assert-Equal 0 @($treeModel.Artifacts | Where-Object { $_.Created -notmatch '^\d{4}-\d{2}-\d{2}$' }).Count 'every row has an ISO creation date'

Write-Host '-- the harvest: urls read from a result (#3112)' -ForegroundColor Cyan
. (Join-Path $RepoRoot 'scripts\lib\artifact-harvest-lib.ps1')
Assert-Equal 'https://claude.ai/artifact/Abc123' (Get-ArtifactPublishUrl 'Published C:\x\index.html at https://claude.ai/artifact/Abc123 (Version 2, version id 1-a)') 'a publish names its Artifact after "at"'
Assert-Equal 'https://claude.ai/artifact/New1' (Get-ArtifactPublishUrl 'Created a new Artifact at https://claude.ai/artifact/New1 (version 1) from the Artifact type https://claude.ai/artifact/Type9 (release 2)') 'a typed create names the new Artifact, not its type'
Assert-Equal '' (Get-ArtifactPublishUrl 'The publish was refused: the file is too large.') 'a refused publish names none'
Assert-Equal 'https://claude.ai/code/artifact/7d2f-ac' (Get-ArtifactPublishUrl '{"frame":{"url":"https://claude.ai/code/artifact/7d2f-ac"}}' -Docs) 'a Docs create names its code/artifact link'
Assert-Equal 'https://claude.ai/artifact/Abc' (Get-ArtifactUrlKey 'https://claude.ai/artifact/Abc?sk=Zx_1') 'a share link is recorded without its key'
Assert-True (Test-PathUnderRoot 'c:\users\me\repo\sub' @('C:/Users/me/repo')) 'a session in a subfolder is the repo''s, whatever the case or slash'
Assert-True (-not (Test-PathUnderRoot 'C:\Users\me\repo-other' @('C:\Users\me\repo'))) 'a sibling with a longer name is not'

Write-Host '-- the harvest: one transcript' -ForegroundColor Cyan
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('harvest-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$repo = 'C:\\Users\\me\\repo'
$lines = @(
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-01T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Artifact","input":{"file_path":"C:\\nowhere\\atlas.html","title":"Atlas","description":"first"}}]}}',
    '{"type":"user","cwd":"{REPO}","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"Published C:\\nowhere\\atlas.html at https://claude.ai/artifact/Atl1 (Version 1)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-02T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Artifact","input":{"action":"read","url":"https://claude.ai/artifact/Read1"}}]}}',
    '{"type":"user","cwd":"{REPO}","message":{"content":[{"type":"tool_result","tool_use_id":"t2","content":"Read the Artifact at https://claude.ai/artifact/Read1"}]}}',
    '{"type":"assistant","cwd":"C:\\Users\\me\\elsewhere","timestamp":"2026-10-03T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t3","name":"Artifact","input":{"file_path":"C:\\nowhere\\x.html"}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t3","content":"Published C:\\nowhere\\x.html at https://claude.ai/artifact/Other1 (Version 1)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-04T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t4","name":"mcp__claude_ai_Claude_Docs__batch","input":{"container":{"kind":"project","create":{"name":"Handout"}}}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t4","content":[{"type":"text","text":"{\"frame\":{\"url\":\"https://claude.ai/code/artifact/0f1e-2a\"}}"}]}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-05T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t5","name":"Artifact","input":{"url":"https://claude.ai/artifact/Atl1?sk=k","file_path":"C:\\nowhere\\atlas.html","asset":true}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t5","content":"Uploaded the asset at https://claude.ai/artifact/Atl1"}]}}',
    '{"type":"assistant","cwd":"{REPO}","timestamp":"2026-10-06T07:00:00Z","message":{"content":[{"type":"tool_use","id":"t6","name":"Artifact","input":{"url":"https://claude.ai/artifact/Atl1?sk=k","file_path":"C:\\nowhere\\atlas.html","description":"second"}}]}}',
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t6","content":"Published C:\\nowhere\\atlas.html at https://claude.ai/artifact/Atl1 (Version 2)"}]}}',
    '{"type":"assistant","cwd":"{REPO}","message":{"content":[{"type":"tool_use","id":"t7","name":"Artif'
) | ForEach-Object { $_.Replace('{REPO}', $repo) }
$tx = Join-Path $tmp 'session.jsonl'
[IO.File]::WriteAllText($tx, ($lines -join "`n"))
$pubs = @(Read-ArtifactPublishes -Path $tx -Root @('C:\Users\me\repo'))
Assert-Equal 'Atl1,0f1e-2a,Atl1' (($pubs | ForEach-Object { ($_.Url -split '/')[-1] }) -join ',') 'publishes and a Docs create are found; a read, an asset upload, another repo and a cut-off last line are not'
Assert-Equal 'Atlas|page|2026-10-01' ($pubs[0].Title + '|' + $pubs[0].Kind + '|' + $pubs[0].Date) 'a publish carries its title, kind and day'
Assert-Equal 'Handout|document' ($pubs[1].Title + '|' + $pubs[1].Kind) 'a Docs create is a document named after the doc'
Assert-Equal 'atlas' $pubs[2].Title 'a publish without a title, its page gone, is named after its file'
$none = @(Read-ArtifactPublishes -Path $tx -Root @('C:\Users\me\unrelated'))
Assert-Equal 0 $none.Count 'a transcript from another repo yields nothing, not one empty entry'
Remove-Item -LiteralPath $tmp -Recurse -Force

Write-Host '-- the harvest: the merge only adds' -ForegroundColor Cyan
$held = '{ "artifacts": [ { "title": "Fixed by hand", "url": "https://claude.ai/artifact/Atl1", "kind": "slides", "created": "2026-10-02", "updated": "2026-10-03", "about": "kept" } ] }' | ConvertFrom-Json
$mg = Merge-ArtifactRegister -Register $held -Found $pubs
Assert-Equal 2 @($mg.Artifacts).Count 'one row added, the held one not duplicated by its share link'
$a1 = @($mg.Artifacts)[0]
Assert-Equal 'Fixed by hand|slides|kept' ($a1.title + '|' + $a1.kind + '|' + $a1.about) 'a held row keeps its title, kind and about'
Assert-Equal '2026-10-01..2026-10-06' ($a1.created + '..' + $a1.updated) 'and only has its dates widened'
Assert-Equal 'https://claude.ai/artifact/Atl1' (@($mg.Widened) -join ',') 'the widened row is reported'
Assert-Equal 'https://claude.ai/code/artifact/0f1e-2a' (@($mg.Added) -join ',') 'and so is the new one'
$fresh = Merge-ArtifactRegister -Register $null -Found $pubs
$f1 = @($fresh.Artifacts | Where-Object { $_.url -like '*Atl1' })[0]
Assert-Equal 'Atlas|second|2026-10-01|2026-10-06' ($f1.title + '|' + $f1.about + '|' + $f1.created + '|' + $f1.updated) 'a new row: title from the first publish, about from the last, dates spanning both'
$again = Merge-ArtifactRegister -Register ((ConvertTo-ArtifactRegisterJson -About 'a' -Date 'd' -Method 'm' -Artifacts $fresh.Artifacts) | ConvertFrom-Json) -Found $pubs
Assert-Equal 0 (@($again.Added).Count + @($again.Widened).Count) 'a second harvest of the same transcripts changes nothing'

Write-Host '-- the harvest: the file it writes' -ForegroundColor Cyan
$json = ConvertTo-ArtifactRegisterJson -About "it's" -Date '2026-10-18' -Method 'm' -Artifacts @([ordered]@{ title = 'A "q" \ b'; url = 'https://claude.ai/artifact/X'; kind = 'page'; created = '2026-10-01'; updated = '2026-10-01'; about = "line`tend" })
$back = $json | ConvertFrom-Json
Assert-Equal 'A "q" \ b' $back.artifacts[0].title 'quotes and backslashes survive the round trip'
Assert-Equal "line`tend" $back.artifacts[0].about 'and so does a control character'
Assert-True ($json.Contains("`"about`": `"it's`"")) 'an apostrophe is written as itself'
Assert-True ($json.StartsWith("{`n  `"about`"") -and $json.EndsWith("`n  ]`n}`n")) 'two-space indented, LF, ending in a newline'
Assert-Equal 0 @((ConvertTo-ArtifactRegisterJson -About 'a' -Date 'd' -Method 'm' -Artifacts @()) | ConvertFrom-Json).artifacts.Count 'an empty register is still valid JSON'

Write-Host '-- the release-notes page, as the dev server serves it (#3108)' -ForegroundColor Cyan
# The real template, so a change to its shape that would leave the served copy undressed goes red here.
$tpl = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\release-notes-page-template.html'))
$rn = Format-ReleaseNotesDevPage -Html $tpl
Assert-True ($rn -ne $tpl) 'the template has the shape the dressing needs'
Assert-True ($rn.Contains((Format-RepoHubBanner)) -and $rn.IndexOf('id="hub-banner"') -lt $rn.IndexOf('class="breadcrumbs-bar"') -and ([regex]::Matches($rn, 'id="hub-banner"')).Count -eq 1) 'the release notes carry the general banner once, above the bar and any site header (#3297; owner, October 24, 2026)'
Assert-True ($rn -match '<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">') 'it takes the theme key and the lilac default every other page of the general server uses (#3162)'
Set-GeneralPagesThemeDefault 'teal'
Assert-True ((Format-ReleaseNotesDevPage -Html $tpl) -match 'data-theme-default="teal"' -and (Format-GeneralPageHtml -Title 't' -Lead '' -Body '') -match 'data-theme-default="teal"') 'a repo''s DefaultTheme reaches the release notes and every general page (#3390)'
Set-GeneralPagesThemeDefault 'x"y'
Assert-True ((Format-GeneralPageHtml -Title 't' -Lead '' -Body '') -match 'data-theme-default="x&quot;y"') 'and is escaped there, whatever was handed in'
Set-GeneralPagesThemeDefault ''
Assert-True ((Format-ReleaseNotesDevPage -Html $tpl -ThemeKey 'k"x' -HubHref '/') -match 'data-theme-key="k&quot;x"' -and (Format-ReleaseNotesDevPage -Html $tpl -HubHref '/') -match '<li><a href="/">Home</a></li>') 'a caller may name the theme key and the hub crumb''s target, both escaped'
$tplStyleEnd = $rn.IndexOf('</style>')
$houseAt = $rn.IndexOf('<link rel="stylesheet" href="/house-style.css">')
Assert-True ($houseAt -gt $tplStyleEnd -and $tplStyleEnd -gt 0) 'the house stylesheet loads after the template''s own style, so the house body wins'
Assert-True ($rn.IndexOf('--panel: var(--paper-2)') -gt $houseAt) 'and the template''s tokens are pointed at house tokens after it'
Assert-True ($rn.IndexOf('.wrap { max-width: 1080px; display: grid;') -gt $houseAt -and $rn.Contains('header.masthead h1 { font-family: inherit; font-size: var(--text-h1);') -and $rn.Contains('footer.colophon { margin: 0; padding: 0; border: 0; color: var(--muted);')) 'and its column, h1 and colophon take the Stopwatch page''s measures (owner, October 25, 2026)'
Assert-True ($rn.IndexOf('<script src="/house-theme.js"></script>') -lt $rn.IndexOf('<body')) 'the theme script loads in the head'
$bodyAt = $rn.IndexOf('<body>')
$barAt = $rn.IndexOf('<div class="breadcrumbs-bar">')
Assert-True ($barAt -gt $bodyAt -and $rn.Substring($bodyAt + 6, $barAt - $bodyAt - 6).Trim() -eq (Format-RepoHubBanner).Trim()) 'the banner is the first thing in <body>, and with no repo named the breadcrumb bar comes straight after it'
Assert-True ($rn -match '<li><a href="/hub">Home</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true"><svg\ viewBox="0\ 0\ 24\ 24"><path\ fill="currentColor"\ fill-rule="evenodd"\ d="M9\.793\ 16\.707a1\ 1\ 0\ 0\ 1\ 0-1\.414L13\.086\ 12\ 9\.793\ 8\.707a1\ 1\ 0\ 0\ 1\ 1\.414-1\.414l4\ 4a1\ 1\ 0\ 0\ 1\ 0\ 1\.414l-4\ 4a1\ 1\ 0\ 0\ 1-1\.414\ 0"\ clip-rule="evenodd"/></svg></span><span aria-current="page">Release notes</span></li>') 'its trail runs from the hub, on /hub of the general server, to this page'
Assert-True ($rn.IndexOf('DKJTheme.settings(') -gt $rn.IndexOf('id="settings"') -and $rn.IndexOf('DKJTheme.settings(') -lt $rn.LastIndexOf('</body>')) 'the settings button is mounted before </body>'
Assert-True ($rn.Contains('<div class="wrap">') -and $rn.Contains('@@PAGE_MAIN@@') -and $rn.Contains('@@PAGE_STYLE@@')) 'the template''s own content is left alone'
# The settings panel's width reaches main and .container only, and the template's column is neither, so the
# template answers data-width itself -- every width the theme script offers but fluid, which is its own column.
Assert-True ($tpl.Contains(':root[data-width="phone"] .wrap {') -and $tpl.Contains(':root[data-width="full"] .wrap { max-width: none; }')) 'the template''s column follows the page-width setting'
Assert-Equal '<html>fixture</html>' (Format-ReleaseNotesDevPage -Html '<html>fixture</html>') 'a page without the template''s shape is served as it came'
$rnNamed = Format-ReleaseNotesDevPage -Html $tpl -RepoName 'Org/repo'
Assert-True ($rnNamed -match 'class="site-header"' -and $rnNamed -notmatch 'class="eyebrow"' -and $rnNamed -match '<header class="masthead">\s*@@PAGE_BACK@@\s*@@PAGE_MASTHEAD@@\s*<h1>@@PAGE_HEADING@@</h1>') 'under a site header the masthead opens with its h1, with no eyebrow (#3423)'
Assert-True ($rn -match '<span class="eyebrow">@@PAGE_TITLE@@</span>' -and $tpl -match '<span class="eyebrow">@@PAGE_TITLE@@</span>') 'and with no site header the eyebrow stays, as it does in the template the Worker serves'

Write-Host '-- a release''s own page, as the dev server serves it (owner, October 25, 2026)' -ForegroundColor Cyan
$relPage = $tpl.Replace('@@PAGE_BACK@@', '<a class="back" href="/release-notes">&larr; All releases</a>').Replace('@@PAGE_HEADING@@', 'Version 2.39')
$rel = Format-ReleaseNotesDevPage -Html $relPage -Release
Assert-True ($rel -match '<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/release-notes">Release notes</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">Version 2\.39</span></li>') 'its trail runs Home > Release notes > the version read off its own h1, with Release notes a link'
Assert-True ($rel -notmatch 'class="back"') 'and its own way back is taken out, because that crumb already is one'
Assert-True ($rn.IndexOf('.cards > .card { padding: var(--spacing-3) var(--spacing-4); margin-top: 0; }') -gt $rn.IndexOf('/house-style.css')) 'the release cards take a tighter padding than the house .card, after the house file so it holds (owner, October 25, 2026)'
Assert-True ((Format-ReleaseNotesDevPage -Html ($tpl.Replace('@@PAGE_HEADING@@', '<b>x</b>')) -Release) -match 'aria-current="page">Release</span>') 'an h1 not of the builder''s own shape never reaches the crumb'
Assert-True ((Format-ReleaseNotesDevPage -Html $relPage) -match 'class="back"') 'while the index keeps whatever the page carries'
$rnIdx = 'C:\r\dkj-policy\releases\page\release-notes.html'
$q = Resolve-ReleaseNotesRequest -Path '/release-notes' -IndexFile $rnIdx
Assert-True ($q.File -eq $rnIdx -and $q.Version -eq '') '/release-notes is the index'
$q = Resolve-ReleaseNotesRequest -Path '/release-notes/v2.39.0/' -IndexFile $rnIdx
Assert-True ($q.File -eq 'C:\r\dkj-policy\releases\page\release-notes\v2.39.0.html' -and $q.Version -eq '2.39.0') 'a release''s address is its page in the folder named after the index, a trailing slash ignored'
Assert-Equal 'C:\r\dkj-policy\releases\page\release-notes\v2.39.0.html' (Resolve-ReleaseNotesRequest -Path '/release-notes/v2.39' -IndexFile $rnIdx).File 'and the version as the page shows it reaches the same page'
Assert-True ($null -eq (Resolve-ReleaseNotesRequest -Path '/release-notes/..\..\x' -IndexFile $rnIdx) -and $null -eq (Resolve-ReleaseNotesRequest -Path '/release-notesx' -IndexFile $rnIdx) -and $null -eq (Resolve-ReleaseNotesRequest -Path '/issues' -IndexFile $rnIdx)) 'anything but a version is not the release notes'' to answer, so no request names a file outside that folder'
$rnFix = Join-Path ([System.IO.Path]::GetTempPath()) ('rn-built-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $rnFix | Out-Null
    $rnFixIdx = Join-Path $rnFix 'release-notes.html'
    [System.IO.File]::WriteAllText($rnFixIdx, 'x')
    Assert-True ($null -eq (Get-ReleaseNotesBuiltTime -IndexFile $rnFixIdx)) 'an index built before releases had pages of their own counts as not built, so it is rebuilt'
    New-Item -ItemType Directory -Force -Path (Join-Path $rnFix 'release-notes') | Out-Null
    Assert-True ($null -ne (Get-ReleaseNotesBuiltTime -IndexFile $rnFixIdx)) 'and one with its release folder beside it is built'
    Assert-True ($null -eq (Get-ReleaseNotesBuiltTime -IndexFile (Join-Path $rnFix 'absent.html'))) 'and no index is not built either'
} finally { Remove-Item -Recurse -Force -LiteralPath $rnFix -ErrorAction SilentlyContinue }

Write-Host '-- the Issues model' -ForegroundColor Cyan
$now = [DateTime]::new(2026, 10, 18, 12, 0, 0, [DateTimeKind]::Utc)
$isOpen = '[ { "number": 7, "title": "Free <b>", "url": "https://github.com/Org/some-repo/issues/7", "state": "OPEN", "labels": [ { "name": "bug" }, { "name": "prio-3" } ], "assignees": [], "createdAt": "2026-10-16T12:00:00Z", "closedAt": null },
  { "number": 8, "title": "Parked", "url": "javascript:alert(1)", "state": "OPEN", "labels": [ { "name": "feature" }, { "name": "awaiting-decision-dev" } ], "assignees": [ { "login": "a" } ], "createdAt": "2026-10-10T12:00:00Z", "closedAt": null },
  { "number": 9, "title": "Claimed", "state": "OPEN", "labels": [ { "name": "bug-inbound" }, { "name": "bug" }, { "name": "prio-3" } ], "assignees": [ { "login": "b" } ], "createdAt": "2026-08-01T12:00:00Z", "closedAt": null } ]' | ConvertFrom-Json
$isRecent = '[ { "number": 1, "title": "Done", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [ { "name": "bug" }, { "name": "prio-2" } ], "assignees": [], "createdAt": "2026-10-17T00:00:00Z", "closedAt": "2026-10-17T10:00:00Z" },
  { "number": 1, "title": "Done", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [ { "name": "bug" }, { "name": "prio-2" } ], "assignees": [], "createdAt": "2026-10-17T00:00:00Z", "closedAt": "2026-10-17T10:00:00Z" },
  { "number": 2, "title": "Old one closed", "state": "CLOSED", "stateReason": "NOT_PLANNED", "labels": [], "assignees": [], "createdAt": "2026-09-01T00:00:00Z", "closedAt": "2026-10-01T00:00:00Z" },
  { "number": 3, "title": "Closed before the window", "state": "CLOSED", "stateReason": "COMPLETED", "labels": [], "assignees": [], "createdAt": "2026-09-01T00:00:00Z", "closedAt": "2026-09-02T00:00:00Z" },
  { "number": 7, "title": "Free <b>", "url": "https://github.com/Org/some-repo/issues/7", "state": "OPEN", "labels": [ { "name": "bug" }, { "name": "prio-3" } ], "assignees": [], "createdAt": "2026-10-16T12:00:00Z", "closedAt": null } ]' | ConvertFrom-Json
$im = ConvertFrom-IssueList -Open @($isOpen | ForEach-Object { $_ }) -Recent @($isRecent | ForEach-Object { $_ }) -Now $now -Days 28
Assert-Equal '7,9,8' ((@($im.Open) | ForEach-Object { $_.Number }) -join ',') 'open issues, highest priority first, then by number'
Assert-Equal 'Free,Claimed,Parked' ((@($im.Open) | ForEach-Object { $_.Board }) -join ',') 'a parking label wins over an assignee; an assignee makes it claimed'
Assert-Equal 'bug-inbound' (@($im.Open)[1].Kind) 'an inbound label names the kind before bug'
Assert-Equal 3 $im.Opened 'opened in the window: #7, #8 and #1, #1 counted once'
Assert-Equal 2 $im.Closed 'closed in the window: #1 and #2, not #3'
Assert-Equal 1 $im.Matrix['3'].Free 'the matrix counts the free prio-3 issue...'
Assert-Equal 1 $im.Matrix['3'].Claimed '...and the claimed one'
Assert-Equal 1 $im.Matrix['0'].Parked 'an issue without a priority lands in row 0'
Assert-Equal 4 @($im.Weeks).Count 'a 28-day window is four weeks'
Assert-Equal 2 @($im.Weeks)[-1].Opened 'the last week holds the openings of #7 and #1'
Assert-Equal 1 @($im.Weeks)[-1].Closed 'and the one close of that week'
Assert-Equal 365.0 ([double]$im.MedianCloseHours) 'the median of 10 h and 720 h is their mean'
Assert-Equal 'completed,not planned' ((@($im.ClosedBy.Reason) | ForEach-Object { $_.Name }) -join ',') 'closed-as reasons, lowercase'

Write-Host '-- the Issues page' -ForegroundColor Cyan
$ip = Format-IssuesPageHtml -Model $im -GeneratedAt '2026-10-18 14:00:00' -Seconds 3.2
Assert-True ($ip -match '<h1>Issues</h1>' -and $ip -match '<span aria-current="page">Issues</span>') 'the page is named Issues, in the h1 and the trail'
Assert-True ($ip -match 'Open now</div><div class="v num">3<') 'the tile counts the open issues'
Assert-True ($ip.Contains('Free &lt;b&gt;') -and -not $ip.Contains('Free <b>')) 'an issue title is escaped'
Assert-True ($ip.Contains('href="https://github.com/Org/some-repo/issues/7"')) 'an open issue links to the url gh gave it, not to a repo this lib knows'
Assert-True ($ip -notmatch 'href="javascript' -and $ip.Contains('#8 Parked')) 'an issue whose url is not a GitHub issue link is shown without an href'
Assert-True ($ip -notmatch 'dkj-claude-plugins') 'and nothing of this repo is built into the page'
Assert-True ($ip -match '<div class="grid__head"><h2>Closed</h2>' -and ([regex]::Matches($ip, '<h3 class="card__title">')).Count -eq 3 -and $ip -match '<section class="card grid__full">\r?\n<div class="card__head"><h3 class="card__title">Closed as</h3>') 'the three closed breakdowns stand under one h2, each card titled with an h3 (#3175)'
Assert-True ($ip -notmatch '<h2 class="card' -and ([regex]::Matches($ip, '<h2>')).Count -eq ([regex]::Matches($ip, '<div class="grid__head"><h2>')).Count) 'every h2 on the page stands in a grid__head, above its cards'
Assert-True ((Format-IssuesPageHtml -Model $im -RepoName 'Org/some<repo>') -match 'The GitHub issues of <code>Org/some&lt;repo&gt;</code>' -and (Format-IssuesPageHtml -Model $im -RepoName 'Org/x') -match '<title>Org/x -- Issues</title>') 'the repo''s name, escaped, is in the lead and the title'
Assert-Equal '' (ConvertTo-IssueRow -Issue ('{ "number": 1, "title": "t", "url": "https://github.com/a/b/issues/1x" }' | ConvertFrom-Json)).Url 'a url with anything after the number is not kept'
Assert-Equal 'https://github.com/a/b/issues/1' (ConvertTo-IssueRow -Issue ('{ "number": 1, "title": "t", "url": "https://github.com/a/b/issues/1" }' | ConvertFrom-Json)).Url 'a GitHub issue url is kept'
Assert-Equal '' (ConvertTo-IssueRow -Issue ('{ "number": 1, "title": "t" }' | ConvertFrom-Json)).Url 'an issue without a url has none'
Assert-True ($ip.Contains('/refresh?page=issues')) 'the footer offers a fresh read'
$ipNone = Format-IssuesPageHtml -Model (ConvertFrom-IssueList -Now $now)
Assert-True ($ipNone.Contains('No open issue')) 'no open issue says so instead of an empty table'
$ipFailed = Format-IssuesPageHtml -Model $null -ReadError 'gh issue list exited 1'
Assert-True ($ipFailed.Contains('msg--warn') -and $ipFailed.Contains('gh issue list exited 1')) 'a failed read is a warning on the page'
Write-Host '-- the repo name and the always-on lib, as the general server finds them (#3119)' -ForegroundColor Cyan
Assert-Equal 'Foo/bar' (ConvertFrom-GitRemoteUrl 'https://github.com/Foo/bar.git') 'an https remote reads as owner/name'
Assert-Equal 'Foo/bar' (ConvertFrom-GitRemoteUrl 'git@github.com:Foo/bar.git') 'and so does an scp-style ssh remote'
Assert-Equal 'Foo/bar.js' (ConvertFrom-GitRemoteUrl 'ssh://git@github.com/Foo/bar.js') 'a dot in the name stays, and ssh:// is read'
Assert-Equal 'Foo/bar' (ConvertFrom-GitRemoteUrl 'https://user@github.com/Foo/bar/') 'a user and a trailing slash are dropped'
Assert-Equal '' (ConvertFrom-GitRemoteUrl 'https://gitlab.com/Foo/bar.git') 'a host that is not github.com is no repo name'
Assert-Equal '' (ConvertFrom-GitRemoteUrl 'https://github.com/Foo/bar baz') 'nor is a name with a space'
Assert-Equal '' (ConvertFrom-GitRemoteUrl 'https://github.com/Foo/..') 'nor a dot-dot'
Assert-Equal '' (ConvertFrom-GitRemoteUrl '') 'nor is no remote'
$cands = @(Get-AlwaysOnBudgetLibCandidates -RepoRoot 'C:\r\repo' -PluginRoot 'C:\r\mkt\plugins\dkj-policy')
Assert-Equal 'C:\r\repo\scripts\lib\always-on-budget-lib.ps1' $cands[0] 'the repo''s own copy is tried first'
Assert-Equal 'C:\r\mkt\plugins\dkj-policy\scripts\lib\always-on-budget-lib.ps1' $cands[1] 'then the dkj-policy plugin the server runs from (#3198)'
Assert-Equal 2 $cands.Count 'and nothing else: the server is dkj-policy''s, so no other version is searched for'
$cands = @(Get-DkjPolicyScriptCandidates -RepoRoot 'C:\r\repo' -PluginRoot 'C:\cache\mkt\dkj-policy\5.26.0\' -RelativePath 'scripts\release\build-release-notes-page.ps1')
Assert-Equal 'C:\r\repo\scripts\release\build-release-notes-page.ps1' $cands[0] 'the release-notes builder is looked for the same way: the repo''s own copy first (#3189)'
Assert-Equal 'C:\cache\mkt\dkj-policy\5.26.0\scripts\release\build-release-notes-page.ps1' $cands[1] 'then in the cached dkj-policy version the server runs from, the same release as the server'
Write-Host '-- when /release-notes builds its page first (#3189)' -ForegroundColor Cyan
$built = [datetime]'2026-10-19 10:00'
Assert-Equal 'absent' (Get-ReleaseNotesPageNeed -PageTime $null -NewestInputTime $built) 'no page is built'
Assert-Equal 'absent' (Get-ReleaseNotesPageNeed -PageTime $null -NewestInputTime $null) 'even where there is nothing to build it from: the build says why'
Assert-Equal 'stale' (Get-ReleaseNotesPageNeed -PageTime $built -NewestInputTime $built.AddMinutes(1)) 'a page older than a release document is rebuilt'
Assert-Equal '' (Get-ReleaseNotesPageNeed -PageTime $built -NewestInputTime $built) 'one as new as the newest document is served as it is'
Assert-Equal '' (Get-ReleaseNotesPageNeed -PageTime $built -NewestInputTime $null) 'and so is a page with no document beside it'


Write-Host '-- the Specialists model' -ForegroundColor Cyan
# The emoji and the em dash as code points: the script layer is ASCII.
$compass = [char]::ConvertFromUtf32(0x1F9ED)
$agentText = "---`nname: paula`nid: 09`ndescription: >`n  Project Planner -- tracks`n  deadlines.`ntools: Read`n---`n`nYou are **Paula $compass**, the Project Planner. Your playbook`nlives here.`n"
$sa = ConvertTo-SpecialistRow -Id '02-09' -Plugin 'dkj-subagents-alpha' -Form subagent -Text $agentText -ManualBytes 1000 -LensBytes $null -Enabled $true
Assert-Equal 'Paula' $sa.Name 'a subagent''s name comes from its "You are" line'
Assert-Equal $compass $sa.Emoji 'and its emoji beside it'
Assert-Equal 'Project Planner' $sa.Title 'and its title, without "the"'
Assert-Equal '09' $sa.Number 'the number is the id''s second half'
Assert-Equal ([Text.Encoding]::UTF8.GetByteCount('Project Planner -- tracks deadlines.')) $sa.ListingBytes 'the listing is the folded description, its lines joined'
Assert-Equal ([Text.Encoding]::UTF8.GetByteCount("`nYou are **Paula $compass**, the Project Planner. Your playbook`nlives here.`n")) $sa.DefinitionBytes 'the definition is the file without its frontmatter'
Assert-True ($null -eq $sa.LensBytes) 'no lens is $null, not 0'
Assert-Equal ($sa.ListingBytes + $sa.DefinitionBytes + 1000) $sa.TotalBytes 'the full read sums the parts that exist'
$personaText = "---`nid: 01`ngroup: 01`n---`n`n# Chris $compass " + [char]0x2014 + " the Chief of Staff (*Chief of Staff Chris*)`n`nBody.`n"
$pa = ConvertTo-SpecialistRow -Id '01-01' -Plugin 'dkj-subagents-alpha' -Form persona -Text $personaText -Enabled $true
Assert-Equal 'Chris|Chief of Staff|0' ($pa.Name + '|' + $pa.Title + '|' + $pa.ListingBytes) 'a persona''s name and title come from its h1, and it has no listing'
Assert-True $pa.AlwaysOn 'the orchestrator''s persona is always-on'
$empty = ConvertTo-SpecialistRow -Id '02-09' -Plugin 'x' -Form subagent -Text "---`n---`nYou are **Ann**, the Tester. Body`n"
Assert-Equal 'Ann|0' ($empty.Name + '|' + $empty.ListingBytes) 'an empty frontmatter block is cut cleanly, with no listing'
Assert-Equal '07-77' (ConvertTo-SpecialistRow -Id '07-77' -Plugin 'x' -Form subagent -Text 'no shape').Name 'a file of no known shape is named by its id'

Write-Host '-- the Specialists overview: one card per plugin, each linking its own page (#3550)' -ForegroundColor Cyan
$evil = ConvertTo-SpecialistRow -Id '06-99' -Plugin 'dkj-subagents-ecomm' -Form subagent -Text "---`ndescription: <b>x</b>`n---`nYou are **Eve <i>**, the Bad <b>. Body`n" -ManualBytes 99999
$sp = Format-SpecialistsPageHtml -Rows @($sa, $pa, $evil) -CharsPerToken 3.12
Assert-True ($sp -match '<h1>Specialists</h1>' -and $sp -match '<span aria-current="page">Specialists</span>') 'the page is named Specialists, in the h1 and the trail'
Assert-True ($sp -notmatch 'href="/plugins') 'its trail is Home > Specialists: the product has no Plugins page, so the page sits under the product home (#3540)'
Assert-True (-not $sp.Contains('class="tiles"') -and -not $sp.Contains('class="lead"') -and -not $sp.Contains('grid__head"><h2>Plugins')) 'the overview opens on its cards: no tiles, no lead and no heading over the grid (the owner, #3550)'
Assert-True (-not $sp.Contains('id="when"')) 'and the column explanation is left to the plugin pages, where the table is'
Assert-True ($sp.Contains('<section class="card card--link sp-card" id="plugin-alpha">') -and $sp.Contains('href="/specialists/alpha"') -and $sp.Contains('href="/specialists/ecomm"')) 'each plugin is a link card to its own page'
Assert-Equal 2 ([regex]::Matches($sp, '<h2 class="sp-card-title">')).Count 'one card per plugin, its label an h2'
Assert-True ($sp.IndexOf('id="plugin-alpha"') -lt $sp.IndexOf('id="plugin-ecomm"')) 'the core team''s card comes first, even where an add-on''s specialist reads larger'
Assert-True ($sp.Contains('<h2 class="sp-card-title">alpha</h2><span class="menu-item__sub">core team &middot; enabled here &middot; 2 specialists &middot; listing ~')) 'a card says what the plugin is, whether it is on here and how many specialists it ships'
Assert-True ($sp.Contains('full read ~' + (Format-DevNumber ([Math]::Round(($sa.TotalBytes + $pa.TotalBytes) / 3.12))) + '</span>')) 'and sums its own full read'
Assert-True ($sp.Contains('card--link sp-card sp-card--off" id="plugin-ecomm"') -and $sp.Contains('add-on team &middot; off here &middot; 1 specialist &middot;')) 'a plugin not enabled here keeps its card, muted and marked off'
Assert-True (-not $sp.Contains('<strong>Paula') -and -not $sp.Contains('<table')) 'the specialists themselves are on the plugin''s page, not the overview'
$offOnly = ConvertTo-SpecialistRow -Id '07-01' -Plugin 'dkj-subagents-aaa' -Form subagent -Text 'x'
$onAddOn = ConvertTo-SpecialistRow -Id '07-02' -Plugin 'dkj-subagents-zzz' -Form subagent -Text 'x' -Enabled $true
$order = @(Get-SpecialistPlugins -Rows @($evil, $offOnly, $onAddOn, $sa) | ForEach-Object { $_.Short }) -join ','
Assert-Equal 'alpha,zzz,aaa,ecomm' $order 'the core team, then add-on teams enabled here, then the off ones by name'
Assert-True ($sp.Contains('3.12 characters per token')) 'the footer names the factor, so the estimate is labelled as one'
Assert-True ((Format-SpecialistsPageHtml -Rows @() -CharsPerToken 3.12).Contains('No specialist was found')) 'none found says so instead of an empty grid'
Assert-True ((Format-SpecialistsPageHtml -Rows @() -CharsPerToken 3.12 -ReadError 'x.md').Contains('msg--warn')) 'a failed read is a warning on the page'

Write-Host '-- a plugin''s own Specialists page (#3550)' -ForegroundColor Cyan
$al = Format-SpecialistsPageHtml -Rows @($sa, $pa, $evil) -CharsPerToken 3.12 -Plugin 'alpha'
Assert-True ($al -match '<h1>alpha</h1>' -and $al.Contains('<a href="/specialists">Specialists</a>') -and $al.Contains('<span aria-current="page">alpha</span>')) 'its trail is Home > Specialists > the plugin'
Assert-True ($al.Contains('<strong><a href="/specialists/alpha/paula">Paula') -and $al.Contains('<strong><a href="/specialists/alpha/chris">Chris') -and -not $al.Contains('>Eve')) 'it lists its own specialists and nobody else''s, each name a link to its own page (#3551)'
Assert-True ($al.IndexOf('/alpha/paula">Paula') -lt $al.IndexOf('/alpha/chris">Chris')) 'the table puts the largest full read first'
Assert-True (-not $al.Contains('class="tiles"') -and -not $al.Contains('class="lead"') -and -not $al.Contains('grid__head"><h2>The specialists')) 'the plugin page opens on its cards too: no tiles, no lead and no heading over them (the owner, October 27, 2026)'
Assert-True ($al.Contains('<code>dkj-subagents-alpha</code>') -and $al.Contains('core team')) 'it names the plugin in full'
Assert-True ($al.Contains('always-on</span>')) 'the orchestrator carries the always-on badge'
Assert-True ($al.Contains('~' + (Format-DevNumber ([Math]::Round(1000 / 3.12))) + '<')) 'tokens are the bytes at the given factor'
Assert-True (-not $al.Contains('Not enabled in')) 'an enabled plugin carries no off notice'
Assert-True ($al.Contains('id="when"') -and $al.IndexOf('</table>') -lt $al.IndexOf('id="when"')) 'the column explanation sits under the table it explains'
$ec = Format-SpecialistsPageHtml -Rows @($sa, $pa, $evil) -CharsPerToken 3.12 -Plugin 'ecomm'
Assert-True ($ec.Contains('Eve &lt;i&gt;') -and -not $ec.Contains('Eve <i>')) 'a name is escaped'
Assert-True ($ec.Contains('Not enabled in'))'an off plugin''s page says what being off means here'
Assert-True ($ec.Contains('style="width: 100%"')) 'the bar is drawn against the largest on the plugin''s own page'
Assert-True ($null -eq (Format-SpecialistsPageHtml -Rows @($sa) -CharsPerToken 3.12 -Plugin 'nope')) 'a plugin the tree does not ship is $null, which the server answers with a 404'
Assert-True ($null -eq (Format-SpecialistsPageHtml -Rows @($sa) -CharsPerToken 3.12 -Plugin 'ALPHA')) 'and the name is matched as written'
Assert-True ($al.Contains('<div class="grid-3 sp-grid-4" id="cards">') -and $al.IndexOf('id="cards"') -lt $al.IndexOf('<table')) 'the plugin page opens on one card per specialist, above the table (#3551)'
Assert-True ($al.Contains('.grid-3.sp-grid-4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }')) 'the specialist cards sit four to a row'
Assert-True ($al.Contains('<section class="card card--link sp-card" id="specialist-paula">') -and $al.Contains('<a class="menu-item" href="/specialists/alpha/chris">')) 'each card is the link to that specialist''s page'
Assert-True ($al.IndexOf('id="specialist-chris"') -lt $al.IndexOf('id="specialist-paula"')) 'the cards are in roster order, 01-01 before 02-09, where the table is by size'
Assert-True ($al.Contains('<h2 class="sp-card-title">Paula ' + $compass + '</h2><span class="menu-item__sub">#09 &middot; Project Planner &middot; subagent &middot; full read ~')) 'a card names the specialist, its number, title, form and full read'

Write-Host '-- a specialist''s own page (#3551)' -ForegroundColor Cyan
Assert-Equal 'paula|eve|07-77' ($sa.Slug + '|' + $evil.Slug + '|' + (ConvertTo-SpecialistRow -Id '07-77' -Plugin 'x' -Form subagent -Text 'no shape').Slug) 'the route segment is the name lowercased, or the id where the name is not a plain word'
$sa2 = ConvertTo-SpecialistRow -Id '02-09' -Plugin 'dkj-subagents-alpha' -Form subagent -Text $agentText -ManualBytes 1000 -LensBytes $null -Enabled $true `
    -DefinitionPath 'plugins/dkj-subagents/dkj-subagents-alpha/subagents/specialist-02-09-subagent.md' -ManualPath 'm.md' -LensPath 'l.md'
Assert-Equal 'm.md|' ($sa2.ManualPath + '|' + $sa2.LensPath) 'a path is kept only for a file that exists: no lens bytes, no lens path'
$pg = Format-SpecialistsPageHtml -Rows @($sa2, $pa, $evil) -CharsPerToken 3.12 -Plugin 'alpha' -Specialist 'paula'
Assert-True ($pg -match '<h1>Paula ' + $compass + '</h1>' -and $pg.Contains('<a href="/specialists">Specialists</a>') -and $pg.Contains('<a href="/specialists/alpha">alpha</a>')) 'its trail is Home > Specialists > the plugin > the specialist'
Assert-True ($pg -match 'Full read</div><div class="v num">~' -and $pg -match 'Lens</div><div class="v num">--<') 'its tiles are its own parts, a missing one a dash'
Assert-True ($pg.Contains('<dt>Number</dt><dd>#09') -and $pg.Contains('<dt>Title</dt><dd>Project Planner') -and $pg.Contains('<code>dkj-subagents-alpha</code>, the core team')) 'it says what the specialist is and which plugin ships it'
Assert-True ($pg.Contains('<code>plugins/dkj-subagents/dkj-subagents-alpha/subagents/specialist-02-09-subagent.md</code>') -and $pg.Contains('<dt>Lens</dt><dd><span class="note">none</span>')) 'it names where each file is, and none where there is none'
Assert-True ($pg.Contains('<p>Project Planner -- tracks deadlines.</p>') -and $pg.Contains('<details class="more"><summary>Show the definition</summary><pre class="sp-text">You are **Paula')) 'it shows the listing, and the definition folded'
$cp = Format-SpecialistsPageHtml -Rows @($sa, $pa) -CharsPerToken 3.12 -Plugin 'alpha' -Specialist 'chris'
Assert-True ($cp.Contains('Imported on every turn') -and $cp.Contains('A persona has none')) 'the orchestrator''s page says it is always loaded and has no listing'
$ep = Format-SpecialistsPageHtml -Rows @($sa, $pa, $evil) -CharsPerToken 3.12 -Plugin 'ecomm' -Specialist 'eve'
Assert-True ($ep.Contains('Eve &lt;i&gt;') -and -not $ep.Contains('<i>') -and $ep.Contains('&lt;b&gt;x&lt;/b&gt;') -and $ep.Contains('Its plugin is not enabled')) 'its name, listing and definition are escaped, and an off plugin says so'
Assert-True ($null -eq (Format-SpecialistsPageHtml -Rows @($sa, $pa) -CharsPerToken 3.12 -Plugin 'alpha' -Specialist 'eve')) 'a specialist the plugin does not ship is $null, a 404'
Assert-True ($null -eq (Format-SpecialistsPageHtml -Rows @($sa, $pa) -CharsPerToken 3.12 -Specialist 'paula')) 'and so is a specialist named without its plugin'
Write-Host '-- the DKJ repos on GitHub (#3231), a section of /connectors/dkj since #3549: what it shows' -ForegroundColor Cyan
$gql = '{"data":{"organization":{"repositories":{"nodes":[' +
    '{"name":"dkj-lifehub","nameWithOwner":"DKJ-Solutions/dkj-lifehub","url":"https://github.com/DKJ-Solutions/dkj-lifehub","description":"<b>life</b>","visibility":"PRIVATE","isArchived":false,"pushedAt":"2026-10-20T10:00:00Z","issues":{"totalCount":3},"pullRequests":{"totalCount":0}},' +
    '{"name":"old","nameWithOwner":"DKJ-Solutions/old","url":"https://github.com/DKJ-Solutions/old","description":null,"visibility":"PUBLIC","isArchived":true,"pushedAt":"2025-01-01T00:00:00Z","issues":{"totalCount":0},"pullRequests":{"totalCount":0}}]}}}}'
$q = ConvertFrom-DkjRepoQuery -Json $gql
Assert-True ($q.Repos.Count -eq 1 -and (@($q.Archived) -join ',') -eq 'DKJ-Solutions/old' -and $q.Repos[0].Issues -eq 3 -and $q.Repos[0].Visibility -eq 'private' -and -not $q.Error) 'the query answer reads into live repos, with the archived ones counted and left out'
Assert-True ((ConvertFrom-DkjRepoQuery -Json '').Error -and (ConvertFrom-DkjRepoQuery -Json 'nope').Error -and (ConvertFrom-DkjRepoQuery -Json '{"errors":[{"message":"bad"}]}').Error -match 'bad' -and (ConvertFrom-DkjRepoQuery -Json '{"data":{}}').Error) 'no answer, no JSON, an error answer or a wrong shape is an Error, never an empty organisation'
Assert-True ((Get-DkjRepoQuery) -notmatch '"') 'the query holds no double quote, which Windows PowerShell 5.1 would split on its way to gh'
$co = @(@{ Repo = 'DKJ-Solutions/dkj-lifehub'; Path = 'C:\x\dkj-lifehub'; Branch = 'main'; Dirty = 2 }, @{ Repo = 'DKJ-Solutions/unlisted'; Path = 'C:\x\unlisted'; Branch = 'dev'; Dirty = 0 })
$sec = Format-DkjReposSectionHtml -Query $q -Checkouts $co -Meta @{ GeneratedAt = '2026-10-20 12:00:00'; Seconds = 1.2 }
$page = $sec.Html
Assert-True ($page -match '<div class="dr-grid" id="repos">\s*<div class="grid__head"><h2>On GitHub</h2><p class="card__sub">[^<]+</p></div>\s*<section class="card dr-card">' -and $page -notmatch '<h1' -and $page -notmatch 'class="tiles"' -and $page -notmatch '<table') 'the repos are cards in a grid headed by an h2, as Connected repos and Issues head theirs, with no h1, no tiles and no table (#3549)'
Assert-True ($sec.Style -match '\.dr-grid \{' -and $sec.FooterNote -match '^On GitHub: read with one <code>gh api graphql</code> call[^<]*2026-10-20 12:00:00 in 1\.2s\.$' -and $sec.FooterNote -notmatch 'href=') 'it hands the page its style and a footer clause naming its source and time, with no refresh link of its own'
Assert-True ($page -match '<section class="card dr-card"><h3><a href="https://github.com/DKJ-Solutions/dkj-lifehub">dkj-lifehub</a></h3>[^\n]*data-copy="Set-Location[^\n]*</section>') 'a repo card is titled with an h3 under the section''s h2, and a checkout''s session command sits in its own repo''s card'
Assert-True ($page -match '&lt;b&gt;life&lt;/b&gt;' -and $page -notmatch '<b>life</b>') 'a repo description is escaped'
Assert-True ($page -match 'href="https://github.com/DKJ-Solutions/dkj-lifehub/issues">3</a>' -and $page -match '2 uncommitted') 'a repo row links its open issues and names its checkout state'
Assert-True ($page -match '>unlisted</a>' -and $page -match 'unlisted&#39;; claude') 'a checkout GitHub did not list still gets its card and its session'
Assert-True ($page.Contains('data-copy="Set-Location -LiteralPath &#39;C:\x\dkj-lifehub&#39;; claude"') -and $page -match 'execCommand\("copy"\)') 'each checkout has its command to copy, with the fallback the Simple Browser needs'
Assert-True ($page -match '1 archived repo is left out' -and $page -notmatch '>old</a>') 'an archived repo is counted, not listed'
$pageArch = (Format-DkjReposSectionHtml -Query $q -Checkouts @(@{ Repo = 'DKJ-Solutions/old'; Path = 'C:\x\old'; Branch = 'main'; Dirty = 0 }) -Meta @{ GeneratedAt = 'x' }).Html
Assert-True ($pageArch -match '>old</a>' -and $pageArch -match '<p class="dr-line">archived &middot; ' -and $pageArch -notmatch 'archived repo is left out') 'an archived repo checked out here is listed, marked archived, and not counted as left out'
$evil = @{ Repos = @(@{ Repo = 'DKJ-Solutions/x'; Name = 'x'; Url = 'javascript:alert(1)'; Description = ''; Visibility = 'public'; PushedAt = ''; Issues = 1; Pulls = 0 }); Archived = @(); Error = '' }
Assert-True ((Format-DkjReposSectionHtml -Query $evil -Checkouts @() -Meta @{ GeneratedAt = 'x' }).Html -notmatch 'javascript:' ) 'a link is built from owner/name, never from the url field'
$pageErr = (Format-DkjReposSectionHtml -Query (ConvertFrom-DkjRepoQuery -Json '') -Checkouts $co -Meta @{ GeneratedAt = 'x'; Seconds = $null }).Html
Assert-True ($pageErr -match 'msg--warn' -and $pageErr -match '>dkj-lifehub</a>' -and $pageErr.IndexOf('<h2>On GitHub</h2>') -lt $pageErr.IndexOf('msg--warn')) 'when GitHub cannot be read the section says so under its heading and still lists the checkouts'
Assert-True ((Format-DkjReposSectionHtml -Query $q -Checkouts @() -Meta @{ GeneratedAt = 'x' }).Html -match 'No DKJ-Solutions checkout was found') 'no checkout at all says so'
Write-Host '-- the DKJ group''s connector page holds the section (#3549)' -ForegroundColor Cyan
$cdk = @(@{ Repo = 'DKJ-Solutions/dkj-lifehub'; Status = 'bad'; Plugins = @(); Signals = @(); Present = $false; Git = $null })
$merged = Format-ConnectorDashboardHtml -Connectors $cdk -Meta @{ GeneratedAt = 'now' } -Group 'dkj' -SectionHtml $sec.Html -SectionStyle $sec.Style -SectionFooterNote $sec.FooterNote
$mO = $merged.IndexOf('id="overview"'); $mR = $merged.IndexOf('id="repos"'); $mI = $merged.IndexOf('id="issues"')
Assert-True ($mO -ge 0 -and $mO -lt $mR -and $mR -lt $mI) 'on /connectors/dkj the repos on GitHub sit between Connected repos and Issues'
Assert-True ($merged -match '<h1>DKJ repos</h1>' -and ([regex]::Matches($merged, '<h1')).Count -eq 1 -and $merged -match '\.dr-grid \{' -and $merged -match 'serve-connector-dashboard\.ps1</code>\. On GitHub: read with one') 'the page keeps its one h1, and takes the section''s style and footer clause'
Assert-True ($merged -match 'href="/refresh\?page=connectors/dkj"' -and $merged -notmatch 'page=dkj-repos') 'its one refresh link comes back to /connectors/dkj'
$plain = Format-ConnectorDashboardHtml -Connectors $cdk -Meta @{ GeneratedAt = 'now' } -SectionHtml $sec.Html -SectionStyle $sec.Style -SectionFooterNote $sec.FooterNote
Assert-True ($plain -notmatch 'id="repos"' -and $plain -notmatch 'dr-grid' -and $plain -notmatch 'On GitHub') 'the overview on /connectors ignores a section'
Write-Host '-- the Plugins page (#3482): plugin-versions -Json read into a model, and the page it draws' -ForegroundColor Cyan
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\plugins-page-lib.ps1')
Assert-True ((Get-HubIconSvg -Name 'plugins') -match '<svg') 'the Plugins card has an icon'
$pvJson = '{"Root":"C:\r","Consulted":"user and repo","Plugins":[' +
    '{"Id":"zeta@m","Name":"zeta","Marketplace":"m","InstVersion":"1.0.0","InstScope":"project","Code":"match","Verdict":"up to date","Action":"the clone advances only on: x","Description":"<i>z</i>"},' +
    '{"Id":"alpha@m","Name":"alpha","Marketplace":"m","InstVersion":"0.9.0","InstScope":"project","Code":"behind","Verdict":"the clone is <b>ahead</b>","Action":"claude plugin update alpha@m --scope project"},' +
    '{"Id":"beta@m","Name":"beta","Marketplace":"m","InstVersion":"1.0.0","Code":"match","InstallPathMissing":true,"Verdict":"up to date"},' +
    '{"Id":"gamma@m","Name":"gamma","Marketplace":"m","Code":"clone-behind","Verdict":"the clone is stale"}],' +
    '"Clones":[{"Marketplace":"m","Exists":true,"Head":"0123456789abcdef","HeadDate":"2026-10-25"}]}'
$pv = ConvertFrom-PluginVersionsJson -Text ("noise`n" + $pvJson)
Assert-True (-not $pv.Error -and $pv.Plugins.Count -eq 4 -and $pv.Clones.Count -eq 1 -and $pv.Consulted -eq 'user and repo') 'the last JSON line is the model, a stray line before it is harmless'
Assert-True ((ConvertFrom-PluginVersionsJson -Text '').Error -and (ConvertFrom-PluginVersionsJson -Text '{nope').Error -and (ConvertFrom-PluginVersionsJson -Text '').Plugins.Count -eq 0) 'no output or broken JSON is an Error and no plugins, never a throw'
Assert-Equal 'ok,ok,ok,error,error,warn,warn,warn' ((@('match', 'ver-match', 'unreleased', 'behind', 'not-installed', 'clone-behind', 'retired', 'indeterminate') | ForEach-Object { (Get-PluginRowStatus -Code $_).Level }) -join ',') 'each plugin-versions code is fine, an error or a warning'
Assert-Equal 'error' (Get-PluginRowStatus -Code 'match' -InstallPathMissing $true).Level 'an install folder gone from disk is an error whatever the version says'
$pp = Format-PluginsPageHtml -Model $pv -RepoName 'r'
Assert-True ($pp -match '<span aria-current="page">Plugins</span>' -and $pp -match '<h1>Plugins</h1>') 'the overview opens with the breadcrumb bar and its own h1'
Assert-Equal 4 ([regex]::Matches($pp, '<section class="card card--link"><h3 class="card__title"><span class="badge badge--sm badge--(good|warn|bad)" aria-hidden="true">(&#10003;|!|&#10007;)</span><a href="/plugins/[a-z-]+">[a-z-]+</a></h3><p class="card__sub">(Up to date|Behind|Install folder missing|Clone behind): ')).Count 'a card per plugin: its state as a decorative mark in the round badge, its name the one link, and the state in words on the sub line (the owner, October 25, 2026)'
Assert-True ($pp -notmatch 'class="tiles"' -and $pp -notmatch '<table' -and $pp -notmatch 'id="problems"' -and -not $pp.Contains('claude plugin update')) 'the overview stays compact: no tiles, no table, no problems block, no command -- those are on the plugin''s page'
Assert-True ($pp.IndexOf('/plugins/alpha"') -lt $pp.IndexOf('/plugins/beta"') -and $pp.IndexOf('/plugins/beta"') -lt $pp.IndexOf('/plugins/gamma"') -and $pp.IndexOf('/plugins/gamma"') -lt $pp.IndexOf('/plugins/zeta"')) 'errors first, then warnings, then the rest, each by name'
Assert-True ($pp.Contains('no longer on disk') -and $pp.Contains('Up to date: 1.0.0, project scope')) 'a card says what is wrong or which version is installed'
Assert-True ($pp.Contains('the clone is &lt;b&gt;ahead&lt;/b&gt;') -and $pp -notmatch '<b>ahead') 'every value from the script is escaped'
$ppOk = Format-PluginsPageHtml -Model (ConvertFrom-PluginVersionsJson -Text '{"Consulted":"c","Plugins":[{"Id":"a@m","Name":"a","Marketplace":"m","Code":"match"}],"Clones":[]}')
Assert-True ($ppOk.Substring($ppOk.IndexOf('<main')) -notmatch '<p class="msg' -and $ppOk -notmatch 'class="lead"' -and $ppOk -match 'card--link') 'the overview is its cards alone: no status line and no lead (the owner, October 25, 2026)'
Assert-True ((Format-PluginsPageHtml -Model (ConvertFrom-PluginVersionsJson -Text '{"Consulted":"c","Plugins":[],"Clones":[]}')) -match 'No plugin is enabled') 'no enabled plugin says so'
$ppErr = Format-PluginsPageHtml -Model (ConvertFrom-PluginVersionsJson -Text '') -ReadError 'it <broke>'
Assert-True ($ppErr -match 'msg--warn' -and $ppErr.Contains('it &lt;broke&gt;') -and $ppErr -notmatch 'card--link') 'a failed read is an escaped warning, with no cards'
Assert-True ((Read-PluginsPageModel -Script (Join-Path $RepoRoot 'no-such.ps1') -RepoRoot $RepoRoot).Error -match 'not found') 'a missing script is a sentence, not a throw'
Assert-True ((Format-PluginsPageHtml -Model $pv -HubHref '/') -match 'href="/"') 'a hub that serves the page itself points Home at its own root'
Write-Host '-- one plugin''s page (#3482): /plugins/<name>' -ForegroundColor Cyan
Assert-Equal '' (Resolve-PluginsPageRequest -Path '/plugins').Name 'the overview is /plugins'
Assert-Equal 'dkj-policy' (Resolve-PluginsPageRequest -Path '/plugins/dkj-policy').Name 'a plugin''s page is /plugins/<name>'
Assert-True ($null -eq (Resolve-PluginsPageRequest -Path '/plugins/../x') -and $null -eq (Resolve-PluginsPageRequest -Path '/plugins/A') -and $null -eq (Resolve-PluginsPageRequest -Path '/pluginsx')) 'anything that is not a plugin slug is no Plugins page'
Assert-True ($null -eq (Find-PluginsPageRow -Model $pv -Name 'nope') -and (Find-PluginsPageRow -Model $pv -Name 'alpha').Status.Level -eq 'error') 'a name is found among the enabled plugins, with its state, or not at all'
$one = Format-PluginPageHtml -Row (Find-PluginsPageRow -Model $pv -Name 'alpha') -Model $pv -RepoName 'r'
Assert-True ($one -match '<a href="/hub">Home</a>' -and $one -match '<a href="/plugins">Plugins</a>' -and $one -match '<span aria-current="page">alpha</span>' -and $one -match '<h1>alpha</h1>') 'its crumbs read Home > Plugins > the plugin'
Assert-True ($one.Contains('<code>claude plugin update alpha@m --scope project</code>') -and $one.Contains('the clone is &lt;b&gt;ahead&lt;/b&gt;') -and $one -match 'msg--warn') 'a problem is named, escaped, with the command that closes it'
$zeta = Format-PluginPageHtml -Row (Find-PluginsPageRow -Model $pv -Name 'zeta') -Model $pv
Assert-True ($zeta.Contains('&lt;i&gt;z&lt;/i&gt;') -and $zeta -notmatch 'role="status"' -and $zeta -notmatch 'To close it' -and $zeta -match 'committed 2026-10-25') 'a healthy plugin shows its description and the clone, and no verdict line or command'
$beta = Format-PluginPageHtml -Row (Find-PluginsPageRow -Model $pv -Name 'beta') -Model $pv
Assert-True ($beta.Contains('no longer on disk') -and $beta -notmatch 'To close it') 'a missing install folder says to reinstall, with no update command'
Write-Host '-- the house style under its plugin (#3493): /plugins/dkj-solutions/house-style' -ForegroundColor Cyan
$hsReq = Resolve-PluginsPageRequest -Path '/plugins/dkj-solutions/house-style'
Assert-True ($hsReq.Name -eq 'dkj-solutions' -and $hsReq.Page -eq 'house-style' -and (Resolve-PluginsPageRequest -Path '/plugins/dkj-solutions').Page -eq '') 'the specimens are a page below the dkj-solutions plugin''s own'
Assert-True ($null -eq (Resolve-PluginsPageRequest -Path '/plugins/dkj-policy/house-style') -and $null -eq (Resolve-PluginsPageRequest -Path '/plugins/dkj-solutions/other')) 'and no other plugin, and no other page below it, is a route'
Assert-True ($zeta -notmatch 'href="/plugins/dkj-solutions/house-style"' -and $zeta -notmatch 'class="grid-3"') 'a plugin that ships no house style links none, and with no cards there is no card grid'
$zc = Format-PluginPageHtml -Row (Find-PluginsPageRow -Model $pv -Name 'zeta') -Model $pv -Cards @(@{ Href = '/plugins/zeta/x'; Label = 'X <y>'; Sub = 's'; Icon = 'specialists' })
Assert-True ($zc -match 'class="grid-3"' -and $zc -match 'href="/plugins/zeta/x"' -and $zc.Contains('X &lt;y&gt;')) 'a hub''s own page below a plugin is a card on that plugin''s page, its label escaped'
$dsRow = (Find-PluginsPageRow -Model $pv -Name 'zeta').Clone(); $dsRow.Name = 'dkj-solutions'
$ds = Format-PluginPageHtml -Row $dsRow -Model $pv -RepoName 'r'
Assert-True ($ds -match '<section class="card card--link"><nav class="menu-list" aria-label="House style"><a class="menu-item" href="/plugins/dkj-solutions/house-style"><svg class="menu-item__icon"') 'the dkj-solutions page links its house style as a card, with its icon'
$hs = Format-HouseStyleSpecimensPageHtml -Body '<section class="card" id="specimen-x"></section>' -RepoName 'r'
Assert-True ($hs -match '<a href="/plugins">Plugins</a>' -and $hs -match '<a href="/plugins/dkj-solutions">dkj-solutions</a>' -and $hs -match '<span aria-current="page">House style</span>' -and $hs -match 'id="specimen-x"' -and $hs -match 'href="/house-style.css"') 'the specimens page sits under Plugins and dkj-solutions, on the house stylesheet the server serves'
$hsErr = Format-HouseStyleSpecimensPageHtml -Body '<p>never</p>' -ReadError 'gone <now>'
Assert-True ($hsErr -notmatch '<p>never</p>' -and $hsErr -match 'could not be read: gone &lt;now&gt;') 'a read error replaces the specimens, escaped'
$specimens = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'plugins\dkj-policy\assets\house-style\specimens.html'))
Assert-True ($specimens -notmatch '(?i)<(html|head|body)[ >]' -and $specimens -notmatch '(?i)<link ' -and $specimens -notmatch '(?i)<script[^>]+src=') 'the specimens ship beside the stylesheet as a body fragment: the shell, the stylesheet and the theme script are the server''s'
Assert-True ($one.Contains('<p class="badge-row"><span class="badge badge--sm badge--bad" aria-hidden="true">&#10007;</span>Behind</p>') -and $one -notmatch 'aria-hidden="true">Behind') 'the plugin page shows its state as the house badge row: the mark, then the word'
Assert-Equal '<p>Intro. Two chapters.</p><h3>The house style</h3><p>tokens &lt;b&gt;.</p><h3>The tracker labels</h3><p>feature. Requires X.</p>' (ConvertTo-PluginDescriptionHtml 'Intro. Two chapters. THE HOUSE STYLE: tokens <b>. THE TRACKER LABELS: feature. Requires X.') 'a description is split into escaped paragraphs at each capitals lead-in, the lead-in an h3 in sentence case'
Assert-Equal '<p>One sentence. CHECK-HOUSE-STYLE gate holds.</p>' (ConvertTo-PluginDescriptionHtml 'One sentence. CHECK-HOUSE-STYLE gate holds.') 'capitals without a colon start no paragraph'
$headRow = [regex]::Match($one, '(?s)<header>\s*<div>\s*<h1>alpha</h1>.*?</div>\s*<p class="badge-row">.*?Behind</p>\s*</header>').Success
Assert-True $headRow 'the plugin page sets its state at the right of the h1 row, in the house page-header row (the owner, October 26, 2026)'
Write-Host ''
Write-Host "dev-pages: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
