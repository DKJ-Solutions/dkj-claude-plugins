<#
.SYNOPSIS
    Tests for scripts/lib/dev-pages-lib.ps1 -- the Repo hub and the test-gate page of the dev server
    (#3097) -- and for the plugin libs it reuses: plugins/dkj-policy/hub/lib/general-pages-lib.ps1 -- the page
    shell, the number formats and the four general pages (SessionStart, Artifacts, Issues, Release notes) that
    moved there in #3119, and to dkj-policy in #3198 -- and plugins/dkj-policy/dkj-solutions/scripts/lib/
    dkj-solutions-pages-lib.ps1, the Brandbook's card and how the general server serves its build (#3210). Pure: the servers that serve them are
    exercised by connector-dashboard.tests.ps1 and dev-preview-sessionstart.tests.ps1.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
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
Assert-True ($shell -match '<li><a href="/">Repo hub</a></li>') 'the trail starts at the Repo hub, linked'
Assert-True ($shell -match 'breadcrumbs__sep" aria-hidden="true"><svg\ viewBox="0\ 0\ 24\ 24"><path\ fill="currentColor"\ fill-rule="evenodd"\ d="M9\.793\ 16\.707a1\ 1\ 0\ 0\ 1\ 0-1\.414L13\.086\ 12\ 9\.793\ 8\.707a1\ 1\ 0\ 0\ 1\ 1\.414-1\.414l4\ 4a1\ 1\ 0\ 0\ 1\ 0\ 1\.414l-4\ 4a1\ 1\ 0\ 0\ 1-1\.414\ 0"\ clip-rule="evenodd"/></svg></span><span aria-current="page">A &lt;b&gt;page</span>') 'and ends at the page, unlinked and escaped'
Assert-True ($shell -match '<h1>A &lt;b&gt;page</h1>') 'the h1 is the page name, escaped'
Assert-True ($shell -match 'data-theme-key="general-pages"') 'the theme key is the general pages'' own, so a theme picked on any page the hub serves holds on all of them (#3168)'
Assert-True ($shell -match '<p class="footer-note">note</p>') 'the footer note closes the column'

Write-Host '-- the general page shell (the plugin''s)' -ForegroundColor Cyan
$gshell = Format-GeneralPageHtml -Title 'An <i>issue' -Lead 'lead' -Body '<p>body</p>' -Eyebrow 'Org/some<repo>' -SiteName 'Org/some<repo>'
Assert-True ($gshell -match '<li><a href="/hub">Repo hub</a></li>') 'the first crumb goes to /hub on the general server'
Assert-True ($gshell -match '<title>Org/some&lt;repo&gt; -- An &lt;i&gt;issue</title>' -and $gshell -match '<p class="eyebrow">Org/some&lt;repo&gt;</p>') 'the title and the eyebrow carry the repo''s name, escaped'
Assert-True ($gshell -match 'data-theme-key="general-pages"') 'the theme key is the general server''s own'
Assert-True ($gshell -notmatch 'dkj-claude-plugins') 'and nothing of this repo is built into it'

Write-Host '-- the Repo hub' -ForegroundColor Cyan
$pages = @(Get-RepoHubPages)
Assert-Equal '/connectors,/specialists,/test-gate' (($pages | ForEach-Object { $_.Href }) -join ',') 'the hub links this repo''s own three pages, in order: the Brandbook is no longer one of them'
Assert-Equal '/artifacts,/issues,/release-notes,/sessionstart' ((Get-GeneralPages | ForEach-Object { $_.Href }) -join ',') 'the plugin lists the four general pages, in order'
Assert-Equal '/brandbook' ((Get-DkjSolutionsPages | ForEach-Object { $_.Href }) -join ',') 'and the one page only DKJ-Solutions repos share, the Brandbook'
$hub = Format-RepoHubHtml -Pages $pages -SourceCommit 'abc1234' -GeneralPagesUrl 'http://localhost:4890'
Assert-True ($hub -match '<title>dkj-claude-plugins -- Repo hub</title>' -and $hub -match '<h1>Repo hub</h1>') 'the h1 and the title are Repo hub, word for word'
Assert-True ($hub -match '<body>\s*<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>\s*<li><span aria-current="page">Repo hub</span></li>\s*</ol>') 'the bar opens <body>, its trail the one crumb Repo hub'
Assert-True ($hub -match '<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>' -and $hub -notmatch '<header' -and $hub -notmatch 'btn--primary') 'the intro is the slug and no <header>, and there is no product button'
Assert-Equal 8 ([regex]::Matches($hub, '<a class="menu-item" href="(http://localhost:4890)?/[a-z-]+"><span class="menu-item__label">[^<]+<span class="menu-item__sub">[^<]+</span></span><svg class="menu-item__chevron"')).Count 'each page is a menu-item row: label, description, chevron'
Assert-True ($hub -match '<nav class="menu-list" aria-label="This repo pages">\r?\n<a class="menu-item"' -and $hub -match '</a>\r?\n<a class="menu-item"') 'the rows are direct siblings in the nav, so the house draws the line between them'
Assert-True ($hub -match '<div class="grid-2">\r?\n<div class="grid__head"><h2>Pages</h2><p class="card__sub">[^<]+</p></div>\r?\n<section class="card">') 'the row opens with a grid__head carrying the h2 Pages and its sub line'
Assert-True ($hub -match '<h3>This repo</h3>.*\r?\n<nav class="menu-list" aria-label="This repo pages">\r?\n<a class="menu-item" href="/connectors"' -and $hub -match '<h3>General</h3>.*\r?\n<nav class="menu-list" aria-label="General pages">\r?\n<a class="menu-item" href="/artifacts"') 'each card''s title is an h3: the repo''s own pages, then the general ones, linked on the hub''s own origin, which relays them (#3168)'
Assert-True ($hub -match '<h3>DKJ-Solutions</h3><p class="card__sub">[^<]+</p></div>\r?\n<nav class="menu-list" aria-label="DKJ-Solutions pages">\r?\n<a class="menu-item" href="/brandbook"' -and $hub.IndexOf('<h3>General</h3>') -lt $hub.IndexOf('<h3>DKJ-Solutions</h3>')) 'the third card, DKJ-Solutions, follows General and links the Brandbook on the hub''s own origin'
Assert-True ($hub -match '<h3>General</h3><p class="card__sub">[^<]*every repo has them</p>') 'General is what every repo has, whichever organisation it belongs to'
Assert-True ($hub -notmatch '<h2 class="card__title">Pages</h2>' -and $hub -notmatch '<style>' -and $hub -notmatch 'grid__card') 'no card repeats the h2, and the hub restyles nothing: the grid head, the full row and the card margin are the house style''s own (#3133)'
Assert-True ($hub.IndexOf('href="/test-gate"') -lt $hub.IndexOf('<h3>General</h3>') -and $hub.IndexOf('href="/issues"') -gt $hub.IndexOf('<h3>General</h3>')) 'and no page sits in the other group''s card'
Assert-True ($hub.IndexOf('<h3>DKJ-Solutions</h3>') -lt $hub.IndexOf('</section>' + [Environment]::NewLine + '</div>' + [Environment]::NewLine + '<div class="grid-2">' + [Environment]::NewLine + '<div class="grid__head"><h2>About this repo</h2>')) 'the three cards stand in one house grid, closed before About this repo'
Assert-True ($hub -match '<div class="grid-2">\r?\n<div class="grid__head"><h2>About this repo</h2><p class="card__sub">[^<]+</p></div>\r?\n<section class="card grid__full">\r?\n<dl class="facts">' -and $hub -notmatch 'card__title">About this repo') 'About this repo''s h2 stands outside its card too, with its sub line, the card a full row under it'
Assert-Equal ([regex]::Matches($hub, '<h2[ >]')).Count ([regex]::Matches($hub, '</h2><p class="card__sub">[^<]+</p>')).Count 'every h2 on the hub carries a sub line'
$down = Format-RepoHubHtml -Pages $pages
Assert-True ($down -match '<h3>General</h3>' -and $down -match 'The general pages server is not running' -and $down -notmatch 'href="http://localhost' -and $down -notmatch 'href="/artifacts"') 'with no general server the General card says it is not running, and links nothing'
Assert-True ((Format-RepoHubHtml -Pages $pages -GeneralPagesUrl 'http://evil.example:4890') -match 'is not running') 'a pages url that is not plain loopback is no server at all'
Assert-True ((Format-GeneralPagesCardHtml -PagesUrl 'http://localhost:4890/') -match 'href="http://localhost:4890/issues"') 'a trailing slash on the base url is cut'
Assert-True ((Format-GeneralPagesCardHtml -PagesUrl 'http://localhost:4890' -SameOrigin) -match 'href="/issues"' -and (Format-GeneralPagesCardHtml -PagesUrl '' -SameOrigin) -match 'is not running') '-SameOrigin links each page by its bare path, and still only when a server answers (#3168)'
$alone = Format-RepoHubHtml -Pages @() -GeneralPagesUrl 'http://localhost:4890'
Assert-True ($alone -notmatch '<h2>Pages</h2>' -and $alone -notmatch '<h3>' -and $alone -match '<div class="grid__head"><h2>General pages</h2>[^\r\n]*\r?\n<section class="card grid__full">' -and $alone -match '<div class="grid__head"><h2>DKJ-Solutions pages</h2>[^\r\n]*\r?\n<section class="card grid__full">') 'a hub with no page of its own has the General and DKJ-Solutions cards alone, each h2 above its card (#3175)'
Assert-True ($alone -notmatch 'This repo</h3>') 'and no card for the repo''s own'
Assert-True ($hub -match '<dt>Source at</dt><dd><code>abc1234</code></dd>') 'About this repo names the commit it serves from'
Assert-True ((Format-RepoHubHtml -Pages $pages) -notmatch 'Source at') 'and leaves the row out when the commit could not be read'
$ix = @('class="breadcrumbs-bar"', 'id="settings"', 'class="eyebrow"', 'Pages</h2>', 'About this repo</h2>', 'class="footer-note"') | ForEach-Object { $hub.IndexOf($_) }
Assert-True ((@($ix | Where-Object { $_ -lt 0 }).Count -eq 0) -and ((($ix | Sort-Object) -join ',') -eq ($ix -join ','))) 'the blocks stand in the form''s order'
$evil = Format-RepoHubHtml -Pages @(@{ Href = '/x"><script>'; Label = '<b>'; Sub = '' })
Assert-True ($evil -notmatch 'x"><script>' -and $evil -match 'href="/x&quot;&gt;&lt;script&gt;"' -and $evil -notmatch '<b>') 'every value is escaped'
Assert-True ($evil -notmatch 'menu-item__sub">[^<]*</span></span><svg[^>]*><path[^>]*/></svg></a>\r?\n</nav>\r?\n</section>\r?\n<section class="card">\r?\n<div') 'and an empty description is left out'

Write-Host '-- the Brandbook: the brandbook/ app''s build, served under /brandbook/' -ForegroundColor Cyan
Assert-Equal 'index.html' (ConvertTo-BrandbookRelPath -Path '/brandbook/') 'the base is the app''s page'
Assert-Equal 'assets/index-abc.js' (ConvertTo-BrandbookRelPath -Path '/brandbook/assets/index-abc.js') 'a file is named relative to dist/'
Assert-Equal 'dashboards/etf' (ConvertTo-BrandbookRelPath -Path '/brandbook/dashboards/etf/') 'a route''s trailing slash goes'
Assert-True ($null -eq (ConvertTo-BrandbookRelPath -Path '/brandbook') -and $null -eq (ConvertTo-BrandbookRelPath -Path '/connectors')) 'a path outside the base is not the brand book''s'
Assert-Equal 0 @('/brandbook/../x', '/brandbook/a/../../x', '/brandbook/%2e%2e/x', '/brandbook/a\..\x', '/brandbook/C:/x', '/brandbook//x', '/brandbook/./x' |
    Where-Object { $null -ne (ConvertTo-BrandbookRelPath -Path $_) }).Count 'a path that could climb out of dist/ is refused, encoded or not'
$bbDir = Join-Path ([System.IO.Path]::GetTempPath()) "dev-pages-bb-$PID-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Path (Join-Path $bbDir 'assets') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $bbDir 'index.html') -Value '<div id="root"></div>'
Set-Content -LiteralPath (Join-Path $bbDir 'assets\a.js') -Value 'x'
try {
    Assert-Equal 'assets/a.js' (Resolve-BrandbookFile -Path '/brandbook/assets/a.js' -BuildDir $bbDir).Rel 'a file of the build is served as itself'
    Assert-Equal 'index.html' (Resolve-BrandbookFile -Path '/brandbook/repo-hub' -BuildDir $bbDir).Rel 'one of the app''s routes is answered with its page'
    Assert-Equal 'assets/gone.js' (Resolve-BrandbookFile -Path '/brandbook/assets/gone.js' -BuildDir $bbDir).Rel 'a missing file stays a missing file, so it is a 404 rather than the page'
    Assert-True ($null -eq (Resolve-BrandbookFile -Path '/brandbook/../x' -BuildDir $bbDir)) 'and an unsafe path resolves to nothing'
} finally { Remove-Item -LiteralPath $bbDir -Recurse -Force -ErrorAction SilentlyContinue }
Assert-True ((Get-BrandbookBuildDir -PluginRoot 'C:\p\dkj-policy\') -eq 'C:\p\dkj-policy\dkj-solutions\assets\brandbook') 'the shipped build is the dkj-solutions extension''s assets/brandbook/ (#3210)'
$bm = Format-BrandbookMissingHtml -RepoName 'Org/<r>'
Assert-True ($bm -match '<h1>Brandbook</h1>' -and $bm -match '<a href="/hub">Repo hub</a>' -and $bm -match 'ships no build of the brand book' -and $bm -match 'Org/&lt;r&gt;') 'a payload with no build says so, as a general page, and escapes the repo name'
Assert-Equal 'text/javascript; charset=utf-8|text/css; charset=utf-8|image/svg+xml|application/octet-stream' (('a.js', 'b.css', 'c.svg', 'd.map' | ForEach-Object { Get-BrandbookContentType -RelPath $_ }) -join '|') 'each file is sent with its type'
$bs = Format-BrandbookStatusHtml -Message 'Not <built>' -Detail 'line <1>'
Assert-True ($bs -match '<h1>Brandbook</h1>' -and $bs -match '<a href="/">Repo hub</a>' -and $bs -match 'role="alert">Not &lt;built&gt;' -and $bs -match '<pre class="note">line &lt;1&gt;</pre>') 'the status page is a page under the Repo hub, and escapes what it is handed'

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
Assert-True ($tg -match 'actions/runs/111"') 'each run links to its CI run'
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
Assert-True ($gp -match '<h2>Groups</h2>' -and $gp -match 'Every suite runs on every PR') 'the page opens with the groups, and says every suite runs on every PR'
Assert-True ($gp -match 'href="#group-one">Step &lt;one&gt;</a>' -and $gp -notmatch 'Step <one>') 'each group links to its own section, its title escaped'
Assert-True ($gp.IndexOf('id="group-one"') -lt $gp.IndexOf('id="group-two"') -and $gp -match '<h2>Step two</h2><p class="card__sub">Guards the second</p>') 'each group has its own section, in order, with what it guards'
Assert-True ($gp.IndexOf('>a.tests.ps1<') -gt $gp.IndexOf('id="group-one"') -and $gp.IndexOf('>a.tests.ps1<') -lt $gp.IndexOf('id="group-two"')) 'a suite is listed in its own group'
Assert-True ($gp -match 'href="#group-one">.*?</span></td><td class="num">2</td>' -and $gp -match 'new.tests.ps1</code> <span class="badge badge--sm badge--neutral">not recorded yet</span></td><td class="num">--</td>') 'a group counts and lists its unmeasured suites too, marked as not recorded yet'
Assert-True ($gp -match 'role="alert">In no group of scripts/tests/suite-groups.json: <code>gone.tests.ps1</code>' -and $gp -match '<h2>Not grouped</h2>') 'an ungrouped suite is a warning, and still listed'
Assert-True ($gp -match 'Grouped but no longer on disk: <code>away.tests.ps1</code>') 'a grouped name not on disk is named'
Assert-True ($gp -notmatch 'id="suites"') 'and the ungrouped single table is gone'
Assert-True ($gp -match '<tfoot><tr class="row-total dp-total"><td class="dp-left">Total <span class="note">all groups, run one after another; CI runs them in parallel</span></td><td class="num">3</td><td class="num">40.0s</td><td class="dp-left"></td><td>88.9%</td></tr></tfoot>') 'the groups table closes on the sum of every group, its count, and its share of the whole'
Assert-True ($gp -match '>Total <span class="note">2 suites, run one after another; CI runs them in parallel</span></td><td class="num">10.0s</td><td class="dp-left"></td><td>22.2%</td></tr></tfoot>') 'each group''s table closes on its own sum, counting its unmeasured suites'
Assert-True ($gp -match '\.dp-total td \{ border-top: 2px solid var\(--primary-5\); \}') 'the total row stands under a heavier rule than the rows above it'
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
Assert-True ($ss -match '<h1>SessionStart</h1>') 'the page is named SessionStart'
Assert-True ($ss -match 'Headroom \(B\)</div><div class="v num">3,000') 'inside the budget: the headroom'
Assert-True ($ss.IndexOf('~/persona.md') -lt $ss.IndexOf('<code>CLAUDE.md</code></td>')) 'the documents are listed largest first'
Assert-True ($ss -match '~/persona.md</code></td><td class="num">900</td>.*?<td>90.0%</td><td class="dp-left">from the baseline') 'a carried document says so'
Assert-True ($ss -match 'role="status">Not counted.*lost.md') 'an unmeasured document is named, not counted as zero'
Assert-True ($ss -notmatch 'msg--warn') 'no warning inside the budget'
$ssModel.Total = 5000; $ssModel.Ok = $false; $ssModel.State = 'over-growing'
$over = Format-SessionStartPageHtml -Model $ssModel
Assert-True ($over -match 'Over the budget \(B\)</div><div class="v num">1,000') 'over the budget: by how much'
Assert-True ($over -match 'msg msg--warn" role="alert">The always-on path is over its limit \(over-growing\)') 'and a warning naming the state'
$failed = Format-SessionStartPageHtml -Model $null -ReadError 'boom <x>'
Assert-True ($failed -match 'could not be measured: boom &lt;x&gt;') 'a failed measurement is a warning, escaped'
Assert-True ($failed -match 'No always-on document was measured') 'and the table says it is empty'

Write-Host '-- the SessionStart snapshot' -ForegroundColor Cyan
Assert-True ($ss -notmatch 'id="last-measurement"') 'without a snapshot the page shows only the live table'
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
Assert-True ($sp -match 'id="last-measurement"' -and $sp.IndexOf('id="documents"') -lt $sp.IndexOf('id="last-measurement"')) 'the snapshot follows the live table'
Assert-True ($sp -match 'About <strong>47k</strong> in <code>CLAUDE.md</code> &lt;b&gt;') 'the lede renders bold and code, and escapes the rest'
Assert-True ($sp -match 'Efficiency score</div><div class="v num">30 / 100 \(was 20\)') 'the score is the no-influence share, against the previous one'
Assert-True ($sp -match 'Direct \(tokens\)</div><div class="v num">~600 \(60%\)') 'the influence tiles sum the layers'
Assert-True ($sp.IndexOf('>Docs') -lt $sp.IndexOf('>Stubs') -and $sp.IndexOf('>Stubs') -lt $sp.IndexOf('>Tools')) 'the layers are grouped direct, setting, none'
Assert-True ($sp -match '<td class="num">-100</td>') 'a layer that shrank shows by how much'
Assert-True ($sp -match '<td class="num">~100</td>') 'an estimated layer is marked as one'
Assert-True ($sp.IndexOf('Open one') -lt $sp.IndexOf('Old one')) 'open actions come before done ones'
Assert-True ($sp -match 'Old one.*?&#10003;</span>Done') 'a done action says so'
Assert-True ($sp -match '<em>Caveat:</em> careful') 'an action carries its caveat'
Assert-True ($sp -match '<dt>Harness</dt><dd>fixed</dd>' -and $sp -match '<strong>Do not:</strong> that') 'what cannot change, and the advice, are shown'
Assert-True ($sp -match 'href="https://claude.ai/artifact/abc"') 'the source Artifact is linked'
$snap.source.artifact = 'javascript:alert(1)'
Assert-True ((Format-SessionStartPageHtml -Model $ssModel -Snapshot $snap) -notmatch 'javascript:') 'a source that is not an Artifact link is not linked'
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
Assert-True ($rn -match '<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">') 'it takes the theme key and the lilac default every other page of the general server uses (#3162)'
Assert-True ((Format-ReleaseNotesDevPage -Html $tpl -ThemeKey 'k"x' -HubHref '/') -match 'data-theme-key="k&quot;x"' -and (Format-ReleaseNotesDevPage -Html $tpl -HubHref '/') -match '<li><a href="/">Repo hub</a></li>') 'a caller may name the theme key and the hub crumb''s target, both escaped'
$tplStyleEnd = $rn.IndexOf('</style>')
$houseAt = $rn.IndexOf('<link rel="stylesheet" href="/house-style.css">')
Assert-True ($houseAt -gt $tplStyleEnd -and $tplStyleEnd -gt 0) 'the house stylesheet loads after the template''s own style, so the house body wins'
Assert-True ($rn.IndexOf('--panel: var(--primary-2)') -gt $houseAt) 'and the template''s tokens are pointed at house tokens after it'
Assert-True ($rn.IndexOf('<script src="/house-theme.js"></script>') -lt $rn.IndexOf('<body')) 'the theme script loads in the head'
$bodyAt = $rn.IndexOf('<body>')
$barAt = $rn.IndexOf('<div class="breadcrumbs-bar">')
Assert-True ($barAt -gt $bodyAt -and $rn.Substring($bodyAt + 6, $barAt - $bodyAt - 6).Trim() -eq '') 'the breadcrumb bar is the first thing in <body>'
Assert-True ($rn -match '<li><a href="/hub">Repo hub</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true"><svg\ viewBox="0\ 0\ 24\ 24"><path\ fill="currentColor"\ fill-rule="evenodd"\ d="M9\.793\ 16\.707a1\ 1\ 0\ 0\ 1\ 0-1\.414L13\.086\ 12\ 9\.793\ 8\.707a1\ 1\ 0\ 0\ 1\ 1\.414-1\.414l4\ 4a1\ 1\ 0\ 0\ 1\ 0\ 1\.414l-4\ 4a1\ 1\ 0\ 0\ 1-1\.414\ 0"\ clip-rule="evenodd"/></svg></span><span aria-current="page">Release notes</span></li>') 'its trail runs from the Repo hub, on /hub of the general server, to this page'
Assert-True ($rn.IndexOf('DKJTheme.settings(') -gt $rn.IndexOf('id="settings"') -and $rn.IndexOf('DKJTheme.settings(') -lt $rn.LastIndexOf('</body>')) 'the settings button is mounted before </body>'
Assert-True ($rn.Contains('<div class="wrap">') -and $rn.Contains('@@RELEASE_ROWS@@') -and $rn.Contains('@@PAGE_STYLE@@')) 'the template''s own content is left alone'
# The settings panel's width reaches main and .container only, and the template's column is neither, so the
# template answers data-width itself -- every width the theme script offers but fluid, which is its own column.
Assert-True ($tpl.Contains(':root[data-width="phone"] .wrap {') -and $tpl.Contains(':root[data-width="full"] .wrap { max-width: none; }')) 'the template''s column follows the page-width setting'
Assert-Equal '<html>fixture</html>' (Format-ReleaseNotesDevPage -Html '<html>fixture</html>') 'a page without the template''s shape is served as it came'

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

Write-Host '-- the Specialists page' -ForegroundColor Cyan
$evil = ConvertTo-SpecialistRow -Id '06-99' -Plugin 'dkj-subagents-ecomm' -Form subagent -Text "---`ndescription: <b>x</b>`n---`nYou are **Eve <i>**, the Bad <b>. Body`n" -ManualBytes 99999
$sp = Format-SpecialistsPageHtml -Rows @($sa, $pa, $evil) -CharsPerToken 3.12
Assert-True ($sp -match '<h1>Specialists</h1>' -and $sp -match '<span aria-current="page">Specialists</span>') 'the page is named Specialists, in the h1 and the trail'
Assert-True ($sp -match 'Specialists</div><div class="v num">3<' -and $sp -match 'Enabled here</div><div class="v num">2<') 'the tiles count the specialists and those enabled here'
Assert-True ($sp.IndexOf('<strong>Eve') -lt $sp.IndexOf('<strong>Paula') -and $sp.IndexOf('<strong>Paula') -lt $sp.IndexOf('<strong>Chris')) 'largest full read first'
Assert-True ($sp.Contains('Eve &lt;i&gt;') -and -not $sp.Contains('Eve <i>')) 'a name is escaped'
Assert-True ($sp.Contains('ecomm <span class="note">(off here)</span>')) 'a plugin not enabled here says so'
Assert-True ($sp.Contains('always-on</span>')) 'the orchestrator carries the always-on badge'
Assert-True ($sp.Contains('~' + (Format-DevNumber ([Math]::Round(1000 / 3.12))) + '<')) 'tokens are the bytes at the given factor'
Assert-True ($sp.Contains('3.12 characters per token')) 'the footer names the factor, so the estimate is labelled as one'
Assert-True ((Format-SpecialistsPageHtml -Rows @() -CharsPerToken 3.12).Contains('No specialist was found')) 'none found says so instead of an empty table'
Assert-True ((Format-SpecialistsPageHtml -Rows @() -CharsPerToken 3.12 -ReadError 'x.md').Contains('msg--warn')) 'a failed read is a warning on the page'
Write-Host ''
Write-Host "dev-pages: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
