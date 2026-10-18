<#
.SYNOPSIS
    The Repo hub on '/' of this repo's dev server and its measurement pages (#3097): the SessionStart page
    (the always-on path every session loads before its first turn) and the test-gate page (the per-suite
    CI durations). No I/O -- the server (scripts/dashboard/serve-connector-dashboard.ps1) measures and reads, and hands the
    results in, so every rule here is tested without a server.

.DESCRIPTION
    THE HUB TAKES THE ONE FORM THE BRAND BOOK LAYS DOWN (house style v0.3.0, "The Repo hub"): the bar
    with its one crumb, the settings button, the intro with the fixed h1, the Pages card (block 7) linking
    the repo's own pages, About this repo and a footer note. This repo is no product and keeps no in-flight
    lists on the hub, so blocks 6 and 8 to 10 are left out. The pages it links are Get-RepoHubPages; the
    general ones -- a page every DKJ-Solutions repo is meant to serve, such as its issues or its release
    notes -- stand in a second card of the same form, General pages, directly under block 7, so a page that
    is this repo's own is never read as one every repo has.

    ONE SHELL FOR EVERY PAGE BELOW THE HUB. Each page opens with the house breadcrumb bar, its trail
    starting at the Repo hub on '/' and ending at the page itself, unlinked ("Every page: the breadcrumb
    bar"); then the settings button, an intro (eyebrow, h1, lead), the page's own blocks and a footer
    note naming where the data comes from.

    THE DATA IS THE REPO'S OWN, NOT A SECOND MEASUREMENT. The SessionStart page shows what
    always-on-budget-lib measures -- the figure always-on-sessioncheck prints at every session start --
    and the test-gate page shows scripts/tests/suite-durations.json, which record-suite-durations.ps1
    writes from CI runs (the measure-suites skill). A suite in scripts/tests that the file does not name
    is counted, because the gate charges it the largest recorded value.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED, through connector-dashboard-lib's ConvertTo-DashboardText.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'connector-dashboard-lib.ps1')

function Format-DevNumber {
    <# An integer with thousands separators, culture-independent: 58895 -> '58,895'. #>
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return '--' }
    return ([int64]$Value).ToString('N0', [Globalization.CultureInfo]::InvariantCulture)
}

function Format-DevSeconds {
    <# Seconds as one decimal under a minute, else m:ss -- 7.6 -> '7.6s', 1402 -> '23:22'. #>
    param([AllowNull()]$Seconds)
    if ($null -eq $Seconds) { return '--' }
    $s = [double]$Seconds
    if ($s -lt 60) { return $s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' }
    $whole = [int][Math]::Round($s)
    return ('{0}:{1:00}' -f [int][Math]::Floor($whole / 60), ($whole % 60))
}

function Format-DevPageHtml {
    <#
        The whole page around -Body. -Title is the page's own name: the last crumb, the h1 and the
        <title>. -Style is the page's own layer, names the house file does not define. -FooterNote is
        markup the caller has escaped.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'connector-dashboard'
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    # The theme key is the index page's, so a theme picked on one page holds on every page of this server.
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-theme-key="' + (& $e $ThemeKey) + '">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- ' + (& $e $Title) + '</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The page layer: only names the house file does not define (.dp-*).
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.dp-link { color: var(--primary-7); text-underline-offset: 2px; }')
    [void]$sb.AppendLine('.dp-thead th { background: var(--primary-3); }')
    [void]$sb.AppendLine('.table td.dp-left, .table th.dp-left { text-align: left; }')
    if ($Style) { [void]$sb.AppendLine($Style) }
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><a href="/">Repo hub</a></li>')
    [void]$sb.AppendLine('<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">' + (& $e $Title) + '</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>')
    [void]$sb.AppendLine('<main class="page-column">')
    [void]$sb.AppendLine('<div>')
    [void]$sb.AppendLine('<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>')
    [void]$sb.AppendLine('<h1>' + (& $e $Title) + '</h1>')
    [void]$sb.AppendLine('<p class="lead">' + $Lead + '</p>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.Append($Body)
    if ($FooterNote) { [void]$sb.AppendLine('<p class="footer-note">' + $FooterNote + '</p>') }
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

# The Pages row's chevron, the brand book's own svg (patterns/repo-dashboard.html at v0.3.0).
$script:RepoHubChevron = '<svg class="menu-item__chevron" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

function Get-RepoHubPages {
    <#
        The pages the Repo hub links, in the order it lists them: each a route on this server, its label
        the page's own name as its breadcrumb reads it, one line on what it shows, and its Group. 'repo' is
        a page only this repo has, listed in the Pages card; 'general' is a page every DKJ-Solutions
        repo is meant to serve the same way -- its GitHub issues, its releases, what a session loads --
        listed in the General pages card below it, so the two are never mistaken for each other.
    #>
    @(
        @{ Href = '/connectors';    Label = 'Connectors';    Group = 'repo';    Sub = 'Every repo registered under connectors/, as check-connectors.ps1 reports it on this machine' },
        @{ Href = '/test-gate';     Label = 'Test gate';     Group = 'repo';    Sub = 'What each test suite costs on CI' },
        @{ Href = '/artifacts';     Label = 'Artifacts';     Group = 'general'; Sub = 'Every claude.ai Artifact published from a session in this repo' },
        @{ Href = '/issues';        Label = 'Issues';        Group = 'general'; Sub = 'The open GitHub issues and where they stand, and the flow of the last four weeks' },
        @{ Href = '/release-notes'; Label = 'Release notes'; Group = 'general'; Sub = 'What each released version of the plugins changed' },
        @{ Href = '/sessionstart';  Label = 'SessionStart';  Group = 'general'; Sub = 'The always-on path every session loads before its first turn' }
    )
}

function Format-RepoHubHtml {
    <#
        The Repo hub on '/'. -Pages is Get-RepoHubPages' shape; -SourceCommit is the short sha the server
        reads, or empty.
    #>
    param(
        [Parameter(Mandatory = $true)][object[]]$Pages,
        [AllowEmptyString()][string]$SourceCommit = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-theme-key="connector-dashboard">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- Repo hub</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The page layer: only names the house file does not define, with house tokens -- never a house class
    # in a selector, which check-house-style refuses. A grid__head spans both columns of the .grid-2 it opens,
    # as does a card that is a row of its own (grid__full, About this repo's); every h2 in one carries a
    # short sub line, the house .card__sub. A card in such a row (grid__card) drops the house .card's
    # margin-top, which came on top of the grid's own gap and doubled it (the owner's look; asked for
    # upstream in DKJ-Solutions/dkj-brandbook#207).
    [void]$sb.AppendLine('<style>.grid__head, .grid__full { grid-column: 1 / -1; } .grid__head > h2 { margin: 0; } .grid__card { margin-top: 0; }</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    # Block 0, the breadcrumb bar: on the hub its trail is the one crumb.
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><span aria-current="page">Repo hub</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    # Block 1, the settings button, sits outside <main>.
    [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>')
    [void]$sb.AppendLine('<main class="page-column">')
    # Blocks 2 to 5: the intro is a <div>, never a <header>, which the house style lays out as a flex row.
    [void]$sb.AppendLine('<div>')
    [void]$sb.AppendLine('<p class="eyebrow">DKJ-Solutions/dkj-claude-plugins</p>')
    [void]$sb.AppendLine('<h1>Repo hub</h1>')
    [void]$sb.AppendLine('<p class="lead">The source of the Claude Specialists plugins: the marketplace, its agent definitions, manuals and skills, and the scripts and gates that ship them.</p>')
    [void]$sb.AppendLine('</div>')

    # Block 7, Pages: the repo's own pages, then the general ones in a card of their own, the two on one row
    # of the house's .grid-2 (it stacks them again below 760px) under one grid__head carrying the h2, so
    # each card's title is an h3, the house's own. One menu-item row per page, direct siblings so the house
    # draws the line between them. A page without a Group is the repo's own; a group with no page has no
    # card, and one card alone is block 7 as the form gives it, its title the h2.
    $cards = @(
        @{ Title = 'This repo'; Sub = 'Specific to this repo';                                        Rows = @($Pages | Where-Object { $_.Group -ne 'general' }) },
        @{ Title = 'General';   Sub = 'Not specific to this repo: every DKJ-Solutions repo has them'; Rows = @($Pages | Where-Object { $_.Group -eq 'general' }) }
    )
    $cards = @($cards | Where-Object { $_.Rows.Count -gt 0 })
    $row = $cards.Count -gt 1
    if ($row) {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Pages</h2><p class="card__sub">Every page this dev server serves</p></div>')
    }
    foreach ($c in $cards) {
        $title = if ($row) { '<h3>' + $c.Title + '</h3>' } else { '<h2 class="card__title">Pages</h2>' }
        $label = if ($row) { $c.Title + ' pages' } else { 'Pages' }
        [void]$sb.AppendLine($(if ($row) { '<section class="card grid__card">' } else { '<section class="card">' }))
        [void]$sb.AppendLine('<div class="card__head">' + $title + '<p class="card__sub">' + $c.Sub + '</p></div>')
        [void]$sb.AppendLine('<nav class="menu-list" aria-label="' + $label + '">')
        foreach ($p in $c.Rows) {
            $sub = if ($p.Sub) { '<span class="menu-item__sub">' + (& $e $p.Sub) + '</span>' } else { '' }
            [void]$sb.AppendLine('<a class="menu-item" href="' + (& $e $p.Href) + '"><span class="menu-item__label">' + (& $e $p.Label) + $sub + '</span>' + $script:RepoHubChevron + '</a>')
        }
        [void]$sb.AppendLine('</nav>')
        [void]$sb.AppendLine('</section>')
    }
    if ($row) { [void]$sb.AppendLine('</div>') }

    # Block 11: About this repo, the fixed title, with this repo's own facts. Its h2 stands outside the
    # card in a grid__head, as Pages' does, so the two blocks read alike and stay apart; the card spans
    # both columns of a grid-2 row of its own, which gives head and card the same gap as the Pages row.
    [void]$sb.AppendLine('<div class="grid-2">')
    [void]$sb.AppendLine('<div class="grid__head"><h2>About this repo</h2><p class="card__sub">What this repo is, and the commit this hub is served from</p></div>')
    [void]$sb.AppendLine('<section class="card grid__card grid__full">')
    [void]$sb.AppendLine('<dl class="facts">')
    [void]$sb.AppendLine('<div><dt>Marketplace</dt><dd>dkj-claude-plugins</dd></div>')
    [void]$sb.AppendLine('<div><dt>Trunk</dt><dd>main</dd></div>')
    [void]$sb.AppendLine('<div><dt>Visibility</dt><dd>public</dd></div>')
    [void]$sb.AppendLine('<div><dt>Required check</dt><dd>lint-en-tests</dd></div>')
    if ($SourceCommit) { [void]$sb.AppendLine('<div><dt>Source at</dt><dd><code>' + (& $e $SourceCommit) + '</code></dd></div>') }
    [void]$sb.AppendLine('</dl>')
    [void]$sb.AppendLine('</section>')
    [void]$sb.AppendLine('</div>')

    # Block 12: where the data comes from.
    [void]$sb.AppendLine('<p class="footer-note">The facts are this repo''s own, and each page names its own source. Served on 127.0.0.1 only, by <code>scripts/dashboard/serve-connector-dashboard.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

function Format-DevTiles {
    <# The house tile row: -Tiles is a list of @{ L = label; V = value (already text) }. #>
    param([Parameter(Mandatory = $true)][object[]]$Tiles)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<div class="tiles">')
    foreach ($t in $Tiles) {
        [void]$sb.AppendLine('<div class="tile"><div class="label">' + (ConvertTo-DashboardText $t.L) + '</div><div class="v num">' + (ConvertTo-DashboardText $t.V) + '</div></div>')
    }
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}

# The share bar both tables draw: a track in --primary-3 and a fill in the house highlight.
$script:DevBarStyle = '.dp-bar { display: block; height: 8px; border-radius: 4px; background: var(--primary-3); min-width: 80px; }' + "`n" +
    '.dp-bar > span { display: block; height: 100%; border-radius: 4px; background: var(--primary-7); }'

function Format-DevShareCell {
    <#
        Two cells: a bar, and the share of -Whole as a percentage. The bar is drawn against -BarOf where
        given (the largest row), so a long table of small shares still reads; otherwise against -Whole.
    #>
    param([double]$Part, [double]$Whole, [double]$BarOf = 0)
    $pct = if ($Whole -gt 0) { 100.0 * $Part / $Whole } else { 0 }
    $txt = $pct.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
    $scale = if ($BarOf -gt 0) { $BarOf } else { $Whole }
    $bar = if ($scale -gt 0) { 100.0 * $Part / $scale } else { 0 }
    # Double literals: with an int 0 or 100, PowerShell picks Math's int overload and truncates the width.
    $w = [Math]::Min(100.0, [Math]::Max(0.0, $bar)).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)
    return '<td class="dp-left"><span class="sr-only">' + $txt + '%</span><span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span></td><td>' + $txt + '%</td>'
}

function ConvertFrom-SuiteDurations {
    <#
        The test-gate model from the parsed suite-durations.json (-Durations, $null when the file is
        missing or unreadable) and the suite file names in scripts/tests (-SuiteFiles). Returns
        @{ Suites (list of @{ Name; Seconds }, slowest first); Total; Missing (names on disk the file does
        not record); Stale (names the file records that are no longer on disk); Runs; Date; Machine; Method }.
    #>
    param($Durations, [AllowEmptyCollection()][string[]]$SuiteFiles = @())
    $suites = @()
    if ($Durations -and $Durations.seconds) {
        foreach ($p in $Durations.seconds.PSObject.Properties) {
            $suites += @{ Name = [string]$p.Name; Seconds = [double]$p.Value }
        }
    }
    $suites = @($suites | Sort-Object @{ Expression = { $_.Seconds }; Descending = $true }, @{ Expression = { $_.Name } })
    $recorded = @{}
    foreach ($s in $suites) { $recorded[$s.Name] = $true }
    $onDisk = @{}
    foreach ($f in @($SuiteFiles)) { if ($f) { $onDisk[$f] = $true } }
    $from = if ($Durations) { $Durations.recordedFrom } else { $null }
    return @{
        Suites  = $suites
        Total   = [double](($suites | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        Missing = @(@($SuiteFiles) | Where-Object { $_ -and -not $recorded.ContainsKey($_) } | Sort-Object)
        Stale   = @(if ($onDisk.Count) { $suites | Where-Object { -not $onDisk.ContainsKey($_.Name) } | ForEach-Object { $_.Name } })
        Runs    = @(if ($from) { @($from.runs) | Where-Object { $_ } | ForEach-Object { [string]$_ } })
        Date    = if ($from) { [string]$from.date } else { '' }
        Machine = if ($from) { [string]$from.machine } else { '' }
        Method  = if ($from) { [string]$from.method } else { '' }
    }
}

function Format-TestGatePageHtml {
    <# The test-gate page from ConvertFrom-SuiteDurations' model. -ReadError is set when the file could not be read. #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$ReadError = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $suites = @($Model.Suites)
    $slowest = if ($suites.Count) { $suites[0] } else { $null }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Suites recorded'; V = $suites.Count },
        @{ L = 'Sum of all suites'; V = (Format-DevSeconds $(if ($suites.Count) { $Model.Total } else { $null })) },
        @{ L = 'Slowest suite'; V = (Format-DevSeconds $(if ($slowest) { $slowest.Seconds } else { $null })) },
        @{ L = 'Not recorded'; V = @($Model.Missing).Count })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/tests/suite-durations.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if (@($Model.Missing).Count) {
        [void]$body.AppendLine('<p class="msg" role="status">Not recorded yet, so the gate charges each the largest recorded value: ' +
            ((@($Model.Missing) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<section class="card" id="suites">')
    [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Suites</h2><p class="card__sub">Mean CI duration per suite, slowest first</p></div>')
    if ($suites.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th>Seconds</th><th class="dp-left">Against the slowest</th><th>Share of the sum</th></tr></thead><tbody>')
        foreach ($s in $suites) {
            $stale = if (@($Model.Stale) -contains $s.Name) { ' <span class="badge badge--sm badge--neutral">no longer on disk</span>' } else { '' }
            [void]$body.AppendLine('<tr><td class="dp-left"><code>' + (& $e $s.Name) + '</code>' + $stale + '</td><td class="num">' +
                ([double]$s.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + '</td>' + (Format-DevShareCell $s.Seconds $Model.Total $slowest.Seconds) + '</tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No suite durations are recorded.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('<section class="card" id="recorded">')
    [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Where it was measured</h2></div>')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Machine</dt><dd>' + $(if ($Model.Machine) { & $e $Model.Machine } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
    $runs = (@($Model.Runs) | Where-Object { $_ -match '^\d+$' } | ForEach-Object {
            '<a class="dp-link" href="https://github.com/DKJ-Solutions/dkj-claude-plugins/actions/runs/' + $_ + '">' + $_ + '</a>' }) -join ', '
    [void]$body.AppendLine('<div><dt>CI runs</dt><dd>' + $(if ($runs) { $runs } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    return Format-DevPageHtml -Title 'Test gate' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead 'What each test suite costs on CI, as the gate packs its shards from it. Measured on CI runners, never on a workstation: a local reading does not convert.' `
        -FooterNote 'Read from <code>scripts/tests/suite-durations.json</code>. Refreshed by <code>scripts/maintenance/record-suite-durations.ps1</code>; the <code>measure-suites</code> skill compares two sets of runs.'
}

function Format-SessionStartPageHtml {
    <#
        The SessionStart page. -Model is @{ Total; DiskBytes; Tokens; Budget; State; Ok; Documents (list of
        @{ Display; Bytes; Source = 'measured'|'carried'|'unmeasured' }); GeneratedAt; Seconds }, or
        $null with -ReadError when the measurement failed.
    #>
    param($Model, [AllowEmptyString()][string]$ReadError = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $docs = if ($Model) { @($Model.Documents | Where-Object { $_ } | Sort-Object @{ Expression = { [int64]$_.Bytes }; Descending = $true }) } else { @() }
    $total = if ($Model) { [int64]$Model.Total } else { $null }
    $budget = if ($Model) { [int64]$Model.Budget } else { $null }
    $room = if ($Model) { $budget - $total } else { $null }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Always-on path (B)'; V = (Format-DevNumber $total) },
        @{ L = 'Estimated tokens'; V = $(if ($Model) { '~' + (Format-DevNumber $Model.Tokens) } else { '--' }) },
        @{ L = 'Budget (B)'; V = (Format-DevNumber $budget) },
        @{ L = $(if ($null -ne $room -and $room -lt 0) { 'Over the budget (B)' } else { 'Headroom (B)' }); V = $(if ($null -ne $room) { Format-DevNumber ([Math]::Abs($room)) } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The always-on path could not be measured: ' + (& $e $ReadError) + '.</p>')
    } elseif ($Model -and -not $Model.Ok) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The always-on path is over its limit (' + (& $e $Model.State) + '): every session pays it, and the gate refuses a branch that grows it.</p>')
    }
    $unmeasured = @($docs | Where-Object { $_.Source -eq 'unmeasured' })
    if ($unmeasured.Count) {
        [void]$body.AppendLine('<p class="msg" role="status">Not counted, because neither this machine nor the baseline has a size for it: ' +
            (($unmeasured | ForEach-Object { '<code>' + (& $e $_.Display) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<section class="card" id="documents">')
    [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Always-on documents</h2><p class="card__sub"><code>CLAUDE.md</code> and every file it imports, largest first</p></div>')
    $counted = @($docs | Where-Object { $_.Source -ne 'unmeasured' })
    if ($counted.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Document</th><th>Bytes</th><th class="dp-left">Share of the path</th><th>Share</th><th class="dp-left">Measured</th></tr></thead><tbody>')
        foreach ($d in $counted) {
            $src = if ($d.Source -eq 'carried') { 'from the baseline' } else { 'on this machine' }
            [void]$body.AppendLine('<tr><td class="dp-left"><code>' + (& $e $d.Display) + '</code></td><td class="num">' + (Format-DevNumber $d.Bytes) + '</td>' +
                (Format-DevShareCell ([double]$d.Bytes) ([double]$total)) + '<td class="dp-left">' + $src + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No always-on document was measured.</p>')
    }
    [void]$body.AppendLine('</section>')
    $when = if ($Model -and $Model.GeneratedAt) {
        $secs = if ($null -ne $Model.Seconds) { ' in ' + ([double]$Model.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
        ', measured ' + (& $e $Model.GeneratedAt) + $secs
    } else { '' }
    return Format-DevPageHtml -Title 'SessionStart' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead 'What every session in this repo loads before its first turn: the always-on document path that <code>always-on-sessioncheck</code> reports at session start, against the budget the gate holds it to.' `
        -FooterNote ('Measured by <code>scripts/lib/always-on-budget-lib.ps1</code>, in LF bytes, the unit the gate judges' + $when + ' (<a class="dp-link" href="/refresh?page=sessionstart">measure again</a>).')
}

function Test-ArtifactUrl {
    <#
        True for a claude.ai Artifact link and nothing else: claude.ai/artifact/<id> or
        claude.ai/code/artifact/<uuid>, over https. The register is data in a public repo and the page
        renders each url as a link, so anything else is never given an href.
    #>
    param([AllowEmptyString()][string]$Url)
    return $Url -cmatch '^https://claude\.ai/(artifact/[A-Za-z0-9]+|code/artifact/[0-9a-f-]+)\z'
}

function ConvertFrom-ArtifactRegister {
    <#
        The Artifacts page model from the parsed scripts/dashboard/artifacts.json (-Register, $null when the
        file is missing or unreadable). Returns @{ Artifacts (list of @{ Title; Url; Kind; Created; Updated;
        About; Linked }, newest first); Date; Method }. A row whose url is not a claude.ai Artifact link is
        kept, with Linked false, so a typo shows on the page instead of a row going missing.
    #>
    param($Register)
    $rows = @()
    if ($Register -and $Register.artifacts) {
        foreach ($a in @($Register.artifacts)) {
            if (-not $a) { continue }
            $url = [string]$a.url
            $rows += @{
                Title   = [string]$a.title
                Url     = $url
                Kind    = [string]$a.kind
                Created = [string]$a.created
                Updated = [string]$a.updated
                About   = [string]$a.about
                Linked  = (Test-ArtifactUrl $url)
            }
        }
    }
    # ISO dates sort as text -- Windows PowerShell 5.1's ConvertFrom-Json leaves them strings, where 7 would
    # make them DateTime, and the server runs under powershell.exe. The title breaks a tie so two of one day keep a stable order.
    $rows = @($rows | Sort-Object @{ Expression = { $_.Created }; Descending = $true }, @{ Expression = { $_.Title } })
    $from = if ($Register) { $Register.recordedFrom } else { $null }
    return @{
        Artifacts = $rows
        Date      = if ($from) { [string]$from.date } else { '' }
        Method    = if ($from) { [string]$from.method } else { '' }
    }
}

function Format-ArtifactsPageHtml {
    <# The Artifacts page from ConvertFrom-ArtifactRegister's model. -ReadError is set when the file could not be read. #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$ReadError = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $rows = @($Model.Artifacts)
    $unlinked = @($rows | Where-Object { -not $_.Linked })
    $kinds = @($rows | ForEach-Object { $_.Kind } | Where-Object { $_ } | Sort-Object -Unique)
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Artifacts'; V = $rows.Count },
        @{ L = 'Kinds'; V = $kinds.Count },
        @{ L = 'Most recent'; V = $(if ($rows.Count -and $rows[0].Created) { $rows[0].Created } else { '--' }) },
        @{ L = 'Without a link'; V = $unlinked.Count })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/dashboard/artifacts.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if ($unlinked.Count) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="status">Not a claude.ai Artifact link, so shown without one: ' +
            (($unlinked | ForEach-Object { '<code>' + (& $e $_.Title) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<section class="card" id="artifacts">')
    [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Artifacts</h2><p class="card__sub">Newest first. Each opens on claude.ai, for an account it is shared with</p></div>')
    if ($rows.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Artifact</th><th class="dp-left">Kind</th><th class="dp-left">Created</th><th class="dp-left">Last published</th></tr></thead><tbody>')
        foreach ($a in $rows) {
            $name = if ($a.Title) { & $e $a.Title } else { '(untitled)' }
            $title = if ($a.Linked) { '<a class="dp-link" href="' + (& $e $a.Url) + '" target="_blank" rel="noopener noreferrer">' + $name + '</a>' } else { $name }
            $about = if ($a.About) { '<p class="note">' + (& $e $a.About) + '</p>' } else { '' }
            $kind = if ($a.Kind) { '<span class="badge badge--sm badge--neutral">' + (& $e $a.Kind) + '</span>' } else { '--' }
            [void]$body.AppendLine('<tr><td class="dp-left">' + $title + $about + '</td><td class="dp-left">' + $kind + '</td><td class="dp-left num">' +
                $(if ($a.Created) { & $e $a.Created } else { '--' }) + '</td><td class="dp-left num">' + $(if ($a.Updated) { & $e $a.Updated } else { '--' }) + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No Artifact is recorded.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('<section class="card" id="recorded">')
    [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Where the list comes from</h2></div>')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    return Format-DevPageHtml -Title 'Artifacts' -Body $body.ToString() `
        -Lead 'Every claude.ai Artifact a session in this repo has published: pages, decks and documents. An Artifact is private to the account that made it until it is shared, so a link may not open for everyone.' `
        -FooterNote 'Read from <code>scripts/dashboard/artifacts.json</code>, on every request. A new Artifact is added there by <code>scripts/maintenance/harvest-artifacts.ps1</code> (the <code>harvest-artifacts</code> skill), from each machine''s session transcripts.'
}

function Format-DevDuration {
    <# Hours as hours under two days, else days, one decimal -- 5.25 -> '5.3 h', 60 -> '2.5 d'. #>
    param([AllowNull()]$Hours)
    if ($null -eq $Hours) { return '--' }
    $h = [double]$Hours
    $inv = [Globalization.CultureInfo]::InvariantCulture
    if ($h -lt 48) { return $h.ToString('0.0', $inv) + ' h' }
    return ($h / 24).ToString('0.0', $inv) + ' d'
}

function ConvertTo-IssueRow {
    <#
        One issue from gh issue list --json (number,title,state,stateReason,labels,assignees,createdAt,closedAt)
        as the page reads it: its priority (prio-N, 0 for none), its parking label (awaiting-*), its kind (the
        first of the tracker's type labels it carries) and its state on the board -- Parked over Claimed over Free.
    #>
    param([Parameter(Mandatory = $true)]$Issue)
    $labels = @(@($Issue.labels) | Where-Object { $_ } | ForEach-Object { [string]$_.name })
    $assignees = @(@($Issue.assignees) | Where-Object { $_ } | ForEach-Object { [string]$_.login })
    $prio = 0
    foreach ($l in $labels) { if ($l -match '^prio-([1-4])$') { $prio = [int]$Matches[1] } }
    $parked = @($labels | Where-Object { $_ -like 'awaiting-*' } | Select-Object -First 1)
    $kind = 'other'
    foreach ($k in 'bug-inbound', 'feature-inbound', 'bug', 'feature', 'documentation') {
        if ($labels -contains $k) { $kind = $k; break }
    }
    $parse = { param($v) if ($v) { [DateTime]::Parse([string]$v, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal) } else { $null } }
    $board = if ($parked.Count) { 'Parked' } elseif ($assignees.Count) { 'Claimed' } else { 'Free' }
    return @{
        Number    = [int]$Issue.number
        Title     = [string]$Issue.title
        Open      = ([string]$Issue.state -eq 'OPEN')
        Reason    = [string]$Issue.stateReason
        Labels    = $labels
        Assignees = $assignees
        Prio      = $prio
        Parked    = if ($parked.Count) { $parked[0] } else { '' }
        Kind      = $kind
        Board     = $board
        Created   = (& $parse $Issue.createdAt)
        Closed    = (& $parse $Issue.closedAt)
    }
}

function ConvertFrom-IssueList {
    <#
        The Issues page model. -Open is every open issue; -Recent the issues created or closed inside the
        window (the two searches the server makes, so a number may arrive twice and is counted once). -Now
        is the moment the window ends, -Days its length. Returns @{ Open; Opened; Closed; MedianCloseHours;
        Weeks (list of @{ From; To; Opened; Closed }, oldest first); Matrix ('4'..'0' -> @{ Free; Parked;
        Claimed }); ClosedBy (@{ Kind; Prio; Reason }, each a list of @{ Name; Count }, largest first); Days; Now }.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Open = @(),
        [AllowEmptyCollection()][object[]]$Recent = @(),
        [Parameter(Mandatory = $true)][datetime]$Now,
        [ValidateRange(7, 365)][int]$Days = 28
    )
    $now = $Now.ToUniversalTime()
    $start = $now.AddDays(-$Days)
    $byNumber = @{}
    foreach ($i in @(@($Open) + @($Recent))) {
        if (-not $i) { continue }
        $r = ConvertTo-IssueRow $i
        $byNumber[$r.Number] = $r
    }
    $rows = @($byNumber.Values)
    $open = @($rows | Where-Object { $_.Open } | Sort-Object @{ Expression = { $_.Prio }; Descending = $true }, @{ Expression = { $_.Number } })
    # Bounded at -Now on both ends, so the tiles and the weekly rows count the same issues.
    $opened = @($rows | Where-Object { $_.Created -and $_.Created -ge $start -and $_.Created -lt $now })
    $closed = @($rows | Where-Object { -not $_.Open -and $_.Closed -and $_.Closed -ge $start -and $_.Closed -lt $now })

    $hours = @($closed | Where-Object { $_.Created } | ForEach-Object { ($_.Closed - $_.Created).TotalHours } | Sort-Object)
    $median = $null
    if ($hours.Count) {
        $mid = [int][Math]::Floor($hours.Count / 2)
        $median = if ($hours.Count % 2) { [double]$hours[$mid] } else { ([double]$hours[$mid - 1] + [double]$hours[$mid]) / 2 }
    }

    $weeks = @()
    for ($w = [int][Math]::Ceiling($Days / 7) - 1; $w -ge 0; $w--) {
        $to = $now.AddDays(-7 * $w)
        $from = $to.AddDays(-7)
        if ($from -lt $start) { $from = $start }
        $weeks += @{
            From   = $from
            To     = $to
            Opened = @($opened | Where-Object { $_.Created -ge $from -and $_.Created -lt $to }).Count
            Closed = @($closed | Where-Object { $_.Closed -ge $from -and $_.Closed -lt $to }).Count
        }
    }

    $matrix = [ordered]@{}
    foreach ($p in 4, 3, 2, 1, 0) {
        $at = @($open | Where-Object { $_.Prio -eq $p })
        # String keys: an [ordered] dictionary indexed by an int reads by POSITION, not by key.
        $matrix[[string]$p] = @{
            Free    = @($at | Where-Object { $_.Board -eq 'Free' }).Count
            Parked  = @($at | Where-Object { $_.Board -eq 'Parked' }).Count
            Claimed = @($at | Where-Object { $_.Board -eq 'Claimed' }).Count
        }
    }

    $group = { param($items, $key)
        @($items | Group-Object -Property { & $key $_ } | Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } } |
            ForEach-Object { @{ Name = [string]$_.Name; Count = [int]$_.Count } })
    }
    return @{
        Open             = $open
        Opened           = $opened.Count
        Closed           = $closed.Count
        MedianCloseHours = $median
        Weeks            = $weeks
        Matrix           = $matrix
        ClosedBy         = @{
            Kind   = (& $group $closed { param($r) $r.Kind })
            Prio   = (& $group $closed { param($r) if ($r.Prio) { 'prio-' + $r.Prio } else { 'no priority' } })
            Reason = (& $group $closed { param($r) if ($r.Reason) { $r.Reason.ToLowerInvariant().Replace('_', ' ') } else { 'unknown' } })
        }
        Days             = $Days
        Now              = $now
    }
}

$script:IssueRepoUrl = 'https://github.com/DKJ-Solutions/dkj-claude-plugins/issues'

function Format-IssueGroupCard {
    <# One card of the closed-in-the-window breakdown: -Groups is a list of @{ Name; Count }. #>
    param([string]$Title, [AllowEmptyCollection()][object[]]$Groups, [int]$Total)
    $e = { param($v) ConvertTo-DashboardText $v }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<section class="card">')
    [void]$sb.AppendLine('<div class="card__head"><h2 class="card__title">' + (& $e $Title) + '</h2></div>')
    if (@($Groups).Count) {
        $max = [double](@($Groups)[0].Count)
        [void]$sb.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">' + (& $e $Title) + '</th><th>Issues</th><th class="dp-left">Against the largest</th><th>Share</th></tr></thead><tbody>')
        foreach ($g in @($Groups)) {
            [void]$sb.AppendLine('<tr><td class="dp-left">' + (& $e $g.Name) + '</td><td class="num">' + (Format-DevNumber $g.Count) + '</td>' + (Format-DevShareCell ([double]$g.Count) ([double]$Total) $max) + '</tr>')
        }
        [void]$sb.AppendLine('</tbody></table></div>')
    } else {
        [void]$sb.AppendLine('<p class="note">No issue was closed in the window.</p>')
    }
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}

function Format-IssuesPageHtml {
    <#
        The Issues page from ConvertFrom-IssueList's model. -ReadError is set when gh could not be read;
        -GeneratedAt and -Seconds say when and how long the read took.
    #>
    param(
        $Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$GeneratedAt = '',
        [AllowNull()]$Seconds = $null
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $open = if ($Model) { @($Model.Open) } else { @() }
    $days = if ($Model) { [int]$Model.Days } else { 28 }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Open now'; V = $(if ($Model) { $open.Count } else { '--' }) },
        @{ L = "Opened, last $days days"; V = $(if ($Model) { Format-DevNumber $Model.Opened } else { '--' }) },
        @{ L = "Closed, last $days days"; V = $(if ($Model) { Format-DevNumber $Model.Closed } else { '--' }) },
        @{ L = 'Median time to close'; V = $(if ($Model) { Format-DevDuration $Model.MedianCloseHours } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The issues could not be read from GitHub: ' + (& $e $ReadError) + '.</p>')
    }

    if ($Model) {
        # The open issues: where they stand, then each one.
        [void]$body.AppendLine('<section class="card" id="open">')
        [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Open issues</h2><p class="card__sub">Free is work nobody holds, parked waits on an awaiting-* label, claimed has an assignee</p></div>')
        if ($open.Count) {
            [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Priority</th><th>Free</th><th>Parked</th><th>Claimed</th><th>Total</th></tr></thead><tbody>')
            foreach ($p in $Model.Matrix.Keys) {
                $m = $Model.Matrix[$p]
                $sum = $m.Free + $m.Parked + $m.Claimed
                if (-not $sum) { continue }
                $name = if ($p -ne '0') { 'prio-' + $p } else { 'no priority' }
                [void]$body.AppendLine('<tr><td class="dp-left">' + $name + '</td><td class="num">' + $m.Free + '</td><td class="num">' + $m.Parked + '</td><td class="num">' + $m.Claimed + '</td><td class="num">' + $sum + '</td></tr>')
            }
            [void]$body.AppendLine('</tbody></table></div>')
            [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Issue</th><th class="dp-left">Priority</th><th class="dp-left">State</th><th class="dp-left">Kind</th><th>Age</th></tr></thead><tbody>')
            foreach ($i in $open) {
                $tone = switch ($i.Board) { 'Free' { 'good' } 'Parked' { 'warn' } default { 'info' } }
                $state = '<span class="badge badge--sm badge--' + $tone + '">' + $i.Board + '</span>'
                if ($i.Parked) { $state += ' <code>' + (& $e $i.Parked) + '</code>' }
                if ($i.Assignees.Count) { $state += ' ' + (& $e ($i.Assignees -join ', ')) }
                $age = if ($i.Created -and $Model.Now) { Format-DevDuration (($Model.Now - $i.Created).TotalHours) } else { '--' }
                [void]$body.AppendLine('<tr><td class="dp-left"><a class="dp-link" href="' + $script:IssueRepoUrl + '/' + [int]$i.Number + '" target="_blank" rel="noopener noreferrer">#' + [int]$i.Number + '</a> ' + (& $e $i.Title) + '</td><td class="dp-left">' +
                    $(if ($i.Prio) { 'prio-' + $i.Prio } else { '--' }) + '</td><td class="dp-left">' + $state + '</td><td class="dp-left">' + (& $e $i.Kind) + '</td><td class="num">' + $age + '</td></tr>')
            }
            [void]$body.AppendLine('</tbody></table></div>')
        } else {
            [void]$body.AppendLine('<p class="msg" role="status">No open issue: everything filed has been closed.</p>')
        }
        [void]$body.AppendLine('</section>')

        # The flow: opened against closed, per week of the window.
        $weeks = @($Model.Weeks)
        $peak = [double](@($weeks | ForEach-Object { $_.Opened; $_.Closed } | Measure-Object -Maximum).Maximum)
        $bar = { param($n) $w = if ($peak -gt 0) { [Math]::Min(100.0, 100.0 * $n / $peak) } else { 0.0 }
            '<span class="dp-bar" aria-hidden="true"><span style="width: ' + $w.ToString('0.##', $inv) + '%"></span></span>' }
        [void]$body.AppendLine('<section class="card" id="flow">')
        [void]$body.AppendLine('<div class="card__head"><h2 class="card__title">Opened and closed</h2><p class="card__sub">Per week of the last ' + $days + ' days, oldest first</p></div>')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Week</th><th>Opened</th><th class="dp-left"></th><th>Closed</th><th class="dp-left"></th><th>Net</th></tr></thead><tbody>')
        foreach ($w in $weeks) {
            $net = $w.Opened - $w.Closed
            $netTxt = if ($net -gt 0) { '+' + $net } else { [string]$net }
            [void]$body.AppendLine('<tr><td class="dp-left num">' + $w.From.ToString('yyyy-MM-dd', $inv) + ' to ' + $w.To.ToString('yyyy-MM-dd', $inv) + '</td><td class="num">' + $w.Opened + '</td><td class="dp-left">' + (& $bar $w.Opened) +
                '</td><td class="num">' + $w.Closed + '</td><td class="dp-left">' + (& $bar $w.Closed) + '</td><td class="num">' + $netTxt + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
        [void]$body.AppendLine('</section>')

        # What was closed in the window, three ways.
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.Append((Format-IssueGroupCard -Title 'Kind' -Groups $Model.ClosedBy.Kind -Total $Model.Closed))
        [void]$body.Append((Format-IssueGroupCard -Title 'Priority' -Groups $Model.ClosedBy.Prio -Total $Model.Closed))
        [void]$body.AppendLine('</div>')
        [void]$body.Append((Format-IssueGroupCard -Title 'Closed as' -Groups $Model.ClosedBy.Reason -Total $Model.Closed))
    }

    $when = if ($GeneratedAt) {
        $secs = if ($null -ne $Seconds) { ' in ' + ([double]$Seconds).ToString('0.0', $inv) + 's' } else { '' }
        ', read ' + (& $e $GeneratedAt) + $secs
    } else { '' }
    return Format-DevPageHtml -Title 'Issues' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead ('This repo''s GitHub issues: what is open and where it stands, and what came in and went out over the last ' + $days + ' days.') `
        -FooterNote ('Read from GitHub with <code>gh issue list</code>, as the account <code>gh</code> is logged in as on this machine' + $when + ' (<a class="dp-link" href="/refresh?page=issues">read again</a>). The window is bounded because a GitHub search returns at most 1,000 issues.')
}

function Format-ReleaseNotesDevPage {
    <#
        The built release-notes page (#3108), as this dev server serves it: the house stylesheet and theme
        script, the breadcrumb bar and the settings button, put around the page build-release-notes-page.ps1
        leaves in dkj-policy/releases/page/.

        ONLY THIS COPY, NOT THE TEMPLATE. The template is dkj-policy's, shared with every consumer --
        BWJ-Development repos included, which do not take the house style -- and it is deliberately
        self-contained, because a Worker serves it as one string and a request to another origin would leak
        who reads it. So the page is dressed here, on the way out, and the file on disk stays the template's.

        THE ORDER IS THE MECHANISM. The house file goes in AFTER the template's own <style>, so the house
        body (surface, ink, font) wins on equal specificity; then a layer that points the template's own
        tokens at house tokens, so its panel, lines and accent follow whichever theme is picked. Those token
        names are the template's, none of them a house name, so nothing in the house file is redefined.

        A page that is not the template's shape (no <html>, </style>, <body> or </body>) is returned as it
        came: it is still the release notes, and dev-pages.tests.ps1 holds the real template to that shape.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Html,
        [string]$ThemeKey = 'connector-dashboard'
    )
    $htmlRx = [regex]'<html\b[^>]*>'
    $styleEnd = $Html.IndexOf('</style>')
    $bodyRx = [regex]'<body\b[^>]*>'
    $bodyEnd = $Html.LastIndexOf('</body>')
    if (-not $htmlRx.IsMatch($Html) -or $styleEnd -lt 0 -or -not $bodyRx.IsMatch($Html) -or $bodyEnd -lt 0) { return $Html }

    $e = { param($v) ConvertTo-DashboardText $v }
    $head = @(
        '<link rel="stylesheet" href="/house-style.css">'
        '<script src="/house-theme.js"></script>'
        '<style>'
        '/* The template''s tokens, read from the house ones (#3108). */'
        ':root { --bg: var(--primary-1); --panel: var(--primary-2); --ink: var(--primary-9); --ink-soft: var(--primary-8); --ink-faint: var(--primary-6);'
        '  --line: var(--primary-3); --accent: var(--primary-7); --accent-soft: var(--primary-2); --code-bg: var(--primary-1); }'
        'header.masthead h1 { font-family: var(--font-serif); font-weight: 600; color: var(--primary-7); }'
        '</style>'
    ) -join "`n"
    $bar = @(
        '<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>'
        '<li><a href="/">Repo hub</a></li>'
        '<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">Release notes</span></li>'
        '</ol></nav></div></div>'
        '<div id="settings" class="theme-settings--floating"></div>'
    ) -join "`n"
    $settings = '<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>'

    # Back to front, so each index still points where it was read.
    $out = $Html.Substring(0, $bodyEnd) + $settings + "`n" + $Html.Substring($bodyEnd)
    $out = $bodyRx.Replace($out, { param($m) $m.Value + "`n" + $bar }, 1)
    $styleEnd = $out.IndexOf('</style>') + '</style>'.Length
    $out = $out.Substring(0, $styleEnd) + "`n" + $head + $out.Substring($styleEnd)
    # The theme key is the index page's, so a theme picked on one page holds on this one too.
    $out = $htmlRx.Replace($out, ('<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="' + (& $e $ThemeKey) + '">'), 1)
    return $out
}
