<#
.SYNOPSIS
    The Repo hub on '/' of this repo's dev server and its own pages: the test-gate page (the per-suite CI
    durations, #3097), the Specialists page, and the status page /brandbook/ answers with when the brandbook/ app's
    build cannot be served (its paths and content types are dkj-solutions-pages-lib's, #3210). No I/O -- the server
    (scripts/dashboard/serve-connector-dashboard.ps1) measures and reads, and hands the results in, so every rule here is tested without a server.

.DESCRIPTION
    THE HUB TAKES THE ONE FORM THE BRAND BOOK LAYS DOWN (house style v0.3.0, "The Repo hub"): the bar
    with its one crumb, the settings button, the intro with the fixed h1, the Pages block (block 7: the
    'This repo' card linking the repo's own pages, then the General card), About this repo and a footer note. This repo is no product and keeps no in-flight
    lists on the hub, so blocks 6 and 8 to 10 are left out. The pages it links are Get-RepoHubPages, the
    ones only this repo has. The GENERAL pages -- Artifacts, Issues, Release notes and SessionStart, which
    every repo has -- are no longer built here (#3119): the dkj-policy plugin ships them (since #3198) as
    a server of its own, and the hub's second card, General, links that server, through the plugin's
    shared Format-GeneralPagesCardHtml, so a page that is this repo's own is never read as one every repo
    has. The Brandbook went the same way: the house style is every DKJ-Solutions repo's, so it is the
    dkj-solutions plugin's page, in the hub's third card, DKJ-Solutions. This server still answers /brandbook itself,
    from this tree, so a house-style change shows here before it is released. This file dot-sources the plugin's general-pages-lib.ps1 for the page shell, the number formats and
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

    THE DKJ REPOS PAGE (#3231) is this hub's own, listed in the DKJ-Solutions card after the plugin's pages
    (Get-RepoHubDkjPages): every DKJ-Solutions repo on GitHub, its checkout beside this repo, and the command
    that opens Claude Code there. Find-DkjCheckouts is the one function in this file that reads the disk.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED, through connector-dashboard-lib's ConvertTo-DashboardText
    here and the plugin lib's own escape there (the two are the same five replacements).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'connector-dashboard-lib.ps1')
# The plugins' libs: this repo is their source, so it reads them from its own tree -- dkj-policy's page shell and
# General card, then dkj-solutions' DKJ-Solutions card, which builds on that shell (#3198).
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\general-pages-lib.ps1')
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\dkj-solutions\scripts\lib\dkj-solutions-pages-lib.ps1')

function Format-DevPageHtml {
    <#
        The whole page around -Body, for this repo's own pages (the Test gate): the plugin's page shell with
        this repo's eyebrow and title, its theme key (the general pages' own, so a theme picked on one page
        holds on every page this server serves, the general pages it relays included, #3168) and the Repo
        hub crumb on '/'.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'general-pages'
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
        @{ Href = '/connectors';  Label = 'Connectors';  Sub = 'Every repo registered under connectors/, as check-connectors.ps1 reports it on this machine' },
        @{ Href = '/specialists'; Label = 'Specialists'; Sub = 'Every specialist the plugins ship, and how much context each one costs' },
        @{ Href = '/test-gate';   Label = 'Test gate';   Sub = 'What each test suite costs on CI' }
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
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- Repo hub</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # No page layer of its own: the heading above a group of cards (.grid__head), a card that takes the whole
    # row (.grid__full) and a card's margin inside a .grid-2 are the house style's own since #3133, so every
    # h2 in a grid__head carries a short sub line, the house .card__sub, and nothing here restyles them.
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
    # running. The DKJ-Solutions card (Format-DkjSolutionsPagesCardHtml) follows it, the same card with the
    # pages only DKJ-Solutions repos share, so on a wide screen it opens the row below. Both are always
    # drawn; the repo's own card is drawn when there is a page for it, and one card
    # alone is block 7 as the form gives it: its h2 still stands above the card, never inside it (#3175).
    $repoRows = @($Pages)
    $row = $repoRows.Count -gt 0
    if ($row) {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Pages</h2><p class="card__sub">Every page this dev server serves, and the shared ones beside it</p></div>')
        [void]$sb.AppendLine('<section class="card">')
        [void]$sb.AppendLine('<div class="card__head"><h3>This repo</h3><p class="card__sub">Specific to this repo</p></div>')
        [void]$sb.AppendLine('<nav class="menu-list" aria-label="This repo pages">')
        foreach ($p in $repoRows) {
            $sub = if ($p.Sub) { '<span class="menu-item__sub">' + (& $e $p.Sub) + '</span>' } else { '' }
            [void]$sb.AppendLine('<a class="menu-item" href="' + (& $e $p.Href) + '"><span class="menu-item__label">' + (& $e $p.Label) + $sub + '</span>' + $script:RepoHubChevron + '</a>')
        }
        [void]$sb.AppendLine('</nav>')
        [void]$sb.AppendLine('</section>')
    }
    [void]$sb.Append((Format-GeneralPagesCardHtml -PagesUrl $GeneralPagesUrl -InRow $row -SameOrigin))
    [void]$sb.Append((Format-DkjSolutionsPagesCardHtml -PagesUrl $GeneralPagesUrl -InRow $row -SameOrigin -LocalPages @(Get-RepoHubDkjPages)))
    if ($row) { [void]$sb.AppendLine('</div>') }

    # Block 11: About this repo, the fixed title, with this repo's own facts. Its h2 stands outside the
    # card in a grid__head, as Pages' does, so the two blocks read alike and stay apart; the card spans
    # both columns of a grid-2 row of its own, which gives head and card the same gap as the Pages row.
    [void]$sb.AppendLine('<div class="grid-2">')
    [void]$sb.AppendLine('<div class="grid__head"><h2>About this repo</h2><p class="card__sub">What this repo is, and the commit this hub is served from</p></div>')
    [void]$sb.AppendLine('<section class="card grid__full">')
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
        not record); Stale (names the file records that are no longer on disk); Runs; Date; Machine; Method;
        Groups; Ungrouped; Unknown }.

        -Groups is the parsed groups array of suite-groups.json, $null when that file is missing or unreadable.
        Groups is then one @{ Key; Title; Guards; Tips; Split; Suites; Unmeasured; Total } per group, in the file's order,
        each holding its recorded suites slowest first and, in Unmeasured, its suites on disk with no recorded
        duration yet; Ungrouped names every suite on disk or recorded that no group holds, and Unknown every
        name a group holds that is not on disk. With no -Groups all three are empty.
    #>
    param($Durations, [AllowEmptyCollection()][string[]]$SuiteFiles = @(), $Groups = $null)
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
    $groupRows = @(); $grouped = @{}
    foreach ($g in @($Groups | Where-Object { $_ })) {
        $members = @{}
        foreach ($n in @($g.suites | Where-Object { $_ })) { $members[[string]$n] = $true; $grouped[[string]$n] = $true }
        $in = @($suites | Where-Object { $members.ContainsKey($_.Name) })
        $groupRows += @{
            Key      = [string]$g.key
            Title    = [string]$g.title
            Guards   = [string]$g.guards
            Tips     = @(@($g.tips) | Where-Object { $_ } | ForEach-Object { [string]$_ })
            Split    = [string]$g.split
            Suites   = $in
            Unmeasured = @(@($SuiteFiles) | Where-Object { $_ -and $members.ContainsKey($_) -and -not $recorded.ContainsKey($_) } | Sort-Object)
            Total  = [double](($in | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        }
    }
    $known = @(@($SuiteFiles | Where-Object { $_ }) + @($suites | ForEach-Object { $_.Name })) | Sort-Object -Unique
    return @{
        Groups    = $groupRows
        Ungrouped = @(if ($groupRows.Count) { $known | Where-Object { -not $grouped.ContainsKey($_) } })
        Unknown   = @(if ($onDisk.Count) { $grouped.Keys | Where-Object { -not $onDisk.ContainsKey($_) } | Sort-Object })
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
    <#
        The test-gate page from ConvertFrom-SuiteDurations' model. -ReadError is set when suite-durations.json
        could not be read, -GroupsError when suite-groups.json could not be; without groups the page lists the
        suites in one table, slowest first, as it did before the groups existed.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$ReadError = '', [AllowEmptyString()][string]$GroupsError = '')
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
    if ($GroupsError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/tests/suite-groups.json could not be read: ' + (& $e $GroupsError) + ', so the suites are listed ungrouped.</p>')
    }
    if (@($Model.Ungrouped).Count) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">In no group of scripts/tests/suite-groups.json: ' +
            ((@($Model.Ungrouped) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
    }
    if (@($Model.Unknown).Count) {
        [void]$body.AppendLine('<p class="msg" role="status">Grouped but no longer on disk: ' +
            ((@($Model.Unknown) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
    }
    # One suite table: the same columns for the ungrouped list and for each group, each bar drawn against
    # the slowest suite of all and each share of the whole sum, so two groups' rows read on one scale.
    # A group's suites with no recorded duration close its table, so a group lists every suite it holds.
    $suiteTable = {
        param($Rows, $Unmeasured = @())
        $t = '<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th>Seconds</th><th class="dp-left">Against the slowest</th><th>Share of the sum</th></tr></thead><tbody>' + "`n"
        foreach ($s in @($Rows)) {
            $stale = if (@($Model.Stale) -contains $s.Name) { ' <span class="badge badge--sm badge--neutral">no longer on disk</span>' } else { '' }
            $t += '<tr><td class="dp-left"><code>' + (& $e $s.Name) + '</code>' + $stale + '</td><td class="num">' +
                ([double]$s.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + '</td>' + (Format-DevShareCell $s.Seconds $Model.Total $slowest.Seconds) + '</tr>' + "`n"
        }
        foreach ($n in @($Unmeasured)) {
            $t += '<tr><td class="dp-left"><code>' + (& $e $n) + '</code> <span class="badge badge--sm badge--neutral">not recorded yet</span></td><td class="num">--</td><td class="dp-left"></td><td>--</td></tr>' + "`n"
        }
        $sum = [double]((@($Rows) | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        return $t + '</tbody>' + (& $totalRow $sum (@($Rows).Count + @($Unmeasured).Count) 2) + '</table></div>'
    }
    # The closing row of a table: the sum of its seconds, one after another, which is not what CI waits --
    # the gate spreads the suites over shards and lanes -- so the label says so. -Pad is the count of
    # columns between the label and the seconds.
    $totalRow = {
        param([double]$Sum, [int]$Count, [int]$Pad)
        $pct = if ($Model.Total -gt 0) { (100.0 * $Sum / $Model.Total).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) } else { '0.0' }
        $mid = if ($Pad -gt 2) { '<td class="num">' + $Count + '</td>' } else { '' }
        $what = if ($Pad -gt 2) { 'all groups' } else { "$Count suites" }
        return '<tfoot><tr class="row-total dp-total"><td class="dp-left">Total <span class="note">' + $what + ', run one after another; CI runs them in parallel</span></td>' + $mid +
            '<td class="num">' + (Format-DevSeconds $Sum) + '</td><td class="dp-left"></td><td>' + $pct + '%</td></tr></tfoot>'
    }
    # A section's points to note, closing the section below its card as a full grid row of their own:
    # nothing when there are none.
    $tipsBlock = {
        param($Tips)
        $items = @(@($Tips) | Where-Object { $_ })
        if (-not $items.Count) { return '' }
        return '<div class="grid__full dp-tips"><h3>Points to note</h3><ul>' + (($items | ForEach-Object { '<li>' + (& $e $_) + '</li>' }) -join '') + '</ul></div>'
    }
    $groups = @($Model.Groups)
    if ($groups.Count -and $suites.Count) {
        [void]$body.AppendLine('<div class="grid-2" id="groups">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Groups</h2><p class="card__sub">What each group of suites guards. CI runs every suite on every PR, whichever group it is in</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Group</th><th>Suites</th><th>Seconds</th><th class="dp-left">Against the slowest group</th><th>Share of the sum</th></tr></thead><tbody>')
        $heaviest = ($groups | ForEach-Object { $_.Total } | Measure-Object -Maximum).Maximum
        foreach ($g in $groups) {
            [void]$body.AppendLine('<tr><td class="dp-left"><a class="dp-link" href="#group-' + (& $e $g.Key) + '">' + (& $e $g.Title) + '</a><br><span class="note">' + (& $e $g.Guards) +
                '</span></td><td class="num">' + (@($g.Suites).Count + @($g.Unmeasured).Count) + '</td><td class="num">' + (Format-DevSeconds $g.Total) + '</td>' + (Format-DevShareCell $g.Total $Model.Total $heaviest) + '</tr>')
        }
        $allCount = ($groups | ForEach-Object { @($_.Suites).Count + @($_.Unmeasured).Count } | Measure-Object -Sum).Sum
        $allSum = [double](($groups | ForEach-Object { $_.Total } | Measure-Object -Sum).Sum)
        [void]$body.AppendLine('</tbody>' + (& $totalRow $allSum $allCount 3) + '</table></div>')
        [void]$body.AppendLine('</section>')
        # The split candidates are the groups suite-groups.json gives a split for, largest first: which ones
        # is a judgement written into that file, and the counts beside them are measured here.
        $candidates = @($groups | Where-Object { $_.Split } | Sort-Object @{ Expression = { $_.Total }; Descending = $true } | ForEach-Object {
                $_.Title + ' (' + (@($_.Suites).Count + @($_.Unmeasured).Count) + ' suites, ' +
                $(if ($Model.Total -gt 0) { (100.0 * $_.Total / $Model.Total).ToString('0', [Globalization.CultureInfo]::InvariantCulture) } else { '0' }) + '%)' })
        [void]$body.AppendLine((& $tipsBlock @(
            'The seconds are summed as if every suite ran one after another. CI splits the suites over four shards that run side by side, and a shard has taken roughly 6 to 13 minutes.',
            'A group''s name jumps to its own table below.',
            $(if ($candidates.Count) { 'Candidates to split, largest first: ' + ($candidates -join '; ') + '. Each one''s own notes say how. A split changes only how this page reads, never what runs.' }))))
        [void]$body.AppendLine('</div>')
        foreach ($g in $groups) {
            [void]$body.AppendLine('<div class="grid-2" id="group-' + (& $e $g.Key) + '">')
            [void]$body.AppendLine('<div class="grid__head"><h2>' + (& $e $g.Title) + '</h2><p class="card__sub">Guards ' + (& $e $g.Guards) + '</p></div>')
            [void]$body.AppendLine('<section class="card grid__full">')
            if (@($g.Suites).Count + @($g.Unmeasured).Count) { [void]$body.AppendLine((& $suiteTable $g.Suites $g.Unmeasured)) }
            else { [void]$body.AppendLine('<p class="note">No suite of this group is on disk.</p>') }
            [void]$body.AppendLine('</section>')
            [void]$body.AppendLine((& $tipsBlock (@($g.Tips) + @($(if ($g.Split) { 'Could be split into ' + $g.Split })))))
            [void]$body.AppendLine('</div>')
        }
        $loose = @($suites | Where-Object { @($Model.Ungrouped) -contains $_.Name })
        $looseUnmeasured = @(@($Model.Ungrouped) | Where-Object { @($Model.Missing) -contains $_ })
        if ($loose.Count + $looseUnmeasured.Count) {
            [void]$body.AppendLine('<div class="grid-2" id="ungrouped">')
            [void]$body.AppendLine('<div class="grid__head"><h2>Not grouped</h2><p class="card__sub">Suites no group holds yet</p></div>')
            [void]$body.AppendLine('<section class="card grid__full">')
            [void]$body.AppendLine((& $suiteTable $loose $looseUnmeasured))
            [void]$body.AppendLine('</section>')
            [void]$body.AppendLine((& $tipsBlock @('Add each one to the group whose workflow step it guards, in scripts/tests/suite-groups.json. dev-pages.tests.ps1 stays red until you do.')))
            [void]$body.AppendLine('</div>')
        }
    } else {
        [void]$body.AppendLine('<div class="grid-2" id="suites">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Suites</h2><p class="card__sub">Mean CI duration per suite, slowest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        if ($suites.Count) { [void]$body.AppendLine((& $suiteTable $suites)) }
        else { [void]$body.AppendLine('<p class="note">No suite durations are recorded.</p>') }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine((& $tipsBlock @('Without scripts/tests/suite-groups.json the suites are listed in one table; CI still runs every one of them on every PR.')))
        [void]$body.AppendLine('</div>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="recorded">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Where it was measured</h2></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Machine</dt><dd>' + $(if ($Model.Machine) { & $e $Model.Machine } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
    $runs = (@($Model.Runs) | Where-Object { $_ -match '^\d+$' } | ForEach-Object {
            '<a class="dp-link" href="https://github.com/DKJ-Solutions/dkj-claude-plugins/actions/runs/' + $_ + '">' + $_ + '</a>' }) -join ', '
    [void]$body.AppendLine('<div><dt>CI runs</dt><dd>' + $(if ($runs) { $runs } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine((& $tipsBlock @(
        'A suite not recorded yet is charged the largest recorded duration when the gate packs its shards, so a new suite starts early rather than last.',
        'Refresh with scripts/maintenance/record-suite-durations.ps1 once a suite has been added or has grown.')))
    [void]$body.AppendLine('</div>')
    # The house's .row-total sets the weight; the rule above it, heavier than a row's own, is this page's.
    $style = $script:DevBarStyle + "`n" + '.dp-total td { border-top: 2px solid var(--paper-4); }'
    return Format-DevPageHtml -Title 'Test gate' -Style $style -Body $body.ToString() `
        -Lead 'What each test suite costs on CI, grouped by the workflow step it guards. No suite is optional: the required CI check runs every one on every PR, while open-pr runs locally only those the branch can affect. A group says what breaks when its suites go red, not when they run. Measured on CI runners, never on a workstation: a local reading does not convert.' `
        -FooterNote 'Read from <code>scripts/tests/suite-durations.json</code>, grouped by <code>scripts/tests/suite-groups.json</code>. Refreshed by <code>scripts/maintenance/record-suite-durations.ps1</code>; the <code>measure-suites</code> skill compares two sets of runs.'
}

function Format-BrandbookStatusHtml {
    <#
        The page /brandbook answers with when there is no build to serve: brandbook/ is missing, the build
        is switched off, or it failed. -Message says which, -Detail carries the build's last output lines.
    #>
    param([Parameter(Mandatory = $true)][string]$Message, [AllowEmptyString()][string]$Detail = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $body = '<p class="msg msg--warn" role="alert">' + (& $e $Message) + '</p>'
    if ($Detail) { $body += "`n" + '<pre class="note">' + (& $e $Detail) + '</pre>' }
    return Format-DevPageHtml -Title 'Brandbook' -Style $script:DevBarStyle -Body $body `
        -Lead 'The DKJ-Solutions brand book: the house style''s tokens, themes and components, built from brandbook/ in this checkout.' `
        -FooterNote 'Built with <code>npm run build</code> in <code>brandbook/</code>; the hub rebuilds it when its sources or the house style change.'
}

function ConvertTo-SpecialistRow {
    <#
        One specialist from its definition file. -Text is the file as read (a subagent definition or a
        persona); -ManualBytes and -LensBytes are the sizes of its manual and this repo's lens, $null where
        there is none. Returns @{ Id; Number; Name; Emoji; Title; Plugin; Form; Enabled; ListingBytes;
        DefinitionBytes; ManualBytes; LensBytes; TotalBytes; AlwaysOn }.

        WHAT EACH PART IS. The listing is a subagent's frontmatter description, which Claude Code puts in
        every session that enables its plugin; a persona has none. The definition is the file without its
        frontmatter: a subagent's system prompt when it is spawned, or a persona's body when it is read --
        and the orchestrator's persona (01-01) is imported on every turn, which is what AlwaysOn says. The
        manual and the lens are read on demand.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Plugin,
        [Parameter(Mandatory = $true)][ValidateSet('subagent', 'persona')][string]$Form,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [AllowNull()]$ManualBytes,
        [AllowNull()]$LensBytes,
        [bool]$Enabled = $false
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $lines = @($Text.Replace("`r`n", "`n").Split("`n"))
    $front = @(); $bodyFrom = 0
    if ($lines.Count -gt 1 -and $lines[0].TrimStart([char]0xFEFF) -eq '---') {
        for ($j = 1; $j -lt $lines.Count; $j++) {
            # An empty block ($j = 1) would make 1..0 a descending range, so it is guarded.
            if ($lines[$j] -eq '---') { if ($j -gt 1) { $front = @($lines[1..($j - 1)]) }; $bodyFrom = $j + 1; break }
        }
    }
    $body = if ($bodyFrom -lt $lines.Count) { ($lines[$bodyFrom..($lines.Count - 1)]) -join "`n" } else { '' }

    # The description: an inline value, or a folded/literal block of the indented lines below it.
    $desc = ''
    for ($k = 0; $k -lt $front.Count; $k++) {
        if ($front[$k] -match '^description:\s*(.*)$') {
            $v = $Matches[1].Trim()
            if ($v -match '^[>|][-+]?$') {
                $parts = @()
                for ($m = $k + 1; $m -lt $front.Count -and $front[$m] -match '^\s+\S|^\s*$'; $m++) { $parts += $front[$m].Trim() }
                $desc = ($parts | Where-Object { $_ }) -join ' '
            } else { $desc = $v.Trim('"', "'") }
            break
        }
    }

    # The name, emoji and title: a subagent says "You are **Name E**, the Title."; a persona's h1 is
    # "# Name E -- the Title (*...*)", with an em dash.
    $who = ''; $title = ''
    if ($Form -eq 'subagent' -and $body -match '(?m)^You are \*\*(.+?)\*\*,\s+(?:the\s+)?([^.]+?)\.') {
        $who = $Matches[1]; $title = $Matches[2]
    } elseif ($body -match ('(?m)^#\s+(.+?)\s+' + [char]0x2014 + '\s+(?:the\s+)?(.+?)\s*$')) {
        $who = $Matches[1]; $title = $Matches[2] -replace '\s*\(\*[^)]*\*\)\s*$', ''
    }
    $title = ($title -replace '\s+', ' ').Trim()
    $name = ($who -split '\s+', 2)[0]
    $emoji = if ($who -match '^\S+\s+(.+)$') { $Matches[1].Trim() } else { '' }
    if (-not $name) { $name = $Id }

    $listing = if ($desc) { [int64]$utf8.GetByteCount($desc) } else { [int64]0 }
    $definition = [int64]$utf8.GetByteCount($body)
    $total = $listing + $definition + $(if ($null -ne $ManualBytes) { [int64]$ManualBytes } else { 0 }) + $(if ($null -ne $LensBytes) { [int64]$LensBytes } else { 0 })
    return @{
        Id = $Id; Number = ($Id -split '-')[-1]; Name = $name; Emoji = $emoji; Title = $title
        Plugin = $Plugin; Form = $Form; Enabled = $Enabled
        ListingBytes = $listing; DefinitionBytes = $definition
        ManualBytes = $(if ($null -ne $ManualBytes) { [int64]$ManualBytes } else { $null })
        LensBytes = $(if ($null -ne $LensBytes) { [int64]$LensBytes } else { $null })
        TotalBytes = $total; AlwaysOn = ($Id -eq '01-01')
    }
}

function Format-SpecialistsPageHtml {
    <#
        The Specialists page. -Rows is ConvertTo-SpecialistRow's shape; -CharsPerToken the calibrated
        factor (measure-context-lib's Get-CalibratedCharsPerToken). The bytes are measured, the tokens an
        estimate at that factor, and the page says which is which.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [AllowEmptyString()][string]$ReadError = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $tok = { param($b) if ($null -eq $b) { '--' } elseif ([int64]$b -eq 0) { '--' } else { '~' + (Format-DevNumber ([Math]::Round([double]$b / $CharsPerToken))) } }
    $rows = @($Rows | Where-Object { $_ } | Sort-Object @{ Expression = { [int64]$_.TotalBytes }; Descending = $true }, @{ Expression = { $_.Id } })
    $enabled = @($rows | Where-Object { $_.Enabled })
    # Summed by hand: 5.1's Measure-Object -Property does not read a hashtable's keys.
    $listingHere = [int64]0
    foreach ($r in $enabled) { $listingHere += [int64]$r.ListingBytes }
    $max = if ($rows.Count) { [double]$rows[0].TotalBytes } else { 0 }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Specialists'; V = $rows.Count },
        @{ L = 'Enabled here'; V = $enabled.Count },
        @{ L = 'Listing, every session here'; V = (& $tok $listingHere) },
        @{ L = 'Largest full read'; V = $(if ($rows.Count) { $rows[0].Name + ' ' + (& $tok $rows[0].TotalBytes) } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The specialists could not all be read: ' + (& $e $ReadError) + '.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="specialists">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Context per specialist</h2><p class="card__sub">Estimated tokens, largest full read first. The bar is the full read against the largest one</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($rows.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Specialist</th><th class="dp-left">Plugin</th><th>Listing</th><th>Definition</th><th>Manual</th><th>Lens</th><th>Full read</th><th class="dp-left">Against the largest</th></tr></thead><tbody>')
        foreach ($r in $rows) {
            # Muted text, not .badge: the house badge is an 18px circle for one character, and a word in it
            # spills over the text beside it.
            $badges = '<span class="note">&middot; ' + (& $e $r.Form) + $(if ($r.AlwaysOn) { ' &middot; always-on' } else { '' }) + '</span>'
            $plugin = (& $e ($r.Plugin -replace '^dkj-subagents-', '')) + $(if ($r.Enabled) { '' } else { ' <span class="note">(off here)</span>' })
            $w = $(if ($max -gt 0) { [Math]::Min(100.0, 100.0 * [double]$r.TotalBytes / $max) } else { 0.0 }).ToString('0.##', $inv)
            $label = (& $e $r.Name) + $(if ($r.Emoji) { ' ' + (& $e $r.Emoji) } else { '' })
            # One line per specialist: the title follows the name inline and the badges sit with the plugin,
            # where a block-level title and badge row gave every specialist three lines.
            [void]$body.AppendLine('<tr><td class="dp-left"><strong>' + $label + '</strong> <span class="note">#' + (& $e $r.Number) +
                $(if ($r.Title) { ' &middot; ' + (& $e $r.Title) } else { '' }) + '</span></td>' +
                '<td class="dp-left">' + $plugin + ' ' + $badges + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ListingBytes) + ' B">' + (& $tok $r.ListingBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.DefinitionBytes) + ' B">' + (& $tok $r.DefinitionBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ManualBytes) + ' B">' + (& $tok $r.ManualBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.LensBytes) + ' B">' + (& $tok $r.LensBytes) + '</td>' +
                '<td class="num"><strong>' + (& $tok $r.TotalBytes) + '</strong></td>' +
                '<td class="dp-left"><span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span></td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No specialist was found.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine('<div class="grid-2" id="when">')
    [void]$body.AppendLine('<div class="grid__head"><h2>When each part loads</h2></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Listing</dt><dd>A subagent''s description. Every session of a repo that enables its plugin carries it, whether the specialist is called or not. A persona has none.</dd></div>')
    [void]$body.AppendLine('<div><dt>Definition</dt><dd>The file without its frontmatter: a subagent''s system prompt each time it is spawned, or a persona''s body when it is read. The orchestrator''s persona is imported on every turn.</dd></div>')
    [void]$body.AppendLine('<div><dt>Manual</dt><dd>The portable playbook, read on demand.</dd></div>')
    [void]$body.AppendLine('<div><dt>Lens</dt><dd>This repo''s own lens, read on demand. A plugin not enabled here has none.</dd></div>')
    [void]$body.AppendLine('<div><dt>Full read</dt><dd>All four together: what a specialist costs when everything about it is in context.</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    $factor = $CharsPerToken.ToString('0.00', $inv)
    return Format-DevPageHtml -Title 'Specialists' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead 'Every specialist the dkj-subagents plugins ship, and how much context each one brings along: what every session pays for it, what it costs when it is called, and what its manual and lens add.' `
        -FooterNote ('Read from this checkout''s <code>plugins/dkj-subagents/</code> and <code>.claude/specialists/lenses/</code> on every request, so it is the tree, not the installed release. Bytes are measured (hover a cell); tokens are an estimate at ' + $factor + ' characters per token, the factor in <code>scripts/lib/measure-context-lib.ps1</code>.')
}

function Get-RepoHubDkjPages {
    <#
        The DKJ-Solutions pages only this hub has, listed in the hub's DKJ-Solutions card after the plugin's own
        (#3231): this server answers them, so they are linked whether or not the general pages server runs.
    #>
    @(
        @{ Href = '/dkj-repos'; Label = 'DKJ repos'; Sub = 'Every DKJ-Solutions repo: its checkout on this machine, its open issues, and a session to open there' }
    )
}

function Find-DkjCheckouts {
    <#
        Every checkout of an -Owner repo directly under -ParentDir (#3231): a folder whose .git is a DIRECTORY
        and whose origin is github.com/<Owner>/<name>. A worktree's .git is a file, so a lane of a repo never
        stands in for its checkout. Returns @{ Repo; Path; Branch; Dirty } per checkout; Branch is '' where git
        does not answer, Dirty the count of uncommitted paths. THIS FUNCTION READS THE DISK AND RUNS GIT, the one
        that does in this file, because the server and repo-session.ps1 must find a checkout the same way.
    #>
    param([Parameter(Mandatory = $true)][string]$ParentDir, [string]$Owner = 'DKJ-Solutions')
    $git = {
        param([string]$Path, [string[]]$GitArgs)
        # 'Continue' and the catch: under 'Stop', Windows PowerShell 5.1 turns a native command's stderr into a
        # terminating error even with 2>$null.
        $ErrorActionPreference = 'Continue'
        # The folders are found by a scan, not named by anybody, so git reads nothing from them that could run
        # code (core.fsmonitor) and writes nothing (--no-optional-locks: status would refresh the index).
        try { $out = & git --no-optional-locks -c core.fsmonitor=false -C $Path @GitArgs 2>$null } catch { return $null }
        if ($LASTEXITCODE -ne 0) { return $null }
        return , @($out)
    }
    $found = @()
    foreach ($d in @(Get-ChildItem -LiteralPath $ParentDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName '.git') -PathType Container)) { continue }
        $url = & $git $d.FullName @('remote', 'get-url', 'origin')
        if (-not $url) { continue }
        $repo = ConvertFrom-GitRemoteUrl ([string]$url[0])
        if (-not $repo -or ($repo -split '/')[0] -ne $Owner) { continue }
        $branch = & $git $d.FullName @('rev-parse', '--abbrev-ref', 'HEAD')
        $status = & $git $d.FullName @('status', '--porcelain')
        $found += @{ Repo = $repo; Path = $d.FullName; Branch = $(if ($branch) { [string]$branch[0] } else { '' }); Dirty = @($status | Where-Object { $_ }).Count }
    }
    return $found
}

function Get-DkjRepoQuery {
    <#
        The one GraphQL query the DKJ repos page asks: every repo of the organisation named by the variable
        $owner (gh api graphql -f owner=...), newest push first, with its open issue and pull request counts.
        The name goes as a variable, not inline: the query then holds no double quote, which Windows PowerShell
        5.1 would split on its way to gh.
    #>
    return 'query($owner: String!) { organization(login: $owner) { repositories(first: 100, orderBy: {field: PUSHED_AT, direction: DESC}) { nodes { name nameWithOwner url description visibility isArchived pushedAt issues(states: OPEN) { totalCount } pullRequests(states: OPEN) { totalCount } } } } }'
}

function ConvertFrom-DkjRepoQuery {
    <#
        Get-DkjRepoQuery's answer, as text, into @{ Repos; Archived; Error }: Repos the live repos in the order
        GitHub gave them, each @{ Repo; Name; Url; Description; Visibility; PushedAt; Issues; Pulls }; Archived
        the 'owner/name' of each one left out. An answer that is not that shape is an Error, never an empty organisation.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Json)
    $none = @{ Repos = @(); Archived = @(); Error = '' }
    if (-not $Json) { $none.Error = 'gh gave no answer'; return $none }
    try { $doc = $Json | ConvertFrom-Json } catch { $none.Error = 'the answer is not JSON'; return $none }
    if ($doc.errors) { $none.Error = 'GitHub answered with an error: ' + ([string]@($doc.errors)[0].message); return $none }
    $nodes = $doc.data.organization.repositories.nodes
    if ($null -eq $nodes) { $none.Error = 'the answer holds no repository list'; return $none }
    $repos = @(); $archived = @()
    foreach ($n in @($nodes)) {
        if (-not $n) { continue }
        if ($n.isArchived) { $archived += [string]$n.nameWithOwner; continue }
        $repos += @{
            Repo = [string]$n.nameWithOwner; Name = [string]$n.name; Url = [string]$n.url; Description = [string]$n.description
            Visibility = ([string]$n.visibility).ToLowerInvariant(); PushedAt = [string]$n.pushedAt
            Issues = [int]$n.issues.totalCount; Pulls = [int]$n.pullRequests.totalCount
        }
    }
    return @{ Repos = $repos; Archived = $archived; Error = '' }
}

function Get-CopyButtonScript {
    <#
        The script behind every [data-copy] button. The clipboard API first; then execCommand on a hidden
        textarea, because VS Code's Simple Browser serves the page in an iframe without clipboard-write, where
        the API is refused (the owner's own browser, #3231); and where both fail, the first <code> beside the
        button is selected for Ctrl+C.
    #>
    return '<script>(function () {' + "`n" +
        'function label(b, t) { b.textContent = t; setTimeout(function () { b.textContent = "Copy"; }, 2000); }' + "`n" +
        'function fallback(b, text) { var ta = document.createElement("textarea"); ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0"; document.body.appendChild(ta); ta.select(); var ok = false; try { ok = document.execCommand("copy"); } catch (e) { ok = false; } document.body.removeChild(ta);' + "`n" +
        '  if (ok) { label(b, "Copied"); return; } var code = b.parentNode.querySelector("code"); if (code) { var r = document.createRange(); r.selectNodeContents(code); var sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(r); } label(b, "Press Ctrl+C"); }' + "`n" +
        'document.addEventListener("click", function (ev) { var b = ev.target.closest("[data-copy]"); if (!b) return; var text = b.getAttribute("data-copy");' + "`n" +
        '  if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(text).then(function () { label(b, "Copied"); }, function () { fallback(b, text); }); } else { fallback(b, text); } });' + "`n" +
        '})();</script>'
}

function Format-DkjReposPageHtml {
    <#
        The DKJ repos page (#3231). -Query is ConvertFrom-DkjRepoQuery's result; -Checkouts is Find-DkjCheckouts'
        list; -Meta is @{ GeneratedAt; Seconds }. A checkout whose repo GitHub did not list (the query failed,
        a repo outside the first hundred, or an archived one, marked so) still gets its row, so the page never
        hides a folder on disk.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Query,
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]]$Checkouts,
        [Parameter(Mandatory = $true)][hashtable]$Meta
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $byRepo = @{}
    foreach ($c in @($Checkouts | Where-Object { $_ })) { if (-not $byRepo.ContainsKey($c.Repo)) { $byRepo[$c.Repo] = $c } }
    $rows = @(@($Query.Repos) | Where-Object { $_ })
    $listed = @{}; foreach ($r in $rows) { $listed[$r.Repo] = $true }
    foreach ($c in @($byRepo.Values | Sort-Object { $_.Repo })) {
        if (-not $listed.ContainsKey($c.Repo)) {
            $vis = if (@($Query.Archived) -contains $c.Repo) { 'archived' } else { '' }
            $rows += @{ Repo = $c.Repo; Name = ($c.Repo -split '/')[-1]; Url = 'https://github.com/' + $c.Repo; Description = ''; Visibility = $vis; PushedAt = ''; Issues = $null; Pulls = $null }
        }
    }
    $sum = { param($k) $t = 0; foreach ($r in $rows) { if ($null -ne $r[$k]) { $t += [int]$r[$k] } }; $t }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Repos'; V = $rows.Count },
        @{ L = 'Checked out here'; V = $byRepo.Count },
        @{ L = 'Open issues'; V = (& $sum 'Issues') },
        @{ L = 'Open pull requests'; V = (& $sum 'Pulls') })))
    if ($Query.Error) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">GitHub could not be read: ' + (& $e $Query.Error) + '. The checkouts on this machine are shown without their issues.</p>')
    }

    [void]$body.AppendLine('<div class="grid-2" id="repos">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Repos</h2><p class="card__sub">Newest push first</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<div class="table-wrap"><table class="table dr-table"><thead class="dr-thead"><tr><th class="dr-left">Repo</th><th>Visibility</th><th>Issues</th><th>Pull requests</th><th class="dr-left">Checkout here</th><th>Last push</th></tr></thead><tbody>')
    foreach ($r in $rows) {
        # The link is built from the repo's owner/name, never taken from the answer's url field (Sebastian, #3231).
        $url = 'https://github.com/' + (& $e $r.Repo)
        $desc = if ($r.Description) { '<span class="dr-desc">' + (& $e $r.Description) + '</span>' } else { '' }
        $count = { param($n, $path) if ($null -eq $n) { '--' } elseif ($n -gt 0) { '<a class="dr-link" href="' + $url + $path + '">' + $n + '</a>' } else { '0' } }
        $c = $byRepo[$r.Repo]
        $where = if (-not $c) { '<span class="note">not here</span>' }
                 else {
                     $state = if ($c.Dirty) { [string]$c.Dirty + ' uncommitted' } else { 'clean' }
                     '<code>' + (& $e $c.Branch) + '</code> <span class="note">' + $state + '</span>'
                 }
        $pushed = if ($r.PushedAt -match '^(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { '--' }
        [void]$body.AppendLine('<tr><td class="dr-left"><a class="dr-link" href="' + $url + '">' + (& $e $r.Name) + '</a>' + $desc + '</td>' +
            '<td>' + $(if ($r.Visibility) { & $e $r.Visibility } else { '--' }) + '</td>' +
            '<td class="num">' + (& $count $r.Issues '/issues') + '</td><td class="num">' + (& $count $r.Pulls '/pulls') + '</td>' +
            '<td class="dr-left">' + $where + '</td><td>' + $pushed + '</td></tr>')
    }
    [void]$body.AppendLine('</tbody></table></div>')
    $nArch = @(@($Query.Archived) | Where-Object { $_ -and -not $byRepo.ContainsKey($_) }).Count
    if ($nArch) { [void]$body.AppendLine('<p class="note">' + $nArch + ' archived repo' + $(if ($nArch -ne 1) { 's are' } else { ' is' }) + ' left out.</p>') }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    # The sessions: one row per checkout, the command to copy. The server starts nothing (#3231).
    [void]$body.AppendLine('<div class="grid-2" id="sessions">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Open a session</h2><p class="card__sub">Claude Code in that checkout, under that repo''s own rules. Paste the command in a terminal, or ask a session here: "open a session in lifehub"</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($byRepo.Count) {
        [void]$body.AppendLine('<ul class="dr-sessions">')
        foreach ($c in @($byRepo.Values | Sort-Object { $_.Repo })) {
            $cmd = Format-RepoSessionCommand -Path ([string]$c.Path)
            [void]$body.AppendLine('<li><strong>' + (& $e (($c.Repo -split '/')[-1])) + '</strong><code>' + (& $e $cmd) + '</code><button type="button" class="btn" data-copy="' + (& $e $cmd) + '">Copy</button></li>')
        }
        [void]$body.AppendLine('</ul>')
    } else {
        [void]$body.AppendLine('<p class="note">No DKJ-Solutions checkout was found beside this repo.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine((Get-CopyButtonScript))

    $style = @(
        '.dr-link { color: var(--primary-9); text-underline-offset: 2px; }',
        '.dr-thead th { background: var(--primary-3); }',
        '.table td.dr-left, .table th.dr-left { text-align: left; }',
        '.dr-desc { display: block; font-size: var(--text-xs); color: var(--primary-7); }',
        '.dr-sessions { list-style: none; padding: 0; margin: 0; }',
        '.dr-sessions li { display: flex; flex-wrap: wrap; align-items: center; gap: var(--spacing-1-5) var(--spacing-3); padding: var(--spacing-2) 0; border-top: 1px solid var(--primary-3); }',
        '.dr-sessions li:first-child { border-top: 0; }',
        '.dr-sessions strong { min-width: 12ch; }',
        '.dr-sessions code { flex: 1 1 24ch; font-size: var(--text-xs); overflow-wrap: anywhere; }'
    ) -join "`n"
    $secs = if ($null -ne $Meta.Seconds) { ' in ' + ([double]$Meta.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
    return Format-DevPageHtml -Title 'DKJ repos' -Style $style -Body $body.ToString() `
        -Lead 'Every DKJ-Solutions repo on GitHub, where it is checked out on this machine, and a Claude Code session to open there. Work in a repo runs in that repo, and an issue for it is filed there.' `
        -FooterNote ('Read from GitHub (one <code>gh api graphql</code> call) and from the checkouts beside this repo, ' + (& $e $Meta.GeneratedAt) + $secs + ' (<a class="dr-link" href="/refresh?page=dkj-repos">read again</a>). Nothing here is written to this repo.')
}
