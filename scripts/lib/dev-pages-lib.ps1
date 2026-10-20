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
    [void]$sb.Append((Format-DkjSolutionsPagesCardHtml -PagesUrl $GeneralPagesUrl -InRow $row -SameOrigin))
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
    [void]$body.AppendLine('<div class="grid-2" id="suites">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Suites</h2><p class="card__sub">Mean CI duration per suite, slowest first</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
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
    [void]$body.AppendLine('</div>')
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
    [void]$body.AppendLine('</div>')
    return Format-DevPageHtml -Title 'Test gate' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead 'What each test suite costs on CI, as the gate packs its shards from it. Measured on CI runners, never on a workstation: a local reading does not convert.' `
        -FooterNote 'Read from <code>scripts/tests/suite-durations.json</code>. Refreshed by <code>scripts/maintenance/record-suite-durations.ps1</code>; the <code>measure-suites</code> skill compares two sets of runs.'
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

