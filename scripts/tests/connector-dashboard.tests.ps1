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
    outside the scope root, and no check-connectors.ps1 at all -- and the release-notes page, before
    and after it is built (#3083).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Server   = Join-Path $RepoRoot 'scripts\dashboard\serve-connector-dashboard.ps1'
. (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1')

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
Assert-True  (Test-DashboardHost 'localhost:4870' 4870) 'localhost on our port is served'
Assert-True  (Test-DashboardHost '127.0.0.1:4870' 4870) '127.0.0.1 on our port is served'
Assert-True  (Test-DashboardHost 'LocalHost:4870 ' 4870) 'the Host is compared case-insensitively and trimmed'
Assert-True  (-not (Test-DashboardHost 'evil.example:4870' 4870)) 'a rebound foreign name is refused'
Assert-True  (-not (Test-DashboardHost 'localhost:4871' 4870)) 'another port is refused'
Assert-True  (-not (Test-DashboardHost '' 4870)) 'no Host is refused'

Assert-True  (Test-DashboardCheckoutInScope 'C:\g\org\repo' 'C:\g') 'a sibling checkout under the scope root is in scope'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\other\repo' 'C:\g')) 'a path that climbs out of the scope root is not'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\g2\repo' 'C:\g')) 'a sibling of the scope root that shares its prefix is not'
Assert-True  (-not (Test-DashboardCheckoutInScope 'C:\g' 'C:\g')) 'the scope root itself is not a checkout'
Assert-True  (Test-DashboardCrossSite 'cross-site') 'a cross-site request is refused'
Assert-True  (Test-DashboardCrossSite 'Same-Site') 'a same-site (other port or subdomain) request is refused'
Assert-True  (-not (Test-DashboardCrossSite 'same-origin')) 'the page itself is served'
Assert-True  (-not (Test-DashboardCrossSite 'none')) 'a typed or bookmarked URL is served'
Assert-True  (-not (Test-DashboardCrossSite '')) 'no header (curl) is served'

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
Assert-Equal 1 ([regex]::Matches($grouped, '<h2 class="card__title">Connected repos</h2>')).Count 'the overview stays one h2 card, headed Connected repos'
$oB = $grouped.IndexOf('id="overview-bwj"'); $oD = $grouped.IndexOf('id="overview-dkj"'); $oO = $grouped.IndexOf('id="overview-other"')
Assert-True ($grouped.IndexOf('<h2 class="card__title">Connected repos</h2>') -lt $oB -and $oB -lt $oD -and $oD -lt $oO -and $oO -lt $iB) 'inside Connected repos a table per group, BWJ, DKJ, Other, before the Status cards'
Assert-True ($grouped -notmatch '<h3[^>]*id="overview-' -and $grouped -match '<th>BWJ repos</th>' -and $grouped -match '<th>DKJ repos</th>' -and $grouped -match '<th>Other repos</th>' -and $grouped -notmatch '<th>Repo</th>') 'no h3 over the tables: each table names its group in its first column head'
$tables = [regex]::Matches($grouped, '<table class="table cd-overview"[^>]*><colgroup>(.*?)</colgroup>')
Assert-True ($tables.Count -eq 3 -and @($tables | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique).Count -eq 1) 'every group''s table carries the same fixed column set, so the columns line up'
Assert-True ($grouped -match '\.cd-overview \{ table-layout: fixed;') 'the overview tables use a fixed layout'
$iS = $grouped.IndexOf('<section class="card" id="issues">')
Assert-True ($oO -lt $iS -and $iS -lt $iB -and $grouped -match '<h3 class="cd-subgroup" id="group-bwj">' -and $grouped -match '<h4>Someone/x</h4>') 'the details sit beside Connected repos: an h2 Issues, an h3 per group, the repo name an h4'
Assert-True (([regex]::Matches($grouped, 'class="card"')).Count -eq 2 -and ([regex]::Matches($grouped, '<section class="mini-card cd-repo-card"')).Count -eq 3) 'Connected repos and Issues are a card each, and each repo a house mini-card inside Issues'
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

# A repoint of the house-style skill to a new tag left both vendored files on the old one, and nothing
# noticed (#2989). The skill's table is the one place the checksums live, so the copy is held to it.
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
            Assert-Equal 303 (Get-Status 'GET' '/refresh' "localhost:$port") '/refresh redirects to the page'
            Assert-True ((Get-Raw 'GET' '/refresh?page=sessionstart' "localhost:$port") -match 'Location: /sessionstart\r') '/refresh?page= goes back to the page that asked'
            Assert-True ((Get-Raw 'GET' '/refresh?page=//evil.example' "localhost:$port") -match 'Location: /\r') 'and to the index for a page outside its list'
            Assert-Equal 403 (Get-Status 'GET' '/refresh' "localhost:$port" "Sec-Fetch-Site: cross-site`r`n") 'a request another site makes is refused'
            $headRaw = Get-Raw 'HEAD' '/house-style.css' "localhost:$port"
            Assert-True ($headRaw -match 'Content-Length: 0' -and $headRaw.TrimEnd().EndsWith('close')) 'HEAD on a static file sends no body'
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
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $src 'scripts\lib'), (Join-Path $src 'plugins\dkj-policy\dkj-solutions\assets\house-style'), (Join-Path $src 'connectors'), $noup, $outside | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $src 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $src 'scripts\lib\')
        Copy-Item $Server (Join-Path $src 'scripts\dashboard\')
        Set-Content -LiteralPath (Join-Path $src 'connectors\noup.json') -Encoding ASCII -Value '{ "repo": "Org/noup", "visibility": "private", "localCheckout": "../noup", "plugins": [] }'
        Set-Content -LiteralPath (Join-Path $src 'connectors\far.json') -Encoding ASCII -Value ('{ "repo": "Org/far", "visibility": "public", "localCheckout": "../../../' + (Split-Path -Leaf $outside) + '", "plugins": [] }')
        & git -C $noup init -q 2>$null
        & git -C $noup -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'local only' 2>$null
        & git -C $outside init -q 2>$null

        $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
        $probe.Start(); $port3 = $probe.LocalEndpoint.Port; $probe.Stop()
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
            # The release-notes page is served from where build-release-notes-page.ps1 leaves it (#3083).
            $notes = if ($up) { Get-Raw 'GET' '/release-notes' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($notes -match 'HTTP/1.1 404' -and $notes -match 'Not built yet') 'the release notes are a 404 naming the build step until the page is built'
            $pageDir = Join-Path $src 'dkj-policy\releases\page'
            New-Item -ItemType Directory -Force -Path $pageDir | Out-Null
            Set-Content -LiteralPath (Join-Path $pageDir 'release-notes.html') -Encoding ASCII -Value '<html>fixture notes</html>'
            $notes = if ($up) { Get-Raw 'GET' '/release-notes' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($notes -match 'HTTP/1.1 200' -and $notes -match 'text/html' -and $notes -match 'fixture notes') 'and served as HTML once it is, read on each request'
            Set-Content -LiteralPath (Join-Path $pageDir 'release-notes.html') -Encoding ASCII -Value '<html lang="en"><head><style>a{}</style></head><body>shaped notes</body></html>'
            $notes = if ($up) { Get-Raw 'GET' '/release-notes' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($notes -match 'shaped notes' -and $notes -match '<a href="/">Repo hub</a>' -and $notes -match 'href="/house-style.css"') 'a page of the template''s shape is served with the house style and the breadcrumb bar (#3108)'
            # The Repo hub on '/' and the pages under it (#3097). The fixture has no always-on lib and no
            # suite-durations.json, so both measurement pages take their failure path, and are still served.
            $hub = if ($up) { Get-Raw 'GET' '/' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match '<h1>Repo hub</h1>' -and $hub -match '<a class="menu-item" href="/connectors">') '/ serves the Repo hub, linking the pages below it'
            Assert-True ($page -match 'HTTP/1.1 200' -and $page -match '<h1>Connectors</h1>' -and $page -match '<a href="/">Repo hub</a>') '/connectors serves the overview as a page under the Repo hub'
            $ss = if ($up) { Get-Raw 'GET' '/sessionstart' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($ss -match 'HTTP/1.1 200' -and $ss -match 'could not be measured') '/sessionstart reports a measurement that failed, rather than failing'
            $tg = if ($up) { Get-Raw 'GET' '/test-gate' "localhost:$port3" '' $port3 } else { '' }
            Assert-True ($tg -match 'HTTP/1.1 200' -and $tg -match 'the file is not there') '/test-gate reports a missing suite-durations.json, rather than failing'
        } finally {
            if (-not $proc3.HasExited) { Stop-Process -Id $proc3.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
        }
    } finally {
        Remove-Item -LiteralPath $fixture, $outside -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host '  [SKIP] group 3 needs Windows PowerShell, git and group 2' -ForegroundColor Yellow
}

Write-Host '-- group 4: a server whose checkout moved restarts itself on the new commit (#3122)' -ForegroundColor Cyan

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT -and (Get-Command git -ErrorAction SilentlyContinue) -and $group2Ran) {
    # Measured October 18, 2026: the hook started the server, a pull moved HEAD four seconds later, and the
    # server kept serving the old pages while its "Source at" line read the new commit live.
    $fixture4 = Join-Path ([System.IO.Path]::GetTempPath()) "connector-dashboard-move-$PID-$([guid]::NewGuid().ToString('n'))"
    $port4 = $null
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture4 'scripts\lib'), (Join-Path $fixture4 'plugins\dkj-policy\dkj-solutions\assets\house-style') | Out-Null
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        Copy-Item (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1') (Join-Path $fixture4 'scripts\lib\')
        Copy-Item $Server (Join-Path $fixture4 'scripts\dashboard\')
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

        & git -C $fixture4 -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m 'second' 2>$null
        $second = ([string](& git -C $fixture4 rev-parse HEAD)).Trim()
        $css = if ($up) { Get-Raw 'GET' '/house-style.css' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($css -notmatch 'HTTP/1.1 503') 'a static file skips the check'
        $moved = if ($up) { Get-Raw 'GET' '/' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($moved -match 'HTTP/1.1 503' -and $moved -match 'Refresh: 3' -and $moved -match 'restarting on the new code') 'a page asked for after HEAD moved answers 503 and reloads'
        Assert-True ($proc4.WaitForExit(15000)) 'and the old server exits'
        $up = Wait-ServerUp $port4
        Assert-True $up 'its successor listens on the same port'
        $hub = if ($up) { Get-Raw 'GET' '/' "localhost:$port4" '' $port4 } else { '' }
        Assert-True ($hub -match 'HTTP/1.1 200' -and $hub -match "<code>$($second.Substring(0, 8))</code>") 'and serves the new commit'
    } finally {
        if ($proc4 -and -not $proc4.HasExited) { Stop-Process -Id $proc4.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
        # The successor is detached; it is found by the port it holds.
        if ($port4) {
            foreach ($o in @(Get-NetTCPConnection -State Listen -LocalPort $port4 -ErrorAction SilentlyContinue | ForEach-Object { $_.OwningProcess })) {
                Stop-Process -Id $o -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Milliseconds 500
        Remove-Item -LiteralPath $fixture4 -Recurse -Force -ErrorAction SilentlyContinue
        if ($port4) { Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter "serve-connector-dashboard-$port4-*.log" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
    }
} else {
    Write-Host '  [SKIP] group 4 needs Windows PowerShell, git and group 2' -ForegroundColor Yellow
}

Write-Host ''
Write-Host "connector-dashboard: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
