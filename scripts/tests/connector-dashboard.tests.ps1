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
    the dkj-solutions general pages server (#3119): the hub's General card before and after a state file
    names a server that answers, and the relayed answer or the 404 each of those routes gets (#3168).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Server   = Join-Path $RepoRoot 'scripts\dashboard\serve-connector-dashboard.ps1'
. (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1')
# The state file's reader and writer, which the server and these fixtures share (#3119).
$PluginLib = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions\scripts\lib'
$GeneralServer = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions\scripts\pages\serve-general-pages.ps1'
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
$html = Format-ConnectorDashboardHtml -Connectors $connectors -Meta @{ GeneratedAt = 'now'; SourceCommit = 'abc1234'; Seconds = 1.25; CheckFailed = $null }
Assert-True ($html -notmatch '<script>alert') 'a git subject is shown as text, never as markup'
Assert-True ($html -match '&lt;script&gt;alert') 'and it is still shown'
Assert-True ($html -match 'a&quot;note') 'the register notes are escaped too'
Assert-True ($html -match 'Last commit on main 2 days ago: ' -and $html -notmatch 'feat/y') 'the card states the trunk''s last commit, never the checked-out branch'
Assert-True ($html -match 'not on this machine') 'an absent checkout says so'
Assert-True ($html.IndexOf('id="repo-org-beta"') -lt $html.IndexOf('id="repo-org-gamma"')) 'a repo that needs action comes before a skipped one'
Assert-True ($html -match 'href="/house-style.css"' -and $html -match 'src="/house-theme.js"') 'the page loads the house style from its own server'
Assert-True ($html -match 'DKJTheme\.settings\(' -and $html -notmatch 'DKJTheme\.picker\(') 'the theme choice is the house settings button, not a hand-built picker card'
Assert-True ($html -match '<div id="settings" class="theme-settings--floating">') 'the settings button floats fixed top right, outside the header'
Assert-True (([regex]::Matches($html, 'var\(--primary')).Count -ge 6 -and $html -match 'class="cd-link"') 'the chosen theme reaches the page beyond its buttons, through the repo layer''s own --primary accents'
Assert-True ($html -match '<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>' -and $html -match '<h1>Connectors</h1>' -and $html -match '<main class="page-column">') 'the page keeps the Repo hub frame: the slug as eyebrow, its own h1, the page column (#3066, #3097)'
Assert-True ($html -match '<body>\s*<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>\s*<li><a href="/">Repo hub</a></li>\s*<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">Connectors</span></li>') 'the breadcrumb bar opens <body>, its trail from the Repo hub to Connectors (#3090, #3097)'
Assert-True ($html -notmatch '<header' -and $html -notmatch 'cd-band|cd-accent') 'and its intro is no <header>, and no decoration the form does not carry'
Assert-True ($html -notmatch 'About this repo</h2>' -and $html -match 'href="#overview">Back to overview') 'the facts card is the hub''s, and the card the overview links down to carries the way back'
$ix = @('class="eyebrow"', 'class="tiles"', 'Connected repos</h2>', 'Issues</h2>', 'class="footer-note"') | ForEach-Object { $html.IndexOf($_) }
Assert-True ((@($ix | Where-Object { $_ -lt 0 }).Count -eq 0) -and ((($ix | Sort-Object) -join ',') -eq ($ix -join ','))) 'and its blocks stand in the form''s order'
Assert-True ($html -match '1\.3s|1\.2s') 'the run time is printed with an invariant decimal point'
Assert-Equal 'bwj' (Get-ConnectorOwnerGroup 'BWJ-Development/shop') 'a BWJ-Development repo is in the BWJ group'
Assert-Equal 'dkj' (Get-ConnectorOwnerGroup 'dkj-solutions/hub') 'a DKJ-Solutions repo is in the DKJ group, whatever the case'
Assert-Equal 'other' (Get-ConnectorOwnerGroup 'DaveKJohn/djcylow-react') 'any other owner is Other'
Assert-Equal 'other' (Get-ConnectorOwnerGroup '') 'no slug is Other, not an error'
$grouped = Format-ConnectorDashboardHtml -Connectors @(
    @{ Repo = 'Someone/x'; Status = 'bad'; Plugins = @(); Signals = @(); Present = $false; Git = $null },
    @{ Repo = 'DKJ-Solutions/y'; Status = 'good'; Plugins = @(); Signals = @(); Present = $false; Git = $null },
    @{ Repo = 'BWJ-Development/z'; Status = 'good'; Plugins = @(); Signals = @(); Present = $false; Git = $null }) -Meta @{ GeneratedAt = 'now' }
$iB = $grouped.IndexOf('id="group-bwj"'); $iD = $grouped.IndexOf('id="group-dkj"'); $iO = $grouped.IndexOf('id="group-other"')
Assert-True ($iB -ge 0 -and $iB -lt $iD -and $iD -lt $iO) 'the groups come BWJ, DKJ, Other -- owner order beats status order'
Assert-True ($iO -lt $grouped.IndexOf('id="repo-someone-x"')) 'a repo sits under its own group heading'
Assert-True ($grouped -match '<h1>Connectors</h1>' -and $grouped -match '<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>') 'the h1 is Connectors, and the eyebrow this repo''s slug (#3066, #3097)'
Assert-Equal 1 ([regex]::Matches($grouped, '<div class="grid-2" id="overview">\r?\n<div class="grid__head"><h2>Connected repos</h2>')).Count 'the overview stays one card, its h2 Connected repos above it (#3175)'
$oB = $grouped.IndexOf('id="overview-bwj"'); $oD = $grouped.IndexOf('id="overview-dkj"'); $oO = $grouped.IndexOf('id="overview-other"')
Assert-True ($grouped.IndexOf('<h2>Connected repos</h2>') -lt $oB -and $oB -lt $oD -and $oD -lt $oO -and $oO -lt $iB) 'inside Connected repos a table per group, BWJ, DKJ, Other, before the Status cards'
Assert-True ($grouped -notmatch '<h3[^>]*id="overview-' -and $grouped -match '<th>BWJ repos</th>' -and $grouped -match '<th>DKJ repos</th>' -and $grouped -match '<th>Other repos</th>' -and $grouped -notmatch '<th>Repo</th>') 'no h3 over the tables: each table names its group in its first column head'
$tables = [regex]::Matches($grouped, '<table class="table cd-overview"[^>]*><colgroup>(.*?)</colgroup>')
Assert-True ($tables.Count -eq 3 -and @($tables | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique).Count -eq 1) 'every group''s table carries the same fixed column set, so the columns line up'
Assert-True ($grouped -match '\.cd-overview \{ table-layout: fixed;') 'the overview tables use a fixed layout'
$iS = $grouped.IndexOf('<div class="grid-2" id="issues">')
Assert-True ($oO -lt $iS -and $iS -lt $iB -and $grouped -match '<h3 class="cd-subgroup" id="group-bwj">' -and $grouped -match '<h4>Someone/x</h4>') 'the details sit beside Connected repos: an h2 Issues, an h3 per group, the repo name an h4'
Assert-True (([regex]::Matches($grouped, 'class="card grid__full"')).Count -eq 2 -and $grouped -notmatch 'card__head.{0,2}<h2' -and ([regex]::Matches($grouped, '<section class="mini-card cd-repo-card"')).Count -eq 3) 'Connected repos and Issues are a card each, and each repo a house mini-card inside Issues'
Assert-True ($html -notmatch 'id="group-bwj"' -and $html -match 'id="group-other"') 'an empty group is left out'
Assert-Equal '3 repos &#183; 1 needs action &#183; 2 in sync' (Format-DashboardGroupSummary @(@{ Status = 'good' }, @{ Status = 'bad' }, @{ Status = 'good' })) 'a group summary counts its repos, then each status worst first'
Assert-Equal '1 repo &#183; 1 not on this machine' (Format-DashboardGroupSummary @(@{ Status = 'skip' })) 'one repo is singular'
Assert-Equal '2 repos &#183; 2 need action' (Format-DashboardGroupSummary @(@{ Status = 'bad' }, @{ Status = 'bad' })) 'and several agree with their verb'
Assert-True ($grouped -match '<h3 class="cd-subgroup" id="group-bwj">BWJ repos</h3>\r?\n<p class="sub cd-group-summary">1 repo &#183; 1 in sync</p>') 'every Issues group heading is followed by its own summary line'
Assert-True ($html -match '\.cd-repo h4 \{ margin: 0; font-size: var\(--text-h5\); \}') 'a repo name sits a size below its group heading, so the h3 reads as the bigger one'
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
    $actual = (Get-FileHash -LiteralPath (Join-Path $RepoRoot "plugins\dkj-policy\dkj-solutions\assets\house-style\$file") -Algorithm SHA256).Hash.ToLowerInvariant()
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
            Assert-Equal 404 (Get-Status 'GET' '/../connectors/x.json' "localhost:$port") 'a path outside the routes is not found'
            $bb = Get-Raw 'GET' '/brandbook' "localhost:$port"
            Assert-True ($bb -match 'HTTP/1.1 200' -and $bb -match '<h1>Brandbook</h1>' -and $bb -notmatch 'could not be read') '/brandbook reads the plugin''s house style from this tree (#3132)'
            Assert-Equal 303 (Get-Status 'GET' '/refresh' "localhost:$port") '/refresh redirects to the page'
            Assert-True ((Get-Raw 'GET' '/refresh?page=connectors' "localhost:$port") -match 'Location: /connectors\r') '/refresh?page= goes back to the page that asked'
            Assert-True ((Get-Raw 'GET' '/refresh?page=sessionstart' "localhost:$port") -match 'Location: /\r') 'and a page that moved to the general pages server (#3119) is no page of this one''s'
            Assert-True ((Get-Raw 'GET' '/refresh?page=//evil.example' "localhost:$port") -match 'Location: /\r') 'and to the index for a page outside its list'
            Assert-Equal 403 (Get-Status 'GET' '/refresh' "localhost:$port" "Sec-Fetch-Site: cross-site`r`n") 'a request another site makes is refused'
            # A HEAD answers like the GET would, real Content-Length included, and carries no body (#3161).
            $cssLength = (Get-Item -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions\assets\house-style\house-style.css')).Length
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
        New-Item -ItemType Directory -Force -Path (Join-Path $src 'scripts\lib'), (Join-Path $src 'scripts\dashboard'),(Join-Path $src 'plugins\dkj-policy\dkj-solutions\assets\house-style'), (Join-Path $src 'connectors'), $noup, $outside | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $src 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $src 'scripts\lib\')
        # dev-pages-lib reads the plugin's lib from the plugin tree beside scripts/, and the server its state reader.
        New-Item -ItemType Directory -Force -Path (Join-Path $src 'plugins\dkj-policy\dkj-solutions\scripts\lib') | Out-Null
        Copy-Item (Join-Path $PluginLib '*.ps1') (Join-Path $src 'plugins\dkj-policy\dkj-solutions\scripts\lib\')
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
            $page = if ($up) { Get-Raw 'GET' '/connectors' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($page -match 'HTTP/1.1 200') 'the page is served with a checkout that has no upstream'
            Assert-True ($page -match 'Last commit on (master|main) [^:]*: local only') 'and that checkout shows its trunk''s last commit'
            Assert-True ($page -match 'class="msg msg--warn"') 'a check that could not run is reported, not fatal'
            $at = $page.IndexOf('id="repo-org-far"')
            $far = if ($at -ge 0) { $page.Substring($at, $page.IndexOf('</section>', $at) - $at) } else { '' }
            Assert-True ($far -and $far -notmatch 'class="meta"') 'a checkout outside the scope root is not read'
            # THE GENERAL PAGES MOVED (#3119): Artifacts, Issues, Release notes and SessionStart are the dkj-solutions
            # general pages server's now, so this server sends each on when the state file names that server AND
            # that server says it is this checkout's, and says so in a short 404 text when it does not.
            foreach ($moved in '/artifacts', '/issues', '/release-notes', '/sessionstart') {
                $r = if ($up) { Get-Raw 'GET' $moved "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 404' -and $r -match 'general pages server') "$moved is a 404 text naming the general pages server while no state file names one"
            }
            $srcState = Get-RepoHubStatePath -Root $src
            # The Repo hub on '/' and the pages under it (#3097). The fixture has no
            # suite-durations.json, so the test-gate page takes its failure path, and is still served.
            $hub = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match '<h1>Repo hub</h1>' -and $hub -match '<a class="menu-item" href="/connectors">') '/ serves the Repo hub, linking the pages below it'
            Assert-True ($hub -match 'The general pages server is not running' -and $hub -notmatch 'href="http://localhost') 'its General card says the general pages server is not running while no state file names one'
            # A state file naming a port nobody answers on is no server.
            Write-RepoHubState -Root $src -Hub "http://localhost:$port3/" -Pages "http://localhost:$genPort3"
            $r = if ($up) { Get-Raw 'GET' '/issues' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($r -match 'HTTP/1.1 404') 'a state file naming a port where nothing answers is no server: a 404 text, not a redirect'
            # The real general server for this fixture, which answers /whoami with this root's hash.
            $gen3 = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$GeneralServer`"", '-Port', $genPort3, '-RepoRootOverride', "`"$src`"")
            try {
                Assert-True (Wait-ServerUp $genPort3) 'the fixture''s general pages server listens'
                # SERVED FROM THIS ORIGIN (#3168): the general server builds the page, this server relays its answer
                # as it came -- so the browser stays on one origin, and one theme choice holds on every page.
                $r = if ($up) { Get-Raw 'GET' '/artifacts' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 200' -and $r -match '<h1>Artifacts</h1>' -and $r -match 'data-theme-key="general-pages"' -and $r -notmatch 'Location:') '/artifacts is relayed from the general pages server, on this origin, under the shared theme key'
                $r = if ($up) { Get-Raw 'GET' '/release-notes' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 404' -and $r -match 'Not built yet') 'and its answer is relayed as it came, a 404 included'
                $len = if ($r -match 'Content-Length: ([0-9]+)\r') { [int]$Matches[1] } else { -1 }
                $r = if ($up) { Get-Raw 'HEAD' '/release-notes' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match "Content-Length: $len\r" -and $r.EndsWith("`r`n`r`n")) 'a relayed HEAD keeps the real Content-Length and carries no body'
                $r = if ($up) { Get-Raw 'GET' '/refresh?page=issues' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 303' -and $r -match 'Location: /issues\r') 'a general page''s refresh is relayed too, and its 303 names a path on this origin'
                $r = if ($up) { Get-Raw 'GET' '/hub' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($r -match 'HTTP/1.1 303' -and $r -match 'Location: /\r') 'and the general pages'' "Repo hub" crumb, /hub, is answered here with the hub'
                # THE BROWSER'S OWN HEADERS (#3119): ports do not count toward "site", so the hub's link, and the 303 hop to the
                # general server, arrive same-site -- a top-level navigation. A fetch or a cross-site request does not get in.
                $nav = "Sec-Fetch-Site: same-site`r`nSec-Fetch-Mode: navigate`r`nSec-Fetch-Dest: document`r`n"
                $r = Get-Raw 'GET' '/artifacts' "localhost:$port3" $nav $port3
                Assert-True ($r -match 'HTTP/1.1 200' -and $r -match '<h1>Artifacts</h1>') 'a same-site navigation to a relayed route on this server is served, not refused'
                $r = Get-Raw 'GET' '/' "localhost:$port3" $nav $port3
                Assert-True ($r -match 'HTTP/1.1 200' -and $r -match '<h1>Repo hub</h1>') 'and the hub itself, reached by the crumb back from the general pages, is served'
                $r = Get-Raw 'GET' '/connectors' "localhost:$port3" "Sec-Fetch-Site: same-site`r`nSec-Fetch-Mode: cors`r`n" $port3
                Assert-True ($r -match 'HTTP/1.1 403') 'a same-site fetch is still refused'
                $r = Get-Raw 'GET' '/' "localhost:$port3" "Sec-Fetch-Site: cross-site`r`nSec-Fetch-Mode: navigate`r`n" $port3
                Assert-True ($r -match 'HTTP/1.1 403') 'and so is a cross-site navigation'
                $r = Get-Raw 'GET' '/artifacts' "localhost:$genPort3" $nav $genPort3
                Assert-True ($r -match 'HTTP/1.1 200' -and $r -match '<h1>Artifacts</h1>') 'the general server serves the click from the hub too'
                $r = Get-Raw 'GET' '/hub' "localhost:$genPort3" $nav $genPort3
                Assert-True ($r -match 'HTTP/1.1 303' -and $r -match ('Location: http://localhost:' + $port3 + '/\r')) 'and sends the crumb''s /hub on to the repo hub'
                $r = Get-Raw 'GET' '/artifacts' "localhost:$genPort3" "Sec-Fetch-Site: same-site`r`nSec-Fetch-Mode: no-cors`r`n" $genPort3
                Assert-True ($r -match 'HTTP/1.1 403') 'while a same-site subresource request to it is refused'
                $hubUp = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
                Assert-True ($hubUp -match '<a class="menu-item" href="/issues">' -and $hubUp -match 'href="/release-notes"' -and $hubUp -notmatch 'href="http://localhost' -and $hubUp -notmatch 'is not running') 'the General card links the pages on this origin, when the server the state file names answers as this checkout''s (#3168)'
            } finally {
                if (-not $gen3.HasExited) { Stop-Process -Id $gen3.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
                $gen3.WaitForExit(5000) | Out-Null
            }
            $hubDown = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($hubDown -match 'HTTP/1.1 200' -and $hubDown -match 'The general pages server is not running') 'and the card is back to not running once nothing answers there'
            Remove-Item -LiteralPath $srcState -Force -ErrorAction SilentlyContinue
            Assert-True ($page -match 'HTTP/1.1 200' -and $page -match '<h1>Connectors</h1>' -and $page -match '<a href="/">Repo hub</a>') '/connectors serves the overview as a page under the Repo hub'
            $tg = if ($up) { Get-Raw 'GET' '/test-gate' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($tg -match 'HTTP/1.1 200' -and $tg -match 'the file is not there') '/test-gate reports a missing suite-durations.json, rather than failing'
            # The fixture's assets/house-style/ is empty, so /brandbook takes its failure path, and is still served.
            $bbf = if ($up) { Get-Raw 'GET' '/brandbook' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($bbf -match 'HTTP/1.1 200' -and $bbf -match 'The house style could not be read: house-style.css is not readable, house-theme.js is not readable') '/brandbook names the house-style files it could not read, rather than failing'
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
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture4 'scripts\lib'), (Join-Path $fixture4 'scripts\dashboard'),(Join-Path $fixture4 'plugins\dkj-policy\dkj-solutions\assets\house-style') | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture4 'plugins\dkj-policy\dkj-solutions\scripts\lib') | Out-Null
        Copy-Item (Join-Path $PluginLib '*.ps1') (Join-Path $fixture4 'plugins\dkj-policy\dkj-solutions\scripts\lib\')
        Copy-Item $Server (Join-Path $fixture4 'scripts\dashboard\')
        # The stylesheet is there and the theme script is not: a present and a missing static file side by side.
        [System.IO.File]::WriteAllText((Join-Path $fixture4 'plugins\dkj-policy\dkj-solutions\assets\house-style\house-style.css'), 'body{}')
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
        Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match "<code>$($first.Substring(0, 8))</code>") '"Source at" names the commit the server loaded'
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

Write-Host ''
Write-Host "connector-dashboard: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
