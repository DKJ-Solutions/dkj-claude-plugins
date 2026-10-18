<#
.SYNOPSIS
    The Repo hub on '/' of this repo's dev server and its own measurement page (#3097): the test-gate page
    (the per-suite CI durations). No I/O -- the server (scripts/dashboard/serve-connector-dashboard.ps1)
    measures and reads, and hands the results in, so every rule here is tested without a server.

.DESCRIPTION
    THE HUB TAKES THE ONE FORM THE BRAND BOOK LAYS DOWN (house style v0.3.0, "The Repo hub"): the bar
    with its one crumb, the settings button, the intro with the fixed h1, the Pages card (block 7) linking
    the repo's own pages, About this repo and a footer note. This repo is no product and keeps no in-flight
    lists on the hub, so blocks 6 and 8 to 10 are left out. The pages it links are Get-RepoHubPages, the
    two only this repo has. The GENERAL pages -- Artifacts, Issues, Release notes and SessionStart, which
    every DKJ-Solutions repo has -- are no longer built here (#3119): the dkj-solutions plugin ships them as
    a server of its own, and the hub's second card, General, links that server, through the plugin's
    shared Format-GeneralPagesCardHtml, so a page that is this repo's own is never read as one every repo
    has. This file dot-sources the plugin's general-pages-lib.ps1 for the page shell, the number formats and
    the tile and bar helpers the Test gate page shares with those pages, so nothing is written twice.

    ONE SHELL FOR EVERY PAGE BELOW THE HUB. Each page opens with the house breadcrumb bar, its trail
    starting at the Repo hub on '/' and ending at the page itself, unlinked ("Every page: the breadcrumb
    bar"); then the settings button, an intro (eyebrow, h1, lead), the page's own blocks and a footer
    note naming where the data comes from. Format-DevPageHtml is this repo's call of the plugin's
    Format-GeneralPageHtml.

    THE DATA IS THE REPO'S OWN, NOT A SECOND MEASUREMENT. The test-gate page shows
    scripts/tests/suite-durations.json, which record-suite-durations.ps1 writes from CI runs (the
    measure-suites skill). A suite in scripts/tests that the file does not name is counted, because the
    gate charges it the largest recorded value.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED, through connector-dashboard-lib's ConvertTo-DashboardText
    here and the plugin lib's own escape there (the two are the same five replacements).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'connector-dashboard-lib.ps1')
# The plugin's lib: this repo is the plugin's source, so it reads the lib from its own tree.
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\dkj-solutions\scripts\lib\general-pages-lib.ps1')

function Format-DevPageHtml {
    <#
        The whole page around -Body, for this repo's own pages (the Test gate): the plugin's page shell with
        this repo's eyebrow and title, its theme key (the index page's, so a theme picked on one page holds
        on every page of this server) and the Repo hub crumb on '/'.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'connector-dashboard'
    )
    return Format-GeneralPageHtml -Title $Title -Lead $Lead -Body $Body -Style $Style -FooterNote $FooterNote -ThemeKey $ThemeKey `
        -Eyebrow 'DKJ-Solutions/dkj-claude-plugins' -SiteName 'dkj-claude-plugins' -HubHref '/'
}

function Get-RepoHubPages {
    <#
        The pages the Repo hub links in its "This repo" card, in the order it lists them: each a route on this
        server, its label the page's own name as its breadcrumb reads it, and one line on what it shows. The
        general pages are the plugin's (Get-GeneralPages), on a server of their own.
    #>
    @(
        @{ Href = '/connectors'; Label = 'Connectors'; Sub = 'Every repo registered under connectors/, as check-connectors.ps1 reports it on this machine' },
        @{ Href = '/test-gate';  Label = 'Test gate';  Sub = 'What each test suite costs on CI' }
    )
}

function Format-RepoHubHtml {
    <#
        The Repo hub on '/'. -Pages is Get-RepoHubPages' shape; -SourceCommit is the short sha the server
        reads, or empty; -GeneralPagesUrl is the general pages server's base url when it answers, or empty
        (the General card then says it is not running).
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Pages,
        [AllowEmptyString()][string]$SourceCommit = '',
        [AllowEmptyString()][string]$GeneralPagesUrl = ''
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
    # draws the line between them. The General card is the plugin's, the same in every hub
    # (Format-GeneralPagesCardHtml): it links the general pages server at -GeneralPagesUrl, or says it is not
    # running. It is always drawn; the repo's own card is drawn when there is a page for it, and one card
    # alone is block 7 as the form gives it, its title the h2.
    $repoRows = @($Pages)
    $row = $repoRows.Count -gt 0
    if ($row) {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Pages</h2><p class="card__sub">Every page this dev server serves, and the general ones beside it</p></div>')
        [void]$sb.AppendLine('<section class="card grid__card">')
        [void]$sb.AppendLine('<div class="card__head"><h3>This repo</h3><p class="card__sub">Specific to this repo</p></div>')
        [void]$sb.AppendLine('<nav class="menu-list" aria-label="This repo pages">')
        foreach ($p in $repoRows) {
            $sub = if ($p.Sub) { '<span class="menu-item__sub">' + (& $e $p.Sub) + '</span>' } else { '' }
            [void]$sb.AppendLine('<a class="menu-item" href="' + (& $e $p.Href) + '"><span class="menu-item__label">' + (& $e $p.Label) + $sub + '</span>' + $script:RepoHubChevron + '</a>')
        }
        [void]$sb.AppendLine('</nav>')
        [void]$sb.AppendLine('</section>')
    }
    [void]$sb.Append((Format-GeneralPagesCardHtml -PagesUrl $GeneralPagesUrl -InRow $row))
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
