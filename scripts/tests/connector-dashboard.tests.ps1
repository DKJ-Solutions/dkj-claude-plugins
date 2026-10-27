<#
.SYNOPSIS
    Tests for scripts/lib/connector-dashboard-lib.ps1 and the server beside it,
    scripts/dashboard/serve-connector-dashboard.ps1 -- the connector dashboard (#2976).

.DESCRIPTION
    Group 1 pins the rules without a server: how check-connectors.ps1's report splits into repos and
    plugins, which status a repo gets, which Host is served, that every value the page shows is
    escaped, and that the plugin's canonical house style is the copy the house-style skill pins. Group 2 starts
    the real server on a free loopback port against this tree and asks it for the static files, a foreign Host, a cross-site request, a POST, a missing path, a dripping client and
    an oversized head. Group 3 serves the page from a fixture tree: a checkout with no upstream, one
    outside the scope root, and no check-connectors.ps1 at all -- and the four general routes that moved to
    the general pages server (#3119, dkj-policy's since #3198): the hub's General card before and after a state file
    names a server that answers, and the relayed answer or the 404 each of those routes gets (#3168).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Server   = Join-Path $RepoRoot 'scripts\dashboard\serve-connector-dashboard.ps1'
. (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1')
# The state file's reader and writer, which the server and these fixtures share (#3119).
$PluginLib = Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib'
$GeneralServer = Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\serve-general-pages.ps1'
. (Join-Path $PluginLib 'general-pages-state.ps1')
. (Join-Path $PluginLib 'loopback-server-lib.ps1')

$script:pass = 0
$script:fail = 0
$group2Ran = $false   # group 3 reuses group 2's request helper

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

Write-Host '-- group 1a: the report splits into repos and plugins' -ForegroundColor Cyan

$report = @(
    '== check-connectors -- 3 manifest(s) -- source read at abc1234 ==',
    '',
    '== connector: Org/alpha',
    '  [ERROR] Org/alpha: origin names someone else',
    '',
    '== connector: Org/beta',
    '  -- plugin: p1@m',
    '  [OK]    plugin is enabled in .claude/settings.json',
    '  [ERROR] Org/beta / p1@m: machine record is on v1, source on v2',
    '  [INFO]  Org/beta: plugin q@m is enabled but not listed',
    '',
    '== connector: Org/gamma',
    '  [SKIP]  checkout ''../gamma'' not present on this machine -- not checked.',
    '',
    'Summary: 2 error(s), 1 info signal(s).',
    '  [ERROR] Org/beta: after the summary, not a signal'
)
$parsed = ConvertFrom-ConnectorCheckOutput -Lines $report
Assert-Equal 'Org/alpha Org/beta Org/gamma' (@($parsed.Keys) -join ' ') 'every connector block becomes a repo, in report order; the opening line is not one'
Assert-Equal 1 @($parsed['Org/alpha'].Signals).Count 'a repo-level signal belongs to its repo'
Assert-Equal 'origin names someone else' $parsed['Org/alpha'].Signals[0].Text 'the "<repo>: " prefix is stripped'
$beta = @($parsed['Org/beta'].Signals)
Assert-Equal 3 $beta.Count 'the summary after the last block adds nothing to it'
Assert-Equal 'p1@m' $beta[1].Plugin 'a signal under "-- plugin:" carries that plugin'
Assert-Equal 'machine record is on v1, source on v2' $beta[1].Text 'the "<repo> / <plugin>: " prefix is stripped'
Assert-Equal 'plugin q@m is enabled but not listed' $beta[2].Text 'a repo-level prefix is stripped inside a plugin block too'
Assert-Equal 0 @((ConvertFrom-ConnectorCheckOutput -Lines @()).Keys).Count 'an empty report is no repos, not an error'
Assert-Equal 0 @((ConvertFrom-ConnectorCheckOutput -Lines $null).Keys).Count 'no report at all is no repos either'

# #2995: the check prints non-counting markers inside a connector block, and a parser naming four
# tags dropped them -- so such a repo read as 'In sync'.
$markers = ConvertFrom-ConnectorCheckOutput -Lines @(
    '== connector: Org/delta',
    '  [OK]    plugin is enabled in .claude/settings.json',
    '  [INVENTORY] this repo has 1 lens(es) that its own entry in the connector register does not list (x)',
    '  -- plugin: p1@m',
    '  [NOT-INSTALLED-HERE] ''p1@m'' is enabled in .claude/settings.json but has no install record',
    '  [UNLISTED] this repo has 1 plugin(s) enabled that its own entry does not list (q@m)',
    '  [UNREGISTERED] Org/delta: not in the register'
)
$delta = @($markers['Org/delta'].Signals)
Assert-Equal 5 $delta.Count 'every bracketed tag inside a connector block is a signal, not just four named ones'
Assert-Equal 'OK INFO INFO INFO INFO' (($delta | ForEach-Object { $_.Level }) -join ' ') 'a tag other than ERROR, OK or SKIP is read as INFO -- a note, never an error'
Assert-Equal 'p1@m' $delta[2].Plugin 'a marker under "-- plugin:" carries that plugin'
Assert-Equal 'not in the register' $delta[4].Text 'a marker''s "<repo>: " prefix is stripped like any signal''s'
Assert-Equal 'warn' (Get-ConnectorStatus $delta) 'a repo with only a marker beside [OK] is warn, not In sync'

Write-Host '-- group 1b: status, worst first' -ForegroundColor Cyan

Assert-Equal 'bad'  (Get-ConnectorStatus $beta) 'an [ERROR] makes a repo bad, whatever else it has'
Assert-Equal 'warn' (Get-ConnectorStatus @(@{ Level = 'OK' }, @{ Level = 'INFO' })) 'an [INFO] without an error is warn'
Assert-Equal 'skip' (Get-ConnectorStatus @($parsed['Org/gamma'].Signals)) 'a skipped checkout is skip -- nothing was read, so it is not called healthy'
Assert-Equal 'good' (Get-ConnectorStatus @(@{ Level = 'OK' })) 'only [OK] is good'
Assert-Equal 'good' (Get-ConnectorStatus @()) 'no signals is good'

Write-Host '-- group 1b1: a drift block belongs to the repo it names (#2997)' -ForegroundColor Cyan

$driftReport = ConvertFrom-ConnectorCheckOutput -Lines @(
    '== connector: Org/clean',
    '  [OK]    plugin is enabled in .claude/settings.json',
    '== connector: Org/drifty',
    '  -- plugin: p1@m',
    '  [OK]    machine record is on the source version (v5.18.0)',
    '== connector: Org/far',
    '  [SKIP]  checkout ''../far'' not present on this machine -- not checked.',
    '',
    '-- drift-check: Org/clean',
    '  == check-consumer-drift -- C:\somewhere\clean ==',
    '  Agent-def summary: 26 missing, 0 identical (dead copies), 0 drifted.',
    '    Persona drift is INFORMATIONAL (does not affect the exit code): 0 drifted of 4 compared.',
    '',
    '-- drift-check: Org/drifty',
    '  == check-consumer-drift -- C:\somewhere\drifty ==',
    '    [IDENTICAL] id 05-15 (x) -- dead copy at C:\somewhere\drifty\x.md, safe to remove.',
    '    [DRIFTED]   id 06-16 (y) -- differs from the canonical version: C:\somewhere\drifty\y.md',
    '    [DRIFTED]   persona z -- body differs from the canonical source: C:\somewhere\drifty\z.md',
    '  Agent-def summary: 24 missing, 1 identical (dead copies), 1 drifted.',
    '    Persona drift is INFORMATIONAL (does not affect the exit code): 1 drifted of 4 compared.',
    '  [ERROR] Org/drifty: agent-def drift found -- see check-consumer-drift.',
    '',
    'Summary: 1 error(s), 0 info signal(s).'
)
$dc = $driftReport['Org/clean']
Assert-Equal '0 0 0 4' "$($dc.Drift.Dead) $($dc.Drift.Drifted) $($dc.Drift.PersonaDrifted) $($dc.Drift.PersonaCompared)" 'the two summary lines become the repo''s Drift record'
Assert-Equal 'good' (Get-ConnectorStatus $dc.Signals) 'a clean drift block leaves the status alone'
$dd = $driftReport['Org/drifty']
Assert-Equal '1 1 1 4' "$($dd.Drift.Dead) $($dd.Drift.Drifted) $($dd.Drift.PersonaDrifted) $($dd.Drift.PersonaCompared)" 'non-zero counts are read'
Assert-Equal 2 @($dd.Signals).Count 'only the [ERROR] joins the signals -- the per-file lines with local paths do not'
Assert-Equal 'agent-def drift found -- see check-consumer-drift.' @($dd.Signals)[1].Text 'the drift [ERROR] belongs to the repo its block names, prefix stripped, no plugin carried over'
Assert-Equal '' @($dd.Signals)[1].Plugin 'a drift block opens with no plugin'
Assert-Equal 'bad' (Get-ConnectorStatus $dd.Signals) 'agent-def drift makes the repo bad, as the check counts it'
Assert-True ($null -eq $driftReport['Org/far'].Drift) 'a repo with no drift block has no Drift record'
$personaOnly = ConvertFrom-ConnectorCheckOutput -Lines @(
    '== connector: Org/p', '  [OK]    fine', '-- drift-check: Org/p',
    '  Agent-def summary: 26 missing, 0 identical (dead copies), 0 drifted.',
    '    Persona drift is INFORMATIONAL (does not affect the exit code): 2 drifted of 4 compared.')
Assert-Equal 'good' (Get-ConnectorStatus $personaOnly['Org/p'].Signals) 'persona drift alone never changes the status'
Assert-Equal 'Drift: 1 dead copies &#183; 1 drifted agent defs &#183; 1 of 4 personas drifted (informational)' (Format-DashboardDrift $dd.Drift) 'the card line names all three counts'
Assert-Equal '' (Format-DashboardDrift $null) 'no Drift record, no line'
Assert-True ((Format-DashboardDrift @{ Dead = 0; Drifted = $null; PersonaDrifted = $null; PersonaCompared = $null }) -match 'Drift: 0 dead copies &#183; \? drifted') 'a count the check did not print reads ?'

Write-Host '-- group 1b2: the installed plugin version (#2996)' -ForegroundColor Cyan

$verReport = ConvertFrom-ConnectorCheckOutput -Lines @(
    '== connector: Org/same',
    '  -- plugin: a@m',
    '  [OK]    machine record is on the source version (v5.18.0)',
    '  -- plugin: b@m',
    '  [OK]    machine record is on the source version (v5.18.0)',
    '== connector: Org/lags',
    '  -- plugin: a@m',
    '  [OK]    machine record is on the source version (v5.18.0)',
    '  -- plugin: b@m',
    '  [ERROR] Org/lags / b@m: machine record is on v5.9.2, source on v5.18.0 -- update the plugin',
    '== connector: Org/norecord',
    '  -- plugin: a@m',
    '  [INFO]  no machine record for this consumer (the install may run via a different machine).'
)
$same = Get-ConnectorInstalledVersion $verReport['Org/same'].Signals
Assert-Equal '5.18.0' $same.Version 'the version comes from the check''s own machine-record line'
Assert-True (-not $same.Mixed) 'plugins on one version are not mixed'
$lags = Get-ConnectorInstalledVersion $verReport['Org/lags'].Signals
Assert-Equal '5.9.2 b@m' "$($lags.Version) $($lags.Plugin)" 'the lowest version wins, compared as a version (5.9.2 below 5.18.0), with its plugin'
Assert-True $lags.Mixed 'plugins on different versions are mixed'
Assert-True ($null -eq (Get-ConnectorInstalledVersion $verReport['Org/norecord'].Signals)) 'no machine-record line is no version'
Assert-Equal 'v5.18.0' (Format-DashboardInstalledVersion @{ Present = $true; Signals = $verReport['Org/same'].Signals }) 'one version: the cell is the version alone'
Assert-Equal 'v5.9.2 <code>b@m</code>' (Format-DashboardInstalledVersion @{ Present = $true; Signals = $verReport['Org/lags'].Signals }) 'differing versions: the cell names the lowest and its plugin'
Assert-Equal 'no record' (Format-DashboardInstalledVersion @{ Present = $true; Signals = $verReport['Org/norecord'].Signals }) 'a checkout here with no record says so'
Assert-Equal '-' (Format-DashboardInstalledVersion @{ Present = $false; Signals = @() }) 'a repo not on this machine is -'

Write-Host '-- group 1c: the checkout list and the Host guard' -ForegroundColor Cyan

Assert-Equal '../a' ((Get-ConnectorCheckoutCandidates '../a') -join ',') 'one path is a list of one'
Assert-Equal '../a,../b' ((Get-ConnectorCheckoutCandidates @('../a', ' ', '../b')) -join ',') 'a list drops its blanks'
Assert-True  (Test-LoopbackHost 'localhost:4870' 4870) 'localhost on our port is served'
Assert-True  (Test-LoopbackHost '127.0.0.1:4870' 4870) '127.0.0.1 on our port is served'
Assert-True  (Test-LoopbackHost 'LocalHost:4870 ' 4870) 'the Host is compared case-insensitively and trimmed'
Assert-True  (-not (Test-LoopbackHost 'evil.example:4870' 4870)) 'a rebound foreign name is refused'
Assert-True  (-not (Test-LoopbackHost 'localhost:4871' 4870)) 'another port is refused'
Assert-True  (-not (Test-LoopbackHost '' 4870)) 'no Host is refused'

Assert-True  (Test-DashboardCheckoutInScope 'C:\g\org\repo' 'C:\g') 'a sibling checkout under the scope root is in scope'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\other\repo' 'C:\g')) 'a path that climbs out of the scope root is not'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\g2\repo' 'C:\g')) 'a sibling of the scope root that shares its prefix is not'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\g' 'C:\g')) 'the scope root itself is not a checkout'
Assert-True  (Test-LoopbackCrossSite 'cross-site') 'a cross-site request is refused'
Assert-True  (Test-LoopbackCrossSite 'Same-Site') 'a same-site (other port or subdomain) request is refused'
Assert-True  (-not (Test-LoopbackCrossSite 'same-site' 'navigate' 'GET')) 'a same-site top-level GET navigation -- the crumb back from the general pages on another port -- is served (#3119)'
Assert-True  (Test-LoopbackCrossSite 'same-site' 'cors' 'GET') 'a same-site fetch is still refused'
Assert-True  (Test-LoopbackCrossSite 'same-site' 'navigate' 'POST') 'and so is a same-site navigation that is a POST'
Assert-True  (Test-LoopbackCrossSite 'cross-site' 'navigate' 'GET') 'a cross-site navigation is refused whatever its mode'
Assert-True  (-not (Test-LoopbackCrossSite 'same-origin')) 'the page itself is served'
Assert-True  (-not (Test-LoopbackCrossSite 'none')) 'a typed or bookmarked URL is served'
Assert-True  (-not (Test-LoopbackCrossSite '')) 'no header (curl) is served'

Write-Host '-- group 1d: the page escapes what it shows' -ForegroundColor Cyan

$hostile = '<script>alert(1)</script>'
$connectors = @(
    @{ Repo = 'Org/beta'; Visibility = 'private'; File = 'beta.json'; Checkout = @('../beta'); Present = $true
       Plugins = @(@{ Id = 'p1@m'; Extensions = @('01-01', '05-05') }); Signals = $beta; Status = 'bad'
       Git = @{ Branch = 'feat/y'; Trunk = 'main'; Subject = $hostile; When = '2 days ago' }; Notes = "a`"note" },
    @{ Repo = 'Org/gamma'; Visibility = 'public'; File = 'gamma.json'; Checkout = @('../gamma'); Present = $false
       Plugins = @(); Signals = @($parsed['Org/gamma'].Signals); Status = 'skip'; Git = $null; Notes = '' }
)
# Both repos are owned by neither DKJ nor BWJ, so their details are the Other group's page (owner, October 26, 2026).
$html = Format-ConnectorDashboardHtml -Connectors $connectors -Meta @{ GeneratedAt = 'now'; SourceCommit = 'abc1234'; Seconds = 1.25; CheckFailed = $null } -Group 'other'
Assert-True ($html -notmatch '<script>alert') 'a git subject is shown as text, never as markup'
Assert-True ($html -match '&lt;script&gt;alert') 'and it is still shown'
Assert-True ($html -match 'a&quot;note') 'the register notes are escaped too'
Assert-True ($html -match 'Last commit on main 2 days ago: ' -and $html -notmatch 'feat/y') 'the card states the trunk''s last commit, never the checked-out branch'
Assert-True ($html -match 'not on this machine') 'an absent checkout says so'
Assert-True ($html.IndexOf('id="repo-org-beta"') -lt $html.IndexOf('id="repo-org-gamma"')) 'a repo that needs action comes before a skipped one'
Assert-True ($html -match 'href="/refresh\?page=connectors/other"') 'a group page''s re-run comes back to that same group page'
Assert-True ($html -match 'href="/house-style.css"' -and $html -match 'src="/house-theme.js"') 'the page loads the house style from its own server'
Assert-True ($html -match 'DKJTheme\.settings\(' -and $html -notmatch 'DKJTheme\.picker\(') 'the theme choice is the house settings button, not a hand-built picker card'
Assert-True ($html -match '<div id="settings"></div></div></header>' -and $html -notmatch 'theme-settings--floating') 'the settings button sits at the far right of the site header'
Assert-True (([regex]::Matches($html, 'var\(--(primary|muted|fg-|paper-)')).Count -ge 6 -and $html -match 'class="cd-link"') 'the chosen theme reaches the page beyond its buttons, through the repo layer''s own theme-colour accents'
Assert-True ($html -notmatch 'class="eyebrow"' -and $html -match '<header class="site-header"><div class="container"><a class="site-header__brand" href="/"' -and $html -match '<h1>Other repos</h1>' -and $html -match '<main class="page-column">') 'the page keeps the hub frame: the site header in place of the eyebrow, its own h1, the page column'
Assert-True ($html -match '(?s)<body>\s*<div class="notice" id="hub-banner".*?</script>\s*<header class="site-header">.*?</header>\s*<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>\s*<li><a href="/">Home</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true"><svg\ viewBox="0\ 0\ 24\ 24"><path\ fill="currentColor"\ fill-rule="evenodd"\ d="M9\.793\ 16\.707a1\ 1\ 0\ 0\ 1\ 0-1\.414L13\.086\ 12\ 9\.793\ 8\.707a1\ 1\ 0\ 0\ 1\ 1\.414-1\.414l4\ 4a1\ 1\ 0\ 0\ 1\ 0\ 1\.414l-4\ 4a1\ 1\ 0\ 0\ 1-1\.414\ 0"\ clip-rule="evenodd"/></svg></span><a href="/connectors">Connectors</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true"><svg[^>]*><path[^>]*/></svg></span><span aria-current="page">Other repos</span></li>') 'the banner opens <body>, then the site header and the breadcrumb bar, its trail from the hub through Connectors to the group (#3090, #3097)'
Assert-True (([regex]::Matches($html, '<header')).Count -eq 1 -and $html -notmatch 'cd-band|cd-accent') 'and its intro is no <header> (the one is the site header), and no decoration the form does not carry'
Assert-True ($html -notmatch 'About this repo</h2>' -and $html -match 'href="#overview">Back to overview') 'the facts card is the hub''s, and the card the overview links down to carries the way back'
Assert-True ($html.Contains((Format-RepoHubBanner)) -and ([regex]::Matches($html, 'id="hub-banner"')).Count -eq 1) 'the page carries the hub''s general banner once, as every hub page does (#3356)'
$ix = @('id="hub-banner"', 'class="site-header"', 'class="breadcrumbs-bar"', '<h1>', 'Connected repos</h2>', 'Issues</h2>', 'class="footer-note"') | ForEach-Object { $html.IndexOf($_) }
Assert-True ((@($ix | Where-Object { $_ -lt 0 }).Count -eq 0) -and ((($ix | Sort-Object) -join ',') -eq ($ix -join ','))) 'and its blocks stand in the form''s order'
Assert-True ($html -match '1\.3s|1\.2s') 'the run time is printed with an invariant decimal point'
Assert-Equal 'bwj' (Get-ConnectorOwnerGroup 'BWJ-Development/shop') 'a BWJ-Development repo is in the BWJ group'
Assert-Equal 'dkj' (Get-ConnectorOwnerGroup 'dkj-solutions/hub') 'a DKJ-Solutions repo is in the DKJ group, whatever the case'
Assert-Equal 'other' (Get-ConnectorOwnerGroup 'DaveKJohn/djcylow-react') 'any other owner is Other'
Assert-Equal 'other' (Get-ConnectorOwnerGroup '') 'no slug is Other, not an error'
$three = @(
    @{ Repo = 'Someone/x'; Status = 'bad'; Plugins = @(); Signals = @(); Present = $false; Git = $null },
    @{ Repo = 'DKJ-Solutions/y'; Status = 'good'; Plugins = @(); Signals = @(); Present = $false; Git = $null },
    @{ Repo = 'DKJ-Solutions/w'; Status = 'bad'; Plugins = @(); Signals = @(); Present = $false; Git = $null })
$overview = Format-ConnectorDashboardHtml -Connectors $three -Meta @{ GeneratedAt = 'now' }
Assert-True ($overview -match '<h1>Connectors</h1>' -and $overview -match 'site-header__name">dkj-claude-plugins <span class="site-header__tag">product</span></span>' -and $overview -match '<span aria-current="page">Connectors</span>') 'the overview''s h1 is Connectors, and the site header names this repo''s product, whose page it is (#3540)'
$cD = $overview.IndexOf('href="/connectors/dkj"'); $cB = $overview.IndexOf('href="/connectors/bwj"'); $cO = $overview.IndexOf('href="/connectors/other"')
Assert-True ($cD -ge 0 -and $cD -lt $cB -and $cB -lt $cO) 'the overview has a card per owner group, DKJ, BWJ, Other, each linking its own page (owner, October 26, 2026)'
Assert-Equal 3 ([regex]::Matches($overview, '<section class="card card--link">')).Count 'three cards, in the hub''s card form'
Assert-True ($overview -match '<div class="grid-3" id="groups">' -and $overview -notmatch 'grid__head') 'the cards sit three to a row, with no heading above them'
Assert-True ($overview.Contains('<div class="menu-item__label"><h2 class="menu-item__title">DKJ</h2><span class="menu-item__sub">2 repos &#183; 1 needs action &#183; 1 in sync</span></div>')) 'a card''s label is an h2, its group''s summary under it (owner, October 26, 2026)'
Assert-Equal 3 ([regex]::Matches($overview, '<h2 class="menu-item__title">')).Count 'one h2 per card'
Assert-True ($overview.Contains('<h2 class="menu-item__title">BWJ</h2><span class="menu-item__sub">0 repos</span>')) 'an empty group keeps its card'
Assert-True ($overview -notmatch 'Connected repos</h2>' -and $overview -notmatch '<section class="mini-card' -and $overview -notmatch 'id="issues"') 'the overview holds no table and no repo card: those are the group pages'
Assert-True ($overview -notmatch 'class="tiles"' -and $overview -notmatch 'class="lead"') 'the overview has no tiles and no lead: its h1, then its cards, each carrying its group''s summary (owner, October 26, 2026)'
Assert-True ($html -notmatch 'class="tiles"' -and $html -notmatch 'class="lead"') 'and neither has a group''s page'
$dkj = Format-ConnectorDashboardHtml -Connectors $three -Meta @{ GeneratedAt = 'now' } -Group 'dkj'
Assert-True ($dkj -match '<h1>DKJ repos</h1>' -and $dkj -match '<title>dkj-claude-plugins -- DKJ repos</title>') 'a group page is headed by its group'
Assert-True (([regex]::Matches($dkj, '<section class="mini-card cd-repo-card"')).Count -eq 2 -and $dkj -notmatch 'Someone/x') 'and holds that group''s repos alone'
Assert-True ($dkj.IndexOf('id="repo-dkj-solutions-w"') -lt $dkj.IndexOf('id="repo-dkj-solutions-y"')) 'inside a group, worst first'
Assert-Equal 1 ([regex]::Matches($dkj, '<div class="grid-2" id="overview">\r?\n<div class="grid__head"><h2>Connected repos</h2>')).Count 'the group''s overview is one card, its h2 Connected repos above it (#3175)'
Assert-True ($dkj -match '<table class="table cd-overview" id="overview-dkj">' -and $dkj -match '<th>DKJ repos</th>' -and $dkj -notmatch '<th>Repo</th>' -and $dkj -match '\.cd-overview \{ table-layout: fixed;') 'one fixed-layout table, its group named in its first column head'
$iS = $dkj.IndexOf('<div class="grid-2" id="issues">')
Assert-True ($dkj.IndexOf('id="overview-dkj"') -lt $iS -and $dkj -match '<div id="group-dkj">\r?\n<p class="sub cd-group-summary">2 repos &#183; 1 needs action &#183; 1 in sync</p>' -and $dkj -match '<p class="cd-repo__name">DKJ-Solutions/w</p>' -and $dkj -notmatch '<h3') 'the details sit beside Connected repos: an h2 Issues, the group''s summary line, no h3 repeating the page''s own heading'
Assert-True (([regex]::Matches($dkj, 'class="card grid__full"')).Count -eq 2 -and $dkj -notmatch 'card__head.{0,2}<h2' -and ([regex]::Matches($dkj, '<section class="mini-card cd-repo-card"')).Count -eq 2) 'Connected repos and Issues are a card each, and each repo a house mini-card inside Issues'
$bwj = Format-ConnectorDashboardHtml -Connectors $three -Meta @{ GeneratedAt = 'now' } -Group 'bwj'
Assert-True ($bwj -match '<h1>BWJ repos</h1>' -and $bwj -match 'No repo owned by BWJ-Development is registered' -and $bwj -notmatch 'id="issues"') 'an empty group''s page says so, and has no details card'
Assert-Equal '3 repos &#183; 1 needs action &#183; 2 in sync' (Format-DashboardGroupSummary @(@{ Status = 'good' }, @{ Status = 'bad' }, @{ Status = 'good' })) 'a group summary counts its repos, then each status worst first'
Assert-Equal '1 repo &#183; 1 not on this machine' (Format-DashboardGroupSummary @(@{ Status = 'skip' })) 'one repo is singular'
Assert-Equal '2 repos &#183; 2 need action' (Format-DashboardGroupSummary @(@{ Status = 'bad' }, @{ Status = 'bad' })) 'and several agree with their verb'
Assert-True ($html -match '\.cd-repo__name \{ margin: 0; font-weight: 600; \}' -and $html -notmatch '<h4') 'a repo name is a bold line, not a heading: the house style has no h4 (October 25, 2026)'
Assert-True ($html -notmatch '<th>Errors</th>' -and $html -notmatch '<th>Notes</th>' -and ([regex]::Match($html, '<colgroup>.*?</colgroup>').Value -split '<col ').Count -eq 6) 'the overview has no Errors or Notes column: five columns, five widths'
Assert-True ($html -notmatch '>Main</th>' -and $html -notmatch '>Checkout</th>' -and $html -notmatch 'behind') 'the overview has no Main or Checkout column, and nothing measures a trunk against origin'
$failed = Format-ConnectorDashboardHtml -Connectors @() -Meta @{ GeneratedAt = 'now'; SourceCommit = ''; Seconds = $null; CheckFailed = 'boom <b>' }
Assert-True ($failed -match 'class="msg msg--warn" role="alert"' -and $failed -match 'boom &lt;b&gt;') 'a check that could not run is the form''s warning line, escaped'

Write-Host '-- group 1e: the canonical house style is the copy the skill pins' -ForegroundColor Cyan

# History (#2989): a repoint of the skill to a new tag once left two vendored files on the old one, and
# nothing noticed. There is now one canonical copy, in the plugin (#3130); the skill's table is still the
# one place the checksums live, so the copy is held to it.
$skillPage = Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions\skills\house-style\SKILL.md') -Raw
foreach ($file in 'house-style.css', 'house-theme.js') {
    $row = [regex]::Match($skillPage, '(?m)^\| `' + [regex]::Escape($file) + '` \|.*\| `([0-9a-f]{64})` \|\s*$')
    Assert-True $row.Success "the skill's table pins a sha256 for $file"
    if (-not $row.Success) { continue }
    $actual = (Get-FileHash -LiteralPath (Join-Path $RepoRoot "plugins\dkj-policy\assets\house-style\$file") -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Equal $row.Groups[1].Value $actual "the canonical $file hashes to the skill's pinned sha256"
}

Write-Host '-- group 2: the server answers on loopback only to itself' -ForegroundColor Cyan

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Host '  [SKIP] group 2 needs Windows PowerShell' -ForegroundColor Yellow
} else {
    $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $port = $probe.LocalEndpoint.Port; $probe.Stop()
    # This server reads the REAL checkout's state file, so on a machine whose hook started this checkout's
    # general pages server it would relay to it (#3168). A port nobody answers on keeps it out of the run.
    $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $env:DKJ_GENERAL_PAGES_PORTS = [string]$probe.LocalEndpoint.Port; $probe.Stop()
    $proc = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Server`"", '-Port', $port)
    try {
        # THE TWO WINDOWS BELOW ARE WIDE ON PURPOSE (#3038). Both groups failed on a loaded CI shard and
        # passed on a rerun. Measured unloaded: the server is up in ~0.6s, a request behind a silent
        # connection takes ~1.0s (the server's 1s deadline), and group 3's cold page ~0.5s -- against a
        # 3s read window, a 3x margin that 4 lanes of suites can eat. No assert here measures time with
        # these windows, so widening them costs a failing run time and a passing run nothing: a server
        # that DOES stall still returns no answer inside 15s, because the stalling client stays open
        # until after its assert.
        function Wait-ServerUp([int]$OnPort) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.ElapsedMilliseconds -lt 30000) {
                Start-Sleep -Milliseconds 250
                $t = New-Object System.Net.Sockets.TcpClient
                try { $t.Connect('127.0.0.1', $OnPort); return $true } catch { } finally { $t.Close() }
            }
            return $false
        }
        $up = Wait-ServerUp $port
        Assert-True $up 'the server listens on the port it was given'

        $group2Ran = $true
        function Get-Raw([string]$Method, [string]$Path, [string]$HostHeader, [string]$Extra = '', [int]$OnPort = $port) {
            $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $OnPort)
            $c.ReceiveTimeout = 15000
            try {
                $s = $c.GetStream()
                $req = [System.Text.Encoding]::ASCII.GetBytes("$Method $Path HTTP/1.1`r`nHost: $HostHeader`r`n$Extra`r`n")
                $s.Write($req, 0, $req.Length)
                return (New-Object System.IO.StreamReader($s)).ReadToEnd()
            } catch { return '' } finally { $c.Close() }
        }
        function Get-Status([string]$Method, [string]$Path, [string]$HostHeader, [string]$Extra = '') {
            $raw = Get-Raw $Method $Path $HostHeader $Extra
            return [int]((($raw -split "`r`n")[0] -split ' ')[1])
        }
        if ($up) {
            Assert-Equal 200 (Get-Status 'GET' '/house-style.css' "localhost:$port") 'the stylesheet is served'
            Assert-Equal 200 (Get-Status 'GET' '/house-theme.js' "127.0.0.1:$port") 'the theme script is served'
            Assert-Equal 403 (Get-Status 'GET' '/house-style.css' "evil.example:$port") 'a foreign Host is refused'
            Assert-Equal 405 (Get-Status 'POST' '/' "localhost:$port") 'a POST is refused'
            Assert-Equal 405 (Get-Status 'POST' '/stopwatch/start?label=x' "localhost:$port" "Sec-Fetch-Site: same-origin`r`n") 'the Stopwatch takes no POST any more (#3323)'
            # THE GENERAL PAGES ARE THE PLUGIN HUB'S (#3540): this server is the product, so it neither builds nor relays them.
            foreach ($general in '/stopwatch', '/logbook', '/test-gate', '/plugins', '/repository', '/artifacts', '/issues', '/sessionstart', '/release-notes', '/about') {
                Assert-Equal 404 (Get-Status 'GET' $general "localhost:$port") "$general is no page of the product: it is the plugin hub's"
            }
            Assert-Equal 404 (Get-Status 'GET' '/../connectors/x.json' "localhost:$port") 'a path outside the routes is not found'
            # The brandbook app is retired (#3493): the product neither serves nor redirects it, and the house style's specimens are under the hub's /plugins.
            Assert-Equal 404 (Get-Status 'GET' '/brandbook' "localhost:$port") '/brandbook is not a page of the product'
            Assert-Equal 404 (Get-Status 'GET' '/brandbook/' "localhost:$port") 'and neither is /brandbook/'
            Assert-Equal 404 (Get-Status 'GET' '/house-style' "localhost:$port") 'and no /house-style either: the house style is the dkj-solutions plugin''s, under the hub''s /plugins (#3493)'
            # Whose server this is: the general server's own question, answered the same way.
            $who = Get-Raw 'GET' '/whoami' "localhost:$port"
            Assert-True ($who -match 'HTTP/1.1 200' -and $who.EndsWith("`r`n`r`n" + (Get-DevPreviewRootHash -Root $RepoRoot))) '/whoami answers the hash of this root, as the general server does'
            Assert-Equal 303 (Get-Status 'GET' '/refresh' "localhost:$port") '/refresh redirects to the page'
            Assert-True ((Get-Raw 'GET' '/refresh?page=connectors' "localhost:$port") -match 'Location: /connectors\r') '/refresh?page= goes back to the page that asked'
            Assert-True ((Get-Raw 'GET' '/refresh?page=connectors/bwj' "localhost:$port") -match 'Location: /connectors/bwj\r') 'and to a Connectors group page that asked (owner, October 26, 2026)'
            Assert-Equal 404 (Get-Status 'GET' '/connectors/nope' "localhost:$port") 'a Connectors group no owner has is not found'
            Assert-True ((Get-Raw 'GET' '/refresh?page=sessionstart' "localhost:$port") -match 'Location: /\r') 'and a general page''s refresh is no page of the product''s (#3540)'
            Assert-True ((Get-Raw 'GET' '/refresh?page=//evil.example' "localhost:$port") -match 'Location: /\r') 'and to the index for a page outside its list'
            Assert-Equal 403 (Get-Status 'GET' '/refresh' "localhost:$port" "Sec-Fetch-Site: cross-site`r`n") 'a request another site makes is refused'
            # A HEAD answers like the GET would, real Content-Length included, and carries no body (#3161).
            $cssLength = (Get-Item -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\assets\house-style\house-style.css')).Length
            $headRaw = Get-Raw 'HEAD' '/house-style.css' "localhost:$port"
            Assert-True ($headRaw -match "Content-Length: $cssLength\r" -and $headRaw.EndsWith("`r`n`r`n")) 'HEAD on a static file sends the real Content-Length and no body'
            $head404 = Get-Raw 'HEAD' '/nope' "localhost:$port"
            Assert-True ($head404 -match 'HTTP/1.1 404' -and $head404 -notmatch 'Content-Length: 0\r' -and $head404.EndsWith("`r`n`r`n")) 'HEAD on a non-200 route sends no body either'
            $head403 = Get-Raw 'HEAD' '/' "evil.example:$port"
            Assert-True ($head403 -match 'HTTP/1.1 403' -and $head403.EndsWith("`r`n`r`n")) 'nor does a refused HEAD'
            $silent = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port)
            Assert-Equal 200 (Get-Status 'GET' '/house-theme.js' "localhost:$port") 'a connection that sends nothing does not stall the next one'
            $silent.Close()
            # A client that drips one byte at a time stays under any per-read timeout; one deadline drops it.
            $drip = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port)
            $dripStream = $drip.GetStream()
            # Drip past the server's 1s deadline and keep the connection OPEN: without the deadline the loop
            # would still be reading it, and the next request would get no answer (Get-Raw gives up at 15s).
            try { for ($i = 0; $i -lt 20; $i++) { $dripStream.WriteByte(71); $dripStream.Flush(); Start-Sleep -Milliseconds 100 } } catch { }
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Assert-Equal 200 (Get-Status 'GET' '/house-theme.js' "localhost:$port") 'a dripping client is cut off by one deadline, and the next one is answered'
            Assert-True ($sw.ElapsedMilliseconds -lt 2000) 'without waiting for the dripping client'
            $drip.Close()
            $big = Get-Raw 'GET' '/house-theme.js' "localhost:$port" ("X-Pad: " + ('a' * 9000) + "`r`n")
            Assert-True ($big -notmatch 'HTTP/1.1 200') 'a request head over 8 KB gets no answer'
        }
    } finally {
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
    }
}

Write-Host '-- group 3: the page survives a checkout with no upstream and a check that cannot run' -ForegroundColor Cyan

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and (Get-Command git -ErrorAction SilentlyContinue) -and $group2Ran) {
    # Layout: <fixture>\org\src is the repo root, so the scope root is <fixture>. <fixture>\org\noup holds
    # a commit and no upstream, which made 'rev-list HEAD...@{u}' throw under 'Stop' and blanked the page
    # (#2976 review). <outside> is a git repo beyond the scope root that one manifest points at. The fixture
    # carries no check-connectors.ps1, so the check's failure path is exercised too.
    $fixture = Join-Path ([System.IO.Path]::GetTempPath()) "connector-dashboard-$PID-$([guid]::NewGuid().ToString('n'))"
    $src = Join-Path $fixture 'org\src'
    $noup = Join-Path $fixture 'org\noup'
    $outside = Join-Path ([System.IO.Path]::GetTempPath()) "connector-dashboard-outside-$PID-$([guid]::NewGuid().ToString('n'))"
    $group3Done = $false
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $src 'scripts\lib'), (Join-Path $src 'scripts\dashboard'),(Join-Path $src 'plugins\dkj-policy\assets\house-style'), (Join-Path $src 'connectors'), $noup, $outside | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $src 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $src 'scripts\lib\')
        # dev-pages-lib reads the plugins' libs from the plugin tree beside scripts/, and the server its state reader.
        New-Item -ItemType Directory -Force -Path (Join-Path $src 'plugins\dkj-policy\hub\lib') | Out-Null
        Copy-Item (Join-Path $PluginLib '*.ps1') (Join-Path $src 'plugins\dkj-policy\hub\lib\')
        Copy-Item $Server (Join-Path $src 'scripts\dashboard\')
        Set-Content -LiteralPath (Join-Path $src 'connectors\noup.json') -Encoding ASCII -Value '{ "repo": "Org/noup", "visibility": "private", "localCheckout": "../noup", "plugins": [] }'
        Set-Content -LiteralPath (Join-Path $src 'connectors\far.json') -Encoding ASCII -Value ('{ "repo": "Org/far", "visibility": "public", "localCheckout": "../../../' + (Split-Path -Leaf $outside) + '", "plugins": [] }')
        & git -C $noup init -q 2>$null
        & git -C $noup -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'local only' 2>$null
        & git -C $outside init -q 2>$null

        $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
        $probe.Start(); $port3 = $probe.LocalEndpoint.Port; $probe.Stop()
        # The general pages server's port for this fixture, on the test override the servers inherit (#3119):
        # the real 4890-4899 is never touched, and the state file's pages url is believed only on that port.
        $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
        $probe.Start(); $genPort3 = $probe.LocalEndpoint.Port; $probe.Stop()
        $env:DKJ_GENERAL_PAGES_PORTS = [string]$genPort3
        $proc3 = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $src 'scripts\dashboard\serve-connector-dashboard.ps1')`"", '-Port', $port3)
        try {
            # Asserted on its own, so a recurrence says whether the server never came up or the page did not
            # come back -- the question #3038 could not answer from four asserts failing together.
            $up = Wait-ServerUp $port3
            Assert-True $up 'the group-3 server listens on the port it was given'
            # The fixture's repos are all Org/*, so their details are on the Other group's page (owner, October 26, 2026).
            $page = if ($up) { Get-Raw 'GET' '/connectors/other' "localhost:$port3" '' $port3 } else { '' }
            $overviewPage = if ($up) { Get-Raw 'GET' '/connectors' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($page -match 'HTTP/1.1 200') 'the page is served with a checkout that has no upstream'
            Assert-True ($page -match 'Last commit on (master|main) [^:]*: local only') 'and that checkout shows its trunk''s last commit'
            Assert-True ($page -match 'class="msg msg--warn"') 'a check that could not run is reported, not fatal'
            $at = $page.IndexOf('id="repo-org-far"')
            $far = if ($at -ge 0) { $page.Substring($at, $page.IndexOf('</section>', $at) - $at) } else { '' }
            Assert-True ($far -and $far -notmatch 'class="meta"') 'a checkout outside the scope root is not read'
            # THE PRODUCT (#3540): the general pages are the plugin hub's, so this server neither relays nor builds them.
            foreach ($moved in '/artifacts', '/issues', '/sessionstart', '/release-notes', '/test-gate', '/repository') {
                $r = if ($up) { Get-Raw 'GET' $moved "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 404' -and $r -match 'Not found\.') "$moved is a plain 404: it is the plugin hub's page, not the product's"
            }
            $srcState = Get-RepoHubStatePath -Root $src
            # The product's home page on '/' and the pages under it (#3540).
            $home3 = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($home3 -match 'HTTP/1.1 200' -and $home3 -match 'site-header__name">dkj-claude-plugins <span class="site-header__tag">product</span>' -and $home3 -match 'href="/connectors"' -and $home3 -match 'href="/specialists"' -and $home3 -notmatch 'href="/dkj-repos"') '/ serves the product''s home page, linking Connectors and Specialists'
            $r = if ($up) { Get-Raw 'GET' '/dkj-repos' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($r -match 'HTTP/1.1 303' -and $r -match 'Location: /connectors/dkj\r') 'the old /dkj-repos sends an old link to /connectors/dkj, which holds the repos on GitHub since #3549'
            Assert-True ($home3 -match 'The toolbox is not running' -and $home3 -notmatch 'href="http://localhost' -and $home3 -notmatch 'href="/brandbook' -and $home3 -notmatch 'href="/test-gate"') 'with no state file it says the hub is not running, and links no general page of its own'
            $r = if ($up) { Get-Raw 'GET' '/hub' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($r -match 'HTTP/1.1 404' -and $r -match 'toolbox is not running') 'and /hub is a 404 text, never a redirect to a port nobody answers on'
            # A state file naming a port nobody answers on is no hub.
            Write-RepoHubState -Root $src -Hub "http://localhost:$genPort3/" -Pages "http://localhost:$genPort3" -Product "http://localhost:$port3/" -Mode 'product'
            $r = if ($up) { Get-Raw 'GET' '/hub' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($r -match 'HTTP/1.1 404') 'a state file naming a port where nothing answers is no hub: a 404 text, not a redirect'
            # The real plugin hub for this fixture, which answers /whoami with this root's hash.
            $gen3 = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$GeneralServer`"", '-Port', $genPort3, '-RepoRootOverride', "`"$src`"",
                '-StopwatchPath', "`"$(Join-Path $fixture 'timing\stopwatch.json')`"", '-LogbookPath', "`"$(Join-Path $fixture 'timing\logbook.json')`"", '-TranscriptDir', "`"$(Join-Path $fixture 'timing\transcripts')`"")
            try {
                Assert-True (Wait-ServerUp $genPort3) 'the fixture''s plugin hub listens'
                Assert-True ((Get-Raw 'GET' '/brandbook' "localhost:$genPort3" '' $genPort3) -match 'HTTP/1.1 404') 'the plugin hub serves no Brandbook (#3475)'
                $homeUp = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($homeUp -match ('<a class="menu-item" href="http://localhost:' + $genPort3 + '">') -and $homeUp -notmatch 'toolbox is not running') 'the home page''s first card links the plugin hub, once it answers as this checkout''s'
                $r = if ($up) { Get-Raw 'GET' '/hub' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 303' -and $r -match ('Location: http://localhost:' + $genPort3 + '\r')) 'and /hub sends the visitor there'
                $hubHome = Get-Raw 'GET' '/' "localhost:$genPort3" '' $genPort3
                Assert-True ($hubHome -match 'HTTP/1.1 200' -and $hubHome -match ('href="http://localhost:' + $port3 + '/"')) 'the plugin hub links the product in turn, from the state file (#3245)'
                # THE BROWSER'S OWN HEADERS (#3119): ports do not count toward "site", so the hub's link to the product
                # arrives same-site -- a top-level navigation. A fetch or a cross-site request does not get in.
                $nav = "Sec-Fetch-Site: same-site`r`nSec-Fetch-Mode: navigate`r`nSec-Fetch-Dest: document`r`n"
                $r = Get-Raw 'GET' '/' "localhost:$port3" $nav $port3
                Assert-True ($r -match 'HTTP/1.1 200' -and $r -match '<title>dkj-claude-plugins -- Home</title>') 'a same-site navigation from the hub to the product is served'
                $r = Get-Raw 'GET' '/connectors' "localhost:$port3" "Sec-Fetch-Site: same-site`r`nSec-Fetch-Mode: cors`r`n" $port3
                Assert-True ($r -match 'HTTP/1.1 403') 'a same-site fetch is still refused'
                $r = Get-Raw 'GET' '/' "localhost:$port3" "Sec-Fetch-Site: cross-site`r`nSec-Fetch-Mode: navigate`r`n" $port3
                Assert-True ($r -match 'HTTP/1.1 403') 'and so is a cross-site navigation'
            } finally {
                if (-not $gen3.HasExited) { Stop-Process -Id $gen3.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
                $gen3.WaitForExit(5000) | Out-Null
            }
            $homeDown = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($homeDown -match 'HTTP/1.1 200' -and $homeDown -match 'The toolbox is not running') 'and the Toolbox card is back to not running once nothing answers there'
            Remove-Item -LiteralPath $srcState -Force -ErrorAction SilentlyContinue
            Assert-True ($overviewPage -match 'HTTP/1.1 200' -and $overviewPage -match '<h1>Connectors</h1>' -and $overviewPage -match '<a href="/">Home</a>' -and $overviewPage -match 'href="/connectors/other"') '/connectors serves the overview as a page under the product''s home, linking each group''s page'
            Assert-True ($page -match '<h1>Other repos</h1>' -and $page -match '<a href="/connectors">Connectors</a>') '/connectors/other serves that group''s page under the overview'
        } finally {
            if (-not $proc3.HasExited) { Stop-Process -Id $proc3.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
        }
        $group3Done = $true
    } finally {
        Remove-Item Env:\DKJ_GENERAL_PAGES_PORTS -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $fixture, $outside -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    $group3Done = $null
    Write-Host '  [SKIP] group 3 needs Windows PowerShell, git and group 2' -ForegroundColor Yellow
}
# A STATEMENT-TERMINATING ERROR ENDS THE GROUP IN SILENCE (#3137). An IOException from a fixture step (Copy-Item
# into a directory the fixture never made) aborts the whole top-level `if` even under 'Continue', the script goes
# on with the next statement, and the suite read green with not one of the group's asserts run.
if ($null -ne $group3Done) { Assert-True $group3Done 'group 3 ran to its end -- no fixture step aborted it (#3137)' }

Write-Host '-- group 4: a server whose checkout moved restarts itself on the new commit (#3122)' -ForegroundColor Cyan

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and (Get-Command git -ErrorAction SilentlyContinue) -and $group2Ran) {
    # Measured October 18, 2026: the hook started the server, a pull moved HEAD four seconds later, and the
    # server kept serving the old pages while its "Source at" line read the new commit live.
    $fixture4 = Join-Path ([System.IO.Path]::GetTempPath()) "connector-dashboard-move-$PID-$([guid]::NewGuid().ToString('n'))"
    $port4 = $null
    $group4Done = $false
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture4 'scripts\lib'), (Join-Path $fixture4 'scripts\dashboard'),(Join-Path $fixture4 'plugins\dkj-policy\assets\house-style') | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture4 'plugins\dkj-policy\hub\lib') | Out-Null
        Copy-Item (Join-Path $PluginLib '*.ps1') (Join-Path $fixture4 'plugins\dkj-policy\hub\lib\')
        Copy-Item $Server (Join-Path $fixture4 'scripts\dashboard\')
        # The stylesheet is there and the theme script is not: a present and a missing static file side by side.
        [System.IO.File]::WriteAllText((Join-Path $fixture4 'plugins\dkj-policy\assets\house-style\house-style.css'), 'body{}')
        & git -C $fixture4 init -q 2>$null
        & git -C $fixture4 -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'first' 2>$null
        $first = ([string](& git -C $fixture4 rev-parse HEAD)).Trim()

        $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
        $probe.Start(); $port4 = $probe.LocalEndpoint.Port; $probe.Stop()
        $proc4 = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $fixture4 'scripts\dashboard\serve-connector-dashboard.ps1')`"", '-Port', $port4)
        $up = Wait-ServerUp $port4
        Assert-True $up 'the group-4 server listens on the port it was given'
        $hub = if ($up) { Get-Raw 'GET' '/' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match "<code>$($first.Substring(0, 8))</code>") 'the home page''s footer names the commit the server loaded'
        # Measured October 19, 2026: a server started before #3130 moved the house style threw on the file it
        # could no longer find, and the browser saw a dropped connection instead of a stylesheet.
        $gone = if ($up) { Get-Raw 'GET' '/house-theme.js' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($gone -match 'HTTP/1.1 404' -and $gone -match 'house-theme.js is not where this server looks') 'a missing static file is a 404, not a dropped connection'

        & git -C $fixture4 -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'second' 2>$null
        $second = ([string](& git -C $fixture4 rev-parse HEAD)).Trim()
        $css = if ($up) { Get-Raw 'GET' '/house-style.css' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($css -match 'HTTP/1.1 200') 'a static file that is there skips the check'
        $moved = if ($up) { Get-Raw 'GET' '/house-theme.js' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($moved -match 'HTTP/1.1 503' -and $moved -match 'restarting on the new code') 'a missing one, after HEAD moved, restarts the server'
        Assert-True ($proc4.WaitForExit(15000)) 'and the old server exits'
        $up = Wait-ServerUp $port4
        Assert-True $up 'its successor listens on the same port'
        $hub = if ($up) { Get-Raw 'GET' '/' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match "<code>$($second.Substring(0, 8))</code>") 'and serves the new commit'
        $succ = @(Get-NetTCPConnection -State Listen -LocalPort $port4 -ErrorAction SilentlyContinue | ForEach-Object { $_.OwningProcess })
        & git -C $fixture4 -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'third' 2>$null
        $page = if ($up) { Get-Raw 'GET' '/' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($page -match 'HTTP/1.1 503' -and $page -match 'Refresh: 3' -and $page -match 'restarting on the new code') 'a page asked for after HEAD moved answers 503 and reloads'
        # Wait for the second successor before the finally looks for it by port (#3200): looked for straight after
        # the 503 it had not bound yet, so it was never stopped and kept its fixture directory alive.
        foreach ($s in $succ) { Wait-Process -Id $s -Timeout 15 -ErrorAction SilentlyContinue }
        $up = if ($up) { Wait-ServerUp $port4 } else { $false }
        $owner = @(Get-NetTCPConnection -State Listen -LocalPort $port4 -ErrorAction SilentlyContinue | ForEach-Object { $_.OwningProcess })
        Assert-True ($up -and $succ.Count -gt 0 -and $owner.Count -gt 0 -and -not @($owner | Where-Object { $succ -contains $_ }).Count) 'and its own successor, a new process, takes the port in turn'
        $group4Done = $true
    } finally {
        if ($proc4 -and -not $proc4.HasExited) { Stop-Process -Id $proc4.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
        # The successor is detached; it is found by the port it holds.
        if ($port4) {
            foreach ($o in @(Get-NetTCPConnection -State Listen -LocalPort $port4 -ErrorAction SilentlyContinue | ForEach-Object { $_.OwningProcess })) {
                Stop-Process -Id $o -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        # And whatever still runs from the fixture -- a successor that had not bound yet when the group aborted. Twice,
        # because a server stopped mid-restart may already have started the cmd.exe that starts the next one.
        foreach ($sweep in 1, 2) {
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($fixture4) } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -Confirm:$false -ErrorAction SilentlyContinue }
            Start-Sleep -Milliseconds 500
        }
        Remove-Item -LiteralPath $fixture4 -Recurse -Force -ErrorAction SilentlyContinue
        if ($port4) { Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter "serve-connector-dashboard-$port4-*.log" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
    }
} else {
    $group4Done = $null
    Write-Host '  [SKIP] group 4 needs Windows PowerShell, git and group 2' -ForegroundColor Yellow
}
if ($null -ne $group4Done) { Assert-True $group4Done 'group 4 ran to its end -- no fixture step aborted it (#3137)' }

# --- Repo sessions (#3231): which repo a loose name means, and the command that opens Claude Code there ---
Write-Host "`n[Repo sessions: name resolution and the session command]"
$regs = @(
    @{ Repo = 'DKJ-Solutions/dkj-lifehub'; File = 'life-hub.json' },
    @{ Repo = 'DKJ-Solutions/dkj-thumbnail-generator'; File = 'thumbnail-generator.json' },
    @{ Repo = 'DKJ-Solutions/dkj-recipes'; File = 'recipes.json' },
    @{ Repo = 'DKJ-Solutions/dkj-music-library'; File = 'music-library.json' }
)
foreach ($n in 'lifehub', 'life-hub', 'dkj-lifehub', 'DKJ-Solutions/dkj-lifehub', 'LIFEHUB', 'life-hub.json') {
    $hit = @(Resolve-ConnectorRepo -Connectors $regs -Name $n)
    Assert-True ($hit.Count -eq 1 -and $hit[0].Repo -eq 'DKJ-Solutions/dkj-lifehub') "'$n' names dkj-lifehub"
}
$hit = @(Resolve-ConnectorRepo -Connectors $regs -Name 'thumb')
Assert-True ($hit.Count -eq 1 -and $hit[0].Repo -eq 'DKJ-Solutions/dkj-thumbnail-generator') 'a part of a name names the one repo containing it'
Assert-True (@(Resolve-ConnectorRepo -Connectors $regs -Name 'r').Count -ge 2)'an ambiguous part returns every match, so the caller can refuse it'
Assert-Equal 0 (@(Resolve-ConnectorRepo -Connectors $regs -Name 'nothing-like-it').Count) 'an unknown name matches nothing'
Assert-Equal 0 (@(Resolve-ConnectorRepo -Connectors $regs -Name '--').Count) 'a name of punctuation alone matches nothing'

Assert-Equal "'a''b'" (ConvertTo-PowerShellLiteral "a'b") 'a straight single quote is doubled'
$curly = 'dossier' + [char]0x2019 + 's'
Assert-Equal ("'dossier" + [char]0x2019 + [char]0x2019 + "s'") (ConvertTo-PowerShellLiteral $curly) 'a typographic single quote is doubled too'
# The decisive check: what PowerShell itself reads back from the literal is the original text.
foreach ($v in "it's", $curly, ([char]0x2018 + 'x' + [char]0x201B), '$(Remove-Item x); `n', '') {
    $back = Invoke-Expression (ConvertTo-PowerShellLiteral $v)
    Assert-Equal $v $back "PowerShell reads the literal of '$v' back unchanged"
}
Assert-Equal "Set-Location -LiteralPath 'C:\x\dkj-lifehub'; claude" (Format-RepoSessionCommand -Path 'C:\x\dkj-lifehub') 'the command without a prompt'
Assert-Equal "Set-Location -LiteralPath 'C:\x\o''b'; claude 'start it''s dossier'" (Format-RepoSessionCommand -Path "C:\x\o'b" -Prompt "start it's dossier") 'the command quotes the path and the prompt'

# repo-session.ps1 against a fixture tree: the register resolves, a missing checkout is refused, -WhatIf runs nothing.
$rsRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('repo-session-' + [guid]::NewGuid().ToString('n'))
$rsHub = Join-Path $rsRoot 'org\hub'
New-Item -ItemType Directory -Force -Path (Join-Path $rsHub 'connectors'), (Join-Path $rsHub 'scripts\lib'), (Join-Path $rsRoot 'org\dkj-lifehub') | Out-Null
# repo-session.ps1 loads the hub's page lib, which loads the connector lib and the plugin libs beside it
# (dev-preview-rules.ps1 for the Product card's url rule, #3468; test-gate-lib.ps1, the Test gate's page, #3470).
foreach ($lib in 'scripts\lib\connector-dashboard-lib.ps1', 'scripts\lib\dev-pages-lib.ps1', 'plugins\dkj-policy\hub\lib\general-pages-lib.ps1', 'plugins\dkj-policy\hub\lib\dev-preview-rules.ps1', 'plugins\dkj-policy\hub\lib\test-gate-lib.ps1') {
    $to = Join-Path $rsHub (Split-Path -Parent $lib)
    New-Item -ItemType Directory -Force -Path $to | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot $lib) -Destination $to
}
Set-Content -LiteralPath (Join-Path $rsHub 'connectors\life-hub.json') -Encoding UTF8 -Value '{ "repo": "DKJ-Solutions/dkj-lifehub", "visibility": "private", "localCheckout": ["../dkj-lifehub", "../life-hub"] }'
Set-Content -LiteralPath (Join-Path $rsHub 'connectors\recipes.json') -Encoding UTF8 -Value '{ "repo": "DKJ-Solutions/dkj-recipes", "visibility": "private", "localCheckout": "../dkj-recipes" }'
Set-Content -LiteralPath (Join-Path $rsHub 'connectors\escape.json') -Encoding UTF8 -Value '{ "repo": "DKJ-Solutions/escape", "visibility": "public", "localCheckout": "../../../../.." }'
$rsScript = Join-Path $RepoRoot 'scripts\dashboard\repo-session.ps1'
$run = { param([string[]]$a) $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $rsScript @a -RepoRootOverride $rsHub 2>&1 | ForEach-Object { [string]$_ }; @{ Out = ($o -join "`n"); Code = $LASTEXITCODE } }
try {
    $r = & $run @('lifehub', '-Open', '-WhatIf', '-Prompt', 'Start a dossier')
    $expected = Format-RepoSessionCommand -Path ([System.IO.Path]::GetFullPath((Join-Path $rsRoot 'org\dkj-lifehub'))) -Prompt 'Start a dossier'
    Assert-True ($r.Code -eq 0 -and $r.Out.Trim() -eq $expected) '-WhatIf prints the command for the checkout the register resolves, and starts nothing'
    $r = & $run @('recipes', '-IssueLimit', '0')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'no checkout on this machine') 'a repo with no checkout is refused'
    $r = & $run @('escape', '-IssueLimit', '0')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'no checkout on this machine') 'a localCheckout outside the scope root is never resolved'
    $r = & $run @('dkj', '-IssueLimit', '0')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'more than one') 'an ambiguous name is refused with the candidates'
    # Written as \" because Windows PowerShell 5.1 drops a bare double quote on the way to the child process.
    $r = & $run @('lifehub', '-Open', '-WhatIf', '-Prompt', 'say \"hi\"')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'double quote') 'a prompt with a double quote is refused'
    $r = & $run @('lifehub', '-Open', '-WhatIf', '-Prompt', ' --dangerously-skip-permissions')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'opens with') 'a prompt that opens with a dash is refused, so it never reaches claude as an option'
    $r = & $run @('lifehub', '-Open', '-WhatIf', '-Prompt', ('x' * 8001))
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'under 8000') 'a prompt too long for the command line is refused'
    $r = & $run @('lifehub', '-IssueLimit', '0')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'not a git checkout' -and $r.Out -match 'gh issue create --repo DKJ-Solutions/dkj-lifehub') 'the status names the checkout and where an issue for it is filed'
    $r = & $run @('-List')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'dkj-recipes\s+private\s+\(not checked out') '-List names a repo with no checkout as such'
} finally {
    Remove-Item -LiteralPath $rsRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "connector-dashboard: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
