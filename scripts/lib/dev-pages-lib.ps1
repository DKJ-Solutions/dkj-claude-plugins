<#
.SYNOPSIS
    The measurement pages of this repo's dev server (#3097): the SessionStart page (the always-on path
    every session loads before its first turn) and the test-gate page (the per-suite CI durations). No
    I/O -- the server (scripts/dashboard/serve-connector-dashboard.ps1) measures and reads, and hands the
    results in, so every rule here is tested without a server.

.DESCRIPTION
    ONE SHELL FOR EVERY PAGE BELOW THE INDEX. Each page opens with the house breadcrumb bar, its trail
    starting at the Repo dashboard on '/' and ending at the page itself, unlinked (house style v0.2.0,
    "Every page: the breadcrumb bar"); then the settings button, an intro (eyebrow, h1, lead), the page's
    own blocks and a footer note naming where the data comes from.

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
    [void]$sb.AppendLine('<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="' + (& $e $ThemeKey) + '">')
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
    [void]$sb.AppendLine('<li><a href="/">Repo dashboard</a></li>')
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
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark" });</script>')
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
        '<li><a href="/">Repo dashboard</a></li>'
        '<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">Release notes</span></li>'
        '</ol></nav></div></div>'
        '<div id="settings" class="theme-settings--floating"></div>'
    ) -join "`n"
    $settings = '<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark" });</script>'

    # Back to front, so each index still points where it was read.
    $out = $Html.Substring(0, $bodyEnd) + $settings + "`n" + $Html.Substring($bodyEnd)
    $out = $bodyRx.Replace($out, { param($m) $m.Value + "`n" + $bar }, 1)
    $styleEnd = $out.IndexOf('</style>') + '</style>'.Length
    $out = $out.Substring(0, $styleEnd) + "`n" + $head + $out.Substring($styleEnd)
    # The theme key is the index page's, so a theme picked on one page holds on this one too.
    $out = $htmlRx.Replace($out, ('<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="' + (& $e $ThemeKey) + '">'), 1)
    return $out
}
